# Data & Analytics - Operational Analysis Framework

> **Domain**: Data & Analytics / Dữ liệu & Phân tích
> **Last Updated**: 2026-03-19

---

## 1. Core Processes

### Process 1: Data Collection & Ingestion

```
[Source Systems] → [Extraction] → [Landing Zone] → [Validation] → [Data Warehouse]
      │                │               │                │                │
      ▼                ▼               ▼                ▼                ▼
  CRM, ERP,       API pull /      Raw storage      Schema check,    Curated,
  POS, Logs,      CDC, Batch,     (S3, ADLS,       null checks,     partitioned,
  3rd-party       Streaming       GCS)             dedup             indexed
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Extraction | BI Engineer | API call / CDC capture / file export | Row count vs source, checksum |
| Landing | BI Engineer | Write to raw zone with timestamp | File integrity check |
| Schema validation | BI Engineer | Compare against expected schema | Alert on column drift |
| Transformation | BI Engineer | Apply business rules, join dimensions | Data quality tests (dbt) |
| Load to warehouse | BI Engineer | Upsert / append to fact/dim tables | Unique key constraints |

---

### Process 2: Data Modeling & Warehousing

```
[Raw Layer] → [Staging Layer] → [Core Layer] → [Data Mart] → [Reporting Layer]
     │               │               │               │               │
     ▼               ▼               ▼               ▼               ▼
  Source-        Cleaned,        Fact Tables,    Department-    Aggregated,
  aligned        typed,          Dimension       specific       pre-joined
  replica        renamed         Tables          views          views
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Staging models | BI Engineer | Rename, cast types, deduplicate | Not null, accepted values |
| Core fact tables | BI Engineer | Grain definition, foreign keys | Referential integrity tests |
| Dimension tables (SCD) | BI Engineer | Track slowly changing attributes | Uniqueness on natural key |
| Data mart build | BI Engineer | Denormalize for query performance | Row count reconciliation vs core |
| Reporting views | Data Analyst / BI Engineer | Metric calculations, aggregations | Business rule verification |

---

### Process 3: Report & Dashboard Development

```
[Business Request] → [Requirements] → [Data Availability] → [Build] → [QA] → [Publish] → [Monitor]
        │                  │                  │                 │         │        │            │
        ▼                  ▼                  ▼                 ▼         ▼        ▼            ▼
  Stakeholder          KPI definition,    Check data        Dashboard  Data     Manager     Usage
  ad-hoc or            audience,          model exists      / Report   accuracy  approval   tracking
  recurring            refresh rate       or needs build    build      check     sign-off
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Intake & triage | Analytics Manager | Log in backlog, assign priority | Business justification present |
| KPI definition | Data Analyst + Stakeholder | Document metric formula, data source | Sign-off on definition |
| Data model check | BI Engineer | Verify data availability in warehouse | Gap analysis documented |
| Build | Data Analyst | Create dashboard / report in BI tool | Visual QA, number spot-check |
| QA review | Analytics Manager | Cross-check numbers vs source | Tolerance ±0.1% for aggregates |
| Publish | Analytics Manager | Move to production environment | Access permissions set |
| Monitor | Data Analyst | Track views, exports, user feedback | Adoption report monthly |

---

### Process 4: Data Quality Management

```
[Profiling] → [Rule Definition] → [Automated Tests] → [Alerting] → [Remediation] → [Reporting]
     │                │                  │                 │               │               │
     ▼                ▼                  ▼                 ▼               ▼               ▼
  Null rates,      Thresholds,        dbt tests,        Slack /        Root cause      DQ score
  duplicates,      expected           Great              email          analysis,       dashboard,
  distributions    ranges             Expectations       alerts         backfill         SLA report
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Profiling | BI Engineer | Run column statistics, anomaly detection | Baseline documented |
| Rule definition | BI Engineer + Data Analyst | Codify business rules as tests | Peer review |
| Test execution | Automated (dbt, CI/CD) | Run on every pipeline run | Pass/fail report |
| Alert dispatch | Automated | Notify on-call BI Engineer | Alert routed within 15 min |
| Remediation | BI Engineer | Fix source or transformation | Incident log updated |
| DQ score report | Data Analyst | Aggregate test results weekly | Stakeholder distribution |

---

## 2. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Pipeline health check | BI Engineer | 15-30 min | Alert fatigue từ false positives |
| Monitor data freshness | BI Engineer | 10 min | Không có centralized observability dashboard |
| Respond to ad-hoc data requests | Data Analyst | 1-3 giờ | Interrupt-driven, breaks planned work |
| Update daily ops dashboards | Data Analyst | 15-30 min | Manual refresh nếu pipeline chậm |
| Review data quality alerts | BI Engineer | 20 min | Khó phân biệt critical vs noise |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Weekly performance report | Data Analyst | 2-4 giờ | Số liệu không nhất quán giữa sources |
| Pipeline performance review | BI Engineer | 1 giờ | Query cost tracking không tự động |
| Stakeholder sync on analytics backlog | Analytics Manager | 1 giờ | Priority shifting thường xuyên |
| Data quality score review | Data Analyst | 30 min | Thiếu historical trend để so sánh |
| New dashboard/report QA | Data Analyst | 1-2 giờ | Không có standardized QA checklist |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Monthly business review pack | Data Analyst | 1-2 ngày | Tổng hợp từ nhiều sources thủ công |
| Dashboard audit (unused/stale) | Analytics Manager | 3-4 giờ | Không có usage metadata |
| Data catalog update | BI Engineer | 2-3 giờ | Documentation thường bị bỏ qua |
| Access review & cleanup | Analytics Manager | 2 giờ | Không có automated deprovisioning |
| Cost optimization review | BI Engineer | 2 giờ | Difficult to attribute query costs per team |

### Quarterly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| KPI framework review | Analytics Manager | 1-2 ngày | Alignment giữa business units khó đạt |
| BI tool evaluation | Analytics Manager | 1 tuần | ROI khó đo |
| Data governance policy update | Analytics Manager | 3-4 giờ | Policy enforcement manual |
| Capacity planning (warehouse) | BI Engineer | 1 ngày | Tăng trưởng data khó dự đoán |
| Analytics team OKR review | Analytics Manager | 2 giờ | Output metrics vs outcome metrics confusion |

---

## 3. Decision Support Requirements

### Dashboards

| Dashboard | Audience | Key Metrics | Refresh Rate |
|-----------|----------|-------------|--------------|
| Executive KPI Dashboard | C-level, VP | Revenue, MAU, NPS, Churn Rate, Gross Margin | Daily |
| Operations Dashboard | Department Managers | SLA compliance, throughput, error rate | Hourly |
| Sales Performance Dashboard | Sales Manager, Reps | Pipeline, Win Rate, Quota Attainment, ACV | Daily |
| Marketing Attribution Dashboard | Marketing Manager | CAC, ROAS, Conversion by Channel | Daily |
| Data Quality Dashboard | Analytics Manager, BI Engineer | DQ Score, failed tests, freshness SLA | Real-time |
| Cost & Infrastructure Dashboard | BI Engineer, Head of Data | Compute cost, storage growth, query volume | Daily |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Daily Ops Summary | Daily, 08:00 | Snapshot of prior day performance | Department Managers |
| Weekly Business Review | Monday, 09:00 | Week-over-week trend analysis | VP level |
| Monthly Deep-dive | 1st business day/month | Root cause analysis of key metrics | All stakeholders |
| Quarterly Analytics ROI | End of quarter | Measure analytics team impact | C-level |
| Ad-hoc Analysis | On request | Answer specific business questions | Requestor |

---

## 4. Integration Touchpoints

### Source Systems (Inbound)

| System | Data Flow | Data Type | Frequency |
|--------|-----------|-----------|-----------|
| CRM (Salesforce, HubSpot) | Source → Warehouse | Customer, Deal, Activity | Daily batch / CDC |
| ERP (SAP, Oracle) | Source → Warehouse | Financial, Inventory, Order | Daily batch |
| POS / E-commerce Platform | Source → Warehouse | Transaction, Product, Customer | Real-time / Hourly |
| Marketing Platforms (GA4, Meta Ads) | API pull → Warehouse | Campaign metrics, Events | Daily |
| Product Analytics (Mixpanel, Amplitude) | API pull → Warehouse | User behavior, Feature usage | Daily |
| Support System (Zendesk, Freshdesk) | API pull → Warehouse | Tickets, SLA, CSAT | Daily |

### Analytics Tools (Outbound / Internal)

| System | Data Flow | Purpose |
|--------|-----------|---------|
| BI Platform (Tableau, Power BI, Looker) | Warehouse → BI | Dashboard & report delivery |
| Reverse ETL (Census, Hightouch) | Warehouse → CRM/Marketing | Operationalize analytics |
| Alerting (PagerDuty, Slack) | Pipeline → Notification | Incident notification |
| Data Catalog (Alation, DataHub) | Warehouse metadata → Catalog | Documentation & discovery |
| dbt Cloud | Warehouse ↔ Transformation | ELT transformation layer |

---

## 5. KPIs & Metrics

### Data Freshness Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Pipeline SLA compliance | (Pipelines delivered on time / Total pipelines) × 100 | ≥ 99% |
| Data freshness lag | Current time − max(last_loaded_at) per table | ≤ 4 giờ (batch), ≤ 15 min (real-time) |
| Pipeline failure rate | (Failed runs / Total runs) × 100 | ≤ 1% |
| Mean Time to Recovery (MTTR) | Avg time from alert to pipeline restored | ≤ 2 giờ |

### Query Performance Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Dashboard load time (P95) | 95th percentile load time in BI tool | ≤ 5 giây |
| Query execution time (median) | Median SQL query runtime on warehouse | ≤ 30 giây |
| Long-running query rate | (Queries > 5 min / Total queries) × 100 | ≤ 5% |
| Warehouse compute cost per query | Total compute cost / Query count | Trending down QoQ |

### Dashboard Adoption Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Monthly Active Dashboard Users | Unique users viewing dashboards / 30 ngày | ≥ 70% của licensed users |
| Dashboard view frequency | Total views / Active dashboards / Month | ≥ 20 views/dashboard/month |
| Report export rate | Export events / Total dashboard views | ≥ 15% |
| Self-service query rate | Ad-hoc queries by business users / Total queries | Tăng QoQ |

### Data Quality Score

| Metric | Formula | Target |
|--------|---------|--------|
| Overall DQ score | (Passed tests / Total tests) × 100 | ≥ 98% |
| Null rate (critical fields) | NULL values / Total rows per critical column | ≤ 0.1% |
| Duplicate rate | Duplicate rows / Total rows per entity | ≤ 0.01% |
| Referential integrity pass rate | (FK valid / Total FK checks) × 100 | 100% |
