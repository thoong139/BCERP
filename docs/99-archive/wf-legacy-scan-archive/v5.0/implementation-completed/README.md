# Implementation Plan — wf-legacy-scan v4.1 → v5.0

> **Trạng thái:** Planning v1.0 · **Draft** · Chuẩn bị trước Phase B
> **Design reference:** [../README.md](../README.md) (v2.1)
> **Ngày tạo:** 2026-04-22
> **Mục đích:** Kế hoạch chi tiết cho 10 phases (A-J) theo [../07-migration-plan.md](../07-migration-plan.md).
>
> **North Star:** Triển khai chính xác theo design, không skip checkpoint, không shortcut backward-compat verification.

---

## Mục Đích Folder Này

Design v2.1 đã chốt **WHAT** (17 ADRs, 11 documents). Implementation folder này chốt **HOW** cho mỗi phase:

1. Mỗi phase 1 file action plan chi tiết (từng task có acceptance criteria + verify command).
2. Master plan điều phối phases theo dependency + parallel opportunities.
3. Checklist per deliverable để tránh miss item.
4. Session log per run để audit.

---

## Cấu Trúc Folder

```
implementation/
├── README.md                          ← File này — overview + navigation
├── 00-master-plan.md                  ← Dependency graph + parallel schedule + milestones
├── 01-session-protocol.md             ← Cách làm việc mỗi session (handoff, context mgmt)
├── phases/                            ← Action plan chi tiết per phase
│   ├── phase-A-design-closure.md
│   ├── phase-B-foundation.md
│   ├── phase-C-profiles-ips-vn.md
│   ├── phase-D-agents-submigration.md
│   ├── phase-E-checkpoint-concurrency-cache.md
│   ├── phase-F-impact-incremental.md
│   ├── phase-G-bash-refactor.md
│   ├── phase-H-resume-routing.md
│   ├── phase-I-integration-testing.md
│   └── phase-J-migration-docs.md
├── checklists/                        ← Deliverable checklists
│   ├── _template-task-checklist.md    ← Template cho task checklist
│   ├── backward-compat-lock.md        ← Verify standard=v4.1 checklist
│   ├── post-gate-t1-t4.md             ← POST-GATE verification checklist
│   ├── template-files.md              ← 7 new templates cần tạo
│   └── sub-skill-migration.md         ← Sub-skill Phase D migration checklist
└── session-logs/                      ← Log per implementation session (append-only)
    └── SESSION-LOG-TEMPLATE.md
```

---

## Thứ Tự Đọc

### Cho người quản lý (PMO)
1. [00-master-plan.md](00-master-plan.md) — dependency graph + timeline
2. [phases/phase-A-design-closure.md](phases/phase-A-design-closure.md) — start here

### Cho người triển khai
1. [01-session-protocol.md](01-session-protocol.md) — cách làm việc per session
2. [phases/phase-{X}-*.md](phases/) — chi tiết phase hiện tại
3. [checklists/](checklists/) — verify deliverables

### Cho reviewer
1. [checklists/backward-compat-lock.md](checklists/backward-compat-lock.md) — ưu tiên review
2. [checklists/post-gate-t1-t4.md](checklists/post-gate-t1-t4.md)

---

## Nguyên Tắc Chung

### Sequential Dependencies
- Phase A → B → C → D → I → J (critical path).
- E, F, G có thể chạy song song sau D.
- H phụ thuộc E.

### Per-Phase Gate
Mỗi phase PHẢI pass:
1. All tasks trong action plan = completed.
2. Deliverable checklist = all green.
3. Verify commands = pass.
4. Rollback procedure = tested (dry run OK).
5. Git tag `v5.0-phase-<X>` tạo.

### Session Handoff
Mỗi session làm việc PHẢI:
1. Đọc master plan + phase plan hiện tại.
2. Chọn 1-3 tasks (không quá, tránh context overflow).
3. Ghi session log vào `session-logs/YYYY-MM-DD-{N}.md`.
4. Update phase plan task status.
5. Commit với tag phù hợp.

---

## Status Legend

| Symbol | Nghĩa |
|--------|-------|
| ⬜ | Pending (chưa bắt đầu) |
| 🟡 | In Progress (đang làm) |
| 🔵 | Blocked (chờ dependency) |
| ✅ | Completed + verified |
| ❌ | Failed / rolled back |
| ⏸️ | Paused (có checkpoint) |

---

## Current Status

| Phase | Status | Progress | Owner | Last Update |
|-------|--------|----------|-------|-------------|
| A — Design Closure | ⬜ Pending | 0/7 actions | — | 2026-04-22 |
| B — Foundation | ⬜ Pending | 0 | — | — |
| C — Profiles + IPS + VN | ⬜ Pending | 0 | — | — |
| D — Agents + Sub-migration | ⬜ Pending | 0 | — | — |
| E — Checkpoint/Concurrency/Cache | ⬜ Pending | 0 | — | — |
| F — Impact + Incremental | ⬜ Pending | 0 | — | — |
| G — Bash Refactor | ⬜ Pending | 0 | — | — |
| H — Resume Routing | ⬜ Pending | 0 | — | — |
| I — Integration + Testing | ⬜ Pending | 0 | — | — |
| J — Migration + Docs | ⬜ Pending | 0 | — | — |

**Next action:** Đọc [00-master-plan.md](00-master-plan.md) → bắt đầu [phases/phase-A-design-closure.md](phases/phase-A-design-closure.md).
