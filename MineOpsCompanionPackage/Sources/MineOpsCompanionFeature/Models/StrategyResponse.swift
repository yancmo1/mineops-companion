import Foundation

struct StrategyResponse: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let comboName: String
    let recommendedManagers: [String]
    let strategySummary: String
    let estimatedMultiplier: Double?
    let detailedPlan: String?

    private enum CodingKeys: String, CodingKey {
        case comboName
        case recommendedManagers
        case strategySummary
        case estimatedMultiplier
        case detailedPlan
    }

    init(
        comboName: String,
        recommendedManagers: [String],
        strategySummary: String,
        estimatedMultiplier: Double?,
        detailedPlan: String? = nil
    ) {
        self.comboName = comboName
        self.recommendedManagers = recommendedManagers
        self.strategySummary = strategySummary
        self.estimatedMultiplier = estimatedMultiplier
        self.detailedPlan = detailedPlan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode comboName – trim and default only if present but empty
        let rawCombo = try container.decode(String.self, forKey: .comboName)
        comboName = rawCombo.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "AI Strategy"

        // Decode recommendedManagers – array or single string
        if let managerArray = try? container.decode([String].self, forKey: .recommendedManagers) {
            recommendedManagers = managerArray.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } else if let singleManager = try? container.decode(String.self, forKey: .recommendedManagers) {
            let cleaned = singleManager.trimmingCharacters(in: .whitespacesAndNewlines)
            recommendedManagers = cleaned.isEmpty ? [] : [cleaned]
        } else {
            recommendedManagers = []
        }

        // Decode strategySummary – trim and default only if present but empty
        let rawSummary = try container.decode(String.self, forKey: .strategySummary)
        strategySummary = rawSummary.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "No summary provided."

        // Decode estimatedMultiplier – try number or string-encoded number
        if let numeric = try? container.decode(Double.self, forKey: .estimatedMultiplier) {
            estimatedMultiplier = numeric
        } else if let stringValue = try? container.decode(String.self, forKey: .estimatedMultiplier),
                  let numeric = Double(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            estimatedMultiplier = numeric
        } else {
            estimatedMultiplier = nil
        }

        detailedPlan = (try? container.decode(String.self, forKey: .detailedPlan))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(comboName, forKey: .comboName)
        try container.encode(recommendedManagers, forKey: .recommendedManagers)
        try container.encode(strategySummary, forKey: .strategySummary)
        try container.encodeIfPresent(estimatedMultiplier, forKey: .estimatedMultiplier)
        try container.encodeIfPresent(detailedPlan, forKey: .detailedPlan)
    }
    
    /// Validates and sanitizes the strategy against the available manager roster.
    /// - Parameter availableManagers: Set of manager names that were passed to the AI
    /// - Returns: A validated copy with trimmed/filtered recommendedManagers
    func validated(against availableManagers: Set<String>) -> StrategyResponse {
        let availableLowercased = Set(availableManagers.map { $0.lowercased() })
        
        // Filter to only managers that were in the available list
        let validManagers = recommendedManagers.filter { manager in
            availableLowercased.contains(manager.lowercased())
        }
        
        let trimmedCount = recommendedManagers.count - validManagers.count
        if trimmedCount > 0 {
            print("⚠️ Trimmed \(trimmedCount) unknown manager(s) from AI recommendation")
        }
        
        // Cap at 8 managers max
        var finalManagers = validManagers
        if finalManagers.count > 8 {
            print("⚠️ AI recommended \(finalManagers.count) managers, capping at 8")
            finalManagers = Array(finalManagers.prefix(8))
        }
        
        // Check for department duplicates (log warning only)
        // This is informational since we don't have department info here
        if finalManagers.count > 7 {
            print("⚠️ Large manager count (\(finalManagers.count)) - verify no department duplicates")
        }
        
        return StrategyResponse(
            comboName: comboName,
            recommendedManagers: finalManagers,
            strategySummary: strategySummary,
            estimatedMultiplier: estimatedMultiplier,
            detailedPlan: detailedPlan
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
