# Playbook: Review E-commerce Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: ecommerce-expert
> **Triggered by**: /wf-implement-feature khi review code e-commerce module
> **Output**: E-commerce implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của e-commerce module
- Khi cần validate implementation từ business logic và domain perspective
- Khi cần check compliance (PCI-DSS, VAT, e-invoice, security)

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type:
□ Product Catalog → check taxonomy, variants, pricing rules, inventory linkage
□ Shopping Cart → check state machine, persistence, price lock, merge logic
□ Checkout Flow → check guest checkout, address, shipping, coupon application
□ Payment Integration → check gateway integration, signature, idempotency
□ Order Management → check order status machine, snapshot data, notifications
□ Inventory Management → check stock reservation, race conditions, audit trail
□ Promotion / Coupon → check validation logic, stacking rules, usage limits
□ Tax / E-invoice → check VAT calculation, e-invoice generation compliance
```

### Bước 2: Review Cart & Order State Machine Integrity

```
Cart state transitions phải đúng:
□ active → abandoned (sau N phút không activity)
□ active → converted (sau payment success)
□ abandoned → active (khi user quay lại)
□ Không cho phép: converted → active (backward transition)

Order state transitions phải đúng:
□ pending_payment → confirmed (payment success)
□ pending_payment → cancelled (timeout / failed / user cancel)
□ confirmed → processing (warehouse picked up)
□ processing → shipped (tracking number assigned)
□ shipped → delivered (delivery confirmed)
□ delivered → completed (after return window)
□ confirmed / processing → cancelled (refund triggered)
□ delivered → return_requested (nếu return policy cho phép)

Kiểm tra:
□ Mọi state transition có guard condition rõ ràng không?
□ Invalid transitions bị reject (không silently pass)
□ State change events được emit cho downstream systems (email, webhook)
□ Concurrency: 2 requests cùng update 1 order cùng lúc → xử lý thế nào?
```

### Bước 3: Review Payment Flow Security (PCI-DSS Checklist)

```
Bắt buộc review cho mọi payment-related code:

PCI-DSS Level 1 basics:
□ Không lưu raw card number, CVV, expiry trên server
□ Card data chỉ đi qua payment gateway (tokenization)
□ HTTPS/TLS 1.2+ cho toàn bộ payment endpoints
□ 3D Secure được implement cho card payments

Gateway integration:
□ Secret key KHÔNG hardcode trong source code → dùng environment variables
□ Webhook signature được verify (HMAC) trước khi process
□ Payment intent/session được tạo phía server, không phía client
□ Amount được tính phía server — KHÔNG trust amount từ client request
□ Order amount ở DB phải match với amount gửi gateway (anti-manipulation)

Idempotency:
□ Idempotency key = order_id được gửi với mọi payment request
□ Duplicate webhook events → chỉ process 1 lần (idempotent handler)
□ Test case: webhook gửi 2 lần cùng 1 event → order updated chỉ 1 lần

Logging:
□ KHÔNG log card data, CVV, raw payment credentials
□ KHÔNG log full payment token
□ Log payment events (attempt, success, fail) với masked data (last 4 digits only)

Refund:
□ Refund chỉ được trigger bởi authenticated admin / automated system
□ Refund amount <= original payment amount (validation)
□ Refund audit trail: ai trigger, khi nào, lý do
```

### Bước 4: Review Inventory Race Condition Handling

```
Vấn đề phổ biến: flash sale, nhiều users cùng mua cùng 1 sản phẩm

Kiểm tra:
□ Optimistic locking: version column trên Inventory table?
□ Hoặc Pessimistic locking: SELECT FOR UPDATE trong transaction?
□ Atomic decrement: UPDATE inventory SET qty = qty - ? WHERE qty >= ?
□ Không update qty rồi check — check trước, update trong cùng 1 statement

Test scenarios cần verify:
□ 100 users cùng lúc mua sản phẩm còn 1 cái → chỉ 1 người thành công
□ Cart reservation expire → stock được release đúng không?
□ Order cancelled → stock được hoàn lại đúng không?
□ Race condition giữa reserve và deduct

Flash sale specific:
□ Redis lock / distributed lock cho flash sale inventory?
□ Queue-based processing để serialize requests?
□ Pre-allocation: giữ N item cho flash sale trước khi bắt đầu
□ Overselling protection: tuyệt đối không cho phép qty_available âm
```

### Bước 5: Review Pricing Calculation Accuracy

```
Pricing logic phải deterministic — cùng input cho cùng output:

□ Thứ tự áp dụng pricing layers đúng không?
  (flash sale > customer-specific > tier > sale > base)
□ Rounding: làm tròn CUỐI CÙNG, không rounding từng bước trung gian
□ Floating point: dùng Decimal/BigDecimal, KHÔNG dùng float/double
□ VND: không có decimal (1,000 VND, không phải 1,000.50 VND)
□ Multi-currency: exchange rate apply đúng không? Khi nào snapshot rate?

Tax calculation:
□ VAT 8% vs 10% áp dụng đúng theo category không?
□ VAT tính trên unit price hay trên discounted price?
  → Chuẩn VN: VAT tính trên giá bán cuối (sau discount)
□ Shipping fee có tính VAT không? → Thường có, tùy loại
□ Grand total = subtotal + shipping - discount + tax (thứ tự đúng)

Order total reconciliation test:
□ sum(item.quantity × item.unit_price) = order.subtotal
□ order.subtotal - order.discount + order.shipping + order.tax = order.grand_total
□ Không có rounding discrepancy > 1 VND
```

### Bước 6: Review Coupon Validation Logic

```
□ Validation có atomic không? (check + apply trong 1 transaction)
□ Race condition: 2 users cùng apply coupon có usage_limit = 1 → 1 người thành công
□ Timing check: server time (không phải client time) cho start_at/end_at
□ Usage count increment atomic: UPDATE coupons SET usage_count = usage_count + 1 WHERE ...
□ Rollback: nếu order fail sau khi coupon applied → usage_count được giảm lại

Security:
□ Coupon code không được đoán được (không phải SALE10, DISCOUNT20 v.v.)
□ Brute force: rate limit cho coupon validation endpoint
□ Code case-insensitive normalize: "SALE10" = "sale10" = "Sale10"

B2B-specific:
□ Customer-specific coupons: validate user_id match
□ Single-use coupon: đánh dấu used ngay sau apply, trước khi payment
```

### Bước 7: Review VAT & Tax Calculation

```
Vietnam tax compliance:

□ VAT rate đúng per product category (8% hoặc 10%)?
□ Có thể configure VAT rate không (khi nhà nước thay đổi)?
□ Tax-exempt products (sách giáo khoa, một số thực phẩm) được xử lý?
□ VAT được hiển thị rõ ràng trên order confirmation và invoice?
□ Tax amount được lưu vào order record (không chỉ tính lại)

E-invoice (Hóa đơn điện tử):
□ E-invoice được gen tự động sau payment_success webhook?
□ Thông tin bắt buộc: buyer name, address, tax code (nếu B2B), items, VAT
□ Serial number đúng định dạng theo quy định?
□ Sent to buyer email trong vòng 24h sau giao dịch
□ Báo cáo định kỳ gửi Cục Thuế (batch job)?
□ E-invoice provider: VNPT / Viettel-S / MISA / Fast — API integration đúng?

Error handling:
□ E-invoice generation fail → không block order completion
□ Retry logic cho e-invoice gen (3 attempts)
□ Alert khi e-invoice fail nhiều lần → manual intervention
```

### Bước 8: Review Performance (Flash Sale Load)

```
Flash sale là scenario khắc nghiệt nhất cho e-commerce:

□ Product page cache (CDN/Redis): TTL ngắn hơn khi flash sale active?
□ Inventory read: cache hay real-time? (real-time cần thiết cho flash sale)
□ Cart/checkout: không có N+1 queries
□ Database indexes: có index trên variant_id, order_id, cart_id?
□ Payment callback handling: có queue/async processing không?

Load test checklist:
□ Target: chịu được Nx normal traffic (N tùy yêu cầu, thường 10-50x)
□ Checkout endpoint: concurrent requests không gây inventory corruption
□ Database connection pool: không bị exhausted
□ Payment gateway rate limits: biết limits của gateway, có queue không?

Common bottlenecks:
□ SELECT * thay vì SELECT needed_columns
□ Missing JOIN indexes → full table scan khi order volume lớn
□ Synchronous email sending trong request thread → move to queue
□ Image resize on-the-fly → pre-resize, serve từ CDN
```

### Bước 9: Output — Review Report

```markdown
# E-commerce Implementation Review: [Module Name]

## Compliance Status: PASS / FAIL / NEEDS ATTENTION

## Critical Issues (chặn go-live)
- [ ] [Issue]: [Vị trí trong code] → [Fix bắt buộc]

## Important Issues (fix trước sprint tiếp theo)
- [ ] [Issue]: [Vị trí] → [Recommendation]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

## Domain Compliance Checklist

### Payment Security (PCI-DSS)
| Item | Status | Notes |
|------|--------|-------|
| Không lưu card data raw | OK / FAIL | ... |
| Webhook signature verified | OK / FAIL | ... |
| Idempotent payment processing | OK / FAIL | ... |
| Amount validated server-side | OK / FAIL | ... |

### Inventory Integrity
| Item | Status | Notes |
|------|--------|-------|
| Race condition protection | OK / FAIL | ... |
| Atomic stock decrement | OK / FAIL | ... |
| Reservation release on cancel | OK / FAIL | ... |

### Tax & Legal (Vietnam)
| Item | Status | Notes |
|------|--------|-------|
| VAT rate correct per category | OK / FAIL | ... |
| E-invoice auto-generated | OK / FAIL | ... |
| Order total reconciliation | OK / FAIL | ... |

### Performance
| Scenario | Result | Target |
|----------|--------|--------|
| PDP load | ...ms | <1500ms |
| Checkout page | ...ms | <1000ms |
| Flash sale concurrent | ... req/s | ... |

## Sign-off
□ Payment security: OK / ISSUE
□ Inventory integrity: OK / ISSUE
□ Business logic accuracy: OK / ISSUE
□ Tax/legal compliance: OK / ISSUE
□ Performance: OK / ISSUE
```

---

## Checklist trước khi submit

```
□ State machine integrity đã verify (cart + order)
□ PCI-DSS payment checklist đầy đủ
□ Inventory race condition tests đã review
□ Pricing calculation dùng Decimal, không float
□ Coupon validation atomic
□ VAT rate đúng per category
□ E-invoice auto-generation được kiểm tra
□ Performance bottlenecks cho flash sale đã identified
□ Critical issues phân biệt rõ với suggestions
□ Sign-off checklist điền đầy đủ
```
