
# MineOps Companion – AI Strategy Engine Prompt PRD

## 1. Background

MineOps Companion uses an OpenAI model to generate **Idle Miner Tycoon** manager strategies based on the player’s current roster and mine state. The current AI output is often:

- Too generic (e.g. “rotate every few minutes”)
- Ignorant of real game constraints (multiple managers in one department at once)
- Missing concrete details like shaft assignments and burst timing
- Confused when managers are missing from the static directory (e.g. `Jeff`, `Sojo`)

We want to tighten the **prompt contract** and response format so the AI produces **specific, actionable burst plans** that match how we actually play the game.

This document defines what the AI “Strategy Engine” should do and how the prompt should be structured.

---

## 2. Goals

1. **Concrete Burst Rotations**  
   - Output should be a step‑by‑step burst script with timestamps, not vague advice.
2. **Respect Game Rules**  
   - Enforce 1 elevator, 1 warehouse, many shafts.  
   - Never assign managers to the wrong department.
3. **Use Only Known Managers**  
   - Only use managers passed in the “Available Managers” list.  
   - If department is unknown and can’t be inferred, exclude from the plan.
4. **Compact JSON for UI**  
   - Keep using the existing JSON schema: `comboName`, `recommendedManagers`, `strategySummary`, `estimatedMultiplier`, `detailedPlan`.
5. **Be Mine‑Aware**  
   - Strategies should be written for the specific mine context we pass (e.g. Mainland 1, Prestige 5, Max Shaft 30).

---

## 3. Non‑Goals

- Exact mathematical DPS / multiplier calculation.
- Auto‑discovering new managers from the web.
- Long essay explanations; we want **short, high‑signal tactics** suitable for in‑app display.

---

## 4. Current Behaviour (Problems)

Example decoded output (simplified):

```json
{
  "comboName": "Mining Machine Loop",
  "recommendedManagers": ["almost every manager"],
  "strategySummary": "Utilize dedicated managers...",
  "detailedPlan": "- 0:00 assign X,Y,Z ...
- Rotate every few minutes ..."
}
```

Issues:

- Assigns **many managers to the same department simultaneously**  
  (e.g. several elevator and warehouse managers at once).
- No **shaft numbers** (e.g. “H4V0C on Shaft 10”).
- No understanding of **skill durations** (1m, 2m, 5m, 30s).
- Uses vague language (“maximize efficiency”, “rotate every few minutes”).

We need the prompt to explicitly forbid these behaviours.

---

## 5. Required Behaviour

### 5.1 High‑Level Output Contract

The AI must:

1. Select:
   - **1 elevator manager**
   - **1 warehouse manager**
   - **3–5 key mineshaft managers**
2. Assume a **burst window ≈ 5 minutes**.
3. Produce a precise **burst script** in Markdown:
   - Timestamps in `MM:SS` format.
   - Explicit department + shaft assignments.
4. Provide a short **strategy summary** and **combo name**.
5. Return valid JSON matching the existing schema.

### 5.2 JSON Schema (unchanged)

The code already enforces:

```json
{
  "comboName": "string",
  "recommendedManagers": ["string"],
  "strategySummary": "string",
  "estimatedMultiplier": number,
  "detailedPlan": "string"
}
```

Keep this, but ensure the prompt reinforces what each field should contain.

---

## 6. Prompt Specification (to update in `AIStrategyEngine.swift`)

### 6.1 System Prompt Text

Replace the current free‑form instructions with something equivalent to the following (pseudocode / text block):

```text
You are MineOps AI, an expert Idle Miner Tycoon strategist.

Design a **burst rotation** for this mine using ONLY the managers listed below.

HARD RULES:
- MINESHAFT managers: only in mine shafts (never elevator/warehouse)
- ELEVATOR managers: only in elevator
- WAREHOUSE managers: only in warehouse
- There is **1 elevator slot**, **1 warehouse slot**, and multiple mine shafts.
- Do NOT assign more than **1 manager per department at the same time**.
- Only use manager NAMES that appear in "Available Managers".

If a manager has unknown department (e.g. Jeff, Sojo) and you are not sure, **exclude them**.

Your job:
1. Pick **one elevator manager**, **one warehouse manager**, and **3–5 mineshaft managers** that form a strong combo for the given mine.
2. Assume a burst window of about **5 minutes**.
3. Produce a **precise rotation** with timestamps like 0:00, 0:10, 1:30 based on typical skill durations:
   - Long skills (~5m): fire at the start of the burst.
   - Medium (1–2m): layer after the long skills.
   - Short (30s): use as a finisher when income is already high.

The plan MUST include:
- Exact **positioning**: which manager in Elevator, Warehouse, and which **shaft numbers** for each mineshaft manager (deepest, most valuable shafts get the strongest boosters).
- A **burst script**: step-by-step bullet points with timestamps in `MM:SS` format.
- Short **rationale**: why these managers and why this order.
- A rough **estimatedMultiplier** (overall cash gain during a well-executed burst).

Forbidden:
- Vague phrases like "rotate every few minutes" or "maximize efficiency".
- Assigning multiple managers to the same department at the same time.
- Suggesting managers that are not in the Available list.

Return JSON:
{
  "comboName": "creative strategy name",
  "recommendedManagers": ["names you actually use in the plan"],
  "strategySummary": "1–2 sentence summary of the burst loop",
  "estimatedMultiplier": number,
  "detailedPlan": "Markdown bullets with timestamps and shaft assignments (<= 800 chars)"
}
```

### 6.2 Dynamic Context

The runtime code must continue to interpolate:

- **Mine description** (e.g. “Mainland Mine 1 (Prestige 5, Max Shaft 30)”).
- **Available Managers** with department mapping, e.g.:  
  `Al Titude (Warehouse), H4V0C (Mineshaft), Damian Jones (Elevator)...`
- **Unknown managers warning**, e.g.:  
  `WARNING: The following managers have unknown departments: Jeff, Sojo`.

The AI should either:
- Recognize and assign them correctly **OR**
- Exclude them if not sure.

We’re okay leaving this as a soft instruction; the directory JSON will eventually be updated to remove “Unknown” cases.

---

## 7. Implementation Notes (VS Code / Copilot)

1. **Locate the existing prompt**  
   - File: `MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/Strategy/AIStrategyEngine.swift`
   - Find the constant/variable that builds the system prompt string.

2. **Replace the text body** with the new prompt spec above, keeping the same string interpolation for:
   - Mine name
   - Available managers
   - Unknown managers list

3. **Do NOT change**:
   - The JSON schema passed as `response_format` / `json_schema`.
   - The `StrategyResponse` model fields.

4. **Optional Improvement**  
   - Add a quick validation step after decoding:
     - Ensure `recommendedManagers` is a subset of `Available Managers`.
     - Log a warning if more than, say, **8 managers** are included or if multiple are from the same department.

---

## 8. Acceptance Criteria

A strategy run against your current roster should:

1. Recommend **1 elevator, 1 warehouse, 3–5 mineshaft** managers, **not the whole roster**.
2. Produce a `detailedPlan` that:
   - Uses **bullet points**.
   - Includes **timestamps** like `0:00`, `1:30`, `4:45`.
   - Mentions **shaft numbers** (e.g. “H4V0C → Shaft 10, Thalia → Shaft 9”).  
3. Never assigns multiple managers to the same department at the same time.
4. Never mentions managers that are *not* in the `Available Managers` list.
5. Remains under ~800 characters so it fits nicely in the MineOps UI.

If these conditions are met on a few sample mines (e.g. Mainland 1, Frontier 3) with your live roster, the change is successful.

---

## 9. Future Extensions (Nice‑to‑Have)

- Per‑manager metadata in the directory (burst duration, passive type) so the prompt can reference real numbers instead of “typical” durations.
- Special handling for **cost‑reduction waves** vs **income waves** and AFK vs active play.
- Difficulty‑aware strategies (early Mainland vs late Frontier behaviour).

