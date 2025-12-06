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
  public let active: ActiveInfo
  public let passive: PassiveInfo
  public let actions: ActionFlags

  public struct ActiveInfo: Hashable, Codable {
    public let effect: String?
    public let multiplier: Double?
    public let durationSeconds: Int?
    public let cooldownSeconds: Int?

    public init(effect: String? = nil, multiplier: Double? = nil, durationSeconds: Int? = nil, cooldownSeconds: Int? = nil) {
      self.effect = effect
      self.multiplier = multiplier
      self.durationSeconds = durationSeconds
      self.cooldownSeconds = cooldownSeconds
    }

    var isEmpty: Bool {
      effect == nil && multiplier == nil && durationSeconds == nil && cooldownSeconds == nil
    }
  }

  public struct PassiveInfo: Hashable, Codable {
    public let effect: String?
    public let multiplier: Double?
    public let durationSeconds: Int?
    /// Status of the 3 passive ability slots (top, middle, bottom). True = unlocked/colorized, false = locked/gray.
    public let unlockedSlots: [Bool]

    public init(effect: String? = nil, multiplier: Double? = nil, durationSeconds: Int? = nil, unlockedSlots: [Bool] = []) {
      self.effect = effect
      self.multiplier = multiplier
      self.durationSeconds = durationSeconds
      self.unlockedSlots = unlockedSlots
    }

    var isEmpty: Bool {
      effect == nil && multiplier == nil && durationSeconds == nil
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
    self.active = active
    self.passive = passive
    self.actions = actions
  }

  public var confidence: Double {
    (level != nil ? 0.5 : 0) + (directoryMatch != nil ? 0.5 : 0)
  }

  public var departmentDisplay: String {
    if let roleDisplay = roleDisplay {
      return roleDisplay
    }
    return directoryMatch?.department.capitalized ?? "Unknown"
  }

  public var primaryBoostString: String {
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

  public static func == (lhs: RecognizedSM, rhs: RecognizedSM) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public var identityKey: String {
    directoryMatch?.id ?? resolvedName.lowercased()
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
