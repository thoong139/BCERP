# Plan: /wf-manage-change v3.0 Overhaul

> **Trạng thái:** DRAFT v0.1 — Đã hoàn tất 7 tài liệu, chờ user review để bắt đầu Sprint 1.

## Cấu trúc tài liệu

| File | Trạng thái | Mục đích |
|------|------------|----------|
| [`00-master-plan.md`](./00-master-plan.md) | DRAFT v0.1 | Tổng quan: mục tiêu, hiện trạng, định hướng giải pháp, roadmap |
| [`01-findings.md`](./01-findings.md) | DRAFT v0.1 | Chi tiết 10 findings (3 P0, 4 P1, 3 P2) với evidence + line numbers |
| [`02-architecture-design.md`](./02-architecture-design.md) | DRAFT v0.1 | Schemas đầy đủ, file layout, bash script samples, session structure |
| [`03-decisions-pending.md`](./03-decisions-pending.md) | DRAFT v0.1 | 6 quyết định cần xác nhận + đề xuất + tradeoffs |
| [`sprints/sprint-1-foundation.md`](./sprints/sprint-1-foundation.md) | DRAFT v0.1 | Bash scripts + common helpers |
| [`sprints/sprint-2-lock-heartbeat.md`](./sprints/sprint-2-lock-heartbeat.md) | DRAFT v0.1 | Lock + heartbeat + sessions.jsonl |
| [`sprints/sprint-3-change-impact.md`](./sprints/sprint-3-change-impact.md) | DRAFT v0.1 | change-impact.json schema + builder script |
| [`sprints/sprint-4-template-fixes.md`](./sprints/sprint-4-template-fixes.md) | DRAFT v0.1 | Template + schema consistency |
| [`sprints/sprint-5-phase-updates.md`](./sprints/sprint-5-phase-updates.md) | DRAFT v0.1 | Phase files → bash delegation + lock integration |
| [`sprints/sprint-6-contract-wiring.md`](./sprints/sprint-6-contract-wiring.md) | DRAFT v0.1 | SKILL.md + _contract.json + 00-core.md §4b |
| [`sprints/sprint-7-e2e-test.md`](./sprints/sprint-7-e2e-test.md) | DRAFT v0.1 | E2E test + evals + compliance audit |
| [`progress.md`](./progress.md) | ACTIVE | Tracking tiến độ triển khai |

## Tóm tắt 6 quyết định cần chốt

| ID | Decision | Đề xuất |
|----|----------|---------|
| D1 | index.json → sessions.jsonl migration window | **Ngay v3.0** (skill mới, không có backward-compat concern) |
| D2 | Lock mechanism | **Per-session `.session.lock`** + **per-registry `registry.lock`** — copy pattern từ wf-fix-bugs |
| D3 | change-impact.json scope | **3 consumer skills**: wf-verify-sync, wf-preflight, wf-implement-feature — opt-in flag `--from-manage-change` |
| D4 | Template phase-summary.md | **Tạo minimal template** (CORE-031 compliance) + giữ free-form population |
| D5 | Session ID format | **`YYYY-MM-DD-{slug}-{NN}`** — đồng bộ wf-fix-bugs v7, wf-scan-target v2 |
| D6 | Bash scripts placement | **`.claude/scripts/wf-manage-change/`** — đúng pattern wf-implement-feature v4 |

## Phạm vi skill bị tác động

- **1 skill duy nhất:** `wf-manage-change` (SKILL.md + 10 procedure files + 9 templates + 1 evals + 1 contract)
- **10 bash scripts MỚI** trong `.claude/scripts/wf-manage-change/`

## Skills KHÔNG bị tác động

Tất cả skills khác (brainstorm, analyze-requirements, define-features, design, design-ux, plan-modules, implement-feature, fix-bugs, fix-triage, fix-execute, fix-functional/business/security/performance/ux-a11y/data/compat, legacy-*, scan-target, verify-sync, prepare-deployment, preflight, add-scope, annotate-code) → **zero impact** trong v3.0.

3 skills sẽ **tùy chọn** consume artifact mới `change-impact.json` qua flag `--from-manage-change`:
- `wf-verify-sync` — cross-check registry changes
- `wf-preflight` — scope affected files
- `wf-implement-feature` — Pre-Implementation Safety Gate enhancement

## Mục tiêu sau v3.0

| Tiêu chí | v2.0.3 | v3.0 target | Cải thiện |
|----------|--------|-------------|-----------|
| Token avg / run trung bình | ~85k | ~55k | **-35%** |
| Concurrent multi-dev safe | Khong | Co | + |
| Resume reliability | ~75% | ~95% | **+20pp** |
| CORE-031 template compliance | ~90% | 100% | **+10pp** |
| Cross-skill machine-readable handoff | Khong | Co | + |
| Bash scripts delegation | 0 scripts | 10 scripts | + |
| Protocol references complete | ~70% | 100% | **+30pp** |

## Critical findings phải fix (P0)

3 findings P0 phải fix trong v3.0:

| ID | Tom tat | Sprint |
|----|---------|--------|
| G1 | KHONG co Lock/Heartbeat — race condition tren registry + index.json | S2 |
| G2 | index.json KHONG concurrent-safe — JSON corruption khi 2 dev ghi cung luc | S2 |
| G3 | KHONG co bash script delegation — ton token, kho debug | S1 |

## Roadmap timeline

```
Total estimate:    ~12h
Sequential path:   7 sprints
```

```
S1  (2h)  Foundation: Bash scripts + common helpers                 [P1 → Token]
S2  (2h)  Lock/Heartbeat + sessions.jsonl migration                 [P0 → Correctness]
S3  (1.5h) change-impact.json Schema + Builder                      [P1 → Cross-skill]
S4  (1h)  Template + Schema Fixes                                    [P1 → Quality]
S5  (2h)  Phase Files Update: inline → bash delegation + lock       [P0+P1 → All]
S6  (1.5h) SKILL.md + _contract.json + 00-core.md §4b wiring       [P1 → Integration]
S7  (2h)  E2E test + evals + compliance audit                       [P0 → Verification]
```

## Cách review

1. Đọc theo thứ tự:
   - `00-master-plan.md` — overview
   - `03-decisions-pending.md` — 6 quyết định cần chốt
   - `01-findings.md` — evidence chi tiết 10 findings
   - `02-architecture-design.md` — schemas + code samples
   - Sprint files theo thứ tự S1→S7
2. Phản hồi:
   - Đồng ý với 6 quyết định trong `03-decisions-pending.md`?
   - Có findings nào cần re-prioritize?
   - Sprint sequencing có cần điều chỉnh?
3. Sau approve → bắt đầu **Sprint 1 (Foundation: Bash Scripts + Common Helpers)** — 2h estimate.

## Definition of Done (toàn dự án v3.0)

- [ ] 7 sprints "Done" theo từng sprint §Definition of Done
- [ ] 10 bash scripts trong `.claude/scripts/wf-manage-change/` hoạt động
- [ ] skill-compliance-audit.sh wf-manage-change PASS
- [ ] validate-schema-sync.sh wf-manage-change PASS
- [ ] All evals green (15 hiện tại + ≥3 mới)
- [ ] CORE-007 §4b updated (1 entry cross-skill mới cho change-impact.json)
- [ ] _contract.json version bump to 3.0.0
- [ ] E2E test trên EUREKA-2026 pass
- [ ] CHANGELOG entry
