# Fix Plan

> **Muc dich:** Ke hoach phat hien va sua loi trong du an.
>
> **Ai viet:** `/wf-fix-triage` (Phase 2) — dung shared template `_shared/lane/templates/fix-plan.md`
>
> **Khi viet:** Sau khi Lane Dispatch (wf-fix-bugs Phase 0-2) xong → Triage phan loai issues → Viet file nay
>
> **Cap nhat:** `/wf-fix-execute` append progress sau moi batch/phase hoan thanh
>
> ---
>
> **Convention cho implementer:**
> - **Bracket placeholders** `[...]` (vi du: `[FIX-YYYYMMDD-NNN]`, `[PROJECT_NAME]`, `[N]`) → PHAI replace bang gia tri thuc te khi tao file output.
> - **Shell variable references** `$SESSION_DIR` (vi du: `$SESSION_DIR/fix-plan.md`) → GIU NGUYEN — day la pattern document cho user hieu path theo scope, KHONG phai placeholder. User doc se tu resolve theo scope cua minh.
> - **Literal examples** (vi du: `.mc-data/work/wf-fix-bugs/sessions/2026-04-28-module-payment-01/`) tai Bang §7.2 → giu nguyen nhu example, khong thay.

---

## Meta Information

| Muc | Gia tri |
|-----|---------|
| **Fix ID** | `[FIX-YYYYMMDD-NNN]` |
| **Project** | `[PROJECT_NAME]` |
| **Scope** | `all / system / module` |
| **Scope Name** | `[System/Module ID]` |
| **User Description** | `[mo ta loi tu user]` |
| **Dry Run** | `[YES / NO]` |
| **Deep Scan** | `[YES / NO]` |
| **Run Tests** | `[YES / NO]` |
| **Large Project Mode** | `[YES / NO]` |
| **Created** | `[YYYY-MM-DD HH:mm:ss]` |
| **Last Updated** | `[YYYY-MM-DD HH:mm:ss]` |
| **Status** | `In Progress` / `Completed` / `Error` |

---

## 1. Scope Overview

### 1.1 Bug Discovery Scope

| Metric | Gia tri |
|--------|---------|
| Scope type | `[all / system / module]` |
| Systems in scope | `[N]` |
| Modules in scope | `[N]` |
| Source directories | `[dirs]` |
| REQ-IDs in scope | `[N]` |
| Deprecated modules (LEGACY_MODE) | `[N]` |
| Runtime Discovery | `[ENABLED / DISABLED / SKIPPED]` |
| App URL | `[url hoac "N/A"]` |
| Pages to scan | `[N routes]` |
| Deep Scan | `[ENABLED / DISABLED]` |
| Deep Scan Pages | `[N routes / M sessions]` |
| Preflight score (before) | `[N/100]` |

### 1.2 Severity Distribution

| Severity | Count | Action |
|----------|-------|--------|
| CRITICAL | `[N]` | Fix ngay, Batch 1 (sequential) |
| HIGH | `[N]` | Fix Batch 2 (parallel) |
| MEDIUM | `[N]` | Fix Batch 3 |
| LOW | `[N]` | Log, skip hoac Batch 3 tuy type |
| **Total** | `[N]` | — |

### 1.3 Fixability Distribution

| Fixability | Count | Action |
|------------|-------|--------|
| AUTO_FIX | `[N]` | wf-fix-execute tu fix (lint, type, format) |
| AGENT_FIX | `[N]` | Spawn developer/security/frontend/dba agent |
| ESCALATE | `[N]` | Log + recommend skill/action (khong fix) |
| SKIP | `[N]` | Log only |

---

## 2. Pipeline Breakdown (3 sub-skills)

### 2.1 Execution Plan

> **Pure Orchestrator Pattern (v6.0.0+):** `/wf-fix-bugs` KHONG co procedures rieng — thuc hien Lane Dispatch (Phase 0-2), sau do delegate: **wf-fix-triage → wf-fix-execute**.

```
┌─ Orchestrator: /wf-fix-bugs — Lane Dispatch ─────────────────┐
│  Phase 0-1: Dimension Scan (QD1-QD10 parallel)  ⏳ ~5-20 min │
│    Status: ⬜ Pending                                          │
│    ├── QD1: Functional Correctness (route, API, UI)           │
│    ├── QD2: Business Correctness (domain, calc, fixture)      │
│    ├── QD3: Security (CVE, secret, auth, OWASP)               │
│    ├── QD4: Performance (CWV, bundle, query, render)          │
│    ├── QD5: A11y (WCAG, contrast, ARIA, keyboard)             │
│    ├── QD6: Data Integrity (schema drift, migration, ORM)     │
│    ├── QD7: Compatibility (deprecated API, browser, polyfill) │
│    └── QD8: Observability & Reliability (retry/CB, log/metric)│
│  Phase 2: Aggregation → issue-registry.json (initial)         │
│    Output: $SESSION_DIR/fix-status.json + issue-registry.json │
│            $SESSION_DIR/lanes/QD*/signals.json (per-lane)     │
│            $SESSION_DIR/lanes/QD*/evidence/ (screenshots)     │
└───────────────────────────────────────────────────────────────┘
                            ↓
┌─ Sub-skill 1: /wf-fix-triage ───────────────────────────────┐
│  Phase 2: Triage                       ⏳ ~5 min            │
│    Status: ⬜ Pending                                        │
│    ├── Scope filter (multi-source)                          │
│    ├── Severity classification (CRITICAL/HIGH/MEDIUM/LOW)   │
│    ├── Fixability classification (AUTO_FIX/AGENT_FIX/...)   │
│    ├── Domain detection per issue                           │
│    ├── Issue ID assignment (ISSUE-001..NNN)                 │
│    └── Orphan UI issues merge (--deep mode)                 │
│    Output: $SESSION_DIR/bug-triage.md                       │
│            $SESSION_DIR/fix-plan.md (THIS FILE)             │
│            $SESSION_DIR/issue-registry.json (enriched)      │
│            $SESSION_DIR/fix-log.json (init, entries=[])     │
│    [DRY-RUN: Van tao files, wf-fix-execute skip Phase 3-5]  │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌─ Sub-skill 2: /wf-fix-execute ──────────────────────────────┐
│  Phase 3: Fix Code                     ⏳ ~15-40 min        │
│    Status: ⬜ Pending                                        │
│    ├── Batch 1: CRITICAL (sequential)      ⏳ ~10 min       │
│    │   └── CHECKPOINT ✓                                     │
│    ├── Batch 2: HIGH (PARALLEL)            ⏳ ~15 min       │
│    │   ├── developer agent (test/logic)                     │
│    │   ├── security agent (security issues)                 │
│    │   ├── frontend-developer (UI)                          │
│    │   ├── dba agent (database)                             │
│    │   └── CHECKPOINT ✓                                     │
│    └── Batch 3: MEDIUM/LOW + AGENT_FIX     ⏳ ~10 min       │
│        └── CHECKPOINT ✓                                     │
│                                                              │
│  Phase 4: Docs Sync                    ⏳ ~5-15 min         │
│    Status: ⬜ Pending                                        │
│    ├── Phase 4a: Sync existing docs (behavior_changed)     │
│    └── Phase 4b: Stub creation (--deep only, CORE-027 CDG) │
│                                                              │
│  Phase 5: State Machine Verify Loop    ⏳ ~5-15 min         │
│    Status: ⬜ Pending                                        │
│    ├── State: VERIFY_INIT → VERIFY_SCAN → VERIFY_EVALUATE  │
│    ├── Max iterations: 3                                    │
│    ├── Loop-back to Phase 3/4 neu co regressions           │
│    └── E2E flow test (Playwright, neu app running)          │
│                                                              │
│  Phase 6: Report                       ⏳ ~3 min            │
│    Status: ⬜ Pending                                        │
│    ├── Output: $SESSION_DIR/fix-report.md                  │
│    ├── Output: $SESSION_DIR/phase-summary.md (CORE-028)    │
│    ├── Append: .mc-data/work/wf-fix-bugs/fix-history.md    │
│    └── Registry update: impl_status (safe-update)           │
│    [DRY-RUN: Van chay Phase 6 day du — preview mode]        │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Progress Tracking

| Sub-skill | Phase | Name | Status | Started | Completed | Output File |
|-----------|-------|------|--------|---------|-----------|-------------|
| wf-fix-bugs | 0-2 | Lane Dispatch | ⬜ | — | — | fix-status.json, issue-registry.json (initial), evidence/ |
| wf-fix-triage | 2 | Triage | ⬜ | — | — | bug-triage.md, fix-plan.md, fix-log.json |
| wf-fix-execute | 3 | Fix Code | ⬜ | — | — | Fixed source files, fix-log.json |
| wf-fix-execute | 4a | Docs Sync | ⬜ | — | — | Updated feature specs |
| wf-fix-execute | 4b | Stub Creation (--deep) | ⬜ | — | — | Stubs in phase2-features/, phase4-ux/ |
| wf-fix-execute | 5 | Verify Loop | ⬜ | — | — | e2e-results.json (optional) |
| wf-fix-execute | 6 | Report | ⬜ | — | — | fix-report.md, phase-summary.md, fix-history.md |

**Overall Progress:** `0% (0/8 phases completed)`

---

## 3. Fix Batch Plan

### 3.1 Batch 1: CRITICAL (sequential)

| # | ID | Issue | File | REQ-ID | Domain | Agent | Status |
|---|----|-------|------|--------|--------|-------|--------|
| 1 | ISSUE-001 | `[issue description]` | `[path]` | `[REQ-XXX-NNN]` | `[domain]` | `developer` | ⬜ |

### 3.2 Batch 2: HIGH (parallel)

| # | ID | Issue | File | REQ-ID | Domain | Agent | Sub-Batch | Status |
|---|----|-------|------|--------|--------|-------|-----------|--------|
| 1 | ISSUE-NNN | `[test failure]` | `[path]` | `[REQ-XXX-NNN]` | `[domain]` | `developer` | A | ⬜ |
| 2 | ISSUE-NNN | `[security issue]` | `[path]` | `[REQ-XXX-NNN]` | `security` | `security` | B | ⬜ |
| 3 | ISSUE-NNN | `[UI bug]` | `[path]` | `[REQ-XXX-NNN]` | `frontend` | `frontend-developer` | C | ⬜ |
| 4 | ISSUE-NNN | `[DB issue]` | `[path]` | `[REQ-XXX-NNN]` | `database` | `dba` | D | ⬜ |

### 3.3 Batch 3: MEDIUM/LOW + AGENT_FIX

| # | ID | Issue | File | REQ-ID | Domain | Agent | Status |
|---|----|-------|------|--------|--------|-------|--------|
| 1 | ISSUE-NNN | `[issue description]` | `[path]` | `[REQ-XXX-NNN]` | `[domain]` | `developer` | ⬜ |

### 3.4 Escalated / Skipped

| # | ID | Issue | Fixability | Reason | Recommended Action |
|---|----|-------|-----------|--------|-------------------|
| 1 | ISSUE-NNN | `[issue]` | ESCALATE | `[reason]` | `/wf-design-ux` hoac `/wf-plan-modules` |
| 2 | ISSUE-NNN | `[issue]` | SKIP | Informational only | Log |

---

## 4. Domain Expert Routing

| Issue Domain | Expert Agent | Issues Count |
|-------------|-------------|-------------|
| General code | `developer` | `[N]` |
| Security | `security` | `[N]` |
| Database | `dba` | `[N]` |
| Frontend/UI | `frontend-developer` | `[N]` |
| Backend API | `developer` | `[N]` |
| Mobile | `mobile-developer` | `[N]` |
| DevOps/Infra | `devops` | `[N]` |
| Embedded/IoT | `embedded-engineer` | `[N]` |

---

## 5. Docs Sync Assessment (Phase 4a)

| Feature Spec | Behavior Changed | API Contract Changed | Action | Status |
|-------------|-----------------|---------------------|--------|--------|
| `[feature].md` | `[YES / NO]` | `[YES / NO]` | `[UPDATE / SKIP]` | ⬜ |

### 5.1 Stub Creation Plan (--deep only — Phase 4b)

> CORE-027 Critical Decision Gate: Truoc khi tao stub phai hien thi summary va hoi user xac nhan.

| # | Orphan UI Type | Proposed Stub Path | Matched Module | Status |
|---|---------------|-------------------|----------------|--------|
| 1 | `ACTION / SCREEN / FLOW` | `.mc-data/docs/phase2-features/[sys]/[mod]/[slug].md` | `[MOD-ID]` | ⬜ |

---

## 6. Context Sources

### 6.1 Required Inputs

| Input | Location | Status |
|-------|----------|--------|
| req-registry.json | `.mc-data/docs/_meta/req-registry.json` | `[FOUND / NOT_FOUND]` |
| Source code | `src/` or `apps/` | `[FOUND / NOT_FOUND]` |
| preflight-report.md | `.mc-data/work/wf-preflight/preflight-report.md` | `[FOUND / NOT_FOUND / OPTIONAL]` |
| Feature specs | `.mc-data/docs/phase2-features/` | `[FOUND / NOT_FOUND]` |
| legacy-decisions.json (LEGACY_MODE) | `.mc-data/work/wf-brainstorm/legacy-decisions.json` | `[FOUND / N/A]` |

---

## 7. Expected Outputs

### 7.1 Fix Artifacts

| File | Sub-skill | Phase | Description | Status |
|------|-----------|-------|-------------|--------|
| `issue-registry.json` | discover → triage → execute | 1/2/5 | Issue tracker (init → enriched → verify results) | ⬜ |
| `bug-triage.md` | triage | 2 | Triage report + execution plan summary | ⬜ |
| `fix-plan.md` (this file) | triage | 2 | This file | ⬜ |
| `fix-log.json` | triage → execute | 2/3/5 | Per-issue fix details + verify iterations | ⬜ |
| Fixed source files | execute | 3 | Code fixes | ⬜ |
| Updated feature specs | execute | 4a | Docs sync (neu behavior doi) | ⬜ |
| Stub docs | execute | 4b | Orphan UI stubs (--deep only) | ⬜ |
| `e2e-results.json` | execute | 5 | Playwright E2E results (optional) | ⬜ |
| `fix-report.md` | execute | 6 | Final fix report (preview neu dry-run) | ⬜ |
| `phase-summary.md` | execute | 6 | CORE-028 tieng Viet summary | ⬜ |

### 7.2 Status Files

> Duong dan thuc te phu thuoc vao session — xem SESSION_DIR Resolution trong `.claude/skills/workflow/wf-fix-bugs/procedures/session-dir.md`.

| File | Duong dan (theo session) | Description |
|------|--------------------------|-------------|
| `fix-status.json` | `$SESSION_DIR/fix-status.json` | Runtime status tracking (shared by 3 sub-skills) |
| `checkpoint.json` | `$SESSION_DIR/checkpoint.json` | Checkpoint for resume (contains partial_state.deep_scan_state) |
| `fix-plan.md` | `$SESSION_DIR/fix-plan.md` | This file |
| `bug-triage.md` | `$SESSION_DIR/bug-triage.md` | Triage report |
| `issue-registry.json` | `$SESSION_DIR/issue-registry.json` | Issue tracker |
| `fix-log.json` | `$SESSION_DIR/fix-log.json` | Per-issue fix log |
| `fix-report.md` | `$SESSION_DIR/fix-report.md` | Per-run fix report |
| `phase-summary.md` | `$SESSION_DIR/phase-summary.md` | CORE-028 summary |
| `fix-history.md` | `.mc-data/work/wf-fix-bugs/fix-history.md` | Cross-session history (ROOT, append-only) |

**Vi du cu the (v7.0+ session layout):**

| Scope | SESSION_DIR | fix-status.json path |
|-------|------------|---------------------|
| `--scope=all` | `.mc-data/work/wf-fix-bugs/sessions/2026-04-28-all-01/` | `.mc-data/work/wf-fix-bugs/sessions/2026-04-28-all-01/fix-status.json` |
| `--scope=system --name=SYS-ERP` | `.mc-data/work/wf-fix-bugs/sessions/2026-04-28-system-erp-01/` | `.../sessions/2026-04-28-system-erp-01/fix-status.json` |
| `--scope=module --name=MOD-PAYMENT` | `.mc-data/work/wf-fix-bugs/sessions/2026-04-28-module-payment-01/` | `.../sessions/2026-04-28-module-payment-01/fix-status.json` |

---

## 8. Checkpoint & Resume Strategy

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context Warning | 65% | Log warning, continue |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |
| Batch Complete | Any | Save checkpoint with batch data |
| Deep Scan Page Batch | Sau moi 3 pages | CHECKPOINT `checkpoint.partial_state.deep_scan_state`, check context usage |
| Verify Loop Iteration | Moi iteration | Update `fix-status.json.phases.phase_5.loop_state` |

### 8.1 Resume Routing

Orchestrator resume theo `fix-status.json.active_skill`:

| active_skill | Resume Command |
|--------------|---------------|
| `wf-fix-triage` | `/wf-fix-triage --resume` |
| `wf-fix-execute` | `/wf-fix-execute --resume` |
| `wf-fix-bugs` | `/wf-fix-bugs --resume` (orchestrator resume tu next_action) |

---

## 9. Notes

*[Ghi chu them ve bugs, root cause analysis, domain-specific notes, LEGACY_MODE considerations, v.v.]*

---

*This plan was auto-generated by DEVKIT `/wf-fix-triage` skill (Phase 2), using shared template `.claude/skills/workflow/_shared/lane/templates/fix-plan.md`.*
