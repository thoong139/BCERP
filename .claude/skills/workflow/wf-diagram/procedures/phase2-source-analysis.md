# /wf-diagram — Phase 2: Source Code Analysis

> Lazy-loaded từ SKILL.md. Xem `_shared.md` cho state variables, helpers, error matrix.
> Xem `_shared.md` §analysis.json Schema cho output format (analysis-v1).

---

## PRE-GATE

```
- [ ] $source_path tồn tại (test -d)
- [ ] Phase 1 hoàn tất (phases.phase_1.status == "done")
- [ ] bash ≥4 + jq có sẵn (required bởi wf-diagram-source-scan.sh)
```

---

## Steps

### 2.1 — Run Source Scan Script

```bash
bash .claude/scripts/wf-diagram-source-scan.sh \
     "$source_path" "$module" "$scope" "$SESSION_ID" \
     "$session_dir/analysis.json"
```

Script thực hiện toàn bộ phân tích source code (thay thế cho Steps 2.1-2.5 cũ):
- Scan module structure (folder-based, .NET namespace, package-based)
- Detect DB schema (Prisma, TypeORM, EF DbContext, SQL migrations)
- Extract endpoints (Express/NestJS/.NET/Spring), actors (auth patterns), state machines (enum *Status/State)
- Group use cases theo controller_class / url_prefix / sub_folder
- Ghi output vào `$session_dir/analysis.json` (schema analysis-v1, xem `_shared.md`)
- Đánh dấu `"// TODO: cần xác nhận"` cho thông tin mơ hồ (BHV-002)

Lưu ý về output partial:
- `processes[]` và `scenarios[]` để `[]` — Phase 3 derive từ `endpoints` + `entities` (business logic cần AI reasoning)
- `usecase_groups[]` để `[]` — Phase 5 derive từ `endpoints.controller_class` / `url_prefix`
- Các fields có `_todo` suffix → AI tầng trên review và refine

Exit codes:
- `0` = OK (analysis.json đã ghi)
- `1` = ERROR (source_path không tìm thấy, jq thiếu, hoặc write fail)

### 2.2 — Verify analysis.json

```bash
# Bash đã ghi analysis.json — step này chỉ verify file tồn tại + non-empty
test -s "$session_dir/analysis.json" || { log_error "E007" "analysis.json missing after scan"; exit 1; }

jq -e '(.modules | length > 0) or (.entities | length > 0) or (.endpoints | length > 0)' \
   "$session_dir/analysis.json" \
   || { log_error "E005" "analysis.json: no modules/entities/endpoints detected"; }

# Hiển thị summary cho user
jq -r '"Phân tích xong: \(.modules | length) modules, \(.entities | length) entities, \(.endpoints | length) endpoints, \(.actors | length) actors"' \
   "$session_dir/analysis.json"
```

### 2.3 — Save Checkpoint

```bash
save_checkpoint "phase_2" "phase_3"
# (xem _shared.md §save_checkpoint helper)
jq --arg path "$session_dir/analysis.json" \
   '.intermediate_outputs.analysis_json = $path' \
   "$session_dir/checkpoint.json" > /tmp/cp.tmp && mv /tmp/cp.tmp "$session_dir/checkpoint.json"
```

---

## POST-GATE

```
- [ ] analysis.json tồn tại + non-empty (test -s)
- [ ] jq '.modules | length > 0' HOẶC '.entities | length > 0' HOẶC '.endpoints | length > 0'
- [ ] phases.phase_2.status = "done" trong checkpoint.json
```

---

## Next Phase

→ Phase 3: `procedures/phase3-plan.md` (Generation Plan)
