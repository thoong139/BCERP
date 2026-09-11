# /wf-diagram — Shared: State Variables, Helpers & Error Matrix

> Cross-cutting reference cho tất cả phase files. Không phải phase — đây là thư viện dùng chung.
> Mỗi phase file import implicit: `> Xem \`_shared.md\` cho state vars, helpers, error matrix.`

---

## State Variables Glossary

| Variable | Source | Description |
|----------|--------|-------------|
| `$module` | `--module=<name>` arg | Module cần sinh diagram. Bắt buộc trừ `scope=system-only` |
| `$source_path` | `--source-path=<path>` arg | Root source code, default `.` |
| `$output_path` | `--output-path=<path>` arg | Đường dẫn xuất diagrams, default `.mc-data/docs/diagrams` |
| `$scope` | `--scope=<value>` arg | `full` \| `module-only` \| `system-only`, default `full` |
| `$session_id` | Phase 0.4 generated | Format `{YYYY-MM-DD}-{scope-label}[-{N}]` (Protocol 18.2) |
| `$session_dir` | Computed | `.mc-data/work/wf-diagram/sessions/$session_id/` |
| `$system_dir` | Computed (v1.2.0) | `$output_path/modules/$module/_system` (full/module-only) HOẶC `$output_path/_system` (system-only) |
| `$user_choice` | Phase 1.3 CDG-02 | `overwrite` \| `skip` \| `update_missing` \| null (no conflict) |
| `$analysis` | Phase 2 output | Content từ `$session_dir/analysis.json` |
| `$plan` | Phase 3 output | Content từ `diagram-status.json.generation_plan` |

---

## Helper: slugify()

```bash
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g'
}
# Usage: slugify "Order Status" → "order-status"
# Usage: slugify "Order Creation" → "order-creation"
```

---

## Helper: save_checkpoint()

```bash
save_checkpoint() {
  local phase="$1"   # vd: "phase_2"
  local next="$2"    # vd: "phase_3" (hoặc "null" nếu DONE)
  jq --arg p "$phase" --arg n "$next" \
     '.phase_states[$p] = "done" | .next_action.phase = $n' \
     "$session_dir/checkpoint.json" > /tmp/cp.tmp && mv /tmp/cp.tmp "$session_dir/checkpoint.json"
}
```

---

## Helper: log_error()

```bash
log_error() {
  local code="$1"   # vd: "E007"
  local msg="$2"    # mô tả
  jq --arg c "$code" --arg m "$msg" \
     '.error_log += [{"code": $c, "message": $m}]' \
     "$session_dir/diagram-status.json" > /tmp/ds.tmp && mv /tmp/ds.tmp "$session_dir/diagram-status.json"
}
```

---

## analysis.json Schema (analysis-v1)

```json
{
  "$schema": "analysis-v1",
  "session_id": "<session_id>",
  "scanned_at": "<ISO-8601>",
  "modules": [
    { "name": "order", "path": "src/modules/order", "type": "folder" }
  ],
  "entities": [
    { "name": "Order", "table": "orders", "module": "order",
      "columns": [{"name":"id","type":"uuid","pk":true}],
      "fks": [{"col":"customer_id","ref_table":"customers"}] }
  ],
  "endpoints": [
    { "method": "POST", "path": "/api/orders", "handler": "createOrder",
      "controller_class": "OrderController",
      "url_prefix": "/api/orders",
      "sub_folder": "src/modules/order",
      "services_called": ["OrderService","PaymentService"],
      "is_async": false,
      "has_complex_error_handling": true }
  ],
  "actors": [
    { "name": "Admin", "role": "admin", "modules_used": ["order"],
      "auth_pattern": "@Roles('admin')" }
  ],
  "state_machines": [
    { "entity": "Order",
      "states": ["draft","pending","confirmed","shipped","delivered","cancelled"],
      "transitions": [{"from":"draft","to":"pending","event":"submit"}] }
  ],
  "processes": [
    { "name": "createOrder",
      "steps": ["validate","check_stock","create_record","charge_payment","notify"],
      "has_decision_branch": true }
  ],
  "scenarios": [
    { "name": "createOrder",
      "services_called": ["OrderService","PaymentService","NotificationService"],
      "is_async": true,
      "has_complex_error_handling": true }
  ],
  "usecase_groups": [
    { "group_name": "Order Management",
      "group_slug": "order-management",
      "description": "CRUD và lifecycle cho Order",
      "use_cases": [{"name":"Create Order","endpoint":"POST /api/orders"}],
      "actors": ["Admin","Customer"],
      "grouping_basis": "controller_class" }
  ]
}
```

---

## Error Handling Matrix

| Code | Tình huống | Action | Retry |
|------|------------|--------|-------|
| E001 | Missing --module + scope ≠ system-only | Display message → STOP | No |
| E002 | --source-path không tồn tại | ERROR + suggest ls → STOP | No |
| E003 | output_path/modules/$module/ exists | CDG-02 (Protocol 16) | — |
| E004 | $module không tìm thấy trong source | WARN + offer scope=system-only → ASK | No |
| E005 | DB schema không tìm thấy | WARN + skip ERD generation | No |
| E006 | Mermaid syntax invalid | Re-render từ template | x3 |
| E007 | File missing/empty sau generate | Re-run phase | x3 |
| E008 | File write fail | Retry → ESCALATE | x3 |
| E009 | User reject CDG-02 | Skip module, continue (Protocol 16.2.1) | — |

---

## Context Usage Thresholds (Protocol 18.3)

| Context | Action |
|---------|--------|
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint (save_checkpoint + ghi rõ next phase) |
| 80-90% | Force save_checkpoint ngay |
| > 90% | FORCE STOP — tạo checkpoint + thông báo user |
