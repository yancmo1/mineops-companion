# 🧾 MineOps Companion – Changelog

All notable changes to **MineOps Companion** will be documented in this file.  
The format follows **[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)**  
and is versioned according to **Semantic Versioning (SemVer)**.

Each entry includes:
- 🧩 **Features / Enhancements**
- 🐞 **Fixes / Refactors**
- 🧪 **Tests / Docs**
- 🔖 **Phase Reference** (from [ROADMAP.md](./ROADMAP.md))
- 🔗 **PR Reference** if available

---

## [Unreleased]
> Ongoing development on `main`.

### Added
- Placeholder section for upcoming commits during active milestone.

### Fixed
- TBD

---

## [v0.3.0] – *Prototype Build* – October 2025
> **Phase 1 – Core Foundation**

### 🧩 Features
- SwiftUI app scaffold generated per [`PRD-MineOps-Companion.md`](./PRD-MineOps-Companion.md).  
- OCR module with VisionKit recognition and parsing.  
- Strategy Engine for top-SM recommendations and upgrade priority logic.  
- Initial UI flow: Dashboard → Import → Review → Summary.

### 🐞 Fixes
- Added `import UIKit` to all files referencing `UIImage`.  
- Corrected level-digit parsing to isolate digits after “Level”.  
- Replaced placeholder `UIImage()` with real imported image reference.

### 🧪 Tests
- Created `OCRTests.swift` and `StrategyEngineTests.swift`.  
- Verified compilation on Xcode 17 simulator (iOS 17 target).

### 🔗 References
- PRs: `#1` – Initial Scaffold, `#2` – OCR Review Fixes  
- PRD §6 Tasks 1–3

---

## [v0.4.0] – *Persistence + Export* – Planned Q4 2025
> **Phase 2 – Data Persistence + Export**

### Planned
- Core Data snapshot storage (`Persistence.swift` + `.xcdatamodeld`).  
- `SummaryHistoryView` listing prior strategy runs.  
- Markdown export + Share Sheet integration (`ExportManager`).  
- Corresponding unit tests for save/load/export.

---

## [v0.5.0] – *UX & AI Advisor* – Planned Q1 2026
> **Phase 3 – UX Enhancement + AI Advisor**

### Planned
- Settings screen + Directory refresh.  
- GPT-5-based AI Strategy Advisor.  
- Dark Mode theme + icon assets.  
- OCR accuracy refinements.

---

## [v0.6.0 +] – *Stretch Features* – Future
> **Phase 4 – Extended Goals**

### Potential
- Android port (Kotlin + ML Kit).  
- Clan data compare / sync.  
- Event Mine support + visual dashboards.  
- iCloud Drive backup integration.

---

## 🧭 Versioning Rules
| Type | Semantic Effect | Example |
|------|-----------------|----------|
| `feat:` | Minor version bump | v0.3.0 → v0.4.0 |
| `fix:` | Patch version bump | v0.3.0 → v0.3.1 |
| `docs:` `test:` `refactor:` | No version bump unless feature-impacting | v0.3.0 unchanged |

---

## 🧠 Agent Notes
When generating or merging PRs, include in the PR description:
```
Implements Phase X – Task Y per PRD §6.Y
Affects: [module]
Type: [feat|fix|refactor|docs|test]
Version impact: [minor|patch|none]
```
This ensures automated changelog updates remain accurate.

---

*End of Changelog v1.0 – October 2025*
