# Phase 5a: Plan Modules

> Lập kế hoạch implementation cho features mới. Sub-skill `wf-plan-modules` tạo roadmap + task files.

## PRE-GATE

- Phase 4 completed hoặc skipped
- `$STATUS_FILE.new_feature_ids.length > 0`

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5a.1 | Hiển thị: `▶ Phase 5a: Lập kế hoạch Implementation` | - | - |
| 5a.2 | Verify `.claude/skills/workflow/wf-plan-modules/SKILL.md` tồn tại | Read | File exists (else E004) |
| 5a.3 | Gọi `Skill("wf-plan-modules")` | Skill | Sub-skill POST-GATE pass |

## POST-GATE

```bash
# Roadmap file phải tồn tại
test -f .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md

# Task files cho NEW_FEATURE_IDS phải tồn tại (spot-check)
for feat_id in $(jq -r '.new_feature_ids[]' "$STATUS_FILE"); do
  # Tìm task file với feat slug — flexible pattern match
  find .mc-data/docs/phase5-implementation/tasks -name "*-impl.md" | head -1
done
```

- `$STATUS_FILE.phases_completed += "phase5a"`
- `$STATUS_FILE.current_phase = "phase5b"`

## Transition

```
✅ Phase 5a hoàn thành — implementation roadmap tạo
   Task files: [N] file cho [M] features mới

→ Next: Phase 5b — code từng feature (có thể dừng/resume)
```

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-plan-modules SKILL.md không tồn tại

Chi tiết: `_shared.md §Error Handling Reference`.
