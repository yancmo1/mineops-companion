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
        self.recognized = persistence.loadRecognized()
    }

    /// Process OCR results from imported images.
    public func process(images: [UIImage], texts: [String]) {
        let incoming = zip(images, texts).map { image, text -> RecognizedSM in
            let match = DirectoryMatcher.bestMatch(in: text, directory: directory)
            let stats = SMStatsParser.parse(text: text)
            let level = stats.level?.current ?? OCRLevelParser.parse(from: text)
            let displayName = match?.name ?? OCRTextHeuristics.guessDisplayName(from: text)
            let fields = OCRFieldExtraction.extract(from: text)

            let imageHash = ImageHasher.perceptualHash(for: image)
            
            // Detect passive ability unlock status using color analysis
            let passiveStatuses = AbilityDetector.detectPassives(in: image)
            let unlockedSlots = passiveStatuses.map { $0.isUnlocked }
            
            return RecognizedSM(
                sourceImage: image,
                rawText: text,
                level: level,
                directoryMatch: match,
                resolvedName: displayName,
                stats: stats,
                imageHash: imageHash,
                rarity: fields.rarity,
                role: fields.role,
                stars: fields.stars,
                active: RecognizedSM.ActiveInfo(
                    effect: fields.activeEffect,
                    multiplier: fields.activeMultiplier,
                    durationSeconds: fields.activeDurationSeconds,
                    cooldownSeconds: fields.activeCooldownSeconds
                ),
                passive: RecognizedSM.PassiveInfo(
                    effect: fields.passiveEffect,
                    multiplier: fields.passiveMultiplier,
                    durationSeconds: fields.passiveDurationSeconds,
                    unlockedSlots: unlockedSlots
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
    
    /// Replace the current roster and return info about what was updated vs new.
    public func replaceAndTrackChanges(with incoming: [RecognizedSM]) -> (newImports: [RecognizedSM], updates: [RecognizedSM]) {
        let existingKeys = Set(recognized.map { $0.identityKey })
        let newImports = incoming.filter { !existingKeys.contains($0.identityKey) }
        let updates = incoming.filter { existingKeys.contains($0.identityKey) }
        
        applyMerged(with: incoming)
        
        return (newImports, updates)
    }

    public func delete(_ record: RecognizedSM) {
        recognized.removeAll { $0.id == record.id }
        recognized = persistence.saveRecognized(recognized)
        
        // Remove hash from store
        if let hash = record.imageHash {
            Task {
                await ImageHashStore.shared.removeHash(hash)
            }
        }
    }

    public func update(_ record: RecognizedSM, with updated: RecognizedSM) {
        recognized = recognized.map { current in
            current.id == record.id ? updated : current
        }
        recognized = persistence.saveRecognized(recognized)
    }

    private func applyMerged(with incoming: [RecognizedSM]) {
        let merged = merge(current: recognized, incoming: incoming)
        recognized = persistence.saveRecognized(merged)
    }

    private func merge(current: [RecognizedSM], incoming: [RecognizedSM]) -> [RecognizedSM] {
        var dictionary: [String: RecognizedSM] = [:]

        for item in current {
            dictionary[item.identityKey] = item
        }

        for item in incoming {
            if let existing = dictionary[item.identityKey] {
                dictionary[item.identityKey] = item.updating(id: existing.id, storedImageName: existing.storedImageName)
            } else {
                dictionary[item.identityKey] = item
            }
        }

        return dictionary.values.sorted { lhs, rhs in
            lhs.resolvedName.localizedCaseInsensitiveCompare(rhs.resolvedName) == .orderedAscending
        }
    }
}
