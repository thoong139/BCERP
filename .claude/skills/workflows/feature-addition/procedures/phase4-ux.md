# Phase 4: Design UX (conditional)

> Thiết kế UX/UI cho feature mới. Tự động skip nếu `api-only` hoặc feature không có UI.

## PRE-GATE

- Phase 3 completed hoặc skipped
- `$STATUS_FILE.interface_type` đã set (đọc từ Phase 3 always-run)

## Skip Conditions — kiểm tra theo thứ tự

| Ưu tiên | Điều kiện | Nếu TRUE |
|---------|-----------|----------|
| 1 | `interface_type == "api-only"` | Hiển thị `⏭ Phase 4: Bỏ qua (API-only)` *(không hỏi user)* |
| 2 | (chỉ check nếu #1 FALSE) Hỏi: *"Feature mới có UI không? (yes/no)"* → `no` | Hiển thị `⏭ Phase 4: Bỏ qua` |

Nếu SKIP → ghi `$STATUS_FILE.phases_skipped += "phase4"` + `current_phase = "phase5a"` → chuyển sang phase5a.

## Steps (chạy khi KHÔNG skip)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4.1 | Hiển thị: `▶ Phase 4: Thiết kế UX cho Feature mới` | - | - |
| 4.2 | Verify `.claude/skills/workflow/wf-design-ux/SKILL.md` tồn tại | Read | File exists (else E004) |
| 4.3 | Gọi `Skill("wf-design-ux")` | Skill | Sub-skill POST-GATE pass |

## POST-GATE (chỉ khi phase KHÔNG skip)

```bash
test -d .mc-data/docs/phase4-ux
# Spot-check: có ít nhất 1 .md screen file cho NEW_FEATURE_IDS
```
- `$STATUS_FILE.phases_completed += "phase4"`
- `$STATUS_FILE.current_phase = "phase5a"`

## Transition

- **Skip (api-only):** `⏭ Phase 4 bỏ qua — API-only project` → Phase 5a
- **Skip (no UI):** `⏭ Phase 4 bỏ qua — feature không có UI` → Phase 5a
- **Completed:** `✅ Phase 4 hoàn thành — UX đã thiết kế` → hỏi user xác nhận → Phase 5a

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-design-ux SKILL.md không tồn tại

Chi tiết: `_shared.md §Error Handling Reference`.
