import Foundation
import UIKit

struct SMTrackerImportResult {
    let recognized: [RecognizedSM]
    let importedCount: Int
    let addedCount: Int
    let updatedCount: Int
    let removedCount: Int
}

enum SMTrackerImportError: LocalizedError {
    case invalidSchema(missingKeys: [String], extraKeys: [String])

    var errorDescription: String? {
        switch self {
        case let .invalidSchema(missingKeys, extraKeys):
            var parts: [String] = []
            if !missingKeys.isEmpty {
                parts.append("missing keys: \(missingKeys.joined(separator: ", "))")
            }
            if !extraKeys.isEmpty {
                parts.append("unexpected keys: \(extraKeys.joined(separator: ", "))")
            }
            return "Invalid SM tracker backup schema (\(parts.joined(separator: "; ")))."
        }
    }
}

enum SMTrackerImporter {
    private static let levelTotal = 50
    private static let promotionTotal = 5
    private static let importedManagerRawText = "Imported from SM tracker backup"
    private static let displayNameOverrides = [
        "h4v0c": "H4V0C"
    ]

    static func importRecognized(
        from data: Data,
        existing: [RecognizedSM],
        directory: [SMDirectoryEntry]
    ) throws -> SMTrackerImportResult {
        let payload = try JSONDecoder().decode([String: SMTrackerBackupEntry].self, from: data)
        try validateSchema(keys: Set(payload.keys))

        let canonicalKeys = Set(SMTrackerExporter.canonicalManagerKeys)
        let directoryByKey = Dictionary(uniqueKeysWithValues: directory.map {
            (SMTrackerExporter.trackerKey(forDirectoryID: $0.id), $0)
        })
        let existingByKey = Dictionary(uniqueKeysWithValues: existing.map {
            (SMTrackerExporter.trackerKey(forRecognized: $0), $0)
        })

        var recognized: [RecognizedSM] = []
        recognized.reserveCapacity(payload.count)

        var addedCount = 0
        var updatedCount = 0
        var importedKeys = Set<String>()

        for key in SMTrackerExporter.canonicalManagerKeys {
            guard let item = payload[key], item.unlocked else { continue }
            importedKeys.insert(key)

            let imported = makeRecognized(
                forKey: key,
                item: item,
                existing: existingByKey[key],
                directoryMatch: directoryByKey[key]
            )

            if let existing = existingByKey[key] {
                if trackerFieldsDiffer(existing: existing, imported: imported) {
                    updatedCount += 1
                }
            } else {
                addedCount += 1
            }

            recognized.append(imported)
        }

        let preservedUnknown = existing.filter {
            let key = SMTrackerExporter.trackerKey(forRecognized: $0)
            return !canonicalKeys.contains(key) && !importedKeys.contains(key)
        }

        recognized.append(contentsOf: preservedUnknown)
        recognized.sort {
            $0.resolvedName.localizedCaseInsensitiveCompare($1.resolvedName) == .orderedAscending
        }

        let removedCount = existing.filter {
            let key = SMTrackerExporter.trackerKey(forRecognized: $0)
            return canonicalKeys.contains(key) && !importedKeys.contains(key)
        }.count

        return SMTrackerImportResult(
            recognized: recognized,
            importedCount: importedKeys.count,
            addedCount: addedCount,
            updatedCount: updatedCount,
            removedCount: removedCount
        )
    }
}

private extension SMTrackerImporter {
    static func validateSchema(keys: Set<String>) throws {
        let expectedKeys = Set(SMTrackerExporter.canonicalManagerKeys)
        let missingKeys = Array(expectedKeys.subtracting(keys)).sorted()
        let extraKeys = Array(keys.subtracting(expectedKeys)).sorted()
        guard missingKeys.isEmpty, extraKeys.isEmpty else {
            throw SMTrackerImportError.invalidSchema(missingKeys: missingKeys, extraKeys: extraKeys)
        }
    }

    static func makeRecognized(
        forKey key: String,
        item: SMTrackerBackupEntry,
        existing: RecognizedSM?,
        directoryMatch: SMDirectoryEntry?
    ) -> RecognizedSM {
        let level = max(item.level, 1)
        let promotion = max(item.promoted, 0)
        let stats = mergedStats(
            from: existing?.stats,
            level: level,
            promotion: promotion
        )

        if let existing {
            return RecognizedSM(
                id: existing.id,
                sourceImage: existing.sourceImage,
                rawText: existing.rawText,
                level: level,
                directoryMatch: directoryMatch ?? existing.directoryMatch,
                resolvedName: existing.resolvedName,
                stats: stats,
                storedImageName: existing.storedImageName,
                imageFingerprint: existing.imageFingerprint,
                rarity: existing.rarity ?? directoryMatch?.rarity.capitalized,
                role: existing.role ?? directoryMatch?.department,
                stars: max(item.rank, 0),
                fragments: max(item.fragments, 0),
                chronoExcluded: item.chronoExcluded,
                tierlistExcluded: item.tierlistExcluded,
                active: existing.active,
                passive: existing.passive,
                actions: existing.actions
            )
        }

        return RecognizedSM(
            sourceImage: UIImage(),
            rawText: importedManagerRawText,
            level: level,
            directoryMatch: directoryMatch,
            resolvedName: directoryMatch?.name ?? displayName(forKey: key),
            stats: stats,
            rarity: directoryMatch?.rarity.capitalized,
            role: directoryMatch?.department,
            stars: max(item.rank, 0),
            fragments: max(item.fragments, 0),
            chronoExcluded: item.chronoExcluded,
            tierlistExcluded: item.tierlistExcluded
        )
    }

    static func mergedStats(from existing: SMStats?, level: Int, promotion: Int) -> SMStats {
        SMStats(
            level: .init(current: level, total: levelTotal),
            promotion: .init(current: promotion, total: promotionTotal),
            percentValues: existing?.percentValues ?? [],
            multiplierValues: existing?.multiplierValues ?? [],
            minuteDurations: existing?.minuteDurations ?? []
        )
    }

    static func displayName(forKey key: String) -> String {
        if let override = displayNameOverrides[key] {
            return override
        }

        return key
            .split(separator: "-")
            .map { $0.lowercased().capitalized }
            .joined(separator: " ")
    }

    static func trackerFieldsDiffer(existing: RecognizedSM, imported: RecognizedSM) -> Bool {
        existing.level != imported.level ||
        existing.stats != imported.stats ||
        existing.directoryMatch != imported.directoryMatch ||
        existing.stars != imported.stars ||
        existing.fragments != imported.fragments ||
        existing.chronoExcluded != imported.chronoExcluded ||
        existing.tierlistExcluded != imported.tierlistExcluded
    }
}
