# Phase 4: Signal Aggregation + Cross-Validation (ADR-OPT-04)

> Gom kết quả từ Phase 3 lanes → aggregate + dedup → cross-validate UX consistency.
> 8 checks chính + 2 CQG checks + accessibility audit — tối đa 3 iterations.

**PRE-GATE:**
- [ ] Phase 3 (`phase3-screen-groups.md`) POST-GATE PASS
- [ ] `ls .mc-data/docs/phase4-ux/*/*/screens-*.md` có ít nhất 1 file

**INPUT:**
- `.mc-data/docs/phase4-ux/design-system.md`
- `.mc-data/docs/phase4-ux/*/Navigation-*.md`
- `.mc-data/docs/phase4-ux/*/*/screens-*.md`
- `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md`
- `.mc-data/docs/phase2-features/**/*.md`

**OUTPUT:**
- Các file UX (auto-fix nếu cần)
- `.mc-data/work/wf-design-ux/cross-validation-report.md`
- `design-ux-status.json` → `cross_validation_log.iterations[]` populated

---

## Reference Sections

- `_shared.md` §_shared Module Imports (ADR-OPT Integration)
- `_shared.md` §Agent Prompt Templates → P4 (accessibility-auditor)
- `_shared.md` §Fix Rules đặc thù
- `protocols/` §Auto-Correction Loop Protocol (max 3 iterations)

---

## Validation Checks (8 chính + 2 CQG)

| # | Check | Mô tả | Khi FAIL → Auto-Fix |
|---|-------|-------|----------------------|
| 4.1 | Feature-Screen Coverage | Mỗi feature có UI → có ≥1 screen group | Tạo screen group stub từ feature spec |
| 4.2 | UI-ID Uniqueness | Tất cả UI-IDs unique, không duplicate | Đổi tên UI-ID trùng + update references |
| 4.3 | Navigation-Screen Sync | Tất cả screen groups → có entry trong Navigation files | Thêm entry vào Screen Group Registry |
| 4.4 | API Endpoint Validity | API endpoints trong screens → tồn tại trong api-contract.md | Sửa reference, thêm endpoint, hoặc DEFER High |
| 4.5 | Design Token Consistency | Tokens dùng nhất quán trong screens | Chuẩn hóa theo design-system.md |
| 4.6 | Permission Matrix Sync | Permission matrix trong Navigation khớp feature spec | Sync permission theo feature spec |
| 4.7 | Navigation-Screen Bidirectional | Mỗi screen group trong Navigation → có file screen group tương ứng | Tạo missing files hoặc xóa entry Navigation |
| 4.8 | Accessibility (WCAG) | Spawn `accessibility-auditor` (prompt P4) | Auto-fix theo suggestions (contrast, focus, ARIA) |
| **CQG-09.1** | All UI Features Covered | `features[].interface_type != api-only` → mỗi feature có ≥1 screen group | Tạo missing screen group stub |
| **CQG-09.2** | Design System Match | Colors/fonts trong screens match design-system.md | Chuẩn hóa theo design-system.md |

---

## Auto-Correction Loop

```
iteration = 0
MAX_ITERATIONS = 3
errors_remaining = 999

WHILE errors_remaining > 0 AND iteration < MAX_ITERATIONS:
  iteration += 1
  checks_result = {}
  errors_found = 0
  errors_fixed = 0
  
  FOR each check IN [4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, CQG-09.1, CQG-09.2]:
    result = run_check(check)
    
    IF result.status == "passed":
      checks_result[check] = "passed"
    ELSE:
      errors_found += 1
      fix_attempt = auto_fix(check, result.details)
      
      IF fix_attempt.success:
        checks_result[check] = "fixed"
        errors_fixed += 1
      ELSE:
        checks_result[check] = "failed"
  
  errors_remaining = errors_found - errors_fixed
  
  # Append iteration log vào design-ux-status.json
  append_iteration_log({
    iteration: iteration,
    timestamp: now(),
    checks: checks_result,
    errors_found: errors_found,
    errors_fixed: errors_fixed,
    errors_remaining: errors_remaining
  })
  
  IF errors_remaining == 0:
    BREAK (PASS)

IF errors_remaining > 0 AND iteration == MAX_ITERATIONS:
  → STOP, escalate with detailed report
```

---

## Check 4.4 Special Case: Missing api-contract.md

```
IF NOT test -f api-contract.md OR test file size < 50 bytes:
  # KHÔNG pass vacuously
  → Ghi DEFERRED finding:
    severity: High
    description: "api-contract-missing — không thể verify endpoint coverage"
    action: "Chạy /wf-design để hoàn thiện api-contract.md"
  → Tính là 1 error_remaining (không fix được tự động)
  → Phase 5 sẽ include finding này trong stakeholder review
```

---

## Iteration Log Format

Sau mỗi iteration, append vào `design-ux-status.json`:

```json
{
  "iteration": 1,
  "timestamp": "2026-04-19T10:00:00Z",
  "checks": {
    "4.1": "passed",
    "4.2": "passed",
    "4.3": "fixed",
    "4.4": "passed",
    "4.5": "passed",
    "4.6": "passed",
    "4.7": "passed",
    "4.8": "passed",
    "CQG-09.1": "passed",
    "CQG-09.2": "passed"
  },
  "errors_found": 1,
  "errors_fixed": 1,
  "errors_remaining": 0
}
```

---

## Cross-Validation Report

Sau iteration cuối (PASS hoặc MAX reached), tạo `.mc-data/work/wf-design-ux/cross-validation-report.md`:

```markdown
# Cross-Validation Report — wf-design-ux

## Tổng quan
- Total iterations: N
- Total checks: 10 (8 chính + 2 CQG)
- Total errors found: X
- Total errors fixed: Y
- Errors remaining: Z
- Status: PASSED / FAILED

## Iterations
[Expand từng iteration với checks result]

## Auto-Fixes Applied
- 4.3 Navigation-Screen Sync: thêm 2 entries vào Screen Group Registry (SYS-CRM)
- 4.8 Accessibility: fix contrast ratio cho button primary (#A1B2C3 → #B2C3D4)

## Deferred Findings (nếu có)
- 4.4 api-contract-missing: severity=High — chạy /wf-design

## Agents Spawned
- accessibility-auditor: 1 invocation (iteration 2)
```

---

## Steps (execution order)

| Step | Action | Verify |
|------|--------|--------|
| 4.0 | **Signal Aggregation (ADR-OPT-04):** Import `_shared/aggregate/aggregator.py`. `aggregate_lane_signals(lane_outputs=glob("$SESSION_DIR/lanes/*/signals.json"), dedup_key_fn=dedup_by_id("screen_id"))`. Output: WRITE `$SESSION_DIR/aggregation-result.json`. **Special handling:** reuse component cross-module → KHÔNG flag conflict — merge vào shared design system (Phase 1 revision nếu cần). Log: total lanes, total screens, duplicates found, merged-to-shared-design. | `test -s $SESSION_DIR/aggregation-result.json` |
| 4.0b | Init `iteration_log[]` trong `$SESSION_DIR/design-ux-status.json`. Input cross-val: kết hợp aggregation-result.json + screen group files + Navigation files. | Field ready |
| 4.1-4.10 | Run auto-correction loop (xem §Auto-Correction Loop) — input từ aggregation-result conflicts + screen files | errors_remaining = 0 OR max iterations |
| 4.11 | **LOG AGENTS** — append `accessibility-auditor` vào `$SESSION_DIR/design-ux-status.json` → `metrics.agents_spawned[]` | Agent logged |
| 4.12 | Tạo `.mc-data/work/wf-design-ux/cross-validation-report.md` tổng hợp tất cả iterations + aggregation summary | `test -s cross-validation-report.md` |
| 4.13 | **SAVE CHECKPOINT** — POPULATE (trigger=phase4_complete, position.current_phase=4, validation_state) → WRITE `$SESSION_DIR/checkpoint.json` | Checkpoint saved |

---

## POST-GATE

- [ ] `$SESSION_DIR/aggregation-result.json` tồn tại, non-empty, JSON hợp lệ (`jq -e '.' aggregation-result.json`)
- [ ] `screen_id` dedup đã chạy — không còn duplicate IDs trong aggregation-result
- [ ] Zero validation errors sau loop (tất cả 10 checks PASS hoặc DEFERRED high acceptable)
- [ ] `.mc-data/work/wf-design-ux/cross-validation-report.md` tồn tại, non-empty
- [ ] `iteration_log[]` trong `$SESSION_DIR/design-ux-status.json` có ít nhất 1 entry
- [ ] Checkpoint đã save tại `$SESSION_DIR/checkpoint.json`

**Next phase:** `phase5-review.md`

---

## Error Handling

- Iteration 3 vẫn còn Critical/High errors → STOP, escalate với báo cáo chi tiết
- accessibility-auditor timeout → skip check 4.8 cho iteration đó, retry iteration sau
- Regression sau auto-fix → rollback fix, log error, tiếp tục iteration
