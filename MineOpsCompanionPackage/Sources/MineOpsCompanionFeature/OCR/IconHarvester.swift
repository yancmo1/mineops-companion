import UIKit
import Foundation

/// Extracts passive ability icons from SM card screenshots for training/labeling.
public enum IconHarvester {
    
    public struct HarvestedIcon {
        public let image: UIImage
        public let slotIndex: Int // 0=top, 1=mid, 2=bottom
        public let isUnlocked: Bool
        public let confidence: Double
    }
    
    /// Crop all passive icons from a full card screenshot.
    /// Uses calibrated positions if available, otherwise falls back to sliding window detection.
    public static func harvestIcons(from card: UIImage, managerId: String) -> [HarvestedIcon] {
        guard let cg = card.cgImage else { return [] }
        
        // First, detect how many passives this card has using color analysis
        let detectedStatuses = AbilityDetector.detectPassives(in: card)
        let passiveCount = detectedStatuses.count
        
        // Try to get calibration for this specific passive count
        if let calibratedRects = IconCalibration.getCalibrationRects(forPassiveCount: passiveCount) {
            print("📍 Using calibrated positions for \(passiveCount) passive\(passiveCount == 1 ? "" : "s")")
            return harvestIconsFromFixedPositions(cg: cg, rects: calibratedRects, card: card)
        }
        
        // Fall back to sliding window detection
        print("🔍 Using sliding window detection (no calibration for \(passiveCount) passives)")
        return harvestIconsWithSlidingWindow(cg: cg, card: card)
    }
    
    /// Harvest icons from calibrated fixed positions
    private static func harvestIconsFromFixedPositions(cg: CGImage, rects: [(index: Int, rect: CGRect)], card: UIImage) -> [HarvestedIcon] {
        // Detect lock status for all positions first
        let statuses = AbilityDetector.detectPassives(in: card)
        
        return rects.compactMap { index, rect in
            guard let cropped = cropNormalized(cg, rect) else { return nil }
            let status = statuses[safe: index] ?? AbilityIconStatus(isUnlocked: false, confidence: 0)
            
            // Scale to 64x64 for consistency
            guard let scaled = scaleImage(cropped, targetSize: CGSize(width: 64, height: 64)) else {
                return nil
            }
            
            return HarvestedIcon(
                image: scaled,
                slotIndex: index,
                isUnlocked: status.isUnlocked,
                confidence: status.confidence
            )
        }
    }
    
    /// Harvest icons using sliding window detection (for uncalibrated cards)
    private static func harvestIconsWithSlidingWindow(cg: CGImage, card: UIImage) -> [HarvestedIcon] {
        // Define the passive ability region (bottom-right area of card)
        let passiveRegion = CGRect(x: 0.55, y: 0.75, width: 0.40, height: 0.15)
        
        guard let regionImage = cropNormalized(cg, passiveRegion) else { return [] }
        
        // Scan for icons within this region using a sliding window
        let iconWidth = 0.15  // Width relative to passive region
        let iconHeight = 0.40 // Height relative to passive region
        let stepSize = 0.08   // How much to move the window each step
        
        var foundIcons: [HarvestedIcon] = []
        var slotIndex = 0
        
        // Slide horizontally across the passive region
        var x: CGFloat = 0
        while x + iconWidth <= 1.0 && slotIndex < 5 { // Max 5 passive slots
            let iconRect = CGRect(
                x: x,
                y: 0.1, // Vertically centered in passive region
                width: iconWidth,
                height: iconHeight
            )
            
            guard let iconCrop = cropNormalized(regionImage, iconRect) else {
                x += stepSize
                continue
            }
            
            // Check if this looks like an icon (has some color variation)
            if hasIconContent(iconCrop) {
                // Scale to 64x64 for consistency
                guard let scaled = scaleImage(iconCrop, targetSize: CGSize(width: 64, height: 64)) else {
                    x += stepSize
                    continue
                }
                
                // Detect if this icon is locked/unlocked
                let status = analyzeIconLockStatus(scaled)
                
                foundIcons.append(HarvestedIcon(
                    image: scaled,
                    slotIndex: slotIndex,
                    isUnlocked: status.isUnlocked,
                    confidence: status.confidence
                ))
                
                slotIndex += 1
                x += iconWidth // Jump past this icon
            } else {
                x += stepSize // Small step to find next icon
            }
        }
        
        return foundIcons
    }
    
    /// Quick check if a cropped region contains an icon (not just background)
    private static func hasIconContent(_ image: CGImage) -> Bool {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return false }
        
        // Sample center pixels and check for color variation
        let centerX = w / 2, centerY = h / 2
        guard let data = image.dataProvider?.data as Data? else { return false }
        let bytes = [UInt8](data)
        
        var hasColor = false
        let sampleSize = min(10, w / 2)
        
        for dy in -sampleSize...sampleSize {
            for dx in -sampleSize...sampleSize {
                let x = centerX + dx, y = centerY + dy
                guard x >= 0, x < w, y >= 0, y < h else { continue }
                
                let idx = (y * w + x) * 4
                guard idx + 2 < bytes.count else { continue }
                
                let r = Int(bytes[idx])
                let g = Int(bytes[idx + 1])
                let b = Int(bytes[idx + 2])
                
                // Check for color variation (not pure gray/beige background)
                let variance = abs(r - g) + abs(g - b) + abs(b - r)
                if variance > 30 { // Has some color
                    hasColor = true
                    break
                }
            }
            if hasColor { break }
        }
        
        return hasColor
    }
    
    /// Analyze if an icon is locked or unlocked using color
    private static func analyzeIconLockStatus(_ image: UIImage) -> (isUnlocked: Bool, confidence: Double) {
        guard let cg = image.cgImage else { return (false, 0) }
        
        // Use the same LAB colorfulness check as AbilityDetector
        let status = AbilityDetector.detectPassives(in: image).first ?? AbilityIconStatus(isUnlocked: false, confidence: 0)
        return (status.isUnlocked, status.confidence)
    }
    
    /// Save harvested icons to Documents/Icons/ and append to harvest log.
    public static func saveHarvest(_ icons: [HarvestedIcon], managerId: String, managerName: String, sourceImage: UIImage? = nil) throws {
        let docsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let iconsDir = docsURL.appendingPathComponent("Icons", isDirectory: true)
        try FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
        
        // Save source screenshot for alignment adjustments
        if let sourceImage, let pngData = sourceImage.pngData() {
            let sourceURL = iconsDir.appendingPathComponent("\(managerId)_source.png")
            try pngData.write(to: sourceURL)
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var logEntries: [String] = []
        
        for icon in icons {
            let lockStatus = icon.isUnlocked ? "unlocked" : "locked"
            let filename = "\(managerId)_\(icon.slotIndex)_\(lockStatus)_\(Int(icon.confidence * 100)).png"
            let fileURL = iconsDir.appendingPathComponent(filename)
            
            // Save PNG
            if let pngData = icon.image.pngData() {
                try pngData.write(to: fileURL)
            }
            
            // CSV row: filename, managerId, managerName, slotIndex, isUnlocked, confidence, createdAt
            let csvRow = "\"\(filename)\",\"\(managerId)\",\"\(managerName)\",\(icon.slotIndex),\(icon.isUnlocked),\(String(format: "%.2f", icon.confidence)),\"\(timestamp)\""
            logEntries.append(csvRow)
        }
        
        // Append to _harvest.csv
        let csvURL = iconsDir.appendingPathComponent("_harvest.csv")
        let csvHeader = "filename,managerId,managerName,slotIndex,isUnlocked,confidence,createdAt\n"
        
        if !FileManager.default.fileExists(atPath: csvURL.path) {
            try csvHeader.write(to: csvURL, atomically: true, encoding: .utf8)
        }
        
        let csvContent = logEntries.joined(separator: "\n") + "\n"
        if let handle = try? FileHandle(forWritingTo: csvURL) {
            handle.seekToEndOfFile()
            if let data = csvContent.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }
    }
    
    // MARK: - Helpers
    
    private static func cropNormalized(_ cg: CGImage, _ n: CGRect) -> CGImage? {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let rect = CGRect(
            x: n.origin.x * w,
            y: n.origin.y * h,
            width: n.size.width * w,
            height: n.size.height * h
        )
        .integral
        .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        
        return cg.cropping(to: rect)
    }
    
    private static func scaleImage(_ cg: CGImage, targetSize: CGSize) -> UIImage? {
        let w = Int(targetSize.width)
        let h = Int(targetSize.height)
        
        guard let ctx = CGContext(
            data: nil,
            width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        
        guard let scaled = ctx.makeImage() else { return nil }
        return UIImage(cgImage: scaled)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
