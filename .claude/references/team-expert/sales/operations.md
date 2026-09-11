# Sales Domain - Operational Analysis Framework

> **Domain**: Sales / Quản trị Bán hàng
> **Last Updated**: 2026-03-07

---

## 1. Sales Process Stages

```
┌───────┐   ┌───────────┐   ┌──────────┐   ┌────────────┐   ┌─────┐
│ Lead  │──▶│ Qualified │──▶│ Proposal │──▶│ Negotiation│──▶│ Won │
└───────┘   └───────────┘   └──────────┘   └────────────┘   └─────┘
     │            │              │               │            │
     ▼            ▼              ▼               ▼            ▼
  Inbound      Discovery      Quote sent    Terms agreed   Contract
  Outbound     Demo done      Revision      Legal review   PO received
  Scoring      Stakeholder    Price final   Signature      Handoff
```

### Stage Definitions

| Stage | Entry Criteria | Exit Criteria | Typical Duration |
|-------|----------------|---------------|------------------|
| **Lead** | Contact created | BANT qualified | 1-7 days |
| **Qualified** | Budget, Authority, Need, Timeline confirmed | Demo scheduled | 7-14 days |
| **Proposal** | Quote sent | Customer feedback received | 7-30 days |
| **Negotiation** | Terms under discussion | Verbal agreement | 14-60 days |
| **Closed Won** | Contract/PO received | Revenue booked | - |
| **Closed Lost** | Deal not proceeding | Analysis complete | - |

### Stage Probability

| Stage | Default Win % | Adjusted By |
|-------|:-------------:|-------------|
| Lead | 10% | Lead score, Source |
| Qualified | 25% | Engagement level |
| Proposal | 50% | Competition, Budget |
| Negotiation | 75% | Decision timeline |
| Closed Won | 100% | - |

---

## 2. Core Sales Processes

### Process 1: Lead to Opportunity

```
Lead Capture → Qualification → Scoring → Assignment → Opportunity
      │             │             │           │            │
      ▼             ▼             ▼           ▼            ▼
   Marketing      BANT         Points      Territory    Sales Rep
   Website        Check        0-100       Rules        Ownership
   Event          Screen       Score       Owner        Creates
```

| Step | Owner | System Actions | Data Required |
|------|-------|----------------|---------------|
| Capture | Marketing | Create lead record | Contact info, Source |
| Qualify | Inside Sales | BANT checklist | Budget, Authority, Need, Timeline |
| Score | System | Auto-score based on rules | Company size, Industry, Behavior |
| Assign | System | Territory rules | Geographic, Industry, Product |
| Convert | Rep | Create opportunity | Opportunity name, Value, Close date |

### Process 2: Quotation to Order

```
Quote Request → Configuration → Pricing → Approval → Send → Revise → Accept → Order
      │              │             │          │        │        │       │       │
      ▼              ▼             ▼          ▼        ▼        ▼       ▼       ▼
   Rep/System     Product       Margin    Workflow  Customer  Customer  Rep    System
   identifies     selection     Check     If needed  Reviews  Feedback  Wins   Creates
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Request | Rep | Create quote record | Opportunity linked |
| Configure | Rep | Product selector | Availability check |
| Price | System | Apply price book | Margin calculation |
| Approve | Manager | Approval workflow | Per discount matrix |
| Send | Rep | Email with tracking | Version locked |
| Revise | Rep | Create new version | Link to previous |
| Accept | Customer | E-signature / PO | Contract terms |
| Order | System | Create sales order | Credit check |

### Process 3: Forecast Management

```
Pipeline Review → Commit Analysis → Forecast Rollup → Submission → Actuals
       │               │                 │               │           │
       ▼               ▼                 ▼               ▼           ▼
   Rep reviews      Identify          Manager         Director    Compare
   opportunities    Commits           aggregates      reviews     vs Forecast
   weekly           Best Bets         team forecast   submits     for accuracy
```

| Step | Frequency | Participants | Output |
|------|-----------|--------------|--------|
| Pipeline review | Weekly | Rep + Manager | Clean pipeline |
| Commit analysis | Weekly | Rep | Commit vs Best case |
| Team rollup | Weekly | Manager | Team forecast |
| Division rollup | Monthly | Director | Division forecast |
| Final submission | End of period | Director | Official forecast |

### Process 4: Deal Desk (Complex Deals)

```
Request → Triage → Analysis → Approval → Documentation → Execute
    │        │         │          │            │            │
    ▼        ▼         ▼          ▼            ▼            ▼
  Rep      Deal      Finance    Deal         Contract     Order
  submits  Desk      Legal      Committee    Generated    Created
           assigns   Reviews    Decides      Sent         Per Terms
```

| Step | Owner | Actions | SLA |
|------|-------|---------|-----|
| Request | Rep | Submit deal details | - |
| Triage | Deal Desk | Assign complexity level | 4 hours |
| Analysis | Finance/Legal | Risk assessment | 24-48 hours |
| Approval | Committee | Go/No-go decision | Per calendar |
| Documentation | Legal | Contract generation | 24 hours |
| Execute | Rep | Get signature | Per deal |

---

## 3. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Update opportunities | Sales Rep | 30 min | Manual entry |
| Follow-up calls | Sales Rep | 2-3 hours | No call logging |
| Email prospects | Sales Rep | 1 hour | No templates |
| Review pipeline | Sales Manager | 30 min | Manual reports |
| Process approvals | Sales Manager | 30 min | Slow turnaround |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Pipeline review meeting | Team | 1-2 hours | Manual prep |
| Forecast submission | Manager | 1 hour | Spreadsheet work |
| Lead follow-up | Inside Sales | Ongoing | No prioritization |
| Quote follow-up | Sales Rep | 1 hour | No tracking |
| Activity report | Sales Rep | 15 min | Manual logging |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Commission calculation | Sales Ops | 4-8 hours | Manual errors |
| Territory review | Manager | 2 hours | No data support |
| Performance review | Director | 4 hours | Manual reports |
| Win/Loss analysis | Sales Ops | 2 hours | Data scattered |

### Quarterly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Quota setting | Director | 1 day | Manual analysis |
| Territory realignment | Director + Ops | 2 days | Disruption |
| Commission plan review | Director + Finance | 1 day | Complex rules |
| Strategic account review | Director | 4 hours | No system support |

---

## 4. Decision Support Requirements

### Real-Time Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| Rep Pipeline | Sales Rep | Own pipeline by stage, Activities, Quota attainment |
| Team Pipeline | Sales Manager | Team pipeline, Forecast, Win rate |
| Revenue | Sales Director | Bookings vs Target, Pipeline coverage, Forecast accuracy |
| Executive | C-Suite | Revenue, Growth, Top deals, Conversion |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Pipeline Snapshot | Daily | Current state | Reps, Managers |
| Forecast vs Actual | Weekly | Accuracy tracking | Managers, Directors |
| Win/Loss Analysis | Monthly | Competitive insights | Directors, Marketing |
| Activity Metrics | Weekly | Rep productivity | Managers |
| Quota Attainment | Monthly | Performance tracking | All levels |
| Commission Statement | Monthly | Payment calculation | Reps, Finance |

---

## 5. Integration Touchpoints

### Internal Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **Marketing Automation** | Marketing → Sales | Lead handoff, Campaign engagement |
| **ERP/Finance** | Bi-directional | Orders, Invoicing, Credit check |
| **Inventory** | ERP → CRM | Availability, Pricing |
| **Customer Success** | CRM → CS | Account handoff, Usage data |

### External Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **LinkedIn** | Bi-directional | Contact enrichment, Outreach |
| **E-signature** | CRM → Vendor | Contract signing |
| **Communication** | Bi-directional | Email/Call logging |
| **Data Enrichment** | Vendor → CRM | Company info, Contacts |

---

## 6. KPIs & Metrics

### Revenue Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Revenue | Sum of closed won | Per quota |
| Revenue vs Target | Revenue / Target × 100 | ≥100% |
| Average Deal Size | Revenue / # Deals | Track over time |
| Revenue per Rep | Total revenue / # Reps | Per quota |

### Pipeline Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Pipeline Value | Sum of open opportunities | 3-4x quota |
| Pipeline Coverage | Pipeline / Remaining quota | ≥3x |
| Pipeline Velocity | Value × Win rate / Cycle time | Track over time |
| Stage Conversion | Moved to next / Total in stage | Per stage target |

### Efficiency Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Win Rate | Won / (Won + Lost) | >30% |
| Sales Cycle | Avg days from lead to close | <60 days |
| Time to First Response | Avg time to lead response | <1 hour |
| Quote Turnaround | Avg time from request to sent | <24 hours |

### Activity Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Calls per Day | Total calls / # days | Per role |
| Emails per Day | Total emails / # days | Per role |
| Meetings per Week | Total meetings / # weeks | Per role |
| Proposal Rate | Proposals / Opportunities | >50% |

### Forecast Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Forecast Accuracy | 1 - \|Actual - Forecast\| / Actual | >90% |
| Commit Accuracy | 1 - \|Actual - Commit\| / Commit | >95% |
| Upside Capture | Actual - Commit / (Best case - Commit) | Track over time |

---

## Quick Reference: Sales Cycle by Deal Size

| Deal Size | Typical Cycle | Key Activities | Decision Makers |
|-----------|---------------|----------------|-----------------|
| <50M VND | 7-14 days | Demo, Quick quote | User, Manager |
| 50M-200M VND | 14-30 days | Discovery, Proposal, Negotiation | Manager, Director |
| 200M-1B VND | 30-90 days | RFP, Demo, POC, Legal | Director, CFO |
| >1B VND | 60-180 days | Strategic review, Executive sponsor | C-Suite, Board |
