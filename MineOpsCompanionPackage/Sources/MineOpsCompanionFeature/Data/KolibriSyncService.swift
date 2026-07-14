// # File: Sources/MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/Data/KolibriSyncService.swift

import Foundation
import OSLog
import UIKit

/// Service responsible for syncing game data from Kolibri API
@MainActor
@Observable
public final class KolibriSyncService {
    
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
    
    public var autoSyncEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "com.yancmo1.mineops.autoSyncEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "com.yancmo1.mineops.autoSyncEnabled")
            if newValue {
                startAutoSync()
            } else {
                stopAutoSync()
            }
        }
    }
    
    public var syncInterval: TimeInterval {
        get {
            let interval = UserDefaults.standard.double(forKey: "com.yancmo1.mineops.syncInterval")
            return interval > 0 ? interval : 30.0 // Default 30 seconds
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "com.yancmo1.mineops.syncInterval")
            if autoSyncEnabled {
                restartAutoSync()
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let apiClient = KolibriAPIClient()
    private let credentialsStore = KolibriCredentialsStore.shared
    private let logger = Logger(subsystem: "com.yancmo1.mineops", category: "KolibriSync")
    
    private var syncTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    public init() {
        UserDefaults.standard.register(defaults: [
            "com.yancmo1.mineops.autoSyncEnabled": false,
            "com.yancmo1.mineops.syncInterval": 30.0
        ])

        // Start auto-sync if enabled
        if autoSyncEnabled {
            startAutoSync()
        }
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
            lastErrorDetails = "Add credentials in Settings or use the hardcoded defaults."
            return
        }
        
        syncState = .syncing
        lastErrorDetails = nil
        logger.info("Starting sync...")
        
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
            
            logger.info("Sync completed successfully")
            
        } catch {
            logger.error("Sync failed: \(error.localizedDescription)")
            syncState = .error(error.localizedDescription)
            lastErrorDetails = Self.debugHint(for: error)
        }
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
    
    /// Start automatic syncing at the configured interval
    public func startAutoSync() {
        stopAutoSync() // Cancel any existing task
        
        syncTask = Task { [weak self] in
            guard let self else { return }
            
            logger.info("Auto-sync started with interval: \(self.syncInterval)s")
            
            // Initial sync
            await self.sync()
            
            // Periodic sync
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(syncInterval))
                
                guard !Task.isCancelled else { break }
                await self.sync()
            }
            
            logger.info("Auto-sync stopped")
        }
    }
    
    /// Stop automatic syncing
    public func stopAutoSync() {
        syncTask?.cancel()
        syncTask = nil
    }
    
    /// Restart auto-sync (useful when interval changes)
    private func restartAutoSync() {
        if autoSyncEnabled {
            startAutoSync()
        }
    }
    
    // MARK: - Helper Methods
    
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
