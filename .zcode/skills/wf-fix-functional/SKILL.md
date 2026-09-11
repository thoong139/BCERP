---
name: wf-fix-functional
version: 2.0.0-alpha.s6
last_updated: 2026-05-11
description: QD1 Functional Correctness Lane — phát hiện bug functional qua 10 probes (static, runtime, agent). TRIGGER: spawned bởi /wf-fix-bugs orchestrator khi QD1 trong selected_dims. KHÔNG gọi trực tiếp.

argument-hint: "[--session-dir=PATH] [--profile=quick|standard|deep|exhaustive] [--use-cache] [--base-url=URL]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-functional: QD1 Functional Correctness Lane

> **Shared Library:** `_shared/lane/_shared.md` (schema), `_shared/lane/{pre-gate,post-gate}.md`, `_shared/lane/profile-resolver.md`, `_shared/lane/signal-emit.md`, `_shared/lane/templates/`.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Dimension** | QD1 — Functional Correctness |
| **Muc dich** | Phat hien bug functional: UI control, API endpoint, infrastructure, feature coverage |
| **Entry point** | Spawned boi `/wf-fix-bugs` orchestrator (KHONG trigger truc tiep) |
| **Prerequisites** | `$SESSION_DIR` da tao, `req-registry.json` ton tai |
| **Duration** | 2-15 min tuy profile |
| **Probes** | 10 (lazy-load tu `procedures/probes/`; +3 v9.1: stub-todo-aggregate, multitenant-isolation-audit, spec-completeness-check) |
| **Cache Policy** | Static probes: opt-in `--use-cache`. Runtime probes: skip cache. |
| **Output** | `$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/{static-scan/signals.json, runtime/signals.json, llm-scan/signals.json, lane-status.json, QD1-functional-report.md}` |

### Workflow Position

```
/wf-fix-bugs (orchestrator v10.x)
  → Init session, compose plan
  → Spawn Lane QD1 (YOU ARE HERE)  ─┐
  → Spawn Lane QD2 (parallel)        │ CORE-025: write scope tach biet
  → Spawn Lane QD3 (parallel)        │ KHONG goi nhau truc tiep
  → ... (other lanes)              ─┘
  → Signal Bus aggregate + dedup → issue-registry.json
  → Triage → Fix Execute → Verify → Report
```

Next step: Orchestrator tiep tuc Signal Aggregation sau khi lane complete (POST-GATE).

## Probe Routing Table (Lazy-Load)

| Probe ID | Loai | quick | standard | deep | exhaustive | Procedure file |
|----------|------|:-----:|:--------:|:----:|:----------:|----------------|
| P-QD1-req-registry-xref | static | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD1-req-registry-xref.md` |
| P-QD1-route-config-parse | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD1-route-config-parse.md` |
| P-QD1-infra-preflight | runtime | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD1-infra-preflight.md` |
| P-QD1-api-smoke | runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD1-api-smoke.md` |
| P-QD1-orphan-ui-detect | static+runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD1-orphan-ui-detect.md` |
| P-QD1-deep-ui-traversal | runtime | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD1-deep-ui-traversal.md` |
| P-QD1-agent-feature-verify | agent | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD1-agent-feature-verify.md` |
| P-QD1-stub-todo-aggregate | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD1-stub-todo-aggregate.md` |
| P-QD1-multitenant-isolation-audit | static | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD1-multitenant-isolation-audit.md` |
| P-QD1-spec-completeness-check | agent | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD1-spec-completeness-check.md` |
| P-QD1-llm-analysis | llm | ❌ | ❌ | ✅ | ✅ | `prompts/llm-probe-qd1-functional.md` |

**Lazy-load:** SKILL.md chỉ load probe file khi probe trigger. Profile-resolver xác định probe subset → spawn từng probe theo `procedures/probes/<id>.md`.

## Phase 1: PRE-GATE + SENSE

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | PRE-GATE forensic + resolve profile + init lane state | lane skill | `lane-status.json` (in_progress) |
| 2 | SENSE — chạy static probes (req-registry-xref, route-config-parse) | lane skill | `phase4-find-bugs/lanes/QD1-functional/raw/<probe>.json` |

## Phase 2: THINK + ACT + VERIFY

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 3 | THINK — cross-ref + dedup + severity hint | lane skill | (in-memory) |
| 4 | ACT — chạy runtime + agent probes (per profile) | lane skill | `phase4-find-bugs/lanes/QD1-functional/raw/<probe>.json` + evidence |
| 5 | VERIFY — validate signal-v2 schema, drop signals thiếu evidence | lane skill | merged `signals.json` |
| 6 | POST-GATE T1-T4 + render lane-report + phase-summary | lane skill | `lane-report.md`, `phase-summary.md`, `lane-status.json=completed` |

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools được auto-detect, không hỏi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → IF `needs_scan` → call `mcp__serena__check_onboarding_performed` + `ListMcpResourcesTool` → `ci-detect.sh --write-cache '<json>'` → read cache → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Skip nếu non-git. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sánh HEAD vs index_commit. Freshness level → caveat trong probe context nếu stale (light ≤5 / strong 6-20 / severe >20). | Freshness status set |
| 0.Nc | **CI Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → 4 templates auto-select → inject vào probe execution context. IF no CI → exit 1 → continue với Grep/Glob (current behavior, zero regression). | CI context ready |

### CI-ROUTE: Functional Bug Detection (Protocol 20 §20.5)

> **Khi `$GITNEXUS_AVAILABLE == "true"` hoặc `$SERENA_AVAILABLE == "true"`:** PHẢI dùng GitNexus + Serena để trace bug flows. KHÔNG dùng Grep/Read thủ công khi CI tools available.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `understand_flow` | **GitNexus** `query("{feature_name}")` | Grep + Read | Trace execution flows của feature cần verify |
| `find_references` | **Serena** `find_referencing_symbols` | Grep | Kiểm tra REQ-ID có code reference |
| `symbol_overview` | **Serena** `get_symbols_overview` | Read file | Hiểu cấu trúc file nghi ngờ có bug |

> **Freshness caveat:** Nếu index behind > 0 → kèm cảnh báo trong probe findings.

## PRE-GATE

**Procedure:** `procedures/pre-gate.md` (lane-specific extensions của `_shared/lane/pre-gate.md`).

Tóm tắt: 7 steps chuẩn (orchestrator handoff → input data → dimension scope → resolve profile → init working dir → init lane-status.json → init signals.json) + Step 8 verify --base-url + Step 9 resolve probe list QD1.

## Execution: Sense → Think → Act → Verify

Lane chạy probes theo profile-resolver mapping. Mỗi probe: SENSE collect → THINK analyze → ACT emit signals atomic (xem `_shared/lane/signal-emit.md`) → VERIFY locally.

**CI-ROUTE cho probes:** Static probes (P-QD1-req-registry-xref, P-QD1-route-config-parse) PHẢI dùng Serena `find_referencing_symbols` để verify REQ-ID → code trace thay vì grep thủ công. Runtime probes (P-QD1-api-smoke, P-QD1-infra-preflight) PHẢI dùng GitNexus `query()` để trace execution flows trước khi test. CI unavailable → fallback Grep/Read (current behavior).

Sau khi hết probes:
- Merge raw signals → `phase4-find-bugs/lanes/QD1-functional/signals.json` (atomic, dedup theo fingerprint)
- Update `lane-status.json.totals` (signals_emitted, signals_by_severity)

## POST-GATE

**Procedure:** `procedures/post-gate.md` (lane-specific T3 rules cho QD1).

Tóm tắt: T1 Existence (4/4 files) → T2 Structure ($schema, fields, sections) → T3 Content (signal-v2 valid + QD1 dimension match + runtime evidence) → T4 Cross-ref (location.file exists, REQ-IDs trong registry, probe_ids declared).

## Severity Rules (QD1)

| Điều kiện | Severity | Confidence |
|-----------|----------|-----------|
| Infrastructure down (P-QD1-infra-preflight fail) | CRITICAL | 0.95 |
| Feature impl_status=done + endpoint không tồn tại / HTTP 5xx | CRITICAL | 0.90 |
| Feature impl_status=done + REQ-ID không có code reference | HIGH | 0.90 |
| UI primary CTA không click được / form không submit | HIGH | 0.85 |
| Route config mismatch spec | HIGH | 0.85 |
| Feature done + code co TODO/FIXME/stub (done_feature_has_todo) | HIGH | 0.85 |
| Feature in_progress + code co stub (in_progress_feature_stub) | HIGH | 0.80 |
| Feature done + >=1 requirement hoan toan thieu code | HIGH | 0.90 |
| Feature done + coverage < 80% (done_feature_low_coverage) | HIGH | 0.85 |
| Orphan UI element (UI có nhưng không trong Navigation spec) | MEDIUM | 0.70 |
| impl_status != done + REQ-ID không có code ref | MEDIUM | 0.80 |
| Spec yeu cau X, code implement Y (spec_code_mismatch) | MEDIUM | 0.60 |
| Orphan stub khong co REQ-ID (orphan_stub_implementation) | MEDIUM | 0.55 |
| FIXME/HACK marker trong production code | MEDIUM | 0.50 |
| Route config minor discrepancy | LOW | 0.60 |
| Empty function body / dead conditional feature flag | LOW | 0.40 |

## Fix Rules

| Severity | Action | Suggested Agent |
|----------|--------|-----------------|
| critical | auto_fix nếu infra restart, otherwise agent_fix | developer / devops |
| high | agent_fix | fullstack-developer / frontend-developer |
| medium | agent_fix | developer |
| low | skip hoặc batch fix | — |

## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/`

| File | Required | Template | Mô tả |
|------|----------|----------|-------|
| `static-scan/signals.json` | yes | `_shared/lane/templates/signals.json` | Static probe signals (signal-v2). |
| `runtime/signals.json` | yes | `_shared/lane/templates/signals.json` | Runtime/agent probe signals (signal-v2). |
| `llm-scan/signals.json` | yes (nếu `--llm-scan`) | `_shared/lane/templates/signals.json` | LLM probe signals (signal-v2). |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` | Progress tracker (lane-status-v1). |
| `QD1-functional-report.md` | yes | `_shared/lane/templates/lane-report.md` | Issue counts by severity + probe results. |
| `raw/` | optional | — | Per-probe raw outputs. |
| `evidence/` | optional | — | Screenshots, HTTP traces. |

> `phase-summary.md` không còn được tạo — orchestrator tổng hợp vào `Phase4-report.md`.

Next step: `/wf-fix-bugs` Signal Aggregation Phase 1 step 1.2.

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E041 | PRE-GATE FAIL (SESSION_DIR/registry/dimension scope invalid) | STOP — ghi lane-status.failed, exit non-zero |
| E042 | Probe execution timeout (>profile budget) | Mark probe skipped, continue probes khác |
| E043 | Evidence file missing khi emit signal | Drop signal + log WARNING |
| E044 | CDG flag rejected by user | Skip signal fix downstream |
| E045 | POST-GATE T1-T4 FAIL sau retry 2 lần | Mark status=partial, return orchestrator |
| E046 | Runtime probe — BASE_URL không có | Skip probe, note "skipped_no_base_url" |
| E047 | Scan Cache corrupt | Fallback scan thường, log WARNING |
| E048 | Agent timeout (P-QD1-agent-feature-verify) | Skip probe, emit 0 signals |

## Registry Safe-Write

Lane KHÔNG ghi `req-registry.json`. Role: NONE (CORE-006). Chỉ đọc registry để cross-ref REQ-ID annotations.

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-fix-bugs` | Parent orchestrator — spawn lane khi QD1 ∈ selected_dims |
| `/wf-fix-triage` | Downstream — nhận aggregated signals |
| `/wf-fix-execute` | Downstream — fix bugs sau triage |
| `/wf-fix-business` | Sibling lane QD2 (parallel) |
| `/wf-fix-security` | Sibling lane QD3 (parallel) |
| `/wf-fix-performance` | Sibling lane QD4 (parallel) |
| `/wf-fix-ux-a11y` | Sibling lane QD5 (parallel) |
| `/wf-fix-data` | Sibling lane QD6 (parallel) |
| `/wf-fix-compat` | Sibling lane QD7 (parallel) |
| `/wf-fix-observability` | Sibling lane QD8 (parallel) |
| `/wf-fix-runtime-health` | Sibling lane QD9 (parallel) |
| `/wf-fix-integration` | Sibling lane QD10 (parallel) |
| `/wf-fix-business-completeness` | Sibling lane QD11 (parallel) |

## References

- Quality Dimensions: `docs/design/skills/wf-fix-bugs/02-quality-dimensions.md` §QD1
- Architecture: `docs/design/skills/wf-fix-bugs/03-architecture.md` §2.2
- Contracts: `docs/design/skills/wf-fix-bugs/04-contracts-data-model.md`
- Execution Profiles: `docs/design/skills/wf-fix-bugs/05-execution-profiles.md`
- Core Rules: `.claude/rules/00-core.md` (CORE-006/007/011/012/023/025/026/028/030/031)
- Protocols: `.claude/skills/protocols/{01,10,14,15,16,19}-*.md`
