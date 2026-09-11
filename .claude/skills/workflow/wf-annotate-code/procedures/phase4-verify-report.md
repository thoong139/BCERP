# Phase 4: Verify & Report

> Final phase — verify toàn bộ annotations, tính traceability after,
> tạo report, update ledger + status + session log + phase-summary.

**PRE-GATE:**
- [ ] Phase 3 POST-GATE PASS (`files_done + files_skipped + files_error == files_total`)
- [ ] **[BUG-07 fix]** `annotate-checkpoint.json` trigger gần nhất là `"batch_completed"`: `[ "$(jq -r '.trigger.reason' .mc-data/work/legacy-scan/annotate-checkpoint.json)" == "batch_completed" ]`
- [ ] `$TRACEABILITY_BEFORE` đã set trong memory (từ Phase 0)

**INPUT:**
- `.mc-data/work/legacy-scan/annotation-map.json` (user confirmed)
- `.mc-data/work/legacy-scan/annotate-status.json` (progress data)
- `.mc-data/work/legacy-scan/ledger.json`
- `.mc-data/work/legacy-scan/legacy-scan-status.json`

**OUTPUT:**
- `.mc-data/work/legacy-scan/annotation-report.md` (final report)
- `.mc-data/work/legacy-scan/ledger.json` (updated `stages.annotate`)
- `.mc-data/work/legacy-scan/legacy-scan-status.json` (updated `stages.annotate`)
- `.mc-data/work/legacy-scan/annotate-status.json` (finalized)
- `.mc-data/work/legacy-scan/annotate-plan.md` (marked all phases complete)
- `.mc-data/work/wf-annotate-code/phase-summary.md` (CORE-028)
- `.mc-data/work/_trace/session-log.json` (COMPLETE event)
- In-memory: `$TRACEABILITY_AFTER`

---

## Reference Sections

- `_shared.md` §Traceability Score (after calculation)
- `_shared.md` §State Variables Glossary

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4.1 | Count files annotated: `files_with_reqid_after = grep -rlE "(//\|#\|<!--\|/\*\|--)\s*REQ-ID:" <mapped directories> \| wc -l` | Bash | Count ≥ `files_done` |
| 4.2 | Spot-check format: với 5 files ngẫu nhiên từ map, verify comment đúng format theo language (Grep pattern) | Grep | Format correct |
| 4.3 | Verify không có file corrupt: nếu Phase 3 log `corrupt_rollbacks > 0` → include trong report, KHÔNG fail Phase 4 | — | Issues logged |
| 4.4 | Tính `$TRACEABILITY_AFTER` theo `_shared.md §Traceability Score` | Bash | Value calculated |
| 4.5 | **CHECK:** `$TRACEABILITY_AFTER > $TRACEABILITY_BEFORE`. Nếu không tăng → WARN, escalate user (có thể do annotations đã tồn tại từ trước → skip cao) | — | Trace check |
| 4.6 | **[READ-TEMPLATE]** READ `templates/annotation-report.md` → POPULATE summary, traceability score (before/after/delta), annotation statistics, module breakdown, errors (E041-E046 aggregated), files annotated (sample list, full list reference to annotation-map.json) → WRITE `.mc-data/work/legacy-scan/annotation-report.md` | Read → Write | Report created |
| 4.7 | Cập nhật `ledger.json`: `stages.annotate.status = "completed"`, `stages.annotate.files_annotated`, `stages.annotate.traceability_score`, `stages.annotate.completed_at = ISO_DATE` | Edit | Ledger updated |
| 4.8 | Cập nhật `legacy-scan-status.json`: `stages.annotate.status = "completed"`, `stages.annotate.completed_at = ISO_DATE` | Edit | Status file updated |
| 4.9 | Cập nhật `annotate-status.json`: `status = "completed"`, `progress_pct = 100`, `phases.phase_4.status = "completed"`, `annotation_stats` (final), `traceability_score` (before/after/delta), `completed_at` | Edit | Status finalized |
| 4.10 | Cập nhật `annotate-plan.md`: mark tất cả phases completed (✅), overall progress 100% | Edit | Plan finalized |
| 4.11 | **[CORE-028]** READ `.claude/doc-framework/_meta/phase-summary.template.md` → POPULATE summary cho tất cả phases (context, map building, review, injection, verification) theo phong cách tiếng Việt cho non-specialist (≤15 dòng) → WRITE `.mc-data/work/wf-annotate-code/phase-summary.md` | Read → Write | Phase summary created |
| 4.12 | **[CORE-026]** Append COMPLETE event vào `.mc-data/work/_trace/session-log.json`: `{ skill: "wf-annotate-code", event: "COMPLETE", stats: { files_annotated, traceability_before, traceability_after, modules_covered }, timestamp }` | Edit | Trace logged |
| 4.12b | **[ARCH-03 fix — Timing Check]** Kiểm tra `jq -r '.stages.plan_modules.status' legacy-scan-status.json`. Nếu = `"completed"` → đây là cảnh báo timing violation: wf-plan-modules đã chạy TRƯỚC khi annotation hoàn thành. Ghi flag `"annotation_completed_after_plan_modules": true` vào `legacy-scan-status.json.stages.annotate`. Hiển thị: "⚠️ wf-plan-modules đã chạy trước khi annotation hoàn thành. implementation_strategy trong task files có thể không chính xác. Khuyến nghị: chạy lại `/wf-plan-modules` để refresh." | Edit | Timing flag set |
| 4.13 | **CLEANUP:** Xoá `annotate-checkpoint.json` (không cần giữ sau khi completed) — TÙY chọn (user có thể giữ để audit) | Bash | Optional cleanup |

---

## Report Structure (Step 4.6)

```markdown
# Annotation Report — wf-annotate-code

> Generated: [ISO_DATE]
> Project: [project_name]
> Mode: [full | diverged_only | dry_run]

## Summary

| Metric | Value |
|--------|-------|
| Files annotated | [N] |
| Files skipped (already annotated) | [N] |
| Files skipped (deprecated modules) | [N] |
| Files skipped (unsupported language) | [N] |
| Files error | [N] |
| REQ-IDs injected (unique) | [N] |
| FEAT-IDs injected (unique) | [N] |
| Modules covered | [N] |
| Batches processed | [N] |

## Traceability Score

| Thời điểm | Files có REQ-ID | Tổng files | % |
|-----------|----------------|------------|---|
| Trước | [X] | [Y] | [Z%] |
| Sau | [X] | [Y] | [Z%] |
| Tăng | — | — | +[Δ%] |

## Module Breakdown

| Module | Files annotated | REQ-IDs | Status |
|--------|----------------|---------|--------|
| ... | ... | ... | completed |

## Errors (nếu có)

| Error Code | Count | Details |
|-----------|-------|---------|
| E041 (write fail) | 0 | — |
| E042 (corrupt rollback) | 0 | — |
| E045 (unsupported language) | 0 | — |
| E046 (annotation conflict) | 0 | — |

## Files Annotated (sample 20 đầu)

[Bảng 20 files đầu, toàn bộ tham chiếu annotation-map.json]

## Next Steps

- `/wf-design-ux [system-name]` (nếu có UI) HOẶC
- `/wf-plan-modules` (để xác định implementation order)
```

---

## POST-GATE

```bash
# 1. Output files tồn tại và non-empty
test -s .mc-data/work/legacy-scan/annotation-report.md
test -s .mc-data/work/legacy-scan/annotation-map.json
test -s .mc-data/work/legacy-scan/annotate-status.json
test -s .mc-data/work/legacy-scan/annotate-plan.md

# 2. JSON files valid
jq '.' .mc-data/work/legacy-scan/annotation-map.json > /dev/null 2>&1
jq '.' .mc-data/work/legacy-scan/annotate-status.json > /dev/null 2>&1

# 3. Ledger cập nhật
[ "$(jq -r '.stages.annotate.status' .mc-data/work/legacy-scan/ledger.json)" == "completed" ]

# 4. Shared pipeline status cập nhật
[ "$(jq -r '.stages.annotate.status' .mc-data/work/legacy-scan/legacy-scan-status.json)" == "completed" ]

# 5. Skill-specific status finalized
[ "$(jq -r '.status' .mc-data/work/legacy-scan/annotate-status.json)" == "completed" ]

# 6. Traceability tăng (WARN nếu không tăng — không block, có thể do skip cao)
AFTER=$(jq -r '.annotation_stats.traceability_score_after' .mc-data/work/legacy-scan/annotate-status.json)
BEFORE=$(jq -r '.annotation_stats.traceability_score_before' .mc-data/work/legacy-scan/annotate-status.json)
[ "$AFTER" -ge "$BEFORE" ] || echo "WARN: traceability score không tăng ($BEFORE% → $AFTER%) — có thể do nhiều files skip (đã annotated hoặc unsupported language)"

# 7. CORE-028: phase-summary.md exists
test -s .mc-data/work/wf-annotate-code/phase-summary.md

# 8. CORE-026: session-log.json có COMPLETE event cho wf-annotate-code
jq -e '.events | map(select(.skill == "wf-annotate-code" and .event == "COMPLETE")) | length > 0' \
  .mc-data/work/_trace/session-log.json
```

---

## Output Report (hiển thị user)

```
## /wf-annotate-code Hoàn tất!

| Mục | Giá trị |
|-----|---------|
| Files annotated | [count] |
| REQ-IDs injected | [count unique] |
| FEAT-IDs injected | [count unique] |
| Traceability score | [before]% → [after]% (+[Δ]%) |
| Modules covered | [count] |
| Batches processed | [count] |
| Errors | [count] |

Next: /wf-design-ux [system-name] (nếu có UI) hoặc /wf-plan-modules
```

---

## Completion

Sau khi POST-GATE pass:
- SKILL hoàn thành — KHÔNG có phase tiếp theo
- User chuyển sang skill successor theo workflow legacy path
