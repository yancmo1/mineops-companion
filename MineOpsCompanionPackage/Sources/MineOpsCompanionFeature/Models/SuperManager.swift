import Foundation

struct SuperManager: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var role: String
    var baseBoost: Double
    var maxBoost: Double
    var boostType: String
    var cost: Int?
    var imageName: String?
    var availability: String?
    var synergy: [String]?

    private enum CodingKeys: String, CodingKey {
        case name
        case role
        case baseBoost
        case maxBoost
        case boostType
        case cost
        case imageName
        case availability
        case synergy
    }
}
