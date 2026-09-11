# Phase 1: Module Resolution & Planning

> Normalize module names, build `$MODULE_MAP`, tính topological order,
> chọn domain expert per module, pre-compress source files thành digests.
> Update extract-plan.md với module breakdown và parallel groups.

**PRE-GATE:**
- [ ] Phase 0 POST-GATE PASS
- [ ] `$MATURITY_MODE != "skip"` (skip mode bypass Phase 1-4)
- [ ] `classified/batch-*.json` tồn tại
- [ ] `inventory/dependency-graph.json` loaded (Phase 0 Step 0.6)

**INPUT:**
- `.mc-data/work/legacy-scan/classified/batch-*.json` (grouped by module)
- `.mc-data/work/legacy-scan/classified/classify-naming-fixes.json` (optional)
- `.mc-data/work/legacy-scan/inventory/dependency-graph.json`

**OUTPUT:**
- In-memory state: `$MODULE_MAP`, `$TOPOLOGICAL_ORDER`, `$PARALLEL_GROUPS`, `$MODULE_DIGESTS`, `$DOMAIN_EXPERTS`
- Updated: `extract-plan.md` (Sections 1.1, 3.1, 3.2, 4.1 populated)
- Normalization log → `warnings[]` trong extract-status.json

---

## Reference Sections

- `_shared.md` §Module Name Normalization
- `_shared.md` §Domain Expert Selection
- `_shared.md` §State Variables Glossary

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | **Normalize module names:** Đọc tất cả `classified/batch-*.json` → group files theo `module` field. Apply thuật toán normalization (xem `_shared.md §Module Name Normalization`): lowercase → trim → replace spaces/underscores với hyphens | Read | Raw module list built |
| 1.2 | **Case-insensitive dedup:** Merge các modules có cùng normalized name. Log merge events vào `warnings[]` của extract-status.json với format: `{type: "NAME_MERGED", original: [...], normalized: "..."}` | — | Dedup complete |
| 1.3 | **Apply naming fixes:** Nếu `classified/classify-naming-fixes.json` tồn tại → READ → apply mapping `{original: normalized}` lên module names | Read | Fixes applied |
| 1.4 | **Build `$MODULE_MAP`:** Object `{normalized_name: [file_paths...]}`. Lưu để Phase 2 dùng | — | `$MODULE_MAP` ready |
| 1.5 | **Validate `--module` filter:** Nếu `$MODULE_FILTER` không empty — kiểm tra tồn tại trong `$MODULE_MAP`. Nếu không có → STOP: "Module '[name]' không tồn tại trong classified data. Available: [...]." | — | Filter validated |
| 1.6 | **Topological ordering:** Đọc `dependency-graph.json` → tính thứ tự theo dependency (parent trước child). Nếu phát hiện circular refs → xem §Circular Handling | Read | `$TOPOLOGICAL_ORDER` set |
| 1.7 | **Parallel grouping:** Chia modules thành groups theo quy tắc: (a) modules không có dependency lẫn nhau → cùng group; (b) max 3 modules/group; (c) group tiếp theo chỉ start sau group trước hoàn thành. Lưu `$PARALLEL_GROUPS` | — | Groups computed |
| 1.8 | **Domain expert selection:** Cho mỗi module, đếm keywords match theo bảng `_shared.md §Domain Expert Selection`. Chọn 1 expert bổ sung (ngoài `business-analyst`). Lưu `$DOMAIN_EXPERTS = {module: expert_name}` | — | Experts assigned |
| 1.9 | **Pre-compression (Protocol 6.2):** Cho mỗi module, Grep key patterns từ source files (class/function/route/export declarations, business keywords) → tạo `module-digest` (~300 từ/file). Lưu `$MODULE_DIGESTS = {module: digest_string}` | Grep/Read | Digests ready |
| 1.10 | **Update extract-plan.md:** Đọc file hiện tại → POPULATE Section 1.1 (Module Breakdown), Section 3.1 (Topological Order), Section 3.2 (Parallel Groups), Section 4.1 (Domain Expert Selection) với dữ liệu từ Steps 1.4-1.8 → WRITE lại | Read/Edit | Plan updated |
| 1.11 | **Save checkpoint (MEDIUM/LARGE):** Update `extract-checkpoint.json` — `position.current_phase = 1`, `position.phase_complete = true`, `state.module_map_size = N` | Write | Checkpoint saved |

---

## Circular Handling (Step 1.6)

```
Detect circular deps bằng DFS (depth-first search):
- Nếu visit 1 node đang in_stack → circular detected

Xử lý:
1. WARN E015: log circular path vào error_log[]
2. Break circular bằng cách remove edge có weight thấp nhất (hoặc edge cuối cùng nếu không có weights)
3. Re-compute topological order
4. Ghi note vào `warnings[]` của extract-status.json:
   {type: "CIRCULAR_BROKEN", path: [...], broken_edge: "A → B"}
5. Continue (KHÔNG STOP)
```

---

## Domain Expert Selection Algorithm (Step 1.8)

```
FOR each module trong $MODULE_MAP:
  keyword_matches = {}
  FOR each (domain, keywords) trong _shared.md domain table:
    count = 0
    FOR each file trong $MODULE_MAP[module]:
      Grep keywords trong file content (case-insensitive)
      count += matches
    keyword_matches[domain] = count
  
  # Chọn primary expert
  primary_domain = domain có keyword_matches cao nhất
  IF 2 domains bằng nhau → chọn domain đặc thù hơn
  (vd: procurement-expert > operations-expert khi có PO + vendor)
  
  IF primary_domain không rõ (max count = 0):
    $DOMAIN_EXPERTS[module] = null  # chỉ dùng business-analyst
  ELSE:
    $DOMAIN_EXPERTS[module] = expert_name từ domain table
```

---

## Pre-compression Spec (Step 1.9)

**Mục đích:** Giảm context token cho agent — agent nhận digest trong prompt thay vì load toàn bộ source.

**Thuật toán per module:**

```
digest_parts = []
FOR each file trong $MODULE_MAP[module]:
  key_patterns = [
    "class|interface|type|struct",
    "function|def|public|private.*method",
    "@app.route|@GetMapping|@PostMapping|router\.(get|post|put|delete)",
    "export (default |const |function |class )",
    "business_keywords_from_glossary"  # từ glossary.json
  ]
  matches = Grep(file, key_patterns, max 20 lines)
  digest_parts.append(f"### {file}\n{matches}")

$MODULE_DIGESTS[module] = "\n".join(digest_parts[:max_300_words_per_file])
```

**Khi nào agent đọc file gốc:**
- Digest không đủ chi tiết xác nhận behavior cụ thể
- Cần extract acceptance criteria từ test files
- Agent có quyền Read file gốc khi cần

---

## POST-GATE

- [ ] `$MODULE_MAP` không rỗng (có ít nhất 1 module)
- [ ] `$TOPOLOGICAL_ORDER` có đúng số modules như `$MODULE_MAP`
- [ ] `$PARALLEL_GROUPS` tổng số modules = `$TOPOLOGICAL_ORDER.length`
- [ ] `$DOMAIN_EXPERTS` có entry cho mỗi module (có thể null = chỉ BA)
- [ ] `$MODULE_DIGESTS` có entry cho mỗi module
- [ ] Nếu `$MODULE_FILTER` set: chỉ 1 module trong `$MODULE_MAP` (đã filter)
- [ ] `extract-plan.md` được update với Section 1.1, 3.1, 3.2, 4.1 (non-placeholder)
- [ ] Normalization events được log vào `warnings[]`

**Next phase:** `phase2-extraction.md`
