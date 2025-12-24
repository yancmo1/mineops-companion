import Foundation
import UIKit
import Vision
import VisionKit

@MainActor
public final class OCRProcessor: ObservableObject {
    @Published private(set) public var results: [RecognizedSM] = []
    @Published private(set) public var skippedCount: Int = 0
    private let directory: [SMDirectoryEntry] = (try? SMDirectory.load()) ?? []
    
    public init() {}

    public func processImages(_ images: [UIImage]) async {
        for (index, image) in images.enumerated() {
            guard let cgImage = image.cgImage else { continue }
            let text = await OCRTextRecognizer.recognizeText(from: cgImage)
            
            // Validate that this looks like a Super Manager card
            let validation = SMCardValidator.validate(ocrText: text)
            if !validation.isValid {
                print("⏭️ Skipping non-SM image: \(validation.summary)")
                skippedCount += 1
                continue
            }
            
            print("✅ Valid SM card detected: \(validation.summary)")

            // New approach: extract and OCR the "blue pill" tokens in the bottom panel.
            // This improves reliability for durations and numeric values (e.g. `5m`, `30m`, `8.08x`, `-14.5%`).
            let pillExtraction = await SMCardPillExtractor.extract(from: cgImage)
            
            let stats = SMStatsParser.parse(text: text)
            let level = stats.level?.current ?? OCRLevelParser.parse(from: text)
            let match = DirectoryMatcher.bestMatch(in: text, directory: directory)
            let displayName = match?.name ?? OCRTextHeuristics.guessDisplayName(from: text)
            let fields = OCRFieldExtraction.extract(from: text)
            let fingerprint = ImageHasher.fingerprint(for: image)

            // Debug-only: run V2 pill extraction in parallel with legacy and log a diff.
            if FeatureFlags.newPillExtractionV2Enabled {
                let v2 = await SMCardPillExtractor.extractV2(from: cgImage)
                let screenshotID = fingerprint?.perceptualHash ?? "img_\(index + 1)_\(Int(Date().timeIntervalSince1970))"
                PillDiffLogger.log(screenshotID: screenshotID, timestamp: .now, legacy: pillExtraction, v2: v2)
            }

            // Detect passive ability unlock status using color analysis
            let passiveStatuses = AbilityDetector.detectPassives(in: image)
            let unlockedSlots = passiveStatuses.map { $0.isUnlocked }

            let mergedActiveMultiplier = pillExtraction.activeMultiplier ?? fields.activeMultiplier
            let mergedActiveDuration = pillExtraction.activeDurationSeconds ?? fields.activeDurationSeconds
            let mergedActiveCooldown = pillExtraction.activeCooldownSeconds ?? fields.activeCooldownSeconds
            let mergedPassiveMultiplier = pillExtraction.passiveMultiplier ?? fields.passiveMultiplier

            let recognized = RecognizedSM(
                sourceImage: image,
                rawText: text,
                level: level,
                directoryMatch: match,
                resolvedName: displayName,
                stats: stats,
                imageFingerprint: fingerprint,
                rarity: fields.rarity,
                role: fields.role,
                stars: fields.stars,
                active: RecognizedSM.ActiveInfo(
                    effect: fields.activeEffect,
                    multiplier: mergedActiveMultiplier,
                    durationSeconds: mergedActiveDuration,
                    cooldownSeconds: mergedActiveCooldown
                ),
                passive: RecognizedSM.PassiveInfo(
                    effect: fields.passiveEffect,
                    multiplier: mergedPassiveMultiplier,
                    durationSeconds: fields.passiveDurationSeconds,
                    unlockedSlots: unlockedSlots
                ),
                actions: RecognizedSM.ActionFlags(
                    hasLevelUp: fields.hasLevelUp,
                    hasPromote: fields.hasPromote,
                    hasRankUp: fields.hasRankUp
                )
            )

            // Important: Do NOT upsert/deduplicate here.
            // Import flows often process multiple screenshots in a single batch, and OCR/name matching
            // can be wrong for one or more images. Upserting here can collapse distinct cards into one.
            // Dedup/merge should happen at the import/review layer using stronger signals.
            results.append(recognized)

            #if DEBUG
            let keyPreview = String(recognized.identityKey.prefix(28))
            let digestPreview = fingerprint?.pixelDigest.map { String($0.prefix(8)) } ?? "nil"
            let phashPreview = fingerprint.map { String($0.perceptualHash.prefix(8)) } ?? "nil"
            let dirID = match?.id ?? "nil"
            print("🧩 OCRProcessor[\(index + 1)/\(images.count)] key=\(keyPreview) dir=\(dirID) pixel=\(digestPreview) phash=\(phashPreview)")
            #endif
        }
    }

    func reset() {
        results = []
        skippedCount = 0
    }

    // Intentionally no local upsert/dedup in OCRProcessor.
}
