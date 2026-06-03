import Foundation
import UIKit

public struct RecognizedSM: Identifiable, Hashable {
  public let id: UUID
  public let sourceImage: UIImage
  public let rawText: String
  public let level: Int?
  public let directoryMatch: SMDirectoryEntry?
  public let resolvedName: String
  public let stats: SMStats
  public let storedImageName: String?
  public let imageFingerprint: ImageFingerprint?
  public let rarity: String?
  public let role: String?
  public let stars: Int?
  public let fragments: Int?
  public let active: ActiveInfo
  public let passive: PassiveInfo
  public let actions: ActionFlags

  public enum StatUnit: String, Codable, Hashable, Sendable {
    case x
    case percent
  }

  public enum StatState: String, Codable, Hashable, Sendable {
    case unlocked
    case locked
    case absent
  }

  public struct StatSlot: Codable, Hashable {
    public let slot: Int
    public let state: StatState
    public let value: Double?
    public let unit: StatUnit?

    public init(slot: Int, state: StatState, value: Double? = nil, unit: StatUnit? = nil) {
      self.slot = slot
      self.state = state
      self.value = value
      self.unit = unit
    }
  }

  public struct ActiveEffect: Codable, Hashable {
    public let value: Double
    public let unit: StatUnit

    public init(value: Double, unit: StatUnit) {
      self.value = value
      self.unit = unit
    }
  }

  public struct ActiveInfo: Hashable, Codable {
    /// Human-readable effect description (best-effort from OCR).
    public let effect: String?

    /// Back-compat: when the active effect is an `x` multiplier, this is populated.
    public let multiplier: Double?

    /// New: the active effect as a typed value (supports both `x` and `%`).
    public let effectValue: ActiveEffect?

    public let durationSeconds: Int?
    public let cooldownSeconds: Int?

    public init(
      effect: String? = nil,
      multiplier: Double? = nil,
      effectValue: ActiveEffect? = nil,
      durationSeconds: Int? = nil,
      cooldownSeconds: Int? = nil
    ) {
      self.effect = effect
      self.multiplier = multiplier
      self.effectValue = effectValue
      self.durationSeconds = durationSeconds
      self.cooldownSeconds = cooldownSeconds
    }

    var isEmpty: Bool {
      effect == nil && multiplier == nil && effectValue == nil && durationSeconds == nil && cooldownSeconds == nil
    }
  }

  public struct PassiveInfo: Hashable, Codable {
    /// Human-readable effect description (best-effort from OCR).
    public let effect: String?

    /// Back-compat: when the primary passive is an `x` multiplier, this is populated.
    public let multiplier: Double?

    public let durationSeconds: Int?

    /// Status of the 3 passive ability slots (top, middle, bottom). True = unlocked/colorized, false = locked/gray.
    /// Note: a locked slot may still have a *visible* numeric value on the card.
    public let unlockedSlots: [Bool]

    /// New: per-slot typed values and states (unlocked / locked / absent).
    /// Always store up to 3 slots when possible.
    public let slots: [StatSlot]

    public init(
      effect: String? = nil,
      multiplier: Double? = nil,
      durationSeconds: Int? = nil,
      unlockedSlots: [Bool] = [],
      slots: [StatSlot] = []
    ) {
      self.effect = effect
      self.multiplier = multiplier
      self.durationSeconds = durationSeconds
      self.unlockedSlots = unlockedSlots
      self.slots = slots
    }

    var isEmpty: Bool {
      effect == nil && multiplier == nil && durationSeconds == nil && unlockedSlots.isEmpty && slots.isEmpty
    }
  }

  public struct ActionFlags: Hashable, Codable {
    public let hasLevelUp: Bool
    public let hasPromote: Bool
    public let hasRankUp: Bool

    public init(hasLevelUp: Bool = false, hasPromote: Bool = false, hasRankUp: Bool = false) {
      self.hasLevelUp = hasLevelUp
      self.hasPromote = hasPromote
      self.hasRankUp = hasRankUp
    }

    var isEmpty: Bool { !hasLevelUp && !hasPromote && !hasRankUp }
  }

  public init(
    id: UUID = .init(),
    sourceImage: UIImage,
    rawText: String,
    level: Int?,
    directoryMatch: SMDirectoryEntry?,
    resolvedName: String,
    stats: SMStats,
    storedImageName: String? = nil,
    imageFingerprint: ImageFingerprint? = nil,
    rarity: String? = nil,
    role: String? = nil,
    stars: Int? = nil,
    fragments: Int? = nil,
    active: ActiveInfo = .init(),
    passive: PassiveInfo = .init(),
    actions: ActionFlags = .init()
  ) {
    self.id = id
    self.sourceImage = sourceImage
    self.rawText = rawText
    self.level = level
    self.directoryMatch = directoryMatch
    self.resolvedName = resolvedName
    self.stats = stats
    self.storedImageName = storedImageName
    self.imageFingerprint = imageFingerprint
    self.rarity = rarity
    self.role = role
    self.stars = stars
    self.fragments = fragments
    self.active = active
    self.passive = passive
    self.actions = actions
  }

  public var confidence: Double {
    (level != nil ? 0.5 : 0) + (directoryMatch != nil ? 0.5 : 0)
  }

  /// Elements (affinities) as defined by the directory, if available.
  public var elements: [SMElement] {
    guard let elements = directoryMatch?.elements, !elements.isEmpty else { return [] }
    return elements.map(SMElement.init)
  }

  /// A compact string suitable for UI/prompt usage.
  public var elementAffinityDisplay: String {
    let values = elements.map { $0.name }.filter { !$0.isEmpty }
    return values.isEmpty ? "Unknown" : values.joined(separator: ", ")
  }

  public var departmentDisplay: String {
    if let roleDisplay = roleDisplay {
      return roleDisplay
    }
    return directoryMatch?.department.capitalized ?? "Unknown"
  }

  public var primaryBoostString: String {
    if let typed = active.effectValue {
      switch typed.unit {
      case .percent:
        return Self.percentString(fromPercentValue: typed.value)
      case .x:
        return Self.percentString(fromMultiplier: typed.value)
      }
    }
    if let value = active.multiplier {
      return Self.percentString(fromMultiplier: value)
    }
    if let display = stats.primaryBoostDisplay {
      return display
    }
    if let mult = directoryMatch?.active?.multiplier {
      return Self.percentString(fromMultiplier: mult)
    }
    return "—"
  }

  public var secondaryBoostString: String? {
    if let slot1 = passive.slots.first(where: { $0.slot == 1 }),
       slot1.state != .absent,
       let value = slot1.value,
       let unit = slot1.unit {
      switch unit {
      case .percent:
        return Self.percentString(fromPercentValue: value)
      case .x:
        return Self.percentString(fromMultiplier: value)
      }
    }

    // Back-compat fallback.
    if let value = passive.multiplier {
      return Self.percentString(fromMultiplier: value)
    }

    return stats.secondaryBoostDisplay
  }

  public var primaryBoostScore: Double {
    if let mult = active.multiplier {
      return mult
    }
    if let mult = stats.multipliersDescending.first?.value {
      return mult
    }
    if let percent = stats.percentNumberValues.first {
      return abs(percent) / 100 + 1
    }
    if let mult = directoryMatch?.active?.multiplier {
      return mult
    }
    return 0
  }

  private static func percentString(fromMultiplier multiplier: Double) -> String {
    let percent = (multiplier - 1) * 100
    if percent == 0 { return "0%" }
    if percent > 0 {
      return String(format: "+%.0f%%", percent.rounded())
    }
    return String(format: "%.0f%%", percent.rounded())
  }

  private static func percentString(fromPercentValue value: Double) -> String {
    if value == 0 { return "0%" }
    if value > 0 {
      return String(format: "+%.0f%%", value.rounded())
    }
    return String(format: "%.0f%%", value.rounded())
  }

  public static func == (lhs: RecognizedSM, rhs: RecognizedSM) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public var identityKey: String {
    if let id = directoryMatch?.id {
      return id
    }

    // If we can't match a directory entry, the OCR-derived name can be wrong (or the same across
    // multiple screenshots), which would collapse distinct cards during import/merge.
    if let digest = imageFingerprint?.pixelDigest {
      return "fp_\(digest)"
    }

    if let hash = imageFingerprint?.perceptualHash {
      return "phash_\(hash)"
    }

    return resolvedName.lowercased()
  }

  public func updating(id newID: UUID, storedImageName: String?) -> RecognizedSM {
    RecognizedSM(
      id: newID,
      sourceImage: sourceImage,
      rawText: rawText,
      level: level,
      directoryMatch: directoryMatch,
      resolvedName: resolvedName,
      stats: stats,
      storedImageName: storedImageName,
      imageFingerprint: imageFingerprint,
      rarity: rarity,
      role: role,
      stars: stars,
      fragments: fragments,
      active: active,
      passive: passive,
      actions: actions
    )
  }

  public func withStoredImageName(_ name: String?) -> RecognizedSM {
    RecognizedSM(
      id: id,
      sourceImage: sourceImage,
      rawText: rawText,
      level: level,
      directoryMatch: directoryMatch,
      resolvedName: resolvedName,
      stats: stats,
      storedImageName: name,
      imageFingerprint: imageFingerprint,
      rarity: rarity,
      role: role,
      stars: stars,
      fragments: fragments,
      active: active,
      passive: passive,
      actions: actions
    )
  }

  public func updatingMetadata(
    resolvedName: String,
    rarity: String?,
    role: String?,
    stars: Int?,
    fragments: Int?,
    active: ActiveInfo,
    passive: PassiveInfo,
    actions: ActionFlags
  ) -> RecognizedSM {
    RecognizedSM(
      id: id,
      sourceImage: sourceImage,
      rawText: rawText,
      level: level,
      directoryMatch: directoryMatch,
      resolvedName: resolvedName,
      stats: stats,
      storedImageName: storedImageName,
      imageFingerprint: imageFingerprint,
      rarity: rarity.nilIfEmpty,
      role: role.nilIfEmpty,
      stars: stars,
      fragments: fragments,
      active: active,
      passive: passive,
      actions: actions
    )
  }

  private var roleDisplay: String? {
    guard let role else { return nil }
    switch role.lowercased() {
    case "mine", "mineshaft": return "Mineshaft"
    case "elevator": return "Elevator"
    case "warehouse": return "Warehouse"
    case "transport": return "Transport"
    default: return role.capitalized
    }
  }
}

private extension Optional where Wrapped == String {
  var nilIfEmpty: String? {
    guard let value = self else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
