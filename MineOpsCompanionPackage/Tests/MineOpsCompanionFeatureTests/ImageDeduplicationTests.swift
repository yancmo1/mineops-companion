import Testing
import UIKit
@testable import MineOpsCompanionFeature

@Suite("Image Deduplication")
struct ImageDeduplicationTests {

    @MainActor
    @Test("Identical screenshots are treated as duplicates")
    func identicalImagesAreDuplicates() throws {
        let image = try Self.makeTestCard(text: "Alpha")
        guard let first = ImageHasher.fingerprint(for: image),
              let second = ImageHasher.fingerprint(for: image) else {
            throw TestError.fingerprintFailed
        }

        let store = ImageHashStore(storage: .inMemory)
        #expect(store.isDuplicate(first) == false)
        store.add(first)
        #expect(store.isDuplicate(second))
    }

    @MainActor
    @Test("Different cards no longer collide")
    func distinctCardsAreNotDuplicates() throws {
        let alpha = try Self.makeTestCard(text: "Alpha")
        let beta = try Self.makeTestCard(text: "Beta")

        guard let first = ImageHasher.fingerprint(for: alpha),
              let second = ImageHasher.fingerprint(for: beta) else {
            throw TestError.fingerprintFailed
        }

        #expect(first.pixelDigest != nil)
        #expect(second.pixelDigest != nil)
        #expect(first.pixelDigest != second.pixelDigest)

        let store = ImageHashStore(storage: .inMemory)
        store.add(first)
        #expect(store.isDuplicate(second) == false)
    }

    private enum TestError: Error {
        case imageCreationFailed
        case fingerprintFailed
    }

    @MainActor
    private static func makeTestCard(text: String) throws -> UIImage {
        let size = CGSize(width: 400, height: 600)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        defer { UIGraphicsEndImageContext() }

        UIColor.darkGray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        let titleRect = CGRect(x: 40, y: 60, width: size.width - 80, height: 80)
        let bodyRect = CGRect(x: 40, y: 180, width: size.width - 80, height: 260)

        UIColor.orange.setFill()
        UIRectFill(titleRect)
        UIColor.white.set()
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 48),
            .foregroundColor: UIColor.black
        ]
        NSString(string: text).draw(in: titleRect.insetBy(dx: 10, dy: 10), withAttributes: titleAttributes)

        UIColor.black.setFill()
        UIRectFill(bodyRect)
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32),
            .foregroundColor: UIColor.white
        ]
        NSString(string: "Passive Bonus: +15%\nDuration: 30s\nCooldown: 60s").draw(in: bodyRect.insetBy(dx: 16, dy: 16), withAttributes: bodyAttributes)

        guard let rendered = UIGraphicsGetImageFromCurrentImageContext() else {
            throw TestError.imageCreationFailed
        }
        return rendered
    }
}
