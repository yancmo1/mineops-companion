import Testing
@testable import MineOpsCompanionFeature

@Test("All continents have exactly 5 mines")
func allContinentsHaveFiveMines() {
    let continents: [MineType] = [.start, .ice, .fire, .dawn, .dusk, .ancient, .desert]
    
    for continent in continents {
        let mines = continent.continentMines
        #expect(mines?.count == 5, "Expected \(continent.rawValue) to have 5 mines, but got \(mines?.count ?? 0)")
    }
}

@Test("Ancient Continent has correct mine names")
func ancientContinentMines() {
    let expectedMines: [ContinentMine] = [.aquamarine, .ammolite, .azurite, .pearl, .turquoise]
    let actualMines = MineType.ancient.continentMines
    
    #expect(actualMines == expectedMines, "Ancient Continent mines don't match expected values")
}

@Test("Start Continent has correct mine names")
func startContinentMines() {
    let expectedMines: [ContinentMine] = [.coal, .gold, .ruby, .diamond, .emerald]
    let actualMines = MineType.start.continentMines
    
    #expect(actualMines == expectedMines, "Start Continent mines don't match expected values")
}

@Test("Ice Continent has correct mine names")
func iceContinentMines() {
    let expectedMines: [ContinentMine] = [.moonstone, .amethyst, .crystal, .jade, .sapphire]
    let actualMines = MineType.ice.continentMines
    
    #expect(actualMines == expectedMines, "Ice Continent mines don't match expected values")
}

@Test("Fire Continent has correct mine names")
func fireContinentMines() {
    let expectedMines: [ContinentMine] = [.amber, .topaz, .sunstone, .platinum, .obsidian]
    let actualMines = MineType.fire.continentMines
    
    #expect(actualMines == expectedMines, "Fire Continent mines don't match expected values")
}

@Test("Dawn Continent has correct mine names")
func dawnContinentMines() {
    let expectedMines: [ContinentMine] = [.heliodor, .realgar, .alexandrite, .celestine, .titanite]
    let actualMines = MineType.dawn.continentMines
    
    #expect(actualMines == expectedMines, "Dawn Continent mines don't match expected values")
}

@Test("Dusk Continent has correct mine names")
func duskContinentMines() {
    let expectedMines: [ContinentMine] = [.fluorite, .quartz, .aragonite, .beryl, .calcite]
    let actualMines = MineType.dusk.continentMines
    
    #expect(actualMines == expectedMines, "Dusk Continent mines don't match expected values")
}

@Test("Desert Continent has correct mine names")
func desertContinentMines() {
    let expectedMines: [ContinentMine] = [.chrysoberyl, .labradorite, .aventurine, .jasper, .carnelian]
    let actualMines = MineType.desert.continentMines
    
    #expect(actualMines == expectedMines, "Desert Continent mines don't match expected values")
}

@Test("Mainland does not have continent mines")
func mainlandHasNoContinentMines() {
    #expect(MineType.mainland.continentMines == nil, "Mainland should not have continent mines")
}

@Test("Frontier does not have continent mines")
func frontierHasNoContinentMines() {
    #expect(MineType.frontier.continentMines == nil, "Frontier should not have continent mines")
}

@Test("MineContext display name includes continent and mine")
func mineContextDisplayName() {
    let context = MineContext(
        type: .ancient,
        continentMine: .aquamarine,
        prestige: 5,
        maxShaft: 30
    )
    
    #expect(context.displayName == "Ancient Continent - Aquamarine")
}
