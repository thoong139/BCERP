# Scope Filtering Logic — wf-verify-sync

> Áp dụng tại Phase 0 (Step 0 build `$SCOPE_FILTER`) và Phase 1 (filter REQ-IDs + code paths).

```
IF scope == "all":
  → Lấy TẤT CẢ REQ-IDs từ registry.requirements[]
  → $SCOPE_FILTER.req_ids = all, $SCOPE_FILTER.modules = [] (scan toàn bộ src/)

IF scope == "system":
  → Lấy modules[] có system_id == $NAME
  → Lấy requirements[] có module_id thuộc các modules trên
  → $SCOPE_FILTER.modules = các module paths trong code (mapping từ module_id)
  → FALLBACK: Nếu module_id không map được sang code directory (directory không tồn tại):
      → LOG WARNING: "Module [X] chưa có code directory. Filter by REQ-ID only (không filter by directory)."
      → $SCOPE_FILTER.modules = [] (Phase 1 Group B scan toàn bộ src/ rồi filter post-hoc theo REQ-ID list)

IF scope == "module":
  → Lấy requirements[] có module_id == $NAME
  → $SCOPE_FILTER.modules = code path của module đó
  → FALLBACK: Nếu module directory không tồn tại:
      → LOG WARNING: "Module [X] chưa có code directory. Filter by REQ-ID only."
      → $SCOPE_FILTER.modules = [] (filter post-hoc)

VALIDATE: Nếu $NAME không tồn tại trong registry (system_id/module_id invalid):
  → ERROR E013: liệt kê valid IDs từ registry, STOP
```
