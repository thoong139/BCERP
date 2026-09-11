# Playbook: Audit Existing E-commerce Systems

> **Type**: Agent Skill Playbook
> **Agent**: ecommerce-expert
> **Triggered by**: /wf-legacy-scan khi có e-commerce platform cũ
> **Output**: `.mc-data/docs/phase1-business/ecommerce-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống e-commerce
- Khi cần đánh giá nền tảng hiện tại trước khi thiết kế lại
- Khi cần tìm gaps, technical debt, migration risks

---

## Procedure

### Bước 1: Inventory thu thập thông tin

```
Thu thập từ stakeholders hoặc codebase:

Platform & Infrastructure:
□ Nền tảng đang dùng: WooCommerce / Shopify / Haravan / Magento / Custom?
□ Phiên bản (version): có out-of-date không?
□ Hosting: Shared hosting / VPS / Cloud (AWS, GCP, Azure)?
□ CDN: đang dùng gì?

Business metrics:
□ GMV/tháng hiện tại (Gross Merchandise Value)
□ Số đơn hàng/ngày trung bình
□ Số SKU đang active
□ Số seller (nếu marketplace)

Performance metrics (nếu có):
□ Conversion rate hiện tại
□ Cart abandonment rate
□ Payment success rate
□ Average page load time (GTmetrix, PageSpeed Insights)
□ Uptime % (có SLA không?)

Integrations:
□ Payment gateways: đang tích hợp gì?
□ Shipping carriers: GHN, GHTK, Viettel Post...?
□ ERP/Accounting: MISA, Fast, SAP...?
□ CRM: đang dùng gì?
□ Warehouse/WMS: có không?
□ Analytics: Google Analytics, Facebook Pixel...?
```

### Bước 2: Đánh giá nền tảng hiện tại

```
READ: platform-comparison.md → đọc toàn bộ để đánh giá

Với mỗi platform phát hiện, đánh giá:
□ License/version còn được support không?
□ Performance: benchmark so với platform-comparison.md
□ Security: có CVE đã công bố nào chưa vá không?
□ Scalability: platform có thể scale đến GMV kỳ vọng không?
□ Customization: custom code có nhiều không? Có technical debt không?
□ Total Cost of Ownership (TCO): hosting + license + maintenance

Common platform issues:
WooCommerce:
  → Plugin conflicts (quá nhiều plugins)
  → WordPress security vulnerabilities
  → Không scale tốt khi >100K SKUs

Shopify:
  → Transaction fees nếu không dùng Shopify Payments
  → Limited customization ở plan thấp
  → Vietnam payment gateways support hạn chế

Magento 1.x:
  → End-of-life từ 2020 → CRITICAL RISK
  → Không có security patches mới
  → Migration urgent

Custom platforms:
  → Thường thiếu documentation
  → Tight coupling, hard to maintain
  → Developer dependency risk
```

### Bước 3: Audit Product Catalog Quality

```
Đánh giá chất lượng dữ liệu catalog:

□ Tổng số products: active / inactive / draft
□ Completeness rate: % products có đầy đủ (name, description, image, price)
□ Image quality: có đủ images không? Resolution đạt chuẩn?
□ Category structure: có taxonomy rõ ràng không? Có orphan products không?
□ Variant coverage: % products có variant setup đúng
□ Duplicate products: có SKU trùng không?
□ SEO metadata: % products có seo_title, seo_description

Catalog health score:
  > 80% completeness → Good
  50-80% → Needs improvement
  < 50% → Critical (ảnh hưởng search ranking và conversion)

Data issues cần document:
□ Missing required fields (per loại sản phẩm)
□ Inconsistent attribute values (size "S", "small", "Small" — cùng 1 value)
□ Wrong categories (sản phẩm trong sai ngành hàng)
□ Inactive products chiếm bao nhiêu % → cleanup needed?
```

### Bước 4: Đánh giá Payment Success Rate

```
Các chỉ số cần kiểm tra:

Payment success rate per method:
□ VNPay: target >95%
□ MoMo: target >95%
□ Credit/debit card: target >92% (3DS friction)
□ COD: target 100% (không fail, nhưng có completion rate issue)

Common payment issues:
□ Timeout rate cao → server quá slow, gateway response time?
□ 3D Secure failure rate cao → UX vấn đề?
□ Duplicate charges → thiếu idempotency?
□ Refund processing: có tự động không hay manual?
□ Webhook reliability: có missed webhooks không?

Reconciliation:
□ Số tiền settlement từ gateway có khớp với order totals không?
□ Có gaps (missing payments) nào không?
□ Chargeback rate: >1% là red flag
```

### Bước 5: Đánh giá Cart Abandonment Rate

```
READ: customer-journey.md → Checkout Funnel

Benchmark:
  Cart abandonment < 70%: Good
  70-80%: Average
  > 80%: Poor — cần investigate

Funnel analysis:
  Cart view (100%) → Login step → Shipping → Payment → Confirmation
  Identify drop-off points: bước nào có drop lớn nhất?

Common causes:
□ Forced registration → remove hoặc add guest checkout
□ Surprise shipping fees → show estimated shipping earlier
□ Too many checkout steps → simplify
□ Payment method không phù hợp → add local methods
□ Mobile UX poor → optimize
□ Page speed slow → optimize

Cart abandonment recovery:
□ Có abandonment email sequence không?
□ Timing: 1h, 24h, 72h sau abandonment
□ Recovery rate: mục tiêu 5-15% của abandoned carts
```

### Bước 6: Đánh giá Integration Health

```
Inventory integration:
□ Inventory sync real-time hay batch?
□ Overselling issues: có không? Tần suất?
□ Multi-channel sync: Shopee/Lazada/Tiki nếu có → tốc độ sync?
□ Return: inventory auto-restock khi return không?

Logistics integration:
□ Shipping label auto-print hay manual?
□ Tracking number sync về website?
□ Failed delivery handling: có workflow không?
□ SLA tracking: % đơn giao đúng hạn?

ERP/Accounting integration:
□ Dữ liệu bán hàng sync sang kế toán tự động?
□ VAT/e-invoice được gen tự động?
□ Frequency: real-time / daily batch?

Analytics:
□ Google Analytics 4 đã setup chưa (GA3 đã sunset tháng 7/2023)?
□ Enhanced e-commerce events: purchase, add_to_cart, checkout...?
□ Facebook Pixel / TikTok Pixel?
□ Conversion tracking có accurate không?
```

### Bước 7: Đánh giá Migration Complexity

```
Đưa ra đánh giá complexity tổng thể:

Low complexity (3-6 tháng migration):
  → Platform phổ biến (Shopify → Shopify Plus)
  → Catalog < 10K SKUs, clean data
  → < 5 integrations
  → Ít custom code

Medium complexity (6-12 tháng):
  → Cross-platform migration (WooCommerce → custom)
  → Catalog 10K-100K SKUs, data cleanup needed
  → 5-15 integrations
  → Significant custom functionality

High complexity (12-18+ tháng):
  → Legacy system (Magento 1.x, custom)
  → Catalog > 100K SKUs hoặc complex data model
  → > 15 integrations
  → Business-critical custom processes

Migration risks:
□ Data loss: product data, customer data, order history
□ SEO drop: URL changes, meta data migration
□ Downtime: switch-over window
□ Integration breaks: API compatibility
□ Payment continuity: subscription billing

Recommendation:
□ Đề xuất nên migrate hay refactor?
□ Big-bang hay phased migration?
□ Parallel run duration (cả 2 hệ thống cùng chạy)
□ Rollback plan
```

### Bước 8: Output — As-Is Analysis Report

```markdown
# E-commerce As-Is Analysis

## Executive Summary
[3-5 dòng: overall health, critical risks, top recommendations]

## Current Platform Overview
| Item | Detail |
|------|--------|
| Platform | [name + version] |
| Hosting | [...] |
| Monthly GMV | [...] |
| Orders/day | [...] |
| Active SKUs | [...] |
| Sellers | [...] (nếu marketplace) |

## Platform Assessment
| Dimension | Status | Score (1-5) | Notes |
|-----------|--------|-------------|-------|
| Security | OK/RISK/CRITICAL | ... | ... |
| Performance | ... | ... | ... |
| Scalability | ... | ... | ... |
| Maintainability | ... | ... | ... |
| Integration health | ... | ... | ... |

## Business Metrics vs Benchmarks
| Metric | Current | Benchmark | Gap | Priority |
|--------|---------|-----------|-----|----------|
| Conversion rate | ...% | 2-3% | ... | ... |
| Cart abandonment | ...% | <70% | ... | ... |
| Payment success | ...% | >95% | ... | ... |
| Page load (LCP) | ...s | <2.5s | ... | ... |

## Catalog Quality Report
[Completeness score, issues found, cleanup needed]

## Integration Health
[Table: Integration | Status | Issues | Risk]

## Critical Issues (block migration/growth)
- [Issue 1]: [Impact] → [Recommendation]
- [Issue 2]: ...

## Migration Complexity Assessment
Complexity: Low / Medium / High
Estimated timeline: [...] months
Key risks: [...]

## Priority Recommendations
1. [Highest impact action] — Effort: [...], Impact: [...]
2. ...

## Next Steps
[Quick wins (< 1 tháng) / Medium term / Migration roadmap]
```

---

## Checklist trước khi submit

```
□ Platform version đã check — có EOL risk không?
□ GMV và order volume đã document
□ Catalog completeness đã đánh giá
□ Payment success rate đã phân tích per method
□ Cart abandonment funnel đã analyzed
□ Tất cả integrations đã inventory
□ Migration complexity đã assess với lý do cụ thể
□ Critical issues được phân biệt rõ với nice-to-have
□ Recommendations có effort/impact estimate
```
