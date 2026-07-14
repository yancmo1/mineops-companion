import Foundation
import OSLog

public enum MasterDataSource: String, Sendable {
    case bundled
    case cache
    case remote
}

/// Fetches and caches SM master data from idle-miners.com API
@MainActor
@Observable
public final class SMMasterDataService {
    public static let shared = SMMasterDataService()

    public var masterData: [SMMasterEntry] = []
    public private(set) var activeScaling: [String: SMActiveScaling] = [:]
    public private(set) var passiveTables: SMPassiveTables?
    public private(set) var isLoading = false
    public private(set) var lastFetchDate: Date?
    public private(set) var errorMessage: String?
    public private(set) var currentSource: MasterDataSource = .bundled

    private let baseURL = "https://idle-miners.com"
    private let session: URLSession
    private let logger = Logger(subsystem: "com.yancmo1.mineops", category: "MasterData")
    private let cacheKey = "com.yancmo1.mineops.masterDataCache"

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)

        if loadCachedSnapshot() {
            currentSource = .cache
        } else if loadBundledFallback() {
            currentSource = .bundled
        }
    }

    /// Fetch or refresh all master data from idle-miners.com
    public func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if masterData.isEmpty {
            _ = loadCachedSnapshot() || loadBundledFallback()
        }

        do {
            async let smData = fetchData(from: "\(baseURL)/api/sm-data")
            async let activeData = fetchData(from: "\(baseURL)/api/sm-actives")
            async let passiveData = fetchData(from: "\(baseURL)/static/data/sm_passive_tables.json")

            let (smRaw, activeRaw, passiveRaw) = try await (smData, activeData, passiveData)

            let decoder = JSONDecoder()
            masterData = try decoder.decode([SMMasterEntry].self, from: smRaw)

            let activeDict = try JSONSerialization.jsonObject(with: activeRaw) as? [String: Any] ?? [:]
            activeScaling = [:]
            for (slug, value) in activeDict {
                if let scalingData = try? JSONSerialization.data(withJSONObject: value),
                   let scaling = try? decoder.decode(SMActiveScaling.self, from: scalingData) {
                    activeScaling[slug] = scaling
                }
            }

            passiveTables = try? decoder.decode(SMPassiveTables.self, from: passiveRaw)

            lastFetchDate = Date()
            currentSource = .remote
            persistCachedSnapshot()
            logger.info("Loaded \(self.masterData.count) SM entries, \(self.activeScaling.count) active scaling sets, passive tables: \(self.passiveTables != nil)")
        } catch let error as ServiceError {
            errorMessage = error.localizedDescription
            logger.error("Master data error: \(error.localizedDescription)")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Master data error: \(error.localizedDescription)")
        }
    }

    /// Look up a master entry by gameId.
    public func entry(for gameId: Int) -> SMMasterEntry? {
        masterData.first { $0.gameId == gameId }
    }

    /// Look up a master entry by slug/id.
    public func entry(for slug: String) -> SMMasterEntry? {
        masterData.first { $0.id == slug }
    }

    /// Get sprite image URL for a manager.
    public func spriteURL(for entry: SMMasterEntry) -> URL? {
        let rarity = entry.rarity.lowercased().capitalized
        let sanitized = entry.sprite.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? entry.sprite
        return URL(string: "https://idle-miners.com/static/sprites/\(rarity)/\(sanitized).webp")
    }

    private func fetchData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceError.networkError
        }

        return data
    }

    enum ServiceError: LocalizedError {
        case invalidURL
        case networkError
        case invalidResponse(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL for master data API"
            case .networkError: return "Network request failed for master data"
            case .invalidResponse(let detail): return "Invalid response: \(detail)"
            }
        }
    }

    private struct CachedMasterSnapshot: Codable {
        var masterData: [SMMasterEntry]
        var activeScaling: [String: SMActiveScaling]
        var passiveTables: SMPassiveTables?
        var cachedAt: Date
    }

    private struct BundledSuperManagers: Codable {
        struct Manager: Codable {
            struct Active: Codable {
                let multiplier: Double?
                let cooldown: String?
                let duration: String?
            }

            let id: String
            let name: String
            let rarity: String
            let type: String
            let active: Active?
        }

        let managers: [Manager]
    }

    private func persistCachedSnapshot() {
        let snapshot = CachedMasterSnapshot(
            masterData: masterData,
            activeScaling: activeScaling,
            passiveTables: passiveTables,
            cachedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func loadCachedSnapshot() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let snapshot = try? JSONDecoder().decode(CachedMasterSnapshot.self, from: data) else {
            return false
        }

        masterData = snapshot.masterData
        activeScaling = snapshot.activeScaling
        passiveTables = snapshot.passiveTables
        lastFetchDate = snapshot.cachedAt
        return !masterData.isEmpty
    }

    private func loadBundledFallback() -> Bool {
        guard let url = Bundle.module.url(forResource: "supermanagers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bundled = try? JSONDecoder().decode(BundledSuperManagers.self, from: data) else {
            return false
        }

        let converted = bundled.managers.enumerated().map { offset, manager in
            SMMasterEntry(
                id: manager.id,
                name: manager.name,
                rarity: manager.rarity.lowercased(),
                area: Self.normalizedArea(from: manager.type),
                gameId: 10_000 + offset,
                sprite: manager.id,
                elements: [],
                passives: [],
                activeL1: manager.active?.multiplier ?? 1,
                activeL100: manager.active?.multiplier ?? 1,
                cooldown: Self.parseDuration(manager.active?.cooldown) ?? 1800,
                duration: Self.parseDuration(manager.active?.duration) ?? 300,
                descriptionLong: nil,
                descriptionShort: nil,
                placeholderIndices: nil,
                legacyGameIds: nil,
                rental: nil,
                maxLevel: nil
            )
        }

        guard !converted.isEmpty else { return false }
        masterData = converted
        activeScaling = [:]
        passiveTables = nil
        lastFetchDate = nil
        return true
    }

    private static func normalizedArea(from type: String) -> String {
        switch type.lowercased() {
        case "mine shaft", "mineshaft":
            return "mineshaft"
        case "elevator":
            return "elevator"
        case "warehouse":
            return "warehouse"
        default:
            return "mineshaft"
        }
    }

    private static func parseDuration(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        let pattern = #"(?:(\d+)m)?\s*(?:(\d+)s)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, range: range) else { return nil }

        var seconds = 0
        if let minuteRange = Range(match.range(at: 1), in: raw),
           let minutes = Int(raw[minuteRange]) {
            seconds += minutes * 60
        }

        if let secondRange = Range(match.range(at: 2), in: raw),
           let sec = Int(raw[secondRange]) {
            seconds += sec
        }

        return seconds > 0 ? seconds : nil
    }
}
