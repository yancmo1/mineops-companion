import Foundation

struct OCRFieldExtraction {
    let rarity: String?
    let role: String?
    let stars: Int?
    let activeEffect: String?
    let activeMultiplier: Double?
    let activeDurationSeconds: Int?
    let activeCooldownSeconds: Int?
    let activeValue: Double?
    let activeUnit: RecognizedSM.StatUnit?
    let passiveEffect: String?
    let passiveMultiplier: Double?
    let passiveDurationSeconds: Int?
    /// Up to 3 passive values found in-order in the Passive section (supports both `x` and `%`).
    let passiveValues: [(value: Double, unit: RecognizedSM.StatUnit)]
    let hasLevelUp: Bool
    let hasPromote: Bool
    let hasRankUp: Bool

    static func extract(from text: String) -> OCRFieldExtraction {
        let rarity = Self.match(in: text, pattern: #"(?i)\b(common|rare|epic|legendary|mythic)\b"#)
        let role = Self.match(in: text, pattern: #"(?i)\b(mine|mineshaft|elevator|warehouse|transport)\b"#)
        let stars = Self.countStars(in: text)

        let lines = text
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let activeSection = Self.section(containing: "active", from: lines)
        let passiveSection = Self.section(containing: "passive", from: lines)

        let activeEffect = Self.effectDescription(from: activeSection)
        let passiveEffect = Self.effectDescription(from: passiveSection)

        let activeTyped = Self.firstStatValue(in: activeSection)
        let passiveTyped = Self.statValues(in: passiveSection, limit: 3)

        let activeMultiplier = (activeTyped?.unit == .x) ? activeTyped?.value : nil
        let passiveMultiplier = (passiveTyped.first?.unit == .x) ? passiveTyped.first?.value : nil

        let activeDurationSeconds = Self.firstDuration(in: activeSection)
        let passiveDurationSeconds = Self.firstDuration(in: passiveSection)

        let activeCooldownSeconds = Self.cooldown(in: activeSection)

        let hasLevelUp = text.localizedCaseInsensitiveContains("Level Up")
        let hasPromote = text.localizedCaseInsensitiveContains("Promote")
        let hasRankUp = text.localizedCaseInsensitiveContains("Rank Up")

        return OCRFieldExtraction(
            rarity: rarity?.capitalized,
            role: role?.capitalized,
            stars: stars,
            activeEffect: activeEffect,
            activeMultiplier: activeMultiplier,
            activeDurationSeconds: activeDurationSeconds,
            activeCooldownSeconds: activeCooldownSeconds,
            activeValue: activeTyped?.value,
            activeUnit: activeTyped?.unit,
            passiveEffect: passiveEffect,
            passiveMultiplier: passiveMultiplier,
            passiveDurationSeconds: passiveDurationSeconds,
            passiveValues: passiveTyped,
            hasLevelUp: hasLevelUp,
            hasPromote: hasPromote,
            hasRankUp: hasRankUp
        )
    }

    private static func match(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        guard let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    private static func countStars(in text: String) -> Int? {
        let starCharacters: Set<Character> = ["⭐", "★", "✦", "✪"]
        let count = text.reduce(0) { partial, char in
            starCharacters.contains(char) ? partial + 1 : partial
        }
        return count > 0 ? count : nil
    }

    private static func section(containing keyword: String, from lines: [String]) -> String {
        guard let index = lines.firstIndex(where: { $0.range(of: keyword, options: .caseInsensitive) != nil }) else {
            return ""
        }
        let window = lines[index...min(index + 3, lines.count - 1)]
        return window.joined(separator: " ")
    }

    private static func effectDescription(from section: String) -> String? {
        guard !section.isEmpty else { return nil }
        var cleaned = section
            .replacingOccurrences(of: "Active", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Passive", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ":", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let regex = try? NSRegularExpression(pattern: #"(?i)\b(duration|cooldown)\b"#, options: []) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            if let match = regex.firstMatch(in: cleaned, options: [], range: range),
               let matchRange = Range(match.range(at: 0), in: cleaned) {
                cleaned = String(cleaned[..<matchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if let digitRange = cleaned.rangeOfCharacter(from: .decimalDigits) {
            cleaned = String(cleaned[..<digitRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func firstStatValue(in section: String) -> (value: Double, unit: RecognizedSM.StatUnit)? {
        guard !section.isEmpty else { return nil }
        // Prefer `x` and `%` values; allow negative values.
        let pattern = #"(-?[0-9]{1,4}(?:\.[0-9]+)?)\s*(x|%)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(section.startIndex..<section.endIndex, in: section)
        guard let match = regex.firstMatch(in: section, options: [], range: range) else { return nil }
        guard let valueRange = Range(match.range(at: 1), in: section) else { return nil }
        guard let unitRange = Range(match.range(at: 2), in: section) else { return nil }
        let value = Double(section[valueRange])
        let unitToken = section[unitRange].lowercased()
        guard let value else { return nil }
        let unit: RecognizedSM.StatUnit = (unitToken == "%") ? .percent : .x
        return (value: value, unit: unit)
    }

    private static func statValues(in section: String, limit: Int) -> [(value: Double, unit: RecognizedSM.StatUnit)] {
        guard !section.isEmpty, limit > 0 else { return [] }
        let pattern = #"(-?[0-9]{1,4}(?:\.[0-9]+)?)\s*(x|%)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(section.startIndex..<section.endIndex, in: section)
        let matches = regex.matches(in: section, options: [], range: range)
        var results: [(value: Double, unit: RecognizedSM.StatUnit)] = []
        results.reserveCapacity(min(matches.count, limit))
        for match in matches {
            guard results.count < limit else { break }
            guard let valueRange = Range(match.range(at: 1), in: section) else { continue }
            guard let unitRange = Range(match.range(at: 2), in: section) else { continue }
            guard let value = Double(section[valueRange]) else { continue }
            let unitToken = section[unitRange].lowercased()
            let unit: RecognizedSM.StatUnit = (unitToken == "%") ? .percent : .x
            results.append((value: value, unit: unit))
        }
        return results
    }

    private static func firstDuration(in section: String) -> Int? {
        guard !section.isEmpty else { return nil }
        let pattern = #"([0-9]{1,3})\s*(h|hr|hrs|hour|hours|m|min|mins|minute|minutes|s|sec|secs|second|seconds)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(section.startIndex..<section.endIndex, in: section)
        guard let match = regex.firstMatch(in: section, options: [], range: range) else { return nil }
        guard let valueRange = Range(match.range(at: 1), in: section) else { return nil }
        guard let unitRange = Range(match.range(at: 2), in: section) else { return nil }
        let value = Int(section[valueRange]) ?? 0
        let unit = section[unitRange].lowercased()
        return durationToSeconds(value: value, unit: unit)
    }

    private static func cooldown(in section: String) -> Int? {
        guard !section.isEmpty else { return nil }
        let pattern = #"(?i)cooldown[^0-9]*([0-9]{1,3})\s*(h|hr|hrs|hour|hours|m|min|mins|minute|minutes|s|sec|secs|second|seconds)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(section.startIndex..<section.endIndex, in: section)
        guard let match = regex.firstMatch(in: section, options: [], range: range) else { return nil }
        guard let valueRange = Range(match.range(at: 1), in: section) else { return nil }
        guard let unitRange = Range(match.range(at: 2), in: section) else { return nil }
        let value = Int(section[valueRange]) ?? 0
        let unit = section[unitRange].lowercased()
        return durationToSeconds(value: value, unit: unit)
    }

    static func durationToSeconds(value: Int, unit: String) -> Int {
        switch unit {
        case "h", "hr", "hrs", "hour", "hours":
            return value * 3600
        case "m", "min", "mins", "minute", "minutes":
            return value * 60
        default:
            return value
        }
    }
}
