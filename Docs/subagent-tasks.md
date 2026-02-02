# Subagent Task Orchestration (Repo Standard)

Use this playbook to break down work into safe subtasks and execute them with subagents.

## Workflow (always)
1) SCOUT → 2) PLAN → 3) IMPLEMENT (phased) → 4) REVIEW (per phase)

## Read first
- [AGENTS.md](../AGENTS.md)
- [WORKSPACE_LIVING_DOC.md](../WORKSPACE_LIVING_DOC.md)
- [.github/copilot-instructions.md](../.github/copilot-instructions.md)

## Rules
- No `.env` edits
- Atomic changes
- Verify with repo checks
- Stop on ambiguity with options + recommendation

## Available Agents

### Atlas (Orchestrator)
Located at: `docs/agents/Atlas.agent.md`  
**Purpose:** Full end-to-end orchestration using SCOUT → PLAN → IMPLEMENT → REVIEW workflow  
**Use when:** You need complete task execution with gate enforcement

### Prometheus (Planner)
Located at: `docs/agents/Prometheus.agent.md`  
**Purpose:** Creates phased plans with acceptance criteria and verification steps  
**Use when:** You need a plan before implementation (can hand off to Atlas)

### Scout (Discovery)
Located at: `docs/agents/Scout-subagent.agent.md`  
**Purpose:** Read-only discovery of files, patterns, and constraints  
**Use when:** You need to understand what exists before planning or implementing

### Planner (Phased Planning)
Located at: `docs/agents/Planner-subagent.agent.md`  
**Purpose:** Convert findings into small, testable plans with 3-7 phases  
**Use when:** Scout findings need to be structured into an actionable plan

### Implementer (Execution)
Located at: `docs/agents/Implementer-subagent.agent.md`  
**Purpose:** Execute ONE approved phase with minimal diffs  
**Use when:** You have an approved plan and need to implement a specific phase

### Reviewer (Validation)
Located at: `docs/agents/Reviewer-subagent.agent.md`  
**Purpose:** Approve/block changes against acceptance criteria  
**Use when:** Implementation is complete and needs validation

## Example Workflow

```
User: "Add a new export format for mining data"

1. @Atlas (or @Prometheus): Orchestrate/Plan the feature
   - Delegates to @Scout-subagent for discovery
   - Delegates to @Planner-subagent for phased plan
   
2. @Implementer-subagent: Phase 1 - Add data models
   - Makes minimal changes
   - Runs tests
   
3. @Reviewer-subagent: Validate Phase 1
   - APPROVED / NEEDS_REVISION / FAILED
   
4. @Implementer-subagent: Phase 2 - Add UI components
   (repeat cycle)
```

## iOS/Swift Testing

Always test implementations using:
- Simulator: **Yancy's Phone Sim** (D3B97618-A8E6-4594-9F2B-C80DA9A0650C)
- Use XcodeBuildMCP tools (`test_sim_name_ws`)
- Run Swift Testing tests from `MineOpsCompanionPackage/Tests/`
