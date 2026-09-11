# Playbook: Kiểm thử Tải API (Load Testing)

> **Type**: Agent Skill Playbook
> **Agent**: api-tester
> **Triggered by**: Pre-deployment performance testing, SLA validation
> **Output**: API Load Test Report tại path do skill cung cấp

---

## Khi nào dùng playbook này

- Trước khi deploy lên production lần đầu
- Khi có thay đổi lớn về architecture hoặc database schema
- Khi SLA yêu cầu cụ thể cần được validate
- Định kỳ (hàng quý) để phát hiện performance regression

---

## Procedure

### Bước 1: Xác định Load Scenarios và SLA Targets

```
INPUT: Performance requirements từ paths do skill cung cấp
FALLBACK: tra .claude/references/path-registry.md → PHASE3, PHASE2

Thu thập SLA requirements:
□ Response time targets: P50, P95, P99 (ms)
□ Throughput targets: requests/second
□ Error rate threshold: < X% dưới tải bình thường
□ Concurrent user targets
□ Uptime SLA: 99.9% / 99.99%?

Nếu SLA không được spec rõ, dùng defaults:
  P50 < 200ms, P95 < 500ms, P99 < 1000ms
  Error rate < 1% dưới normal load
  Error rate < 5% dưới peak load

READ: .claude/references/team-expert/testing/load-testing-examples.md
READ: .claude/references/team-expert/testing/api-testing-patterns.md

Xác định critical endpoints để test:
□ High-traffic endpoints (homepage, product list, search)
□ Write-heavy endpoints (create order, update inventory)
□ Computationally expensive endpoints (report generation, analytics)
□ Authentication endpoints (login, token refresh)
```

### Bước 2: Định nghĩa Load Scenarios

```
3 scenarios bắt buộc:

SCENARIO 1 — Normal Load (Baseline):
□ Mức tải thường ngày theo estimate (hoặc production metrics)
□ Mục tiêu: verify SLA được đáp ứng trong điều kiện bình thường
□ Duration: 10 phút
□ Concurrent users: [N] (theo estimate)
□ Think time: 1-3 giây giữa requests (realistic user behavior)

SCENARIO 2 — Peak Load:
□ Gấp 3-5x normal load (sales event, campaign launch, ...)
□ Mục tiêu: verify hệ thống chịu được peak traffic không bị crash
□ Duration: 5 phút
□ Error rate threshold: < 5%
□ Graceful degradation: chậm lại OK, nhưng không 500

SCENARIO 3 — Stress Test:
□ Tăng dần đến breaking point để biết giới hạn
□ Mục tiêu: xác định điểm saturation, không phải vượt qua
□ Ramp-up: 10 users → 20 → 50 → 100 → 200 → ... mỗi 2 phút
□ Dừng khi error rate > 20% hoặc P99 > 5000ms

SCENARIO 4 — Soak Test (optional, nếu cần):
□ Normal load trong thời gian dài (1-4 giờ)
□ Mục tiêu: phát hiện memory leaks, connection pool exhaustion
□ Monitor: memory usage tăng dần không? GC pauses?
```

### Bước 3: Ramp-up Strategy

```
Tránh cold-start bias — luôn warm-up trước khi measure:

Warm-up phase (2 phút):
→ 10% target load
→ Để JIT/JVM/cache warm up
→ Kết quả phase này không tính vào metrics

Ramp-up phase (3 phút):
→ 10% → 25% → 50% → 75% → 100% target load
→ Quan sát errors và latency tăng

Sustained phase (10 phút):
→ 100% target load
→ Đây là phase chính để lấy metrics

Cool-down phase (2 phút):
→ 100% → 0%
→ Quan sát recovery time

Ghi lại:
□ Time-to-first-error dưới tải cao?
□ Latency curve có ổn định không (flat) hay tăng dần (memory leak)?
□ Error rate có tăng theo thời gian không?
```

### Bước 4: SLA Thresholds Definition

```
Thiết lập quality gates cụ thể trước khi chạy test:

Response Time SLAs (theo endpoint priority):
  Critical endpoints (auth, checkout, payment):
    P50: < 100ms
    P95: < 300ms
    P99: < 500ms

  Standard endpoints (list, get, update):
    P50: < 200ms
    P95: < 500ms
    P99: < 1000ms

  Heavy endpoints (report, analytics, export):
    P50: < 1000ms
    P95: < 3000ms
    P99: < 5000ms (có thể async)

Error Rate SLAs:
  Normal load: < 0.1% (1 trong 1000 requests)
  Peak load: < 1%
  Stress test: < 20% (point of saturation)

Throughput SLAs:
  Minimum throughput: [X] RPS tại P95 < 500ms

AUTO-FAIL conditions (test fails ngay nếu hit):
  → Error rate > 5% trong normal load scenario
  → P99 > 5000ms trong normal load scenario
  → Any 500 error trên critical endpoints
```

### Bước 5: Concurrent User Targets

```
Xác định realistic concurrency dựa trên:

Method 1: Little's Law
  L = λ × W
  L = concurrent users, λ = request rate (RPS), W = average response time (s)
  Ví dụ: 100 RPS × 0.2s = 20 concurrent users

Method 2: Business estimate
  DAU (Daily Active Users) × peak hour factor × average session requests
  Ví dụ: 10,000 DAU × 0.1 peak factor × 5 requests = 5,000 requests/peak hour = ~1.4 RPS

Method 3: Production baseline (nếu có)
  Lấy từ APM/monitoring tool

Sau khi xác định:
□ Normal concurrent: [N] users
□ Peak concurrent: [N × 3] users
□ Stress test max: tăng đến khi hệ thống fail

Realistic user simulation (không chỉ flood):
□ Think time 1-3s giữa requests
□ Mix of endpoints theo usage pattern (80/20: 80% reads, 20% writes)
□ Test data đa dạng (không phải cùng 1 user_id)
```

### Bước 6: Bottleneck Identification

```
Trong và sau khi chạy load test, monitor các tầng:

Application Layer:
□ CPU usage: > 80% sustained → CPU-bound
□ Memory usage: tăng dần không release → memory leak
□ Thread pool saturation → tăng pool size hoặc optimize
□ GC pauses: > 500ms → tuning cần thiết
□ Slow queries log: queries > 1s

Database Layer:
□ Query execution time tăng khi load tăng → index missing hoặc N+1
□ Connection pool exhaustion → "too many connections" error
□ Lock waits và deadlocks
□ Buffer pool hit rate: < 95% → cần RAM hoặc optimize queries
□ Replication lag (nếu có read replicas)

Network/Infrastructure:
□ Network I/O saturation?
□ Load balancer connection limits?
□ Upstream service rate limits hit?
□ CDN/cache hit rate cho static assets?

Cách đọc kết quả:
  Latency tăng đột ngột tại [N] concurrent → đây là saturation point
  Error rate tăng trước latency → exhausted queue
  Memory tăng đều không release → memory leak
  CPU spike periodic → GC pressure
```

### Bước 7: Database Connection Pool Behavior

```
Test đặc biệt cho database connection pool:

Pool size testing:
□ Mặc định pool size là bao nhiêu?
□ Peak concurrent connections thực tế dưới tải cao?
□ Khi pool exhausted: queue hay reject ngay?
□ Queue timeout là bao lâu? (không để mãi mãi)
□ Connection acquisition time < 50ms?

Stress pool:
□ Đặt pool size nhỏ hơn concurrent users → observe behavior
□ "Connection timeout" error xuất hiện ở đâu?
□ Application có retry logic khi pool exhausted không?

Long-running queries:
□ Slow queries hold connection quá lâu?
□ Query timeout được set không?
□ Idle connection cleanup (connection TTL)?

Khuyến nghị pool size:
  pool_size = (concurrent_users × avg_queries_per_request) / avg_query_time_ms × 1000
  Ví dụ: 50 users × 2 queries × 1000ms / 50ms = 50 connections
  Thêm 20% buffer → pool_size = 60
```

### Bước 8: Memory Leak Detection

```
Chạy soak test (1-2 giờ với normal load):

Monitor memory:
□ JVM heap / Node.js RSS / Python RSS theo thời gian
□ Memory sau warm-up → ghi baseline
□ Memory sau 30 phút, 60 phút, 120 phút → có tăng đều không?

Dấu hiệu memory leak:
□ Memory tăng liên tục, không có GC releases
□ GC chạy ngày càng thường xuyên hơn
□ Response time tăng dần theo thời gian (GC pressure)
□ OOMKilled trong Kubernetes logs

Phân tích:
□ Heap dump trước/sau load để so sánh object counts
□ Event listener leaks (Node.js)?
□ Unclosed streams, connections?
□ Cache không có eviction policy?
□ Large objects being accumulated?

Auto-pass nếu: memory growth < 5% sau 1 giờ
Auto-fail nếu: memory growth > 20% sau 1 giờ (linear growth pattern)
```

### Bước 9: So sánh Results vs SLA

```
Tổng hợp kết quả và so sánh với SLA đã định nghĩa (Bước 4):

Với mỗi endpoint tested:
  P50_actual vs P50_SLA → PASS / FAIL
  P95_actual vs P95_SLA → PASS / FAIL
  P99_actual vs P99_SLA → PASS / FAIL
  error_rate_actual vs error_rate_SLA → PASS / FAIL

Overall Go/No-Go:
  → GO: Mọi critical endpoints PASS tất cả SLA thresholds
  → NO-GO: Bất kỳ critical endpoint nào FAIL SLA
  → CONDITIONAL GO: Non-critical endpoint FAIL nhưng có mitigation plan

Xác định capacity limits:
  → Tại [N] concurrent users: P95 bắt đầu vượt SLA
  → Maximum throughput trước khi degrade: [X] RPS
  → Estimated user capacity: [N] concurrent users
```

---

## Format Output: API Load Test Report

```markdown
## API Load Test Report

**Agent**: api-tester
**Ngày test**: [date]
**Environment**: [staging / production]
**Tool**: [k6 / Locust / JMeter / Artillery]
**Kết luận**: [GO / NO-GO / CONDITIONAL GO]

---

### SLA Summary

| Endpoint | Scenario | P50 (ms) | P95 (ms) | P99 (ms) | Error % | SLA |
|----------|----------|----------|----------|----------|---------|-----|
| GET /products | Normal | 85 | 210 | 450 | 0.02% | PASS |
| POST /orders | Normal | 145 | 480 | 980 | 0.05% | PASS |
| GET /products | Peak | 120 | 650 | 2100 | 0.8% | FAIL |
| ... | | | | | | |

---

### Load Scenarios Results

#### Scenario 1: Normal Load ([N] concurrent users)
- Duration: 10 phút
- Peak RPS achieved: [X]
- P95 overall: [X]ms
- Error rate: [X]%
- **Verdict**: PASS / FAIL

#### Scenario 2: Peak Load ([N×3] concurrent users)
- Duration: 5 phút
- P95 overall: [X]ms
- Error rate: [X]%
- **Verdict**: PASS / FAIL

#### Scenario 3: Stress Test (ramp đến breaking point)
- Saturation point: [N] concurrent users
- Max RPS: [X]
- Breaking point: [N] concurrent (error rate > 20%)
- **Verdict**: Informational

---

### Bottlenecks Identified

| Layer | Vấn đề | Tại tải [N] users | Severity |
|-------|--------|------------------|---------|
| Database | N+1 queries tại GET /orders | 50+ concurrent | High |
| App | Memory tăng 15% sau 1h | Mọi tải | Medium |

---

### Database Connection Pool
- Pool size hiện tại: [N]
- Peak connections used: [N] ([X]% utilization)
- Connection wait time P95: [X]ms
- Pool exhaustion events: [N]

### Memory Analysis (Soak Test)
- Baseline memory: [X]MB
- Memory sau 1 giờ: [X]MB ([+X]% growth)
- **Verdict**: [Stable / Potential leak]

---

### Capacity Planning
- Comfortable operating capacity: [N] concurrent users
- Maximum before SLA breach: [N] concurrent users
- Recommended scaling trigger: [N] concurrent users ([X]% of max)

---

### Go/No-Go Recommendation
**[GO / NO-GO / CONDITIONAL GO]**

Lý do: [...]

Action items (nếu NO-GO hoặc CONDITIONAL):
1. [Fix N+1 query tại /orders endpoint — estimated 2h]
2. [Investigate memory growth — estimated 4h]
```

---

## Checklist trước khi submit

```
□ SLA thresholds được xác định rõ trước khi test (không định nghĩa sau khi có kết quả)
□ Warm-up phase được thực hiện (kết quả cold start không tính)
□ 3 scenarios: normal, peak, stress
□ Bottlenecks được identify và document
□ Database connection pool behavior được test
□ Memory leak check (soak test hoặc ít nhất 30 phút)
□ So sánh với SLA: PASS/FAIL rõ ràng
□ Go/No-Go recommendation với lý do cụ thể
□ REQ-ID được reference trong report
```
