import Foundation
import Testing
import UIKit
@testable import MineOpsCompanionFeature

@Suite("SMTrackerImporter")
struct SMTrackerImporterTests {
    @Test("Import syncs canonical managers and preserves unknown entries")
    func importSyncsRoster() throws {
        let chester = try makeDirectoryEntry(id: "chester", name: "Chester", department: "mineshaft")
        let mark = try makeDirectoryEntry(id: "mark", name: "Mark", department: "warehouse")
        let turner = try makeDirectoryEntry(id: "mr_turner", name: "Mr. Turner", department: "elevator")

        let existingChester = RecognizedSM(
            sourceImage: UIImage(),
            rawText: "old chester",
            level: 1,
            directoryMatch: chester,
            resolvedName: "Chester Custom",
            stats: SMStats(
                level: .init(current: 1, total: 50),
                promotion: .init(current: 0, total: 5),
                percentValues: ["+15%"],
                multiplierValues: ["2x"],
                minuteDurations: [5, 30]
            ),
            stars: 0,
            fragments: 0
        )

        let existingTurner = RecognizedSM(
            sourceImage: UIImage(),
            rawText: "old turner",
            level: 10,
            directoryMatch: turner,
            resolvedName: "Mr. Turner",
            stats: SMStats(level: .init(current: 10, total: 50), promotion: .init(current: 1, total: 5)),
            stars: 1,
            fragments: 5
        )

        let unknown = RecognizedSM(
            sourceImage: UIImage(),
            rawText: "manual",
            level: 3,
            directoryMatch: nil,
            resolvedName: "Unmapped Hero",
            stats: SMStats(level: .init(current: 3, total: 50)),
            stars: 1
        )

        let data = try makePayload(overrides: [
            "chester": SMTrackerBackupEntry(
                unlocked: true,
                rank: 3,
                level: 27,
                promoted: 2,
                fragments: 11,
                chronoExcluded: true,
                tierlistExcluded: true
            ),
            "mark": SMTrackerBackupEntry(
                unlocked: true,
                rank: 2,
                level: 18,
                promoted: 1,
                fragments: 7,
                chronoExcluded: false,
                tierlistExcluded: true
            )
        ])

        let result = try SMTrackerImporter.importRecognized(
            from: data,
            existing: [existingChester, existingTurner, unknown],
            directory: [chester, mark, turner]
        )

        #expect(result.importedCount == 2)
        #expect(result.addedCount == 1)
        #expect(result.updatedCount == 1)
        #expect(result.removedCount == 1)
        #expect(result.recognized.count == 3)

        let syncedChester = try #require(result.recognized.first {
            SMTrackerExporter.trackerKey(forRecognized: $0) == "chester"
        })
        #expect(syncedChester.resolvedName == "Chester Custom")
        #expect(syncedChester.level == 27)
        #expect(syncedChester.stats.level?.current == 27)
        #expect(syncedChester.stats.promotion?.current == 2)
        #expect(syncedChester.stats.percentValues == ["+15%"])
        #expect(syncedChester.stats.multiplierValues == ["2x"])
        #expect(syncedChester.stats.minuteDurations == [5, 30])
        #expect(syncedChester.stars == 3)
        #expect(syncedChester.fragments == 11)
        #expect(syncedChester.chronoExcluded == true)
        #expect(syncedChester.tierlistExcluded == true)

        let syncedMark = try #require(result.recognized.first {
            SMTrackerExporter.trackerKey(forRecognized: $0) == "mark"
        })
        #expect(syncedMark.resolvedName == "Mark")
        #expect(syncedMark.level == 18)
        #expect(syncedMark.stats.level?.current == 18)
        #expect(syncedMark.stats.promotion?.current == 1)
        #expect(syncedMark.role == "warehouse")
        #expect(syncedMark.stars == 2)
        #expect(syncedMark.fragments == 7)
        #expect(syncedMark.tierlistExcluded == true)

        #expect(result.recognized.contains { $0.resolvedName == "Unmapped Hero" })
        #expect(result.recognized.contains {
            SMTrackerExporter.trackerKey(forRecognized: $0) == "mr-turner"
        } == false)
    }

    @Test("Import requires exact tracker key universe")
    func importValidatesSchema() throws {
        var payload = Dictionary(
            uniqueKeysWithValues: SMTrackerExporter.canonicalManagerKeys.map {
                ($0, SMTrackerBackupEntry.defaults)
            }
        )
        payload.removeValue(forKey: "chester")
        payload["totally-new-key"] = .defaults

        let data = try JSONEncoder().encode(payload)

        var caughtExpectedError = false
        do {
            _ = try SMTrackerImporter.importRecognized(from: data, existing: [], directory: [])
        } catch let error as SMTrackerImportError {
            caughtExpectedError = true
            switch error {
            case let .invalidSchema(missingKeys, extraKeys):
                #expect(missingKeys == ["chester"])
                #expect(extraKeys == ["totally-new-key"])
            }
        }
        #expect(caughtExpectedError)
    }

    @Test("Export includes imported exclusion flags")
    func exportIncludesImportedFlags() throws {
        let manager = RecognizedSM(
            sourceImage: UIImage(),
            rawText: "import",
            level: 9,
            directoryMatch: try makeDirectoryEntry(id: "chester", name: "Chester", department: "mineshaft"),
            resolvedName: "Chester",
            stats: SMStats(level: .init(current: 9, total: 50), promotion: .init(current: 1, total: 5)),
            stars: 2,
            fragments: 4,
            chronoExcluded: true,
            tierlistExcluded: true
        )

        let data = try SMTrackerExporter.makeExportData(from: [manager], directory: [])
        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])
        let chester = try #require(raw["chester"])

        #expect(chester["chronoExcluded"] as? Bool == true)
        #expect(chester["tierlistExcluded"] as? Bool == true)
    }

    private func makePayload(overrides: [String: SMTrackerBackupEntry]) throws -> Data {
        var payload = Dictionary(
            uniqueKeysWithValues: SMTrackerExporter.canonicalManagerKeys.map {
                ($0, SMTrackerBackupEntry.defaults)
            }
        )
        for (key, value) in overrides {
            payload[key] = value
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    private func makeDirectoryEntry(id: String, name: String, department: String) throws -> SMDirectoryEntry {
        let json = """
        {
          "id": "\(id)",
          "name": "\(name)",
          "department": "\(department)",
          "rarity": "epic",
          "aliases": ["\(name)"]
        }
        """

        let data = try #require(json.data(using: .utf8))
        return try JSONDecoder().decode(SMDirectoryEntry.self, from: data)
    }
}
