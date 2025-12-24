import CoreGraphics
import Foundation

/// V2 deterministic pill extraction models.
///
/// These are additive types used for parallel extraction/mapping (legacy path remains unchanged).
public enum SourceArea: Sendable, Hashable {
  case activeMultiplier
  case activeDuration
  case activeCooldown
  case passiveSlot(Int)      // 0..2 top->bottom
  case unknown
}

public struct PassiveValue: Sendable, Hashable {
  public enum Unit: String, Sendable, Hashable {
    case multiplier
    case percent
    case unknown
  }

  public let slot: Int                 // 0..2
  public let raw: String               // exact OCR text (normalized token)
  public let value: Double?            // numeric value (percent or multiplier)
  public let unit: Unit                // percent or multiplier
  public let derivedMultiplier: Double?  // percent => 1 + p/100, multiplier => m
  public let confidence: Double

  public init(
    slot: Int,
    raw: String,
    value: Double?,
    unit: Unit,
    derivedMultiplier: Double?,
    confidence: Double
  ) {
    self.slot = slot
    self.raw = raw
    self.value = value
    self.unit = unit
    self.derivedMultiplier = derivedMultiplier
    self.confidence = confidence
  }
}

public struct MappingV2: Sendable, Hashable {
  public let activeMultiplier: Double?
  public let activeDurationSeconds: Int?
  public let activeCooldownSeconds: Int?
  public let passive: [PassiveValue]   // 0..3, ordered by slot (top->bottom)

  public init(
    activeMultiplier: Double?,
    activeDurationSeconds: Int?,
    activeCooldownSeconds: Int?,
    passive: [PassiveValue]
  ) {
    self.activeMultiplier = activeMultiplier
    self.activeDurationSeconds = activeDurationSeconds
    self.activeCooldownSeconds = activeCooldownSeconds
    self.passive = passive
  }
}

public struct ExtractionV2: Sendable, Hashable {
  public let tokens: [SMCardPillExtractor.Token]  // includes `source`
  public let mapping: MappingV2

  public init(tokens: [SMCardPillExtractor.Token], mapping: MappingV2) {
    self.tokens = tokens
    self.mapping = mapping
  }
}
