@testable import MineOpsCompanionFeature
import Foundation
import Testing

@Suite
struct AIStrategyResourcesTests {
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
