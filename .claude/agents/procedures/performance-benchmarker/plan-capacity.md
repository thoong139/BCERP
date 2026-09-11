# Playbook: Lập kế hoạch dung lượng hệ thống

> **Type**: Agent Skill Playbook
> **Agent**: performance-benchmarker
> **Triggered by**: Capacity planning cho expected traffic growth
> **Output**: Capacity Planning Document

---

## Khi nào dùng playbook này

- Trước launch với expected traffic surge
- Khi business báo cáo traffic dự kiến tăng đáng kể (marketing campaign, seasonal peak)
- Quarterly capacity review
- Khi `devops` hoặc `sre` cần infrastructure sizing guidance
- Sau khi có benchmark data từ `benchmark-api-performance.md`

---

## Procedure

### Bước 1: Đọc baseline metrics hiện tại

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3, PHASE6

READ: .claude/references/team-expert/testing/load-testing-examples.md
READ: .claude/references/team-expert/testing/performance-benchmarks.md

Thu thập metrics baseline (từ production monitoring hoặc benchmark tests):
□ Current peak RPS (requests per second)
□ Average concurrent users
□ p95/p99 latency tại current load
□ CPU utilization tại current load (bao nhiêu % CPU đang dùng?)
□ Memory utilization (RSS, heap usage)
□ Database: queries/second, connections active, storage size
□ Cache: hit rate, memory usage
□ Network: bandwidth in/out

Nếu không có production data (pre-launch):
□ Dùng results từ load tests (benchmark-api-performance.md)
□ Estimate từ comparable products/competitors nếu có
```

### Bước 2: Traffic growth projections

```
Cần 3 scenarios: Conservative / Expected / Aggressive

Thu thập inputs từ business:
□ Current MAU/DAU (hoặc target nếu pre-launch)
□ Expected growth rate (% per month/quarter)
□ Seasonal patterns (peak months, holiday spikes)
□ Planned marketing campaigns (có thể tạo sudden spikes)
□ Geographic expansion plans
□ New features sẽ tăng engagement

Tính projected load:

Scenario CONSERVATIVE (base case):
  Traffic = current * (1 + conservative_growth_rate)^months
  Ví dụ: current 100 RPS, growth 20%/tháng → 6 tháng = 299 RPS

Scenario EXPECTED (most likely):
  Traffic = current * (1 + expected_growth_rate)^months

Scenario AGGRESSIVE (best case / worst case for infra):
  Traffic = current * (1 + aggressive_growth_rate)^months + spike_factor
  Spike factor: marketing campaign có thể tạo 5-10x spike ngắn hạn

Timeline: 3 tháng, 6 tháng, 12 tháng

⚠️ p95/p99 latency phải maintain ở SLA dù ở scenario Aggressive
```

### Bước 3: Resource utilization analysis

```
Với mỗi component (application servers, databases, cache, queues):

Application servers:
□ Tại current load: CPU = X%, Memory = Y%
□ Giới hạn performance bắt đầu khi CPU > 70% (rule of thumb)
□ Giới hạn trước khi cần scale: CPU > 70% hoặc Memory > 80%
□ Số instances hiện tại là bao nhiêu?
□ Cost per instance/month?

Database:
□ Tại current load: connections = X/max_pool, CPU = Y%, IOPS = Z
□ Read vs. write ratio là bao nhiêu?
□ Storage growth rate (GB/month)
□ Khi nào cần read replica? (read > 60% total queries)
□ Khi nào cần sharding? (single instance không đủ write throughput)

Cache:
□ Hit rate hiện tại
□ Memory usage / max memory
□ Eviction rate (nếu cao → cần tăng memory hoặc optimize TTL)

Infrastructure tổng:
□ Monthly cost hiện tại
□ Cost per concurrent user hoặc cost per 1000 requests
```

### Bước 4: Scaling thresholds

```
Xác định khi nào trigger scaling — PHẢI có triggers rõ ràng, không scale manual:

Auto-scaling triggers (horizontal scale-out):
□ CPU > 70% sustained 5 phút → add 1 instance
□ Memory > 80% sustained 5 phút → add 1 instance
□ Request queue depth > 100 → add 1 instance
□ p95 latency > SLA × 1.5 → add 1 instance

Scale-in triggers (save cost):
□ CPU < 30% sustained 15 phút → remove 1 instance
□ Minimum instances: đủ để handle traffic nếu 1 instance fail

Database scaling triggers:
□ Connections > 80% pool → tăng pool size hoặc add read replica
□ CPU > 70% → analyze queries first, then vertical scale
□ IOPS > 80% → vertical scale storage hoặc optimize queries

Cache scaling triggers:
□ Hit rate < 70% → review cache strategy
□ Memory > 80% → tăng memory hoặc review eviction policy
□ Eviction rate tăng → tăng memory
```

### Bước 5: Cost projections

```
Tính cost tại từng traffic scenario:

Infrastructure cost formula:
□ Application: số instances × cost/instance × uptime
□ Database: instance type + storage + I/O + backup
□ Cache: instance type × uptime
□ CDN: bandwidth cost + request count
□ Load balancer
□ Monitoring/observability tools
□ Data transfer costs (egress)

Tạo bảng cost projection:
SCENARIO | 3 MONTHS | 6 MONTHS | 12 MONTHS | COST/USER | COST/1K_REQ

Cost optimization opportunities:
□ Reserved instances (1yr hoặc 3yr) — tiết kiệm 30-60% so với on-demand
□ Spot instances cho non-critical workloads (batch jobs, queue workers)
□ Auto-scaling xuống ngoài giờ (nếu traffic pattern predictable)
□ CDN caching để giảm origin requests
□ Database query caching để giảm read replicas cần thiết

⚠️ Cost tăng tuyến tính vs. traffic? Nếu có — optimize cache và database trước khi scale infrastructure
```

### Bước 6: Infrastructure recommendations

```
Dựa trên analysis từ bước 1-5, đưa ra recommendations:

Short-term (3 tháng):
□ Changes cần làm ngay để handle expected traffic
□ Không cần infrastructure changes — current capacity đủ
□ Tăng auto-scaling upper limit (hiện tại bị cap quá thấp)

Medium-term (3-6 tháng):
□ Database: khi nào cần add read replica? (date estimate)
□ Caching: tăng cache size từ khi nào?
□ Application: cần refactor gì để scale tốt hơn? (N+1 queries, sync → async)

Long-term (6-12 tháng):
□ Architecture decisions: cần microservices không? (hiện tại monolith đủ chưa?)
□ Database sharding khi nào cần? (metrics trigger)
□ Multi-region khi nào cần? (latency hoặc availability requirements)

Format mỗi recommendation:
RECOMMENDATION | TRIGGER_METRIC | TIMELINE | EFFORT | COST_IMPACT | RISK_IF_DELAYED
```

### Bước 7: Output Capacity Planning Document

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/capacity-planning.md

Cấu trúc output:
1. Executive Summary (1 trang: current state, growth projection, key recommendations)
2. Current Baseline (metrics table)
3. Traffic Growth Projections (3 scenarios × 3 timeframes)
4. Resource Utilization Forecast (per component per scenario)
5. Scaling Architecture (thresholds và triggers)
6. Cost Projections (table + cost per user)
7. Infrastructure Recommendations (prioritized)
8. Risk Assessment (nếu không implement recommendations)
9. Review Schedule (khi nào review lại capacity plan)
```

---

## Checklist trước khi submit

```
□ Baseline metrics có từ actual data (không estimate nếu có thể)
□ Cả 3 scenarios (conservative/expected/aggressive) đã được tính
□ p95/p99 latency được project, không chỉ throughput
□ Cost projections bao gồm cả infrastructure lẫn operational costs
□ Scaling triggers có ngưỡng cụ thể (không chỉ "khi cần thì scale")
□ Recommendations có timeline và trigger metrics
□ Risk assessment cho "nếu không làm gì" đã được articulate
□ Review schedule đã được đề xuất
```
