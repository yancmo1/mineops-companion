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

    @Test("Parses stars from rank fallback when star glyphs are missing")
    func parsesStarsFromRankFallback() {
        let sample = """
        Epic Manager
        Rank 2
        Active
        2.7x
        """

        let extraction = OCRFieldExtraction.extract(from: sample)
        #expect(extraction.stars == 2)
    }

    @Test("Parses fragment pieces from rank progress")
    func parsesFragmentsFromProgress() {
        let sample = """
        Legendary Manager
        Rank Up
        8/30
        Active
        5m
        """

        let extraction = OCRFieldExtraction.extract(from: sample)
        #expect(extraction.fragments == 8)
    }

    @Test("Parses rank-up fragments with /50 denominator without confusing level progress")
    func parsesFragmentsFromRankUpWithFiftyDenominator() {
        let sample = """
        9/50
        Rank up
        Active
        Passive
        Level: 14/50
        Promotion: 1/5
        """

        let extraction = OCRFieldExtraction.extract(from: sample)
        #expect(extraction.fragments == 9)
    }

    @Test("Parses screenshot-style card with /80 rank progress and expected stat fields")
    func parsesScreenshotStyleCardWithEightyDenominator() {
        let sample = """
        Zoe_365
        Epic
        Mineshaft
        ⭐⭐⭐
        2/80
        Rank up
        Active
        Level: 13/50
        2.98x
        3m
        30m
        Passive
        Promotion: 1/5
        -30.5%
        2.85x
        1.98x
        Level Up
        Promote
        """

        let extraction = OCRFieldExtraction.extract(from: sample)

        #expect(extraction.rarity == "Epic")
        #expect(extraction.role == "Mineshaft")
        #expect(extraction.stars == 3)
        #expect(extraction.fragments == 2)
        #expect(extraction.activeMultiplier == 2.98)
        #expect(extraction.activeDurationSeconds == 180)
        #expect(extraction.activeCooldownSeconds == 1800)
        #expect(extraction.passiveValues.count >= 3)
        #expect(extraction.passiveValues[0].value == -30.5)
        #expect(extraction.passiveValues[0].unit == .percent)
        #expect(extraction.passiveValues[1].value == 2.85)
        #expect(extraction.passiveValues[2].value == 1.98)
        #expect(extraction.hasLevelUp)
        #expect(extraction.hasPromote)
        #expect(extraction.hasRankUp)
    }

    @Test("Parses rank-up fragments when denominator scales with progression")
    func parsesFragmentsWithScaledDenominator() {
        let sample = """
        7/160
        Rank up
        Level: 24/50
        Promotion: 2/5
        """

        let extraction = OCRFieldExtraction.extract(from: sample)
        #expect(extraction.fragments == 7)
    }

    @Test("Does not treat Level or Promotion counters as fragments when rank-up context is missing")
    func ignoresLevelAndPromotionCountersForFragments() {
        let sample = """
        Active
        Passive
        Level: 14/50
        Promotion: 1/5
        """

        let extraction = OCRFieldExtraction.extract(from: sample)
        #expect(extraction.fragments == nil)
    }

    @Test("Spatial extraction splits Active and Passive columns correctly")
    func spatialSplitsColumns() {
        // Simulated spatial data: Active header at x=0.15, Passive at x=0.7
        let lines: [OCRTextRecognizer.SpatialLine] = [
            .init(text: "Dr. Lilly", boundingBox: CGRect(x: 0.3, y: 0.85, width: 0.4, height: 0.05)),
            .init(text: "Epic", boundingBox: CGRect(x: 0.1, y: 0.78, width: 0.15, height: 0.04)),
            .init(text: "Elevator", boundingBox: CGRect(x: 0.7, y: 0.78, width: 0.2, height: 0.04)),
            .init(text: "Active", boundingBox: CGRect(x: 0.1, y: 0.55, width: 0.15, height: 0.04)),
            .init(text: "Passive", boundingBox: CGRect(x: 0.65, y: 0.55, width: 0.15, height: 0.04)),
            .init(text: "2.7x", boundingBox: CGRect(x: 0.12, y: 0.48, width: 0.1, height: 0.03)),
            .init(text: "5m", boundingBox: CGRect(x: 0.12, y: 0.43, width: 0.08, height: 0.03)),
            .init(text: "Cooldown 30m", boundingBox: CGRect(x: 0.1, y: 0.38, width: 0.2, height: 0.03)),
            .init(text: "1.11x", boundingBox: CGRect(x: 0.67, y: 0.48, width: 0.1, height: 0.03)),
            .init(text: "1.2x", boundingBox: CGRect(x: 0.67, y: 0.43, width: 0.1, height: 0.03)),
            .init(text: "-43.7%", boundingBox: CGRect(x: 0.67, y: 0.38, width: 0.1, height: 0.03)),
        ]

        let result = OCRFieldExtraction.extractWithSpatialData(from: lines)

        // Active column values
        #expect(result.activeMultiplier == 2.7)
        #expect(result.activeDurationSeconds == 300)
        #expect(result.activeCooldownSeconds == 1800)

        // Passive column values — should NOT bleed into active
        #expect(result.passiveValues.count >= 2)
        #expect(result.passiveValues[0].value == 1.11)
        #expect(result.passiveValues[0].unit == .x)
    }

    @Test("durationToSeconds converts time units correctly")
    func durationConversion() {
        #expect(OCRFieldExtraction.durationToSeconds(value: 2, unit: "h") == 7200)
        #expect(OCRFieldExtraction.durationToSeconds(value: 5, unit: "m") == 300)
        #expect(OCRFieldExtraction.durationToSeconds(value: 30, unit: "s") == 30)
        #expect(OCRFieldExtraction.durationToSeconds(value: 1, unit: "hours") == 3600)
        #expect(OCRFieldExtraction.durationToSeconds(value: 15, unit: "min") == 900)
    }
}