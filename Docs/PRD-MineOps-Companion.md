# 🧭 MineOps Companion – Product Requirements Document (PRD)
**Document Purpose:**  
Define the full technical and functional scope of *MineOps Companion*, a private iOS SwiftUI app that extracts, analyzes, and manages **Idle Miner Tycoon Super Manager (SM)** data via on-device OCR and strategy logic.  
This PRD is written for autonomous agent collaboration (GitHub Copilot, GPT-5 Codex, etc.) to ensure all generated code aligns with user goals.

---

## 1. Vision & Context
Idle Miner Tycoon players manually manage “Super Managers” across mines, transports, and warehouses.  
The game provides no API or export mechanism, so data must be captured visually.  
**MineOps Companion** solves this by:
- Importing screenshots from iOS Photos.
- Running OCR (VisionKit) to extract text (SM name, level, boost).
- Matching parsed results to a **local SM directory** (JSON).
- Generating strategy recommendations.
- Exporting results as text or Markdown.

The project is **private / non-App-Store**, optimized for personal use and future expansion.

---

## 2. Core Goals

| Goal | Description |
|------|--------------|
| 📸 OCR Recognition | Accurately parse Super Manager details from screenshots using VisionKit. |
| 🧠 Local Strategy Engine | Rank and recommend the best active SM combos and upgrade priorities. |
| 📂 Local Data | Maintain an editable SM directory and user progress snapshots (offline). |
| 📤 Export | Generate and share strategy summaries as text/Markdown. |
| 🧩 Modular Design | Each module (OCR, Strategy, Export, Persistence) self-contained and testable. |
| 🔒 Privacy | All data processed locally, no network calls except optional updates. |

---

## 3. System Overview

### App Architecture
SwiftUI single-target iOS app with modular folder layout:

```
MineOpsCompanion/
 ├─ App/                # App lifecycle + navigation
 ├─ Models/             # Data structures (SM, OCRResult)
 ├─ OCR/                # VisionKit recognition + parsing
 ├─ Strategy/           # SM ranking and team logic
 ├─ Export/             # Markdown/text export and share
 ├─ Data/               # Static JSON and persistence
 ├─ Resources/          # Assets, icons, launch screen
 └─ Tests/              # Unit tests per module
```

### Major Components

#### 3.1 OCR Module
- **Framework:** VisionKit / Vision  
- **Input:** UIImage(s) imported from PhotosPicker  
- **Process:**  
  1. Detect text (SM name, “Level #”, “+###% Type”).  
  2. Parse to `OCRResult` model.  
  3. Present in a review/edit UI.  
- **Output:** `[OCRResult]` stored locally.

#### 3.2 Strategy Engine
- **Input:** `[OCRResult]`  
- **Logic:**  
  - Sort by boost type & value.  
  - Recommend top “active team” (Mine / Transport / Warehouse).  
  - Suggest upgrade priorities and synergy tips.  
- **Output:** Formatted Markdown string.  

<!-- #### 3.3 Export Manager
- Generate shareable `.md` or `.txt` reports.
- Include timestamp (`MineOps_StrategyReport_YYYYMMDD.md`).
- Share via iOS ShareSheet. -->

#### 3.4 Persistence (Phase 2)
- Initial milestone: in-memory data only.  
- Later: Core Data or SQLite snapshot storage (progress history).  

#### 3.5 SM Directory
- JSON reference (`sm_directory.json`) with canonical SM stats.  
- Supports local refresh or manual edit.

---

## 4. Technical Requirements

| Category | Requirement |
|-----------|--------------|
| **Language** | Swift 5.9 + |
| **UI Framework** | SwiftUI |
| **Min iOS** | 16.0 |
| **OCR** | VisionKit / Vision |
| **Storage** | Core Data (stubbed for now) |
| **Export** | UIKit ShareSheet |
| **Testing** | XCTest for OCR & Strategy |
| **IDE** | Xcode 15 + |
| **Version Control** | GitHub (main + feature branches) |

---

## 5. Current State (as of initial scaffold)
✅ Folder structure complete  
✅ Core Swift files drafted  
⚠️ Missing `.xcodeproj` (to be scaffolded next)  
⚠️ `UIImage` imports require `UIKit`  
⚠️ Core Data model placeholder (`Persistence.swift` currently unused)  
⚠️ Minor OCR parsing bug (merges digits from level & boost)

---

## 6. Immediate Tasks (Phase 1 Fix & Scaffold)

| Priority | Task | Owner | Notes |
|-----------|------|--------|-------|
| 🟥 1 | Add `import UIKit` to all Swift files referencing `UIImage`. | Agent | Fix compile errors. |
| 🟥 2 | Correct `parseText(_:)` logic → capture digits only after “Level”. | Agent | Prevent “Level 10 +650%” → 10650 merge. |
| 🟧 3 | Assign actual image in `OCRResult` instead of placeholder. | Agent | Enables UI previews. |
| 🟧 4 | Scaffold `.xcodeproj` for SwiftUI iOS 17+. | Agent | Generate app target + test target. |
| 🟨 5 | Remove / comment out Core Data references. | Agent | Defer until data model defined. |
| 🟩 6 | Re-run unit tests & verify successful build in Xcode. | User | Confirm via simulator. |

---

## 7. Future Milestones (Phase 2 + 3)

### Phase 2 – Data & Export
- Implement Core Data snapshot storage.  
- Build `SummaryHistoryView` (timeline of strategy runs).  
- Finalize `ExportManager` with Markdown and share logic.  

### Phase 3 – UX & AI
- Add Settings > DirectoryView with refresh option.  
- Integrate optional GPT-5 API for “AI strategy advisor.”  
- Add dark mode, custom themes, and icon set.  

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
2. Passes unit tests.  
3. UI matches expected flow (Import → Review → Summary → Export).  
4. No hard-coded file paths or external API calls.  

---

## 9. Success Metrics
- **Build success:** 0 compile-time errors in Xcode 17.  
- **OCR accuracy:** ≥ 90 % recognition on clear screenshots.  
- **UI flow:** All screens reachable without crash.  
- **Performance:** < 3 s OCR for batch of 5 images on iPhone 14 Pro.  
- **Export:** Markdown opens cleanly in Notes / Discord.  

---

## 10. Future Expansion Ideas
- Android version (Kotlin + ML Kit OCR).  
- Clan data sharing / merge compare.  
- Event mine mode support.  
- Progress visualizations and leaderboards.

---

## 11. Ownership
- **Product Owner / Vision:** Yancy Shepherd  
- **AI Implementation Agents:** GPT-5 Codex + GitHub Copilot Agent  
- **Repository:** [yancmo1/mineops-companion](https://github.com/yancmo1/mineops-companion)  
- **License:** MIT (private prototype)  

---

## 12. Current Directive to Agents
> Using this PRD as reference, ensure the repository compiles into a functioning SwiftUI iOS app.  
> Implement the fixes in Section 6, scaffold the Xcode project, and prepare the codebase for Phase 2 (data persistence & export).  
> All generated commits must include references to the relevant PRD sections for traceability.

---

*End of PRD – version 1.0 – October 2025*  
*(Save this in repo root as `PRD-MineOps-Companion.md`)*  