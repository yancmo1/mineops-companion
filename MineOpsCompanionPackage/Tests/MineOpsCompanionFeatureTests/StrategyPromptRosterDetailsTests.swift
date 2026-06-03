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

@Test("StrategyRosterExportEntry propagates OCR-extracted active stats")
func exportEntryPropagatesOCRStats() throws {
    let entry = try makeDirectoryEntryWithElements()

    let sm = RecognizedSM(
        sourceImage: UIImage(),
        rawText: "",
        level: 15,
        directoryMatch: entry,
        resolvedName: "Blingsley",
        stats: SMStats(),
        active: RecognizedSM.ActiveInfo(
            multiplier: 3.5,
            durationSeconds: 300,
            cooldownSeconds: 1800
        ),
        passive: RecognizedSM.PassiveInfo(
            multiplier: 1.11
        )
    )

    let export = StrategyRosterExportEntry(from: sm)

    // OCR-extracted values should take priority over directory values
    #expect(export.activeMultiplier == 3.5)
    #expect(export.activeDurationSeconds == 300)
    #expect(export.activeCooldownSeconds == 1800)
    #expect(export.passiveMultiplier == 1.11)

    let line = export.promptLine
    #expect(line.contains("ActiveMult: 3.50x"))
    #expect(line.contains("ActiveDur: 300s"))
    #expect(line.contains("ActiveCD: 1800s"))
    #expect(line.contains("PassiveMult: 1.11x"))
}
