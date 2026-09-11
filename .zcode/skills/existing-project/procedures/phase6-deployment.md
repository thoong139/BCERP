# Phase 6: Prepare Deployment

> Tạo tài liệu triển khai — deployment docs, user guides, runbooks. `wf-prepare-deployment`
> sinh phase6-deployment/ + stakeholder-review.md.

## PRE-GATE

- Verify hoàn thành (`test -f .mc-data/docs/_meta/verify-sync.md`)

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 6.1 | Hiển thị: `▶ Phase 6: Chuẩn bị Deployment` | - | - |
| 6.2 | Verify `.claude/skills/workflow/wf-prepare-deployment/SKILL.md` tồn tại | Read | File exists (else E004) |
| 6.3 | Gọi `Skill("wf-prepare-deployment")` | Skill | Sub-skill POST-GATE pass |

## POST-GATE

```bash
test -f .mc-data/docs/phase6-deployment/stakeholder-review.md
```

Nếu fail → E003 → retry sub-skill tối đa 3 lần.

## Status File Update

```bash
jq '
  .phases_completed += ["deployment"]
  | .current_step = "completed"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Transition

```
✅ Phase 6 hoàn thành — deployment docs created

→ Workflow KẾT THÚC. Chuyển sang Final Output Report.
```

## Final Output Report (cuối workflow)

```markdown
## Existing Project Workflow Hoàn tất!

| Mục | Giá trị |
|-----|---------|
| Phases completed | [count]/13 |
| Strategy | [S1-S7]: [strategy name] |
| Features implemented | [done]/[total] ([skipped] skipped) |
| Preflight verdict | PASS/WARN/FAIL |
| Verification | PASSED/WARNING |

### Chi tiết

✅ Phase Scan (Strategy: [strategy], pipeline COMPLETE)
✅ Phase Brainstorm
✅ Phase Analyze-Req
✅ Phase Define-Features
✅ Phase Design (cluster Buoc 0b kết thúc)
✅/⏭ Phase Annotate
✅/⏭ Phase 4: UX/UI
✅ Phase 5a: Plan
✅ Phase 5b: Implement ([done]/[total] features, [skipped] skipped)
✅ Phase Preflight: Health Check
✅ Phase Verify: Traceability
✅ Phase 6: Deployment

Next: `/feature-addition` để thêm tính năng mới
```

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-prepare-deployment SKILL.md không tồn tại (STOP)
- **E014** — sub-skill fail sau retry

Chi tiết: `_shared.md §Error Handling Reference`.
