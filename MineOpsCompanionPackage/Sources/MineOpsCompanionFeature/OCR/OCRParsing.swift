import Foundation

import Foundation

public enum OCRLevelParser {
  // Matches: "Level 14", "Level: 14/50", "LV 7", "Lvl 10"
  private static let re = try! NSRegularExpression(
    pattern: #"(?i)\b(?:level|lvl|lv)[:\s]*([0-9]{1,2})(?:\s*/\s*\d{1,3})?"#,
    options: []
  )

  public static func parse(from text: String) -> Int? {
    // Do NOT replace letters globally (it breaks "Level").
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let m = re.firstMatch(in: text, range: range),
          let r = Range(m.range(at: 1), in: text)
    else { return nil }
    return Int(text[r])
  }
}

public enum DirectoryMatcher {
  /// Name tokens that are too generic to identify a specific manager by themselves.
  private static let weakNameTokens: Set<String> = [
    "dr", "mr", "mrs", "ms", "sir", "lord", "lady", "count", "queen", "king", "prof", "professor"
  ]

  /// Normalizes common OCR letter/digit confusions for name matching only.
  /// Example: "N0va" -> "nova"
  private static func normalizeNameOCRConfusions(_ s: String) -> String {
    let chars = Array(s)
    guard !chars.isEmpty else { return s }

    var out = ""
    out.reserveCapacity(chars.count)

    for i in chars.indices {
      let c = chars[i]
      let prevIsLetter = i > 0 ? chars[i - 1].isLetter : false
      let nextIsLetter = i + 1 < chars.count ? chars[i + 1].isLetter : false

      if c == "0" && (prevIsLetter || nextIsLetter) {
        out.append("o")
      } else {
        out.append(c)
      }
    }

    return out
  }

  private static func hasStrongSharedToken(_ tokens: Set<String>) -> Bool {
    tokens.contains { token in
      token.count >= 3 && !weakNameTokens.contains(token)
    }
  }

  private static func norm(_ s: String) -> String {
    normalizeNameOCRConfusions(
      s.folding(options: .diacriticInsensitive, locale: .current)
      .lowercased()
      .replacingOccurrences(of: ".", with: "")
      .replacingOccurrences(of: "'", with: "")
      .replacingOccurrences(of: "’", with: "")
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "+", with: " ")
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }

  private static func tokensLettersOnly(_ s: String) -> Set<String> {
    let digits = CharacterSet.decimalDigits
    let toks = norm(s).split(separator: " ").map(String.init)
    return Set(toks.filter { $0.unicodeScalars.allSatisfy { !digits.contains($0) } && $0.count >= 2 })
  }

  private static func bestMatchWithScore(for rawName: String, in dir: [SMDirectoryEntry]) -> (SMDirectoryEntry, Double)? {
    let raw = norm(rawName)
    guard !raw.isEmpty else { return nil }

    // Direct containment in the raw line earns a perfect score.
    // NOTE: We intentionally only check `raw.contains(candidate)`.
    // Allowing `candidate.contains(raw)` creates severe false positives when OCR emits short
    // fragments (e.g. "u", "ut"), which would incorrectly match entries like "Ut'ux".
    for entry in dir {
      let names = [entry.name] + (entry.aliases ?? [])
      for candidate in names {
        let normalized = norm(candidate)
        if normalized.isEmpty { continue }
        if normalized.count >= 3, raw.contains(normalized) {
          return (entry, 1.0)
        }
      }
    }

    let tokensA = tokensLettersOnly(rawName)
    guard !tokensA.isEmpty else { return nil }

    var best: (SMDirectoryEntry, Double)?
    for entry in dir {
      let candidates = [entry.name] + (entry.aliases ?? [])
      let score = candidates.map { candidate -> Double in
        let tokensB = tokensLettersOnly(candidate)
        guard !tokensB.isEmpty else { return 0 }
        let intersectionTokens = tokensA.intersection(tokensB)
        // Guard against false positives where only weak tokens overlap,
        // e.g. "dr" matching all doctor names.
        guard hasStrongSharedToken(intersectionTokens) else { return 0 }

        let intersection = intersectionTokens.count
        let union = tokensA.union(tokensB).count
        guard union > 0 else { return 0 }
        var score = Double(intersection) / Double(union)

        // Slight penalty for 1-token overlaps across multi-token names.
        // This helps avoid near-collisions while still allowing clear single-token matches.
        if intersection == 1, tokensA.count >= 2, tokensB.count >= 2 {
          score *= 0.8
        }

        return score
      }.max() ?? 0

      if let currentBest = best {
        if score > currentBest.1 { best = (entry, score) }
      } else if score > 0 {
        best = (entry, score)
      }
    }

    return best
  }

  /// Prefer substring containment, then fall back to token Jaccard with a lower gate.
  public static func bestMatch(for rawName: String, in dir: [SMDirectoryEntry]) -> SMDirectoryEntry? {
    bestMatchWithScore(for: rawName, in: dir)?.0
  }

  /// Inspect each line of OCR output to locate the most likely directory entry.
  public static func bestMatch(in text: String, directory dir: [SMDirectoryEntry]) -> SMDirectoryEntry? {
    let lines = text
      .split(separator: "\n")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    var best: (SMDirectoryEntry, Double)?

    for line in lines {
      guard let candidate = bestMatchWithScore(for: line, in: dir) else { continue }
      if candidate.1 >= 0.95 { return candidate.0 } // strong signal, finish early
      if let currentBest = best {
        if candidate.1 > currentBest.1 { best = candidate }
      } else {
        best = candidate
      }
    }

    if let best, best.1 >= 0.30 {
      return best.0
    }

    // Fall back to token comparison against the whole text
    if let fallback = bestMatchWithScore(for: text, in: dir), fallback.1 >= 0.30 {
      return fallback.0
    }

    return nil
  }
}

public enum OCRTextHeuristics {
  /// Common UI elements and game labels that should NOT be treated as manager names
  private static let uiBlacklist: Set<String> = [
    // Button labels
    "done", "cancel", "ok", "close", "back", "next", "confirm", "skip",
    "level up", "promote", "rank up", "upgrade", "collect", "claim",
    // Game UI elements
    "super manager", "super managers", "supermanager", "supermanagers",
    "promotion", "snapshot", "overview", "details", "info", "stats",
    "active", "passive", "ability", "abilities", "effect", "effects",
    "duration", "cooldown", "boost", "boosts", "multiplier",
    "readiness", "ready", "available", "unavailable", "locked", "unlocked",
    // Common misreads
    "pharmacy", "x reels", "reels", "reel",
    "loading", "processing", "analyzing",
    // Percentage and number patterns
    "mine", "mineshaft", "elevator", "warehouse", "transport",
    // Rarity labels
    "common", "rare", "epic", "legendary", "mythic"
  ]

  /// Additional patterns that indicate this line is NOT a manager name
  private static let blacklistPatterns: [NSRegularExpression] = {
    let patterns = [
      #"^\d+$"#,                          // Just numbers
      #"^\d+\s*[kmbt]$"#,                 // Compact numbers like 154K, 2M, 1B
      #"^\d+(?:\.\d+)?\s*[kmbt]$"#,       // Compact decimals like 1.5K, 2.3M
      #"^\d+\s*[x%]"#,                    // Multipliers like "5x" or "500%"
      #"^[x%]\s*\d+"#,                    // Reversed like "x5"
      #"^\d+\s*(m|min|s|sec|h|hr)"#,      // Duration like "5m" or "30s"
      #"^level\s*\d+"#,                   // "Level 15"
      #"^lv\s*\d+"#,                      // "Lv 15"
      #"^\d+\s*/\s*\d+"#,                 // "14/50" fraction
      #"^[+\-]\s*\d+"#,                   // "+50%" or "-10%"
      #"^[\⭐★✦✪]+"#,                     // Star characters
      #"^\$"#,                            // Dollar amounts
      #"^[A-Z]$"#                         // Single uppercase letter (close buttons)
    ]
    return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
  }()

  public static func guessDisplayName(from text: String) -> String {
    let lines = text
      .split(separator: "\n")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !lines.isEmpty else { return "Unknown" }

    // Find the best candidate line that looks like a manager name
    if let candidate = lines.first(where: { line in
      isValidManagerName(line)
    }) {
      return candidate
    }

    // Fallback: find line with most letters that isn't blacklisted
    if let longestByLetters = lines
      .filter({ !isBlacklisted($0) })
      .max(by: { letterCount(in: $0) < letterCount(in: $1) }) {
      return longestByLetters
    }

    return lines.first ?? "Unknown"
  }

  /// Check if a string could be a valid manager name
  private static func isValidManagerName(_ line: String) -> Bool {
    // Too short
    if line.count < 2 { return false }
    
    // Single character or just X (close button)
    if line.count == 1 || line.uppercased() == "X" { return false }
    
    // Check against blacklist
    if isBlacklisted(line) { return false }
    
    // Check against regex patterns
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    for pattern in blacklistPatterns {
      if pattern.firstMatch(in: line, range: range) != nil {
        return false
      }
    }
    
    // Contains digits without letters (pure number)
    let hasLetters = line.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    let hasDigits = line.rangeOfCharacter(from: .decimalDigits) != nil
    
    // Names with digits are okay if they have letters (like H4V0C)
    // But pure numbers or percentage text is not a name
    if hasDigits && !hasLetters { return false }
    
    // At least some letters present
    return hasLetters
  }
  
  private static func isBlacklisted(_ line: String) -> Bool {
    let normalized = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    return uiBlacklist.contains(normalized)
  }

  private static func letterCount(in string: String) -> Int {
    string.reduce(0) { $0 + ($1.isLetter ? 1 : 0) }
  }
}
