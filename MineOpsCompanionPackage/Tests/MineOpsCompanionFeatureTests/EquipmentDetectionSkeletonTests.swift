import Testing
import UIKit
@testable import MineOpsCompanionFeature

private func repoRootURL() -> URL {
    // .../MineOpsCompanionPackage/Tests/MineOpsCompanionFeatureTests/<this file>
    // -> repo root is 3 levels up from MineOpsCompanionPackage.
    let testFile = URL(fileURLWithPath: #filePath)
    let testsDir = testFile.deletingLastPathComponent()
    let packageTestsDir = testsDir.deletingLastPathComponent()
    let packageDir = packageTestsDir.deletingLastPathComponent()
    let repoRoot = packageDir.deletingLastPathComponent()
    return repoRoot
}

private func loadExampleScreenshots(limit: Int = 3) -> [UIImage] {
    let dir = repoRootURL().appendingPathComponent("Docs/Example_ScreenShots", isDirectory: true)
    guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }

    let pngs = urls
        .filter { $0.pathExtension.lowercased() == "png" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .prefix(limit)

    return pngs.compactMap { UIImage(contentsOfFile: $0.path) }
}

@Test("Equipment skeleton returns unknown slots for example screenshots")
func equipmentDetectorReturnsUnknown() {
    let images = loadExampleScreenshots()
    #expect(!images.isEmpty)

    let regions = SMEquipmentSlotRegions.default
    for region in regions.regions {
        #expect(region.isValid)
    }

    for image in images {
        let detected = EquipmentDetector.detect(in: image, regions: regions)
        #expect(detected.slots.count == SMEquipmentSlot.allCases.count)

        for slot in detected.slots {
            switch slot.kind {
            case .unknown:
                #expect(true)
            case .detected:
                // Skeleton should not be confidently detecting yet.
                #expect(false)
            }
        }
    }
}
