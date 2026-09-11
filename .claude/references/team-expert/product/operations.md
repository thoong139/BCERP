# Product Management - Operational Analysis Framework

> **Domain**: Product Management / Quản lý Sản phẩm
> **Last Updated**: 2026-03-22

---

## 1. Core Processes

### Process 1: Product Discovery

```
[Problem Signal] → [Opportunity Framing] → [User Research] → [Hypothesis Formation] → [Validation]
       │                   │                    │                    │                    │
       ▼                   ▼                    ▼                    ▼                    ▼
  User feedback      Problem statement     Interviews/         Solution concept      Prototype test
  Support tickets    How Might We          surveys/data        Job-to-be-Done        Build/measure
  Analytics          POV statement         synthesis           User journey map      Go/No-Go
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Problem Signal | PM / PO | Capture vào feedback log | Minimum 3 independent sources confirm problem |
| Opportunity Framing | PM | Document problem statement | PM + Head of Product alignment |
| User Research | PM + User Researcher | Interview notes, survey results | Minimum 5 user interviews cho greenfield feature |
| Hypothesis Formation | PM | Document hypothesis card | Testable, falsifiable, time-bound |
| Validation | PM + Analyst | Prototype test results hoặc data analysis | Statistical significance hoặc qualitative saturation |

---

### Process 2: Feature Prioritization

```
[Raw Requests] → [RICE/ICE Scoring] → [Stack Ranking] → [Roadmap Slot] → [Stakeholder Review]
      │                  │                   │                 │                  │
      ▼                  ▼                   ▼                 ▼                  ▼
  Backlog              Score each          Rank by           Quarter /           Sign-off
  intake               by criteria         score             Theme               Notify
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Raw Requests | PM / PO | Log vào backlog, tag theo source | Duplicate check, link to requirement |
| RICE/ICE Scoring | PM | Score từng item theo framework | Scoring rubric áp dụng nhất quán |
| Stack Ranking | PM | Sắp xếp theo score, điều chỉnh strategic weight | Head of Product review top 20% |
| Roadmap Slot | PM | Assign vào quarter/sprint theo capacity | Engineering capacity xác nhận |
| Stakeholder Review | PM + HoP | Publish roadmap, collect feedback | Sign-off từ key stakeholders |

**RICE Score Formula:**

```
RICE = (Reach × Impact × Confidence) / Effort

Reach     = số users bị ảnh hưởng per quarter
Impact    = 0.25 (minimal) / 0.5 (low) / 1 (medium) / 2 (high) / 3 (massive)
Confidence= % certainty về estimates (40% low / 80% medium / 100% high)
Effort    = person-months để complete
```

**ICE Score Formula:**

```
ICE = Impact + Confidence + Ease  (mỗi yếu tố 1-10)

Áp dụng khi: prioritize nhanh, backlog grooming, early-stage ideation
```

**MoSCoW Classification:**

```
Must Have   = release blocker, core value proposition
Should Have = high value, workaround exists
Could Have  = nice-to-have, include nếu còn capacity
Won't Have  = explicitly deferred, không thuộc release này
```

---

### Process 3: Sprint & Release Planning

```
[Roadmap] → [Sprint Goal] → [Backlog Grooming] → [Sprint Planning] → [Sprint] → [Release]
    │              │                │                    │               │            │
    ▼              ▼                ▼                    ▼               ▼            ▼
 Quarter       Theme/OKR        Story refinement      Capacity        2-week        Feature
 theme         alignment        AC writing            match           cycle         flag/deploy
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Sprint Goal | PM + PO | Document goal tied to OKR | Measurable outcome, not output |
| Backlog Grooming | PO | Refine stories, add AC, estimate | Definition of Ready checklist |
| Sprint Planning | PO + Engineering Lead | Commit stories per capacity | Team velocity × confidence factor |
| Sprint Execution | PO | Daily standup, blocker removal | Burndown chart tracking |
| Release | PM + Engineering | Release notes, analytics events active | Smoke test, rollback plan ready |

**Definition of Ready (DoR) — Backlog story phải đáp ứng:**

```
- [ ] User story có đủ: As a [user], I want [action], So that [outcome]
- [ ] Acceptance criteria viết xong, testable
- [ ] Dependencies xác định, unblocked
- [ ] Design mockup attached (nếu có UI)
- [ ] Story point estimate hoàn thành
- [ ] No open critical questions
```

---

### Process 4: Product Review & Retrospective

```
[Feature Launch] → [Metric Collection] → [Post-launch Review] → [Learnings Doc] → [Next Cycle Input]
        │                  │                      │                    │                  │
        ▼                  ▼                      ▼                    ▼                  ▼
     D+1               D+7, D+30           Feature scorecard      Decision log       Backlog update
  Smoke check         Adoption, NPS        vs. hypothesis         What worked        Iterate/pivot
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Metric Collection | Analyst | Pull adoption rate, funnel data, NPS delta | Events firing confirmed pre-launch |
| Post-launch Review | PM + Analyst | Compare actuals vs. hypothesis targets | Written review shared với team |
| Learnings Doc | PM | Document findings in decision log | Accessible to all product team |
| Next Cycle Input | PM | Update backlog với follow-up items | Linked to original feature |

---

## 2. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Review product analytics | Analyst / PM | 30-45 min | Multiple tools, no unified view |
| Respond to Slack/stakeholder questions | PM / PO | 60-90 min | Interrupts deep work |
| Update story statuses | PO | 20-30 min | Manual Jira update, prone to staleness |
| Daily standup | PO + Team | 15 min | Off-topic discussions bloat duration |
| Check support/feedback queue | PM | 15-20 min | No direct pipeline to backlog |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Backlog grooming session | PO + PM | 60-90 min | Stories arrive underspecified |
| Sprint review / demo | PO + Stakeholders | 60 min | Stakeholders không có advance context |
| Product metrics report | Analyst | 2-3 giờ | Data from multiple sources, manual assembly |
| 1:1 với engineering lead | PM | 30-45 min | Alignment gaps về scope thường surface late |
| Roadmap sync với design | PM + UX | 30-45 min | Design timeline không synced với sprint cadence |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Roadmap review và update | PM + HoP | 2-3 giờ | Slide deck format → stale the next day |
| User research synthesis | PM + User Researcher | 4-6 giờ | No standard format, insights siloed |
| Feature post-launch review | PM + Analyst | 1-2 giờ | Missing metrics because tracking not set up pre-launch |
| OKR health check | HoP + PMs | 1-2 giờ | OKR progress not automated |
| Competitor update | HoP / PM | 1 giờ | No structured competitive tracking tool |

### Quarterly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Quarterly roadmap planning | HoP + PMs | 2-3 ngày | Capacity uncertainty from engineering |
| OKR setting | HoP + PMs + Exec | 4-6 giờ | Cascading từ company OKR thường trễ |
| Product strategy review | HoP + CEO/COO | 2-3 giờ | No live data → rely on prepared decks |
| Team performance review | HoP | Ongoing | PM performance metrics chưa chuẩn hóa |
| Annual planning input | HoP + Finance | 4-8 giờ | Product roadmap chưa có cost model attached |

---

## 3. Decision Support Requirements

### Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| Feature Adoption Dashboard | PM, Analyst | Feature activation rate, daily active users per feature, retention D7/D30 |
| Sprint Health Board | PO, Engineering | Velocity trend, burndown, story completion rate, unplanned work % |
| Product Portfolio View | HoP, Exec | OKR progress, roadmap milestone status, feature launch count per quarter |
| Funnel Analysis Dashboard | PM, Growth PM, Analyst | Step-by-step conversion rates, drop-off points, cohort comparisons |
| NPS & Feedback Tracker | PM, HoP | NPS score trend, feedback volume by category, top-cited issues |
| Experiment Monitor | Growth PM, Analyst | A/B test status, statistical significance, conversion delta by variant |
| Research Insights Repository | PM, User Researcher | Insight count by theme, research coverage per feature area, recency |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Weekly Product Metrics | Weekly | Track KPI progress, surface anomalies | PM, PO, HoP |
| Sprint Velocity Report | Per sprint | Capacity planning, team health | PO, Engineering Lead |
| Feature Launch Report | Per launch | Post-launch health check D+7, D+30 | PM, Analyst, HoP |
| Quarterly OKR Review | Quarterly | Strategy alignment, pivots | HoP, Exec, Board |
| Experiment Results Report | Per experiment | Inform build/kill decisions | Growth PM, Analyst |
| Competitor Intelligence Brief | Monthly | Market awareness | HoP, PM |

---

## 4. Integration Touchpoints

### Internal Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| Jira | Product → Engineering: Epics, Stories, Bugs | Sprint planning và execution tracking |
| Figma | Design → Product: Mockups, prototypes, design tokens | Spec attachment vào user stories |
| Confluence | Product ↔ All: PRDs, decision logs, retrospectives | Documentation hub |
| GitHub / GitLab | Engineering → Product: Release tags, commit messages | Link feature deployments to roadmap |
| Slack | All → Product: Feature requests, feedback, alerts | Informal input capture |

### External Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| Amplitude / Mixpanel | Product ← Analytics: Event data, funnels, retention | Product analytics và experiment tracking |
| Intercom / Zendesk | Customer Support → Product: Ticket themes, user quotes | Voice-of-customer input to backlog |
| Hotjar / FullStory | UX → Product: Session recordings, heatmaps | Qualitative behavioral data |
| SurveyMonkey / Typeform | Product ← Users: NPS, CSAT, user research surveys | Structured user feedback |
| Productboard / Aha! | Product ↔ Stakeholders: Roadmap sharing, idea portal | Stakeholder visibility and request intake |

---

## 5. KPIs & Metrics

### Feature Performance Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Feature Activation Rate | Users who used feature ÷ Users who had access | ≥ 40% trong D+30 |
| Feature Adoption Rate | MAU using feature ÷ Total MAU | Depends on feature scope — baseline in D+90 |
| Time-to-Value | Time từ signup đến first meaningful action | Giảm 20% so với baseline mỗi quarter |

### Engagement & Retention Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| DAU / MAU Ratio | Daily Active Users ÷ Monthly Active Users | ≥ 20% (B2B SaaS); ≥ 40% (consumer) |
| D7 Retention | Users active on Day 7 ÷ Users who joined on Day 0 | ≥ 30% (consumer); ≥ 50% (B2B) |
| D30 Retention | Users active on Day 30 ÷ Users who joined Day 0 | ≥ 20% (consumer); ≥ 40% (B2B) |
| Churn Rate | Users lost in period ÷ Users at start of period | ≤ 2% monthly (B2B SaaS) |

### Delivery Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Sprint Velocity | Story points completed per sprint | Stable ± 15% across consecutive sprints |
| Time-to-Market | Days from feature kick-off to production launch | Track trend; reduce by 10% YoY |
| Planned vs. Unplanned Work | Unplanned story points ÷ Total story points | ≤ 15% per sprint |
| Cycle Time | Days from story start to done | Track per epic/team |

### Customer Satisfaction Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| NPS (Net Promoter Score) | % Promoters − % Detractors | ≥ 30 (good); ≥ 50 (excellent) |
| CSAT | Sum of scores ÷ Number of responses (scale 1-5) | ≥ 4.0 / 5.0 |
| Support Ticket Volume per Feature | Tickets tagged to feature ÷ Feature MAU | Giảm theo thời gian sau initial launch |
