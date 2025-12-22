@testable import MineOpsCompanionFeature
import Foundation
import Testing

@Suite("SM Directory Validation")
struct SMDirectoryValidationTests {
    
    // MARK: - Test Data Loading
    
    @Test("sm_directory.json loads successfully")
    func directoryLoads() throws {
        let entries = try SMDirectory.load()
        #expect(!entries.isEmpty, "Directory should contain at least one manager")
    }
    
    // MARK: - ID Validation
    
    @Test("All SM IDs are unique")
    func allIdsAreUnique() throws {
        let entries = try SMDirectory.load()
        let ids = entries.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count, "Found duplicate IDs: \(ids.filter { id in ids.filter { $0 == id }.count > 1 })")
    }
    
    @Test("All SM IDs are valid slugs (lowercase, no spaces)")
    func allIdsAreValidSlugs() throws {
        let entries = try SMDirectory.load()
        for entry in entries {
            #expect(!entry.id.contains(" "), "ID '\(entry.id)' contains spaces")
            #expect(entry.id == entry.id.lowercased(), "ID '\(entry.id)' is not lowercase")
            #expect(!entry.id.contains("."), "ID '\(entry.id)' contains periods")
        }
    }
    
    // MARK: - Department Validation
    
    @Test("All departments are valid (mineshaft, elevator, warehouse)")
    func allDepartmentsAreValid() throws {
        let validDepartments = Set(["mineshaft", "elevator", "warehouse"])
        let entries = try SMDirectory.load()
        
        for entry in entries {
            #expect(
                validDepartments.contains(entry.department),
                "Invalid department '\(entry.department)' for SM '\(entry.name)'. Expected one of: \(validDepartments)"
            )
        }
    }
    
    // MARK: - Rarity Validation
    
    @Test("All rarities are valid (common, rare, epic, legendary)")
    func allRaritiesAreValid() throws {
        let validRarities = Set(["common", "rare", "epic", "legendary"])
        let entries = try SMDirectory.load()
        
        for entry in entries {
            #expect(
                validRarities.contains(entry.rarity),
                "Invalid rarity '\(entry.rarity)' for SM '\(entry.name)'. Expected one of: \(validRarities)"
            )
        }
    }
    
    // MARK: - Element Validation
    
    @Test("All elements are valid")
    func allElementsAreValid() throws {
        let validElements = Set(["Nature", "Water", "Sand", "Flame", "Frost", "Light", "Dark", "Wind"])
        let entries = try SMDirectory.load()
        
        for entry in entries {
            guard let elements = entry.elements else { continue }
            for element in elements {
                #expect(
                    validElements.contains(element),
                    "Invalid element '\(element)' for SM '\(entry.name)'. Expected one of: \(validElements)"
                )
            }
        }
    }
    
    @Test("Element count matches rarity (common=1, rare=2, epic/legendary=3)")
    func elementCountMatchesRarity() throws {
        let entries = try SMDirectory.load()
        
        for entry in entries {
            guard let elements = entry.elements else { continue }
            
            let expectedCount: Int
            switch entry.rarity {
            case "common":
                expectedCount = 1
            case "rare":
                expectedCount = 2
            case "epic", "legendary":
                expectedCount = 3
            default:
                continue
            }
            
            #expect(
                elements.count == expectedCount,
                "SM '\(entry.name)' (\(entry.rarity)) has \(elements.count) elements, expected \(expectedCount)"
            )
        }
    }
    
    // MARK: - Active Ability Validation
    
    @Test("Active abilities have valid durations and cooldowns")
    func activeAbilitiesHaveValidTiming() throws {
        let entries = try SMDirectory.load()
        
        for entry in entries {
            guard let active = entry.active else { continue }
            
            #expect(active.durationSeconds > 0, "SM '\(entry.name)' has invalid duration: \(active.durationSeconds)")
            #expect(active.cooldownSeconds > 0, "SM '\(entry.name)' has invalid cooldown: \(active.cooldownSeconds)")
            #expect(
                active.cooldownSeconds >= active.durationSeconds,
                "SM '\(entry.name)' has cooldown (\(active.cooldownSeconds)s) shorter than duration (\(active.durationSeconds)s)"
            )
        }
    }
    
    @Test("Active multipliers are positive")
    func activeMultipliersArePositive() throws {
        let entries = try SMDirectory.load()
        
        for entry in entries {
            guard let active = entry.active, let multiplier = active.multiplier else { continue }
            #expect(multiplier > 0, "SM '\(entry.name)' has non-positive multiplier: \(multiplier)")
        }
    }
    
    // MARK: - Coverage Tests
    
    @Test("Directory contains expected SM count (at least 30)")
    func directoryHasExpectedCount() throws {
        let entries = try SMDirectory.load()
        #expect(entries.count >= 30, "Expected at least 30 SMs, found \(entries.count)")
    }
    
    @Test("Directory has all rarity tiers represented")
    func allRaritiesRepresented() throws {
        let entries = try SMDirectory.load()
        let rarities = Set(entries.map { $0.rarity })
        
        #expect(rarities.contains("common"), "Missing common SMs")
        #expect(rarities.contains("rare"), "Missing rare SMs")
        #expect(rarities.contains("epic"), "Missing epic SMs")
        #expect(rarities.contains("legendary"), "Missing legendary SMs")
    }
    
    @Test("Directory has all departments represented")
    func allDepartmentsRepresented() throws {
        let entries = try SMDirectory.load()
        let departments = Set(entries.map { $0.department })
        
        #expect(departments.contains("mineshaft"), "Missing mineshaft SMs")
        #expect(departments.contains("elevator"), "Missing elevator SMs")
        #expect(departments.contains("warehouse"), "Missing warehouse SMs")
    }
    
    // MARK: - Known SM Validation
    
    @Test("Key SMs exist with correct IDs")
    func keySMsExist() throws {
        let entries = try SMDirectory.load()
        let ids = Set(entries.map { $0.id })
        
        // Common
        #expect(ids.contains("chester"), "Missing Chester")
        #expect(ids.contains("gordon"), "Missing Gordon")
        #expect(ids.contains("mark"), "Missing Mark")
        #expect(ids.contains("lee_vatori"), "Missing Lee Vatori")
        
        // Rare
        #expect(ids.contains("blingsley"), "Missing Blingsley")
        #expect(ids.contains("sir_henry"), "Missing Sir Henry")
        #expect(ids.contains("mr_turner"), "Missing Mr. Turner")
        #expect(ids.contains("damian_jones"), "Missing Damian Jones")
        #expect(ids.contains("zi_galvani"), "Missing Zi Galvani")
        #expect(ids.contains("chris_capella"), "Missing Chris Capella")
        
        // Epic
        #expect(ids.contains("dr_steiner"), "Missing Dr. Steiner")
        #expect(ids.contains("dr_lilly"), "Missing Dr. Lilly")
        #expect(ids.contains("jade_kim"), "Missing Jade Kim")
        
        // Legendary
        #expect(ids.contains("sir_lorenzo"), "Missing Sir Lorenzo")
        #expect(ids.contains("luna_stella"), "Missing Luna & Stella")
        #expect(ids.contains("h4v0c"), "Missing H4V0C")
    }
}
