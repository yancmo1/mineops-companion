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
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
