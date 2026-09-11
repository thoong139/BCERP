# Procedure: Audit Observability

> **Owner agent:** `sre`
> **Use case:** Khi `sre` được spawn từ `/wf-fix-bugs` lane QD8 (Observability & Reliability)
> hoặc khi cần đánh giá độ quan sát (observability) của codebase trước go-live.

## Khi nào dùng

- QD8 lane probes: retry/circuit-breaker, timeout-config-audit, log-coverage-audit,
  metrics-instrumentation, health-check-probe, trace-propagation, alert-rule-audit
- Pre-deployment review cho payment / auth / order-processing flows
- Post-incident review: identify observability gaps đã làm chậm response

## Đầu vào

- `$SESSION_DIR/scope.json` — modules trong scope
- `req-registry.json` — REQ-IDs liên quan tới reliability requirements
- Source code: `src/`, `apps/`
- Existing observability config: `prometheus/`, `grafana/`, log config files

## Đầu ra

JSON array signals theo schema CORE-029:

```json
[{
  "type": "missing_circuit_breaker | missing_timeout | missing_health_check | inadequate_logging | missing_trace_propagation | missing_metric | missing_alert_rule",
  "description": "≥ 50 ký tự — mô tả gap + business impact",
  "file_path": "src/services/payment-gateway.ts",
  "line_range": [42, 58],
  "severity": "critical | high | medium | low",
  "evidence": "Code snippet hoặc config showing absence",
  "remediation_hint": "Suggest pattern (vd: 'wrap external call with cockatiel circuit breaker, threshold 5 failures/30s')"
}]
```

## Quy trình audit

### Bước 1 — Discovery

1. **Identify external dependencies:** Grep `fetch`, `axios`, `http.Client`, `db.query`,
   `redis.`, `kafka.`, message queue calls. Mỗi external call là candidate cho
   circuit breaker + timeout + retry policy.
2. **Identify entry points:** API routes, message consumers, scheduled jobs.
   Mỗi entry point cần health check + logging + tracing.
3. **Identify business-critical flows:** payment, auth, order, billing.
   Apply stricter standard (CDG-RELIABILITY-RISK).

### Bước 2 — Pattern checks (per finding type)

#### Circuit Breaker / Retry
- External HTTP/DB call WITHOUT retry-with-backoff → MEDIUM
- Payment/auth call WITHOUT circuit breaker → CRITICAL (CDG-RELIABILITY-RISK)
- Retry without max-attempts cap → HIGH (infinite retry risk)

#### Timeout Configuration
- HTTP client KHÔNG set explicit timeout → HIGH
- DB query không có statement_timeout → MEDIUM
- Default timeout > 30s cho user-facing path → HIGH

#### Health Checks
- Service không expose `/health` hoặc `/healthz` → HIGH
- Health endpoint chỉ return `200` mà không check downstream → MEDIUM (shallow health)
- Health endpoint check toàn bộ downstream sync → MEDIUM (cascading failure)

#### Logging Coverage
- Critical operation (payment, auth) không có structured log entry/exit → HIGH
- Log có chứa PII (password, JWT, credit card) → CRITICAL
- Error path không log với context (correlation ID) → MEDIUM

#### Metrics Instrumentation
- Payment/order endpoint không có request_count + latency_histogram → HIGH
- Background job không có job_duration metric → MEDIUM
- Custom business metric thiếu (vd: orders_per_minute) → LOW

#### Trace Propagation
- HTTP header forwarding (`traceparent`, `x-correlation-id`) thiếu → HIGH
- Async job không inherit parent trace context → MEDIUM

#### Alert Rules
- Critical metric (error_rate, p99_latency) không có alert → HIGH
- Alert threshold quá nhạy (5xx > 0 trong 1 phút) → LOW (noise)
- Alert không có runbook link → LOW

### Bước 3 — Severity assignment

| Tình huống | Severity |
|---|---|
| Payment/auth missing CB → cascade failure khả năng cao | CRITICAL |
| External call missing timeout → resource exhaustion | HIGH |
| Service missing health check → ko detect được lỗi | HIGH |
| PII trong log → compliance violation | CRITICAL |
| Missing custom business metric | LOW |

### Bước 4 — Cross-reference với SLO/SLI

Nếu project có `slo-targets.yaml` hoặc tương đương:
- Verify mỗi SLI có metric tương ứng được instrument
- Flag gap: SLI defined nhưng metric thiếu → HIGH

## CDG flag

Khi finding nằm trong payment / auth / order:
- Set `cdg_flags: ["CDG-RELIABILITY-RISK"]` để orchestrator escalate
  Critical Decision Gate trước khi mark fixed.

## Anti-patterns to ignore

- KHÔNG flag missing health check trên CLI tool (không phải service)
- KHÔNG flag missing CB trên local-only call (cùng process)
- KHÔNG flag missing trace propagation khi project chưa có distributed tracing setup
  (suggest setup trong remediation_hint thay vì critical finding)

## Output validation (CORE-029)

- Mỗi signal phải có `description` ≥ 50 ký tự, `evidence` non-empty
- `severity` chỉ được là `critical|high|medium|low`
- `file_path` + `line_range` phải resolve về file thực sự
