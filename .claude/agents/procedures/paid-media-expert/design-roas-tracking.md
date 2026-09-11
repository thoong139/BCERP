# Playbook: Design ROAS Tracking & Attribution Module

> **Type**: Agent Skill Playbook
> **Agent**: paid-media-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần thiết kế attribution và ROAS tracking
> **Output**: Feature spec ROAS Tracking & Attribution tại `.mc-data/docs/phase2-features/`

---

## Khi nào dùng playbook này

- Khi cần spec module "ROAS Tracking", "Attribution", "Conversion Measurement" hoặc tương đương
- Khi thiết kế pixel/tag implementation, server-side tracking (CAPI)
- Khi cần thiết kế multi-touch attribution và cross-channel deduplication
- Khi thiết kế performance dashboard cho paid media

---

## Procedure

### Bước 1: Xác định scope

```
Hỏi hoặc suy luận từ requirements context:
□ Platforms nào cần tracking: Google / Meta / TikTok / LinkedIn?
□ Conversion event types: E-commerce purchase / Lead form / App install / Sign-up?
□ Attribution model đã quyết định (từ analyze-paid-media-requirements)?
□ Sales cycle length: <7 ngày (FMCG/Impulse) / 7–30 ngày (Considered) / >30 ngày (B2B)?
□ Privacy constraints: GDPR / CCPA / PDPA áp dụng không?
□ Revenue data source: E-commerce platform / CRM / Manual import?
□ Cần server-side tracking (CAPI) không? — Bắt buộc nếu có iOS users
```

### Bước 2: Thiết kế Conversion Event Taxonomy

```
Định nghĩa chuẩn event taxonomy TRƯỚC KHI implement bất kỳ pixel nào.
Tất cả platforms phải dùng cùng event names để cross-channel deduplication hoạt động.

Standard E-commerce Event Taxonomy:
| Event Name        | Trigger                           | Value Pass?  | Priority  |
|-------------------|-----------------------------------|--------------|-----------|
| page_view         | Mọi page load                     | Không        | Cơ sở     |
| view_content      | Product detail page               | Không        | Standard  |
| search            | Search query submit               | Không        | Standard  |
| add_to_cart       | Thêm sản phẩm vào giỏ             | Có (giá)     | Quan trọng|
| initiate_checkout | Bắt đầu checkout flow             | Có (total)   | Quan trọng|
| add_payment_info  | Nhập thông tin thanh toán          | Có (total)   | Quan trọng|
| purchase          | Đơn hàng xác nhận thành công      | Có (revenue) | Bắt buộc  |

Standard Lead Gen Event Taxonomy:
| Event Name        | Trigger                           | Value Pass?  | Priority  |
|-------------------|-----------------------------------|--------------|-----------|
| page_view         | Mọi page load                     | Không        | Cơ sở     |
| view_content      | Service/product landing page      | Không        | Standard  |
| lead              | Form submit (any lead form)       | Tuỳ chọn     | Bắt buộc  |
| complete_registration | Sign-up / Account creation   | Không        | Quan trọng|
| schedule          | Demo / appointment booking        | Không        | Quan trọng|
| contact           | Contact us submit                 | Không        | Standard  |

QUAN TRỌNG — Điều phải tránh:
□ KHÔNG đặt event name khác nhau cho cùng 1 hành động trên các platform
□ KHÔNG pass PII (email, phone, tên) vào event parameters — chỉ dùng hashed (SHA-256)
□ KHÔNG fire duplicate events cho cùng 1 conversion (deduplication là bắt buộc)
```

### Bước 3: Thiết kế Pixel / Tag Implementation Plan

```
READ: attribution.md → Section 6 (Privacy-First Measurement)
READ: platform-optimization.md → Section 5 (Landing Page QA Checklist — Tracking section)

Client-Side Tags (Browser Pixel) — Layer 1:
□ Meta Pixel (Base code + Event tracking)
  - Cài đặt qua Google Tag Manager (GTM)
  - Base code: Tất cả pages
  - Standard Events: purchase, lead, add_to_cart...
  - Custom Events: Nếu cần event ngoài standard list

□ Google Analytics GA4 (Tag + Events)
  - GA4 Configuration Tag trong GTM
  - Conversion events đánh dấu trong GA4 admin
  - Enhanced Ecommerce events nếu e-commerce

□ TikTok Pixel
  - TikTok Pixel base via GTM Custom HTML
  - Event tracking via dataLayer push

□ LinkedIn Insight Tag
  - 1 line script qua GTM Custom HTML
  - Conversion tracking via LinkedIn pixel

Tag Manager Setup:
□ Google Tag Manager container (Web + Server)
□ dataLayer schema chuẩn hóa cho mọi events
□ dataLayer.push() spec cho từng event type
□ Trigger conditions cho từng event
□ Testing: Preview mode + Tag Assistant + pixel debuggers

Server-Side Tags (CAPI) — Layer 2:
READ: attribution.md → Section 6 (Priority 1 — Server-Side Tracking)

Meta Conversions API (CAPI):
□ Kết nối Meta CAPI từ server (không phụ thuộc browser cookie/iOS restrictions)
□ Match Key: event_id (để dedup với pixel events), external_id (hashed user ID), fbc/fbp cookie
□ Events gửi qua CAPI: Tất cả micro và macro conversions
□ Payload: event_name, event_time (Unix), event_source_url, user_data (hashed), custom_data

Google Enhanced Conversions:
□ Gửi hashed conversion data (email/phone) từ server tới Google Ads
□ Match với Google account data để improve attribution

Deduplication Logic (bắt buộc khi dùng cả pixel + CAPI):
□ event_id: Tạo unique event ID khi event xảy ra → gửi cả pixel VÀ CAPI cùng event_id
□ Platform tự dedup dựa trên event_id (không count 2 lần)
□ Thời gian match window: CAPI event phải đến platform trong vòng 24 giờ sau pixel event
```

### Bước 4: Thiết kế Attribution Window Configuration

```
READ: attribution.md → Section 5 (Attribution Window Best Practices)

Attribution window settings (configurable per platform):

| Platform    | Click Window Options | View Window Options | Default Recommended   |
|-------------|---------------------|---------------------|-----------------------|
| Meta Ads    | 1d / 7d / 28d       | 1d (only)           | 7d click / 1d view    |
| Google Ads  | 1d / 7d / 30d       | 1d                  | 30d click / 1d view   |
| LinkedIn    | 1d / 7d / 30d       | 1d / 7d             | 30d click / 7d view   |
| TikTok Ads  | 1d / 7d             | 1d                  | 7d click / 1d view    |

QUAN TRỌNG: Mọi platform phải dùng CÙNG attribution window để cross-channel comparison công bằng.
Recommended standard: 7-day click / 1-day view (post-iOS 14 industry consensus)

Attribution model config:
□ Cho phép switch model mà không mất historical data
□ Lưu attribution model history (ai thay đổi, khi nào, lý do)
□ Re-calculate ROAS khi thay đổi model (backfill option)
```

### Bước 5: Thiết kế Multi-Touch Attribution & Cross-Channel Deduplication

```
READ: attribution.md → Section 3 (Cross-Channel Attribution Workflow)

Multi-Touch Attribution (MTA) system:
□ Capture toàn bộ touchpoints trong conversion path (ad impressions + clicks → conversion)
□ Assign credit theo model được chọn (Last-Click / Linear / Time-Decay / Data-Driven)
□ Store conversion path: event sequence với timestamps, channel, campaign, ad ID

Deduplication architecture:
1. User identification: Kết hợp cookie ID + hashed email + phone (probabilistic match)
2. Conversion dedup: 1 conversion chỉ được count 1 lần trong reporting, dù nhiều platform đều claim
3. Dedup key: order_id (e-commerce) hoặc lead_id (lead gen) — UNIQUE per conversion
4. Cross-platform reconciliation: Total attributed conversions ≤ total actual conversions

Data model:
  ConversionEvent:
    - id, dedup_key (order_id/lead_id), event_name
    - event_timestamp, event_source (pixel/capi/import)
    - user_id (internal, hashed), anonymous_id (cookie)
    - channel, platform, campaign_id, adset_id, ad_id
    - conversion_value, currency
    - attributed (boolean) — chỉ 1 event per dedup_key được mark là attributed
    - event_id (để dedup pixel vs CAPI)

  TouchpointPath:
    - conversion_event_id
    - touchpoints (JSON array: [{timestamp, channel, campaign_id, interaction_type}])
    - path_length, first_touch_channel, last_touch_channel
    - attributed_revenue (per model)
```

### Bước 6: Thiết kế ROAS Calculation

```
ROAS (Return on Ad Spend) formula chuẩn:
ROAS = Attributed Revenue / Ad Spend

Cần thiết kế ROAS ở nhiều levels:
□ Account-level ROAS (tổng chi tiêu vs tổng doanh thu attributed)
□ Platform-level ROAS (ví dụ: Meta ROAS = Meta Revenue / Meta Spend)
□ Campaign-level ROAS (per campaign)
□ Ad Set-level ROAS (per audience segment)
□ Ad-level ROAS (per creative — để biết creative nào hiệu quả)

ROAS data pipeline:
1. Ad spend: Kéo từ platform APIs (daily, per campaign/adset/ad)
2. Attributed revenue: Từ ConversionEvent table (filter: attributed = true, platform = X)
3. ROAS = SUM(attributed revenue) / SUM(ad spend) cho cùng time range + dimension

Budget optimization recommendations (tự động):
□ Nếu ROAS > target × 1.5 → Đề xuất tăng budget (scaling opportunity)
□ Nếu ROAS < target × 0.5 → Đề xuất giảm budget hoặc pause (performance issue)
□ So sánh ROAS của các campaigns → Đề xuất reallocate budget từ thấp → cao

QUAN TRỌNG — Phân biệt Platform ROAS vs Actual ROAS:
□ Platform ROAS: Số platform tự báo cáo (thường cao hơn thực tế do overlap + view-through)
□ Actual ROAS: Dựa trên deduplication logic của hệ thống
□ Report cả 2, note discrepancy để stakeholders hiểu
```

### Bước 7: Thiết kế Dashboard & Reporting

```
READ: attribution.md → Section 4 (Key Metrics Benchmarks per Channel)

Dashboard layers:

Executive View (Marketing Director):
□ Total spend vs budget (tất cả platforms)
□ Total attributed revenue và blended ROAS
□ ROAS trend (30/60/90 ngày)
□ Cost per acquisition (blended CPA)
□ Top performing channels (bar chart)

Campaign Manager View:
□ Spend, impressions, clicks, CTR per campaign
□ Conversions, CVR, CPA per campaign
□ ROAS per campaign vs target
□ Budget pacing (% spent vs % of period elapsed)
□ Alerts panel (underperforming campaigns)

Analytics Lead View:
□ Conversion path analysis (most common paths)
□ Assisted conversions per channel
□ Attribution model comparison (toggle giữa models)
□ Pixel/CAPI health (event match rate, dedup rate)
□ Platform-reported vs deduped conversion gap

Data refresh cadence:
□ Platform spend data: Kéo API mỗi 1 giờ (xem xét rate limits)
□ Conversion events: Real-time (CAPI) + hourly reconciliation
□ ROAS calculation: Cập nhật sau mỗi data pull
□ Historical reports: Frozen data, không retroactively change
```

### Bước 8: Thiết kế PII Compliance trong Tracking

```
PII Rules (BẮTBUỘC — vi phạm = critical bug):

□ KHÔNG bao giờ pass raw PII vào pixel events (email, phone, full name, address)
□ Hash PII trước khi gửi: SHA-256 lowercase, trimmed (Facebook/TikTok standard)
□ Consent gate: Tracking events CHỈ fire sau khi user cho phép (GDPR/PDPA)
□ IP anonymization: Bật IP anonymization trong GA4
□ Cookie consent: Respect user consent choice — nếu reject → chỉ fire analytics không có PII
□ Data retention: Conversion event raw data xóa sau 13 tháng (GDPR default)
□ Server-side CAPI: Được phép gửi hashed PII từ server (không bị iOS block)

Consent Management Platform (CMP) integration:
□ OneTrust / Cookiebot / custom CMP tích hợp với GTM Consent Mode
□ Google Consent Mode v2: Gửi consent signals cho Google tags
□ Meta Consent Mode: Dùng Limited Data Use (LDU) khi user không consent
□ TikTok: Opt-out API nếu cần
```

### Bước 9: Feature Spec Output

```markdown
# Feature Spec: ROAS Tracking & Attribution

## REQ-IDs

REQ-PAID-ATTR-001: Conversion event taxonomy chuẩn (tất cả platforms dùng cùng schema)
REQ-PAID-ATTR-002: Client-side pixel implementation (Meta Pixel, GA4, TikTok Pixel)
REQ-PAID-ATTR-003: Meta Conversions API (CAPI) server-side tracking
REQ-PAID-ATTR-004: Google Enhanced Conversions
REQ-PAID-ATTR-005: Event deduplication (pixel vs CAPI, cross-platform)
REQ-PAID-ATTR-006: Attribution window configuration per platform
REQ-PAID-ATTR-007: Multi-touch conversion path tracking
REQ-PAID-ATTR-008: ROAS calculation per dimension (platform/campaign/adset/ad)
REQ-PAID-ATTR-009: Cross-platform deduplication (1 conversion = 1 count)
REQ-PAID-ATTR-010: Budget optimization recommendations based on ROAS
REQ-PAID-RPT-001:  Executive dashboard (total spend, ROAS, CPA trend)
REQ-PAID-RPT-002:  Campaign manager dashboard (pacing, performance alerts)
REQ-PAID-RPT-003:  Conversion path analysis report
REQ-PAID-RPT-004:  Platform ROAS vs actual ROAS reconciliation report
REQ-PAID-PRIV-001: PII hashing trước khi gửi bất kỳ platform nào
REQ-PAID-PRIV-002: Consent gate — tracking chỉ fire sau consent
REQ-PAID-PRIV-003: IP anonymization trong analytics

## Data Model
[ConversionEvent, TouchpointPath, AdSpend entities như trên]

## Non-functional Requirements
- ROAS dashboard load: < 3 giây cho date range 90 ngày
- Pixel event firing: < 200ms sau trigger (không block page interaction)
- CAPI event delivery: < 60 giây sau server-side conversion event
- Data dedup accuracy: 99%+ (không đếm duplicate conversions)
- Event match rate (CAPI): Target ≥ 80% (Meta benchmark)
```

---

## Checklist trước khi submit

```
□ Conversion event taxonomy được định nghĩa trước khi thiết kế pixels
□ event_id deduplication logic được spec rõ (pixel + CAPI cùng event_id)
□ PII hashing requirement được noted rõ ràng (SHA-256)
□ Consent gate requirement được included
□ ROAS calculated ở đủ các levels (platform/campaign/adset/ad)
□ Platform ROAS vs actual ROAS distinction được giải thích
□ Attribution window được config per platform và documented
□ API rate limits (hourly data pull) được noted trong non-functional requirements
□ Data retention policy được specified
```
