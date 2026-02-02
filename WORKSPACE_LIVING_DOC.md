# WORKSPACE_LIVING_DOC (Repo Source of Truth)

This document is the **single source of truth** for how this repo works:
- Architecture and major components
- Local dev workflow
- Test/build commands
- Deployment notes
- Decisions and follow-ups (Session Log)

## Read first
- [AGENTS.md](AGENTS.md) (agent entrypoint)
- [.github/copilot-instructions.md](.github/copilot-instructions.md) (agent guardrails)

## Architecture

**MineOps Companion** is an iOS 18+ app built with Swift 6.1+ and SwiftUI using the Model-View (MV) pattern.

### Project Structure
- **MineOpsCompanion/** — Main app shell (minimal code)
- **MineOpsCompanionPackage/** — Swift Package containing all features (preferred location for new code)
  - `Sources/MineOpsCompanionFeature/` — All Swift code
  - `Tests/MineOpsCompanionFeatureTests/` — Swift Testing framework tests
- **Config/** — `.xcconfig` files for build configuration
- **Docs/** — PRDs, guides, roadmaps

### Key Components
- **OCR Engine** — Image text extraction and parsing for mining operations
- **AI Strategy System** — Strategic recommendations for mining optimization
- **Export System** — Data export to CSV/Excel
- **Theme System** — Consistent UI styling

## Local Dev Workflow

### Prerequisites
- Xcode 16+ with iOS 18.4 SDK
- Swift 6.1+
- XcodeBuildMCP tools (preferred for automation)

### Building
Use XcodeBuildMCP tools or:
```bash
xcodebuild -workspace MineOpsCompanion.xcworkspace -scheme MineOpsCompanion
```

### Testing
Always test on **Yancy's Phone Sim** (UUID: D3B97618-A8E6-4594-9F2B-C80DA9A0650C):
- Use XcodeBuildMCP `test_sim_name_ws` tool
- Run tests from `MineOpsCompanionPackage/Tests/`

### Code Standards
- Swift Concurrency (async/await, actors, @MainActor) — no GCD
- SwiftUI native state management (@State, @Observable, @Environment, @Binding) — no ViewModels/MVVM
- Swift Testing framework (@Test, #expect, #require) — no XCTest
- All new features go in the Swift Package, not the app shell

## Session Log

Append short entries here when changes affect:
- schema / data model
- endpoints / auth / permissions
- workflow / automation
- anything that could surprise future contributors

---

### 2026-02-01: Atlas Bootstrap
- Initialized Atlas + subagents workflow
- Created AGENTS.md, WORKSPACE_LIVING_DOC.md, docs/agents/ with standard roles
- Backed up existing .github/copilot-instructions.md

### 2026-02-01: Swift Compilation Fixes
- Fixed orphaned static functions in SMCardPillExtractor.swift (buildMappingV2, typedValue)
- Resolved type naming conflicts between internal and external V2 model types
- Added Sendable conformance to RecognizedSM.StatUnit and StatState enums
- All tests passing on iOS Simulator 26.0.1

### 2026-02-01: Fixed "Clear All Data" in Settings
- Added `reload()` method to OCRReviewViewModel to refresh from persistence
- Fixed MineOpsSettingsView clear button to properly wrap async call in Task
- Clear All Data now correctly removes all managers, snapshots, hashes, and strategy cache
- UI properly reflects cleared state after operation completes

