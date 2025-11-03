# 🚀 MineOps Companion – Release Checklist

**Purpose:**  
Define the exact steps required to release a new version of *MineOps Companion* cleanly and consistently.  
This checklist must be followed by Yancy Shepherd (maintainer) or any authorized agent before tagging or publishing a new version.

---

## 1. Pre-Release Verification

### ✅ Code Quality
- [ ] Ensure all modules compile successfully in **Xcode 17+**.  
- [ ] Run unit tests in `/Tests` folder.  
- [ ] Confirm zero build warnings or SwiftLint violations.  
- [ ] Verify app navigation: *Dashboard → Import → Review → Strategy.*

### 🧩 Feature Completion
- [ ] Confirm all milestone tasks for the current **Phase** in [`ROADMAP.md`](./ROADMAP.md) are complete.  
- [ ] Ensure all PRs linked to this phase are merged into `main`.  
- [ ] Check that all new commits reference the appropriate PRD § and Phase.

### 📄 Documentation
- [ ] Update `CHANGELOG.md` with new section for the version being released.  
- [ ] Update `VERSIONING.md` table if version progression changes.  
- [ ] Confirm `PRD-MineOps-Companion.md` reflects current architecture.  
- [ ] Update `README-DEV-SETUP.md` or screenshots if UI changed.

---

## 2. Version Bump
1. Determine new version type:  
   - `feat:` → Minor  
   - `fix:` → Patch  
   - Major refactor → Major  
2. Update `CHANGELOG.md` and commit:
   ```
   docs: bump version to vX.Y.Z
   ```
3. Tag the release:
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z – [summary]"
   git push origin vX.Y.Z
   ```

---

## 3. Release Validation
- [ ] Checkout tag locally → build and run in simulator.  
- [ ] Confirm `sm_directory.json` loads correctly.  
- [ ] Verify strategy summaries render expected recommendations.  
- [ ] Check OCR accuracy with sample screenshots.

---

## 4. GitHub Release
- [ ] Navigate to **Releases → Draft a new release**.  
- [ ] Select tag `vX.Y.Z`.  
- [ ] Paste the relevant `CHANGELOG.md` section as notes.  
- [ ] Attach any new screenshots or build artifacts.  
- [ ] Publish.

---

## 5. Post-Release
- [ ] Merge any hotfix branches if pending.  
- [ ] Close completed milestone in `ROADMAP.md`.  
- [ ] Create next milestone section and update **Current Phase** header.  
- [ ] Notify agents: “Advance to next roadmap phase.”

---

## 6. Automation Notes
When CI/CD is enabled:  
- Auto-run tests → if pass, auto-tag patch/minor.  
- Generate release draft for review.  
- Require maintainer approval before publish.

---

**Final Sign-Off Checklist**
- [ ] Maintainer approval  
- [ ] Tag pushed  
- [ ] GitHub release published  
- [ ] Docs updated  
- [ ] Repository verified clean  

---

*End of Release Checklist v1.0 – October 2025*
