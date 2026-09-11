# Bước 5 — Phase 5a: Plan Modules

> Delegate đến `wf-plan-modules`. Dependency analysis + implementation plans → Phase 5a docs
> (roadmap + task files per feature).

**Sub-skill:** `wf-plan-modules`
**DEVKIT Phase:** Phase 5a

## PRE-GATE

```bash
# Phase 3 output bắt buộc
test -f .mc-data/docs/phase3-architecture/stakeholder-review.md || exit_with E010

# Phase 4 output hoặc api-only (xem status file hoặc check registry)
INTERFACE_TYPE=$(jq -r '.interface_type // "web+mobile"' .mc-data/docs/_meta/req-registry.json)
if [ "$INTERFACE_TYPE" != "api-only" ]; then
  test -f .mc-data/docs/phase4-ux/stakeholder-review.md || exit_with E010
fi
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5.1 | Hiển thị: `▶ Bước 5 — Phase 5a: Lập kế hoạch Implementation` | Output | — |
| 5.2 | VERIFY `.claude/skills/workflow/wf-plan-modules/SKILL.md` tồn tại | Read | File loaded hoặc E004 |
| 5.3 | Gọi `Skill("wf-plan-modules")` — thực thi đầy đủ | Skill | — |
| 5.4 | Đợi sub-skill hoàn thành POST-GATE nội bộ | - | Sub-skill done |

## POST-GATE

```bash
test -f .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md || exit_with E001
test -s .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md || exit_with E001
```

Nếu POST-GATE fail → retry sub-skill (max 3 lần). Vẫn fail → E001.

## Checkpoint Update

Cập nhật `$STATUS_FILE`:
- `steps_completed += [5]`
- `current_step = 6`
- `current_phase = "phase7-implement"`
- `updated_at = now()`
- `next_action = "Bắt đầu Bước 6 — Phase 5b: Implement Features (loop)"`

## Transition

```
✅ Bước 5 hoàn thành — Phase 5a: Implementation Plan

→ Next: Bước 6 — Phase 5b: Implement Features (phase7-implement.md)

Tiếp tục? (yes/no)
```

Nếu user chọn `no` → E002.

## Errors liên quan

- **E001** — POST-GATE fail sau 3 retries → STOP
- **E002** — User dừng → checkpoint + resume note
- **E004** — Sub-skill SKILL.md thiếu → STOP
- **E010** — Prerequisite fail (thiếu Phase 3 hoặc Phase 4 non-api-only) → báo user
- **E012** — `jq` không có → fallback python

Chi tiết: `_shared.md §Error Handling Reference`.
