# Phase 2.7: UI Coverage Cross-Check (CHỈ LEGACY_MODE + có screens)

> So sánh UI screens thực tế với features đã defined.
> Phát hiện orphan screens không có feature spec tương ứng.

**PRE-GATE:**

```bash
# CHỈ chạy khi TẤT CẢ điều kiện sau đồng thời TRUE:
#   1. LEGACY_MODE = true (CORE-021)
#   2. inventory/ui-manifest.json tồn tại và non-empty
#   3. ui-manifest.total_screens > 0
test "$LEGACY_MODE" = "true"
test -f .mc-data/work/legacy-scan/project-context.md
test -f .mc-data/work/legacy-scan/inventory/ui-manifest.json
jq -e '.total_screens > 0' .mc-data/work/legacy-scan/inventory/ui-manifest.json
```

> Nếu BẤT KỲ điều kiện nào KHÔNG thỏa → SKIP phase này, tiếp tục `phase3-cross-validation.md`.
> Set `$HAS_SCREENS = false` và chuyển thẳng next phase.

> **(CORE-026)** Append START entry vào `.mc-data/work/_trace/session-log.json` (xem `_shared.md §Execution Trace Protocol`).

**INPUT:** `ui-manifest.json` + defined features (từ Phase 2)

**OUTPUT:** `.mc-data/work/wf-define-features/ui-coverage-gaps.json`

## Steps

| Step  | Action | Verify |
|-------|--------|--------|
| 2.7.1 | Đọc `ui-manifest.json` → build screen list với routes | Screen list loaded |
| 2.7.2 | Đọc defined features → extract screen/UI references từ feature specs | Feature refs collected |
| 2.7.3 | Cross-check: mỗi screen → tìm matching feature (exact/fuzzy) | Gaps identified |
| 2.7.4 | Phân loại: COVERED / INFRASTRUCTURE(skip) / GAP / AMBIGUOUS | Gaps classified |
| 2.7.5 | Nếu có GAP → tạo feature spec stub từ screen context (`status: stub`, sẽ được flesh-out sau bởi `/wf-define-features` khi re-run hoặc manual review) | Stubs created |
| 2.7.6 | Ghi `ui-coverage-gaps.json` từ template `.claude/skills/workflow/wf-define-features/templates/ui-coverage-gaps.json` (Template Usage Rule) | Report exists |

## Matching Logic

### Auto-skip list (infrastructure screens — KHÔNG đánh giá coverage)

```
layout.*, error.*, loading.*, not-found.*, default.*, template.*,
global-error.*, head.*, middleware.*,
_app.*, _document.*,
opengraph-image.*, sitemap.*, robots.*,
favicon.*, icon.*, apple-icon.*,
route.* (trong app/ nhưng là API route, KHÔNG phải screen)
```

### Exact match (confidence = 1.0)

- Screen route string == feature metadata route
- Screen filename (không extension) == feature slug
- Screen path xuất hiện nguyên vẹn trong feature `file` field

### Fuzzy match (threshold ≥ 0.7)

- `module_hint == module_id` VÀ ít nhất 1 keyword overlap > 60%
- Screen type xuất hiện trong feature description
- Minimum similarity score: 0.7 (dựa trên Jaccard similarity của normalized tokens)

### Conflict resolution

- Nếu >1 feature match cùng screen → đánh dấu `AMBIGUOUS`, KHÔNG auto-assign
- Agent `review_required = true` cho AMBIGUOUS entries

### Categories

| Category | Điều kiện |
|----------|-----------|
| COVERED | Screen có ≥1 matching feature (exact hoặc fuzzy ≥ 0.7) |
| INFRASTRUCTURE | Screen match auto-skip list → loại khỏi coverage calculation |
| GAP | Screen KHÔNG match feature nào VÀ không phải infrastructure |
| AMBIGUOUS | Screen match >1 feature → cần manual review |

**POST-GATE:**

```bash
test -f .mc-data/work/wf-define-features/ui-coverage-gaps.json
jq '.' .mc-data/work/wf-define-features/ui-coverage-gaps.json > /dev/null
jq -e '.coverage_stats.gaps >= 0' .mc-data/work/wf-define-features/ui-coverage-gaps.json

# T4: coverage_stats totals khớp actual screen counts
jq -e '.coverage_stats.covered + .coverage_stats.gaps + .coverage_stats.ambiguous + .coverage_stats.infrastructure_skipped == .total_screens' .mc-data/work/wf-define-features/ui-coverage-gaps.json
```

> **Phase 3 cross-validation interaction:** Stubs tạo ở Phase 2.7 có `status: "stub"`. Phase 3 cross-validation nên SKIP stubs hoặc validate với relaxed criteria (không check section completeness). Thêm rule vào Phase 3 check 3.4: "Nếu feature spec có status=stub → đánh dấu 'awaiting flesh-out', KHÔNG auto-fix."

> **(Protocol 6.6)** Nếu `$LARGE_PROJECT = true` → **SAVE CHECKPOINT** sau Phase 2.7.

**Status update:** `define-features-status.json` → `phase_2_7.status = "completed"` (hoặc "skipped"), `phase_2_7.completed_at = <ISO timestamp>`, `phase_2_7.ui_coverage_pct = <number>`.

### Khi Thất Bại

| Điều kiện | Hành động |
|-----------|----------|
| Retryable error (E003, E004) | Retry ≤ 3 lần, ghi error_log |
| Max retry reached | STOP + báo cáo → user quyết định |
| Non-retryable (E002) | STOP + dùng default scope |

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id, status, items_processed, key_findings, next_action
3. WRITE: `.mc-data/work/wf-define-features/phase-summary.md`

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json`.

**Next phase:** `phase3-cross-validation.md`
