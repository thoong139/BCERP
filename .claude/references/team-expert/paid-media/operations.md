# Paid Media - Operational Analysis Framework

> **Domain**: Paid Media / Quảng cáo Có Trả Phí
> **Last Updated**: 2026-03-19

---

## 1. Core Processes

### Process 1: Campaign Planning

```
Brief → Strategy → Targeting → Creative → Launch
  │         │           │           │         │
  ▼         ▼           ▼           ▼         ▼
Business  Channel    Audience    Ad copy   QA check
goals     mix &      segments    & visual   & go-live
defined   budget     defined     approved   scheduled
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Brief | Marketing Manager | Create campaign brief doc | Business goals, KPIs, budget defined |
| Strategy | Perf. Marketing Manager | Channel allocation plan | ROAS/CPA target per channel set |
| Targeting | Media Buyer / PPC Analyst | Audience builder, keyword planner | Audience size ≥ minimum threshold |
| Creative | Paid Social Specialist + Creative Team | Creative upload per format | Platform spec compliance check |
| Launch | Media Buyer | Campaign publish → tracking verify | UTM parameters active, pixel firing |

---

### Process 2: Campaign Optimization

```
Monitor → Analyze → Adjust → Test → Scale/Pause
    │          │         │        │         │
    ▼          ▼         ▼        ▼         ▼
 Daily      Segment   Bid/     A/B test   Budget
 metrics    breakdown  budget   creative   shift or
 review     by device, changes  variants   kill ad set
            audience,
            placement
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Monitor | Media Buyer | Pull automated performance alerts | CPA/ROAS vs target threshold |
| Analyze | PPC Analyst / Paid Social Specialist | Segment drilldown | Statistical significance for test |
| Adjust | Media Buyer | Bid, budget, audience edits | Log change with timestamp + reason |
| Test | Media Buyer | Create A/B experiment | Control vs variant isolation |
| Scale/Pause | Perf. Marketing Manager | Approve budget shift | Minimum data thresholds met |

---

### Process 3: Budget Management

```
Allocation → Pacing → Reallocation → Reporting → Review
     │           │           │            │           │
     ▼           ▼           ▼            ▼           ▼
Monthly      Daily       Mid-period    Weekly       Quarterly
budget       spend       adjustment    budget vs    strategy
divided      tracking    based on      actual       review
by channel   per account ROAS signal   report       & planning
```

| Step | Owner | Frequency | Data Source |
|------|-------|-----------|-------------|
| Monthly allocation | Growth Lead + Perf. Manager | Monthly | LTV:CAC per channel, targets |
| Daily pacing | Media Buyer | Daily | Platform dashboards |
| Reallocation | Perf. Marketing Manager | Weekly | Performance delta vs plan |
| Reporting | Perf. Marketing Manager | Weekly / Monthly | Cross-platform consolidated data |
| Strategic review | Growth Lead | Quarterly | Channel ROI trends, market data |

---

### Process 4: Reporting & Attribution

```
Data Collection → Consolidation → Attribution → Insights → Action
       │                │               │            │          │
       ▼                ▼               ▼            ▼          ▼
UTM tracking       Cross-platform    Model         Root         Budget or
Pixel events       data aggregation  applied       cause        strategy
CRM match          (BI / dashboard)  (GA4, DDA)    analysis     change
```

| Step | Owner | Tools | Output |
|------|-------|-------|--------|
| Data Collection | Media Buyer | Platform pixels, UTM, GA4 | Raw event data |
| Consolidation | PPC Analyst | BI dashboard, Looker Studio | Unified performance table |
| Attribution | PPC Analyst | GA4 DDA, platform attribution | ROAS per channel after model |
| Insights | Perf. Marketing Manager | Weekly review meeting | Key findings doc |
| Action | Growth Lead | Budget / strategy decision | Updated allocation plan |

---

## 2. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Spend pacing check | Media Buyer | 30 min | Manual login per platform |
| Bid adjustment review | Media Buyer | 45 min | No unified bid management UI |
| CPA / ROAS anomaly check | Perf. Marketing Manager | 20 min | No cross-platform alerting |
| Search term report review | PPC Analyst | 45 min | Manual negative keyword addition |
| Creative fatigue check (frequency) | Paid Social Specialist | 20 min | No automated threshold alert |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Performance review meeting | Full team | 1-2 giờ | Manual report compilation |
| A/B test analysis | Paid Social Specialist / PPC Analyst | 2 giờ | No structured test log |
| Creative refresh planning | Paid Social Specialist | 1 giờ | Dependency on creative team timeline |
| Budget reallocation recommendation | Perf. Marketing Manager | 1 giờ | Spreadsheet-based scenario modeling |
| Competitor auction insights review | PPC Analyst | 30 min | Static export, no trend tracking |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Budget vs. actual reconciliation | Perf. Marketing Manager | 3-4 giờ | Multiple platform exports required |
| Attribution model review | PPC Analyst | 2 giờ | Discrepancy giữa platform vs. GA4 |
| Strategy adjustment | Growth Lead | 2 giờ | Thiếu long-term trend data |
| Audience refresh (CRM sync) | Paid Social Specialist | 1 giờ | Manual upload process |
| Executive performance report | Perf. Marketing Manager | 3 giờ | Manual slide deck preparation |

### Quarterly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Channel strategy review | Growth Lead | 1 ngày | Thiếu LTV:CAC per channel view |
| Annual planning input | Growth Lead + Perf. Manager | 2 ngày | Budget modeling không có tool tốt |
| Competitive landscape analysis | Perf. Marketing Manager | 4 giờ | Data nằm ở nhiều nguồn |
| Attribution model recalibration | PPC Analyst | 4 giờ | Cần đủ data volume (≥300 conv/tháng) |

---

## 3. Decision Support Requirements

### Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| Campaign Performance (daily) | Media Buyer, Specialists | Impressions, Clicks, CTR, Spend, CPA, ROAS |
| Cross-Channel Summary | Perf. Marketing Manager | Total spend, ROAS per channel, pacing % |
| Budget Pacing Tracker | Perf. Marketing Manager | Daily spend vs budget, monthly burn rate |
| Executive Overview | Growth Lead, CMO | Total CAC, LTV:CAC, revenue attributed, MoM trend |
| Creative Performance | Paid Social Specialist | CTR, CVR, Frequency per creative |
| Keyword Performance | PPC Analyst | Quality Score, CPC, Impression Share, top queries |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Daily Performance Snapshot | Daily | Anomaly detection, pacing | Media Buyers, Manager |
| Weekly Channel Report | Weekly | Optimization decisions | Perf. Marketing Manager |
| Creative Test Results | Per test completion | A/B winner determination | Full team |
| Monthly Budget Reconciliation | Monthly | Finance alignment | Manager, Finance |
| Quarterly Channel Strategy Report | Quarterly | Budget strategy review | Growth Lead, CMO |
| Attribution Report | Monthly | Multi-touch credit analysis | Perf. Manager, Growth Lead |

---

## 4. Integration Touchpoints

### Internal Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **CRM (Salesforce, HubSpot)** | CRM → Paid Platforms | Custom audience upload, lead quality feedback |
| **CRM** | Paid → CRM | Lead source attribution, cost per lead |
| **Analytics (GA4)** | Site → GA4 → Ad platforms | Conversion tracking, audience signals |
| **Marketing Automation** | MAP → Paid Platforms | Suppression list, nurture audience exclusion |
| **Finance / Billing** | Finance → Media Team | Budget approval, invoice reconciliation |

### External Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **Google Ads** | Bi-directional | Campaign management, conversion import |
| **Meta Ads Manager** | Bi-directional | Campaign management, CAPI for server-side events |
| **TikTok Ads Manager** | Bi-directional | Campaign management, Events API |
| **LinkedIn Campaign Manager** | Bi-directional | B2B campaign management, Lead Gen Forms |
| **Looker Studio / Supermetrics** | Platforms → Dashboard | Cross-platform reporting consolidation |
| **Third-party attribution (Northbeam, Triple Whale)** | Multi-source → Platform | Multi-touch attribution modeling |

---

## 5. KPIs & Metrics

### Efficiency Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| ROAS | Revenue / Ad Spend | ≥4x (e-commerce), ≥2x (lead gen, revenue-weighted) |
| CPA | Total Ad Spend / Conversions | Per campaign target, vs. LTV threshold |
| CPM | (Ad Spend / Impressions) × 1,000 | Benchmark by platform và industry |
| CTR | Clicks / Impressions × 100 | Search ≥3%, Social ≥0.8%, Display ≥0.15% |
| Conversion Rate | Conversions / Clicks × 100 | Landing page CVR ≥2% (general target) |

### Quality Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Quality Score (Google) | Platform composite (1–10) | ≥7 trên core keywords |
| Impression Share | Impressions / Eligible Impressions | ≥60% (brand), ≥30% (non-brand) |
| Relevance Score / Ad Quality (Meta) | Platform composite rating | Above average on Relevance |
| Landing Page Experience | Platform rating | Above average |

### Growth Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| LTV:CAC ratio | Customer LTV / CAC per channel | ≥3:1 |
| Frequency | Impressions / Unique Reach | ≤3.5 (social awareness), ≤5 (retargeting) |
| Reach | Unique users exposed | Per awareness campaign target |
| CAC | Total Acquisition Cost / New Customers | Per business model CAC threshold |

### Attribution Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Assisted Conversion Rate | Assisted Conversions / Total Conversions | Track per channel, benchmark over time |
| Attribution Accuracy | (Platform-reported conv − CRM actuals) / CRM actuals | Discrepancy <20% |
| View-Through Conversion Rate | View-through conv / Total impressions | Track for awareness channels |
