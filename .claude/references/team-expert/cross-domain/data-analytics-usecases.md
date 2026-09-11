# Cross-Domain - Analytics Use Cases theo Domain

> **Domain**: Cross-Domain / Data & Analytics
> **Last Updated**: 2026-03-15
> **Nguồn**: Tổng hợp từ data-engineer, business-analyst agents — Analytics Engineering best practices

---

## 1. Analytics Maturity Model

Tổ chức tiến qua 4 cấp độ. Mỗi cấp yêu cầu data foundation của cấp trước.

```
Cấp 1: Descriptive        "Chuyện gì đã xảy ra?"
        └── Reports, dashboards, historical data

Cấp 2: Diagnostic         "Tại sao nó xảy ra?"
        └── Drill-down, root cause, correlation analysis

Cấp 3: Predictive         "Chuyện gì sẽ xảy ra?"
        └── Forecasting, scoring models, trend extrapolation

Cấp 4: Prescriptive       "Chúng ta nên làm gì?"
        └── Recommendation engines, automated decisions, optimization
```

**Sai lầm phổ biến:** Nhảy thẳng lên Cấp 3/4 khi data quality Cấp 1 chưa ổn định.

---

## 2. Use Case Matrix theo Domain

| Domain | Key Metrics | Common Dashboards | Data Sources chính |
|--------|------------|-------------------|--------------------|
| **Sales** | Pipeline velocity, win rate, quota attainment | Pipeline health, rep performance, forecast | CRM, call recordings |
| **Marketing** | MQL volume, CAC, ROAS, attribution | Campaign performance, funnel, channel ROI | Ad platforms, website, CRM |
| **Finance** | Gross margin, burn rate, DSO, DPO | P&L, cash flow, budget vs actual | ERP, accounting, payroll |
| **Operations** | Throughput, cycle time, defect rate | Production KPI, inventory turns, OEE | MES, ERP, IoT sensors |
| **HR** | Headcount, attrition rate, time-to-hire | Workforce analytics, retention, cost per hire | HRIS, ATS, payroll |
| **Customer Success** | NPS, churn rate, NRR, time-to-value | Health score, renewal pipeline, expansion | CRM, product, support tickets |
| **Product** | DAU/MAU, retention, feature adoption | Activation funnel, cohort retention, NPS | Event tracking, A/B test results |

---

## 3. KPI Hierarchy Framework

Thiếu hierarchy là lý do dashboards trở nên "con số nhưng không insight".

```
Company OKRs (Board/C-Suite)
│   Ví dụ: "Tăng ARR 40% YoY"
│
├── Department KPIs (VP level)
│   Ví dụ: "Sales: +$5M new ARR / Marketing: 1,200 MQLs / Q"
│   │
│   ├── Team Metrics (Manager level)
│   │   Ví dụ: "AE Team: 85% quota attainment / SDR: 50 SQLs/tháng"
│   │   │
│   │   └── Individual Metrics (IC level)
│   │       Ví dụ: "Rep A: $420K pipeline / 8 demos/tuần"
```

**Nguyên tắc:** Mỗi individual metric phải truy được lên KPI cấp trên. Nếu không thể, metric đó không nên tồn tại.

---

## 4. Data Quality Dimensions

| Dimension | Định nghĩa | Cách đo | Threshold tối thiểu |
|-----------|-----------|---------|---------------------|
| **Accuracy** | Data phản ánh đúng thực tế | % records khớp với source of truth | >98% |
| **Completeness** | Không thiếu trường quan trọng | % records có đủ required fields | >95% |
| **Consistency** | Cùng entity, cùng giá trị trên mọi system | % records match cross-system | >99% |
| **Timeliness** | Data cập nhật đúng tần suất cần thiết | % data trong SLA freshness window | >95% |
| **Uniqueness** | Không duplicate entity | % records không trùng lặp | >99.5% |
| **Validity** | Data đúng format, range, domain | % records pass validation rules | >97% |

**Data Quality Score tổng hợp:** Trung bình có trọng số 6 dimensions — cần ≥95 để production-ready.

---

## 5. Common Analytics Patterns

### 5.1 Cohort Analysis

Phân tích nhóm user/customer theo thời điểm họ bắt đầu (acquisition cohort) hoặc hành vi.

```
Retention Cohort:
Month     | Jan Cohort | Feb Cohort | Mar Cohort
Month 0   |    100%    |    100%    |    100%
Month 1   |     60%    |     65%    |     70%
Month 3   |     40%    |     45%    |     48%
Month 6   |     30%    |     34%    |     37%
Month 12  |     22%    |     26%    |     28%

→ Mar cohort đang tốt nhất: kiểm tra điều gì thay đổi trong acquisition/onboarding tháng 3.
```

**Áp dụng:** User retention (Product), revenue cohort (Finance), churn prediction (CS).

### 5.2 Funnel Analysis

Đo conversion và drop-off tại mỗi bước của một process.

```
Acquisition Funnel:
Visitors        10,000  (100%)
│ ↓ 35% conversion
Signups          3,500
│ ↓ 60% conversion
Activated        2,100
│ ↓ 45% conversion
Paying             945   (9.45% overall)
│ ↓ 80% retention
Retained (M3)      756
```

**Key insight:** Tìm bước có drop-off cao nhất → đó là bottleneck cần fix trước.

### 5.3 RFM Segmentation (Customer)

| Segment | Recency | Frequency | Monetary | Hành động |
|---------|---------|-----------|----------|-----------|
| Champions | Gần đây | Cao | Cao | Reward, upsell |
| Loyal | Gần đây | Cao | Trung bình | Upsell |
| At Risk | Lâu | Cao | Cao | Win-back campaign |
| Lost | Rất lâu | Thấp | Thấp | Reactivation hoặc discard |
| Promising | Gần đây | Thấp | Thấp | Nurture |

### 5.4 Forecasting Methods

| Method | Khi dùng | Yêu cầu data | Độ chính xác |
|--------|----------|--------------|--------------|
| Moving Average | Trend ổn định, ngắn hạn | ≥6 kỳ lịch sử | Thấp-Trung |
| Linear Regression | Tương quan rõ ràng | ≥12 kỳ + features | Trung |
| Time-Series (ARIMA) | Có seasonality | ≥2 năm | Trung-Cao |
| Prophet (Meta) | Nhiều seasonality, missing data | ≥1 năm | Cao |
| ML Ensemble | Nhiều variables, nonlinear | Large labeled dataset | Cao nhất |

---

## 6. Dashboard Design Principles

### 5-Second Rule
Người xem phải hiểu được insight chính trong 5 giây. Nếu cần đọc lâu hơn — redesign.

### Progressive Disclosure
```
Level 1: Executive Summary (3-5 KPIs, traffic light status)
    │
    ▼
Level 2: Department Breakdown (charts, trends, comparisons)
    │
    ▼
Level 3: Drill-down (individual records, filters, raw data)
```

### Actionable Insight Framework

| Yếu tố | Mô tả |
|--------|-------|
| **Context** | So sánh với gì? (vs last period, vs target, vs benchmark) |
| **Signal** | Trend đang đi đâu? (up/down/flat + magnitude) |
| **Significance** | Đây có phải anomaly? (control limits, statistical significance) |
| **Action** | Người xem nên làm gì với thông tin này? |

**Chỉ hiển thị metric nếu có thể link tới một action cụ thể.**

---

## 7. Cross-Department Data Sharing Governance

| Vấn đề | Giải pháp |
|--------|-----------|
| Ai được xem data gì? | Role-based access control (RBAC) theo domain + seniority |
| Data definition khác nhau giữa teams | Semantic layer / Data dictionary dùng chung |
| Ai là owner của dataset? | Data steward per domain — chịu trách nhiệm quality |
| Audit trail ai đã access | Query logging bắt buộc với data governance tool |
| PII và sensitive data | Column-level masking, data classification tags |

---

## 8. Self-Service Analytics Framework

Để non-technical user tự khai thác data mà không cần data team.

```
Data Sources → Data Warehouse → Semantic Layer → Self-Service Tools
(ERP, CRM)     (Snowflake,       (dbt metrics,    (Looker, Tableau,
                BigQuery)         Cube.dev)         Metabase, Power BI)
```

| Layer | Vai trò | Người dùng |
|-------|---------|------------|
| **Data Catalog** | Tìm kiếm dataset, xem metadata | Tất cả |
| **Semantic Layer** | Business metrics pre-defined, nhất quán | Analyst tự phục vụ |
| **Report Builder** | Drag-drop chart, filter, schedule | Manager, Business user |
| **SQL Workbench** | Ad-hoc queries, custom analysis | Data analyst |
| **ML Platform** | Feature engineering, model training | Data scientist |

**Access Control:** Mỗi user chỉ thấy data trong domain mình phụ trách.

---

## Quick Reference: Chọn Analytics Pattern

| Câu hỏi business | Pattern phù hợp |
|------------------|-----------------|
| "Ai là customer tốt nhất của chúng tôi?" | RFM Segmentation |
| "Tại sao user bỏ rơi ở bước checkout?" | Funnel Analysis |
| "Revenue tháng sau sẽ là bao nhiêu?" | Forecasting |
| "Nhóm user onboard tháng 3 giữ chân tốt hơn không?" | Cohort Analysis |
| "Marketing channel nào đang drive customer tốt nhất?" | Attribution + LTV Analysis |
| "Chúng tôi có đủ inventory không?" | Time-series Forecasting |
