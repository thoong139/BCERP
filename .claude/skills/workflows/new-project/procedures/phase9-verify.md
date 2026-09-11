# Bước 8 — Verify: Sync Check

> Delegate đến `wf-verify-sync`. Verify requirement-to-code traceability — đảm bảo
> mọi REQ-ID trong registry có mapping tới code, và ngược lại.

**Sub-skill:** `wf-verify-sync`
**DEVKIT Phase:** Verify (không thuộc DEVKIT phase 0-6 chính thức, nằm giữa 5c và 6)

## PRE-GATE

```bash
# Preflight report tồn tại (đã chạy Bước 7)
test -f .mc-data/work/wf-preflight/preflight-report.md || exit_with E010
test -s .mc-data/work/wf-preflight/preflight-report.md || exit_with E010
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 8.1 | Hiển thị: `▶ Bước 8 — Verify: Kiểm tra Traceability` | Output | — |
| 8.2 | VERIFY `.claude/skills/workflow/wf-verify-sync/SKILL.md` tồn tại | Read | File loaded hoặc E004 |
| 8.3 | Gọi `Skill("wf-verify-sync")` — thực thi đầy đủ | Skill | — |
| 8.4 | Đợi sub-skill hoàn thành POST-GATE nội bộ | - | Sub-skill done |

## POST-GATE

```bash
test -f .mc-data/docs/_meta/verify-sync.md || exit_with E001
test -s .mc-data/docs/_meta/verify-sync.md || exit_with E001
```

Nếu POST-GATE fail → retry sub-skill (max 3 lần). Vẫn fail → E001.

## Checkpoint Update

Cập nhật `$STATUS_FILE`:
- `steps_completed += [8]`
- `current_step = 9`
- `current_phase = "phase10-deploy"`
- `updated_at = now()`
- `next_action = "Bắt đầu Bước 9 — Phase 6: Prepare Deployment"`

## Transition

```
✅ Bước 8 hoàn thành — Verify: Traceability Check

→ Next: Bước 9 — Phase 6: Deployment Docs (phase10-deploy.md)

Tiếp tục? (yes/no)
```

Nếu user chọn `no` → E002.

## Errors liên quan

- **E001** — POST-GATE fail sau 3 retries → STOP
- **E002** — User dừng → checkpoint + resume note
- **E004** — Sub-skill SKILL.md thiếu → STOP
- **E010** — Prerequisite fail (thiếu preflight-report.md) → báo user

Chi tiết: `_shared.md §Error Handling Reference`.
