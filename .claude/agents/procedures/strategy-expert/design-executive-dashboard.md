# Playbook: Thiết kế Executive Dashboard

> **Type**: Agent Procedure
> **Agent**: strategy-expert
> **Triggered by**: /wf-design khi cần thiết kế Executive Dashboard hoặc C-suite KPI system
> **Output**: `.mc-data/docs/phase3-architecture/strategy/executive-dashboard.md`

---

## Khi nào dùng playbook này

- Khi cần spec module "Executive Dashboard", "CEO Morning Report", "C-suite KPI system", "Management Cockpit"
- Khi cần thiết kế consolidated reporting với drill-down capability
- Khi requirements include: real-time KPI visibility, mobile-first C-suite view, exception alerting

---

## Procedure

### Bước 1: Xác định dashboard audience và access tiers

```
INPUT: Paths do skill cung cấp qua prompt + strategy-requirements.md từ Phase 1
FALLBACK: tra .mc-data/docs/phase1-business/strategy-requirements.md

Xác định rõ access tiers:

CEO VIEW:
  - Scope: Company level + All BUs
  - Refresh: Real-time (operational KPIs) + T+1 (financial)
  - Device: Mobile-first (iOS/Android) + Desktop
  - Priority: Max 5 KPIs on first screen, swipe/click for more

CFO VIEW:
  - Scope: Financial KPIs + Treasury + Subsidiary financials
  - Refresh: T+1 (financial close) + Real-time (treasury)
  - Device: Desktop-first
  - Priority: Variance vs budget, drill-down to transaction

BOARD VIEW (nếu applicable):
  - Scope: Quarterly, high-level, governance-focused
  - Refresh: Monthly/Quarterly (pre-meeting)
  - Device: Board portal (secure, encrypted)
  - Priority: Traffic light summary, board pack integration

BU HEAD VIEW:
  - Scope: Own BU full + Company aggregates (NO other BU details)
  - Refresh: Daily
  - Device: Desktop + Mobile
  - Priority: BU KPIs vs target, OKR score, budget variance
```

### Bước 2: KPI taxonomy và data hierarchy

```
READ: .claude/references/team-expert/strategy/operations.md → Section 7: KPIs by Level

Thiết kế KPI hierarchy:

LEVEL 1 — Company (HĐQT / CEO):
  □ Revenue (consolidated)
  □ EBITDA & EBITDA margin
  □ ROIC
  □ Net Debt / EBITDA
  □ Strategic Initiative Completion Rate
  □ Employee NPS

LEVEL 2 — BU (CEO / BU Head):
  □ BU Revenue & growth
  □ BU EBITDA margin
  □ Market Share
  □ Customer Satisfaction (NPS/CSAT)
  □ OKR Score (quarterly)

LEVEL 3 — Function (BU Head / Function Head):
  □ Function-specific KPIs (Sales: Win rate, Pipeline; Finance: DSO/DPO; HR: Attrition)

Drill-down paths:
  L1 Company KPI → L2 BU breakdown → L3 Function detail → Transaction/record level

Cho mỗi KPI, xác định:
  - metric_name, description, formula
  - data_source (ERP, CRM, HRIS, manual input)
  - refresh_frequency (real-time / T+1 / manual)
  - owner (responsible for data accuracy)
  - target_value, target_type (absolute/percentage/score)
```

### Bước 3: Data architecture

```
Xác định data sources và integration:

ERP / Finance system → Financial KPIs (Revenue, EBITDA, CAPEX)
  Refresh: T+1 sau month-end
  Integration: API pull hoặc scheduled batch

CRM → Sales KPIs (Win rate, Pipeline, Customer satisfaction)
  Refresh: Real-time hoặc hourly
  Integration: API pull

HRIS / HR system → People KPIs (Headcount, Attrition, Employee NPS)
  Refresh: Daily hoặc monthly (per HRIS capability)
  Integration: API pull hoặc file sync

OKR system → OKR scores, Initiative progress
  Refresh: Weekly (post check-in)
  Integration: Internal module

Manual inputs → Strategic KPIs without system source
  (Market share estimates, strategic initiative milestones)
  Input: Online form, approval before publish

Aggregation rules (document clearly):
  □ Currency: Functional currency (VND) — conversion rate policy
  □ Intercompany: Elimination logic cho consolidated view
  □ Minority interest: Handling trong group KPIs
  □ Restatement: Policy khi historical data changes
```

### Bước 4: Visualization và UX design specs

```
READ: .claude/references/team-expert/strategy/personas.md → CEO, CFO sections

KPI Card Design:
  □ Current value (large, prominent)
  □ Target value
  □ Variance (absolute + %)
  □ Trend sparkline (last 6-12 data points)
  □ Traffic light: Green (≥100% target) / Amber (80-99%) / Red (<80%)
  □ Period label (MTD / QTD / YTD)

Traffic Light Logic:
  Green: Actual ≥ Target × 100%
  Amber: Actual ≥ Target × 80%
  Red: Actual < Target × 80%
  (Configurable per KPI — some KPIs: lower = better, e.g., cost KPIs)

Mobile-first layout (CEO use case):
  □ Screen 1: Top 5 most critical KPIs (configurable per user)
  □ Swipe right: Next group of 5 KPIs
  □ Tap KPI card → drill-down to L2 BU breakdown
  □ Exception alerts: Push notification when KPI turns Red

Desktop layout (CFO/Strategy Manager):
  □ Full dashboard grid: 12-15 KPIs visible without scroll
  □ Side panel: Exception list (all Red + Amber KPIs)
  □ Filter: Period, BU, Perspective (Financial/Customer/Process/People)
  □ Comparison: Actual vs Budget vs Last Year vs Forecast

Export specs:
  □ PDF: Board pack format (pre-defined template, company branding)
  □ Excel: Raw data với all KPIs, all periods (CFO analysis)
  □ PNG: Individual KPI cards (for presentation embedding)
```

### Bước 5: Access control và security specs

```
READ: .claude/references/team-expert/strategy/controls.md → Section 5: Executive Dashboard Access Controls

Security requirements:

RBAC Data Filtering (server-side, NOT UI-only):
  □ CEO: All data (Company + All BUs + Subsidiaries)
  □ CFO: All financial data + All BU financial data
  □ Board: Summary level only + Board Confidential tier (encrypted)
  □ BU Head: Own BU full + Company aggregates (BU peers blinded)
  □ Strategy Manager: OKR + Initiative data all BUs, Financial = aggregated only

Technical security:
  □ Session timeout: 30 minutes inactive
  □ MFA: Required for CEO, CFO, Board roles
  □ Board portal: Encrypted at rest + in transit, remote wipe capable
  □ No screenshot/clipboard for Board Confidential docs (DRM controls)
  □ Audit log: Every access, export, sharing action logged

API contracts to define (coordinate với architect + data-expert):
  □ GET /api/kpi/{level}/{period} → returns KPIs per access role
  □ GET /api/kpi/{kpiId}/drill-down → returns sub-level breakdown
  □ GET /api/exceptions/active → returns Red + Amber KPIs
  □ POST /api/export/board-pack → generates PDF board pack
  □ GET /api/audit-log → admin access only
```

---

## Output Structure

```markdown
# Executive Dashboard Design

## 1. Dashboard Architecture Overview
[Diagram: User roles → Access tiers → Data layers]

## 2. KPI Taxonomy
[Table: KPI / Level / Formula / Source / Refresh / Owner / Target]

## 3. Data Integration Specs
[Per source: connection type, refresh frequency, transformation rules]

## 4. Screen Designs (wireframe-level)
[Per role: layout, KPI cards visible, drill-down paths, mobile vs desktop]

## 5. Access Control Matrix
[Role / Company data / BU data / Financial / M&A / Actions allowed]

## 6. API Contracts
[Endpoints, request/response schemas, authentication]

## 7. Performance Requirements
[Load time targets, data freshness SLAs, concurrent user capacity]

## 8. Open Technical Questions
[Items for architect + data-expert to resolve]
```

---

## Checklist trước khi submit

```
□ Access tiers defined và mapped to roles (không chỉ UI — phải server-side)
□ KPI hierarchy L1/L2/L3 đầy đủ với formula và data source
□ Refresh frequency đã defined cho mỗi KPI (không để "real-time" vague)
□ Mobile layout spec cho CEO use case (max 5 KPIs first screen)
□ Traffic light thresholds configurable (không hardcode)
□ Audit log spec đầy đủ
□ Export formats (PDF/Excel) spec đầy đủ
□ API contracts drafted để data-expert + architect có thể pick up
□ Performance requirements: dashboard load < 3 giây
□ Board portal security requirements nếu applicable
```
