# MineOps iOS OCR Parser Replacement Plan (No LLM Required)

## Objective

Build a reliable, deterministic “manager screen” image parser on iOS that extracts a structured `StrategyManagerFacts` object from screenshots like the examples you provided, **without** using GPT/LLMs for OCR.

This new parser must be introduced **alongside** your existing implementation first (feature-flagged and A/B comparable), then promoted to replace it only after you confirm reliability.

## Scope

### In scope
- Extract these fields from the Manager detail screen:
  - `name`
  - `department` (Warehouse / Mineshaft / Elevator)
  - `activeMultiplier` (e.g., `3.42x`)
  - `activeDuration` (e.g., `2m`, `2m 30s`)
  - `cooldown` (e.g., `15m`, `30m`)
  - `passiveBonuses` (values + icon classification if possible)
  - `elements` (icon set on the right rail)
  - `equipment` (icon to the right of department row when present)
  - `computedScore` (optional, downstream “Strategy” phase)
- Robust parsing + validation + confidence scoring.
- Debug artifacts: store crops + OCR text + parse results for iteration.
- iOS-native stack: Vision + Core Image (+ optional Accelerate).

### Out of scope (for this phase)
- Building a custom-trained OCR model.
- General OCR of arbitrary IMT screens.
- Fully “semantic” strategy reasoning (that’s the separate Strategy stage where you can spend tokens).

## Why a no-LLM OCR parser is the right first move

These Manager screens are an unusually good candidate for classic OCR + rules because:
- Layout is consistent and UI is stable.
- Target values are short, strongly-formatted tokens: `N.NNx`, `-N.N%`, `Xm Ys`.
- The “hard” parts are icons (elements/equipment/passive types), which are better solved via icon matching than OCR.

Result: you can keep GPT tokens for **Strategy** (ranking, rotations, recommendations) instead of burning them on image parsing.

## Recommended architecture

### Data model

Define a model that carries both parsed values and raw OCR strings (for debugging and recovery).

- `StrategyManagerFacts`
  - `name: String`
  - `department: Department`
  - `activeMultiplier: Double?` and `activeMultiplierRaw: String`
  - `activeDurationSec: Int?` and `activeDurationRaw: String`
  - `cooldownSec: Int?` and `cooldownRaw: String`
  - `passiveBonuses: [PassiveBonus]`
  - `elements: [ElementId]` (ordered top→bottom)
  - `equipment: EquipmentId?`
  - `confidence: FactsConfidence`
  - `computedScore: Double?` (optional; Strategy stage)

- `PassiveBonus`
  - `slot: Int` (1–3)
  - `value: Double?`
  - `unit: Unit` (`multiplier`, `percent`, `unknown`)
  - `raw: String`
  - `iconType: PassiveIconId?` (optional now; improve over time)
  - `confidence: Double`

- `FactsConfidence`
  - `overall: Double`
  - `perField: [FieldId: Double]`
  - `needsReview: Bool`
  - `errors: [String]`

### Pipeline components

1. `ScreenshotNormalizer`
   - Normalizes orientation, ensures a consistent pixel format.
   - Outputs a `CGImage` or `CIImage` and metadata (width/height).

2. `ManagerScreenDetector`
   - Fast check that the screenshot is the correct screen type.
   - Recommended heuristic: look for the “Active” and “Passive” headers region via OCR on a narrow strip, or verify presence of the bottom panel layout using image feature prints.
   - If detection fails: return `notManagerScreen`.

3. `RegionLocator`
   - Produces crop rectangles for each field (in image coordinates).
   - Strategy: **normalized coordinates** relative to the screenshot size (unit rects), with a compatibility layer for minor UI scaling.
   - Future upgrade: anchor refinement (detect bottom panel top edge, right rail position, etc.) but start with normalized rects.

4. `ImagePreprocessor`
   - Applies per-field preprocessing presets:
     - `grayscale`
     - `upscale` (2×–4×)
     - `contrast`
     - `adaptive threshold` (optional; per field)
     - `sharpen` (light)
   - The goal is to make text “high-contrast” against backgrounds for OCR.

5. `TextRecognizer` (Vision)
   - Uses `VNRecognizeTextRequest` with:
     - `recognitionLevel = accurate`
     - `usesLanguageCorrection = false` (often better for tokens like `3.42x`)
     - Restrict recognition languages to English.
   - Returns: best candidate string + confidence per region.

6. `TokenParsers`
   - Strict parsers with fail-closed behavior:
     - Multiplier tokens: `number + "x"`
     - Percent tokens: optional sign + `number + "%"`
     - Duration tokens: `Xm`, `Ys`, or `Xm Ys`
   - Also include “common OCR fixups” **before parsing**:
     - Replace `O`→`0` when surrounded by digits
     - Replace `l`/`I`→`1` when numeric context is strong
     - Normalize whitespace and punctuation

7. `IconClassifier` (no OCR)
   - For `elements`, `equipment`, and optionally passive icons.
   - Recommended iOS-native approach:
     - Create a library of template crops from known icons.
     - Generate Vision feature prints for both template and query crops (image embeddings).
     - Compare distance; accept the best match if under threshold.
   - Store match id + confidence. If under threshold: mark `unknown` and continue.

8. `FactsAssembler`
   - Combines region OCR + parsed tokens + icon matches into `StrategyManagerFacts`.

9. `Validator`
   - Applies “hard rules” and sets `needsReview` if violated:
     - `activeMultiplier` must be > 0 and < 1000
     - durations must be within sensible ranges (1s–3600s)
     - cooldown must be within 1s–24h
     - percent typically within -99.9% to +999% (configurable)
     - multiplier typically within 0.01x to 100x (configurable)
   - Produces overall confidence.

10. `DebugArtifactStore`
   - Stores:
     - original screenshot id
     - per-field crops (before/after preprocessing)
     - raw OCR strings + Vision confidences
     - parsed values
     - icon match results
     - final facts JSON
   - This is critical to iterating quickly without guessing.

## Integration plan (do not remove your current setup yet)

### Phase 0 — Add feature flag + parallel execution
- Add a runtime flag: `NewManagerParserEnabled` (default OFF).
- When ON:
  - Run the new parser AND your existing parser in parallel on the same screenshot.
  - Save both outputs plus a “diff summary”.

### Phase 1 — Compare and iterate
- Build a comparison view (internal/debug only) that highlights:
  - Field-by-field differences
  - Confidence scores
  - The exact crop image used for each field
- Start collecting a small dataset (50–200 screenshots) across:
  - different managers, rarities
  - different departments
  - different elements/equipment
  - locked passive slots
  - varied lighting/backgrounds (as they appear in-game)

### Phase 2 — Promote to default with fallback
- When your measured accuracy is acceptable, switch default:
  - New parser first
  - Old parser as fallback only when `needsReview == true` or `notManagerScreen`

### Phase 3 — Remove old parser (only after confidence)
- Remove only after:
  - steady-state logs show low `needsReview`
  - edge cases are understood and handled

## Region map for the Manager screen (initial normalized rect approach)

Start with a reference image size (your examples are 1320×2868) and define unit rectangles (0–1) that scale to any screenshot size. Maintain these in a single file: `ManagerScreenRegionMap.swift` (or similar).

Field regions to define:
- `nameRect`
- `departmentRect`
- `activeMultiplierRect`
- `activeDurationRect`
- `cooldownRect`
- `passiveValueRects[1..3]`
- `elementsRailRects[]` (each circle)
- `equipmentRect`

Guidance:
- Keep rectangles slightly “loose” to tolerate UI shifts.
- Favor cropping only the token bubble area (avoid icons inside the crop when OCRing numbers).

Upgrade path:
- After baseline works, add “anchor checks” (detect bottom panel boundary) to adjust unit rects slightly if needed.

## OCR presets (per-field)

Use different preprocessing presets for:
- `name` and `department` (larger font, white text on darker background)
- numeric tokens in blue bubbles (very OCR-friendly after contrast/threshold)
- percent values (ensure minus sign survives thresholding)

Keep preprocessing configurable:
- `PresetName.departmentText`
- `PresetName.numericBubble`
- `PresetName.percentBubble`

Store preset parameters in code (or a small JSON) so you can tweak without invasive changes.

## Icon classification plan (elements/equipment/passive icons)

### Template library
- Create a “golden set” of icon templates:
  - each element icon (right rail)
  - equipment icons you care about (e.g., shoes)
  - passive icons (optional in Phase 1)

Store templates in the app bundle and/or as generated assets.

### Matching
- Use feature print matching (embedding distance) for robustness.
- Maintain per-category thresholds:
  - elements: strict threshold
  - equipment: strict threshold
  - passive icons: slightly looser at first (many are visually similar)

### Output
- Always output an id + confidence.
- If confidence is low, return `unknown` (do not guess).

## Validator rules (local, mirrored in Strategy prompts)

Hard rules (fail-closed):
- If `name` is empty OR department is unknown -> `needsReview = true`.
- If `activeMultiplier` fails parse -> `needsReview = true`.
- If duration/cooldown fail parse -> `needsReview = true`.
- Passive values:
  - If raw ends with `%`, unit must be percent.
  - If raw ends with `x`, unit must be multiplier.
  - Otherwise unit unknown and `confidence` reduced.

Soft rules (confidence reducers):
- Unexpected ranges (configurable).
- OCR confidence below threshold for a field.
- Icon match below threshold.

## Logging and debug artifacts (must-have for iteration)

For every parse attempt (or at least for failures), record:
- `screenshotId`
- image size
- crop rects used
- preprocessed crop images
- OCR candidates + Vision confidences
- parsed values + parse errors
- icon match results + distances
- final facts + confidence

Provide a debug UI to inspect the last N attempts and export a “bundle” for diagnosis.

## Test strategy

### Unit tests
- Token parser tests:
  - Multipliers: `3.42x`, `11.01x`, `1.5x`
  - Percents: `-43.7%`, `-14.5%`
  - Durations: `2m`, `2m 30s`, `30s`, `15m`
- “Fixup” tests:
  - `l.11x` → `1.11x`
  - `2m3Os` → `2m 30s`
- Validator tests:
  - range boundaries
  - missing fields => `needsReview`

### Snapshot tests (recommended)
- Maintain a small gallery of test screenshots in a private test target.
- Run the parser and assert:
  - non-null fields for known images
  - stable output JSON (allowing minor confidence changes)

## Performance and UX considerations

- Run parsing off the main thread.
- Use batching for Vision requests where possible:
  - OCR crops can be recognized in a small number of requests.
- Keep a time budget target (example):
  - < 200–400ms on modern iPhones for a single screenshot parse (excluding disk I/O).
- Avoid user-visible delays; show “Parsing…” only when necessary.

## How this connects to Strategy (where you can spend GPT tokens)

Once `StrategyManagerFacts` is reliable and deterministic:
- Send ONLY the facts JSON (not images) to GPT for:
  - ranking
  - rotation recommendations
  - computed scores
  - rule-based explanation
- Include your “hard rules” in the Strategy prompt, but still validate locally.

This makes token use predictable and small, and keeps the system robust if GPT output is ever malformed.

## Deliverables checklist (implementation order)

1. `StrategyManagerFacts` + confidence model
2. Region map (unit rects) for all needed fields
3. Preprocessing presets per field
4. Vision OCR wrapper with per-region confidence
5. Token parsers + fixups + validator
6. Debug artifact store (crops + JSON + diffs)
7. Feature flag + parallel run + diff view
8. Icon classifier (elements/equipment first, passive icons later)
9. Promote new parser → default + fallback
10. Remove old parser (only after you confirm stability)

## Acceptance criteria

You should consider this “ready to replace” when:
- On your dataset (minimum 100 screenshots), the new parser correctly extracts:
  - name, department, active multiplier, duration, cooldown
  - passive values (where unlocked)
  - elements/equipment at least as `unknown` rather than incorrect
- `needsReview` rate is low and explainable (e.g., bad screenshots, transitions, motion blur)
- Debug artifacts make failures easy to diagnose and fix
- Your Strategy layer can operate entirely on `StrategyManagerFacts` without needing image access

## Notes specific to your managers example set

From your sample screens, the parser must handle:
- durations formatted as both `2m` and `2m 30s`
- passive slots that are locked (icon shown but no value bubble)
- department labels: `Warehouse`, `Mineshaft`, `Elevator`
- equipment sometimes present (e.g., shoes on Mineshaft row for Dr. Steiner)

Those cases should be explicitly included in your test gallery.