import Foundation

// MARK: - Mine Types

/// The different mine/continent types in Idle Miner Tycoon
enum MineType: String, CaseIterable, Identifiable, Codable {
    // Main progression
    case mainland = "Mainland"
    
    // Frontier progression
    case frontier = "Frontier Mine"
    
    // Continents (each has 5 themed mines: Coal, Gold, Ruby, Sapphire, then a special one)
    case start = "Start Continent"        // Obsidian
    case ice = "Ice Continent"            // Ice
    case fire = "Fire Continent"          // Fire
    case dawn = "Dawn Continent"          // Light
    case dusk = "Dusk Continent"          // Dark/Shadow
    case ancient = "Ancient Continent"    // Crystal
    case desert = "Lost Desert"           // Sand
    
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
            return [.coal, .gold, .ruby, .sapphire, .obsidian]
        case .ice:
            return [.coal, .gold, .ruby, .sapphire, .ice]
        case .fire:
            return [.coal, .gold, .ruby, .sapphire, .fire]
        case .dawn:
            return [.coal, .gold, .ruby, .sapphire, .dawn]
        case .dusk:
            return [.coal, .gold, .ruby, .sapphire, .dusk]
        case .ancient:
            return [.coal, .gold, .ruby, .sapphire, .crystal]
        case .desert:
            return [.coal, .gold, .ruby, .sapphire, .sand]
        default:
            return nil
        }
    }
}

/// Named mines on each continent
enum ContinentMine: String, CaseIterable, Identifiable, Codable {
    // Common to all continents
    case coal = "Coal"
    case gold = "Gold"
    case ruby = "Ruby"
    case sapphire = "Sapphire"
    
    // Continent-specific special mines
    case obsidian = "Obsidian"   // Start
    case ice = "Ice"             // Ice
    case fire = "Fire"           // Fire
    case dawn = "Dawn"           // Dawn
    case dusk = "Dusk"           // Dusk
    case crystal = "Crystal"     // Ancient
    case sand = "Sand"           // Desert
    
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
