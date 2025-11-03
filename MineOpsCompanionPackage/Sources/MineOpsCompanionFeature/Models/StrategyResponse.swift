import Foundation

struct StrategyResponse: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let comboName: String
    let recommendedManagers: [String]
    let strategySummary: String
    let estimatedMultiplier: Double?

    private enum CodingKeys: String, CodingKey {
        case comboName
        case recommendedManagers
        case strategySummary
        case estimatedMultiplier
    }
}
