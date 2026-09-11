---
name: wf-fix-data
version: 2.0.0-alpha.s4
last_updated: 2026-04-28
description: |
  QD6 Data Integrity & Resilience Lane — phat hien van de validation, schema drift, constraint violation, idempotency qua probes P-QD6-xxx (6 probes lazy-load).

  TRIGGER: spawned boi /wf-fix-bugs orchestrator khi QD6 trong selected_dims. KHONG goi truc tiep.

  v2.0 (S3-S4): chuan hoa schema, tach probes + pre-gate + post-gate ra procedures/ (lazy-load). Fix F8, F9, F10, F16.

argument-hint: "[--session-dir=PATH] [--profile=quick|standard|deep|exhaustive] [--use-cache] [--base-url=URL]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-data: QD6 Data Integrity & Resilience Lane

> **Shared Library:** `_shared/lane/_shared.md`, `_shared/lane/{pre-gate,post-gate}.md`, `_shared/lane/profile-resolver.md`, `_shared/lane/signal-emit.md`, `_shared/lane/templates/`.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Dimension** | QD6 — Data Integrity & Resilience |
| **Muc dich** | Validation, constraint DB, edge-cases (null/empty/unicode/boundary), concurrency (race, idempotency), retry/timeout, schema drift |
| **Entry point** | Spawned boi `/wf-fix-bugs` orchestrator |
| **Owner Agent** | `dba`, `database-engineer` |
| **Prerequisites** | `$SESSION_DIR` da tao, source code + migration files |
| **Duration** | 2-15 min tuy profile |
| **Probes** | 6 (lazy-load) |
| **Cache Policy** | Static probes (schema-drift, ORM-sync, type-mismatch): opt-in. Runtime (constraint, race): skip cache. |
| **Output** | `$SESSION_DIR/phase4-find-bugs/lanes/QD6-data/{signals.json, lane-status.json, lane-report.md, phase-summary.md}` |

### Workflow Position

```
/wf-fix-bugs (orchestrator v9.x)
  → Spawn Lane QD6 (YOU ARE HERE) ─┐ CORE-025: parallel với other lanes
  → ... (other lanes parallel)    ─┘
  → Signal Bus aggregate
  → Triage → Fix Execute (CDG-SCHEMA-BREAK escalation) → Verify → Report
```

Next step: Orchestrator tiếp tục Signal Aggregation. Schema-break CRITICAL → CDG escalate.

## Probe Routing Table (Lazy-Load)

| Probe ID | Loai | quick | standard | deep | exhaustive | Procedure file |
|----------|------|:-----:|:--------:|:----:|:----------:|----------------|
| P-QD6-schema-drift-detect | static+runtime | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD6-schema-drift-detect.md` |
| P-QD6-migration-integrity | static | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD6-migration-integrity.md` |
| P-QD6-constraint-violation | runtime | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD6-constraint-violation.md` |
| P-QD6-data-type-mismatch | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD6-data-type-mismatch.md` |
| P-QD6-orm-model-sync | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD6-orm-model-sync.md` |
| P-QD6-seed-data-audit | static | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD6-seed-data-audit.md` |
| P-QD6-llm-analysis | llm | ❌ | ❌ | ✅ | ✅ | `prompts/llm-probe-qd6-data-integrity.md` |

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools được auto-detect, không hỏi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → IF `needs_scan` → call `mcp__serena__check_onboarding_performed` + `ListMcpResourcesTool` → `ci-detect.sh --write-cache '<json>'` → read cache → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Skip nếu non-git. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sánh HEAD vs index_commit. Freshness level → caveat trong probe context nếu stale. | Freshness status set |
| 0.Nc | **CI Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → 4 templates auto-select → inject vào probe execution context. IF no CI → exit 1 → continue với Grep/Glob (current behavior). | CI context ready |

### CI-ROUTE: Data Integrity Discovery (Protocol 20 §20.5)

> **Khi `$GITNEXUS_AVAILABLE == "true"` hoặc `$SERENA_AVAILABLE == "true"`:** PHẢI dùng GitNexus + Serena để trace data flows. KHÔNG dùng Grep/Read thủ công khi CI tools available.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `understand_flow` | **GitNexus** `query("data mutation, migration")` | Grep + Read | Trace data mutation flows, schema migration paths |
| `find_references` | **Serena** `find_referencing_symbols` | Grep | Tìm tất cả nơi dùng schema/model/ORM entity |
| `impact_analysis` | **GitNexus** `impact({target, direction: "upstream"})` | Manual grep | Blast radius của schema change — ai bị ảnh hưởng |

> **Freshness caveat:** Nếu index behind > 0 → kèm cảnh báo trong probe findings.

## Phase 1: PRE-GATE + SENSE

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | PRE-GATE forensic + verify migration/schema files exist + resolve profile | lane skill | `lane-status.json` (in_progress) |
| 2 | Phase SENSE — chạy static probes (ORM sync, type-mismatch, schema-drift, migration) | lane skill | `phase4-find-bugs/lanes/QD6-data/raw/<probe>.json` |

## Phase 2: THINK + ACT + VERIFY

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 3 | Phase THINK — diff schema vs ORM model + idempotency analysis | lane skill | (in-memory) |
| 4 | Phase ACT — chạy runtime probes (constraint, race condition fuzz) | lane skill | http traces + signals |
| 5 | Phase VERIFY — validate schema_diff/migration evidence + CDG-SCHEMA-BREAK flags | lane skill | merged `signals.json` |
| 6 | POST-GATE T1-T4 + idempotency severity check + CDG enforcement | lane skill | `lane-report.md`, `phase-summary.md`, `lane-status.json=completed` |

## PRE-GATE

**Procedure:** `procedures/pre-gate.md`. Tóm tắt: 7 steps chuẩn + Step 8 verify migration directory + ORM model files exist + Step 9 verify --base-url + Step 10 resolve probe list QD6.

## Execution: Sense → Think → Act → Verify

Lane chạy probes theo profile-resolver. Atomic emit qua `_shared/lane/signal-emit.md`. Schema-break signals tự động đính kèm CDG-SCHEMA-BREAK hoặc CDG-DELETE-DATA flag.

## POST-GATE

**Procedure:** `procedures/post-gate.md` (T3 rules QD6: schema/migration evidence required, CDG-SCHEMA-BREAK enforcement, idempotency-on-payment severity check).

## Severity Rules (QD6)

| Điều kiện | Severity | CDG Flag |
|-----------|----------|----------|
| Missing DB constraint khiến data corrupt | CRITICAL | CDG-SCHEMA-BREAK |
| No idempotency trên payment/order/checkout endpoint | CRITICAL | — |
| Race condition xác nhận trên business mutation | CRITICAL | — |
| Migration drop column / alter type without backup | CRITICAL | CDG-DELETE-DATA |
| Schema drift (ORM vs DB) khiến runtime crash | CRITICAL | CDG-SCHEMA-BREAK |
| Edge-case crash 500 (null/empty/unicode/boundary) | HIGH | — |
| Stale read / lost update | HIGH | — |
| Validation mismatch FE-BE | MEDIUM | — |
| Missing retry/timeout policy | MEDIUM | — |
| Schema drift minor (ORM extra field, no runtime impact) | MEDIUM | — |
| Seed data outdated | LOW | — |

## Fix Rules

| Severity | Action | Suggested Agent |
|----------|--------|-----------------|
| critical | escalate (CDG required cho schema-break, không auto-fix) | dba / database-engineer |
| high | agent_fix (add validation, fix race, write migration) | backend-developer / dba |
| medium | agent_fix (sync FE-BE validation, add retry config) | developer |
| low | batch fix hoặc skip | developer |

## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/QD6-data/`

| File | Required | Template | Mô tả |
|------|----------|----------|-------|
| `static-scan/signals.json` | yes | `_shared/lane/templates/signals.json` | Static probe signals với schema_diff + CDG flags (signal-v2). |
| `runtime/signals.json` | yes | `_shared/lane/templates/signals.json` | Runtime probe signals (signal-v2). |
| `llm-scan/signals.json` | yes (nếu `--llm-scan`) | `_shared/lane/templates/signals.json` | LLM probe signals (signal-v2). |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` | Progress tracker. |
| `QD6-data-report.md` | yes | `_shared/lane/templates/lane-report.md` | Findings by severity + schema diffs. |
| `raw/` | optional | — | Per-probe raw outputs. |
| `evidence/` | optional | — | HTTP traces, DB query results. |

> `phase-summary.md` không còn được tạo — orchestrator tổng hợp vào `Phase4-report.md`.

Next step: `/wf-fix-bugs` Signal Aggregation Phase 1 step 1.2.

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E041 | PRE-GATE FAIL | STOP — ghi lane-status.failed |
| E042 | Probe execution timeout | Mark probe skipped, continue |
| E043 | Migration directory không tìm thấy | Skip P-QD6-migration-integrity + P-QD6-schema-drift-detect, note "no_migrations" |
| E044 | ORM model files không có | Skip P-QD6-orm-model-sync, note "no_orm_files" |
| E045 | Database không truy cập được | Skip runtime probes (P-QD6-constraint-violation), note "no_db_access" |
| E046 | POST-GATE T3 FAIL (schema-break thiếu CDG flag) | STOP — return failed (compliance violation) |
| E047 | Agent timeout (database-engineer) | Skip probe, emit 0 signals |
| E048 | Schema diff parse error | Log WARNING, continue với probes khác |

## Registry Safe-Write

Lane KHÔNG ghi `req-registry.json`. Role: NONE.

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-fix-bugs` | Parent orchestrator |
| `/wf-fix-triage` | Downstream — escalate CDG-SCHEMA-BREAK signals |
| `/wf-fix-execute` | Downstream — respect CDG reject tokens |
| `/wf-fix-functional` | Sibling lane QD1 (parallel) |
| `/wf-fix-performance` | Sibling lane QD4 (parallel — DB query overlap) |
| `dba` agent | `.claude/agents/engineering/dba.md` |

## References

- Quality Dimensions: `docs/design/skills/wf-fix-bugs/02-quality-dimensions.md` §QD6
- Architecture: `docs/design/skills/wf-fix-bugs/03-architecture.md`
- Core Rules: `.claude/rules/00-core.md` (CORE-006/007/011/012/023/025/026/027/028/030/031)
