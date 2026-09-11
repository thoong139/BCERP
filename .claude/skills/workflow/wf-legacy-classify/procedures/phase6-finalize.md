# Phase 6: Finalize — Ledger Update + Report + Phase Summary

> Cập nhật ledger.json (`stages.classify.status = "completed"`), legacy-scan-status.json
> (`current_stage = "extract"`), tạo phase-summary.md (CORE-028), hiển thị CLASSIFY COMPLETED report.

**PRE-GATE:**
- Phase 5 POST-GATE PASS (glossary, coverage, batch files, naming consistency OK)
- Có ít nhất 1 file `classified/batch-*.json` valid

**INPUT:**
- `.mc-data/work/legacy-scan/ledger.json`
- `.mc-data/work/legacy-scan/legacy-scan-status.json`
- `.mc-data/work/legacy-scan/classified/batch-*.json` (cho metrics)
- `.mc-data/work/legacy-scan/classified/glossary.json` (cho metrics)

**OUTPUT:**
- `.mc-data/work/legacy-scan/ledger.json` (updated: `stages.classify.status = "completed"` + summary fields)
- `.mc-data/work/legacy-scan/legacy-scan-status.json` (updated: `current_stage = "extract"`, `next_action = "Stage 3: Extract"`)
- `.mc-data/work/wf-legacy-classify/phase-summary.md` (CORE-028 — tiếng Việt, <=15 dòng)
- Console: CLASSIFY COMPLETED report

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `00-core.md` §CORE-006 Registry Safe-Write
- `00-core.md` §CORE-028 Phase Summary

---

## Steps

### 6.1 — Compute Final Metrics

```
total_batches = count(classified/batch-*.json valid)
items_classified = sum(jq '.stats.total' classified/batch-*.json)
total_items = ledger.summary.total_items
percentage = round(items_classified / total_items * 100, 1)

systems_detected = jq -r '.items[].system' classified/batch-*.json | sort -u | length
modules_detected = jq -r '.items[].module' classified/batch-*.json | sort -u | length

categories = {
  for category in [screen, api, doc, source, config, test, asset, migration, type]:
    count = sum(jq '.stats.by_category."'category'" // 0' classified/batch-*.json)
}

glossary_terms = jq '.stats.total_terms' classified/glossary.json
glossary_abbr = jq '.stats.total_abbreviations' classified/glossary.json
glossary_concepts = jq '.stats.total_domain_concepts' classified/glossary.json

errors = length(error_log[])
```

### 6.2 — Update ledger.json (Atomic Write)

```
READ ledger.json (fresh read, KHÔNG cache)
MODIFY chỉ các fields:
  stages.classify.status = "completed"
  stages.classify.completed_at = ISO_NOW
  stages.classify.completed_batches = total_batches
  stages.classify.items_classified = items_classified
  summary.items_classified = items_classified
  summary.by_stage.classified = items_classified
  summary.systems_detected = systems_detected
  summary.modules_detected = modules_detected
GIỮ NGUYEN tất cả fields khác
WRITE ledger.json (atomic — single Write operation)
VALIDATE: jq '.' ledger.json
VALIDATE: jq -e '.stages.classify.status == "completed"' ledger.json
```

### 6.3 — Update legacy-scan-status.json

```
READ legacy-scan-status.json
MODIFY:
  stages.classify.status = "completed"
  stages.classify.completed_at = ISO_NOW
  stages.classify.completed_batches = total_batches
  stages.classify.items_classified = items_classified
  current_stage = "extract"
  next_action = "Stage 3: Extract — chạy /wf-legacy-extract"
WRITE legacy-scan-status.json
```

### 6.3b — [PHASE D] Update scan-state.layers.L4 → completed

```
# Mark L4 Classification completed qua helper (state-machine enforced)
update_layer_status("L4", "completed")

# Defensive: nếu helper throw (missing session), log WARNING và tiếp tục —
# sub-skill đã ghi xong output files; không block user vì helper failure.
```

Xem `_shared.md §Scan-State Integration` cho chi tiết helper.

### 6.4 — Tạo phase-summary.md (CORE-028)

```
mkdir -p .mc-data/work/wf-legacy-classify/

WRITE .mc-data/work/wf-legacy-classify/phase-summary.md:

# Phase Summary — wf-legacy-classify

> Tóm tắt cho người không chuyên — kết quả phân loại files từ inventory.

## Kết quả

- **Dự án:** [project_name]
- **Tổng files đã phân loại:** [items_classified] / [total_items] ([percentage]%)
- **Số batches:** [total_batches] (mỗi batch [batch_size] files)
- **Systems phát hiện:** [systems_detected] — [list 5 đầu]
- **Modules phát hiện:** [modules_detected] — [list 5 đầu]
- **Glossary:** [glossary_terms] thuật ngữ + [glossary_abbr] viết tắt + [glossary_concepts] khái niệm domain

## Trạng thái

- **Mode:** [maturity_mode]
- **Naming fixes (CORE-016):** [count_naming_fixes] (xem classify-naming-fixes.json nếu có)
- **Errors:** [errors_count] (chi tiết: error_log trong legacy-scan-status.json)

## Bước tiếp theo

Chạy `/wf-legacy-extract` để trích xuất requirements/features từ classified data.

---

(Tự động tạo bởi /wf-legacy-classify v2.0.0 lúc [ISO_NOW])
```

> **Lưu ý:** phase-summary.md PHẢI <= 15 dòng nội dung chính (không tính header/footer markdown).

### 6.5 — Hiển thị CLASSIFY COMPLETED Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CLASSIFY COMPLETED — [project_name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Batches:     [total_batches] ([batch_size] items/batch)
Items:       [items_classified]/[total_items] ([percentage]%)
Systems:     [systems_detected] — [list]
Modules:     [modules_detected] — [list]
Glossary:    [total_glossary_entries] entries
Duration:    [started_at] → [completed_at]
Errors:      [errors_count]

Naming fixes (CORE-016): [count_naming_fixes]

Next step: /wf-legacy-extract
```

---

## Phase 6 POST-GATE

```
1. jq -e '.stages.classify.status == "completed"' ledger.json
2. jq -e '.stages.classify.items_classified > 0' ledger.json
3. jq -e '.summary.systems_detected > 0' ledger.json
4. jq -e '.current_stage == "extract"' legacy-scan-status.json
5. test -s .mc-data/work/wf-legacy-classify/phase-summary.md (file non-empty, <= 15 dòng nội dung)
6. CLASSIFY COMPLETED report đã hiển thị
7. [PHASE D] scan-state.layers.L4.status == "completed"
   (nếu scan-state.json tồn tại — best-effort check, không block nếu file missing)
```

---

## Special Cases

### Skip Mode (đã handle trong Phase 0)

```
Phase 0 đã set ledger.stages.classify.status = "completed" với note "skipped_maturity"
Phase 6 KHÔNG được gọi trong skip mode
```

Nếu vô tình route đến Phase 6 với skip mode → SKIP các updates, chỉ tạo phase-summary với note "skipped_maturity":

```
# Phase Summary — wf-legacy-classify

> CLASSIFY SKIPPED — maturity_level = [maturity_level], không cần phân loại files.

## Lý do

Dự án này có maturity level [maturity_level] (vd: DOCS_ONLY hoặc EARLY_PROTOTYPE),
classify stage được đánh dấu skip trong ledger.maturity.stage_modes.classify.

## Bước tiếp theo

Chạy `/wf-legacy-extract` để tiếp tục pipeline.
```

---

## Error Handling

| Tình huống | Xử lý |
|-----------|-------|
| Ledger write fail (disk full, permission) | Retry 3 lần, sau đó escalate |
| JSON parse error sau write | Rollback, re-read backup, retry |
| phase-summary > 15 dòng nội dung | Truncate, log WARNING |

---

**END OF SKILL** — User sẽ chạy `/wf-legacy-extract` tiếp theo.
