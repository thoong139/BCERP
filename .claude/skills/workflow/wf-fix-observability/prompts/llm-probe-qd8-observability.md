# LLM Probe — QD8 Observability & Reliability (v2.0)

Vai tro: Senior SRE engineer + production reliability specialist. Phat hien thieu sot ve observability (logs, metrics, traces, alerts) va reliability patterns (retry, circuit breaker, timeout, graceful degradation, health check) ma static probes bo sot.

> **v2.0 (2026-05-11):** mo rong 18 → 25 categories. Them 7 categories: structured log format inconsistency, OTel SDK initialization, log sampling rate, dashboard/alert silent failure, graceful shutdown (SIGTERM/SIGINT), middleware observability gap, error response observability. Severity matrix cap nhat.

---

## 1. Tap trung phat hien

### 1.1 Reliability gaps

1. **Missing circuit breaker on critical external dependency**: Payment gateway, auth service, third-party API khong co circuit breaker → cascade failure khi dep down.
2. **Retry without idempotency on POST**: Retry tao duplicate side effect (charge double, order tao 2 lan).
3. **Retry exponential backoff thieu jitter**: Thundering herd khi nhieu client cung fail simultaneously.
4. **Timeout chua cau hinh**: External HTTP/DB call default infinite timeout → request hang chiem connection pool.
5. **Graceful degradation thieu**: Khi dep fail → cascade error 5xx thay vi fallback (cached/default response).
6. **Connection pool config sai**: Pool size qua nho cho concurrent load, max-life cau hinh sai → exhausted hoac long-lived connection cu.
7. **Graceful shutdown thieu (v2.0 moi)**: Process nhan SIGTERM/SIGINT → khong close connections, khong drain in-flight requests, khong flush logs → lost data + connection leak khi K8s restart pod. Pattern thieu: `process.on('SIGTERM', ...)`, `server.close()` + `setTimeout` force exit.

### 1.2 Observability gaps

8. **Critical operation thieu structured log**: Payment, auth, role change, delete khong duoc log → audit trail thieu, kho dieu tra.
9. **Log thieu correlation_id / trace_id**: Distributed system khong correlate request qua services.
10. **Log level dung sai**: INFO cho event quan trong nen WARN/ERROR, DEBUG cho event production cho.
11. **PII / sensitive data trong log**: password, JWT, credit card, CCCD → GDPR/compliance violation.
12. **Metrics thieu cho critical path**: Khong record histogram latency + counter request → khong monitor SLO.
13. **High-cardinality label**: `user_id`, `request_id` dung lam metric label → time-series explosion.
14. **Trace context khong propagate**: External HTTP / queue khong gan traceparent header → distributed trace bi gay.
15. **Alert rule khong cover golden signals**: Thieu alert cho latency, errors, saturation (Google SRE).
16. **Alert routing thieu**: Alert trigger nhung khong route den PagerDuty/Slack on-call channel.
17. **Structured log format inconsistency (v2.0 moi)**: Log output mix JSON + plain text trong cung stream → log aggregator parse fail → alert khong trigger. Pattern: `console.log` xen ke `logger.info(structured)`.
18. **OpenTelemetry SDK thieu hoac sai config (v2.0 moi)**: Khong co OTEL initialization, hoac exporter config sai (sai endpoint, thieu auth header), sampler config khong phu hop (always_on cho production → qua nhieu trace).
19. **Log sampling rate khong phu hop (v2.0 moi)**: DEBUG/TRACE log khong sampled → 50% log volume la noise. Hoac nguoc lai: sample ERROR log → lost critical signal. Pattern thieu: level-based sampling.

### 1.3 Health & Deployment Readiness

20. **Health check endpoint khong ton tai**: Production deploy (k8s, ECS) yeu cau /health → without → unhealthy pod khong replace.
21. **Health check false-positive (no deps status)**: Return 200 ngay ca khi DB/cache down → load balancer route traffic toi.
22. **Liveness vs readiness khong tach**: K8s best practice — liveness (process alive) tach roi readiness (ready to serve).
23. **Dashboard/alert silent failure (v2.0 moi)**: Grafana dashboard query sai, alert rule threshold vo ly nhung khong ai test → alert never fire. Pattern: metric name sai, unit mismatch, time range filter sai.
24. **Middleware observability gap (v2.0 moi)**: Auth middleware, rate-limit middleware, validation middleware thieu metric + log → khong biet co bao nhieu request bi reject, rate limit hit rate, auth fail pattern.
25. **Error response observability (v2.0 moi)**: 5xx error response khong log request context (body, headers, user) → kho debug. 4xx client error khong track pattern (co phai brute-force?) → miss attack.

---

## 2. Severity Calibration (QD8-specific)

| Pattern | Default severity | Bump khi |
|---------|------------------|----------|
| Missing CB on payment/auth | **critical** | Always (CDG-RELIABILITY-RISK) |
| Retry without idempotency on POST | **critical** | Always |
| Timeout chua config (external HTTP) | **high** | DB query → critical |
| Retry no jitter | **high** | Burst load → critical |
| Graceful degradation thieu | **medium** | Critical UX path → high |
| Pool size qua nho | **medium** | Production peak → high |
| Graceful shutdown thieu | **high** | K8s auto-restart → critical |
| Critical op thieu log | **medium** | Compliance-required (audit) → high |
| Log thieu correlation_id | **low** | Distributed system → medium |
| Log level sai | **low** | Production logs aggregated → medium |
| PII in logs | **high** | Production aggregate → critical |
| Metrics thieu cho critical path | **medium** | SRE workflow → high |
| High-cardinality label | **medium** | > 10k unique → high |
| Trace propagation thieu | **medium** | Multi-service architecture → high |
| Alert rule thieu golden signals | **medium** | Production deploy → high |
| Alert routing thieu | **medium** | On-call team exists → high |
| Log format inconsistency | **medium** | Aggregator pipeline → high |
| OTel SDK thieu/sai config | **high** | Distributed system → critical |
| Log sampling sai | **low** | Hide ERROR logs → critical |
| Health check 404 | **critical** | Always (deploy blocker) |
| Health false-healthy | **high** | Multi-region → critical |
| Liveness/readiness khong tach | **medium** | K8s deploy → high |
| Dashboard/alert silent fail | **medium** | Single alert source → high |
| Middleware unobservable | **medium** | Auth/rate-limit middleware → high |
| Error response unobservable | **high** | Production incident → critical |

> **CDG-RELIABILITY-RISK** flag tu dong gan khi: payment/auth + critical → POST-GATE T3.6 enforce.

---

## 3. KHONG focus (tranh duplicate)

- Retry/CB static patterns → static probe (P-QD8-retry-circuit-breaker)
- Timeout config static → static probe (P-QD8-timeout-config-audit)
- Log coverage static → static probe (P-QD8-log-coverage-audit)
- Metrics instrumentation static → static probe (P-QD8-metrics-instrumentation)
- Health check runtime → runtime probe (P-QD8-health-check-probe)

---

## 4. Negative Patterns — KHONG emit (QD8-specific)

> Bo sung cho `_shared.md` §5.

1. **Retry/CB thieu KHI** internal service-to-service trong cung cluster (low latency, monitored).
2. **Timeout thieu KHI** la CLI script chay 1 lan (offline, exit ngay).
3. **Log thieu KHI** la pure compute function (no side effect, audit khong yeu cau).
4. **Metrics thieu KHI** endpoint la admin tool truy cap rare (< 100 req/day).
5. **Trace propagation thieu KHI** monolith single-process (no downstream).
6. **Alert thieu KHI** project la library/SDK (no deployment).
7. **Health check thieu KHI** project la pure static site (no backend).
8. **Graceful shutdown thieu KHI** platform handle signal thay app (AWS Lambda, Cloudflare Workers — serverless runtime tu dong cleanup).
9. **OTel SDK thieu KHI** monolith single-service + metrics/logs collected qua agent (Prometheus, Fluentd sidecar).
10. **Log level inconsistency KHI** dung 2 logger khac nhau cho 2 purpose khac nhau (structured JSON cho ELK, plain text cho console dev) — acceptable neu split stream.
11. **Dashboard alert silent fail KHI** dashboard la optional, khong co on-call dependency.

---

## 5. CI Tools (uu tien khi available)

Khi co GitNexus/Serena, dung de nang confidence cho QD8:

- **External call boundary**: `mcp__plugin_gitnexus_gitnexus__query({query: "external HTTP, retry, circuit breaker"})` → trace external call sites + retry pattern proximity.
- **Logger reference count**: `mcp__serena__find_referencing_symbols({name_path: <logger>, relative_path})` → dem logger usage vs route count → coverage estimate.
- **Critical op blast radius**: `mcp__plugin_gitnexus_gitnexus__impact({target: <chargePayment>, direction: "upstream"})` → identify all callers, check log/metric instrumentation tai moi caller.
- **Trace propagation flow**: `mcp__plugin_gitnexus_gitnexus__query({query: "distributed trace, traceparent"})` → trace OTEL inject pipeline.
- **Health check endpoint**: `mcp__plugin_gitnexus_gitnexus__route_map()` → list all routes → confirm health check exists.
- **Middleware observability coverage**: `mcp__serena__find_referencing_symbols({name_path: <middleware_function>, relative_path})` → check log/metric call trong moi middleware.
- **SIGTERM handler**: `mcp__serena__find_referencing_symbols({name_path: "SIGTERM"})` → confirm graceful shutdown pattern.
- **OTel SDK init**: `mcp__serena__find_referencing_symbols({name_path: "NodeSDK" | "OpenTelemetrySdk", relative_path})` → confirm init + exporter config.

Populate `evidence.ci_citation` voi `serena_refs_count`, `gitnexus_flow`, `tools_used`.

---

## 6. Vi du

### 6.1 Positive — Missing circuit breaker on payment

```json
{
  "title": "Payment endpoint thieu circuit breaker → cascade failure khi Stripe cham",
  "description": "Trong charge.ts:24, axios.post('https://api.stripe.com/charges') khong wrap trong opossum/circuit breaker. Khi Stripe API latency tang > 5s → tat ca request tu app pile up → connection pool exhaust → 503 cho moi user. Thieu safety net cho external dep.",
  "severity": "critical",
  "fixability": "manual_fix",
  "domain": "backend",
  "req_ids": ["REQ-PAY-001"],
  "feat_ids": ["FEAT-PAYMENT-PROCESS"],
  "affected_modules": ["payment-service"],
  "location": {"file": "src/api/payments/charge.ts", "line": 24},
  "evidence": {
    "code_snippet": "const result = await axios.post('https://api.stripe.com/v1/charges', {\n  amount, currency, source\n}, { headers: { Authorization: `Bearer ${stripeKey}` } });\n// missing: opossum / resilience pattern wrapping",
    "reproduction_steps": "1. Mock Stripe API to 8s response time, 2. Send 100 concurrent /api/payments/charge, 3. Quan sat: pool exhaust sau 30s, 4. All subsequent requests get 503.",
    "confidence": 0.88,
    "ci_citation": {
      "gitnexus_impact_callers": 14,
      "tools_used": ["gitnexus_impact"]
    }
  },
  "remediation": {
    "suggested_action": "Wrap voi opossum (Node) / Polly (.NET) / Resilience4j (Java): const breaker = new CircuitBreaker(stripeCharge, { timeout: 5000, errorThresholdPercentage: 50, resetTimeout: 30000 }). Khi open → return cached 'service unavailable' response thay vi pile up.",
    "test_recommendation": "Chaos test: simulate Stripe down → assert circuit opens trong 5s + return graceful 503 (not pile up).",
    "references": ["https://github.com/nodeshift/opossum", "https://martinfowler.com/bliki/CircuitBreaker.html"],
    "estimated_effort_min": 180,
    "regression_risk": "high"
  }
}
```

### 6.2 Edge case — Graceful shutdown missing (v2.0)

```json
{
  "title": "Express server thieu graceful shutdown handler → mat in-flight requests khi K8s restart pod",
  "description": "Trong server.ts:88, `app.listen(3000)` khong co handler SIGTERM/SIGINT. Khi K8s rolling restart pod, container nhan SIGTERM → process exit ngay → cac request dang xu ly (payment processing, file upload) bi terminate giua chung → mat data + connection leak (DB pool khong close). Vi pham K8s pod lifecycle best practice.",
  "severity": "high",
  "fixability": "agent_fix",
  "domain": "backend",
  "req_ids": ["REQ-DEPLOY-001"],
  "feat_ids": ["FEAT-DEPLOYMENT"],
  "affected_modules": ["api-server"],
  "location": {"file": "src/server.ts", "line": 88},
  "evidence": {
    "code_snippet": "const server = app.listen(3000, () => {\n  console.log('Server running on port 3000');\n});\n// missing: process.on('SIGTERM', gracefulShutdown)",
    "reproduction_steps": "1. Start server, 2. Send 10 concurrent slow requests (5s processing), 3. Send SIGTERM signal, 4. Quan sat: process exit < 1s, 5. Check: 4/10 requests incomplete, DB connections leaked.",
    "confidence": 0.85,
    "environment": "K8s 1.29, Node.js 20"
  },
  "remediation": {
    "suggested_action": "Them graceful shutdown: const shutdown = () => { server.close(() => { db.disconnect(); process.exit(0); }); setTimeout(() => process.exit(1), 30000); }; process.on('SIGTERM', shutdown); process.on('SIGINT', shutdown);",
    "test_recommendation": "Integration test: send SIGTERM during request → assert (a) in-flight requests complete, (b) DB connections closed, (c) exit code 0.",
    "references": ["https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/"],
    "estimated_effort_min": 30,
    "regression_risk": "low"
  }
}
```

### 6.3 Edge case — OTEL SDK missing config (v2.0)

```json
{
  "title": "OpenTelemetry SDK khoi tao nhung exporter endpoint sai → traces khong den collector",
  "description": "Trong tracing.ts:12, OTel SDK init voi exporter endpoint `http://localhost:4318/v1/traces` (OTLP HTTP default). Nhưng production collector chay tren `otel-collector.monitoring.svc:4317` (gRPC). HTTP/gRPC mismatch + hostname sai → 100% traces silently dropped → khong co distributed trace trong production.",
  "severity": "high",
  "fixability": "agent_fix",
  "domain": "devops",
  "req_ids": ["REQ-OBSERV-TRACE"],
  "feat_ids": ["FEAT-OBSERVABILITY"],
  "affected_modules": ["tracing-infra"],
  "location": {"file": "src/infra/tracing.ts", "line": 12},
  "evidence": {
    "code_snippet": "const exporter = new OTLPTraceExporter({\n  url: 'http://localhost:4318/v1/traces',  // default, not production\n});\nconst sdk = new NodeSDK({ traceExporter: exporter });\nsdk.start();",
    "reproduction_steps": "1. Deploy app to production, 2. Check OTEL collector: 0 spans received in 10 min, 3. Check app log: no OTEL exporter error (gRPC connection fail but silent), 4. Check trace UI: empty.",
    "confidence": 0.9,
    "environment": "Production K8s cluster"
  },
  "remediation": {
    "suggested_action": "Config OTEL exporter tu env: url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces'. Validate exporter connection at startup: health check ping to collector endpoint before server.listen().",
    "test_recommendation": "Smoke test: app startup → assert exporter connected (ping collector). Health endpoint /health include trace_exporter status.",
    "references": ["https://opentelemetry.io/docs/languages/js/exporters/"],
    "estimated_effort_min": 45,
    "regression_risk": "medium"
  }
}
```

### 6.4 Counter-example — DO NOT emit

```typescript
// internal/admin/cleanup-script.ts (cron job once/week)
async function cleanupOldRecords() {
  const records = await db.records.findMany({ where: { createdAt: { lt: oneYearAgo } } });
  for (const r of records) {
    await db.records.delete({ where: { id: r.id } });  // no retry/CB
  }
}
// LLM TEMPTED: "Loop DB delete khong retry → reliability bug!" → SAI
```

**Ly do KHONG emit:**
- Cron script offline, run 1 lan/tuan, low concurrency.
- DB local cluster, no external dep.
- Retry/CB thua trong context nay → match negative pattern §1.

---

> **Tham chieu schema + rules chung**: Xem `_shared.md`.
