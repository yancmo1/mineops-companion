# 🏷️ MineOps Companion – Versioning & Release Guide

**Purpose:**  
Provide a standardized versioning process for all contributors and AI agents working on the *MineOps Companion* repository.  
This document explains how version numbers, git tags, and pre-releases should be handled across milestones defined in [`ROADMAP.md`](./ROADMAP.md).

---

## 1. Version Format (Semantic Versioning)
Use **SemVer 2.0.0**:  
```
MAJOR.MINOR.PATCH
```

### Meaning
| Segment | Increment When... | Example |
|----------|------------------|----------|
| **MAJOR** | Backward-incompatible changes (e.g., Swift module refactor, new app target). | `1.0.0` |
| **MINOR** | Backward-compatible feature additions (new screen, new export type). | `0.4.0` |
| **PATCH** | Backward-compatible bug fixes, performance, or minor UI corrections. | `0.3.1` |

---

## 2. Pre-Release Tags
For testing or staged milestones, append identifiers:
```
0.3.0-beta.1
0.4.0-rc.1
```
**Suffixes:**  
- `-alpha` → experimental internal build  
- `-beta` → feature-complete, not yet polished  
- `-rc` → release candidate for tagging as stable  

Agents may publish pre-release tags when instructed, but only the maintainer (Yancy) approves final merges to `main`.

---

## 3. Release Workflow

### Step 1 – Confirm Version Bump
After merging a milestone PR:
1. Check [`CHANGELOG.md`](./CHANGELOG.md) for latest entry.  
2. Determine new version using this table:

| Commit Type | Bump | Example |
|--------------|------|----------|
| `feat:` | MINOR | 0.3.0 → 0.4.0 |
| `fix:` | PATCH | 0.3.0 → 0.3.1 |
| `refactor:` or `docs:` | none | — |

---

### Step 2 – Update Files
1. Edit `CHANGELOG.md` with new section header (use previous as template).  
2. Update `README.md` footer if version is displayed.  
3. Commit with:
   ```
   docs: bump version to v0.X.X
   ```

---

### Step 3 – Tag the Release
Run:
```bash
git tag -a v0.X.X -m "Release v0.X.X – [brief summary]"
git push origin v0.X.X
```

Tags should always include a message referencing:
- Current Phase from ROADMAP  
- Key PR numbers or short summary

Example:
```
git tag -a v0.3.0 -m "Phase 1 complete: SwiftUI scaffold + OCR + Strategy Engine"
```

---

### Step 4 – Create GitHub Release (Optional)
1. Go to the **Releases** tab → **Draft a new release**.  
2. Choose the tag (e.g., `v0.3.0`).  
3. Copy the corresponding CHANGELOG section as release notes.  
4. Click **Publish release**.

---

## 4. Development Branch Versioning
- `main` → always stable / latest release.  
- `develop` (optional) → staging for next minor version.  
- `feature/*` → temporary, use suffix `-dev` in version identifiers if tagging interim builds.  
  Example: `v0.4.0-dev.2`

---

## 5. Automated Version Proposal (Agent Rule)
When a PR is merged:
- If commit type includes `feat:` → propose new **minor** version.  
- If commit type includes `fix:` → propose new **patch** version.  
- The agent should append the following to PR comment:
  ```
  Proposed Version Bump: v<new-version>
  CHANGELOG Section: [phase reference]
  ```
This ensures synchronization with human approvals.

---

## 6. Hotfix Process
For critical issues discovered post-release:
1. Create branch `hotfix/vX.Y.Z`.
2. Implement fix and test.
3. Commit as `fix: hotfix [short desc]`.
4. Merge to `main`, tag as new patch version (`vX.Y.Z+1`).

---

## 7. Example Version Timeline
| Version | Phase | Summary |
|----------|--------|----------|
| v0.3.0 | Phase 1 | Core scaffold + OCR + Strategy |
| v0.3.1 | Phase 1 | Parsing + UIKit import fix |
| v0.4.0 | Phase 2 | Persistence + Export |
| v0.5.0 | Phase 3 | UX & AI Advisor |
| v1.0.0 | Stable | Public-ready internal release |

---

## 8. Agent Command Snippets

**Create Tag**
```
git tag -a v0.3.1 -m "fix: corrected OCR digit parsing per PRD §6.2"
git push origin v0.3.1
```

**Bump Version Automatically**
```
Update CHANGELOG.md and PRD version header to v0.X.X
Commit as docs: bump version to v0.X.X
Tag and push new version
```

---

## 9. Owner Responsibilities
- Yancy approves final tags and GitHub Releases.  
- Agents propose bumps but cannot publish new versions without approval.  
- Use the CHANGELOG as release source-of-truth.

---

## 10. Future Automation
When GitHub Actions integration is enabled:
- Detect merged PR with `feat:` or `fix:` label.  
- Auto-bump version and update CHANGELOG.  
- Generate GitHub release draft for maintainer review.

---

*End of Versioning Guide – v1.0 – October 2025*  