# MineOps Companion – OCR Extraction Map (Super Manager Data Spec)

## 🎯 Purpose
This PRD defines all the text and numeric data that must be extracted from each Idle Miner Tycoon Super Manager card image via OCR.  
It serves as a reference for both the OCR processor (to target fields precisely) and the data model (to store & compare stats across mines and elements).

---

## 📸 OCR INPUT: Super Manager Card

Each Super Manager card screenshot provides the following visible zones:

| Section | Example Screenshot Reference | Data Target | Notes |
|----------|-------------------------------|--------------|-------|
| Header | “Lee Vatori” / “Mr. Edmund” | `name` | Always top center of the card |
| Stars | ⭐⭐⭐ (3 filled) | `stars` | Count the filled stars (0–5) |
| Level Header | “47” or “Level 13/50” | `displayLevel` | Used for quick UI check |
| Rarity | “Common”, “Rare”, “Epic”, “Legendary”, “Mythic” | `rarity` | Located to left of portrait |
| Assignment | “Mine / Elevator / Transport / Warehouse” | `role` | Icon on right side of name |
| Promotion Progress | “Promotion: 1/5” | `promotionLevel` | Always present near bottom |
| Active Block | Box labeled “Active” | `activeEffect`, `activeDuration`, `activeCooldown`, `activeMultiplier` | Extract all visible time & boost values |
| Passive Block | Box labeled “Passive” | `passiveEffect`, `passiveMultiplier`, `passiveDuration` | Extract multiplier and duration if shown |
| Buttons | “Level Up”, “Promote”, “Rank Up” | `hasLevelUp`, `hasPromote`, `hasRankUp` | Boolean flags (optional OCR trigger) |
| Portrait Thumbnail | — | `portraitConfidence` | Optional image match for duplicate SM prevention |

---

## 🧠 OCR FIELD DEFINITIONS

| Field | Type | Example | Description |
|--------|------|----------|-------------|
| `name` | String | “Lee Vatori” | Display name |
| `rarity` | Enum | `Common`, `Rare`, `Epic`, `Legendary`, `Mythic` | Defines upgrade cost and passive multipliers |
| `role` | Enum | `Mine`, `Elevator`, `Warehouse`, `Transport` | Determines boost target |
| `levelCurrent` | Int | `13` | Current SM level |
| `levelMax` | Int | `50` | Level cap |
| `promotionLevel` | Int | `1` | Number of promotions unlocked |
| `promotionMax` | Int | `5` | Maximum promotions available |
| `stars` | Int | `3` | Number of filled stars (promotion progress) |
| `activeMultiplier` | Float | `4.76` | Multiplier value before “x” |
| `activeDuration` | String | `5m` | Time active boost lasts |
| `activeCooldown` | String | `30m` | Cooldown duration before next activation |
| `passiveMultiplier` | Float | `1.06` | Always listed on passive card |
| `passiveDuration` | Optional String | `—` | Only some event SMs include passive durations |
| `hasRankUp` | Bool | true | Found if “Rank Up” visible |
| `hasLevelUp` | Bool | true | Found if “Level Up” visible |
| `hasPromote` | Bool | true | Found if “Promote” visible |

---

## 🔍 OCR PROCESS FLOW

1. **Pre-Processing**
   - Use grayscale + contrast boost
   - Apply region masking to isolate key areas:
     - Header zone
     - Active / Passive boxes
     - Star icons
   - Use template coordinates for scaling per resolution (1080×2400, 1170×2532, etc.)

2. **Text Extraction**
   - Perform `VisionKit` OCR on each region separately.
   - Normalize numbers (strip “x”, “m”, “h” suffixes and store separately).
   - Map OCR results to fields using contextual keywords:
     - If “Active” detected → parse within bounding box.
     - If “Passive” detected → same logic.
     - Detect “Promotion:” to isolate promotion level pair.

3. **Post-Processing**
   - Validate `activeMultiplier` and `passiveMultiplier` values as floats.
   - Auto-convert durations (`5m` = 300 sec, `30m` = 1800 sec).
   - Save combined OCR data as JSON payload:
     ```json
     {
       "name": "Lee Vatori",
       "role": "Elevator",
       "rarity": "Common",
       "promotionLevel": 1,
       "promotionMax": 5,
       "levelCurrent": 13,
       "levelMax": 50,
       "activeMultiplier": 4.76,
       "activeDuration": "5m",
       "activeCooldown": "30m",
       "passiveMultiplier": 1.06
     }
     ```

4. **Data Verification**
   - Cross-check `name` with known Super Manager list (stored locally).
   - If OCR result confidence < 80%, flag for manual review in app.

---

## 🌐 EXTERNAL DATA AUGMENTATION (Wiki Sync)

After OCR parsing, enrich each record with static data pulled from the Kolibri Games help/wiki API or scraped dataset:

| Field | Source | Example | Description |
|--------|---------|----------|-------------|
| `mineAffinity` | Helpshift (e.g., “Mr Edmund”) | “Warehouse” | Base specialization |
| `elementAffinity` | Wiki (Elemental Mines) | “Water”, “Fire”, “Earth”, “Electric” | SM’s elemental synergy |
| `bestMines` | Wiki | “Fire Mine”, “Ice Mine” | Best mines for that manager |
| `bonusType` | Wiki | “Boost Duration +x%” | Passive bonus type |
| `availability` | Wiki | “Event Exclusive” | Determines if obtainable |
| `releaseDate` | Wiki | “2024-02-11” | Optional metadata |
| `wikiURL` | Helpshift or fandom | Direct URL to source |

The app’s `Data` folder should contain:
```
MineOpsCompanion/Data/supermanagers.json
```
with baseline wiki-synced records for known managers.  
OCR will update *dynamic fields* (level, promotion, boosts), not static metadata.

---

## 🧩 STORAGE MODEL

Each parsed manager entry is stored as a single object in SQLite / Core Data:

| Column | Type |
|---------|------|
| id | UUID |
| name | TEXT |
| rarity | TEXT |
| role | TEXT |
| promotionLevel | INT |
| levelCurrent | INT |
| activeMultiplier | REAL |
| passiveMultiplier | REAL |
| elementAffinity | TEXT |
| mineAffinity | TEXT |
| lastUpdated | DATETIME |

---

## ⚙️ AGENT TASKS

1. **Enhance OCRProcessor.swift**
   - Detect all new fields defined above.
   - Implement per-section parsing (header, active, passive, footer).
   - Add string normalization:  
     `4.76x → 4.76`, `30m → 1800`.

2. **Add DataSyncManager.swift**
   - Sync known manager info from Helpshift/Wiki JSON.
   - Match `name` field → enrich with static metadata.

3. **Add Debug Mode**
   - Show extracted OCR text regions overlaid in app for accuracy checks.

---

## ✅ Success Criteria

- OCR can detect **name, rarity, stars, levels, boosts, and times** from one screenshot with ≥ 90% accuracy.  
- Enriched JSON includes both **live game stats** and **reference metadata**.  
- Output file `supermanagers.json` updates dynamically as new screenshots are imported.

---

**End of PRD**