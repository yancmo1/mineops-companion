import Testing
import UIKit
@testable import MineOpsCompanionFeature

private func makeTempContainerURL() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("MineOpsCompanionTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeDirectoryEntry(id: String = "blingsley", name: String = "Bling") throws -> SMDirectoryEntry {
    let json = """
    {
      "id": "\(id)",
      "name": "\(name)",
      "department": "mineshaft",
      "rarity": "epic"
    }
    """
    let data = try #require(json.data(using: .utf8))
    return try JSONDecoder().decode(SMDirectoryEntry.self, from: data)
}

@Test("Re-import preserves user metadata edits")
@MainActor
func reimportPreservesUserMetadataEdits() throws {
    let persistence = Persistence.makeForTesting(containerURL: makeTempContainerURL())
    let review = OCRReviewViewModel(persistence: persistence)

    let entry = try makeDirectoryEntry()

    let original = RecognizedSM(
        sourceImage: UIImage(),
        rawText: "old",
        level: 1,
        directoryMatch: entry,
        resolvedName: "Bling",
        stats: SMStats(),
        rarity: "Epic",
        role: "Mineshaft",
        stars: 3,
        active: .init(effect: "Boost", multiplier: 1.2, durationSeconds: 60, cooldownSeconds: 120),
        passive: .init(effect: "Passive", multiplier: 1.1, durationSeconds: 30, unlockedSlots: [true, false, true]),
        actions: .init(hasLevelUp: false, hasPromote: false, hasRankUp: false)
    )

    review.replace(with: [original])

    let edited = original.updatingMetadata(
        resolvedName: "Bling (Custom)",
        rarity: original.rarity,
        role: "Warehouse",
        stars: 4,
        fragments: original.fragments,
        active: original.active,
        passive: original.passive,
        actions: original.actions
    )

    review.update(original, with: edited)

    let updatedStats = SMStats(level: .init(current: 10, total: 20))

    let incoming = RecognizedSM(
        sourceImage: UIImage(),
        rawText: "new",
        level: 10,
        directoryMatch: entry,
        resolvedName: "Bling",
        stats: updatedStats,
        active: original.active,
        passive: original.passive,
        actions: original.actions
    )

    review.replace(with: [incoming])

    let final = try #require(review.recognized.first)
    #expect(final.level == 10)
    #expect(final.stats == updatedStats)

    // User edits should win.
    #expect(final.resolvedName == "Bling (Custom)")
    #expect(final.role == "Warehouse")
    #expect(final.stars == 4)

    // Passive unlock-slot detection should not be lost.
    #expect(final.passive.unlockedSlots == [true, false, true])
}

@Test("Re-import does not mark unchanged records as updated")
@MainActor
func reimportDoesNotMarkUnchangedAsUpdated() throws {
    let persistence = Persistence.makeForTesting(containerURL: makeTempContainerURL())
    let review = OCRReviewViewModel(persistence: persistence)

    let entry = try makeDirectoryEntry()

    let stats = SMStats(level: .init(current: 1, total: 10))

    let original = RecognizedSM(
        sourceImage: UIImage(),
        rawText: "old",
        level: 1,
        directoryMatch: entry,
        resolvedName: "Bling",
        stats: stats,
        active: .init(effect: "Boost", multiplier: 1.2, durationSeconds: 60, cooldownSeconds: 120),
        passive: .init(effect: "Passive", multiplier: 1.1, durationSeconds: 30, unlockedSlots: [true, false, true]),
        actions: .init(hasLevelUp: false, hasPromote: false, hasRankUp: false)
    )

    review.replace(with: [original])

    // Incoming differs only in rawText/sourceImage; meaningful fields are the same.
    let incomingSame = RecognizedSM(
        sourceImage: UIImage(),
        rawText: "different ocr text",
        level: 1,
        directoryMatch: entry,
        resolvedName: "Bling",
        stats: stats,
        active: original.active,
        passive: original.passive,
        actions: original.actions
    )

    let mergeResult = review.replaceAndTrackChanges(with: [incomingSame])
    #expect(mergeResult.newImports.isEmpty)
    #expect(mergeResult.updates.isEmpty)
    #expect(mergeResult.unchanged.count == 1)

    let final = try #require(review.recognized.first)
    #expect(final.rawText == "old")
}
