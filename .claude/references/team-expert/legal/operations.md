# Legal Domain - Operational Analysis Framework

> **Domain**: Legal / Pháp lý và Compliance
> **Last Updated**: 2026-03-07

---

## 1. Contract Lifecycle Management

```
┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐
│  Request   │──▶│   Draft    │──▶│  Negotiate │──▶│   Execute  │──▶│  Monitor   │
└────────────┘   └────────────┘   └────────────┘   └────────────┘   └────────────┘
      │                │                │                │                │
      ▼                ▼                ▼                ▼                ▼
   Business         Template         Version           Sign             Renewal
   Submits          Selection        Tracking          Archive          Alerts
   Request          Customization     Redline           Store            Compliance
```

### Stage Details

| Stage | Duration | Activities | Output |
|-------|----------|------------|--------|
| **Request** | 1 day | Capture requirements, Identify template | Request ticket |
| **Draft** | 1-5 days | Select template, Customize, Internal review | Draft contract |
| **Negotiate** | 1-30 days | Exchange versions, Track changes, Agree terms | Final draft |
| **Execute** | 1-5 days | Obtain approvals, Sign, Distribute | Signed contract |
| **Monitor** | Ongoing | Track obligations, Manage renewals, Compliance | Status updates |

---

## 2. Core Legal Processes

### Process 1: Contract Request & Drafting

```
Request → Triage → Template → Draft → Review → Revise
    │        │         │         │        │        │
    ▼        ▼         ▼         ▼        ▼        ▼
 Business  Admin    Select    Populate  Counsel  Incorporate
 Submit    Assigns  Template  Fields    Reviews  Feedback
```

| Step | Owner | System Actions | SLA |
|------|-------|----------------|-----|
| Request | Business | Create ticket, Capture details | - |
| Triage | Contract Admin | Assign to counsel, Set priority | <4 hours |
| Template | Counsel | Select appropriate template | <1 day |
| Draft | Counsel | Populate with specific terms | 1-3 days |
| Review | Counsel | Quality check, Risk assessment | <1 day |
| Revise | Counsel | Finalize draft | <1 day |

### Process 2: Contract Negotiation

```
Send → Review → Redline → Counter → Agree → Final
  │       │        │         │        │       │
  ▼       ▼        ▼         ▼        ▼       ▼
Share   Counter   Mark-up   Respond  Terms   Clean
Draft   Party     Changes   to       Locked  Version
        Reviews             Changes
```

| Step | Activities | Tracking |
|------|------------|----------|
| Send | Share draft via secure channel | Timestamp, Recipient |
| Review | Counterparty reviews terms | Response deadline |
| Redline | Mark changes, Add comments | Version number |
| Counter | Respond to proposed changes | Comparison view |
| Agree | Finalize all terms | Version lock |
| Final | Generate clean version for signature | Final status |

### Process 3: Contract Execution

```
Approvals → Signature → Distribution → Archival
    │          │             │            │
    ▼          ▼             ▼            ▼
 Per matrix   E-sign or    Send copies   Store in
 required     Wet ink      to parties    repository
```

| Step | Owner | Actions |
|------|-------|---------|
| Approvals | Managers | Approve per authorization matrix |
| Signature | Authorized signatories | Sign via e-signature or wet ink |
| Distribution | Contract Admin | Send executed copies to all parties |
| Archival | System | Store in repository, Set alerts |

### Process 4: Compliance Monitoring

```
Calendar → Review → Assess → Report → Remediate
    │        │        │        │         │
    ▼        ▼        ▼        ▼         ▼
 Track    Check    Identify  Document  Address
 Deadlines Status   Gaps      Findings  Issues
```

| Activity | Frequency | Owner | Output |
|----------|-----------|-------|--------|
| Deadline tracking | Daily | System | Alerts |
| Status review | Weekly | Compliance | Dashboard |
| Gap assessment | Monthly | Compliance | Gap report |
| Management report | Monthly | Compliance Officer | Status report |
| Remediation | As needed | Business + Legal | Resolution |

---

## 3. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Review contract requests | Contract Admin | 1 hour | Manual triage |
| Draft/review contracts | Counsel | 4-5 hours | No templates |
| Respond to legal queries | Counsel | 2 hours | Scattered requests |
| Track deadlines | Compliance | 30 min | Spreadsheet |
| Monitor inbox | All | 1 hour | Email overload |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Contract status review | Legal Manager | 2 hours | Manual tracking |
| Compliance check | Compliance | 2 hours | No automation |
| Team meeting | Legal Manager | 1 hour | - |
| Regulatory update scan | Compliance | 2 hours | Manual research |
| Report to leadership | Legal Manager | 1 hour | Manual compilation |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Contract renewal review | Contract Admin | 2 hours | Manual alerts |
| Compliance reporting | Compliance | 4 hours | Manual data |
| Policy review | Compliance | 2 hours | No version control |
| Legal spend tracking | Legal Manager | 1 hour | Spreadsheet |
| Training compliance | Compliance + HR | 2 hours | Manual tracking |

### Annual Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Template review | Counsel | 8 hours | Manual update |
| Retention cleanup | Contract Admin | 4 hours | Manual process |
| Compliance audit | Compliance | 1-2 days | Document gathering |
| Legal strategy | Legal Director | 1 day | Manual analysis |
| Policy overhaul | Compliance | 2 days | No change tracking |

---

## 4. Decision Support Requirements

### Real-Time Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| Contract Pipeline | Legal Manager | Draft, Review, Pending signature |
| Compliance Status | Compliance | Deadlines, Overdue items, Risk areas |
| Legal Operations | Legal Director | Workload, Turnaround, Spend |
| Team Performance | Legal Manager | SLA compliance, Volume |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Contract status | Weekly | Track pipeline | Legal team |
| Compliance calendar | Weekly | Upcoming deadlines | Compliance |
| Legal spend | Monthly | Budget tracking | Legal Director, Finance |
| Contract summary | Monthly | New, Expiring, Renewed | Leadership |
| Risk report | Quarterly | Legal risks overview | Leadership |
| Compliance report | Quarterly | Compliance status | Board/Audit committee |

---

## 5. Integration Touchpoints

### Internal Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **HR** | Bi-directional | Employment contracts, Policy training |
| **Sales/CRM** | Sales → Legal | Customer contracts, Terms |
| **Procurement** | Procurement → Legal | Vendor contracts, Terms |
| **Finance** | Bi-directional | Contract values, Legal spend |
| **Document Management** | Bi-directional | Centralized storage |

### External Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **E-signature** | Bi-directional | Digital signing |
| **Court systems** | Read-only | Case tracking |
| **Regulatory databases** | Read-only | Compliance updates |
| **External counsel** | Bi-directional | Matter management |

---

## 6. KPIs & Metrics

### Contract Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Contract turnaround time | Days from request to signature | <14 days (standard) |
| Template usage | Template-based / Total contracts | >80% |
| Contract accuracy | Error-free / Total contracts | >98% |
| Renewal rate | Renewed / Expiring contracts | Per business |

### Compliance Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Deadline compliance | On-time / Total deadlines | 100% |
| Training completion | Completed / Required | >95% |
| Policy acknowledgment | Acknowledged / Required | 100% |
| Audit findings | Open / Total findings | <5 open |

### Efficiency Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Contract volume | Contracts processed / Period | Track over time |
| Cost per contract | Legal spend / Contracts | Track over time |
| Legal spend vs budget | Spend / Budget | ≤100% |
| Self-service rate | Self-service / Total requests | >50% (basic) |

---

## Quick Reference: Contract Turnaround by Type

| Contract Type | Typical Duration | Complexity Factors |
|---------------|------------------|-------------------|
| NDA | 1-3 days | Standard vs mutual |
| Simple agreement | 3-7 days | Standard terms |
| Vendor contract | 7-14 days | Custom terms, Value |
| Customer contract | 7-21 days | Negotiation length |
| Partnership | 30-60 days | Multiple parties, Complex terms |
| M&A | 60-180 days | Due diligence, Regulatory |

## Quick Reference: Compliance Calendar Template

| Month | Key Deadlines | Responsible | Status |
|-------|---------------|-------------|--------|
| January | Annual report prep, License renewals | Company Sec | |
| February | Tax filings, Policy review | Finance + Legal | |
| March | Q1 compliance review | Compliance | |
| April | Annual report filing, Training audit | Company Sec + HR | |
| May | Data protection review | Compliance + IT | |
| June | Q2 compliance review, Mid-year audit | Compliance | |
| July | License renewals, Contract review | Legal | |
| August | Regulatory update assessment | Compliance | |
| September | Q3 compliance review | Compliance | |
| October | Budget planning, Policy updates | Legal Director | |
| November | Year-end prep, Training completion | All | |
| December | Year-end compliance, Planning | Compliance | |
