import Foundation
import UIKit

@MainActor
final class AIStrategyEngine: ObservableObject {
    enum StrategyError: LocalizedError {
        case missingAPIKey
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "OPENAI_API_KEY not found in environment variables."
            case .invalidResponse: return "Unable to decode strategy response."
            }
        }
    }

    static let shared = AIStrategyEngine()

    @Published private(set) var lastResult: StrategyResponse?
    @Published private(set) var isLoading = false

    private init() {}

    @discardableResult
    func generateStrategy(
        mineName: String,
        mineLevel: Int,
        shaftLevel: Int,
        selectedManagers: [String],
        screenshots: [UIImage],
        notes: String?
    ) async throws -> StrategyResponse {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            throw StrategyError.missingAPIKey
        }

        isLoading = true
        defer { isLoading = false }

        let prompt = Self.buildPrompt(
            mineName: mineName,
            mineLevel: mineLevel,
            shaftLevel: shaftLevel,
            managers: selectedManagers,
            notes: notes
        )

        let content = Self.buildContent(prompt: prompt, screenshots: screenshots)
        let payload = OpenAIRequest(model: "gpt-5", input: [content], responseFormat: .json)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw StrategyError.invalidResponse
        }

        let strategy = try Self.decodeStrategy(from: data, fallbackManagers: selectedManagers)
        lastResult = strategy
        return strategy
    }

    private static func buildPrompt(
        mineName: String,
        mineLevel: Int,
        shaftLevel: Int,
        managers: [String],
        notes: String?
    ) -> String {
        let roster = managers.joined(separator: ", ")
        let message = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        You are an Idle Miner Tycoon strategist.
        Mine: \(mineName)
        Mine Level: \(mineLevel)
        Shaft Level: \(shaftLevel)
        Available Managers: \(roster.isEmpty ? "None provided" : roster)
        Notes: \(message?.isEmpty == false ? message! : "None")
        Recommend the best combination using the provided data.
        Respond with JSON matching the schema:
        {"comboName": String, "recommendedManagers": [String], "strategySummary": String, "estimatedMultiplier": Double?}
        """
    }

    private static func buildContent(prompt: String, screenshots: [UIImage]) -> OpenAIMessage {
        var parts: [OpenAIContent] = [.text(prompt)]
        for image in screenshots {
            guard let data = image.pngData() else { continue }
            let base64 = data.base64EncodedString()
            parts.append(.imageData(base64))
        }
        return OpenAIMessage(role: "user", content: parts)
    }

    private static func decodeStrategy(from data: Data, fallbackManagers: [String]) throws -> StrategyResponse {
        if let jsonString = extractPrimaryText(from: data) {
            if let jsonData = jsonString.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(StrategyResponse.self, from: jsonData) {
                return decoded
            }
            // Fallback: treat returned text as a narrative summary when JSON decoding fails.
            return StrategyResponse(
                comboName: "AI Strategy",
                recommendedManagers: fallbackManagers,
                strategySummary: jsonString,
                estimatedMultiplier: nil
            )
        }
        throw StrategyError.invalidResponse
    }
}

// MARK: - OpenAI payloads

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

    let output: [Output]?
    let outputText: [String]?
}

private struct OpenAIChoiceResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            struct ContentPart: Decodable {
                let type: String?
                let text: String?
            }

            let content: [ContentPart]
        }

        let message: Message
    }

    let choices: [Choice]?
}

private func extractPrimaryText(from data: Data) -> String? {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    if let response = try? decoder.decode(OpenAIResponse.self, from: data) {
        if let text = response.output?.first?.content.first(where: { $0.text != nil })?.text {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let fallback = response.outputText?.first {
            return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    if let choiceResponse = try? decoder.decode(OpenAIChoiceResponse.self, from: data) {
        if let text = choiceResponse.choices?.first?.message.content.first(where: { $0.text != nil })?.text {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let direct = json["output_text"] as? [String], let text = direct.first {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any] {
            if let content = message["content"] as? [[String: Any]] {
                for item in content {
                    if let text = item["text"] as? String {
                        return text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            if let text = message["content"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if let content = json["content"] as? [[String: Any]] {
            for item in content {
                if let text = item["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
    }

    return nil
}
