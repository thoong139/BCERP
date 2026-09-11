# 07 — Procedures Structure

> **Mục đích file:** Outline 11 procedure files (lazy-load) + `_shared.md` cross-cutting concerns.

---

## 1. Layout

```
.claude/skills/workflow/wf-design/procedures/
├── _shared.md                       ← Cross-cutting (NOT loaded standalone)
├── phase0-context.md                ← Entry: registry load, LPM detect, session init, --resume/--status
├── phase0.5-workload-gate.md        ← Workload Gate (ADR-OPT-03)
├── phase1-architecture.md           ← Architecture Lane Dispatch per system (ADR-OPT-01)
├── phase2-specs-parallel.md         ← Specs Lane Dispatch per system (Option A 3 specs trong cùng lane)
├── phase3-integration.md            ← Signal Aggregation dual-dedup (ADR-OPT-04)
├── phase4-crossval.md               ← Conflict resolution + Cross-Validation loop max 3
├── phase5-review.md                 ← Stakeholder Review PARALLEL architect + security
├── phase6-finalize.md               ← Registry safe-write design_status + Compressed Spec
├── phase7-gap.md                    ← LEGACY Gap Analysis SEQUENTIAL (KHÔNG lane)
└── phase8-digest-summary.md         ← Template Strip + Atomic Write + canonical sync
```

---

## 2. `_shared.md` content

| Section | Mục đích |
|---------|---------|
| **§State Variables** | `$LEGACY_MODE`, `$HAS_AI_ML`, `$HAS_DATA_PIPELINE`, `$HAS_AUTOMATION`, `$LPM_MODE`, `$LPM_PARAMS`, `$SCOPE`, `$SESSION_DIR`, `$CI_CONTEXT` |
| **§Architecture Documentation Labels** | `[VERIFIED]` (existing code confirmed), `[INFERRED]` (suy luận từ requirements), `[RECOMMENDED]` (new design) |
| **§LEGACY Context Injection** | Đọc `project-context.md` + `legacy-decisions.json` → inject vào architect/dba/devops prompts |
| **§Agent Prompt Templates** | 8-section CORE-037 cho 7 agent types |
| **§Checkpoint Protocol** | 3-level: L1 phase, L2 lane (per system), L3 agent (intra-lane) |
| **§Token Limit Prevention** | Skeleton-first, feature digest, input compression |
| **§Registry Safe-Write** | Narrow jq update `design_status` per feature |
| **§Atomic Write + Template Strip** | `strip_template_metadata()`, `atomic_write_json()`, `dual_write()` |
| **§Error Codes Reference** | Full table E000-E016 |

---

## 3. Phase procedure template (4 sections)

Mỗi `phaseN-*.md` tuân theo cấu trúc:

### A — Header
```markdown
# Phase N: {Tên}
**Đầu vào:** ...
**Đầu ra:** ...
**Auto-fix budget:** N retries
**Load khi:** condition
```

### B — PRE-GATE (T1→T4)
### C — Steps
### D — POST-GATE (T1→T4)
### E — Phase Report (CORE-028 Vietnamese)

---

## 4. Per-phase responsibility

| File | Key responsibility |
|------|-------------------|
| `phase0-context.md` | Registry load + LEGACY detect (CORE-021) + LPM eval (5 thresholds) + Approach decision + Session init (ADR-OPT-02) + `--resume`/`--status` handlers |
| `phase0.5-workload-gate.md` | Estimate + 3-zone gate + CDG override |
| `phase1-architecture.md` | **Lane Dispatch per system (ADR-OPT-01)**: spawn `architect` (+ conditional ai-engineer/data-engineer/automation-architect) per system, max parallel theo `$LPM_PARAMS`. Output: `lanes/{system}/signals.json` |
| `phase2-specs-parallel.md` | Lane per system (Option A): `api-contract` + `database-design` + `infra-spec` trong cùng lane, agents: `architect` + `dba` + `devops` |
| `phase3-integration.md` | **Signal Aggregation dual-dedup (ADR-OPT-04)**: aggregate Phase 1 + Phase 2 outputs, dedup theo `component_id` AND `api_id`, flag conflicts. Sinh `integration-map.md` SEQUENTIAL sau aggregation |
| `phase4-crossval.md` | Conflict resolution từ aggregation + 8 cross-validation checks + auto-fix loop max 3 iterations |
| `phase5-review.md` | **PARALLEL** `architect` + `security` → stakeholder-review.md với Phần B/C/D |
| `phase6-finalize.md` | Registry safe-write `design_status = "completed"` cho mỗi feature in scope + Compressed Spec (`design-summary.json`) + deferred-findings.md (conditional) |
| `phase7-gap.md` | **LEGACY-only** — SEQUENTIAL (KHÔNG lane). Cross-reference design với `module-code-mapping.json`. Output `gap-report.md`, `gap-categories.json`, `action-items.json` (STRIPPED). |
| `phase8-digest-summary.md` | Generate `design-input-digest.json` + `phase-summary.md`. **Template Strip recursive** trước khi ghi canonical `_meta/`. |

---

## 5. SKILL.md routing (lazy-load contract)

`SKILL.md` (~370 dòng) chứa Phase Routing Map:

```markdown
| Phase | Procedure file | Điều kiện |
|-------|---------------|-----------|
| 0 | procedures/phase0-context.md | Always (entry) |
| 0.5 | procedures/phase0.5-workload-gate.md | Always |
| 1 | procedures/phase1-architecture.md | Always (Lane Dispatch) |
| ... | ... | ... |
| 7 | procedures/phase7-gap.md | $LEGACY_MODE = true |
| 8 | procedures/phase8-digest-summary.md | Always |
```

Mỗi phase file là **self-contained** — chứa PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE riêng.

---

## 6. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Pattern: [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md) — 7 agents
- Rules: CORE-032, CORE-035, CORE-037, CORE-038
- Source: [`.claude/skills/workflow/wf-design/SKILL.md`](../../../.claude/skills/workflow/wf-design/SKILL.md) + [`procedures/`](../../../.claude/skills/workflow/wf-design/procedures/)
