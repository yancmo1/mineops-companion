# MineOps Companion V2 — Yancmo-Friendly Product and Code Handoff

## Purpose

Refine MineOps Companion V2 into a simple, practical daily companion built around **Kolibri sync as the only player-data source**.

OCR has been removed from the active product direction. Do not restore OCR, screenshot parsing, or manual card extraction unless explicitly requested later.

The app should answer these questions quickly:

1. Did my game data sync successfully?
2. Who are my best Super Managers by area?
3. Which managers are close to an upgrade or rank-up?
4. What lineup or upgrade should I work on next?
5. Where do I manage sync, credentials, and application settings?

The finished experience should feel friendly, obvious, and low-maintenance rather than like a developer diagnostic utility.

---

# Confirmed Product Decisions

These decisions are final for this pass.

- Kolibri sync is the only source of player progress.
- Remove the permanent **Sync** tab.
- Replace the Sync tab with **More** or **Settings**.
- Move all sync controls, credential entry, sync diagnostics, and manual sync into More/Settings.
- Automatically sync when the app opens.
- Allow manual sync from the Today screen and More/Settings.
- Do not continuously auto-sync while the app remains open.
- Keep an optional scheduled-sync setting only if it is simple and reliable.
- Scheduled intervals may be: Off, 1 hour, 6 hours, 12 hours, 24 hours.
- The default scheduled-sync setting is Off.
- Credential setup should accept the complete Idle Miner debug ID string and extract the correct Kolibri UUID automatically.
- The Managers screen should default to unlocked managers.
- Add useful filters and sorting.
- Replace the misleading “Top Unlocked” section with a meaningful best-by-area or strongest-by-area section.
- Persist and clearly display sync freshness.
- Kolibri sync data should be authoritative, not merged with `max()` logic.

---

# Current Relevant Architecture

The following files currently control the V2 product experience.

```text
Sources/MineOpsCompanionFeature/
├── ContentView.swift
├── App/
│   ├── KolibriSyncView.swift
│   └── MineOpsSettingsView.swift
├── Data/
│   ├── KolibriAPIClient.swift
│   ├── KolibriCredentialsStore.swift
│   └── KolibriSyncService.swift
└── V2/
    ├── SMMasterDataService.swift
    ├── Services/
    │   ├── SMProgressService.swift
    │   └── AIStrategyService.swift
    └── Views/
        ├── V2DashboardView.swift
        ├── V2ManagersView.swift
        └── V2StrategyView.swift
```

Current navigation in `ContentView.swift`:

```text
Dashboard | Managers | Strategy | Sync
```

Target navigation:

```text
Today | Managers | Strategy | More
```

---

# Phase 1 — Navigation and App Structure

## 1. Rename Dashboard to Today

### File

`Sources/MineOpsCompanionFeature/ContentView.swift`

### Required changes

Replace the Dashboard tab label and icon:

```swift
V2DashboardView()
    .tabItem {
        Label("Today", systemImage: "sun.max.fill")
    }
```

The view type may remain `V2DashboardView` for this pass, but renaming it to `V2TodayView` is preferred if references are straightforward to update.

### Acceptance criteria

- First tab is named **Today**.
- The screen is clearly action-oriented rather than a generic dashboard.
- Existing V2 state and environment injection continue to work.

---

## 2. Replace Sync tab with More

### File

`Sources/MineOpsCompanionFeature/ContentView.swift`

Replace:

```swift
KolibriSyncView()
    .tabItem {
        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
    }
```

With a new view:

```swift
V2MoreView()
    .tabItem {
        Label("More", systemImage: "ellipsis.circle")
    }
```

### New file

Create:

```text
Sources/MineOpsCompanionFeature/V2/Views/V2MoreView.swift
```

### More screen structure

Use a `NavigationStack` and grouped `List`.

Suggested sections:

#### Game Connection

- Connection status
- Player name
- Masked Kolibri ID
- Last game save time
- Last successful MineOps sync time
- Manual **Sync Now** button
- Navigation link to **Game Connection Settings**

#### MineOps

- Strategy settings
- AI provider settings
- Appearance or future preferences
- Export/debug tools, only if still required

#### Support and Diagnostics

- Sync diagnostics
- Last sync error
- Data counts
- App version/build
- Reset local data, placed behind a destructive confirmation

### Important

Do not make technical diagnostics the first thing users see. Put them under an Advanced or Diagnostics disclosure/navigation destination.

---

# Phase 2 — App Launch Sync Behavior

## 3. Auto-sync once when the app opens

### Current issue

`ContentView` only runs:

```swift
await progressService.initialize()
```

It does not coordinate the initial Kolibri sync.

### Desired behavior

On app launch:

1. Load bundled/cached master data.
2. Load last known local progress immediately.
3. If valid Kolibri credentials exist, perform one sync.
4. Apply the sync result to `SMProgressService`.
5. Update sync metadata.
6. Do not start a repeating 30-second loop.
7. Do not block the entire app if sync fails.

### Recommended implementation

Create a shared app coordinator or make `KolibriSyncService` a shared instance.

Preferred new type:

```text
Sources/MineOpsCompanionFeature/App/AppLaunchCoordinator.swift
```

Suggested responsibilities:

```swift
@MainActor
@Observable
final class AppLaunchCoordinator {
    static let shared = AppLaunchCoordinator()

    private(set) var hasInitialized = false
    private(set) var isLaunching = false

    let progressService = SMProgressService.shared
    let syncService = KolibriSyncService.shared

    func initialize() async {
        guard !hasInitialized, !isLaunching else { return }
        isLaunching = true
        defer {
            isLaunching = false
            hasInitialized = true
        }

        await progressService.initialize()

        guard syncService.hasUsableCredentials else { return }
        await syncService.syncAndApplyToProgress()
    }
}
```

If adding a coordinator feels excessive, the same orchestration may live in `ContentView`, but avoid creating multiple independent `KolibriSyncService()` instances.

### Critical singleton change

`KolibriSyncView` currently creates its own service:

```swift
@State private var syncService = KolibriSyncService()
```

This produces isolated sync state and will cause Today, More, and launch sync to disagree.

Change `KolibriSyncService` to:

```swift
public static let shared = KolibriSyncService()
```

Make the initializer private unless tests require injection.

Every V2 screen should reference the same instance through environment injection or `KolibriSyncService.shared`.

### Acceptance criteria

- App loads cached progress without waiting for the network.
- If credentials are present, one background sync runs on launch.
- The user can continue using the app when sync fails.
- Sync state is identical on Today and More.
- App does not begin a repeated short-interval sync loop.

---

## 4. Add a single orchestration method

### File

`Data/KolibriSyncService.swift`

Create a higher-level method such as:

```swift
public func syncAndApplyToProgress() async {
    await sync()

    guard case .success = syncState else { return }

    let managers = getManagers()
    await SMProgressService.shared.applySyncData(managers: managers)
    setLastImportedManagerCount(managers.count)
}
```

Prefer this over requiring every view to separately call `sync()`, fetch managers, and apply progress.

### Acceptance criteria

- One method performs the complete sync-to-UI pipeline.
- Today manual sync and More manual sync call the same method.
- Sync cannot apply stale data after a failed request.

---

# Phase 3 — Remove Continuous Auto-Sync

## 5. Delete or disable the 30-second polling model

### File

`Data/KolibriSyncService.swift`

Current default:

```swift
return interval > 0 ? interval : 30.0
```

Current initializer also registers 30 seconds and starts a repeating task if enabled.

This is not appropriate for game-save data.

### Required behavior

Default:

```text
Scheduled Sync: Off
```

Allowed optional intervals:

```text
Off
Every 1 hour
Every 6 hours
Every 12 hours
Every 24 hours
```

### Preferred approach

For the first implementation, remove repeating in-session polling entirely.

Keep only:

- Sync once on launch.
- Sync manually on demand.
- Persist an optional preferred refresh interval for future use.
- Optionally use the selected interval as a launch freshness rule rather than a live timer.

Example launch rule:

```swift
if Date().timeIntervalSince(lastSuccessfulSyncDate) >= configuredInterval {
    await syncAndApplyToProgress()
}
```

This means “every 6 hours” becomes “sync at next app open if the previous sync is older than 6 hours.” It avoids background task complexity and battery/network misuse.

### Suggested enum

```swift
public enum SyncFrequency: String, CaseIterable, Codable, Identifiable {
    case off
    case hourly
    case sixHours
    case twelveHours
    case daily

    public var id: String { rawValue }

    public var interval: TimeInterval? {
        switch self {
        case .off: return nil
        case .hourly: return 60 * 60
        case .sixHours: return 6 * 60 * 60
        case .twelveHours: return 12 * 60 * 60
        case .daily: return 24 * 60 * 60
        }
    }

    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .hourly: return "Every Hour"
        case .sixHours: return "Every 6 Hours"
        case .twelveHours: return "Every 12 Hours"
        case .daily: return "Every 24 Hours"
        }
    }
}
```

### Remove or deprecate

- `syncTask`
- `startAutoSync()`
- `stopAutoSync()`
- `restartAutoSync()`
- 30-second defaults

If keeping these temporarily for compatibility, ensure they are never started by default and never use sub-hour intervals.

---

# Phase 4 — Credential Setup Using Full Debug ID

## 6. Accept the complete debug ID string

### Goal

The user should paste the complete text copied from Idle Miner Tycoon, for example:

```text
ID: 5.56.0 95973ir b1febfd3-f04f-4a05-8f3d-329fcdae7bef 5C6E939D2BEAF907 Disconnected dbffca92-27e9-485a-831a-feb5bfc2e3c4
```

MineOps should extract the correct Kolibri UUID automatically.

### Required parser

Create:

```text
Sources/MineOpsCompanionFeature/Data/KolibriDebugIDParser.swift
```

Suggested implementation:

```swift
public enum KolibriDebugIDParser {
    private static let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#

    public static func parseKolibriID(from input: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: uuidPattern) else { return nil }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = regex.matches(in: input, range: range)

        guard let last = matches.last,
              let valueRange = Range(last.range, in: input)
        else { return nil }

        return input[valueRange].lowercased()
    }
}
```

The current known behavior is to use the **last UUID** in the pasted debug ID.

### UI behavior

In Game Connection Settings:

- Label: **Paste Debug ID**
- Supporting text: “Copy the complete ID text from Idle Miner Tycoon. MineOps will find the correct player ID automatically.”
- Multiline text editor.
- Button: **Connect Game**
- Validate locally before saving.
- On success, show only a masked ID such as `••••• 3c4`.
- Do not require the user to manually identify which UUID is correct.

### Error states

- “No player UUID was found. Paste the complete debug ID from the game.”
- “The player ID appears incomplete.”
- “Connection failed. Check the authorization token and try again.”

### Tests

Create unit tests for:

- Full debug string with two UUIDs returns the last UUID.
- A single UUID returns that UUID.
- Uppercase UUID is normalized to lowercase.
- Whitespace/newline-heavy strings still parse.
- Invalid text returns `nil`.

---

## 7. Simplify credential settings

### Current issue

Credential setup is developer-oriented and exposes too many implementation details.

### Target structure

#### Standard section

- Paste Debug ID
- Connection status
- Player name
- Masked player ID
- Connect / Reconnect button

#### Advanced section

- Authorization token
- Save game key
- API diagnostics
- Raw endpoint status

The authorization token and save-game key should not dominate the normal setup flow.

### Security requirement

Store secrets in Keychain.

At minimum:

- Kolibri auth token → Keychain
- OpenAI API key → Keychain
- DeepSeek key, if retained → Keychain

Never ship hardcoded live credentials in source code.

Do not display the full auth token after saving.

---

# Phase 5 — Make Kolibri Sync Authoritative

## 8. Replace `max()` merge behavior

### File

`V2/Services/SMProgressService.swift`

Current behavior:

```swift
prog.level = max(prog.level, manager.level ?? 1)
prog.promoted = max(prog.promoted, manager.promotion ?? 0)
prog.rank = max(prog.rank, manager.rank ?? 0)
```

This permanently preserves bad or stale local values.

### Required behavior

Kolibri is the source of truth. Replace synced values directly:

```swift
prog.level = max(1, manager.level ?? 1)
prog.promoted = max(0, manager.promotion ?? 0)
prog.rank = max(0, manager.rank ?? 0)
prog.fragments = max(0, manager.fragments ?? 0)
prog.unlocked = true
```

All managers absent from the current synchronized save should return to their default locked state unless there is a clearly documented reason not to do so.

### Important design rule

Do not merge current local progress into the new synced roster before applying Kolibri values.

Preferred flow:

1. Build defaults for all master managers.
2. Apply current Kolibri save values exactly.
3. Replace the local roster atomically.
4. Persist the resulting roster.

### Manual editing

Because sync is authoritative, manual edits should either:

- be removed from the V2 experience, or
- be explicitly labeled as temporary overrides and stored separately.

Do not silently mix manual progress with synced progress.

### Acceptance criteria

- A manager previously stored at level 50 updates to level 16 if Kolibri says 16.
- Rank, promotion, and fragments can decrease when the save says they decreased.
- Sync result is deterministic.
- Repeating the same sync produces the same local roster.

---

# Phase 6 — Persist Sync Metadata

## 9. Add a persistent sync metadata model

### Problem

`KolibriSyncService.lastSyncDate` is in memory only. App relaunch loses sync context.

### Create model

```text
Sources/MineOpsCompanionFeature/Models/SyncMetadata.swift
```

Suggested structure:

```swift
public struct SyncMetadata: Codable, Equatable {
    public var lastSuccessfulSyncAt: Date?
    public var lastAttemptAt: Date?
    public var lastGameSaveAt: Date?
    public var lastGameSaveDisplay: String?
    public var playerName: String?
    public var maskedPlayerID: String?
    public var importedManagerCount: Int?
    public var payloadFormat: String?
    public var appBuild: String?
}
```

### Persistence

For this small metadata object, `UserDefaults` with JSON encoding is acceptable.

Create a focused store:

```text
Data/SyncMetadataStore.swift
```

Do not scatter sync metadata keys throughout views.

### Update metadata on every attempt

On attempt:

```swift
metadata.lastAttemptAt = Date()
```

On success:

```swift
metadata.lastSuccessfulSyncAt = Date()
metadata.playerName = parsedPlayerName
metadata.lastGameSaveAt = parsedSaveTimestamp
metadata.importedManagerCount = managers.count
metadata.maskedPlayerID = credentialsStore.maskedKolibriID
```

On failure, preserve the previous successful-sync metadata.

### Display distinction

Show both:

```text
Game saved 14 minutes ago
MineOps synced 2 minutes ago
```

These are not the same timestamp.

---

# Phase 7 — Today Screen Redesign

## 10. Replace current dashboard hierarchy

### File

`V2/Views/V2DashboardView.swift`

Current order:

1. Total/unlocked/locked cards
2. Coverage by area
3. Top Unlocked
4. Sync explanation card

Target order:

1. Sync status/header
2. Strongest by area
3. Upgrade opportunities
4. Quick actions
5. Collection overview
6. Coverage by area

---

## 11. Today sync header

Create a compact status card at the top.

Example successful state:

```text
Diggin Dad
Synced 2 minutes ago
Game save: 14 minutes ago
55 managers unlocked
```

Buttons:

- **Sync Now**
- Optional subtle link: **View Details** → More > Sync

States:

### Syncing

```text
Syncing game data…
```

### Error with cached data

```text
Couldn’t refresh game data
Showing your last successful sync from 2 hours ago
[Try Again]
```

### Not connected

```text
Connect Idle Miner to load your Super Managers
[Connect Game]
```

Do not remove cached progress because the latest network request fails.

---

## 12. Strongest by Area

Replace “Top Unlocked.”

### Display

Show one card for each department:

- Mineshaft
- Elevator
- Warehouse

Each card should show:

- Manager image
- Name
- Level
- Rank
- Promotion
- Effective active value
- Optional best-use label

### Selection logic

Do not rank by rarity alone.

Create a deterministic score in `SMProgressService` or a new `SMRecommendationService`.

Initial score can combine:

```text
active strength
level
rank
promotion
rarity weight
```

Suggested simple first-pass formula:

```swift
score =
    log10(max(effectiveActiveValue, 1)) * 100
    + Double(level) * 1.5
    + Double(rank) * 20
    + Double(promoted) * 10
    + rarityWeight
```

Document the formula. Keep it deterministic and testable.

Do not claim this is mathematically optimal. Label it as “Strongest by Area” based on current MineOps scoring.

### Fallback

If no unlocked manager exists in an area, show:

```text
No unlocked manager yet
```

---

## 13. Upgrade opportunities

Add a card titled:

```text
Ready to Improve
```

Show managers matching one or more of these:

- Enough fragments for rank-up
- Promotion available or relevant
- Close to rank-up
- High-value manager at unusually low level

Start with fragment-based logic if rank thresholds are available.

Suggested rows:

```text
Dr. Steiner — Ready to rank up
Jade Kim — 6 fragments needed
Sojo — Consider leveling next
```

If exact upgrade thresholds are not yet modeled, implement the UI and service boundary but only show recommendations backed by known data.

Do not invent upgrade readiness.

---

## 14. Quick actions

Add a compact button row:

- Sync Now
- View Managers
- Build Strategy

Use existing `MineOpsButton` styles where practical.

---

## 15. Move collection counts lower

Keep Total, Unlocked, and Locked, but place them below actionable sections.

Rename section to:

```text
Collection
```

The current three-card layout may be retained.

---

## 16. Remove obsolete sync explanation text

Delete copy such as:

```text
Manager data is pulled from Knight's Hub...
Game progress is synced via the Sync tab...
```

It is outdated and exposes implementation details instead of helping the user.

Replace it with live status derived from sync metadata.

---

# Phase 8 — Managers Screen Improvements

## 17. Default to unlocked managers

### File

`V2/Views/V2ManagersView.swift`

Current default includes all managers, then sorts unlocked first.

Add a scope/filter enum:

```swift
enum ManagerOwnershipFilter: String, CaseIterable, Identifiable {
    case unlocked
    case all
    case locked

    var id: String { rawValue }
}
```

Default:

```swift
@State private var ownershipFilter: ManagerOwnershipFilter = .unlocked
```

### UI

Use a segmented picker or compact menu:

```text
Unlocked | All | Locked
```

---

## 18. Add richer filters

Required filters:

- Department
- Rarity
- Ownership
- Upgrade-ready, when supported

Optional later filters:

- Rank
- Promotion
- Has fragments

Do not overload the top of the screen with too many chips. Use:

- Department chips for fast use
- A filter button opening a sheet for advanced filters

---

## 19. Add sorting

Create:

```swift
enum ManagerSortOption: String, CaseIterable, Identifiable {
    case recommended
    case name
    case level
    case rank
    case promotion
    case rarity
    case fragments
}
```

Display names:

```text
Recommended
Name
Highest Level
Highest Rank
Highest Promotion
Rarity
Most Fragments
```

Default sort:

```text
Recommended
```

Sorting must be deterministic and include a name tie-breaker.

---

## 20. Improve manager card readability

Current cards are compact but can be improved.

For unlocked managers, show:

- Level
- Rank
- Promotion
- Fragments only when greater than zero
- A small badge when ready to rank up

For locked managers:

- Keep a muted sprite/card
- Show fragments if the user has fragments toward unlock
- Avoid showing meaningless default level/rank values

Make department labels readable instead of three-letter abbreviations if space permits.

---

## 21. Empty-state handling

Examples:

### No search results

```text
No managers match “Steiner.”
```

### No unlocked managers

```text
No unlocked managers are available yet. Sync your game data to refresh MineOps.
```

### Filter excludes all

```text
No managers match the selected filters.
[Clear Filters]
```

---

# Phase 9 — More / Settings Information Architecture

## 22. Create V2MoreView

Suggested layout:

```text
More
├── Game Connection
│   ├── Sync status
│   ├── Sync Now
│   ├── Player name / masked ID
│   └── Game Connection Settings
├── Sync Preferences
│   ├── Sync on app open (On)
│   └── Refresh frequency (Off / 1h / 6h / 12h / 24h)
├── Strategy & AI
│   ├── AI provider
│   ├── Model
│   └── API key status
├── Data
│   ├── Export
│   ├── Sync diagnostics
│   └── Reset local data
└── About
    ├── Version
    └── Build
```

### Note on “Sync on app open”

For this phase, keep it enabled by default. It may be user-configurable, but avoid presenting too many settings unless needed.

---

## 23. Refactor KolibriSyncView

Do not delete the useful sync UI immediately.

Refactor it into one or more destination views:

```text
V2GameConnectionView.swift
V2SyncDiagnosticsView.swift
```

Reuse useful components from `KolibriSyncView`, but remove its tab-level assumptions.

The normal Game Connection screen should emphasize:

- Connected/disconnected
- Player name
- Last save
- Last sync
- Sync Now
- Reconnect

The diagnostics screen may show:

- HTTP status
- Payload format
- Imported manager count
- Last error details
- Decode diagnostics

---

# Phase 10 — Master Data Reliability

## 24. Do not make the app unusable when idle-miners.com is unavailable

### File

`V2/SMMasterDataService.swift`

Current behavior fetches all master data remotely every time:

```text
/api/sm-data
/api/sm-actives
/static/data/sm_passive_tables.json
```

The app already contains bundled resources such as:

```text
Resources/sm_complete_database.json
Resources/sm_directory.json
Resources/supermanagers.json
Resources/Icons/passives.json
```

### Required strategy

1. Load bundled master data immediately.
2. Use cached remote master data if newer and valid.
3. Refresh remote data in the background.
4. Validate remote payload before replacing cache.
5. Fall back to bundled/cached data on network failure.

### Service states

Add source information:

```swift
enum MasterDataSource {
    case bundled
    case cache
    case remote
}
```

Expose:

```swift
public private(set) var currentSource: MasterDataSource
```

### Acceptance criteria

- Managers screen works offline after installation.
- A remote API outage does not produce an empty roster.
- Remote master data can still update manager definitions.

---

# Phase 11 — State and Persistence Cleanup

## 25. Keep player progress in one source of truth

Use `SMProgressService.shared` for all V2 screens.

Do not maintain separate copies of the synchronized roster in:

- Sync view state
- Today state
- Strategy state
- Manager state

Views should derive from the shared progress service.

---

## 26. Make sync replacement atomic

When applying a save:

1. Parse entire save.
2. Validate manager IDs.
3. Build the complete new progress collection in memory.
4. Persist it.
5. Publish it to the UI once.

Do not visibly update one manager at a time.

If parsing fails, keep the previous roster.

---

## 27. Add sync snapshot rollback

Before replacing synchronized progress, save the previous roster as a snapshot.

Reuse `SnapshotManager` if appropriate.

Minimum snapshot metadata:

- Timestamp
- Player name
- Manager count
- Save timestamp
- Progress payload

Keep a small number, such as the latest 5 successful sync snapshots.

This is not a primary UI feature, but it protects against parser or endpoint changes.

---

# Phase 12 — Strategy Integration

## 28. Strategy must use only synced roster data

Remove any remaining assumptions that strategy data may come from OCR or manual recognized cards.

Strategy input should use:

```swift
SMProgressService.shared.progress.filter(\.unlocked)
```

Include:

- Manager identity
- Department
- Rarity
- Level
- Rank
- Promotion
- Fragments
- Effective active value
- Computed passives

Do not send locked managers as owned options.

---

## 29. Add clear strategy freshness

At the top of Strategy, show:

```text
Using roster synced 12 minutes ago
```

If roster is stale or never synced:

```text
Sync your game before building a strategy.
```

Provide a Sync Now button.

---

# Phase 13 — Error Handling and UX Copy

## 30. Friendly sync errors

Map technical failures to user-facing messages.

### Missing credentials

```text
MineOps is not connected to your game yet.
```

### Unauthorized

```text
Your game connection needs to be refreshed. Open Game Connection Settings and reconnect.
```

### Network

```text
MineOps couldn’t reach the game service. Your last synced data is still available.
```

### Payload changed

```text
The game save format may have changed. Your previous data is safe. Open Sync Diagnostics for details.
```

Do not show raw decoder errors in the primary UI.

---

## 31. Sync button behavior

When syncing:

- Disable duplicate sync requests.
- Show progress feedback.
- Keep current data visible.
- On success, show subtle confirmation.
- On failure, retain cached data.

Suggested button labels:

```text
Sync Now
Syncing…
Synced
Try Again
```

---

# Phase 14 — Tests

Add or update tests for the following.

## KolibriDebugIDParserTests

- Extracts final UUID from full debug string.
- Handles one UUID.
- Handles uppercase.
- Handles line breaks.
- Rejects invalid strings.

## SMProgressServiceSyncTests

- Kolibri value replaces larger local level.
- Kolibri value replaces larger local rank.
- Kolibri value replaces larger local promotion.
- Fragments update exactly.
- Missing managers reset to locked defaults.
- Reapplying identical save is idempotent.

## SyncMetadataStoreTests

- Successful sync metadata persists.
- Failed attempt preserves previous success timestamp.
- Masked ID does not reveal full UUID.

## SyncFrequencyTests

- Off has no interval.
- 1/6/12/24-hour values are correct.
- Freshness rule only requests sync when due.

## ManagerFilteringTests

- Default returns unlocked only.
- Department filter works.
- Search combines with ownership filter.
- Sorts are deterministic.

## TodayRecommendationTests

- Strongest manager is selected per department.
- Locked managers are excluded.
- Ties use stable name ordering.

---

# Phase 15 — Cleanup

## 32. Remove obsolete product references

Search for and remove user-facing references to:

```text
OCR
screenshot import
recognized card
Sync tab
Knight’s Hub as the player-progress source
30-second auto-sync
```

Do not remove historical code solely because a string exists; verify whether the code is still used. The product experience, however, must clearly describe Kolibri sync as the player-data source.

---

## 33. Package cleanup

Ensure `.gitignore` includes:

```gitignore
.build/
.swiftpm/
.DS_Store
__MACOSX/
DerivedData/
```

Do not commit generated build output or macOS archive metadata.

---

# Suggested Implementation Order

Codex should work in this order to reduce rework.

## Milestone 1 — Shared Sync Foundation

1. Make `KolibriSyncService` shared.
2. Add `syncAndApplyToProgress()`.
3. Make Kolibri sync authoritative in `SMProgressService`.
4. Add persistent sync metadata.
5. Add full debug ID parser.
6. Add unit tests for parser and authoritative sync.

## Milestone 2 — Navigation and Settings

1. Change tabs to Today, Managers, Strategy, More.
2. Create `V2MoreView`.
3. Refactor sync view into Game Connection and Diagnostics destinations.
4. Move credential setup into Game Connection Settings.
5. Add manual Sync Now controls.

## Milestone 3 — Launch Sync and Frequency

1. Add launch coordinator.
2. Sync once on app open.
3. Remove 30-second polling.
4. Add Off/1h/6h/12h/24h freshness setting.
5. Default to Off for scheduled refresh.

## Milestone 4 — Today Experience

1. Add sync header.
2. Add strongest-by-area.
3. Add upgrade opportunities.
4. Add quick actions.
5. Move collection metrics lower.
6. Remove stale explanatory sync copy.

## Milestone 5 — Managers Experience

1. Default to unlocked.
2. Add ownership filter.
3. Add advanced filter sheet.
4. Add sorting.
5. Improve empty states and card badges.

## Milestone 6 — Reliability

1. Bundle and cache master data.
2. Add remote fallback behavior.
3. Add sync snapshots.
4. Audit secrets and Keychain storage.
5. Remove dead V1/OCR-facing product references.

---

# Definition of Done

This pass is complete when all of the following are true.

- The tab bar is Today, Managers, Strategy, More.
- Sync is no longer a permanent tab.
- The app loads cached progress immediately.
- The app performs at most one launch sync when appropriate.
- No 30-second or short repeating sync loop runs.
- Manual Sync Now exists on Today and More.
- The complete debug ID can be pasted and parsed automatically.
- The correct final UUID is stored as the Kolibri ID.
- Secrets are not hardcoded and are stored securely.
- Kolibri values replace local player-progress values exactly.
- Sync timestamps and game-save freshness persist across launches.
- Today shows actionable information before collection totals.
- Strongest-by-area replaces rarity-only “Top Unlocked.”
- Managers defaults to unlocked managers.
- Managers has useful sorting and filters.
- Strategy clearly indicates roster freshness.
- Cached data remains usable during sync failures.
- Master manager data has bundled/cached fallback.
- New parsing, sync replacement, filtering, and metadata behavior has tests.

---

# Codex Working Rules

- Preserve the working Kolibri API integration.
- Do not restore OCR.
- Do not replace working save decoding unless required.
- Do not expose credentials or raw auth tokens in logs.
- Do not delete diagnostics; move them behind an Advanced destination.
- Keep changes incremental and compilable after each milestone.
- Run the Swift test suite after each milestone.
- Add tests before modifying authoritative merge behavior.
- Prefer existing MineOps UI components and theme tokens.
- Avoid introducing a second state-management system.
- Record notable architectural changes in the project development journal if one exists.

