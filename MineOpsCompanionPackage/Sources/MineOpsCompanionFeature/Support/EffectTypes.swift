import Foundation

// MARK: - Passive Effects

enum PassiveEffectType: String, CaseIterable, Identifiable, Codable {
    case barrierUnlockCost = "barrier_unlock_cost"
    case beamResourcesToWarehouse = "beam_resources_to_warehouse"
    case continentIncomeBoost = "continent_income_boost"
    case elevatorUpgradeCost = "elevator_upgrade_cost"
    case idleCashBoost = "idle_cash_boost"
    case loadingMovementSpeedBoost = "loading_movement_speed_boost"
    case mineIncomeFaster = "mine_income_faster"
    case mineshaftUnlockCostReduced = "minelock_shaft_unlock_cost_reduced"
    case miningSpeedBoost = "mining_speed_boost"
    case miningWalkingSpeedBoost = "mining_walking_speed_boost"
    case movementSpeedBoost = "movement_speed_boost"
    case upgradeCostReduced = "upgrade_cost_reduced"
    case warehouseUpgradeCost = "warehouse_upgrade_cost"
    case walkingSpeedBoost = "walking_speed_boost"
    case walkingLoadingSpeedBoost = "walking_loading_speed_boost"
    case other = "other"
    case skip = "skip"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .barrierUnlockCost: return "Barrier Unlock Cost ↓"
        case .beamResourcesToWarehouse: return "Beam Resources → Warehouse"
        case .continentIncomeBoost: return "Continent Income ↑"
        case .elevatorUpgradeCost: return "Elevator Upgrade Cost ↓"
        case .idleCashBoost: return "Idle Cash ↑"
        case .loadingMovementSpeedBoost: return "Loading & Movement Speed ↑"
        case .mineIncomeFaster: return "Mine Income ↑"
        case .mineshaftUnlockCostReduced: return "Mine Shaft Unlock Cost ↓"
        case .miningSpeedBoost: return "Mining Speed ↑"
        case .miningWalkingSpeedBoost: return "Mining & Walking Speed ↑"
        case .movementSpeedBoost: return "Movement Speed ↑"
        case .upgradeCostReduced: return "Upgrade Cost ↓"
        case .warehouseUpgradeCost: return "Warehouse Upgrade Cost ↓"
        case .walkingSpeedBoost: return "Walking Speed ↑"
        case .walkingLoadingSpeedBoost: return "Walking & Loading Speed ↑"
        case .other: return "Other (Unlisted Passive)"
        case .skip: return "Skip"
        }
    }
}

// MARK: - Active Effects

enum ActiveEffectType: String, CaseIterable, Identifiable, Codable {
    case storeAndUnloadMultiplier = "store_and_unload_multiplier"
    case beamOrTransmitToWarehouse = "beam_or_transmit_to_warehouse"
    case upgradeCostReduction = "upgrade_cost_reduction"
    case movementSpeedBoost = "movement_speed_boost"
    case miningSpeedBoost = "mining_speed_boost"
    case globalAreaBoost = "global_area_boost"
    case cashGeneration = "cash_generation"
    case resourceTransformation = "resource_transformation"
    case other = "other"
    case skip = "skip"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .storeAndUnloadMultiplier: return "Store & Unload Multiplier"
        case .beamOrTransmitToWarehouse: return "Beam / Transmit to Warehouse"
        case .upgradeCostReduction: return "Upgrade Cost Reduction"
        case .movementSpeedBoost: return "Movement Speed Boost"
        case .miningSpeedBoost: return "Mining Speed Boost"
        case .globalAreaBoost: return "Global Area Boost (All)"
        case .cashGeneration: return "Cash Generation"
        case .resourceTransformation: return "Resource → Cash Conversion"
        case .other: return "Other (Unlisted Active)"
        case .skip: return "Skip"
        }
    }
}

// MARK: - Helper for Dropdown UI

struct EffectTypeLists {
    static let passiveTypes = PassiveEffectType.allCases
    static let activeTypes = ActiveEffectType.allCases
}
