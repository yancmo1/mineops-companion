import Foundation

struct RosterManager: Codable, Identifiable, Equatable, Hashable {
    struct ActiveAbility: Codable, Equatable, Hashable {
        let description: String?
        let multiplier: Double?
        let duration: String?
        let cooldown: String?
    }

    struct PassiveAbility: Codable, Equatable, Hashable {
        let unlockLevel: Int
        let type: String
        let multiplier: Double?
        let description: String?
    }

    let id: String
    let name: String
    let rarity: String
    let type: String
    let active: ActiveAbility?
    let passives: [PassiveAbility]?
}

@MainActor
final class ManagerRoster: ObservableObject {
    static let shared = ManagerRoster()

    @Published private(set) var managers: [RosterManager] = []

    private init() {
        load()
    }

    func load() {
        struct Wrapper: Decodable { let managers: [RosterManager] }

        do {
            let wrapper = try ResourceLoader.decode(Wrapper.self, from: "supermanagers")
            managers = wrapper.managers.sorted { $0.name < $1.name }
        } catch {
            managers = []
            print("⚠️ Unable to load supermanagers.json: \(error)")
        }
    }

    var managerNames: [String] {
        managers.map(\.name)
    }

    func manager(named name: String) -> RosterManager? {
        let target = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return managers.first { candidate in
            candidate.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == target
        }
    }
}
