import Testing
import UIKit
@testable import MineOpsCompanionFeature

@Test("OCRProcessor starts empty")
@MainActor
func ocrProcessorStartsEmpty() {
    let processor = OCRProcessor()
    #expect(processor.results.isEmpty)
}
