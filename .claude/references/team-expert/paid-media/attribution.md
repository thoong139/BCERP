# Paid Media - Attribution Models & Measurement

> **Domain**: Paid Media / Attribution & Analytics
> **Last Updated**: 2026-03-15
> **Nguồn**: Google Analytics 4, Meta Attribution documentation, industry measurement frameworks

---

## 1. So Sánh Các Mô Hình Attribution

| Model | Mô Tả | Credit Distribution | Pros | Cons |
|-------|-------|---------------------|------|------|
| **First-Click** | 100% credit cho touchpoint đầu tiên | 100% → First touch | Đo lường awareness tốt | Bỏ qua mid/bottom funnel |
| **Last-Click** | 100% credit cho touchpoint cuối cùng | 100% → Last touch | Đơn giản, conversion-focused | Bỏ qua upper funnel; favors branded search |
| **Linear** | Chia đều credit cho tất cả touchpoints | Equal split | Cân bằng; dễ hiểu | Không phản ánh impact thực tế |
| **Time-Decay** | Touchpoint gần conversion nhận credit nhiều hơn | Exponential toward end | Phù hợp sales cycle dài | Undervalues awareness channels |
| **Position-Based (U-Shape)** | 40% first, 40% last, 20% chia đều middle | 40–20–40 | Cân bằng giữa acquisition và conversion | Cứng nhắc; không tự điều chỉnh |
| **Data-Driven (DDA)** | ML phân tích toàn bộ conversion path | Algorithmic | Chính xác nhất; cập nhật liên tục | Cần đủ data volume (≥300 conversions/30 ngày) |

---

## 2. Khi Nào Dùng Mô Hình Nào

```
┌─────────────────────────────────────────────────────┐
│            CHỌN ATTRIBUTION MODEL                   │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Có đủ data? (≥300 conv/tháng)                      │
│       │                                             │
│   YES ▼                         NO ▼               │
│  Data-Driven               Sales cycle dài? (>30d)  │
│  (GA4, Google Ads)               │                  │
│                            YES ▼    NO ▼            │
│                         Time-Decay  Linear           │
│                                     │               │
│                            Brand awareness goal?    │
│                                 │                   │
│                            YES → Position-Based     │
│                            NO  → Last-Click         │
└─────────────────────────────────────────────────────┘
```

### Hướng Dẫn Sử Dụng Theo Mục Tiêu

| Mục Tiêu | Model Phù Hợp | Lý Do |
|----------|---------------|-------|
| Đo lường awareness campaigns | First-Click | Ghi nhận vai trò kênh phát hiện đầu tiên |
| Tối ưu conversion rate | Last-Click | Xem kênh nào đang close deal |
| Multi-channel B2B (sales cycle dài) | Time-Decay | Ưu tiên touchpoints gần ngày quyết định |
| Brand + Performance mix | Position-Based | Ghi nhận cả acquisition lẫn conversion |
| Chiến lược media toàn diện | Data-Driven | Phân bổ chính xác nhất nếu đủ data |

---

## 3. Cross-Channel Attribution Workflow

```
User Journey:
 [Google Display Ad] → [Instagram Ad] → [Google Search Brand] → [Conversion]
         │                   │                    │
         ▼                   ▼                    ▼
   Impression            Click                 Click
   (View-through)       (UTM tracked)         (UTM tracked)

─────────────────────────────────────────────────────────────────
TRACKING LAYER:

Step 1: UTM Parameters
   utm_source=google
   utm_medium=cpc
   utm_campaign=brand-search
   utm_content=ad-variant-a
   utm_term=brand-keyword

Step 2: CRM/CDP Capture
   Landing page → Cookie set → GA4 session recorded
   Form submit → Lead ID created → Source attributed

Step 3: Revenue Matching
   Lead ID → CRM Opportunity → Closed Won → Revenue
   Match conversion data back to campaign spend

─────────────────────────────────────────────────────────────────
REPORTING LAYER:

Channel Report: Cost, Revenue, ROAS per campaign
Path Report: Most common conversion paths
Overlap Report: Assisted conversions per channel
```

### UTM Convention Chuẩn

| Parameter | Format | Ví Dụ |
|-----------|--------|-------|
| utm_source | Tên platform | `google`, `meta`, `linkedin` |
| utm_medium | Loại kênh | `cpc`, `display`, `social`, `email` |
| utm_campaign | Tên campaign | `brand-search-vn-q1-2026` |
| utm_content | Ad variant | `video-30s-promo`, `image-cta-blue` |
| utm_term | Keyword (Search) | `crm+software` |

---

## 4. Key Metrics Benchmarks theo Kênh

### ROAS Benchmarks

| Kênh | ROAS Target (E-commerce) | ROAS Target (Lead Gen) |
|------|--------------------------|------------------------|
| Google Search | 4–8x | N/A (dùng CPA) |
| Google Shopping | 5–10x | N/A |
| Meta Ads | 2–5x | N/A |
| LinkedIn Ads | 2–4x | $50–200 CPL |
| TikTok Ads | 2–4x | N/A |

### CPA / CPL Benchmarks theo Ngành

| Ngành | CPA (E-commerce) | CPL (Lead Gen) |
|-------|-----------------|----------------|
| Finance / Insurance | — | $80–200 |
| SaaS / Software | — | $50–150 |
| Healthcare | — | $30–100 |
| Education / E-learning | $30–80 | $20–60 |
| Retail / E-commerce | $10–40 | — |
| Real Estate | — | $50–200 |
| Travel | $40–120 | — |

### CTR & CVR Benchmarks

| Kênh | CTR Trung Bình | CVR Landing Page |
|------|---------------|-----------------|
| Google Search | 3–8% | 3–10% |
| Google Display | 0.1–0.3% | 1–3% |
| Meta Ads (Feed) | 0.5–1.5% | 1–5% |
| LinkedIn Ads | 0.4–0.8% | 2–7% |
| TikTok Ads | 0.3–1.0% | 1–3% |
| Email (nếu tracking) | 2–5% | 5–15% |

---

## 5. Attribution Window Best Practices

| Kênh | Click Window | View-Through Window | Lý Do |
|------|-------------|---------------------|-------|
| Google Ads | 30 ngày | 1 ngày | Default; phù hợp phần lớn B2C |
| Meta Ads | 7 ngày | 1 ngày | iOS 14+ ảnh hưởng; window ngắn hơn chính xác hơn |
| LinkedIn Ads | 30 ngày | 7 ngày | B2B sales cycle dài |
| TikTok Ads | 7 ngày | 1 ngày | Impulse purchase pattern |
| B2B SaaS (tự định nghĩa) | 90 ngày | 7 ngày | Sales cycle thường 30–90 ngày |

**Nguyên tắc:** Đồng bộ attribution window giữa các platform với CRM để tránh double-counting.

---

## 6. Privacy-First Measurement (iOS 14+ & Cookie Deprecation)

### Thách Thức Và Giải Pháp

| Thách Thức | Tác Động | Giải Pháp |
|------------|----------|-----------|
| iOS 14+ App Tracking Transparency | Mất 30–50% data từ iOS Meta | Conversions API (CAPI), AEM |
| Third-party cookie deprecation (Chrome 2025) | Mất remarketing audience rộng | First-party data, server-side tracking |
| Stricter privacy laws (GDPR, PDPA) | Không track không có consent | Consent Management Platform (CMP) |

### Ưu Tiên Triển Khai

```
[Priority 1] — Server-Side Tracking
   Conversions API (Meta CAPI)
   Google Enhanced Conversions
   → Gửi conversion data trực tiếp từ server, không phụ thuộc cookie

[Priority 2] — First-Party Data Strategy
   Email list, CRM data
   Customer match / Hashed audience upload
   → Remarketing không phụ thuộc third-party cookie

[Priority 3] — Modeling & MMM
   Meta's Advantage+ modeling
   Google's AI-powered attribution
   Marketing Mix Modeling (MMM) cho macro view
   → Bổ sung data bị thiếu bằng statistical modeling
```

### Checklist Đo Lường Privacy-First

- [ ] GA4 đã được cài đặt (thay thế Universal Analytics)
- [ ] Conversions API (CAPI) đã kết nối với Meta
- [ ] Google Enhanced Conversions đã bật
- [ ] Consent Management Platform (CMP) đang hoạt động
- [ ] UTM parameters nhất quán trên mọi kênh
- [ ] First-party data list được cập nhật hàng tuần
- [ ] Server-side GTM container đã triển khai
