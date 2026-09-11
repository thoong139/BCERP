# Playbook: Review Analytics Implementation

> **Type**: Agent Procedure
> **Agent**: data-expert
> **Triggered by**: /wf-implement-feature khi review analytics/reporting/dashboard features
> **Output**: Analytics implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của analytics/reporting/dashboard module
- Khi cần validate implementation từ data accuracy và business logic perspective
- Khi cần check performance với large datasets

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type:
□ Operational Report → check query logic, filters, export
□ BI Dashboard → check KPI calculations, drill-down, real-time
□ KPI Engine → check formula accuracy, threshold logic, alerts
□ Data Export → check format, encoding, large file handling
□ Analytics API → check aggregation logic, caching, pagination
```

### Bước 2: Review against Analytics Requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE1, PHASE2

□ Đọc analytics-requirements.md → lấy REQ-DATA-xxx tương ứng
□ Đọc feature spec → lấy acceptance criteria
□ Mapping: Mỗi REQ-ID có implementation tương ứng không?
□ Flag: REQ nào chưa được implement?
```

### Bước 3: Verify KPI Calculations

```
READ: .claude/references/team-expert/data/analytics-framework.md → KPI Framework

Với mỗi KPI trong implementation:
□ Formula đúng với spec không? (vd: Revenue = sum(order_amount) WHERE status = 'completed')
□ Edge cases: NULL values được xử lý thế nào?
□ Division by zero: Có guard không? (vd: Conversion Rate = orders/visitors)
□ Rounding: Số thập phân, làm tròn có nhất quán không?
□ Currency: Multi-currency có convert đúng không?
□ Date range: Boundary dates có bị include/exclude đúng không? (>= vs >)
□ Timezone: Calculations dùng timezone nào? Có nhất quán không?
```

### Bước 4: Check Data Accuracy vs Source

```
□ Spot check: Lấy 3-5 records cụ thể → verify số liệu khớp với source DB
□ Aggregate check: Total trên report có khớp với direct SQL query không?
□ Filter check: Khi filter theo date range, có include đúng rows không?
□ Joins: LEFT JOIN vs INNER JOIN có cho kết quả đúng không?
□ Duplicates: Có row nào bị count 2 lần do join logic không?
□ Soft deletes: Records đã xóa mềm có bị lọc ra khỏi report không?
```

### Bước 5: Validate Access Controls

```
READ: .claude/references/team-expert/data/analytics-framework.md → Data Requirements

□ Role-based access: User không có role phù hợp có bị block không?
□ Row-level security: User chỉ thấy dữ liệu của scope mình không?
□ Column masking: Fields nhạy cảm (lương, giá vốn) có bị ẩn theo role không?
□ Direct URL access: Có bypass access control qua direct URL không?
□ Export security: Khi export, có giữ nguyên access restrictions không?
□ API security: Analytics API endpoint có authenticate không?
```

### Bước 6: Performance Testing (Large Datasets)

```
□ Query execution plan: Có table scan không? Index được dùng chưa?
□ Index coverage: Date columns, foreign keys, status fields có index không?
□ N+1 queries: Dashboard có trigger N+1 queries không? (1 query per KPI widget)
□ Pagination: Báo cáo >1000 rows có pagination/virtualization không?
□ Memory: Khi export Excel với 100k rows, có OOM không?
□ Timeout: Query timeout setting có phù hợp với complexity không?

Benchmark targets:
  Dashboard load: < 3 giây (P95)
  Standard report: < 5 giây (P95)
  Heavy report (>50k rows): < 30 giây hoặc async
  Export 10k rows: < 10 giây
```

### Bước 7: Dashboard Load Times & Data Freshness

```
□ Initial load time: Đo time-to-interactive của dashboard
□ Widget loading: Có skeleton loading để UX tốt hơn không?
□ Cache hit rate: Caching có hoạt động không? TTL có phù hợp không?
□ Data staleness indicator: User có biết dữ liệu fresh đến khi nào không?
□ Manual refresh: User có thể trigger refresh không?
□ Error states: Khi data source unavailable, dashboard hiện gì?
```

### Bước 8: Output — Review Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/work/wf-implement-feature/analytics-review-[module]-[date].md
```

```markdown
# Analytics Implementation Review: [Module Name]

## Overall Status: PASS / FAIL / NEEDS ATTENTION

## REQ-ID Coverage
| REQ-ID | Status | Notes |
|--------|--------|-------|
| REQ-DATA-xxx | Implemented / Missing / Partial | |

## Critical Issues (block go-live)
- [ ] [Issue]: [File:line] → [Required fix]

## Important Issues (fix before next sprint)
- [ ] [Issue]: [Location] → [Recommendation]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

## KPI Accuracy Checklist
| KPI | Formula Correct | Edge Cases | Spot Check |
|-----|----------------|-----------|-----------|

## Performance Results
| Scenario | Actual Time | Target SLA | Status |
|----------|------------|-----------|--------|

## Access Control Checklist
| Check | Status | Notes |
|-------|--------|-------|
| Role-based access | OK / FAIL | |
| Row-level security | OK / FAIL | |
| Column masking | OK / FAIL / N/A | |

## Sign-off
□ KPI calculations: OK / ISSUE
□ Data accuracy: OK / ISSUE
□ Access controls: OK / ISSUE
□ Performance: OK / ISSUE
□ Data freshness: OK / ISSUE
```

---

## Checklist trước khi submit

```
□ Tất cả REQ-DATA-xxx đã được verify coverage
□ KPI formulas đã được spot-check với source data
□ Performance benchmarks đã được test với realistic data volume
□ Access control đã verify theo tất cả roles
□ Critical issues (nếu có) có hướng fix rõ ràng
```
