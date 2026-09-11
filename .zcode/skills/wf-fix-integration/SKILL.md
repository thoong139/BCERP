---
name: wf-fix-integration
version: 1.9.0
last_updated: 2026-05-11
description: |
  QD10 Cross-Module Integration Lane — phat hien loi tich hop giua cac modules: cross-module reference drift,
  API contract violations, event handler coverage gaps, orphan FK references, multi-platform entity sync issues,
  cache staleness, state machine errors, business flow violations, auth matrix violations.

  TRIGGER: spawned boi /wf-fix-bugs orchestrator khi QD10 trong selected_dims. KHONG goi truc tiep.
  SKIP: khong co cross_module_dependencies[] trong registry (E100) hoac profile=quick.

argument-hint: "[--session-dir=PATH] [--profile=quick|standard|deep|exhaustive] [--pair=MODULE_A-MODULE_B] [--test-cache-sync]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-integration: QD10 Cross-Module Integration Lane

> **Shared Library:** `_shared/lane/_shared.md`, `_shared/lane/{pre-gate,post-gate}.md`, `_shared/lane/profile-resolver.md`, `_shared/lane/signal-emit.md`, `_shared/lane/templates/`.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Dimension** | QD10 — Cross-Module Integration |
| **Muc dich** | Phat hien loi tich hop giua cac modules: reference drift, API contract violations, event handler gaps, orphan references, multi-platform sync, cache staleness, state machine errors, business flow violations |
| **Entry point** | Spawned boi `/wf-fix-bugs` orchestrator |
| **Owner Agent** | `architect`, `data-engineer`, domain experts (theo pair) |
| **Prerequisites** | `$SESSION_DIR` da tao, `cross_module_dependencies[]` ton tai trong registry, source code co the accessible |
| **Duration** | 2-20 min tuy profile (quick=skip, standard=static only, deep=+runtime, exhaustive=+business) |
| **Probes** | 10 (lazy-load; 3 static Wave 2, 3 runtime Wave 3, 2 business Wave 4, 1 auth-matrix Wave 5, 1 fe-be-coverage v9.1) |
| **Cache Policy** | static probes: 24h; runtime probes: skip (no cache) |
| **Output** | `$SESSION_DIR/phase4-find-bugs/lanes/QD10-integration/{signals.json, lane-status.json, lane-report.md, phase-summary.md}` |

### Workflow Position

```
/wf-fix-bugs (orchestrator v9.x)
  → Spawn Lane QD10 (YOU ARE HERE) ─┐ CORE-025: sau QD9 (doc flow-unreliable.json)
  → ... (other lanes parallel)     ─┘ QD10 singleton trong Wave 4 (sau QD1-QD9 batch)
  → QD10 signals → Signal Bus aggregate
  → Triage → Fix Execute → Verify → Report
```

**QD9 → QD10 coordination:**
- Doc `$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/flow-unreliable.json` → skip flows bi broken (neu co)
- Doc `$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/dev-server-state.json` → reuse dev server session
- Doc `$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/auth-session.json` → reuse auth cookies/tokens cho API calls

Next step: Orchestrator tiep tuc Signal Aggregation. Cross-module drifts → wf-fix-triage phan loai.

## Probe Routing Table (Lazy-Load)

| Probe ID | Loai | quick | standard | deep | exhaustive | Procedure file |
|----------|------|:-----:|:--------:|:----:|:----------:|----------------|
| P-QD10-cross-module-ref-static | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD10-cross-module-ref-static.md` |
| P-QD10-api-contract-drift | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD10-api-contract-drift.md` |
| P-QD10-event-handler-coverage | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD10-event-handler-coverage.md` |
| P-QD10-orphan-reference-runtime | runtime | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD10-orphan-reference-runtime.md` |
| P-QD10-multi-platform-entity-sync | runtime | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD10-multi-platform-entity-sync.md` |
| P-QD10-cache-staleness-probe | runtime | ❌ | ❌ | ❌ | ✅ | `procedures/probes/P-QD10-cache-staleness-probe.md` |
| P-QD10-state-machine-correctness | static | ❌ | ❌ | ❌ | ✅ | `procedures/probes/P-QD10-state-machine-correctness.md` |
| P-QD10-llm-analysis | llm | ❌ | ❌ | ✅ | ✅ | `prompts/llm-probe-qd10-integration.md` |
| P-QD10-business-flow-runtime | runtime | ❌ | ❌ | ❌ | ✅ | `procedures/probes/P-QD10-business-flow-runtime.md` |
| P-QD10-auth-matrix-check | static | ❌ | ❌ | ❌ | ✅ | `procedures/probes/P-QD10-auth-matrix-check.md` |
| P-QD10-frontend-backend-coverage | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD10-frontend-backend-coverage.md` |

> **quick profile:** Lane bi SKIP hoan toan. Ghi lane-status.json = "skipped" + ly do.
> **Probes Wave 2 (static):** chay parallel max 3 (CORE-025 §4.3 — static class).
> **Probes Wave 3 (runtime):** sequential (API/DB connection limit). Opt-in: `--test-cache-sync` cho cache-staleness-probe.
> **Probes Wave 4-5 (exhaustive):** state-machine-correctness + auth-matrix-check (static, parallel max 2) → business-flow-runtime (runtime, cuoi cung).

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools duoc auto-detect, khong hoi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → IF `needs_scan` → call `mcp__serena__check_onboarding_performed` + `ListMcpResourcesTool` → `ci-detect.sh --write-cache '<json>'` → read cache → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Skip neu non-git. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sanh HEAD vs index_commit. Freshness level → caveat trong probe context neu stale. | Freshness status set |
| 0.Nc | **CI Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → 4 templates auto-select → inject vao probe execution context. | CI context ready |

### CI-ROUTE: Cross-Module Analysis (Protocol 20 §20.5)

> **Khi `$SERENA_AVAILABLE == "true"` hoac `$GITNEXUS_AVAILABLE == "true"`:** PHAI dung Serena/GitNexus de phan tich cross-module references. KHONG grep thu cong khi CI tools available.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `find_consumer_references` | **Serena** `find_referencing_symbols(provider_entity)` | Grep import paths | **PRIMARY** — verify consumer references |
| `blast_radius_before_edit` | **GitNexus** `impact(provider_symbol, upstream)` | Manual grep | Identify consumer modules pre-edit |
| `locate_provider_dto` | **Serena** `find_symbol(provider_dto_name)` | Glob OpenAPI files | Locate provider/consumer schemas |
| `find_event_subscribers` | **GitNexus** `query("event:event-name")` cypher | Grep `on('event')` | **PRIMARY** — find subscribers in graph |
| `find_event_emitter_refs` | **Serena** `find_referencing_symbols(event_emitter)` | Grep | Backup if GitNexus stale |
| `trace_state_transitions` | **GitNexus** `query("state, transition, status")` | Grep switch/if chains | **PRIMARY** — trace transition logic |
| `find_state_enum` | **Serena** `find_symbol(state_enum_name)` | Grep | Verify state values declared |
| `find_api_endpoint` | **Serena** `find_symbol(endpoint_handler_name)` | Grep | Locate API handler per step |
| `trace_business_flow` | **GitNexus** `impact(step_symbol, upstream)` | Manual grep | Pre-flight: verify step symbol exists |

## Phase 1: PRE-GATE + SENSE

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | PRE-GATE forensic + detect cross_module_deps + resolve profile + load QD9 coordination files | lane skill | `lane-status.json` (in_progress) |
| 2 | Phase SENSE — phan tich static cross-module refs via Serena + GitNexus | lane skill | `phase4-find-bugs/lanes/QD10-integration/raw/<probe>.jsonl` |

## Phase 2: THINK + ACT + VERIFY

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 3 | Phase THINK — phan tich drifts + gaps + violations | lane skill | (in-memory) |
| 4 | Phase ACT — runtime probes (DB, API) neu profile=deep+, business flow neu exhaustive | lane skill | API responses + DB query results + signals |
| 5 | Phase VERIFY — validate evidence + emit signals | lane skill | merged `signals.json` |
| 6 | POST-GATE T1-T4 + cross-module evidence check | lane skill | `lane-report.md`, `phase-summary.md`, `lane-status.json=completed` |

## PRE-GATE

**Procedure:** `procedures/pre-gate.md`. Tom tat: 7 steps chuan + Step 8 detect cross_module_dependencies (skip neu empty → E100) + Step 9 load QD9 coordination files (optional) + Step 10 resolve probe list QD10 + Step 11 validate --pair filter (neu co).

## Execution: Static → Runtime → Business

Static probes (P-QD10-cross-module-ref-static, P-QD10-api-contract-drift, P-QD10-event-handler-coverage) co the chay PARALLEL max 3 (CORE-025: static class). Runtime probes SEQUENTIAL (API/DB connection limit). Atomic emit qua `_shared/lane/signal-emit.md`.

## POST-GATE

**Procedure:** `procedures/post-gate.md` (T3 rules QD10: cross-module signal phai co provider+consumer evidence, orphan reference phai co query evidence, API drift phai co schema evidence).

## Severity Rules (QD10)

| Dieu kien | Severity | CDG Flag |
|-----------|----------|----------|
| Orphan FK reference (consumer refs non-existent provider row) | CRITICAL | CDG-RELIABILITY-RISK |
| API contract field removed/renamed (breaking change) | HIGH | — |
| State machine invalid transition possible | HIGH | — |
| Business flow step unreachable | HIGH | — |
| Event handler completely missing for declared event | HIGH | — |
| Consumer importing deprecated provider export | MEDIUM | — |
| API contract type mismatch (non-breaking) | MEDIUM | — |
| Backend endpoint (feature done) khong co frontend consumer | HIGH | — |
| Frontend form action khong co backend handler | HIGH | — |
| Frontend API call trong page load khong co backend handler | HIGH | — |
| Cache staleness > 5s on entity sync | MEDIUM | — |
| Multi-platform entity shape divergence | MEDIUM | — |
| Event handler partial coverage (some event types missing) | MEDIUM | — |
| Frontend API call trong event handler khong co backend handler | MEDIUM | — |
| Consumer missing optional field that is now used | LOW | — |
| Backend endpoint (unknown feature) khong co frontend consumer | LOW | — |

## Fix Rules

| Severity | Action | Suggested Agent |
|----------|--------|-----------------|
| critical | agent_fix (orphan reference = data integrity risk) | data-engineer / architect |
| high | agent_fix | architect / developer |
| medium | agent_fix hoac batch | developer |
| low | batch fix hoac skip | developer |

## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/QD10-integration/`

| File | Required | Template | Mô tả |
|------|----------|----------|-------|
| `static-scan/signals.json` | yes | `_shared/lane/templates/signals.json` | Static probe signals với cross-module evidence (signal-v2). |
| `runtime/signals.json` | yes | `_shared/lane/templates/signals.json` | Runtime probe signals (signal-v2). |
| `llm-scan/signals.json` | yes (nếu `--llm-scan`) | `_shared/lane/templates/signals.json` | LLM probe signals (signal-v2). |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` | Progress tracker. |
| `QD10-integration-report.md` | yes | `_shared/lane/templates/lane-report.md` | Findings by severity + cross-module drift summary. |
| `raw/` | optional | — | Per-probe raw outputs (JSONL). |
| `evidence/` | optional | — | Schema diffs, API responses, DB query results. |

> `phase-summary.md` không còn được tạo — orchestrator tổng hợp vào `Phase4-report.md`.

**Cross-lane coordination:**
- Đọc `$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/flow-unreliable.json` (nếu có) → skip flows bị broken trong P-QD10-business-flow-runtime
- Đọc `$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/dev-server-state.json` (nếu có) → reuse dev server cho runtime probes
- Đọc `$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/auth-session.json` (nếu có) → reuse auth session cho API calls

Next step: `/wf-fix-bugs` Signal Aggregation Phase 1 step 1.2.

## Error Handling

| Code | Tinh huong | Xu ly |
|------|-----------|-------|
| E099 | PRE-GATE FAIL | STOP — ghi lane-status.failed |
| E100 | Khong co cross_module_dependencies trong registry | SKIP lane — ghi lane-status.skipped + ly do |
| E101 | cross_module_dependencies filter --pair khong khop | SKIP lane — ghi lane-status.skipped + ly do |
| E102 | Provider module code path khong tim thay | WARN trong probe output — fallback Grep |
| E103 | Consumer module code path khong tim thay | WARN trong probe output — fallback Grep |
| E104 | DB connection env la production (safety guard W3.1) | STOP probe — ghi safety violation |
| E105 | POST-GATE T3 FAIL (thieu cross-module evidence) | STOP — return failed (compliance violation) |
| E106 | API schema parse fail (OpenAPI/GraphQL malformed) | WARN trong probe + fallback DTO analysis |

## Registry Safe-Write

Lane KHONG ghi `req-registry.json`. Role: NONE.

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-fix-bugs` | Parent orchestrator |
| `/wf-fix-triage` | Downstream — classify cross-module errors |
| `/wf-fix-execute` | Downstream — fix integration bugs |
| `/wf-fix-runtime-health` | Sibling lane QD9 (upstream — provides coordination files) |
| `/wf-fix-data` | Sibling lane QD6 (overlap: schema drift detect — reuse QD6 algorithm) |
| `/wf-fix-business` | Sibling lane QD2 (upstream — boundary mode enhancement W2.5) |
| `architect` agent | `.claude/agents/engineering/architect.md` |
| `data-engineer` agent | `.claude/agents/engineering/data-engineer.md` |

## References

- Reuse map: `plans/wf-fix-bugs-v9/03-reuse-ci-parallelism.md` §2.3 (per-probe reuse QD10), §3.3 (CI-ROUTE QD10)
- Parallelism: `plans/wf-fix-bugs-v9/03-reuse-ci-parallelism.md` §4.3 (static probes parallel, runtime sequential)
- Core Rules: `.claude/rules/00-core.md` (CORE-006/007/011/012/023/025/026/027/028/030/031)
- Protocol 20: `.claude/skills/protocols/20-code-intelligence.md`
