# Playbook: Thiết kế Cart & Checkout Flow

> **Type**: Agent Skill Playbook
> **Agent**: ecommerce-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần design cart & checkout
> **Output**: Feature spec cho Cart và Checkout module

---

## Khi nào dùng playbook này

- Khi cần spec module "Giỏ hàng" / "Checkout" / "Thanh toán"
- Khi thiết kế luồng mua hàng end-to-end
- Phase 2 (Feature spec) hoặc Phase 3 (Technical design) của workflow

---

## Procedure

### Bước 1: Xác định scope và constraints

```
Hỏi hoặc suy luận từ context:
□ Guest checkout có bắt buộc không? (recommended: YES)
□ Multi-seller cart có cần không? (marketplace)
□ Payment methods cần support (VNPay, MoMo, ZaloPay, Stripe, COD...)
□ Shipping: flat-rate / real-time carrier rates / free shipping conditions
□ Coupon/voucher system có không?
□ B2B checkout có không? (NET terms, PO upload, approval)
□ Subscription checkout có không? (recurring billing)
□ Inventory reservation strategy: cart-level hay order-level?
```

### Bước 2: Thiết kế Cart Management

```
READ: customer-journey.md → Stage 3 (Purchase) → Checkout Flow

Cart state machine:
  active (đang dùng) → abandoned (>30 phút không activity) →
  converted (đặt hàng thành công) → expired (>7 ngày, archived)

Cart (session cart):
  - id, session_id (anonymous) hoặc user_id (logged in)
  - status: active / abandoned / converted / expired
  - currency_code
  - expires_at
  - created_at, updated_at

CartItem:
  - id, cart_id, variant_id
  - quantity
  - unit_price (snapshot tại thời điểm add — không thay đổi khi giá catalog thay đổi)
  - applied_price (sau discount)
  - seller_id (nullable — cho marketplace split)
  - is_gift (boolean)
  - gift_message
  - added_at

Business rules:
□ Cart persist 7 ngày cho anonymous user (cookie-based)
□ Merge cart khi anonymous user login (anonymous cart + user cart)
□ Khi merge: quantity cộng dồn, không duplicate items
□ Price lock: giá trong cart giữ nguyên 30 phút, sau đó refresh
□ Stock check mỗi lần open cart page
□ Out-of-stock items → hiển thị cảnh báo, không chặn checkout ngay
□ Quantity validation: 1 ≤ qty ≤ max_per_order (configurable per SKU)
```

### Bước 3: Thiết kế Guest vs Registered Checkout

```
READ: personas.md → Shopper pain points: "forced registration"

Guest checkout flow:
  Cart → Email input → Shipping → Payment → Confirmation
  (không yêu cầu password)
  Sau order thành công → offer "create account with this email"

Registered checkout flow:
  Cart → Login/Register → Shipping (prefilled) → Payment (saved cards) → Confirmation

Social login (OAuth):
□ Google / Facebook login → reduce friction
□ Link social account với existing email (merge accounts)

Guest-to-account conversion:
□ Email confirmation link sau order → set password → account created
□ Giữ nguyên order history khi convert
□ Không force duplicate: kiểm tra email đã tồn tại
```

### Bước 4: Thiết kế Address Management

```
Address:
  - id, user_id (nullable — guest addresses gắn với order)
  - full_name, phone
  - province_id, district_id, ward_id (theo đơn vị hành chính VN)
  - street_address (số nhà, tên đường)
  - postal_code
  - is_default (boolean)
  - address_type: home / office / other
  - label (custom: "Nhà", "Công ty"...)

Vietnam address hierarchy:
□ Tỉnh/Thành phố → Quận/Huyện → Phường/Xã
□ Danh sách chuẩn: lấy từ data.gov.vn hoặc static JSON
□ Auto-fill postal code theo ward
□ Geocoding optional (Google Maps API cho hiển thị bản đồ)

Validation rules:
□ Phone: 10 số, bắt đầu 0 (VN format)
□ Tên: không chứa ký tự đặc biệt
□ Địa chỉ: không để trống street_address
```

### Bước 5: Thiết kế Shipping Calculation

```
Shipping methods:

1. Flat rate:
   - Phí cố định per order hoặc per item
   - Free shipping khi cart > threshold (ví dụ: miễn phí ship khi >500K)

2. Weight-based:
   - Tính theo tổng trọng lượng cart
   - Rate table: weight_range → price

3. Real-time carrier rates:
   - GHN (Giao Hàng Nhanh) API
   - GHTK (Giao Hàng Tiết Kiệm) API
   - Viettel Post API
   - Input: from_address, to_address, weight, dimensions
   - Output: estimated fee + estimated delivery date

4. Free shipping (override):
   - Conditions: cart_total > X / membership tier / promotion code

ShippingMethod:
  - id, name, carrier (ghn / ghtk / viettel / flat)
  - estimated_days_min, estimated_days_max
  - fee_calculation_type: flat / weight / api
  - is_active, sort_order

Inventory reservation tại bước shipping:
□ Khi user chọn shipping method → reserve stock
□ Reservation expires sau 30 phút nếu không complete payment
□ Tự động release khi reservation expires
```

### Bước 6: Thiết kế Coupon & Voucher Application

```
Coupon:
  - id, code (unique, case-insensitive)
  - discount_type: percentage / fixed_amount / free_shipping / buy_x_get_y
  - discount_value
  - min_order_value (nullable)
  - max_discount_amount (cap cho percentage discounts)
  - applicable_to: all / category / product (JSON list)
  - usage_limit_total (nullable — null = unlimited)
  - usage_limit_per_user (nullable)
  - usage_count (current)
  - start_at, end_at
  - is_active

Validation rules khi apply coupon:
□ Code tồn tại và is_active
□ Chưa hết hạn (start_at <= now <= end_at)
□ Chưa đạt usage_limit_total
□ User chưa dùng quá usage_limit_per_user
□ Cart total >= min_order_value
□ Sản phẩm trong cart thuộc applicable_to scope

Stacking rules:
□ Chỉ 1 coupon code / order (default)
□ Ngoại lệ: loyalty points có thể stack với coupon
□ Flash sale price không stack với coupon (cần business rule rõ)

Voucher (seller-specific, marketplace):
□ Seller tự tạo voucher → tự chịu discount cost
□ Platform voucher → platform chịu
□ Split discount cost theo origin
```

### Bước 7: Thiết kế Payment Gateway Integration

```
Payment flow chuẩn:

1. User chọn payment method
2. System tạo Order với status = pending_payment
3. System tạo payment intent / payment request tại gateway
4. Redirect user đến gateway (hoặc in-page form)
5. User hoàn thành payment
6. Gateway callback (webhook) → System nhận kết quả
7. System verify signature (chống giả mạo)
8. Cập nhật Order status: confirmed / failed

VNPay integration:
  □ API: VNPay VNPAY-QR, VNPAY-ATM
  □ Signature: HMAC-SHA512 với secret key
  □ Callback URL: POST /webhooks/vnpay
  □ IPN (Instant Payment Notification) + Return URL
  □ Test environment: sandbox.vnpayment.vn

MoMo integration:
  □ API: MoMo Payment Gateway v2
  □ Signature: HMAC-SHA256
  □ Callback: IPN endpoint
  □ Deep link cho mobile app redirect

ZaloPay integration:
  □ API: ZaloPay Gateway
  □ Order token tạo phía server
  □ Mac verification trên callback

Stripe integration (international):
  □ Payment Intents API (recommend) — hỗ trợ 3D Secure
  □ Stripe Elements hoặc Stripe Checkout
  □ Webhook: payment_intent.succeeded / payment_intent.payment_failed

COD (Cash on Delivery):
  □ Không cần payment gateway
  □ Order tạo với status = confirmed (COD)
  □ Payment collected khi giao hàng → driver update
  □ Risk: fraud check trước khi accept COD (address verify, phone verify)

Security requirements:
□ Không log raw payment credentials
□ Payment token lưu qua Stripe/gateway (không lưu card number)
□ Webhook signature verification bắt buộc
□ Idempotent payment processing (tránh charge 2 lần)
```

### Bước 8: Thiết kế Order Confirmation & Inventory Reservation

```
Sau khi payment thành công (hoặc COD confirmed):

Order status machine:
  pending_payment → confirmed → processing → shipped → delivered → completed
  pending_payment → cancelled (timeout / user cancel / payment failed)
  confirmed → cancelled (before shipped, with refund trigger)
  delivered → return_requested → returned → refunded

Order creation checklist:
□ Tạo Order record với snapshot data (giá, địa chỉ, sản phẩm)
□ Deduct inventory: quantity_on_hand -= qty, quantity_reserved = 0
□ Gửi order confirmation email (bắt buộc trong 1 phút)
□ Gửi SMS confirmation (optional, nếu có SMS gateway)
□ Trigger e-invoice generation (nếu required bởi pháp lý)
□ Notify seller (marketplace: per-seller notification)
□ Notify warehouse/WMS (picking list trigger)

Order snapshot (tại thời điểm đặt hàng — KHÔNG thay đổi sau):
  - product name, SKU, variant attributes
  - unit_price, quantity, total
  - shipping_address (full copy, không FK)
  - shipping_method name + fee
  - coupon_code + discount_amount applied
  - tax_amount, grand_total

Lý do snapshot: tránh data drift khi sản phẩm bị edit sau khi order
```

### Bước 9: Thiết kế Failed Payment Handling

```
Scenarios cần xử lý:

1. Payment timeout (user không hoàn thành trong 15 phút):
   → Auto-cancel pending_payment order
   → Release inventory reservation
   → Gửi email "Đơn hàng của bạn đã hết hạn" + link re-order

2. Payment declined (insufficient funds, card expired...):
   → Order status = payment_failed (không xóa order)
   → Hiển thị lỗi rõ ràng từ gateway (localized messages)
   → Cho phép retry với payment method khác
   → Giữ cart data để re-checkout dễ dàng

3. Payment pending (VNPay ATM processing, bank transfer):
   → Order status = pending_payment
   → Inventory reserved nhưng chưa deducted
   → Webhook sẽ confirm khi payment cleared
   → Timeout sau 24h → auto-cancel

4. Duplicate payment (network error → user click 2 lần):
   → Idempotency key = order_id
   → Gateway phát hiện → chỉ charge 1 lần
   → Nếu 2 lần charge → auto-refund 1 lần qua reconciliation

Retry logic:
□ Webhook nhận failed → retry 3 lần (exponential backoff: 1m, 5m, 15m)
□ Sau 3 retries → alert DevOps + ghi log để manual review
□ Dead letter queue cho failed webhooks
```

### Bước 10: Feature Spec Output

```markdown
# Feature Spec: Cart & Checkout

## REQ-ID Coverage
REQ-ECOM-CART-001: Cart CRUD (add, update quantity, remove, clear)
REQ-ECOM-CART-002: Cart persistence (session + logged-in, merge on login)
REQ-ECOM-CART-003: Real-time stock check & price lock
REQ-ECOM-CART-004: Cart abandonment tracking (trigger recovery email)
REQ-ECOM-CHK-001: Guest checkout (no forced registration)
REQ-ECOM-CHK-002: Address management (VN hierarchy, auto-fill)
REQ-ECOM-CHK-003: Shipping method selection & calculation
REQ-ECOM-CHK-004: Coupon/voucher application & validation
REQ-ECOM-CHK-005: Payment gateway integration (VNPay, MoMo, ZaloPay, COD)
REQ-ECOM-CHK-006: Order confirmation + email notification
REQ-ECOM-CHK-007: Inventory reservation & deduction on payment
REQ-ECOM-CHK-008: Failed payment handling & retry flow
REQ-ECOM-CHK-009: Order status machine (full lifecycle)

## Non-functional Requirements
- Checkout page load < 1s
- Payment redirect < 500ms
- Inventory reservation race condition: optimistic locking
- Webhook processing: idempotent, at-least-once delivery

## Security Requirements
- HTTPS required toàn bộ checkout flow
- CSRF protection trên checkout endpoints
- Rate limiting: max 10 attempts/IP/minute trên payment endpoint
- No PII logging trong payment flow
```

---

## Checklist trước khi submit

```
□ Guest checkout được thiết kế rõ ràng (không force registration)
□ Cart merge logic khi anonymous → login đã documented
□ Inventory reservation strategy đã chọn (cart-level với 30-min expiry)
□ Tất cả payment gateways VN đã listed (VNPay, MoMo, ZaloPay, COD)
□ Webhook signature verification được nhấn mạnh
□ Idempotency cho payment processing
□ Failed payment handling đầy đủ 4 scenarios
□ Order snapshot đã được thiết kế (không FK tới live catalog data)
□ E-invoice trigger sau payment success (VN compliance)
□ Mỗi REQ có REQ-ID format REQ-ECOM-CART/CHK-[NNN]
```
