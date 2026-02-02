import Foundation
import UIKit

@MainActor
public final class OCRReviewViewModel: ObservableObject {
    @Published public private(set) var recognized: [RecognizedSM]
    private let directory: [SMDirectoryEntry]
    private let persistence: Persistence

    public convenience init() {
        self.init(persistence: .shared)
    }

    init(persistence: Persistence) {
        self.persistence = persistence
        self.directory = (try? SMDirectory.load()) ?? []
        self.recognized = persistence.applyOverrides(to: persistence.loadRecognized())
    }

    /// Process OCR results from imported images.
    public func process(images: [UIImage], texts: [String]) {
        let incoming = zip(images, texts).map { image, text -> RecognizedSM in
            let match = DirectoryMatcher.bestMatch(in: text, directory: directory)
            let stats = SMStatsParser.parse(text: text)
            let level = stats.level?.current ?? OCRLevelParser.parse(from: text)
            let displayName = match?.name ?? OCRTextHeuristics.guessDisplayName(from: text)
            let fields = OCRFieldExtraction.extract(from: text)

            let imageFingerprint = ImageHasher.fingerprint(for: image)

            // Detect passive ability unlock status using color analysis
            let passiveStatuses = AbilityDetector.detectPassives(in: image)
            let unlockedSlots = passiveStatuses.map { $0.isUnlocked }

            let activeEffectValue: RecognizedSM.ActiveEffect? = {
                guard let value = fields.activeValue, let unit = fields.activeUnit else { return nil }
                return RecognizedSM.ActiveEffect(value: value, unit: unit)
            }()

            let passiveSlots: [RecognizedSM.StatSlot] = {
                // Map detected slot statuses to unlocked/locked/absent, and attach parsed values when present.
                // If the detector returns fewer than 3 statuses, treat the remaining slots as absent.
                var slots: [RecognizedSM.StatSlot] = []
                slots.reserveCapacity(3)
                for idx in 0..<3 {
                    let slotNumber = idx + 1
                    let state: RecognizedSM.StatState
                    if idx >= passiveStatuses.count {
                        state = .absent
                    } else {
                        state = passiveStatuses[idx].isUnlocked ? .unlocked : .locked
                    }

                    if idx < fields.passiveValues.count {
                        let typed = fields.passiveValues[idx]
                        slots.append(.init(slot: slotNumber, state: state, value: typed.value, unit: typed.unit))
                    } else {
                        slots.append(.init(slot: slotNumber, state: state))
                    }
                }
                return slots
            }()

            return RecognizedSM(
                sourceImage: image,
                rawText: text,
                level: level,
                directoryMatch: match,
                resolvedName: displayName,
                stats: stats,
                imageFingerprint: imageFingerprint,
                rarity: fields.rarity,
                role: fields.role,
                stars: fields.stars,
                active: RecognizedSM.ActiveInfo(
                    effect: fields.activeEffect,
                    multiplier: fields.activeMultiplier,
                    effectValue: activeEffectValue,
                    durationSeconds: fields.activeDurationSeconds,
                    cooldownSeconds: fields.activeCooldownSeconds
                ),
                passive: RecognizedSM.PassiveInfo(
                    effect: fields.passiveEffect,
                    multiplier: fields.passiveMultiplier,
                    durationSeconds: fields.passiveDurationSeconds,
                    unlockedSlots: unlockedSlots,
                    slots: passiveSlots
                ),
                actions: RecognizedSM.ActionFlags(
                    hasLevelUp: fields.hasLevelUp,
                    hasPromote: fields.hasPromote,
                    hasRankUp: fields.hasRankUp
                )
            )
        }

        applyMerged(with: incoming)
    }

    /// Replace the current roster with a provided set of recognized managers.
    public func replace(with recognized: [RecognizedSM]) {
        applyMerged(with: recognized)
    }
    
    /// Replace the current roster and return info about what was updated vs new vs unchanged.
    public func replaceAndTrackChanges(with incoming: [RecognizedSM]) -> (newImports: [RecognizedSM], updates: [RecognizedSM], unchanged: [RecognizedSM]) {
        let existingByKey: [String: RecognizedSM] = recognized.reduce(into: [:]) { partial, item in
            partial[item.identityKey] = item
        }

        let newImports = incoming.filter { existingByKey[$0.identityKey] == nil }
        let updates = incoming.filter {
            guard let existing = existingByKey[$0.identityKey] else { return false }
            return hasMeaningfulChanges(existing: existing, incoming: $0)
        }
        let unchanged = incoming.filter {
            guard let existing = existingByKey[$0.identityKey] else { return false }
            return !hasMeaningfulChanges(existing: existing, incoming: $0)
        }
        
        applyMerged(with: incoming)
        
        return (newImports, updates, unchanged)
    }

    public func delete(_ record: RecognizedSM) {
        recognized.removeAll { $0.id == record.id }
        persistence.removeOverride(for: record.id)
        recognized = persistence.saveRecognized(recognized)
        
        // Remove hash from store
        if let fingerprint = record.imageFingerprint {
            Task {
                await ImageHashStore.shared.remove(fingerprint)
            }
        }
    }

    public func update(_ record: RecognizedSM, with updated: RecognizedSM) {
        recognized = recognized.map { current in
            current.id == record.id ? updated : current
        }
        persistence.upsertOverride(original: record, updated: updated)
        recognized = persistence.saveRecognized(recognized)
    }

    /// Reload recognized managers from persistence (e.g., after clearing all data).
    public func reload() {
        recognized = persistence.applyOverrides(to: persistence.loadRecognized())
    }

    private func applyMerged(with incoming: [RecognizedSM]) {
        let merged = merge(current: recognized, incoming: incoming)
        let withOverrides = persistence.applyOverrides(to: merged)
        recognized = persistence.saveRecognized(withOverrides)
    }

    private func merge(current: [RecognizedSM], incoming: [RecognizedSM]) -> [RecognizedSM] {
        var dictionary: [String: RecognizedSM] = [:]

        for item in current {
            dictionary[item.identityKey] = item
        }

        for item in incoming {
            if let existing = dictionary[item.identityKey] {
                let candidate = item.updating(id: existing.id, storedImageName: existing.storedImageName)
                dictionary[item.identityKey] = hasMeaningfulChanges(existing: existing, incoming: item) ? candidate : existing
            } else {
                dictionary[item.identityKey] = item
            }
        }

        return dictionary.values.sorted { lhs, rhs in
            lhs.resolvedName.localizedCaseInsensitiveCompare(rhs.resolvedName) == .orderedAscending
        }
    }

    private func hasMeaningfulChanges(existing: RecognizedSM, incoming: RecognizedSM) -> Bool {
        // Compare the parts of the model that should be updated by re-import.
        // Intentionally ignores fields the user may manually edit (name/rarity/role/stars).
        let existingDirectoryID = existing.directoryMatch?.id
        let incomingDirectoryID = incoming.directoryMatch?.id

        if existingDirectoryID != incomingDirectoryID { return true }
        if existing.level != incoming.level { return true }
        if existing.stats != incoming.stats { return true }
        if existing.imageFingerprint != incoming.imageFingerprint { return true }
        if existing.active != incoming.active { return true }
        if existing.passive != incoming.passive { return true }
        if existing.actions != incoming.actions { return true }
        return false
    }
}
