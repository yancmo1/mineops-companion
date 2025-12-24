import Testing
import UIKit
@testable import MineOpsCompanionFeature

private func makeDirectoryEntryWithElements() throws -> SMDirectoryEntry {
    let json = """
    {
      "id": "blingsley",
      "name": "Blingsley",
      "department": "mineshaft",
      "rarity": "epic",
      "elements": ["Nature", "Water"],
      "active": {
        "name": "Boost",
        "type": "boost",
        "durationSeconds": 300,
        "cooldownSeconds": 900,
        "multiplier": 2.5,
        "description": ""
      }
    }
    """
    let data = try #require(json.data(using: .utf8))
    return try JSONDecoder().decode(SMDirectoryEntry.self, from: data)
}

@Test("StrategyPrompt includes roster numeric details and elements")
func strategyPromptIncludesRosterDetails() throws {
    let entry = try makeDirectoryEntryWithElements()

    let sm = RecognizedSM(
        sourceImage: UIImage(),
        rawText: "",
        level: 10,
        directoryMatch: entry,
        resolvedName: "Blingsley",
        stats: SMStats(level: .init(current: 10, total: 20), promotion: .init(current: 2, total: 5))
    )

    let roster = [StrategyRosterExportEntry(from: sm)]

    let prompt = StrategyPrompt(
        mineContext: MineContext(type: .mainland, mainlandMineNumber: 1, continentMine: nil, prestige: 5, maxShaft: 30),
        managerRoster: roster,
        goal: "Test"
    )

    #expect(prompt.text.contains("Roster Details"))
    #expect(prompt.text.contains("Level: 10/20"))
    #expect(prompt.text.contains("Promotion: 2/5"))
    #expect(prompt.text.contains("ActiveMult: 2.50x"))
    #expect(prompt.text.contains("Elements: Nature, Water"))
    #expect(prompt.text.contains("Equipment:"))
}
