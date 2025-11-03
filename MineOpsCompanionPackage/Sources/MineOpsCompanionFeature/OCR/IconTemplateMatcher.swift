import UIKit
import Accelerate

/// Template matching for identifying passive ability icon types
public enum IconTemplateMatcher {
    
    /// Match an unknown icon against known templates
    public static func findBestMatch(for icon: UIImage, in templates: [String: UIImage]) -> (type: String, similarity: Double)? {
        guard let targetCG = icon.cgImage else { return nil }
        
        var bestMatch: (type: String, similarity: Double)?
        
        for (type, template) in templates {
            guard let templateCG = template.cgImage else { continue }
            
            let similarity = normalizedCrossCorrelation(target: targetCG, template: templateCG)
            
            if let current = bestMatch {
                if similarity > current.similarity {
                    bestMatch = (type, similarity)
                }
            } else {
                bestMatch = (type, similarity)
            }
        }
        
        // Only return matches above threshold
        if let match = bestMatch, match.similarity > 0.7 {
            return match
        }
        
        return nil
    }
    
    /// Normalized cross-correlation between two images
    /// Returns similarity score 0-1 (1 = perfect match)
    private static func normalizedCrossCorrelation(target: CGImage, template: CGImage) -> Double {
        // Ensure both images are same size (resize template to match target)
        let targetSize = CGSize(width: target.width, height: target.height)
        guard let resizedTemplate = resize(template, to: targetSize) else { return 0 }
        
        // Convert to grayscale pixel arrays
        guard let targetPixels = grayscalePixels(from: target),
              let templatePixels = grayscalePixels(from: resizedTemplate) else {
            return 0
        }
        
        guard targetPixels.count == templatePixels.count else { return 0 }
        
        // Calculate means
        let targetMean = targetPixels.reduce(0.0, +) / Double(targetPixels.count)
        let templateMean = templatePixels.reduce(0.0, +) / Double(templatePixels.count)
        
        // Calculate correlation
        var numerator = 0.0
        var targetSumSq = 0.0
        var templateSumSq = 0.0
        
        for i in 0..<targetPixels.count {
            let targetDiff = targetPixels[i] - targetMean
            let templateDiff = templatePixels[i] - templateMean
            
            numerator += targetDiff * templateDiff
            targetSumSq += targetDiff * targetDiff
            templateSumSq += templateDiff * templateDiff
        }
        
        let denominator = sqrt(targetSumSq * templateSumSq)
        
        guard denominator > 0 else { return 0 }
        
        let correlation = numerator / denominator
        
        // Normalize to 0-1 range (correlation can be -1 to 1)
        return (correlation + 1.0) / 2.0
    }
    
    /// Extract grayscale pixel values from image
    private static func grayscalePixels(from image: CGImage) -> [Double]? {
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h)
        
        guard let ctx = CGContext(
            data: &pixels,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        
        return pixels.map { Double($0) / 255.0 }
    }
    
    /// Resize image to target size
    private static func resize(_ image: CGImage, to size: CGSize) -> CGImage? {
        let w = Int(size.width), h = Int(size.height)
        
        guard let ctx = CGContext(
            data: nil,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        
        return ctx.makeImage()
    }
    
    /// Load template library from Resources/Icons/templates/
    public static func loadTemplates() -> [String: UIImage] {
        var templates: [String: UIImage] = [:]
        
        // Try to load from Documents/Icons/templates/ (user-exported templates)
        if let docsURL = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            let templatesDir = docsURL.appendingPathComponent("Icons/templates", isDirectory: true)
            
            if let files = try? FileManager.default.contentsOfDirectory(at: templatesDir, includingPropertiesForKeys: nil) {
                for fileURL in files where fileURL.pathExtension == "png" {
                    let type = fileURL.deletingPathExtension().lastPathComponent
                    if let image = UIImage(contentsOfFile: fileURL.path) {
                        templates[type] = image
                    }
                }
            }
        }
        
        return templates
    }
}
