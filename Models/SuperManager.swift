import Foundation

struct SuperManager: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var role: String
    var baseBoost: Double
    var maxBoost: Double
    var boostType: String
    var cost: Int?
    var imageName: String?
}
