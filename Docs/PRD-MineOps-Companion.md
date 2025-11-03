# 🧭 MineOps Companion – Product Requirements Document (PRD)
**Document Purpose:**  
Define the full technical and functional scope of *MineOps Companion*, a private iOS SwiftUI app that ingests Idle Miner Tycoon **Super Manager (SM)** screenshots, extracts structured data via on-device OCR, and stores normalized results in a local database for review.  
This PRD is written for autonomous agent collaboration (GitHub Copilot, GPT-5 Codex, etc.) to ensure all generated code aligns with user goals and the current implementation plan.

---

## 1. Vision & Context
Idle Miner Tycoon players manually manage “Super Managers” across mines, transports, and warehouses.  
The game provides no API or export mechanism, so data must be captured visually.  
**MineOps Companion** solves this by:
- Importing screenshots from iOS Photos.
- Running OCR (Vision) to extract SM details.
- Normalizing parsed data into SwiftData models.
- Letting the user review, correct, and persist entries locally.
- Surfacing saved SMs in lightweight browsing tools.

The project is **private / non-App-Store**, optimized for personal use and future expansion (strategy automation, exports, AI advisor) after the OCR + database foundation ships.

---

## 2. Core Goals

| Goal | Description |
|------|--------------|
| 📸 OCR Recognition | Accurately parse Super Manager details from screenshots using Vision. |
| 🗃️ Local SM Database | Store normalized SM records in SwiftData for offline review. |
| 📝 Review UI | Provide an editable confirmation screen before saving parsed data. |
| 🔍 SM Browser | Offer a minimal list/detail view to inspect and update saved managers. |
| 🧩 Modular Design | Keep OCR, parsing, persistence, and UI components isolated inside the package. |
| 🔒 Privacy | All data processed locally; no external network calls required for MVP. |

> Future expansions (strategy engine, exports, AI advisor) remain in the roadmap but are out of scope for the MVP tracked in this PRD revision.

---

## 3. System Overview

### Architecture Overview
The repository uses an Xcode workspace with a SwiftUI app target (`MineOpsCompanion`) that hosts a Swift Package (`MineOpsCompanionPackage`). Feature code—including OCR, parsing, persistence, and UI—lives inside the package for modular development.

```
MineOpsCompanion.xcworkspace
 ├─ MineOpsCompanion/                  # App shell (launch, DI, Info.plist)
 └─ MineOpsCompanionPackage/           # Swift package containing feature modules
     └─ Sources/MineOpsCompanionFeature
         ├─ App/                       # SwiftUI views, UI components
         ├─ OCR/                       # Vision integration + parsing
         ├─ DB/                        # SwiftData models & helpers
         ├─ Parsing/                   # Normalizers & heuristics
         └─ Resources/                 # Seeds, assets
```

### Major Components (MVP)

#### 3.1 OCR Pipeline
- **Framework:** Vision  
- **Input:** `PhotosPicker` images supplied by the app shell  
- **Process:**  
  1. Detect text in SM screenshots.  
  2. Normalize raw OCR text via parsing heuristics.  
  3. Produce a `ParsedSM` struct for the review UI.
- **Output:** Parsed text plus metadata for persistence.

#### 3.2 SwiftData Persistence
- **Models:** `SuperManager`, `ParsedImage` (SwiftData `@Model`).  
- **Container:** App injects a `ModelContainer` and passes it to package views.  
- **Storage:** On-device, no external services required.

#### 3.3 Review & Browser UI
- **Intake Flow:** Select screenshots → run OCR → parse → review → save.  
- **List / Detail:** Browse saved managers, edit fields, view timestamps.

#### 3.4 Strategy Extensions (Future Phases)
- Strategy ranking and optional AI advisor remain roadmap items and are not part of the MVP tracked here.

---

## 4. Technical Requirements

| Category | Requirement |
|-----------|--------------|
| **Language** | Swift 5.9 + |
| **UI Framework** | SwiftUI |
| **Min iOS** | 16.0 |
| **OCR** | Vision |
| **Storage** | SwiftData (`@Model`, `ModelContainer`) |
| **Testing** | XCTest for OCR parsing + SwiftData helpers |
| **IDE** | Xcode 15 + (workspace with app + package) |
| **Version Control** | GitHub (main + feature branches) |

---

## 5. Current State (SwiftData MVP Initialization)
✅ Workspace + Swift package split established  
✅ Vision-based OCR scaffolding in progress  
✅ SwiftUI intake and command center views stubbed  
⚠️ SwiftData models and container wiring pending  
⚠️ OCR parser needs normalization for durations, passives, and role detection  
⚠️ Review UI does not yet persist or edit real data

---

## 6. Immediate Tasks (Phase 1 – OCR + SwiftData Foundation)

| Priority | Task | Owner | Notes |
|-----------|------|--------|-------|
| 🟥 1 | Finalize SwiftData `SuperManager` + `ParsedImage` models and migrations. | Agent | Align fields with MVP schema (name, role, rarity, active/passive text, durations). |
| 🟥 2 | Wire `ModelContainer` injection from app target into package entry view. | Agent | Maintain consistent container usage for app runtime and previews. |
| 🟥 3 | Implement `OCRService` + parser normalization for name, role, rarity, durations, cooldowns, and passive text. | Agent | Backed by unit tests in `OCRFieldExtractionTests`. |
| 🟧 4 | Build Intake → Review → Save flow that persists data to SwiftData and links parsed images. | Agent | Include “needs review” flag when critical fields missing. |
| 🟨 5 | Seed initial Super Manager entries via packaged JSON importer. | Agent | Import if DB empty; allow merge-by-name updates. |
| 🟦 6 | Smoke-test Vision OCR pipeline with sample screenshots. | User | Validate recognition quality and persistence behaviour. |

---

## 7. Future Milestones (Phase 2 + 3)

### Phase 2 – Strategy Insights Enablement
- Layer strategy ranking engine on top of the saved SwiftData records.  
- Build `SummaryHistoryView` (timeline of runs using persisted data).  
- Expand automated tests to cover strategy scoring and history persistence.

### Phase 3 – UX & AI Enhancements
- Add Settings > DirectoryView with refresh option.  
- Integrate optional GPT-5 API for “AI strategy advisor.”  
- Expand UI with themed dashboards per Style Guide PRDs.  
- Add dark mode polish, custom icons, and improved loading/error states.  

---

## 8. AI / Agent Collaboration Guidelines

### Design Principles
- **Single-source-of-truth:** All requirements originate from this PRD.  
- **Incremental branches:** Each major task → feature branch + PR.  
- **Self-documenting commits:** Use concise, descriptive messages.  
- **Avoid feature drift:** Stick to scope defined here.  
- **Prompt hygiene:** Each agent task starts with context: “According to PRD-MineOps-Companion.md, implement ___.”

### Definition of Done (per feature)
1. Compiles cleanly on Xcode 17 simulator.  
2. Passes unit tests (Vision parsing + SwiftData helpers).  
3. MVP UI matches expected flow (Import → Review → Save → Browse).  
4. No hard-coded file paths or external API calls.  

---

## 9. Success Metrics
- **Build success:** 0 compile-time errors in Xcode 17.  
- **OCR accuracy:** ≥ 90 % recognition on clear screenshots.  
- **SwiftData persistence:** Saved managers reappear on relaunch.  
- **UI flow:** Intake → Review → Browser path completes without crash.  
- **Performance:** < 3 s OCR for batch of 5 images on iPhone 14 Pro.  

---

## 10. Future Expansion Ideas
- Android version (Kotlin + ML Kit OCR).  
- Clan data sharing / merge compare.  
- Event mine mode support.  
- Progress visualizations and leaderboards.  
- Markdown/export tooling (removed from scope).

---

## 11. Ownership
- **Product Owner / Vision:** Yancy Shepherd  
- **AI Implementation Agents:** GPT-5 Codex + GitHub Copilot Agent  
- **Repository:** [yancmo1/mineops-companion](https://github.com/yancmo1/mineops-companion)  
- **License:** MIT (private prototype)  

---

## 12. Current Directive to Agents
> Using this PRD as reference, deliver the SwiftData-backed OCR pipeline: finalize models, complete intake → review → save flow, and expose a minimal browser UI. Strategy and AI features remain out of scope until Phase 2 begins.  
> All generated commits must include references to the relevant PRD sections for traceability.

---

*End of PRD – version 1.0 – October 2025*  
*(Save this in repo root as `PRD-MineOps-Companion.md`)*  
