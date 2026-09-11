---
name: wf-legacy-extract
version: 2.2.0
last_updated: 2026-04-23
description: |
  Trich xuat requirements va features tu classified modules.
  Parallel processing toi da 3 agents. Stage 3 cua legacy scan pipeline.

  TRIGGER khi:
  - /wf-legacy-classify da hoan thanh (classify completed)

  KHONG trigger khi:
  - Chua co classified data

argument-hint: "[--module=<name>] [--resume] [--status]"
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, AskUserQuestion
---

# /wf-legacy-extract: $ARGUMENTS

Trich xuat requirements va features tu classified modules — Stage 3 cua legacy scan pipeline.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Muc dich** | Trich xuat requirements va features tu tung module da classify. Parallel processing toi da 3 agents |
| **Prerequisites** | `/wf-legacy-classify` completed (`ledger.stages.classify.status == "completed"`) |
| **Duration** | Single-session (SMALL), Multi-session (MEDIUM/LARGE) |
| **Phases** | 0 → 1 → 2 → 3 → 4 → 5 (6 phase files, lazy-loaded) |
| **Input** | `classified/batch-*.json`, `glossary.json`, `project-profile.json`, `dependency-graph.json`, `inventory/ui-manifest.json` (optional) |
| **Output** | `extracted/{module}.json`, `extracted/dedup-report.json`, `module-code-mapping.json`, `extracted/{module}-divergences.json` (S5 only) |

### Vi tri trong Workflow

```
EXISTING PATH:
  /wf-legacy-classify → /wf-legacy-extract ← YOU ARE HERE → /wf-brainstorm (legacy flow)
```

### Legacy Pipeline Skills

| # | Skill | Mo ta |
|---|-------|-------|
| 1 | /wf-legacy-scan | Detection + Assessment + Inventory |
| 2 | /wf-legacy-classify | Classify files + Glossary |
| 3 | **/wf-legacy-extract** | **Extract requirements/features (YOU ARE HERE)** |
| 4 | /wf-brainstorm* | Phase 0 docs (legacy flow) |
| 5 | /wf-analyze-requirements* | Phase 1 docs (legacy flow) |
| 6 | /wf-define-features* | Phase 2 docs (legacy flow) |
| 7 | /wf-design* | Phase 3 docs + Registry + Gap Analysis (legacy flow) |
| 8 | /wf-design-ux* | UX docs — conditional (legacy flow) |

> \* = shared skills tu detect legacy mode

---

## Arguments

| Argument | Mo ta | Default |
|----------|-------|---------|
| `--module=<name>` | Chi xu ly 1 module cu the | All modules |
| `--resume` | Resume tu checkpoint cuoi cung | — |
| `--status` | Hien thi trang thai extract, khong thuc thi | — |

---

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 6 (Token Limit Prevention),
> Protocol 7 (PAR), Protocol 9 (PLN), Protocol 10 (POST-GATE Schema Validation),
> Protocol 14 (Phase Summary), Protocol 15 (Session Log), Protocol 19 (Template Usage Rule).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables Glossary, Module Name Normalization,
> Domain Expert Selection, Confidence Tiers, Checkpoint Protocol.

### Template Usage Rule (CORE-031)

> **BAT BUOC:** Moi file co Template PHAI duoc tao bang pattern:
> 1. **READ** template file tu `templates/` directory
> 2. **POPULATE** — thay the placeholders bang gia tri thuc te
> 3. **WRITE** output file den destination path
>
> **NEU SKIP buoc READ template → STOP skill.**
>
> Ap dung cho:
> - **Internal templates** (4 files): `templates/extract-status.json`, `templates/extract-plan.md`, `templates/extract-checkpoint.json`, `templates/extracted-module.json`
> - **Shared templates**: `.claude/doc-framework/_meta/phase-summary.template.md`, `.claude/doc-framework/_meta/session-log.template.json`

### Execution Strategy

| Phase | Mode | Max Agents |
|-------|------|-----------|
| Phase 0 (context) | SEQUENTIAL | 0 (main only) |
| Phase 1 (resolution) | SEQUENTIAL | 0 (main only) |
| Phase 2 (extraction) | **PARALLEL per group** | 3 (business-analyst + domain expert per module) |
| Phase 3 (dedup) | SEQUENTIAL | 0 (main only) |
| Phase 4 (alignment) | SEQUENTIAL | 0 (main only, user interaction) |
| Phase 5 (verify) | SEQUENTIAL | 0-3 (auto-fix chỉ khi missing modules) |

### Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `pregate_fail` (E001) | STOP, huong dan chay prerequisite | — |
| `file_write_fail` (E004) | Retry x3, check disk space | Van fail sau 3 lan |
| `extract_module_fail` (E007) | Retry module x3, tiep tuc module khac | >30% modules fail |
| `dedup_ambiguous` (E008) | Giu ca hai (70-85%), WARNING | — |
| `circular_dependencies` (E015) | WARN, pha vo circular ref | — |
| `missing_extracted_modules` (E020) | Auto-fix x3: re-extract missing modules | Van thieu sau 3 attempts |
| `low_avg_confidence` (E022) | WARNING, log modules co confidence < 0.5 | avg_confidence < 0.4 |

---

## Phase 0: Entry (BẮT BUỘC — chạy trước tiên)

> Entry point — kiểm tra prerequisites, parse arguments, route vào `procedures/phase0-context.md`.

| Step | Action |
|------|--------|
| 1 | Kiểm tra `classify-status.json` hoặc `classified/` tồn tại — IF NOT → STOP E001 |
| 2 | Verify classify completed (`status == "completed"`) — IF NOT → STOP E001 |
| 3 | Parse args (`--status`, `--resume`, `--module`, `--skip`) |
| 4 | Route vào `procedures/phase0-context.md` (context loading + maturity check) |

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHONG chua execution steps. Toan bo logic chi tiet duoc lazy-load
> qua cac phase files rieng. Read MOI phase file CHI KHI toi phase tuong ung de giam context load.

| Phase | Procedure file | Dieu kien | Muc dich |
|-------|---------------|-----------|----------|
| **0** | `procedures/phase0-context.md` | Always (entry point) | Context Loading + PRE-GATE + `--status`/`--resume` + maturity check + init templates |
| **1** | `procedures/phase1-resolution.md` | `$MATURITY_MODE != "skip"` | Module Resolution (normalize, dedup, topological, parallel groups, domain experts, pre-compression) |
| **2** | `procedures/phase2-extraction.md` | `$MATURITY_MODE != "skip"` | Parallel Extraction — spawn agents max 3/group, write `extracted/{module}.json` per module |
| **3** | `procedures/phase3-dedup.md` | `$MATURITY_MODE != "skip"` | Cross-module Deduplication + Divergence Detection (S5 only) |
| **4** | `procedures/phase4-alignment.md` | `$MATURITY_MODE != "skip"` | Module-Code Alignment (CORE-013) — scan code projects, map, user confirm, `module-code-mapping.json` |
| **5** | `procedures/phase5-verify.md` | Always | Verification (self-diagnostic + auto-fix) + POST-GATE T1-T4 + ledger update + phase-summary |

### Routing Flow

```
SKILL.md Phase 0 → Read procedures/phase0-context.md → execute → return
   ↓ (neu $MATURITY_MODE == "skip" → JUMP thang Phase 5)
   ↓ (neu --status → hien thi → STOP)
Read procedures/phase1-resolution.md → execute → return
   ↓
Read procedures/phase2-extraction.md → execute → return
   ↓
Read procedures/phase3-dedup.md → execute → return
   ↓
Read procedures/phase4-alignment.md → execute → return
   ↓
Read procedures/phase5-verify.md → execute → return → STOP
```

> **Moi phase file la self-contained** — chua PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE rieng.
> Phase file tham chieu `procedures/_shared.md` cho cross-cutting: State Variables, Normalization, Experts, Errors.

---

## Work Directory

```
.mc-data/work/legacy-scan/
├── sessions/{session-id}/      # ★ v5.0 canonical session isolation (CORE-030)
│   └── scan-state.json          # Session-scoped state (L5 layer status — dual-write từ Phase 5)
├── extract-status.json         # Runtime status (Phase 0 → 5 updates)
├── extract-plan.md             # Execution plan (Phase 0 init, Phase 1 update)
├── extract-checkpoint.json     # Checkpoint cho resume (MEDIUM/LARGE only)
├── domain-hints.json           # (v5.0 optional input từ wf-legacy-scan IPS-B — ADR-LS06 domain expert routing)
├── extracted/
│   ├── {module}.json           # Per-module output (Phase 2)
│   ├── dedup-report.json       # Cross-module dedup (Phase 3)
│   └── {module}-divergences.json # S5 only (Phase 3)
└── module-code-mapping.json    # CORE-013 alignment (Phase 4)

.mc-data/work/wf-legacy-extract/
└── phase-summary.md            # CORE-028 summary (Phase 5)
```

> **v5.0 Dual-mode read:** Helper `scan_state_reader.py` tự ưu tiên `sessions/{id}/scan-state.json` (canonical), fallback về `ledger.json` khi session chưa tồn tại. Phase 5 dual-write cả `sessions/{id}/scan-state.json` (canonical) và `extract-status.json` (legacy).

---

## Output Files

### Standard Outputs

| # | File | Path | Phase | Template |
|---|------|------|-------|----------|
| 1 | extract-status.json | `.mc-data/work/legacy-scan/` | 0 | `templates/extract-status.json` |
| 2 | extract-plan.md | `.mc-data/work/legacy-scan/` | 0, 1 | `templates/extract-plan.md` |
| 3 | extract-checkpoint.json | `.mc-data/work/legacy-scan/` | 0, 2 | `templates/extract-checkpoint.json` |
| 4 | {module}.json | `.mc-data/work/legacy-scan/extracted/` | 2 | `templates/extracted-module.json` |
| 5 | dedup-report.json | `.mc-data/work/legacy-scan/extracted/` | 3 | — (inline schema) |
| 6 | module-code-mapping.json | `.mc-data/work/legacy-scan/` | 4 | — (inline schema) |
| 7 | phase-summary.md | `.mc-data/work/wf-legacy-extract/` | 5 | `_meta/phase-summary.template.md` |

### Conditional Outputs

| File | Khi nao | Phase |
|------|---------|-------|
| `{module}-divergences.json` | Strategy S5 hoac maturity CODE_PLUS_* | 3 |

---

## --status Display

Khi chay `/wf-legacy-extract --status`:

```markdown
## Extract Status

| Muc | Gia tri |
|-----|---------|
| Stage | 3 — Extract |
| Status | [in_progress/completed] |
| Modules | [done]/[total] ([percentage]%) |
| Extracted files tren disk | [actual] |
| Modules error | [count] |
| Requirements extracted | [count] |
| Features extracted | [count] |
| Avg confidence | [score] |
| Current module | [name] (neu in_progress) |
```

---

## Error Handling

| Code | Tinh huong | Xu ly |
|------|-----------|-------|
| E001 | PRE-GATE fail — classify chua completed | STOP, huong dan chay `/wf-legacy-classify` |
| E004 | File write fail | RETRY x3, check permissions |
| E007 | Extract fail 1 module | RETRY x3, tiep tuc modules khac |
| E008 | Dedup ambiguous (70-85%) | Giu ca hai, WARNING |
| E015 | Circular dependencies | WARN, pha vo circular ref |
| E020 | Post-Stage: missing extracted modules | Auto-fix x3, ASK user |
| E022 | Avg confidence < 0.6 | WARNING, log low-confidence modules |

---

## Agents Spawned

| Phase | Agent | Muc dich |
|-------|-------|----------|
| 2 | `business-analyst` | Extract requirements/features per module (primary) |
| 2 | Domain expert (1 in 7) | Extract domain-specific insights (finance/procurement/sales/hr/ecommerce/operations/compliance) |
| 5 | `business-analyst` | Auto-fix re-extract (nếu missing modules) |

> Chi tiet mapping module → domain expert: xem `procedures/_shared.md §Domain Expert Selection`.

---

## Related Skills

| Skill | Quan he |
|-------|---------|
| `/wf-legacy-classify` | Predecessor — tao classified data (classified/*.json, glossary.json) |
| `/wf-brainstorm` (legacy flow) | Successor — tao Phase 0 docs tu extracted data |
| `/wf-analyze-requirements` (legacy flow) | Successor — tao Phase 1 docs tu extracted data |
| `/wf-define-features` (legacy flow) | Successor — tao Phase 2 docs tu extracted data |
| `/wf-design` (legacy flow) | Successor — tao Phase 3 docs + Registry + Gap Analysis |
| `/wf-annotate-code` | Consumer — su dung module-code-mapping.json |
| `/existing-project` | Orchestrator workflow |

---

## Context & Checkpoint

Multi-session skill (LARGE projects). Checkpoint sau moi module tai Phase 2.

| Context Usage | Hanh dong |
|---------------|-----------|
| < 65% | Tiep tuc |
| 65-80% | Chuan bi checkpoint |
| 80-90% | Luu checkpoint, STOP sau module hien tai |
| > 90% | FORCE STOP |

Resume detail: xem `procedures/_shared.md §Checkpoint Protocol`.

---

## Examples

### Example 1: Happy Path (new extract)

```
Phase 0: PRE-GATE pass, maturity=full, strategy=S3 → PASS
Phase 1: 10 modules normalized, 3 parallel groups, experts assigned → PASS
Phase 2: 10 modules extracted (3 parallel x 4 waves) → 85 reqs, 52 features → PASS
Phase 3: Dedup 17 merges, 4 ambiguous → PASS
Phase 4: Mapping 8 standalone + 2 cross-cutting, user confirmed → PASS
Phase 5: POST-GATE all pass, ledger updated → DONE

Next: /wf-brainstorm (legacy flow)
```

### Example 2: Resume Session

```
SESSION 1: Phase 0-2 (4/10 modules done) → CHECKPOINT (Context: 82%)
SESSION 2 (--resume): Phase 2 (6 modules remaining) → Phase 3-5 → DONE
```

### Example 3: Single Module Filter

```
/wf-legacy-extract --module=auth
Phase 0: $MODULE_FILTER="auth" → PASS
Phase 1: Chi xu ly module auth → PASS
Phase 2: 1 agent extract auth → PASS
Phase 3-5: Van chay dedup + alignment + verify (chi 1 file) → DONE
```

### Example 4: Skip Maturity

```
Phase 0: $MATURITY_MODE="skip" → JUMP Phase 5
Phase 5: Mark completed with note "skipped_maturity" → DONE
```
