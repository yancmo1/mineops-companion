import CoreData
import CryptoKit
import Foundation
import OSLog
import SwiftUI
import UIKit

@MainActor
final class AIStrategyPipeline: ObservableObject {
    static let shared = AIStrategyPipeline()

    @Published private(set) var isAnalyzing = false
    @Published private(set) var lastStrategy: StrategyResponse?
    @Published private(set) var detectedManagers: [String] = []
    @Published private(set) var lastError: String?

    private let context: NSManagedObjectContext
    private let visionModelName = "gpt-4o-mini"

    private init() {
        context = CoreDataManager.shared.container.viewContext
    }

    func runFullPipeline(
        mineContext: MineContext,
        screenshots: [UIImage],
        notes: String?,
        selectedRoster: [RecognizedSM]
    ) async {
        isAnalyzing = true
        lastError = nil
        defer { isAnalyzing = false }

        if let cached = fetchCachedStrategy(cacheKey: mineContext.cacheKey) {
            detectedManagers = cached.detectedManagers ?? []

            if
                let raw = cached.strategyJSON?.data(using: .utf8),
                let decoded = try? JSONDecoder().decode(StrategyResponse.self, from: raw)
            {
                lastStrategy = decoded
                return
            }

            // Cached entry exists but is missing or has invalid JSON; purge and continue.
            context.delete(cached)
            CoreDataManager.shared.saveContext()
        }

        let selected = selectedRoster
        if selected.isEmpty {
            let names = await detectManagers(from: screenshots)
            detectedManagers = names
        } else {
            detectedManagers = selected.map { $0.resolvedName }.sorted()
        }

        guard !detectedManagers.isEmpty else {
            lastError = "Select at least one manager before generating a strategy."
            return
        }

        do {
            let managerRoster: [StrategyRosterExportEntry]
            if !selected.isEmpty {
                managerRoster = selected
                    .map(StrategyRosterExportEntry.init(from:))
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            } else {
                // Fallback: we only have names from vision detection.
                let directory = (try? SMDirectory.load()) ?? []
                managerRoster = detectedManagers.map { name in
                    let lowercaseName = name.lowercased()
                    if let entry = directory.first(where: { entry in
                        entry.name.lowercased() == lowercaseName ||
                        (entry.aliases?.contains(where: { $0.lowercased() == lowercaseName }) ?? false)
                    }) {
                        // Create a minimal entry (no stats).
                        let stub = RecognizedSM(
                            sourceImage: UIImage(),
                            rawText: "",
                            level: nil,
                            directoryMatch: entry,
                            resolvedName: entry.name,
                            stats: SMStats()
                        )
                        return StrategyRosterExportEntry(from: stub)
                    } else {
                        Logger.strategy.warning("Unknown manager '\(name, privacy: .public)' - marking department as unknown")
                        let stub = RecognizedSM(
                            sourceImage: UIImage(),
                            rawText: "",
                            level: nil,
                            directoryMatch: nil,
                            resolvedName: name,
                            stats: SMStats()
                        )
                        return StrategyRosterExportEntry(from: stub)
                    }
                }
            }
            
            let promptModel = StrategyPrompt(
                mineContext: mineContext,
                managerRoster: managerRoster,
                goal: notes ?? "Optimize production for \(mineContext.promptDescription)"
            )

            let rawStrategy = try await AIStrategyEngine.shared.fetchStrategy(prompt: promptModel.text)
            
            // Validate and sanitize the AI response against available managers
            let availableNames = Set(managerRoster.map { $0.name })
            let strategy = rawStrategy.validated(against: availableNames)
            
            storeStrategy(
                cacheKey: mineContext.cacheKey,
                mineContext: mineContext,
                managers: strategy.recommendedManagers,
                strategy: strategy
            )
            lastStrategy = strategy
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearAllCaches() {
        ["CachedStrategy"].forEach { entityName in
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetch)
            _ = try? context.execute(deleteRequest)
        }
        CoreDataManager.shared.saveContext()
        detectedManagers = []
        lastStrategy = nil
        Task { await ManagerDetectionCache.shared.clear() }
    }

    // MARK: - Detection

    private func detectManagers(from screenshots: [UIImage]) async -> [String] {
        var names: [String] = []

        for image in screenshots {
            guard let data = image.pngData() else { continue }
            let hash = Self.hash(data)
            if let name = await ManagerDetectionCache.shared.loadName(for: hash) {
                names.append(name)
                continue
            }

            if let name = try? await requestDetection(for: data) {
                names.append(name)
                await ManagerDetectionCache.shared.storeName(name, for: hash)
            }
        }

        return Array(Set(names)).sorted()
    }

    private func requestDetection(for imageData: Data) async throws -> String? {
        guard let apiKey = await OpenAIKeyStore.shared.resolvedAPIKey(), !apiKey.isEmpty else {
            throw AIStrategyEngine.StrategyError.missingAPIKey
        }

        let base64 = imageData.base64EncodedString()
        let prompt = "Identify the Idle Miner Tycoon manager shown."
        let payload = ResponsesPayloadBuilder.managerDetection(
            model: visionModelName,
            prompt: prompt,
            base64Image: base64
        )

        let data = try await performResponsesRequest(payload: payload, apiKey: apiKey)

        struct ResponsesAPIResponse: Decodable {
            struct Output: Decodable {
                struct Content: Decodable { let text: String? }
                let content: [Content]
            }
            let output: [Output]
        }

        guard let responsesAPI = try? JSONDecoder().decode(ResponsesAPIResponse.self, from: data),
              let jsonText = responsesAPI.output.first?.content.first?.text,
              let jsonData = jsonText.data(using: .utf8) else { return nil }

        struct Simple: Decodable { let manager: String }
        return try? JSONDecoder().decode(Simple.self, from: jsonData).manager
    }

    private func performResponsesRequest(payload: [String: Any], apiKey: String) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIStrategyEngine.StrategyError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let message = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data).error.message {
                throw AIStrategyEngine.StrategyError.apiError(message)
            }
            throw AIStrategyEngine.StrategyError.invalidResponse
        }

        return data
    }

    // MARK: - Core Data helpers

    private func fetchCachedStrategy(cacheKey: String) -> CachedStrategyEntity? {
        let request = NSFetchRequest<CachedStrategyEntity>(entityName: "CachedStrategy")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "cacheKey == %@", cacheKey)
        return try? context.fetch(request).first
    }

    private func storeStrategy(
        cacheKey: String,
        mineContext: MineContext,
        managers: [String],
        strategy: StrategyResponse
    ) {
        let entity = CachedStrategyEntity(context: context)
        entity.cacheKey = cacheKey
        entity.mineName = mineContext.displayName
        entity.mineLevel = Int64(mineContext.prestige)
        entity.shaftLevel = Int64(mineContext.maxShaft)
        entity.detectedManagers = managers
        entity.comboName = strategy.comboName
        entity.detailedPlan = strategy.detailedPlan
        if let data = try? JSONEncoder().encode(strategy) {
            entity.strategyJSON = String(data: data, encoding: .utf8)
        } else {
            entity.strategyJSON = nil
        }
        entity.timestamp = Date()
        CoreDataManager.shared.saveContext()
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
