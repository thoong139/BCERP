# Phase 5: Cross-Validation (AUTO-CORRECTION LOOP)

> Cũ Phase 6a. Kiểm tra nhất quán dữ liệu sync trước khi generate report.
> Phát hiện arithmetic/logic errors → auto-correction loop tối đa 3 iterations.

> **Protocol:** Xem `.claude/skills/protocols/` — Auto-Correction Loop Protocol.

**PRE-GATE:**
- Phase 2 (`phase2-analyze.md`) POST-GATE PASS
- `$SYNC_RATE` defined (number HOẶC null nếu E020)
- Nếu `$SYNC_RATE == null` (E020 triggered) → SKIP Phase 5 toàn bộ, set `$VALIDATION_REPORT = {skipped: true, reason: "E020_total_zero"}`, NEXT Phase 6
- `$W001_ANOMALIES` defined, `$W002_ANOMALIES` defined (có thể empty array)

**📥 INPUT:** In-memory state từ Phase 1-4: `$REQ_INDEX`, `$CODE_REFS`, `$ORPHAN_LIST`, `$SYNC_RATE`, `$COVERAGE_RATE`, `$W001_ANOMALIES`, `$W002_ANOMALIES`, `$GAPS_LIST`

**📤 OUTPUT:**
- `$VALIDATION_REPORT` (in-memory) — `{iterations_run, checks_passed, errors_found, errors_fixed, skipped, reason, validation_details: {5.1...5.10}}`
- `error_log[]` updated với errors detected (nếu có)

> Phase này KHÔNG tạo file. Output dùng cho Phase 6 report.
> **Lưu ý:** `$W001_ANOMALIES` và `$W002_ANOMALIES` được tính tại Phase 2 — KHÔNG tính lại ở đây.

---

## Reference Sections

- `_shared/protocols-fix-rules.md`
- `protocols/` §Auto-Correction Loop Protocol (max 3 iterations)
- `protocols/` §Content Quality Gate (CQG-12)

---

## Steps

> **v4.0+ S4:** 10 crossval checks delegated to `vs-validate.sh` cho token efficiency.
> Script chạy tất cả checks, output `validation-report.json`.

| Step | Action | Verify |
|------|--------|--------|
| 5.0 | **Bash delegation:** Chạy `bash .claude/scripts/wf-verify-sync/vs-validate.sh --analysis-results $SESSION_DIR/analysis-results.json --scan-results $SESSION_DIR/scan-results.json --registry .mc-data/docs/_meta/req-registry.json --output $SESSION_DIR/validation-report.json`. Nếu có `$FIX_IMPACT_CONTEXT` → pass `--fix-impact <path>`. Nếu có `$ADD_SCOPE_CONTEXT` → pass `--add-scope <path>`. Tương tự cho `--manage-change`, `--preflight`. | `test -s $SESSION_DIR/validation-report.json` |
| 5.1 | Đọc `$SESSION_DIR/validation-report.json` → set `$VALIDATION_REPORT`. Nếu `final_status == "escalted"` → render lỗi cho user, hỏi action (retry/skip/escalate). | `$VALIDATION_REPORT` loaded |

### vs-validate.sh — Input/Output

```
Input:  --analysis-results <path>   (output từ vs-analyze.sh)
        --scan-results <path>       (output từ vs-scan-code.sh)
        --registry <path>           (.mc-data/docs/_meta/req-registry.json)
        --output <path>
        --fix-impact <path>         (optional: fix-impact.json)
        --add-scope <path>          (optional: scope-impact.json)
        --manage-change <path>      (optional: change-impact.json)
        --preflight <path>          (optional: preflight-impact.json)
Output: validation-report.json:
        {iterations_run, max_iterations, checks_total, checks_passed,
         errors_found, errors_fixed, skipped, reason,
         validation_details: {"5.1": "passed", ...},
         fix_impact_xref: {checks_run, mismatches[], warnings[]},
         add_scope_xref, manage_change_xref, preflight_xref,
         final_status: "passed"|"escalated"|"skipped"}
Logic:  10 deterministic checks (5.1-5.10) + 4 conditional cross-skill checks
        (5.11-5.14). Max 3 iterations auto-correction loop. If errors not
        decreasing → E041 circular regression.
```

## Validation Checks (10 checks — chạy bởi vs-validate.sh)

> Dưới đây là chi tiết từng check cho reference. AI Agent không chạy inline — đọc `validation-report.json`.

### Core checks (5.1-5.6)

| Check | Action | Verify |
|-------|--------|--------|
| 5.1 | **Arithmetic sum check:** Verify `implemented_count + in_progress_count + not_started_count + W001_count + W002_count == Total REQ-IDs` (Total đã loại trừ skipped). Đây là pure arithmetic verification. `implemented_count` = done + có code (KHÔNG bao gồm W001, KHÔNG bao gồm W003). `in_progress_count` = in_progress + có code, bao gồm W003 (KHÔNG bao gồm W002 — W002 là in_progress TRONG REGISTRY nhưng KHÔNG có code, nên không thuộc in_progress_count). `W002_count` là REQ-IDs có impl_status="in_progress" nhưng không có code — được tính riêng. | Arithmetic correct |
| 5.2 | Verify: orphan code list KHÔNG overlap với implemented REQ-ID list | No overlaps |
| 5.3 | Verify: tất cả REQ-IDs trong `$REQ_INDEX` match pattern chuẩn (`REQ-[A-Z]+-\d+` hoặc `REQ-[A-Z]+-[A-Z]+-\d+`) | Format valid |
| 5.4 | Verify: KHÔNG có REQ-ID duplicates trong `$CODE_REFS` (1 REQ-ID không xuất hiện 2 lần trong cùng 1 file) | No duplicates |
| 5.5 | Verify: tất cả referenced source files trong `$CODE_REFS` tồn tại trên disk | Files exist |
| 5.6 | Verify: status values nhất quán — không "done" trong `$GAPS_LIST` (Missing/Partial), không "pending" trong covered list | Status consistent |

### Content Quality Gate (CQG-12) — Protocol 8

> Verify sync_rate tính đúng và gap list đầy đủ — ngăn chặn report sai lệch.

| Check | Action | Verify |
|-------|--------|--------|
| 5.7 | **Sync rate accuracy:** Verify `$SYNC_RATE = (implemented_count / total_req_ids) × 100` — tính lại từ raw data, so sánh với value đã set ở Phase 2. **`implemented_count` = REQ-IDs có `impl_status="done"` VÀ code scan tìm thấy (KHÔNG bao gồm W001 — W001 là done trong registry nhưng KHÔNG có code).** `total_req_ids` = Total đã loại trừ skipped, W001 KHÔNG bị loại. Ví dụ: 10 REQ-IDs, 0 skipped, 1 W001 → total = 10, implemented = 6 (done+code only), sync_rate = 6/10 = 60%. | Recalculated == reported |
| 5.8 | **Gap list membership check (per-item assertion):** Với mỗi REQ-ID trong `$REQ_INDEX` có status `not_started` — verify REQ-ID đó CÓ entry trong `$GAPS_LIST` với `type="missing_implementation"`. Với mỗi REQ-ID có status `in_progress` (có code) — verify CÓ entry với `type="partial_implementation"`. **Đây là per-item check, KHÔNG phải arithmetic count.** Phát hiện: REQ-ID bị drop khỏi GAPS_LIST trong khi count vẫn balance. | No missing entries (per-item verified) |
| 5.9 | **Orphan list accuracy:** Mọi file trong `$ORPHAN_LIST` THỰC SỰ không chứa REQ-ID (re-scan verify per file) | All orphans confirmed |
| 5.10 | **Independent recalculation (REQ-ID accounting only):** Tính lại từ raw data — không dùng cached counts. Lấy riêng: `missing_impl_count = count($GAPS_LIST where type="missing_implementation")`, `partial_impl_count = count($GAPS_LIST where type="partial_implementation" AND w002 != true)`. Verify: `missing_impl_count + partial_impl_count + implemented_count + W001_count + W002_count == total_req_ids`. **Orphan files KHÔNG được đưa vào công thức này** — orphan là source files, không phải REQ-IDs. Nếu khác → có REQ-ID bị mất hoặc double-count. | Recalculated matches (REQ-IDs only, excluding orphans) |

### Cross-FEAT REQ-ID Validation (CF6 — v8.0.0, wf-e2e-batch)

> **Conditional:** Chỉ chạy khi `requirements[].cross_feat_refs[]` tồn tại trong registry. Mục đích: phát hiện broken cross-FEAT references và circular dependencies giữa các FEATs.
> **Severity:** Mismatch → WARNING (không block verify-sync). Cycle → CRITICAL (block completion).

| Check | Action | Verify |
|-------|--------|--------|
| 5.CF6a | **Cross-FEAT REQ-ID existence:** Đọc tất cả `requirements[].cross_feat_refs[].target_req_id` từ registry. Validate từng `target_req_id` tồn tại trong `requirements[]`. Validate `target_feat_id` tồn tại trong `features[]`. Mismatch → log WARNING với code W-CF6-001, thêm vào report warnings. KHÔNG block. | All target_req_id/feat_id tồn tại hoặc warnings logged |
| 5.CF6b | **Consume-relationship impl_status check:** Với mỗi cross_feat_ref có `relationship="consume"` → validate `target.impl_status = "done"`. Nếu target là `not_started` hoặc `in_progress` → log WARNING W-CF6-002: "FEAT X consume REQ Y nhưng Y chưa implement". Gợi ý: implement Y trước hoặc cập nhật relationship type. | All consume targets done hoặc warnings logged |
| 5.CF6c | **Cross-FEAT cycle detection:** Build directed graph từ tất cả cross_feat_refs (A → B = A phụ thuộc B). Chạy DFS detect cycles (A → B → C → A). Cycle → CRITICAL, log E057, đưa vào `$VALIDATION_REPORT.cross_feat_cycles`. Block verify-sync completion cho đến khi user resolve. | No cycles hoặc E057 escalate |

**Fix Rules:**
- `W-CF6-001` (target không tồn tại) → log warning + display trong Phase 6 report, KHÔNG auto-fix
- `W-CF6-002` (consume target chưa done) → log warning + recommend implement target first
- E057 (cycle) → CRITICAL, block Phase 6 — yêu cầu user fix circular references trước

---

### Cross-Skill Integration (v2.1+ S9 — `--from-fix-bugs`)

> **Conditional:** Chỉ chạy khi `$FIX_IMPACT_CONTEXT != null` (user pass `--from-fix-bugs` ở Phase 0). Mục đích: verify mọi `affected_artifacts.registry_changes[]` từ wf-fix-bugs đã apply đúng vào `req-registry.json` hiện tại.

| Check | Action | Verify |
|-------|--------|--------|
| 5.11 | **Fix-Impact registry_changes cross-check (conditional):** IF `$FIX_IMPACT_CONTEXT == null` → SKIP (set `5.11_fix_impact_xref = "skipped"`). ELSE: lấy `$CHANGES = $FIX_IMPACT_CONTEXT.affected_artifacts.registry_changes[]`. Cho mỗi change: (a) verify `req_id` tồn tại trong `req-registry.json` requirements[].id — nếu không → ERROR `req_id_missing` (REQ-ID claimed nhưng không trong registry); (b) verify field hiện tại match `change.after`: `CURRENT=$(jq -r --arg id "$req_id" '.requirements[] \| select(.id==$id) \| .[$change.field]' registry.json)`. Nếu `CURRENT != change.after` → ERROR `change_not_applied` (fix-impact claims `before→after` nhưng registry không khớp); (c) accumulate: `$VALIDATION_REPORT.fix_impact_xref = {checks_run, mismatches[]}`. **Fix Rules:** `req_id_missing` → log warning, KHÔNG auto-fix (registry là SSOT — fix-impact có thể stale). `change_not_applied` → log warning + recommend user re-run wf-fix-bugs hoặc manual update. NEVER auto-modify registry từ check này. | All registry_changes verified hoặc warnings logged |

---

## Auto-Correction Loop

```
iteration = 0
max_iterations = 3
errors_total = 0
errors_fixed = 0
prev_error_count = 9999  // sentinel giá trị lớn

WHILE iteration < max_iterations:
  iteration += 1
  errors_in_iter = []

  RUN tất cả 10 checks (5.1 → 5.10)
  COLLECT errors vào errors_in_iter

  IF errors_in_iter empty:
    → BREAK (validation passed)

  errors_total += len(errors_in_iter)

  // Early-stop: nếu error count không giảm sau iteration đầu → có circular regression
  IF iteration > 1 AND len(errors_in_iter) >= prev_error_count:
    → STOP ngay: "Lỗi không giảm sau iteration [N] (trước: [prev_error_count], hiện tại: [len(errors_in_iter)]).
       Có thể có circular regression. Escalate ngay."
    → E051 (circular regression) với error_log đầy đủ → BREAK

  prev_error_count = len(errors_in_iter)

  FOR mỗi error trong errors_in_iter:
    Lookup Fix Rule (xem `_shared/protocols-fix-rules.md`):
      - arithmetic_error  → Recalculate $SYNC_RATE từ raw data (dùng implemented_count, KHÔNG dùng done_count)
      - overlap_detection → Remove duplicate entries từ $ORPHAN_LIST
      - invalid_req_format → Fix format trong $REQ_INDEX (best-effort)
      - duplicate_id      → Merge/dedupe trong $CODE_REFS
      - missing_file      → Mark as gap trong $GAPS_LIST (expected)
      - stale_status      → Re-scan code file (single file)
      - membership_missing → Add missing REQ-ID entry vào $GAPS_LIST (check 5.8 fix)
      - orphan_in_formula  → Re-tính check 5.10 với filter type="missing_implementation" only

    APPLY fix → errors_fixed += 1
    LOG vào error_log[]

  // Tiếp tục iteration kế

IF iteration == max_iterations AND errors_in_iter NOT empty:
  → STOP với E050 (crossval iteration limit exceeded)
  → Escalate to user với báo cáo chi tiết error_log[]
```

---

## Validation Report Schema

```json
{
  "iterations_run": "1-3 | 0 nếu skipped",
  "max_iterations": 3,
  "checks_total": "10 | 0 nếu skipped",
  "checks_passed": "0-10 | 0 nếu skipped",
  "errors_found": 0,
  "errors_fixed": 0,
  "skipped": "false | true (khi E020 Total==0)",
  "reason": "null | 'E020_total_zero'",
  "validation_details": {
    "5.1_arithmetic": "passed | failed | fixed | skipped",
    "5.2_no_overlaps": "passed | failed | fixed | skipped",
    "5.3_format_valid": "passed | failed | fixed | skipped",
    "5.4_no_duplicates": "passed | failed | fixed | skipped",
    "5.5_files_exist": "passed | failed | fixed | skipped",
    "5.6_status_consistent": "passed | failed | fixed | skipped",
    "5.7_sync_rate_accuracy_implemented_count": "passed | failed | fixed | skipped",
    "5.8_gap_membership_per_item": "passed | failed | fixed | skipped",
    "5.9_orphan_accuracy": "passed | failed | fixed | skipped",
    "5.10_req_id_accounting_excluding_orphans": "passed | failed | fixed | skipped",
    "5.11_fix_impact_xref": "passed | failed | warning | skipped"
  },
  "fix_impact_xref": {
    "checks_run": 0,
    "mismatches": [],
    "warnings": []
  },
  "final_status": "passed | escalated | skipped"
}
```

> `fix_impact_xref` chỉ populate khi check 5.11 chạy (`$FIX_IMPACT_CONTEXT != null`). Schema:
> - `checks_run`: số registry_changes verified
> - `mismatches`: array `{req_id, field, expected_after, actual_current, error_type}`
> - `warnings`: array string (recommend actions)

---

**POST-GATE:**
- Zero arithmetic/logic errors sau auto-correction loop, HOẶC `final_status="escalated"` đã được user xử lý
- `$VALIDATION_REPORT` defined với `iterations_run >= 1`
- Cập nhật `verify-sync-status.json`: `phases.phase_5.status="completed"`, `phases.phase_5.iterations_run`, `phases.phase_5.checks_passed`, `phases.phase_5.validation_details.*`

**NEXT:** Load `phase6-report.md`.
