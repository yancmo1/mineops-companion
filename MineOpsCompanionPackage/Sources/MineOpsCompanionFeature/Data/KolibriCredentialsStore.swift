// # File: Sources/MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/Data/KolibriCredentialsStore.swift

import Foundation

/// Secure storage for Kolibri API credentials
@MainActor
@Observable
public final class KolibriCredentialsStore {
    
    public static let shared = KolibriCredentialsStore()
    
    // MARK: - Storage Keys
    
    private enum Keys {
        static let kolibriId = "com.yancmo1.mineops.kolibriId"
        static let authToken = "com.yancmo1.mineops.kolibriAuthToken"
        static let saveGameKey = "com.yancmo1.mineops.saveGameKey"
    }

    private enum HardcodedDefaults {
        static let kolibriId = "dbffca92-27e9-485a-831a-feb5bfc2e3c4"
        static let authToken = "M8XMbdJKrSZMZL2nxd2vH2tFWE6m7LaJwY7hNsTQavtZ65Xe8AztsR=="
        static let saveGameKey = "0"
    }
    
    // MARK: - Properties
    
    public var kolibriId: String {
        get {
            resolvedValue(forKey: Keys.kolibriId, fallback: HardcodedDefaults.kolibriId)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.kolibriId)
        }
    }
    
    public var authToken: String {
        get {
            resolvedValue(forKey: Keys.authToken, fallback: HardcodedDefaults.authToken)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.authToken)
        }
    }
    
    public var saveGameKey: String {
        get {
            resolvedValue(forKey: Keys.saveGameKey, fallback: HardcodedDefaults.saveGameKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.saveGameKey)
        }
    }

    public var usingHardcodedDefaults: Bool {
        let hasStoredID = hasStoredValue(forKey: Keys.kolibriId)
        let hasStoredToken = hasStoredValue(forKey: Keys.authToken)
        return !hasStoredID && !hasStoredToken
    }
    
    // MARK: - Computed Properties
    
    public var hasCredentials: Bool {
        !kolibriId.isEmpty && !authToken.isEmpty
    }
    
    // MARK: - Methods
    
    public func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: Keys.kolibriId)
        UserDefaults.standard.removeObject(forKey: Keys.authToken)
        UserDefaults.standard.removeObject(forKey: Keys.saveGameKey)
    }

    private func hasStoredValue(forKey key: String) -> Bool {
        guard let value = UserDefaults.standard.string(forKey: key) else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func resolvedValue(forKey key: String, fallback: String) -> String {
        guard let value = UserDefaults.standard.string(forKey: key) else {
            return fallback
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
    
    private init() {}
}
