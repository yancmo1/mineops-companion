import Foundation

// MARK: - Mine Types

/// The different mine/continent types in Idle Miner Tycoon
enum MineType: String, CaseIterable, Identifiable, Codable {
    // Main progression
    case mainland = "Mainland"
    
    // Frontier progression
    case frontier = "Frontier Mine"
    
    // Continents (each has 5 unique themed mines)
    case start = "Start Continent"        // Coal, Gold, Ruby, Diamond, Emerald
    case ice = "Ice Continent"            // Moonstone, Amethyst, Crystal, Jade, Sapphire
    case fire = "Fire Continent"          // Amber, Topaz, Sunstone, Platinum, Obsidian
    case dawn = "Dawn Continent"          // Heliodor, Realgar, Alexandrite, Celestine, Titanite
    case dusk = "Dusk Continent"          // Fluorite, Quartz, Aragonite, Beryl, Calcite
    case ancient = "Ancient Continent"    // Aquamarine, Ammolite, Azurite, Pearl, Turquoise
    case desert = "Lost Desert"           // Crysoberyl, Labradorite, Aventurine, Jasper, Carnelian
    
    // Special mines
    case event = "Event Mine"
    case impossible = "Impossible Mine"
    case expedition = "Expedition"
    
    var id: String { rawValue }
    
    /// Whether this mine type uses numbered progression (Mainland) vs named mines (Continents)
    var usesNumberedProgression: Bool {
        self == .mainland || self == .frontier
    }
    
    /// The themed mines available on each continent
    var continentMines: [ContinentMine]? {
        switch self {
        case .start:
            return [.coal, .gold, .ruby, .diamond, .emerald]
        case .ice:
            return [.moonstone, .amethyst, .crystal, .jade, .sapphire]
        case .fire:
            return [.amber, .topaz, .sunstone, .platinum, .obsidian]
        case .dawn:
            return [.heliodor, .realgar, .alexandrite, .celestine, .titanite]
        case .dusk:
            return [.fluorite, .quartz, .aragonite, .beryl, .calcite]
        case .ancient:
            return [.aquamarine, .ammolite, .azurite, .pearl, .turquoise]
        case .desert:
            return [.crysoberyl, .labradorite, .aventurine, .jasper, .carnelian]
        default:
            return nil
        }
    }
}

/// Named mines on each continent
enum ContinentMine: String, CaseIterable, Identifiable, Codable {
    // Start Continent mines
    case coal = "Coal"
    case gold = "Gold"
    case ruby = "Ruby"
    case diamond = "Diamond"
    case emerald = "Emerald"
    
    // Ice Continent mines
    case moonstone = "Moonstone"
    case amethyst = "Amethyst"
    case crystal = "Crystal"
    case jade = "Jade"
    case sapphire = "Sapphire"
    
    // Fire Continent mines
    case amber = "Amber"
    case topaz = "Topaz"
    case sunstone = "Sunstone"
    case platinum = "Platinum"
    case obsidian = "Obsidian"
    
    // Dawn Continent mines
    case heliodor = "Heliodor"
    case realgar = "Realgar"
    case alexandrite = "Alexandrite"
    case celestine = "Celestine"
    case titanite = "Titanite"
    
    // Dusk Continent mines
    case fluorite = "Fluorite"
    case quartz = "Quartz"
    case aragonite = "Aragonite"
    case beryl = "Beryl"
    case calcite = "Calcite"
    
    // Ancient Continent mines
    case aquamarine = "Aquamarine"
    case ammolite = "Ammolite"
    case azurite = "Azurite"
    case pearl = "Pearl"
    case turquoise = "Turquoise"
    
    // Desert Continent mines
    case crysoberyl = "Crysoberyl"
    case labradorite = "Labradorite"
    case aventurine = "Aventurine"
    case jasper = "Jasper"
    case carnelian = "Carnelian"
    
    var id: String { rawValue }
}

// MARK: - Mine Context

struct MineContext: Codable, Hashable {
    let type: MineType
    
    /// For Mainland: the mine number (1, 2, 3, etc. - infinite progression)
    let mainlandMineNumber: Int?
    
    /// For Continents: the specific mine within that continent
    let continentMine: ContinentMine?
    
    /// Prestige level (how many times prestiged)
    let prestige: Int
    
    /// Max shaft level reached
    let maxShaft: Int
    
    init(
        type: MineType,
        mainlandMineNumber: Int? = nil,
        continentMine: ContinentMine? = nil,
        prestige: Int,
        maxShaft: Int
    ) {
        self.type = type
        self.mainlandMineNumber = mainlandMineNumber
        self.continentMine = continentMine
        self.prestige = prestige
        self.maxShaft = maxShaft
    }
    
    var displayName: String {
        switch type {
        case .mainland:
            if let num = mainlandMineNumber {
                return "Mainland Mine \(num)"
            }
            return "Mainland"
        case .frontier:
            if let num = mainlandMineNumber {
                return "Frontier Mine \(num)"
            }
            return "Frontier Mine"
        case .event, .impossible, .expedition:
            return type.rawValue
        default:
            // Continent with specific mine
            if let mine = continentMine {
                return "\(type.rawValue) - \(mine.rawValue)"
            }
            return type.rawValue
        }
    }
    
    var promptDescription: String {
        switch type {
        case .mainland:
            if let num = mainlandMineNumber {
                return "Mainland Mine \(num) (Prestige \(prestige), Max Shaft \(maxShaft))"
            }
            return "Mainland (Prestige \(prestige), Max Shaft \(maxShaft))"
        case .frontier:
            if let num = mainlandMineNumber {
                return "Frontier Mine \(num) (Prestige \(prestige), Max Shaft \(maxShaft))"
            }
            return "Frontier Mine (Prestige \(prestige), Max Shaft \(maxShaft))"
        default:
            return "\(displayName) (Prestige \(prestige), Max Shaft \(maxShaft))"
        }
    }
    
    var cacheKey: String {
        let typeKey = type.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
        switch type {
        case .mainland:
            let mineNum = mainlandMineNumber ?? 1
            return "mainland_\(mineNum)_p\(prestige)_s\(maxShaft)"
        case .frontier:
            let mineNum = mainlandMineNumber ?? 1
            return "frontier_\(mineNum)_p\(prestige)_s\(maxShaft)"
        default:
            if let mine = continentMine {
                return "\(typeKey)_\(mine.rawValue.lowercased())_p\(prestige)_s\(maxShaft)"
            }
            return "\(typeKey)_p\(prestige)_s\(maxShaft)"
        }
    }
}
