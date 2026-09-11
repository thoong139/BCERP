# Playbook: Design Marketing Analytics & Dashboard Module

> **Type**: Agent Skill Playbook
> **Agent**: marketing-expert
> **Triggered by**: /wf-design hoặc /wf-define-features khi có Analytics module
> **Output**: Analytics spec + Dashboard wireframe descriptions + Data requirements

---

## Khi nào dùng playbook này

- Khi cần spec module "Marketing Analytics" hoặc "Báo cáo Marketing"
- Khi thiết kế dashboards cho marketing team
- Khi thiết kế attribution và tracking infrastructure

---

## Procedure

### Bước 1: Xác định scope analytics

```
□ Audience chính: CMO? Campaign Manager? Content? C-Suite?
□ Data sources: Web, Email, Ads, CRM, Social, Product?
□ Attribution model: Single-touch / Multi-touch / Data-driven?
□ Real-time hay batch? (ảnh hưởng architecture)
□ Self-serve BI hay pre-built reports?
□ Export capabilities: CSV? API? Data warehouse?
□ Integration: Existing BI tools? (Looker, Tableau, Power BI)
```

### Bước 2: Đọc analytics knowledge

```
READ: analytics-attribution.md → Toàn bộ
READ: metrics-framework.md → Dashboard Requirements section

Key frameworks:
- UTM tracking standards → áp dụng cho data collection
- Attribution models → chọn model phù hợp
- Funnel analysis → thiết kế funnel visualization
- Dashboard specifications → dùng làm template
```

### Bước 3: Thiết kế Data Architecture

```
Data Flow:
Website/App → Event Tracking → Data Layer → Analytics DB → Dashboards
                                              ↑
               CRM, Email Platform, Ad Platforms → Connectors

Tables cần thiết kế:

fact_page_views:
  session_id, user_id (nullable), anonymous_id
  page_url, page_title, referrer_url
  utm_source, utm_medium, utm_campaign, utm_content, utm_term
  event_timestamp, time_on_page, scroll_depth_pct

fact_events:
  session_id, user_id, anonymous_id
  event_name, event_category, event_properties (JSON)
  page_url, event_timestamp

fact_conversions:
  conversion_id, conversion_type, conversion_value
  user_id, lead_id (nullable), customer_id (nullable)
  utm_source, utm_medium, utm_campaign (last touch)
  first_touch_source, first_touch_medium (first touch)
  all_touchpoints (JSON array)
  conversion_timestamp

fact_campaign_performance:
  date, campaign_id, channel, ad_group_id, ad_id
  impressions, clicks, spend
  conversions, conversion_value
  imported_from (google/facebook/linkedin)
  imported_at

dim_campaigns:
  campaign_id, name, type, status
  start_date, end_date, budget
  owner_id, team_id

dim_channels: channel_key, channel_name, channel_group
dim_date: date_key, date, week, month, quarter, year
```

### Bước 4: Thiết kế Attribution Engine

```
READ: analytics-attribution.md → Section 3: Attribution Models

Implement các models:

Model 1: Last Touch (mặc định, đơn giản nhất)
  → Gán 100% credit cho utm_source của last session trước conversion

Model 2: First Touch
  → Gán 100% credit cho utm_source của session đầu tiên

Model 3: Linear
  → Lấy all_touchpoints JSON → chia đều credit

Model 4: Time Decay
  → Tính decay_weight = e^(-λ × days_before_conversion)
  → Normalize và assign credit

Requirements:
□ Mỗi conversion lưu đủ touchpoints data
□ API hoặc function để recalculate attribution với model khác nhau
□ Attribution comparison view: so sánh channel performance theo 2+ models
□ Cross-device tracking để merge anonymous → known user journey
```

### Bước 5: Thiết kế Dashboard Layer

**Dashboard 1: Executive Overview**
```
Audience: CMO, Marketing Director
Refresh: Daily/Weekly

Sections:
├── KPI Cards (vs target, vs last period)
│   CAC | LTV:CAC | MQL Volume | Marketing-Sourced Revenue | Total Spend
│
├── Funnel Overview (bar/funnel chart)
│   Visits → Leads → MQLs → SQLs → Customers (with % conversion each step)
│
├── Channel Mix (pie/bar)
│   Marketing spend + lead volume by channel
│
├── Performance Trend (line chart, 12 weeks)
│   MQL volume + CAC trend
│
└── Budget Summary
    Spent vs Budget (by channel, % remaining)
```

**Dashboard 2: Campaign Performance**
```
Audience: Campaign Manager, Growth Marketer
Refresh: Hourly

Sections:
├── Campaign Table (sortable, filterable)
│   Campaign | Channel | Spend | Leads | CPL | CVR | Status
│
├── Budget Pacing
│   Daily spend rate vs required pace to hit monthly target
│
├── Creative Performance
│   CTR, CVR by creative/ad (A/B test results highlighted)
│
└── Alerts Panel
    Active issues: budget > 80%, performance drop, spend anomaly
```

**Dashboard 3: Content & SEO**
```
Audience: Content Manager, SEO Specialist
Refresh: Weekly

Sections:
├── Organic Traffic Trend (line, 26 weeks)
│
├── Top Pages Table
│   Page | Sessions | Bounce Rate | Avg Time | Conversions | CVR
│
├── Keyword Rankings (top 20)
│   Keyword | Position | Change | Volume | Page ranking
│
└── Content Conversion Funnel
    Page view → CTA click → Form submit → MQL
```

**Dashboard 4: Email Performance**
```
Audience: Email/Marketing Automation Specialist
Refresh: Daily

Sections:
├── Sequence Health Table
│   Sequence | Active Contacts | Step completion rates | Goal CVR
│
├── Recent Sends Performance
│   Email | Sent | Open Rate | CTR | Unsubscribe Rate
│
└── Deliverability Monitor
    Bounce rate | Spam rate | Domain reputation | List health %
```

### Bước 6: Thiết kế Reporting Features

```
Self-serve requirements:
□ Date range picker (relative: last 7d, 30d, 90d; absolute: custom range)
□ Filter by: campaign, channel, segment, geo, device
□ Drill-down: Click metric → see underlying data
□ Export: CSV, PDF report
□ Scheduled reports: Auto-send to email on schedule

Advanced:
□ Custom dashboard builder (drag-drop widgets)
□ Saved views / bookmarks
□ Annotations: Mark campaign launches, events trên charts
□ Cohort analysis tool
□ Funnel builder (custom funnel steps)
□ Attribution model selector (compare side-by-side)
```

### Bước 7: Feature Spec Output

```markdown
## REQ-IDs
REQ-MKT-ANA-001: Event tracking infrastructure (page view, custom events)
REQ-MKT-ANA-002: UTM capture & preservation through funnel
REQ-MKT-ANA-003: Attribution engine (multi-model support)
REQ-MKT-ANA-004: Campaign data import (Google, Facebook, LinkedIn APIs)
REQ-MKT-ANA-005: Executive dashboard (KPIs, funnel, channel mix)
REQ-MKT-ANA-006: Campaign performance dashboard
REQ-MKT-ANA-007: Content & SEO dashboard
REQ-MKT-ANA-008: Email performance dashboard
REQ-MKT-ANA-009: Custom date range + filtering
REQ-MKT-ANA-010: Export (CSV + scheduled reports)
REQ-MKT-ANA-011: Real-time alerts (budget, performance anomalies)
REQ-MKT-ANA-012: GDPR-compliant data collection (consent-based)
```
