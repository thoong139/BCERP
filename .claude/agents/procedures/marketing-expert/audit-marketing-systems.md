# Playbook: Audit Existing Marketing Systems

> **Type**: Agent Skill Playbook
> **Agent**: marketing-expert
> **Triggered by**: /wf-legacy-scan khi có marketing system
> **Output**: Marketing audit report + Gap analysis + Priority recommendations

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống Marketing
- Khi cần đánh giá marketing tech stack hiện tại
- Khi cần tìm gaps trước khi thiết kế lại

---

## Procedure

### Bước 1: Inventory thu thập

```
Cần thu thập từ stakeholders hoặc codebase:

□ Channels đang dùng: Email, Paid, SEO, Social, Referral?
□ Tools/Platforms: List tất cả marketing tools
□ Integrations: Tools nào connect với nhau?
□ Data: Analytics đang dùng gì? Data có accessible không?
□ Team: Ai làm marketing? Role là gì?
□ Performance: Metrics hiện tại (nếu có)
```

### Bước 2: Gap Analysis theo Lifecycle

```
READ: customer-lifecycle.md

So sánh current state vs ideal state mỗi stage:

ACQUIRE:
□ Có landing page builder không? → A/B testing?
□ UTM tracking đang setup đúng không?
□ Conversion tracking (pixel) đang fire không?
□ Attribution: đang track channel nào?

NURTURE:
□ Có lead scoring không? → Criteria phù hợp?
□ Có email automation không? → Sequences nào active?
□ Lead data: Đang capture đủ fields?

CONVERT:
□ MQL definition có không? → Criteria rõ ràng?
□ Handoff process: Có SLA? Sales có follow không?
□ Attribution: Marketing có visibility into revenue không?

RETAIN:
□ Có lifecycle emails không?
□ Churn prediction/early warning?
□ NPS/CSAT đang collect không?

ADVOCATE:
□ Có referral program không?
□ Review management đang làm gì?
```

### Bước 3: Tech Stack Audit

```
READ: analytics-attribution.md → Tool Stack section

Đánh giá từng tool:
□ Đang dùng tool nào?
□ Được setup đúng không? (tracking, data quality)
□ Có integrate với nhau không? (data flow)
□ Team có dùng được không? (adoption)
□ Cost vs value?

Common issues cần check:
□ Google Analytics: Events có setup đúng không? Conversions tracked?
□ Email platform: Deliverability score? List hygiene?
□ CRM: UTM data có được pass từ marketing không?
□ Ad platforms: Conversion tracking pixel đang fire không?
□ Attribution: First-touch vs last-touch? Cross-device?
```

### Bước 4: Data Quality Check

```
□ UTM consistency: Naming convention đồng nhất?
□ Duplicate tracking: Cùng 1 conversion tracked 2 lần?
□ Attribution gaps: Leads nào không có source?
□ Email list health: Bounce rate, engagement rate?
□ Lead data completeness: % leads có đủ fields key?
□ Consent compliance: Opt-in records có audit trail?
```

### Bước 5: Performance Baseline

```
READ: metrics-framework.md → benchmarks

Collect metrics hiện tại:
□ CPL by channel
□ Lead-to-MQL rate
□ MQL-to-SQL rate
□ Email open/click rates
□ CAC (nếu có revenue data)
□ Monthly lead volume trend

So sánh với benchmarks → identify where lagging
```

### Bước 6: Output — Audit Report

```markdown
# Marketing System Audit Report

## Executive Summary
[3-5 dòng: overall health, biggest strengths, critical gaps]

## Current State
### Tech Stack
[Table: Tool | Purpose | Status | Issues]

### Channel Performance
[Table: Channel | CPL | Volume | Health | Notes]

## Gap Analysis

### Critical Gaps (block growth)
- [Gap 1]: [Impact] → [Recommendation]

### Important Gaps (limit efficiency)
- [Gap 2]: [Impact] → [Recommendation]

### Nice-to-have Gaps
- [Gap 3]: [Impact] → [Recommendation]

## Data Quality Issues
[Table: Issue | Affected data | Severity | Fix]

## Performance vs Benchmark
[Table: Metric | Current | Benchmark | Gap | Priority]

## Priority Recommendations
1. [Highest impact, easiest fix] — Effort: Low, Impact: High
2. ...

## Implementation Roadmap
[Quick wins (< 1 tháng) / Medium term (1-3 tháng) / Long term (3+ tháng)]
```
