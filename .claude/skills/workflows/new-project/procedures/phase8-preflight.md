# Bước 7 — Phase 5c: Preflight Check

> Delegate đến `wf-preflight`. Health check toàn diện: registry + docs + code + quality.
> Routing sau Preflight: PASS → tiếp tục Verify; WARN → hỏi user; FAIL → gợi ý `/wf-fix-bugs`.

**Sub-skill:** `wf-preflight`
**DEVKIT Phase:** Phase 5c

## PRE-GATE

```bash
# Có ≥1 feature đã implement
jq -e '[.features[] | select(.impl_status == "done")] | length > 0' .mc-data/docs/_meta/req-registry.json || exit_with E010
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 7.1 | Hiển thị: `▶ Bước 7 — Phase 5c: Preflight — Kiểm tra sức khỏe dự án` | Output | — |
| 7.2 | VERIFY `.claude/skills/workflow/wf-preflight/SKILL.md` tồn tại | Read | File loaded hoặc E004 |
| 7.3 | Gọi `Skill("wf-preflight")` — thực thi đầy đủ (registry + docs + code + quality) | Skill | — |
| 7.4 | Đợi sub-skill hoàn thành POST-GATE nội bộ | - | Sub-skill done |
| 7.5 | Đọc kết quả preflight → xác định `$PREFLIGHT_STATUS` (PASS / WARN / FAIL) | Read | Status parsed |

## POST-GATE

```bash
test -f .mc-data/work/wf-preflight/preflight-report.md || exit_with E001
test -s .mc-data/work/wf-preflight/preflight-report.md || exit_with E001
```

## Routing theo $PREFLIGHT_STATUS

```
PASS → ghi status "PASS" → tiếp tục Bước 8

WARN → hiển thị summary warnings
     → hỏi user: "Tiếp tục verify hay dừng để fix? (continue / fix)"
       - continue → note warnings, tiếp tục Bước 8
       - fix      → dừng, gợi ý /wf-fix-bugs → resume sau

FAIL → E015: hiển thị errors cụ thể
     → gợi ý: "Chạy /wf-fix-bugs trước khi tiếp tục. Resume bằng /new-project --resume sau khi fix."
     → DỪNG
```

## Checkpoint Update

### Nhánh PASS

Cập nhật `$STATUS_FILE`:
- `steps_completed += [7]`
- `preflight_status = "PASS"`
- `current_step = 8`
- `current_phase = "phase9-verify"`
- `next_action = "Bắt đầu Bước 8 — Verify: Sync Check"`

### Nhánh WARN + continue

Cập nhật tương tự PASS nhưng `preflight_status = "WARN"`.

### Nhánh WARN + fix / FAIL

Cập nhật `$STATUS_FILE`:
- `preflight_status = "WARN" | "FAIL"`
- `next_action = "Chạy /wf-fix-bugs → /new-project --resume"`
- KHÔNG advance `current_step` — giữ ở 7 để resume quay lại Preflight

## Transition

```
✅ Bước 7 hoàn thành — Phase 5c: Preflight (PASS / WARN / FAIL)

→ Next: Bước 8 — Verify: Sync Check (phase9-verify.md)
   [nếu FAIL → dừng, gợi ý /wf-fix-bugs]

Tiếp tục? (yes/no)
```

## Errors liên quan

- **E001** — POST-GATE fail sau 3 retries → STOP
- **E002** — User dừng → checkpoint + resume note
- **E004** — Sub-skill SKILL.md thiếu → STOP
- **E010** — Prerequisite fail (không có feature done) → báo user
- **E015** — Preflight FAIL → gợi ý `/wf-fix-bugs` trước khi verify

Chi tiết: `_shared.md §Error Handling Reference`.
