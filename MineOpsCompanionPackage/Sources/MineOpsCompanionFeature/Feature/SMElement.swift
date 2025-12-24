import Foundation

/// Element affinity for a Super Manager.
///
/// This is intentionally lightweight and string-backed because the directory schema may evolve.
public struct SMElement: Hashable, Sendable {
    public let name: String

    public init(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmed.isEmpty ? "Unknown" : trimmed
    }

    public static let unknown = SMElement("Unknown")

    public var normalizedKey: String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
