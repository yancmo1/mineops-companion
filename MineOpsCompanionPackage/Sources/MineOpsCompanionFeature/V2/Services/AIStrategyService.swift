import Foundation
import OSLog

/// Supported AI providers for strategy generation
public enum AIProvider: String, CaseIterable, Codable, Sendable {
    case openAI
    case deepSeek

    public var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .deepSeek: return "DeepSeek"
        }
    }

    public var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .deepSeek: return "deepseek-chat"
        }
    }

    public var endpointURL: URL {
        switch self {
        case .openAI:
            return URL(string: "https://api.openai.com/v1/responses")!
        case .deepSeek:
            return URL(string: "https://api.deepseek.com/v1/chat/completions")!
        }
    }
}

/// Manages AI provider configuration: which provider is active, API keys, model selection
@MainActor
@Observable
public final class AIProviderConfig {
    public static let shared = AIProviderConfig()

    public var activeProvider: AIProvider {
        didSet {
            UserDefaults.standard.set(activeProvider.rawValue, forKey: providerKey)
        }
    }

    public var openAIModel: String {
        didSet {
            UserDefaults.standard.set(openAIModel, forKey: openAIModelKey)
        }
    }

    public var deepSeekModel: String {
        didSet {
            UserDefaults.standard.set(deepSeekModel, forKey: deepSeekModelKey)
        }
    }

    private let providerKey = "com.yancmo1.mineops.aiProvider"
    private let openAIModelKey = "com.yancmo1.mineops.openAIModel"
    private let deepSeekModelKey = "com.yancmo1.mineops.deepSeekModel"

    private init() {
        self.activeProvider = AIProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .openAI
        self.openAIModel = UserDefaults.standard.string(forKey: openAIModelKey) ?? AIProvider.openAI.defaultModel
        self.deepSeekModel = UserDefaults.standard.string(forKey: deepSeekModelKey) ?? AIProvider.deepSeek.defaultModel
    }

    public func resolvedAPIKey(for provider: AIProvider) async -> String? {
        switch provider {
        case .openAI:
            return await OpenAIKeyStore.shared.loadKey()
        case .deepSeek:
            return UserDefaults.standard.string(forKey: "com.yancmo1.mineops.deepSeekKey")
        }
    }

    public func saveDeepSeekKey(_ key: String) {
        UserDefaults.standard.set(key.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "com.yancmo1.mineops.deepSeekKey")
    }

    public func clearDeepSeekKey() {
        UserDefaults.standard.removeObject(forKey: "com.yancmo1.mineops.deepSeekKey")
    }

    public func hasKey(for provider: AIProvider) -> Bool {
        switch provider {
        case .openAI:
            // OpenAIKeyStore is an actor; this is a quick synchronous check.
            // The actor can be safely read from the main actor since all UI lives there.
            return OpenAIKeyStore.shared.loadKey() != nil
        case .deepSeek:
            guard let key = UserDefaults.standard.string(forKey: "com.yancmo1.mineops.deepSeekKey") else { return false }
            return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

// MARK: - Strategy Prompt

public struct AIStrategyPromptInput: Sendable {
    public let availableManagers: [SMProgress]
    public let mineType: String
    public let mineNumber: Int?
    public let mineName: String?
    public let prestige: Int
    public let maxShaft: Int

    public init(
        availableManagers: [SMProgress],
        mineType: String,
        mineNumber: Int?,
        mineName: String?,
        prestige: Int,
        maxShaft: Int
    ) {
        self.availableManagers = availableManagers
        self.mineType = mineType
        self.mineNumber = mineNumber
        self.mineName = mineName
        self.prestige = prestige
        self.maxShaft = maxShaft
    }
}

public struct AIStrategyOutput: Sendable {
    public let comboName: String
    public let recommendedManagerIDs: [String]  // SMProgress.id (slug)
    public let strategySummary: String
    public let estimatedMultiplier: Double?

    public init(comboName: String, recommendedManagerIDs: [String], strategySummary: String, estimatedMultiplier: Double?) {
        self.comboName = comboName
        self.recommendedManagerIDs = recommendedManagerIDs
        self.strategySummary = strategySummary
        self.estimatedMultiplier = estimatedMultiplier
    }
}

// MARK: - AI Provider Protocol

public protocol AIStrategyProvider: Sendable {
    func generateStrategy(input: AIStrategyPromptInput) async throws -> AIStrategyOutput
}

// MARK: - Strategy Service

@MainActor
@Observable
public final class V2StrategyService {
    public static let shared = V2StrategyService()

    public private(set) var isAnalyzing = false
    public private(set) var lastError: String?
    public private(set) var lastOutput: AIStrategyOutput?

    private let config = AIProviderConfig.shared
    private let logger = Logger(subsystem: "com.yancmo1.mineops", category: "V2Strategy")

    private init() {}

    public func generateStrategy(input: AIStrategyPromptInput) async {
        isAnalyzing = true
        lastError = nil
        defer { isAnalyzing = false }

        let provider = config.activeProvider

        guard config.hasKey(for: provider) else {
            lastError = "No API key configured for \(provider.displayName). Add it in Settings."
            return
        }

        guard let apiKey = await config.resolvedAPIKey(for: provider) else {
            lastError = "Could not retrieve API key for \(provider.displayName)."
            return
        }

        do {
            let prompt = buildPrompt(input: input, provider: provider)

            let result = switch provider {
            case .openAI:
                try await callOpenAI(prompt: prompt, apiKey: apiKey)
            case .deepSeek:
                try await callDeepSeek(prompt: prompt, apiKey: apiKey)
            }

            let cleaned = JSONParser.cleanJSONString(result)
            guard let data = cleaned.data(using: .utf8) else {
                lastError = "Failed to encode strategy response."
                return
            }

            let output = try decodeStrategyResponse(from: data, availableManagerIDs: Set(input.availableManagers.map(\.id)))
            lastOutput = output
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - OpenAI

    private func callOpenAI(prompt: String, apiKey: String) async throws -> String {
        let model = config.openAIModel
        let payload = ResponsesPayloadBuilder.strategy(model: model, prompt: prompt)
        let requestData = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: AIProvider.openAI.endpointURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AIError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // Parse /v1/responses format
        if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let output = root["output"] as? [[String: Any]],
           let content = output.first?["content"] as? [[String: Any]],
           let text = content.first?["text"] as? String {
            return text
        }

        throw AIError.unexpectedResponse
    }

    // MARK: - DeepSeek

    private func callDeepSeek(prompt: String, apiKey: String) async throws -> String {
        let model = config.deepSeekModel
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 2000,
            "temperature": 0.3
        ]
        let requestData = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: AIProvider.deepSeek.endpointURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AIError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // Parse chat completions format
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw AIError.unexpectedResponse
        }

        return text
    }

    // MARK: - Prompt Builder

    private func buildPrompt(input: AIStrategyPromptInput, provider: AIProvider) -> String {
        var lines: [String] = []
        lines.append("You are a strategy advisor for Idle Miner Tycoon.")
        lines.append("Design a burst rotation for the following mine using ONLY the managers listed below.")
        lines.append("")

        // Mine context
        var context = "Mine: \(input.mineType)"
        if let number = input.mineNumber { context += " #\(number)" }
        if let name = input.mineName { context += " (\(name))" }
        lines.append(context)
        lines.append("Prestige: \(input.prestige)")
        lines.append("Max Shaft Level: \(input.maxShaft)")
        lines.append("")

        // Manager roster
        lines.append("Available Managers:")
        for sm in input.availableManagers where sm.unlocked {
            let elements = sm.sortedElements.prefix(3).map { "\($0.element.capitalized)(\($0.effectiveness))" }.joined(separator: ", ")
            let passives = sm.availablePassives.map { "\($0.typeDisplayName)" }.joined(separator: ", ")
            let activeValue = sm.effectiveActiveValue(using: SMMasterDataService.shared.activeScaling)
            lines.append("- \(sm.master.name) [\(sm.master.rarity.capitalized) \(sm.areaEnum.displayName)] Lv\(sm.level) P\(sm.promoted) Rank\(sm.rank)")
            lines.append("  Active: \(String(format: "%.1f", activeValue))x  Cooldown: \(sm.master.cooldown)s  Duration: \(sm.master.duration)s")
            if !elements.isEmpty { lines.append("  Elements: \(elements)") }
            if !passives.isEmpty { lines.append("  Passives: \(passives)") }
        }
        lines.append("")

        // Response format
        lines.append("Respond in JSON format without markdown:")
        lines.append("""
        {
          "comboName": "Short combo name",
          "recommendedManagerIDs": ["manager-slug-1", "manager-slug-2"],
          "strategySummary": "Brief strategy explanation",
          "estimatedMultiplier": 1.0
        }
        """)

        return lines.joined(separator: "\n")
    }

    // MARK: - Response Decoding

    private func decodeStrategyResponse(from data: Data, availableManagerIDs: Set<String>) throws -> AIStrategyOutput {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.invalidResponse
        }

        let comboName = dict["comboName"] as? String ?? "AI Strategy"
        let summary = dict["strategySummary"] as? String ?? ""
        let multiplier = dict["estimatedMultiplier"] as? Double

        let rawIDs: [String]
        if let ids = dict["recommendedManagerIDs"] as? [String] {
            rawIDs = ids
        } else if let ids = dict["recommendedManagers"] as? [String] {
            rawIDs = ids
        } else {
            rawIDs = []
        }

        // Filter to only known managers
        let validIDs = rawIDs.filter { availableManagerIDs.contains($0) }
            .prefix(8).map { $0 }

        return AIStrategyOutput(
            comboName: comboName,
            recommendedManagerIDs: Array(validIDs),
            strategySummary: summary,
            estimatedMultiplier: multiplier
        )
    }

    enum AIError: LocalizedError {
        case apiError(statusCode: Int)
        case unexpectedResponse
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .apiError(let code): return "API returned HTTP \(code)"
            case .unexpectedResponse: return "Unexpected API response format"
            case .invalidResponse: return "Could not parse strategy from response"
            }
        }
    }
}

// MARK: - JSON Cleaner

enum JSONParser {
    /// Strip markdown code fences and trim whitespace for JSON parsing
    static func cleanJSONString(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove ```json ... ``` fences
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Remove leading/trailing non-JSON if needed
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        return cleaned
    }
}
