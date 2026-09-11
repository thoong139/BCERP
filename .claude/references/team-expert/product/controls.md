# Product Management - Controls & Access Management

> **Domain**: Product Management / Quản lý Sản phẩm
> **Last Updated**: 2026-03-22

---

## 1. Approval Matrix

### Feature Scope Changes

| Scope Change Type | Product Manager | Head of Product | CTO / VP Eng | CEO / COO |
|-------------------|:---------------:|:---------------:|:------------:|:---------:|
| Minor scope within sprint (≤ 2 story points added) | ✅ | ❌ | ❌ | ❌ |
| Story scope change mid-sprint (3-8 story points) | ✅ + PO notify | ✅ | ❌ | ❌ |
| Epic scope change (affects current quarter roadmap) | Recommend | ✅ | ✅ input | ❌ |
| New feature added to locked roadmap (mid-quarter) | Recommend | ✅ | ✅ confirm capacity | ❌ |
| Kill/sunset existing feature | Recommend | ✅ | ✅ | ⚠ nếu revenue-bearing |
| New product line (outside current portfolio) | Recommend | Recommend | Recommend | ✅ |

### Resource Allocation Changes

| Allocation Change | Product Manager | Head of Product | CEO / COO |
|-------------------|:---------------:|:---------------:|:---------:|
| Borrow engineer từ squad khác (< 1 sprint) | Recommend | ✅ | ❌ |
| Reallocate designer sang feature khác (< 2 weeks) | Recommend | ✅ | ❌ |
| New contractor/vendor cho feature delivery | ❌ | Recommend | ✅ |
| Headcount request (full-time hire) | ❌ | Recommend | ✅ |
| Cross-team dependency (blocks another squad) | ✅ escalate | ✅ | ❌ |

### Pricing & Monetization Decisions

| Decision | Product Manager | Head of Product | Finance | CEO |
|----------|:---------------:|:---------------:|:-------:|:---:|
| A/B test pricing page copy (no price change) | ✅ | ❌ | ❌ | ❌ |
| Temporary discount campaign (≤ 10%) | Recommend | ✅ | ✅ confirm | ❌ |
| Pricing tier restructure | Recommend | Recommend | ✅ | ✅ |
| New pricing model (e.g., usage-based) | Recommend | Recommend | Recommend | ✅ |
| Free-to-paid conversion gate change | ✅ | ✅ | ❌ | ❌ |

---

## 2. Access Control

### Roadmap & Planning Access Matrix

| Resource | Product Manager | Product Owner | Product Analyst | Head of Product | Engineering Lead | Exec/Stakeholder |
|----------|:---------------:|:-------------:|:---------------:|:---------------:|:----------------:|:----------------:|
| Roadmap — view public version | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Roadmap — view full internal detail | ✅ | ✅ | ⚠ read-only | ✅ | ✅ | ⚠ HoP grant |
| Roadmap — edit/move items | ✅ | ⚠ sprint scope | ❌ | ✅ | ❌ | ❌ |
| Backlog — create/edit stories | ✅ | ✅ | ❌ | ✅ | ⚠ tech stories | ❌ |
| Backlog — delete/archive items | ✅ | ⚠ PO scope | ❌ | ✅ | ❌ | ❌ |
| Feature spec — create PRD | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Sprint board — move cards | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |

### Analytics & Experiment Access Matrix

| Resource | Product Manager | Product Owner | Product Analyst | Growth PM | Head of Product | Engineering Lead |
|----------|:---------------:|:-------------:|:---------------:|:---------:|:---------------:|:----------------:|
| Product analytics dashboards — view | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Raw event data — query | ⚠ cần training | ❌ | ✅ | ✅ | ✅ | ✅ |
| A/B experiment — design & configure | ⚠ Analyst support | ❌ | ✅ | ✅ | ✅ | ❌ |
| A/B experiment — launch | ⚠ HoP approval | ❌ | ⚠ PM approval | ✅ | ✅ | ❌ |
| A/B experiment — stop/conclude | ✅ | ❌ | ⚠ PM confirm | ✅ | ✅ | ❌ |
| Feature flag — enable/disable (staging) | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ |
| Feature flag — enable/disable (production) | ⚠ Eng approval | ❌ | ❌ | ⚠ Eng approval | ✅ | ✅ |
| User segment — create/edit | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ |

### Ownership Rules

| Scenario | Rule | Override Authority |
|----------|------|--------------------|
| PM leaves team | Roadmap ownership transfers to HoP until replacement assigned | HoP |
| PO absent during sprint | Engineering Lead + PM co-own story acceptance | HoP |
| Experiment result disputed | Analyst produces final statistical report, PM makes call | HoP |
| Competing priorities giữa 2 PMs | Both PMs escalate to HoP within 1 business day | HoP |
| Stakeholder requests direct backlog change | PM xác nhận trước khi PO thực hiện | PM |
| User Researcher finding contradicts PM hypothesis | Research finding documented; PM decides with explicit rationale | HoP |
| Growth PM experiment conflicts với core PM roadmap | Joint review với HoP to determine priority | HoP |

---

## 3. Workflow Controls

### Feature Lifecycle State Transitions

| From State | To State | Entry Criteria | Validation |
|------------|----------|----------------|------------|
| Idea | Discovery | PM logs opportunity, links to feedback evidence | Minimum 1 supporting data source |
| Discovery | Spec | Discovery findings documented, problem validated | PM sign-off on opportunity size |
| Spec | Backlog Ready | PRD written, AC defined, UX mockup attached | Definition of Ready checklist passed |
| Backlog Ready | In Sprint | Capacity available, dependencies unblocked | PO + Engineering Lead confirm |
| In Sprint | In Review | Developer marks done, code PR merged | AC checklist completed by developer |
| In Review | Done | PO verifies AC met, QA sign-off | PO acceptance recorded |
| Done | Launched | Feature deployed to production, analytics events active | PM launch checklist complete |
| Launched | Measuring | D+7 metrics collected | No critical bugs open (P1/P2) |
| Measuring | Closed | Post-launch review completed, learnings documented | PM retrospective filed |

**Blocked State Rules:**

```
Bất kỳ state nào → Blocked:
  - Blocker documented với description và owner
  - PM notified within 1 business day
  - Escalation to HoP nếu không unblock trong 3 business days
```

### Backlog Hygiene Controls

| Control | Frequency | Enforcement |
|---------|-----------|-------------|
| Stories không có AC phải flagged | Per sprint planning | PO review; story không đưa vào sprint nếu thiếu AC |
| Backlog items không được groomed > 90 ngày | Monthly | PM review; archive hoặc re-prioritize |
| Duplicate stories phải merge | Per intake | PO kiểm tra trước khi tạo story mới |
| Stories không có RICE/ICE score | Weekly grooming | PO flagged; không rank trong roadmap |
| Bugs P1/P2 phải có story trong sprint hiện tại | On creation | Triage meeting quyết định trong 24h |

### Experiment Controls

| Control | Rule | Enforcement |
|---------|------|-------------|
| Minimum sample size trước khi conclude | 95% statistical significance, p < 0.05 | Analyst validates trước khi PM declares winner |
| Experiment runtime tối thiểu | 2 tuần (1 business cycle) | Prevent premature stopping |
| Concurrent experiments trên cùng user segment | Tối đa 2 experiments cùng lúc per segment | Analyst tracks experiment registry |
| Kết quả experiment phải được recorded | Win/Lose/Inconclusive + action taken | Decision log entry required trước khi archive |

---

## 4. Audit Trail Requirements

### Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Feature created | Feature ID, name, creator, timestamp, linked requirements | 5 năm |
| Feature prioritization change | Feature ID, old rank, new rank, changed by, rationale | 3 năm |
| Roadmap item added/removed | Item ID, action, actor, timestamp, justification | 3 năm |
| Feature spec approved | Feature ID, approver, timestamp, version | 5 năm |
| A/B experiment launched | Experiment ID, hypothesis, variants, target segment, launch date | 5 năm |
| A/B experiment concluded | Experiment ID, results, decision, actor, date | 5 năm |
| Feature killed/sunset | Feature ID, reason, decision maker, date, impact assessment | 5 năm |
| Pricing change approved | Change description, approvers, effective date, rollback plan | 7 năm |
| Scope change mid-sprint | Sprint ID, change description, justification, approver | 2 năm |
| Post-launch review filed | Feature ID, metrics vs. target, learnings summary, author | 3 năm |
| Research insight created | Insight ID, source study, researcher, date, linked features | 3 năm |
| Requirement change | REQ-ID, old value, new value, changed by, rationale, date | 5 năm |

### Feature Decision Log — Required Fields

| Field | Description | Mandatory |
|-------|-------------|:---------:|
| Decision ID | Auto-generated unique ID | ✅ |
| Feature / Epic reference | Link to Jira/Productboard item | ✅ |
| Decision date | YYYY-MM-DD | ✅ |
| Decision type | Prioritize / Kill / Scope change / Pricing / Experiment | ✅ |
| Decision made by | Name + role | ✅ |
| Rationale | Free text, minimum 2 sentences | ✅ |
| Data sources referenced | Links to dashboards, research, tickets | ✅ |
| Alternatives considered | List of options evaluated | ⚠ cho major decisions |
| Expected outcome | Quantified target nếu có thể | ⚠ cho major decisions |
| Stakeholders notified | List of notified parties + channel | ✅ |

### Sensitive Data Access Log

| Data Accessed | Who Can Access | Purpose |
|---------------|----------------|---------|
| Individual user session recordings (Hotjar/FullStory) | PM, User Researcher, Analyst | UX research, bug investigation |
| Raw user-level event data | Analyst, Engineering Lead | Debugging, deep analysis |
| Survey responses với PII | PM, Analyst | Research synthesis |
| NPS verbatim comments | PM, Analyst, HoP | Product improvement |
| Customer churn data tied to user IDs | PM, Analyst, HoP | Retention analysis |
| Pricing experiment data per user cohort | Analyst, HoP, Finance | Monetization decisions |

---

## Quick Reference: Feature Launch Checklist

### Before Launching Feature to Production

- [ ] Acceptance criteria verified và sign-off by PO recorded
- [ ] QA sign-off received (no open P1/P2 bugs)
- [ ] Analytics events confirmed firing in staging environment
- [ ] Feature flag configured — initial rollout % defined
- [ ] Rollback plan documented với owner assigned
- [ ] Release notes drafted (internal + external nếu customer-facing)
- [ ] Support team briefed nếu user-facing change
- [ ] Post-launch review scheduled (D+7 check-in, D+30 full review)

### Before Concluding A/B Experiment

- [ ] Minimum runtime đạt (2 tuần)
- [ ] Statistical significance ≥ 95% (p < 0.05)
- [ ] Sample size đủ lớn — Analyst confirms
- [ ] Secondary metrics không bị negative impact
- [ ] Decision recorded trong experiment log với rationale
- [ ] Follow-up action logged vào backlog
