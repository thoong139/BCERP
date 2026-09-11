# Playbook: Thiết kế Product Catalog Module

> **Type**: Agent Skill Playbook
> **Agent**: ecommerce-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần design product catalog
> **Output**: Feature spec cho Product Catalog module

---

## Khi nào dùng playbook này

- Khi cần spec module "Product Catalog" / "Quản lý Sản phẩm" / "PIM"
- Khi thiết kế data model cho products, variants, categories
- Phase 2 (Feature spec) hoặc Phase 3 (Technical design) của workflow

---

## Procedure

### Bước 1: Xác định scope catalog

```
Hỏi hoặc suy luận từ context:
□ Số lượng SKU kỳ vọng: < 1K / 1K-100K / 100K+
□ Có product variants không? (size, color, material...)
□ Có multi-seller catalog không? (marketplace)
□ Cần PIM integration không? (Akeneo, inRiver...)
□ Digital products hay physical? Hay cả hai?
□ Cần multi-language, multi-currency không?
□ B2B pricing tier có không? (giá sỉ, giá lẻ, giá theo khách hàng)
```

### Bước 2: Thiết kế taxonomy danh mục

```
READ: customer-journey.md → Stage 2 (Consideration) để hiểu browse experience

Taxonomy structure (3-4 cấp):
Level 1: Ngành hàng (Thời trang, Điện tử, Gia dụng...)
  Level 2: Danh mục (Áo, Quần, Giày...)
    Level 3: Danh mục con (Áo phông, Áo sơ mi...)
      Level 4: Nhóm sản phẩm (tùy optional)

Rules thiết kế taxonomy:
□ Mỗi sản phẩm thuộc 1 danh mục chính (primary category)
□ Có thể có nhiều danh mục phụ (cross-category placement)
□ Slug URL thân thiện SEO: /thoi-trang/ao/ao-phong
□ Breadcrumb navigation tự động theo taxonomy
□ Category có thể có banner image, description, SEO meta
```

**Data model Category:**
```
Category:
  - id, name, slug (URL-friendly)
  - parent_id (nullable — Level 1 có parent_id = null)
  - level (1-4)
  - description, short_description
  - image_url, banner_url
  - seo_title, seo_description, seo_keywords
  - sort_order, is_active
  - attribute_set_id (FK → AttributeSet)
  - created_at, updated_at
```

### Bước 3: Thiết kế Attribute System

```
Mục đích: Mỗi ngành hàng có attributes khác nhau
(Thời trang: Size, Màu sắc | Điện tử: RAM, Storage | Giày: Size số)

AttributeSet (nhóm attributes):
  - id, name, category_id
  - Ví dụ: "Fashion", "Electronics", "Footwear"

Attribute:
  - id, code (SKU-friendly), name, type
  - type: text / number / select / multi-select / boolean / date
  - is_required, is_filterable, is_searchable, is_variant
  - sort_order

AttributeOption (cho type = select/multi-select):
  - id, attribute_id, value, label, sort_order

ProductAttribute (pivot):
  - product_id, attribute_id, value (text) hoặc option_id

Variant attributes (is_variant = true):
  → Tạo SKU combinations: Color × Size → ProductVariant
```

### Bước 4: Thiết kế SKU & Variant Management

```
Product (cha):
  - id, name, slug
  - short_description, full_description (rich text)
  - brand_id, category_id
  - status: draft / active / inactive / discontinued
  - product_type: simple / variable / bundle / digital
  - base_price (chỉ dùng nếu simple product)
  - seller_id (nullable — null = platform product, not null = marketplace seller)
  - created_at, updated_at, published_at

ProductVariant (con — chỉ có khi product_type = variable):
  - id, product_id
  - sku (UNIQUE, bắt buộc) — format: PROD-COLOR-SIZE (ví dụ: TS001-RED-M)
  - attribute_combination (JSON: {color: "red", size: "M"})
  - price, sale_price, cost_price
  - weight, dimensions (JSON)
  - barcode (EAN/UPC)
  - is_active, sort_order

SKU generation rules:
□ SKU auto-generate hoặc manual input
□ SKU phải UNIQUE toàn hệ thống
□ SKU không được thay đổi sau khi có đơn hàng
□ Khi inactive variant → không xóa SKU (historical orders)
```

### Bước 5: Thiết kế Pricing Rules

```
Pricing layers (thứ tự ưu tiên từ cao đến thấp):
1. Flash sale price (time-boxed, limited quantity)
2. Customer-specific price (B2B contract)
3. Tier pricing (volume discount: mua 10+ giảm 5%)
4. Sale price (on-sale, no time limit)
5. Base price (default)

PriceRule:
  - id, name, type: flash_sale / tier / customer_group / coupon
  - product_id hoặc category_id (scope)
  - customer_group_id (nullable — null = all)
  - discount_type: percentage / fixed_amount
  - discount_value
  - min_quantity (tier pricing)
  - start_at, end_at (nullable — null = permanent)
  - is_active, priority

Flash sale requirements:
□ Số lượng giới hạn (quantity cap) per flash sale
□ Countdown timer hiển thị
□ Inventory reservation: trừ stock ngay khi add to cart
□ Auto-revert khi hết thời gian
```

### Bước 6: Thiết kế Inventory Linkage

```
Inventory liên kết tại cấp ProductVariant (không phải Product):

Inventory:
  - variant_id (FK, UNIQUE per warehouse)
  - warehouse_id
  - quantity_on_hand
  - quantity_reserved (trong cart/pending orders)
  - quantity_available = on_hand - reserved
  - low_stock_threshold
  - backorder_allowed (boolean)

Stock movement log (audit trail):
  - id, variant_id, warehouse_id
  - movement_type: sale / return / adjustment / transfer / receipt
  - quantity_change (positive = in, negative = out)
  - reference_id (order_id / adjustment_id)
  - created_at, created_by

Business rules:
□ quantity_available không được âm (trừ khi backorder_allowed)
□ Khi add to cart → reserve ngay
□ Khi order cancelled/expired → release reservation
□ Low stock alert khi quantity_available <= low_stock_threshold
```

### Bước 7: Thiết kế Media Management

```
ProductMedia:
  - id, product_id, variant_id (nullable — null = chung cho product)
  - type: image / video / document (spec sheet)
  - url (CDN URL)
  - alt_text (SEO + accessibility)
  - sort_order, is_primary

Image processing pipeline:
□ Upload → Resize tự động (thumbnail 200px, medium 600px, large 1200px)
□ Format convert sang WebP (performance)
□ CDN serving (CloudFront, Cloudflare)
□ Lazy loading trên storefront
□ Zoom capability trên PDP
□ Max file size: 10MB / image, 100MB / video

Marketplace multi-seller:
□ Platform có thể override seller images (moderation)
□ Image moderation queue (tránh nội dung vi phạm)
```

### Bước 8: Thiết kế SEO Metadata

```
ProductSEO (1-1 với Product):
  - product_id
  - seo_title (max 60 chars)
  - seo_description (max 160 chars)
  - og_title, og_description, og_image (Open Graph)
  - canonical_url
  - structured_data (JSON-LD Schema.org Product)
  - is_indexable (boolean — noindex cho drafts/discontinued)

Auto-generate nếu trống:
  seo_title = product.name + " | " + brand.name + " | " + site.name
  seo_description = product.short_description (truncate 160)

Schema.org Product markup (bắt buộc cho Google Shopping):
  @type: Product
  name, description, image, brand
  offers: { price, priceCurrency, availability }
  aggregateRating: { ratingValue, reviewCount }
```

### Bước 9: Thiết kế Multi-seller Catalog (Marketplace)

```
Chỉ áp dụng khi business model = Marketplace

Seller Catalog Rule:
□ Mỗi seller quản lý catalog riêng (seller_id trên Product)
□ Platform có thể tạo "master catalog" (canonical products)
□ Seller listing = link tới master catalog + seller price/stock
□ Hoặc seller tự tạo listing (flexible marketplace)

Catalog moderation:
□ New product listing → status = pending_review
□ Marketplace admin review → approve / reject (kèm lý do)
□ Auto-approve sau N ngày nếu không có action (configurable)
□ Violation report → disable listing + notify seller

Commission per category:
□ Commission rate định nghĩa tại category level
□ Override tại product level (deal riêng với seller)
```

### Bước 10: Thiết kế Search & Filter

```
Search requirements:
□ Full-text search trên: name, description, brand, category, SKU
□ Typo tolerance (fuzzy search)
□ Synonym support (áo phông = áo thun)
□ Search suggestions / autocomplete
□ Kết quả có highlight matching keywords
□ Search analytics (top queries, zero results)

Filter requirements:
□ Faceted filtering: Category, Brand, Price range, Attributes (size, color...)
□ Filter counts (số sản phẩm per filter option)
□ URL-persisted filters (?color=red&size=M) → shareable, SEO-friendly
□ Multiple values: color=red,blue (OR) / price=100-500 (RANGE)
□ Sort: Relevance / Price asc/desc / Newest / Best seller / Rating

Tech recommendation:
□ Elasticsearch hoặc Meilisearch cho full-text search
□ Database for filtering nếu catalog < 100K SKUs (với indexes tốt)
□ Algolia nếu cần managed service (cost cao hơn)
```

### Bước 11: Feature Spec Output

```markdown
# Feature Spec: Product Catalog

## REQ-ID Coverage
REQ-ECOM-CAT-001: Category taxonomy management (CRUD, hierarchy, slug)
REQ-ECOM-CAT-002: Attribute system (AttributeSet, Attribute, Options)
REQ-ECOM-CAT-003: Product CRUD (simple + variable, draft/publish lifecycle)
REQ-ECOM-CAT-004: SKU & Variant management (combinations, unique SKU)
REQ-ECOM-CAT-005: Pricing rules (base, sale, tier, flash sale)
REQ-ECOM-CAT-006: Inventory linkage (per variant, per warehouse)
REQ-ECOM-CAT-007: Media management (upload, resize, CDN)
REQ-ECOM-CAT-008: SEO metadata (title, desc, schema.org)
REQ-ECOM-CAT-009: Search & faceted filter
REQ-ECOM-CAT-010: Multi-seller catalog & moderation (nếu Marketplace)

## Data Model
[ERD theo fields đã thiết kế ở các bước trên]

## Non-functional Requirements
- PDP load < 1.5s (LCP)
- Search response < 300ms
- Bulk import: 10,000 SKUs / batch
- Image CDN cache-hit > 90%

## Phụ thuộc
- REQ-ECOM-INV-001: Inventory Management
- REQ-ECOM-PAY-001: Pricing (flash sale cần payment gateway aware)
- REQ-ECOM-MKT-001: Seller onboarding (nếu Marketplace)
```

---

## Checklist trước khi submit

```
□ Taxonomy cấp đủ sâu cho ngành hàng của dự án
□ Attribute system đủ flexible để extend mà không cần schema migration
□ SKU uniqueness constraint được nhấn mạnh
□ Pricing layers đã xác định thứ tự ưu tiên
□ Inventory liên kết tại variant level (không phải product level)
□ Flash sale có time-box và quantity cap
□ Media có pipeline resize + CDN
□ SEO metadata bao gồm schema.org markup
□ Search có typo tolerance và faceted filter
□ Marketplace moderation flow đã được design (nếu áp dụng)
□ Mỗi REQ có REQ-ID format REQ-ECOM-CAT-[NNN]
```
