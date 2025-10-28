import Testing
import UIKit
@testable import MineOpsCompanionFeature

@Test("OCRProcessor starts empty")
@MainActor
func ocrProcessorStartsEmpty() {
    let processor = OCRProcessor()
    #expect(processor.results.isEmpty)
}

@Test("OCRResult stores parsed values")
func ocrResultStoresParsedValues() {
    let result = OCRResult(
        image: UIImage(),
        parsedName: "Test Manager",
        parsedLevel: 5,
        parsedBoost: 100.0,
        parsedBoostType: "Mine"
    )

    #expect(result.parsedName == "Test Manager")
    #expect(result.parsedLevel == 5)
    #expect(result.parsedBoost == 100.0)
    #expect(result.parsedBoostType == "Mine")
}

@Test("StrategyEngine handles empty input")
func strategyEngineHandlesEmptyInput() {
    let engine = StrategyEngine()
    let summary = engine.generateSummary(for: [])
    #expect(summary.contains("Top Super Managers by Boost:"))
}

@Test("StrategyEngine renders manager names and boosts")
func strategyEngineRendersManagerDetails() {
    let engine = StrategyEngine()
    let managers = [
        OCRResult(image: UIImage(), parsedName: "Manager A", parsedLevel: 10, parsedBoost: 500, parsedBoostType: "Mine"),
        OCRResult(image: UIImage(), parsedName: "Manager B", parsedLevel: 8, parsedBoost: 300, parsedBoostType: "Warehouse")
    ]

    let summary = engine.generateSummary(for: managers)
    #expect(summary.contains("Manager A"))
    #expect(summary.contains("Manager B"))
    #expect(summary.contains("500%"))
    #expect(summary.contains("300%"))
}
