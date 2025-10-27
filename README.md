# 🧭 MineOps Companion – Build & Compile Guide

## 1. Project Summary
**MineOps Companion** is a private iOS SwiftUI app designed to analyze *Idle Miner Tycoon* Super Managers.  
It uses VisionKit OCR to extract data from screenshots, matches them to a static SM directory, generates optimized strategies, and exports reports as text or Markdown.

---

## 2. Module Overview
| Module | Description |
|---------|-------------|
| **App/** | Entry point, navigation, and global app lifecycle. |
| **Models/** | Data models (`SuperManager`, `OCRResult`, etc.) for storing structured SM data. |
| **OCR/** | Handles VisionKit text recognition, multi-image import, and parsing logic. |
| **Strategy/** | Core logic that ranks managers, builds active team suggestions, and generates upgrade priorities. |
| **Export/** | Exports strategy summaries as Markdown or plain text via iOS Share Sheet. |
| **Data/** | Stores `sm_directory.json` (static SM reference) and persistent CoreData snapshots. |
| **Resources/** | Assets, app icons, and localizations. |
| **Tests/** | Unit tests for OCR parsing and strategy generation logic. |

---

## 3. Build Requirements
- **Xcode:** 15.0 or later  
- **iOS Deployment Target:** iOS 16.0+  
- **Swift Version:** 5.9  
- **Frameworks Used:**
  - VisionKit (OCR)
  - SwiftUI
  - CoreData
  - UIKit (ShareSheet integration)

---

## 4. Running the App
1. Clone the repo:
   ```bash
   git clone https://github.com/yancmo1/mineops-companion.git
   cd mineops-companion
   ```
2. Open in Xcode:
   ```bash
   open MineOpsCompanion.xcodeproj
   ```
3. Choose a simulator or device running iOS 16+.
4. Press **Run ▶️**.

---

## 5. How It Works
1. **Import Screenshots** → select multiple Idle Miner SM screenshots.  
2. **OCR Processing** → VisionKit detects text (name, level, boost).  
3. **Review Screen** → confirm parsed data and fix errors if needed.  
4. **Strategy Engine** → recommends top SMs and upgrade order.  
5. **Export Report** → share as Markdown (`MineOps_StrategyReport_YYYYMMDD.md`).  
6. **Snapshot History** → stores your progress over time.

---

## 6. Future Enhancements
- [ ] Dark mode & custom theme options  
- [ ] Enhanced synergy analysis  
- [ ] AI-based “combo advisor” (GPT-5 API integration)  
- [ ] Downloadable SM directory updates  
- [ ] Optional Android companion port  

---

## 7. Project Status
✅ OCR Review  
✅ Strategy Engine  
✅ Export Manager  
✅ CoreData Snapshots  
🟡 AI Integration (planned)  
🟡 UI Polish in progress  

---

## 8. Credits
- Concept & Design: **Yancy Shepherd**  
- Build Assistant: **GitHub Copilot + GPT-5 Agent**  
- Data Source: [Idle Miner Tycoon Fandom Wiki](https://idleminertycoon.fandom.com/wiki/Super_Manager)

---

**Repo:** [github.com/yancmo1/mineops-companion](https://github.com/yancmo1/mineops-companion)  
**Version:** 0.3.0 – Initial Functional Prototype  
**License:** MIT  