import Testing
@testable import MineOpsCompanionFeature

@Suite
struct SMStatsParserTests {
    @Test func parsesFractionsMultipliersAndDurations() {
        let text = """
        Lee Vatori
        Active
        Level 13/50
        Promotion: 1/5
        4.76x
        5m
        30m
        Passive
        1.06x
        """

        let stats = SMStatsParser.parse(text: text)

        #expect(stats.level?.current == 13)
        #expect(stats.level?.total == 50)
        #expect(stats.promotion?.current == 1)
        #expect(stats.promotion?.total == 5)
        #expect(stats.multipliers.count == 2)
        #expect(stats.multipliersDescending.first?.display == "4.76x")
        #expect(stats.multipliersDescending.last?.display == "1.06x")
        #expect(stats.minuteDurations.sorted() == [5, 30])
    }

    @Test func parsesPercentagesWithSigns() {
        let text = """
        Damian Jones Passive -12% 1.44x
        Promotion 1/5
        Active Level 12/50
        """
        let stats = SMStatsParser.parse(text: text)

        #expect(stats.normalizedPercentDisplays.contains("-12%"))
        #expect(stats.percentNumberValues.contains(-12))
        #expect(stats.promotion?.current == 1)
        #expect(stats.level?.current == 12)
    }
}
