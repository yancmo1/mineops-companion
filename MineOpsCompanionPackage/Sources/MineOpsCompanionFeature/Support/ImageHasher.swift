import UIKit
import CryptoKit

/// Computes perceptual hashes for images to detect duplicates.
public struct ImageHasher {

  /// Builds a full fingerprint that captures both perceptual similarity and coarse pixel layout.
  public static func fingerprint(for image: UIImage) -> ImageFingerprint? {
    guard let perceptualHash = perceptualHash(for: image) else { return nil }
    let pixelDigest = pixelDigest(for: image)
    return ImageFingerprint(perceptualHash: perceptualHash, pixelDigest: pixelDigest)
  }

  /// Computes a perceptual hash (pHash) for an image.
  /// Returns a hash string that can be compared for similarity.
  public static func perceptualHash(for image: UIImage) -> String? {
    guard let resizedImage = resize(image, to: CGSize(width: 32, height: 32)),
          let cgImage = resizedImage.cgImage else {
      return nil
    }

    // Convert to grayscale and extract pixel data
    guard let grayscaleData = grayscalePixelData(from: cgImage) else {
      return nil
    }

    // Compute DCT (Discrete Cosine Transform) approximation
    let dctValues = simpleDCT(grayscaleData, width: 32, height: 32)

    // Take top-left 8x8 coefficients (excluding DC component)
    var hash: UInt64 = 0
    let median = computeMedian(dctValues)

    for i in 0..<64 {
      if dctValues[i] > median {
        hash |= (1 << i)
      }
    }

    return String(hash, radix: 16)
  }
  
  /// Computes Hamming distance between two hash strings (0-64).
  /// Lower distance means more similar images.
  public static func hammingDistance(_ hash1: String, _ hash2: String) -> Int? {
    guard let val1 = UInt64(hash1, radix: 16),
          let val2 = UInt64(hash2, radix: 16) else {
      return nil
    }
    
    let xor = val1 ^ val2
    return xor.nonzeroBitCount
  }
  
  /// Returns true if two images are considered duplicates (Hamming distance <= threshold).
  /// Default threshold of 3 for exact/near-exact duplicates only.
  /// Game screenshots with similar UI but different characters need strict matching.
  public static func areSimilar(_ hash1: String, _ hash2: String, threshold: Int = 3) -> Bool {
    guard let distance = hammingDistance(hash1, hash2) else {
      return false
    }
    return distance <= threshold
  }

  /// Creates a coarse pixel digest that highlights visible differences between cards.
  /// Quantises pixels to reduce sensitivity to compression noise while still catching distinct cards.
  public static func pixelDigest(for image: UIImage) -> String? {
    guard let cgImage = resize(image, to: CGSize(width: 64, height: 64))?.cgImage else {
      return nil
    }

    guard let quantized = quantizedPixelData(from: cgImage) else {
      return nil
    }

    let digest = SHA256.hash(data: quantized)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
  
  // MARK: - Private Helpers
  
  private static func resize(_ image: UIImage, to size: CGSize) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
    defer { UIGraphicsEndImageContext() }
    image.draw(in: CGRect(origin: .zero, size: size))
    return UIGraphicsGetImageFromCurrentImageContext()
  }
  
  private static func grayscalePixelData(from cgImage: CGImage) -> [Double]? {
    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 1
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8
    
    var pixelData = [UInt8](repeating: 0, count: width * height)
    
    guard let context = CGContext(
      data: &pixelData,
      width: width,
      height: height,
      bitsPerComponent: bitsPerComponent,
      bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceGray(),
      bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else {
      return nil
    }
    
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    return pixelData.map { Double($0) }
  }
  
  private static func simpleDCT(_ data: [Double], width: Int, height: Int) -> [Double] {
    // Simplified DCT for 8x8 top-left region
    let blockSize = 8
    var dctValues = [Double](repeating: 0, count: blockSize * blockSize)
    
    for u in 0..<blockSize {
      for v in 0..<blockSize {
        var sum = 0.0
        for x in 0..<blockSize {
          for y in 0..<blockSize {
            let pixelIndex = y * width + x
            if pixelIndex < data.count {
              let cosU = cos(Double.pi * Double(u) * (Double(x) + 0.5) / Double(blockSize))
              let cosV = cos(Double.pi * Double(v) * (Double(y) + 0.5) / Double(blockSize))
              sum += data[pixelIndex] * cosU * cosV
            }
          }
        }
        dctValues[v * blockSize + u] = sum
      }
    }
    
    return dctValues
  }
  
  private static func computeMedian(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let count = sorted.count
    if count == 0 { return 0 }
    if count % 2 == 0 {
      return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
    } else {
      return sorted[count / 2]
    }
  }

  private static func quantizedPixelData(from cgImage: CGImage) -> Data? {
    let width = 64
    let height = 64
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

    guard let context = CGContext(
      data: &pixels,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return nil
    }

    context.interpolationQuality = .medium
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Quantise each channel to 4 bits to minimise noise-driven differences.
    for index in 0..<pixels.count {
      pixels[index] &= 0xF0
    }

    return Data(pixels)
  }
}
