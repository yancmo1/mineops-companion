import Testing
@testable import MineOpsCompanionFeature

@Suite
struct DirectoryMatcherTests {
    @Test func matchesNameInsideMultilineText() throws {
        let directory = try SMDirectory.load()
        let text = """
        Super Manager Overview
        Mr Edmund
        Promotion 3/6
        """
        let match = DirectoryMatcher.bestMatch(in: text, directory: directory)
        #require(match != nil)
        #expect(match?.name == "Mr Edmund")
    }

    @Test func heuristicsPickNameFromNoise() {
        let text = """
        Super Manager Stats
        Dr Lilly
        Level 5/6
        Readiness Snapshot
        """
        let guess = OCRTextHeuristics.guessDisplayName(from: text)
        #expect(guess == "Dr Lilly")
    }
}
