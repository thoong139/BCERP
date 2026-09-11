# Marketing - Lead Management

> **Domain**: Marketing / Lead Generation & Pipeline Management
> **Last Updated**: 2026-03-16
> **Nguồn**: Marketo Lead Scoring Best Practices, SiriusDecisions Demand Waterfall

---

## Tổng quan Lead Lifecycle

```
Visitor → Raw Lead → Working Lead → MQL → SAL → SQL → Opportunity → Customer
    │          │            │         │      │      │
 Anonymous  Captured    Scoring   M passes  S accepts  BANT
            (form)      active    threshold  lead      qualified
```

**Definitions:**
- **Raw Lead**: Điền form, chưa đủ thông tin / score
- **Working Lead**: Đang được nurture, score đang tăng
- **MQL** (Marketing Qualified Lead): Đạt ngưỡng score, Marketing pass sang Sales
- **SAL** (Sales Accepted Lead): Sales xác nhận đây là lead phù hợp
- **SQL** (Sales Qualified Lead): Sales đã qualify bằng BANT/MEDDPICC
- **Recycled Lead**: SQL bị Sales reject → trả về Marketing để nurture tiếp

---

## Lead Scoring Model

### Cấu trúc điểm

```
Tổng score = Demographic Score + Behavioral Score - Decay

MQL Threshold: thường 75-100 điểm (tùy business)
```

### Demographic Scoring (Fit Score)

Đo "đây có phải đúng người không?" — dựa trên ICP (Ideal Customer Profile):

| Yếu tố | Điểm (+) | Điểm (-) |
|--------|----------|----------|
| Job title phù hợp ICP (VP, Director, Manager) | +15 đến +25 | - |
| Job title không phù hợp (Intern, Student) | - | -10 |
| Company size phù hợp (B2B: 50-5000 nhân viên) | +10 đến +20 | - |
| Industry phù hợp ICP | +10 đến +15 | - |
| Industry không phù hợp | - | -5 |
| Email domain công ty (không phải gmail/yahoo) | +10 | - |
| Email domain personal | - | -5 |
| Phone number có thật | +5 | - |
| Location / Region phù hợp | +5 đến +10 | - |

### Behavioral Scoring (Interest Score)

Đo "họ đang thể hiện interest không?" — dựa trên actions:

| Hành động | Điểm | Ghi chú |
|-----------|------|---------|
| Xem Pricing page | +20 | High intent |
| Request Demo / Contact Sales | +35 | Immediate MQL trigger |
| Download whitepaper/ebook | +15 | Content engagement |
| Attend webinar | +15 | Active interest |
| Watch demo video > 50% | +20 | Strong interest |
| Email click (campaign) | +5 | General engagement |
| Email open | +2 | Weak signal |
| Visit blog post | +2 | Low intent |
| Visit homepage 3+ lần trong 1 tuần | +10 | Repeat visitor |
| Xem Case study | +10 | Consideration stage |
| Start free trial | +40 | Very high intent |
| Invite team member | +25 | Expansion signal |

### Score Decay

Behavioral score giảm nếu không có hoạt động:

| Thời gian không active | Decay |
|------------------------|-------|
| 2 tuần | -5 điểm |
| 1 tháng | -15 điểm |
| 2 tháng | -30 điểm (về Working Lead) |
| 3 tháng+ | Reset behavioral score |

---

## MQL Definition & Threshold

### MQL Qualification Criteria

Lead được gọi là MQL khi ĐẠT TẤT CẢ điều kiện:

1. **Score ≥ threshold** (ví dụ: 75 điểm)
2. **Email hợp lệ** — không phải disposable, không bounce
3. **Không có DNC flag** — không trong Do Not Contact list
4. **Không phải competitor** — lọc theo domain blacklist
5. **Phù hợp địa lý** — trong territory Sales đang phục vụ

### Fast-Track MQL (Bỏ qua threshold)

Một số hành động trigger MQL ngay lập tức:
- Request Demo
- Contact Sales form
- Start Free Trial
- Respond "Yes" to email nurture CTA

---

## Lead Segmentation

### Segmentation cho Nurture

| Segment | Criteria | Nurture Strategy |
|---------|----------|-----------------|
| Enterprise | Company > 500 người | High-touch, case studies, ROI calculators |
| Mid-Market | Company 50-500 người | Mix: automated + 1-1 outreach |
| SMB | Company < 50 người | Automated, product-led |
| By Industry | Vertical-specific | Industry-specific content |
| By Role | CXO vs Manager vs IC | Message theo decision authority |
| By Stage | Awareness vs Consideration | Educational vs Comparison content |

---

## Marketing-to-Sales Handoff Protocol

### Handoff Checklist (Marketing phải cung cấp)

```
✅ Lead profile: Tên, Email, Phone, Company, Role, Company size
✅ Lead source: Kênh nào, Campaign nào, Landing page nào
✅ Score breakdown: Demographic score + Behavioral score
✅ Activity history: 10 actions gần nhất
✅ Content consumed: Đã đọc/xem gì (context cho Sales)
✅ Previous outreach: Đã liên hệ chưa, kết quả thế nào
✅ Territory assignment: Đúng territory của AE nào
```

### SLA Handoff

| Trigger | Sales Action Required | SLA |
|---------|----------------------|-----|
| MQL từ Demo Request | Contact lead | < 1 giờ |
| MQL từ Score threshold | Review + Accept/Reject | < 4 giờ |
| MQL từ Free Trial | Welcome call | < 24 giờ |
| MQL từ Event | Follow-up email | < 48 giờ |

### Lead Rejection & Recycling

Sales có thể reject MQL với lý do:

| Lý do Reject | Hành động tiếp theo |
|-------------|---------------------|
| Not ready yet (timing) | Return to Marketing nurture, re-qualify sau 30-60 ngày |
| Wrong contact (persona) | Research đúng contact, reassign |
| Bad data | Marketing ops clean data, re-score |
| Competitor | Add to competitor exclusion list |
| Already a customer | Merge với customer record |
| No budget | Nurture quarterly touch |

---

## Lead Nurture Sequences

### Welcome Series (Mọi new leads)

```
Day 0:  Confirmation email + download link (nếu có gated content)
Day 2:  "Getting started" — giá trị cốt lõi
Day 5:  Social proof — case study ngắn
Day 10: Education — insight / tip liên quan
Day 15: Soft CTA — invite webinar hoặc read guide
Day 21: Mid-funnel CTA — free trial / demo offer
Day 30: Last chance nurture — re-engagement hoặc downgrade frequency
```

### Re-engagement Series (Inactive > 30 ngày)

```
Email 1: "Chúng tôi nhớ bạn" — gợi lại value prop
Email 2: New content / update liên quan đến họ
Email 3: Hard choice — "Vẫn muốn nhận tin không?" với Yes/No CTA
→ Không click: Move to suppression list (giảm spam rate)
```

---

## Lead Data Requirements

### Minimum Fields (bắt buộc capture)

- First name, Last name
- Business email
- Company name
- Lead source (auto-populated)
- UTM parameters (auto-populated)
- Consent timestamp + method

### Enrichment Fields (cố gắng capture hoặc enrich)

- Job title / Role
- Company size
- Industry / Vertical
- Phone number
- Country / City
- LinkedIn URL

### System Requirements

| Feature | Mô tả | Priority |
|---------|--------|----------|
| Lead scoring engine | Real-time score calculation trên mọi event | Bắt buộc |
| Score history log | Track score changes theo thời gian | Bắt buộc |
| Duplicate detection | Merge leads từ cùng 1 người | Bắt buộc |
| CRM bi-directional sync | Đồng bộ 2 chiều lead data | Bắt buộc |
| Consent audit trail | Log mọi consent action + timestamp | Bắt buộc |
| Lead routing rules | Auto-assign theo territory/round-robin | Nên có |
| Progressive profiling | Thu thập thêm data mỗi form submit | Nên có |
| Intent data integration | 3rd party intent signals | Tùy ngân sách |
