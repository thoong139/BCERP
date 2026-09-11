# Bước 0 — Phase 0: Brainstorm

> Delegate đến `wf-brainstorm`. Entry point của DEVKIT workflow — tạo `.mc-data/` structure,
> seed `req-registry.json`, dẫn dắt hội thoại brainstorm với user.

**Sub-skill:** `wf-brainstorm`
**DEVKIT Phase:** Phase 0

## PRE-GATE

```bash
# Đảm bảo orchestrator đã init status file
test -f .mc-data/work/new-project/status.json || exit_with E009
```

Nếu PRE-GATE fail → quay lại `phase0-init.md` để tạo status file.

## Steps (theo Sub-Skill Invocation Pattern — xem `_shared.md`)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1 | Hiển thị: `▶ Bước 0 — Phase 0: Brainstorm` | Output | — |
| 0.2 | VERIFY `.claude/skills/workflow/wf-brainstorm/SKILL.md` tồn tại | Read | File loaded hoặc E004 |
| 0.3 | Gọi `Skill("wf-brainstorm", args=$PROJECT_NAME)` — thực thi đầy đủ toàn bộ phases của sub-skill | Skill | — |
| 0.4 | Đợi sub-skill hoàn thành POST-GATE nội bộ | - | Sub-skill done |

## POST-GATE

```bash
# T1: File tồn tại
test -f .mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md || exit_with E001
# T2: File non-empty
test -s .mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md || exit_with E001
# T3: Registry tồn tại và JSON valid
test -f .mc-data/docs/_meta/req-registry.json || exit_with E001
jq '.' .mc-data/docs/_meta/req-registry.json > /dev/null 2>&1 || exit_with E001
```

Nếu POST-GATE fail → retry sub-skill (max 3 lần). Vẫn fail → E001.

## Checkpoint Update

Cập nhật `$STATUS_FILE`:
- `steps_completed += [0]`
- `current_step = 1`
- `current_phase = "phase2-analyze"`
- `updated_at = now()`
- `next_action = "Bắt đầu Bước 1 — Phase 1: Analyze Requirements"`

## Transition

```
✅ Bước 0 hoàn thành — Phase 0: Brainstorm

→ Next: Bước 1 — Phase 1: Analyze Requirements (phase2-analyze.md)

Tiếp tục? (yes/no)
```

Nếu user chọn `no` → E002: ghi checkpoint, thông báo resume bằng `--resume`.

## Errors liên quan

- **E001** — POST-GATE fail sau 3 retries → STOP
- **E002** — User dừng → checkpoint + resume note
- **E004** — Sub-skill SKILL.md thiếu → STOP
- **E014** — Sub-skill timeout/partial → retry 1 lần

Chi tiết: `_shared.md §Error Handling Reference`.
