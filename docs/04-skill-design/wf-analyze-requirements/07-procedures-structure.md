# 07 — Procedures Structure

> **Mục đích file:** Outline 16 procedure files (lazy-load) + `_shared` module imports.

---

## 1. Layout

```
.claude/skills/workflow/wf-analyze-requirements/procedures/
├── _shared.md                          ← Cross-cutting concerns (NOT loaded standalone)
├── phase0-context.md                   ← Entry: project detection, session init, --resume/--status
├── phase0.5-workload-gate.md           ← Workload estimation + gate (3 zones)
├── phase1-scope.md                     ← Scope decision (all/business/module)
├── phase2-plan.md                      ← Expert mapping + analyze-plan.md
├── phase3-ba-parta.md                  ← Spawn BA → Part A dept docs
├── phase3.5-legacy.md                  ← LEGACY_MODE naming normalization (CORE-015)
├── phase4-experts-partb.md             ← Lane Dispatch parallel experts (ADR-OPT-01)
├── phase5-existing-docs.md             ← Merge existing docs (LEGACY HAS_EXISTING_DOCS)
├── phase6-consolidate.md               ← Signal Aggregation dedup (ADR-OPT-04)
├── phase6b-workflow.md                 ← Cross-dept workflow (scope=all)
├── phase6c-stakeholder.md              ← Stakeholder review (scope=all)
├── phase6d-conflict.md                 ← Conflict resolution (scope=all)
├── phase8-registry.md                  ← Registry update DIRECT (NO AGENT)
├── phase8b-crossval.md                 ← Cross-validation auto-fix loop max 3
└── phase8c-handoff.md                  ← Handoff digests + Template Strip (ADR-OPT-05)
```

---

## 2. `_shared.md` content (reference-only)

| Section | Mục đích |
|---------|---------|
| **§State Variables** | `$LEGACY_MODE`, `$HAS_EXISTING_DOCS`, `$SCOPE`, `$DEPT_LIST`, `$EXPERT_MAPPING`, `$WORKLOAD_RATIO`, `$SESSION_DIR`, `$CI_CONTEXT` |
| **§Atomic Write + Template Strip** | `atomic_write_json()`, `strip_template_metadata()` (recursive `_*` key removal), `dual_write()` (sessions + flat) |
| **§Agent Templates** | 8-section prompt cho BA + 28 domain experts (CORE-037) |
| **§LEGACY Context Injection** | Đọc `project-context.md` + `legacy-decisions.json` → inject vào BA/expert prompts |
| **§Fix Rules** | `missing_dept_doc` → re-create from context; `expert_conflict` → Phase 6d resolve; `registry_schema_error` → normalize fields; `traceability_gap` → backfill REQ-ID anchors |
| **§Resolution Tracks** | AUTO-RESOLVE / EXPERT-RESOLVE / DEFER-TO-DESIGN classification |
| **§Registry Schema** | Safe-write fields_owned, narrow jq update pattern |
| **§Error Codes Reference** | Full table E000-E060 + CDG-A01/A02 |
| **§Output Report Template** | Final analyze-report.md format |
| **§_shared Module Imports** | Lane dispatcher, partition planner, aggregator, cache, CDG helpers |

---

## 3. `_shared` module imports (ADR-OPT integration)

| Module | Import | Phase | Mục đích |
|--------|--------|-------|---------|
| `_shared/lane` | `from lane import dispatch_lanes, LaneConfig` | Phase 4 | Dept-expert lane dispatch, max_parallel=3 |
| `_shared/partition` | `from partition import plan_partitions, check_workload_gate` | Phase 0.5 | Workload estimation + gate evaluation |
| `_shared/aggregate` | `from aggregate import aggregate_lane_signals, dedup_by_id` | Phase 6 | REQ-ID dedup giữa dept-lanes |
| `_shared/cache` | `from cache import get_cached, set_cached, compute_content_hash` | Phase 0.5 | Cache check (P1, không P0) |
| `_shared/cdg` | `from cdg import create_cdg_token, check_anti_loop` | Phase 0.5, 6d | CDG-A01/A02 |

Import convention: `_shared/_shared.md §3-4`.

---

## 4. Phase procedure template (4 sections)

Mỗi `phaseN-*.md` tuân theo cấu trúc:

### A — Header

```markdown
# Phase N: {Tên phase}

**Đầu vào:** {file/state}
**Đầu ra:** {file/state}
**Auto-fix budget:** N retries
**Time estimate:** X min
**Load khi:** {condition}
```

### B — PRE-GATE (T1→T4)

### C — Steps

```markdown
## Steps

| # | Mô tả | Tool/Agent | Output |
|---|------|-----------|--------|
| N.1 | Read template | Read | content |
| N.2 | Populate | Edit/Agent | tmp |
| N.3 | Validate | Bash (jq) | pass/fail |
| N.4 | Atomic write | Bash | output |
```

### D — POST-GATE (T1→T4)

### E — Phase Report (CORE-028)

---

## 5. Per-phase responsibility (16 files)

| File | Key responsibility |
|------|-------------------|
| `phase0-context.md` | LEGACY_MODE detect (CORE-021), session init, `--resume`/`--status` handlers, digest load |
| `phase0.5-workload-gate.md` | EST_MINUTES compute, 3-zone gate (dead/warn/block), CDG-A02 override |
| `phase1-scope.md` | Parse scope arg, set `$SCOPE`, decide phase 6b/6c/6d skip |
| `phase2-plan.md` | Domain detection, expert mapping per dept, build `analyze-plan.md` |
| `phase3-ba-parta.md` | Spawn `business-analyst` agent → Phần A cho mỗi dept |
| `phase3.5-legacy.md` | Naming normalization (CORE-015), legacy module mapping |
| `phase4-experts-partb.md` | **Lane Dispatch (ADR-OPT-01)**: spawn expert per dept parallel, max 3 concurrent, write `lanes/{dept}/signals.json` |
| `phase5-existing-docs.md` | Detect existing dept docs (LEGACY), merge logic — preserve user content |
| `phase6-consolidate.md` | **Signal Aggregator (ADR-OPT-04)**: read all lanes, dedup REQ-ID, flag conflicts |
| `phase6b-workflow.md` | Spawn workflow agent → cross-dept business workflow |
| `phase6c-stakeholder.md` | Spawn stakeholder agent → stakeholder-review.md |
| `phase6d-conflict.md` | Classify findings: AUTO-RESOLVE / EXPERT-RESOLVE / DEFER-TO-DESIGN |
| `phase8-registry.md` | **DIRECT** (NO AGENT) — main conversation Read/Write registry, narrow jq update per field |
| `phase8b-crossval.md` | 8 validation checks, auto-fix loop max 3 iterations, all-checks re-run sau mỗi fix |
| `phase8c-handoff.md` | Generate `dept-digests.json` + `phase1-handoff.json`, **Template Strip (ADR-OPT-05)**, copy to `_meta/` canonical |

---

## 6. SKILL.md routing (lazy-load contract)

`SKILL.md` (lean routing ~420 dòng) chứa Phase Mapping table:

```markdown
## SKILL.md ↔ procedures/ Phase Mapping

| SKILL.md Phase | procedures/ files | Mô tả |
| --- | --- | --- |
| Phase 0: Auto-Detection | phase0-context.md | Detect project, session init |
| Phase 1: Phân tích Requirements | phase1-scope.md → phase2-plan.md → phase3-ba-parta.md → ... → phase6d-conflict.md | Multi-phase analysis |
| Phase 2: Registry Update | phase8-registry.md → phase8b-crossval.md | Safe-write registry |
| Phase 3: Handoff Artifacts | phase8c-handoff.md | Generate digests + strip |
```

Load-on-Demand: AI chỉ đọc phase file đang thực thi + `_shared.md` — tiết kiệm ~85-90% tokens so với monolithic.

---

## 7. Resume + Status handlers (inline trong `phase0-context.md`)

### `--resume`

```
1. Discover session: --session=<id> OR latest pointer OR newest in sessions/
2. Read session-state.json → next_phase = phases.next_action
3. Re-validate PRE-GATE of next_phase
4. Load procedures/_shared.md + procedures/{next_phase}.md
5. Continue execution
```

### `--status`

```
1. Read sessions/{id}/checkpoint.json (legacy) OR session-state.json
2. Filesystem reconciliation: count actual dept files vs checkpoint.depts_completed
3. Display:
   - Phase status table
   - Lanes completed (Phase 4)
   - Aggregation stats (Phase 6)
   - Iterations (Phase 8b)
   - Files on disk vs checkpoint
4. STOP (no execution)
```

---

## 8. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Pattern: [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md) — 8-section BA + experts
- Rules: CORE-032, CORE-035, CORE-037, CORE-038
- Source SKILL.md: [`.claude/skills/workflow/wf-analyze-requirements/SKILL.md`](../../../.claude/skills/workflow/wf-analyze-requirements/SKILL.md)
- `_shared` package: [`.claude/skills/workflow/_shared/`](../../../.claude/skills/workflow/_shared/)
