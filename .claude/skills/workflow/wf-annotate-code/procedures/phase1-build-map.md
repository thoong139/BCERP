# Phase 1: Build Annotation Map

> Scan code trong mapped directories, match với feature entities/endpoints/components,
> build annotation map từ registry + gap report. **Không chỉnh sửa code** trong phase này.

**PRE-GATE:**
- [ ] Phase 0 POST-GATE PASS (annotate-status.json, annotate-plan.md, annotate-checkpoint.json tồn tại)
- [ ] `$LEGACY_MODE`, `$MODULE_FILTER`, `$DEPRECATED_MODULES`, `$TECH_STACK` đã set trong memory
- [ ] `$ANNOTATION_MODE` ∈ `{"full", "diverged_only"}` (nếu `"skipped"` thì skill đã exit ở Phase 0)
- [ ] Nếu `$ANNOTATION_MODE = "diverged_only"` → `gap-categories.json` phải đã được kiểm tra ở Phase 0 Mode Check (không cần re-check ở đây)

**INPUT:**
- `$ANNOTATION_MAP` (chưa build — sẽ populate ở phase này)
- `req-registry.json` (features[], requirements[])
- `module-code-mapping.json` (module → code directories)
- `gap-report.md` (annotation gaps section)
- `$DEPRECATED_MODULES` (loại)
- `$MODULE_FILTER` (nếu có)
- Source code files trong mapped directories

**OUTPUT:**
- `.mc-data/work/legacy-scan/annotation-map.json`
- In-memory: `$ANNOTATION_MAP`

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §LEGACY Decisions Filter
- `_shared.md` §Comment Format Table (để validate file extension supported)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | Từ registry: extract danh sách features (ưu tiên `impl_status ∈ {"done", "in_progress"}`, fallback tất cả nếu trống) | jq | Features loaded, count > 0 |
| 1.2 | Từ `module-code-mapping.json`: extract danh sách `{module_id → code_directories[]}` | jq | Mappings loaded |
| 1.3 | **[FILTER 1 — DEPRECATE]** Loại module thuộc `$DEPRECATED_MODULES` khỏi danh sách. Log: `"Skipped annotation for deprecated modules: [list]"` | — | Deprecated filtered |
| 1.4 | **[FILTER 2 — MODULE_FILTER]** Nếu `$MODULE_FILTER` set: chỉ giữ module đó | — | Filter applied |
| 1.5 | Cho mỗi feature còn lại: đọc `phase2-features/[sys]/[mod]/[feat].md` → extract entity names, endpoint paths, component names, service names | Read | Entities extracted per feature |
| 1.6 | Scan code project trong mapped directories (từ Step 1.2): dùng Grep/Glob tìm files match entity/endpoint/component names từ Step 1.5. Limit theo `$TECH_STACK.file_extensions` (tránh false-positive config/doc files) | Grep/Glob | Candidate files identified |
| 1.7 | Cross-ref với gap-report: ưu tiên files thuộc "Annotation Gaps" section (confidence cao hơn) | Grep | Gap files prioritized |
| 1.8 | **[ANNOTATION_MODE]** Nếu `$ANNOTATION_MODE = "diverged_only"`: đọc `gap-categories.json` → filter chỉ giữ files có `status = "diverged"`. Nếu gap-categories.json valid nhưng rỗng (0 diverged entries) → WARN, set `$ANNOTATION_MODE = "full"` (fallback) và tiếp tục với full scan | jq | Mode filter applied |
| 1.9 | Build annotation map entries: `{ file_path, req_ids[], feat_id, confidence, module, language }`. Rule mapping: 1 feature → N files match; 1 file có thể mapped tới nhiều features (join req_ids[]). Soft limit: nếu 1 file match >5 REQ-IDs → downgrade confidence sang `"low"` (cardinality guard — files match quá nhiều features thường là base classes/utilities, annotation noise) | — | Map built |
| 1.10 | **[LANGUAGE FILTER]** Loại file có extension không match `_shared.md §Comment Format Table`. Log `E045` cho mỗi file skipped | — | Unsupported filtered |
| 1.11 | Calculate confidence per entry: `high` (exact entity name + path match), `medium` (entity match only), `low` (heuristic/partial) | — | Confidence set |
| 1.12 | GHI `.mc-data/work/legacy-scan/annotation-map.json` với schema: `{ generated_at, total_entries, entries: [...], skipped_deprecated_modules: [...], skipped_unsupported_languages: [...] }` | Write | File valid JSON |
| 1.13 | Cập nhật `annotate-status.json`: `phases.phase_1.status = "completed"`, `phases.phase_1.stats = { total_entries, modules_covered, avg_confidence }` | Edit | Status updated |

---

## Phase 1 Context Checkpoint (ARCH-04 fix)

Phase 1 không có batch mechanism như Phase 3, nhưng với dự án có >100 features, việc đọc toàn bộ feature files (Step 1.5) có thể gây context overflow. **Intermediate flush** sau mỗi N features:

```
PARTIAL_MAP = []
FEATURES_PROCESSED = 0
FLUSH_INTERVAL = 30  # flush annotation-map.json sau mỗi 30 features

FOR each feature IN feature_list:
  ... (Steps 1.5-1.11 per feature) ...
  FEATURES_PROCESSED++
  PARTIAL_MAP.append(entries from this feature)
  
  IF FEATURES_PROCESSED % FLUSH_INTERVAL == 0:
    # Flush partial map — cho phép resume nếu context interrupt
    GHI .mc-data/work/legacy-scan/annotation-map.json (partial, overwrite)
    Update annotate-status.json: phases.phase_1.features_processed = FEATURES_PROCESSED
    
    IF $CONTEXT_PERCENT >= 80%:
      WARN: "⚠️ Context threshold reached trong Phase 1 ($CONTEXT_PERCENT%).
             Đã xử lý $FEATURES_PROCESSED/$TOTAL_FEATURES features.
             Đang flush partial annotation-map.json.
             Chạy /wf-annotate-code --resume để tiếp tục từ feature $FEATURES_PROCESSED."
      Ghi annotate-checkpoint.json: position.current_phase="phase_1", phases_completed=["phase_0"]
      STOP
```

> **Resume từ Phase 1:** Khi `--resume` và checkpoint `position.current_phase = "phase_1"`, đọc partial `annotation-map.json` → tiếp tục từ `phases_processed` đến hết.

## Empty Map Handling (E040)

Nếu annotation map có 0 entries sau Step 1.12:

```
WARN: "Annotation map rỗng — không tìm thấy code files match features."
AskUserQuestion:
  (a) Provide manual mapping (user upload custom annotation-map.json)
  (b) Skip annotation — update status=skipped, reason=empty_map
  (c) Re-run với --module khác

IF user chọn (a): Read custom map → validate schema → lưu → tiếp tục Phase 2
IF user chọn (b) or (c): STOP skill phù hợp
```

---

## Annotation Map Schema

```json
{
  "$schema": "annotation-map-v1",
  "generated_at": "ISO_DATE",
  "generator": "wf-annotate-code Phase 1",
  "project_module_filter": "customer-management | null",
  "annotation_mode": "full | diverged_only",
  "total_entries": 147,
  "modules_covered": ["customer-management", "order-processing", "..."],
  "skipped_deprecated_modules": ["legacy-reporting"],
  "skipped_unsupported_languages": [
    { "file_path": "...", "extension": ".ftl" }
  ],
  "entries": [
    {
      "file_path": "src/Services/CustomerService.cs",
      "language": "csharp",
      "req_ids": ["REQ-SALES-001", "REQ-SALES-002"],
      "feat_id": "FEAT-ERP-CRM-001",
      "confidence": "high",
      "module": "customer-management",
      "matched_by": ["entity:Customer", "endpoint:/api/customers"]
    }
  ]
}
```

---

## POST-GATE

```bash
# T1: File tồn tại
test -s .mc-data/work/legacy-scan/annotation-map.json

# T2: Valid JSON
jq '.' .mc-data/work/legacy-scan/annotation-map.json > /dev/null 2>&1

# T3: Schema valid
jq -e '.entries | type == "array"' .mc-data/work/legacy-scan/annotation-map.json > /dev/null

# T4: Required content
jq -e '.entries | length > 0' .mc-data/work/legacy-scan/annotation-map.json > /dev/null  # empty → E040 handled

# Per-entry validation
jq -e '.entries | all(.file_path != null and .req_ids != null and (.req_ids | length > 0) and .module != null)' \
  .mc-data/work/legacy-scan/annotation-map.json > /dev/null
```

**Next phase:** `phase2-review.md`
