# Super Manager Resources

This directory contains JSON data files for Super Manager information used in the MineOps Companion app.

## Files

### sm_base_stats.json
**Purpose**: New base stats database with upgrade formulas  
**Created**: 2026-02-04  
**Version**: 1.0.0

Comprehensive base stats for Super Managers including:
- Base active ability multipliers at level 1
- Passive ability unlock levels and base multipliers
- Upgrade formulas by rarity tier
- Duration and cooldown information

**Used by**:
- `SMBaseStatsLoader.swift` - Loads manager data
- `SMUpgradeProjectionView.swift` - Shows upgrade projections
- `SMUpgradeCalculator.swift` - Calculates stats at any level

### sm_complete_database.json
**Purpose**: Legacy complete database  
**Version**: 4.42.1  
**Last Updated**: 2025-11-01  
**Managers**: 31

Comprehensive manager information including:
- Detailed descriptions
- Element affinities
- Availability information
- Some progression data for select managers

### sm_directory.json
**Purpose**: Manager directory for name matching  
**Managers**: Multiple

Used for:
- OCR name matching
- Directory lookups
- Aliases and alternate names

### supermanagers.json
**Purpose**: Basic manager data  
**Managers**: 6

Simplified manager information for:
- Quick lookups
- Basic stats reference

## Data Relationships

```
sm_base_stats.json          ← New: Upgrade calculator source
    ↓
SMBaseStatsLoader
    ↓
SMUpgradeCalculator
    ↓
SMUpgradeProjectionView

sm_complete_database.json   ← Existing: Full game data
    ↓
Various app features

sm_directory.json           ← Existing: Name matching
    ↓
OCR and directory matching
```

## Maintenance

When updating manager data:

1. **For new managers**: Add to both `sm_base_stats.json` and `sm_complete_database.json`
2. **For stat changes**: Update base multipliers in `sm_base_stats.json`
3. **For name aliases**: Update `sm_directory.json`
4. **Version updates**: Increment version numbers and update `lastUpdated` dates

## Schema Differences

### sm_base_stats.json
```json
{
  "baseStats": {
    "level": 1,
    "activeMultiplier": 5.0,
    "activeDuration": "5m"
  },
  "passives": [{
    "unlockLevel": 10,
    "baseMultiplier": 2.0,
    "type": "mining_speed"
  }]
}
```

### sm_complete_database.json
```json
{
  "active": {
    "description": "Grant 5x mining speed",
    "multiplier": 5.0,
    "duration": "5m"
  },
  "passives": [{
    "unlockLevel": 10,
    "type": "mining_speed",
    "multiplier": 2.0,
    "progression": [
      {"level": 10, "value": 2.3}
    ]
  }]
}
```

## Adding New Managers

Use this template for `sm_base_stats.json`:

```json
{
  "id": "manager_id",
  "name": "Manager Name",
  "rarity": "Common|Rare|Epic|Legendary",
  "type": "Mine Shaft|Elevator|Warehouse",
  "baseStats": {
    "level": 1,
    "promotion": 0,
    "activeMultiplier": 0.0,
    "activeDuration": "Xm",
    "activeCooldown": "Xm"
  },
  "passives": [
    {
      "unlockLevel": 10,
      "type": "ability_type",
      "baseMultiplier": 0.0,
      "description": "Human readable description"
    }
  ]
}
```

## Validation

Before committing changes:

1. Validate JSON syntax
2. Run `SMBaseStatsLoaderTests`
3. Verify all managers load correctly
4. Check rarity values are valid
5. Ensure active multipliers are positive

## See Also

- [SM Upgrade System Documentation](../../Docs/SM-Upgrade-System.md)
- [SMBaseStatsLoader.swift](../Sources/MineOpsCompanionFeature/Data/SMBaseStatsLoader.swift)
- [SMUpgradeCalculator.swift](../Sources/MineOpsCompanionFeature/Models/SMUpgradeCalculator.swift)
