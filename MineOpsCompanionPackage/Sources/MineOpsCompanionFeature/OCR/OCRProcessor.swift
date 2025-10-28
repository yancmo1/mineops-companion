import Foundation
import UIKit
import Vision
import VisionKit

@MainActor
final class OCRProcessor: ObservableObject {
    @Published private(set) var results: [OCRResult] = []

    func processImages(_ images: [UIImage]) async {
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            if let parsed = await Self.recognize(image: image, cgImage: cgImage) {
                results.append(parsed)
            }
        }
    }

    private nonisolated static func recognize(image: UIImage, cgImage: CGImage) async -> OCRResult? {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                var parsedResult: OCRResult?
                let request = VNRecognizeTextRequest { req, _ in
                    guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
                    let allText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                    parsedResult = parseText(allText, sourceImage: image)
                }
                request.recognitionLevel = .accurate
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let fallback = parseText("", sourceImage: image)
                    continuation.resume(returning: parsedResult ?? fallback)
                } catch {
                    continuation.resume(returning: parseText("", sourceImage: image))
                }
            }
        }
    }

    private nonisolated static func parseText(_ text: String, sourceImage: UIImage) -> OCRResult {
        let name = text.components(separatedBy: "Level").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        let level = OCRLevelParser.parse(from: text) ?? 0
        let boostMatch = text.range(of: #"\+\d+%"#, options: .regularExpression)
        let boostString = boostMatch.map { String(text[$0]) } ?? "+0%"
        let boostValue = Double(boostString.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "%", with: "")) ?? 0
        return OCRResult(image: sourceImage, parsedName: name, parsedLevel: level, parsedBoost: boostValue, parsedBoostType: "")
    }
}
