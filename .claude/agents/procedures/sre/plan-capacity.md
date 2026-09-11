# Playbook: Capacity Planning

> **Type**: Agent Skill Playbook
> **Agent**: sre
> **Triggered by**: Capacity planning cho service — thường trước khi scale up hoặc khi traffic growth dự báo > 50%
> **Output**: `.mc-data/docs/phase3-architecture/capacity-plan-[service-name].md`

---

## Khi nào dùng playbook này

- Khi traffic growth dự báo vượt 50% trong 3-6 tháng tới
- Trước major marketing events (sale, launch) cần scale trước
- Khi chi phí infrastructure tăng đột biến không giải thích được
- Quarterly capacity review theo lịch định kỳ
- Sau incidents liên quan đến resource exhaustion

---

## Procedure

### Bước 1: Current metrics baseline

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3
READ: sre-patterns.md (PromQL examples, Chaos Engineering game days)

Thu thập dữ liệu baseline 90 ngày gần nhất:
```

Metrics cần thu thập theo resource type:

```markdown
## CPU
- Average utilization: [X]%
- P95 peak utilization: [X]%
- Spike pattern: [daily/weekly/event-driven]

## Memory
- Average utilization: [X]% / [X] GB
- P95 peak: [X]%
- OOM events trong 90 ngày: [N]

## Network
- Ingress: [X] Mbps average, [X] Mbps peak
- Egress: [X] Mbps average, [X] Mbps peak

## Storage
- Current usage: [X] GB / [X] GB ([Y]%)
- Growth rate: [X] GB/tháng

## Application metrics
- RPS (Requests per second): avg [X], P95 [X], peak [X]
- Active connections: avg [X], max [X]
- Queue depth: avg [X], max [X]
- Database connections: avg [X], max [pool size]

## Cost baseline
- Infrastructure cost/tháng: [X] USD
- Cost per 1000 requests: [X] USD
```

**Quy tắc**: Không dùng current utilization làm baseline nếu < 30 ngày data. Cần ít nhất 2 tuần để thấy weekly patterns.

### Bước 2: Traffic growth models

Phân tích historical growth và project forward:

```markdown
## Historical Growth Analysis

| Giai đoạn | RPS trung bình | Growth % |
|-----------|---------------|---------|
| 90 ngày trước | [X] | baseline |
| 60 ngày trước | [X] | +[Y]% |
| 30 ngày trước | [X] | +[Y]% |
| Hiện tại | [X] | +[Y]% |

Monthly growth rate: [X]%
```

3 scenarios projection (12 tháng tới):

| Scenario | Assumption | Month 3 | Month 6 | Month 12 |
|----------|-----------|---------|---------|---------|
| Conservative | Growth rate giảm 50% | [X] RPS | [X] RPS | [X] RPS |
| Base | Growth rate giữ nguyên | [X] RPS | [X] RPS | [X] RPS |
| Optimistic | Growth rate tăng 50% | [X] RPS | [X] RPS | [X] RPS |

Ngoài organic growth, xét thêm:
```
□ Planned product launches trong roadmap
□ Marketing campaigns (Black Friday, launch events)
□ Geographic expansion
□ New integrations có thể tăng API traffic
```

### Bước 3: Resource utilization trends

Map traffic growth → resource consumption:

```markdown
## Resource Scaling Coefficients

Mỗi 2x tăng RPS → tăng bao nhiêu resource?

| Resource | Scaling factor | Linearity |
|----------|---------------|----------|
| CPU | 1.8x per 2x RPS | Sub-linear (caching effect) |
| Memory | 1.2x per 2x RPS | Near-constant (stateless) |
| DB connections | 1.9x per 2x RPS | Near-linear |
| Storage | [X] GB/tháng + [Y] GB per 1M requests | Cumulative |
| Network | 2x per 2x RPS | Linear |
```

Xác định bottleneck dự kiến:

```
Bottleneck analysis:
- Resource nào sẽ đạt 80% utilization đầu tiên: [resource]
- Dự kiến tại: [date/traffic level]
- Lead time cần để scale: [X ngày/tuần]
→ Action needed by: [date]
```

### Bước 4: Scaling strategies — horizontal/vertical/auto

Đánh giá options với trade-offs rõ ràng:

#### Horizontal scaling (scale out)

```markdown
**Khi phù hợp**: Stateless services, CPU/Network bound
**Trade-offs**:
- Ưu: Linear cost scaling, không downtime khi scale
- Nhược: Cần load balancer, state management phức tạp hơn, higher fixed overhead

**Capacity calculation**:
- Current: [N] instances × [spec]
- Target load: [X] RPS
- Per-instance capacity: [Y] RPS (P95, 80% utilization headroom)
- Instances needed: ceil([X] / [Y]) = [N_new]
```

#### Vertical scaling (scale up)

```markdown
**Khi phù hợp**: Memory-bound, database servers, không stateless
**Trade-offs**:
- Ưu: Đơn giản, không thay đổi architecture
- Nhược: Downtime khi resize, diminishing returns ở sizes lớn, higher single point of failure

**Options**:
| Tier | Spec | Cost/tháng | % improvement |
|------|------|-----------|--------------|
| Current | [current] | [X] USD | baseline |
| Next tier | [tier+1] | [Y] USD | [Z]% |
| 2 tiers up | [tier+2] | [Z] USD | [W]% |
```

#### Auto-scaling

```markdown
**Khi phù hợp**: Variable traffic với clear peaks, cost optimization
**Configuration**:
- Scale-out trigger: CPU > 70% trong 3 phút HOẶC RPS > [X]
- Scale-in trigger: CPU < 30% trong 15 phút
- Min instances: [N_min] (tránh cold start)
- Max instances: [N_max] (cost guard + test coverage)
- Scale-out cooldown: 3 phút
- Scale-in cooldown: 10 phút (tránh thrashing)

**Gotchas**:
- Đảm bảo DB connection pool đủ cho N_max instances
- Warm-up time của instances: [X giây]
- Không auto-scale DB xuống trong giờ business
```

### Bước 5: Cost optimization

Phân tích cost efficiency:

```markdown
## Cost Analysis

### Current cost breakdown
| Resource | Cost/tháng | % total |
|----------|-----------|---------|
| Compute | [X] USD | [Y]% |
| Database | [X] USD | [Y]% |
| Storage | [X] USD | [Y]% |
| Network | [X] USD | [Y]% |
| Total | [X] USD | 100% |

### Optimization opportunities

| Opportunity | Effort | Monthly saving | Risk |
|-------------|--------|----------------|------|
| Reserved instances (1yr) | Low | [X] USD ([Y]%) | Low |
| Spot instances cho batch jobs | Medium | [X] USD | Medium |
| Storage tiering (hot/warm/cold) | Medium | [X] USD | Low |
| Database right-sizing | Low | [X] USD | Low |
| CDN cho static assets | Low | [X] USD | Low |

### Cost per unit metrics
- Cost per 1000 requests hiện tại: [X] USD
- Industry benchmark: [Y] USD
- Target: [Z] USD (sau optimization)
```

Quy tắc: Không optimize cost nếu làm giảm reliability dưới SLO target.

### Bước 6: Reliability impact của capacity decisions

Mọi capacity decision phải được đánh giá qua lens reliability:

```markdown
## Reliability Impact Assessment

### Scaling headroom requirement
- SLO target: [X]%
- Error budget: [Y] phút/tháng
- Recommended headroom: 30-40% above peak (để absorb spikes)

### Single point of failure analysis
| Component | Current redundancy | Failure impact | Action needed |
|-----------|------------------|----------------|--------------|
| [db-primary] | 1 primary + 1 replica | 2-5 phút downtime | Add read replica |
| [cache] | Single node | Full degradation | Add replica/sentinel |
| [queue] | Clustered | Graceful degradation | OK |

### Traffic spike scenarios
Nếu traffic spike 3x trong 5 phút:
- Auto-scale trigger time: [X giây]
- Instances warm-up: [Y giây]
- Total new capacity available: [Z giây sau spike]
- Error budget impact trong window này: [W giây]

Kết luận: Spike 3x [acceptable/exceeds error budget]
```

### Bước 7: Capacity review schedule

```markdown
## Capacity Review Schedule

| Review type | Tần suất | Trigger | Output |
|-------------|---------|---------|--------|
| Regular review | Quarterly | Calendar | Updated capacity plan |
| Pre-event review | 4 tuần trước major events | Event calendar | Scale-up plan |
| Post-incident review | Sau resource-related incidents | Incident postmortem | Immediate actions |
| Growth threshold review | Khi actual growth > base scenario | Monitoring alert | Scenario update |

### Metrics để monitor giữa reviews
- Alert khi: CPU P95 > 70% trong 1 giờ bất kỳ
- Alert khi: DB connections > 80% pool trong 15 phút
- Alert khi: Storage > 70% capacity
- Monthly report: cost per unit so với benchmark
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase3-architecture/capacity-plan-[service-name].md

Cấu trúc output:
1. Executive Summary — current state, risks, recommendations
2. Current Metrics Baseline — 90 ngày data
3. Traffic Growth Models — 3 scenarios
4. Resource Utilization Trends — bottleneck analysis
5. Scaling Strategies — options với trade-offs
6. Cost Optimization — opportunities với savings
7. Reliability Impact — SLO compliance dưới scaling decisions
8. Action Plan — prioritized actions với timelines
9. Review Schedule — khi nào review lại
```

---

## Checklist trước khi submit

```
□ Baseline data ít nhất 90 ngày (30 ngày minimum)
□ 3 growth scenarios với assumptions rõ ràng
□ Bottleneck và thời điểm cần action được xác định
□ Auto-scaling config có min/max và cooldown periods
□ Cost analysis có current breakdown và optimization opportunities
□ Reliability impact không vi phạm SLO targets
□ Single point of failure assessment đầy đủ
□ Action plan có owner và deadline
□ Review schedule được xác định
```

---

## Lưu ý kỹ thuật

- **Headroom**: Luôn duy trì 30-40% headroom trên peak capacity
- **Thundering herd**: Test auto-scale behavior dưới sudden spike, không chỉ gradual growth
- **Database capacity**: DB scaling có lead time dài hơn compute — plan trước 2-4 tuần
- **Cost anomaly**: Setup cost anomaly alerts ngay từ đầu để phát hiện runaway spending
