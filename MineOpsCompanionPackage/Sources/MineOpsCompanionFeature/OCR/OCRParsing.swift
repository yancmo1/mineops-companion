import Foundation

public enum OCRLevelParser {
  // Matches: "Level 14", "LV 7", "Lvel10", etc.
  private static let re = try! NSRegularExpression(
    pattern: "(?:lev(?:el)?|lv)\\s*([0-9]{1,2})",
    options: [.caseInsensitive]
  )

  public static func parse(from text: String) -> Int? {
    // Common OCR fixes: O→0, I/l→1
    let cleaned = text
      .replacingOccurrences(of: "O", with: "0")
      .replacingOccurrences(of: "o", with: "0")
      .replacingOccurrences(of: "I", with: "1")
      .replacingOccurrences(of: "l", with: "1")

    let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
    guard let m = re.firstMatch(in: cleaned, range: range),
          let r = Range(m.range(at: 1), in: cleaned)
    else { return nil }
    return Int(cleaned[r])
  }
}

public enum DirectoryMatcher {
  private static func norm(_ s: String) -> String {
    s.folding(options: .diacriticInsensitive, locale: .current)
      .lowercased()
      .replacingOccurrences(of: ".", with: "")
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Super lightweight token-overlap similarity for name → directory matching.
  private static func similar(_ a: String, _ b: String) -> Double {
    let ta = Set(norm(a).split(separator: " "))
    let tb = Set(norm(b).split(separator: " "))
    guard !ta.isEmpty, !tb.isEmpty else { return 0 }
    let inter = ta.intersection(tb).count
    let uni = ta.union(tb).count
    return Double(inter) / Double(uni) // 0…1
  }

  public static func bestMatch(for rawName: String, in dir: [SMDirectoryEntry]) -> SMDirectoryEntry? {
    var best: (SMDirectoryEntry, Double)?
    for entry in dir {
      let all = [entry.name] + (entry.aliases ?? [])
      let score = all.map { similar($0, rawName) }.max() ?? 0
      if let b = best {
        if score > b.1 { best = (entry, score) }
      } else {
        best = (entry, score)
      }
    }
    if let (entry, score) = best, score >= 0.5 { return entry }
    return nil
  }
}
