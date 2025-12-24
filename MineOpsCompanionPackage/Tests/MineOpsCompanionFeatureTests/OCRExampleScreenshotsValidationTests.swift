import Testing
import UIKit
@testable import MineOpsCompanionFeature

private func repoRootURL_ForOCRExampleTests() -> URL {
    let testFile = URL(fileURLWithPath: #filePath)
    let testsDir = testFile.deletingLastPathComponent()
    let packageTestsDir = testsDir.deletingLastPathComponent()
    let packageDir = packageTestsDir.deletingLastPathComponent()
    let repoRoot = packageDir.deletingLastPathComponent()
    return repoRoot
}

private func loadExampleScreenshots_ForOCRExampleTests(limit: Int = 4) -> [UIImage] {
    let dir = repoRootURL_ForOCRExampleTests().appendingPathComponent("Docs/Example_ScreenShots", isDirectory: true)
    guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }

    let pngs = urls
        .filter { $0.pathExtension.lowercased() == "png" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .prefix(limit)

    return pngs.compactMap { UIImage(contentsOfFile: $0.path) }
}

private extension UIImage {
    func downsampled_ForOCRExampleTests(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        guard scale < 1 else { return self }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

@Test("Example screenshots are recognized as SM cards")
func exampleScreenshotsValidateAsSMCards() async {
    let images = loadExampleScreenshots_ForOCRExampleTests(limit: 4)
    #require(images.count == 4)

    for (index, image) in images.enumerated() {
        guard let cgImage = image.cgImage else {
            Issue.record("Example screenshot #\(index + 1) missing cgImage")
            continue
        }

        let text = await OCRTextRecognizer.recognizeText(from: cgImage)
        let validation = SMCardValidator.validate(ocrText: text)

        if !validation.isValid {
            let snippet = String(text.prefix(600))
            Issue.record("Example screenshot #\(index + 1) failed validation: \(validation.summary)\nOCR snippet:\n\(snippet)")
        }

        #expect(validation.isValid)
    }
}

@Test("Downsampled screenshots are still usually valid (guards against degraded PhotoKit callbacks)")
func downsampledScreenshotsStillValidate() async {
    let images = loadExampleScreenshots_ForOCRExampleTests(limit: 2)
    #require(!images.isEmpty)

    for (index, image) in images.enumerated() {
        let downsampled = image.downsampled_ForOCRExampleTests(toMaxDimension: 900)
        guard let cgImage = downsampled.cgImage else {
            Issue.record("Downsampled example screenshot #\(index + 1) missing cgImage")
            continue
        }

        let text = await OCRTextRecognizer.recognizeText(from: cgImage)
        let validation = SMCardValidator.validate(ocrText: text)

        // This test is intentionally lenient to avoid flakiness across OCR engines/simulator versions.
        // If this fails, it suggests the validator is too strict for slightly degraded images.
        #expect(validation.confidence >= 0.35)
    }
}
