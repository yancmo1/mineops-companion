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
  private static func norm(_ s: String) -> String {
    s.folding(options: .diacriticInsensitive, locale: .current)
      .lowercased()
      .replacingOccurrences(of: ".", with: "")
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "+", with: " ")
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
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
    for entry in dir {
      let names = [entry.name] + (entry.aliases ?? [])
      for candidate in names {
        let normalized = norm(candidate)
        if normalized.isEmpty { continue }
        if raw.contains(normalized) || normalized.contains(raw) {
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
        let intersection = tokensA.intersection(tokensB).count
        let union = tokensA.union(tokensB).count
        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
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
  public static func guessDisplayName(from text: String) -> String {
    let lines = text
      .split(separator: "\n")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !lines.isEmpty else { return "Unknown" }

    let keywords = ["super manager", "promotion", "level", "snapshot", "overview", "%", "boost", "readiness"]
    let singleCharBlacklist = ["x", "X"]

    if let candidate = lines.first(where: { line in
      let lower = line.lowercased()
      if line.count < 2 { return false } // Filter single characters
      if singleCharBlacklist.contains(line) { return false } // Filter X close button
      if keywords.contains(where: { lower.contains($0) }) { return false }
      if line.rangeOfCharacter(from: .decimalDigits) != nil { return false }
      return lower.rangeOfCharacter(from: .letters) != nil
    }) {
      return candidate
    }

    if let longestByLetters = lines.max(by: { letterCount(in: $0) < letterCount(in: $1) }) {
      return longestByLetters
    }

    return lines.first ?? "Unknown"
  }

  private static func letterCount(in string: String) -> Int {
    string.reduce(0) { $0 + ($1.isLetter ? 1 : 0) }
  }
}
