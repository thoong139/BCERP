---
name: wf-design
version: 4.1.0
last_updated: 2026-09-12
description: |
  Chuyển requirements thành technical design — architecture, API, database schema, infra spec, integration rules. v4.1: Business Context Baseline (actors/roles, vòng đời business object, cross-module workflow, ownership) làm nền thiết kế ERP liên kết. Hỗ trợ dự án mới và dự án có sẵn (legacy); tự phát hiện loại dự án và inject context phù hợp.

  TRIGGER khi:
  - User nói: "thiết kế", "design", "kiến trúc", "architecture", "tech stack"
  - User hỏi: "dùng database gì", "auth như thế nào", "cấu trúc backend"
  - Sau khi /wf-define-features để chuyển features thành technical design
  - Gọi lệnh: /wf-design [target] [--status] [--resume]

  LUÔN trigger khi user cần thiết kế kỹ thuật cho hệ thống/module, dù không dùng từ "design" — bước trung tâm giữa requirements và coding.

  KHÔNG trigger khi:
  - Chưa có req-registry.json → dùng /wf-analyze-requirements trước
  - Chưa có features → dùng /wf-define-features trước
  - Chỉ cần phân tích requirements → dùng /wf-analyze-requirements
argument-hint: "[platform | system | module-name] [--status] [--resume] [--from-scan=<session-id|path>]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite
---

# /wf-design: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Chuyển requirements thành technical design đầy đủ — architecture, API, database, infra |
| **Prerequisites** | `phase2-features/` + `req-registry.json` (features[]) |
| **Workflow position** | `/wf-define-features` → **/wf-design** ← YOU ARE HERE → `/wf-design-ux` (nếu UI) hoặc `/wf-plan-modules` (nếu API-only) |
| **Output** | `phase3-architecture/P3-01-architecture.md` + `technical-specs/*.md` + `stakeholder-review.md` + `design-summary.json` + `design-input-digest.json` + `req-registry.json.design_status` |
| **Phases** | 0 → 0.5 → 1 → 2 → 3 → 4 → 5 → 6 → [7 LEGACY] → 8 |
| **Duration** | Multi-session (có thể dừng/resume qua checkpoint) |

## Arguments

| Argument | Mô tả | Default |
|----------|--------|---------|
| `target` | `platform` / `system` / `[module-name]` (auto-detect) | — |
| `--status` | Hiển thị tiến độ, không thực thi | — |
| `--resume` | Resume từ checkpoint đã lưu | — |
| `--from-scan=<session-id\|path>` | **OPTIONAL (Sprint 5 cross-skill).** Đọc `target-map.json` từ wf-scan-target session làm gap-analysis baseline cho legacy design. KHÔNG auto-modify design docs — chỉ dùng làm context cho architect agent (existing endpoints, entities, scan_diff). | — |

> **Sprint 5 cross-skill — `--from-scan`:** OPTIONAL flag dành cho legacy design / re-design.
> Khi có flag, skill load `target-map.json` từ
> `.mc-data/work/wf-scan-target/sessions/<id>/target-map.json` và inject vào architect agent
> context (endpoints + entities + scan_diff). Hữu ích để: (1) baseline cho gap analysis,
> (2) tránh re-design API/entity đã có trong code, (3) phát hiện scan_diff giữa các đợt scan.
> KHÔNG thay đổi default behavior — không pass flag thì skill chạy như cũ.

### Template Usage Rule (CORE-031)

> **BẮT BUỘC:** Mọi file có Template PHẢI được tạo bằng pattern:
> 1. **READ** template file từ `templates/` directory (internal) hoặc `doc-framework/` (output docs)
> 2. **POPULATE** — thay thế placeholders bằng giá trị thực tế
> 3. **WRITE** output file đến destination path
>
> **NẾU SKIP bước READ template → STOP skill.** Không viết output từ đầu khi template tồn tại.
>
> Áp dụng cho:
> - **Internal templates** (3 files): `templates/design-status.json`, `templates/design-plan.md`, `templates/checkpoint.json`
> - **doc-framework templates** (6 files): `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/{api-contract,database-design,integration-map,infra-spec}.md`, `phase3-architecture/stakeholder-review.md`
> - **Digest template**: `_digests/design-input-digest.template.json`
> - **Shared templates**: `_meta/deferred-findings-template.md`, `_meta/phase-summary.template.md`

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 6 (Token Limit Prevention), Protocol 7 (PAR), Protocol 8 (CQG), Protocol 9 (PLN), Protocol 10 (POST-GATE Schema Validation), Protocol 11 (Rollback), Protocol 14 (Phase Summary), Protocol 15 (Session Log), Protocol 19 (Template Usage Rule).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables Glossary, Architecture Documentation Labels, LEGACY Context Injection, Agent Prompt Templates, Checkpoint Protocol.

- **Accuracy Assurance** (mọi phase): POST-GATE Enforcement + Fix Rules + Error Tracking
- **Business Context Baseline** (Phase 1, v4.1): main conversation — actor/role/phòng ban matrix + vòng đời business object (state transitions) + cross-module workflow + ownership/assignment + exception events + **module consolidation review** (flag module ứng viên gộp → user quyết, không tự sửa registry) → `$SESSION_DIR/business-context.md`, inject vào MỌI agent prompt (Phase 1–5) — xem `_shared.md` §Business Context Injection
- **Auto-Correction Loop** (Phase 4, 5): max 3 iterations
- **Context & Checkpoint**: thresholds 65/80/90%
- **Stakeholder Review** (Phase 5): SO-01/02/03 với parallel agents (architect + security)
- **Token Limit Prevention** (Phase 0, 1, 2, 5): input compression + skeleton-first + feature digest
- **Registry Safe-Write** (Phase 6): CHỈ update field `design_status` (legacy flow extension — xem `_shared.md`)
- **Parallel Execution** (Phase 1, 2, 5): max `$LPM_PARAMS.max_parallel_agents` (Standard: 5, LPM: 3)
- **Content Quality Gate** (Phase 4): 8 validation checks + CQG-05 freshness
- **Large Project Mode** (auto-detect Phase 0): `systems >= 5 OR departments >= 10 OR requirements >= 50 OR features >= 40` → compression sớm hơn, skeleton-first, checkpoint per phase

## Execution Strategy

| Điều kiện | Chế độ |
|-----------|--------|
| Phase 0.5 (workload gate) | SEQUENTIAL — estimate + gate check, hỏi user nếu WARN/BLOCK |
| Phase 1 (architecture) — Lane Dispatch per system | **Step 1.0 Business Context Baseline chạy SEQUENTIAL main-conversation TRƯỚC lane dispatch**; sau đó PARALLEL per system (max `$LPM_PARAMS.max_parallel_agents`): mỗi system = 1 lane, conditional agents trong cùng lane. LPM override: SEQUENTIAL nếu tổng conditionals >= 3 |
| Phase 2 (technical specs) — Option A: 3 specs per system, trong cùng lane | PARALLEL per system lane: api-contract + database-design + infra-spec trong lane của system đó |
| Phase 3 (integration map) | SEQUENTIAL sau Phase 2 + Signal Aggregation (component_id + api_id dual dedup) |
| Phase 4 (cross-validation) | SEQUENTIAL (aggregation conflict resolution → 8-check loop, max 3 iterations) |
| Phase 5 (stakeholder review) | PARALLEL: architect + security |
| Phase 6 (registry update + compressed spec) | SEQUENTIAL — main conversation, KHÔNG spawn agent |
| Phase 7 (gap analysis — LEGACY only) | SEQUENTIAL — KHÔNG lane-ify |
| Phase 8 (digest + summary) | SEQUENTIAL — Template Strip + Atomic Write + canonical sync |

## Work Directory

```
.mc-data/work/wf-design/
├── latest                      # Latest session ID pointer (Phase 0)
├── design-status.json          # Runtime status — canonical sync từ session (Phase 0)
├── design-plan.md              # Execution plan — approach, scope (Phase 0)
├── execution-plan.md           # Protocol 9 execution plan (Phase 0)
├── checkpoint.json             # Backward-compat mirror (pre-v4.0 consumers)
├── design-report.md            # Cross-validation + completion log (Phase 4, 6)
├── design-summary.json         # Compressed spec — canonical sync từ session (Phase 8)
├── deferred-findings.md        # Conditional — DEFERRED items cho wf-plan-modules (Phase 6)
└── sessions/
    └── {YYYYMMDD-HHMMSS}-{hash4}/   # Session-scoped isolation (ADR-OPT-02)
        ├── session-state.json         # PRIMARY checkpoint (3-level L1/L2/L3)
        ├── workload-report.md         # Phase 0.5 output
        ├── feature-digest.md          # Phase 0 conditional
        ├── business-context.md        # Phase 1 — Business Context Baseline (v4.1)
        ├── design-status.json         # Working copy (synced → parent)
        ├── design-summary.json        # Working copy (synced → parent at Phase 8)
        ├── design-input-digest.json   # Working copy (synced → _meta/ at Phase 8)
        ├── aggregation-result.json    # Phase 3 Signal Aggregation output
        ├── checkpoint.json            # Backward-compat mirror
        ├── lanes/
        │   └── {system-slug}/
        │       ├── signals.json       # Phase 1 architecture lane signals
        │       └── specs-signals.json # Phase 2 specs lane signals
        └── phase-summary.md           # CORE-028 (Phase 8)
```

Templates: `.claude/skills/workflow/wf-design/templates/`

---

## Phase 0: Auto-Detection & Routing (BẮT BUỘC — chạy trước tiên)

> Phát hiện project type và inject context phù hợp.
> LEGACY_MODE detection theo CORE-021: check `project-context.md` (> 500 bytes).

### CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools duoc auto-detect, khong hoi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → check per-tool TTL. Read `.mc-data/work/_meta/code-intelligence.json` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sanh HEAD vs index_commit. SEVERE (>20 behind) → warning: "Architecture review may miss recent code changes." | Freshness status set |

```
STEP 1: Kiểm tra prerequisites
  (a) test -f .mc-data/docs/_meta/req-registry.json
      IF NOT EXISTS → STOP: "req-registry.json không tìm thấy. Chạy /wf-analyze-requirements."
  (b) test -d .mc-data/docs/phase2-features
      IF NOT EXISTS → STOP: "Chưa có feature specs. Chạy /wf-define-features trước."

STEP 2: Detect LEGACY_MODE (CORE-021)
  LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes
  IF LEGACY_MODE → PROJECT_TYPE = LEGACY

STEP 3: Routing
  → Read procedures/phase0-context.md (Phase 0 detail: registry load + approach + execution plan)
```

**Đặc biệt — `--resume` handler:**

```
IF $ARGUMENTS chứa "--resume":
  IF test -f .mc-data/work/wf-design/checkpoint.json:
    → Read procedures/phase0-context.md §Sub-Phase 0.8 Resume Reconciliation
    → Jump tới phase trong checkpoint.position.current_phase (xem §Phase Routing Map)
  ELSE:
    → STOP: "Không tìm thấy checkpoint. Chạy /wf-design từ đầu."
```

**Đặc biệt — `--status` handler:**

```
IF $ARGUMENTS chứa "--status":
  → Read procedures/phase0-context.md §--status Handler
  → Hiển thị trạng thái → STOP
```

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load
> qua các phase files riêng. Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase | Procedure file | Điều kiện | Mục đích |
|-------|---------------|-----------|----------|
| **0** | `procedures/phase0-context.md` | Always (entry point) | Context Loading + LEGACY detect + LPM eval + Approach + Session Init (ADR-OPT-02) |
| **0.5** | `procedures/phase0.5-workload-gate.md` | Always | Workload estimation + gate (ADR-OPT-03): dead_zone/warn/block |
| **1** | `procedures/phase1-architecture.md` | Always | Business Context Baseline (Step 1.0, main conversation — v4.1) + Architecture Overview — Lane Dispatch per system (ADR-OPT-01) |
| **2** | `procedures/phase2-specs-parallel.md` | Always | Technical Specs per system lane — api-contract + database-design + infra-spec (Option A) |
| **3** | `procedures/phase3-integration.md` | Always | Signal Aggregation (ADR-OPT-04, dual dedup: component_id + api_id) + Integration Map |
| **4** | `procedures/phase4-crossval.md` | Always | Aggregation conflict resolution + Cross-Validation (8 checks, auto-correction loop max 3 iterations) |
| **5** | `procedures/phase5-review.md` | Always | Stakeholder Review (PARALLEL architect + security) |
| **6** | `procedures/phase6-finalize.md` | Always | Registry Safe-Write (`design_status = "completed"`) + Compressed Spec (session working copy) |
| **7** | `procedures/phase7-gap.md` | `$LEGACY_MODE = true` | Gap Analysis — SEQUENTIAL, KHÔNG lane-ify, Template Strip cho action-items.json |
| **8** | `procedures/phase8-digest-summary.md` | Always | Template Strip + Atomic Write + canonical sync → digest + phase-summary + session log |

**Routing flow:**

```
SKILL.md Phase 0 → Read procedures/phase0-context.md → execute (Session Init) → return
   ↓
Read procedures/phase0.5-workload-gate.md → execute (Workload Gate) → return
   ↓
Read procedures/phase1-architecture.md → execute (Lane Dispatch) → return
   ↓
Read procedures/phase2-specs-parallel.md → execute (Lane Dispatch per system) → return
   ↓
Read procedures/phase3-integration.md → execute (Signal Aggregation + Integration Map) → return
   ↓
Read procedures/phase4-crossval.md → execute (Conflict resolution + Cross-Validation) → return
   ↓
Read procedures/phase5-review.md → execute → return
   ↓
Read procedures/phase6-finalize.md → execute → return
   ↓ (nếu $LEGACY_MODE = true)
Read procedures/phase7-gap.md → execute (sequential gap analysis) → return
   ↓
Read procedures/phase8-digest-summary.md → execute (Template Strip + canonical sync) → return → STOP
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting: State Variables, Architecture Labels, LEGACY Injection, Agent Prompts, Checkpoint, Token Limit, Registry Safe-Write.

---

## Output Files

### Standard (new project)

| # | File | Path | Phase | Template |
|---|------|------|-------|----------|
| 1 | P3-01-architecture.md | `.mc-data/docs/phase3-architecture/` | 1 | `doc-framework/phase3-architecture/P3-01-architecture.md` |
| 2 | api-contract.md | `.mc-data/docs/phase3-architecture/technical-specs/` | 2 | `doc-framework/phase3-architecture/technical-specs/api-contract.md` |
| 3 | database-design.md | `.mc-data/docs/phase3-architecture/technical-specs/` | 2 | `doc-framework/phase3-architecture/technical-specs/database-design.md` |
| 4 | infra-spec.md | `.mc-data/docs/phase3-architecture/technical-specs/` | 2 | `doc-framework/phase3-architecture/technical-specs/infra-spec.md` |
| 5 | integration-map.md | `.mc-data/docs/phase3-architecture/technical-specs/` | 3 | `doc-framework/phase3-architecture/technical-specs/integration-map.md` |
| 6 | stakeholder-review.md | `.mc-data/docs/phase3-architecture/` | 5 | `doc-framework/phase3-architecture/stakeholder-review.md` |
| 7 | design-summary.json | `.mc-data/work/wf-design/` | 6 | — (schema inline) |
| 8 | design-input-digest.json | `.mc-data/docs/_meta/` | 8 | `doc-framework/_digests/design-input-digest.template.json` |
| 9 | Registry update | `req-registry.json` | 6 | — (safe-write `design_status`) |

### Working files

| File | Path | Phase | Template |
|------|------|-------|----------|
| design-status.json | `.mc-data/work/wf-design/` | 0 | `templates/design-status.json` |
| design-plan.md | `.mc-data/work/wf-design/` | 0 | `templates/design-plan.md` |
| execution-plan.md | `.mc-data/work/wf-design/` | 0 | — (Protocol 9 PLN-08 inline) |
| checkpoint.json | `.mc-data/work/wf-design/` | 0-6 | `templates/checkpoint.json` |
| feature-digest.md | `.mc-data/work/wf-design/` | 0 (conditional) | — |
| business-context.md | `.mc-data/work/wf-design/sessions/{SESSION_ID}/` | 1 | — (inline schema trong `procedures/phase1-architecture.md` §Step 1.0) — session-scoped, inject vào agent prompts Phase 1-5 |
| design-report.md | `.mc-data/work/wf-design/` | 4, 6 | — |
| deferred-findings.md | `.mc-data/work/wf-design/` | 6 (conditional) | `_meta/deferred-findings-template.md` |
| phase-summary.md | `.mc-data/work/wf-design/` | 8 | `doc-framework/_meta/phase-summary.template.md` |

### LEGACY_MODE (additional outputs)

| # | File | Path | Phase |
|---|------|------|-------|
| 10 | gap-report.md | `.mc-data/work/legacy-scan/` | 7 |
| 11 | gap-categories.json | `.mc-data/work/legacy-scan/` | 7 |
| 12 | action-items.json | `.mc-data/work/legacy-scan/` | 7 |
| 13 | final-report.md | `.mc-data/work/legacy-scan/` | 7 |
| 14 | Registry (extended) | `req-registry.json` | 6 (legacy flow: systems, modules, departments, requirements, features, interface_type) |

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E000 | `req-registry.json` không tìm thấy | STOP → chạy `/wf-analyze-requirements` |
| E001 | Registry có modules nhưng chưa có requirements | STOP → chạy `/wf-analyze-requirements` |
| E002 | Phase2-features forensic fail (< 6 headings hoặc < 400 words) | STOP → chạy `/wf-define-features` |
| E003 | Agent timeout / không trả output | Re-spawn 1 lần; nếu vẫn fail → skip + WARNING |
| E004 | Architecture conflict giữa agent outputs | Flag conflict, present cả hai options cho user quyết định |
| E005 | Output file write fail | Retry 3 lần, sau đó escalate to user |
| E006 | Integration map inconsistency | Re-run Phase 3 |
| E007 | Phase verification failed | Retry phase (max 3×) |
| E008 | Max retries exceeded | Escalate với error details |
| E009 | Cross-validation mismatch sau 3 iterations (Phase 4) | List mismatches, retry affected specs → user decide |
| E010 | POST-GATE fail sau 3 retries | STOP — báo cáo chi tiết → user quyết định |
| E011 | Auto-fix gây regression | Rollback fix → escalate with context |
| E012 | Stakeholder review Critical/High findings sau 3 iterations (Phase 5) | STOP + báo cáo findings → user quyết định |
| E013 | `module-code-mapping.json` không tồn tại (Phase 7) | STOP → chạy `/wf-legacy-extract` trước |
| E014 | Gap classification fail (Phase 7) | Retry với relaxed thresholds |
| E015 | Digest generation fail (Phase 8) | Log warning, continue (backward compatible) |
| E016 | Phase summary template thiếu | Fallback tạo summary inline |

---

## Agents Spawned

| Phase | Agent | Mục đích |
|-------|-------|----------|
| 1 | `architect` | Architecture overview (P3-01) |
| 1 | `ai-engineer` | ML Pipeline section (conditional — `$HAS_AI_ML = true`) |
| 1 | `data-engineer` | Data Pipeline section (conditional — `$HAS_DATA_PIPELINE = true`) |
| 1 | `automation-architect` | Automation section (conditional — `$HAS_AUTOMATION = true`) |
| 2 | `architect` | API Contract |
| 2 | `dba` + `architect` | Database Design |
| 2 | `devops` + `architect` | Infra Spec |
| 3 | `architect` | Integration Map |
| 5 | `architect` | Stakeholder Review Phần B+C (Cross-Review, Consistency) |
| 5 | `security` | Stakeholder Review Phần D (Gap Analysis) |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/wf-define-features` | Prerequisite (tạo feature specs) |
| `/wf-analyze-requirements` | Prerequisite (new projects — trước `/wf-define-features`) |
| `/wf-legacy-scan` | Prerequisite (existing projects) |
| `/wf-legacy-extract` | Prerequisite cho Phase 7 (LEGACY) — tạo `module-code-mapping.json` |
| `/wf-design-ux` | **Next step** (nếu project có UI) — tiêu thụ business context từ P3-01 + integration-map (actor matrix, lifecycle, cross-module status) cho workflow-aware UX |
| `/wf-plan-modules` | **Next step** (nếu API-only, hoặc sau `/wf-design-ux`) |
| `/wf-implement-feature` | Consumer của `design-summary.json` + `design-input-digest.json` |

---

## Examples

### Example 1: Happy Path (new project)

```
Phase 0: Registry loaded, approach=System, LPM=false → PASS
Phase 1: business-context.md (actors/roles, lifecycle, cross-module, ownership — Step 1.0) → P3-01-architecture.md (architect + ai-engineer conditional) → PASS
Phase 2: api-contract.md + database-design.md + infra-spec.md PARALLEL → PASS
Phase 3: integration-map.md → PASS
Phase 4: Validation 8/8 checks PASS (1 iteration)
Phase 5: APPROVED (0 Critical, 2 Medium RESOLVED)
Phase 6: design_status=completed, design-summary.json created
Phase 8: design-input-digest.json + phase-summary.md → DONE

Next: /wf-design-ux (UI) hoặc /wf-plan-modules (API-only)
```

### Example 2: Multi-Session (large project, LPM)

```
SESSION 1: Phase 0-2 (LPM detected, 6 systems) → CHECKPOINT (Context: 82%, 3 systems done)
SESSION 2 (--resume): Phase 3-5 → CHECKPOINT (Context: 78%)
SESSION 3 (--resume): Phase 6-8 → DONE
```

### Example 3: LEGACY_MODE

```
Phase 0: LEGACY_MODE=true (project-context.md > 500 bytes), $DEPRECATED_MODULES=[MOD-OLD-01]
Phase 1-5: Design với LEGACY injection + [VERIFIED]/[INFERRED]/[RECOMMENDED] labels
Phase 6: registry updated với extended fields (systems, modules, features, interface_type)
Phase 7: Gap Analysis — cross-reference với module-code-mapping.json → action-items.json
Phase 8: DONE

Next: /wf-plan-modules (sử dụng action-items.json làm priority input)
```
