# Phase 7: Verify — Sync Check & Final Report

> Kiểm tra traceability requirements ↔ features ↔ code qua sub-skill `wf-verify-sync`.
> In final report + mark workflow `completed`.

## PRE-GATE

- Preflight completed (`"preflight"` in `phases_completed[]`) HOẶC user confirm tiếp tục sau WARN

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 7.1 | Hiển thị: `▶ Verify: Kiểm tra Traceability` | - | - |
| 7.2 | Verify `.claude/skills/workflow/wf-verify-sync/SKILL.md` tồn tại | Read | File exists (else E004) |
| 7.3 | Gọi `Skill("wf-verify-sync")` | Skill | Sub-skill POST-GATE pass |

## POST-GATE

```bash
test -f .mc-data/docs/_meta/verify-sync.md
```

Nếu POST-GATE fail → retry tối đa 2 lần → nếu vẫn fail → E009 (WARNING, cho phép tiếp tục sau user xác nhận).

- `$STATUS_FILE.phases_completed += "verify"`
- `$STATUS_FILE.current_phase = "completed"`
- `$STATUS_FILE.updated_at = now()`
- Xóa lock file: `rm -f .mc-data/work/feature-addition/.lock`

## Final Workflow Report

```
🎉 Feature Addition Workflow hoàn thành!
─────────────────────────────────────────
[✅/⏭] Phase 1: Scope Addition
[✅]    Phase 2: Feature Definitions — [N] features mới
[✅/⏭] Phase 3: Architecture Update
[✅/⏭] Phase 4: UX Design
[✅]    Phase 5a: Implementation Plan
[✅]    Phase 5b: Code — [M]/[N] features implemented ([S] skipped)
[✅]    Preflight: Health Check — [PASS/WARN]
[✅]    Verify: Traceability

📁 Outputs:
   - .mc-data/docs/phase2-features/
   - .mc-data/docs/phase5-implementation/
   - .mc-data/work/wf-preflight/preflight-report.md
   - .mc-data/docs/_meta/verify-sync.md

🚀 Next:
   - /status           — xem tổng tiến độ dự án
   - /wf-prepare-deployment (nếu release)
   - /wf-fix-bugs      (nếu có issues phát sinh)
```

### Output Files summary

| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | Feature specs | `.mc-data/docs/phase2-features/[sys]/[mod]/` | Đặc tả features mới |
| 2 | Implementation plan | `.mc-data/docs/phase5-implementation/` | Kế hoạch + task files |
| 3 | Preflight report | `.mc-data/work/wf-preflight/preflight-report.md` | Health check |
| 4 | Verify report | `.mc-data/docs/_meta/verify-sync.md` | Traceability |
| 5 | Status tracking | `.mc-data/work/feature-addition/feature-addition-status.json` | Workflow state |

## Errors liên quan

- **E004** — wf-verify-sync SKILL.md không tồn tại
- **E009** — verify POST-GATE fail sau 2 retries → WARNING, cho phép tiếp tục

Chi tiết: `_shared.md §Error Handling Reference`.
