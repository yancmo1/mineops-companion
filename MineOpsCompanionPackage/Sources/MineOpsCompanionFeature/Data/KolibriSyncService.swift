// # File: Sources/MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/Data/KolibriSyncService.swift

import Foundation
import OSLog
import UIKit

/// Service responsible for syncing game data from Kolibri API
@MainActor
@Observable
public final class KolibriSyncService {
    public static let shared = KolibriSyncService()
    
    // MARK: - State
    
    public enum SyncState: Equatable {
        case idle
        case syncing
        case success(Date)
        case error(String)
    }
    
    public private(set) var syncState: SyncState = .idle
    public private(set) var currentSavegame: KolibriSavegameResponse?
    public private(set) var lastSyncDate: Date?
    public private(set) var lastDiagnostics: KolibriSyncDiagnostics?
    public private(set) var lastErrorDetails: String?
    public private(set) var lastImportedManagerCount: Int?
    
    // MARK: - Configuration
    
    public var syncFrequency: SyncFrequency {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "com.yancmo1.mineops.syncFrequency"),
                  let frequency = SyncFrequency(rawValue: rawValue) else {
                return .off
            }
            return frequency
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "com.yancmo1.mineops.syncFrequency")
        }
    }

    // Backward-compatible shim for legacy UI state.
    public var autoSyncEnabled: Bool {
        get { syncFrequency != .off }
        set {
            if !newValue {
                syncFrequency = .off
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let apiClient = KolibriAPIClient()
    private let credentialsStore = KolibriCredentialsStore.shared
    private let logger = Logger(subsystem: "com.yancmo1.mineops", category: "KolibriSync")
    
    // MARK: - Initialization

    private init() {
        UserDefaults.standard.register(defaults: [
            "com.yancmo1.mineops.syncFrequency": SyncFrequency.off.rawValue
        ])
    }
    
    // MARK: - Public Methods
    
    /// Manually trigger a sync
    public func sync() async {
        guard syncState != .syncing else {
            logger.info("Sync already in progress, skipping")
            return
        }
        
        guard credentialsStore.hasCredentials else {
            logger.warning("Cannot sync: missing credentials")
            syncState = .error("Missing Kolibri ID or Auth Token")
            lastErrorDetails = "Add credentials in Settings or set KOLIBRI_ID / KOLIBRI_AUTH_TOKEN environment variables for development."
            return
        }
        
        syncState = .syncing
        lastErrorDetails = nil
        logger.info("Starting sync...")
        // Record an attempt for metadata/troubleshooting
        SyncMetadataStore.shared.recordAttempt()
        
        do {
            let result = try await apiClient.fetchSavegame(
                kolibriId: credentialsStore.kolibriId,
                authToken: credentialsStore.authToken,
                saveGameKey: credentialsStore.saveGameKey
            )
            
            currentSavegame = result.savegame
            lastDiagnostics = result.diagnostics
            lastSyncDate = Date()
            syncState = .success(lastSyncDate!)

            // Persist metadata about the successful sync
            SyncMetadataStore.shared.recordSuccess(
                playerName: result.savegame.saveGameData?.playerData?.playerName,
                lastGameSaveAt: result.savegame.timestamp,
                importedManagerCount: result.savegame.saveGameData?.managers?.count,
                maskedPlayerID: credentialsStore.maskedKolibriID,
                payloadFormat: result.diagnostics.payloadFormat
            )

            logger.info("Sync completed successfully")
            
        } catch {
            logger.error("Sync failed: \(error.localizedDescription)")
            syncState = .error(error.localizedDescription)
            lastErrorDetails = Self.debugHint(for: error)
        }
    }

    /// Perform a full sync and apply the resulting manager roster to the shared progress service.
    /// This method ensures a single orchestration path for manual and launch-triggered syncs.
    public func syncAndApplyToProgress() async {
        await sync()

        guard case .success = syncState else { return }

        let managers = getManagers()
        guard !managers.isEmpty else {
            setLastImportedManagerCount(0)
            return
        }

        await SMProgressService.shared.applySyncData(managers: managers)
        setLastImportedManagerCount(managers.count)
    }

    /// Build a roster that can be consumed by the Manager tab / strategy pipeline.
    public func buildRecognizedManagersFromSync() async -> [RecognizedSM] {
        let managers = getManagers()
        guard !managers.isEmpty else { return [] }

        let directory = (try? SMDirectory.load()) ?? []
        let directoryByID = Dictionary(uniqueKeysWithValues: directory.map { ($0.id, $0) })
        let trackerIDByGameID = await apiClient.fetchManagerIDLookup()

        var recognized: [RecognizedSM] = []
        recognized.reserveCapacity(managers.count)

        for manager in managers {
            let trackerID = trackerIDByGameID[manager.id]
            let directoryEntry = trackerID.flatMap { directoryByID[$0] }

            let levelFraction: SMStats.Fraction? = {
                guard let level = manager.level, level > 0 else { return nil }
                return .init(current: level, total: max(level, 50))
            }()

            let promotionFraction: SMStats.Fraction? = {
                guard let promotion = manager.promotion else { return nil }
                return .init(current: max(0, promotion), total: 5)
            }()

            let record = RecognizedSM(
                sourceImage: UIImage(),
                rawText: "Synced from Kolibri API",
                level: manager.level,
                directoryMatch: directoryEntry,
                resolvedName: displayName(for: manager, trackerID: trackerID),
                stats: SMStats(level: levelFraction, promotion: promotionFraction),
                rarity: directoryEntry?.rarity.capitalized,
                role: roleDisplay(fromDepartment: directoryEntry?.department),
                stars: nil,
                fragments: manager.fragments ?? 0,
                active: .init(),
                passive: .init(),
                actions: .init()
            )

            recognized.append(record)
        }

        recognized.sort { lhs, rhs in
            lhs.resolvedName.localizedCaseInsensitiveCompare(rhs.resolvedName) == .orderedAscending
        }

        return recognized
    }

    public func setLastImportedManagerCount(_ count: Int) {
        lastImportedManagerCount = count
    }
    
    /// Legacy no-op. Repeating in-session sync loops are intentionally disabled.
    public func startAutoSync() {
        logger.info("startAutoSync called; repeating sync is disabled in V2")
    }
    
    /// Legacy no-op.
    public func stopAutoSync() {
        logger.info("stopAutoSync called; repeating sync is disabled in V2")
    }
    
    /// Legacy no-op.
    private func restartAutoSync() {
        logger.info("restartAutoSync called; repeating sync is disabled in V2")
    }
    
    // MARK: - Helper Methods

    /// Expose whether the service has usable credentials to perform a sync.
    public var hasUsableCredentials: Bool {
        credentialsStore.hasCredentials
    }
    
    /// Extract manager data from current savegame
    public func getManagers() -> [ManagerData] {
        currentSavegame?.saveGameData?.managers ?? []
    }
    
    /// Extract mine data from current savegame
    public func getMines() -> [MineData] {
        currentSavegame?.saveGameData?.mines ?? []
    }
    
    /// Extract continent data from current savegame
    public func getContinents() -> [ContinentData] {
        currentSavegame?.saveGameData?.continents ?? []
    }
    
    /// Extract resources from current savegame
    public func getResources() -> Resources? {
        currentSavegame?.saveGameData?.resources
    }

    private static func debugHint(for error: Error) -> String {
        let message = error.localizedDescription.lowercased()

        if message.contains("http 401") || message.contains("unauthorized") {
            return "Authorization failed (401). The token may be expired or copied incorrectly."
        }

        if message.contains("payload") || message.contains("decode") || message.contains("inflate") {
            return "Save payload decode failed. Confirm this is Capsule savegame data with U58U header and valid auth headers."
        }

        if message.contains("timed out") || message.contains("network") {
            return "Network issue while syncing. Check connectivity and retry manual sync."
        }

        return "Open Sync Debug for payload details and retry manually."
    }

    private func displayName(for manager: ManagerData, trackerID: String?) -> String {
        if let knownName = manager.name, !knownName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return knownName
        }

        if let trackerID {
            return trackerID
                .split(separator: "_")
                .map { $0.capitalized }
                .joined(separator: " ")
        }

        return "Manager #\(manager.id)"
    }

    private func roleDisplay(fromDepartment department: String?) -> String? {
        guard let department else { return nil }

        switch department.lowercased() {
        case "mineshaft":
            return "Mine"
        case "elevator":
            return "Transport"
        case "warehouse":
            return "Warehouse"
        default:
            return nil
        }
    }
}
