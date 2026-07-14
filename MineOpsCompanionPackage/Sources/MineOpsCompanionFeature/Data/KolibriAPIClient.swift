// # File: Sources/MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/Data/KolibriAPIClient.swift

import Foundation
import OSLog
import zlib

/// Actor responsible for communicating with Kolibri Game Services API
@MainActor
public final class KolibriAPIClient: Sendable {
    
    // MARK: - Errors
    
    public enum APIError: LocalizedError {
        case missingKolibriId
        case missingAuthToken
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int, message: String)
        case payloadFormat(String)
        case payloadDecode(String)
        case jsonParse(String)
        case decodingError(Error)
        case networkError(Error)
        
        public var errorDescription: String? {
            switch self {
            case .missingKolibriId:
                return "Kolibri ID is missing. Configure it in Settings."
            case .missingAuthToken:
                return "Authorization token is missing. Configure it in Settings."
            case .invalidURL:
                return "Failed to construct API URL."
            case .invalidResponse:
                return "Server returned an invalid response."
            case .httpError(let statusCode, let message):
                return "HTTP \(statusCode): \(message)"
            case .payloadFormat(let details):
                return "Unexpected save payload format: \(details)"
            case .payloadDecode(let details):
                return "Failed to decode save payload: \(details)"
            case .jsonParse(let details):
                return "Failed to parse decoded save JSON: \(details)"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Configuration
    
    private let baseURL = "https://capsule.kolibrigames.com/api/client/v1"
    private let gameId = "com.fluffyfairygames.idleminertycoon"
    private let session: URLSession
    
    private let logger = Logger(subsystem: "com.yancmo1.mineops", category: "KolibriAPI")
    
    // MARK: - Initialization
    
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - API Methods
    
    /// Fetch savegame data for a specific player
    /// - Parameters:
    ///   - kolibriId: The player's Kolibri ID
    ///   - authToken: Authorization token for authentication
    ///   - saveGameKey: The save game slot key (default: "0")
    /// - Returns: The decoded savegame response with diagnostics
    public func fetchSavegame(
        kolibriId: String,
        authToken: String,
        saveGameKey: String = "0"
    ) async throws -> KolibriFetchResult {
        
        // Validate inputs
        guard !kolibriId.isEmpty else {
            throw APIError.missingKolibriId
        }
        
        guard !authToken.isEmpty else {
            throw APIError.missingAuthToken
        }
        
        let candidatePlayerIDs = Self.candidatePlayerIDs(from: kolibriId)
        var lastAPIError: APIError?

        for (index, playerID) in candidatePlayerIDs.enumerated() {
            logger.info("Fetching savegame for player candidate \(index + 1, privacy: .public)/\(candidatePlayerIDs.count, privacy: .public): \(playerID, privacy: .public)")

            do {
                guard let requestURL = Self.buildSavegameURL(baseURL: baseURL, gameId: gameId, playerID: playerID, saveGameKey: saveGameKey) else {
                    throw APIError.invalidURL
                }

                var request = URLRequest(url: requestURL)
                request.httpMethod = "GET"
                request.setValue(authToken, forHTTPHeaderField: "Authorization")
                request.setValue("IdleMiner/96354", forHTTPHeaderField: "User-Agent")
                request.setValue("2022.3.62f2", forHTTPHeaderField: "X-Unity-Version")
                request.setValue("*/*", forHTTPHeaderField: "Accept")

                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                logger.debug("Response status: \(httpResponse.statusCode, privacy: .public)")

                guard (200..<300).contains(httpResponse.statusCode) else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    let apiError = APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)

                    if httpResponse.statusCode == 404, index < candidatePlayerIDs.count - 1 {
                        logger.warning("Player candidate \(playerID, privacy: .public) returned 404, trying next candidate")
                        continue
                    }

                    throw apiError
                }

                let prefixHex = Self.hexPrefix(for: data)
                let (decodedJSON, payloadFormat) = try decodeSavePayload(data)
                let savegame = try parseSavegame(from: decodedJSON)
                let managerCount = savegame.saveGameData?.managers?.count ?? 0

                let diagnostics = KolibriSyncDiagnostics(
                    statusCode: httpResponse.statusCode,
                    payloadFormat: payloadFormat,
                    rawPayloadBytes: data.count,
                    decodedPayloadBytes: decodedJSON.count,
                    managerCount: managerCount,
                    payloadPrefixHex: prefixHex
                )

                logger.info("Successfully fetched savegame data (managers: \(managerCount, privacy: .public))")
                return KolibriFetchResult(savegame: savegame, diagnostics: diagnostics)
            } catch let error as APIError {
                lastAPIError = error
                if case .httpError(let statusCode, _) = error, statusCode == 404, index < candidatePlayerIDs.count - 1 {
                    continue
                }
                throw error
            } catch {
                logger.error("Network error: \(error.localizedDescription)")
                throw APIError.networkError(error)
            }
        }

        if let lastAPIError {
            throw lastAPIError
        }

        throw APIError.httpError(statusCode: 404, message: "No valid player ID candidate matched the Capsule endpoint")
    }

    /// Lookup table used to map in-save game IDs to tracker IDs / known manager slugs.
    public func fetchManagerIDLookup() async -> [String: String] {
        guard let url = URL(string: "https://idle-miners.com/api/sm-data") else {
            return [:]
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return [:]
            }

            guard let entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return [:]
            }

            var lookup: [String: String] = [:]
            lookup.reserveCapacity(entries.count)

            for entry in entries {
                guard let trackerID = entry["id"] as? String else { continue }

                if let gameID = entry["gameId"] as? Int {
                    lookup[String(gameID)] = trackerID
                } else if let gameIDString = entry["gameId"] as? String {
                    lookup[gameIDString] = trackerID
                }
            }

            return lookup
        } catch {
            logger.warning("Failed to fetch manager ID lookup: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    // MARK: - Payload Decoding

    private func decodeSavePayload(_ payload: Data) throws -> (json: Data, format: String) {
        if payload.starts(with: [0x7B]) {
            return (payload, "json")
        }

        guard payload.count >= 4 else {
            throw APIError.payloadFormat("Payload too short (\(payload.count) bytes)")
        }

        let header = String(data: payload.prefix(4), encoding: .utf8) ?? "<non-text>"

        if header == "U58U" {
            let base64Payload = Data(payload.dropFirst(4))
            guard let decoded = Data(base64Encoded: base64Payload) else {
                throw APIError.payloadDecode("Base64 decode failed after U58U header")
            }

            guard let gzipPayload = Self.extractGzipPayload(from: decoded) else {
                throw APIError.payloadFormat("U58U payload decoded, but gzip header not found")
            }

            let jsonData = try Self.gunzip(gzipPayload)
            return (jsonData, "u58u-base64-gzip")
        }

        // Newer/alternate format observed in production: entire response is base64,
        // and decoded bytes may contain a short binary envelope before gzip (e.g. QJ8U...)
        if let decoded = Data(base64Encoded: payload) {
            if let gzipPayload = Self.extractGzipPayload(from: decoded) {
                let jsonData = try Self.gunzip(gzipPayload)
                return (jsonData, "base64-prefixed-gzip")
            }

            if decoded.starts(with: [0x7B]) {
                return (decoded, "base64-json")
            }
        }

        throw APIError.payloadFormat("Unknown header \(header) with hex prefix \(Self.hexPrefix(for: payload))")
    }

    private func parseSavegame(from jsonData: Data) throws -> KolibriSavegameResponse {
        guard let root = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw APIError.jsonParse("Root object is not a dictionary")
        }

        let dataNode = (root["Data"] as? [String: Any]) ?? root
        let superManagersNode = dataNode["SuperManagers"] as? [String: Any]
        let managersNode = superManagersNode?["Managers"] as? [[String: Any]] ?? []

        let managers: [ManagerData] = managersNode.compactMap { row in
            guard let idValue = row["Id"] else { return nil }
            let id = String(describing: idValue)

            let level = row["Level"] as? Int
            let promotion = row["Promotion"] as? Int
            let rank = row["Rank"] as? Int
            let area = row["Area"].map { String(describing: $0) }

            return ManagerData(
                id: id,
                name: nil,
                rarity: nil,
                rank: rank,
                level: level,
                promotion: promotion,
                assignedTo: area,
                fragments: nil,
                abilities: nil
            )
        }

        let saveData = SaveGameData(
            version: root["Version"] as? String,
            managers: managers
        )

        return KolibriSavegameResponse(saveGameData: saveData, timestamp: Date())
    }

    private static func hexPrefix(for data: Data, length: Int = 12) -> String {
        data.prefix(length).map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private static func gunzip(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }

        var stream = z_stream()
        var input = [UInt8](data)
        var output = Data()

        let chunkSize = 64 * 1024
        var chunk = [UInt8](repeating: 0, count: chunkSize)

        let initStatus = inflateInit2_(&stream, 47, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else {
            throw APIError.payloadDecode("inflateInit2 failed with status \(initStatus)")
        }

        defer {
            inflateEnd(&stream)
        }

        let inflateStatus: Int32 = input.withUnsafeMutableBufferPointer { inputBuffer in
            guard let inputBase = inputBuffer.baseAddress else {
                return Z_DATA_ERROR
            }

            stream.next_in = inputBase
            stream.avail_in = uInt(inputBuffer.count)

            var status: Int32 = Z_OK

            repeat {
                chunk.withUnsafeMutableBufferPointer { chunkBuffer in
                    stream.next_out = chunkBuffer.baseAddress
                    stream.avail_out = uInt(chunkBuffer.count)
                    status = inflate(&stream, Z_NO_FLUSH)
                }

                let produced = chunkSize - Int(stream.avail_out)
                if produced > 0 {
                    output.append(chunk, count: produced)
                }
            } while status == Z_OK

            return status
        }

        guard inflateStatus == Z_STREAM_END else {
            throw APIError.payloadDecode("inflate failed with status \(inflateStatus)")
        }

        return output
    }

    private static func buildSavegameURL(baseURL: String, gameId: String, playerID: String, saveGameKey: String) -> URL? {
        let encodedPlayerID = playerID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? playerID
        let encodedSaveGameKey = saveGameKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? saveGameKey
        let urlString = "\(baseURL)/games/\(gameId)/players/\(encodedPlayerID)/savegame?saveGameKey=\(encodedSaveGameKey)"
        return URL(string: urlString)
    }

    private static func extractGzipPayload(from decoded: Data) -> Data? {
        if decoded.starts(with: [0x1F, 0x8B]) {
            return decoded
        }

        if let gzipIndex = decoded.range(of: Data([0x1F, 0x8B]))?.lowerBound {
            return decoded.subdata(in: gzipIndex..<decoded.count)
        }

        return nil
    }

    private static func candidatePlayerIDs(from rawValue: String) -> [String] {
        let cleaned = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        var candidates: [String] = []

        // 1) Original input first.
        candidates.append(cleaned)

        // 2) Whitespace-separated tokens.
        let tokens = cleaned
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .map(String.init)
        candidates.append(contentsOf: tokens)

        // 3) UUID-like tokens are most likely valid Capsule player IDs.
        let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        if let regex = try? NSRegularExpression(pattern: uuidPattern) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            let matches = regex.matches(in: cleaned, range: range)
            for match in matches {
                if let matchRange = Range(match.range, in: cleaned) {
                    candidates.append(String(cleaned[matchRange]))
                }
            }
        }

        // Deduplicate while preserving order.
        var seen = Set<String>()
        return candidates.filter { candidate in
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            let normalized = trimmed.lowercased()
            if seen.contains(normalized) { return false }
            seen.insert(normalized)
            return true
        }
    }
}
