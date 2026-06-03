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

            // Run two spatial OCR passes:
            // - corrected text (better words)
            // - raw text without language correction (better symbols/numbers)
            async let spatialCorrectedAsync = OCRTextRecognizer.recognizeTextWithSpatialData(
                from: cgImage,
                usesLanguageCorrection: true
            )
            async let spatialRawAsync = OCRTextRecognizer.recognizeTextWithSpatialData(
                from: cgImage,
                usesLanguageCorrection: false
            )
            async let pillExtractionAsync = SMCardPillExtractor.extract(from: cgImage)

            let spatialCorrected = await spatialCorrectedAsync
            let spatialRaw = await spatialRawAsync
            let spatialLines = mergeSpatialLines(primary: spatialCorrected, secondary: spatialRaw)
            let text = spatialLines.map(\.text).joined(separator: "\n")

            // Validate that this looks like a Super Manager card
            let validation = SMCardValidator.validate(ocrText: text)
            if !validation.isValid {
                print("⏭️ Skipping non-SM image: \(validation.summary)")
                skippedCount += 1
                continue
            }
            
            print("✅ Valid SM card detected: \(validation.summary)")

            let pillExtraction = await pillExtractionAsync

            let stats = SMStatsParser.parse(text: text)
            let level = stats.level?.current ?? OCRLevelParser.parse(from: text)
            let match = DirectoryMatcher.bestMatch(in: text, directory: directory)
            let displayName = match?.name ?? OCRTextHeuristics.guessDisplayName(from: text)

            // Use spatial-aware field extraction (properly splits Active vs Passive columns).
            let fields = OCRFieldExtraction.extractWithSpatialData(from: spatialLines)
            let visualStars = SMCardStarDetector.detectStars(in: image)
            let mergedStars = fields.stars ?? visualStars

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

            // Merge: prefer pill extraction (more precise), fall back to field extraction.
            let mergedActiveMultiplier = pillExtraction.activeMultiplier ?? fields.activeMultiplier
            let mergedActiveDuration = pillExtraction.activeDurationSeconds ?? fields.activeDurationSeconds
            let mergedActiveCooldown = pillExtraction.activeCooldownSeconds ?? fields.activeCooldownSeconds
            let mergedPassiveMultiplier = pillExtraction.passiveMultiplier ?? fields.passiveMultiplier

            // Build typed active effect.
            let activeEffect: RecognizedSM.ActiveEffect? = {
                if let value = fields.activeValue, let unit = fields.activeUnit {
                    return RecognizedSM.ActiveEffect(value: value, unit: unit)
                }
                return nil
            }()

            // Build passive slots from field extraction values + unlock status.
            let passiveSlots: [RecognizedSM.StatSlot] = {
                let values = fields.passiveValues
                var slots: [RecognizedSM.StatSlot] = []
                for i in 0..<3 {
                    let isUnlocked = (i < unlockedSlots.count) ? unlockedSlots[i] : false
                    let state: RecognizedSM.StatState = isUnlocked ? .unlocked : .locked
                    if i < values.count {
                        slots.append(RecognizedSM.StatSlot(slot: i, state: state, value: values[i].value, unit: values[i].unit))
                    } else {
                        slots.append(RecognizedSM.StatSlot(slot: i, state: .absent))
                    }
                }
                return slots
            }()

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
                stars: mergedStars,
                fragments: fields.fragments,
                active: RecognizedSM.ActiveInfo(
                    effect: fields.activeEffect,
                    multiplier: mergedActiveMultiplier,
                    effectValue: activeEffect,
                    durationSeconds: mergedActiveDuration,
                    cooldownSeconds: mergedActiveCooldown
                ),
                passive: RecognizedSM.PassiveInfo(
                    effect: fields.passiveEffect,
                    multiplier: mergedPassiveMultiplier,
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

    private func mergeSpatialLines(
        primary: [OCRTextRecognizer.SpatialLine],
        secondary: [OCRTextRecognizer.SpatialLine]
    ) -> [OCRTextRecognizer.SpatialLine] {
        struct Bucket: Hashable {
            let x: Int
            let y: Int
            let w: Int
            let h: Int
        }

        func bucket(for line: OCRTextRecognizer.SpatialLine) -> Bucket {
            Bucket(
                x: Int((line.boundingBox.origin.x * 100).rounded()),
                y: Int((line.boundingBox.origin.y * 100).rounded()),
                w: Int((line.boundingBox.size.width * 100).rounded()),
                h: Int((line.boundingBox.size.height * 100).rounded())
            )
        }

        func qualityScore(for line: OCRTextRecognizer.SpatialLine) -> Double {
            let text = line.text.lowercased()
            var score = line.confidence

            // Prefer lines likely carrying star/rank/fragment signal.
            if text.contains("⭐") || text.contains("★") || text.contains("✦") || text.contains("✪") {
                score += 0.40
            }
            if text.range(of: #"\b[0-9]{1,3}\s*/\s*(15|30|50|100)\b"#, options: .regularExpression) != nil {
                score += 0.35
            }
            if text.range(of: #"\brank\s*[:#-]?\s*[0-9]{1,2}\b"#, options: .regularExpression) != nil {
                score += 0.25
            }

            // Keep section headers stable.
            if text.contains("active") || text.contains("passive") {
                score += 0.15
            }

            return score
        }

        var mergedByBucket: [Bucket: OCRTextRecognizer.SpatialLine] = [:]
        mergedByBucket.reserveCapacity(max(primary.count, secondary.count))

        for line in primary {
            mergedByBucket[bucket(for: line)] = line
        }

        for line in secondary {
            let key = bucket(for: line)
            guard let current = mergedByBucket[key] else {
                mergedByBucket[key] = line
                continue
            }

            if qualityScore(for: line) > qualityScore(for: current) {
                mergedByBucket[key] = line
            }
        }

        return mergedByBucket.values.sorted { lhs, rhs in
            if abs(lhs.centerYTopOrigin - rhs.centerYTopOrigin) > 0.005 {
                return lhs.centerYTopOrigin < rhs.centerYTopOrigin
            }
            return lhs.centerX < rhs.centerX
        }
    }

    // Intentionally no local upsert/dedup in OCRProcessor.
}
