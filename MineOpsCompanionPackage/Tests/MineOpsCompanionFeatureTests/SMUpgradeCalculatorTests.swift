import Testing
@testable import MineOpsCompanionFeature

@Suite
struct SMUpgradeCalculatorTests {
    
    // MARK: - Rarity Tests
    
    @Test func rarityMaxLevels() {
        #expect(SMUpgradeCalculator.Rarity.common.maxLevel == 40)
        #expect(SMUpgradeCalculator.Rarity.rare.maxLevel == 30)
        #expect(SMUpgradeCalculator.Rarity.epic.maxLevel == 20)
        #expect(SMUpgradeCalculator.Rarity.legendary.maxLevel == 20)
    }
    
    @Test func rarityMaxPromotions() {
        #expect(SMUpgradeCalculator.Rarity.common.maxPromotion == 4)
        #expect(SMUpgradeCalculator.Rarity.rare.maxPromotion == 3)
        #expect(SMUpgradeCalculator.Rarity.epic.maxPromotion == 2)
        #expect(SMUpgradeCalculator.Rarity.legendary.maxPromotion == 2)
    }
    
    @Test func commonRarityMultipliers() {
        let rarity = SMUpgradeCalculator.Rarity.common
        #expect(rarity.multiplierForLevel(5) == 1.40)
        #expect(rarity.multiplierForLevel(15) == 1.40)
        #expect(rarity.multiplierForLevel(25) == 1.337)
        #expect(rarity.multiplierForLevel(35) == 1.30)
    }
    
    @Test func rareRarityMultipliers() {
        let rarity = SMUpgradeCalculator.Rarity.rare
        #expect(rarity.multiplierForLevel(5) == 1.45)
        #expect(rarity.multiplierForLevel(15) == 1.35)
        #expect(rarity.multiplierForLevel(25) == 1.30)
    }
    
    @Test func epicRarityMultipliers() {
        let rarity = SMUpgradeCalculator.Rarity.epic
        #expect(rarity.multiplierForLevel(5) == 1.50)
        #expect(rarity.multiplierForLevel(15) == 1.45)
    }
    
    @Test func legendaryRarityMultipliers() {
        let rarity = SMUpgradeCalculator.Rarity.legendary
        #expect(rarity.multiplierForLevel(5) == 1.55)
        #expect(rarity.multiplierForLevel(15) == 1.50)
    }
    
    // MARK: - Active Multiplier Calculation Tests
    
    @Test func calculatesActiveMultiplierAtLevel1() {
        let result = SMUpgradeCalculator.calculateActiveMultiplier(
            baseMultiplier: 5.0,
            currentLevel: 1,
            rarity: .common
        )
        #expect(result == 5.0)
    }
    
    @Test func calculatesActiveMultiplierAtLevel2() {
        let result = SMUpgradeCalculator.calculateActiveMultiplier(
            baseMultiplier: 5.0,
            currentLevel: 2,
            rarity: .common
        )
        // Level 2 = 5.0 * 1.40 = 7.0
        #expect(result == 7.0)
    }
    
    @Test func calculatesActiveMultiplierAtLevel10Common() {
        let result = SMUpgradeCalculator.calculateActiveMultiplier(
            baseMultiplier: 5.0,
            currentLevel: 10,
            rarity: .common
        )
        // Level 2-10: 5.0 * (1.40^9) = 5.0 * 28.925...
        let expected = 5.0 * pow(1.40, 9)
        #expect(abs(result - expected) < 0.01)
    }
    
    @Test func calculatesActiveMultiplierForLegendary() {
        // Sir Lorenzo base: 10.19x at level 1
        let result = SMUpgradeCalculator.calculateActiveMultiplier(
            baseMultiplier: 10.19,
            currentLevel: 5,
            rarity: .legendary
        )
        // Level 2-5: 10.19 * (1.55^4)
        let expected = 10.19 * pow(1.55, 4)
        #expect(abs(result - expected) < 0.01)
    }
    
    @Test func activeMultiplierCapsAtMaxLevel() {
        let result = SMUpgradeCalculator.calculateActiveMultiplier(
            baseMultiplier: 5.0,
            currentLevel: 100, // Exceeds max level for common (40)
            rarity: .common
        )
        #expect(result == 5.0) // Should return base multiplier
    }
    
    // MARK: - Passive Multiplier Tests
    
    @Test func passiveNotUnlockedReturnsNil() {
        let result = SMUpgradeCalculator.calculatePassiveMultiplier(
            baseMultiplier: 2.0,
            currentLevel: 5,
            unlockLevel: 10,
            rarity: .common
        )
        #expect(result == nil)
    }
    
    @Test func passiveUnlockedReturnsBaseMultiplier() {
        let result = SMUpgradeCalculator.calculatePassiveMultiplier(
            baseMultiplier: 2.0,
            currentLevel: 10,
            unlockLevel: 10,
            rarity: .common
        )
        #expect(result == 2.0)
    }
    
    @Test func passiveUnlockedAtHigherLevel() {
        let result = SMUpgradeCalculator.calculatePassiveMultiplier(
            baseMultiplier: 2.17,
            currentLevel: 20,
            unlockLevel: 10,
            rarity: .rare
        )
        #expect(result == 2.17)
    }
    
    // MARK: - Full Stats Calculation Tests
    
    @Test func calculatesStatsWithNoPassivesUnlocked() {
        let stats = SMUpgradeCalculator.calculateStats(
            baseActiveMultiplier: 5.0,
            currentLevel: 5,
            promotion: 0,
            rarity: .common,
            passives: [
                (unlockLevel: 10, baseMultiplier: 2.0, type: "mining_speed")
            ]
        )
        
        #expect(stats.level == 5)
        #expect(stats.promotion == 0)
        #expect(stats.rarity == .common)
        #expect(stats.passives.isEmpty)
    }
    
    @Test func calculatesStatsWithOnePassiveUnlocked() {
        let stats = SMUpgradeCalculator.calculateStats(
            baseActiveMultiplier: 5.0,
            currentLevel: 10,
            promotion: 1,
            rarity: .common,
            passives: [
                (unlockLevel: 10, baseMultiplier: 2.0, type: "mining_speed")
            ]
        )
        
        #expect(stats.level == 10)
        #expect(stats.promotion == 1)
        #expect(stats.passives.count == 1)
        #expect(stats.passives.first?.type == "mining_speed")
        #expect(stats.passives.first?.multiplier == 2.0)
    }
    
    @Test func calculatesStatsWithMultiplePassivesUnlocked() {
        let stats = SMUpgradeCalculator.calculateStats(
            baseActiveMultiplier: 10.19,
            currentLevel: 30,
            promotion: 3,
            rarity: .legendary,
            passives: [
                (unlockLevel: 10, baseMultiplier: 4.17, type: "mining_speed"),
                (unlockLevel: 30, baseMultiplier: 0.5, type: "upgrade_cost_reduction")
            ]
        )
        
        #expect(stats.level == 30)
        #expect(stats.promotion == 3)
        #expect(stats.passives.count == 2)
        #expect(stats.passives.contains { $0.type == "mining_speed" })
        #expect(stats.passives.contains { $0.type == "upgrade_cost_reduction" })
    }
    
    @Test func calculatesStatsWithMixedPassives() {
        // Level 20: First passive unlocked, second not yet
        let stats = SMUpgradeCalculator.calculateStats(
            baseActiveMultiplier: 10.19,
            currentLevel: 20,
            promotion: 2,
            rarity: .legendary,
            passives: [
                (unlockLevel: 10, baseMultiplier: 4.17, type: "mining_speed"),
                (unlockLevel: 30, baseMultiplier: 0.5, type: "upgrade_cost_reduction"),
                (unlockLevel: 50, baseMultiplier: 1.41, type: "continent_income")
            ]
        )
        
        #expect(stats.passives.count == 1)
        #expect(stats.passives.first?.type == "mining_speed")
    }
    
    // MARK: - Display Format Tests
    
    @Test func formatsActiveMultiplierDisplay() {
        let stats = SMCalculatedStats(
            level: 10,
            promotion: 1,
            rarity: .common,
            activeMultiplier: 123.456,
            passives: []
        )
        #expect(stats.activeMultiplierDisplay == "123.46x")
    }
    
    @Test func formatsCostReductionPassiveDisplay() {
        let passive = SMPassiveStat(
            type: "upgrade_cost_reduction",
            multiplier: 0.5,
            unlockLevel: 10
        )
        #expect(passive.multiplierDisplay == "-50%")
    }
    
    @Test func formatsMultiplierPassiveDisplay() {
        let passive = SMPassiveStat(
            type: "mining_speed",
            multiplier: 2.17,
            unlockLevel: 10
        )
        #expect(passive.multiplierDisplay == "2.17x")
    }
    
    // MARK: - Real World Examples
    
    @Test("Chester (Common) at Level 1")
    func chesterLevel1() {
        let stats = SMUpgradeCalculator.calculateStats(
            baseActiveMultiplier: 5.0,
            currentLevel: 1,
            promotion: 0,
            rarity: .common,
            passives: [
                (unlockLevel: 10, baseMultiplier: 0.5, type: "upgrade_cost_reduction")
            ]
        )
        
        #expect(stats.activeMultiplier == 5.0)
        #expect(stats.passives.isEmpty)
    }
    
    @Test("Chester (Common) at Level 10")
    func chesterLevel10() {
        let stats = SMUpgradeCalculator.calculateStats(
            baseActiveMultiplier: 5.0,
            currentLevel: 10,
            promotion: 1,
            rarity: .common,
            passives: [
                (unlockLevel: 10, baseMultiplier: 0.5, type: "upgrade_cost_reduction")
            ]
        )
        
        // Active should be upgraded: 5.0 * (1.40^9)
        let expectedActive = 5.0 * pow(1.40, 9)
        #expect(abs(stats.activeMultiplier - expectedActive) < 0.01)
        
        // Passive should be unlocked
        #expect(stats.passives.count == 1)
        #expect(stats.passives.first?.multiplier == 0.5)
    }
    
    @Test("Sir Lorenzo (Legendary) at Level 10")
    func sirLorenzoLevel10() {
        let stats = SMUpgradeCalculator.calculateStats(
            baseActiveMultiplier: 10.19,
            currentLevel: 10,
            promotion: 1,
            rarity: .legendary,
            passives: [
                (unlockLevel: 10, baseMultiplier: 4.17, type: "mining_speed")
            ]
        )
        
        // Active should be upgraded: 10.19 * (1.55^9)
        let expectedActive = 10.19 * pow(1.55, 9)
        #expect(abs(stats.activeMultiplier - expectedActive) < 0.01)
        
        // Passive should be unlocked
        #expect(stats.passives.count == 1)
        #expect(stats.passives.first?.multiplier == 4.17)
    }
}
