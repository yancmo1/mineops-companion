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
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let text = await Self.recognizeText(from: cgImage)
            
            // Validate that this looks like a Super Manager card
            let validation = SMCardValidator.validate(ocrText: text)
            if !validation.isValid {
                print("⏭️ Skipping non-SM image: \(validation.summary)")
                skippedCount += 1
                continue
            }
            
            print("✅ Valid SM card detected: \(validation.summary)")
            
            let stats = SMStatsParser.parse(text: text)
            let level = stats.level?.current ?? OCRLevelParser.parse(from: text)
            let match = DirectoryMatcher.bestMatch(in: text, directory: directory)
            let displayName = match?.name ?? OCRTextHeuristics.guessDisplayName(from: text)
            let fields = OCRFieldExtraction.extract(from: text)
            let fingerprint = ImageHasher.fingerprint(for: image)

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
                    multiplier: fields.activeMultiplier,
                    durationSeconds: fields.activeDurationSeconds,
                    cooldownSeconds: fields.activeCooldownSeconds
                ),
                passive: RecognizedSM.PassiveInfo(
                    effect: fields.passiveEffect,
                    multiplier: fields.passiveMultiplier,
                    durationSeconds: fields.passiveDurationSeconds
                ),
                actions: RecognizedSM.ActionFlags(
                    hasLevelUp: fields.hasLevelUp,
                    hasPromote: fields.hasPromote,
                    hasRankUp: fields.hasRankUp
                )
            )

            upsert(recognized)
        }
    }

    func reset() {
        results = []
        skippedCount = 0
    }

    private nonisolated static func recognizeText(from cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                var recognizedText = ""
                let request = VNRecognizeTextRequest { req, _ in
                    guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    recognizedText = lines.joined(separator: "\n")
                }
                request.recognitionLevel = .accurate
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    continuation.resume(returning: recognizedText)
                } catch {
                    continuation.resume(returning: recognizedText)
                }
            }
        }
    }


    private func upsert(_ recognized: RecognizedSM) {
        if let index = results.firstIndex(where: { $0.identityKey == recognized.identityKey }) {
            let existing = results[index]
            results[index] = recognized.updating(id: existing.id, storedImageName: existing.storedImageName)
        } else {
            results.append(recognized)
        }
    }
}
