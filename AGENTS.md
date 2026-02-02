# AGENTS (Repo Entry Point)

This file is the **entrypoint** for any AI agent/subagent working in this repo.

## Read order (required)

1) **[WORKSPACE_LIVING_DOC.md](WORKSPACE_LIVING_DOC.md)** (single source of truth: architecture, workflow, decisions)
2) **[.github/copilot-instructions.md](.github/copilot-instructions.md)** (agent guardrails / repo rules)
3) Any relevant product/design notes (PRD, backlog, UI notes) referenced in the task

> If these sources conflict with anything else you see, **they win**.

## Repo non-negotiables

- **Do not modify or create `.env`.** If environment variables must change, document them only.
- **Keep changes atomic.** Prefer small, reviewable PRs and avoid broad refactors unless explicitly required.
- **Follow existing patterns.** Match current routing, component conventions, data access patterns, and styling.
- **Verify your work.** If you change behavior, run the relevant checks and report results.
- **No scope creep.** If you discover adjacent issues, log them as follow-ups instead of expanding the current change.

## iOS/Swift-Specific Rules

- This is an iOS 18+ project using Swift 6.1+ and SwiftUI
- Use the Model-View (MV) pattern with native SwiftUI state management — **no ViewModels or MVVM**
- All concurrency must use Swift Concurrency (async/await, actors, @MainActor) — **no GCD or completion handlers**
- Write all new code and features inside the Swift Package (`MineOpsCompanionPackage`), not in the app shell
- Use the Swift Testing framework (`@Test`, `#expect`, `#require`) for all tests
- When running tests, use the designated simulator: **Yancy's Phone Sim** (D3B97618-A8E6-4594-9F2B-C80DA9A0650C)
- Use XcodeBuildMCP tools for building, testing, and automation
- For data persistence, use SwiftData (never CoreData), but prefer simpler options like UserDefaults first
- Always provide accessibility labels and identifiers for UI elements
- Never log sensitive information or use insecure network calls

## Where to record decisions

If you make material changes (schema/endpoints/auth/permissions/workflow/automation), append a concise note to the **Session Log** in [WORKSPACE_LIVING_DOC.md](WORKSPACE_LIVING_DOC.md):
- what changed
- why
- risks/mitigations
- follow-ups

---

## Standard Subagent Roles (KISS)

Use these role names in prompts. Each role has strict scope.

### 1) SCOUT (Read-only discovery)
**Purpose:** Find relevant files, current patterns, and constraints.  
**Must output:** primary/secondary file list + current behavior summary.  
**Must NOT:** edit files or run commands.

### 2) PLANNER (Acceptance criteria + phased plan)
**Purpose:** Turn findings into a small, testable plan.  
**Must output:** acceptance criteria + 3–7 phases + verification steps.  
**Must NOT:** implement code changes.

### 3) IMPLEMENTER (Make the smallest safe diff)
**Purpose:** Implement one approved phase at a time.  
**Must output:** files changed + what changed + commands run + results.  
**Must NOT:** expand scope, refactor broadly, or "improvise requirements."  
**If blocked/ambiguous:** STOP and report "open question + options + recommendation."

### 4) REVIEWER (Approve or block)
**Purpose:** Validate against acceptance criteria and repo standards.  
**Must output:** APPROVED / NEEDS_REVISION / FAILED + blocking issues.  
**Must NOT:** bikeshed style or request scope creep.
