import Foundation

/// Loader for SM base stats from JSON resource
public struct SMBaseStatsLoader {
    
    public struct Manager: Codable {
        public let id: String
        public let name: String
        public let rarity: String
        public let type: String
        public let baseStats: BaseStats
        public let passives: [Passive]
        
        public struct BaseStats: Codable {
            public let level: Int
            public let promotion: Int
            public let activeMultiplier: Double
            public let activeDuration: String
            public let activeCooldown: String
            public let description: String?
        }
        
        public struct Passive: Codable {
            public let unlockLevel: Int
            public let type: String
            public let baseMultiplier: Double
            public let description: String
        }
    }
    
    public struct BaseStatsDatabase: Codable {
        public let version: String
        public let lastUpdated: String
        public let description: String
        public let upgradeFormulas: [String: RarityFormula]
        public let managers: [Manager]
        
        public struct RarityFormula: Codable {
            public let maxLevel: Int
            public let maxPromotion: Int
            public let levelMultipliers: [String: Double]
        }
    }
    
    /// Load base stats database from bundled JSON
    public static func loadDatabase() throws -> BaseStatsDatabase {
        guard let url = Bundle.module.url(forResource: "sm_base_stats", withExtension: "json") else {
            throw NSError(domain: "SMBaseStatsLoader", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not find sm_base_stats.json in bundle"
            ])
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(BaseStatsDatabase.self, from: data)
    }
    
    /// Get a specific manager by ID
    public static func getManager(id: String) throws -> Manager? {
        let database = try loadDatabase()
        return database.managers.first { $0.id == id }
    }
    
    /// Get all managers of a specific rarity
    public static func getManagersByRarity(_ rarity: String) throws -> [Manager] {
        let database = try loadDatabase()
        return database.managers.filter { $0.rarity.lowercased() == rarity.lowercased() }
    }
    
    /// Convert a manager to upgrade calculator inputs
    public static func toCalculatorInputs(manager: Manager) -> (
        rarity: SMUpgradeCalculator.Rarity,
        baseMultiplier: Double,
        passives: [(unlockLevel: Int, baseMultiplier: Double, type: String)]
    )? {
        guard let rarity = SMUpgradeCalculator.Rarity(rawValue: manager.rarity) else {
            return nil
        }
        
        let passives = manager.passives.map { passive in
            (unlockLevel: passive.unlockLevel, baseMultiplier: passive.baseMultiplier, type: passive.type)
        }
        
        return (rarity, manager.baseStats.activeMultiplier, passives)
    }
}
