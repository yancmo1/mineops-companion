# Super Manager Base Stats & Upgrade Calculator

This system provides comprehensive base stats for Super Managers and calculates projected stats at any level and promotion.

## Overview

The SM upgrade system consists of three main components:

1. **Base Stats Database** (`sm_base_stats.json`) - JSON database with base stats for all Super Managers
2. **Upgrade Calculator** (`SMUpgradeCalculator.swift`) - Mathematical formulas to calculate stats at any level
3. **UI Components** - Interactive views to display upgrade projections

## Usage

### Calculating Stats Programmatically

```swift
// Calculate stats for Chester at level 10
let stats = SMUpgradeCalculator.calculateStats(
    baseActiveMultiplier: 5.0,
    currentLevel: 10,
    promotion: 1,
    rarity: .common,
    passives: [
        (unlockLevel: 10, baseMultiplier: 0.5, type: "upgrade_cost_reduction")
    ]
)

print("Active: \(stats.activeMultiplierDisplay)")  // e.g., "144.56x"
print("Passives unlocked: \(stats.passives.count)")
```

### Loading Manager Data from JSON

```swift
// Load a specific manager
let chester = try SMBaseStatsLoader.getManager(id: "chester")

// Get all legendary managers
let legendaries = try SMBaseStatsLoader.getManagersByRarity("Legendary")

// Convert to calculator inputs
if let inputs = SMBaseStatsLoader.toCalculatorInputs(manager: chester) {
    let stats = SMUpgradeCalculator.calculateStats(
        baseActiveMultiplier: inputs.baseMultiplier,
        currentLevel: 15,
        promotion: 1,
        rarity: inputs.rarity,
        passives: inputs.passives
    )
}
```

### Showing Upgrade Projection UI

```swift
// In your SwiftUI view
@State private var showUpgradeProjection = false

var body: some View {
    Button("View Upgrade Projection") {
        showUpgradeProjection = true
    }
    .sheet(isPresented: $showUpgradeProjection) {
        SMUpgradeProjectionSheet(managerId: "chester")
    }
}
```

## Upgrade Formulas

Stats are calculated based on rarity-specific multipliers:

### Active Ability Multipliers (Per Level)

| Rarity    | Levels 1-10 | Levels 11-20 | Levels 21-30 | Levels 31-40 |
|-----------|-------------|--------------|--------------|--------------|
| Common    | 1.40x       | 1.40x        | 1.337x       | 1.30x        |
| Rare      | 1.45x       | 1.35x        | 1.30x        | -            |
| Epic      | 1.50x       | 1.45x        | -            | -            |
| Legendary | 1.55x       | 1.50x        | -            | -            |

### Max Levels by Rarity

- **Common**: Level 40, Promotion 4
- **Rare**: Level 30, Promotion 3
- **Epic**: Level 20, Promotion 2
- **Legendary**: Level 20, Promotion 2

### Formula Example

For Chester (Common) at Level 10:
- Base active multiplier: 5.0x
- Levels 2-10 each multiply by 1.40x
- Final multiplier: 5.0 × (1.40^9) ≈ 144.56x

### Passive Abilities

Passive abilities unlock at specific levels (typically 10, 30, 50) and maintain their base multiplier value once unlocked. Currently, passive multipliers do not increase with level, though this could be enhanced with progression formulas in the future.

## Data Structure

### sm_base_stats.json

```json
{
  "version": "1.0.0",
  "upgradeFormulas": {
    "Common": {
      "maxLevel": 40,
      "maxPromotion": 4,
      "levelMultipliers": { ... }
    }
  },
  "managers": [
    {
      "id": "chester",
      "name": "Chester",
      "rarity": "Common",
      "type": "Mine Shaft",
      "baseStats": {
        "level": 1,
        "promotion": 0,
        "activeMultiplier": 5.0,
        "activeDuration": "5m",
        "activeCooldown": "30m"
      },
      "passives": [
        {
          "unlockLevel": 10,
          "type": "upgrade_cost_reduction",
          "baseMultiplier": 0.5,
          "description": "Upgrade Cost Reduction"
        }
      ]
    }
  ]
}
```

## Extending the System

### Adding New Managers

1. Add manager data to `sm_base_stats.json`
2. Include all required fields: id, name, rarity, type, baseStats, passives
3. Ensure rarity is one of: Common, Rare, Epic, Legendary

### Adding Passive Progression

To make passives scale with level:

1. Add progression formulas to `SMUpgradeCalculator.calculatePassiveMultiplier()`
2. Consider passive type (e.g., speed boosts might scale differently than cost reductions)
3. Add tests to verify progression calculations

### Custom Upgrade Formulas

To add custom formulas for specific managers:

1. Extend `SMUpgradeCalculator` with manager-specific methods
2. Add conditional logic based on manager ID
3. Document the custom formula in this guide

## Testing

The system includes comprehensive test coverage:

- `SMUpgradeCalculatorTests.swift` - 25+ tests for calculation logic
- `SMBaseStatsLoaderTests.swift` - 15+ tests for data loading

Run tests:
```bash
# From Xcode
⌘U (Command+U)

# Or using test simulator
test_sim_name_ws with scheme MineOpsCompanion
```

## Future Enhancements

Potential improvements to the system:

1. **Passive Progression**: Add formulas for passive abilities to scale with level
2. **Rank Up Effects**: Model rank-up bonuses that occur after max level
3. **Equipment Bonuses**: Factor in equipment multipliers
4. **Synergy Calculations**: Calculate combined effects when multiple SMs are active
5. **Cost Calculator**: Show gem costs for upgrades
6. **Comparison View**: Compare multiple managers side-by-side
7. **Export/Share**: Allow users to export upgrade paths

## Sources

Data based on:
- Idle Miner Tycoon Wiki: https://idleminertycoon.fandom.com/wiki/Super_Managers
- Official game data and community research
- In-game observations

## Contributing

When adding or updating manager data:

1. Verify stats in-game when possible
2. Update both `sm_base_stats.json` and `sm_complete_database.json` if needed
3. Add tests for new managers
4. Update this documentation with any formula changes
