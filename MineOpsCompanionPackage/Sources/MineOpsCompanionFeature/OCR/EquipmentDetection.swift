import CoreGraphics
import UIKit

/// Lightweight, non-persistent representation of detected equipment from a Super Manager screenshot.
///
/// This is intentionally a skeleton:
/// - it defines slots + regions
/// - it provides "unknown" defaults
/// - it does NOT attempt robust visual classification yet
public enum SMEquipmentSlot: Int, CaseIterable, Sendable {
    case slot1
    case slot2
    case slot3

    public var displayName: String {
        switch self {
        case .slot1: return "Slot 1"
        case .slot2: return "Slot 2"
        case .slot3: return "Slot 3"
        }
    }
}

public struct SMEquipmentSlotRegion: Hashable, Sendable {
    public let slot: SMEquipmentSlot
    /// Normalized region in image coordinates (0...1).
    public let normalizedRect: CGRect

    public init(slot: SMEquipmentSlot, normalizedRect: CGRect) {
        self.slot = slot
        self.normalizedRect = normalizedRect
    }

    public var isValid: Bool {
        normalizedRect.width > 0 &&
            normalizedRect.height > 0 &&
            normalizedRect.minX >= 0 &&
            normalizedRect.minY >= 0 &&
            normalizedRect.maxX <= 1 &&
            normalizedRect.maxY <= 1
    }
}

public struct SMEquipmentSlotRegions: Sendable {
    public let regions: [SMEquipmentSlotRegion]

    public init(regions: [SMEquipmentSlotRegion]) {
        self.regions = regions
    }

    public static let `default` = SMEquipmentSlotRegions(
        regions: [
            // These are placeholder regions based on typical SM card layout.
            // We’ll refine with calibration once we have labeled ground truth.
            SMEquipmentSlotRegion(slot: .slot1, normalizedRect: CGRect(x: 0.14, y: 0.70, width: 0.16, height: 0.10)),
            SMEquipmentSlotRegion(slot: .slot2, normalizedRect: CGRect(x: 0.42, y: 0.70, width: 0.16, height: 0.10)),
            SMEquipmentSlotRegion(slot: .slot3, normalizedRect: CGRect(x: 0.70, y: 0.70, width: 0.16, height: 0.10))
        ]
    )
}

public enum SMEquipmentDetectionKind: Hashable, Sendable {
    case unknown
    case detected(name: String, confidence: Double)
}

public struct SMDetectedEquipmentSlot: Hashable, Sendable {
    public let slot: SMEquipmentSlot
    public let region: SMEquipmentSlotRegion
    public let kind: SMEquipmentDetectionKind

    public init(slot: SMEquipmentSlot, region: SMEquipmentSlotRegion, kind: SMEquipmentDetectionKind) {
        self.slot = slot
        self.region = region
        self.kind = kind
    }
}

public struct SMDetectedEquipment: Hashable, Sendable {
    public let slots: [SMDetectedEquipmentSlot]

    public init(slots: [SMDetectedEquipmentSlot]) {
        self.slots = slots
    }

    public static func unknown(using regions: SMEquipmentSlotRegions = .default) -> SMDetectedEquipment {
        let slots = SMEquipmentSlot.allCases.map { slot in
            let region = regions.regions.first(where: { $0.slot == slot }) ?? SMEquipmentSlotRegion(slot: slot, normalizedRect: .zero)
            return SMDetectedEquipmentSlot(slot: slot, region: region, kind: .unknown)
        }
        return SMDetectedEquipment(slots: slots)
    }
}

public enum EquipmentDetector {
    /// Skeleton implementation: returns `.unknown` for all slots.
    ///
    /// Next step: crop each region, run template/icon classification, then map to known equipment.
    public static func detect(in image: UIImage, regions: SMEquipmentSlotRegions = .default) -> SMDetectedEquipment {
        _ = image // placeholder (avoids unused warnings if build settings differ)
        return .unknown(using: regions)
    }
}
