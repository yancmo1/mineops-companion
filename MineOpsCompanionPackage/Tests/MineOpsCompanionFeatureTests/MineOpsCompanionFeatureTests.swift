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
