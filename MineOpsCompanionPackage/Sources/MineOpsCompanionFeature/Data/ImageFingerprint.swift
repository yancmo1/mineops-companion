import Foundation

/// Describes the visual identity of a screenshot for deduplication.
public struct ImageFingerprint: Codable, Hashable {
  public enum Version: Int, Codable {
    case legacy = 0
    case v1 = 1
  }

  public let perceptualHash: String
  public let pixelDigest: String?
  public let version: Version

  public init(perceptualHash: String, pixelDigest: String?, version: Version = .v1) {
    self.perceptualHash = perceptualHash
    self.pixelDigest = pixelDigest
    self.version = version
  }

  /// Creates a fingerprint from a legacy hash string.
  public static func legacy(_ hash: String) -> ImageFingerprint {
    ImageFingerprint(perceptualHash: hash, pixelDigest: nil, version: .legacy)
  }

  public static func == (lhs: ImageFingerprint, rhs: ImageFingerprint) -> Bool {
    switch (lhs.pixelDigest, rhs.pixelDigest) {
    case let (.some(lhsDigest), .some(rhsDigest)):
      return lhsDigest == rhsDigest
    default:
      return lhs.perceptualHash == rhs.perceptualHash && lhs.version == rhs.version
    }
  }

  public func hash(into hasher: inout Hasher) {
    if let pixelDigest {
      hasher.combine(pixelDigest)
    } else {
      hasher.combine(perceptualHash)
      hasher.combine(version)
    }
  }
}
