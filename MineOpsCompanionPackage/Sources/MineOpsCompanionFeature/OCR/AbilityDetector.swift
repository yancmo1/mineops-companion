import CoreGraphics
import CoreImage
import UIKit

public struct AbilityIconStatus: Equatable {
    public let isUnlocked: Bool
    public let confidence: Double      // 0–1
}

/// Detects lock state of the 3 passive icons on the right column of an SM card screenshot.
/// Assumes a standard full-card portrait screenshot (like the ones you've been sharing).
public enum AbilityDetector {

    /// Main entry. Returns array of icon statuses (length varies by promotion level).
    public static func detectPassives(in card: UIImage) -> [AbilityIconStatus] {
        guard let cg = card.cgImage else { return [] }

        // 1) Try each calibration layout to find which one exists
        //    Start with 3-passives since that's most common
        let rects: [CGRect]
        if let calibrated = IconCalibration.getCalibrationRects(for: .threePassives) {
            rects = calibrated.map { $0.rect }
        } else if let calibrated = IconCalibration.getCalibrationRects(for: .twoPassives) {
            rects = calibrated.map { $0.rect }
        } else if let calibrated = IconCalibration.getCalibrationRects(for: .onePassive) {
            rects = calibrated.map { $0.rect }
        } else {
            // Default rectangles - assume 3 passives layout
            rects = [
                CGRect(x: 0.71, y: 0.78, width: 0.08, height: 0.055), // left
                CGRect(x: 0.80, y: 0.78, width: 0.08, height: 0.055), // middle
                CGRect(x: 0.89, y: 0.78, width: 0.08, height: 0.055)  // right
            ]
        }

        return rects.map { r in
            guard let sub = cropNormalized(cg, r) else {
                return AbilityIconStatus(isUnlocked: false, confidence: 0)
            }
            // 2) Downsample to tiny tile to make stats robust & fast.
            guard let tiny = downsample(sub, maxSide: 48) else {
                return AbilityIconStatus(isUnlocked: false, confidence: 0)
            }
            // 3) Compute colorfulness in LAB space (|ab| magnitude).
            let (meanC, fracStrong) = labColorfulnessStats(tiny)

            // 4) Classify with two simple signals:
            //    - meanC: average color magnitude (0≈gray … 1+≈strong color)
            //    - fracStrong: fraction of pixels with strong color
            //    Thresholds tuned for your screenshots; adjust if needed.
            let unlocked: Bool
            let conf: Double
            if meanC >= 0.18 || fracStrong >= 0.12 {        // clear color present
                unlocked = true; conf = min(1.0, max(0.55, meanC * 1.4 + fracStrong))
            } else if meanC <= 0.10 && fracStrong <= 0.05 {  // clearly gray
                unlocked = false; conf = 0.9 - (meanC * 2.0)
            } else {
                // Ambiguous zone → try lock glyph heuristic, else low-confidence guess
                if lockGlyphLikely(in: tiny) {
                    unlocked = false; conf = 0.7
                } else {
                    unlocked = meanC > 0.14
                    conf = 0.55
                }
            }
            return AbilityIconStatus(isUnlocked: unlocked, confidence: conf)
        }
    }

    // MARK: - Helpers

    /// Crop using normalized coordinates (percentages of the full image).
    private static func cropNormalized(_ cg: CGImage, _ n: CGRect) -> CGImage? {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let rect = CGRect(x: n.origin.x * w,
                          y: n.origin.y * h,
                          width: n.size.width * w,
                          height: n.size.height * h)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        return cg.cropping(to: rect)
    }

    /// Nearest-neighbor downsample (icons are flat; NN is fine here).
    private static func downsample(_ cg: CGImage, maxSide: Int) -> CGImage? {
        let w = cg.width, h = cg.height
        let scale = CGFloat(maxSide) / CGFloat(max(w, h))
        let dstW = max(8, Int(CGFloat(w) * scale))
        let dstH = max(8, Int(CGFloat(h) * scale))

        guard let ctx = CGContext(
            data: nil,
            width: dstW, height: dstH,
            bitsPerComponent: 8, bytesPerRow: dstW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .none
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: dstW, height: dstH))
        return ctx.makeImage()
    }

    /// Compute mean LAB colorfulness and fraction of "strong color" pixels.
    /// Colorfulness = sqrt(a^2 + b^2) normalized into ~[0,1.5] for our use.
    private static func labColorfulnessStats(_ cg: CGImage) -> (mean: Double, fracStrong: Double) {
        let w = cg.width, h = cg.height
        let count = w * h
        var buf = [UInt8](repeating: 0, count: count * 4)

        guard let ctx = CGContext(
            data: &buf, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (0, 0) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var sum: Double = 0
        var strong: Int = 0

        for i in stride(from: 0, to: buf.count, by: 4) {
            let r = Double(buf[i+0]) / 255.0
            let g = Double(buf[i+1]) / 255.0
            let b = Double(buf[i+2]) / 255.0

            // RGB → LAB (approx) via linearized sRGB → XYZ → LAB
            // Keep it fast; accuracy is plenty for a gray vs color test.
            func toLinear(_ c: Double) -> Double {
                c <= 0.04045 ? (c / 12.92) : pow((c + 0.055)/1.055, 2.4)
            }
            let R = toLinear(r), G = toLinear(g), B = toLinear(b)
            // sRGB D65
            let X = 0.4124*R + 0.3576*G + 0.1805*B
            let Y = 0.2126*R + 0.7152*G + 0.0722*B
            let Z = 0.0193*R + 0.1192*G + 0.9505*B

            func f(_ t: Double) -> Double {
                let e = 216.0/24389.0, k = 24389.0/27.0
                return t > e ? pow(t, 1.0/3.0) : ( (k * t + 16.0) / 116.0 )
            }

            // D65 white
            let xn = 0.95047, yn = 1.00000, zn = 1.08883
            let fx = f(X/xn), fy = f(Y/yn), fz = f(Z/zn)
            let a = 500.0 * (fx - fy)
            let b2 = 200.0 * (fy - fz)

            let chroma = sqrt(a*a + b2*b2) / 100.0 // normalize
            sum += chroma
            if chroma > 0.22 { strong += 1 }       // "clearly colored" pixel
        }

        let mean = sum / Double(count)
        let frac = Double(strong) / Double(count)
        return (mean, frac)
    }

    /// Very cheap heuristic: many lock overlays are pale/white with a dark outline near center.
    /// We sample central cross and look for low colorfulness + high luminance.
    private static func lockGlyphLikely(in cg: CGImage) -> Bool {
        let w = cg.width, h = cg.height
        let cx = w/2, cy = h/2
        guard let data = cg.dataProvider?.data as Data? else { return false }
        let bytes = [UInt8](data)

        func luma(_ i: Int) -> Double {
            let r = Double(bytes[i]) / 255.0
            let g = Double(bytes[i+1]) / 255.0
            let b = Double(bytes[i+2]) / 255.0
            return 0.2126*r + 0.7152*g + 0.0722*b
        }

        var lum: Double = 0, cnt = 0
        for dx in -2...2 {
            let idx = ((cy) * w + (cx + dx)) * 4
            if idx >= 0 && idx+2 < bytes.count { lum += luma(idx); cnt += 1 }
        }
        for dy in -2...2 {
            let idx = ((cy + dy) * w + (cx)) * 4
            if idx >= 0 && idx+2 < bytes.count { lum += luma(idx); cnt += 1 }
        }
        guard cnt > 0 else { return false }
        let avgLuma = lum / Double(cnt)
        return avgLuma > 0.78   // bright center suggests white lock glyph on gray background
    }
}
