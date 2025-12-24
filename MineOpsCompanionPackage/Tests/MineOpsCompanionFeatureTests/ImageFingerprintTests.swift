import Testing
import UIKit
@testable import MineOpsCompanionFeature

private func repoRootURL_ForFingerprintTests() -> URL {
    let testFile = URL(fileURLWithPath: #filePath)
    let testsDir = testFile.deletingLastPathComponent()
    let packageTestsDir = testsDir.deletingLastPathComponent()
    let packageDir = packageTestsDir.deletingLastPathComponent()
    let repoRoot = packageDir.deletingLastPathComponent()
    return repoRoot
}

private func loadExampleScreenshots_ForFingerprintTests(limit: Int = 4) -> [UIImage] {
    let dir = repoRootURL_ForFingerprintTests().appendingPathComponent("Docs/Example_ScreenShots", isDirectory: true)
    guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }

    let pngs = urls
        .filter { $0.pathExtension.lowercased() == "png" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .prefix(limit)

    return pngs.compactMap { UIImage(contentsOfFile: $0.path) }
}

@Test("Example screenshots produce stable, mostly-unique image fingerprints")
func exampleScreenshotsFingerprints() {
    let images = loadExampleScreenshots_ForFingerprintTests(limit: 4)
    #require(images.count == 4)

    let fingerprints = images.compactMap { ImageHasher.fingerprint(for: $0) }
    #require(fingerprints.count == 4)

    // pixelDigest should be present (SHA256 of quantized pixels).
    #expect(fingerprints.allSatisfy { $0.pixelDigest != nil })

    let uniquePixelDigests = Set(fingerprints.compactMap(
        .pixelDigest
    ))

    // We expect these example screenshots to not all collapse to one digest.
    #expect(uniquePixelDigests.count >= 2)
}
