# Copilot Instructions (Repo Guardrails)

Before making any code changes:
1) Read [AGENTS.md](../AGENTS.md)
2) Read [WORKSPACE_LIVING_DOC.md](../WORKSPACE_LIVING_DOC.md)

## Non-negotiables
- Do not modify or create `.env`
- Keep changes atomic and reviewable
- Prefer existing patterns over refactors
- If blocked/ambiguous: stop and report options + recommendation
- Run the repo's normal verification steps relevant to your changes

## iOS/Swift-Specific Rules
- This repository uses Swift 6.1+ and SwiftUI for iOS 18+ apps. All code should follow modern Swift and SwiftUI best practices.
- This is an iOS project NOT a pure Swift Package or macOS project. It utilises a local Swift Package which is wrapped in an Xcode project. This makes it easier for agents to work on the project.
- Use the Model-View (MV) pattern with native SwiftUI state management (`@State`, `@Observable`, `@Environment`, `@Binding`). Do not use ViewModels or MVVM.
- All concurrency must use Swift Concurrency (async/await, actors, @MainActor). Do not use GCD or completion handlers.
- Write all new code and features inside the Swift Package (`MineOpsCompanionPackage`), not in the app shell.
- Use the Swift Testing framework (`@Test`, `#expect`, `#require`) for all tests. Place tests in the package's `Tests/` directory.
- When running tests use the `test_sim_name_ws` tool do not use `swift_package_test`.
- Use XcodeBuildMCP tools for building, testing, and automation. Prefer these over raw xcodebuild or CLI commands.
- For data persistence, use SwiftData (never CoreData), though only use for complex scenarios, prefer simpler options first e.g. UserDefaults.
- Always provide accessibility labels and identifiers for UI elements.
- Never log sensitive information or use insecure network calls.
- On iOS Swift apps, you should always run a build and test using simulator **Yancy's Phone Sim** (D3B97618-A8E6-4594-9F2B-C80DA9A0650C) to make sure there are no build issues. 
