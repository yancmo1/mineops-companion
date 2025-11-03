@testable import MineOpsCompanionFeature
import Foundation
import Testing

@Suite
struct AIStrategyResourcesTests {
    @Test("supermanagers.json decodes and sorts by name")
    func rosterDecodes() throws {
        let wrapper = try ResourceLoader.decode(RosterWrapper.self, from: "supermanagers")
        #expect(wrapper.managers.count >= 3)
        let names = wrapper.managers.map(\.name)
        #expect(names == names.sorted())
    }

    @Test("StrategyResponse decodes from sample JSON")
    func strategyResponseDecodes() throws {
        let json = """
        {
            "comboName": "Tunnel Blitz",
            "recommendedManagers": ["Mr. Edmund", "Dr. Lilly"],
            "strategySummary": "Fire Lilly, funnel with Edmund, then rotate Turner.",
            "estimatedMultiplier": 6.5
        }
        """
        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(StrategyResponse.self, from: data)
        #expect(response.comboName == "Tunnel Blitz")
        #expect(response.recommendedManagers == ["Mr. Edmund", "Dr. Lilly"])
        #expect(response.estimatedMultiplier == 6.5)
    }
}

private struct RosterWrapper: Decodable {
    let managers: [RosterManager]
}
