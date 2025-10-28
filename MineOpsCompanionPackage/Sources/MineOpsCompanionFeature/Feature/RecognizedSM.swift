import Foundation
import UIKit

public struct RecognizedSM: Identifiable, Hashable {
  public let id: UUID = .init()
  public let sourceImage: UIImage
  public let rawText: String
  public let level: Int?
  public let directoryMatch: SMDirectoryEntry?

  public init(sourceImage: UIImage, rawText: String, level: Int?, directoryMatch: SMDirectoryEntry?) {
    self.sourceImage = sourceImage
    self.rawText = rawText
    self.level = level
    self.directoryMatch = directoryMatch
  }

  public var confidence: Double {
    (level != nil ? 0.5 : 0) + (directoryMatch != nil ? 0.5 : 0)
  }
}
