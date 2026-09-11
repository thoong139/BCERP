# Phase 1: Scope Addition (conditional)

> Thêm module mới vào registry nếu feature mới thuộc module chưa tồn tại.
> `wf-define-features` chỉ có thể thêm features vào modules ĐÃ CÓ — module mới phải qua `wf-add-scope` trước.

## PRE-GATE

- Phase 0 completed (`"phase0"` trong `phases_completed[]`)
- `$STATUS_FILE` tồn tại, `$EXISTING_MODULE_IDS` đã load

## Steps — Xác định nhu cầu

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | Đọc registry → lấy `modules[]` với cả `id` + `name` + `description` → hiển thị dạng danh sách có đánh số | Read | Displayed |
| 1.2 | Hỏi user: *"Feature mới thuộc module nào? (nhập số thứ tự, tên, hoặc 'new' nếu cần module mới)"* | - | User chọn |
| 1.3 | Kiểm tra lựa chọn của user có match với `$EXISTING_MODULE_IDS` | Read | Match/no match |

### Step 1.1 — Chi tiết hiển thị modules

```bash
# Đọc registry lấy id + name + description, KHÔNG chỉ id
MODULE_LIST=$(jq -r '.modules[] | "  \(.id): \(.name) — \(.description // "không có mô tả")"' \
  .mc-data/docs/_meta/req-registry.json)
```

Hiển thị:
```
📦 Modules hiện có trong dự án:
  1) MOD-AUTH: Xác thực người dùng — Quản lý đăng nhập, đăng ký, phân quyền
  2) MOD-PAYMENT: Thanh toán — Xử lý giao dịch và cổng thanh toán
  3) MOD-REPORT: Báo cáo — Dashboard và xuất báo cáo
  ...

→ Nhập số thứ tự, ID module, hoặc gõ 'new' để tạo module mới:
```

> Nếu user nhập tên không rõ (VD: "auth" thay vì "MOD-AUTH") → thực hiện fuzzy match trên `name` + `id` → hiển thị kết quả match + xác nhận với user trước khi tiếp tục.

## Routing

### A. Module đã tồn tại → SKIP Phase 1

```
1. Hiển thị: `⏭ Phase 1: Bỏ qua (module đã tồn tại)`
2. Ghi $STATUS_FILE:
   - phases_skipped += "phase1"
   - current_phase = "phase2"
3. Chuyển sang phase2-features.md
```

### B. Module mới cần thêm → GỌI wf-add-scope

**Guardrail LEGACY_MODE (CORE-022):**
```bash
if [[ "${LEGACY_MODE}" == "true" ]] && echo "${DEPRECATED_MODULES}" | jq -e ". | index(\"$NEW_MODULE_ID\")" > /dev/null; then
  exit_with E013   # Module bị DEPRECATE
fi
```

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.4 | Hiển thị: `▶ Phase 1: Thêm Scope — Module mới` | - | - |
| 1.5 | Verify `.claude/skills/workflow/wf-add-scope/SKILL.md` tồn tại | Read | File exists (else E004) |
| 1.6 | Gọi `Skill("wf-add-scope", args="--system=[sys] --module=[mod]")` | Skill | Sub-skill POST-GATE pass |
| 1.7 | Đọc registry → verify module count tăng | Read | `length > $MOD_COUNT_BEFORE` |
| 1.8 | Ghi `module_scope_added: true` + thêm ID mới vào `existing_module_ids[]` | Write | Saved |

## POST-GATE (chỉ khi không skip)

```bash
# Module mới phải xuất hiện trong registry
jq -e --arg id "$NEW_MODULE_ID" '.modules | map(.id) | index($id)' \
  .mc-data/docs/_meta/req-registry.json
```

- `$STATUS_FILE.module_scope_added == true`
- `$STATUS_FILE.phases_completed += "phase1"`
- `$STATUS_FILE.current_phase = "phase2"`

## Transition

- **Skip:** `⏭ Phase 1 bỏ qua — module đã tồn tại` → Phase 2
- **Added:** `✅ Phase 1 hoàn thành — module mới đã thêm vào registry` → hỏi user xác nhận → Phase 2

## Errors liên quan

- **E004** — sub-skill SKILL.md không tồn tại (STOP)
- **E013** — module nằm trong `deprecated_modules` (STOP)
- **E014** — wf-add-scope fail (hỏi user retry/skip/manual)

Chi tiết: `_shared.md §Error Handling Reference`.
