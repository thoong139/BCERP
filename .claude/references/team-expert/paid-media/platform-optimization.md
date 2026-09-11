# Paid Media - Platform-Specific Optimization

> **Domain**: Paid Media / Campaign Optimization
> **Last Updated**: 2026-03-15
> **Nguồn**: Google Ads Help Center, Meta Business Help, LinkedIn Marketing Solutions, TikTok For Business documentation

---

## 1. Google Ads Optimization Checklist

### Campaign Structure (SKAG / STAG)

```
Account
  └── Campaign (1 objective, 1 budget)
        └── Ad Group (1 theme / product category)
              └── Keywords (tight match type grouping)
              └── Ads (3–5 RSA variants per ad group)
```

| Level | Best Practice |
|-------|--------------|
| Campaign | 1 goal per campaign (Leads, Sales, Awareness). Tách branded vs non-branded. |
| Ad Group | Nhóm keywords cùng intent. Tối đa 10–20 keywords/ad group. |
| Keywords | Ưu tiên Exact Match và Phrase Match; hạn chế Broad Match khi ngân sách eo hẹp. |
| Ads | Tối thiểu 3 RSA per ad group; Ad Strength ≥ "Good". |

### Bidding Strategy Guide

| Mục Tiêu | Bidding Strategy | Điều Kiện |
|----------|-----------------|-----------|
| Maximize conversions (budget-limited) | Maximize Conversions | Mới bắt đầu; <50 conv/tháng |
| CPA mục tiêu | Target CPA | ≥50 conversions/30 ngày |
| ROAS mục tiêu (e-commerce) | Target ROAS | ≥30 conv/30 ngày với giá trị đa dạng |
| Tối đa traffic | Maximize Clicks | Awareness; không cần conversion data |
| Vị trí quảng cáo cụ thể | Target Impression Share | Brand defense |

### Quality Score Improvement

| Thành Phần | Weight | Cách Cải Thiện |
|------------|--------|----------------|
| Expected CTR | ~35% | Ad copy mạnh, keyword relevance |
| Ad Relevance | ~35% | Match keyword với headline ad |
| Landing Page Experience | ~30% | Load speed, content relevance, mobile |

### Negative Keyword Management

- Thêm negatives ngay khi launch (brand terms, competitor names, irrelevant verticals)
- Review Search Terms Report hàng tuần; add new negatives
- Tạo Negative Keyword List dùng chung cho toàn account
- Negative match types: Exact cho terms cần chặt chẽ, Phrase cho categories rộng

---

## 2. Meta Ads Optimization

### Audience Layering Framework

```
COLD AUDIENCE (Prospecting):
  ├── Lookalike 1–3% (từ customer list hoặc website buyers)
  ├── Interest Targeting (broad, relevant interests)
  └── Advantage+ Audience (để Meta tự tìm)

WARM AUDIENCE (Remarketing):
  ├── Website Visitors (All visitors — 30 ngày)
  ├── Engaged Users (Video views 25–50%, Page/Profile engagement)
  └── Add-to-Cart but not Purchase (7–14 ngày)

HOT AUDIENCE (Conversion):
  └── Abandoned Cart (3–7 ngày) — highest urgency creative
```

### Creative Testing Framework

| Biến Thể | Cách Test | Thời Gian |
|----------|-----------|-----------|
| Hook (3 giây đầu) | Test 2–3 hooks khác nhau | 7–14 ngày |
| Visual format | Image vs Video vs Carousel | 14 ngày |
| CTA | "Shop Now" vs "Learn More" vs "Get Offer" | 7 ngày |
| Headline copy | Benefit-led vs Feature-led vs Social proof | 7–14 ngày |

**Nguyên tắc:** Test 1 biến tại một thời điểm. Budget tối thiểu $20/ngày/ad set để có đủ data.

### Advantage+ Campaigns (ASC)

- Dùng khi đã có conversion data tốt (≥50 conv/tuần)
- Kết hợp tối đa 150 creative assets (image + video)
- Không cần target audience thủ công — Meta tự optimize
- Giữ lại 1–2 manual campaigns để kiểm soát và so sánh

---

## 3. LinkedIn Ads B2B Playbook

### Audience Targeting Priorities

| Tier | Targeting Method | Khi Nào Dùng |
|------|-----------------|--------------|
| 1 | Matched Audiences (retargeting, list upload) | Luôn ưu tiên — chính xác nhất |
| 2 | Company Targeting + Job Function | ABM; biết rõ ICP |
| 3 | Job Title + Seniority | Lead gen cụ thể per persona |
| 4 | Skills + Groups | Phủ rộng hơn khi audience quá hẹp |

**Audience size:** Tối thiểu 50,000 người cho Traffic/Awareness; 300+ contacts cho Matched Audiences.

### Message Ads (InMail) Best Practices

- Tiêu đề ngắn gọn (≤60 ký tự): nêu rõ lợi ích
- Body: 3–4 câu; không quá 500 ký tự
- CTA: 1 hành động rõ ràng (đăng ký demo, tải tài liệu)
- Gửi vào thứ Ba–Thứ Năm sáng (giờ local của recipient)
- Tần suất: 1 lần/30 ngày cho cùng recipient

### Lead Gen Forms Best Practices

- Giữ ≤4 fields (name, email, company, job title)
- Pre-fill LinkedIn profile data → giảm friction
- Offer rõ ràng trong headline (case study, demo, trial)
- Follow up trong vòng 24 giờ sau khi nhận lead

---

## 4. TikTok Ads Creative Guidelines

### Nguyên Tắc Native Content

```
"Don't make ads. Make TikToks."

DO:
  ✓ Vertical video 9:16, full screen
  ✓ Hook mạnh trong 0–3 giây đầu
  ✓ Âm thanh/nhạc TikTok trending
  ✓ Text overlay rõ ràng (nhiều người xem không có âm thanh)
  ✓ Cuối video có CTA rõ ràng
  ✓ Authentic, "lo-fi" style thường beat polished ads

DON'T:
  ✗ Sử dụng footage đã edit sẵn từ TV/YouTube
  ✗ Logo lớn xuất hiện sớm (người dùng sẽ skip)
  ✗ Video dài hơn 15–30 giây cho top-of-funnel
```

### Spark Ads (Boost Organic)

- Dùng để boost UGC (User Generated Content) và creator content
- Yêu cầu creator cấp quyền sử dụng nội dung (Authorization Code)
- Organic content + paid reach = social proof + scale
- Thường có CPM thấp hơn 30–50% so với paid-only creative

### Video Length Guide

| Mục Tiêu | Video Length | Lý Do |
|----------|-------------|-------|
| Brand Awareness | 6–15 giây | Retain attention |
| Product Demo | 15–30 giây | Đủ thời gian explain |
| Tutorial / Story | 30–60 giây | Deep engagement |
| Full Content | 1–3 phút | Educational content |

---

## 5. Landing Page QA Checklist

### Performance

- [ ] Page load time < 3 giây (test bằng Google PageSpeed Insights)
- [ ] Mobile-first design; responsive trên mọi screen size
- [ ] LCP (Largest Contentful Paint) < 2.5 giây
- [ ] CLS (Cumulative Layout Shift) < 0.1

### Conversion Elements

- [ ] Headline khớp với ad copy (message match)
- [ ] CTA nằm above the fold
- [ ] Form không quá 3–5 fields (cho lead gen)
- [ ] Trust signals: logo khách hàng, testimonials, badges
- [ ] Số điện thoại/live chat visible

### Tracking

- [ ] Google Analytics GA4 event tracking đang ghi đúng
- [ ] Meta Pixel (Base + Events) đang fire
- [ ] LinkedIn Insight Tag đang active
- [ ] Conversion events test qua Tag Manager Preview
- [ ] Thank you page URL khác với landing page URL

---

## 6. A/B Testing Framework

### Điều Kiện Thống Kê

| Thông Số | Giá Trị Khuyến Nghị | Ý Nghĩa |
|----------|---------------------|---------|
| Statistical Significance | ≥95% | Kết quả không phải do ngẫu nhiên |
| Minimum Sample Size | ≥100 conversions/variant | Đủ data để kết luận |
| Test Duration | 2–4 tuần | Tránh day-of-week bias |
| Max Variants per Test | 2 (A vs B) | Tránh traffic split quá mỏng |

### Test Priority Matrix

```
HIGH IMPACT + EASY TO TEST → Do First
  → Ad Headlines, Hook video (3 giây đầu), CTA button text

HIGH IMPACT + COMPLEX → Schedule
  → Landing page redesign, Audience targeting, Bidding strategy

LOW IMPACT + EASY → Do When Have Time
  → Ad description text, Image color variant

LOW IMPACT + COMPLEX → Skip
  → Minor layout tweaks on low-traffic pages
```

### Test Velocity Guide

| Budget/Tháng | Test Frequency | Focus Area |
|--------------|---------------|------------|
| < $5,000 | 1 test/tháng | Creative (highest impact) |
| $5,000–$20,000 | 2–3 tests/tháng | Creative + Audience |
| $20,000–$100,000 | 4–6 tests/tháng | Creative, Audience, Bidding, Landing Page |
| > $100,000 | Continuous | Tất cả elements, automated testing |
