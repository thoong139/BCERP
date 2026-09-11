# Change Report — [Change Summary]

## Summary
- **Change ID:** CHG-YYYYMMDD-NNN
- **User request:** [prompt summary]
- **Change type:** [MODIFY_FEATURE]
- **Scope:** [N] systems, [M] modules affected

## Changes Made

### Docs Updated ([N] files)
| File | Changes |
|------|---------|
| [path] | [mo ta ngan] |

### Code Modified ([N] files)
| File | Changes | REQ-IDs |
|------|---------|---------|
| [path] | [mo ta ngan] | [IDs] |

### Tests Updated ([N] files)
| File | Changes |
|------|---------|
| [path] | [mo ta ngan] |

### Registry Updated
- Fields changed: [list]
- Backup: `req-registry.json.pre-change-[timestamp]`

## Verification Results
- **Preflight:** PASS / WARN (details)
- **Verify-sync:** [X]% sync rate
- **Mini-verifies:** [passed]/[total] passed
- **Regression risk:** [HIGH/MEDIUM/LOW] → [outcome]

## Expert Analysis Applied (DEEP mode only)
- [Expert insights used in implementation]

## Remaining Items / Follow-up
- [Any items not completed or needing attention]

## Rollback Instructions
```bash
# Restore registry
cp .mc-data/docs/_meta/req-registry.json.pre-change-<timestamp> .mc-data/docs/_meta/req-registry.json

# Restore individual code files
git checkout -- [file paths]
```

## Next Steps
1. Review changes: `git diff`
2. Run full test suite
3. Check `/status` for overall project health

---

> **Tom tat khong chuyen:** Xem `phase-summary.md` cung folder nay — giai thich nhung gi da thay doi bang ngon ngu don gian.
