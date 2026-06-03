import Foundation
import UIKit

@MainActor
final class Persistence {
    static let shared = Persistence()

    private let storageURL: URL
    private let overridesURL: URL
    private let imagesDirectoryURL: URL
    private let directory: [SMDirectoryEntry]

    private init(containerURLOverride: URL? = nil, directoryOverride: [SMDirectoryEntry]? = nil) {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let container = (containerURLOverride ?? base.appendingPathComponent("MineOpsCompanion", isDirectory: true))
        let images = container.appendingPathComponent("Images", isDirectory: true)

        try? fm.createDirectory(at: container, withIntermediateDirectories: true)
        try? fm.createDirectory(at: images, withIntermediateDirectories: true)

        storageURL = container.appendingPathComponent("recognized_managers.json")
        overridesURL = container.appendingPathComponent("recognized_overrides.json")
        imagesDirectoryURL = images
        directory = directoryOverride ?? (try? SMDirectory.load()) ?? []
    }

    static func makeForTesting(containerURL: URL, directory: [SMDirectoryEntry] = []) -> Persistence {
        Persistence(containerURLOverride: containerURL, directoryOverride: directory)
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
                fragments: record.fragments,
                active: record.active?.asDomain ?? .init(),
                passive: record.passive?.asDomain ?? .init(),
                actions: record.actions?.asDomain ?? .init()
            )
        }
        .sorted { lhs, rhs in
            lhs.resolvedName.localizedCaseInsensitiveCompare(rhs.resolvedName) == .orderedAscending
        }
    }

    func applyOverrides(to recognized: [RecognizedSM]) -> [RecognizedSM] {
        let overrides = loadOverridesByID()
        guard !overrides.isEmpty else { return recognized }
        return recognized.map { record in
            guard let override = overrides[record.id] else { return record }
            return record.applying(override: override)
        }
    }

    func upsertOverride(from updated: RecognizedSM) {
        // Deprecated: prefer upsertOverride(original:updated:) so we only persist what the user changed.
        var overrides = loadOverrides()
        overrides.removeAll { $0.id == updated.id }
        overrides.append(StoredRecognizedSMOverride(from: updated))
        saveOverrides(overrides)
    }

    func upsertOverride(original: RecognizedSM, updated: RecognizedSM) {
        let override = StoredRecognizedSMOverride(original: original, updated: updated)
        if override.isEffectivelyEmpty {
            removeOverride(for: updated.id)
            return
        }

        var overrides = loadOverrides()
        overrides.removeAll { $0.id == updated.id }
        overrides.append(override)
        saveOverrides(overrides)
    }

    func removeOverride(for id: UUID) {
        var overrides = loadOverrides()
        let originalCount = overrides.count
        overrides.removeAll { $0.id == id }
        guard overrides.count != originalCount else { return }
        saveOverrides(overrides)
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
                    fragments: item.fragments,
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

    /// Clears all stored recognized managers, overrides, and saved images.
    func clearRecognizedManagers() {
        // Remove JSON files.
        try? FileManager.default.removeItem(at: storageURL)
        try? FileManager.default.removeItem(at: overridesURL)

        // Remove saved images.
        if let existing = try? FileManager.default.contentsOfDirectory(at: imagesDirectoryURL, includingPropertiesForKeys: nil) {
            for url in existing {
                try? FileManager.default.removeItem(at: url)
            }
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
    let fragments: Int?
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
        case fragments
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
        fragments: Int?,
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
        self.fragments = fragments
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
        fragments = try container.decodeIfPresent(Int.self, forKey: .fragments)
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
        try container.encodeIfPresent(fragments, forKey: .fragments)
        try container.encodeIfPresent(active, forKey: .active)
        try container.encodeIfPresent(passive, forKey: .passive)
        try container.encodeIfPresent(actions, forKey: .actions)
    }

    struct StoredActiveInfo: Codable {
        let effect: String?
        let multiplier: Double?
        let effectValue: RecognizedSM.ActiveEffect?
        let durationSeconds: Int?
        let cooldownSeconds: Int?

        init(from active: RecognizedSM.ActiveInfo) {
            self.effect = active.effect
            self.multiplier = active.multiplier
            self.effectValue = active.effectValue
            self.durationSeconds = active.durationSeconds
            self.cooldownSeconds = active.cooldownSeconds
        }

        var asDomain: RecognizedSM.ActiveInfo {
            RecognizedSM.ActiveInfo(
                effect: effect,
                multiplier: multiplier,
                effectValue: effectValue,
                durationSeconds: durationSeconds,
                cooldownSeconds: cooldownSeconds
            )
        }
    }

    struct StoredPassiveInfo: Codable {
        let effect: String?
        let multiplier: Double?
        let durationSeconds: Int?
        let unlockedSlots: [Bool]?
        let slots: [RecognizedSM.StatSlot]?

        init(from passive: RecognizedSM.PassiveInfo) {
            self.effect = passive.effect
            self.multiplier = passive.multiplier
            self.durationSeconds = passive.durationSeconds
            self.unlockedSlots = passive.unlockedSlots.isEmpty ? nil : passive.unlockedSlots
            self.slots = passive.slots.isEmpty ? nil : passive.slots
        }

        var asDomain: RecognizedSM.PassiveInfo {
            RecognizedSM.PassiveInfo(
                effect: effect,
                multiplier: multiplier,
                durationSeconds: durationSeconds,
                unlockedSlots: unlockedSlots ?? [],
                slots: slots ?? []
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

private struct StoredRecognizedSMOverride: Codable {
    let id: UUID
    let resolvedName: String?
    let rarity: String?
    let role: String?
    let stars: Int?
    let fragments: Int?
    let active: StoredRecognizedSM.StoredActiveInfo?
    let passive: StoredRecognizedSM.StoredPassiveInfo?
    let actions: StoredRecognizedSM.StoredActions?

    init(from record: RecognizedSM) {
        self.id = record.id
        self.resolvedName = record.resolvedName
        self.rarity = record.rarity
        self.role = record.role
        self.stars = record.stars
        self.fragments = record.fragments
        self.active = record.active.isEmpty ? nil : StoredRecognizedSM.StoredActiveInfo(from: record.active)
        let passiveWithoutUnlockSlots = RecognizedSM.PassiveInfo(
            effect: record.passive.effect,
            multiplier: record.passive.multiplier,
            durationSeconds: record.passive.durationSeconds,
            unlockedSlots: []
        )
        self.passive = passiveWithoutUnlockSlots.isEmpty ? nil : StoredRecognizedSM.StoredPassiveInfo(from: passiveWithoutUnlockSlots)
        self.actions = record.actions.isEmpty ? nil : StoredRecognizedSM.StoredActions(from: record.actions)
    }

    init(original: RecognizedSM, updated: RecognizedSM) {
        self.id = updated.id

        self.resolvedName = original.resolvedName != updated.resolvedName ? updated.resolvedName : nil
        self.rarity = original.rarity != updated.rarity ? updated.rarity : nil
        self.role = original.role != updated.role ? updated.role : nil
        self.stars = original.stars != updated.stars ? updated.stars : nil
        self.fragments = original.fragments != updated.fragments ? updated.fragments : nil

        self.active = original.active != updated.active ? (updated.active.isEmpty ? nil : StoredRecognizedSM.StoredActiveInfo(from: updated.active)) : nil

        let originalPassiveComparable = RecognizedSM.PassiveInfo(
            effect: original.passive.effect,
            multiplier: original.passive.multiplier,
            durationSeconds: original.passive.durationSeconds,
            unlockedSlots: []
        )
        let updatedPassiveComparable = RecognizedSM.PassiveInfo(
            effect: updated.passive.effect,
            multiplier: updated.passive.multiplier,
            durationSeconds: updated.passive.durationSeconds,
            unlockedSlots: []
        )
        self.passive = originalPassiveComparable != updatedPassiveComparable
            ? (updatedPassiveComparable.isEmpty ? nil : StoredRecognizedSM.StoredPassiveInfo(from: updatedPassiveComparable))
            : nil

        self.actions = original.actions != updated.actions ? (updated.actions.isEmpty ? nil : StoredRecognizedSM.StoredActions(from: updated.actions)) : nil
    }

    var isEffectivelyEmpty: Bool {
        resolvedName == nil && rarity == nil && role == nil && stars == nil && fragments == nil && active == nil && passive == nil && actions == nil
    }
}

private extension Persistence {
    func loadOverrides() -> [StoredRecognizedSMOverride] {
        guard let data = try? Data(contentsOf: overridesURL) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([StoredRecognizedSMOverride].self, from: data)) ?? []
    }

    func loadOverridesByID() -> [UUID: StoredRecognizedSMOverride] {
        let overrides = loadOverrides()
        guard !overrides.isEmpty else { return [:] }
        return overrides.reduce(into: [:]) { partial, item in
            partial[item.id] = item
        }
    }

    func saveOverrides(_ overrides: [StoredRecognizedSMOverride]) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(overrides) else { return }
        try? data.write(to: overridesURL, options: .atomic)
    }
}

private extension RecognizedSM {
    func applying(override stored: StoredRecognizedSMOverride) -> RecognizedSM {
        let activeOverride = stored.active?.asDomain ?? active
        let passiveOverride: RecognizedSM.PassiveInfo = {
            guard let override = stored.passive?.asDomain else { return passive }
            return RecognizedSM.PassiveInfo(
                effect: override.effect,
                multiplier: override.multiplier,
                durationSeconds: override.durationSeconds,
                unlockedSlots: passive.unlockedSlots
            )
        }()

        return updatingMetadata(
            resolvedName: stored.resolvedName ?? resolvedName,
            rarity: stored.rarity ?? rarity,
            role: stored.role ?? role,
            stars: stored.stars ?? stars,
            fragments: stored.fragments ?? fragments,
            active: activeOverride,
            passive: passiveOverride,
            actions: stored.actions?.asDomain ?? actions
        )
    }
}

