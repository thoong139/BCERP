---
name: wf-fix-performance
version: 2.0.0-alpha.s4
last_updated: 2026-05-15
description: |
  QD4 Performance Bottlenecks Lane — phat hien van de hieu nang qua probes P-QD4-xxx (7 probes lazy-load).
  Bao gom CWV (LCP/INP/CLS), API latency p50/p95/p99, N+1 queries, bundle size, memory leaks.

  TRIGGER: spawned boi /wf-fix-bugs orchestrator khi QD4 trong selected_dims. KHONG goi truc tiep.

  v2.0 (S3-S4): chuan hoa schema, tach probes + pre-gate + post-gate ra procedures/ (lazy-load). Fix F8, F9, F10, F16.

argument-hint: "[--session-dir=PATH] [--profile=quick|standard|deep|exhaustive] [--use-cache] [--base-url=URL]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-performance: QD4 Performance Bottlenecks Lane

> **Shared Library:** `_shared/lane/_shared.md`, `_shared/lane/{pre-gate,post-gate}.md`, `_shared/lane/profile-resolver.md`, `_shared/lane/signal-emit.md`, `_shared/lane/templates/`.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Dimension** | QD4 — Performance & Efficiency |
| **Muc dich** | Đo latency, throughput, memory, bundle size, render perf. Phát hiện N+1, slow queries, missing memoization |
| **Entry point** | Spawned boi `/wf-fix-bugs` orchestrator |
| **Owner Agent** | `performance-benchmarker` |
| **Prerequisites** | `$SESSION_DIR` da tao, source code ton tai |
| **Duration** | 2-15 min tuy profile (Lighthouse/k6 ton thoi gian) |
| **Probes** | 6 (lazy-load) |
| **Cache Policy** | Static probes (bundle-size, query-analysis): opt-in. Runtime probes (Lighthouse, k6): skip cache. |
| **Output** | `$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/{signals.json, lane-status.json, lane-report.md, phase-summary.md}` |

### Workflow Position

```
/wf-fix-bugs (orchestrator v10.x)
  → Spawn Lane QD4 (YOU ARE HERE) ─┐ CORE-025: parallel với other lanes
  → ... (other lanes parallel)    ─┘
  → Signal Bus aggregate
  → Triage → Fix Execute → Verify → Report
```

Next step: Orchestrator tiếp tục Signal Aggregation sau lane complete.

## Probe Routing Table (Lazy-Load)

| Probe ID | Loai | quick | standard | deep | exhaustive | Procedure file |
|----------|------|:-----:|:--------:|:----:|:----------:|----------------|
| P-QD4-bundle-size-audit | static | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD4-bundle-size-audit.md` |
| P-QD4-render-perf-check | runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD4-render-perf-check.md` |
| P-QD4-llm-analysis | llm | ❌ | ❌ | ✅ | ✅ | `prompts/llm-probe-qd4-performance.md` |
| P-QD4-api-latency-probe | runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD4-api-latency-probe.md` |
| P-QD4-db-query-analysis | static+runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD4-db-query-analysis.md` |
| P-QD4-core-web-vitals | runtime | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD4-core-web-vitals.md` |
| P-QD4-memory-leak-scan | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD4-memory-leak-scan.md` |

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools được auto-detect, không hỏi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → IF `needs_scan` → call `mcp__serena__check_onboarding_performed` + `ListMcpResourcesTool` → `ci-detect.sh --write-cache '<json>'` → read cache → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Skip nếu non-git. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sánh HEAD vs index_commit. Freshness level → caveat trong probe context nếu stale. | Freshness status set |
| 0.Nc | **CI Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → 4 templates auto-select → inject vào probe execution context. IF no CI → exit 1 → continue với Grep/Glob (current behavior). | CI context ready |

### CI-ROUTE: Performance Bottleneck Discovery (Protocol 20 §20.5)

> **Khi `$GITNEXUS_AVAILABLE == "true"` hoặc `$SERENA_AVAILABLE == "true"`:** PHẢI dùng GitNexus + Serena để trace slow paths. KHÔNG dùng Grep/Read thủ công khi CI tools available.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `understand_flow` | **GitNexus** `query("{endpoint_or_feature}")` | Grep + Read | Trace execution flows để phát hiện N+1 queries, slow paths |
| `symbol_overview` | **Serena** `get_symbols_overview` | Read file | Xác định heavy components, large modules |
| `find_references` | **Serena** `find_referencing_symbols` | Grep | Tìm call sites của expensive functions, check memoization coverage |

> **Freshness caveat:** Nếu index behind > 0 → kèm cảnh báo trong probe findings.

## Phase 1: PRE-GATE + SENSE

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | PRE-GATE forensic + verify perf tools (Lighthouse/k6) + resolve profile | lane skill | `lane-status.json` (in_progress) |
| 2 | Phase SENSE — chạy static probes (bundle, query, memory) | lane skill | `phase4-find-bugs/lanes/QD4-performance/raw/<probe>.json` |

## Phase 2: THINK + ACT + VERIFY

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 3 | Phase THINK — analyze metrics theo threshold rules | lane skill | (in-memory) |
| 4 | Phase ACT — chạy runtime probes (Lighthouse, k6, latency) | lane skill | metric evidence + signals |
| 5 | Phase VERIFY — validate metric values trong evidence | lane skill | merged `signals.json` |
| 6 | POST-GATE T1-T4 + threshold consistency check | lane skill | `lane-report.md`, `phase-summary.md`, `lane-status.json=completed` |

## PRE-GATE

**Procedure:** `procedures/pre-gate.md`. Tóm tắt: 7 steps chuẩn + Step 8 verify perf tools (lighthouse/k6/bundle-analyzer) + Step 9 verify --base-url + Step 10 resolve probe list QD4.

## Execution: Sense → Think → Act → Verify

Lane chạy probes theo profile-resolver. Atomic emit qua `_shared/lane/signal-emit.md`. Mỗi signal mang theo metric value (bundle KB, latency ms, LCP s) trong description + evidence.

## POST-GATE

**Procedure:** `procedures/post-gate.md` (T3 rules QD4: metric evidence required, severity threshold consistency, bundle size numeric value).

## Severity Rules (QD4)

| Điều kiện | Severity |
|-----------|----------|
| LCP > 4s trên page chính / page crash / timeout | CRITICAL |
| INP > 500ms trên page chính | HIGH |
| LCP 2.5s-4s trên page chính | HIGH |
| API p95 > 1000ms / p99 > 5000ms | HIGH |
| N+1 query xác nhận trên endpoint hot | HIGH |
| Bundle gzip > 500KB total | MEDIUM |
| DB query > 1s không có index | MEDIUM |
| LCP 2.5s baseline (border) | MEDIUM |
| Bundle gzip > 250KB | LOW |
| Missing memoization (React.memo, useMemo) | LOW |
| LCP < 2.5s, p95 < 200ms | INFO (no issue) |

## Fix Rules

| Severity | Action | Suggested Agent |
|----------|--------|-----------------|
| critical | escalate (perf incident — cần investigate root cause) | performance-benchmarker / sre |
| high | agent_fix (optimize query/cache/lazy-load) | performance-benchmarker / dba |
| medium | agent_fix (bundle split, index add) | frontend-developer / dba |
| low | skip hoặc batch fix | developer |

## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/`

| File | Required | Template | Mô tả |
|------|----------|----------|-------|
| `static-scan/signals.json` | yes | `_shared/lane/templates/signals.json` | Static probe signals với metric values (signal-v2). |
| `runtime/signals.json` | yes | `_shared/lane/templates/signals.json` | Runtime probe signals với metric values (signal-v2). |
| `llm-scan/signals.json` | yes (nếu `--llm-scan`) | `_shared/lane/templates/signals.json` | LLM probe signals (signal-v2). |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` | Progress tracker. |
| `QD4-performance-report.md` | yes | `_shared/lane/templates/lane-report.md` | Performance findings + metrics table. |
| `raw/` | optional | — | Per-probe raw outputs. |
| `evidence/` | optional | — | Lighthouse/k6 traces. |

> `phase-summary.md` không còn được tạo — orchestrator tổng hợp vào `Phase4-report.md`.

Next step: `/wf-fix-bugs` Signal Aggregation Phase 1 step 1.2.

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E041 | PRE-GATE FAIL | STOP — ghi lane-status.failed |
| E042 | Probe execution timeout (Lighthouse > 5min) | Mark probe skipped, continue |
| E043 | Lighthouse CLI không cài | Fallback static check, log WARNING |
| E044 | k6 không cài | Fallback curl loop, degraded coverage |
| E045 | Runtime probe — BASE_URL không có | Skip runtime probes, note "skipped_no_base_url" |
| E046 | POST-GATE T3 FAIL (metric evidence missing) | Retry, max 2 lần → status=partial |
| E047 | Bundle analyzer không configured | Fallback du size estimation, note degraded |
| E048 | Database không truy cập được | Skip P-QD4-db-query-analysis, note "no_db_access" |

## Registry Safe-Write

Lane KHÔNG ghi `req-registry.json`. Role: NONE.

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-fix-bugs` | Parent orchestrator |
| `/wf-fix-triage` | Downstream |
| `/wf-fix-execute` | Downstream |
| `/wf-fix-functional` | Sibling lane QD1 (parallel) |
| `/wf-fix-data` | Sibling lane QD6 (parallel — DB query analysis có overlap) |
| `performance-benchmarker` agent | `.claude/agents/testing/performance-benchmarker.md` |

## References

- Quality Dimensions: `docs/design/skills/wf-fix-bugs/02-quality-dimensions.md` §QD4
- Architecture: `docs/design/skills/wf-fix-bugs/03-architecture.md` §2.2
- Core Rules: `.claude/rules/00-core.md` (CORE-006/007/011/012/023/025/026/028/030/031)
