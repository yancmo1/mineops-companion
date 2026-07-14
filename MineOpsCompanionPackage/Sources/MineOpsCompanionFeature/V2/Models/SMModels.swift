import Foundation

// MARK: - Master Entry (idle-miners.com /api/sm-data)

public struct SMMasterEntry: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let rarity: String
    public let area: String
    public let gameId: Int
    public let sprite: String
    public let elements: [SMElementEntry]
    public let passives: [SMPassiveEntry]
    public let activeL1: Double
    public let activeL100: Double
    public let cooldown: Int
    public let duration: Int
    public let descriptionLong: String?
    public let descriptionShort: String?
    public let placeholderIndices: [Int]?
    public let legacyGameIds: [Int]?
    public let rental: Bool?
    public let maxLevel: Int?

    public struct SMElementEntry: Codable, Hashable, Sendable {
        public let element: String
        public let effectiveness: String   // SE, PE, NVE
        public let rankReq: Int
    }

    public struct SMPassiveEntry: Codable, Hashable, Sendable {
        public let type: String
        public let value: Double?
        public let promoReq: Int
    }
}

// MARK: - Active Scaling (idle-miners.com /api/sm-actives)

public struct SMActiveScaling: Codable, Hashable, Sendable {
    public let type: Int
    public let scaleType: Int
    public let values: [[Double]]
}

// MARK: - Merged Progress

public struct SMProgress: Identifiable, Hashable, Sendable, Codable {
    public let master: SMMasterEntry
    public var rank: Int
    public var level: Int
    public var promoted: Int
    public var unlocked: Bool
    public var fragments: Int

    public var id: String { master.id }

    /// Calculate the effective active ability value based on level and rank using scaling table
    public func effectiveActiveValue(using scalingLookup: [String: SMActiveScaling]) -> Double {
        guard let scaling = scalingLookup[master.id],
              level >= 1, level <= scaling.values.count,
              rank >= 0, rank < 6 else {
            // Fallback: linear interpolation
            let base = master.activeL1
            let maxVal = master.activeL100
            let ratio = min(Double(level) / 100.0, 1.0)
            return base + (maxVal - base) * ratio
        }
        return scaling.values[level - 1][rank]
    }

    public var areaEnum: SMDepartment { SMDepartment(rawValue: master.area) ?? .mineshaft }

    public var sortedElements: [SMMasterEntry.SMElementEntry] {
        master.elements.filter { $0.rankReq <= promoted }.sorted {
            if $0.effectiveness != $1.effectiveness {
                return $0.effectivenessPriority < $1.effectivenessPriority
            }
            return $0.rankReq < $1.rankReq
        }
    }

    public var availablePassives: [SMMasterEntry.SMPassiveEntry] {
        master.passives.filter { $0.promoReq <= promoted }
    }
    
    /// Passive entries with computed values from the scaling tables
    public func computedPassives(using passiveTables: SMPassiveTables?) -> [ComputedPassive] {
        availablePassives.compactMap { passive in
            guard let tables = passiveTables else {
                return ComputedPassive(entry: passive, value: passive.value)
            }
            let lookedUp = tables.lookupPassiveValue(
                type: passive.type,
                rarity: master.rarity,
                rank: rank,
                promoted: promoted
            )
            return ComputedPassive(entry: passive, value: lookedUp ?? passive.value)
        }
    }
}

// MARK: - Computed Passive

public struct ComputedPassive: Identifiable, Hashable, Sendable {
    public let entry: SMMasterEntry.SMPassiveEntry
    public let value: Double?
    
    public var id: String { entry.type }
    
    public var typeDisplayName: String { entry.typeDisplayName }
}

// MARK: - Department

public enum SMDepartment: String, CaseIterable, Sendable {
    case mineshaft
    case elevator
    case warehouse

    public var displayName: String {
        switch self {
        case .mineshaft: return "Mineshaft"
        case .elevator: return "Elevator"
        case .warehouse: return "Warehouse"
        }
    }
}

// MARK: - Passive Type Display

public extension SMMasterEntry.SMPassiveEntry {
    var typeDisplayName: String {
        PassiveTypeCode(rawValue: type)?.displayName ?? type
    }
}

enum PassiveTypeCode: String {
    case MSB, CR, MSUCR, CIF, WMSB, BUCR, MLSB, IC, MIF, WWLSB
    case EBEAM, MSBEAM, EMSB, GWSB, WWLB, WSB, MBEAM

    var displayName: String {
        switch self {
        case .MSB: return "Mining Speed Boost"
        case .CR: return "Crate Resources"
        case .MSUCR: return "Mineshaft Upgrade Cost Reduction"
        case .CIF: return "Cash Income Factor"
        case .WMSB: return "Walking & Mining Speed Boost"
        case .BUCR: return "Building Upgrade Cost Reduction"
        case .MLSB: return "Mineshaft Loading Speed Boost"
        case .IC: return "Instant Cash"
        case .MIF: return "Mine Income Factor"
        case .WWLSB: return "Worker Loading Speed Boost"
        case .EBEAM: return "Elevator Beam"
        case .MSBEAM: return "Mineshaft Beam"
        case .EMSB: return "Elevator Movement Speed Boost"
        case .GWSB: return "General Walking Speed Boost"
        case .WWLB: return "Worker Loading Boost"
        case .WSB: return "Walking Speed Boost"
        case .MBEAM: return "Mine Beam"
        }
    }
}

// MARK: - Effectiveness Priority

extension SMMasterEntry.SMElementEntry {
    var effectivenessPriority: Int {
        switch effectiveness {
        case "SE": return 0
        case "PE": return 1
        case "NVE": return 2
        default: return 3
        }
    }
}

// MARK: - Passive Tables (sm_passive_tables.json)

public struct SMPassiveTables: Codable, Hashable, Sendable {
    public let metadata: PassiveMetadata?
    public let passives: [String: PassiveTypeTable]
    public let gameData: PassiveGameData?
    
    public struct PassiveMetadata: Codable, Hashable, Sendable {
        public let promoLevels: [String]
        public let ranks: [String]
        public let maxPromoByRank: [String: String]
        public let passiveUnlock: [String: Int]?
    }
    
    public struct PassiveTypeTable: Codable, Hashable, Sendable {
        public let tables: [String: [String: [Double]]] // rarity → rank → [values per promo]
    }
    
    public struct PassiveGameData: Codable, Hashable, Sendable {
        public let source: String?
        public let passiveIdToType: [String: String]?
    }
}

// MARK: - Rank Helpers

extension SMPassiveTables {
    /// Max promotions allowed for a given rank (0-5)
    public static func maxPromoForRank(_ rank: Int) -> Int {
        if rank <= 1 { return 1 }
        return rank // R2→p2, R3→p3, R4→p4, R5→p5
    }
    
    /// Lookup a passive value for a given type/rarity/rank/promotion
    public func lookupPassiveValue(type: String, rarity: String, rank: Int, promoted: Int) -> Double? {
        guard let typeTable = passives[type],
              let rarityTable = typeTable.tables[rarity.lowercased()],
              let rankRow = rarityTable["R\(rank)"] else { return nil }
        
        let maxP = Self.maxPromoForRank(rank)
        let promoIdx = min(promoted, maxP) - 1
        guard promoIdx >= 0, promoIdx < rankRow.count else { return nil }
        return rankRow[promoIdx]
    }
}
