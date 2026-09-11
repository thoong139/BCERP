---
name: wf-legacy-classify
version: 2.2.0
last_updated: 2026-04-23
description: |
  Phan loai files tu inventory vao systems/modules. Tao glossary thuat ngu domain.
  Stage 2 cua legacy scan pipeline.

  TRIGGER khi:
  - /wf-legacy-scan da hoan thanh (inventory completed)
  - User chay /wf-legacy-classify (truc tiep hoac qua /existing-project)

  KHONG trigger khi:
  - Chua co inventory (chua chay /wf-legacy-scan)

argument-hint: "[--resume] [--batch-size=N] [--status]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, AskUserQuestion
---

# /wf-legacy-classify: $ARGUMENTS

Phan loai files tu inventory vao systems/modules — Stage 2 cua legacy scan pipeline.

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Phân loại tất cả items trong inventory vào systems/modules. Tạo glossary thuật ngữ domain |
| **Prerequisites** | `/wf-legacy-scan` completed (inventory stage) |
| **Workflow position** | `/wf-legacy-scan` → **/wf-legacy-classify** ← YOU ARE HERE → `/wf-legacy-extract` |
| **Output** | `classified/batch-*.json` + `classified/glossary.json` + ledger update |
| **Phases** | 0 → 1 → 2 → 3 → 4 → 5 → 6 |
| **Duration** | Single-session (SMALL/MEDIUM), Multi-session với checkpoint (LARGE) |

### Vị trí trong Workflow

```
EXISTING PATH:
  /wf-legacy-scan → /wf-legacy-classify ← YOU ARE HERE → /wf-legacy-extract
```

### Legacy Pipeline Skills

| # | Skill | Mô tả |
|---|-------|-------|
| 1 | /wf-legacy-scan | Detection + Assessment + Inventory |
| 2 | /wf-legacy-classify | Classify files + Glossary (YOU ARE HERE) |
| 3 | /wf-legacy-extract | Extract requirements/features |
| 4 | /wf-brainstorm* | Phase 0 docs (legacy flow) |
| 5 | /wf-analyze-requirements* | Phase 1 docs (legacy flow) |
| 6 | /wf-define-features* | Phase 2 docs (legacy flow) |
| 7 | /wf-design* | Phase 3 docs + Registry + Gap Analysis (legacy flow) |
| 8 | /wf-design-ux* | UX docs — conditional (legacy flow) |

> \* = shared skills tự detect legacy mode

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `--resume` | Resume từ checkpoint cuối cùng | — |
| `--batch-size=N` | Số items mỗi batch (10-500) | 100 |
| `--status` | Hiển thị trạng thái classify | — |

---

## Template Usage Rule (CORE-031)

> **BẮT BUỘC:** Mọi file có Template PHẢI được tạo bằng pattern:
> 1. **READ** template file từ `templates/` directory
> 2. **POPULATE** — thay thế placeholders bằng giá trị thực tế
> 3. **WRITE** output file đến destination path
>
> **NẾU SKIP bước READ template → STOP skill.** Không viết output từ đầu khi template tồn tại.
>
> Áp dụng cho:
> - **Internal templates** (3 files): `templates/classify-plan.md`, `templates/glossary.json`, `templates/checkpoint.json`

---

## Protocols & Strategy

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 1 (POST-GATE), Protocol 2 (Auto-Correction), Protocol 3 (Context & Checkpoint), Protocol 6 (Token Limit Prevention), Protocol 8 (Content Quality Gate), Protocol 9 (Task Planning), Protocol 19 (Template Usage Rule).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables Glossary, Maturity Modes, DOCS_ONLY Mode, Classification Types, System vs Module Detection, Agent Prompt Templates (code-reviewer + business-analyst), Fix Rules, Error Codes, Checkpoint Protocol, Naming Convention.

- **Accuracy Assurance** (mọi phase): POST-GATE Enforcement + Fix Rules + Error Tracking
- **Auto-Correction Loop** (Phase 2, 3, 4): max 3 iterations mỗi sub-phase
- **Context & Checkpoint** (Phase 2): thresholds 65/80/90% — checkpoint mỗi 3 batches
- **Token Limit Prevention** (Phase 2): Large Project Mode — tier-based batch_size auto-reduce
- **Content Quality Gate** (Phase 5): validate batch files + glossary trước khi finalize
- **Task Planning** (Phase 1): tạo `classify-plan.md` từ template

### Execution Strategy

| Mode | Agent limit | Ghi chú |
|------|-------------|---------|
| **SEQUENTIAL** — 1 agent/batch | 1 | code-reviewer (Phase 2), business-analyst (Phase 3) |

---

## Work Directory

```
.mc-data/work/legacy-scan/
├── ledger.json                     # Pipeline ledger (shared với wf-legacy-scan)
├── sessions/{session-id}/           # ★ v5.0 canonical session isolation (CORE-030)
│   └── scan-state.json              # Session-scoped scan state (L1-L6 layer status)
├── legacy-scan-status.json         # (deprecated v5.1) Backward-compat mirror của scan-state
├── legacy-scan-plan.md             # (deprecated v5.1) Backward-compat mirror
├── checkpoint.json                 # Per-skill checkpoint (NEW v2.0.0)
├── classify-plan.md                # Phase 1 output (từ template)
├── domain-hints.json               # (v5.0 optional input từ wf-legacy-scan IPS-B)
├── classified/
│   ├── batch-1.json                # Phase 2 output
│   ├── batch-N.json
│   ├── glossary.json               # Phase 3 output
│   └── classify-naming-fixes.json  # Phase 5 output (chỉ khi CORE-016 fires)
└── error-ledger.json               # E019 tracking

.mc-data/work/wf-legacy-classify/
└── phase-summary.md                # Phase 6 output (CORE-028)
```

> **v5.0 Dual-mode read:** Helper `scan_state_reader.py` tự ưu tiên `sessions/{id}/scan-state.json` (canonical), fallback về `legacy-scan-status.json` + `ledger.json` khi session chưa tồn tại (backward-compat cho scan < v5.0).

Templates: `.claude/skills/workflow/wf-legacy-classify/templates/`

---

## Phase 0: Routing Entry (BẮT BUỘC — chạy trước tiên)

> Entry point của skill — kiểm tra prerequisites, parse arguments, và route vào `procedures/phase0-init.md`.

| Step | Action |
|------|--------|
| 1 | Kiểm tra `ledger.json` tồn tại — IF NOT → STOP E001 |
| 2 | Verify `stages.inventory.status == "completed"` — IF NOT → STOP E001 |
| 3 | Parse args (`--status`, `--resume`, `--batch-size`, `--skip`) |
| 4 | Route vào `procedures/phase0-init.md` (maturity check + skip mode handler) |

**Đặc biệt — `--status` handler:** Read `procedures/phase0-init.md §--status Handler` → hiển thị → STOP

**Đặc biệt — `--resume` handler:** Read `procedures/phase0-init.md §Resume Logic` → reconcile → tiếp tục Phase 1

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load
> qua các phase files riêng. Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase | Procedure file | Điều kiện | Mục đích |
|-------|---------------|-----------|----------|
| **0** | `procedures/phase0-init.md` | Always (entry point) | PRE-GATE + parse args + --status/--resume + maturity check + skip mode handling |
| **1** | `procedures/phase1-prepare.md` | `$MATURITY_MODE != "skip"` | Load context + compute `$UNCLASSIFIED_LIST` + tạo classify-plan.md |
| **2** | `procedures/phase2-classify.md` | `$UNCLASSIFIED_LIST` non-empty | Batch loop — spawn code-reviewer agents (1/batch) + checkpoint per 3 batches |
| **3** | `procedures/phase3-glossary.md` | Always (sau Phase 2) | Spawn business-analyst — tạo `glossary.json` từ template |
| **4** | `procedures/phase4-verify.md` | Always | Self-diagnostic >= 95% coverage + auto-fix x3 nếu thấp |
| **5** | `procedures/phase5-postgate.md` | Always | POST-GATE 4 tiers + CORE-016 Naming Consistency Check |
| **6** | `procedures/phase6-finalize.md` | Always | Update ledger + status + phase-summary.md (CORE-028) + report |

**Routing flow:**

```
SKILL.md → Read procedures/phase0-init.md → execute → return
   ↓ (nếu --status: STOP. nếu --skip: STOP với CLASSIFY SKIPPED report)
   ↓ (mode != skip: tiếp tục)
Read procedures/phase1-prepare.md → execute → return
   ↓
Read procedures/phase2-classify.md → execute (loop) → return
   ↓ (có thể STOP do context >= 80% — checkpoint, user resume sau)
Read procedures/phase3-glossary.md → execute → return
   ↓
Read procedures/phase4-verify.md → execute → return
   ↓
Read procedures/phase5-postgate.md → execute → return
   ↓
Read procedures/phase6-finalize.md → execute → return → STOP
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting: State Variables, Agent Prompts, Classification Types, Error Codes.

---

## --status Display Format

```
CLASSIFY STATUS — [project_name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Stage:    classify
Status:   [status] (completed/in_progress/pending)
Mode:     [full/delta/skip]

Progress: [completed_batches]/[total_batches] batches
Disk:     [actual_batches] batch files trên disk / [total_batches]
Items:    [items_classified]/[total_items] ([percentage]%)

Systems:  [list systems detected]
Modules:  [list modules detected]

Categories:
  screen: [N]  |  api: [N]     |  doc: [N]
  source: [N]  |  config: [N]  |  test: [N]
  asset: [N]   |  migration: [N] | type: [N]

Errors:   [error_count] (xem error_log trong legacy-scan-status.json)
Next:     [next_action]
```

---

## Output Report

### Normal Completion

```
CLASSIFY COMPLETED — [project_name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Batches:     [total_batches] ([batch_size] items/batch)
Items:       [items_classified]/[total_items] ([percentage]%)
Systems:     [N] — [list]
Modules:     [N] — [list]
Glossary:    [N] terms
Duration:    [started_at] → [completed_at]
Errors:      [error_count]

Naming fixes (CORE-016): [count_naming_fixes]

Next step: /wf-legacy-extract
```

### Skip Mode

```
CLASSIFY SKIPPED — [project_name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Reason:      Maturity level [maturity_level] — classify not needed
Status:      completed (skipped_maturity)

Next step: /wf-legacy-extract
```

**Next step:** `/wf-legacy-extract`

---

## Output Files

### Standard Output

| # | File | Path | Phase | Template |
|---|------|------|-------|----------|
| 1 | classify-plan.md | `.mc-data/work/legacy-scan/` | 1 | `templates/classify-plan.md` |
| 2 | batch-N.json | `.mc-data/work/legacy-scan/classified/` | 2 | — (inline schema) |
| 3 | glossary.json | `.mc-data/work/legacy-scan/classified/` | 3 | `templates/glossary.json` |
| 4 | classify-naming-fixes.json | `.mc-data/work/legacy-scan/classified/` | 5 | — (inline schema, conditional) |
| 5 | checkpoint.json | `.mc-data/work/legacy-scan/` | 2 (per 3 batches) | `templates/checkpoint.json` |
| 6 | phase-summary.md | `.mc-data/work/wf-legacy-classify/` | 6 | — (CORE-028 inline) |
| 7 | Ledger updates | `ledger.json` | 0, 1, 2, 6 | — (safe-write per CORE-006) |

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001 | PRE-GATE fail — `ledger.json` không tồn tại hoặc inventory chưa completed | STOP, hướng dẫn chạy `/wf-legacy-scan` |
| E006 | Classify batch timeout hoặc agent fail | Giảm batch_size / 2, retry (100→50→25→12). Escalate nếu batch_size < 10 |
| E019 | Post-Stage 2: classified < 95% inventory | Auto-fix x3, log vào `error-ledger.json`, ASK user |
| E020 | Batch JSON file corrupt (invalid JSON hoặc partial write) | Xóa batch file, re-classify batch đó. Escalate nếu > 2 batches liên tiếp |
| E021 | Glossary creation failed (business-analyst agent error) | Retry agent tối đa 2 lần. Vẫn fail → tạo glossary rỗng với warning |
| E022 | 0 unclassified items nhưng mode != skip | WARNING, ASK user xác nhận tiếp tục hay STOP |
| E023 | Invalid `--batch-size` (< 10 hoặc > 500) | STOP, hiển thị message lỗi với valid range [10-500] |

---

## Agents Spawned

| Phase | Agent | Mục đích |
|-------|-------|----------|
| 2 | `code-reviewer` | Phân loại files thành systems/modules + types (1 agent per batch) |
| 3 | `business-analyst` | Tạo glossary thuật ngữ domain từ classified data |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/wf-legacy-scan` | Predecessor — tạo inventory |
| `/wf-legacy-extract` | Successor — extract từ classified data |
| `/existing-project` | Orchestrator workflow |

---

## Examples

### Example 1: Happy Path (small-medium project)

```
Phase 0: parse args, mode=full, BATCH_SIZE=100
Phase 1: 800 items → 8 batches, classify-plan.md created
Phase 2: 8 batches × code-reviewer agent → batch-1.json...batch-8.json
Phase 3: business-analyst → glossary.json (45 terms, 12 abbr, 8 concepts)
Phase 4: coverage = 98% → PASS (no auto-fix needed)
Phase 5: POST-GATE PASS, CORE-016: 2 naming fixes (CRM→crm, OrderMgmt→order-management)
Phase 6: ledger updated, status=completed → CLASSIFY COMPLETED report

Next: /wf-legacy-extract
```

### Example 2: Multi-Session (large project, context-aware)

```
SESSION 1: Phase 0-2 (5/12 batches done) → CHECKPOINT (Context: 82%)
SESSION 2 (--resume): Phase 2 batches 6-12 → CHECKPOINT (Context: 78%)
SESSION 3 (--resume): Phase 3-6 → DONE
```

### Example 3: Skip Mode (PROTOTYPE project)

```
Phase 0: maturity.stage_modes.classify == "skip"
  → mark ledger.stages.classify.status = "completed" (skipped_maturity)
  → CLASSIFY SKIPPED report
  → STOP (skip Phase 1-5)
Phase 6: chỉ tạo phase-summary.md với note skipped
```

### Example 4: DOCS_ONLY Mode

```
Phase 0: maturity_level == "DOCS_ONLY", source_count == 0
  → DOCS_ONLY_MODE = true, INVENTORY_FILE = doc-classified.json
Phase 2: code-reviewer classify by doc_type (prd, spec, wireframe, ...)
Phase 3: glossary từ docs domain terms
Phase 6: DONE
```
