# Phase 8: Update Registry (CHUNKED — NO AGENT)

> **Lưu ý Phase numbering:** Phase 7 (Feature Specs) thuộc `/wf-define-features`, không nằm trong skill này. Đánh số 6d→8 là intentional để giữ nhất quán với workflow tổng thể.
>
> Main conversation cập nhật registry trực tiếp. **KHÔNG delegate cho agent** để tránh token limit.

**PRE-GATE:** `test -f .mc-data/docs/_meta/req-registry.json`

**INPUT:** Registry hiện tại + tất cả `[dept].md` files

**OUTPUT:**
- Registry UPDATED (systems[], modules[], departments[], requirements[], interface_type)
- `.mc-data/work/wf-analyze-requirements/analyze-report-[date].md` (NEW)

## Registry Safe-Write

> Xem chi tiết tại `_shared.md §Registry Safe-Write`.
>
> Quy tắc: đọc fresh → modify ONLY fields được phân công → atomic write → validate `jq`.

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 8.1  | Đọc registry JSON hiện tại (fresh read) | Content loaded |
| 8.2  | Update `modules[]` + `departments[]` (small arrays). Cho mỗi module: set `system` (slug/id của system chịu trách nhiệm chính — match với `systems[].id`) và `department_ids[]` (list DEPT-* phục vụ module). | Arrays updated |
| 8.2-SYS | **Enrich `systems[]` (KHÔNG ghi đè fields seed):** Với mỗi system đã seed bởi brainstorm, giữ nguyên `user_roles[]`, `touchpoints[]`, `related_departments[]`, `phase`. Enrich `module_ids[]` bằng reverse mapping từ `modules[].system = <system-id>`. Cụ thể: `jq '.systems \|= map(. + {module_ids: ([$modules[] \| select(.system == .id) \| .id])})' --argjson modules '$(jq .modules registry.json)'`. KHÔNG xóa system nào đã seed — nếu system không có module nào, giữ `module_ids: []` + log WARNING "system <id> chưa có module — cần xem lại BA output". | `jq -e 'all(.systems[]; has("module_ids"))' passes + seed fields intact |
| 8.3  | Update `requirements[]` — extract từ dept docs, upsert by id theo schema chuẩn (xem `_shared.md §Registry Schema — requirements[]`). **BẮT BUỘC set `systems[]` cho mỗi REQ** từ ma trận "Hệ thống liên quan" trong dept doc Phần A. Nếu dept doc không có ma trận → derive từ `modules[primary_module].system` (default 1 system). | REQ count matches + all REQs have systems[] |
| 8.3a | **Schema Guard**: Verify mỗi entry trong `requirements[]` có đúng 8 fields bắt buộc (xem schema). Nếu thiếu field → tự bổ sung default. Nếu dùng tên field sai (vd: `description` thay vì `title`) → rename theo schema. **Nếu `systems[]` rỗng hoặc thiếu** → FAIL (E017). Derive default `systems[]` = `[modules[primary_module].system]`. | 0 schema violations |
| 8.3b | **Systems validation (CORE-011 forensic):** Mỗi value trong `requirements[].systems[]` PHẢI match với `.systems[].id`. Nếu có system ID không hợp lệ → FAIL với log chi tiết. Nếu REQ-ID thuộc department có multi-system (≥ 2 systems trong `related_departments`) mà chỉ có 1 system trong REQ.systems[] → log WARNING "REQ {id} thuộc dept multi-system nhưng chỉ gán 1 system — có thể miss fan-out". | validation pass |
| 8.4  | Set metadata: `interface_type` (từ `$INTERFACE_TYPE` — Phase 6), counters, timestamps | Fields set |
| 8.5  | Write complete registry JSON (single atomic write) — giữ nguyên `features[]`, `design_status`, `impl_status`, etc. | `jq '.' registry.json` |
| 8.5b | **Scope=[module]**: Chỉ upsert `requirements[]` cho module target. Giữ nguyên `requirements[]` của modules khác. | No data loss |
| 8.6  | Validate: count `requirements[]` == expected | Counts match |
| 8.6-COV | **Per-system coverage (BẮT BUỘC — T4 cross-ref):** Với mỗi system đã khai báo (`systems[].id`), đếm số REQ có system trong `requirements[].systems[]`. Nếu có system phase=MVP với count=0 → FAIL (E018 NO_REQ_FOR_SYSTEM). Log: "System <id> (MVP) không có requirement nào — BA có thể đã bỏ sót. Xem lại dept doc + ma trận Requirement × System." | mỗi system MVP có ≥ 1 REQ |
| 8.7  | Generate `.mc-data/work/wf-analyze-requirements/analyze-report-[date].md` (agent OK cho report nhỏ). Report BẮT BUỘC có bảng per-system coverage (system × count_requirements × departments_contributing). | `test -s report` |

## Schema Guard jq Check (chạy sau khi upsert)

```bash
# Phải = 0. Nếu > 0 → có entry dùng field name sai
jq '[.requirements[] | select(has("department") or has("description") or has("source_file"))] | length' registry.json
```

**POST-GATE:**

```bash
jq '.' .mc-data/docs/_meta/req-registry.json  # valid JSON

# T4-SYS: mỗi REQ có systems[] ≥ 1, giá trị match với .systems[].id
jq -e '
  (.systems | map(.id)) as $valid
  | all(.requirements[];
      (.systems // []) | length > 0
      and all(.systems[]; . as $s | ($valid | index($s)) | not | not))
' .mc-data/docs/_meta/req-registry.json

# T4-COV: mỗi system phase=MVP có ≥ 1 requirement
jq -e '
  [.systems[] | select(.phase == "MVP") | .id] as $mvp_systems
  | ([.requirements[].systems[]?] | unique) as $covered
  | all($mvp_systems[]; . as $s | ($covered | index($s)))
' .mc-data/docs/_meta/req-registry.json

# T4-LINK: modules[].system phải match systems[].id
jq -e '
  (.systems | map(.id)) as $valid
  | all(.modules[]; (.system == null) or ($valid | index(.system)))
' .mc-data/docs/_meta/req-registry.json
```

Nếu T4-COV fail → STOP với E018 và log danh sách systems thiếu coverage. KHÔNG tiếp tục Phase 8b.

**Status update:** `analyze-status.json` → `phase_8.status = "completed"`, `phase_8.req_count = <N>`, `phase_8.systems_coverage = {system_id: req_count}`.

**Next phase:** `phase8b-crossval.md`
