import XCTest
@testable import MineOpsCompanion

final class StrategyEngineTests: XCTestCase {
    func testStrategyEngineInitialization() {
        let engine = StrategyEngine()
        XCTAssertNotNil(engine)
    }
    
    func testGenerateSummaryWithEmptyArray() {
        let engine = StrategyEngine()
        let summary = engine.generateSummary(for: [])
        XCTAssertTrue(summary.contains("Top Super Managers by Boost:"))
    }
    
    func testGenerateSummaryWithManagers() {
        let engine = StrategyEngine()
        let mockManagers = [
            OCRResult(image: UIImage(), parsedName: "Manager A", parsedLevel: 10, parsedBoost: 500, parsedBoostType: "Mine"),
            OCRResult(image: UIImage(), parsedName: "Manager B", parsedLevel: 8, parsedBoost: 300, parsedBoostType: "Warehouse")
        ]
        let summary = engine.generateSummary(for: mockManagers)
        XCTAssertTrue(summary.contains("Manager A"))
        XCTAssertTrue(summary.contains("Manager B"))
        XCTAssertTrue(summary.contains("500%"))
        XCTAssertTrue(summary.contains("300%"))
    }
}
