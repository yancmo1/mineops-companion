import Foundation
import Security
import OSLog

/// Keychain-backed store for Kolibri credentials (ID, Auth Token, Save Game Key)
/// Mirrors the pattern used by `OpenAIKeyStore` for secure storage.
public final class KolibriKeyStore: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.yancmo1.mineops", category: "KolibriKeyStore")
    public enum KeychainError: LocalizedError {
        case keyNotFound
        case invalidValue
        case unexpectedStatus(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .keyNotFound: return "Kolibri credential not set."
            case .invalidValue: return "The provided value is empty or invalid."
            case .unexpectedStatus(let status): return "Keychain operation failed (status: \(status))."
            }
        }
    }

    public static let shared = KolibriKeyStore()

    private static var serviceName: String {
        (Bundle.main.bundleIdentifier ?? "com.example.mineopscompanion") + ".kolibri"
    }

    public enum Account: String {
        case kolibriId = "KOLIBRI_ID"
        case authToken = "KOLIBRI_AUTH_TOKEN"
        case saveGameKey = "KOLIBRI_SAVE_GAME_KEY"
    }

    public init() {}

    // Generic loader
    public func loadValue(account: Account) -> String? {
        var item: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else { return nil }
        guard let data = item as? Data else { return nil }
        let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        logger.debug("Loaded keychain value for account: \(account.rawValue, privacy: .public) length: \(value.count, privacy: .public) suffix: \(value.suffix(6), privacy: .private)")
        return value
    }

    // Generic saver (add or update)
    public func saveValue(_ value: String, account: Account) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw KeychainError.invalidValue }
        guard let data = trimmed.data(using: .utf8) else { throw KeychainError.invalidValue }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account.rawValue,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(updateStatus) }
            logger.debug("Updated keychain value for account: \(account.rawValue, privacy: .public) length: \(trimmed.count, privacy: .public) suffix: \(trimmed.suffix(6), privacy: .private)")
        } else if status == errSecItemNotFound {
            var addQuery = query
            for (k, v) in attributes { addQuery[k] = v }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
            logger.debug("Added keychain value for account: \(account.rawValue, privacy: .public) length: \(trimmed.count, privacy: .public) suffix: \(trimmed.suffix(6), privacy: .private)")
        } else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func clearValue(account: Account) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    public func clearAll() {
        for account in [Account.kolibriId, Account.authToken, Account.saveGameKey] {
            clearValue(account: account)
        }
    }

    public func hasValue(account: Account) -> Bool {
        loadValue(account: account) != nil
    }

    // Convenience helpers with environment fallback for developer convenience
    public func resolvedKolibriID() -> String? {
        if let v = loadValue(account: .kolibriId) { return v }
        let env = ProcessInfo.processInfo.environment["KOLIBRI_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty { return env }
        return nil
    }

    public func resolvedAuthToken() -> String? {
        if let v = loadValue(account: .authToken) { return v }
        let env = ProcessInfo.processInfo.environment["KOLIBRI_AUTH_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty { return env }
        return nil
    }

    public func resolvedSaveGameKey() -> String? {
        if let v = loadValue(account: .saveGameKey) { return v }
        let env = ProcessInfo.processInfo.environment["KOLIBRI_SAVE_GAME_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty { return env }
        return nil
    }

    // Convenience save/clear helpers for callers
    public func saveKolibriID(_ id: String) throws {
        try saveValue(id, account: .kolibriId)
    }

    public func saveAuthToken(_ token: String) throws {
        try saveValue(token, account: .authToken)
    }

    public func saveSaveGameKey(_ key: String) throws {
        try saveValue(key, account: .saveGameKey)
    }

    public func clearAllCredentials() {
        clearAll()
    }

    public func hasKolibriID() -> Bool { hasValue(account: .kolibriId) }
    public func hasAuthToken() -> Bool { hasValue(account: .authToken) }
    public func hasSaveGameKey() -> Bool { hasValue(account: .saveGameKey) }
}
