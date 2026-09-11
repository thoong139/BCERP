# Marketing - Metrics Framework

> **Domain**: Marketing / Analytics & Performance Measurement
> **Last Updated**: 2026-03-16
> **Nguồn**: HubSpot, Gartner, SiriusDecisions Marketing Metrics Standards

---

## Tổng quan

Bộ metrics Marketing được tổ chức theo 4 nhóm: Acquisition, Pipeline, Retention, Brand.
Mỗi metric có formula, target benchmark, và cách đọc kết quả.

---

## Nhóm 1: Acquisition Metrics

### Efficiency Metrics

| Metric | Formula | Target | Đọc kết quả |
|--------|---------|--------|-------------|
| **CAC** (Customer Acquisition Cost) | Total Marketing + Sales Cost / # New Customers | < 1/3 LTV | Thấp hơn = tốt hơn |
| **CPL** (Cost per Lead) | Total Campaign Spend / # Leads | Theo channel | So sánh cùng channel |
| **CPA** (Cost per Acquisition) | Campaign Spend / # Conversions | Theo mục tiêu | Thấp hơn = tốt hơn |
| **ROAS** (Return on Ad Spend) | Revenue / Ad Spend × 100% | > 300% | Cao hơn = tốt hơn |
| **Payback Period** | CAC / (Monthly Revenue per Customer × Gross Margin) | < 12 tháng (B2B SaaS) | Ngắn hơn = tốt hơn |

### Volume Metrics

| Metric | Formula | Đọc kết quả |
|--------|---------|-------------|
| Lead Volume | # Leads per period | Trend quan trọng hơn số tuyệt đối |
| MQL Volume | # Marketing Qualified Leads per period | Phải tăng tỷ lệ với tổng leads |
| Lead Velocity Rate (LVR) | (MQL tháng này - tháng trước) / tháng trước × 100 | > 0% mỗi tháng |
| Organic Traffic | Sessions từ organic search | Tăng dần, giảm là vấn đề SEO |

---

## Nhóm 2: Pipeline Metrics

### Funnel Conversion Rates

| Stage | Metric | Formula | Benchmark |
|-------|--------|---------|-----------|
| Traffic → Lead | Landing Page CVR | Form Submits / Visitors | 3-8% |
| Lead → MQL | Lead Qualification Rate | MQLs / Leads × 100 | 20-40% |
| MQL → SQL | Sales Acceptance Rate | SQLs / MQLs × 100 | 30-50% |
| SQL → Opportunity | Opportunity Rate | Opps / SQLs × 100 | 50-70% |
| Opportunity → Customer | Win Rate | Won / Total Opps × 100 | 20-35% |
| **Full funnel** | Lead-to-Customer Rate | Customers / Leads × 100 | 1-5% |

### Pipeline Quality Metrics

| Metric | Formula | Đọc kết quả |
|--------|---------|-------------|
| **Pipeline Velocity** | (# Opps × Avg Deal Size × Win Rate) / Sales Cycle (days) | Đo tốc độ tạo revenue |
| **Pipeline Coverage** | Total Pipeline Value / Remaining Quota | Cần ≥ 3x để healthy |
| Marketing Contribution % | Revenue from Marketing-sourced Opps / Total Revenue × 100 | > 40% (B2B tech) |
| MQL-to-Revenue Cycle | Avg days từ MQL → Closed Won | Giảm dần |

---

## Nhóm 3: Retention Metrics

### Customer Health

| Metric | Formula | Target |
|--------|---------|--------|
| **Customer Retention Rate** | (Customers cuối kỳ - New customers) / Customers đầu kỳ × 100 | > 85% (annual, B2B) |
| **Churn Rate** | Churned Customers / Customers đầu kỳ × 100 | < 5% (annual, B2B SaaS) |
| **NPS** (Net Promoter Score) | % Promoters - % Detractors | > 50 = excellent, > 0 = acceptable |
| **CSAT** (Customer Satisfaction) | # Satisfied / Total Responses × 100 | > 80% |
| **CES** (Customer Effort Score) | Avg score trên scale 1-7 | < 3 (thấp = effort thấp = tốt) |

### Revenue Retention

| Metric | Formula | Target |
|--------|---------|--------|
| **MRR Churn Rate** | Churned MRR / MRR đầu kỳ × 100 | < 2% / tháng |
| **Net Revenue Retention (NRR)** | (Starting MRR + Expansion - Contraction - Churn) / Starting MRR × 100 | > 110% = best-in-class |
| **Gross Revenue Retention (GRR)** | (Starting MRR - Contraction - Churn) / Starting MRR × 100 | > 85% |
| **Expansion MRR** | New MRR từ upsell + cross-sell của existing customers | Tăng dần |
| **LTV** (Lifetime Value) | Avg Monthly Revenue × Gross Margin % / Monthly Churn Rate | Phải > 3× CAC |

### LTV:CAC Ratio Interpretation

| LTV:CAC | Đánh giá | Hành động |
|---------|----------|-----------|
| < 1:1 | Nguy hiểm — đang mất tiền | Tăng price hoặc giảm CAC ngay |
| 1:1 → 2:1 | Không bền vững | Tối ưu một trong hai phía |
| 3:1 | Healthy | Duy trì và scale |
| > 5:1 | Có thể đang under-invest | Xem xét tăng marketing spend |

---

## Nhóm 4: Brand Metrics

| Metric | Cách đo | Frequency | Ý nghĩa |
|--------|---------|-----------|---------|
| **Brand Awareness** | Unaided/Aided recall survey | Quarterly | % target audience biết brand |
| **Share of Voice (SOV)** | Brand mentions / Total category mentions | Monthly | Market presence vs competitors |
| **Brand Search Volume** | Branded keyword searches trên Google | Monthly | Organic brand interest |
| **Sentiment Score** | Positive mentions / Total mentions × 100 | Weekly | Sức khỏe reputation online |
| **Earned Media Value** | PR coverage × equivalent ad cost | Monthly | Giá trị PR so với paid |

---

## Channel Benchmarks (Vietnam Market)

| Channel | Typical CPL | CTR | Conversion Rate |
|---------|------------|-----|-----------------|
| Google Search | 300K-1.5M VND | 3-6% | 5-12% |
| Google Display | 100K-500K VND | 0.3-0.8% | 1-3% |
| Facebook/Instagram | 200K-800K VND | 1-2.5% | 2-6% |
| TikTok Ads | 150K-600K VND | 1.5-3% | 1.5-4% |
| LinkedIn Ads | 1M-4M VND | 0.4-0.8% | 2-5% |
| Email (owned list) | 30K-150K VND | CTR: 2-5% | 3-10% |
| Content/SEO | 50K-300K VND | - | 2-6% |

---

## Dashboard Requirements

### Marketing Executive Dashboard (Weekly)
- Pipeline contribution: MQL volume, MQL→Revenue %, Marketing-sourced revenue
- Efficiency: CAC trend, ROAS by channel, CPL by channel
- Funnel health: Lead volume, Conversion rates tại mỗi stage
- Budget: Spend vs plan, Projected vs actual

### Campaign Performance Dashboard (Daily)
- By channel: Spend, Impressions, Clicks, Leads, CPL, CVR
- Budget pacing: Remaining budget, projected month-end spend
- Creative performance: CTR by creative, A/B test results
- Lead quality: Score distribution, MQL rate

### Content Performance Dashboard (Weekly)
- Organic traffic: Total sessions, New users, Bounce rate
- Keyword rankings: Top 10 keywords, Ranking changes
- Content conversion: Form submits, CTA clicks per page
- Email metrics: Open rate, CTR, Unsubscribe rate

---

## Reporting Cadence

| Report | Frequency | Audience | Format |
|--------|-----------|----------|--------|
| Campaign performance alert | Real-time / Hourly | Campaign team | Automated alert |
| Daily performance | Daily | Campaign Specialist | Automated email |
| Weekly marketing summary | Weekly | Marketing team | Dashboard snapshot |
| Lead quality review | Weekly | Marketing + Sales | Shared report |
| Monthly ROI analysis | Monthly | Marketing Director | Slide deck |
| Quarterly strategy review | Quarterly | Leadership | Presentation |
