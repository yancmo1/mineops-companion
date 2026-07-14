// # File: Sources/MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/Models/KolibriModels.swift

import Foundation

// MARK: - Savegame Response

/// Root response from Kolibri savegame API
public struct KolibriSavegameResponse: Codable, Hashable, Sendable {
    public let saveGameData: SaveGameData?
    public let timestamp: Date?
    
    enum CodingKeys: String, CodingKey {
        case saveGameData = "save_game_data"
        case timestamp
    }
    
    public init(saveGameData: SaveGameData?, timestamp: Date?) {
        self.saveGameData = saveGameData
        self.timestamp = timestamp
    }
}

// MARK: - Save Game Data

/// Main save game data structure
public struct SaveGameData: Codable, Hashable, Sendable {
    public let version: String?
    public let playerData: PlayerData?
    public let mines: [MineData]?
    public let managers: [ManagerData]?
    public let continents: [ContinentData]?
    public let resources: Resources?
    public let settings: GameSettings?
    
    // Store raw JSON for future parsing
    public let rawData: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case version
        case playerData = "player_data"
        case mines
        case managers
        case continents
        case resources
        case settings
    }

    public init(
        version: String? = nil,
        playerData: PlayerData? = nil,
        mines: [MineData]? = nil,
        managers: [ManagerData]? = nil,
        continents: [ContinentData]? = nil,
        resources: Resources? = nil,
        settings: GameSettings? = nil,
        rawData: [String: AnyCodable]? = nil
    ) {
        self.version = version
        self.playerData = playerData
        self.mines = mines
        self.managers = managers
        self.continents = continents
        self.resources = resources
        self.settings = settings
        self.rawData = rawData
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        version = try container.decodeIfPresent(String.self, forKey: .version)
        playerData = try container.decodeIfPresent(PlayerData.self, forKey: .playerData)
        mines = try container.decodeIfPresent([MineData].self, forKey: .mines)
        managers = try container.decodeIfPresent([ManagerData].self, forKey: .managers)
        continents = try container.decodeIfPresent([ContinentData].self, forKey: .continents)
        resources = try container.decodeIfPresent(Resources.self, forKey: .resources)
        settings = try container.decodeIfPresent(GameSettings.self, forKey: .settings)
        
        // Store everything for future use
        let allContainer = try decoder.singleValueContainer()
        rawData = try? allContainer.decode([String: AnyCodable].self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(playerData, forKey: .playerData)
        try container.encodeIfPresent(mines, forKey: .mines)
        try container.encodeIfPresent(managers, forKey: .managers)
        try container.encodeIfPresent(continents, forKey: .continents)
        try container.encodeIfPresent(resources, forKey: .resources)
        try container.encodeIfPresent(settings, forKey: .settings)
    }
}

// MARK: - Player Data

public struct PlayerData: Codable, Hashable, Sendable {
    public let playerId: String?
    public let playerName: String?
    public let level: Int?
    public let experience: Int64?
    public let prestigeLevel: Int?
    
    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case playerName = "player_name"
        case level
        case experience
        case prestigeLevel = "prestige_level"
    }
}

// MARK: - Mine Data

public struct MineData: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String?
    public let mineType: String?
    public let level: Int?
    public let shaftCount: Int?
    public let elevatorLevel: Int?
    public let warehouseLevel: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case mineType = "mine_type"
        case level
        case shaftCount = "shaft_count"
        case elevatorLevel = "elevator_level"
        case warehouseLevel = "warehouse_level"
    }
}

// MARK: - Manager Data

public struct ManagerData: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String?
    public let rarity: String?
    public let rank: Int?
    public let level: Int?
    public let promotion: Int?
    public let assignedTo: String?
    public let fragments: Int?
    public let abilities: [AbilityData]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case rarity
        case rank
        case level
        case promotion
        case assignedTo = "assigned_to"
        case fragments
        case abilities
    }
}

// MARK: - Ability Data

public struct AbilityData: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let abilityType: String?
    public let value: Double?
    public let multiplier: Double?
    public let duration: Int?
    public let cooldown: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case abilityType = "ability_type"
        case value
        case multiplier
        case duration
        case cooldown
    }
}

// MARK: - Continent Data

public struct ContinentData: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String?
    public let unlocked: Bool?
    public let currentMine: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case unlocked
        case currentMine = "current_mine"
    }
}

// MARK: - Resources

public struct Resources: Codable, Hashable, Sendable {
    public let superCash: Int64?
    public let greenCash: Int64?
    public let eventKeys: Int?
    
    enum CodingKeys: String, CodingKey {
        case superCash = "super_cash"
        case greenCash = "green_cash"
        case eventKeys = "event_keys"
    }
}

// MARK: - Game Settings

public struct GameSettings: Codable, Hashable, Sendable {
    public let soundEnabled: Bool?
    public let musicEnabled: Bool?
    public let notificationsEnabled: Bool?
    
    enum CodingKeys: String, CodingKey {
        case soundEnabled = "sound_enabled"
        case musicEnabled = "music_enabled"
        case notificationsEnabled = "notifications_enabled"
    }
}

// MARK: - AnyCodable Helper

/// Helper type to decode arbitrary JSON
public struct AnyCodable: Codable, Hashable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        // Simple hash based on type
        hasher.combine(String(describing: type(of: value)))
    }
    
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Simplified equality
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}

// Mark AnyCodable as unchecked Sendable since it's used for JSON decoding
extension AnyCodable: @unchecked Sendable {}

// MARK: - Sync Diagnostics

public struct KolibriSyncDiagnostics: Hashable, Sendable {
    public let statusCode: Int
    public let payloadFormat: String
    public let rawPayloadBytes: Int
    public let decodedPayloadBytes: Int
    public let managerCount: Int
    public let payloadPrefixHex: String

    public init(
        statusCode: Int,
        payloadFormat: String,
        rawPayloadBytes: Int,
        decodedPayloadBytes: Int,
        managerCount: Int,
        payloadPrefixHex: String
    ) {
        self.statusCode = statusCode
        self.payloadFormat = payloadFormat
        self.rawPayloadBytes = rawPayloadBytes
        self.decodedPayloadBytes = decodedPayloadBytes
        self.managerCount = managerCount
        self.payloadPrefixHex = payloadPrefixHex
    }
}

public struct KolibriFetchResult: Sendable {
    public let savegame: KolibriSavegameResponse
    public let diagnostics: KolibriSyncDiagnostics

    public init(savegame: KolibriSavegameResponse, diagnostics: KolibriSyncDiagnostics) {
        self.savegame = savegame
        self.diagnostics = diagnostics
    }
}
