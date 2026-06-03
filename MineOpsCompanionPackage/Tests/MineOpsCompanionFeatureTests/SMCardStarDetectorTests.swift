import Testing
import UIKit
@testable import MineOpsCompanionFeature

private func repoRootURL_ForStarDetectorTests() -> URL {
    let testFile = URL(fileURLWithPath: #filePath)
    let testsDir = testFile.deletingLastPathComponent()
    let packageTestsDir = testsDir.deletingLastPathComponent()
    let packageDir = packageTestsDir.deletingLastPathComponent()
    return packageDir.deletingLastPathComponent()
}

private func loadScreenshot_ForStarDetectorTests(_ name: String) -> UIImage? {
    let url = repoRootURL_ForStarDetectorTests()
        .appendingPathComponent("Docs/Example_ScreenShots", isDirectory: true)
        .appendingPathComponent(name)
    return UIImage(contentsOfFile: url.path)
}

@Suite
struct SMCardStarDetectorTests {
    @Test("Detects filled stars from screenshot examples")
    func detectsFilledStars() {
        let fixtures: [(String, Int)] = [
            ("IMG_9619.PNG", 0), // Luxario: all brown stars
            ("IMG_9620.PNG", 2), // Mr. Turner: 2 yellow stars
            ("IMG_9621.PNG", 1), // Blingsley: 1 yellow star
        ]

        for (fileName, expectedStars) in fixtures {
            guard let image = loadScreenshot_ForStarDetectorTests(fileName) else {
                Issue.record("Missing fixture image: \(fileName)")
                continue
            }

            let detected = SMCardStarDetector.detectStars(in: image)
            #expect(detected == expectedStars, "\(fileName) expected \(expectedStars) stars, got \(String(describing: detected))")
        }
    }
}
