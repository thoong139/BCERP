# Phase 5a: Plan Modules

> Lập kế hoạch implementation cho features mới. `wf-plan-modules` đọc registry.features
> và gap-report.md (legacy mode) để xác định implementation_strategy per feature
> (CORE-019: VERIFY_ONLY / COMPLETE_EXISTING / IMPLEMENT_NEW).

## PRE-GATE

- Phase 4 xong/skip (`phases_completed/skipped` chứa `"phase4"`)
- `jq -e '.features | length > 0' req-registry.json`
- (LEGACY_MODE) gap-report.md tồn tại

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5a.1 | Hiển thị: `▶ Phase 5a: Lập kế hoạch Implementation` | - | - |
| 5a.2 | Verify `.claude/skills/workflow/wf-plan-modules/SKILL.md` tồn tại | Read | File exists (else E004) |
| 5a.3 | Gọi `Skill("wf-plan-modules")` | Skill | Sub-skill POST-GATE pass |

## POST-GATE

```bash
# 1. Roadmap tồn tại
test -f .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md

# 2. Task files tồn tại (ít nhất 1 file)
test -n "$(find .mc-data/docs/phase5-implementation/tasks -name '*-impl.md' 2>/dev/null | head -1)" \
  || echo "WARNING: Không tìm thấy task files trong phase5-implementation/tasks/"
```

Nếu roadmap thiếu → E003 → retry sub-skill tối đa 3 lần.

## Status File Update

```bash
jq '
  .phases_completed += ["phase5a"]
  | .current_step = "phase5b"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Transition

```
✅ Phase 5a hoàn thành — implementation roadmap created
  Roadmap: P5-00-implementation-roadmap.md
  Task files: [count]

→ Next: phase5b-implement
```

Hỏi user xác nhận tiếp tục.

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-plan-modules SKILL.md không tồn tại (STOP)
- **E014** — sub-skill fail sau retry

Chi tiết: `_shared.md §Error Handling Reference`.
