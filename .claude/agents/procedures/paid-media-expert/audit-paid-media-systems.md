# Playbook: Audit Existing Paid Media Systems

> **Type**: Agent Skill Playbook
> **Agent**: paid-media-expert
> **Triggered by**: /wf-legacy-scan khi có paid advertising infrastructure
> **Output**: `.mc-data/docs/phase1-business/paid-media-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống paid advertising / media buying
- Khi cần đánh giá hiệu quả chi tiêu quảng cáo hiện tại
- Khi cần tìm gaps trước khi thiết kế lại hoặc migrate platform
- Khi stakeholders cần baseline trước khi commit budget mới

---

## Procedure

### Bước 1: Inventory Ad Accounts & Platforms

```
Thu thập từ stakeholders hoặc codebase (config files, integration settings):

□ Danh sách tất cả ad accounts đang hoạt động:
  - Platform (Google Ads / Meta Ads / TikTok Ads / LinkedIn / Microsoft / Amazon)
  - Account ID
  - Account name
  - Monthly spend (ước tính)
  - Trạng thái: Active / Paused / Suspended

□ Quyền truy cập:
  - Ai có admin access? Ai chỉ có view access?
  - MCC (My Client Center) Google có không? Business Manager Meta có không?
  - API access đã setup chưa? Credentials ở đâu?

□ Payment methods:
  - Credit card / Invoice / Prepaid?
  - Billing threshold setting (auto-charge khi reach threshold)
  - Credit limit per account
```

### Bước 2: Phân tích Spend by Platform, Campaign, Audience

```
READ: channels.md → Section 4 (Budget Allocation Framework)

Thu thập spend data (ideally 90 ngày gần nhất):

Spend Analysis:
□ Total spend per platform (tháng gần nhất + 3 tháng rolling)
□ Spend trend: tăng/giảm/stable theo tháng?
□ Budget utilization: % tháng nào underspend / overspend?

Campaign-level breakdown:
□ Top 10 campaigns theo spend
□ Top 10 campaigns theo conversions
□ Campaigns không có conversions trong 30 ngày (waste spend?)
□ Paused campaigns: Tại sao pause? Vẫn còn relevant?

Audience-level breakdown:
□ Spend per audience segment (Prospecting vs Remarketing vs Retention)
□ Phân bổ theo funnel stage: TOFU / MOFU / BOFU
□ So sánh với ideal: 20–30% Awareness / 30–40% Consideration / 40–50% Conversion

Note: Nếu không có access trực tiếp, yêu cầu stakeholders export từ platform dashboards.
```

### Bước 3: ROAS / CPA Baseline per Channel

```
READ: attribution.md → Section 4 (ROAS & CPA Benchmarks per Channel)

Collect performance metrics per channel (90 ngày):

| Metric        | Google Ads | Meta Ads | TikTok Ads | LinkedIn | Blended |
|---------------|------------|----------|------------|----------|---------|
| Total Spend   | ?          | ?        | ?          | ?        | ?       |
| Conversions   | ?          | ?        | ?          | ?        | ?       |
| Revenue       | ?          | ?        | ?          | ?        | ?       |
| ROAS          | ?          | ?        | ?          | ?        | ?       |
| CPA / CPL     | ?          | ?        | ?          | ?        | ?       |
| CTR           | ?          | ?        | ?          | ?        | ?       |

So sánh với industry benchmarks từ attribution.md:
□ Google Search ROAS: Hiện tại vs 4–8x benchmark
□ Meta Ads ROAS: Hiện tại vs 2–5x benchmark
□ LinkedIn CPL: Hiện tại vs $50–200 benchmark

Đánh giá blended ROAS:
□ Blended ROAS = Tổng revenue attributed / Tổng spend (cross-platform)
□ Đây là con số stakeholders Finance cần thấy
□ Phân biệt: Platform-reported ROAS (thường cao hơn) vs Actual ROAS (sau dedup)
```

### Bước 4: Attribution Setup Assessment

```
READ: attribution.md → Section 1 (Attribution Models)
READ: attribution.md → Section 5 (Attribution Window Best Practices)

Đánh giá attribution setup hiện tại:

Attribution model:
□ Đang dùng model nào? (Last-Click / Linear / Data-Driven / other?)
□ Model có phù hợp với business model và sales cycle không?
□ Có consistency giữa các platforms không? (tất cả cùng 1 model?)

Attribution windows:
□ Meta Ads: Click window bao nhiêu? (7-day recommended post-iOS 14)
□ Google Ads: Click window bao nhiêu? (30-day default)
□ Có sync với nhau không? (inconsistency → inflated reported conversions)

Cross-platform issues:
□ Tổng conversions các platform báo cáo có lớn hơn actual conversions không?
  → Nếu có: Double-counting vấn đề — cần dedup
□ Có deduplication mechanism không? (unique conversion ID?)
□ Revenue attribution: Platform số vs CRM số khác nhau bao nhiêu %?
  → Gap >20% = vấn đề nghiêm trọng cần fix

Conversion window overlap:
□ Nếu Meta 7d click + Google 30d click → Cùng 1 purchase bị cả 2 platform claim
□ Estimate overlap: (Days overlap × avg daily conversions) × overspend impact
```

### Bước 5: Pixel / Tag Health Check

```
READ: platform-optimization.md → Section 5 (Landing Page QA Checklist — Tracking section)

Cho mỗi platform đang dùng, check:

Meta Pixel:
□ Pixel ID đúng không? (check Meta Events Manager)
□ Base pixel fire trên tất cả pages không?
□ Standard events (purchase, lead, add_to_cart) có fire đúng không?
□ Conversion value có được pass không?
□ Duplicate pixel firing? (count mỗi purchase 2+ lần?)
□ CAPI đã setup chưa? Event Match Quality (EMQ) score bao nhiêu? (target ≥ 6/10)

Google Ads:
□ Conversion tracking tag có fire không? (check via Tag Assistant)
□ Enhanced Conversions đã bật chưa?
□ Conversion value (revenue) có được pass không?
□ Cross-account conversion tracking hay per-account?
□ Duplicate conversion issue? (view-through + click-through cùng 1 user?)

GA4:
□ GA4 property đã migrate từ Universal Analytics chưa? (UA đã sunset 2023)
□ Key events (conversions) có được đánh dấu chưa?
□ Revenue events với value parameter?
□ User ID tracking (cross-device)?

TikTok Pixel:
□ Pixel đang fire không?
□ Standard Events có match với Meta/GA4 event names không?

Tag Manager:
□ GTM container có trên tất cả pages không?
□ GTM server-side container setup chưa? (cho CAPI)
□ Unused/outdated tags có được cleanup chưa? (performance impact)
□ Preview Mode test gần nhất khi nào?
```

### Bước 6: Audience Overlap Analysis

```
READ: platform-optimization.md → Section 2 (Meta Audience Layering)

Kiểm tra audience structure:
□ Có lookalike audiences không? Seed audience là gì? Size?
□ Custom audiences có được refresh không? (stale audiences mất effectiveness)
□ Có exclusion lists không? (tránh serve ads cho existing customers nếu acquisition campaign)
□ Ad Set audiences có overlap nhau không? → Internal cannibalization

Remarketing quality:
□ Website remarketing audience size: Đủ để chạy không? (Meta: tối thiểu 1000 users)
□ Cart abandonment audience: Đang retarget không? (high-value segment)
□ Customer list match rate: % emails matched với platform accounts? (target >30%)

Audience gaps:
□ Lookalike audiences từ top customers (LTV-based) — có chưa?
□ Video viewer retargeting — có chưa?
□ Cross-platform audience consistency: Cùng segment có trên tất cả platforms không?
```

### Bước 7: Account Structure Efficiency

```
READ: platform-optimization.md → Section 1 (Google Ads Structure)

Google Ads structure review:
□ Campaign count: Nhiều quá? Ít quá? (>100 campaigns với budget nhỏ = fragmentation)
□ Branded vs Non-branded separation: Có tách campaign không?
□ Search vs Display vs Shopping vs Performance Max: Có tách không?
□ Negative keyword lists: Có dùng shared negative lists không?
□ Keyword match types: Có quá nhiều Broad Match không? (spend waste risk)
□ Quality Scores: Average QS bao nhiêu? (<5 = cần cải thiện ad relevance)

Meta Ads structure review:
□ Campaign objectives đúng không? (dùng Conversions objective cho performance campaigns)
□ Advantage+ Campaigns (ASC) hay manual? (ASC tốt hơn khi ≥50 conv/tuần)
□ Ad Sets: Có audience overlap không? Số lượng ad sets per campaign hợp lý?
□ Ads per Ad Set: ≥3–5 ads để algorithm tối ưu?
□ Learning phase: Có campaign nào mắc kẹt trong learning phase không?
  → Learning phase = <50 conversions trong 7 ngày → tránh edit thường xuyên

Budget allocation vs results:
□ Có campaign nào dùng >30% budget nhưng <10% conversions? → Candidates to cut
□ Có campaign nào underbudgeted nhưng ROAS tốt? → Candidates to scale
□ Budget allocation có match với funnel stage recommendation không? (channels.md Section 4)
```

### Bước 8: Privacy & Compliance Assessment

```
READ: attribution.md → Section 6 (Privacy-First Measurement)

Privacy compliance:
□ Cookie consent banner có chạy không? Theo CMP nào?
□ GDPR: Người dùng EU có được opt-out tracking không?
□ PDPA (Vietnam, Thailand): Consent flow có compliant không?
□ iOS 14+: Đã setup CAPI / server-side tracking chưa? (nếu chưa → data loss nghiêm trọng)
□ Chrome third-party cookies: Đã có first-party data strategy chưa?

PII in tracking:
□ Có PII nào (email, phone) bị pass raw vào pixel events không? (violation)
□ Hashed user data (SHA-256): Đã implement chưa?
□ Server-side CAPI có hash đúng không?

Ad policy compliance:
□ Healthcare/Finance/Legal ads: Có đang follow platform-specific policies không?
□ Rejected ads: Có campaigns nào bị từ chối/limited do policy không?
□ Landing page compliance: Landing pages có vi phạm platform policies không?
```

### Bước 9: Output — Paid Media As-Is Analysis Report

```markdown
# Paid Media As-Is Analysis

## Executive Summary
[3–5 dòng: overall health, total monthly spend, blended ROAS, top 3 critical issues]

## Ad Accounts Inventory
| Platform | Account ID | Monthly Spend | Status | Admin Access |
|----------|-----------|---------------|--------|--------------|

## Spend Analysis (90 ngày gần nhất)
| Platform | Spend | Conversions | Revenue | ROAS | vs Benchmark | Assessment |
|----------|-------|-------------|---------|------|--------------|------------|

## Attribution Setup
| Aspect             | Current State          | Issue        | Recommendation      |
|--------------------|------------------------|--------------|---------------------|
| Attribution model  | ?                      | ?            | ?                   |
| Attribution window | ?                      | ?            | ?                   |
| Cross-platform dedup | Yes / No              | ?            | ?                   |
| CAPI setup         | Yes / No / Partial     | ?            | ?                   |

## Pixel / Tag Health
| Platform | Status | Issues Found | Severity |
|----------|--------|-------------|----------|

## Account Structure Issues
### Critical (block performance)
- [Issue]: [Impact] → [Fix]

### Important (limit efficiency)
- [Issue]: [Impact] → [Fix]

### Optimization Opportunities
- [Opportunity]: [Potential impact] → [Action]

## Audience Analysis
[Table: Audience | Platform | Size | Health | Usage]

## Privacy & Compliance
| Check                     | Status | Action Required |
|---------------------------|--------|-----------------|

## Priority Recommendations
1. [Highest impact, actionable immediately] — Effort: X, Impact: X
2. ...

## Estimated Impact of Fixes
[Table: Fix | Current cost | Estimated improvement | Priority]
```

---

## Checklist trước khi submit

```
□ Tất cả ad accounts đã được inventory (không bỏ sót platform nào)
□ ROAS/CPA baseline được so sánh với industry benchmarks
□ Attribution setup assessment đã include platform-reported vs actual gap
□ Pixel health check đã thực hiện (đặc biệt CAPI/iOS 14 impact)
□ Audience overlap analysis đã done
□ Account structure efficiency đã reviewed
□ Privacy compliance đã checked (đặc biệt CAPI nếu có iOS users)
□ Priority recommendations có clear action items và estimated impact
```
