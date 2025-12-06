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

        storageURL = container.appendingPathComponent("recognized_managers.json")
        imagesDirectoryURL = images
        directory = (try? SMDirectory.load()) ?? []
    }

    func loadRecognized() -> [RecognizedSM] {
        guard let data = try? Data(contentsOf: storageURL) else { return [] }
        let decoder = JSONDecoder()
        guard let records = try? decoder.decode([StoredRecognizedSM].self, from: data) else { return [] }

        return records.compactMap { record in
            let image = loadImage(named: record.imageName) ?? UIImage()
            let match = directory.first { entry in
                if let id = record.directoryId, entry.id == id { return true }
                return entry.name.caseInsensitiveCompare(record.resolvedName) == .orderedSame
            }
            let fingerprint = record.imageFingerprint ?? record.legacyImageHash.map { ImageFingerprint.legacy($0) }
            return RecognizedSM(
                id: record.id,
                sourceImage: image,
                rawText: record.rawText,
                level: record.level,
                directoryMatch: match,
                resolvedName: record.resolvedName,
                stats: record.stats,
                storedImageName: record.imageName,
                imageFingerprint: fingerprint,
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
                    imageFingerprint: item.imageFingerprint,
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
    let imageFingerprint: ImageFingerprint?
    let legacyImageHash: String?
    let rarity: String?
    let role: String?
    let stars: Int?
    let active: StoredActiveInfo?
    let passive: StoredPassiveInfo?
    let actions: StoredActions?

    enum CodingKeys: String, CodingKey {
        case id
        case rawText
        case level
        case resolvedName
        case directoryId
        case stats
        case imageName
        case imageFingerprint
        case legacyImageHash = "imageHash"
        case rarity
        case role
        case stars
        case active
        case passive
        case actions
    }

    init(
        id: UUID,
        rawText: String,
        level: Int?,
        resolvedName: String,
        directoryId: String?,
        stats: SMStats,
        imageName: String?,
        imageFingerprint: ImageFingerprint?,
        rarity: String?,
        role: String?,
        stars: Int?,
        active: StoredActiveInfo?,
        passive: StoredPassiveInfo?,
        actions: StoredActions?
    ) {
        self.id = id
        self.rawText = rawText
        self.level = level
        self.resolvedName = resolvedName
        self.directoryId = directoryId
        self.stats = stats
        self.imageName = imageName
        self.imageFingerprint = imageFingerprint
        self.legacyImageHash = nil
        self.rarity = rarity
        self.role = role
        self.stars = stars
        self.active = active
        self.passive = passive
        self.actions = actions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        rawText = try container.decode(String.self, forKey: .rawText)
        level = try container.decodeIfPresent(Int.self, forKey: .level)
        resolvedName = try container.decode(String.self, forKey: .resolvedName)
        directoryId = try container.decodeIfPresent(String.self, forKey: .directoryId)
        stats = try container.decode(SMStats.self, forKey: .stats)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        imageFingerprint = try container.decodeIfPresent(ImageFingerprint.self, forKey: .imageFingerprint)
        legacyImageHash = try container.decodeIfPresent(String.self, forKey: .legacyImageHash)
        rarity = try container.decodeIfPresent(String.self, forKey: .rarity)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        stars = try container.decodeIfPresent(Int.self, forKey: .stars)
        active = try container.decodeIfPresent(StoredActiveInfo.self, forKey: .active)
        passive = try container.decodeIfPresent(StoredPassiveInfo.self, forKey: .passive)
        actions = try container.decodeIfPresent(StoredActions.self, forKey: .actions)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(rawText, forKey: .rawText)
        try container.encodeIfPresent(level, forKey: .level)
        try container.encode(resolvedName, forKey: .resolvedName)
        try container.encodeIfPresent(directoryId, forKey: .directoryId)
        try container.encode(stats, forKey: .stats)
        try container.encodeIfPresent(imageName, forKey: .imageName)
        try container.encodeIfPresent(imageFingerprint, forKey: .imageFingerprint)
        try container.encodeIfPresent(rarity, forKey: .rarity)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(stars, forKey: .stars)
        try container.encodeIfPresent(active, forKey: .active)
        try container.encodeIfPresent(passive, forKey: .passive)
        try container.encodeIfPresent(actions, forKey: .actions)
    }

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

