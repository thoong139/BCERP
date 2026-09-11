---
name: wf-legacy-scan
version: 5.0.1
last_updated: 2026-04-22
description: |
  Scan toan dien du an hien co: detect → classify → extract → synthesize → project-context.md.
  Orchestrator cho toan bo legacy scan pipeline (Phase 0-4).
  Tu dong phat hien hien trang du an, xac dinh strategy (S1-S7), tao inventory,
  classify files, extract requirements, va tong hop project-context.md.
  Sau khi hoan thanh → tiep tuc voi /wf-brainstorm.

  TRIGGER khi:
  - Du an hien co can duoc onboard vao DEVKIT — GOI TRUC TIEP
  - Legacy codebase can phan tich va tai lieu hoa lai (bao gom du an dang phat trien)
  - User muon DEVKIT hieu codebase hien co de tiep tuc phat trien
  - Du an da co .mc-data/ nhung chua day du — can bo sung va dong bo
  - Du an gan hoan thien — can validate va fast-track sang verify-sync
  - Du an chi co tai lieu (DOCS_ONLY) — can chuyen doi sang DEVKIT format

  KHONG trigger khi:
  - Du an moi (chua co code VA chua co docs) → dung /wf-brainstorm
  - Chi can kiem tra trang thai hien tai → /status

argument-hint: "[project-path] [--profile=surface|standard|deep|exhaustive] [--layers=L1,L2,...] [--depth=surface|standard|deep] [--session=ID] [--status] [--resume] [--re-vision] [--batch-size=N] [--incremental] [--since=<git-ref>] [--no-cache] [--cache-publish]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, AskUserQuestion
---

# /wf-legacy-scan: $ARGUMENTS

## Overview

| Muc | Noi dung |
|-----|----------|
| **Muc dich** | Scan toan dien du an hien co: detect → classify → extract → synthesize → project-context.md |
| **Prerequisites** | Project directory ton tai. `PROJECT_PATH = argument` hoac `CWD` |
| **Workflow position** | **/wf-legacy-scan** (YOU ARE HERE) → `/wf-legacy-classify` → `/wf-legacy-extract` → `/wf-brainstorm` (legacy flow) → ... |
| **Output** | `project-profile.json`, `assessment-report.json`, `inventory/*.json`, `ledger.json`, `project-context.md`, `doc-quality-map.json`, `impl-status-snapshot.json` |
| **Phases** | `0 → 0A → [0.5 maturity] → 1 → 2 → 3 → 4` |
| **Duration** | Single-session (orchestrator — delegate Phase 2 & 3 sang sub-skills) |

### Vi tri trong Workflow

```
EXISTING PATH:
  /wf-legacy-scan [project-path]  ← YOU ARE HERE
    → /wf-legacy-classify → /wf-legacy-extract
    → /wf-brainstorm* → /wf-analyze-requirements* → /wf-define-features* → /wf-design*
    → /wf-annotate-code (neu co annotation gaps)
    → /wf-design-ux* (neu co UI) → /wf-plan-modules
    (* = shared skills tu detect legacy mode)
```

### Legacy Pipeline Skills

| # | Skill | Mo ta |
|---|-------|-------|
| 1 | `/wf-legacy-scan` | Detection + Assessment + Inventory + Synthesize (YOU ARE HERE) |
| 2 | `/wf-legacy-classify` | Classify files + Glossary |
| 3 | `/wf-legacy-extract` | Extract requirements/features |
| 4 | `/wf-brainstorm*` | Phase 0 docs (legacy flow) |
| 5 | `/wf-analyze-requirements*` | Phase 1 docs (legacy flow) |
| 6 | `/wf-define-features*` | Phase 2 docs (legacy flow) |
| 7 | `/wf-design*` | Phase 3 docs + Registry + Gap Analysis (legacy flow) |
| 8 | `/wf-design-ux*` | UX docs — conditional (legacy flow) |

> `*` = shared skills tu detect legacy mode via `project-context.md` (CORE-021).

---

## Arguments

| Argument | Mo ta | Default |
|----------|-------|---------|
| `project-path` | Duong dan den thu muc goc cua du an | Current directory |
| `--profile=<p>` | Execution profile: `surface`, `standard`, `deep`, `exhaustive`. Chi phoi depth_map cho L4/L5/L6. Neu omit → IPS-A recommend + AskUserQuestion (CDG). | — (IPS recommend) |
| `--layers=L1,L2,...` | Override depth cho layers cu the (dung voi `--depth`). VD `--layers=L5 --depth=deep`. | — |
| `--depth=<d>` | Depth override cho layers trong `--layers`: `surface`, `standard`, `deep`. | — |
| `--session=ID` | Gan vao session cu the (multi-session hoac resume explicit). | — (new SESSION_ID) |
| `--status` | Hien thi trang thai TOAN BO pipeline → STOP | — |
| `--resume` | Resume tu checkpoint cuoi cung (smart routing) | — |
| `--re-vision` | Kich hoat strategy S6: RE-VISION (giu code, thay doi vision) | — |
| `--batch-size=N` | So items moi batch trong Phase 2 (truyen xuong `/wf-legacy-classify`) | 100 |
| `--incremental` | Chi re-process files da thay doi. Neu ko co `--since` → mtime compare voi previous scan-state; neu co → git diff mode. Xem `05-profiles-ips.md §6` + `02-scan-layers.md §7`. Logic implement: `_shared/ips/incremental.py`. | false |
| `--since=<git-ref>` | Dung voi `--incremental` — diff HEAD vs ref qua `git diff --name-status --find-renames=80`. VD `--since=HEAD~5`, `--since=main~2`, `--since=<sha>`. YEU CAU git repo. | — |
| `--no-cache` | Bypass scan cache (force fresh probe). | false |
| `--cache-publish` | Sau khi scan xong, copy session cache → project cache cho team share. | false |

> **Profile resolver chi tiet:** Xem `procedures/phase0b-profile.md` — entry-point sau Phase 0A, truoc Phase 1.

---

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 1 (Accuracy Assurance),
> Protocol 2 (Auto-Correction), Protocol 3 (Context & Checkpoint), Protocol 6 (Token Limit Prevention),
> Protocol 9 (Task Planning), Protocol 10 (POST-GATE Schema Validation), Protocol 19 (Template Usage Rule).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables Glossary, Tech Stack Verification,
> External Docs Scan, Agent Prompt Templates, Error Handling.

### Execution Strategy

| Phase | Mode | Agent limit | Ghi chu |
|-------|------|-------------|---------|
| 0 Detection | **DETERMINISTIC** — bash scripts | 0 | Pure detection |
| 0A Assessment | **HYBRID** — script + AI | 0 | Scoring + strategy selection |
| 0.5 Maturity | **HYBRID** — validate + score | 0 | Existing DEVKIT validation |
| 1 Inventory | **DETERMINISTIC** — bash scripts | 0 | Pure enumeration |
| 2 Classify | **Agent Delegation** — bounded context | 1 (general) | Classify via `/wf-legacy-classify` |
| 3 Extract | **Agent Delegation** — bounded context | 1 (general) | Extract via `/wf-legacy-extract` |
| 4 Synthesize | **Main Context** — truc tiep | 0 | Tao project-context.md + companions |

### Template Usage Rule (CORE-031)

> **BAT BUOC:** Moi file co template PHAI duoc tao bang pattern:
> 1. **READ** template file tu `templates/` directory
> 2. **POPULATE** values (thay the placeholders)
> 3. **WRITE** output file
>
> KHONG viet tu dau — luon doc template truoc de dam bao dung schema.
> Chi tiet: `procedures/_shared.md §Template Usage Rule (CORE-031)`.

---

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools duoc auto-detect, khong hoi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → check per-tool TTL. Read `.mc-data/work/_meta/code-intelligence.json` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Graceful: lock held → fallback Grep/Glob. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sanh HEAD vs index_commit. Short-circuit: non-git → skip. SEVERE (>20 behind) → warning: "Index stale — scan results may be outdated vs current code." | Freshness status set |

### CI-ROUTE: Scan Stages (Protocol 20 §20.5)

> **Khi CI tools available:** Dung GitNexus + Serena de tang toc scan thay vi Glob/Grep thu cong.
> **Graceful:** CI unavailable → fallback Glob/Grep (current behavior, zero regression).

| Stage | CI Task | Primary Tool | Fallback | Purpose |
|-------|---------|-------------|----------|---------|
| 1 (Inventory) | `project_structure` | **Serena** `onboarding` / **GitNexus** `clusters` | Glob | Hieu cau truc du an + functional areas |
| 2 (Analysis) | `understand_flow` | **GitNexus** `query({key_concept})` | Grep + Read | Tim execution flows + symbols cho key concepts |
| 2 (Analysis) | `symbol_overview` | **Serena** `get_symbols_overview` | Read file | Hieu cau truc file quan trong |
| 3 (Extraction) | `find_by_annotation` | **GitNexus** `cypher` (REQ-ID search) | Grep | Tim tat ca REQ-ID annotations |

> **Freshness caveat:** Neu index behind > 0 → "Results based on index N commits behind HEAD."

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHONG chua execution steps. Toan bo logic chi tiet duoc lazy-load
> qua cac phase files rieng. Read MOI phase file CHI KHI toi phase tuong ung de giam context load.

| Phase | Procedure file | Dieu kien | Muc dich |
|-------|---------------|-----------|----------|
| **Resume/Status** | `procedures/resume-status.md` | `--status` hoac `--resume` | Dispatch handler TRONG Phase 0 sau Session Init (Step 0.0c → Step 0.2a/0.2b) |
| **0** | `procedures/phase0-detection.md` | Always (entry point) | Detection + tech stack verify + `--status/--resume` dispatch |
| **0A** | `procedures/phase0a-assessment.md` | Always | Assessment scoring + strategy selection (S1-S7) |
| **0B** | `procedures/phase0b-profile.md` | Always (v5.0+) | Profile resolver + IPS-A + depth_map + AskUserQuestion (CDG) |
| **0.5** | `procedures/phase05-maturity.md` | `$MATURITY_LEVEL IN (DEVKIT_PARTIAL, DEVKIT_COMPLETE, NEAR_COMPLETE)` | Maturity validation — refine `$STAGE_MODES` |
| **1** | `procedures/phase1-inventory.md` | Always | Inventory scan (screens, APIs, docs, sources, dependencies, external docs) |
| **2** | `procedures/phase2-classify.md` | `$STAGE_MODES.classify != "skip"` | Agent delegation → `/wf-legacy-classify` |
| **3** | `procedures/phase3-extract.md` | `$STAGE_MODES.extract != "skip"` | Agent delegation → `/wf-legacy-extract` |
| **4** | `procedures/phase4-synthesize.md` | Always | Synthesize `project-context.md` + companions |

### Routing Flow

```
SKILL.md entry → Parse arguments
  ├── --status → Read procedures/resume-status.md §--status Handler → STOP
  ├── --resume → Read procedures/resume-status.md §--resume Handler → route to last in_progress phase
  └── Fresh run → Read procedures/phase0-detection.md → execute → return
       ↓
Read procedures/phase0a-assessment.md → execute → return
       ↓
Read procedures/phase0b-profile.md → execute (IPS-A + AskUserQuestion CDG + depth_map) → return
       ↓ (neu $MATURITY_LEVEL DEVKIT_PARTIAL+)
Read procedures/phase05-maturity.md → execute → return
       ↓
Read procedures/phase1-inventory.md → execute → return
       ↓ (neu $STAGE_MODES.classify != "skip")
Read procedures/phase2-classify.md → spawn Agent → POST-GATE validate → return
       ↓ (neu $STAGE_MODES.extract != "skip")
Read procedures/phase3-extract.md → spawn Agent → POST-GATE validate → return
       ↓
Read procedures/phase4-synthesize.md → execute → return → STOP (DONE)
```

> **Moi phase file la self-contained** — chua PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE, Next Phase.
> Phase file tham chieu `procedures/_shared.md` cho cross-cutting concerns.

---

## Phase Summary (condensed — chi tiet trong procedure files)

> Moi phase chi tiet duoc lazy-load qua procedure files tuong ung. Day la overview ngon gon.

### Phase 0 — Detection

| Step | Action |
|------|--------|
| 0.1 | Parse arguments (`$PROJECT_PATH`, flags) |
| 0.2 | Run `legacy-scan-detect.sh` → `project-profile.json` |
| 0.3 | PRE-GATE: project directory exists |
| 0.4 | POST-GATE: `project-profile.json` valid (T1-T4) |

### Phase 0A — Assessment

| Step | Action |
|------|--------|
| 0A.1 | Run `legacy-scan-assess.sh` → `assessment-report.json` |
| 0A.2 | Select strategy S1-S7 based on scores |
| 0A.3 | PRE-GATE: `project-profile.json` valid |
| 0A.4 | POST-GATE: strategy selected, assessment written |

### Phase 0B — Profile Resolver + IPS-A

| Step | Action |
|------|--------|
| 0B.1 | Resolve `$PROFILE` (CLI flag or IPS-A recommendation) |
| 0B.2 | Run IPS-A → recommend profile if omitted |
| 0B.3 | CDG: AskUserQuestion to confirm profile (if not explicit) |
| 0B.4 | Write `depth_map` to `scan-state.json` |
| 0B.5 | POST-GATE: `scan-state.json` valid, `depth_map` complete |

### Phase 1 — Inventory

| Step | Action |
|------|--------|
| 1.1 | Run `legacy-scan-inventory.sh` → 8 inventory files |
| 1.2 | Run `ui-coverage-scan.sh` → `ui-manifest.json` (conditional) |
| 1.3 | Run IPS-B → `domain-hints.json` |
| 1.4 | PRE-GATE: assessment completed |
| 1.5 | POST-GATE: all required inventory files present (T1-T4) |

### Phase 2 — Classify (Agent delegation)

| Step | Action |
|------|--------|
| 2.1 | PRE-GATE: inventory completed, `ledger.json` valid |
| 2.2 | Spawn Agent `/wf-legacy-classify` |
| 2.3 | POST-GATE: `classified/` present, naming normalized |

### Phase 3 — Extract (Agent delegation)

| Step | Action |
|------|--------|
| 3.1 | PRE-GATE: classify completed |
| 3.2 | Spawn Agent `/wf-legacy-extract` |
| 3.3 | POST-GATE: `extracted/` present, `module-code-mapping.json` valid |

### Phase 4 — Synthesize

| Step | Action |
|------|--------|
| 4.1 | PRE-GATE: extract completed |
| 4.2 | Generate `project-context.md` from template |
| 4.3 | Generate `doc-quality-map.json`, `impl-status-snapshot.json` |
| 4.4 | Generate `ledger.json` (orchestrator-only — ADR-LS04) |
| 4.5 | POST-GATE: `project-context.md` > 500B (CORE-021), all outputs valid (T1-T4) |

---

## Fix Rules

| Error Type | Auto-Fix Strategy |
|-----------|-------------------|
| `project-profile.json` invalid/empty | Re-run `legacy-scan-detect.sh` |
| Strategy selection ambiguous (S1 vs S5) | AskUserQuestion + CDG |
| Inventory script partial output | Re-run inventory for missing files |
| `scan-state.json` corrupted | Fallback to `ledger.json` (ADR-LS04) |
| Sub-skill (classify/extract) fails | Log to `error-ledger.json`, surface to user |
| `project-context.md` < 500B | Retry synthesis with more extracted data |

---

## Error Handling

> **Canonical table:** xem `procedures/_shared.md §Error Handling`. Bang duoi day
> chi lai reference quick lookup. Neu mau thuan → `_shared.md` la SSOT.

### Namespace convention (v5.0)
Error codes duoc phan chia theo phase namespace de tranh collision:
- **E001-E014** — Pipeline-level (general errors, resume, lock) — xem `_shared.md`
- **E015-E019** — Phase 0 Detection (incremental flags, detect script)
- **E020-E029** — Phase 0B Profile Resolver (invalid profile/layer/depth)
- **E030-E039** — Phase 0.5 Maturity Validation
- **E040-E049** — Phase 2/3 Classify/Extract (agent delegation, spot-check)
- **E0101-E0199** — Phase 1 Workload Gate (CDG user choices)
- **E-L6-XX** — Layer 6 Synthesis non-blocking issues
- **W0B01-W0B05** — Phase 0B profile warnings (informational)
- **W0101-W0102, I0101** — Phase 1 Workload Gate info/warning
- **W-L6-XX** — Layer 6 warnings

### Quick lookup (canonical table trong `_shared.md §Error Handling`)

| Code | Condition | Action | Defined in |
|------|-----------|--------|------------|
| E001 | Project directory not found | STOP | `_shared.md` |
| E002 | Project path empty (0 files) | STOP | `_shared.md` |
| E003 | Detect script fail | RETRY x3, STOP | `_shared.md` |
| E004 | Inventory 0 items | RETRY x3, STOP | `_shared.md` |
| E005 | Pipeline already COMPLETE | ASK: re-scan / cancel | `_shared.md` |
| E006 | `scan-state.json` corrupt on resume | Fallback to `ledger.json` | `_shared.md` |
| E007 | Lock held by other process (< stale) | STOP — inform user | `_shared.md` |
| E008 | Lock stale (>= LOCK_STALE_MINUTES) | Auto-release, warn, continue | `_shared.md` |
| E009 | Cache read error | Bypass cache, continue | `_shared.md` |
| E010 | IPS-A/B failure (non-blocking) | Fallback profile=standard, log warning | `phase0b-profile.md` |
| E011 | Workload Gate abort (user choice C) | Clean exit, `pipeline_status=aborted_by_workload_gate` | `phase1-inventory.md` |
| E012 | Context > 90% | FORCE checkpoint, STOP | `_shared.md` |
| E013 | > 30% stale on resume | WARN, AskUserQuestion | `_shared.md` |
| E015-E018 | Phase 0 incremental flag validation | STOP with hint | `phase0-detection.md` |
| E020-E025 | Phase 0B profile/layer/depth invalid | STOP | `phase0b-profile.md` |
| E040-E049 | Phase 2/3 agent output invalid / spot-check fail | Re-spawn x1, escalate | `phase3-extract.md` |

---

## Output Files

### Session-scoped outputs (NEW v5.0 — per session, tại `sessions/{id}/`)

> **ADR-LS05:** Session isolation runtime-only — session dir chua working state, output cuoi tai standard location.

| # | File | Layer | Template |
|---|------|-------|----------|
| S1 | `sessions/{id}/scan-state.json` | L1 (init) | `templates/scan-state.json` |
| S2 | `sessions/{id}/scan-plan.md` | L1 (init) | `templates/scan-plan.md` |
| S3 | `sessions/{id}/phase-summary.md` | L6 (finalize) | `templates/phase-summary.md` |
| S4 | `sessions/{id}/session-digest.md` | L6 (finalize) | `templates/session-digest.md` |
| S5 | `sessions/{id}/error-ledger.json` | L1 (init) | `templates/error-ledger.json` |
| S6 | `sessions/{id}/session-log.json` | moi layer | (inline — CORE-026 append-only) |
| S7 | `sessions/{id}/events.jsonl` | moi layer | (inline — agent spawn/complete events) |

### Standard location outputs (unchanged v4.1 paths + new v5.0 additions)

| # | File | Path | Layer | Template |
|---|------|------|-------|----------|
| 1 | `project-profile.json` | `.mc-data/work/legacy-scan/` | L1 (IPS-A) | (script output, schema ref: `templates/project-profile.json`) |
| 2 | `assessment-report.json` | `.mc-data/work/legacy-scan/` | L2 (IPS-A) | `templates/assessment-report.json` |
| 3 | `ledger.json` | `.mc-data/work/legacy-scan/` | Init L2 (Phase 0A), incrementally updated through phases, finalized POST L6 (Phase 4) — orchestrator-only ADR-LS04 | `templates/ledger.json` |
| 4 | `domain-hints.json` *(NEW v5.0)* | `.mc-data/work/legacy-scan/` | IPS-B | `templates/domain-hints.json` |
| 5 | `inventory/screens.json` | `.mc-data/work/legacy-scan/inventory/` | L3 | (script output, schema ref: `templates/inventory/screens.json`) |
| 6 | `inventory/api-endpoints.json` | `.mc-data/work/legacy-scan/inventory/` | L3 | (script output) |
| 7 | `inventory/doc-files.json` | `.mc-data/work/legacy-scan/inventory/` | L3 | (script output) |
| 8 | `inventory/source-files.json` | `.mc-data/work/legacy-scan/inventory/` | L3 | (script output) |
| 9 | `inventory/dependency-graph.json` | `.mc-data/work/legacy-scan/inventory/` | L3 | (script output) |
| 10 | `inventory/external-docs.json` | `.mc-data/work/legacy-scan/inventory/` | L3 | (schema ref: `templates/inventory/external-docs.json`) |
| 11 | `inventory/ui-manifest.json` *(conditional)* | `.mc-data/work/legacy-scan/inventory/` | L3 | (schema ref: `templates/inventory/ui-manifest.json`) |
| 12 | `inventory/doc-classified.json` *(DOCS_ONLY)* | `.mc-data/work/legacy-scan/inventory/` | L3 | `templates/inventory/doc-classified.json` |
| 13 | `project-context.md` | `.mc-data/work/legacy-scan/` | L6 | `templates/project-context.md` |
| 14 | `doc-quality-map.json` | `.mc-data/work/legacy-scan/` | L6 | `templates/doc-quality-map.json` |
| 15 | `impl-status-snapshot.json` | `.mc-data/work/legacy-scan/` | L6 | `templates/impl-status-snapshot.json` |
| 16 | `impact-graph.json` *(NEW v5.0, conditional)* | `.mc-data/work/legacy-scan/` | L6 | `templates/impact-graph.json` |

> **Backward compat (rollback period):** `legacy-scan-status.json` va `legacy-scan-plan.md` van duoc ghi tai `.mc-data/work/legacy-scan/` trong v5.0 nhung deprecated. Se bo o v5.1 (ADR-LS04 breaking change).

### Phase L4 & L5 outputs (created by sub-skills via Agent delegation)

| File | Path | Created by |
|------|------|------------|
| `classified/batch-*.json`, `classified/glossary.json`, `classify-naming-fixes.json` | `.mc-data/work/legacy-scan/classified/` | `/wf-legacy-classify` (L4) |
| `extracted/{module}.json`, `module-code-mapping.json`, `dedup-report.json` | `.mc-data/work/legacy-scan/` | `/wf-legacy-extract` (L5) |

---

## Pipeline State Machine

```
START → 0:Detection → 0A:Assessment → [0.5:MaturityVal (DEVKIT_PARTIAL+ only)]
  → 1:Inventory → 2:Classify (Agent) → 3:Extract (Agent) → 4:Synthesize
  → DONE (next: /wf-brainstorm)
```

---

## Next Step

Sau khi hoan thanh Phase 0-4 (full pipeline):

```
→ Tiep tuc: /wf-brainstorm
  (shared skills tu detect LEGACY_MODE tu project-context.md — CORE-021)
```

> **Standalone mode:** User van co the chay `/wf-legacy-classify` va `/wf-legacy-extract` rieng le
> neu can re-run 1 stage cu the.

---

## Related Skills

| Skill | Quan he |
|-------|---------|
| `/existing-project` | Orchestrator workflow — goi wf-legacy-scan lam buoc dau |
| `/wf-brainstorm` | Alternative cho du an HOAN TOAN moi |
| `/wf-legacy-classify` | Phase 2 delegate — classify files tu inventory |
| `/wf-legacy-extract` | Phase 3 delegate — extract requirements/features |
| `/wf-brainstorm` (legacy flow) | Next step — tao Phase 0 docs |
| `/wf-analyze-requirements` (legacy flow) | Downstream — tao Phase 1 docs |
| `/wf-define-features` (legacy flow) | Downstream — tao Phase 2 docs |
| `/wf-design` (legacy flow) | Downstream — tao Phase 3 docs + registry + gap analysis |
| `/wf-design-ux` (legacy flow) | Downstream (conditional) — UX docs tu frontend code |
| `/wf-plan-modules` | Downstream — luon chay sau pipeline |

---

## References

| File | Purpose |
|------|---------|
| `procedures/_shared.md` | Cross-cutting protocols, state vars, tech stack verify, external docs, agent prompts, error handling |
| `procedures/phase0-detection.md` | Phase 0 Detection detail |
| `procedures/phase0a-assessment.md` | Phase 0A Assessment detail (strategy routing, scoring) |
| `procedures/phase0b-profile.md` | Phase 0B Profile Resolver + IPS-A (v5.0+) |
| `procedures/phase05-maturity.md` | Phase 0.5 Maturity Validation detail |
| `procedures/phase1-inventory.md` | Phase 1 Inventory detail (external docs + DOCS_ONLY) |
| `procedures/phase2-classify.md` | Phase 2 Agent delegation (Classify) |
| `procedures/phase3-extract.md` | Phase 3 Agent delegation (Extract) |
| `procedures/phase4-synthesize.md` | Phase 4 Synthesize (project-context.md format) |
| `procedures/resume-status.md` | --resume & --status handlers |
| `.claude/skills/protocols/` | Protocols chung cho moi skill |
| **Templates (data schemas):** | |
| `templates/legacy-scan-status.json` | Pipeline status schema |
| `templates/ledger.json` | Pipeline state machine schema |
| `templates/assessment-report.json` | Assessment report schema |
| `templates/project-profile.json` | Project profile + tech stack schema (schema reference) |
| `templates/error-ledger.json` | Error tracking schema |
| `templates/legacy-scan-plan.md` | Execution plan template |
| `templates/session-digest.md` | Session digest template |
| `templates/project-context.md` | Project context template (CORE-021 LEGACY_MODE anchor) |
| `templates/doc-quality-map.json` | Doc quality assessment template |
| `templates/impl-status-snapshot.json` | Implementation status snapshot template (READ-ONLY — P8) |
| **Templates (inventory schemas):** | |
| `templates/inventory/screens.json` | UI screens inventory schema |
| `templates/inventory/api-endpoints.json` | API routes inventory schema |
| `templates/inventory/source-files.json` | Source code inventory schema |
| `templates/inventory/dependency-graph.json` | Dependency analysis schema |
| `templates/inventory/doc-files.json` | Documentation files schema |
| `templates/inventory/external-docs.json` | External docs schema |
| `templates/inventory/doc-classified.json` | Pre-classified docs schema (DOCS_ONLY) |
| `templates/inventory/ui-manifest.json` | UI manifest schema (conditional) |
| **Templates (v5.0 new):** | |
| `templates/scan-state.json` | Session state schema (v5.0 canonical — replaces legacy-scan-status.json) |
| `templates/scan-plan.md` | Session scan plan template |
| `templates/phase-summary.md` | Phase summary template (CORE-028 tieng Viet) |
| `templates/domain-hints.json` | Domain detection signals + confidence (IPS output, EN + VN) |
| `templates/impact-graph.json` | Impact graph schema (L6 conditional, ADR-LS14) |
| `templates/fix-workload.json` | Workload partitioning template (DEFERRED v5.1, ADR-LS13) |
| **Contract references:** | |
| `templates/legacy-scan-contract.json` | Phase 0-1 output contract |
| `templates/legacy-pipeline-contract.json` | Phase 2-5 pipeline contract (downstream) |
| **ADR references (17 total — `docs/design/skills/wf-legacy-scan/08-tradeoffs-adr.md`):** | |
| ADR-LS01 | 6 Scan Layers (L1-L6) thay 7 stages |
| ADR-LS02 | 4 Profiles: surface / standard / deep / exhaustive |
| ADR-LS03 | IPS 2-phase — Python module `_shared/ips/` |
| ADR-LS04 | scan-state.json canonical — orchestrator-only ledger.json generation |
| ADR-LS05 | Session isolation runtime-only, output tai standard location |
| ADR-LS06 | Domain-Aware Agent Delegation — backward-compat lock standard = v4.1 |
| ADR-LS07 | Bash shared library `legacy-scan-common.sh` |
| ADR-LS08 | Strategy × Profile orthogonal + source-priority formal |
| ADR-LS09 | Configurable caps env vars + CLI override |
| ADR-LS10 | Incremental scan + Scan Cache (content-addressable, 2-tier) |
| ADR-LS11 | 4-Level Checkpoint (phase/layer/batch/intra-batch) |
| ADR-LS12 | Concurrency Controller 3-tier token bucket + per-agent timeout |
| ADR-LS13 | Workload Gate detect+WARN only (Partition Planner deferred v5.1) |
| ADR-LS14 | Impact Graph tai L6 (downstream ripple support) |
| ADR-LS15 | Vietnamese Keyword Pool cho IPS domain detection |
| ADR-LS16 | Thresholds justification table bat buoc |
| ADR-LS17 | Agent Output Spot-Check (CORE-029) integration tai L4/L5 POST-GATE |
