# Playbook: Design Campaign Management Module

> **Type**: Agent Skill Playbook
> **Agent**: paid-media-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi có Paid Campaign Management module
> **Output**: Feature spec Campaign Management tại `.mc-data/docs/phase2-features/`

---

## Khi nào dùng playbook này

- Khi cần spec module "Quản lý Chiến dịch Quảng cáo Trả phí" hoặc tương đương
- Khi cần thiết kế campaign hierarchy, budget management, audience targeting cho paid channels
- Khi thiết kế creative library và A/B testing cho paid ads

---

## Procedure

### Bước 1: Xác định scope

```
Hỏi hoặc suy luận từ requirements context:
□ Platforms cần support: Google Ads / Meta Ads / TikTok Ads / LinkedIn / Programmatic?
□ Campaign objectives: Brand awareness / Lead gen / E-commerce / App installs?
□ Team size: Solo media buyer vs multi-person team (ảnh hưởng approval workflow)
□ Budget scale: <$10k/tháng / $10–100k/tháng / >$100k/tháng (ảnh hưởng automation level)
□ A/B testing: Cần không? Mức phức tạp nào? (creative / audience / landing page)
□ Reporting depth: Basic summary hay full funnel attribution?
□ External platform sync: Cần kéo data từ APIs về hay chỉ quản lý nội bộ?
```

### Bước 2: Thiết kế Campaign Hierarchy

```
READ: channels.md → Section 2 (Chi tiết từng kênh)
READ: platform-optimization.md → Section 1 (Google Ads Structure) + Section 2 (Meta Ads)

Standard Paid Media Hierarchy (mirror platform structure):

Account (Ad Account)
└── Campaign (1 objective, 1 total budget, 1 platform)
    └── Ad Set / Ad Group (1 audience segment, 1 bid strategy)
        └── Ad / Creative (1 bản quảng cáo cụ thể)
            └── Variant (A/B test variant — chỉ khác nhau 1 yếu tố)

Platform-specific mapping:
| System Level  | Google Ads    | Meta Ads      | TikTok Ads    | LinkedIn Ads      |
|---------------|---------------|---------------|---------------|-------------------|
| Campaign      | Campaign      | Campaign      | Campaign      | Campaign          |
| Ad Group      | Ad Group      | Ad Set        | Ad Group      | Campaign Group    |
| Ad            | Ad            | Ad            | Ad            | Sponsored Content |
```

**Data model Campaign:**
```
Campaign:
  - id, name, status (draft/review/approved/scheduled/active/paused/completed/archived)
  - platform (google/meta/tiktok/linkedin/microsoft/amazon)
  - objective (awareness/consideration/conversion/app_install/lead_gen)
  - budget_type (daily/lifetime)
  - budget_amount, currency
  - budget_cap_enforcement (hard/soft) — hard cap = KHÔNG chi vượt
  - start_date, end_date
  - timezone
  - owner_id, team_id, approval_status
  - external_campaign_id (platform's own ID, sau khi sync)
  - created_at, updated_at

AdSet:
  - campaign_id, name, status
  - audience_config (JSON) — targeting parameters
  - bid_strategy (lowest_cost/target_cpa/target_roas/manual_cpc)
  - bid_amount (nếu manual)
  - budget_override (optional, nếu có per-adset budget)
  - schedule_config (dayparting JSON) — khung giờ chạy ads
  - placement_config (JSON) — feed/story/reels/search...
  - external_adset_id

Ad:
  - adset_id, name, status
  - format (image/video/carousel/collection/responsive/lead_form)
  - headline (array, tối đa 15 cho RSA Google)
  - description (array)
  - cta_text, destination_url
  - display_url (Google Search)
  - asset_refs (JSON array — tham chiếu Creative Library)
  - variant_group_id (null nếu không A/B test)
  - variant_label (A/B/C)
  - external_ad_id
  - performance_snapshot (JSON — cached metrics)
```

### Bước 3: Thiết kế Budget Management

```
READ: channels.md → Section 4 (Budget Allocation Framework)
READ: channels.md → Section 5 (Seasonal Budgeting)

Budget management layers:
1. Account-level monthly cap (bảo vệ tổng chi)
2. Campaign-level budget (daily hoặc lifetime)
3. Ad Set-level budget (optional override cho phân khúc ưu tiên)

Budget approval workflow:
| Budget Range (USD/tháng) | Approval Required                |
|--------------------------|----------------------------------|
| < $1,000                 | Auto-approve (Media Buyer tự quyết) |
| $1,000 – $10,000         | Marketing Manager approval       |
| $10,000 – $50,000        | Director approval                |
| > $50,000                | Director + Finance sign-off      |

Budget pacing alerts (system tự gửi notification):
□ 50% budget consumed → Thông báo informational
□ 80% budget consumed → Thông báo cảnh báo
□ 95% budget consumed → Thông báo khẩn, gợi ý pause hoặc top-up
□ Vượt budget (chỉ xảy ra khi soft cap) → Alert critical

Overspend prevention:
□ Hard cap: System từ chối tạo thêm spend khi đạt limit (call API để pause)
□ Daily budget guard: Nếu daily spend × ngày còn lại > lifetime budget → tự điều chỉnh daily
□ Cross-platform reconciliation: So sánh platform-reported spend vs actual invoice daily
```

### Bước 4: Thiết kế Audience Management

```
READ: platform-optimization.md → Section 2 (Meta Audience Layering)
READ: platform-optimization.md → Section 3 (LinkedIn Targeting)

Audience types cần support:
□ Interest/Demographic targeting (natively platform-defined)
□ Custom Audiences: Website visitors (Pixel-based), Customer list (email upload/hash), App users
□ Lookalike Audiences: 1–10% similarity từ seed audience
□ Retargeting segments: View-through, click-through, add-to-cart, checkout-abandoned
□ Exclusion audiences: Existing customers, recent converters (tránh waste spend)

Audience data model:
  Audience:
    - id, name, type (interest/custom/lookalike/retargeting)
    - platform, size_estimate
    - source_audience_id (cho lookalike)
    - definition (JSON — targeting rules)
    - last_refresh_date (custom audiences decay)
    - external_audience_id

Audience management requirements:
□ REQ-PAID-AUD-001: Tạo/edit/archive custom audiences
□ REQ-PAID-AUD-002: Upload customer list với hashing (SHA-256 cho email/phone) trước khi gửi platform
□ REQ-PAID-AUD-003: Schedule auto-refresh custom audiences hàng tuần
□ REQ-PAID-AUD-004: Audience overlap detection (tránh serving cùng 1 người từ nhiều ad sets)
□ REQ-PAID-AUD-005: Exclusion list management (global exclusions áp dụng cho toàn account)
```

### Bước 5: Thiết kế Creative Library

```
Creative Library requirements:
□ Upload và lưu trữ: Images (JPG/PNG, max 30MB), Videos (MP4/MOV, max 4GB)
□ Asset metadata: Name, tags, dimensions, format, platform suitability check
□ Versioning: Lưu lịch sử các phiên bản creative
□ Usage tracking: Creative này đang chạy ở ad nào, performance như thế nào
□ Expiry management: Creative hết hạn (seasonal, copyright) → alert trước 7 ngày
□ Platform specs validation: Tự check file size, dimensions, text-on-image % (Meta: <20% text)

A/B Test structure:
READ: platform-optimization.md → Section 6 (A/B Testing Framework)

□ Chỉ test 1 biến tại 1 thời điểm (1 variant group = 1 biến thay đổi)
□ Traffic split: Mặc định 50/50; configurable
□ Statistical significance threshold: 95% confidence (không kết luận sớm)
□ Minimum runtime: 2–4 tuần (tránh day-of-week bias)
□ Minimum sample: ≥100 conversions per variant trước khi declare winner
□ Auto-declare winner khi đạt threshold → auto-pause loser variant
□ Test learnings log: Lưu kết quả test để tham khảo về sau

Test types:
| Test Type            | Biến test              | Duration |
|----------------------|------------------------|----------|
| Creative hook        | 3 giây đầu video/image | 7–14 ngày |
| Headline copy        | Headline text          | 7–14 ngày |
| CTA text             | Button text            | 7 ngày   |
| Visual format        | Image vs Video         | 14 ngày  |
| Audience segment     | Targeting parameters   | 14 ngày  |
| Landing page         | Destination URL        | 14–21 ngày |
```

### Bước 6: Thiết kế Scheduling & Dayparting

```
Scheduling requirements:
□ Campaign start/end datetime (per timezone)
□ Dayparting (Ad Schedule): Config giờ chạy per day-of-week
□ Seasonal budget multipliers: Tự tăng budget trong peak season
□ Auto-pause rules: Dừng khi hit budget cap / khi performance dưới threshold
□ Time-based rules: Pause vào ban đêm (nếu target audience không active)

Automated Rules engine (cần nếu scale lớn):
□ Rule trigger: Condition (spend, CPA, ROAS, CTR, etc.) + Threshold + Time window
□ Rule action: Pause / Resume / Increase bid / Decrease bid / Send alert
□ Rule scheduling: Run once / Hourly / Daily / Weekly
□ Rule conflict resolution: Priority order khi nhiều rules trigger cùng lúc
□ Audit log: Mọi automated action phải được log với rule ID + timestamp + before/after values
```

### Bước 7: Thiết kế Performance Benchmarks

```
READ: attribution.md → Section 4 (Key Metrics Benchmarks per Channel)
READ: platform-optimization.md → Section 1 (Google Ads Bidding Guide)

Performance KPIs per channel:

| Kênh          | CTR Target | CVR Target | ROAS Target (E-com) | CPA Target (Lead gen) |
|---------------|-----------|------------|---------------------|----------------------|
| Google Search | 3–8%      | 3–10%      | 4–8x                | Tuỳ ngành            |
| Meta Ads      | 0.5–1.5%  | 1–5%       | 2–5x                | Tuỳ ngành            |
| TikTok Ads    | 0.3–1.0%  | 1–3%       | 2–4x                | Tuỳ ngành            |
| LinkedIn Ads  | 0.4–0.8%  | 2–7%       | 2–4x                | $50–200 CPL          |

Performance alerts (tự động):
□ CPA > 2× target → Alert + đề xuất pause
□ CTR < 50% benchmark → Alert về creative quality
□ ROAS < minimum threshold → Alert + đề xuất review targeting
□ Zero impressions trong 24h khi campaign active → Alert (có thể bị reject hoặc lỗi)
□ Conversion rate drops >30% day-over-day → Alert (tracking issue?)
```

### Bước 8: Feature Spec Output

```markdown
# Feature Spec: Paid Campaign Management

## REQ-IDs

REQ-PAID-CAMP-001: Campaign CRUD với hierarchy đầy đủ (Account → Campaign → Ad Set → Ad)
REQ-PAID-CAMP-002: Multi-platform support (Google, Meta, TikTok, LinkedIn)
REQ-PAID-CAMP-003: Campaign status state machine (Draft → Review → Approved → Active → ...)
REQ-PAID-CAMP-004: Budget approval workflow theo threshold
REQ-PAID-CAMP-005: Hard budget cap enforcement (no overspend)
REQ-PAID-CAMP-006: Budget pacing alerts (50%/80%/95%)
REQ-PAID-CAMP-007: Dayparting (ad schedule) configuration
REQ-PAID-CAMP-008: Automated rules engine (trigger-based actions)
REQ-PAID-CAMP-009: Creative Library với version control
REQ-PAID-CAMP-010: A/B testing engine với statistical significance tracking
REQ-PAID-AUD-001:  Custom audience management (upload, refresh, exclude)
REQ-PAID-AUD-002:  Audience PII hashing trước khi upload lên platform

## Data Model
[Campaign, AdSet, Ad, Audience, Creative entities như trên]

## API Endpoints cần thiết kế
POST /campaigns          → Tạo campaign
PUT  /campaigns/:id      → Cập nhật
POST /campaigns/:id/approve → Approval action
GET  /campaigns/:id/performance → Metrics
POST /audiences          → Tạo audience
POST /creatives          → Upload creative asset
POST /ab-tests           → Khởi chạy A/B test

## Non-functional Requirements
- Campaign list load: < 2 giây với 1000+ campaigns
- Real-time performance metrics: refresh mỗi 1 giờ (API rate limit constraint)
- Creative upload: Support up to 4GB video, progress indicator
- A/B test significance calculation: < 1 giây (server-side)
- Automated rules execution: Chạy every 15 phút
```

---

## Checklist trước khi submit

```
□ Campaign hierarchy mirror đúng structure của từng platform
□ Budget cap enforcement được spec rõ (hard vs soft)
□ Approval workflow có thresholds rõ ràng
□ A/B test chỉ test 1 biến tại 1 thời điểm
□ Audience PII hashing requirement được noted
□ Automated rules có audit log
□ Performance benchmarks per channel được reference
□ API rate limits được ghi nhận trong non-functional requirements
```
