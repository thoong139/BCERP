# Cross-Domain - Sales-Marketing Alignment Framework

> **Domain**: Cross-Domain / Sales & Marketing
> **Last Updated**: 2026-03-15
> **Nguồn**: Tổng hợp từ sales-expert và marketing-expert agents — Revenue Operations best practices

---

## 1. Funnel Alignment Diagram

Hai funnel phải được thiết kế để "khớp răng" tại điểm handoff MQL → SQL.

```
Marketing Funnel              Sales Funnel
┌───────────────────┐
│    Awareness      │  (Impressions, Reach, Brand Search)
├───────────────────┤
│    Interest       │──────────────▶ MQL
├───────────────────┤               ├─────────────────┐
│  Consideration    │──────────────▶│      SQL        │
└───────────────────┘               ├─────────────────┤
                                    │   Opportunity   │
                                    ├─────────────────┤
                                    │  Proposal/Demo  │
                                    ├─────────────────┤
                                    │   Negotiation   │
                                    ├─────────────────┤
                                    │     Close       │
                                    └─────────────────┘
```

**MQL (Marketing Qualified Lead):** Lead đủ điều kiện marketing — đáp ứng scoring threshold.
**SQL (Sales Qualified Lead):** Lead được sales confirm là có nhu cầu thực và ngân sách.

---

## 2. MQL → SQL Handoff Criteria

Handoff không rõ ràng là nguyên nhân số 1 gây bất đồng giữa hai team.

### Lead Scoring Model

| Dimension | Yếu tố | Điểm |
|-----------|--------|------|
| **Demographic Fit** | Job title phù hợp ICP | +10 |
| | Company size phù hợp | +10 |
| | Industry phù hợp | +10 |
| | Seniority (Director+) | +5 |
| **Behavioral Triggers** | Demo request | +30 |
| | Pricing page visit | +20 |
| | Case study download | +15 |
| | Webinar attendance | +10 |
| | Email click (repeated) | +5 |
| | Blog visit only | +2 |
| **Firmographic Fit** | Funding stage phù hợp | +10 |
| | Tech stack compatible | +8 |
| | Growth signal (hiring) | +5 |
| **Disqualifiers** | Competitor domain | -50 |
| | Student/personal email | -30 |
| | Country ngoài target market | -20 |

**MQL Threshold:** ≥50 điểm
**SQL Threshold:** MQL + BANT qualification (Budget, Authority, Need, Timeline) confirm bởi sales

---

## 3. SLA Template: Marketing ↔ Sales

### Marketing Commits to Sales

| Cam kết | Metric | Target |
|---------|--------|--------|
| MQL volume | MQLs/tháng | Thỏa thuận theo quota |
| MQL quality | MQL→SQL conversion rate | ≥25% |
| Lead data completeness | Fields đầy đủ (name, email, company, title) | >95% |
| Lead routing speed | Thời gian từ form submit → CRM assign | <5 phút |
| Content cung cấp | Battle cards, case studies theo segment | Cập nhật hàng quý |

### Sales Commits to Marketing

| Cam kết | Metric | Target |
|---------|--------|--------|
| Lead follow-up | Thời gian từ nhận MQL → lần liên lạc đầu | <4 giờ (business hours) |
| CRM hygiene | Cập nhật trạng thái lead trong CRM | 100% trong 48h |
| Opportunity creation | Tỷ lệ SQL → Opportunity | ≥60% |
| Feedback chất lượng | Ghi rõ lý do disqualify | 100% disqualified leads |
| Win/Loss reporting | Điền lý do thắng/thua | 100% closed deals |

### Escalation Protocol

```
Lead chưa được contact sau 4h → Tự động email alert → Sales Manager
Lead chưa được contact sau 24h → Marketing được phép reassign
Tỷ lệ SQL xuống <20%/tuần → Buổi họp alignment bắt buộc trong 48h
```

---

## 4. Shared Metrics Dashboard

Không có "marketing metrics" hay "sales metrics" — chỉ có revenue metrics.

| Metric | Owner | Formula | Target |
|--------|-------|---------|--------|
| **Pipeline Velocity** | Revenue Ops | (Opps × Deal Size × Win Rate) / Cycle Length | Tăng QoQ |
| **MQL → SQL Conversion** | Marketing + Sales | SQLs / MQLs | ≥25% |
| **SQL → Opportunity** | Sales | Opportunities / SQLs | ≥60% |
| **CAC (Customer Acquisition Cost)** | Marketing | (Sales Cost + Marketing Cost) / New Customers | Theo target margin |
| **LTV:CAC Ratio** | Finance | LTV / CAC | ≥3:1 |
| **Channel ROI** | Marketing | Revenue Attributed / Channel Spend | ≥5:1 ROAS |
| **Time to First Contact** | Sales | Avg hours từ MQL → first call | <4h |
| **Revenue Influenced by Marketing** | Revenue Ops | Deals có marketing touchpoint / Total Revenue | Track trend |

---

## 5. Content Mapping theo Funnel Stage

| Stage | Funnel | Format | Mục tiêu |
|-------|--------|--------|----------|
| Awareness | TOFU | Blog, Social, Podcast, Video | Educate — giải quyết vấn đề ngành |
| Interest | TOFU/MOFU | Webinar, eBook, Whitepaper, Newsletter | Build authority, capture lead |
| Consideration | MOFU | Case Study, Comparison Guide, ROI Calculator | Differentiate — vs alternatives |
| Intent | MOFU/BOFU | Demo Video, Free Trial, Pricing Page | Reduce friction to try |
| Decision | BOFU | Proposal Template, References, Contract FAQ | Remove objections |
| Retention | Post-sale | Onboarding Guide, Tips, Community | Expand & renew |

**Quy tắc:** Sales cần được tham gia tạo MOFU/BOFU content — họ biết objections thực tế.

---

## 6. Closed-Loop Reporting (Feedback Loop)

```
[Lead Created] ──▶ [MQL Qualified] ──▶ [SQL Confirmed] ──▶ [Deal Closed]
      ▲                                                           │
      │                                                           │
      └─────────── [Win/Loss Analysis] ◀─────── [Reason Recorded]
                         │
                         ▼
              [Content & Campaign Optimization]
```

**Dữ liệu cần capture tại mỗi bước:**
- Lead Created: Source, campaign, content asset, UTM parameters
- MQL→SQL reject: Lý do disqualify (no budget, wrong timing, wrong ICP, competitor)
- Deal Closed/Lost: Lý do thắng/thua, competitive intel, decision factors

**Frequency review:**
- Weekly: Volume metrics, conversion rates
- Monthly: Channel ROI, CAC, campaign attribution
- Quarterly: ICP refinement, scoring model recalibration, SLA renegotiation

---

## 7. Common Misalignment Patterns & Solutions

| Triệu chứng | Nguyên nhân gốc | Giải pháp |
|-------------|-----------------|-----------|
| "Marketing leads rác" | MQL threshold quá thấp, thiếu behavioral data | Raise threshold, thêm intent signals |
| "Sales không follow up" | Leads đến không đúng thời điểm, data thiếu | Improve routing, add context/insights khi assign |
| "Chúng tôi không biết content nào hiệu quả" | Thiếu closed-loop reporting | Tag UTM toàn bộ, map content → deals won |
| "Marketing không biết sales cần gì" | Không có định kỳ sync | Thiết lập Revenue Sync meeting hàng tuần |
| "Quota marketing và quota sales không thống nhất" | Thiếu shared OKRs | Co-own pipeline creation metric |
| "Deals nhỏ lẻ, không scale" | Targeting quá rộng | Hẹp ICP lại, tập trung segment có LTV cao |

---

## Quick Reference

| Hành động | Frequency | Owner |
|-----------|-----------|-------|
| Revenue Sync meeting | Hàng tuần | VP Sales + VP Marketing |
| Lead Quality Review | 2 tuần/lần | Marketing Ops + Sales Ops |
| MQL Scoring Recalibration | Hàng quý | Revenue Ops |
| ICP & Persona Update | Hàng quý | Sales + Marketing cùng nhau |
| Attribution Model Review | 6 tháng/lần | Marketing Analytics |
