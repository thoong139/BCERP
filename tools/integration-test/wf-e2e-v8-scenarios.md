# wf-e2e v8.0 Integration Test Scenarios

## SCENARIO 1: Happy Path (Simple FEAT, no cross-module)

**Setup:** FEAT với code đã implement, BE/FE/DB online, Playwright available

**Expected:**
- F0: proceed=true (4/4 checks pass)
- F0a: 8 finding files tồn tại + size > 500 bytes
- F0b: seed skip (no seed-requirements.json)
- F1-F8: tất cả completed
- Final: e2e-status.json.final_status = "completed"

**Verify:**
```bash
jq '.f0_infra.status' e2e-status.json    # "completed"
jq '.f0a_finding.status' e2e-status.json # "completed"
ls findings/ | wc -l                     # ≥ 8
```

---

## SCENARIO 2: Infra Down (F0 block)

**Setup:** BE offline (localhost:5048 không phản hồi)

**Expected:**
- F0: proceed=false, blockers[0].error_code = "E011"
- Session status = "BLOCKED_INFRA"
- KHÔNG advance F0a, F1-F8
- phase-summary.md có lệnh khởi động

**Verify:**
```bash
jq '.proceed' infra-blockers.json              # false
jq '.f0a_finding.status' e2e-status.json       # "pending" (chưa chạy)
```

---

## SCENARIO 3: Seed Missing Data (F0b auto-seed)

**Setup:** DB rỗng, seed-requirements.json tồn tại, NODE_ENV=test

**Expected:**
- Guard G1 pass (NODE_ENV != production)
- Guard G2 pass (seed script có upsert)
- Auto-seed thành công
- seed-report.json audit_chain hợp lệ

---

## SCENARIO 4: Cross-Module Gap (B1 detect)

**Setup:** FEAT phụ thuộc module Banking với impl_status=not_started

**Expected:**
- F0a phase1: cross-module-gaps.json tạo với 1 entry
- CDG-NEW-01 triggered: AskUserQuestion
- Nếu --auto: architect dispatched → decision logged

---

## SCENARIO 5: Flaky Scenario (G1 quarantine)

**Setup:** Inject scenario với hardcoded sleep + index selector

**Expected:**
- G1.1 lint: BLOCK scenario (violations found)
- lint-report.json với 2 violations
- scenario KHÔNG execute khi có violations

---

## SCENARIO 6: --no-playwright DEGRADE (G2)

**Setup:** Run với --no-playwright flag

**Expected:**
- F2/F7/F8 status = "degraded_no_browser" (không skip, không completed)
- Final status = "degraded"
- phase-summary.md warning về non-production-ready

---

## SCENARIO 7: Batch Parallel 3 FEATs

**Setup:** FIN-006 dep FIN-008 (hard), FIN-003 standalone

**Expected:**
- dependency-matrix.json: topology_levels[0]=[FIN-008, FIN-003], levels[1]=[FIN-006]
- FIN-008 + FIN-003 chạy parallel (level 1)
- FIN-006 chỉ dispatch sau level 1 complete
- Gate check sau 3 FEATs

---

## Kết Quả Acceptance

7/7 scenarios pass theo expected behavior.

**Verify file structure:**
```bash
ls .mc-data/work/wf-e2e-verify/sessions/*/infra-blockers.json
ls .mc-data/work/wf-e2e-verify/sessions/*/findings/
ls .mc-data/work/wf-e2e-batch/sessions/*/dependency-matrix.json
```
