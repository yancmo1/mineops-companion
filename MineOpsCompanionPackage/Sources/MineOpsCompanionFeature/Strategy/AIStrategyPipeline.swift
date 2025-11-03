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
    private let visionModelName = "gpt-5-vision-preview"

    private init() {
        context = CoreDataManager.shared.container.viewContext
    }

    func runFullPipeline(
        mineName: String,
        mineLevel: Int,
        shaftLevel: Int,
        screenshots: [UIImage],
        notes: String?,
        selectedManagers: [String]
    ) async {
        isAnalyzing = true
        lastError = nil
        defer { isAnalyzing = false }

        if let cached = fetchCachedStrategy(mineName: mineName, mineLevel: mineLevel, shaftLevel: shaftLevel) {
            detectedManagers = cached.detectedManagers ?? []
            if let raw = cached.strategyJSON?.data(using: .utf8) {
                lastStrategy = try? JSONDecoder().decode(StrategyResponse.self, from: raw)
            }
            return
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
            let strategy = try await AIStrategyEngine.shared.generateStrategy(
                mineName: mineName,
                mineLevel: mineLevel,
                shaftLevel: shaftLevel,
                selectedManagers: roster,
                screenshots: screenshots,
                notes: notes
            )
            storeStrategy(
                mineName: mineName,
                mineLevel: mineLevel,
                shaftLevel: shaftLevel,
                managers: detectedManagers,
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
        let message = OpenAIMessage(role: "user", content: [
            .text("Identify the Idle Miner Tycoon manager shown. Respond as JSON: {\"manager\": \"<name>\"}"),
            .imageData(base64)
        ])
        let payload = OpenAIRequest(model: visionModelName, input: [message], responseFormat: .json)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AIStrategyEngine.StrategyError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let openAI = try decoder.decode(OpenAIResponse.self, from: data)
        guard let raw = openAI.output.first?.content.first?.text,
              let jsonData = raw.data(using: .utf8) else {
            return nil
        }
        struct Simple: Decodable { let manager: String }
        return try? JSONDecoder().decode(Simple.self, from: jsonData).manager
    }

    // MARK: - Core Data helpers

    private func fetchCachedStrategy(mineName: String, mineLevel: Int, shaftLevel: Int) -> CachedStrategyEntity? {
        let request = NSFetchRequest<CachedStrategyEntity>(entityName: "CachedStrategy")
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "mineName ==[c] %@ AND mineLevel == %d AND shaftLevel == %d",
            mineName,
            mineLevel,
            shaftLevel
        )
        return try? context.fetch(request).first
    }

    private func storeStrategy(
        mineName: String,
        mineLevel: Int,
        shaftLevel: Int,
        managers: [String],
        strategy: StrategyResponse
    ) {
        let entity = CachedStrategyEntity(context: context)
        entity.mineName = mineName
        entity.mineLevel = Int64(mineLevel)
        entity.shaftLevel = Int64(shaftLevel)
        entity.detectedManagers = managers
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

// MARK: - Shared OpenAI models

private struct OpenAIRequest: Encodable {
    enum ResponseFormat: String, Encodable {
        case json
    }

    let model: String
    let input: [OpenAIMessage]
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case responseFormat = "response_format"
    }
}

private struct OpenAIMessage: Encodable {
    let role: String
    let content: [OpenAIContent]
}

private enum OpenAIContent: Encodable {
    case text(String)
    case imageData(String)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageData = "image_data"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode("input_text", forKey: .type)
            try container.encode(value, forKey: .text)
        case .imageData(let value):
            try container.encode("input_image", forKey: .type)
            try container.encode(value, forKey: .imageData)
        }
    }
}

private struct OpenAIResponse: Decodable {
    struct Output: Decodable {
        struct ContentPart: Decodable {
            let type: String
            let text: String?
        }

        let content: [ContentPart]
    }

    let output: [Output]
}
