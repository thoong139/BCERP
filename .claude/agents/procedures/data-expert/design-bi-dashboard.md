# Playbook: Thiết kế BI/Executive Dashboard

> **Type**: Agent Procedure
> **Agent**: data-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần design BI hoặc executive dashboard
> **Output**: Feature spec cho dashboard module tại `.mc-data/docs/phase2-features/`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-define-features` hoặc `/wf-design`
- Khi project cần BI dashboard, executive scorecard, hoặc operational monitoring
- Khi cần thiết kế KPI widgets, drill-down, alert thresholds
- Phân biệt với `design-reporting-module.md`: playbook này dành cho dashboard interactive — không phải báo cáo bảng tĩnh

---

## Procedure

### Bước 1: Đọc requirements & context

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE1, PHASE2

Cần xác định:
□ analytics-requirements.md đã có chưa? → Đọc để lấy REQ-DATA-DASH-xxx
□ Loại dashboard cần thiết kế (Executive / Manager / Operational)?
□ Primary audience: BGĐ cần strategic view hay team lead cần operational view?
□ Scope: Single department hay cross-department?
```

### Bước 2: Dashboard Hierarchy

```
READ: .claude/references/team-expert/data/dashboard-design.md
READ: .claude/references/team-expert/data/analytics-framework.md → Metrics Hierarchy

Thiết kế 3-tier hierarchy:

Tier 1 — Executive Dashboard:
□ Audience: CEO, BGĐ
□ KPIs: Top 5-7 business metrics (Revenue, Profit, NPS, Growth rate)
□ Time view: Monthly/Quarterly trend
□ Action: Click để drill xuống Tier 2

Tier 2 — Manager Dashboard:
□ Audience: Trưởng phòng, Regional manager
□ KPIs: Department-specific metrics (15-20 metrics)
□ Time view: Weekly trend, daily detail
□ Action: Click để xem Tier 3

Tier 3 — Operational Dashboard:
□ Audience: Team lead, Analyst
□ KPIs: Granular operational metrics
□ Time view: Daily, near real-time
□ Action: Export, drill-to-transaction
```

### Bước 3: KPI Widget Design

```
READ: .claude/references/team-expert/data/analytics-framework.md → KPI Framework

Với mỗi KPI cần thiết kế widget:
□ Widget type: Card (số đơn) / Gauge (%) / Sparkline / Trend arrow
□ Primary value: Số liệu chính
□ Comparison: vs kỳ trước hoặc target (%)
□ Color coding: Green/Yellow/Red dựa trên thresholds
□ Tooltip: Hiện formula khi hover

KPI Card template:
  [Icon] KPI Name
  [Primary Value] [Unit]
  [+X%] vs [comparison period]
  [Threshold indicator]
```

### Bước 4: Drill-down Paths

```
Thiết kế navigation:
□ Dashboard → Chart → Detail table → Single record
□ Breadcrumb navigation để user biết đang ở đâu
□ Back button / ESC để quay lại level trên
□ Context filter: Khi drill vào Sales Region A → tất cả charts lọc theo Region A

Xác định drill-down cho từng KPI:
Revenue → by Product → by Customer → by Transaction
Pipeline → by Stage → by Rep → by Opportunity
Inventory → by Category → by Product → by Location
```

### Bước 5: Real-time vs Batch Data

```
Xác định từng metric cần refresh frequency nào:
□ Real-time (<1 phút): Alerts, active orders, live inventory
□ Near real-time (15-60 phút): Sales today, support tickets open
□ Hourly: Cumulative daily metrics
□ Daily: Trend charts, comparison vs yesterday
□ Weekly/Monthly: Strategic KPIs, variance analysis

Lưu ý: Real-time data tốn infrastructure → chỉ dùng khi thực sự cần thiết
```

### Bước 6: Alert Thresholds

```
READ: .claude/references/team-expert/data/analytics-framework.md → KPI Design Template

Với mỗi critical KPI:
□ Green threshold: Đang đạt mục tiêu (≥ X%)
□ Yellow threshold: Cần chú ý (X% - Y%)
□ Red threshold: Cần hành động ngay (< Y%)

Alert delivery:
□ In-dashboard notification (bell icon)
□ Email alert: Gửi cho ai? Tần suất?
□ Escalation: Nếu không xử lý trong X giờ → escalate lên ai?
□ Silence/snooze: Có thể tắt alert tạm thời không? Bao lâu?
```

### Bước 7: Mobile Responsiveness

```
□ Priority widgets: Widget nào quan trọng nhất trên mobile?
□ Layout: Stack vertically trên mobile (<768px)
□ Touch interactions: Drill-down bằng tap thay vì click
□ Font size: Tối thiểu 14px cho mobile readability
□ Push notifications: Có gửi alert qua mobile push không?
```

### Bước 8: Embedding Requirements

```
□ Standalone app: Dashboard trong ứng dụng chính
□ Embed in external: Nhúng vào portal khác (iframe)?
□ Public sharing: Có cần share link dashboard cho external stakeholders?
□ White-label: Có cần remove branding khi share?
□ SSO: Dashboard phải dùng cùng auth với app chính
```

### Bước 9: Viết Feature Spec

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase2-features/[sys]/analytics/bi-dashboard.md

Cấu trúc output:
1. Overview (mục tiêu, audience, dashboard tiers)
2. Dashboard Hierarchy (table: tier → audience → KPIs → action)
3. KPI Widget Catalog (per dashboard tier)
4. Drill-down Navigation Map
5. Data Freshness Requirements (per metric)
6. Alert & Threshold Config
7. Mobile & Embedding requirements
8. Access control (ai xem dashboard nào)
9. REQ-ID mapping (feature → REQ-DATA-DASH-xxx)
```

---

## Checklist trước khi submit

```
□ Dashboard hierarchy đã cover đủ audience levels
□ Mỗi KPI có widget type, comparison, và threshold rõ ràng
□ Drill-down paths được map rõ ràng
□ Data freshness requirements đã xác định per metric
□ Alert thresholds có logic Green/Yellow/Red
□ Mobile responsiveness đã được addressed
□ REQ-ID mapping đầy đủ với requirements phase 1
```
