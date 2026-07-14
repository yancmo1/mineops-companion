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
        if masterService.masterData.isEmpty {
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
        // Ensure master data is loaded
        if masterService.masterData.isEmpty {
            await masterService.refresh()
        }

        guard !masterService.masterData.isEmpty else { return }

        // Build lookup by gameId
        let masterByGameId: [Int: SMMasterEntry] = Dictionary(
            uniqueKeysWithValues: masterService.masterData.map { ($0.gameId, $0) }
        )

        // Build existing lookup by gameId for merge
        let existingByGameId: [Int: SMProgress] = Dictionary(
            uniqueKeysWithValues: progress.compactMap { prog in
                let id = prog.master.gameId
                return prog.unlocked || prog.rank > 0 || prog.level > 1 || prog.promoted > 0
                    ? (id, prog)
                    : nil
            }
        )

        var updated: [Int: SMProgress] = [:]

        // Start from fresh defaults for all master entries
        for entry in masterService.masterData {
            let existing = existingByGameId[entry.gameId]
            updated[entry.gameId] = SMProgress(
                master: entry,
                rank: existing?.rank ?? 0,
                level: existing?.level ?? 1,
                promoted: existing?.promoted ?? 0,
                unlocked: existing?.unlocked ?? false,
                fragments: existing?.fragments ?? 0
            )
        }

        // Apply sync data
        for manager in managers {
            guard let gameId = Int(manager.id),
                  var prog = updated[gameId] else { continue }

            prog.level = max(prog.level, manager.level ?? 1)
            prog.promoted = max(prog.promoted, manager.promotion ?? 0)
            prog.rank = max(prog.rank, manager.rank ?? 0)
            prog.fragments = manager.fragments ?? prog.fragments
            prog.unlocked = true
            updated[gameId] = prog
        }

        progress = updated.values.sorted { $0.master.name < $1.master.name }
        saveToDisk()
        logger.info("Applied sync data: \(self.progress.filter(\.unlocked).count) unlocked SMs")
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
