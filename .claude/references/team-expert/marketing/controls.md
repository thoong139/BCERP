# Marketing Domain - Controls & Access Management

> **Domain**: Marketing / Quản trị Marketing
> **Last Updated**: 2026-03-07

---

## 1. Budget Control Matrix

### By Campaign Type

| Campaign Type | Campaign Specialist | Marketing Manager | Marketing Director | CFO |
|---------------|:------------------:|:----------------:|:-----------------:|:---:|
| Digital Ads (≤10M) | ✅ Execute | ✅ Execute | ✅ Execute | ✅ |
| Digital Ads (10M-50M) | ⚠️ Request | ✅ Approve | ✅ Execute | ✅ |
| Digital Ads (>50M) | ⚠️ Request | ⚠️ Request | ✅ Approve | ✅ |
| Event (≤50M) | ⚠️ Request | ✅ Approve | ✅ Execute | ✅ |
| Event (>50M) | ⚠️ Request | ⚠️ Request | ⚠️ Recommend | ✅ |
| Content Production | ✅ Execute | ✅ Approve | ✅ Execute | ✅ |
| Brand Campaign | ⚠️ Request | ⚠️ Request | ✅ Approve | ✅ |

### Budget Reallocation Rules

| Action | Authority | Limit |
|--------|-----------|-------|
| Shift between campaigns (same type) | Marketing Manager | ≤20% of budget |
| Shift between channels | Marketing Director | ≤10% of total budget |
| Request additional budget | Marketing Director | Case-by-case |
| Emergency spend | Marketing Manager | ≤5M VND (report to Director) |

---

## 2. Content & Creative Approval

### Content Types & Approval Workflow

| Content Type | Creator | Reviewer | Approver |
|--------------|---------|----------|----------|
| Blog post | Content Writer | Content Manager | Auto (template) |
| Social post (standard) | Social Specialist | - | Auto |
| Social post (sensitive) | Social Specialist | Marketing Manager | Legal (if needed) |
| Email campaign | Campaign Specialist | Marketing Manager | Auto (template) |
| Landing page | Campaign Specialist | Marketing Manager | Legal (if claims) |
| Video | Agency/Internal | Content Manager | Marketing Manager |
| Press release | Content Manager | Marketing Director | Legal + PR |
| Product claim | Content Writer | Marketing Manager | Legal + Product |

### Brand Compliance Checklist

| Check | Responsibility | System Support |
|-------|----------------|----------------|
| Logo usage | Creator | Brand portal templates |
| Color palette | Creator | Design system |
| Typography | Creator | Design system |
| Tone of voice | Reviewer | Style guide |
| Legal disclaimers | Legal review | Template library |

---

## 3. Consent & Compliance Controls

### Consent Management

| Consent Type | Required For | Storage | Expiry |
|--------------|--------------|---------|--------|
| Email marketing | Promotional emails | Consent DB | Until withdrawn |
| Tracking cookies | Analytics, Retargeting | Cookie consent | Per regulation |
| Data processing | Personal data use | Privacy policy | Until withdrawn |
| Third-party sharing | Lead sharing | Explicit consent | Until withdrawn |

### Email Compliance Rules

| Rule | Enforcement | Exception |
|------|-------------|-----------|
| Opt-in required | System check | Transactional emails |
| Unsubscribe link | Template requirement | None |
| Physical address | Template requirement | None |
| Sender identity | Template requirement | None |
| Frequency cap | System limit | None |

### GDPR/PDP Bill Compliance

| Requirement | System Implementation |
|-------------|----------------------|
| Right to access | Self-service portal |
| Right to rectification | Edit request workflow |
| Right to erasure | Delete workflow with audit |
| Data portability | Export functionality |
| Consent withdrawal | Preference center |

---

## 4. Lead Management Controls

### Lead Scoring Rules

| Factor | Points | Max | Decay |
|--------|:------:|:---:|-------|
| **Demographic** | | | |
| Job title match | 5-20 | 20 | None |
| Company size | 5-15 | 15 | None |
| Industry fit | 10 | 10 | None |
| **Behavioral** | | | |
| Website visit | 1-5 | - | 30 days |
| Content download | 10 | - | 60 days |
| Webinar attendance | 20 | - | 90 days |
| Demo request | 50 | - | 90 days |
| **Engagement** | | | |
| Email open | 1 | - | 14 days |
| Email click | 5 | - | 14 days |
| Form submission | 10 | - | 30 days |

### Lead Thresholds

| Score | Status | Action |
|-------|--------|--------|
| 0-25 | Cold | Nurture sequence |
| 26-50 | Warm | Marketing qualified (MQL) |
| 51-74 | Hot | Sales outreach |
| 75+ | SQL | Sales qualified, assign to rep |

### Lead Handoff Rules

| Condition | Action | SLA |
|-----------|--------|-----|
| Score ≥75 | Auto-assign to Sales | Immediate |
| Demo request | Auto-assign to Sales | <5 minutes |
| Pricing page + high score | Notify Sales | <15 minutes |
| Manual qualification | Manager assigns | <1 hour |

---

## 5. Campaign Controls

### Campaign Launch Checklist

| Check | Owner | System |
|-------|-------|--------|
| Budget allocated | Marketing Manager | Budget check |
| Targeting defined | Campaign Specialist | Audience validation |
| Creative approved | Content Manager | Approval workflow |
| Tracking setup | Marketing Analyst | Pixel/UTM check |
| Landing page tested | Campaign Specialist | QA checklist |
| Compliance reviewed | Marketing Manager | Checklist |

### Campaign Pause Rules

| Trigger | Action | Notification |
|---------|--------|--------------|
| CPA >150% of target | Alert | Campaign Specialist |
| CPA >200% of target | Auto-pause (configurable) | Marketing Manager |
| Budget exhausted | Auto-pause | Campaign Specialist |
| Ad disapproved | Alert | Campaign Specialist |
| Negative feedback spike | Alert | Marketing Manager |

### A/B Test Governance

| Requirement | Rule |
|-------------|------|
| Minimum sample size | 1000 impressions per variant |
| Minimum duration | 7 days or statistical significance |
| Max variants | 4 per test |
| Winner declaration | 95% confidence |
| Test documentation | Required in test log |

---

## 6. Data & Privacy Controls

### Data Access Matrix

| Data Type | Campaign Specialist | Marketing Analyst | Marketing Manager | Marketing Ops |
|-----------|:------------------:|:----------------:|:----------------:|:-------------:|
| Aggregate metrics | ✅ | ✅ | ✅ | ✅ |
| Campaign data | ✅ Own | ✅ Full | ✅ Full | ✅ Full |
| Lead PII | ⚠ Limited | ⚠ Limited | ✅ Full | ✅ Full |
| Contact details | ❌ | ⚠ Anonymized | ✅ Full | ✅ Manage |
| Budget details | ⚠ Own | ✅ View | ✅ Full | ✅ Manage |
| System config | ❌ | ❌ | ⚠ Approve | ✅ Full |

### Data Retention

| Data Type | Retention Period | Archive | Delete |
|-----------|------------------|---------|--------|
| Campaign metrics | 3 years | After 1 year | After 3 years |
| Lead data | 2 years after last activity | After 1 year inactive | Per request |
| Email engagement | 1 year | No | Auto-delete |
| Web analytics | 2 years | After 1 year | After 2 years |
| Consent records | Indefinite (or per law) | No | Per law |

---

## 7. Audit Trail Requirements

### Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Campaign create | User, Details, Budget | 3 years |
| Campaign edit | User, Changes, Reason | 3 years |
| Budget change | User, Amount, Approval | 5 years |
| Lead status change | User, Old→New, Score | 3 years |
| Consent change | User, Type, Action | Indefinite |
| Content publish | User, Content ID, Channel | 3 years |
| Data export | User, Data type, Recipient | 5 years |

---

## Quick Reference: Compliance Checklist

### Before Campaign Launch
- [ ] Budget approved
- [ ] Targeting non-discriminatory
- [ ] Creative compliant with brand
- [ ] Claims substantiated
- [ ] Tracking properly configured
- [ ] Landing page compliant
- [ ] Consent mechanism in place

### Before Email Send
- [ ] List has valid consent
- [ ] Unsubscribe link present
- [ ] Physical address included
- [ ] Sender identity clear
- [ ] Content reviewed
- [ ] Test send completed
