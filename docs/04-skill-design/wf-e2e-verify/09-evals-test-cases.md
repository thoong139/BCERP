# 09 — Evals & Test Cases

> **Mục đích file:** 9 evals match `evals/evals.json` v7.0.0 — coverage orchestrator behavior + backward-compat + anti-loop.

---

## 1. Bảng test cases

| ID | Type | Mục đích kiểm tra |
|----|------|-------------------|
| TC-ORCH-001 | integration | Full pipeline 8 steps complete sequential |
| TC-ORCH-002 | integration | Conditional skip — block-test empty, implement-required empty → F3/F4 skipped |
| TC-ORCH-003 | edge | Anti-loop F6↔F5 max 3 vòng → ESCALATE E004 |
| TC-ORCH-004 | integration | Legacy `--playwright-mcp --cross-module --parallel-safe` → 3 WARN + run default chain |
| TC-ORCH-005 | integration | Legacy `--fix=<path>` → standalone F6 mode |
| TC-ORCH-006 | resume | Resume mid-pipeline (sau F4 crash) → KHÔNG re-run F1-F3 |
| TC-ORCH-007 | smoke | `--status` display + no execute |
| TC-ORCH-008 | edge | `--no-playwright` deprecated v7.1.0 → ignored với WARN, pipeline vẫn chạy live |
| TC-ORCH-009 | integration | `--skip=F2,F5,F7,F8` explicit (CI không có browser) |

---

## 2. Test case detail (extract)

### TC-ORCH-001 — Full pipeline 8 steps complete

**Setup:**
- Feature `FEAT-EW-CRM-001` có spec đầy đủ + code implement
- DB+BE+FE running, Playwright MCP available
- 11 sub-skill directories tồn tại

**Run:** `/wf-e2e-verify FEAT-EW-CRM-001`

**Expected behavior:**
1. Init session + `e2e-status.json` + `.lock`
2. F0 infra check PASS
3. F0a wf-e2e-finding → findings/ 8 files + 4 SSOT JSONs rỗng
4. F0b (nếu có seed-requirements) → seed manifest
5. F1 wf-e2e-test → DB/API/UI/Integration test reports, SSOT JSONs APPEND
6. F2 wf-e2e-browser (default ON) → pre-scan + execute browser tests
7. DECIDE F3: block-test.json có entries → run F3 OR skip
8. DECIDE F4: implement-required.json có pending → run F4 OR skip
9. F5 wf-e2e-retest (mandatory)
10. DECIDE F6: issues.json có open → run F6 với anti-loop max 3 vòng
11. F7 wf-e2e-scenario (default ON, Playwright)
12. F8 wf-e2e-demo (default ON, Playwright)
13. Finalize: orchestrator-summary.md + phase-summary.md tiếng Việt

**Pass criteria:**
- `test -f e2e-status.json` ✓
- `test -f orchestrator-summary.md` ✓
- `jq '.overall_status' e2e-status.json` ∈ `{success, partial}` ✓
- `jq '[.steps[] | select(.status=="completed" or .status=="skipped")] | length' e2e-status.json == 11` ✓
- `test -f phase-summary.md` ✓

### TC-ORCH-003 — Anti-loop F6↔F5 max 3 vòng

**Setup:**
- Feature có 1 issue không thể fix surgical (vd: requires architectural change)
- F6 fix fail 3 lần, F5 retest reveal lại issue mỗi lần

**Run:** `/wf-e2e-verify FEAT-EW-CRM-001 --auto`

**Expected behavior:**
1. F6 round 1 → fix attempt → F5 retest FAIL → `still_fail` counter increment
2. F6 round 2 → cùng issue → F5 retest FAIL
3. F6 round 3 → cùng issue → F5 retest FAIL → `still_fail` final
4. Orchestrator detect `f6_f5_loop_count = 3` → ESCALATE E004
5. AskUserQuestion: Continue / Skip / Cancel
6. Issue marked `status=still_fail`

**Pass criteria:**
- `jq '.anti_loop.f6_f5_loop_count' e2e-status.json == 3` ✓
- `grep 'E004' error-ledger.json` ✓
- `jq '.signals[] | select(.status=="still_fail") | length' issues.json >= 1` ✓

### TC-ORCH-004 — Legacy flags accept + WARN

**Run:** `/wf-e2e-verify FEAT-EW-CRM-001 --playwright-mcp --cross-module --parallel-safe`

**Expected behavior:**
- Display 3 DEPRECATION WARNINGS:
  - `--parallel-safe deprecated, always enabled`
  - `--cross-module deprecated, always enabled`
  - `--playwright-mcp deprecated, default ON`
- Track trong `e2e-status.json.legacy_flags_used`
- Run default F1→F8 chain (unchanged behavior)

**Pass criteria:**
- `jq '.legacy_flags_used | length' e2e-status.json >= 3`
- `jq '.legacy_flags_used[]' e2e-status.json` contains 'deprecated'
- Output contains 'DEPRECATION WARNINGS'

### TC-ORCH-006 — Resume mid-pipeline

**Setup:** Session đã có F1-F3 completed. F4 đang implement IMPL-REQ-002 thì user Ctrl+C. `status.json.current_step=F4`, sub-step `in_progress`.

**Run:** `/wf-e2e-verify FEAT-EW-CRM-001 --resume`

**Expected behavior:**
1. Resolve session → latest matching FEAT_ID
2. Acquire `.lock` (stale check, auto-release nếu >30 min)
3. Read `e2e-status.json` → find first incomplete step = F4
4. Re-validate F1-F3 outputs exist
5. Resume từ F4 (idempotent: skip IMPL-REQ-001 đã done, continue IMPL-REQ-002)
6. F4 done → continue F5 → F6 (conditional) → F7 → F8

**Pass criteria:**
- `jq '.steps.F1.status' e2e-status.json == "completed"` (không re-run)
- `jq '.steps.F4.status' e2e-status.json` eventually `"completed"`
- F1/F2/F3 outputs mtime KHÔNG đổi (không re-run)

### TC-ORCH-008 — `--no-playwright` deprecated

**Run:** `/wf-e2e-verify FEAT-EW-CRM-001 --no-playwright`

**Expected behavior:**
- `legacy-flags.md` detect `--no-playwright` → WARN deprecation, unset `NO_PLAYWRIGHT`
- F1 run normally
- F2 RUN (live browser, auto-start mandatory) — KHÔNG skip
- F3, F4 conditional, F5 run với Playwright BẮT BUỘC
- F6 conditional
- F7 RUN (auto-start mandatory) — KHÔNG skip
- F8 RUN (auto-start mandatory) — KHÔNG skip
- `legacy_flags_used` array chứa warning về `--no-playwright`

**Pass criteria:**
- `jq '.steps.F2.status' e2e-status.json != "skipped"`
- `jq '.steps.F7.status' e2e-status.json != "skipped"`
- `jq '.steps.F8.status' e2e-status.json != "skipped"`
- `jq '.legacy_flags_used | length' e2e-status.json >= 1`
- `jq -r '.legacy_flags_used[]' e2e-status.json | grep -q 'no-playwright.*DEPRECATED'`

---

## 3. Eval criteria

### Pass criteria (per test case)

| Criteria | Threshold |
|----------|-----------|
| POST-VERIFY T1-T4 PASS per step | 100% |
| `e2e-status.json` valid + tất cả steps có terminal status | 100% |
| `orchestrator-summary.md` exist với 5 sections | 100% |
| `phase-summary.md` tiếng Việt ≤15 dòng (CORE-028) | 100% |
| Anti-loop counter respect threshold | f6_f5 ≤3, f3_f2 ≤2 |
| Legacy flags tracked trong `legacy_flags_used[]` | 100% |
| Context budget | <80% (smoke), <90% (full pipeline) |

### Fail criteria (đỏ ngay)

| Criteria | Verdict |
|----------|---------|
| `e2e-status.json` missing `$schema` | FAIL |
| Sub-skill spawn fail without retry | FAIL |
| Anti-loop counter ignored (>3 vẫn chạy) | FAIL |
| Legacy flag breaking change (không silent accept) | FAIL |
| `--no-playwright` v7.1.0+ vẫn DEGRADE silent | FAIL |
| F0/F0a skipped | FAIL |
| `phase-summary.md` viết tiếng Anh | FAIL |

---

## 4. Coverage matrix

| | full | standalone | resume | legacy |
|---|------|-----------|--------|--------|
| **No skip** | TC-ORCH-001 | — | — | — |
| **Conditional skip** | TC-ORCH-002 | — | — | — |
| **Explicit --skip** | TC-ORCH-009 | — | — | — |
| **Anti-loop** | TC-ORCH-003 | — | — | — |
| **Status mode** | — | TC-ORCH-007 | — | — |
| **Resume mid** | — | — | TC-ORCH-006 | — |
| **Legacy 3-flag** | — | — | — | TC-ORCH-004 |
| **Legacy --fix** | — | TC-ORCH-005 | — | TC-ORCH-005 |
| **Deprecated --no-playwright** | — | — | — | TC-ORCH-008 |

---

## 5. Eval execution

```bash
# Chạy 1 test case
./.claude/scripts/audit/run-skill-evals.sh wf-e2e-verify --test-id=TC-ORCH-001

# Chạy tất cả 9 evals
./.claude/scripts/audit/run-skill-evals.sh wf-e2e-verify --all
```

---

## 6. Liên kết

- Eval schema: [`.claude/scripts/audit/EVAL-SCHEMA.md`](../../../.claude/scripts/audit/EVAL-SCHEMA.md)
- Eval source: [`.claude/skills/workflow/wf-e2e-verify/evals/evals.json`](../../../.claude/skills/workflow/wf-e2e-verify/evals/evals.json)
- Sub-skill evals: mỗi sub-skill có evals riêng (TC-001 đến TC-{N}-{skill})
- Standards: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) §7
- Review checklist: [`../../05-review-standards/wf-e2e-verify.md`](../../05-review-standards/wf-e2e-verify.md)
