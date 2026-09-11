# Paid Media - Controls & Access Management

> **Domain**: Paid Media / Quảng cáo Có Trả Phí
> **Last Updated**: 2026-03-19

---

## 1. Approval Matrix

### By Daily Budget Level

| Daily Budget Threshold | Media Buyer / Specialist | Perf. Marketing Manager | Director of Marketing | VP / CMO |
|------------------------|:------------------------:|:-----------------------:|:---------------------:|:--------:|
| Tăng/giảm ≤$100/ngày | ✅ | ✅ | ✅ | ✅ |
| Tăng/giảm $100–$500/ngày | ✅ | ✅ | ✅ | ✅ |
| Tăng/giảm $500–$1,000/ngày | ⚠ Manager approve | ✅ | ✅ | ✅ |
| Tăng/giảm $1,000–$10,000/ngày | ❌ | ⚠ Director approve | ✅ | ✅ |
| Tăng/giảm >$10,000/ngày | ❌ | ❌ | ⚠ VP/CMO approve | ✅ |

### By Decision Type

| Decision | Media Buyer | Perf. Manager | Director | VP / CMO |
|----------|:-----------:|:-------------:|:--------:|:--------:|
| New campaign launch (existing channel) | ✅ | ✅ | ✅ | ✅ |
| New channel launch (pilot) | ❌ | ⚠ Recommend | ✅ | ✅ |
| New channel launch (full investment) | ❌ | ❌ | ⚠ Recommend | ✅ |
| Creative approval (standard) | ⚠ Own assets | ✅ | ✅ | ✅ |
| Creative approval (brand-sensitive) | ❌ | ⚠ Recommend | ✅ | ✅ |
| Landing page URL change | ❌ | ✅ | ✅ | ✅ |
| Attribution model change | ❌ | ⚠ Recommend | ✅ | ✅ |

---

## 2. Access Control

### Ad Account Access Matrix

| Resource | Media Buyer | Paid Social Specialist | PPC Analyst | Perf. Marketing Manager | Growth Lead |
|----------|:-----------:|:----------------------:|:-----------:|:-----------------------:|:-----------:|
| Google Ads (edit) | ✅ | ❌ | ✅ | ✅ | ⚠ View only |
| Meta Ads Manager (edit) | ✅ | ✅ | ❌ | ✅ | ⚠ View only |
| TikTok Ads Manager (edit) | ✅ | ✅ | ❌ | ✅ | ⚠ View only |
| LinkedIn Campaign Manager (edit) | ✅ | ✅ | ❌ | ✅ | ⚠ View only |
| Billing information | ❌ | ❌ | ❌ | ⚠ View only | ✅ |
| Admin / user management | ❌ | ❌ | ❌ | ✅ | ✅ |
| API credentials | ❌ | ❌ | ⚠ Read only | ✅ | ✅ |

### Sensitive Data Access

| Data Type | Media Buyer | Specialist | PPC Analyst | Perf. Manager | Growth Lead |
|-----------|:-----------:|:----------:|:-----------:|:-------------:|:-----------:|
| CRM audience (PII) | ❌ | ❌ | ❌ | ⚠ Anonymized | ✅ |
| Customer match lists (hashed) | ✅ Upload | ✅ Upload | ❌ | ✅ | ✅ |
| Competitor intelligence reports | ✅ View | ✅ View | ✅ View | ✅ | ✅ |
| Financial projections & LTV | ❌ | ❌ | ⚠ View only | ⚠ View only | ✅ |
| Ad account invoice history | ❌ | ❌ | ❌ | ⚠ View only | ✅ |

### Ownership Rules

| Scenario | Rule | Override Authority |
|----------|------|--------------------|
| Ad account ownership | Assigned per team member role | Perf. Marketing Manager |
| Shared access (cross-team campaigns) | Read-only unless Manager grants edit | Director |
| Agency / contractor access | Time-limited; revoked post-engagement | Perf. Marketing Manager |
| New hire ad account access | Granted after onboarding sign-off | Manager + IT/Ops |

---

## 3. Workflow Controls

### Campaign Lifecycle States

| From | To | Criteria | Validation |
|------|----|----------|------------|
| Draft | Review | Brief complete, targeting defined, creative uploaded | All required fields non-empty |
| Review | Approved | Creative reviewed, UTM parameters set, budget confirmed | Manager sign-off |
| Approved | Live | Platform publish action executed | Pixel fire test passed |
| Live | Paused | CPA/ROAS breach threshold hoặc creative fatigue detected | Log reason in campaign notes |
| Paused | Live | Issue resolved, budget reconfirmed | Manager re-approve if >7 days paused |
| Live / Paused | Completed | End date reached hoặc budget fully spent | Final performance note recorded |

### Creative Review Workflow

```
Creative Brief → Design Production → Internal Review → Compliance Check → Approve → Upload → Live
       │                 │                  │                 │               │          │       │
       ▼                 ▼                  ▼                 ▼               ▼          ▼       ▼
  Marketing          Creative            Brand              Legal /         PM /      Media    Platform
  Manager            Team               Guardian           Compliance      Manager    Buyer    Review
  defines            produces           checks             review          approves   uploads  (auto)
  brief              assets             brand fit          if needed
```

| Stage | Owner | SLA |
|-------|-------|-----|
| Brief to design handoff | Marketing Manager | 24 giờ |
| Design production | Creative Team | 2-3 ngày |
| Internal review | Brand / PM | 24 giờ |
| Compliance review (if required) | Legal / Compliance | 48 giờ |
| Final approval | Perf. Marketing Manager | 4 giờ |
| Upload to platform | Media Buyer | 2 giờ |

### Budget Change Approval Flow

| Trigger | Initiator | Approver | SLA |
|---------|-----------|----------|-----|
| Organic optimization (≤$500/day) | Media Buyer (self-service) | — | Immediate |
| Performance-driven increase ($500–$1,000/day) | Media Buyer request | Perf. Marketing Manager | 4 giờ |
| Strategic increase ($1,000–$10,000/day) | Perf. Manager recommendation | Director | 1 ngày làm việc |
| Large budget shift (>$10,000/day) | Director proposal | VP / CMO | 2 ngày làm việc |

### Hygiene Controls

| Control | Frequency | Enforcement |
|---------|-----------|-------------|
| Inactive ad set cleanup (no spend >14 ngày) | Weekly | Media Buyer review; auto-flag in dashboard |
| UTM parameter validation | Per campaign launch | Tracking QA checklist required before go-live |
| Negative keyword list update | Weekly | PPC Analyst review of search term report |
| Audience freshness check (custom audiences) | Monthly | Paid Social Specialist; re-upload if >30 ngày cũ |
| Creative duplicate check | Per launch | Platform creative library scan |
| Pixel / tag fire validation | Per site change | QA via GTM Preview or PixelHelper |

---

## 4. Audit Trail Requirements

### Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Campaign created | Creator, platform, budget, targeting, objective | 3 năm |
| Budget change | User, old value, new value, reason, timestamp | 3 năm |
| Campaign pause / resume | User, reason, spend-to-date, timestamp | 3 năm |
| Creative upload / swap | User, creative ID, previous creative, timestamp | 3 năm |
| Bid strategy change | User, old strategy, new strategy, timestamp | 3 năm |
| Targeting change | User, old audience, new audience definition, timestamp | 3 năm |
| Ad account access granted/revoked | Admin, user, platform, access level, timestamp | 5 năm |
| Attribution model change | User, old model, new model, business justification | 3 năm |

### Sensitive Data Access Log

| Data Accessed | Who Can Access | Purpose |
|---------------|----------------|---------|
| CRM customer match list (hashed) | Perf. Marketing Manager, Growth Lead | Audience creation cho retargeting |
| Billing invoices | Growth Lead, Finance | Budget reconciliation, vendor payment |
| Ad account API credentials | Perf. Marketing Manager, Engineer | Integration setup, reporting automation |
| Competitor intelligence reports | Full paid media team | Strategy và bidding decisions |

---

## Quick Reference: Approval Checklist

### Before Campaign Launch

- [ ] Campaign brief reviewed và approved
- [ ] Budget level phù hợp với approval threshold của người launch
- [ ] UTM parameters đã được cấu hình và test
- [ ] Pixel / conversion tag đã verify fire đúng
- [ ] Creative đã được approve theo creative review workflow
- [ ] Targeting audience size đủ lớn (≥1,000 users minimum)
- [ ] Negative keyword list đã được apply (Search campaigns)

### Before Budget Increase >$1,000/day

- [ ] Approval từ Director hoặc VP đã được ghi nhận
- [ ] ROAS / CPA justification đã được document
- [ ] Budget available trong monthly plan đã xác nhận với Finance
- [ ] Audience scale đủ để absorb tăng spend mà không spike CPM bất thường

### Before CRM Audience Upload

- [ ] Data đã được hashed (SHA-256) trước khi upload
- [ ] User consent cho remarketing đã được xác nhận
- [ ] Segment definition đã được document (source, filters, date range)
- [ ] Upload log đã được ghi vào audit trail
