import CoreGraphics
import Foundation

/// Pure layout-based mapping from detected pill tokens to app fields.
///
/// This is intentionally conservative: it only assigns values when the signal is strong.
public enum SMCardPillTokenAssigner {

  public struct Mapping: Sendable, Hashable {
    public let activeMultiplier: Double?
    public let activeDurationSeconds: Int?
    public let activeCooldownSeconds: Int?
    public let passiveMultiplier: Double?

    public init(activeMultiplier: Double?, activeDurationSeconds: Int?, activeCooldownSeconds: Int?, passiveMultiplier: Double?) {
      self.activeMultiplier = activeMultiplier
      self.activeDurationSeconds = activeDurationSeconds
      self.activeCooldownSeconds = activeCooldownSeconds
      self.passiveMultiplier = passiveMultiplier
    }
  }

  public static func assign(tokens: [SMCardPillExtractor.Token], imageSize: CGSize) -> Mapping {
    guard !tokens.isEmpty, imageSize.width > 0, imageSize.height > 0 else {
      return Mapping(activeMultiplier: nil, activeDurationSeconds: nil, activeCooldownSeconds: nil, passiveMultiplier: nil)
    }

    // Split left vs right by clustering the pill x-centers.
    // Why: active time pills often sit near the middle divider; using the screen midX is brittle.
    let splitX = Self.estimatedSplitX(for: tokens, imageSize: imageSize)

    let left = tokens.filter { $0.rect.midX < splitX }
    let right = tokens.filter { $0.rect.midX >= splitX }

    // Active duration/cooldown: duration tokens on left side, ordered by y (top = duration, next = cooldown)
    let durationsLeft: [(y: CGFloat, seconds: Int, conf: Double)] = left.compactMap { token in
      if case let .duration(seconds) = token.kind {
        return (token.rect.midY, seconds, token.confidence)
      }
      return nil
    }.sorted { $0.y < $1.y }

    let activeDurationSeconds = durationsLeft.first?.seconds
    let activeCooldownSeconds = durationsLeft.dropFirst().first?.seconds

    // Active boost token: prefer an explicit x-multiplier on the left, else percent.
    let activeMultiplier = bestMultiplierToken(from: left)

    // Passive: pick the single strongest effect token on the right (model supports only one).
    let passiveMultiplier = bestMultiplierToken(from: right)

    return Mapping(
      activeMultiplier: activeMultiplier,
      activeDurationSeconds: activeDurationSeconds,
      activeCooldownSeconds: activeCooldownSeconds,
      passiveMultiplier: passiveMultiplier
    )
  }

  public static func assignV2(tokens: [SMCardPillExtractor.Token], imageSize: CGSize) -> MappingV2 {
    selectionV2(tokens: tokens, imageSize: imageSize).mapping
  }

  static func selectionForTaggingV2(tokens: [SMCardPillExtractor.Token], imageSize: CGSize) -> (mapping: MappingV2, sourcesByIndex: [Int: SourceArea]) {
    let sel = selectionV2(tokens: tokens, imageSize: imageSize)
    var sources: [Int: SourceArea] = [:]

    if let i = sel.activeMultiplierIndex { sources[i] = .activeMultiplier }
    if let i = sel.activeDurationIndex { sources[i] = .activeDuration }
    if let i = sel.activeCooldownIndex { sources[i] = .activeCooldown }
    for (slot, idx) in sel.passiveIndices.enumerated() {
      sources[idx] = .passiveSlot(slot)
    }

    return (sel.mapping, sources)
  }

  private static func bestMultiplierToken(from tokens: [SMCardPillExtractor.Token]) -> Double? {
    // Convert percent tokens to multiplier to match app conventions.
    let candidates: [(mult: Double, strength: Double, conf: Double)] = tokens.compactMap { token in
      switch token.kind {
      case let .multiplier(mult):
        return (mult, abs(mult - 1), token.confidence)
      case let .percent(p):
        let mult = 1.0 + (p / 100.0)
        return (mult, abs(mult - 1), token.confidence)
      default:
        return nil
      }
    }

    // Prefer candidates with higher OCR confidence; tie-breaker by strength.
    return candidates
      .sorted { a, b in
        if abs(a.conf - b.conf) > 0.08 { return a.conf > b.conf }
        return a.strength > b.strength
      }
      .first
      .map { $0.mult }
  }

  private static func estimatedSplitX(for tokens: [SMCardPillExtractor.Token], imageSize: CGSize) -> CGFloat {
    let xs = tokens.map { $0.rect.midX }.sorted()
    guard xs.count >= 3 else { return imageSize.width / 2 }

    // Choose the biggest gap between consecutive x-centers.
    var bestGap: CGFloat = 0
    var bestIndex: Int?

    for i in 0..<(xs.count - 1) {
      let gap = xs[i + 1] - xs[i]
      if gap > bestGap {
        bestGap = gap
        bestIndex = i
      }
    }

    // If there isn't a meaningful gap, fall back to mid-screen.
    if bestGap < imageSize.width * 0.06 {
      return imageSize.width / 2
    }

    guard let i = bestIndex else { return imageSize.width / 2 }
    return (xs[i] + xs[i + 1]) / 2
  }

  // MARK: - V2

  private struct SelectionV2: Sendable {
    let mapping: MappingV2
    let activeMultiplierIndex: Int?
    let activeDurationIndex: Int?
    let activeCooldownIndex: Int?
    let passiveIndices: [Int] // ordered top->bottom
  }

  private static func selectionV2(tokens: [SMCardPillExtractor.Token], imageSize: CGSize) -> SelectionV2 {
    guard !tokens.isEmpty, imageSize.width > 0, imageSize.height > 0 else {
      return SelectionV2(
        mapping: MappingV2(activeMultiplier: nil, activeDurationSeconds: nil, activeCooldownSeconds: nil, passive: []),
        activeMultiplierIndex: nil,
        activeDurationIndex: nil,
        activeCooldownIndex: nil,
        passiveIndices: []
      )
    }

    let splitX = Self.estimatedSplitX(for: tokens, imageSize: imageSize)

    let indexed = Array(tokens.enumerated())
    let left = indexed.filter { $0.element.rect.midX < splitX }
    let right = indexed.filter { $0.element.rect.midX >= splitX }

    // Active duration/cooldown: duration tokens on left, ordered by y (top = duration, next = cooldown)
    var durationsLeft: [(idx: Int, y: CGFloat, seconds: Int)] = left.compactMap { (idx, token) in
      guard case let .duration(seconds) = token.kind else { return nil }
      guard isSaneDuration(seconds) else { return nil }
      return (idx, token.rect.midY, seconds)
    }.sorted { $0.y < $1.y }

    var activeDurationIndex: Int? = durationsLeft.first?.idx
    var activeCooldownIndex: Int? = durationsLeft.dropFirst().first?.idx

    var activeDurationSeconds: Int? = activeDurationIndex.map { idx in
      if case let .duration(seconds) = tokens[idx].kind { return seconds }
      return nil
    } ?? nil

    var activeCooldownSeconds: Int? = activeCooldownIndex.map { idx in
      if case let .duration(seconds) = tokens[idx].kind { return seconds }
      return nil
    } ?? nil

    // Sanity swap: cooldown should be >= duration.
    if let d = activeDurationSeconds, let c = activeCooldownSeconds, c < d {
      swap(&activeDurationSeconds, &activeCooldownSeconds)
      swap(&activeDurationIndex, &activeCooldownIndex)
    }

    // Active multiplier: choose best multiplier token on left; prefer explicit multiplier over percent.
    let activeMultiplierSelection = bestActiveMultiplierSelection(from: left)

    // Passive: collect up to 3 right-side effect tokens (multiplier or percent), ordered top->bottom.
    let passiveOrdered = right
      .filter {
        switch $0.element.kind {
        case .multiplier, .percent: return true
        default: return false
        }
      }
      .sorted { $0.element.rect.midY < $1.element.rect.midY }

    let passiveSlice = Array(passiveOrdered.prefix(3))
    let passiveValues: [PassiveValue] = passiveSlice.enumerated().map { slot, entry in
      let token = entry.element
      switch token.kind {
      case let .multiplier(m):
        return PassiveValue(
          slot: slot,
          raw: token.raw,
          value: m,
          unit: .multiplier,
          derivedMultiplier: m,
          confidence: token.confidence
        )
      case let .percent(p):
        return PassiveValue(
          slot: slot,
          raw: token.raw,
          value: p,
          unit: .percent,
          derivedMultiplier: 1.0 + (p / 100.0),
          confidence: token.confidence
        )
      default:
        return PassiveValue(
          slot: slot,
          raw: token.raw,
          value: nil,
          unit: .unknown,
          derivedMultiplier: nil,
          confidence: token.confidence
        )
      }
    }

    let passiveIndices = passiveSlice.map { $0.offset }

    let mapping = MappingV2(
      activeMultiplier: activeMultiplierSelection.value,
      activeDurationSeconds: activeDurationSeconds,
      activeCooldownSeconds: activeCooldownSeconds,
      passive: passiveValues
    )

    return SelectionV2(
      mapping: mapping,
      activeMultiplierIndex: activeMultiplierSelection.index,
      activeDurationIndex: activeDurationIndex,
      activeCooldownIndex: activeCooldownIndex,
      passiveIndices: passiveIndices
    )
  }

  private struct ActiveMultiplierSelection {
    let value: Double?
    let index: Int?
  }

  private static func bestActiveMultiplierSelection(from tokens: [(offset: Int, element: SMCardPillExtractor.Token)]) -> ActiveMultiplierSelection {
    // Prefer explicit multipliers on the left.
    let multipliers: [(idx: Int, mult: Double, strength: Double, conf: Double)] = tokens.compactMap { (idx, token) in
      guard case let .multiplier(m) = token.kind else { return nil }
      return (idx, m, abs(m - 1), token.confidence)
    }

    if let best = multipliers
      .sorted(by: { a, b in
        if abs(a.conf - b.conf) > 0.08 { return a.conf > b.conf }
        return a.strength > b.strength
      })
      .first {
      return ActiveMultiplierSelection(value: best.mult, index: best.idx)
    }

    // Otherwise consider percent tokens, converted to multiplier.
    let percents: [(idx: Int, mult: Double, strength: Double, conf: Double)] = tokens.compactMap { (idx, token) in
      guard case let .percent(p) = token.kind else { return nil }
      let mult = 1.0 + (p / 100.0)
      return (idx, mult, abs(mult - 1), token.confidence)
    }

    if let best = percents
      .sorted(by: { a, b in
        if abs(a.conf - b.conf) > 0.08 { return a.conf > b.conf }
        return a.strength > b.strength
      })
      .first {
      return ActiveMultiplierSelection(value: best.mult, index: best.idx)
    }

    return ActiveMultiplierSelection(value: nil, index: nil)
  }

  private static func isSaneDuration(_ seconds: Int) -> Bool {
    // Conservative bounds to avoid obvious OCR garbage while still allowing real game values.
    // (V2-only; legacy behavior remains unchanged.)
    guard seconds > 0 else { return false }
    return seconds <= 12 * 3600
  }
}
