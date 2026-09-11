# Playbook: Phân tích Paid Media Requirements

> **Type**: Agent Skill Playbook
> **Agent**: paid-media-expert
> **Triggered by**: /wf-analyze-requirements khi có paid advertising / media buying modules
> **Output**: `.mc-data/docs/phase1-business/paid-media-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: paid advertising, media buying, PPC, Google Ads, Facebook Ads, Meta Ads, TikTok Ads, programmatic, ROAS, CPA, ad spend
- Khi cần xác định paid media requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại sản phẩm/dịch vụ (SaaS, E-commerce, Marketplace, App, B2B service...)
□ Business model (B2B / B2C / B2B2C)
□ Target market (SMB, Enterprise, Consumer...)
□ Giai đoạn tăng trưởng (Pre-launch / Early stage / Growth / Scale)
□ Đã có paid media infrastructure chưa? Nếu có → đang dùng platform nào?
□ Budget range dự kiến (để xác định platform phù hợp và data thresholds)
□ Mục tiêu chính: Brand awareness / Lead generation / E-commerce sales / App installs?
```

### Bước 2: Xác định scope paid media

```
READ: channels.md → Section 1 & 3 (Channel Selection Matrix)

Map business type với platform stack phù hợp:

| Business Type      | Platform ưu tiên                          |
|--------------------|-------------------------------------------|
| B2C E-commerce     | Meta Ads, Google Shopping, TikTok Ads     |
| B2B SaaS           | LinkedIn Ads, Google Search               |
| Local Service      | Google Search, Meta Ads (geo-targeted)    |
| DTC Fashion/Beauty | Meta/Instagram, TikTok, Pinterest         |
| Mobile App         | Meta App Install, Google UAC, TikTok Ads  |
| CPG/FMCG           | Meta Ads, TikTok Ads, Google Display      |

Xác định modules nào cần build:
□ Campaign Management (tạo, quản lý, theo dõi campaigns)
□ Budget Management (phân bổ, pacing, alerts)
□ Audience Management (targeting, custom audiences, lookalike)
□ Creative Library (quản lý assets, A/B testing)
□ Attribution & ROAS Tracking (conversion measurement, deduplication)
□ Reporting Dashboard (cross-channel performance)
□ Automation Rules (bid adjustments, budget pacing, alerts)
□ API Integrations (Meta Marketing API, Google Ads API, TikTok Ads API)
```

### Bước 3: Xác định personas bị ảnh hưởng

```
Xác định ai sẽ dùng paid media system:

□ Media Buyer / Campaign Manager → cần campaign creation, budget control, optimization
□ Analytics Lead / Performance Analyst → cần attribution data, ROAS dashboards, reporting
□ Finance Manager → cần budget approval workflow, spend reconciliation, invoice matching
□ Creative Specialist → cần creative library, A/B test management, asset versioning
□ Marketing Director → cần executive summary, cross-channel ROAS, budget overview

Với mỗi persona: note down pain points và must-have features
```

### Bước 4: Xác định Budget Management requirements

```
READ: channels.md → Section 4 (Budget Allocation Framework)

Budget management dimensions cần cover:
□ Budget hierarchy: Account-level cap → Campaign-level budget → Ad Set-level budget
□ Budget types: Daily budget / Lifetime budget / Shared budget (per platform logic)
□ Pacing model: Even delivery vs Accelerated delivery
□ Budget approval thresholds: Auto-approve / Manager / Director / Finance sign-off
□ Overspend prevention: Hard cap enforcement (đặc biệt quan trọng với Google Ads)
□ Budget utilization alerts: 50%, 80%, 95% spent notifications
□ Cross-platform budget reconciliation: So sánh planned vs actual spend
□ Seasonal adjustments: Tăng/giảm budget theo mùa vụ (xem channels.md Section 5)
```

### Bước 5: Xác định Attribution Model

```
READ: attribution.md → Section 1 & 2 (Attribution Models + Decision Guide)

Chọn attribution model dựa trên:
□ Data volume: ≥300 conversions/tháng → Data-Driven; ít hơn → các model khác
□ Sales cycle: <7 ngày → Last-Click hoặc Linear; >30 ngày → Time-Decay
□ Business goal: Brand awareness focus → Position-Based; Conversion focus → Last-Click
□ Multi-channel mix: Nhiều channels → Data-Driven hoặc Position-Based

Attribution windows cần config (per platform):
□ Meta Ads: Click 7 ngày / View 1 ngày (post-iOS 14 recommendation)
□ Google Ads: Click 30 ngày / View 1 ngày
□ LinkedIn Ads: Click 30 ngày / View 7 ngày (B2B sales cycle dài hơn)
□ TikTok Ads: Click 7 ngày / View 1 ngày

QUAN TRỌNG: Đồng bộ attribution window giữa các platform và CRM để tránh double-counting
```

### Bước 6: Xác định Integration points

```
Các integration cần thiết kế:

CRM Integration:
□ Conversion data flow: Ad platform → CRM lead record
□ Revenue attribution: Closed deal → Campaign source mapping
□ Audience sync: CRM segments → Custom Audiences upload

Analytics Integration:
□ GA4 / Analytics platform connection
□ UTM parameter passing và preservation
□ Cross-channel reporting view

Finance Integration:
□ Ad spend data → Accounting/ERP
□ Invoice matching (platform invoice vs actual spend)
□ Budget approval workflow với Finance team

Platform APIs:
□ Meta Marketing API (rate limits: 200 calls/hour per app)
□ Google Ads API (rate limits: theo developer token tier)
□ TikTok Ads API (rate limits: 100 calls/minute)
□ Error handling và retry logic cho mọi API calls

Server-Side Tracking:
READ: attribution.md → Section 6 (Privacy-First Measurement)
□ Meta Conversions API (CAPI) — bắt buộc sau iOS 14 changes
□ Google Enhanced Conversions
□ Server-side GTM container
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-PAID-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần - impact gì]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format:**
```
REQ-PAID-CAMP-001  → Campaign management
REQ-PAID-BUDG-001  → Budget management
REQ-PAID-AUD-001   → Audience management
REQ-PAID-CREA-001  → Creative library / A/B testing
REQ-PAID-ATTR-001  → Attribution & ROAS tracking
REQ-PAID-RPT-001   → Reporting & dashboard
REQ-PAID-AUTO-001  → Automation rules & alerts
REQ-PAID-INTG-001  → API integrations (platform APIs)
REQ-PAID-PRIV-001  → Privacy & compliance (GDPR, CAPI)
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/paid-media-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope paid media, platforms, budget range)
2. Platform Stack đề xuất (bảng: Platform | Mục tiêu | Priority)
3. Personas affected (bảng: Persona | Key needs | Pain points)
4. Attribution Model được chọn (lý do)
5. Requirements (theo module, có REQ-ID)
6. Integration Requirements
7. Privacy & Compliance Requirements
8. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-PAID-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng
□ Platform selection có justification (không chọn tùy tiện)
□ Attribution model được chọn và lý do được ghi rõ
□ CAPI / server-side tracking requirements đã included
□ Privacy/GDPR requirements đã covered
□ Budget approval thresholds đã xác định
□ API integration requirements (rate limits, error handling) đã noted
□ Open questions được list ra để stakeholders review
```
