# Customer - Operational Analysis Framework

> **Domain**: Customer / Khách hàng
> **Last Updated**: 2026-03-19

---

## 1. Core Processes

### Process 1: Customer Onboarding

```
[Contract Signed] → [Account Setup] → [Kickoff Call] → [Training] → [Go-Live] → [30-Day Review]
       │                  │                 │               │             │              │
       ▼                  ▼                 ▼               ▼             ▼              ▼
  CRM updated       Provisioning       Goals set       KB + demo     Milestone       Health score
  CSM assigned      credentials        success         sessions      confirmed       established
                    sent               criteria
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Account Setup | CSM + IT | Provision accounts, send credentials | Login confirmed within 48h |
| Kickoff Call | CSM | Log call notes in CRM, set onboarding milestones | Success criteria documented |
| Training | CSM | Track module completion, send KB links | Completion rate ≥80% |
| Go-Live | CSM + Customer | Enable production features, monitor first-week usage | Usage event detected |
| 30-Day Review | CSM | Pull usage report, review KPIs vs goals | Health score ≥70 |

---

### Process 2: Ticket Management

```
[Ticket Created] → [Auto-Triage] → [Assignment] → [Investigation] → [Resolution] → [Closure]
       │                │               │                │                │              │
       ▼                ▼               ▼                ▼                ▼              ▼
  Channel logged   Priority set    Agent notified   Workaround or    Customer        CSAT
  (email/chat/     Category        SLA clock        escalation       informed        survey
   portal/phone)   assigned        starts           path chosen      + ticket        sent
                                                                     updated
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Auto-Triage | System | Detect channel, apply routing rules | Priority and category set |
| Assignment | System / Team Lead | Route to agent by skill + load | Agent accepts within 5 min |
| Investigation | Agent T1 | Search KB, check account history | KB article referenced or escalation triggered |
| Resolution | Agent T1 / T2 | Apply fix or workaround | Customer confirms resolution |
| Closure | System | Send CSAT survey, archive ticket | CSAT response received or 48h timeout |

---

### Process 3: Escalation

```
[Escalation Trigger] → [Handoff] → [Tier 2 Investigation] → [Resolution / Workaround] → [Root Cause Log]
         │                 │                  │                          │                      │
         ▼                 ▼                  ▼                          ▼                      ▼
  Criteria met       Context transfer    Technical deep-dive         Customer              Known-issue
  (complexity,       with full history   or Product bug report       notified              KB updated
   SLA risk,                             filed
   VIP account)
```

| Escalation Trigger | From | To | SLA Impact |
|--------------------|------|----|------------|
| Technical complexity beyond KB | T1 Agent | T2 Engineer | New SLA clock from handoff |
| VIP / Enterprise account flag | T1 Agent | Team Lead | Priority bumped to Critical |
| SLA breach risk (>80% elapsed) | System alert | Team Lead | Immediate intervention |
| Refund request >$25 | T1 Agent | Team Lead | On-hold pending approval |
| Suspected product bug (3+ same reports) | T1 Agent | Product team via T2 | Bug ticket created |

---

### Process 4: Customer Health Review

```
[Automated Score Calc] → [Segment Filter] → [CSM Review] → [Intervention] → [Outcome Log]
           │                    │                │                │                │
           ▼                    ▼                ▼                ▼                ▼
    Usage + ticket       Red / Yellow /      Manual review    Outreach call,   Health trend
    NPS + billing        Green tiers         of Red cohort    QBR, or          updated in
    signals combined     updated             accounts         retention offer   CRM
```

| Step | Owner | System Actions | Frequency |
|------|-------|----------------|-----------|
| Score Calculation | System | Pull usage, tickets, NPS, payment signals | Daily automated |
| Segment Filter | System | Flag accounts by tier: Red (<50), Yellow (50-69), Green (≥70) | Daily |
| CSM Review | CSM | Review Red accounts, plan outreach | Weekly |
| Intervention | CSM | Log call, email, or schedule EBR | As needed |
| Outcome Log | CSM | Update CRM: intervention type, response, next action | Same day |

---

## 2. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Monitor ticket queue volume and SLA risk | Team Lead | 30-45 min | Requires manual dashboard refresh |
| Triage new inbound tickets | T1 Agent | 60-90 min/day | Mis-categorization leads to wrong routing |
| Check customer health score alerts | CSM | 20-30 min | Multiple systems — no unified alert |
| Respond to open tickets within SLA | T1 Agent | Core workday | No workload balancing automation |
| Log customer touchpoints in CRM | CSM | 15-20 min | Manual entry, no auto-logging from calls |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| At-risk account review meeting | CSM + Team Lead | 60 min | Data prep takes additional 90 min |
| Agent coaching 1:1 (per agent) | Team Lead | 30 min/agent | CSAT data has 24-48h lag |
| SLA compliance report | Team Lead | 45-60 min | Manual Excel compilation |
| Knowledge base review and updates | T1 Agent | 30 min | No structured process for flagging outdated articles |
| Onboarding milestone check per new customer | CSM | 20 min/customer | No milestone tracker — tracked in spreadsheets |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| NPS survey send and initial analysis | VP CX | 2-3 hours | Low response rates (<15% typical B2B) |
| Churn analysis: root cause breakdown | CSM + VP CX | 4-8 hours | Manual data pull from 3+ systems |
| QBR preparation for key accounts | CSM | 2-4 hours per QBR | No template auto-population from CRM |
| CSAT trend report to leadership | Team Lead | 2 hours | Cross-tool data reconciliation |
| Product feedback synthesis for roadmap | CSM + VP CX | 3 hours | No structured tagging from tickets |

### Quarterly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Customer success OKR review | VP CX | Full-day planning | Baseline data inconsistent across quarters |
| Health score model recalibration | CSM + Data team | 2-3 days | Requires data science involvement |
| Competitive churn analysis | VP CX | 3-5 hours | Exit interview data rarely captured systematically |
| SLA tier and pricing review with customers | CSM + VP CX | Per-account | No change history in contract system |

---

## 3. Decision Support Requirements

### Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| Customer Health Dashboard | CSM, Team Lead | Health score by account, Red/Yellow/Green distribution, at-risk count |
| Support Operations Dashboard | Team Lead, VP CX | Ticket volume, FRT, resolution time, SLA compliance %, CSAT |
| Executive CX Dashboard | VP CX, CEO | NPS trend, churn rate, NRR, CSAT score, at-risk ARR |
| Agent Performance Dashboard | Team Lead | Tickets handled, avg resolution time, CSAT per agent, escalation rate |
| Onboarding Progress Dashboard | CSM | Milestone completion rate, time-to-first-value, health score at Day 30 |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| SLA Compliance Report | Daily | Track SLA adherence by channel and tier | Team Lead, VP CX |
| Churn Root Cause Report | Monthly | Identify top churn reasons by cohort | VP CX, CEO |
| NPS Trend Report | Monthly | Measure satisfaction over time, detractor follow-up | VP CX, Product |
| Onboarding Completion Report | Weekly | Track new customer onboarding progress | CSM, Team Lead |
| Support Volume & Channel Mix Report | Weekly | Identify peak times, channel preference shifts | Team Lead |
| Product Feedback Summary | Monthly | Translate tickets into product insights | VP CX, Product team |

---

## 4. Integration Touchpoints

### Internal Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| CRM (e.g., Salesforce, HubSpot) | Bi-directional | Customer profile, account value, contract data, touchpoint log |
| Billing System | Inbound to helpdesk | Payment status, subscription tier, renewal date |
| Product Analytics (e.g., Mixpanel, Amplitude) | Inbound to health score | Feature adoption, login frequency, session data |
| HR / Scheduling System | Inbound to helpdesk | Agent availability, shift schedule for queue planning |

### External Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| Email Support (Gmail, Outlook) | Inbound → ticket creation | Convert email to ticket automatically |
| Live Chat (e.g., Intercom, Drift) | Bi-directional | Real-time support, chatbot first-response |
| NPS / Survey Tools (e.g., Delighted, Medallia) | Outbound survey + inbound response | Collect CSAT, NPS, CES |
| Telephony / Call Center (e.g., Twilio, Zendesk Talk) | Inbound call log | Call recording, ticket creation from call |
| Slack / Teams | Outbound alert | At-risk alerts, SLA breach notifications to CSM/Team Lead |

---

## 5. KPIs & Metrics

### Service Quality Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| First Response Time (FRT) | Time from ticket creation to first agent reply | ≤4h (Standard), ≤1h (Priority), ≤15min (Critical) |
| Resolution Time | Time from ticket creation to closed status | ≤24h (Standard), ≤8h (Priority), ≤4h (Critical) |
| First Contact Resolution (FCR) | Tickets resolved without escalation / total tickets | ≥70% |
| SLA Compliance Rate | Tickets resolved within SLA / total tickets | ≥95% |
| Escalation Rate | Tickets escalated to T2 / total tickets | ≤20% |

### Customer Satisfaction Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| CSAT Score | Sum of satisfied responses / total responses × 100 | ≥85% |
| Net Promoter Score (NPS) | % Promoters − % Detractors | ≥40 (B2B SaaS benchmark) |
| Customer Effort Score (CES) | Average rating on effort scale (1-7) | ≤3.0 (lower = easier) |
| Detractor Response Rate | Detractors followed up within 48h / total detractors | ≥90% |

### Retention & Growth Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Gross Churn Rate | ARR lost from cancellations / beginning ARR × 100 | ≤5% annual |
| Net Revenue Retention (NRR) | (Beginning ARR + Expansion − Churn − Contraction) / Beginning ARR | ≥110% |
| Customer Health Score | Weighted composite: usage (40%), support (20%), NPS (20%), billing (20%) | ≥70 = Green |
| Time to First Value (TTFV) | Days from contract signed to first meaningful product event | ≤14 days |
| Onboarding Completion Rate | Customers completing all onboarding milestones / total new customers | ≥80% |
