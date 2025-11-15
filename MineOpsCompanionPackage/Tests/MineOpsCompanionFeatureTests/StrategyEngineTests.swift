import Testing
import UIKit
@testable import MineOpsCompanionFeature

@Suite
struct StrategyEngineTests {
  
  // Helper to create a mock RecognizedSM with directory match
  func mockManager(id: String, name: String, department: String) -> RecognizedSM {
    let directoryEntry = SMDirectoryEntry(
      id: id,
      name: name,
      department: department,
      rarity: "Rare",
      active: nil,
      passives: nil,
      aliases: nil,
      notes: nil
    )
    
    return RecognizedSM(
      sourceImage: UIImage(),
      rawText: name,
      level: 10,
      directoryMatch: directoryEntry,
      resolvedName: name,
      stats: SMStats(rawText: "", multipliersDescending: [], percentNumberValues: [])
    )
  }
  
  @Test("Empty roster returns empty burst steps")
  func emptyRosterReturnsEmptyBurstSteps() {
    let summary = StrategyEngine.generate(from: [])
    #expect(summary.burstSteps.isEmpty)
    #expect(summary.text.contains("Need at least one of"))
  }
  
  @Test("Full roster generates complete burst macro")
  func fullRosterGeneratesCompleteBurstMacro() {
    let roster: [RecognizedSM] = [
      mockManager(id: "damian_jones", name: "Damian Jones", department: "elevator"),
      mockManager(id: "thalia", name: "Thalia", department: "mineshaft"),
      mockManager(id: "h4v0c", name: "H4V0C", department: "mineshaft"),
      mockManager(id: "mr_edmund", name: "Mr. Edmund", department: "warehouse"),
      mockManager(id: "mr_turner", name: "Mr. Turner", department: "mineshaft"),
      mockManager(id: "mark", name: "Mark", department: "warehouse")
    ]
    
    let summary = StrategyEngine.generate(from: roster)
    
    // Should have 6 steps
    #expect(summary.burstSteps.count == 6)
    
    // Verify step order
    #expect(summary.burstSteps[0].order == 1)
    #expect(summary.burstSteps[1].order == 2)
    #expect(summary.burstSteps[2].order == 3)
    #expect(summary.burstSteps[3].order == 4)
    #expect(summary.burstSteps[4].order == 5)
    #expect(summary.burstSteps[5].order == 6)
    
    // Verify managers
    #expect(summary.burstSteps[0].managerName == "Damian Jones")
    #expect(summary.burstSteps[1].managerName == "Thalia")
    #expect(summary.burstSteps[2].managerName == "H4V0C")
    #expect(summary.burstSteps[3].managerName == "Mr. Edmund")
    #expect(summary.burstSteps[4].managerName == "Mr. Turner")
    #expect(summary.burstSteps[5].managerName == "Mark")
    
    // Verify roles
    #expect(summary.burstSteps[0].role == "Elevator")
    #expect(summary.burstSteps[1].role == "Mineshaft")
    #expect(summary.burstSteps[2].role == "Mineshaft")
    #expect(summary.burstSteps[3].role == "Warehouse")
    #expect(summary.burstSteps[4].role == "Mineshaft")
    #expect(summary.burstSteps[5].role == "Warehouse")
    
    // Verify timing
    #expect(summary.burstSteps[0].startOffsetSeconds == 0)
    #expect(summary.burstSteps[0].durationSeconds == 300)
    #expect(summary.burstSteps[3].startOffsetSeconds == 90)
    #expect(summary.burstSteps[3].durationSeconds == 120)
  }
  
  @Test("Partial roster generates partial burst macro")
  func partialRosterGeneratesPartialBurstMacro() {
    let roster: [RecognizedSM] = [
      mockManager(id: "damian_jones", name: "Damian Jones", department: "elevator"),
      mockManager(id: "h4v0c", name: "H4V0C", department: "mineshaft")
    ]
    
    let summary = StrategyEngine.generate(from: roster)
    
    // Should have only 2 steps (Damian + H4V0C)
    #expect(summary.burstSteps.count == 2)
    #expect(summary.burstSteps[0].managerName == "Damian Jones")
    #expect(summary.burstSteps[1].managerName == "H4V0C")
  }
  
  @Test("Alternative elevator booster (Sojo) is used when Damian absent")
  func alternativeElevatorBoosterUsed() {
    let roster: [RecognizedSM] = [
      mockManager(id: "sojo", name: "Sojo", department: "elevator"),
      mockManager(id: "thalia", name: "Thalia", department: "mineshaft")
    ]
    
    let summary = StrategyEngine.generate(from: roster)
    
    #expect(summary.burstSteps.count == 2)
    #expect(summary.burstSteps[0].managerName == "Sojo")
    #expect(summary.burstSteps[0].title == "Prime Elevator")
  }
  
  @Test("Alternative mineshaft starter (Freesia) is used when Thalia absent")
  func alternativeMineshaftStarterUsed() {
    let roster: [RecognizedSM] = [
      mockManager(id: "damian_jones", name: "Damian Jones", department: "elevator"),
      mockManager(id: "freesia", name: "Freesia", department: "mineshaft")
    ]
    
    let summary = StrategyEngine.generate(from: roster)
    
    #expect(summary.burstSteps.count == 2)
    #expect(summary.burstSteps[1].managerName == "Freesia")
    #expect(summary.burstSteps[1].durationSeconds == 60)  // Freesia has 60s duration
  }
  
  @Test("Alternative warehouse filler (Al Titude) is used")
  func alternativeWarehouseFillerUsed() {
    let roster: [RecognizedSM] = [
      mockManager(id: "damian_jones", name: "Damian Jones", department: "elevator"),
      mockManager(id: "al_titude", name: "Al Titude", department: "warehouse")
    ]
    
    let summary = StrategyEngine.generate(from: roster)
    
    let fillerStep = summary.burstSteps.first { $0.order == 6 }
    #expect(fillerStep != nil)
    #expect(fillerStep?.managerName == "Al Titude")
    #expect(fillerStep?.title == "Al Titude Fill Cycle")
  }
  
  @Test("BurstStep has unique ID")
  func burstStepHasUniqueID() {
    let step1 = StrategyEngine.BurstStep(
      order: 1,
      title: "Test",
      managerName: "Manager",
      role: "Elevator",
      startOffsetSeconds: 0,
      durationSeconds: 60
    )
    let step2 = StrategyEngine.BurstStep(
      order: 1,
      title: "Test",
      managerName: "Manager",
      role: "Elevator",
      startOffsetSeconds: 0,
      durationSeconds: 60
    )
    
    #expect(step1.id != step2.id)
  }
  
  @Test("Summary includes both text and burstSteps")
  func summaryIncludesBothTextAndBurstSteps() {
    let roster: [RecognizedSM] = [
      mockManager(id: "damian_jones", name: "Damian Jones", department: "elevator"),
      mockManager(id: "mr_edmund", name: "Mr. Edmund", department: "warehouse")
    ]
    
    let summary = StrategyEngine.generate(from: roster)
    
    #expect(!summary.text.isEmpty)
    #expect(!summary.burstSteps.isEmpty)
    #expect(summary.text.contains("Damian"))
  }
}

// Extension to make SMDirectoryEntry initializable in tests
extension SMDirectoryEntry {
  init(id: String, name: String, department: String, rarity: String, active: Active?, passives: [Passive]?, aliases: [String]?, notes: String?) {
    self.id = id
    self.name = name
    self.department = department
    self.rarity = rarity
    self.active = active
    self.passives = passives
    self.aliases = aliases
    self.notes = notes
  }
}
