import Foundation
import Security

/// Stores the OpenAI API key securely in Keychain.
///
/// Why Keychain?
/// - Environment variables are not available on iPhone/TestFlight.
/// - Keys should never be committed to the repo or shipped in the app binary.
public final class OpenAIKeyStore: @unchecked Sendable {
    public enum KeychainError: LocalizedError {
        case keyNotFound
        case invalidKey
        case unexpectedStatus(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .keyNotFound:
                return "OpenAI API key not set."
            case .invalidKey:
                return "The OpenAI API key is empty or invalid."
            case .unexpectedStatus(let status):
                return "Keychain operation failed (status: \(status))."
            }
        }
    }

    public static let shared = OpenAIKeyStore()

    /// A stable Keychain service name.
    private static let serviceName = (Bundle.main.bundleIdentifier ?? "com.example.mineopscompanion") + ".openai"
    private static let accountName = "OPENAI_API_KEY"

    public init() {}

    /// Reads the API key from Keychain.
    public func loadKey() -> String? {
        var item: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else { return nil }
        guard let data = item as? Data else { return nil }
        let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key, !key.isEmpty else { return nil }
        return key
    }

    /// Saves (adds or updates) the API key in Keychain.
    public func saveKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw KeychainError.invalidKey }
        guard let data = trimmed.data(using: .utf8) else { throw KeychainError.invalidKey }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.accountName,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(updateStatus) }
        } else if status == errSecItemNotFound {
            var addQuery = query
            for (k, v) in attributes { addQuery[k] = v }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        } else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func clearKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.accountName,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Quick check whether a key exists in the keychain.
    public func hasKey() -> Bool {
        loadKey() != nil
    }

    /// Returns the key used by the app.
    ///
    /// Order:
    /// 1) Keychain (device/TestFlight)
    /// 2) Process environment (local dev / simulator convenience)
    public func resolvedAPIKey() -> String? {
        if let key = loadKey() { return key }
        let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty { return env }
        return nil
    }
}
