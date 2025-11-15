import Testing
import UIKit
@testable import MineOpsCompanionFeature

@Suite
@MainActor
struct StrategySummaryViewModelTests {
  
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
  
  @Test("ViewModel initializes with default values")
  func viewModelInitializesWithDefaults() {
    let viewModel = StrategySummaryViewModel()
    #expect(viewModel.strategyText == "No data yet.")
    #expect(viewModel.burstSteps.isEmpty)
  }
  
  @Test("ViewModel updates text and burstSteps when generating strategy")
  func viewModelUpdatesTextAndBurstSteps() {
    let viewModel = StrategySummaryViewModel()
    
    let roster: [RecognizedSM] = [
      mockManager(id: "damian_jones", name: "Damian Jones", department: "elevator"),
      mockManager(id: "thalia", name: "Thalia", department: "mineshaft"),
      mockManager(id: "mr_edmund", name: "Mr. Edmund", department: "warehouse")
    ]
    
    viewModel.generate(from: roster)
    
    #expect(viewModel.strategyText != "No data yet.")
    #expect(!viewModel.strategyText.isEmpty)
    #expect(!viewModel.burstSteps.isEmpty)
  }
  
  @Test("ViewModel can generate when all departments present")
  func canGenerateWithAllDepartments() {
    let viewModel = StrategySummaryViewModel()
    
    let roster: [RecognizedSM] = [
      mockManager(id: "damian_jones", name: "Damian Jones", department: "elevator"),
      mockManager(id: "thalia", name: "Thalia", department: "mineshaft"),
      mockManager(id: "mr_edmund", name: "Mr. Edmund", department: "warehouse")
    ]
    
    #expect(viewModel.canGenerate(from: roster) == true)
  }
  
  @Test("ViewModel cannot generate when missing departments")
  func cannotGenerateWithMissingDepartments() {
    let viewModel = StrategySummaryViewModel()
    
    let roster: [RecognizedSM] = [
      mockManager(id: "damian_jones", name: "Damian Jones", department: "elevator")
    ]
    
    #expect(viewModel.canGenerate(from: roster) == false)
  }
  
  @Test("ViewModel generates empty burstSteps for incomplete roster")
  func generatesEmptyBurstStepsForIncompleteRoster() {
    let viewModel = StrategySummaryViewModel()
    
    let roster: [RecognizedSM] = []
    
    viewModel.generate(from: roster)
    
    #expect(viewModel.burstSteps.isEmpty)
  }
  
  @Test("ViewModel preserves burstSteps count from engine")
  func preservesBurstStepsCountFromEngine() {
    let viewModel = StrategySummaryViewModel()
    
    let roster: [RecognizedSM] = [
      mockManager(id: "damian_jones", name: "Damian Jones", department: "elevator"),
      mockManager(id: "thalia", name: "Thalia", department: "mineshaft"),
      mockManager(id: "h4v0c", name: "H4V0C", department: "mineshaft"),
      mockManager(id: "mr_edmund", name: "Mr. Edmund", department: "warehouse"),
      mockManager(id: "mr_turner", name: "Mr. Turner", department: "mineshaft"),
      mockManager(id: "mark", name: "Mark", department: "warehouse")
    ]
    
    viewModel.generate(from: roster)
    
    #expect(viewModel.burstSteps.count == 6)
  }
}
