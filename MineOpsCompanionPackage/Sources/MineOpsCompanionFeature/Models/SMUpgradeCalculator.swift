import Foundation

/// Calculator for Super Manager stat upgrades based on level and promotion
public struct SMUpgradeCalculator {
    
    /// Rarity level multipliers per level range
    public enum Rarity: String, Codable {
        case common = "Common"
        case rare = "Rare"
        case epic = "Epic"
        case legendary = "Legendary"
        
        public var maxLevel: Int {
            switch self {
            case .common: return 40
            case .rare: return 30
            case .epic: return 20
            case .legendary: return 20
            }
        }
        
        public var maxPromotion: Int {
            switch self {
            case .common: return 4
            case .rare: return 3
            case .epic: return 2
            case .legendary: return 2
            }
        }
        
        /// Get the multiplier per level for a specific level range
        public func multiplierForLevel(_ level: Int) -> Double {
            switch self {
            case .common:
                if level <= 10 { return 1.40 }
                if level <= 20 { return 1.40 }
                if level <= 30 { return 1.337 }
                return 1.30
            case .rare:
                if level <= 10 { return 1.45 }
                if level <= 20 { return 1.35 }
                return 1.30
            case .epic:
                if level <= 10 { return 1.50 }
                return 1.45
            case .legendary:
                if level <= 10 { return 1.55 }
                return 1.50
            }
        }
    }
    
    /// Calculate the active ability multiplier at a given level
    /// - Parameters:
    ///   - baseMultiplier: The base multiplier at level 1
    ///   - currentLevel: The current level (1 to maxLevel)
    ///   - rarity: The rarity of the Super Manager
    /// - Returns: The calculated multiplier at the current level
    public static func calculateActiveMultiplier(
        baseMultiplier: Double,
        currentLevel: Int,
        rarity: Rarity
    ) -> Double {
        guard currentLevel > 1, currentLevel <= rarity.maxLevel else {
            return baseMultiplier
        }
        
        var multiplier = baseMultiplier
        
        // Apply cumulative level multipliers
        for level in 2...currentLevel {
            let levelMultiplier = rarity.multiplierForLevel(level)
            multiplier *= levelMultiplier
        }
        
        return multiplier
    }
    
    /// Calculate the passive ability multiplier at a given level
    /// - Parameters:
    ///   - baseMultiplier: The base multiplier when passive is unlocked
    ///   - currentLevel: The current level
    ///   - unlockLevel: The level at which the passive unlocks
    ///   - rarity: The rarity of the Super Manager
    /// - Returns: The calculated passive multiplier, or nil if not yet unlocked
    public static func calculatePassiveMultiplier(
        baseMultiplier: Double,
        currentLevel: Int,
        unlockLevel: Int,
        rarity: Rarity
    ) -> Double? {
        guard currentLevel >= unlockLevel else {
            return nil // Passive not unlocked yet
        }
        
        // For now, passive multipliers remain constant after unlock
        // This could be enhanced with specific progression formulas per passive type
        return baseMultiplier
    }
    
    /// Calculate all stats for a Super Manager at a given level
    /// - Parameters:
    ///   - baseActiveMultiplier: Base active multiplier
    ///   - currentLevel: Current level
    ///   - promotion: Current promotion level
    ///   - rarity: Rarity tier
    ///   - passives: Array of passive abilities with unlock levels and base multipliers
    /// - Returns: Calculated stats including active and unlocked passive multipliers
    public static func calculateStats(
        baseActiveMultiplier: Double,
        currentLevel: Int,
        promotion: Int,
        rarity: Rarity,
        passives: [(unlockLevel: Int, baseMultiplier: Double, type: String)]
    ) -> SMCalculatedStats {
        let activeMultiplier = calculateActiveMultiplier(
            baseMultiplier: baseActiveMultiplier,
            currentLevel: currentLevel,
            rarity: rarity
        )
        
        let unlockedPassives = passives.compactMap { passive -> SMPassiveStat? in
            guard let multiplier = calculatePassiveMultiplier(
                baseMultiplier: passive.baseMultiplier,
                currentLevel: currentLevel,
                unlockLevel: passive.unlockLevel,
                rarity: rarity
            ) else {
                return nil
            }
            
            return SMPassiveStat(
                type: passive.type,
                multiplier: multiplier,
                unlockLevel: passive.unlockLevel
            )
        }
        
        return SMCalculatedStats(
            level: currentLevel,
            promotion: promotion,
            rarity: rarity,
            activeMultiplier: activeMultiplier,
            passives: unlockedPassives
        )
    }
}

/// Represents calculated stats for a Super Manager at a specific level
public struct SMCalculatedStats: Codable, Hashable {
    public let level: Int
    public let promotion: Int
    public let rarity: SMUpgradeCalculator.Rarity
    public let activeMultiplier: Double
    public let passives: [SMPassiveStat]
    
    public init(
        level: Int,
        promotion: Int,
        rarity: SMUpgradeCalculator.Rarity,
        activeMultiplier: Double,
        passives: [SMPassiveStat]
    ) {
        self.level = level
        self.promotion = promotion
        self.rarity = rarity
        self.activeMultiplier = activeMultiplier
        self.passives = passives
    }
    
    /// Format active multiplier for display
    public var activeMultiplierDisplay: String {
        String(format: "%.2fx", activeMultiplier)
    }
}

/// Represents a passive stat for a Super Manager
public struct SMPassiveStat: Codable, Hashable {
    public let type: String
    public let multiplier: Double
    public let unlockLevel: Int
    
    public init(type: String, multiplier: Double, unlockLevel: Int) {
        self.type = type
        self.multiplier = multiplier
        self.unlockLevel = unlockLevel
    }
    
    /// Format multiplier for display
    public var multiplierDisplay: String {
        if type.contains("cost") || type.contains("reduction") {
            return String(format: "-%.0f%%", (1.0 - multiplier) * 100)
        } else {
            return String(format: "%.2fx", multiplier)
        }
    }
}
