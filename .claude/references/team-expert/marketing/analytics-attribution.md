# Marketing - Analytics & Attribution

> **Domain**: Marketing / Data Analytics & Performance Attribution
> **Last Updated**: 2026-03-16
> **Nguồn**: Google Analytics 4, HubSpot Attribution, Rockerbox Multi-touch

---

## Tổng quan

Marketing Analytics gồm 3 tầng:
1. **Tracking** — Thu thập data chính xác (UTM, pixels, events)
2. **Attribution** — Gán credit cho channels đã contribute vào conversion
3. **Analysis** — Rút ra insights từ data để optimize

---

## 1. UTM Tracking Standards

### UTM Parameter Definitions

| Parameter | Mục đích | Ví dụ giá trị |
|-----------|----------|---------------|
| `utm_source` | Nguồn traffic | `google`, `facebook`, `linkedin`, `newsletter` |
| `utm_medium` | Loại kênh | `cpc`, `social`, `email`, `organic`, `referral` |
| `utm_campaign` | Tên campaign | `spring-sale-2026`, `webinar-april`, `brand-awareness` |
| `utm_content` | Phân biệt creative | `hero-banner`, `text-link`, `cta-blue` |
| `utm_term` | Keyword (Paid Search) | `crm+software`, `marketing+tool` |

### UTM Naming Convention (bắt buộc nhất quán)

```
Quy tắc:
- Viết thường hoàn toàn (lowercase)
- Không dấu cách → dùng dấu gạch ngang (-)
- Ngắn gọn nhưng đủ nghĩa
- Date format: YYYY-MM (vào campaign name nếu cần)

Ví dụ đúng:
utm_source=linkedin&utm_medium=cpc&utm_campaign=b2b-leadgen-2026-q2

Ví dụ sai:
utm_source=LinkedIn&utm_medium=CPC&utm_campaign=B2B Lead Gen Q2 2026
```

### UTM Tracing Requirements

- **Auto-tagging**: Google Ads và LinkedIn Ads nên bật auto-tag
- **UTM preservation**: UTM phải được pass qua toàn bộ funnel đến CRM
- **Session tracking**: UTM gắn với session, không phải chỉ landing page
- **UTM database**: Lưu mọi UTM combinations dùng để audit sau

---

## 2. Event Tracking

### Standard Events (bắt buộc track)

| Event | Trigger | Data cần capture |
|-------|---------|-----------------|
| `page_view` | Mỗi page load | Page URL, Referrer, UTM |
| `form_submit` | Form submission | Form ID, Form type, Lead data |
| `cta_click` | Bấm CTA button | Button text, Page URL, Position |
| `content_download` | Download content | Content title, Type, UTM source |
| `demo_request` | Submit demo form | Lead data, Source, Score at time |
| `free_trial_start` | Begin trial | Account type, Source |
| `pricing_view` | Visit /pricing | Page duration, Scroll depth |
| `video_play` | Start video | Video title, Duration |
| `video_complete` | Watch > 75% | Video title |
| `email_open` | Open email | Campaign, Subject, Timestamp |
| `email_click` | Click email link | Campaign, Link, Destination |
| `login` | User logs in | User ID, Session ID |

### Conversion Events (mục tiêu đo attribution)

| Conversion | Giá trị | Ưu tiên |
|-----------|---------|---------|
| Demo request | High | Primary |
| Free trial sign-up | High | Primary |
| Paid subscription | Highest | Primary |
| Form submit (lead gen) | Medium | Secondary |
| Content download | Low-Medium | Secondary |
| Webinar registration | Medium | Secondary |

---

## 3. Attribution Models

### Single-Touch Models

| Model | Cách gán credit | Khi nào dùng | Hạn chế |
|-------|----------------|--------------|---------|
| **First Touch** | 100% credit cho touchpoint đầu tiên | Đo brand awareness campaigns | Bỏ qua mọi thứ sau |
| **Last Touch** | 100% credit cho touchpoint cuối cùng | Direct response, short cycle | Bỏ qua awareness |

### Multi-Touch Models

| Model | Cách gán credit | Khi nào dùng |
|-------|----------------|--------------|
| **Linear** | Chia đều cho mọi touchpoints | Sales cycle dài, mọi touch quan trọng |
| **Time Decay** | Credit tăng dần theo thời gian → gần conversion = nhiều hơn | Short-to-medium cycle |
| **Position-Based (U-Shape)** | 40% First + 40% Last + 20% cho giữa | Cân bằng awareness và conversion |
| **W-Shape** | 30% First + 30% MQL + 30% Last + 10% còn lại | B2B với nurture dài |
| **Data-Driven** | ML model học từ lịch sử data | Khi có đủ data volume (> 3000 conversions) |

### Attribution Model Comparison Example

```
Customer journey: Google Ad → Blog Post → Email Click → Demo Request
                  (Day 1)     (Day 5)      (Day 12)      (Day 15)

Model          Google Ad    Blog Post    Email Click   Demo Request
First Touch:   100%         0%           0%            0%
Last Touch:    0%           0%           0%            100%
Linear:        25%          25%          25%           25%
Time Decay:    5%           10%          35%           50%
U-Shape:       40%          10%          10%           40%
```

### Chọn Model nào?

```
B2B, sales cycle > 3 tháng → W-Shape hoặc Linear
B2C, impulse purchase → Last Touch
Brand-focused campaign → First Touch để đánh giá
Multi-channel scale → Data-Driven (nếu đủ data)
```

---

## 4. Funnel Analysis

### Standard Funnel Stages & Drop-off Analysis

```
Visitors → Leads → MQLs → SQLs → Opportunities → Customers
  100%      10%     3%     1.5%      1%              0.5%
         -90%    -70%    -50%      -33%             -50%
         Tại sao drop? Investigate từng stage
```

### Drop-off Investigation Framework

| Stage | Drop-off cao → Investigate | Câu hỏi cần trả lời |
|-------|---------------------------|---------------------|
| Visitor → Lead | Landing page CVR thấp | Copy rõ không? Form quá dài? Traffic quality? |
| Lead → MQL | Score không tăng | Content engagement? Sequence hiệu quả? Fit scoring đúng? |
| MQL → SQL | Sales reject nhiều | Lead quality? Persona không khớp? Score threshold sai? |
| SQL → Opportunity | Opportunity thấp | BANT criteria? Competition? Timing? |
| Opportunity → Customer | Win rate thấp | Pricing? Feature gaps? Sales execution? |

### Cohort Analysis

Phân tích nhóm customer theo thời gian để đo retention:

```
Cohort: Nhóm customers bắt đầu trong cùng tháng

Tháng   M0    M1    M2    M3    M6    M12
Jan-26  100%  72%   58%   50%   40%   32%
Feb-26  100%  75%   61%   53%   -     -
Mar-26  100%  70%   -     -     -     -

→ M1 retention benchmark: > 70%
→ M12 retention (annual) > 30%: concerning signal
```

---

## 5. Analytics Dashboard Specifications

### Executive Marketing Dashboard

**Audience**: CMO, Marketing Director
**Refresh**: Weekly

| Metric | Visualization | Period |
|--------|--------------|--------|
| MQL Volume & Trend | Line chart | MTD vs Last Month vs Last Year |
| Marketing-Sourced Pipeline | Bar chart | By month, vs target |
| CAC by Channel | Horizontal bar | Current quarter |
| LTV:CAC Ratio | KPI card | Current vs 3 months ago |
| Marketing ROI | KPI card with trend | MTD |
| NPS Trend | Line chart | Last 6 months |

### Campaign Performance Dashboard

**Audience**: Campaign Manager, Performance Marketer
**Refresh**: Daily

| Metric | Visualization |
|--------|--------------|
| Spend vs Budget (by channel) | Gauge chart |
| CPL by Channel | Bar chart |
| CTR by Creative | Table with sparklines |
| Conversion Funnel by Campaign | Funnel chart |
| A/B Test Results | Significance test widget |

### SEO & Content Dashboard

**Audience**: Content Manager, SEO Specialist
**Refresh**: Weekly

| Metric | Visualization |
|--------|--------------|
| Organic Sessions Trend | Line chart |
| Top Pages by Sessions | Ranked list |
| Keyword Rankings Changes | Table (up/down indicators) |
| Content Conversion Rate | Bar chart by content type |
| Backlink Profile Growth | Line chart |

---

## 6. Analytics System Requirements

| Feature | Mô tả | Priority |
|---------|--------|----------|
| **Cross-device tracking** | Track user across devices | Bắt buộc |
| **Server-side tracking** | Bypass ad blockers, iOS restrictions | Nên có |
| **First-party data** | Cookie-less tracking fallback | Nên có |
| **Real-time data** | Alert khi anomalies xảy ra | Nên có |
| **CRM integration** | Close-the-loop attribution (lead → revenue) | Bắt buộc |
| **Custom events** | Track business-specific events | Bắt buộc |
| **Segmentation** | Slice data theo bất kỳ dimension | Bắt buộc |
| **Export API** | Push data to data warehouse | Nên có |
| **GDPR compliance** | Data anonymization, consent-based tracking | Bắt buộc |
| **Data retention** | Configurable retention period | Bắt buộc |

---

## Quick Reference: Tool Stack

| Mục đích | Tools phổ biến |
|----------|----------------|
| Web Analytics | Google Analytics 4, Adobe Analytics |
| Attribution | Rockerbox, Triple Whale, Northbeam (e-comm), HubSpot |
| SEO | Ahrefs, SEMrush, Google Search Console |
| Email Analytics | Built-in (Mailchimp, HubSpot, ActiveCampaign) |
| Social Analytics | Sprout Social, Hootsuite, native platform |
| Data Warehouse | BigQuery, Snowflake, Redshift |
| BI/Visualization | Looker, Tableau, Google Looker Studio |
