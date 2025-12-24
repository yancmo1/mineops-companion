import Foundation
import Vision

/// Shared Vision OCR implementation used by the import pipeline and tests.
public enum OCRTextRecognizer {
    public struct TokenResult: Sendable {
        public let text: String
        public let confidence: Double

        public init(text: String, confidence: Double) {
            self.text = text
            self.confidence = confidence
        }
    }

    public struct TokenCandidate: Sendable {
        public let text: String
        public let confidence: Double

        public init(text: String, confidence: Double) {
            self.text = text
            self.confidence = confidence
        }
    }

    /// Recognizes text from the given image using Vision.
    public static func recognizeText(from cgImage: CGImage) async -> String {
        await recognizeText(from: cgImage, usesLanguageCorrection: true)
    }

    /// Recognizes general OCR text; tuned for full-screen OCR.
    public static func recognizeText(from cgImage: CGImage, usesLanguageCorrection: Bool) async -> String {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                var recognizedText = ""

                let request = VNRecognizeTextRequest { req, _ in
                    guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    recognizedText = lines.joined(separator: "\n")
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = usesLanguageCorrection
                request.recognitionLanguages = ["en-US"]

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

    /// Recognizes a short token in a small crop. Tuned for numeric/time/multiplier pills.
    public static func recognizeToken(from cgImage: CGImage) async -> TokenResult {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                var bestText = ""
                var bestConfidence: Double = 0

                let request = VNRecognizeTextRequest { req, _ in
                    guard let observations = req.results as? [VNRecognizedTextObservation] else { return }

                    for obs in observations {
                        guard let candidate = obs.topCandidates(1).first else { continue }
                        let conf = Double(candidate.confidence)
                        if conf > bestConfidence {
                            bestConfidence = conf
                            bestText = candidate.string
                        }
                    }
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["en-US"]

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                    continuation.resume(returning: TokenResult(text: bestText, confidence: bestConfidence))
                } catch {
                    continuation.resume(returning: TokenResult(text: bestText, confidence: bestConfidence))
                }
            }
        }
    }

    /// Recognizes multiple candidate strings for a short token crop.
    /// This allows callers (e.g. pill extraction V2) to prefer candidates that parse successfully
    /// when confidence differences are small.
    public static func recognizeTokenCandidates(from cgImage: CGImage, maxCandidatesPerObservation: Int = 3) async -> [TokenCandidate] {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                var candidates: [TokenCandidate] = []

                let request = VNRecognizeTextRequest { req, _ in
                    guard let observations = req.results as? [VNRecognizedTextObservation] else { return }

                    for obs in observations {
                        for cand in obs.topCandidates(maxCandidatesPerObservation) {
                            candidates.append(TokenCandidate(text: cand.string, confidence: Double(cand.confidence)))
                        }
                    }
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["en-US"]

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                } catch {
                    // fall through with whatever we collected
                }

                // Sort stable by confidence (desc), then by text to keep output deterministic.
                candidates.sort { a, b in
                    if abs(a.confidence - b.confidence) > 0.0001 { return a.confidence > b.confidence }
                    return a.text < b.text
                }

                continuation.resume(returning: candidates)
            }
        }
    }
}
