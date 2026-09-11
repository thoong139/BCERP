---
name: wf-annotate-code
version: 2.1.0
last_updated: 2026-04-25
description: |
  Inject REQ-ID comments vào existing code files để thiết lập traceability.
  Dùng cho dự án legacy đã có code nhưng chưa có REQ-ID annotations.
  Stage 5.5 của legacy scan pipeline (sau gap analysis, trước legacy-ux).

  TRIGGER khi:
  - Dự án legacy đã hoàn thành gap analysis, có annotation gaps
  - User muốn thêm REQ-ID vào code hiện có
  - Traceability score thấp (< 50%)

  KHÔNG trigger khi:
  - Dự án mới (dùng /wf-implement-feature — tự có REQ-ID)
  - Chưa có req-registry.json hoặc module-code-mapping.json

argument-hint: "[--module=<name>] [--dry-run] [--batch-size=N] [--resume] [--status]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, AskUserQuestion
---

# /wf-annotate-code: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Thêm REQ-ID và FEAT-ID comments vào code files hiện có để tăng traceability |
| **Prerequisites** | `req-registry.json` có `features[]`, `module-code-mapping.json`, `gap-report.md`, `ledger.stages.gap_analysis.status = "completed"` |
| **Workflow position** | `/wf-design` (legacy — gap analysis) → **/wf-annotate-code** ← YOU ARE HERE → `/wf-design-ux` (nếu có UI) hoặc `/wf-plan-modules` |
| **Output** | Annotated source code files + `annotation-report.md` + `annotation-map.json` + ledger/status updates |
| **Phases** | 0 → 1 → 2 → 3 → 4 |
| **Duration** | Single-session (small) hoặc Multi-session (LARGE — checkpoint per batch) |

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `--module=<name>` | Chỉ annotate 1 module cụ thể | All modules |
| `--dry-run` | Chỉ tạo annotation map + preview report, KHÔNG ghi vào code | — |
| `--batch-size=N` | Số files per batch | 50 |
| `--resume` | Resume từ checkpoint cuối cùng | — |
| `--status` | Hiển thị trạng thái hiện tại, STOP | — |

### Template Usage Rule (CORE-031)

> **BẮT BUỘC:** Mọi output file có template PHẢI được tạo bằng pattern **READ → POPULATE → WRITE**:
>
> - **Internal templates** (`templates/`): `annotate-status.json`, `annotate-plan.md`, `annotate-checkpoint.json`, `annotation-report.md`
> - **Shared templates**: `doc-framework/_meta/phase-summary.template.md`, `doc-framework/_meta/session-log.template.json`
>
> KHÔNG viết output từ đầu khi template tồn tại. Protocol chi tiết trong `protocols/19-template-usage.md`.

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 1 (Accuracy Assurance), Protocol 2 (Auto-Correction Loop, max 3 iterations), Protocol 3 (Context & Checkpoint), Protocol 8 (Content Quality Gate), Protocol 9 (Task Planning), Protocol 10 (POST-GATE Schema Validation), Protocol 14 (Phase Summary), Protocol 15 (Session Log), Protocol 19 (Template Usage Rule).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables Glossary, Comment Format Table, LEGACY Decisions Filter, Annotation Existence Check, Checkpoint Protocol, Resume Logic, Fix Rules, Traceability Score.

- **Registry Access**: **READ-ONLY** — skill này KHÔNG update `req-registry.json`. Chỉ GHI vào source code files (REQ-ID comments) + working files trong `.mc-data/work/legacy-scan/`
- **Context & Checkpoint**: thresholds 65/80/90% — checkpoint sau mỗi batch (Phase 3)
- **Auto-Correction Loop**: max 3 iterations cho annotation existence conflicts (E046)
- **Error Tracking**: tập trung error codes E001, E040-E046 — xem `procedures/_shared.md §Fix Rules`

## Execution Strategy

| Phase | Mode | Agents | Ghi chú |
|-------|------|--------|---------|
| Phase 0 | MAIN CONVERSATION | 0 | Context loading + parse args + init status/plan/checkpoint + traceability baseline |
| Phase 1 | MAIN CONVERSATION | 0 | Scan code (Grep/Glob), build annotation map |
| Phase 2 | MAIN CONVERSATION | 0 | Display map, user confirm, dry-run exit |
| Phase 3 | MAIN CONVERSATION | 0 | Batched injection (Edit per file + existence check + verify + checkpoint) |
| Phase 4 | MAIN CONVERSATION | 0 | Verify + report + ledger/status/plan update + phase-summary + session log close |

KHÔNG spawn agent cho bất kỳ phase nào — skill này thuần main conversation.

## Work Directory

```
.mc-data/work/legacy-scan/               # Shared pipeline workspace
├── annotate-status.json                 # Runtime status (per CORE-031 từ templates/)
├── annotate-plan.md                     # Execution plan
├── annotate-checkpoint.json             # Checkpoint cho resume
├── annotation-map.json                  # Annotation map (Phase 1 → Phase 2 confirmed)
└── annotation-report.md                 # Final report (Phase 4)

.mc-data/work/wf-annotate-code/          # Skill-private
└── phase-summary.md                     # CORE-028 summary

.mc-data/work/_trace/
└── session-log.json                     # CORE-026 trace (START/COMPLETE events)
```

Templates: `.claude/skills/workflow/wf-annotate-code/templates/`

---

## Phase 0: Entry Point (BẮT BUỘC — chạy trước tiên)

> Phase 0 xử lý `--status` và `--resume` special paths, PRE-GATE, context loading.

```
STEP 1: Kiểm tra PRE-GATE (chi tiết trong phase0-context.md)
  IF FAIL → STOP (E001): "Chưa đủ prerequisites. Chạy /wf-design (legacy — gap analysis) trước."

STEP 2: --status handler
  IF $ARGUMENTS chứa "--status":
    → Read procedures/phase0-context.md §--status Handler
    → Hiển thị trạng thái → STOP

STEP 3: Routing
  → Read procedures/phase0-context.md (Phase 0 chi tiết + --resume handler + maturity check)
```

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load qua
> các phase files riêng. Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase | Procedure file | Điều kiện | Mục đích |
|-------|---------------|-----------|----------|
| **0** | `procedures/phase0-context.md` | Always (entry point) | PRE-GATE + context + --status/--resume + maturity-aware mode |
| **1** | `procedures/phase1-build-map.md` | `$ANNOTATION_MODE != "skipped"` | Build `annotation-map.json` từ registry + gap report |
| **2** | `procedures/phase2-review.md` | Phase 1 map non-empty | User confirm map, `--dry-run` exit |
| **3** | `procedures/phase3-inject.md` | `$DRY_RUN = false` | Batched injection với existence check + verify + checkpoint |
| **4** | `procedures/phase4-verify-report.md` | Phase 3 POST-GATE PASS | Verify + report + ledger/status/plan finalize + phase-summary + session log |

**Routing flow:**

```
SKILL.md Phase 0 → Read procedures/phase0-context.md → execute → return
   ↓ (nếu $MATURITY_LEVEL = "DOCS_ONLY" → SKILL EXIT)
   ↓ (nếu $RESUME = true → jump tới phase trong checkpoint)
Read procedures/phase1-build-map.md → execute → return
   ↓
Read procedures/phase2-review.md → execute → return
   ↓ (nếu $DRY_RUN = true → SKILL EXIT)
   ↓ (nếu user CANCEL → SKILL EXIT)
Read procedures/phase3-inject.md → execute → return
   ↓ (có thể STOP giữa chừng do context threshold — prompt --resume)
Read procedures/phase4-verify-report.md → execute → return → STOP
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting: state vars, comment formats, checkpoint/resume, fix rules.

---

## Output Files

### Main Outputs

| # | File | Path | Phase | Template |
|---|------|------|-------|----------|
| 1 | annotation-report.md | `.mc-data/work/legacy-scan/` | 4 (hoặc 2 nếu dry-run) | `templates/annotation-report.md` |
| 2 | annotation-map.json | `.mc-data/work/legacy-scan/` | 1 (confirmed ở 2) | — (inline schema) |
| 3 | annotate-status.json | `.mc-data/work/legacy-scan/` | 0 (init), 0-4 (updates) | `templates/annotate-status.json` |
| 4 | annotate-plan.md | `.mc-data/work/legacy-scan/` | 0 (init), 4 (finalize) | `templates/annotate-plan.md` |
| 5 | annotate-checkpoint.json | `.mc-data/work/legacy-scan/` | 0 (init), 3 (per batch) | `templates/annotate-checkpoint.json` |
| 6 | **Annotated source code files** | Dự án | 3 | — (Edit in place) |
| 7 | ledger.json (updated) | `.mc-data/work/legacy-scan/` | 4 | — (Edit) |
| 8 | legacy-scan-status.json (updated) | `.mc-data/work/legacy-scan/` | 0 (read), 3-4 (updates) | — (Edit) |

### CORE Required Outputs

| # | File | Path | Phase | Template |
|---|------|------|-------|----------|
| 9 | phase-summary.md (CORE-028) | `.mc-data/work/wf-annotate-code/` | 4 | `doc-framework/_meta/phase-summary.template.md` |
| 10 | session-log.json (CORE-026 — append events) | `.mc-data/work/_trace/` | 0, 4 | `doc-framework/_meta/session-log.template.json` |

### Registry

Skill này **KHÔNG** update `req-registry.json` (CORE-006: fields_owned = []).

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001 | PRE-GATE fail (missing prerequisites) | STOP, thông báo user chạy prerequisite |
| E002 | POST-GATE fail (output không đạt validation) | Retry ×3 per Protocol 2 (Auto-Correction Loop) |
| E003 | Max retries exceeded (sau 3 lần vẫn E002) | Escalate to user, STOP + log detail |
| E040 | Annotation map empty (0 files match) | WARN, `AskUserQuestion` cho manual mapping |
| E041 | File write fail (IO) | RETRY ×3, skip file, log. >30% fail → STOP |
| E042 | File corrupt sau annotation | ROLLBACK (restore original), log |
| E043 | Batch checkpoint fail | WARN, tiếp tục. ≥2 liên tiếp → STOP |
| E044 | Resume checkpoint invalid | WARN, confirm user, fallback Phase 0 |
| E045 | Unsupported language (extension không match) | SKIP file, log. >20% → STOP |
| E046 | Annotation tồn tại nhưng khác target | `AskUserQuestion`: UPDATE hoặc SKIP |

Chi tiết Fix Rules: `procedures/_shared.md §Fix Rules đặc thù`.

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/wf-design` (legacy flow) | **Predecessor** — cung cấp `gap-report.md` (annotation gaps), Phase 0-3 docs + registry |
| `/wf-legacy-extract` | **Predecessor** — cung cấp `module-code-mapping.json` |
| `/wf-brainstorm` (Phase 0.5) | **Optional predecessor** — cung cấp `legacy-decisions.json` với DEPRECATE actions |
| `/wf-design-ux` (legacy flow) | **Successor** (nếu có UI) |
| `/wf-plan-modules` | **Successor** — dùng annotated code làm input planning |
| `/existing-project` | **Orchestrator workflow** |

---

## Context & Checkpoint

Multi-session skill (LARGE projects). Chi tiết trong `procedures/_shared.md §Checkpoint Protocol` và `§Resume Logic`.

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục |
| 65-80% | Chuẩn bị checkpoint |
| 80-90% | Lưu checkpoint, STOP sau batch hiện tại |
| > 90% | FORCE STOP |

---

## Examples

### Example 1: Happy Path (single session)

```
Phase 0: prerequisites OK, maturity=CODE_ONLY, traceability_before=23% → PASS
Phase 1: Scan 3 modules → annotation-map.json với 127 entries
Phase 2: User APPROVE_ALL
Phase 3: 3 batches × ~42 files → 120 annotated, 5 skipped (already), 2 error
Phase 4: traceability_after=78% (+55%) → PASS

Next: /wf-design-ux [system-name] hoặc /wf-plan-modules
```

### Example 2: Dry-Run Preview

```
/wf-annotate-code --module=billing --dry-run
Phase 0-2: scan, build map (38 entries), display
Phase 2 Dry-Run Exit: annotation-report.md với DRY-RUN banner + diff preview
STOP (Phase 3-4 skipped)
```

### Example 3: Multi-Session Resume

```
SESSION 1: Phase 0-2 (APPROVE), Phase 3 batch 1-3/8 → CHECKPOINT (Context 82%) → STOP
SESSION 2 (--resume): Reconcile filesystem → pending=5 batches → Phase 3 batch 4-8 → Phase 4 → DONE
```

### Example 4: LEGACY DEPRECATE Filter

```
Phase 0: LEGACY_MODE=true, legacy-decisions.json có modules.reporting-legacy.action="DEPRECATE"
Phase 1: Skip all files thuộc module "reporting-legacy" (log: 22 files skipped)
Phase 2-4: tiếp tục bình thường cho modules còn lại
```
