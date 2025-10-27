import XCTest
@testable import MineOpsCompanion

final class OCRTests: XCTestCase {
    func testOCRProcessorInitialization() {
        let processor = OCRProcessor()
        XCTAssertNotNil(processor)
        XCTAssertEqual(processor.results.count, 0)
    }
    
    func testOCRResultCreation() {
        let result = OCRResult(
            image: UIImage(),
            parsedName: "Test Manager",
            parsedLevel: 5,
            parsedBoost: 100.0,
            parsedBoostType: "Mine"
        )
        XCTAssertEqual(result.parsedName, "Test Manager")
        XCTAssertEqual(result.parsedLevel, 5)
        XCTAssertEqual(result.parsedBoost, 100.0)
        XCTAssertEqual(result.parsedBoostType, "Mine")
    }
}
