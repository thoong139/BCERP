# Playbook: Design Campaign Management Module

> **Type**: Agent Skill Playbook
> **Agent**: marketing-expert
> **Triggered by**: /wf-design hoặc /wf-define-features khi có Campaign module
> **Output**: Feature spec + Data model cho Campaign Management

---

## Khi nào dùng playbook này

- Khi cần spec module "Campaign Management" hoặc "Quản lý Chiến dịch Marketing"
- Khi cần thiết kế data model cho campaigns
- Khi review/audit hệ thống campaign hiện có

---

## Procedure

### Bước 1: Xác định scope

```
Hỏi hoặc suy luận từ context:
□ Campaign types cần support: Email? Paid? Social? Multi-channel?
□ Team size: Solo marketer vs Team (ảnh hưởng approval workflow)
□ Budget management: Cần không? Mức nào? (per campaign / per channel / total)
□ A/B testing: Cần không? Mức phức tạp nào?
□ External integrations: Google Ads, Facebook, Email platform?
□ Reporting depth: Basic metrics hay full attribution?
```

### Bước 2: Thiết kế Campaign Hierarchy

```
READ: operations.md → Process 1: Campaign Planning & Execution
READ: digital-channels.md → Section 5: Paid Advertising (Campaign Structure)

Standard hierarchy:

Campaign (Mục tiêu tổng)
└── Channel (Google / Facebook / Email / Social)
    └── Ad Group / Ad Set (Audience segment)
        └── Ad / Creative (Bản quảng cáo cụ thể)
            └── Variant (A/B test variants)
```

**Data model cần thiết kế:**

```
Campaign:
  - id, name, type, status, objective
  - start_date, end_date
  - total_budget, budget_type (daily/lifetime)
  - target_audience (JSON)
  - owner_id, team_id
  - created_at, updated_at

CampaignChannel:
  - campaign_id, channel_type
  - channel_budget, channel_budget_type
  - external_id (Google campaign ID, etc.)
  - status, metrics (JSON)

AdGroup:
  - campaign_channel_id, name
  - audience_segment, bid_strategy
  - budget (optional override)

Ad / Creative:
  - ad_group_id, name, type (image/video/text/carousel)
  - headline, description, cta_text, cta_url
  - asset_urls (JSON array)
  - status, variant_label (for A/B)
  - performance_metrics (JSON)
```

### Bước 3: Thiết kế Campaign Workflow

```
States:
Draft → Review → Approved → Scheduled → Active → Paused → Completed → Archived

Transitions:
Draft → Review: Campaign Specialist submits
Review → Approved: Marketing Manager approves
Review → Draft: Manager requests changes (với comments)
Approved → Scheduled: Set launch date
Scheduled → Active: Auto-trigger on launch_date
Active → Paused: Manual or rule-based (budget exhausted, performance alert)
Active → Completed: End date reached
```

**Approval logic:**
```
READ: controls.md → Budget approval thresholds

Budget < 5M VND: Auto-approve
Budget 5-50M VND: Marketing Manager approval
Budget > 50M VND: Director approval + Finance notification
```

### Bước 4: Thiết kế UTM & Tracking

```
READ: analytics-attribution.md → Section 1: UTM Standards

Auto-generate UTM khi launch campaign:
- utm_source: platform (google, facebook, linkedin...)
- utm_medium: channel type (cpc, social, email...)
- utm_campaign: campaign slug (auto từ campaign name)
- utm_content: ad/creative ID (auto)

System phải:
□ Auto-tag URLs với UTM khi tạo ads
□ Log tất cả UTM combinations
□ Pass UTM đến CRM khi lead capture
□ Alert khi UTM thiếu hoặc sai format
```

### Bước 5: Thiết kế A/B Testing

```
Test Types:
- Subject line test (Email)
- Creative test (Paid/Social)
- Landing page test
- Audience segment test
- Send time test

Requirements:
□ Minimum sample size calculator (thống kê significance)
□ Traffic split: 50/50 mặc định, configurable
□ Statistical significance threshold: 95% confidence
□ Auto-declare winner khi đạt threshold + min sample
□ Auto-pause loser variant sau khi winner declared
□ Test history & learnings log
```

### Bước 6: Thiết kế Reporting

```
READ: metrics-framework.md → Campaign Performance Dashboard

Metrics per campaign:
- Impressions, Reach, Clicks, CTR
- Conversions, CVR, CPA
- Spend, Budget remaining, Pacing %
- ROAS (nếu có revenue tracking)
- ROI = (Revenue - Cost) / Cost × 100

Real-time alerts:
- Budget > 80% consumed
- CPA > 2× target
- CTR < 50% of benchmark
- Conversion rate drops > 30% day-over-day
```

### Bước 7: Feature Spec Output

```markdown
# Feature Spec: Campaign Management

## Overview
[Mô tả module]

## User Stories
- As a Campaign Specialist, I want to... [theo personas]

## Functional Requirements
REQ-MKT-CAMP-001: Campaign CRUD với hierarchy
REQ-MKT-CAMP-002: Approval workflow theo budget threshold
REQ-MKT-CAMP-003: UTM auto-generation
REQ-MKT-CAMP-004: A/B testing engine
REQ-MKT-CAMP-005: Real-time performance dashboard
REQ-MKT-CAMP-006: Budget pacing alerts
REQ-MKT-CAMP-007: External platform integration

## Data Model
[ERD hoặc field definitions]

## API Endpoints
[Nếu cần thiết kế API]

## Non-functional Requirements
- Performance: Dashboard load < 2s
- Data freshness: Metrics refresh mỗi 1 giờ (API rate limits)
- Scalability: Support 1000+ concurrent campaigns
```
