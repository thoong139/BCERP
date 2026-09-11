# Playbook: Audit Data & Analytics Systems Hiện Có

> **Type**: Agent Procedure
> **Agent**: data-expert
> **Triggered by**: /wf-legacy-scan khi có analytics/reporting tools hoặc BI systems cũ
> **Output**: `.mc-data/docs/phase1-business/data-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống analytics/reporting/BI
- Khi cần đánh giá current state trước khi thiết kế lại
- Khi cần tìm gaps và migration complexity
- Không dùng khi project hoàn toàn mới (greenfield) — dùng `analyze-analytics-requirements.md` thay thế

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, KNOWLEDGE_BASE

Cần xác định:
□ Loại business (ERP, CRM, E-commerce, SaaS...)
□ Số lượng người dùng analytics hiện tại
□ Pain points chính với hệ thống hiện có
□ Ngân sách/timeline cho migration (nếu có)
```

### Bước 2: Inventory BI Tools hiện có

```
Thu thập từ stakeholders hoặc codebase:
□ Commercial BI: Power BI, Tableau, Qlik, Looker, Metabase?
□ Custom reports: Reports tự build trong app?
□ Spreadsheets: Excel/Google Sheets được dùng như report?
□ Database queries: Ad-hoc SQL queries của team IT?
□ Third-party embedded: Analytics nhúng từ vendor (vd: Shopify Analytics)?

Với mỗi tool:
  - Tên tool + version
  - Ai đang dùng (role, số người)
  - Bao nhiêu reports/dashboards đang active
  - Chi phí license/năm
  - Mức độ satisfied (thấp/trung/cao)
```

### Bước 3: Đánh giá Data Quality & Consistency

```
READ: .claude/references/team-expert/data/data-modeling.md

Kiểm tra chất lượng dữ liệu:
□ Duplicate records: Có customer/product bị duplicate không?
□ Missing data: % NULL trên các fields quan trọng?
□ Inconsistent formats: Date formats, currency, enum values có nhất quán không?
□ Stale data: Có bảng/report nào không được update từ lâu?
□ Definition conflicts: Cùng 1 KPI được tính khác nhau ở 2 report?

Ghi lại: Severity (Critical/Major/Minor) + Estimated fix effort
```

### Bước 4: Identify Data Silos

```
□ Dữ liệu nằm ở bao nhiêu nguồn khác nhau?
□ Có cross-system joins không hay mỗi system báo cáo độc lập?
□ Master data (khách hàng, sản phẩm) có consistent ID không?
□ Manual data consolidation: Có ai đang copy-paste giữa hệ thống?
□ Ownership: Ai là data owner của từng source?
```

### Bước 5: Kiểm tra Latency Issues

```
□ Reports chạy bao lâu? (P50, P95 response time)
□ Có reports nào timeout không? Tần suất?
□ Database: Có heavy queries đang ảnh hưởng production DB không?
□ Refresh schedule: Dữ liệu stale bao lâu so với nhu cầu?
□ Peak load: Reports có bị chậm vào giờ cao điểm không?
```

### Bước 6: Document Current KPIs & Metrics

```
READ: .claude/references/team-expert/data/analytics-framework.md → KPI Framework

Liệt kê các KPIs đang được track:
□ KPI tên gì?
□ Được tính theo formula nào?
□ Nguồn dữ liệu nào?
□ Refresh frequency?
□ Có official definition document không hay chỉ "mọi người tự hiểu"?

Red flag: Cùng KPI "Revenue" nhưng Finance tính khác Sales → cần chuẩn hóa
```

### Bước 7: Migration Complexity Assessment

```
Đánh giá effort migration per tool/system:
□ Data volume: Bao nhiêu GB/TB cần migrate?
□ Historical data: Cần giữ lịch sử bao nhiêu năm?
□ Custom logic: Có business logic phức tạp trong reports không?
□ User dependency: Bao nhiêu user phụ thuộc vào system cũ?
□ Integration: System cũ có API/connector nào đang được dùng?
□ Training: Team có cần training cho system mới không?

Matrix:
  Complexity Score = (Data Volume × 0.2) + (Custom Logic × 0.4) + (User Dependency × 0.4)
  Low: <3, Medium: 3-6, High: >6
```

### Bước 8: Output — Data As-Is Analysis Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/data-as-is-analysis.md

Cấu trúc output:
```

```markdown
# Data & Analytics As-Is Analysis

## Executive Summary
[3-5 dòng: overall state, top strengths, critical problems]

## Current Analytics Landscape
### Tool Inventory
| Tool | Type | Users | Reports | Cost/year | Satisfaction |
|------|------|-------|---------|-----------|-------------|

### KPI Inventory
| KPI Name | Formula | Owner | Source | Frequency | Issues |
|----------|---------|-------|--------|-----------|--------|

## Data Quality Assessment
| Issue | Affected Data | Severity | Fix Effort |
|-------|--------------|----------|-----------|

## Data Silos Map
[Diagram mô tả dữ liệu nằm ở đâu và flow giữa các system]

## Performance Issues
| Report/Query | Current Time | Acceptable SLA | Root Cause |
|-------------|-------------|----------------|-----------|

## Migration Complexity
| System | Complexity | Key Risks | Recommended Approach |
|--------|-----------|-----------|---------------------|

## Recommendations
### Quick Wins (< 1 tháng)
### Medium Term (1-3 tháng)
### Long Term (3+ tháng)
```

---

## Checklist trước khi submit

```
□ Tất cả BI tools đã được inventory với chi phí và satisfaction
□ Data quality issues có severity rating
□ Data silos được document rõ ràng
□ KPI conflicts (cùng metric, khác formula) đã được flag
□ Migration complexity có estimate effort
□ Recommendations ưu tiên theo impact/effort
```
