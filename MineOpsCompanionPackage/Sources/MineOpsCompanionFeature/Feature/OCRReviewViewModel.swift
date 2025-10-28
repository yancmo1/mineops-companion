import Foundation
import UIKit

@MainActor
public final class OCRReviewViewModel: ObservableObject {
  @Published public private(set) var recognized: [RecognizedSM] = []
  private var directory: [SMDirectoryEntry] = (try? SMDirectory.load()) ?? []

  public init() {}

  /// Call this after Vision returns OCR text for each selected image.
  public func process(images: [UIImage], texts: [String]) {
    var out: [RecognizedSM] = []
    for (img, text) in zip(images, texts) {
      // Name guess = longest line (works well on SM cards)
      let nameLine = text.split(separator: "\n").map(String.init).max(by: { $0.count < $1.count }) ?? text
      let match = DirectoryMatcher.bestMatch(for: nameLine, in: directory)
      let level = OCRLevelParser.parse(from: text)
      out.append(RecognizedSM(sourceImage: img, rawText: text, level: level, directoryMatch: match))
    }
    recognized = out
  }
}
