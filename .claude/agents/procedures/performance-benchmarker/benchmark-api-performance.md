# Playbook: Benchmark hiệu năng API

> **Type**: Agent Skill Playbook
> **Agent**: performance-benchmarker
> **Triggered by**: API performance testing — trước production hoặc khi có performance regression
> **Output**: API Performance Benchmark Report

---

## Khi nào dùng playbook này

- Trước production deployment của API mới hoặc major changes
- Khi user/stakeholder báo cáo API chậm hoặc timeout
- Sau khi có infrastructure changes (scaling, migration)
- Khi `qa-lead` yêu cầu performance verification cho release gate
- Định kỳ quarterly cho critical APIs

---

## Procedure

### Bước 1: Xác định SLA targets và endpoints cần test

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3, PHASE2

READ: .claude/references/team-expert/testing/load-testing-examples.md
READ: .claude/references/team-expert/testing/performance-benchmarks.md

Xác định từ requirements/architecture docs:
□ SLA targets từng endpoint:
   p50 latency (median) — trải nghiệm người dùng "thường"
   p95 latency — trải nghiệm 95% users
   p99 latency — tail latency, ảnh hưởng đến 1% users nhưng quan trọng cho reliability
   Throughput (requests/second) — tải tối đa hệ thống chịu được
   Error rate — phải < 0.1% ở normal load, < 1% ở peak load

□ Nếu không có SLA được define trong requirements → dùng defaults:
   User-facing APIs: p95 < 200ms, p99 < 500ms
   Background/internal APIs: p95 < 1000ms
   Batch/report APIs: p95 < 5000ms (negotiate với stakeholders)

□ Phân loại endpoints theo criticality:
   CRITICAL: authentication, payment, core user journeys
   IMPORTANT: search, listing, dashboard
   NORMAL: settings, reporting, admin

□ Xác định REQ-IDs liên quan đến performance requirements
```

### Bước 2: Load test scenarios

```
READ: .claude/references/team-expert/testing/load-testing-examples.md (k6 examples)

Thiết kế 4 scenarios bắt buộc:

[Scenario 1: Baseline load — traffic bình thường]
Target: P95 latency phải đạt SLA
Cấu hình:
- VUs: expected concurrent users (từ analytics hoặc estimate)
- Duration: 10 phút (đủ lâu để warm up + measure steady state)
- Ramp up: 2 phút (không spike ngay từ đầu)
Pass criteria: error rate < 0.1%, p95 < SLA target

[Scenario 2: Peak load — giờ cao điểm]
Target: System có degraded gracefully không? P95 có tăng quá 2x SLA không?
Cấu hình:
- VUs: 3-5x baseline (spike ngắn hạn)
- Duration: 5 phút peak + 5 phút cooldown
Pass criteria: error rate < 1%, không có crash/restart, graceful degradation

[Scenario 3: Stress test — tìm breaking point]
Target: Xác định max throughput trước khi error rate > 5%
Cấu hình:
- VUs: tăng dần từ baseline đến system fail
- Duration: ramp up liên tục 20 phút
Output: breaking point (VUs + RPS tại thời điểm error rate > 5%)

[Scenario 4: Soak test — độ bền lâu dài]
Target: Phát hiện memory leaks, connection pool exhaustion, gradual degradation
Cấu hình:
- VUs: baseline load
- Duration: 1-4 giờ (tùy criticality — nếu không có time, minimum 30 phút)
Pass criteria: latency không tăng steady qua thời gian, memory usage ổn định
```

### Bước 3: Database query profiling

```
Bottleneck phổ biến nhất cho API latency là database. Phải profile trước khi optimize.

□ Enable query logging (không trên production — dùng staging với production-like data)
□ Xác định top 10 slowest queries trong test run
□ EXPLAIN/EXPLAIN ANALYZE cho mỗi slow query:
   - Sequential scan trên large table = thiếu index
   - Nested loop với large row count = N+1 problem
   - Sort without index = filesort
□ Verify indexes đã được tạo cho:
   - WHERE clause columns (đặc biệt foreign keys)
   - ORDER BY columns
   - JOIN ON columns
□ Xác định N+1 queries (dùng query count metric per request)
□ Connection pool utilization dưới load:
   - Pool size hợp lý chưa?
   - Có connection leak không? (connections tăng mà không giảm)
```

### Bước 4: Caching effectiveness

```
□ Cache hit rate — bao nhiêu % requests được serve từ cache?
   > 80% = good
   50-80% = acceptable
   < 50% = cần review cache strategy
□ Cache miss latency vs cache hit latency — gap có justify overhead không?
□ Cache invalidation có correct không? (stale data risk)
□ Cache stampede protection — thundering herd khi cache expires?
□ Cache memory usage ổn định không? (không grow unbounded)
□ TTL có phù hợp với data freshness requirements không?

Cho từng endpoint, ghi nhận:
ENDPOINT | CACHEABLE | CURRENT_HIT_RATE | TARGET_HIT_RATE | ACTION
```

### Bước 5: Connection pool tuning

```
Verify connection pool configuration cho databases và external services:

Database connection pool:
□ Min connections, max connections có phù hợp với load không?
   Rule of thumb: max_connections = (core_count * 2) + effective_spindle_count
□ Idle connection timeout có set không? (prevents stale connections)
□ Connection acquisition timeout — request fail fast hay wait lâu?
□ Pool exhaustion behavior — queue hay fail?

HTTP connection pool (cho external service calls):
□ Keep-alive được enable không? (tránh TCP handshake cho mỗi request)
□ Max connections per host có appropriate không?
□ Timeout configuration: connect timeout + read timeout + total timeout

Redis connection pool (nếu dùng):
□ Pool size adequate cho concurrent requests không?
□ Pipeline/pipelining được dùng cho batch operations không?
```

### Bước 6: Bottleneck identification

```
Sau khi có test results, phân tích bottleneck theo thứ tự:

Bước 6.1: Xác định bottleneck layer
□ Latency chủ yếu ở đâu? (dùng distributed tracing nếu có)
   - Database: > 50% total latency → database bottleneck
   - External API calls: check p95 latency của từng external call
   - Application logic: CPU-bound? Memory-bound?
   - Network: bandwidth? DNS resolution time?

Bước 6.2: Phân tích theo p95 breakdown
Ví dụ: API p95 = 800ms
   - Database queries: 600ms (75%) → optimize here first
   - External service call: 150ms (19%) → can we cache?
   - Application code: 50ms (6%) → not a bottleneck yet

Bước 6.3: Xác định quick wins vs. major refactors
Quick wins (< 1 ngày effort):
   - Add missing index
   - Enable query result caching
   - Fix N+1 query (use includes/eager loading)
   - Increase connection pool size
   - Enable HTTP keep-alive

Major refactors (cần planning):
   - Database schema redesign
   - Microservice decomposition
   - Data denormalization
   - Read replica setup
   - Message queue for async processing
```

### Bước 7: Before/after comparison

```
⚠️ KHÔNG báo cáo improvement mà không có before/after comparison.

Sau mỗi optimization:
□ Re-run CÙNG test scenario với CÙNG load profile
□ So sánh: p50, p95, p99 latency trước và sau
□ So sánh: throughput (RPS) trước và sau
□ So sánh: error rate trước và sau
□ Tính improvement %: (before - after) / before * 100%
□ Verify improvement sustained khi run 3+ times (loại trừ variance)

Ghi nhận:
OPTIMIZATION | BEFORE_P95 | AFTER_P95 | IMPROVEMENT% | EFFORT | ROI
```

### Bước 8: Output API Performance Benchmark Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/api-performance-benchmark.md

Cấu trúc output:
1. Performance Assessment: MEETS SLA / BELOW SLA / CRITICAL
2. SLA Targets vs. Actual Results (table: endpoint | p50 | p95 | p99 | throughput | SLA_target | status)
3. Load Test Results (4 scenarios với pass/fail)
4. Database Performance Findings
5. Cache Effectiveness Analysis
6. Bottleneck Analysis (với % contribution)
7. Optimization Recommendations (prioritized bằng ROI)
8. Before/After Comparison (nếu đã có optimizations)
9. REQ-IDs compliance check
10. Next Review Date (performance drift cần periodic check)
```

---

## Checklist trước khi submit

```
□ Tất cả 4 load test scenarios đã được chạy (baseline, peak, stress, soak)
□ Database query profiling đã được thực hiện (không chỉ dùng API metrics)
□ p95 và p99 được report — không chỉ average/median
□ Bottleneck đã được identify với % contribution (không chỉ nói "database chậm")
□ Optimization recommendations có ROI estimate
□ Before/after comparison có nếu optimizations đã được apply
□ REQ-IDs performance requirements được verify
□ Breaking point đã được xác định (biết system chịu được bao nhiêu load)
```
