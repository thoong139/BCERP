# Marketing Domain - Growth Marketing Framework

> **Domain**: Marketing / Growth Marketing, Experimentation, App Marketing
> **Last Updated**: 2026-03-15
> **Nguồn**: Tổng hợp từ Growth Hacking, ASO, Product-Led Growth best practices

---

## 1. Growth Funnel (AARRR Framework)

### Pirate Metrics

```
┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐
│ Acquisition│──▶│ Activation │──▶│ Retention  │──▶│  Revenue   │──▶│  Referral  │
│ (Thu hút)  │   │ (Kích hoạt)│   │ (Giữ chân) │   │ (Doanh thu)│   │ (Giới thiệu)│
└────────────┘   └────────────┘   └────────────┘   └────────────┘   └────────────┘
      │                │                │                │                │
      ▼                ▼                ▼                ▼                ▼
  Traffic          First value       Return usage      Payment        Share/Invite
  Sign-ups         "Aha moment"     Habit loop        Upgrade         K-factor
  Installs         Onboarding       Engagement        Expansion       Viral loop
```

### Stage Metrics & Targets

| Stage | Primary Metric | Secondary Metrics | Benchmark |
|-------|---------------|-------------------|-----------|
| **Acquisition** | CAC (Customer Acquisition Cost) | Traffic volume, Sign-up rate | CAC < 1/3 LTV |
| **Activation** | Activation rate (% users reaching "Aha moment") | Time to value, Onboarding completion | > 60% trong tuần đầu |
| **Retention** | Retention rate (D1/D7/D30) | DAU/MAU ratio, Churn rate | D7 > 40%, D30 > 20% |
| **Revenue** | ARPU (Average Revenue Per User) | Conversion to paid, Expansion revenue | Per industry |
| **Referral** | K-factor (Viral coefficient) | Invite rate, Referral conversion | K > 0.5 (K > 1 = viral) |

### North Star Metric Examples

| Loại sản phẩm | North Star Metric | Giải thích |
|---------------|-------------------|------------|
| SaaS B2B | Weekly Active Teams | Đo adoption + collaboration |
| E-commerce | Weekly Purchases | Đo repeat buying behavior |
| Marketplace | Weekly Transactions | Đo liquidity + both sides |
| Content/Media | Daily Time Spent | Đo engagement depth |
| Social Network | Daily Active Users (DAU) | Đo network health |
| Mobile App | Weekly Active Users (WAU) | Đo habit formation |

---

## 2. Experimentation Framework

### A/B Testing Process

```
Hypothesis → Design → Implement → Run → Analyze → Decide → Document
     │           │          │        │        │         │          │
     ▼           ▼          ▼        ▼        ▼         ▼          ▼
  Problem     Variants   Feature   Traffic  Stats    Ship or    Learning
  + Expected  Control    flags     split    signif.  kill       repository
  impact      Treatment  SDK       duration p-value  rollout    share
```

### Experiment Design Requirements

| Component | Yêu cầu | System Support |
|-----------|---------|----------------|
| Hypothesis | Rõ ràng, đo lường được: "Nếu [thay đổi X], thì [metric Y] sẽ [tăng/giảm Z%]" | Template form |
| Sample size | Tính trước minimum sample cho statistical power (thường 80%) | Calculator tool |
| Duration | Minimum 7 ngày HOẶC đạt statistical significance | Auto-stop rules |
| Variants | Max 4 variants per test, 1 control | Experiment engine |
| Metrics | 1 primary metric + 2-3 guardrail metrics | Dashboard |
| Significance | 95% confidence level (p < 0.05) | Auto-calculation |
| Segmentation | Phân tích results theo segments (device, geo, cohort) | Analytics |
| Documentation | Kết quả + learnings lưu vào knowledge base | Repository |

### Experiment Prioritization (ICE Framework)

| Tiêu chí | Thang điểm | Mô tả |
|----------|-----------|--------|
| **I**mpact | 1-10 | Ảnh hưởng đến metric chính nếu thành công |
| **C**onfidence | 1-10 | Mức tin tưởng experiment sẽ thành công |
| **E**ase | 1-10 | Dễ implement (thời gian, resources) |
| **ICE Score** | I × C × E / 10 | Ưu tiên score cao nhất |

### Experiment Velocity Targets

| Giai đoạn | Experiments/tháng | Focus |
|-----------|-------------------|-------|
| Early stage | 10-20 | Tìm product-market fit, channel fit |
| Growth stage | 15-30 | Optimize funnel, scale channels |
| Mature stage | 10-15 | Incremental improvements, retention |

---

## 3. Viral & Referral Mechanics

### Viral Loop Types

| Loại | Cơ chế | Ví dụ | K-factor tiềm năng |
|------|--------|-------|---------------------|
| **Word-of-mouth** | User tự nhiên giới thiệu | Slack, Notion | 0.3-0.7 |
| **Incentivized referral** | Thưởng cho cả 2 bên | Dropbox, Uber | 0.5-1.5 |
| **Collaborative** | Sản phẩm hay hơn khi có nhiều người | Google Docs, Figma | 0.8-2.0 |
| **Embedded** | Logo/link trong output | "Made with X" | 0.2-0.5 |
| **Social sharing** | Nội dung đáng chia sẻ | Spotify Wrapped | 0.3-1.0 |

### Viral Coefficient Formula

```
K-factor = (Invites per user) × (Conversion rate of invites)

Ví dụ: Mỗi user mời 5 người, 20% accept
K = 5 × 0.20 = 1.0 (viral threshold)

K < 1: Growth cần paid/organic channels bổ sung
K = 1: Self-sustaining (mỗi user mang về đúng 1 user mới)
K > 1: Viral growth (exponential)
```

### Referral Program Requirements

| Feature | Mô tả | Priority |
|---------|--------|----------|
| Unique referral link/code | Mỗi user có link riêng, trackable | Bắt buộc |
| Double-sided incentive | Thưởng cả người giới thiệu và người được giới thiệu | Bắt buộc |
| Real-time tracking | Dashboard hiển thị invites, conversions, rewards | Bắt buộc |
| Fraud detection | Chống self-referral, fake accounts | Bắt buộc |
| Reward tiers | Tăng reward theo số referrals thành công | Nên có |
| Social sharing | Easy share qua email, social media, messaging apps | Nên có |
| Attribution window | Thời gian tối đa để conversion được tính | Bắt buộc |

---

## 4. User Activation & Onboarding

### Activation Requirements

| Component | Mô tả | System Support |
|-----------|--------|----------------|
| "Aha moment" definition | Xác định hành động cụ thể = user nhận được giá trị | Analytics event tracking |
| Onboarding flow | Guided experience đưa user đến "Aha moment" nhanh nhất | Step-by-step wizard |
| Progress tracking | Hiển thị progress (checklist, progress bar) | UI component |
| Contextual tooltips | Hướng dẫn in-app tại đúng thời điểm | Tooltip engine |
| Email onboarding | Drip sequence hỗ trợ activation | Email automation |
| Friction removal | Giảm thiểu steps đến "Aha moment" | Funnel analysis |

### Onboarding Metrics

| Metric | Mô tả | Target |
|--------|--------|--------|
| Time to value | Thời gian từ sign-up đến "Aha moment" | Càng ngắn càng tốt |
| Onboarding completion rate | % users hoàn thành onboarding flow | > 70% |
| Feature adoption rate | % users dùng core features trong tuần đầu | > 50% |
| Drop-off points | Bước nào users bỏ nhiều nhất | Optimize continuously |

---

## 5. Retention & Engagement

### Cohort Analysis Framework

| Cohort Type | Phân nhóm theo | Ứng dụng |
|-------------|---------------|----------|
| Acquisition cohort | Tuần/tháng đăng ký | So sánh retention theo thời gian |
| Behavioral cohort | Hành động cụ thể (activated/not) | Đánh giá impact của feature |
| Channel cohort | Nguồn traffic (organic/paid/referral) | So sánh quality theo channel |
| Plan cohort | Free/paid tier | Phân tích conversion patterns |

### Retention Curve

```
100% ┤
     │╲
     │ ╲
     │  ╲
     │   ╲───────────────── Tốt: curve flatten (habit formed)
     │    ╲
     │     ╲________________ OK: slow decline
     │      ╲
     │       ╲
     │        ╲_____________ Xấu: continuous decline
  0% ┤─────────────────────────
     D1   D7   D14  D30  D90

Target: Curve phải flatten trước D30.
Nếu không → product-market fit chưa đạt.
```

### Engagement Scoring

| Signal | Điểm | Decay | Ý nghĩa |
|--------|------|-------|---------|
| Daily login | +1 | Daily | Active usage |
| Core action (tạo, edit) | +5 | 7 ngày | Value creation |
| Collaboration (invite, share) | +10 | 14 ngày | Network effect |
| Purchase/upgrade | +20 | 30 ngày | Revenue signal |
| Feature exploration | +3 | 7 ngày | Depth of usage |
| Inactive 7+ ngày | -10 | - | Churn risk |

---

## 6. Unit Economics

### Key Formulas

| Metric | Công thức | Target |
|--------|-----------|--------|
| **CAC** (Customer Acquisition Cost) | Tổng chi phí marketing + sales / Số khách mới | Càng thấp càng tốt |
| **LTV** (Lifetime Value) | ARPU × Gross Margin × Avg Customer Lifespan | LTV:CAC ≥ 3:1 |
| **CAC Payback Period** | CAC / (ARPU × Gross Margin) | < 12 tháng |
| **LTV:CAC Ratio** | LTV / CAC | ≥ 3:1 |
| **Monthly Churn Rate** | Số khách mất / Tổng khách đầu tháng | < 5% (B2B SaaS: < 2%) |
| **Net Revenue Retention** | (MRR đầu kỳ + expansion - churn - contraction) / MRR đầu kỳ | > 100% (SaaS: > 110%) |

### CAC by Channel

| Channel | CAC Range (tương đối) | Quality | Scale |
|---------|----------------------|---------|-------|
| Organic/SEO | Thấp | Cao | Chậm |
| Content marketing | Thấp-TB | Cao | Chậm |
| Referral | Thấp | Rất cao | Trung bình |
| Social organic | Thấp | Trung bình | Chậm |
| Paid search | Trung bình | Cao | Nhanh |
| Paid social | Trung bình | Trung bình | Nhanh |
| Display/Programmatic | Cao | Thấp | Nhanh |
| Outbound sales | Rất cao | Cao (B2B) | Chậm |

---

## 7. App Store Optimization (ASO)

### ASO Elements

| Element | Platform | Tối ưu | Impact |
|---------|----------|--------|--------|
| App Title | iOS + Android | Primary keyword + brand (30/50 chars) | Rất cao |
| Subtitle | iOS only | Key benefit + secondary keyword (30 chars) | Cao |
| Short Description | Android only | Hook + value prop + CTA (80 chars) | Cao |
| Long Description | Cả 2 | Feature list, keywords tự nhiên, social proof | Trung bình (Android cao hơn) |
| Keywords field | iOS only | 100 chars, separated by commas | Cao |
| App Icon | Cả 2 | Recognizable ở mọi size, đặc biệt 16x16px | Rất cao |
| Screenshots | Cả 2 | 5-10 screenshots, hero shot đầu tiên | Rất cao |
| Preview Video | Cả 2 | 15-30s, hook trong 3 giây đầu | Cao |
| Rating & Reviews | Cả 2 | Target ≥ 4.5 stars | Rất cao |

### ASO Requirements cho Software

| Feature | Mô tả | Priority |
|---------|--------|----------|
| Keyword tracking | Theo dõi ranking cho target keywords | Cao |
| Competitor monitoring | So sánh ranking, ratings với đối thủ | Cao |
| Review management | Theo dõi, phân loại, trả lời reviews | Cao |
| A/B testing | Test icon, screenshots, descriptions | Trung bình |
| Localization | Multi-language store listings | Tùy dự án |
| Rating prompt | In-app prompt timing optimization | Cao |
| Conversion funnel | Impression → Page view → Install → Activation | Cao |

### Mobile User Acquisition Channels

| Channel | Mô tả | Best For | Metric |
|---------|--------|----------|--------|
| Apple Search Ads | Keyword-based trong App Store | High-intent installs | CPI, CR |
| Google App Campaigns | Cross-Google inventory (Search, Play, YouTube, Display) | Scale installs | CPI, ROAS |
| Facebook/Instagram App Ads | Social install campaigns | Targeted installs | CPI, D7 retention |
| TikTok App Ads | Video-based install campaigns | Young audience | CPI, engagement |
| Influencer marketing | Creator-driven installs | Authentic discovery | CPI, quality |
| Cross-promotion | Promote trong apps khác cùng portfolio | Free/cheap installs | CPI |
| ASO (organic) | Store optimization | Sustainable growth | Organic install rate |

---

## Quick Reference: Growth Experiment Ideas by Stage

| Funnel Stage | Experiment Ideas |
|-------------|-----------------|
| **Acquisition** | Landing page variants, ad creative A/B, new channel test, referral incentive, SEO content experiment |
| **Activation** | Onboarding flow simplification, tooltip timing, welcome email sequence, "Aha moment" shortcut |
| **Retention** | Push notification timing, feature discovery nudge, usage milestone rewards, re-engagement email |
| **Revenue** | Pricing page layout, trial length, upgrade prompt timing, payment method options, annual discount |
| **Referral** | Referral reward amount, sharing mechanism, invite message copy, double-sided vs single-sided |

---

## Quick Reference: Growth Stack Requirements

| Layer | Components | Priority |
|-------|-----------|----------|
| **Analytics** | Event tracking, funnel analysis, cohort analysis, attribution | Bắt buộc |
| **Experimentation** | Feature flags, A/B testing engine, statistical analysis | Bắt buộc |
| **Personalization** | User segmentation, dynamic content, recommendation engine | Nên có |
| **Automation** | Email/push sequences, behavioral triggers, lifecycle campaigns | Bắt buộc |
| **Referral** | Referral tracking, reward system, fraud detection | Nên có |
| **Feedback** | In-app surveys, NPS, feature requests, review prompts | Nên có |
