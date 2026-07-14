import Foundation
import OSLog

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

    private let baseURL = "https://idle-miners.com"
    private let session: URLSession
    private let logger = Logger(subsystem: "com.yancmo1.mineops", category: "MasterData")

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    /// Fetch or refresh all master data from idle-miners.com
    public func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

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
}
