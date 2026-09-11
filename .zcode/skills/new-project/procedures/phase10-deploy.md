# Bước 9 — Phase 6: Prepare Deployment

> Delegate đến `wf-prepare-deployment`. Tạo deployment docs + user guides → Phase 6 docs.
> **Bước cuối cùng** của workflow — sau khi hoàn thành, hiển thị summary tổng thể.

**Sub-skill:** `wf-prepare-deployment`
**DEVKIT Phase:** Phase 6

## PRE-GATE

```bash
# Verify output tồn tại
test -f .mc-data/docs/_meta/verify-sync.md || exit_with E010
test -s .mc-data/docs/_meta/verify-sync.md || exit_with E010
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 9.1 | Hiển thị: `▶ Bước 9 — Phase 6: Tạo Deployment Docs` | Output | — |
| 9.2 | VERIFY `.claude/skills/workflow/wf-prepare-deployment/SKILL.md` tồn tại | Read | File loaded hoặc E004 |
| 9.3 | Gọi `Skill("wf-prepare-deployment")` — thực thi đầy đủ | Skill | — |
| 9.4 | Đợi sub-skill hoàn thành POST-GATE nội bộ | - | Sub-skill done |

## POST-GATE

```bash
test -f .mc-data/docs/phase6-deployment/stakeholder-review.md || exit_with E001
test -s .mc-data/docs/phase6-deployment/stakeholder-review.md || exit_with E001
```

Nếu POST-GATE fail → retry sub-skill (max 3 lần). Vẫn fail → E001.

## Checkpoint Update (FINAL)

Cập nhật `$STATUS_FILE`:
- `steps_completed += [9]`
- `current_step = "completed"`
- `current_phase = "completed"`
- `updated_at = now()`
- `next_action = "Workflow hoàn thành — dùng /status để xem overview hoặc /feature-addition để thêm features"`

## Final Summary

```
New Project Workflow hoàn thành!
─────────────────────────────────────
[✓] Bước 0 — Phase 0: Brainstorm
[✓] Bước 1 — Phase 1: Requirements Analysis
[✓] Bước 2 — Phase 2: Feature Definitions
[✓] Bước 3 — Phase 3: Architecture Design
[✓/SKIP] Bước 4 — Phase 4: UX/UI Design
[✓] Bước 5 — Phase 5a: Implementation Plan
[✓] Bước 6 — Phase 5b: Code Implementation (N/M features)
[✓] Bước 7 — Phase 5c: Preflight Check (PASS/WARN/FAIL)
[✓] Bước 8 — Verify: Traceability Check
[✓] Bước 9 — Phase 6: Deployment Docs

Tất cả tài liệu đã được lưu trong .mc-data/docs/
Dự án sẵn sàng để deploy!
```

### Output Files Overview

| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | Brainstorm | `.mc-data/docs/phase0-brainstorm/` | Khung dự án |
| 2 | Requirements | `.mc-data/docs/phase1-business/` | Business requirements |
| 3 | Features | `.mc-data/docs/phase2-features/` | Feature specs |
| 4 | Architecture | `.mc-data/docs/phase3-architecture/` | Technical design |
| 5 | UX/UI | `.mc-data/docs/phase4-ux/` | UX design (conditional) |
| 6 | Implementation | `.mc-data/docs/phase5-implementation/` | Sprints + tasks |
| 7 | Preflight | `.mc-data/work/wf-preflight/preflight-report.md` | Health check report |
| 8 | Deployment | `.mc-data/docs/phase6-deployment/` | Deployment docs |
| 9 | Registry | `.mc-data/docs/_meta/req-registry.json` | SSOT |
| 10 | Verify | `.mc-data/docs/_meta/verify-sync.md` | Traceability report |

## Transition (end of workflow)

```
Tiếp theo bạn có thể:
  • /status             — Xem tổng quan tiến độ
  • /feature-addition   — Thêm features mới
  • /wf-fix-bugs        — Fix bugs nếu có
```

## Errors liên quan

- **E001** — POST-GATE fail sau 3 retries → STOP
- **E004** — Sub-skill SKILL.md thiếu → STOP
- **E010** — Prerequisite fail (thiếu verify-sync.md) → báo user

Chi tiết: `_shared.md §Error Handling Reference`.
