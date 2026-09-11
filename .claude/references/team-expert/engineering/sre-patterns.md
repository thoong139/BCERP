# Engineering - SRE Patterns

> **Domain**: Engineering / Site Reliability Engineering
> **Last Updated**: 2026-03-15
> **Nguồn**: Google SRE Book, SRE Workbook, Prometheus documentation

---

## 1. SLO Definition Framework

```yaml
# Định nghĩa SLO cho service
service: payment-api
slos:
  - name: Availability
    # Mô tả: Tỷ lệ request thành công trên tổng request hợp lệ
    sli: count(status < 500) / count(total)
    target: 99.95%
    window: 30d
    error_budget_minutes: 21.6  # (1 - 0.9995) * 30 * 24 * 60
    burn_rate_alerts:
      - severity: critical
        # Cảnh báo khi burn rate 14.4x — hết budget trong 2 giờ
        short_window: 5m
        long_window: 1h
        factor: 14.4
      - severity: warning
        # Cảnh báo khi burn rate 6x — hết budget trong 5 ngày
        short_window: 30m
        long_window: 6h
        factor: 6

  - name: Latency
    # Mô tả: 99% request hoàn thành trong 300ms
    sli: count(duration < 300ms) / count(total)
    target: 99%
    window: 30d
```

---

## 2. Observability Stack

### Ba trụ cột

| Trụ cột | Mục đích | Câu hỏi trả lời |
|---------|----------|-----------------|
| Metrics | Xu hướng, alerting, SLO tracking | Hệ thống có khỏe không? Error budget đang cháy không? |
| Logs | Chi tiết sự kiện, debugging | Điều gì xảy ra lúc 14:32:07? |
| Traces | Luồng request qua các service | Latency nằm ở đâu? Service nào bị lỗi? |

### Golden Signals

- **Latency** — Thời gian xử lý request (phân biệt request thành công vs lỗi)
- **Traffic** — Số request/giây, số user đồng thời
- **Errors** — Tỷ lệ lỗi theo loại (5xx, timeout, business logic)
- **Saturation** — CPU, memory, queue depth, connection pool

---

## 3. Incident Response — Runbook Template

```markdown
# Runbook: [Tên Sự cố]

## Mức độ nghiêm trọng
- P0: SLO breach xảy ra hoặc sắp xảy ra trong < 1 giờ
- P1: Error budget burn rate > 6x trong 1 giờ qua
- P2: Degraded performance, chưa breach SLO
- P3: Warning signals, không ảnh hưởng user

## Triệu chứng
[Metrics/logs/alerts cho thấy điều gì]

## Kiểm tra ngay lập tức
1. [Bước 1 — kiểm tra X]
2. [Bước 2 — xác nhận Y]

## Các nguyên nhân phổ biến
| Nguyên nhân | Cách xác nhận | Cách khắc phục |
|-------------|---------------|----------------|
| | | |

## Escalation
[Khi nào và escalate cho ai]
```

---

## 4. Post-Mortem Template

```markdown
# Post-Mortem: [Tên Sự cố] — [Ngày]

## Thông tin tổng quan
- Thời gian bắt đầu:
- Thời gian phát hiện:
- Thời gian khắc phục:
- MTTR (Mean Time To Resolve):
- Mức độ ảnh hưởng: [X% user, Y phút]
- SLO impact: [Error budget tiêu thụ]

## Timeline sự kiện
| Thời gian | Sự kiện | Người thực hiện |
|-----------|---------|-----------------|
| | | |

## Nguyên nhân gốc rễ (Root Cause)
[Mô tả nguyên nhân kỹ thuật — không đổ lỗi con người]

## Yếu tố góp phần
- [Yếu tố 1]
- [Yếu tố 2]

## Điều đã làm tốt / Điều cần cải thiện
- [Ghi nhận và bài học]

## Action Items
| Hành động | Ưu tiên | Người phụ trách | Deadline |
|-----------|---------|-----------------|----------|
| | | | |
```

---

## 5. Capacity Planning Template

```yaml
# Kế hoạch capacity cho service
service: api-gateway
current_metrics:
  rps_p95: 1200
  cpu_utilization: 65%
  memory_utilization: 70%
  response_time_p99: 180ms

growth_projection:
  rate: 20%              # Tăng trưởng dự kiến mỗi tháng
  horizon_months: 6

scaling_thresholds:
  scale_out: cpu > 70% || memory > 80%
  scale_in: cpu < 30% && memory < 40%

capacity_recommendation:
  current_instances: 4
  recommended_3mo: 6
  recommended_6mo: 8
  notes: Xem xét autoscaling nếu traffic có peak patterns rõ ràng
```

---

## 6. Chaos Engineering

### Nguyên tắc

1. Bắt đầu từ steady state — đo baseline trước khi inject fault
2. Hạn chế blast radius — test trong staging trước
3. Có rollback plan — biết cách dừng experiment ngay lập tức
4. Tăng dần độ phức tạp — bắt đầu từ failure modes đơn giản

### Level 1 — Single Component Failure

| Kịch bản | Kỳ vọng | Blast Radius |
|----------|---------|-------------|
| Kill 1 pod (5% capacity) | Service tiếp tục, latency OK | Thấp |
| Database failover | Traffic switch trong < 30s | Trung bình |
| Cache miss (Redis down) | Fallback to DB, latency tăng 5-10% | Thấp |

### Level 2 — Cascading Failure

| Kịch bản | Kỳ vọng | Blast Radius |
|----------|---------|-------------|
| 3 zones down đồng thời | Failover hoạt động, 100% traffic re-route | Cao |
| API timeout cascade | Circuit breakers ngăn cascade | Cao |

### Game Day Discipline

- Pre-game: Establish baseline metrics
- During: Inject fault, KHÔNG can thiệp (quan sát)
- Post-game: Validate SLOs giữ được, document findings
- Nếu SLO breach → finding → trở thành action item

---

## 7. Multi-Window Alerting

```yaml
# Multi-window alerting cho SLO 99.9%
alerts:
  - name: high_burn_rate_critical
    # Cảnh báo sớm — hết budget trong ~2 giờ
    condition: burn_rate_5m > 14.4 AND burn_rate_1h > 14.4
    severity: page

  - name: high_burn_rate_warning
    # Cảnh báo — hết budget trong ~5 ngày
    condition: burn_rate_30m > 6 AND burn_rate_6h > 6
    severity: ticket

  - name: low_burn_rate_warning
    # Cảnh báo chậm — hết budget trong ~3 ngày
    condition: burn_rate_6h > 3 AND burn_rate_3d > 3
    severity: ticket
```

---

## 8. Error Budget Policy

| Error budget còn lại | Hành động |
|---------------------|-----------|
| > 50% | Ship features bình thường |
| 25–50% | Tăng code review cho mọi thay đổi production |
| < 25% | Chỉ ship bug fix và reliability improvements |
| Hết budget | Freeze feature deployments, tập trung 100% vào reliability |

---

## 9. SLI Definition Best Practices

**SLI tốt = phản ánh trải nghiệm user**

| Loại | Ví dụ tốt | Ví dụ kém (không nên dùng) |
|------|-----------|---------------------------|
| Availability | % checkout attempts that completed successfully | Application uptime |
| Latency | % search requests returning results within 300ms | CPU utilization |
| Correctness | % API requests returning status < 500 | Disk space available |

> Phân biệt error latency vs success latency: đo p99 latency của *successful* requests only.

---

## 10. Severity Classification Matrix

| Level | Điều kiện | Response Time | Update Cadence | Escalation |
|-------|-----------|---------------|----------------|------------|
| SEV1 — Critical | Feature down, data loss risk, SLO breach < 1h | < 5 phút | Mỗi 15 phút | VP Eng ngay lập tức |
| SEV2 — Major | Degraded (25-100% users), SLO breach < 6h | < 15 phút | Mỗi 30 phút | Eng Manager 15 phút |
| SEV3 — Moderate | Minor feature broken, workaround có sẵn | < 1 giờ | Mỗi 2 giờ | Team lead |
| SEV4 — Low | Cosmetic, zero user impact | Next business day | Daily | Backlog triage |

---

## 11. On-Call Program Design

### Rotation Structure

- Tối thiểu 4 engineers per on-call shift (tránh burnout)
- Weekly handoff vào giờ làm việc (10 AM local), tránh lúc nửa đêm
- Tối đa 2 tuần liên tiếp on-call per engineer
- Engineer mới shadow 2 tuần trước khi làm primary

### Escalation Policy

| Level | Role | Response Window |
|-------|------|-----------------|
| Level 1 | Primary on-call | 5 phút |
| Level 2 | Secondary on-call | 10 phút |
| Level 3 | Engineering manager | 15 phút |
| Level 4 | VP Engineering | Immediate cho SEV1 |

### Health Metrics (review hàng quý)

- Pages per engineer per week (target: < 5)
- MTTR by engineer và incident type
- False positive rate của alerts
- On-call satisfaction survey (target: > 4/5)

---

## 12. Blameless Post-Mortem Discipline

**Quy tắc blameless:**
- Framing đúng: "hệ thống cho phép failure mode này xảy ra" (system-level)
- Framing sai: "người X gây ra sự cố" (blame-based)
- Ví dụ kém: "DBA chạy migration script sai"
- Ví dụ tốt: "Quy trình migration không có dry-run stage và không có validation — thiếu guardrails"

**Phương pháp 5 Whys:**
1. Tại sao service down? → Database connection pool hết
2. Tại sao connection pool hết? → Không có max_connections limit
3. Tại sao không có limit? → Auto-scaling không bao gồm DB scaling
4. Tại sao auto-scaling không bao gồm DB? → DB được giả định "luôn available"
5. Tại sao giả định như vậy? → Architecture chưa test failure mode này
→ **Root systemic issue**: Thiếu chaos engineering, chưa test failure modes

---

## 13. Toil Measurement Framework

```yaml
# Ví dụ: Database Backup Automation
Toil_Reduction_Project:
  Current_State:
    manual_task: "Backup thủ công mỗi T2, T5, T6"
    frequency: "3x/tuần x 45 phút = 2.25 giờ/tuần"
    toil_per_month: "~9 giờ"
  Solution: "Automated backups với cross-region replication"
  Development_Effort: "20 giờ (2.5 ngày)"
  Savings: "9 giờ/tuần = 36 giờ/tháng"
  ROI: "Hoàn vốn trong < 1 tuần"
```

---

## 14. Graduated Rollout Strategy

```
Canary (1%) → 10% → 25% → 50% → 100%
           |        |       |
           |        |       └── Dừng nếu SLO burn rate tăng
           |        └── Dừng nếu error rate tăng > 0.1%
           └── Dừng nếu bất kỳ alerting nào kích hoạt
```

---

## 15. Concrete SLI PromQL Examples

```promql
# Availability SLI (% successful requests)
sum(rate(http_requests_total{status!~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))

# Latency SLI (% requests under threshold)
histogram_quantile(0.99,
  rate(http_request_duration_seconds_bucket[5m])
) < 0.3  # p99 under 300ms

# Error Budget Burn Rate (critical: 14.4x)
increase(errors_total[5m]) / (21.6 * 60 / 30 / 24) > 14.4
```

---

## 16. Output Templates

### SLO Design Document

```markdown
# SLO Design: [Tên Service]

## User Journeys được bảo vệ
| Journey | SLI | SLO Target | Error Budget (30d) |
|---------|-----|------------|-------------------|
| | | | |

## Alerting Strategy
| Alert | Severity | Điều kiện | Hành động |
|-------|----------|-----------|-----------|
| | | | |

## Dashboard
[Link hoặc mô tả dashboard]
```

### Reliability Report Template

```markdown
# Báo cáo Độ tin cậy: [Tên Service] — [Tháng/Năm]

## Tóm tắt
- Error budget còn lại: X%
- Số incident: Y
- MTTR trung bình: Z phút
- Toil giảm được: N giờ/tuần

## SLO Performance
| SLO | Target | Actual | Status |
|-----|--------|--------|--------|
| | | | |

## Top Issues
[3 vấn đề lớn nhất tháng này và action items]

## Kế hoạch tháng tới
[Các cải tiến reliability đã lên kế hoạch]
```

### Toil Reduction Report Template

```markdown
# Báo cáo Giảm Toil: [Tên Tác vụ]

## Tác vụ thủ công hiện tại
- Tần suất: [N lần/tuần]
- Thời gian: [X phút/lần]
- Tổng toil: [Y giờ/tuần]

## Giải pháp tự động hóa
[Mô tả kỹ thuật]

## ROI
- Thời gian phát triển: [Z giờ]
- Toil tiết kiệm: [Y giờ/tuần]
- Hoàn vốn sau: [W tuần]
```
