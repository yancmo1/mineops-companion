import Testing
@testable import MineOpsCompanionFeature

@Suite
struct OCRLevelParserTests {
    @Test func basics() {
        #expect(OCRLevelParser.parse(from: "Level 14") == 14)
        #expect(OCRLevelParser.parse(from: "LV7") == 7)
        #expect(OCRLevelParser.parse(from: "Lvel 10") == 10)
    }
}
