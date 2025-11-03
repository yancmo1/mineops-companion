# 🗺️ MineOps Companion – Development Roadmap
**Purpose:**  
This roadmap provides milestone-based guidance for the MineOps Companion iOS app.  
Each milestone corresponds to a focused sprint with explicit deliverables, verification criteria, and follow-up tasks.  
All development must adhere to the scope defined in [`PRD-MineOps-Companion.md`](./PRD-MineOps-Companion.md).

---

## 🧭 Current Phase
**Phase 1 – OCR + SwiftData Foundation**  
Status: *In Progress*  
Goal: Deliver a working intake → review → save pipeline that persists Super Manager data locally.

---

## 📆 Milestone Breakdown

### **Phase 1 – OCR + SwiftData MVP**
**Sprint Duration:** 1 week  
**Objective:** Ship a functioning OCR intake flow backed by SwiftData persistence.  

**Deliverables**
- Define SwiftData `@Model`s (`SuperManager`, `ParsedImage`) and align schema with OCR parser output.  
- Inject `ModelContainer` from the app target into package entry points (runtime + previews).  
- Implement `OCRService` and parsing heuristics for name, role, rarity, active/passive text, durations, and cooldowns.  
- Build intake → review → save UI that writes parsed results to SwiftData and links source images.  
- Provide optional seed importer (JSON) to pre-populate baseline Super Managers.  
- Add/extend unit tests covering parser normalization and SwiftData CRUD helpers.  

**Verification**
- ✅ App builds and runs in simulator with SwiftData container initialized.  
- ✅ At least one sample screenshot flows through OCR → review → save and persists on relaunch.  
- ✅ Saved managers appear in list/detail views with editable fields.  

**Next Phase Gate:** Intake pipeline is stable, persistence works end-to-end, and minimal browsing UI is available.

---

### **Phase 2 – Strategy Insights Enablement**
**Sprint Duration:** 2 weeks  
**Objective:** Layer strategy logic and historical insights on top of the SwiftData foundation.  

**Deliverables**
- Implement strategy ranking engine that consumes persisted `SuperManager` records.  
- Store generated recommendations alongside managers for historical tracking.  
- Add `SummaryHistoryView` (timeline of strategy runs with timestamps).  
- Expand automated tests for strategy scoring and history persistence.  

**Verification**
- ✅ Strategy engine produces deterministic top recommendations for seeded data.  
- ✅ History view lists prior strategy runs and opens corresponding details.  
- ✅ Strategy summaries reflect edits stored in SwiftData.  

**Next Phase Gate:** Strategy output is persisted and browsable with meaningful historical context.

---

### **Phase 3 – UX & AI Enhancements**
**Sprint Duration:** 2–3 weeks  
**Objective:** Polish the experience and introduce optional AI insights.  

**Deliverables**
- Add Settings screen with directory refresh + seed management controls.  
- Integrate optional GPT-5 API for “AI Strategy Advisor.”  
- Apply UI style guide across dashboard screens (Command Center, Pocket Assistant, etc.).  
- Add dark-mode polish, custom icon set, loading/error states, and analytics hooks.  
- Continue OCR accuracy improvements (regex refinement, Vision tuning).  

**Verification**
- ✅ Settings flow manages seeds/directory refresh without data loss.  
- ✅ AI Advisor generates context-aware recommendations when enabled.  
- ✅ All primary screens respect the shared theme and pass UI smoke tests.  

**Next Phase Gate:** User-ready app with cohesive UX and optional AI assistance.

---

### **Phase 4 – Extended Features (Stretch Goals)**
**Sprint Duration:** Open  
**Objective:** Future enhancements once core app is stable.  

**Ideas**
- Android port (Kotlin + ML Kit).  
- Clan data compare / team sync.  
- Event Mine mode support.  
- Graphical progress dashboards.  
- Offline backups to iCloud Drive.  

---

## 📈 Development Flow
| Step | Branch | Description |
|------|---------|-------------|
| 1 | `feature/<name>` | Each feature/fix built on a dedicated branch. |
| 2 | PR Review | Reference the PRD section in the PR body. |
| 3 | Merge → main | After CI passes (build + unit tests). |
| 4 | Tag release | `v0.x.y` with summary of implemented milestones. |

---

## ⚙️ Testing Matrix
| Module | Test File | Target Metrics |
|---------|------------|----------------|
| OCR Parsing | `OCRFieldExtractionTests.swift` | ≥ 90 % accuracy on clear screenshots / fixtures. |
| Parser Utilities | `SMStatsParserTests.swift` (planned) | Duration & cooldown normalization correct for edge cases. |
| SwiftData Persistence | `DatabaseTests.swift` (planned) | Create/fetch/update/delete succeed; seeds import idempotent. |
| Strategy Engine (Phase 2) | `StrategyEngineTests.swift` (planned) | Correct top recommendations for sample data. |

---

## 🧠 Agent Guidelines
- Always reference the **PRD** before code generation.  
- One feature → one PR.  
- Use clear commit prefixes:  
  - `feat:` new feature  
  - `fix:` bug fix  
  - `refactor:` internal changes  
  - `test:` unit tests  
  - `docs:` README / PRD updates  
- Include “Implements Phase X – Task Y” in commit messages for traceability.  

---

## 🔖 Current Release Target
**v0.3.0 – Prototype Build (Q4 2025)**  
- Clean SwiftUI build with OCR + SwiftData persistence.  
- Strategy layer in progress.  
- Foundation for AI integration complete.  

---

## 🚀 Next Action for Agents
> Using this roadmap and the PRD, focus on completing Phase 1 deliverables: SwiftData models, OCR normalization, intake → review → save flow, and seed importer.  
> Once validated in simulator, branch into Phase 2 (e.g., `feature/strategy-engine`) to begin strategy-focused work.

---

*End of Roadmap v1.0 – October 2025*  
