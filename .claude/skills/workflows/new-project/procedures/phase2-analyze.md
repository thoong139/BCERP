# Bước 1 — Phase 1: Analyze Requirements

> Delegate đến `wf-analyze-requirements`. Multi-agent phân tích nghiệp vụ → tạo Phase 1 docs
> và populate `requirements[]` trong registry.

**Sub-skill:** `wf-analyze-requirements`
**DEVKIT Phase:** Phase 1

## PRE-GATE

```bash
# Phase 0 output phải có
test -f .mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md || exit_with E010
test -f .mc-data/docs/_meta/req-registry.json || exit_with E003
jq '.' .mc-data/docs/_meta/req-registry.json > /dev/null 2>&1 || exit_with E003
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | Hiển thị: `▶ Bước 1 — Phase 1: Phân tích Requirements` | Output | — |
| 1.2 | VERIFY `.claude/skills/workflow/wf-analyze-requirements/SKILL.md` tồn tại | Read | File loaded hoặc E004 |
| 1.3 | Gọi `Skill("wf-analyze-requirements")` — thực thi đầy đủ multi-agent analysis | Skill | — |
| 1.4 | Đợi sub-skill hoàn thành POST-GATE nội bộ | - | Sub-skill done |

## POST-GATE

```bash
# Registry có ≥1 requirement
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json || exit_with E001
```

Nếu POST-GATE fail → retry sub-skill (max 3 lần). Vẫn fail → E001.

## Checkpoint Update

Cập nhật `$STATUS_FILE`:
- `steps_completed += [1]`
- `current_step = 2`
- `current_phase = "phase3-features"`
- `updated_at = now()`
- `next_action = "Bắt đầu Bước 2 — Phase 2: Define Features"`

## Transition

```
✅ Bước 1 hoàn thành — Phase 1: Requirements Analysis

→ Next: Bước 2 — Phase 2: Define Features (phase3-features.md)

Tiếp tục? (yes/no)
```

Nếu user chọn `no` → E002: ghi checkpoint, thông báo resume bằng `--resume`.

## Errors liên quan

- **E001** — POST-GATE fail sau 3 retries → STOP
- **E002** — User dừng → checkpoint + resume note
- **E003** — registry.json không tồn tại → E003 handler
- **E004** — Sub-skill SKILL.md thiếu → STOP
- **E010** — Prerequisite fail (thiếu Phase 0 output) → báo user

Chi tiết: `_shared.md §Error Handling Reference`.
