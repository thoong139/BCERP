# wf-fix-triage — Shared Cross-Cutting Procedures

> **Sub-skill notice:** wf-fix-triage là delegate Phase 5 của wf-fix-bugs (xem `wf-fix-bugs/procedures/_shared.md`).
> File này CHỈ chứa sections đặc thù triage. Các cross-cutting concerns chung được reference từ wf-fix-bugs.

## Cross-Reference với wf-fix-bugs Shared

Các sections sau dùng chung với wf-fix-bugs (đọc `wf-fix-bugs/procedures/_shared.md`):

| Section | Source canonical | Mục đích |
|---------|------------------|----------|
| §1 State Variables Glossary | `wf-fix-bugs/procedures/_shared.md §1` | `$SESSION_DIR`, `$FLAGS`, `$TARGET_*`, `$LARGE_PROJECT`, ... |
| §3 Atomic Write Pattern | `wf-fix-bugs/procedures/_shared.md §3` | Build tmp → validate JSON → atomic mv |
| §4 Error Handling Canonical | `wf-fix-bugs/procedures/_shared.md §4` | Namespace convention E001-E109, canonical codes |
| §6 On Failure Standard Format | `wf-fix-bugs/procedures/_shared.md §6` | error-ledger append + auto-fix budget |
| §7 Execution Trace (CORE-026) | `wf-fix-bugs/procedures/_shared.md §7` | session-log.json JSON array atomic write |
| §8 Phase Summary (CORE-028) | `wf-fix-bugs/procedures/_shared.md §8` | Vietnamese ≤15-20 dòng format |
| §10 Template Usage Rule (CORE-031) | `wf-fix-bugs/procedures/_shared.md §10` | READ→POPULATE→WRITE, strip `_*` fields |
| §12 CI Detection Pattern (Protocol 20) | `wf-fix-bugs/procedures/_shared.md §12` | CI PRE-GATE 3-step (Na/Nb/Nc), cache TTL |
| §13 Lock/Heartbeat Pattern | `wf-fix-bugs/procedures/_shared.md §13` | acquire_lock + heartbeat daemon |
| §16 Session Isolation Protocol (CORE-030) | `wf-fix-bugs/procedures/_shared.md §16` | sessions/{id}/ + JSONL index |

---

## §T1 CI-ROUTE Bug Investigation (Triage-specific)

> Bổ sung cho `wf-fix-bugs/procedures/_shared.md §12.CI-ROUTE Matrix`. Triage cần investigation theo bug context — không phải scan toàn dự án.

| Triage Task | Primary Tool | Secondary | Fallback | Use Case |
|-------------|-------------|-----------|----------|----------|
| **Live impact fallback** (severity bump) | GitNexus `impact({target, direction:"upstream"})` | Serena `find_referencing_symbols` | Grep | Step 2.1c — bug ở file → check blast radius để bump severity |
| **Fixability escalation** (Serena refs count) | Serena `find_referencing_symbols` | GitNexus `context({name})` | Grep symbol | Step 2.2a — >20 refs → fixability bump MANUAL_FIX |
| **Cross-module impact detection** | GitNexus `impact()` + `query()` | — | Grep import paths | Step 2.1d — bug có dimension QD10 → trace module pairs |
| **REQ-ID context** | GitNexus `cypher` + Serena `find_refs` | — | Grep REQ-* | Issue có req_ids[] → cross-reference upstream docs |

**Graceful Degradation:**
- CI lock held → fallback Grep (no regression)
- Index stale `> 20 commits behind HEAD` → WARN but proceed (chỉ blast radius có thể missing recent changes)
- Non-git environment → skip CI, Grep-only

---

## §T2 Phase 2 POST-GATE Tiered Validation Pattern

> Reference: `wf-fix-bugs/procedures/_shared.md §4 Canonical Codes` cho error codes. Chi tiết jq scripts: `procedures/phase2-triage.md §POST-GATE`.

| Tier | Check | FAIL → |
|------|-------|--------|
| T1 | File existence (`test -s`): bug-triage.md, fix-plan.md, issue-registry.json, fix-log.json, phase-summary.md | E_T001 retry max 3 → escalate T007 |
| T2 | Structure (jq parse JSON + grep required headers in markdown) | E_T002 retry, escalate T010 |
| T3 | Content depth (issues[] has severity+fixability+domain; phase-summary ≤20 lines + required sections) | E_T003 retry với additional context |
| T4 | Cross-reference (escalations.json exists nếu có MANUAL_FIX/ESCALATE) | E_T004 build escalations.json |
| T5 | **Anti-Invention** — bug-triage.md/fix-plan.md KHÔNG chứa FORBIDDEN_PATTERN; issue-registry fixability ∈ canonical 5 | E_T005 retry, escalate T012 |
| T6 | **Profile Coverage** — exhaustive profile KHÔNG được SKIP MEDIUM/LOW vì 'budget' | E_T006 retry, escalate T013 |

---

## §T3 Phase 2 Output Schema References

| File | Schema | Owner |
|------|--------|-------|
| `bug-triage.md` | Markdown — Summary + Execution Plan + Coverage sections | wf-fix-triage Step 2.3 |
| `fix-plan.md` | Markdown — Batch 1/2/3 từ `_shared/lane/templates/fix-plan.md` | wf-fix-triage Step 2.3a |
| `issue-registry.json` | issue-registry-v2 (CORE-036) — UPDATE in-place, add severity+fixability+domain+user_journey_broken | wf-fix-triage Step 2.3b (SAFE-UPDATE) |
| `fix-log.json` | fix-log-v2 từ `_shared/lane/templates/fix-log.json` — init only, entries=[] | wf-fix-triage Step 2.3c |
| `phase-summary.md` | CORE-028 format (Vietnamese, ≤20 lines, sections required) | wf-fix-triage Step 2.8 |
| `escalations.json` | escalations-v1 (xem POST-GATE jq builder trong `phase2-triage.md`) | wf-fix-triage POST-GATE (conditional) |

---

> **Notice (XF-07b extraction):** File này tạo theo F01.017 + audit 2026-05-15 Sprint 4. Trước đây wf-fix-triage không có `procedures/_shared.md`. Cross-cutting concerns chung (state vars, atomic write, ...) reference sang `wf-fix-bugs/procedures/_shared.md` để tránh dual source of truth (F02.002).
