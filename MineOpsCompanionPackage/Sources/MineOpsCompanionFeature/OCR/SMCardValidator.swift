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
        
        // Critical indicators (must have at least one)
        let criticalIndicators: [(pattern: String, weight: Double, name: String)] = [
            ("level up", 0.25, "Level Up button"),
            ("promote", 0.25, "Promote button"),
            ("rank up", 0.20, "Rank Up button"),
        ]
        
        // Strong indicators
        let strongIndicators: [(pattern: String, weight: Double, name: String)] = [
            ("active", 0.15, "Active section"),
            ("passive", 0.15, "Passive section"),
            ("promotion:", 0.15, "Promotion label"),
            ("level:", 0.10, "Level label"),
        ]
        
        // Rarity indicators
        let rarityIndicators: [(pattern: String, weight: Double, name: String)] = [
            ("epic", 0.15, "Epic rarity"),
            ("legendary", 0.15, "Legendary rarity"),
            ("rare", 0.10, "Rare rarity"),
            ("common", 0.10, "Common rarity"),
        ]
        
        // Department indicators
        let departmentIndicators: [(pattern: String, weight: Double, name: String)] = [
            ("mineshaft", 0.15, "Mineshaft department"),
            ("elevator", 0.15, "Elevator department"),
            ("warehouse", 0.15, "Warehouse department"),
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
        var hasCritical = false
        for indicator in criticalIndicators {
            if text.contains(indicator.pattern) {
                score += indicator.weight
                matchedIndicators.append(indicator.name)
                hasCritical = true
            }
        }
        
        if !hasCritical {
            missingCritical.append("No Level Up/Promote/Rank Up button found")
        }
        
        // Check strong indicators
        for indicator in strongIndicators {
            if text.contains(indicator.pattern) {
                score += indicator.weight
                matchedIndicators.append(indicator.name)
            }
        }
        
        // Check rarity (only count one)
        var hasRarity = false
        for indicator in rarityIndicators {
            if text.contains(indicator.pattern) && !hasRarity {
                score += indicator.weight
                matchedIndicators.append(indicator.name)
                hasRarity = true
            }
        }
        
        // Check department (only count one)
        var hasDepartment = false
        for indicator in departmentIndicators {
            if text.contains(indicator.pattern) && !hasDepartment {
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
        
        let isValid = score >= minimumConfidence && hasCritical
        
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
