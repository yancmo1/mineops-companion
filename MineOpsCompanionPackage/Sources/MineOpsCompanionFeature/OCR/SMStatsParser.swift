import Foundation

public struct SMStats: Hashable, Codable {
    public struct Fraction: Hashable, Codable {
        public let current: Int
        public let total: Int

        public var display: String { "\(current)/\(total)" }
    }

    public let level: Fraction?
    public let promotion: Fraction?
    public let percentValues: [String]
    public let multiplierValues: [String]
    public let minuteDurations: [Int]

    public init(
        level: Fraction? = nil,
        promotion: Fraction? = nil,
        percentValues: [String] = [],
        multiplierValues: [String] = [],
        minuteDurations: [Int] = []
    ) {
        self.level = level
        self.promotion = promotion
        self.percentValues = percentValues
        self.multiplierValues = multiplierValues
        self.minuteDurations = minuteDurations
    }

    private static func normalizePercentDisplay(_ value: String) -> String {
        let trimmed = value.replacingOccurrences(of: " ", with: "")
        guard !trimmed.isEmpty else { return value }
        if trimmed.hasPrefix("+") || trimmed.hasPrefix("-") {
            return trimmed
        }
        return "+" + trimmed
    }

    public var normalizedPercentDisplays: [String] {
        percentValues.map(Self.normalizePercentDisplay)
    }

    public var percentNumberValues: [Double] {
        normalizedPercentDisplays.compactMap { value in
            let trimmed = value.replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "+", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(trimmed)
        }
    }

    public var primaryPercentDisplay: String? {
        normalizedPercentDisplays.first
    }

    public var levelDisplay: String? {
        guard let level else { return nil }
        return level.display
    }

    public var promotionDisplay: String? {
        guard let promotion else { return nil }
        return promotion.display
    }

    public var multipliers: [(display: String, value: Double)] {
        multiplierValues.compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let numeric = trimmed.replacingOccurrences(of: "x", with: "")
            guard let value = Double(numeric) else { return nil }
            return (trimmed, value)
        }
    }

    public var multipliersDescending: [(display: String, value: Double)] {
        multipliers.sorted { $0.value > $1.value }
    }

    public var activeMultiplierDisplay: String? {
        multipliersDescending.first?.display
    }

    public var passiveMultiplierDisplays: [String] {
        Array(multipliersDescending.dropFirst().map { $0.display })
    }

    public var secondaryPercentDisplays: [String] {
        Array(normalizedPercentDisplays.dropFirst())
    }

    public var durationDisplays: [String] {
        minuteDurations.map { "\($0)m" }
    }

    public var durationPair: (duration: Int, cooldown: Int)? {
        guard minuteDurations.count >= 2 else { return nil }
        let sorted = minuteDurations.sorted()
        return (duration: sorted[0], cooldown: sorted[1])
    }

    public var passiveBoostDisplays: [String] {
        var displays = normalizedPercentDisplays
        displays.append(contentsOf: passiveMultiplierDisplays)
        return displays
    }

    public var secondaryBoostTokens: [String] {
        var tokens = secondaryPercentDisplays
        tokens.append(contentsOf: passiveMultiplierDisplays)
        return tokens
    }

    public var hasAnyStats: Bool {
        level != nil || promotion != nil || !percentValues.isEmpty || !multiplierValues.isEmpty || !minuteDurations.isEmpty
    }
}

public enum SMStatsParser {
    private static let levelRegex = try! NSRegularExpression(
        pattern: #"(?i)level[^0-9]*([0-9]{1,3})\s*/\s*([0-9]{1,3})"#,
        options: []
    )

    private static let promotionRegex = try! NSRegularExpression(
        pattern: #"(?i)promotion[^0-9]*([0-9]{1,2})\s*/\s*([0-9]{1,2})"#,
        options: []
    )

    private static let percentRegex = try! NSRegularExpression(
        pattern: #"[+\-]?\s*[0-9]{1,4}(?:\.[0-9]+)?%"#,
        options: []
    )

    private static let multiplierRegex = try! NSRegularExpression(
        pattern: #"[0-9]{1,3}(?:\.[0-9]+)?x"#,
        options: []
    )

    private static let minuteRegex = try! NSRegularExpression(
        pattern: #"(?i)\b([0-9]{1,3})\s*(?:m|min)\b"#,
        options: []
    )

    public static func parse(text: String) -> SMStats {
        let normalized = text.replacingOccurrences(of: "\r", with: "")
        let level = fraction(matching: levelRegex, in: normalized)
        let promotion = fraction(matching: promotionRegex, in: normalized)
        let percents = strings(matching: percentRegex, in: normalized)
        let multipliers = strings(matching: multiplierRegex, in: normalized)
        let minutes = minuteValues(in: normalized)

        return SMStats(
            level: level,
            promotion: promotion,
            percentValues: percents.map { $0.replacingOccurrences(of: " ", with: "") },
            multiplierValues: multipliers,
            minuteDurations: minutes
        )
    }

    private static func fraction(matching regex: NSRegularExpression, in text: String) -> SMStats.Fraction? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        guard let currentRange = Range(match.range(at: 1), in: text),
              let totalRange = Range(match.range(at: 2), in: text),
              let current = Int(text[currentRange]),
              let total = Int(text[totalRange]) else { return nil }
        return SMStats.Fraction(current: current, total: total)
    }

    private static func strings(matching regex: NSRegularExpression, in text: String) -> [String] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let matchRange = Range(match.range(at: 0), in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private static func minuteValues(in text: String) -> [Int] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return minuteRegex.matches(in: text, options: [], range: range).compactMap { match in
            guard let capture = Range(match.range(at: 1), in: text) else { return nil }
            return Int(text[capture])
        }
    }
}
