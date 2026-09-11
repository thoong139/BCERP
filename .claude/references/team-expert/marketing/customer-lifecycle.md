# Marketing - Customer Lifecycle

> **Domain**: Marketing / Customer Acquisition & Retention
> **Last Updated**: 2026-03-16
> **Nguồn**: AARRR Framework, McKinsey Customer Decision Journey, HubSpot Flywheel

---

## Tổng quan

Marketing nhìn customer theo 5 stages liên tiếp, mỗi stage có mục tiêu, kênh, KPIs, và yêu cầu hệ thống riêng.

```
ACQUIRE → NURTURE → CONVERT → RETAIN/EXPAND → ADVOCATE
    │         │          │           │               │
 Kéo vào  Dạy dỗ    Chốt sale   Giữ chân       Lan truyền
```

**Ownership:**

| Stage | Owner chính | Owner phụ |
|-------|-------------|-----------|
| Acquire | Marketing | - |
| Nurture | Marketing | Sales |
| Convert | Sales | Marketing |
| Retain/Expand | Customer Success | Marketing |
| Advocate | Marketing | Customer Success |

---

## Stage 1: ACQUIRE (Thu hút)

**Mục tiêu**: Tiếp cận đúng người, đúng thời điểm, đúng kênh — với chi phí hợp lý.

### Channels & Cost Types

| Channel | Use Case | Cost Model | Tốc độ |
|---------|----------|------------|--------|
| SEO/Organic | Informational & transactional queries | Time investment | Chậm, bền |
| Paid Search | High-intent, ready-to-buy queries | CPC/CPL | Nhanh |
| Paid Social | Audience-based awareness & retargeting | CPM/CPL | Nhanh |
| Content Marketing | Authority building, organic traffic | Time investment | Chậm, bền |
| Referral/WOM | Trust-based peer introduction | Incentive cost | Phụ thuộc |
| Events/Webinars | High-quality B2B lead capture | Event cost | Theo sự kiện |
| PR/Earned Media | Brand awareness at scale | Agency/time | Không ổn định |

### KPIs

| Metric | Formula | Benchmark |
|--------|---------|-----------|
| CAC | Total Marketing Cost / # New Customers | Phải < 1/3 LTV |
| CPL | Campaign Spend / # Leads | Theo channel |
| CTR | Clicks / Impressions × 100 | Search: 3-5%, Social: 1-2% |
| Landing Page CVR | Form Submits / Visitors × 100 | 3-8% |

### System Requirements

- Landing page builder + A/B testing engine
- UTM parameter tracking + attribution tagging
- Lead capture forms với progressive profiling
- Conversion pixel / tag management
- CRM integration cho lead capture tự động

---

## Stage 2: NURTURE (Nuôi dưỡng)

**Mục tiêu**: Educate leads, tăng lead score đến ngưỡng MQL — không ép buộc.

### Nurture Mechanics

```
Lead vào → Score tăng dần → Segment → Sequence phù hợp → Đạt MQL
              ↑
   Page visit, Email open, Content download,
   Demo request, Pricing page visit...
```

### Nurture Sequence Types

| Type | Trigger | Số emails | Mục đích |
|------|---------|-----------|----------|
| Welcome | Form submit | 3-5 emails / 2 tuần | Giới thiệu brand, set expectations |
| Educational drip | New lead | 6-10 emails / 1 tháng | Build authority, educate |
| Re-engagement | Inactive 30 ngày | 3 emails / 10 ngày | Win back interest |
| Trial/Freemium | Sign-up | 7-14 emails / 2 tuần | Drive activation |

### KPIs

| Metric | Formula | Target |
|--------|---------|--------|
| Lead-to-MQL Rate | MQLs / Total Leads × 100 | 20-40% |
| Email Open Rate | Opens / Delivered × 100 | > 25% |
| Email CTR | Clicks / Delivered × 100 | > 3% |
| Lead Velocity Rate | (MQL tháng này - tháng trước) / tháng trước | > 0, tăng dần |
| Score Progression | Avg score tăng theo tuần | Tích cực |

### System Requirements

- Lead scoring engine (demographic + behavioral + decay)
- Email automation với conditional branching
- Content recommendation dựa trên behavior
- Progressive profiling qua nhiều form interactions

---

## Stage 3: CONVERT (Chuyển đổi)

**Mục tiêu**: Biến MQL → Customer. Marketing hỗ trợ Sales bằng context và enablement.

### MQL → SQL → Customer Handoff Protocol

| Trigger | Hành động | SLA | Owner |
|---------|-----------|-----|-------|
| Score ≥ threshold | Alert Sales, tạo task | < 4 giờ | Marketing Ops |
| Demo request | Assign AE, gửi confirm | < 1 giờ | Sales Ops |
| Pricing page visit 3+ lần | Alert AE của lead đó | Real-time | System |
| Free trial sign-up | CS outreach + nurture | < 24 giờ | CS + Marketing |
| Proposal requested | Assign AE, block calendar | < 2 giờ | Sales |

### KPIs

| Metric | Formula | Target |
|--------|---------|--------|
| MQL → SQL Rate | SQLs / MQLs × 100 | 30-50% |
| SQL → Customer Rate | Customers / SQLs × 100 | 20-35% |
| Sales Cycle Length | Avg days từ MQL → Closed | Giảm dần |
| Free Trial CVR | Paid / Trials × 100 | 15-25% |

### System Requirements

- CRM integration: auto-create lead/contact, assign owner
- Handoff notifications (email + in-app)
- Attribution tracking qua toàn bộ Convert stage
- Sales enablement: case studies, battle cards, ROI calculators

---

## Stage 4: RETAIN & EXPAND (Giữ chân & Mở rộng)

**Mục tiêu**: Giảm churn, tăng LTV bằng upsell/cross-sell và engagement.

### Retention Mechanics

```
New Customer → Onboarding → Activation → Regular Usage → At-Risk Detection
                                                              ↓
                                                    Intervention campaign
                                                              ↓
                                                    Retain hoặc Offboard
```

### Expansion Triggers

| Tín hiệu | Hành động Marketing |
|----------|----------------------|
| Usage đạt 80% plan limit | Upsell campaign + CS alert |
| New team member added | Upgrade-to-team campaign |
| Feature adoption milestone | Cross-sell adjacent feature |
| Annual contract renewal | Loyalty offer / case study request |

### KPIs

| Metric | Formula | Target |
|--------|---------|--------|
| Customer Retention Rate | (End - New) / Start × 100 | > 85% (annual, B2B) |
| Net Revenue Retention (NRR) | (Start + Expansion - Contraction - Churn) / Start × 100 | > 110% |
| Expansion MRR | New MRR từ existing customers | Tăng dần |
| Customer Health Score | Composite: usage + NPS + support tickets | > 70/100 |

### System Requirements

- Customer health scoring (usage data + support + payment)
- Churn prediction model với early warning alerts
- Lifecycle email triggers dựa trên usage events
- In-app messaging / push notification
- Upsell/cross-sell recommendation engine

---

## Stage 5: ADVOCATE (Lan truyền)

**Mục tiêu**: Biến happy customers thành kênh acquire mới — viral loop tự nhiên.

### Advocacy Mechanics

```
Happy Customer → Referral Invite → Friend signs up → Reward distributed
     │
     └→ Review request → G2/App Store review
     └→ Case study invite → Published story
     └→ Community → Active member → UGC
```

### Referral Program Design

| Yếu tố | Options | Best Practice |
|--------|---------|---------------|
| Incentive structure | One-sided (chỉ referrer), Two-sided (cả 2) | Two-sided hiệu quả hơn |
| Reward type | Cash, Credit, Gift card, Feature unlock | Credit/Feature giữ chân tốt hơn |
| Trigger timing | Sau activation (không phải ngay khi mua) | Khi customer đã thấy value |
| Share channel | Email, Link, Social, In-app | Link + In-app tốt nhất |

### KPIs

| Metric | Formula | Target |
|--------|---------|--------|
| Referral Rate | Customers referring / Total customers × 100 | > 15% |
| K-factor (Viral Coefficient) | Invites sent per user × Conversion rate | > 1 = viral growth |
| Review Score | Avg rating trên platforms | > 4.5/5 |
| Review Volume | New reviews / tháng | Tăng dần |
| Advocacy Index | % customers who are active advocates | > 20% |

### System Requirements

- Referral tracking với unique links + attribution
- Reward distribution tự động (credit, discount code)
- Review request automation (timing dựa trên health score)
- Community platform với moderation
- UGC collection và approval workflow

---

## Integration Map

```
Stage        Hệ thống chính       Tích hợp với
──────────── ──────────────────── ────────────────────────────
Acquire      Ad Platforms, CMS    Analytics, CRM
Nurture      Marketing Automation CRM, Lead Scoring
Convert      CRM, Sales Tools     Marketing Automation, Billing
Retain       Product, CS Tools    CRM, Email, Analytics
Advocate     Referral, Community  CRM, Billing, Email
```
