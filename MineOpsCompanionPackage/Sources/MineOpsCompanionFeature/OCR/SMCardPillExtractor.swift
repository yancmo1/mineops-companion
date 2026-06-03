import CoreGraphics
import CoreImage
import Foundation
import Vision

/// Extracts "blue pill" numeric tokens (e.g. `5m`, `30m`, `8.08x`, `-14.5%`) from a Super Manager card screenshot.
///
/// This is intentionally deterministic:
/// - Detect candidate pill regions by color + connected components.
/// - OCR only the pill crops (Vision tuned for short tokens).
/// - Parse tokens strictly and assign by layout.
public enum SMCardPillExtractor {

  public struct Token: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
      case duration(seconds: Int)
      case multiplier(Double)        // e.g. 8.08x
      case percent(Double)           // numeric percent e.g. -14.5
      case unknown
    }

    public let raw: String
    public let kind: Kind
    public let confidence: Double
    public let rect: CGRect
    public let source: SourceArea

    public init(raw: String, kind: Kind, confidence: Double, rect: CGRect, source: SourceArea = .unknown) {
      self.raw = raw
      self.kind = kind
      self.confidence = confidence
      self.rect = rect
      self.source = source
    }
  }
  

  /// Strongly-typed numeric value extracted from a pill.
  public struct TypedValue: Sendable, Hashable {
    public let value: Double
    public let unit: RecognizedSM.StatUnit

    public init(value: Double, unit: RecognizedSM.StatUnit) {
      self.value = value
      self.unit = unit
    }
  }

  /// Deterministic area assignment for a pill token (used for debugging and downstream mapping).
  public enum SourceArea: String, Sendable, Hashable {
    case unknown
    case active
    case activeDuration
    case activeCooldown
    case passive
    case passive1
    case passive2
    case passive3
  }

  /// V2 extraction result: tokens annotated with `source` and a typed mapping (internal use only).
  private struct InternalExtractionV2: Sendable, Hashable {
    public let tokens: [Token]
    public let mapping: InternalMappingV2

    public init(tokens: [Token], mapping: InternalMappingV2) {
      self.tokens = tokens
      self.mapping = mapping
    }
  }

  /// V2 mapping: preserves both `x` and `%` units for active/passive values (internal use only).
  private struct InternalMappingV2: Sendable, Hashable {
    public let activeMultiplier: Double?
    public let activeDurationSeconds: Int?
    public let activeCooldownSeconds: Int?

    /// Typed active effect (supports both `x` and `%`).
    public let activeValue: TypedValue?

    /// Typed passive values in the detected slot order (slot 1..3). May be fewer than 3.
    public let passive: [TypedValue]

    public init(
      activeMultiplier: Double? = nil,
      activeDurationSeconds: Int? = nil,
      activeCooldownSeconds: Int? = nil,
      activeValue: TypedValue? = nil,
      passive: [TypedValue] = []
    ) {
      self.activeMultiplier = activeMultiplier
      self.activeDurationSeconds = activeDurationSeconds
      self.activeCooldownSeconds = activeCooldownSeconds

      // If caller didn’t provide a typed value but did provide a multiplier, derive `.x`.
      if let activeValue {
        self.activeValue = activeValue
      } else if let activeMultiplier {
        self.activeValue = TypedValue(value: activeMultiplier, unit: .x)
      } else {
        self.activeValue = nil
      }

      self.passive = passive
    }
  }
  public struct Extraction: Sendable, Hashable {
    public let tokens: [Token]

    /// Best-effort mapping into the existing domain model fields.
    public let activeMultiplier: Double?
    public let activeDurationSeconds: Int?
    public let activeCooldownSeconds: Int?

    /// Best-effort single passive value (the app model currently supports only one).
    public let passiveMultiplier: Double?

    public init(
      tokens: [Token],
      activeMultiplier: Double?,
      activeDurationSeconds: Int?,
      activeCooldownSeconds: Int?,
      passiveMultiplier: Double?
    ) {
      self.tokens = tokens
      self.activeMultiplier = activeMultiplier
      self.activeDurationSeconds = activeDurationSeconds
      self.activeCooldownSeconds = activeCooldownSeconds
      self.passiveMultiplier = passiveMultiplier
    }
  }

  /// Main entry point.
  /// - Returns: Parsed token mapping and the raw pill tokens detected.
  public static func extract(from cgImage: CGImage) async -> Extraction {
    // 1) Detect candidate pill rectangles.
    let rects = detectPillRects(in: cgImage)
    guard !rects.isEmpty else {
      return Extraction(tokens: [], activeMultiplier: nil, activeDurationSeconds: nil, activeCooldownSeconds: nil, passiveMultiplier: nil)
    }

    // 2) OCR each rect and parse token.
    var tokens: [Token] = []
    tokens.reserveCapacity(rects.count)

    for rect in rects {
      guard let crop = cgImage.cropping(to: rect.integral) else { continue }
      let processed = preprocessPillCrop(crop)
      let result = await OCRTextRecognizer.recognizeToken(from: processed ?? crop)
      let raw = normalizeTokenText(result.text)
      guard !raw.isEmpty else { continue }
      let kind = parseToken(raw)
      tokens.append(Token(raw: raw, kind: kind, confidence: result.confidence, rect: rect))
    }

    // 3) Assign meaning deterministically by position.
    let mapping = SMCardPillTokenAssigner.assign(tokens: tokens, imageSize: CGSize(width: cgImage.width, height: cgImage.height))

    return Extraction(
      tokens: tokens,
      activeMultiplier: mapping.activeMultiplier,
      activeDurationSeconds: mapping.activeDurationSeconds,
      activeCooldownSeconds: mapping.activeCooldownSeconds,
      passiveMultiplier: mapping.passiveMultiplier
    )
  }

  /// V2 entry point.
  /// - Returns: Tokens annotated with a deterministic `source` plus a MappingV2 that preserves passive units.
  public static func extractV2(from cgImage: CGImage) async -> ExtractionV2 {
    // 1) Detect candidate pill rectangles.
    let rects = detectPillRects(in: cgImage)
    guard !rects.isEmpty else {
      return ExtractionV2(
        tokens: [],
        mapping: MappingV2(activeMultiplier: nil, activeDurationSeconds: nil, activeCooldownSeconds: nil, passive: [])
      )
    }

    // 2) OCR each rect and parse token.
    // V2 improvement: prefer a parseable candidate string when confidence differences are small.
    var tokens: [Token] = []
    tokens.reserveCapacity(rects.count)

    for rect in rects {
      guard let crop = cgImage.cropping(to: rect.integral) else { continue }
      let processed = preprocessPillCrop(crop)
      let candidates = await OCRTextRecognizer.recognizeTokenCandidates(from: processed ?? crop)

      guard let chosen = chooseBestCandidateV2(candidates) else { continue }
      let raw = normalizeTokenText(chosen.text)
      guard !raw.isEmpty else { continue }
      let kind = parseToken(raw)
      tokens.append(Token(raw: raw, kind: kind, confidence: chosen.confidence, rect: rect, source: .unknown))
    }

    let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
    let selection = SMCardPillTokenAssigner.selectionForTaggingV2(tokens: tokens, imageSize: imageSize)

    // 3) Re-tag tokens with deterministic sources (map from external SourceArea to internal).
    let taggedTokens: [Token] = tokens.enumerated().map { idx, token in
      let externalSrc = selection.sourcesByIndex[idx]
      let src: SourceArea
      if let externalSrc = externalSrc {
        switch externalSrc {
        case .activeMultiplier:
          src = .active
        case .activeDuration:
          src = .activeDuration
        case .activeCooldown:
          src = .activeCooldown
        case .passiveSlot(let slot):
          switch slot {
          case 0: src = .passive1
          case 1: src = .passive2
          case 2: src = .passive3
          default: src = .passive
          }
        case .unknown:
          src = .unknown
        }
      } else {
        src = .unknown
      }
      return Token(raw: token.raw, kind: token.kind, confidence: token.confidence, rect: token.rect, source: src)
    }

    let internalMapping = Self.buildInternalMappingV2(from: taggedTokens)
    
    // Convert internal MappingV2 (with TypedValue) to external MappingV2 (with PassiveValue)
    let passiveValues: [PassiveValue] = internalMapping.passive.enumerated().map { index, typedVal in
      let unit: PassiveValue.Unit
      switch typedVal.unit {
      case .x:
        unit = .multiplier
      case .percent:
        unit = .percent
      }
      
      let derivedMultiplier: Double?
      if typedVal.unit == .x {
        derivedMultiplier = typedVal.value
      } else if typedVal.unit == .percent {
        derivedMultiplier = 1.0 + (typedVal.value / 100.0)
      } else {
        derivedMultiplier = nil
      }
      
      return PassiveValue(
        slot: index,
        raw: "\(typedVal.value)\(typedVal.unit == .x ? "x" : "%")",
        value: typedVal.value,
        unit: unit,
        derivedMultiplier: derivedMultiplier,
        confidence: 1.0  // We don't track individual confidence after selection
      )
    }
    
    let externalMapping = MappingV2(
      activeMultiplier: internalMapping.activeMultiplier,
      activeDurationSeconds: internalMapping.activeDurationSeconds,
      activeCooldownSeconds: internalMapping.activeCooldownSeconds,
      passive: passiveValues
    )
    
    return ExtractionV2(tokens: taggedTokens, mapping: externalMapping)
  }

  // MARK: - Token parsing

  private static func parseToken(_ raw: String) -> Token.Kind {
    // Percent: "-14.5%" or "14.5%"
    if let percent = Regex.percent.firstMatch(in: raw) {
      return .percent(percent)
    }

    // Multiplier: "8.08x" or "37x"
    if let multiplier = Regex.multiplier.firstMatch(in: raw) {
      return .multiplier(multiplier)
    }

    // Duration: "5m", "30m", "2m 30s" (rare in pills but supported)
    if let seconds = DurationParser.seconds(from: raw) {
      return .duration(seconds: seconds)
    }

    return .unknown
  }

  private struct CandidateV2: Sendable {
    let text: String
    let confidence: Double
  }

  private static func chooseBestCandidateV2(_ candidates: [OCRTextRecognizer.TokenCandidate]) -> CandidateV2? {
    guard !candidates.isEmpty else { return nil }

    let bestByConfidence = candidates.max(by: { $0.confidence < $1.confidence })
    let bestConfidence = bestByConfidence?.confidence ?? 0

    // If a candidate parses (after normalization) and is close in confidence to the best,
    // prefer it over a slightly higher-confidence but non-parseable string.
    let confidenceSlack: Double = 0.06

    var bestParseable: CandidateV2?
    for c in candidates {
      if bestConfidence - c.confidence > confidenceSlack { continue }

      let raw = normalizeTokenText(c.text)
      guard !raw.isEmpty else { continue }
      let kind = parseToken(raw)
      if case .unknown = kind { continue }

      let candidate = CandidateV2(text: c.text, confidence: c.confidence)
      if let existing = bestParseable {
        if candidate.confidence > existing.confidence { bestParseable = candidate }
      } else {
        bestParseable = candidate
      }
    }

    if let bestParseable {
      return bestParseable
    }

    // Fallback: best confidence.
    if let bestByConfidence {
      return CandidateV2(text: bestByConfidence.text, confidence: bestByConfidence.confidence)
    }

    return nil
  }

  private static func normalizeTokenText(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    // Basic cleanup and common OCR confusions in numeric contexts.
    var s = trimmed
      .replacingOccurrences(of: "×", with: "x")
      .replacingOccurrences(of: ",", with: ".")

    // Keep only characters we expect in pills.
    let allowed = CharacterSet(charactersIn: "0123456789.+-%xXhHrRmMsS ")
    s = String(s.unicodeScalars.filter { allowed.contains($0) }.map(Character.init))

    // Fix common misreads: O→0, I/l→1 when surrounded by digits.
    s = TokenFixups.fix(s)

    // Normalize whitespace.
    s = s.replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return s
  }

  // MARK: - Detection

  private static func detectPillRects(in cgImage: CGImage) -> [CGRect] {
    // Downsample for fast scanning.
    let targetWidth = 280
    guard let sample = Downsampler.downsampleRGBA(cgImage, targetWidth: targetWidth) else { return [] }

    let w = sample.width
    let h = sample.height
    if w == 0 || h == 0 { return [] }

    // Limit search to bottom portion where Active/Passive panels appear.
    let yStart = Int(Double(h) * 0.50)
    let yEnd = Int(Double(h) * 0.95)
    if yEnd <= yStart { return [] }

    let visitedCount = w * h
    var visited = [Bool](repeating: false, count: visitedCount)

    func index(_ x: Int, _ y: Int) -> Int { y * w + x }

    var boxes: [CGRect] = []

    for y in yStart..<yEnd {
      for x in 0..<w {
        let idx = index(x, y)
        if visited[idx] { continue }
        visited[idx] = true

        if !isPillBlue(sample, x: x, y: y) { continue }

        // Flood fill component.
        var minX = x, maxX = x
        var minY = y, maxY = y
        var count = 0
        var stack: [(Int, Int)] = [(x, y)]

        while let (cx, cy) = stack.popLast() {
          count += 1
          minX = min(minX, cx); maxX = max(maxX, cx)
          minY = min(minY, cy); maxY = max(maxY, cy)

          // 4-neighbors.
          let neighbors = [(cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)]
          for (nx, ny) in neighbors {
            if nx < 0 || nx >= w || ny < yStart || ny >= yEnd { continue }
            let nIdx = index(nx, ny)
            if visited[nIdx] { continue }
            visited[nIdx] = true
            if isPillBlue(sample, x: nx, y: ny) {
              stack.append((nx, ny))
            }
          }
        }

        // Filter by size (in downsample pixels).
        let boxW = maxX - minX + 1
        let boxH = maxY - minY + 1
        let area = boxW * boxH
        if area < 100 { continue }

        // Filter by aspect and max size to avoid buttons.
        let aspect = Double(boxW) / Double(max(1, boxH))
        if aspect < 1.0 || aspect > 6.0 { continue }

        // Reject very wide components (buttons).
        if Double(boxW) > Double(w) * 0.42 { continue }

        boxes.append(CGRect(x: minX, y: minY, width: boxW, height: boxH))
      }
    }

    // Convert back to original image coordinates, pad slightly, and de-dup overlapping boxes.
    let scaleX = Double(cgImage.width) / Double(sample.width)
    let scaleY = Double(cgImage.height) / Double(sample.height)

    var rects: [CGRect] = boxes
      .map { box in
        var r = CGRect(
          x: Double(box.minX) * scaleX,
          y: Double(box.minY) * scaleY,
          width: Double(box.width) * scaleX,
          height: Double(box.height) * scaleY
        )

        // Pad to capture glyph edges.
        let padX = r.width * 0.15
        let padY = r.height * 0.25
        r = r.insetBy(dx: -padX, dy: -padY)

        // Clamp.
        r.origin.x = max(0, r.origin.x)
        r.origin.y = max(0, r.origin.y)
        r.size.width = min(CGFloat(cgImage.width) - r.origin.x, r.size.width)
        r.size.height = min(CGFloat(cgImage.height) - r.origin.y, r.size.height)
        return r.integral
      }

    rects = RectDeduper.dedupe(rects: rects, iouThreshold: 0.35)

    // Prefer top-to-bottom, left-to-right ordering (stable output)
    rects.sort { a, b in
      if abs(a.midY - b.midY) > 6 { return a.midY < b.midY }
      return a.midX < b.midX
    }

    return rects
  }

  private static func isPillBlue(_ sample: Downsampler.Sample, x: Int, y: Int) -> Bool {
    let (r, g, b, a) = sample.rgba(x: x, y: y)
    if a < 80 { return false }

    // Avoid very dark or near-white areas.
    if r < 20 && g < 20 && b < 20 { return false }
    if r > 245 && g > 245 && b > 245 { return false }

    // Convert to HSB for robust color matching across different screen calibrations.
    let rf = Double(r) / 255.0
    let gf = Double(g) / 255.0
    let bf = Double(b) / 255.0

    let cMax = max(rf, gf, bf)
    let cMin = min(rf, gf, bf)
    let delta = cMax - cMin

    // If delta is near zero, it's grayscale — not a pill.
    if delta < 0.03 { return false }

    let saturation = (cMax > 0) ? (delta / cMax) : 0
    let brightness = cMax

    var hue: Double
    if cMax == rf {
      hue = 60 * (((gf - bf) / delta).truncatingRemainder(dividingBy: 6))
    } else if cMax == gf {
      hue = 60 * (((bf - rf) / delta) + 2)
    } else {
      hue = 60 * (((rf - gf) / delta) + 4)
    }
    if hue < 0 { hue += 360 }

    // The SM card pills are dark steel-blue / navy-blue capsules.
    // Observed hue range: ~195–230° (steel-blue to blue).
    // Also accept lighter blue-teal pills: ~180–240°.
    // Saturation: moderate to strong (0.20–0.90).
    // Brightness: moderate (0.25–0.85) — distinctly colored, not washed out.
    let hueMatch = (hue >= 180 && hue <= 240)
    let satMatch = (saturation >= 0.20 && saturation <= 0.90)
    let briMatch = (brightness >= 0.25 && brightness <= 0.85)

    return hueMatch && satMatch && briMatch
  }

  // MARK: - Preprocessing

  private static func preprocessPillCrop(_ cgImage: CGImage) -> CGImage? {
    let ci = CIImage(cgImage: cgImage)

    let grayscale = ci.applyingFilter("CIColorControls", parameters: [
      kCIInputSaturationKey: 0.0,
      kCIInputContrastKey: 1.55,
      kCIInputBrightnessKey: 0.0
    ])

    let sharpened = grayscale.applyingFilter("CISharpenLuminance", parameters: [
      kCIInputSharpnessKey: 0.55
    ])

    let scaled = sharpened.applyingFilter("CILanczosScaleTransform", parameters: [
      kCIInputScaleKey: 2.2,
      kCIInputAspectRatioKey: 1.0
    ])

    let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
    return context.createCGImage(scaled, from: scaled.extent)
  }

  // MARK: - V2 typed mapping

  private static func buildInternalMappingV2(from taggedTokens: [Token]) -> InternalMappingV2 {
    func firstToken(in area: SourceArea) -> Token? {
      taggedTokens
        .filter { $0.source == area }
        .sorted(by: { $0.confidence > $1.confidence })
        .first
    }

    // Active duration / cooldown come from duration pills.
    let activeDurationSeconds: Int? = {
      guard let t = firstToken(in: .activeDuration) else { return nil }
      if case .duration(let s) = t.kind { return s }
      return nil
    }()

    let activeCooldownSeconds: Int? = {
      guard let t = firstToken(in: .activeCooldown) else { return nil }
      if case .duration(let s) = t.kind { return s }
      return nil
    }()

    // Active effect can be either x or percent.
    let activeTyped: TypedValue? = {
      guard let t = firstToken(in: .active) else { return nil }
      return typedValue(from: t.kind)
    }()

    // For back-compat, also expose activeMultiplier when typed is `.x`.
    let activeMultiplier: Double? = {
      guard let activeTyped else { return nil }
      guard activeTyped.unit == .x else { return nil }
      return activeTyped.value
    }()

    // Passive values should be in slot order 1..3 when available.
    let passiveTyped: [TypedValue] = [
      firstToken(in: .passive1),
      firstToken(in: .passive2),
      firstToken(in: .passive3)
    ].compactMap { token in
      guard let token else { return nil }
      return typedValue(from: token.kind)
    }

    return InternalMappingV2(
      activeMultiplier: activeMultiplier,
      activeDurationSeconds: activeDurationSeconds,
      activeCooldownSeconds: activeCooldownSeconds,
      activeValue: activeTyped,
      passive: passiveTyped
    )
  }

  private static func typedValue(from kind: Token.Kind) -> TypedValue? {
    switch kind {
    case .multiplier(let m):
      return TypedValue(value: m, unit: .x)
    case .percent(let p):
      return TypedValue(value: p, unit: .percent)
    default:
      return nil
    }
  }
}

// MARK: - Supporting utilities

private enum Regex {
  static let percent = TokenRegex(#"([+\-]?\s*[0-9]{1,3}(?:\.[0-9]{1,2})?)\s*%"#)
  static let multiplier = TokenRegex(#"([0-9]{1,4}(?:\.[0-9]{1,3})?)\s*[xX]"#)

  struct TokenRegex {
    let re: NSRegularExpression
    init(_ pattern: String) {
      self.re = try! NSRegularExpression(pattern: pattern, options: [])
    }

    func firstMatch(in text: String) -> Double? {
      let range = NSRange(text.startIndex..<text.endIndex, in: text)
      guard let m = re.firstMatch(in: text, range: range),
            let r = Range(m.range(at: 1), in: text)
      else { return nil }

      let raw = text[r].replacingOccurrences(of: " ", with: "")
      return Double(raw)
    }
  }
}

private enum DurationParser {
  // Supports strings like: "5m", "30m", "2m 30s", "1h"
  private static let re = try! NSRegularExpression(
    pattern: #"(?i)([0-9]{1,3})\s*(h|hr|hrs|m|min|mins|s|sec|secs)"#,
    options: []
  )

  static func seconds(from text: String) -> Int? {
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    let matches = re.matches(in: text, range: range)
    guard !matches.isEmpty else { return nil }

    var total = 0
    for m in matches {
      guard let vRange = Range(m.range(at: 1), in: text),
            let uRange = Range(m.range(at: 2), in: text)
      else { continue }

      let value = Int(text[vRange]) ?? 0
      let unit = text[uRange].lowercased()

      switch unit {
      case "h", "hr", "hrs": total += value * 3600
      case "m", "min", "mins": total += value * 60
      default: total += value
      }
    }

    return total > 0 ? total : nil
  }
}

private enum TokenFixups {
  static func fix(_ text: String) -> String {
    // Replace O→0, I/l→1 only when next to digits.
    var out = ""
    out.reserveCapacity(text.count)

    let chars = Array(text)
    for i in chars.indices {
      let c = chars[i]
      let prevIsDigit = i > 0 ? chars[i - 1].isNumber : false
      let nextIsDigit = i + 1 < chars.count ? chars[i + 1].isNumber : false

      if (c == "O" || c == "o") && (prevIsDigit || nextIsDigit) {
        out.append("0")
      } else if (c == "I" || c == "l") && (prevIsDigit || nextIsDigit) {
        out.append("1")
      } else {
        out.append(c)
      }
    }

    return out
  }
}

private enum Downsampler {
  struct Sample {
    let width: Int
    let height: Int
    let bytes: [UInt8] // RGBA

    func rgba(x: Int, y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
      let idx = (y * width + x) * 4
      if idx + 3 >= bytes.count { return (0, 0, 0, 0) }
      return (
        Int(bytes[idx + 0]),
        Int(bytes[idx + 1]),
        Int(bytes[idx + 2]),
        Int(bytes[idx + 3])
      )
    }
  }

  static func downsampleRGBA(_ cg: CGImage, targetWidth: Int) -> Sample? {
    let w = cg.width
    let h = cg.height
    guard w > 0, h > 0 else { return nil }

    let scale = Double(targetWidth) / Double(w)
    let dstW = max(32, Int(Double(w) * scale))
    let dstH = max(32, Int(Double(h) * scale))

    var buf = [UInt8](repeating: 0, count: dstW * dstH * 4)

    guard let ctx = CGContext(
      data: &buf,
      width: dstW,
      height: dstH,
      bitsPerComponent: 8,
      bytesPerRow: dstW * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.interpolationQuality = .low
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: dstW, height: dstH))

    return Sample(width: dstW, height: dstH, bytes: buf)
  }
}

private enum RectDeduper {
  static func dedupe(rects: [CGRect], iouThreshold: Double) -> [CGRect] {
    var kept: [CGRect] = []

    for r in rects {
      if kept.contains(where: { iou(a: $0, b: r) >= iouThreshold }) {
        continue
      }
      kept.append(r)
    }

    return kept
  }

  private static func iou(a: CGRect, b: CGRect) -> Double {
    let inter = a.intersection(b)
    if inter.isNull || inter.isEmpty { return 0 }
    let interArea = inter.width * inter.height
    let unionArea = a.width * a.height + b.width * b.height - interArea
    if unionArea <= 0 { return 0 }
    return Double(interArea / unionArea)
  }
}