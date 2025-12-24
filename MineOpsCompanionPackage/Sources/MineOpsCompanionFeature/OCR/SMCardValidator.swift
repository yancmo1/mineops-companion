import Foundation

/// Validates whether OCR text looks like it came from a Super Manager card screenshot.
/// This helps filter out non-game screenshots before processing.
public enum SMCardValidator {
    
    /// Minimum confidence score to consider a screenshot as a valid SM card
    public static let minimumConfidence: Double = 0.5
    
    /// Checks if the OCR text appears to be from a Super Manager card.
    /// Returns a confidence score from 0.0 to 1.0.
    public static func validate(ocrText: String) -> ValidationResult {
        let text = ocrText.lowercased()
        var score: Double = 0.0
        var matchedIndicators: [String] = []
        var missingCritical: [String] = []

        func matches(_ regex: String) -> Bool {
            guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive]) else { return false }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return re.firstMatch(in: text, options: [], range: range) != nil
        }
        
        // Critical indicators (must have at least one OR the screenshot must match a strong card-structure fallback).
        // OCR often drops spaces in button labels (e.g. "RankUp", "LevelUp"), so we match flexibly.
        let criticalIndicators: [(regex: String, weight: Double, name: String)] = [
            (#"\blevel\s*up\b"#, 0.25, "Level Up button"),
            (#"\bpromote\b"#, 0.25, "Promote button"),
            (#"\brank\s*up\b"#, 0.20, "Rank Up button"),
        ]
        
        // Strong indicators
        let strongIndicators: [(regex: String, weight: Double, name: String)] = [
            (#"\bactive\b"#, 0.15, "Active section"),
            (#"\bpassive\b"#, 0.15, "Passive section"),
            (#"\bpromotion\s*:?\b"#, 0.15, "Promotion label"),
            (#"\blevel\s*:?\b"#, 0.10, "Level label"),
        ]
        
        // Rarity indicators
        let rarityIndicators: [(regex: String, weight: Double, name: String)] = [
            (#"\bepic\b"#, 0.15, "Epic rarity"),
            (#"\blegendary\b"#, 0.15, "Legendary rarity"),
            (#"\brare\b"#, 0.10, "Rare rarity"),
            (#"\bcommon\b"#, 0.10, "Common rarity"),
        ]
        
        // Department indicators
        let departmentIndicators: [(regex: String, weight: Double, name: String)] = [
            (#"\bmineshaft\b"#, 0.15, "Mineshaft department"),
            (#"\belevator\b"#, 0.15, "Elevator department"),
            (#"\bwarehouse\b"#, 0.15, "Warehouse department"),
        ]
        
        // Numeric patterns typical of SM cards
        let numericPatterns: [(regex: String, weight: Double, name: String)] = [
            (#"\d+/50"#, 0.15, "Level X/50"),           // Level: 10/50
            (#"\d+/5"#, 0.10, "Promotion X/5"),         // Promotion: 0/5
            (#"\d+/15"#, 0.10, "Rank X/15"),            // 6/15 rank progress
            (#"\d+/30"#, 0.10, "Rank X/30"),            // 12/30 rank progress
            (#"\d+\.\d+x"#, 0.10, "Multiplier"),        // 2.7x, 12.91x
            (#"-?\d+\.?\d*%"#, 0.05, "Percentage"),     // -8.9%, +400%
            (#"\d+[ms]"#, 0.10, "Duration"),            // 5m, 30s, 2m
        ]
        
        // Check critical indicators
        var hasActionButton = false
        for indicator in criticalIndicators {
            if matches(indicator.regex) {
                score += indicator.weight
                matchedIndicators.append(indicator.name)
                hasActionButton = true
            }
        }
        
        // Check strong indicators
        for indicator in strongIndicators {
            if matches(indicator.regex) {
                score += indicator.weight
                matchedIndicators.append(indicator.name)
            }
        }
        
        // Check rarity (only count one)
        var hasRarity = false
        for indicator in rarityIndicators {
            if matches(indicator.regex) && !hasRarity {
                score += indicator.weight
                matchedIndicators.append(indicator.name)
                hasRarity = true
            }
        }
        
        // Check department (only count one)
        var hasDepartment = false
        for indicator in departmentIndicators {
            if matches(indicator.regex) && !hasDepartment {
                score += indicator.weight
                matchedIndicators.append(indicator.name)
                hasDepartment = true
            }
        }
        
        // Check numeric patterns
        for pattern in numericPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern.regex, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    score += pattern.weight
                    matchedIndicators.append(pattern.name)
                }
            }
        }
        
        // Cap at 1.0
        score = min(score, 1.0)
        
        // Fallback for cases where OCR misses button labels: require a strong SM-card structure.
        // This should still reject most non-game images while being robust to OCR quirks.
        let hasActiveAndPassive = matches(#"\bactive\b"#) && matches(#"\bpassive\b"#)
        let hasProgressFraction = matches(#"\b\d{1,2}\s*/\s*50\b"#) || matches(#"\b\d{1,2}\s*/\s*5\b"#)
        let hasCardStructure = hasActiveAndPassive && hasProgressFraction

        if !hasActionButton && !hasCardStructure {
            missingCritical.append("No SM button labels (Level Up/Promote/Rank Up) and no strong card structure")
        }

        let isValid = score >= minimumConfidence && (hasActionButton || hasCardStructure)
        
        return ValidationResult(
            isValid: isValid,
            confidence: score,
            matchedIndicators: matchedIndicators,
            issues: missingCritical
        )
    }
    
    /// Result of SM card validation
    public struct ValidationResult {
        public let isValid: Bool
        public let confidence: Double
        public let matchedIndicators: [String]
        public let issues: [String]
        
        public var summary: String {
            if isValid {
                return "Valid SM card (confidence: \(Int(confidence * 100))%)"
            } else {
                let issueText = issues.isEmpty ? "Low confidence" : issues.joined(separator: ", ")
                return "Invalid: \(issueText) (confidence: \(Int(confidence * 100))%)"
            }
        }
    }
}
