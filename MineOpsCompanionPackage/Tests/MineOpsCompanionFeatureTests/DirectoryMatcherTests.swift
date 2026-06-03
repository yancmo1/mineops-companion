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

    @Test("Does not classify Dr. Nova as Dr. Steiner when only 'Dr' overlaps")
    func doesNotMisclassifyDrNovaAsSteiner() throws {
        let directory = try SMDirectory.load()
        let text = """
        Dr Nova
        Level: 13/50
        Active
        Passive
        Rank up
        """

        let match = DirectoryMatcher.bestMatch(in: text, directory: directory)
        #expect(match?.id != "dr_steiner")
    }

    @Test("Handles OCR confusion N0va without matching Dr. Steiner")
    func doesNotMisclassifyDrN0vaAsSteiner() throws {
        let directory = try SMDirectory.load()
        let text = """
        Dr N0va
        Level: 13/50
        Active
        Passive
        Rank up
        """

        let match = DirectoryMatcher.bestMatch(in: text, directory: directory)
        #expect(match?.id != "dr_steiner")
    }

    @Test("Still matches Dr. Steiner when name token is present")
    func stillMatchesDrSteiner() throws {
        let directory = try SMDirectory.load()
        let text = """
        Dr Steiner
        Level: 21/50
        Active
        Passive
        """

        let match = DirectoryMatcher.bestMatch(in: text, directory: directory)
        #expect(match?.id == "dr_steiner")
    }

    @Test("Matches Rabbit Blingsley OCR variant to Rabbid Blingsley directory id")
    func matchesRabbitVariantToRabbidBlingsley() throws {
        let directory = try SMDirectory.load()
        let text = """
        Rabbit Blingsley
        Level: 1/50
        Active
        Passive
        """

        let match = DirectoryMatcher.bestMatch(in: text, directory: directory)
        #expect(match?.id == "rabbid_blingsley")
    }

    @Test("Prevents ambiguous 'Goodman' alias collision between Mr and Mrs Goodman")
    func preventsGoodmanAliasCollision() throws {
        let directory = try SMDirectory.load()

        let mrGoodman = try #require(directory.first { $0.id == "mr_goodman" })
        let mrsGoodman = try #require(directory.first { $0.id == "mrs_goodman" })

        // Ensure standalone "Goodman" is not in either (too ambiguous)
        #expect(!mrGoodman.aliases.contains("Goodman"))
        #expect(!mrsGoodman.aliases.contains("Goodman"))

        // Both should have explicit Mr/Mrs prefix variants
        #expect(mrGoodman.aliases.contains { $0.lowercased().contains("mr") })
        #expect(mrsGoodman.aliases.contains { $0.lowercased().contains("mrs") })
    }
}
