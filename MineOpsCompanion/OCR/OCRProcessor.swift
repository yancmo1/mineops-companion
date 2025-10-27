import Vision
import VisionKit
import SwiftUI

final class OCRProcessor: ObservableObject {
    @Published var results: [OCRResult] = []

    func processImages(_ images: [UIImage]) async {
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let request = VNRecognizeTextRequest { [weak self] req, _ in
                guard let obs = req.results as? [VNRecognizedTextObservation] else { return }
                let allText = obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                let parsed = self?.parseText(allText) ?? OCRResult(image: image, parsedName: "Unknown", parsedLevel: 0, parsedBoost: 0, parsedBoostType: "")
                DispatchQueue.main.async { self?.results.append(parsed) }
            }
            request.recognitionLevel = .accurate
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func parseText(_ text: String) -> OCRResult {
        let name = text.components(separatedBy: "Level").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        let level = Int(text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) ?? 0
        let boostMatch = text.range(of: #"\+\d+%"#, options: .regularExpression)
        let boostString = boostMatch.map { String(text[$0]) } ?? "+0%"
        let boostValue = Double(boostString.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "%", with: "")) ?? 0
        return OCRResult(image: UIImage(), parsedName: name, parsedLevel: level, parsedBoost: boostValue, parsedBoostType: "")
    }
}
