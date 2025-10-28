import Foundation

public enum OCRLevelParser {
    // Matches: "Level 14", "Lv 7", "LEVEL10", etc.
    private static let regex = try! NSRegularExpression(
        pattern: "(?:lev(?:el)?|lv)\\s*([0-9]{1,2})",
        options: [.caseInsensitive]
    )

    public static func parse(from text: String) -> Int? {
        let cleaned = text
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "o", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "l", with: "1")

        let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        guard let match = regex.firstMatch(in: cleaned, options: [], range: range),
              match.numberOfRanges >= 2,
              let levelRange = Range(match.range(at: 1), in: cleaned) else {
            return nil
        }

        return Int(cleaned[levelRange])
    }
}
