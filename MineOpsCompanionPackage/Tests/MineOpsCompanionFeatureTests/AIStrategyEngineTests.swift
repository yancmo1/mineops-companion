@testable import MineOpsCompanionFeature
import Foundation
import Testing
import UIKit

@Suite
struct AIStrategyEngineTests {
    
    // MARK: - Test Helpers
    
    private func makeManager(
        name: String,
        department: String,
        level: Int? = nil,
        activeMultiplier: Double? = nil
    ) -> RecognizedSM {
        let active: SMDirectoryEntry.Active? = if let mult = activeMultiplier {
            SMDirectoryEntry.Active(
                name: "Test Boost",
                type: "test_boost",
                durationSeconds: 300,
                cooldownSeconds: 900,
                multiplier: mult
            )
        } else {
            nil
        }
        
        let entry = try! JSONDecoder().decode(
            SMDirectoryEntry.self,
            from: """
            {
                "name": "\(name)",
                "department": "\(department)",
                "rarity": "legendary",
                "active": \(active != nil ? "{\"name\": \"Test Boost\", \"type\": \"test_boost\", \"durationSeconds\": 300, \"cooldownSeconds\": 900, \"multiplier\": \(activeMultiplier ?? 0)}" : "null")
            }
            """.data(using: .utf8)!
        )
        
        return RecognizedSM(
            sourceImage: UIImage(),
            rawText: name,
            level: level,
            directoryMatch: entry,
            resolvedName: name,
            stats: SMStats()
        )
    }
    
    // MARK: - Thalia + Freesia + H4V0C Combo Tests
    
    @Test("Thalia + Freesia + H4V0C + Damian + Edmund generates triple burst combo")
    func testFullTripleBurstCombo() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Thalia", department: "mineshaft", level: 30, activeMultiplier: 7.5),
            makeManager(name: "Freesia", department: "elevator", level: 25, activeMultiplier: 6.0),
            makeManager(name: "H4V0C", department: "mineshaft", level: 28, activeMultiplier: 7.0),
            makeManager(name: "Damian Jones", department: "elevator", level: 20, activeMultiplier: 6.4),
            makeManager(name: "Mr. Edmund", department: "warehouse", level: 22, activeMultiplier: 7.5)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.comboName == "Thalia Triple Burst")
        #expect(result.recommendedManagers.contains("Thalia"))
        #expect(result.recommendedManagers.contains("Freesia"))
        #expect(result.recommendedManagers.contains("H4V0C"))
        #expect(result.recommendedManagers.contains("Damian Jones"))
        #expect(result.recommendedManagers.contains("Mr. Edmund"))
        
        #expect(result.strategySummary.contains("Mineshaft"))
        #expect(result.strategySummary.contains("Elevator"))
        #expect(result.strategySummary.contains("Warehouse"))
        #expect(result.strategySummary.contains("Freesia (2m)"))
        #expect(result.strategySummary.contains("Thalia (5m)"))
        #expect(result.strategySummary.contains("H4V0C (3m)"))
        #expect(result.strategySummary.contains("Damian (5m)"))
        #expect(result.strategySummary.contains("Edmund (2m)"))
    }
    
    @Test("Thalia + Freesia + H4V0C without Edmund still generates good strategy")
    func testTripleBurstWithoutEdmund() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Thalia", department: "mineshaft", level: 30),
            makeManager(name: "Freesia", department: "elevator", level: 25),
            makeManager(name: "H4V0C", department: "mineshaft", level: 28),
            makeManager(name: "Mark", department: "warehouse", level: 15)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.comboName == "Thalia Triple Burst")
        #expect(result.strategySummary.contains("Thalia (5m)"))
        #expect(result.strategySummary.contains("H4V0C (3m)"))
        #expect(result.strategySummary.contains("Freesia (2m)"))
    }
    
    // MARK: - Edmund Warehouse Burst Tests
    
    @Test("Edmund without top mineshaft combo generates warehouse burst strategy")
    func testEdmundWarehouseBurst() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Mr. Edmund", department: "warehouse", level: 25, activeMultiplier: 7.5),
            makeManager(name: "Mrs. Goodman", department: "warehouse", level: 20, activeMultiplier: 4.8),
            makeManager(name: "Lee Vatori", department: "elevator", level: 18, activeMultiplier: 6.2),
            makeManager(name: "Cliff Walker", department: "mineshaft", level: 22, activeMultiplier: 5.0)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.comboName == "Edmund Warehouse Burst")
        #expect(result.recommendedManagers.contains("Mr. Edmund"))
        #expect(result.strategySummary.contains("Edmund (2m)"))
        #expect(result.strategySummary.contains("cost reducers"))
    }
    
    // MARK: - Warehouse Priority Tests
    
    @Test("Edmund scores higher than other warehouse managers")
    func testWarehousePriority() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Mr. Edmund", department: "warehouse", level: 10, activeMultiplier: 2.5),
            makeManager(name: "Mark", department: "warehouse", level: 20, activeMultiplier: 5.24),
            makeManager(name: "Mrs. Goodman", department: "warehouse", level: 15, activeMultiplier: 4.8)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        // Edmund should be first even with lower level/boost due to priority
        #expect(result.recommendedManagers.first == "Mr. Edmund")
    }
    
    @Test("Cost reducers are selected when Edmund is missing")
    func testCostReducerFallback() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Mark", department: "warehouse", level: 20),
            makeManager(name: "Mrs. Goodman", department: "warehouse", level: 15),
            makeManager(name: "Goodman Jr.", department: "elevator", level: 12),
            makeManager(name: "Chester", department: "mineshaft", level: 18)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.recommendedManagers.contains("Mark"))
        #expect(result.recommendedManagers.contains("Mrs. Goodman"))
    }
    
    // MARK: - Elevator Priority Tests
    
    @Test("Damian Jones scores highest for elevator")
    func testElevatorPriority() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Damian Jones", department: "elevator", level: 10, activeMultiplier: 6.4),
            makeManager(name: "Lee Vatori", department: "elevator", level: 20, activeMultiplier: 6.2),
            makeManager(name: "Freesia", department: "elevator", level: 25, activeMultiplier: 6.0)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        // Damian should be first due to priority
        let elevatorManagers = result.recommendedManagers.filter { name in
            roster.contains { sm in
                (sm.directoryMatch?.name ?? sm.resolvedName) == name &&
                sm.directoryMatch?.department == "elevator"
            }
        }
        #expect(elevatorManagers.first == "Damian Jones")
    }
    
    // MARK: - Mineshaft Priority Tests
    
    @Test("H4V0C, Freesia, Thalia score highest for mineshaft")
    func testMineshaftPriority() {
        let roster: [RecognizedSM] = [
            makeManager(name: "H4V0C", department: "mineshaft", level: 10, activeMultiplier: 7.0),
            makeManager(name: "Freesia", department: "elevator", level: 10, activeMultiplier: 6.0),
            makeManager(name: "Thalia", department: "mineshaft", level: 10, activeMultiplier: 7.5),
            makeManager(name: "Cliff Walker", department: "mineshaft", level: 20, activeMultiplier: 5.0),
            makeManager(name: "Chris Capella", department: "mineshaft", level: 20, activeMultiplier: 6.8)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        let mineshaftManagers = result.recommendedManagers.filter { name in
            roster.contains { sm in
                (sm.directoryMatch?.name ?? sm.resolvedName) == name &&
                (sm.directoryMatch?.department == "mineshaft" || name == "Freesia")
            }
        }
        
        #expect(mineshaftManagers.contains("H4V0C"))
        #expect(mineshaftManagers.contains("Thalia"))
        #expect(mineshaftManagers.contains("Freesia"))
    }
    
    // MARK: - Synergy Tests
    
    @Test("Synergy bonus increases manager score")
    func testSynergyBonus() {
        // Edmund + Lee Vatori have synergy
        let rosterWithSynergy: [RecognizedSM] = [
            makeManager(name: "Mr. Edmund", department: "warehouse", level: 10, activeMultiplier: 2.5),
            makeManager(name: "Lee Vatori", department: "elevator", level: 10, activeMultiplier: 6.2),
            makeManager(name: "Mark", department: "warehouse", level: 10, activeMultiplier: 5.24)
        ]
        
        let result = AIStrategyEngine.generate(from: rosterWithSynergy)
        
        // Both Edmund and Lee should be selected due to synergy
        #expect(result.recommendedManagers.contains("Mr. Edmund"))
        #expect(result.recommendedManagers.contains("Lee Vatori"))
    }
    
    // MARK: - Fallback Strategy Tests
    
    @Test("Empty roster generates fallback message")
    func testEmptyRoster() {
        let roster: [RecognizedSM] = []
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.strategySummary.contains("No managers available"))
    }
    
    @Test("Incomplete roster with no priority managers generates fallback")
    func testIncompleteRosterFallback() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Chester", department: "mineshaft", level: 15),
            makeManager(name: "Mark", department: "warehouse", level: 10)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        // Should generate a basic strategy, but may include fallback guidance
        #expect(!result.strategySummary.isEmpty)
    }
    
    @Test("Missing mineshaft generates fallback strategy")
    func testMissingMineshaft() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Damian Jones", department: "elevator", level: 20),
            makeManager(name: "Mr. Edmund", department: "warehouse", level: 20)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.strategySummary.contains("Fallback") || result.strategySummary.contains("focus on"))
    }
    
    // MARK: - Level Bonus Tests
    
    @Test("Higher level managers get scoring bonus")
    func testLevelBonus() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Chester", department: "mineshaft", level: 30, activeMultiplier: 4.0),
            makeManager(name: "Cliff Walker", department: "mineshaft", level: 10, activeMultiplier: 5.0)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        // Chester should potentially rank higher despite lower base boost due to level
        #expect(result.recommendedManagers.contains("Chester"))
    }
    
    // MARK: - Multiplier Estimation Tests
    
    @Test("Estimated multiplier is calculated from managers")
    func testMultiplierEstimation() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Thalia", department: "mineshaft", level: 30, activeMultiplier: 7.5),
            makeManager(name: "Mr. Edmund", department: "warehouse", level: 25, activeMultiplier: 7.5),
            makeManager(name: "Damian Jones", department: "elevator", level: 20, activeMultiplier: 6.4)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.estimatedMultiplier != nil)
        #expect(result.estimatedMultiplier! > 0)
    }
    
    @Test("Empty roster returns nil multiplier")
    func testNilMultiplierForEmptyRoster() {
        let roster: [RecognizedSM] = []
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.estimatedMultiplier == nil)
    }
    
    // MARK: - Building Assignment Tests
    
    @Test("Strategy summary includes building assignments")
    func testBuildingAssignments() {
        let roster: [RecognizedSM] = [
            makeManager(name: "H4V0C", department: "mineshaft", level: 20),
            makeManager(name: "Damian Jones", department: "elevator", level: 20),
            makeManager(name: "Mr. Edmund", department: "warehouse", level: 20)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.strategySummary.contains("Mineshaft:"))
        #expect(result.strategySummary.contains("Elevator:"))
        #expect(result.strategySummary.contains("Warehouse:"))
    }
    
    // MARK: - H4V0C Specific Tests
    
    @Test("H4V0C without full combo generates appropriate macro")
    func testH4V0CPartialCombo() {
        let roster: [RecognizedSM] = [
            makeManager(name: "H4V0C", department: "mineshaft", level: 25),
            makeManager(name: "Cliff Walker", department: "mineshaft", level: 20),
            makeManager(name: "Lee Vatori", department: "elevator", level: 18),
            makeManager(name: "Mark", department: "warehouse", level: 15)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.strategySummary.contains("H4V0C"))
        #expect(result.strategySummary.contains("3m") || result.strategySummary.contains("multiply"))
    }
    
    // MARK: - Combo Name Tests
    
    @Test("Damian without Edmund generates Damian Elevator Rush")
    func testDamianComboName() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Damian Jones", department: "elevator", level: 25),
            makeManager(name: "Chris Capella", department: "mineshaft", level: 20),
            makeManager(name: "Mark", department: "warehouse", level: 15)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.comboName == "Damian Elevator Rush")
    }
    
    @Test("H4V0C + Freesia without Thalia generates H4V0C Multiplier Combo")
    func testH4V0CFreesiaComboName() {
        let roster: [RecognizedSM] = [
            makeManager(name: "H4V0C", department: "mineshaft", level: 25),
            makeManager(name: "Freesia", department: "elevator", level: 22),
            makeManager(name: "Lee Vatori", department: "elevator", level: 18),
            makeManager(name: "Mark", department: "warehouse", level: 15)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.comboName == "H4V0C Multiplier Combo")
    }
    
    @Test("No priority combos generates Custom Strategy")
    func testCustomStrategyName() {
        let roster: [RecognizedSM] = [
            makeManager(name: "Chester", department: "mineshaft", level: 20),
            makeManager(name: "Lee Vatori", department: "elevator", level: 18),
            makeManager(name: "Mark", department: "warehouse", level: 15)
        ]
        
        let result = AIStrategyEngine.generate(from: roster)
        
        #expect(result.comboName == "Custom Strategy")
    }
}
