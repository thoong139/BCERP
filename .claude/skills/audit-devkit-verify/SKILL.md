---
name: audit-devkit-verify
version: 3.1.0
last_updated: 2026-09-12
description: |
  Cross-validate findings từ /audit-devkit-scan.
  Kiểm tra cross-references, workflow integrity, bidirectional consistency.
  Đọc structured JSON từ scan, KHÔNG scan lại từ đầu.

  v1.1.0 — Bổ sung Phase 3.5: Master Plan Components Verification.
  V1-V6 cross-checks cho 7 thành phần từ Master Optimization Plan
  (Hook 2-Tầng, Checkpoint Digest, Digest Pipeline, A6-EXT/A7-EXT, Parallel Execution,
  Backward Compatibility). Backward compatible: thành phần chưa triển khai → skip, không tạo findings.

  v2.0.0 — Bổ sung --skill=<name> focused verify mode.
  Chỉ cross-validate 1 skill cụ thể + lightweight cross-ref với downstream/upstream skills.
  Skip full crossref passes (A-D), chỉ chạy focused crossref + workflow + consistency cho skill đó.
  Bổ sung category (functional/structural) vào findings JSON.

  v3.0.0 — Refactor: tách monolithic SKILL.md (794 dòng) thành 8 procedure files + 1 _shared.md
  (lazy loading per-phase). Giảm context load ~75% khi execute từng phase.
  Backup: procedures/flow-legacy.md.bak.

  TRIGGER khi:
  - Đã chạy /audit-devkit-scan xong, cần cross-validate findings
  - Bước thứ 2 trong audit pipeline (scan → verify → fix)
  - Keywords: "audit verify", "verify devkit", "audit-devkit-verify"

  KHÔNG trigger khi:
  - Chưa có scan results → dùng /audit-devkit-scan trước
  - Cần auto-fix issues → dùng /audit-devkit-fix
  - Audit dự án đang dùng MCV3 → không liên quan
  - Chỉ audit agents → dùng /audit-agents

argument-hint: "[--crossref | --workflow | --consistency | --master-plan | --all | --skill=<name>] [--session=<id>] [--resume]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Agent, TodoWrite
---

# /audit-devkit-verify: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Cross-validate scan findings + kiểm tra workflow integrity + bidirectional consistency |
| **Prerequisites** | `/audit-devkit-scan` đã hoàn thành — `.mc-data/work/audit-devkit-scan/[session-id]/audit-scan-result.json` tồn tại |
| **Duration** | Multi-session (nhiều agent passes). Hỗ trợ resume qua `verify-status.json` |
| **Phases** | 0 → 1 (hoặc 1.F) → 2 → 3 → 3.5 → 4 (routing theo scope) |
| **Input** | `.mc-data/work/audit-devkit-scan/[session-id]/audit-index.json`, `audit-scan-result.json` |
| **Output** | `.mc-data/work/audit-devkit-verify/[session-id]/audit-verified-result.json` + reports/devkit-audit-[date].md |

### Workflow Position

```
/audit-devkit-scan → /audit-devkit-verify → /audit-devkit-fix
                            |
                       YOU ARE HERE
```

---

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `--crossref` | Chỉ chạy cross-reference verification (Phase 1) | - |
| `--workflow` | Chỉ chạy workflow integrity check (Phase 2) | - |
| `--consistency` | Chỉ chạy bidirectional consistency check (Phase 3) | - |
| `--master-plan` | **[v1.1]** Chỉ chạy Master Plan Components verification (Phase 3.5) | - |
| `--all` | Chạy tất cả phases | `--all` (mặc định) |
| `--skill=<name>` | **[v2.0]** Focused verify cho 1 skill cụ thể (VD: `wf-legacy-scan`). Skip full crossref passes A-D, chỉ chạy focused crossref + workflow + consistency cho skill đó | - |
| `--session=<id>` | **[v3.1 — C3 fix]** Pin session-id (timestamp dir như `20260510-130000`) từ orchestrator để khớp `audit-devkit-scan` session. Khi gọi standalone (không truyền) → fallback Glob latest. Khi gọi từ `/audit-devkit` orchestrator → BẮT BUỘC nhận flag này để chống race condition giữa nhiều historical sessions | - (fallback latest) |
| `--resume` | Resume từ checkpoint | - |

---

## Protocols

> **Shared protocols (repo-wide):** `.claude/skills/protocols/`
>
> **Skill-internal shared:** `procedures/_shared.md` — State Variables Glossary, Fix Rules, Auditor Prompt Templates, Finding ID Prefixes, Schemas, Checkpoint, Error Handling Reference, Verdict Computation.

### Execution Strategy

| Điều kiện | Mode |
|-----------|------|
| Phase 1 Pass A + Pass B (agents↔skills, skills↔templates) | **PARALLEL** — 2 agents đồng thời |
| Phase 1 Pass C + Pass D (docs, hooks) | **PARALLEL** — 2 agents đồng thời |
| Phase 2 (workflow integrity) | **SEQUENTIAL** — cần crossref results |
| Phase 3 (bidirectional consistency) | **SEQUENTIAL** — cần workflow results |
| Phase 3.5 V1-V5 (Master Plan components) | **PARALLEL** — 5 Bash/Grep checks đồng thời (nhẹ, không agent) |
| Phase 3.5 V6 (backward compatibility) | **SEQUENTIAL sau V1-V5** |
| Phase 4 (merge & report) | **SEQUENTIAL** — cần tất cả findings |
| **[v2.0] --skill=<name> mode** | **Focused crossref only** — 1 agent. Skip full passes A-D, skip Phase 3.5 |

---

## Phase 0: Auto-Detection & Routing (BẮT BUỘC — entry point)

> Phase này **LUÔN chạy đầu tiên** để parse arguments, discover session, và load ground truth.

```
STEP 1: Kiểm tra prerequisites
  (a) Glob .mc-data/work/audit-devkit-scan/*/audit-index.json
      IF NOT FOUND → STOP: "audit-index.json không tìm thấy. Chạy /audit-devkit-scan trước."
  (b) Glob .mc-data/work/audit-devkit-scan/*/audit-scan-result.json
      IF NOT FOUND → STOP: "audit-scan-result.json không tìm thấy. Chạy /audit-devkit-scan trước."

STEP 2: Parse arguments → xác định $SCOPE
  crossref / workflow / consistency / master-plan / all / skill

STEP 3: Read procedures/phase0-load.md → execute Phase 0 → return
```

### Phase 0 Step Summary

| Step | Action | Verify |
|------|--------|--------|
| 1 | PRE-GATE: Glob audit-index.json + audit-scan-result.json từ scan session | Thiếu → E001/E002 STOP |
| 2 | Parse `$ARGUMENTS` → `$SCOPE` (crossref/workflow/consistency/master-plan/all/skill) | Scope hợp lệ |
| 3 | `--resume` handler: đọc verify-status.json → jump pending_phases[0] | File hợp lệ; corrupt → E011 |
| 4 | Lazy-load `procedures/phase0-load.md`: discover session, load ground truth | Session + index loaded |

**Đặc biệt — `--resume` handler:**

```
IF $ARGUMENTS chứa "--resume":
  IF test -f .mc-data/work/audit-devkit-verify/[session-id]/verify-status.json:
    → READ verify-status.json
    → Xác định completed_phases[] + pending_phases[]
    → Jump tới phase trong pending_phases[0] (xem Phase Routing Map)
  ELSE:
    → STOP: "Không tìm thấy checkpoint. Chạy /audit-devkit-verify từ đầu."
```

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load qua các phase files riêng.
> Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase | Procedure file | Điều kiện chạy | Mục đích |
|-------|---------------|----------------|----------|
| **0** | `procedures/phase0-load.md` | Always (entry point) | Parse args, discover session, load ground truth |
| **1** | `procedures/phase1-crossref.md` | `$SCOPE ∈ {crossref, all}` | Cross-reference: 4 passes A/B/C/D (parallel) |
| **1.F** | `procedures/phase1-focused.md` | `$SCOPE = skill` | Focused crossref cho `--skill=<name>` |
| **2** | `procedures/phase2-workflow.md` | `$SCOPE ∈ {workflow, all, skill}` | Workflow integrity (Cross-Skill Output Path Contract) |
| **3** | `procedures/phase3-consistency.md` | `$SCOPE ∈ {consistency, all, skill}` | Bidirectional consistency (coordination, deprecated, naming) |
| **3.5** | `procedures/phase3-5-masterplan-crossvalidate.md` | `$SCOPE ∈ {master-plan, all}` | Master Plan V1-V6 cross-checks |
| **4** | `procedures/phase4-merge.md` | Always (cho mọi scope) | Merge findings, compute verdict, generate report |

### Routing Flows

**`--all` (full verify):**
```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 3.5 → Phase 4 → DONE
```

**`--crossref` (partial):**
```
Phase 0 → Phase 1 → Phase 4 (crossref verdict) → DONE
```

**`--workflow` (partial):**
```
Phase 0 → Phase 2 → Phase 4 (workflow verdict) → DONE
```

**`--consistency` (partial):**
```
Phase 0 → Phase 3 → Phase 4 (consistency verdict) → DONE
```

**`--master-plan` (partial):**
```
Phase 0 → Phase 3.5 → Phase 4 (masterplan verdict) → DONE
```

**`--skill=<name>` (focused):**
```
Phase 0 → Phase 1.F → Phase 2 (focused) → Phase 3 (focused) → Phase 4 → DONE
(skip Phase 3.5)
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, Steps, POST-GATE, Errors riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting concerns (prompts, schemas, fix rules).

---

## Output Files

### Findings files (per phase)

| # | File | Path | Phase | Required |
|---|------|------|-------|----------|
| 1 | findings-crossref-agents-skills.json | `$VERIFY_DIR` | 1 (Pass A) | Full mode |
| 2 | findings-crossref-skills-templates.json | `$VERIFY_DIR` | 1 (Pass B) | Full mode |
| 3 | findings-crossref-docs.json | `$VERIFY_DIR` | 1 (Pass C) | Full mode |
| 4 | findings-crossref-hooks.json | `$VERIFY_DIR` | 1 (Pass D) | Full mode |
| 5 | findings-crossref-[name].json | `$VERIFY_DIR` | 1.F | `--skill` mode only |
| 6 | findings-workflow.json | `$VERIFY_DIR` | 2 | Khi Phase 2 chạy |
| 7 | findings-consistency.json | `$VERIFY_DIR` | 3 | Khi Phase 3 chạy |
| 8 | findings-masterplan-verify.json | `$VERIFY_DIR` | 3.5 | Khi Phase 3.5 chạy (kể cả khi skipped — với `skip_reason`) |
| 9 | audit-verified-result.json | `$VERIFY_DIR` | 4 | Always |

**Path variable:** `$VERIFY_DIR = .mc-data/work/audit-devkit-verify/[session-id]/`

### Working files

| File | Path | Purpose |
|------|------|---------|
| verify-status.json | `$VERIFY_DIR` | Resume support + completion state |
| phase-summary.md | `$VERIFY_DIR` | CORE-028 deliverable — tóm tắt tiếng Việt cho non-specialist sau Phase 4 (merge). Template: `.claude/doc-framework/_meta/phase-summary.template.md` (CORE-031: READ → POPULATE → WRITE). Tạo bởi `procedures/phase4-merge.md` sau khi audit-verified-result.json hoàn tất. |
| devkit-audit-[date].md | `.mc-data/work/audit-devkit-verify/reports/` | Human-readable report |

---

## Error Handling

Codes E001-E016 (prefix VERIFY- khi log) — chi tiết: `procedures/_shared.md §Error Handling Reference`.

Tóm tắt:

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001/E002 | Scan files không tồn tại | STOP — chạy `/audit-devkit-scan` trước |
| E003/E004 | Input JSON invalid | Retry ×3 → STOP, re-scan |
| E005 | Spot-check fail (>20% stale) | WARNING + yêu cầu re-scan |
| E006 | Agent timeout | Re-spawn ×1 → skip pass + WARNING |
| E007 | Agent trả text thay JSON | Fallback parse → MANUAL |
| E008 | findings-crossref-* thiếu sau Phase 1 | Re-run pass → partial merge + WARNING |
| E009 | Dedup conflict | Giữ severity cao hơn |
| E010 | Write fail | Retry ×3 → escalate |
| E011 | verify-status corrupt khi resume | Rebuild từ findings files |
| E012 | Contract table parse fail | Fallback manual Read + regex |
| E013 | scope=partial ghi sai completed_phases | Chỉ list phases thuộc scope |
| E014-E016 | Master Plan errors | Skip checks / WARNING / MAJOR finding — không block |

---

## Agents Spawned

| Phase | Agent | Purpose |
|-------|-------|---------|
| 1 Pass A | `cross-reference-auditor` | Verify agents ↔ skills |
| 1 Pass B | `cross-reference-auditor` | Verify skills ↔ templates |
| 1 Pass C | `cross-reference-auditor` | Verify agents ↔ rules ↔ CLAUDE.md |
| 1 Pass D | `cross-reference-auditor` | Verify hooks ↔ skills ↔ rules |
| 1.F | `cross-reference-auditor` | Focused verify cho 1 skill |
| 2 | `workflow-auditor` | Workflow integrity (§4b handoffs) |
| 3 | — | Bidirectional consistency (Grep/Read only, không agent) |
| 3.5 | — | Master Plan V1-V6 (Bash/Grep only, không agent) |

---

## Context & Checkpoint (count-based)

> Checkpoint dựa trên số lượng items processed, KHÔNG dựa trên context-% (unreliable).

| Trigger | Hành động |
|---------|-----------|
| Sau mỗi cross-ref pass (A/B/C/D) | Update `verify-status.json` (completed_phases[]) |
| Sau Phase 2 workflow | Flush workflow findings |
| Sau Phase 3 consistency | Flush consistency findings |
| FORCE STOP (khi không thể tiếp tục) | Checkpoint ngay — ghi `completed_phases[]` để resume |

Checkpoint schema: `procedures/_shared.md §Checkpoint & Resume`.

---

## Related Skills

| Skill | Relation |
|-------|----------|
| `/audit-devkit-scan` | Prerequisite — output (audit-index.json + audit-scan-result.json) là input |
| `/audit-devkit-fix` | Next step — nhận audit-verified-result.json để auto-fix |
| `/audit-devkit` | Parent orchestrator — gọi skill này như bước 2 trong pipeline |
| `/audit-agents` | Alternative — chỉ audit agent definitions (nhẹ hơn, không cross-validate) |

---

## Examples

### Example 1: Happy Path (full verify)

```
/audit-devkit-verify --all

Phase 0: Load ground truth → session-id=20260419-100000, scope=all → PASS
Phase 1: 4 passes crossref (parallel A+B, then C+D) → 12 findings
Phase 2: Workflow integrity → 3 findings
Phase 3: Bidirectional consistency → 2 findings
Phase 3.5: Master Plan V1-V6 (4 components deployed) → 4 findings
Phase 4: Merge 21 verify + 37 scan → dedup → 49 total → verdict: NEEDS ATTENTION
DONE. Next: /audit-devkit-fix để auto-fix 32 issues
```

### Example 2: Focused mode

```
/audit-devkit-verify --skill=wf-legacy-scan

Phase 0: scope=skill, focused_skill=wf-legacy-scan → PASS
Phase 1.F: Focused crossref (_contract.json + §4b + downstream/upstream) → 3 findings
Phase 2 (focused): Workflow handoffs wf-legacy-scan → 1 finding
Phase 3 (focused): Consistency cho agents của skill → 0 findings
Phase 4: Merge focused findings → 4 total → verdict: ACCEPTABLE
DONE.
```

### Example 3: Partial scope

```
/audit-devkit-verify --crossref

Phase 0: scope=crossref → PASS
Phase 1: 4 passes parallel → 12 findings
Phase 4: Merge crossref only → verdict: ACCEPTABLE
DONE. (Phase 2, 3, 3.5 skipped)
```

### Example 4: Resume

```
/audit-devkit-verify --resume

Phase 0: Read verify-status.json → last session 20260419-100000, completed: phase0-load, phase1-pass-a, phase1-pass-b
Resume Phase 1 từ Pass C (pending: phase1-pass-c, phase1-pass-d, phase2-workflow, ...)
... tiếp tục bình thường
```
