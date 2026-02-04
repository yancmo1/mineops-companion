import Testing
@testable import MineOpsCompanionFeature

@Suite
struct SMBaseStatsLoaderTests {
    
    @Test func loadsDatabase() throws {
        let database = try SMBaseStatsLoader.loadDatabase()
        
        #expect(!database.managers.isEmpty)
        #expect(database.version == "1.0.0")
        #expect(!database.upgradeFormulas.isEmpty)
    }
    
    @Test func databaseContainsUpgradeFormulas() throws {
        let database = try SMBaseStatsLoader.loadDatabase()
        
        #expect(database.upgradeFormulas["Common"] != nil)
        #expect(database.upgradeFormulas["Rare"] != nil)
        #expect(database.upgradeFormulas["Epic"] != nil)
        #expect(database.upgradeFormulas["Legendary"] != nil)
    }
    
    @Test func upgradeFormulasHaveCorrectMaxLevels() throws {
        let database = try SMBaseStatsLoader.loadDatabase()
        
        #expect(database.upgradeFormulas["Common"]?.maxLevel == 40)
        #expect(database.upgradeFormulas["Rare"]?.maxLevel == 30)
        #expect(database.upgradeFormulas["Epic"]?.maxLevel == 20)
        #expect(database.upgradeFormulas["Legendary"]?.maxLevel == 20)
    }
    
    @Test func getManagerById() throws {
        let chester = try SMBaseStatsLoader.getManager(id: "chester")
        
        #expect(chester != nil)
        #expect(chester?.name == "Chester")
        #expect(chester?.rarity == "Common")
        #expect(chester?.type == "Mine Shaft")
    }
    
    @Test func getManagerByIdReturnsNilForInvalidId() throws {
        let result = try SMBaseStatsLoader.getManager(id: "nonexistent_manager")
        #expect(result == nil)
    }
    
    @Test func getManagersByRarity() throws {
        let commons = try SMBaseStatsLoader.getManagersByRarity("Common")
        let legendaries = try SMBaseStatsLoader.getManagersByRarity("Legendary")
        
        #expect(!commons.isEmpty)
        #expect(!legendaries.isEmpty)
        
        // Verify all returned managers have the correct rarity
        #expect(commons.allSatisfy { $0.rarity == "Common" })
        #expect(legendaries.allSatisfy { $0.rarity == "Legendary" })
    }
    
    @Test func chesterHasCorrectBaseStats() throws {
        let chester = try SMBaseStatsLoader.getManager(id: "chester")
        
        #expect(chester?.baseStats.level == 1)
        #expect(chester?.baseStats.promotion == 0)
        #expect(chester?.baseStats.activeMultiplier == 5.0)
        #expect(chester?.baseStats.activeDuration == "5m")
        #expect(chester?.baseStats.activeCooldown == "30m")
    }
    
    @Test func chesterHasCorrectPassives() throws {
        let chester = try SMBaseStatsLoader.getManager(id: "chester")
        
        #expect(chester?.passives.count == 1)
        
        let passive = chester?.passives.first
        #expect(passive?.unlockLevel == 10)
        #expect(passive?.type == "upgrade_cost_reduction")
        #expect(passive?.baseMultiplier == 0.5)
    }
    
    @Test func sirLorenzoHasMultiplePassives() throws {
        let lorenzo = try SMBaseStatsLoader.getManager(id: "sir_lorenzo")
        
        #expect(lorenzo?.passives.count == 3)
        #expect(lorenzo?.passives.contains { $0.unlockLevel == 10 } == true)
        #expect(lorenzo?.passives.contains { $0.unlockLevel == 30 } == true)
        #expect(lorenzo?.passives.contains { $0.unlockLevel == 50 } == true)
    }
    
    @Test func convertsManagerToCalculatorInputs() throws {
        let chester = try SMBaseStatsLoader.getManager(id: "chester")
        #expect(chester != nil)
        
        guard let chester = chester else { return }
        let inputs = SMBaseStatsLoader.toCalculatorInputs(manager: chester)
        
        #expect(inputs != nil)
        #expect(inputs?.rarity == .common)
        #expect(inputs?.baseMultiplier == 5.0)
        #expect(inputs?.passives.count == 1)
    }
    
    @Test func calculatorInputsPreservePassiveData() throws {
        let lorenzo = try SMBaseStatsLoader.getManager(id: "sir_lorenzo")
        #expect(lorenzo != nil)
        
        guard let lorenzo = lorenzo else { return }
        let inputs = SMBaseStatsLoader.toCalculatorInputs(manager: lorenzo)
        
        #expect(inputs?.passives.count == 3)
        
        // Verify first passive
        let firstPassive = inputs?.passives.first
        #expect(firstPassive?.unlockLevel == 10)
        #expect(firstPassive?.baseMultiplier == 4.17)
        #expect(firstPassive?.type == "mining_speed")
    }
    
    @Test func allManagersHaveValidRarity() throws {
        let database = try SMBaseStatsLoader.loadDatabase()
        
        for manager in database.managers {
            let inputs = SMBaseStatsLoader.toCalculatorInputs(manager: manager)
            #expect(inputs != nil, "Manager \(manager.name) has invalid rarity: \(manager.rarity)")
        }
    }
    
    @Test func allManagersHavePositiveActiveMultiplier() throws {
        let database = try SMBaseStatsLoader.loadDatabase()
        
        for manager in database.managers {
            #expect(manager.baseStats.activeMultiplier > 0, 
                   "Manager \(manager.name) has non-positive active multiplier")
        }
    }
    
    @Test func passiveUnlockLevelsAreValid() throws {
        let database = try SMBaseStatsLoader.loadDatabase()
        
        for manager in database.managers {
            guard let inputs = SMBaseStatsLoader.toCalculatorInputs(manager: manager) else {
                continue
            }
            
            let maxLevel = inputs.rarity.maxLevel
            for passive in manager.passives {
                #expect(passive.unlockLevel > 0, 
                       "Manager \(manager.name) has passive with invalid unlock level")
                #expect(passive.unlockLevel <= maxLevel * 2.5, 
                       "Manager \(manager.name) has passive unlock level beyond reasonable range")
            }
        }
    }
}
