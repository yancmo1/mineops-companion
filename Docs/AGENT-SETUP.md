# 🤖 MineOps Companion – Agent Setup & Operating Guide

**Purpose:**  
Define how autonomous or semi-autonomous agents (GPT-5 Codex, Copilot Agent, etc.) interact with the MineOps Companion repository.  
This ensures consistent alignment with [`PRD-MineOps-Companion.md`](./PRD-MineOps-Companion.md) and [`ROADMAP.md`](./ROADMAP.md) across all generated code, documentation, and reviews.

---

## 1. Initialization Workflow

### 1.1 When the Agent Starts

1. Load both `PRD-MineOps-Companion.md` and `ROADMAP.md` into working memory.  
2. Read repository structure to confirm presence of `/App`, `/OCR`, `/Strategy`, `/Export`, `/Models`, `/Data`, `/Resources`, `/Tests`.  
3. Summarize active milestone from `ROADMAP.md` (default: *Phase 1 – Core Foundation*).  
4. Identify open PRs or branches under development.  
5. Acknowledge Yancy Shepherd as product owner for all final approvals.

### 1.2 Active Context String (recommended)
>
> Current Project: MineOps Companion (SwiftUI iOS)  
> Reference Docs: PRD-MineOps-Companion.md + ROADMAP.md  
> Current Phase: [insert phase from roadmap]  
> Branch Pattern: feature/<short-description>  
> Output Format: complete, compilable Swift code or Markdown file only  

---

## 2. Agent Behavior Rules

| Rule | Description |
|------|--------------|
| **R1 – PRD Authority** | All decisions must follow the PRD as source of truth. Do not invent new features unless added to the roadmap. |
| **R2 – One Task = One PR** | Every new feature or fix is scoped to a single pull request. |
| **R3 – Branch Naming** | Use `feature/<short-name>` (e.g., `feature/ocr-parser-fix`). |
| **R4 – Commit Messages** | Prefix commits with type: `feat:`, `fix:`, `refactor:`, `docs:`, `test:` … |
| **R5 – Context Retention** | Persist PRD + Roadmap summary for duration of editing session; reload on restart. |
| **R6 – File Integrity** | Always validate Swift syntax before committing. Never push empty commits. |
| **R7 – Testing Before Merge** | Run or stub unit tests in `/Tests` prior to merge. |
| **R8 – Traceability** | Mention PRD section and phase in PR body, e.g., “Implements Phase 1 – Task 2 (Section 6.2 PRD).” |
| **R9 – Documentation** | Update README or PRD only through dedicated `docs/` PRs. |
| **R10 – Respect Manual Overrides** | If Yancy edits code manually, treat that version as authoritative. |

---

## 3. Agent Prompts & Examples

### 3.1 Start of Session
```
Load PRD-MineOps-Companion.md and ROADMAP.md.
Summarize current phase and pending tasks.
Confirm which modules need work for the active milestone.
```

### 3.2 Feature Creation
```
According to the PRD (Section 6, Task 2), implement the corrected parseText(_:) logic in OCRProcessor.swift.
Create branch feature/ocr-parser-fix, commit with message "fix: correct level parsing logic per PRD §6.2".
Open a pull request targeting main.
```

### 3.3 Review or Debug
```
Analyze current compile errors.
Compare against PRD expected architecture.
Suggest corrections that restore build without feature drift.
```

### 3.4 Documentation Update
```
Add bullet summaries of new functionality to README-DEV-SETUP.md.
Tag commit as docs:update-readme.
```

---

## 4. Branch & Merge Lifecycle

1. `feature/<task>` → commit(s)  
2. Open PR → auto-assign reviewers (if configured).  
3. On approval → merge to `main`.  
4. Post-merge → run `swift build` or open Xcode → verify success.  
5. Update `ROADMAP.md` checklist if milestone completed.  

---

## 5. Phase Recognition Logic
Agents must read “Current Phase” header in `ROADMAP.md`.  
When “Next Phase Gate” criteria are met, propose phase promotion via PR titled:  
> `docs: advance roadmap to Phase X+1`

---

## 6. Agent Output Guidelines
- Use **complete file rewrites** rather than partial fragments for Swift code.  
- Include **file headers** with module name, author, and purpose.  
- Prefer **SwiftUI 2.0+ conventions** (NavigationStack, PhotosPicker, etc.).  
- Keep **imports minimal** (`SwiftUI`, `VisionKit`, `UIKit` when needed).  
- Comment functions clearly for human dev reference.

---

## 7. Testing Expectations
Each commit that affects logic should trigger or update a matching test in `/Tests`.  
Example:
- `OCRProcessor.swift` → `OCRTests.swift`  
- `StrategyEngine.swift` → `StrategyEngineTests.swift`

Tests may stub data but must compile.

---

## 8. Communication & Autonomy Boundaries
- Agents may propose optimizations, but **must not** change app purpose, name, or privacy model.  
- Any cross-platform suggestions (Android, web) must be logged under “Future Expansion” section in PRD, not implemented directly.  
- If ambiguity exists, pause and request clarification via comment:  
  > “Ambiguity detected in PRD §X.Y; please confirm before proceeding.”

---

## 9. Quality Bar
- 0 compiler errors in Xcode 17 simulator build.  
- 100 % functional navigation path: Dashboard → Import → Review → Summary → Export.  
- Code passes SwiftLint checks if enabled.  
- Documentation up-to-date with merged features.

---

## 10. Onboarding Summary (for new agents)
1. Read this file entirely.  
2. Load PRD + Roadmap context.  
3. Verify branch naming and current phase.  
4. Execute pending tasks sequentially.  
5. Maintain changelog integrity and tag releases.

---

**Maintainer:** Yancy Shepherd  
**Primary Agents:** GPT-5 Codex, GitHub Copilot Agent  
**Project Repo:** [yancmo1/mineops-companion](https://github.com/yancmo1/mineops-companion)  
**Version:** v1.0 – October 2025  

---

*End of Agent Setup Guide – Always reference this document at session start.*