import Testing
@testable import MineOpsCompanionFeature

@Suite
struct OCRFieldExtractionTests {
    @Test func parsesActiveAndPassiveSections() {
        let sample = """
        Legendary Super Manager
        ⭐⭐⭐
        Active
        Warehouse Walk Speed 6.42x
        Duration 5m • Cooldown 30m
        Passive
        Idle Income 1.10x
        Promote
        """

        let extraction = OCRFieldExtraction.extract(from: sample)
        #expect(extraction.rarity == "Legendary")
        #expect(extraction.stars == 3)
        #expect(extraction.activeMultiplier == 6.42)
        #expect(extraction.activeValue == 6.42)
        #expect(extraction.activeUnit == .x)
        #expect(extraction.activeDurationSeconds == 300)
        #expect(extraction.activeCooldownSeconds == 1800)
        #expect(extraction.passiveMultiplier == 1.10)
        #expect(extraction.passiveValues.first?.value == 1.10)
        #expect(extraction.passiveValues.first?.unit == .x)
        #expect(extraction.hasPromote)
    }

    @Test func detectsButtonsAndRoles() {
        let sample = """
        Epic Transport Manager
        Rank Up
        Level Up
        """

        let extraction = OCRFieldExtraction.extract(from: sample)
        #expect(extraction.role == "Transport")
        #expect(extraction.hasRankUp)
        #expect(extraction.hasLevelUp)
    }
}

    @Test func parsesNegativePercentValues() {
        let sample = """
        Rare Manager
        Active
        Something -91.74%
        Duration 5m • Cooldown 30m
        Passive
        Another -8.4%
        """

        let extraction = OCRFieldExtraction.extract(from: sample)
        #expect(extraction.activeValue == -91.74)
        #expect(extraction.activeUnit == .percent)
        #expect(extraction.passiveValues.first?.value == -8.4)
        #expect(extraction.passiveValues.first?.unit == .percent)
    }