---
name: wf-fix-observability
version: 1.0.0
last_updated: 2026-05-09
description: |
  QD8 Observability & Reliability Lane — phat hien thieu sot logs/metrics/traces/alerts va reliability patterns (retry, circuit breaker, timeout, health check) qua probes P-QD8-xxx (7 probes lazy-load).

  TRIGGER: spawned boi /wf-fix-bugs orchestrator khi QD8 trong selected_dims. KHONG goi truc tiep.

argument-hint: "[--session-dir=PATH] [--profile=quick|standard|deep|exhaustive] [--use-cache] [--base-url=URL]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-observability: QD8 Observability & Reliability Lane

> **Shared Library:** `_shared/lane/_shared.md`, `_shared/lane/{pre-gate,post-gate}.md`, `_shared/lane/profile-resolver.md`, `_shared/lane/signal-emit.md`, `_shared/lane/templates/`.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Dimension** | QD8 — Observability & Reliability |
| **Muc dich** | Phat hien thieu sot logs/metrics/traces/alerts + reliability patterns (retry, circuit breaker, timeout, health check, graceful degradation) gay he thong khong quan sat duoc trong production |
| **Entry point** | Spawned boi `/wf-fix-bugs` orchestrator |
| **Owner Agent** | `sre`, `devops` |
| **Prerequisites** | `$SESSION_DIR` da tao, source code + (optional) base_url cho runtime probe |
| **Duration** | 2-15 min tuy profile |
| **Probes** | 7 (lazy-load) |
| **Cache Policy** | Static probes (log/metrics/retry/timeout/trace/alert): opt-in. Runtime (health-check): skip cache. |
| **Output** | `$SESSION_DIR/phase4-find-bugs/lanes/QD8-observability/{signals.json, lane-status.json, lane-report.md, phase-summary.md}` |

### Workflow Position

```
/wf-fix-bugs (orchestrator v10.x)
  → Spawn Lane QD8 (YOU ARE HERE) ─┐ CORE-025: parallel với other lanes
  → ... (other lanes parallel)    ─┘
  → Signal Bus aggregate
  → Triage → Fix Execute → Verify → Report
```

Next step: Orchestrator tiếp tục Signal Aggregation. Reliability CRITICAL → CDG escalate (vd: missing circuit breaker tren payment).

## Probe Routing Table (Lazy-Load)

| Probe ID | Loai | quick | standard | deep | exhaustive | Procedure file |
|----------|------|:-----:|:--------:|:----:|:----------:|----------------|
| P-QD8-retry-circuit-breaker | static | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD8-retry-circuit-breaker.md` |
| P-QD8-timeout-config-audit | static | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD8-timeout-config-audit.md` |
| P-QD8-log-coverage-audit | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD8-log-coverage-audit.md` |
| P-QD8-metrics-instrumentation | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD8-metrics-instrumentation.md` |
| P-QD8-health-check-probe | runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD8-health-check-probe.md` |
| P-QD8-trace-propagation | static | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD8-trace-propagation.md` |
| P-QD8-llm-analysis | llm | ❌ | ❌ | ✅ | ✅ | `prompts/llm-probe-qd8-observability.md` |
| P-QD8-alert-rule-audit | static | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD8-alert-rule-audit.md` |

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools được auto-detect, không hỏi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → IF `needs_scan` → call `mcp__serena__check_onboarding_performed` + `ListMcpResourcesTool` → `ci-detect.sh --write-cache '<json>'` → read cache → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Skip nếu non-git. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sánh HEAD vs index_commit. Freshness level → caveat trong probe context nếu stale. | Freshness status set |
| 0.Nc | **CI Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → 4 templates auto-select → inject vào probe execution context. | CI context ready |

### CI-ROUTE: Reliability Discovery (Protocol 20 §20.5)

> **Khi `$GITNEXUS_AVAILABLE == "true"` hoặc `$SERENA_AVAILABLE == "true"`:** PHẢI dùng GitNexus + Serena để trace external calls + retry boundaries. KHÔNG dùng Grep/Read thủ công khi CI tools available.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `understand_flow` | **GitNexus** `query("external HTTP, retry")` | Grep + Read | Trace external dependencies + retry boundaries |
| `find_references` | **Serena** `find_referencing_symbols` | Grep | Tìm tất cả nơi dùng logger / metricsClient / retryWrapper |
| `impact_analysis` | **GitNexus** `impact({target: <retry_util>, direction: "upstream"})` | Manual grep | Blast radius khi sua retry/circuit breaker config |

## Phase 1: PRE-GATE + SENSE

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | PRE-GATE forensic + verify external HTTP call patterns + resolve profile | lane skill | `lane-status.json` (in_progress) |
| 2 | Phase SENSE — chạy static probes (retry/timeout/log/metrics/trace/alert) | lane skill | `phase4-find-bugs/lanes/QD8-observability/raw/<probe>.json` |

## Phase 2: THINK + ACT + VERIFY

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 3 | Phase THINK — phan tich coverage gap (logs/metrics/retry) | lane skill | (in-memory) |
| 4 | Phase ACT — chạy runtime probe (health-check endpoint) | lane skill | http traces + signals |
| 5 | Phase VERIFY — validate evidence + reliability CDG flags | lane skill | merged `signals.json` |
| 6 | POST-GATE T1-T4 + reliability severity check | lane skill | `lane-report.md`, `phase-summary.md`, `lane-status.json=completed` |

## PRE-GATE

**Procedure:** `procedures/pre-gate.md`. Tóm tắt: 7 steps chuẩn + Step 8 detect external HTTP/RPC patterns + Step 9 verify --base-url cho runtime probe + Step 10 resolve probe list QD8.

## Execution: Sense → Think → Act → Verify

Lane chạy probes theo profile-resolver. Atomic emit qua `_shared/lane/signal-emit.md`. Reliability CRITICAL signals (missing CB tren payment, retry-without-idempotency) tự động đính kèm CDG-RELIABILITY-RISK flag.

## POST-GATE

**Procedure:** `procedures/post-gate.md` (T3 rules QD8: external-call evidence required, reliability-on-payment severity check, log-PII check).

## Severity Rules (QD8)

| Điều kiện | Severity | CDG Flag |
|-----------|----------|----------|
| Missing circuit breaker tren payment/auth/critical external dep | CRITICAL | CDG-RELIABILITY-RISK |
| Retry without idempotency on POST endpoint | CRITICAL | CDG-RELIABILITY-RISK |
| Health check endpoint khong ton tai trong production code | CRITICAL | — |
| External HTTP call khong cau hinh timeout (default infinite) | HIGH | — |
| Retry exponential backoff thieu jitter | HIGH | — |
| Health check return 200 khi DB/cache down | HIGH | — |
| Log thieu correlation_id/trace_id (loi de track) | MEDIUM | — |
| Metrics cardinality cao (user_id label) | MEDIUM | — |
| Trace context khong propagate giua services | MEDIUM | — |
| Log level sai (info cho event critical) | LOW | — |
| Naming convention metrics khong nhat quan | LOW | — |

## Fix Rules

| Severity | Action | Suggested Agent |
|----------|--------|-----------------|
| critical | escalate (CDG required cho reliability risk on payment, không auto-fix) | sre / devops |
| high | agent_fix (add timeout, fix retry pattern) | backend-developer / sre |
| medium | agent_fix (add structured log fields, normalize metrics) | developer |
| low | batch fix hoặc skip | developer |

## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/QD8-observability/`

| File | Required | Template | Mô tả |
|------|----------|----------|-------|
| `static-scan/signals.json` | yes | `_shared/lane/templates/signals.json` | Static probe signals với reliability evidence + CDG flags (signal-v2). |
| `runtime/signals.json` | yes | `_shared/lane/templates/signals.json` | Runtime probe signals (signal-v2). |
| `llm-scan/signals.json` | yes (nếu `--llm-scan`) | `_shared/lane/templates/signals.json` | LLM probe signals (signal-v2). |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` | Progress tracker. |
| `QD8-observability-report.md` | yes | `_shared/lane/templates/lane-report.md` | Findings by severity + reliability gaps. |
| `raw/` | optional | — | Per-probe raw outputs. |
| `evidence/` | optional | — | HTTP traces, health check responses. |

> `phase-summary.md` không còn được tạo — orchestrator tổng hợp vào `Phase4-report.md`.

Next step: `/wf-fix-bugs` Signal Aggregation Phase 1 step 1.2.

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E081 | PRE-GATE FAIL | STOP — ghi lane-status.failed |
| E082 | Probe execution timeout | Mark probe skipped, continue |
| E083 | Khong tim thay external HTTP call patterns | Skip P-QD8-retry-circuit-breaker, note "no_external_calls" |
| E084 | Logger framework khong detect duoc | Skip P-QD8-log-coverage-audit, note "no_logger" |
| E085 | Base URL khong set | Skip P-QD8-health-check-probe, note "no_base_url" |
| E086 | POST-GATE T3 FAIL (reliability-risk thieu CDG flag) | STOP — return failed (compliance violation) |
| E087 | Agent timeout (sre) | Skip probe, emit 0 signals |
| E088 | Metrics framework khong detect duoc | Skip P-QD8-metrics-instrumentation, note "no_metrics" |

## Registry Safe-Write

Lane KHÔNG ghi `req-registry.json`. Role: NONE.

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-fix-bugs` | Parent orchestrator |
| `/wf-fix-triage` | Downstream — escalate CDG-RELIABILITY-RISK signals |
| `/wf-fix-execute` | Downstream — respect CDG reject tokens |
| `/wf-fix-data` | Sibling lane QD6 (parallel — DB observability overlap) |
| `/wf-fix-performance` | Sibling lane QD4 (parallel — overlap latency/timeout) |
| `sre` agent | `.claude/agents/engineering/sre.md` |
| `devops` agent | `.claude/agents/engineering/devops.md` |

## References

- Quality Dimensions: `docs/design/skills/wf-fix-bugs/02-quality-dimensions.md` §QD8 (TBA)
- SRE Best Practices: Google SRE Book — https://sre.google/sre-book/
- Resilience Patterns: Hystrix / Polly / Resilience4j docs
- Core Rules: `.claude/rules/00-core.md` (CORE-006/007/011/012/023/025/026/027/028/030/031)
