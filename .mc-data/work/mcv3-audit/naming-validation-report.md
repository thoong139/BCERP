# Pipeline Naming Validation Report

## Ngay: 2026-09-12T15:09:25Z
## mc-data: .mc-data

## Summary

| Metric | Count |
|--------|-------|
| PASS | 4 |
| WARN | 8 |
| FAIL | 1 |
| Total | 13 |

## Verdict: NEEDS WORK — Co 1 loi naming can fix

## Chi tiet


### Check 1: Classified Batch Naming Convention

  [WARN] Khong co classified batch files (chua chay classify?)

### Check 2: Extracted File Naming

  [WARN] Khong co extracted files (chua chay extract?)

### Check 3: Registry Naming Consistency

  [PASS] Registry JSON hop le
  [PASS] Registry systems: 6 (khong duplicate)
  [PASS] Registry modules: 19 (khong duplicate)
  [FAIL] Registry co impl_status khong hop le (CORE-010): REQ-BOD-001=
REQ-BOD-002=
REQ-BOD-003=
REQ-BOD-004=
REQ-BOD-005=
REQ-BOD-006=
REQ-BOD-007=
REQ-BOD-008=
REQ-BOD-009=
REQ-BOD-010=
REQ-BOD-011=
REQ-HR-001=
REQ-HR-002=
REQ-HR-003=
REQ-HR-004=
REQ-HR-005=
REQ-HR-006=
REQ-HR-007=
REQ-HR-008=
REQ-HR-009=
REQ-HR-010=
REQ-FIN-001=
REQ-FIN-002=
REQ-FIN-003=
REQ-FIN-004=
REQ-FIN-005=
REQ-FIN-006=
REQ-FIN-007=
REQ-FIN-008=
REQ-FIN-009=
REQ-FIN-010=
REQ-FIN-011=
REQ-FIN-012=
REQ-FIN-013=
REQ-FIN-014=
REQ-FIN-015=
REQ-FIN-016=
REQ-FIN-017=
REQ-SALES-001=
REQ-SALES-002=
REQ-SALES-003=
REQ-SALES-004=
REQ-SALES-005=
REQ-SALES-006=
REQ-SALES-007=
REQ-SALES-008=
REQ-SALES-009=
REQ-OPS-001=
REQ-OPS-002=
REQ-OPS-003=
REQ-OPS-004=
REQ-OPS-005=
REQ-OPS-006=
REQ-OPS-007=
REQ-OPS-008=
REQ-OPS-009=
REQ-OPS-010=
REQ-OPS-011=
REQ-OPS-012=

### Check 4: Phase 2 Folders vs Registry

  [PASS] Phase 2 co 6 system folders

### Check 5: Cross-Phase Naming Spot Check

  [WARN] Phase 0: 'MOD-RBAC-AUDIT' KHONG tim thay trong P0-01 (co the dung display name)
  [WARN] Phase 0: 'MOD-SETTINGS-GW' KHONG tim thay trong P0-01 (co the dung display name)
  [WARN] Phase 0: 'MOD-HR-CORE' KHONG tim thay trong P0-01 (co the dung display name)

### Check 6: Module-Code Mapping

  [WARN] module-code-mapping.json khong ton tai (chua chay extract Stage 3.5?)

### Check 7: Naming Normalization Log

  [WARN] naming-normalization-log.md khong ton tai (normalize Step 4a.5 chua chay?)

### Check 8: Classify Naming Fixes

  [WARN] classify-naming-fixes.json khong ton tai (classify POST-GATE CORE-016 chua chay hoac khong co fixes)

## CORE Rules Checked

| Rule | Check |
|------|-------|
| CORE-010 | impl_status values (Check 3) |
| CORE-016 | Classify naming convention (Check 1, 8) |
| CORE-017 | Extract normalized names (Check 2) |
| CORE-018 | Cross-phase naming (Check 4, 5) |

## Next Steps

- Fix naming violations truoc khi tiep tuc downstream skills
- Neu > 5 FAIL: can chay lai pipeline tu classify
