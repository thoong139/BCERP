# Bước 2 — Phase 2: Define Features

> Delegate đến `wf-define-features`. Convert requirements → feature specs,
> populate `features[]` trong registry.

**Sub-skill:** `wf-define-features`
**DEVKIT Phase:** Phase 2

## PRE-GATE

```bash
# Registry có ≥1 requirement
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json || exit_with E010
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | Hiển thị: `▶ Bước 2 — Phase 2: Định nghĩa Features` | Output | — |
| 2.2 | VERIFY `.claude/skills/workflow/wf-define-features/SKILL.md` tồn tại | Read | File loaded hoặc E004 |
| 2.3 | Gọi `Skill("wf-define-features")` — thực thi đầy đủ | Skill | — |
| 2.4 | Đợi sub-skill hoàn thành POST-GATE nội bộ | - | Sub-skill done |

## POST-GATE

```bash
# Registry có ≥1 feature
jq -e '.features | length > 0' .mc-data/docs/_meta/req-registry.json || exit_with E001
```

Nếu POST-GATE fail → retry sub-skill (max 3 lần). Vẫn fail → E001.

## Checkpoint Update

Cập nhật `$STATUS_FILE`:
- `steps_completed += [2]`
- `current_step = 3`
- `current_phase = "phase4-design"`
- `updated_at = now()`
- `next_action = "Bắt đầu Bước 3 — Phase 3: Design"`

## Transition

```
✅ Bước 2 hoàn thành — Phase 2: Feature Definitions

→ Next: Bước 3 — Phase 3: Design Architecture (phase4-design.md)

Tiếp tục? (yes/no)
```

Nếu user chọn `no` → E002.

## Errors liên quan

- **E001** — POST-GATE fail sau 3 retries → STOP
- **E002** — User dừng → checkpoint + resume note
- **E004** — Sub-skill SKILL.md thiếu → STOP
- **E010** — Prerequisite fail (thiếu requirements[]) → báo user

Chi tiết: `_shared.md §Error Handling Reference`.
