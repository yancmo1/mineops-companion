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

    @Test func heuristicsIgnoreCurrencyCounters() {
        let text = """
        154K
        Dr. Steiner
        Epic
        Level 13/50
        """

        let guess = OCRTextHeuristics.guessDisplayName(from: text)
        #expect(guess != "154K")
        #expect(guess == "Dr. Steiner")
    }

    @Test func doesNotMatchFromSingleLetterFragments() throws {
        let directory = try SMDirectory.load()
        let text = """
        U
        Level 5/6
        Active
        Passive
        """

        // Previously this could incorrectly match "Ut'ux" because the matcher treated
        // candidate.contains(raw) as a perfect signal (e.g. "utux" contains "u").
        let match = DirectoryMatcher.bestMatch(in: text, directory: directory)
        #expect(match?.id != "utux")
    }
}
