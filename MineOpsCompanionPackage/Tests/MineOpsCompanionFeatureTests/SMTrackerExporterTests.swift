import Foundation
import Testing
import UIKit
@testable import MineOpsCompanionFeature

@Suite("SMTrackerExporter")
struct SMTrackerExporterTests {
    private static func loadHubKeysFixture() throws -> [String] {
        #if SWIFT_PACKAGE
        guard let url = Bundle.module.url(forResource: "sm_tracker_hub_keys", withExtension: "json") else {
            throw NSError(domain: "Fixtures", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing sm_tracker_hub_keys.json"])
        }
        #else
        guard let url = Bundle.main.url(forResource: "sm_tracker_hub_keys", withExtension: "json") else {
            throw NSError(domain: "Fixtures", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing sm_tracker_hub_keys.json in main bundle"])
        }
        #endif

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try JSONDecoder().decode([String].self, from: data)
    }

    @Test("Exports strict schema with exact fields")
    func exportsStrictSchema() throws {
        let drLilly = try makeDirectoryEntry(id: "dr_lilly", name: "Dr. Lilly")
        let mrTurner = try makeDirectoryEntry(id: "mr_turner", name: "Mr. Turner")

        let recognized = RecognizedSM(
            sourceImage: UIImage(),
            rawText: "",
            level: 14,
            directoryMatch: drLilly,
            resolvedName: drLilly.name,
            stats: SMStats(
                level: .init(current: 14, total: 30),
                promotion: .init(current: 1, total: 3)
            ),
            stars: 2,
            fragments: 8
        )

        let data = try SMTrackerExporter.makeExportData(
            from: [recognized],
            directory: [drLilly, mrTurner]
        )

        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])

        // Exact top-level key universe must match canonical backup template.
        #expect(raw.count == SMTrackerExporter.canonicalManagerKeys.count)
        #expect(Set(raw.keys) == Set(SMTrackerExporter.canonicalManagerKeys))

        // Key format must be tracker-style (hyphenated)
        #expect(raw.keys.contains("dr-lilly"))
        #expect(raw.keys.contains("mr-turner"))

        let expectedFieldKeys: Set<String> = [
            "unlocked",
            "rank",
            "level",
            "promoted",
            "fragments",
            "chronoExcluded",
            "tierlistExcluded"
        ]

        // Exact schema: no extra/missing fields
        for (_, value) in raw {
            #expect(Set(value.keys) == expectedFieldKeys)
        }

        let dr = try #require(raw["dr-lilly"])
        #expect(dr["unlocked"] as? Bool == true)
        #expect(dr["rank"] as? Int == 2)
        #expect(dr["level"] as? Int == 14)
        #expect(dr["promoted"] as? Int == 1)
        #expect(dr["fragments"] as? Int == 8)
        #expect(dr["chronoExcluded"] as? Bool == false)
        #expect(dr["tierlistExcluded"] as? Bool == false)

        let turner = try #require(raw["mr-turner"])
        #expect(turner["unlocked"] as? Bool == false)
        #expect(turner["rank"] as? Int == 0)
        #expect(turner["level"] as? Int == 1)
        #expect(turner["promoted"] as? Int == 0)
        #expect(turner["fragments"] as? Int == 0)
        #expect(turner["chronoExcluded"] as? Bool == false)
        #expect(turner["tierlistExcluded"] as? Bool == false)
    }

    @Test("Uses fallback key from resolved name when directory match is unavailable")
    func fallbackKeyWhenNoDirectoryMatch() throws {
        let recognized = RecognizedSM(
            sourceImage: UIImage(),
            rawText: "",
            level: 10,
            directoryMatch: nil,
            resolvedName: "Sir Lorenzo",
            stats: SMStats(level: .init(current: 10, total: 30))
        )

        let data = try SMTrackerExporter.makeExportData(from: [recognized], directory: [])
        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])

        // slug("Sir Lorenzo") => sir_lorenzo => tracker key sir-lorenzo
        #expect(raw.keys.contains("sir-lorenzo"))
        #expect(raw["sir-lorenzo"]?["unlocked"] as? Bool == true)
    }

    @Test("Unknown recognized key is ignored to keep exact export universe")
    func unknownRecognizedKeyIgnored() throws {
        let recognized = RecognizedSM(
            sourceImage: UIImage(),
            rawText: "",
            level: 5,
            directoryMatch: nil,
            resolvedName: "Completely New Manager",
            stats: SMStats(level: .init(current: 5, total: 30))
        )

        let data = try SMTrackerExporter.makeExportData(from: [recognized], directory: [])
        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])

        #expect(raw.count == SMTrackerExporter.canonicalManagerKeys.count)
        #expect(raw.keys.contains("completely-new-manager") == false)
    }

    @Test("Export key universe matches hub fixture contract")
    func exportKeyUniverseMatchesHubFixture() throws {
        let fixtureKeys = Set(try Self.loadHubKeysFixture())

        // Generate payload from exporter itself (instead of reading static constant directly)
        // so this test catches accidental schema drifts in output shape/key set.
        let data = try SMTrackerExporter.makeExportData(from: [], directory: [])
        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])
        let exportKeys = Set(raw.keys)

        #expect(fixtureKeys.count == 108)
        #expect(exportKeys == fixtureKeys)
        #expect(exportKeys.contains("rabbid-blingsley"))
        #expect(exportKeys.contains("rabbit-blingsley") == false)
    }

    @Test("Maps Rabbid Blingsley directory id to rabbid-blingsley export key")
    func mapsRabbidDirectoryKeyToRabbidExportKey() throws {
        let rabbid = try makeDirectoryEntry(id: "rabbid_blingsley", name: "Rabbid Blingsley")
        let recognized = RecognizedSM(
            sourceImage: UIImage(),
            rawText: "",
            level: 12,
            directoryMatch: rabbid,
            resolvedName: rabbid.name,
            stats: SMStats(level: .init(current: 12, total: 50)),
            stars: 3,
            fragments: 9
        )

        let data = try SMTrackerExporter.makeExportData(from: [recognized], directory: [rabbid])
        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])

        #expect(raw["rabbid-blingsley"]?["unlocked"] as? Bool == true)
        #expect(raw["rabbid-blingsley"]?["rank"] as? Int == 3)
    }

    private func makeDirectoryEntry(id: String, name: String) throws -> SMDirectoryEntry {
        let json = """
        {
          "id": "\(id)",
          "name": "\(name)",
          "department": "elevator",
          "rarity": "epic",
          "aliases": ["\(name)"],
          "active": {
            "name": "Boost",
            "type": "boost",
            "durationSeconds": 300,
            "cooldownSeconds": 900,
            "multiplier": 2.0,
            "description": ""
          }
        }
        """

        let data = try #require(json.data(using: .utf8))
        return try JSONDecoder().decode(SMDirectoryEntry.self, from: data)
    }
}
