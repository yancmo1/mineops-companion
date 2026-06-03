import Foundation

struct OCRFieldExtraction {
    let rarity: String?
    let role: String?
    let stars: Int?
    let fragments: Int?
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

    /// Extract fields from raw full-screen OCR text (fallback when spatial data unavailable).
    static func extract(from text: String) -> OCRFieldExtraction {
        let lines = text
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return extractFromLines(lines, fullText: text)
    }

    /// Extract fields using spatial OCR data (preferred — correctly splits Active vs Passive columns).
    static func extractWithSpatialData(from spatialLines: [OCRTextRecognizer.SpatialLine]) -> OCRFieldExtraction {
        let fullText = spatialLines.map(\.text).joined(separator: "\n")

        // Find the "Active" and "Passive" header lines to determine column boundaries.
        let activeHeader = spatialLines.first { $0.text.range(of: "active", options: .caseInsensitive) != nil }
        let passiveHeader = spatialLines.first { $0.text.range(of: "passive", options: .caseInsensitive) != nil }

        // If we found both headers, split lines by their horizontal position.
        if let activeH = activeHeader, let passiveH = passiveHeader {
            // The boundary between columns is between the Active and Passive header centers.
            let splitX = (activeH.centerX + passiveH.centerX) / 2.0

            // Only consider lines below the headers (lower on screen = higher centerYTopOrigin).
            let panelTopY = min(activeH.centerYTopOrigin, passiveH.centerYTopOrigin) - 0.02

            let panelLines = spatialLines.filter { $0.centerYTopOrigin >= panelTopY }
            let leftLines = panelLines.filter { $0.centerX < splitX }
                .sorted { $0.centerYTopOrigin < $1.centerYTopOrigin }
                .map(\.text)
            let rightLines = panelLines.filter { $0.centerX >= splitX }
                .sorted { $0.centerYTopOrigin < $1.centerYTopOrigin }
                .map(\.text)

            let activeSection = leftLines.joined(separator: " ")
            let passiveSection = rightLines.joined(separator: " ")

            return extractFromSections(
                activeSection: activeSection,
                passiveSection: passiveSection,
                fullText: fullText
            )
        }

        // Fallback: treat as flat lines.
        let lines = spatialLines
            .sorted { $0.centerYTopOrigin < $1.centerYTopOrigin }
            .map(\.text)
        return extractFromLines(lines, fullText: fullText)
    }

    // MARK: - Internal extraction from pre-split sections

    private static func extractFromSections(
        activeSection: String,
        passiveSection: String,
        fullText: String
    ) -> OCRFieldExtraction {
        let rarity = Self.match(in: fullText, pattern: #"(?i)\b(common|rare|epic|legendary|mythic)\b"#)
        let role = Self.match(in: fullText, pattern: #"(?i)\b(mine|mineshaft|elevator|warehouse|transport)\b"#)
        let stars = Self.parseStars(in: fullText)
        let fragments = Self.parseFragments(in: fullText)

        let activeEffect = Self.effectDescription(from: activeSection)
        let passiveEffect = Self.effectDescription(from: passiveSection)

        let activeTyped = Self.firstStatValue(in: activeSection)
        let passiveTyped = Self.statValues(in: passiveSection, limit: 3)

        let activeMultiplier = (activeTyped?.unit == .x) ? activeTyped?.value : nil
        let passiveMultiplier = (passiveTyped.first?.unit == .x) ? passiveTyped.first?.value : nil

        let activeDurationSeconds = Self.firstDuration(in: activeSection)
        let passiveDurationSeconds = Self.firstDuration(in: passiveSection)

        let activeCooldownSeconds = Self.cooldown(in: activeSection)
            ?? Self.secondDuration(in: activeSection, after: activeDurationSeconds)

        let hasLevelUp = fullText.localizedCaseInsensitiveContains("Level Up")
        let hasPromote = fullText.localizedCaseInsensitiveContains("Promote")
        let hasRankUp = fullText.localizedCaseInsensitiveContains("Rank Up")

        return OCRFieldExtraction(
            rarity: rarity?.capitalized,
            role: role?.capitalized,
            stars: stars,
            fragments: fragments,
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

    // MARK: - Flat-line fallback

    private static func extractFromLines(_ lines: [String], fullText: String) -> OCRFieldExtraction {
        let rarity = Self.match(in: fullText, pattern: #"(?i)\b(common|rare|epic|legendary|mythic)\b"#)
        let role = Self.match(in: fullText, pattern: #"(?i)\b(mine|mineshaft|elevator|warehouse|transport)\b"#)
        let stars = Self.parseStars(in: fullText)
        let fragments = Self.parseFragments(in: fullText)

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
            ?? Self.secondDuration(in: activeSection, after: activeDurationSeconds)

        let hasLevelUp = fullText.localizedCaseInsensitiveContains("Level Up")
        let hasPromote = fullText.localizedCaseInsensitiveContains("Promote")
        let hasRankUp = fullText.localizedCaseInsensitiveContains("Rank Up")

        return OCRFieldExtraction(
            rarity: rarity?.capitalized,
            role: role?.capitalized,
            stars: stars,
            fragments: fragments,
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

    private static func parseStars(in text: String) -> Int? {
        if let symbolCount = countStars(in: text) {
            return symbolCount
        }

        // Fallback when star glyphs are not recognized by OCR: e.g. "Rank 2"
        if let rank = matchInt(in: text, pattern: #"(?i)\brank\s*[:#-]?\s*([0-9]{1,2})(?!\s*/)"#) {
            return max(rank, 0)
        }

        return nil
    }

    private static func parseFragments(in text: String) -> Int? {
        // Preferred: explicit fragment label.
        if let value = matchInt(
            in: text,
            pattern: #"(?i)\bfragment(?:s)?\b[^0-9]{0,10}([0-9]{1,3})\s*/\s*[0-9]{1,4}\b"#
        ) {
            return max(value, 0)
        }

        // Preferred fallback: fraction adjacent to "Rank up".
        // Handles both:
        // - "8/30 Rank up"
        // - "Rank up 8/30"
        if let value = matchInt(
            in: text,
            pattern: #"(?is)\b([0-9]{1,3})\s*/\s*[0-9]{1,4}\b[^a-z0-9]{0,12}rank\s*up\b"#
        ) {
            return max(value, 0)
        }
        if let value = matchInt(
            in: text,
            pattern: #"(?is)\brank\s*up\b[^0-9]{0,12}([0-9]{1,3})\s*/\s*[0-9]{1,4}\b"#
        ) {
            return max(value, 0)
        }

        // Last resort: pick rank-like denominators while filtering obvious level/promotion lines.
        if let value = firstUnlabeledFragmentProgress(in: text) {
            return max(value, 0)
        }

        return nil
    }

    private static func firstUnlabeledFragmentProgress(in text: String) -> Int? {
        let pattern = #"([0-9]{1,3})\s*/\s*([0-9]{1,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        for match in matches {
            guard let valueRange = Range(match.range(at: 1), in: text) else { continue }
            guard let denominatorRange = Range(match.range(at: 2), in: text) else { continue }
            guard let wholeRange = Range(match.range(at: 0), in: text) else { continue }
            guard let denominator = Int(text[denominatorRange]), denominator >= 10 else {
                // Ignore tiny counters like promotion progress (e.g. 1/5).
                continue
            }

            let contextStart = text.index(wholeRange.lowerBound, offsetBy: -16, limitedBy: text.startIndex) ?? text.startIndex
            let contextEnd = text.index(wholeRange.upperBound, offsetBy: 16, limitedBy: text.endIndex) ?? text.endIndex
            let localContext = text[contextStart..<contextEnd].lowercased()

            // Ignore common non-fragment progress counters.
            if localContext.contains("level") || localContext.contains("promotion") {
                continue
            }

            if let value = Int(text[valueRange]) {
                return value
            }
        }

        return nil
    }

    private static func matchInt(in text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        guard let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[captureRange])
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

    /// Returns the second duration found in the section (used as cooldown fallback when explicit "cooldown" keyword is absent).
    private static func secondDuration(in section: String, after firstDurationSeconds: Int?) -> Int? {
        guard !section.isEmpty else { return nil }
        let pattern = #"([0-9]{1,3})\s*(h|hr|hrs|hour|hours|m|min|mins|minute|minutes|s|sec|secs|second|seconds)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(section.startIndex..<section.endIndex, in: section)
        let matches = regex.matches(in: section, options: [], range: range)
        guard matches.count >= 2 else { return nil }
        let match = matches[1]
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
