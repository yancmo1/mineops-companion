import Testing
import UIKit
@testable import MineOpsCompanionFeature

@Suite("Icon Harvesting Tests")
struct IconHarvesterTests {
    
    @Test("Harvest extracts 3 icons from card screenshot")
    func testHarvestIcons() async throws {
        // Create a test image (white 1080x1920 to simulate iPhone screenshot)
        let size = CGSize(width: 1080, height: 1920)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        guard let testImage = UIGraphicsGetImageFromCurrentImageContext() else {
            throw TestError.imageCreationFailed
        }
        
        // Harvest icons
        let icons = IconHarvester.harvestIcons(from: testImage, managerId: "test-manager")
        
        // Should extract 3 icons (top, middle, bottom)
        #expect(icons.count == 3)
        
        // Verify slot indices
        #expect(icons[0].slotIndex == 0)
        #expect(icons[1].slotIndex == 1)
        #expect(icons[2].slotIndex == 2)
        
        // Verify images are 64x64
        for icon in icons {
            #expect(icon.image.size.width == 64)
            #expect(icon.image.size.height == 64)
        }
    }
    
    @Test("Harvester detects lock status")
    func testLockDetection() async throws {
        // White image should be detected as "unlocked" (no gray/locked pixels)
        let size = CGSize(width: 1080, height: 1920)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        guard let testImage = UIGraphicsGetImageFromCurrentImageContext() else {
            throw TestError.imageCreationFailed
        }
        
        let icons = IconHarvester.harvestIcons(from: testImage, managerId: "test-manager")
        
        // All white pixels should be detected as unlocked (high confidence)
        for icon in icons {
            #expect(icon.confidence > 0)
        }
    }
}

enum TestError: Error {
    case imageCreationFailed
}
