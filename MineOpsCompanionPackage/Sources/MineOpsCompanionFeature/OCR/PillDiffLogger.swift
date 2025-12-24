import Foundation
import OSLog

@MainActor
public enum PillDiffLogger {

  public struct Record: Codable, Sendable {
    public struct Legacy: Codable, Sendable {
      public let activeMultiplier: Double?
      public let durationSeconds: Int?
      public let cooldownSeconds: Int?
      public let passiveMultiplier: Double?
    }

    public struct V2Passive: Codable, Sendable {
      public let slot: Int
      public let raw: String
      public let unit: String
      public let value: Double?
      public let derivedMultiplier: Double?
      public let confidence: Double
    }

    public struct V2: Codable, Sendable {
      public let activeMultiplier: Double?
      public let durationSeconds: Int?
      public let cooldownSeconds: Int?
      public let passive: [V2Passive]
    }

    public struct Mismatch: Codable, Sendable {
      public let activeMultiplier: Bool
      public let durationSeconds: Bool
      public let cooldownSeconds: Bool
      public let passive: Bool
    }

    public let screenshotID: String
    public let timestampISO8601: String
    public let legacy: Legacy
    public let v2: V2
    public let mismatch: Mismatch
  }

  private static let iso8601: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static var ringBuffer: [String] = []
  private static let ringLimit = 120

  public static func log(
    screenshotID: String,
    timestamp: Date = .now,
    legacy: SMCardPillExtractor.Extraction,
    v2: ExtractionV2
  ) {
    #if DEBUG
    let record = makeRecord(screenshotID: screenshotID, timestamp: timestamp, legacy: legacy, v2: v2)

    // Console summary (compact, greppable).
    let summary = compactSummary(for: record)
    Logger.ocr.info("🟦 PillDiff \(summary, privacy: .public)")

    // Keep a small in-memory history for UI/debug screens.
    ringBuffer.append(summary)
    if ringBuffer.count > ringLimit {
      ringBuffer.removeFirst(ringBuffer.count - ringLimit)
    }

    // Persist JSONL for export.
    appendToJSONL(record)
    #endif
  }

  public static func recentSummaries() -> [String] {
    #if DEBUG
    return ringBuffer
    #else
    return []
    #endif
  }

  public static func diffFileURL() -> URL? {
    #if DEBUG
    return fileURL()
    #else
    return nil
    #endif
  }

  // MARK: - Internals

  #if DEBUG
  private static func makeRecord(
    screenshotID: String,
    timestamp: Date,
    legacy: SMCardPillExtractor.Extraction,
    v2: ExtractionV2
  ) -> Record {
    let legacyBlock = Record.Legacy(
      activeMultiplier: legacy.activeMultiplier,
      durationSeconds: legacy.activeDurationSeconds,
      cooldownSeconds: legacy.activeCooldownSeconds,
      passiveMultiplier: legacy.passiveMultiplier
    )

    let v2Passive: [Record.V2Passive] = v2.mapping.passive.map {
      Record.V2Passive(
        slot: $0.slot,
        raw: $0.raw,
        unit: $0.unit.rawValue,
        value: $0.value,
        derivedMultiplier: $0.derivedMultiplier,
        confidence: $0.confidence
      )
    }

    let v2Block = Record.V2(
      activeMultiplier: v2.mapping.activeMultiplier,
      durationSeconds: v2.mapping.activeDurationSeconds,
      cooldownSeconds: v2.mapping.activeCooldownSeconds,
      passive: v2Passive
    )

    let mismatch = Record.Mismatch(
      activeMultiplier: !approxEqual(legacyBlock.activeMultiplier, v2Block.activeMultiplier, eps: 0.001),
      durationSeconds: legacyBlock.durationSeconds != v2Block.durationSeconds,
      cooldownSeconds: legacyBlock.cooldownSeconds != v2Block.cooldownSeconds,
      passive: !passiveRoughlyMatches(legacy: legacyBlock.passiveMultiplier, v2: v2Block.passive)
    )

    return Record(
      screenshotID: screenshotID,
      timestampISO8601: iso8601.string(from: timestamp),
      legacy: legacyBlock,
      v2: v2Block,
      mismatch: mismatch
    )
  }

  private static func compactSummary(for record: Record) -> String {
    func fmt(_ d: Double?) -> String { d.map { String(format: "%.4f", $0) } ?? "nil" }
    func fmt(_ i: Int?) -> String { i.map(String.init) ?? "nil" }

    let legacy = "L{a=\(fmt(record.legacy.activeMultiplier)),d=\(fmt(record.legacy.durationSeconds)),c=\(fmt(record.legacy.cooldownSeconds)),p=\(fmt(record.legacy.passiveMultiplier))}"

    let passiveList = record.v2.passive
      .map { "\($0.slot):\($0.raw)" }
      .joined(separator: ",")

    let v2 = "V2{a=\(fmt(record.v2.activeMultiplier)),d=\(fmt(record.v2.durationSeconds)),c=\(fmt(record.v2.cooldownSeconds)),p=[\(passiveList)]}"

    let m = record.mismatch
    let flags = "Δ{a=\(m.activeMultiplier ? 1 : 0),d=\(m.durationSeconds ? 1 : 0),c=\(m.cooldownSeconds ? 1 : 0),p=\(m.passive ? 1 : 0)}"

    return "id=\(record.screenshotID) t=\(record.timestampISO8601) \(legacy) \(v2) \(flags)"
  }

  private static func passiveRoughlyMatches(legacy: Double?, v2: [Record.V2Passive]) -> Bool {
    switch (legacy, v2.isEmpty) {
    case (nil, true):
      return true
    case (nil, false):
      return false
    case (let l?, _):
      // If any v2 passive derived multiplier is close to legacy, treat as "match".
      return v2.contains(where: { approxEqual($0.derivedMultiplier, l, eps: 0.001) })
    }
  }

  private static func approxEqual(_ a: Double?, _ b: Double?, eps: Double) -> Bool {
    switch (a, b) {
    case (nil, nil): return true
    case (let x?, let y?): return abs(x - y) <= eps
    default: return false
    }
  }

  private static func fileURL() -> URL? {
    guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
    let dir = docs.appendingPathComponent("tmp", isDirectory: true)
    return dir.appendingPathComponent("pill_diffs.jsonl")
  }

  private static func appendToJSONL(_ record: Record) {
    guard let url = fileURL() else { return }

    do {
      let dir = url.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

      let data = try JSONEncoder().encode(record)
      guard var s = String(data: data, encoding: .utf8) else { return }
      s.append("\n")

      if FileManager.default.fileExists(atPath: url.path) {
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        if let bytes = s.data(using: .utf8) {
          try handle.write(contentsOf: bytes)
        }
        try handle.close()
      } else {
        try s.write(to: url, atomically: true, encoding: .utf8)
      }
    } catch {
      Logger.ocr.debug("PillDiffLogger file write failed: \(error.localizedDescription, privacy: .public)")
    }
  }
  #endif
}
