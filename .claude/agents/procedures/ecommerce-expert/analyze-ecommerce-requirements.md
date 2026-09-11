# Playbook: Phân tích E-commerce Requirements

> **Type**: Agent Skill Playbook
> **Agent**: ecommerce-expert
> **Triggered by**: /wf-analyze-requirements khi có ecommerce/marketplace modules
> **Output**: `.mc-data/docs/phase1-business/ecommerce-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: ecommerce, marketplace, cart, checkout,
  product catalog, storefront, TMĐT, thương mại điện tử, giỏ hàng, sàn giao dịch
- Khi cần xác định e-commerce requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại hình kinh doanh (B2C Storefront / B2B Wholesale / Marketplace / D2C Brand)
□ Quy mô kỳ vọng (GMV/tháng, số SKU, số đơn/ngày)
□ Đã có platform chưa? Nếu có → đang dùng gì (Shopify, WooCommerce, Haravan...)?
□ Thị trường chính: Vietnam only / ASEAN / Global
□ Mobile app hay web-only?
```

### Bước 2: Xác định mô hình thương mại

```
READ: personas.md → xác định personas phù hợp với model

B2C Storefront (1 seller):
  → Personas: Shopper, Ops Manager, Content Manager, CS Agent
  → Core modules: Catalog, Cart, Checkout, Order, Customer Account

B2B Wholesale:
  → Personas: Buyer (business), Account Manager, Sales Rep
  → Core modules: Catalog (B2B pricing), Quote, Bulk Order, Contract

Marketplace (multi-seller):
  → Personas: Buyer, Seller/Merchant, Marketplace Admin, Ops Manager
  → Core modules: Seller Onboarding, Catalog (per seller), Commission, Payout

D2C Brand (direct to consumer):
  → Personas: Shopper, Brand Manager, CS Agent
  → Core modules: Catalog, Subscription, Loyalty, Community
```

### Bước 3: Map personas chi tiết

```
READ: personas.md → đọc đầy đủ pain points và must-have per persona

Với mỗi persona dự án cần phục vụ:
□ Shopper (Online Buyer) → pain points: slow load, complicated checkout, hidden fees
□ Seller / Merchant (Marketplace) → pain points: complex onboarding, listing mgmt, fee clarity
□ Marketplace Admin → quản lý toàn sàn, approve sellers, monitor disputes
□ Vendor / Supplier (B2B) → bulk ordering, contract pricing, invoice management
□ Ops Manager → inventory, fulfillment, shipping, returns
□ Content Manager → PIM, product data, SEO metadata
□ CS Agent → order lookup, return processing, dispute resolution

Ghi chú: mỗi pain point → map thành requirement
```

### Bước 4: Xác định luồng giao dịch chính

```
READ: customer-journey.md → đọc Stage 3 (Purchase) kỹ nhất

Mapping transaction flows theo model:

B2C flow:
  Browse → PDP → Add to Cart → Checkout → Payment → Confirmation → Fulfillment

Marketplace flow:
  Browse marketplace → PDP (per seller) → Cart (multi-seller) →
  Checkout (split payment per seller) → Order per seller → Fulfillment per seller

B2B flow:
  Browse catalog (B2B price) → RFQ / Bulk order → Quote approval →
  PO upload → Invoice → Payment (NET terms) → Delivery

Xác định:
□ Guest checkout có support không?
□ Cart có persist across sessions không?
□ Multi-seller cart hay single-seller?
□ Split fulfillment có cần không?
```

### Bước 5: Xác định payment methods

```
Theo thị trường Vietnam:

Local payment (bắt buộc nếu Vietnam):
□ VNPay (QR, banking) — phổ biến nhất, hỗ trợ 40+ ngân hàng
□ MoMo (e-wallet) — >30M users VN
□ ZaloPay (e-wallet) — tích hợp Zalo ecosystem
□ Moca (e-wallet, tích hợp Grab)
□ Banking transfer (ATM, internet banking)
□ COD (Cash on Delivery) — vẫn >40% tại VN

International (nếu cần):
□ Stripe (Visa/Mastercard/AMEX)
□ PayPal
□ BNPL (Mua trả góp): Home Credit, FE Credit, Kredivo

PCI-DSS compliance:
□ Không lưu raw card data trên server
□ Tokenization qua payment gateway
□ HTTPS + TLS 1.2+ bắt buộc
□ 3D Secure cho card payments
```

### Bước 6: Xác định yêu cầu pháp lý

```
Vietnam regulatory requirements:

VAT & Thuế:
□ VAT 8% hoặc 10% tùy loại hàng (Luật VAT 2024)
□ Cần phân loại hàng hóa theo tax category
□ Hiển thị giá đã bao gồm VAT theo quy định

E-invoice (Hóa đơn điện tử):
□ Nghị định 123/2020/NĐ-CP: bắt buộc từ 01/07/2022
□ Tích hợp nhà cung cấp: VNPT eHóa đơn, Viettel-S, MISa, Fast
□ Gửi hóa đơn qua email sau mỗi giao dịch thành công
□ Báo cáo về cơ quan thuế theo kỳ

Data protection:
□ Luật An ninh mạng 2018: lưu trữ data người dùng VN tại VN
□ Thông báo thu thập dữ liệu, có consent
□ PDPA compliance nếu phục vụ thị trường ASEAN khác

GDPR (nếu EU market):
□ Cookie consent
□ Right to erasure
□ Data portability
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-ECOM-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần — impact gì]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format:**
```
REQ-ECOM-CAT-001   → Product Catalog / PIM
REQ-ECOM-CART-001  → Shopping Cart
REQ-ECOM-CHK-001   → Checkout flow
REQ-ECOM-ORD-001   → Order Management
REQ-ECOM-PAY-001   → Payment integration
REQ-ECOM-INV-001   → Inventory management
REQ-ECOM-SHI-001   → Shipping & fulfillment
REQ-ECOM-MKT-001   → Seller / Marketplace management
REQ-ECOM-LOY-001   → Loyalty & promotion
REQ-ECOM-TAX-001   → Tax & invoice (VAT, e-invoice)
REQ-ECOM-CUS-001   → Customer account & profile
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/ecommerce-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope e-commerce)
2. Business Model (B2C / B2B / Marketplace / D2C) + Rationale
3. Personas affected (summary table)
4. Transaction Flows (per model, dạng flowchart text)
5. Payment Methods được support
6. Regulatory requirements (VAT, e-invoice, data protection)
7. Requirements (theo module, có REQ-ID)
8. Integration requirements với các department khác
9. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Xác định rõ business model (B2C / B2B / Marketplace / D2C)
□ Personas đã map đầy đủ với pain points
□ Transaction flows đã được document
□ Payment methods phù hợp với thị trường (VNPay/MoMo/ZaloPay nếu VN)
□ VAT và e-invoice requirements đã covered
□ Mỗi REQ có REQ-ID đúng format REQ-ECOM-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng
□ PCI-DSS requirements đã mentioned trong payment REQs
□ Integration với logistics, finance, CRM đã noted
□ Open questions được list ra để stakeholders review
```
