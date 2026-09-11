# Phase 2.5: Create feat-mapping.json (CHỈ LEGACY_MODE)

> Map FEAT-ID → { title, module, system, doc_path } cho downstream legacy tools.

**PRE-GATE:**

```bash
# Chỉ chạy nếu LEGACY_MODE = true
test "$LEGACY_MODE" = "true"
# Phase 2 đã xong
```

> Nếu `$LEGACY_MODE = false` → SKIP phase này, chuyển thẳng `phase3-cross-validation.md`.

> **(CORE-026)** Append START entry vào `.mc-data/work/_trace/session-log.json` (xem `_shared.md §Execution Trace Protocol`).

**INPUT:** Feature specs từ Phase 2 (`.mc-data/docs/phase2-features/**/*.md`)

**OUTPUT:** `.mc-data/work/legacy-scan/feat-mapping.json`

## Steps

| Step  | Action | Verify |
|-------|--------|--------|
| 2.5.1 | Đọc tất cả feature specs vừa tạo ở Phase 2 (loại trừ stakeholder-review.md và _index.md) | Specs loaded |
| 2.5.2 | Tạo mapping JSON: per FEAT-ID → `{ title, module, system, doc_path }`. Extract từ metadata blockquotes + frontmatter trong mỗi feature file. Nếu phải parallel (nhiều modules, LPM mode): dispatch lane per module với `lane_key="{module-slug}-mapping"` — mỗi lane ghi `$SESSION_DIR/lanes/{module-slug}-mapping/signals.json`, aggregate sau. | Mapping built |
| 2.5.3 | Write `.mc-data/work/legacy-scan/feat-mapping.json` (ATOMIC write — xem `_shared/_shared.md §2`, validate `jq '.'` trước khi finalize) | File created |

**POST-GATE:**

```bash
test -f .mc-data/work/legacy-scan/feat-mapping.json
jq '. | length' .mc-data/work/legacy-scan/feat-mapping.json  # > 0
jq '.' .mc-data/work/legacy-scan/feat-mapping.json > /dev/null  # valid JSON

# T4: FEAT-IDs trong feat-mapping khớp $FEAT_IDS
jq '.[].id' .mc-data/work/legacy-scan/feat-mapping.json | wc -l
```

> **(Protocol 6.6)** Nếu `$LARGE_PROJECT = true` → **SAVE CHECKPOINT** sau Phase 2.5.

**Status update:** `define-features-status.json` → `phase_2_5.status = "completed"`, `phase_2_5.completed_at = <ISO timestamp>`.

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

**Next phase:**

```bash
# Check $HAS_SCREENS TRƯỚC KHI branch — set và persist vào session-state.json
if [ -f .mc-data/work/legacy-scan/inventory/ui-manifest.json ] && \
   jq -e '.total_screens > 0' .mc-data/work/legacy-scan/inventory/ui-manifest.json > /dev/null 2>&1; then
  HAS_SCREENS=true
else
  HAS_SCREENS=false
fi
# Persist: jq ".flags.has_screens = $HAS_SCREENS" $SESSION_DIR/session-state.json > tmp && mv tmp $SESSION_DIR/session-state.json
```

- Nếu `$HAS_SCREENS = true` → `phase2.7-ui-coverage.md`
- Nếu `$HAS_SCREENS = false` → `phase3-cross-validation.md` (skip phase2.7)
