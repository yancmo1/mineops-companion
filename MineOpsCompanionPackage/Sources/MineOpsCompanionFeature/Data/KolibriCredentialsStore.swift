// # File: Sources/MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/Data/KolibriCredentialsStore.swift

import Foundation

/// Secure storage for Kolibri API credentials backed by Keychain (no hardcoded defaults).
@MainActor
@Observable
public final class KolibriCredentialsStore {
    public static let shared = KolibriCredentialsStore()

    // MARK: - Properties

    /// Returns the resolved Kolibri ID (Keychain -> env -> nil). Empty string if not present.
    public var kolibriId: String {
        get { KolibriKeyStore.shared.resolvedKolibriID() ?? "" }
        set {
            do {
                try KolibriKeyStore.shared.saveKolibriID(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                // Swallow errors silently; callers should surface UX-level errors when saving.
            }
        }
    }

    public var authToken: String {
        get { KolibriKeyStore.shared.resolvedAuthToken() ?? "" }
        set {
            do {
                try KolibriKeyStore.shared.saveAuthToken(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                // ignore here; UI will surface errors when appropriate
            }
        }
    }

    /// Save game key is stored in Keychain for parity with other credentials but is not sensitive.
    public var saveGameKey: String {
        // Default to "0" when no save game key is configured to match Capsule API expectations.
        get { KolibriKeyStore.shared.resolvedSaveGameKey() ?? "0" }
        set {
            do {
                try KolibriKeyStore.shared.saveSaveGameKey(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                // ignore
            }
        }
    }

    /// Hardcoded defaults removed — always false.
    public var usingHardcodedDefaults: Bool { false }

    // MARK: - Computed Properties

    public var hasCredentials: Bool {
        !(kolibriId.isEmpty || authToken.isEmpty)
    }

    // MARK: - Methods

    public func clearCredentials() {
        KolibriKeyStore.shared.clearAllCredentials()
    }

    public var maskedKolibriID: String {
        let id = kolibriId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id.count >= 3 else { return id }
        return "••••• \(id.suffix(3))"
    }

    private init() {}
}
