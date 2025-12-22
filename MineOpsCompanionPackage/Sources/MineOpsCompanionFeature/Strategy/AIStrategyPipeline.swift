import CoreData
import CryptoKit
import Foundation
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
        selectedManagers: [String]
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

        var roster = selectedManagers
        if roster.isEmpty {
            let names = await detectManagers(from: screenshots)
            roster = names
        } else {
            roster = selectedManagers
        }

        roster = Array(Set(roster)).sorted()
        detectedManagers = roster

        guard !roster.isEmpty else {
            lastError = "Select at least one manager before generating a strategy."
            return
        }

        do {
            let directory = (try? SMDirectory.load()) ?? []
            let managerRoster = roster.map { name -> ManagerRosterEntry in
                // Try to find department from directory by name or alias
                let lowercaseName = name.lowercased()
                if let entry = directory.first(where: { entry in
                    entry.name.lowercased() == lowercaseName || 
                    (entry.aliases?.contains(where: { $0.lowercased() == lowercaseName }) ?? false)
                }) {
                    return ManagerRosterEntry(name: entry.name, department: entry.department.capitalized)
                } else {
                    // Unknown manager - mark as unknown so AI doesn't make wrong assumptions
                    print("⚠️ Unknown manager '\(name)' - marking department as unknown")
                    return ManagerRosterEntry(name: name, department: "Unknown")
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
        ["CachedStrategy", "CachedDetection"].forEach { entityName in
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetch)
            _ = try? context.execute(deleteRequest)
        }
        CoreDataManager.shared.saveContext()
        detectedManagers = []
        lastStrategy = nil
        Task {
            await AIStrategyEngine.shared.clearCache()
        }
    }

    // MARK: - Detection

    private func detectManagers(from screenshots: [UIImage]) async -> [String] {
        var names: [String] = []

        for image in screenshots {
            guard let data = image.pngData() else { continue }
            let hash = Self.hash(data)
            if let cached = fetchDetection(hash: hash), let name = cached.managerName {
                names.append(name)
                continue
            }

            if let name = try? await requestDetection(for: data) {
                names.append(name)
                storeDetection(hash: hash, name: name)
            }
        }

        return Array(Set(names)).sorted()
    }

    private func requestDetection(for imageData: Data) async throws -> String? {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
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

    private func fetchDetection(hash: String) -> CachedDetectionEntity? {
        let request = NSFetchRequest<CachedDetectionEntity>(entityName: "CachedDetection")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "imageHash == %@", hash)
        return try? context.fetch(request).first
    }

    private func storeDetection(hash: String, name: String) {
        let entity = CachedDetectionEntity(context: context)
        entity.imageHash = hash
        entity.managerName = name
        entity.timestamp = Date()
        CoreDataManager.shared.saveContext()
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
