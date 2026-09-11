# §10 Template Usage Rule (CORE-031)

> **Slim (v10.13.0):** Quy tắc đầy đủ trong [CORE-031 — Template Usage Rule](../../../../rules/00-core.md#4h-core-031-template-usage-rule-b%E1%BA%AFt-bu%E1%BB%99c) + [Protocol 19 — Template Usage](../../../../skills/protocols/19-template-usage.md). File này CHỈ giữ placeholder convention + strip pattern cụ thể cho wf-fix-bugs templates.

## Placeholder Convention

| File type | Pattern | Ví dụ |
|-----------|---------|-------|
| JSON templates | `{{VAR_NAME}}` | `"session_id": "{{SESSION_ID}}"` |
| Markdown templates | `[VAR_NAME]` | `# Phase Report: [PHASE_NAME]` |
| JSON legacy (v9.x) | Empty strings / 0 / [] | Populate by jq field assignment |

## Template Metadata Stripping

Templates chứa nhiều field metadata bắt đầu bằng `_` (vd: `_template_notes`, `_schema_notes`, `_notes`, `_how_to_use`, `_example`, `_entry_schema_notes`, `_generator_notes`) để document schema intent. KHI POPULATE runtime, PHẢI strip TOÀN BỘ các field bắt đầu `_` ở mọi cấp:

```bash
# Canonical STRIP pattern — loại bỏ MỌI field bắt đầu `_` ở mọi cấp (top-level + nested)
jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)' \
  "$TEMPLATE_PATH" > "$OUTPUT_PATH.tmp.$$"

# Sau đó POPULATE values vào output (nếu cần):
jq --arg sid "$SESSION_ID" '. + {"session_id": $sid}' "$OUTPUT_PATH.tmp.$$" > "$OUTPUT_PATH"
rm -f "$OUTPUT_PATH.tmp.$$"
```

> **Lưu ý:**
> - `walk` đệ quy vào nested objects → cover cả `_entry_schema_notes` lồng trong `entries[]`.
> - `del(._template_notes, ._schema_notes)` (pattern cũ) CHỈ strip top-level → **KHÔNG ĐỦ**. Procedures hiện tại còn dùng pattern cũ ở một số nơi — sẽ migrate dần.
> - Cho JSONL templates (vd: `probe-failures-log.json`): KHÔNG WRITE template thẳng vào output (sẽ phá format JSONL); chỉ dùng `_example` làm tài liệu.

Template files nằm tại: `.claude/skills/workflow/wf-fix-bugs/templates/`.
