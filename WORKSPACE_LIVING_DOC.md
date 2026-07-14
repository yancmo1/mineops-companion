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

### 2026-06-03: Added strict SM tracker JSON export format
- Added `SMTrackerExporter` to generate backup JSON in exact external schema (`unlocked`, `rank`, `level`, `promoted`, `fragments`, `chronoExcluded`, `tierlistExcluded`)
- Added Manager screen action: **Export SM Tracker Backup** (shares `sm-tracker-backup.json`)
- Export includes all known directory managers with deterministic defaults and overlays recognized manager progress where available
- Added `SMTrackerExporterTests` to validate schema strictness and key formatting (`snake_case` ids -> hyphenated keys)
- Risk/limitation: app does not yet track `fragments` or exclusion flags per manager, so these fields export as defaults until model support is added

### 2026-06-03: OCR improvements for stars + fragments
- Extended OCR extraction to parse stars from both star glyphs and rank-text fallback (`Rank N`)
- Added fragment piece extraction from OCR text (explicit `Fragments X/Y` and fallback `X/15` / `X/30` patterns)
- Added `fragments` to `RecognizedSM`, persistence storage, overrides, and Manager edit/debug UI
- Updated strict tracker export to emit OCR-derived `fragments` when available
- Added regression tests for stars fallback and fragment extraction in `OCRFieldExtractionTests`

### 2026-06-03: Dual-pass Vision OCR merge for numeric/symbol reliability
- Updated `OCRTextRecognizer` spatial lines to carry confidence values
- Added configurable language-correction toggle for spatial OCR calls
- Updated `OCRProcessor` to run two OCR passes (corrected + raw) and merge lines by position/quality
- Merge heuristic now prefers lines likely containing star/rank/fragment/progress tokens when confidence is competitive
- Goal: reduce numeric/symbol loss from language correction while retaining readable section labels

### 2026-06-03: Fragment parsing updated for rank/promotion-scaled thresholds
- Calibrated against sample OCR output where rank-up progress includes denominators beyond `15/30` (e.g. `50`, `80`, and potentially larger)
- Updated fragment parser to treat rank-up progress as dynamic `x/y` rather than fixed denominator sets
- Added filtering to avoid misreading `Level x/50` and `Promotion x/5` as fragment progress
- Added regression coverage in `OCRFieldExtractionTests` for `/50`, `/80`, and scaled-denominator rank-up patterns

### 2026-06-03: Added visual star-row fallback to prevent rank=0 exports when OCR misses star glyphs
- Added `SMCardStarDetector` (image-based detector) to count filled stars from the card star row using normalized slots + color thresholds
- Integrated fallback in `OCRProcessor`: `stars = OCRFieldExtraction.stars ?? SMCardStarDetector.detectStars(...)`
- This keeps export rank aligned with app rank when Vision OCR does not emit star symbols/text
- Added `SMCardStarDetectorTests` with screenshot fixtures validating 0-, 1-, and 2-star detection

### 2026-06-03: Hardened directory matching to avoid Dr. Nova -> Dr. Steiner misclassification
- Updated `DirectoryMatcher` token scoring to reject matches based only on weak honorific tokens (`dr`, `mr`, `sir`, etc.)
- Added OCR-confusion normalization for names in matcher (`0` -> `o` when letter-adjacent), improving resilience for lines like `N0va`
- Added regression tests in `DirectoryMatcherTests` to ensure `Dr Nova` / `Dr N0va` do not map to `dr_steiner`, while `Dr Steiner` still matches correctly
- Audited canonical export key set vs OCR directory ids and found a large gap (108 canonical keys vs 40 directory entries). Risk: missing directory entries can force fallback-name flows and increase ambiguous matching cases; follow-up is to expand/align directory coverage.

### 2026-06-03: Fixed "Clear All Data" not clearing screenshot import tracking
- Modified `AppDataResetter.clearAllUserData()` to call `ScreenshotsFetcher.shared.resetImportTracking()`
- Previously cleared managers, snapshots, image hashes, and strategy cache but **not** the processed screenshot IDs set
- This caused app to still recognize re-imported screenshots as duplicates even after clear-all, blocking re-import testing
- Now "Clear All Data" → "Import New" allows true fresh import of same screenshots for validation/testing after code changes

### 2026-06-03: Normalized Rabbid/Rabbit Blingsley cross-source key mismatch
- Added OCR alias handling so `Rabbit Blingsley` text variants map to directory entry `rabbid_blingsley`
- Directory ID `rabbid_blingsley` exports as `rabbid-blingsley` (correct canonical name)
- Added regression tests for both matcher and exporter behavior to prevent future drift between in-game naming and external tracker key schema
- Risk/mitigation: external tracker key naming may evolve; keep alias map explicit and small so future schema changes are easy to audit

### 2026-06-03: Fixed Mr/Mrs Goodman alias collision
- Removed standalone "Goodman" alias from Mrs. Goodman (was creating unintended bias)
- Added "Goodman Mrs" to Mrs. Goodman and "Goodman Mr" to Mr. Goodman for explicit variants
- Added DirectoryMatcher test to catch future alias collisions between similar-named entries
- Prevents OCR-only "Goodman" reads from always misclassifying as Mrs. Goodman

### 2026-06-03: Added fixture-backed export key universe contract test
- Added test fixture `Fixtures/sm_tracker_hub_keys.json` with expected external tracker key universe (108 keys)
- Added `SMTrackerExporterTests.exportKeyUniverseMatchesHubFixture()` to compare generated export payload keys against fixture keys
- This catches accidental key drift (missing/extra/renamed ids) independently of the exporter's in-code key list
- Added explicit assertions to require `rabbit-blingsley` and forbid `rabbid-blingsley` in exported key universe

### 2026-07-13: Kolibri personal sync hardcoded + manual-first debug flow
- Added hardcoded personal Kolibri defaults (player ID, auth token, save key) in `KolibriCredentialsStore` with optional user override support in Settings
- Reworked `KolibriAPIClient` save decoding to handle real Capsule payload format (`U58U` header → base64 decode → gzip inflate via zlib) and parse `Data.SuperManagers.Managers`
- Added sync diagnostics model + UI debug panel showing HTTP status, payload format, raw/decoded byte counts, parsed manager count, and payload hex prefix
- Updated sync flow to stay manual by default, with optional auto-sync behind an explicit disclosure/toggle
- On successful manual sync, the app now builds a recognized manager roster from synced data and replaces OCR roster so strategy screens can use synced managers directly
- Risks/mitigations: hardcoded credentials are intentionally temporary for personal use; clear action now removes local overrides and falls back to hardcoded defaults to avoid lockout
- Follow-up: replace hardcoded credential constants with a safer per-device secret path once personal testing phase is complete

### 2026-07-13: V2 app — idle-miners.com data + dual AI provider + sync progress merger
- Replaced entire app with new V2 architecture under `V2/` directory
- Added `SMMasterDataService` — fetches SM master data (111 entries with sprites, elements, passives, actives, scaling) from idle-miners.com API on launch
- Added `SMProgressService` — merges Kolibri sync game data (gameId matched) with master data, persists progress to UserDefaults
- Added `AIProviderConfig` + `V2StrategyService` — dual AI provider support (OpenAI via /v1/responses, DeepSeek via /chat/completions) with per-provider API key storage and model selection
- Fixed `OpenAIKeyStore` from `actor` → `final class @unchecked Sendable` to allow synchronous calls from @MainActor views
- Added DeepSeek API key field to Settings alongside provider picker and per-provider model override
- New screens: Dashboard (overview cards + area coverage + top unlocked), Managers (searchable grid with sprite images, filter by department, detail view with elements/passives/active), Strategy (provider picker, mine details, AI strategy generation with enriched data)
- ContentView now loads master data on launch, then shows 4-tab V2 layout
- Sync tab now writes to `SMProgressService` instead of old OCRReviewViewModel
- Deleted old `CommandCenterViewV2` OCR-import sections, `StrategyPipelineView`/`StrategySummaryView` OCR env refs
- Old `StrategyPipelineView`, `StrategySummaryView`, `CommandCenterViewV2` remain as unused code (can be pruned next)
- **BUILD SUCCEEDED**, **TEST SUCCEEDED** on Yancy's Phone Sim
- Follow-up: prune old V1 screens (CommandCenterV2, StrategyPipeline, StrategySummary, SnapshotHistory), wire image caching for sprites, add manual progress editing

### 2026-07-14: Kolibri Capsule request hardening (auth + save slot fallback)
- Updated Kolibri request auth header to use explicit bearer format (`Authorization: Bearer <token>`) in `KolibriAPIClient.fetchSavegame(...)`
- Added response-body logging for non-2xx Capsule responses to improve runtime diagnosis without exposing full tokens
- Fixed empty `saveGameKey` propagation by defaulting to `"0"` in `KolibriCredentialsStore.saveGameKey` and adding URL-layer fallback in `buildSavegameURL(...)`
- Why: simulator logs showed requests were sent with `saveGameKey=` (empty), which correlated with repeated 404 failures despite valid masked token continuity
- Validation on simulator `C76053FB-D4EB-4736-B906-6D8CF2976C10`: sync now succeeds and parses manager data (`Successfully fetched savegame data (managers: 60)`), and full test run completed with `** TEST SUCCEEDED **`
- Follow-up: after stability window, consider reducing noisy debug logs or gating them behind a diagnostics toggle

### 2026-07-14: Phase 6 metadata persistence follow-through
- Expanded `SyncMetadata` to include `lastGameSaveDisplay` and `payloadFormat` so sync freshness and payload diagnostics persist across launches.
- Updated `SyncMetadataStore.recordSuccess(...)` to persist display-ready game save time, payload format, and app build metadata (with automatic build fallback from bundle info).
- Wired `KolibriSyncService` to pass `payloadFormat` from `KolibriFetchResult.diagnostics` into persisted metadata.
- Added `SyncMetadataStoreTests` covering: persisted success metadata, failed-attempt preservation of previous successful sync timestamp, and masked-ID storage behavior.
- Verification: app scheme tests pass on simulator `C76053FB-D4EB-4736-B906-6D8CF2976C10`; package-only tests are not currently runnable through the workspace test plan/scheme configuration.

### 2026-07-14: Phase 7 Today screen restructure + tab actions
- Refactored `V2DashboardView` into a Today-first layout: sync status header, strongest-by-area section, fragment-backed "Ready to Improve", quick actions, then collection and coverage.
- Removed outdated sync explainer copy that referenced the old Sync tab and replaced with live sync/freshness status from `KolibriSyncService` + `SyncMetadataStore`.
- Added deterministic recommendation helpers in `SMProgressService`: `strengthScore`, `strongestUnlockedManager(in:)`, `strongestByArea()`, and `upgradeOpportunityManagers(limit:)`.
- Updated `ContentView` tab wiring with `V2RootTab` selection so Today quick actions can jump directly to Managers/Strategy tabs.
- Validation: `xcodebuild ... test` succeeded on simulator `C76053FB-D4EB-4736-B906-6D8CF2976C10` after resolving compile-time SwiftUI inference/style issues.

### 2026-07-14: Phase 8+ follow-through (Managers + More IA + sync frequency cleanup)
- Implemented Managers screen improvements: unlocked-only default scope, ownership filter (`Unlocked/All/Locked`), deterministic sorting options (`Recommended/Name/Level/Rank/Promotion/Rarity/Fragments`), advanced rarity + rank-ready filters, improved empty states, and improved card readability (full department labels, locked-fragment visibility, rank-ready badge when known threshold data exists).
- Added `ManagerListQuery` service and `ManagerFilteringTests` to verify default unlocked filtering, department filter correctness, search+ownership combination, and deterministic recommendation tie-break ordering.
- Introduced `SyncFrequency` (`Off/1h/6h/12h/24h`) and removed effective 30-second polling behavior from `KolibriSyncService` (legacy auto-sync APIs are now no-op shims).
- Updated launch sync orchestration to honor frequency freshness when non-off, while still supporting launch sync behavior with shared metadata.
- Restructured `V2MoreView` information architecture: game connection status/freshness summary, Sync Now action, game connection settings, diagnostics route, sync preferences, strategy/data settings links, and about section.
- Added strategy freshness UX in `V2StrategyView` ("using roster synced … ago") with in-context Sync Now action.
- Hardened master-data reliability by adding source tracking (`MasterDataSource`) plus cached snapshot fallback and bundled fallback loading in `SMMasterDataService`.
- Added `SyncFrequencyTests` covering interval values and due/not-due freshness behavior.
- Validation: ran `xcodebuild -quiet ... test` on simulator `C76053FB-D4EB-4736-B906-6D8CF2976C10` after changes; test invocation completed successfully.

