# Feature Kickoff Template

Copy this template when starting any new feature or non-trivial change. Fill in the sections and hand it to `@Atlas`.

---

## Feature: <name>

### Objective
<What needs to be done — one clear sentence.>

### Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>
- [ ] <criterion 3>

### Context
- Related files/endpoints/components: <list any you already know>
- Similar existing pattern to follow: <e.g., see /api/export/tests>

### Constraints
- Follow patterns in `WORKSPACE_LIVING_DOC.md`
- No `.env` changes
- Role/auth must be enforced server-side
- Atomic phases; commit approval required per phase

### Kickoff command

```
@Atlas  implement the feature described above using strict workflow:
SCOUT → PLAN (stop for approval) → SECOND OPINION (no code) → IMPLEMENT phased (commit approval per phase) → REVIEW → WRITEUP → CHANGELOG
```

---

## Notes for Atlas

- Stop after PLAN and wait for explicit approval before any code.
- On second opinion: share plan with @Reviewer-subagent (NO CODE), record findings to docs/reviews/PLAN_<feature>_<date>.md.
- Per phase: lint/format/tests → diff → "Commit this phase? (yes/no)".
- Stop on any failure; report + propose fix path.
- After final review: update writeup, then ask about devChangelog.js update.
