# Playbook: Thiết kế SLO/SLI

> **Type**: Agent Skill Playbook
> **Agent**: sre
> **Triggered by**: Phase 3 (Architecture) hoặc pre-deployment khi cần thiết kế reliability targets
> **Output**: `.mc-data/docs/phase3-architecture/slo-sli-definitions.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design` khi service cần SLO/SLI definitions
- Khi cần xác định reliability targets trước khi production deployment
- Khi stakeholders yêu cầu SLA commitments và cần basis kỹ thuật để justify
- Khi thiết lập observability stack cho hệ thống mới

---

## Procedure

### Bước 1: Đọc service requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (architecture), PHASE2 (functional requirements)
READ: sre-patterns.md (SLO YAML templates, PromQL examples)

Cần xác định:
□ Các user journeys quan trọng nhất (critical path)
□ Dependency graph: upstream/downstream services
□ Current baseline metrics nếu đã có (production data)
□ Business impact của downtime (revenue loss, SLA penalty)
□ Deployment frequency (ảnh hưởng error budget policy)
```

### Bước 2: User journey mapping

Với mỗi user journey quan trọng, document:

```markdown
Journey: [Tên - ví dụ: "Checkout flow"]
- Bắt đầu: [Action của user]
- Kết thúc: [Success state]
- Services liên quan: [list services]
- Business impact nếu fail: [revenue/reputation/compliance]
- Acceptable downtime: [xét từ góc độ user]
```

Ưu tiên journeys theo tiêu chí:
1. Trực tiếp sinh revenue
2. Ảnh hưởng toàn bộ users
3. Có compliance/regulatory requirement

### Bước 3: SLI selection

Với mỗi user journey, chọn SLI phù hợp:

| Loại service | SLI ưu tiên | Không dùng |
|-------------|-------------|-----------|
| API / Web service | Availability, Latency (P95/P99) | CPU usage |
| Data pipeline | Freshness, Correctness | Throughput thô |
| Batch job | Completion rate, Duration | Memory usage |
| Queue consumer | Processing latency, Error rate | Queue depth thô |

Định nghĩa SLI measurement rõ ràng:

```yaml
# Ví dụ format SLI definition
sli:
  name: checkout-api-availability
  description: Tỷ lệ requests checkout thành công (HTTP 2xx/3xx)
  measurement:
    numerator: "count(http_requests{job='checkout-api', status=~'2..|3..'} [window])"
    denominator: "count(http_requests{job='checkout-api'} [window])"
  excludes:
    - "Requests từ health checks"
    - "Requests trong maintenance window đã thông báo"
```

**Lưu ý quan trọng**: SLI phải phản ánh trải nghiệm user, không phải trạng thái infrastructure. CPU 90% không phải SLI — error rate 2% mới là SLI.

### Bước 4: SLO target setting — phân tích trade-offs

Đánh giá 3 mức target phổ biến:

| SLO Level | Downtime/tháng | Error budget/tháng | Phù hợp khi |
|-----------|----------------|-------------------|------------|
| 99.0% | ~7.2 giờ | 7.2 giờ | Internal tools, dev/staging |
| 99.5% | ~3.6 giờ | 3.6 giờ | Internal tools quan trọng |
| 99.9% | ~43 phút | 43 phút | Production services thông thường |
| 99.95% | ~22 phút | 22 phút | Financial, healthcare workloads |
| 99.99% | ~4.3 phút | 4.3 phút | Payment critical path |

Trade-off cần document cho mỗi SLO target:
```
Lý do chọn [X]%:
- Baseline hiện tại: [current reliability]
- Cost to improve vs reliability gain: [phân tích]
- User expectation: [SLA đã cam kết hay kỳ vọng ngầm]
- Operational overhead: [alerts, toil, on-call burden]
```

Quy tắc: KHÔNG đặt SLO cao hơn khả năng đo được. Nếu monitoring chỉ granular 1 phút, SLO 99.99% không có ý nghĩa.

### Bước 5: Error budget calculation

Tính error budget cho mỗi SLO:

```
Error Budget = (1 - SLO target) × rolling window duration

Ví dụ:
- SLO 99.9% trên 30 ngày = 0.1% × 43,200 phút = 43.2 phút
- SLO 99.9% trên 30 ngày = 0.1% × 2,592,000 giây = 2,592 giây

Error Budget Policy:
- 0-25% consumed: Deploy freely, feature work normal
- 25-75% consumed: Caution, prefer smaller deploys
- 75-99% consumed: Feature freeze, reliability work only
- 100% consumed: No deployments (trừ hotfix với approval)
```

Document burn rate thresholds:

```yaml
burn_rate_policy:
  fast_burn:
    threshold: "5% error budget consumed trong 1 giờ"
    alert: P1 — page on-call ngay lập tức
    action: Investigate và rollback nếu cần
  slow_burn:
    threshold: "10% error budget consumed trong 6 giờ"
    alert: P2 — ticket + notify team
    action: Schedule fix trong sprint hiện tại
```

### Bước 6: SLA derivation

SLA = SLO − buffer (thường 0.1-0.5% tùy domain):

```
Quy tắc:
- SLA PHẢI thấp hơn SLO để có buffer xử lý khi vi phạm
- SLA kèm penalty phải được legal review
- Document rõ: service exclusions, force majeure, measurement methodology

Ví dụ:
- Internal SLO: 99.9%
- External SLA: 99.5% (buffer 0.4%)
- Penalty trigger: 3 tháng liên tiếp dưới 99.5%
```

### Bước 7: Alerting policy — burn rate alerts

Thiết kế multi-window burn rate alerts (theo Google SRE Workbook):

```yaml
alerts:
  - name: "slo-critical-fast-burn"
    condition: "burn_rate > 14.4 trong 1 giờ QUÀ 5 phút"
    severity: P1
    runbook: "link-to-runbook"
    # Ý nghĩa: tiêu hết error budget trong 2 giờ nếu tiếp tục

  - name: "slo-warning-slow-burn"
    condition: "burn_rate > 6 trong 6 giờ QUÀ 30 phút"
    severity: P2
    runbook: "link-to-runbook"
    # Ý nghĩa: tiêu hết error budget trong 5 ngày nếu tiếp tục

  - name: "slo-info-trend"
    condition: "burn_rate > 1 trong 24 giờ"
    severity: P3
    channel: slack-only
    # Ý nghĩa: đang tiêu budget theo tốc độ bình thường
```

Quy tắc bắt buộc: Mọi alert PHẢI có runbook link. Alert không có runbook = alert vô dụng.

### Bước 8: Dashboard design

Thiết kế SLO dashboard với 3 panels bắt buộc:

```
Panel 1: SLO Status Overview
- Current SLO compliance (% trong rolling window)
- Màu: Xanh (>= target), Vàng (target-1%), Đỏ (< target-1%)

Panel 2: Error Budget Burn
- Error budget remaining (%)
- Burn rate (current vs threshold)
- Trend line: projected exhaustion date

Panel 3: SLI Time Series
- Raw SLI metric theo thời gian
- P50/P95/P99 latency nếu là latency SLI
- Annotations: deployments, incidents, maintenance windows
```

### Bước 9: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase3-architecture/slo-sli-definitions.md

Cấu trúc output:
1. Executive Summary — reliability targets và rationale
2. User Journey Map — critical paths và business impact
3. SLI Definitions — measurement methodology per journey
4. SLO Targets — với trade-off analysis và justification
5. Error Budget Policy — consumption thresholds và actions
6. SLA Commitments — derived from SLO với buffer
7. Alerting Policy — burn rate alert configurations
8. Dashboard Specifications — panels và metrics
9. Review Schedule — khi nào review SLO targets
```

---

## Checklist trước khi submit

```
□ Mỗi SLI đo user-facing behavior, không phải infrastructure metrics
□ SLO target có justification (baseline + business context)
□ Error budget policy có 4 tiers rõ ràng
□ SLA thấp hơn SLO ít nhất 0.1%
□ Mọi alert có runbook link
□ Dashboard specs đủ để implement bởi devops
□ Review schedule được xác định (thường quarterly)
□ Trade-offs 99.9% vs 99.99% được document
```

---

## Lưu ý kỹ thuật

- **Measurement window**: Rolling 30 ngày tốt hơn calendar month cho SLO compliance
- **SLI granularity**: Không thể có SLO chính xác hơn monitoring granularity
- **Latency SLI**: Luôn dùng histogram percentile, không dùng average
- **Availability SLI**: Đếm good requests, không đo uptime theo ping
