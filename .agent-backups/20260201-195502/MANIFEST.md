# Backup Manifest

**Timestamp:** 20260201-195502  
**Reason:** Atlas bootstrap safety backup  
**Purpose:** Preserve existing agent-related files before normalizing Atlas + subagents workflow

## Files Backed Up

- `.github/copilot-instructions.md` → `copilot-instructions.md`

## Restore Instructions

To restore these files:
```bash
cp .agent-backups/20260201-195502/copilot-instructions.md .github/copilot-instructions.md
```
