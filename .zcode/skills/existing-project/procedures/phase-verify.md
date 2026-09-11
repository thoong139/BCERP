# Phase Verify: Sync Check

> Kiểm tra traceability — đảm bảo mọi requirement được implement đúng. `wf-verify-sync`
> tự đối chiếu registry vs code (REQ-ID/FEAT-ID comments) và sinh `verify-sync.md`.

## PRE-GATE

- Ít nhất 1 feature có `impl_status == "done"`
- preflight-report.md tồn tại HOẶC user confirm skip preflight

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| v.1 | Hiển thị: `▶ Phase Verify: Kiểm tra Traceability` | - | - |
| v.2 | Verify `.claude/skills/workflow/wf-verify-sync/SKILL.md` tồn tại | Read | File exists (else E004) |
| v.3 | Gọi `Skill("wf-verify-sync")` | Skill | Sub-skill POST-GATE pass |

## POST-GATE

```bash
test -f .mc-data/docs/_meta/verify-sync.md
```

Nếu fail → E009 → retry tối đa 2 lần; nếu vẫn fail → WARNING, cho phép tiếp tục với user xác nhận.

## Status File Update

```bash
jq '
  .phases_completed += ["verify"]
  | .current_step = "deployment"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Transition

```
✅ Phase Verify hoàn thành — traceability check passed
  Report: .mc-data/docs/_meta/verify-sync.md

→ Next: phase6-deployment
```

Hỏi user xác nhận tiếp tục.

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-verify-sync SKILL.md không tồn tại (STOP)
- **E009** — verify-sync.md không tồn tại sau 2 retries → WARNING

Chi tiết: `_shared.md §Error Handling Reference`.
