import CoreGraphics
import UIKit

/// Detects the number of filled stars (rank) from the visual star row on an SM card.
///
/// Why this exists:
/// - Vision OCR often misses star glyphs entirely.
/// - Export rank is derived from `RecognizedSM.stars`, so missing stars become rank=0.
///
/// Strategy:
/// - Inspect the known star-row strip on the card (normalized coordinates).
/// - Split into 5 fixed slots.
/// - For each slot, measure "gold" pixel ratio to determine filled stars.
/// - Use a brown-star signal check so rank 0 can still be detected confidently.
public enum SMCardStarDetector {

    /// Returns 0...5 when visual signal is available; `nil` when confidence is too low.
    public static func detectStars(in image: UIImage) -> Int? {
        guard let cgImage = image.cgImage else { return nil }
        return detectStars(in: cgImage)
    }

    static func detectStars(in cgImage: CGImage) -> Int? {
        guard let bytes = rgbaBytes(from: cgImage) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        // Top-origin normalized strip where the 5 stars are rendered.
        let strip = CGRect(x: 0.23, y: 0.60, width: 0.54, height: 0.09)
        let x0 = Int(Double(width) * strip.origin.x)
        let y0 = Int(Double(height) * strip.origin.y)
        let stripW = Int(Double(width) * strip.width)
        let stripH = Int(Double(height) * strip.height)
        guard stripW > 0, stripH > 0 else { return nil }

        var goldRatios: [Double] = []
        goldRatios.reserveCapacity(5)
        var brownRatios: [Double] = []
        brownRatios.reserveCapacity(5)

        for slot in 0..<5 {
            let slotX = x0 + (stripW * slot) / 5
            let slotW = max(1, stripW / 5)

            var goldPixels = 0
            var brownPixels = 0
            var totalPixels = 0

            for y in y0..<(y0 + stripH) {
                guard y >= 0 && y < height else { continue }

                for x in slotX..<(slotX + slotW) {
                    guard x >= 0 && x < width else { continue }

                    let idx = (y * width + x) * 4
                    guard idx + 3 < bytes.count else { continue }

                    let r = Double(bytes[idx + 0]) / 255.0
                    let g = Double(bytes[idx + 1]) / 255.0
                    let b = Double(bytes[idx + 2]) / 255.0

                    let (hue, saturation, brightness) = hsv(r: r, g: g, b: b)

                    // Filled-star gold.
                    if hue >= 32 && hue <= 62 && saturation >= 0.40 && brightness >= 0.45 {
                        goldPixels += 1
                    }

                    // Empty-star brown (for confidence that the row was actually found).
                    if hue >= 12 && hue <= 35 && saturation >= 0.45 && brightness >= 0.20 && brightness <= 0.55 {
                        brownPixels += 1
                    }

                    totalPixels += 1
                }
            }

            if totalPixels == 0 {
                goldRatios.append(0)
                brownRatios.append(0)
            } else {
                goldRatios.append(Double(goldPixels) / Double(totalPixels))
                brownRatios.append(Double(brownPixels) / Double(totalPixels))
            }
        }

        // Confidence gating:
        // if we cannot see either gold stars or brown empty-star signal, region is likely off.
        let maxGold = goldRatios.max() ?? 0
        let meanBrown = brownRatios.reduce(0, +) / Double(max(1, brownRatios.count))
        if maxGold < 0.01 && meanBrown < 0.03 {
            return nil
        }

        let filledStars = goldRatios.filter { $0 >= 0.03 }.count
        return min(max(filledStars, 0), 5)
    }

    private static func rgbaBytes(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }

    private static func hsv(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
        let cMax = max(r, g, b)
        let cMin = min(r, g, b)
        let delta = cMax - cMin

        let saturation = cMax == 0 ? 0 : (delta / cMax)

        var hue: Double = 0
        if delta != 0 {
            if cMax == r {
                hue = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
            } else if cMax == g {
                hue = 60 * (((b - r) / delta) + 2)
            } else {
                hue = 60 * (((r - g) / delta) + 4)
            }
            if hue < 0 { hue += 360 }
        }

        return (h: hue, s: saturation, v: cMax)
    }
}
