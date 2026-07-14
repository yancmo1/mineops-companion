import Foundation
import OSLog

/// Merges Kolibri sync output with idle-miners master data and persists progress
@MainActor
@Observable
public final class SMProgressService {
    public static let shared = SMProgressService()

    public private(set) var progress: [SMProgress] = []
    public private(set) var isLoading = false

    private let masterService = SMMasterDataService.shared
    private let logger = Logger(subsystem: "com.yancmo1.mineops", category: "Progress")

    private let progressKey = "com.yancmo1.mineops.smProgressData"

    private init() {
        loadFromDisk()
    }

    /// Initialize or refresh progress from master data + sync.
    public func initialize() async {
        // Always try to upgrade bundled/cache fallback data to full remote master data.
        if masterService.masterData.isEmpty || masterService.currentSource != .remote {
            await masterService.refresh()
        }

        guard !masterService.masterData.isEmpty else {
            logger.warning("Cannot initialize progress: master data is empty")
            return
        }

        // If we have no progress yet, create default entries from master data
        if progress.isEmpty {
            progress = masterService.masterData.map { entry in
                SMProgress(
                    master: entry,
                    rank: 0,
                    level: 1,
                    promoted: 0,
                    unlocked: false,
                    fragments: 0
                )
            }
            saveToDisk()
        }
    }

    /// Merge synced manager data from Kolibri into progress, matching by gameId.
    public func applySyncData(managers: [ManagerData]) async {
        // Ensure master data is loaded and prefer remote definitions when available.
        if masterService.masterData.isEmpty || masterService.currentSource != .remote {
            await masterService.refresh()
        }

        guard !masterService.masterData.isEmpty else { return }
        // Keep previous snapshot to detect changes
        let previousProgress = progress

        // Build fresh defaults for all master entries
        var updated: [Int: SMProgress] = [:]
        for entry in masterService.masterData {
            updated[entry.gameId] = SMProgress(
                master: entry,
                rank: 0,
                level: 1,
                promoted: 0,
                unlocked: false,
                fragments: 0
            )
        }

        // Apply authoritative Kolibri values directly
        for manager in managers {
            guard let gameId = Int(manager.id), var prog = updated[gameId] else { continue }

            prog.level = max(1, manager.level ?? 1)
            prog.promoted = max(0, manager.promotion ?? 0)
            prog.rank = max(0, manager.rank ?? 0)
            prog.fragments = max(0, manager.fragments ?? 0)
            prog.unlocked = true
            updated[gameId] = prog
        }

        // Replace progress atomically
        let newProgress = updated.values.sorted { $0.master.name < $1.master.name }

        // Compute which managers changed compared to previous progress so UI can highlight
        var changedIDs: [String] = []
        let previousByGameId = Dictionary(uniqueKeysWithValues: previousProgress.map { ($0.master.gameId, $0) })

        for prog in newProgress {
            let gid = prog.master.gameId
            if let old = previousByGameId[gid] {
                if old.unlocked != prog.unlocked || old.level != prog.level || old.rank != prog.rank || old.promoted != prog.promoted || old.fragments != prog.fragments {
                    changedIDs.append(prog.master.id)
                }
            } else {
                // Previously absent entry; if now unlocked consider it a change
                if prog.unlocked {
                    changedIDs.append(prog.master.id)
                }
            }
        }

        progress = newProgress
        saveToDisk()

        // Persist recently-updated manager ids for UI consumption
        SyncMetadataStore.shared.recordRecentUpdates(changedIDs)

        logger.info("Applied authoritative sync data: \(self.progress.filter(\.unlocked).count) unlocked SMs")
    }

    /// Update a single SM's progress manually.
    public func update(id: String, rank: Int? = nil, level: Int? = nil, promoted: Int? = nil, unlocked: Bool? = nil) {
        guard let index = progress.firstIndex(where: { $0.id == id }) else { return }
        var p = progress[index]
        if let rank { p.rank = max(0, rank) }
        if let level { p.level = max(1, level) }
        if let promoted { p.promoted = max(0, promoted) }
        if let unlocked { p.unlocked = unlocked }
        progress[index] = p
        saveToDisk()
    }

    // MARK: - Queries

    public func unlockedManagers(for area: SMDepartment) -> [SMProgress] {
        progress.filter { $0.unlocked && $0.areaEnum == area }
    }

    public var unlockedCount: Int { progress.filter(\.unlocked).count }
    public var totalCount: Int { progress.count }

    public var coverageByArea: [SMDepartment: Int] {
        var result: [SMDepartment: Int] = [:]
        for dept in SMDepartment.allCases {
            result[dept] = unlockedManagers(for: dept).count
        }
        return result
    }

    public var totalByArea: [SMDepartment: Int] {
        var result: [SMDepartment: Int] = [:]
        for dept in SMDepartment.allCases {
            result[dept] = progress.filter { $0.areaEnum == dept }.count
        }
        return result
    }

    // MARK: - Recommendations

    /// Deterministic strength score for an unlocked manager.
    ///
    /// Formula:
    /// - log10(max(effectiveActiveValue, 1)) * 100
    /// - + level * 1.5
    /// - + rank * 20
    /// - + promoted * 10
    /// - + rarity weight
    public func strengthScore(for manager: SMProgress) -> Double {
        let activeValue = max(manager.effectiveActiveValue(using: masterService.activeScaling), 1)
        return log10(activeValue) * 100
            + Double(manager.level) * 1.5
            + Double(manager.rank) * 20
            + Double(manager.promoted) * 10
            + rarityWeight(for: manager.master.rarity)
    }

    public func strongestUnlockedManager(in department: SMDepartment) -> SMProgress? {
        unlockedManagers(for: department)
            .sorted { lhs, rhs in
                let lhsScore = strengthScore(for: lhs)
                let rhsScore = strengthScore(for: rhs)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.master.name.localizedCaseInsensitiveCompare(rhs.master.name) == .orderedAscending
            }
            .first
    }

    public func strongestByArea() -> [SMDepartment: SMProgress] {
        var result: [SMDepartment: SMProgress] = [:]
        for department in SMDepartment.allCases {
            if let strongest = strongestUnlockedManager(in: department) {
                result[department] = strongest
            }
        }
        return result
    }

    /// Fragment-backed improvement opportunities.
    ///
    /// This intentionally uses only known data (current fragment count) and does not infer
    /// unknown rank-up thresholds.
    public func upgradeOpportunityManagers(limit: Int = 4) -> [SMProgress] {
        progress
            .filter { $0.unlocked && $0.fragments > 0 }
            .sorted { lhs, rhs in
                if lhs.fragments != rhs.fragments {
                    return lhs.fragments > rhs.fragments
                }
                let lhsScore = strengthScore(for: lhs)
                let rhsScore = strengthScore(for: rhs)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.master.name.localizedCaseInsensitiveCompare(rhs.master.name) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Returns true only when this service has a known rank-up threshold and the manager meets/exceeds it.
    /// Unknown thresholds intentionally return false rather than guessing.
    public func isRankUpReady(_ manager: SMProgress) -> Bool {
        guard manager.unlocked,
              let threshold = knownFragmentThreshold(forRank: manager.rank)
        else {
            return false
        }

        return manager.fragments >= threshold
    }

    public func knownFragmentThreshold(forRank rank: Int) -> Int? {
        switch rank {
        case 0: return 15
        case 1: return 30
        case 2: return 50
        case 3: return 80
        default: return nil
        }
    }

    public func raritySortWeight(for rarity: String) -> Int {
        switch rarity.lowercased() {
        case "legendary": return 4
        case "epic": return 3
        case "rare": return 2
        case "common": return 1
        default: return 0
        }
    }

    private func rarityWeight(for rarity: String) -> Double {
        switch rarity.lowercased() {
        case "legendary": return 25
        case "epic": return 18
        case "rare": return 12
        case "common": return 6
        default: return 0
        }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: progressKey)
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: progressKey),
              let decoded = try? JSONDecoder().decode([SMProgress].self, from: data) else { return }
        progress = decoded
    }
}
