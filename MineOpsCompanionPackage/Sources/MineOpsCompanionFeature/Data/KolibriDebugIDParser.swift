import Foundation

public enum KolibriDebugIDParser {
    private static let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#

    /// Extracts the last UUID from a pasted debug ID string and returns it lowercased.
    /// Returns nil if no UUID is found.
    public static func extractLastUUID(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: uuidPattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        guard let last = matches.last, let r = Range(last.range, in: text) else { return nil }
        return text[r].lowercased()
    }
}
