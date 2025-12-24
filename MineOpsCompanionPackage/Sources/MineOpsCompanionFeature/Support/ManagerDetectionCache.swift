import Foundation

/// Lightweight cache for manager name detection results.
///
/// This is deliberately *not* CoreData/SwiftData: it's ephemeral, small, and keyed by image hash.
/// It reduces CoreData surface area and removes the need for a dedicated detection entity.
public actor ManagerDetectionCache {
    public static let shared = ManagerDetectionCache()

    private let defaults: UserDefaults
    private let storageKey = "MineOps.ManagerDetectionCache.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadName(for imageHash: String) -> String? {
        let dict = defaults.dictionary(forKey: storageKey) as? [String: String]
        return dict?[imageHash]
    }

    public func storeName(_ name: String, for imageHash: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var dict = defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
        dict[imageHash] = trimmed
        defaults.set(dict, forKey: storageKey)
    }

    public func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}
