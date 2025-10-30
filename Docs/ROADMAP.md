# 🗺️ MineOps Companion – Development Roadmap
**Purpose:**  
This roadmap provides milestone-based guidance for the MineOps Companion iOS app.  
Each milestone corresponds to a focused sprint with explicit deliverables, verification criteria, and follow-up tasks.  
All development must adhere to the scope defined in [`PRD-MineOps-Companion.md`](./PRD-MineOps-Companion.md).

---

## 🧭 Current Phase
**Phase 1 – Foundation & Build Fixes**  
Status: *In Progress*  
Goal: Establish a compiling SwiftUI app with OCR and strategy logic functioning locally.

---

## 📆 Milestone Breakdown

### **Phase 1 – Core Foundation (Build → Run)**
**Sprint Duration:** 1 week  
**Objective:** Achieve a clean compile in Xcode and a working prototype UI.  

**Deliverables**
- Add `import UIKit` to all files referencing `UIImage`.  
- Correct OCR level parsing logic (`parseText(_:)`).  
- Assign actual screenshot image in `OCRResult`.  
- Scaffold `.xcodeproj` with proper targets and bundle settings.  
- Comment-out Core Data references until model exists.  
- Verify successful simulator build (iOS 17+).  

**Verification**
- ✅ No compile-time errors in Xcode.  
- ✅ OCRReviewView displays recognized data correctly.  
- ✅ “Generate Report” produces sample strategy output.  

**Next Phase Gate:** “MineOps Companion” launches in simulator and displays all navigation routes.

---

### **Phase 2 – Data Persistence + Export**
**Sprint Duration:** 2 weeks  
**Objective:** Enable saving, recalling, and sharing of strategy data.  

**Deliverables**
- Implement Core Data or SQLite persistence layer (`Persistence.swift` + `.xcdatamodeld`).  
- Store OCR results and strategy summaries as “Snapshots.”  
- Add `SummaryHistoryView` (timeline of previous runs).  
- Implement `ExportManager` → Markdown/Text → iOS Share Sheet.  
- Write unit tests for save/load/export functions.  

**Verification**
- ✅ “Save Snapshot” stores visible strategy report.  
- ✅ History view lists all prior reports with date/time.  
- ✅ Shared Markdown opens correctly in iOS Notes or Discord.  

**Next Phase Gate:** Data persists between app launches and can be exported.

---

### **Phase 3 – UX Enhancement + AI Advisor**
**Sprint Duration:** 2–3 weeks  
**Objective:** Deliver polished experience and optional AI insights.  

**Deliverables**
- Add Settings screen with “Refresh SM Directory” option.  
- Implement directory JSON fetch/update workflow.  
- Integrate optional GPT-5 API for “AI Strategy Advisor.”  
- Add Dark Mode theme and custom icon set.  
- Implement error handling & loading indicators.  
- Improve OCR accuracy (regex refinement, font normalization).  

**Verification**
- ✅ User can toggle “AI Advisor” in Settings.  
- ✅ AI Advisor generates context-aware recommendations.  
- ✅ Visual polish meets iOS design standards.  

**Next Phase Gate:** User-ready app with optional AI assistance.

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
| OCR Parsing | `OCRTests.swift` | 95 % accuracy for standard fonts. |
| Strategy Engine | `StrategyEngineTests.swift` | Correct top-3 recommendations for sample data. |
| Persistence | `PersistenceTests.swift` | Data saves / loads without crash. |
| Export | `ExportTests.swift` | File created and share sheet invoked. |

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
- Clean SwiftUI build with OCR + Strategy.  
- Export & persistence pending.  
- Foundation for AI integration complete.

---

## 🚀 Next Action for Agents
> Using this roadmap and the PRD, continue implementing Phase 1 fixes until build passes in Xcode.  
> Once validated, open branch `feature/persistence-export` to begin Phase 2.

---

*End of Roadmap v1.0 – October 2025*  