import Foundation
import UIKit

@MainActor
final class Persistence {
    static let shared = Persistence()

    private let storageURL: URL
    private let imagesDirectoryURL: URL
    private let directory: [SMDirectoryEntry]

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let container = base.appendingPathComponent("MineOpsCompanion", isDirectory: true)
        let images = container.appendingPathComponent("Images", isDirectory: true)

        try? fm.createDirectory(at: container, withIntermediateDirectories: true)
        try? fm.createDirectory(at: images, withIntermediateDirectories: true)

        storageURL = container.appendingPathComponent("recognized.json")
        imagesDirectoryURL = images
        directory = (try? SMDirectory.load()) ?? []
    }

    func loadRecognized() -> [RecognizedSM] {
        guard let data = try? Data(contentsOf: storageURL) else { return [] }
        let decoder = JSONDecoder()
        guard let records = try? decoder.decode([StoredRecognizedSM].self, from: data) else { return [] }

        return records.compactMap { record in
            let image = loadImage(named: record.imageName) ?? UIImage()
            let match = directory.first(where: { entry in
                if let id = record.directoryId, entry.id == id { return true }
                return entry.name.caseInsensitiveCompare(record.resolvedName) == .orderedSame
            })
            return RecognizedSM(
                id: record.id,
                sourceImage: image,
                rawText: record.rawText,
                level: record.level,
                directoryMatch: match,
                resolvedName: record.resolvedName,
                stats: record.stats,
                storedImageName: record.imageName,
                imageHash: record.imageHash,
                rarity: record.rarity,
                role: record.role,
                stars: record.stars,
                active: record.active?.asDomain ?? .init(),
                passive: record.passive?.asDomain ?? .init(),
                actions: record.actions?.asDomain ?? .init()
            )
        }
        .sorted { lhs, rhs in
            lhs.resolvedName.localizedCaseInsensitiveCompare(rhs.resolvedName) == .orderedAscending
        }
    }

    func saveRecognized(_ recognized: [RecognizedSM]) -> [RecognizedSM] {
        var stored: [StoredRecognizedSM] = []
        var updated: [RecognizedSM] = []

        for item in recognized {
            let imageName = item.storedImageName ?? "\(item.id.uuidString).png"
            if let data = item.sourceImage.pngData() {
                let url = imagesDirectoryURL.appendingPathComponent(imageName)
                try? data.write(to: url, options: .atomic)
            }

            let storedActive = item.active.isEmpty ? nil : StoredRecognizedSM.StoredActiveInfo(from: item.active)
            let storedPassive = item.passive.isEmpty ? nil : StoredRecognizedSM.StoredPassiveInfo(from: item.passive)
            let storedActions = item.actions.isEmpty ? nil : StoredRecognizedSM.StoredActions(from: item.actions)

            stored.append(
                StoredRecognizedSM(
                    id: item.id,
                    rawText: item.rawText,
                    level: item.level,
                    resolvedName: item.resolvedName,
                    directoryId: item.directoryMatch?.id,
                    stats: item.stats,
                    imageName: imageName,
                    imageHash: item.imageHash,
                    rarity: item.rarity,
                    role: item.role,
                    stars: item.stars,
                    active: storedActive,
                    passive: storedPassive,
                    actions: storedActions
                )
            )

            updated.append(item.withStoredImageName(imageName))
        }

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(stored) {
            try? data.write(to: storageURL, options: .atomic)
        }

        let validNames = Set(stored.compactMap { $0.imageName })
        if let existing = try? FileManager.default.contentsOfDirectory(at: imagesDirectoryURL, includingPropertiesForKeys: nil) {
            for url in existing where !validNames.contains(url.lastPathComponent) {
                try? FileManager.default.removeItem(at: url)
            }
        }

        return updated.sorted { lhs, rhs in
            lhs.resolvedName.localizedCaseInsensitiveCompare(rhs.resolvedName) == .orderedAscending
        }
    }

    private func loadImage(named name: String?) -> UIImage? {
        guard let name else { return nil }
        let url = imagesDirectoryURL.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

private struct StoredRecognizedSM: Codable {
    let id: UUID
    let rawText: String
    let level: Int?
    let resolvedName: String
    let directoryId: String?
    let stats: SMStats
    let imageName: String?
    let imageHash: String?
    let rarity: String?
    let role: String?
    let stars: Int?
    let active: StoredActiveInfo?
    let passive: StoredPassiveInfo?
    let actions: StoredActions?

    struct StoredActiveInfo: Codable {
        let effect: String?
        let multiplier: Double?
        let durationSeconds: Int?
        let cooldownSeconds: Int?

        init(from active: RecognizedSM.ActiveInfo) {
            self.effect = active.effect
            self.multiplier = active.multiplier
            self.durationSeconds = active.durationSeconds
            self.cooldownSeconds = active.cooldownSeconds
        }

        var asDomain: RecognizedSM.ActiveInfo {
            RecognizedSM.ActiveInfo(
                effect: effect,
                multiplier: multiplier,
                durationSeconds: durationSeconds,
                cooldownSeconds: cooldownSeconds
            )
        }
    }

    struct StoredPassiveInfo: Codable {
        let effect: String?
        let multiplier: Double?
        let durationSeconds: Int?

        init(from passive: RecognizedSM.PassiveInfo) {
            self.effect = passive.effect
            self.multiplier = passive.multiplier
            self.durationSeconds = passive.durationSeconds
        }

        var asDomain: RecognizedSM.PassiveInfo {
            RecognizedSM.PassiveInfo(
                effect: effect,
                multiplier: multiplier,
                durationSeconds: durationSeconds
            )
        }
    }

    struct StoredActions: Codable {
        let hasLevelUp: Bool
        let hasPromote: Bool
        let hasRankUp: Bool

        init(from actions: RecognizedSM.ActionFlags) {
            self.hasLevelUp = actions.hasLevelUp
            self.hasPromote = actions.hasPromote
            self.hasRankUp = actions.hasRankUp
        }

        var asDomain: RecognizedSM.ActionFlags {
            RecognizedSM.ActionFlags(
                hasLevelUp: hasLevelUp,
                hasPromote: hasPromote,
                hasRankUp: hasRankUp
            )
        }
    }
}

