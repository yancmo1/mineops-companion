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
| `activeEffect` | String | “++ Mining speed & infinite worker capacity” | Parsed effect description |
| `activeDuration` | String | `5m` | Time active boost lasts |
| `activeCooldown` | String | `30m` | Cooldown duration before next activation |
| `passiveLevel10` | String | `++ Warehouse worker walking/loading speed` | Effect text at level 10 |
| `passiveLevel30` | String | `-- Warehouse Upgrade Cost` | Effect text at level 30 |
| `passiveLevel50` | String | `++ Continent Income` | Effect text at level 50 |
| `notes` | Optional String | `Needs manual review` | Free-form notes |
| `levelCurrent` | Int | `13` | Current SM level *(Phase 2+)* |
| `levelMax` | Int | `50` | Level cap *(Phase 2+)* |
| `promotionLevel` | Int | `1` | Number of promotions unlocked *(Phase 2+)* |
| `promotionMax` | Int | `5` | Maximum promotions available *(Phase 2+)* |
| `stars` | Int | `3` | Number of filled stars (promotion progress) *(Phase 2+)* |
| `activeMultiplier` | Float | `4.76` | Multiplier value before “x” *(Phase 2+)* |
| `passiveMultiplier` | Float | `1.06` | Always listed on passive card *(Phase 2+)* |
| `passiveDuration` | Optional String | `—` | Only some event SMs include passive durations *(Phase 2+)* |
| `hasRankUp` | Bool | true | Found if “Rank Up” visible *(Phase 2+)* |
| `hasLevelUp` | Bool | true | Found if “Level Up” visible *(Phase 2+)* |
| `hasPromote` | Bool | true | Found if “Promote” visible *(Phase 2+)* |

---

### 🎯 MVP Field Scope (Phase 1)
- `name`
- `rarity`
- `role`
- `activeEffect`
- `activeDuration` (with normalized seconds)
- `activeCooldown` (with normalized seconds)
- `passiveLevel10`
- `passiveLevel30`
- `passiveLevel50`
- `notes` (optional, manual review marker)

All other fields in the table above are considered **Phase 2+** and should be captured only when the broader strategy/export feature set is underway.

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
   - Perform `Vision` OCR on each region separately.
   - Normalize numbers (strip “x”, “m”, “h” suffixes and store normalized seconds alongside display strings).
   - Map OCR results to fields using contextual keywords:
     - If “Active” detected → parse within bounding box.
     - If “Passive” detected → same logic.
     - Detect “Promotion:” to isolate promotion level pair.

3. **Post-Processing**
   - When multipliers are captured (Phase 2+), validate the values as floats.
   - Auto-convert durations (`5m` = 300 sec, `30m` = 1800 sec).
   - Save combined OCR data into the SwiftData-ready structure:
     ```json
     {
       "name": "Mr. Edmund",
       "role": "Warehouse",
       "rarity": "Rare",
       "activeEffect": "deepest Mineshaft extraction to cash",
       "activeDuration": "120 sec",
       "activeDurationSeconds": 120,
       "activeCooldown": "15 min",
       "activeCooldownSeconds": 900,
       "passiveLevel10": "++ Warehouse worker walking/loading speed",
       "passiveLevel30": "-- Warehouse Upgrade Cost",
       "passiveLevel50": "++ Continent Income",
       "notes": null
     }
     ```

4. **Data Verification**
   - Cross-check `name` with known Super Manager list (stored locally).
   - If OCR result confidence < 80%, flag for manual review in app.

---

## 🌐 EXTERNAL DATA AUGMENTATION (Wiki Sync)

After OCR parsing, enrich each record with static data pulled from authoritative sources.  
*Phase 1:* rely on bundled seed JSON shipped with the package.  
*Phase 2+:* optional automation can sync with Kolibri Games Help Center or community wikis.

| Field | Source | Example | Description |
|--------|---------|----------|-------------|
| `mineAffinity` | Helpshift (e.g., “Mr Edmund”) | “Warehouse” | Base specialization |
| `elementAffinity` | Wiki (Elemental Mines) | “Water”, “Fire”, “Earth”, “Electric” | SM’s elemental synergy |
| `bestMines` | Wiki | “Fire Mine”, “Ice Mine” | Best mines for that manager |
| `bonusType` | Wiki | “Boost Duration +x%” | Passive bonus type |
| `availability` | Wiki | “Event Exclusive” | Determines if obtainable |
| `releaseDate` | Wiki | “2024-02-11” | Optional metadata |
| `wikiURL` | Helpshift or fandom | Direct URL to source |

The package’s `Resources/Seeds/` directory should contain:
```
MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/Resources/Seeds/super_managers.seed.json
```
with baseline wiki-synced records for known managers.  
OCR will update *dynamic fields* (active/passive effects, durations, cooldowns), while static metadata can be merged in during Phase 2 sync work.

---

## 🧩 STORAGE MODEL

Each parsed manager entry is stored as a SwiftData `@Model`:

| Property | Type | Notes |
|----------|------|-------|
| `id` | UUID | Auto-generated |
| `name` | String | Normalized manager name |
| `rarity` | Rarity enum | `common/rare/epic/legendary/unknown` |
| `role` | Role enum | `mineshaft/elevator/warehouse/unknown` |
| `activeEffect` | String | Raw effect string |
| `activeDurationSeconds` | Int | Normalized duration in seconds |
| `activeCooldownSeconds` | Int | Normalized cooldown in seconds |
| `passiveLevel10` | String? | Optional text |
| `passiveLevel30` | String? | Optional text |
| `passiveLevel50` | String? | Optional text |
| `notes` | String? | Manual annotations / review flags |
| `needsReview` | Bool | Auto-set when required fields missing |
| `lastUpdated` | Date | Timestamp of last save |

`ParsedImage` is a companion model linking the original OCR run (sourceName, raw text, timestamp) to the confirmed `SuperManager`.

---

## ⚙️ AGENT TASKS

### Phase 1 (OCR + SwiftData Foundation)
1. **Enhance OCRProcessor.swift**
   - Capture MVP fields (name, role, rarity, active effect/duration/cooldown, passive level text).  
   - Implement per-section parsing (header, active, passive).  
   - Normalize durations/cooldowns to seconds alongside display strings.
2. **Link to SwiftData**
   - Map parsed results into `SuperManager` + `ParsedImage` models.  
   - Flag entries as `needsReview` when required fields missing or low-confidence.
3. **Testing Support**
   - Update `OCRFieldExtractionTests` and related fixtures to cover duration parsing, passive extraction, and empty-field fallbacks.

### Phase 2+ (Strategy, Sync, Diagnostics)
- **DataSyncManager.swift:** Merge Helpshift/wiki metadata into existing records on demand.  
- **Debug Overlay:** Visualize OCR bounding boxes and confidence for calibration.  
- **Extended Field Capture:** Add support for levels, promotions, multipliers, and button flags when strategy/export features require them.

---

## ✅ Success Criteria

- OCR detects **name, role, rarity, active effect, durations, cooldowns, and passive level text** from a screenshot with ≥ 90 % accuracy on clear samples.  
- Parsed results persist to SwiftData (`SuperManager` + `ParsedImage`) and survive app relaunches.  
- Seed importer populates baseline managers and avoids duplicates on re-run.  
- Phase 2+ items (levels, multipliers, external sync) are documented and deferred until strategy/export work begins.

---

**End of PRD**
