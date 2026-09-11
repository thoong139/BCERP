# Sprint 3 — Resume + Session Init

**Sprint:** 3 of 6
**Effort estimate:** 2h
**Status:** ✅ COMPLETED 2026-05-03
**Goal:** Tạo `resume-routing.md` (dispatcher --resume/--status) và `session-init.md` (reusable session init).

---

## Tasks

| # | Task | Status |
|---|------|--------|
| 3.0 | Tạo file này | ✅ |
| 3.1 | Tạo `procedures/resume-routing.md` | ✅ |
| 3.2 | Tạo `procedures/session-init.md` | ✅ |
| 3.3 | Update `phase0-setup.md` Step 0.0 → reference resume-routing.md | ✅ |
| 3.4 | Update SKILL.md Phase Routing Map → thêm 2 entries | ✅ |
| 3.5 | Update `_contract.json` → procedure_files[] 11→13 entries | ✅ |
| 3.6 | Compliance audit | ✅ PASS |

---

## Files Created

- `.claude/skills/workflow/wf-diagram/procedures/resume-routing.md` (~145 dòng)
  - CASE A: `--status` → table display 5 sessions → STOP
  - CASE B: `--resume` → find candidates, AskUserQuestion nếu nhiều, load checkpoint, trace RESUME, route
  - Routing Table: phase_0..phase_7 → procedure files
  - CASE C: fresh run → pass-through

- `.claude/skills/workflow/wf-diagram/procedures/session-init.md` (~90 dòng)
  - SI-1: Generate SESSION_ID (slugify + collision suffix)
  - SI-2: Create directories ($SESSION_DIR, $output_path, _trace/)
  - SI-3: Init diagram-status.json (CORE-031: READ template → POPULATE → WRITE)
  - SI-4: Init checkpoint.json (CORE-031: READ template → POPULATE → WRITE)
  - SI-5: Append trace START (Protocol 15, atomic mktemp+mv)
  - POST-GATE: 4 checks
  - Called By table (phase0-setup, future reset/restart)

## Files Updated

- `procedures/phase0-setup.md` Step 0.0 — thêm reference tới resume-routing.md
- `SKILL.md` Phase Routing Map — thêm 2 entries (Resume/Status + Session Init)
- `_contract.json` procedure_files[] — 11 → 13 entries

---

## Definition of Done (Sprint 3)

- [x] `resume-routing.md` có CASE A + CASE B + Routing Table ≤ 200 dòng
- [x] `session-init.md` có SI-1..SI-5 + POST-GATE + Called By ≤ 100 dòng
- [x] `phase0-setup.md` Step 0.0 reference resume-routing.md
- [x] SKILL.md Phase Routing Map có 2 entries mới
- [x] `_contract.json` procedure_files[] = 13 entries
- [x] Compliance audit PASS

---

## Design Decisions

- **resume-routing.md vs session-init.md scope**: resume-routing.md handles dispatch logic (when to route). session-init.md handles the actual session creation steps (what to create). Clear separation.
- **No lock file in v2.0**: D4=A defer multi-dev safety to v2.1. resume-routing.md không có lock file logic.
- **No fingerprint check**: wf-diagram generates from local source code (not external target). Source changes are OK — no stale detection needed.
- **trace_file init**: Both resume-routing.md and session-init.md init `session-log.json` nếu chưa tồn tại (defensive).
