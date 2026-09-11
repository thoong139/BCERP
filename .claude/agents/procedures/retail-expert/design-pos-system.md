# Playbook: Design POS System Module

> **Type**: Agent Skill Playbook
> **Agent**: retail-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi có POS module
> **Output**: Feature spec cho POS module (`.mc-data/docs/phase2-features/[sys]/pos/`)

---

## Khi nào dùng playbook này

- Khi cần spec module Point of Sale
- Khi cần thiết kế transaction flow và payment processing
- Khi review/audit hệ thống POS hiện có
- Đặc biệt cần chú ý: **offline mode là yêu cầu bắt buộc** (kết nối mạng tại cửa hàng thường không ổn định)

---

## Procedure

### Bước 1: Xác định scope POS

```
READ: .claude/references/team-expert/retail/operations.md → Section POS Workflow

Hỏi hoặc suy luận từ context:
□ Loại POS: Desktop POS, Mobile POS (tablet/phone), Self-checkout, Hybrid?
□ Số terminal/store: 1-2 terminal hay nhiều (ảnh hưởng sync strategy)
□ Barcode types cần support: EAN-13, Code128, QR, RFID?
□ Scale integration cần không? (thực phẩm bán theo kg)
□ Pharmacy mode cần không? (kiểm soát thuốc theo đơn)
□ Age verification cần không? (rượu, thuốc lá)
□ Customer display cần không? (pole display hiển thị giá cho khách)
```

### Bước 2: Thiết kế Transaction Flow

```
READ: .claude/references/team-expert/retail/operations.md → Section Sales Transaction

STANDARD CHECKOUT FLOW:

[1] Khởi tạo transaction
    - Cashier đăng nhập / xác thực ca làm việc
    - Chọn terminal / cash drawer
    - Tạo transaction mới (generate transaction_id tức thì)

[2] Identify Customer (optional)
    - Quét loyalty card / nhập phone number / scan QR
    - Pull customer profile + điểm tích lũy + vouchers
    - Hiển thị thông tin khách: tên, tier, điểm còn lại

[3] Add Items
    - Quét barcode → lookup giá từ price list hiện hành
    - Nhập manual (tìm theo tên / PLU code)
    - Nhập số lượng / đơn vị (kg nếu có scale)
    - Apply auto-promotions (buy X get Y, bundle discount)
    - Hiển thị subtotal real-time

[4] Apply Discounts & Vouchers
    - Scan voucher / coupon code
    - Manual discount (cần supervisor approval nếu > threshold)
    - Loyalty points redemption
    - Employee discount (nếu applicable)
    - Validate: không stack discount trái quy định

[5] Payment Processing
    - Chọn payment method(s) (có thể nhiều loại)
    - Xử lý từng payment (xem Bước 3)
    - Verify tổng đã thanh toán ≥ grand total

[6] Complete Transaction
    - Print / email / SMS receipt
    - Tích điểm loyalty (nếu customer identified)
    - Update inventory (deduct sold items)
    - Lưu transaction record
    - Mở cash drawer (nếu cash payment)
    - Reset terminal cho giao dịch tiếp theo

STATE MACHINE:
IDLE → SCANNING → PAYMENT → COMPLETED
                           ↓
                        VOIDED (trước khi complete)
```

### Bước 3: Thiết kế Payment Processing

```
READ: .claude/references/team-expert/retail/controls.md → Payment Controls

CASH PAYMENT:
- Nhập tiền khách đưa → tính tiền thối
- Validate: tiền đưa ≥ amount due
- Hỗ trợ over-tender (tiền lẻ + tờ lớn)
- Log: amount_tendered, change_given

CARD PAYMENT (EDC Integration):
- Gửi amount đến EDC terminal
- Chờ approval response (timeout 60s)
- On success: lưu approval_code, last_4_digits, card_scheme
- On decline: hiển thị thông báo, cho phép thử lại hoặc chọn method khác
- On timeout: không tự approve → yêu cầu cashier xác nhận

E-WALLET (VNPay / MoMo / ZaloPay / ShopeePay):
- Generate QR code với amount và transaction_ref
- Poll payment status (webhook preferred, fallback polling mỗi 3s)
- Timeout: 5 phút → expire QR, thông báo cashier
- On success: lưu wallet_transaction_id, wallet_provider
- Đảm bảo idempotency: cùng transaction_ref không charge 2 lần

SPLIT PAYMENT (critical requirement):
- Cho phép combine nhiều payment methods
- Ví dụ: Cash 200k + VNPay 150k + Điểm loyalty 50k = 400k
- Partial payment tracking: remaining_amount sau mỗi step
- Rollback: nếu một phương thức fail sau phương thức khác đã success → alert cashier, hướng dẫn hoàn tiền thủ công

LOYALTY REDEMPTION:
- Hiển thị điểm có thể dùng + tỷ lệ quy đổi (ví dụ: 100 điểm = 10,000 VND)
- Partial redemption: khách chọn dùng bao nhiêu điểm
- Minimum redemption unit (ví dụ: tối thiểu 50 điểm)
- Deduct points real-time sau transaction complete
```

### Bước 4: Thiết kế Offline Mode

```
WHY: Kết nối mạng tại cửa hàng không ổn định. POS PHẢI hoạt động khi mất mạng.

OFFLINE DETECTION:
- Health check server mỗi 10s (lightweight ping)
- Chuyển sang Offline Mode khi 3 lần ping liên tiếp thất bại
- Hiển thị rõ ràng trên UI: "OFFLINE MODE - Chỉ nhận tiền mặt"
- Log timestamp khi offline bắt đầu

OFFLINE CAPABILITIES:
□ Tiếp tục bán hàng (cash only)
□ Price lookup từ local cache (sync giá định kỳ khi online)
□ Inventory deduction vào local queue
□ Receipt in được (local printer không cần internet)
□ Tích điểm loyalty queue (sync sau)

OFFLINE RESTRICTIONS:
□ KHÔNG accept e-wallet (không verify được)
□ KHÔNG accept card nếu EDC offline (tùy terminal, có terminal offline approval)
□ KHÔNG apply voucher mới (không verify được, chỉ pre-loaded vouchers)
□ KHÔNG lookup real-time inventory của stores khác

LOCAL STORAGE (mỗi terminal):
- Price list cache: sync mỗi giờ khi online (hoặc force sync khi mở ca)
- Promotion cache: sync mỗi giờ
- Transaction queue: lưu tất cả transactions offline
- Loyalty points adjustment queue

SYNC STRATEGY khi online trở lại:
1. Detect online → bắt đầu sync ngay
2. Upload offline transactions theo thứ tự thời gian
3. Server validate: không duplicate (kiểm tra transaction_id)
4. Inventory: áp dụng deductions theo thứ tự, flag nếu stock âm (để review sau)
5. Loyalty points: áp dụng points earned từ offline transactions
6. Notify HQ: "Store [X] vừa kết nối lại, [N] transactions offline đã sync"

CONFLICT RESOLUTION:
- Duplicate transaction_id: skip, log warning, alert manager
- Stock đã hết khi sync: ghi nhận sold, tạo negative inventory alert
- Price đã thay đổi khi offline: ghi nhận giá cũ, không recharge khách
- Loyalty points vượt balance: ghi nhận, review thủ công
```

### Bước 5: Thiết kế Return & Exchange Workflow

```
READ: .claude/references/team-expert/retail/controls.md → Return Policy

RETURN FLOW:
[1] Tra cứu đơn hàng gốc (receipt number, order ID, hoặc customer phone)
[2] Verify: trong thời hạn đổi trả (ví dụ: 7 ngày / 30 ngày)
[3] Kiểm tra điều kiện sản phẩm (còn nguyên đai nguyên kiện?)
[4] Chọn phương thức hoàn tiền:
    - Tiền mặt (nếu gốc là cash)
    - Hoàn về thẻ / ví (nếu gốc là card/e-wallet — theo quy định)
    - Store credit / Gift card
    - Exchange (đổi sang sản phẩm khác)
[5] Cần supervisor approval nếu:
    - Amount > threshold (ví dụ: > 500k VND)
    - Không có receipt
    - Sau quá hạn đổi trả thông thường
[6] Process refund
[7] Deduct loyalty points đã tích (nếu hoàn toàn bộ)
[8] Update inventory (add back returned item)

EXCHANGE FLOW:
- Return item (theo Return Flow trên)
- New sale for replacement item
- Charge/refund price difference
- Loyalty points: chỉ tích cho phần giá trị dương (nếu exchange lên đời cao hơn)
```

### Bước 6: Thiết kế End-of-Day Cash Reconciliation

```
READ: .claude/references/team-expert/retail/controls.md → Cash Management

CLOSING PROCEDURE:
[1] Cashier count physical cash trong drawer
[2] System tính expected cash:
    Opening float
    + Cash sales trong ca
    - Cash refunds
    - Cash payouts (nếu có)
    = Expected closing balance
[3] So sánh: Actual vs Expected
[4] Ghi nhận over/short (kèm lý do nếu biết)
[5] Manager review và ký duyệt
[6] Submit closing report → gửi về HQ

CASH VARIANCE RULES:
- Short/Over < 5,000 VND: Auto-approve (rounding)
- Short/Over 5,000 - 50,000 VND: Manager approval required
- Short/Over > 50,000 VND: Area Manager notification, investigation required
- 3 lần short liên tiếp: Flag cho HR
```

### Bước 7: Hardware Integration Requirements

```
BARCODE SCANNER:
- USB HID hoặc Bluetooth (tự động nhận dạng)
- Support: EAN-13, EAN-8, Code128, Code39, QR Code, DataMatrix
- Scan speed: < 100ms response time
- Continuous scan mode cho checkout nhanh

RECEIPT PRINTER:
- Thermal printer qua USB/LAN/Bluetooth
- Receipt template configurable (logo, footer message, promotions)
- Print speed: ≥ 200mm/s
- Fallback: in sau (email/SMS) nếu printer offline

CASH DRAWER:
- Kick via printer RJ-11 port hoặc USB
- Chỉ mở khi: (a) cash payment, (b) cash refund, (c) supervisor override
- Log mỗi lần mở (ai, khi nào, lý do)

EDC TERMINAL:
- Protocol: ISO 8583 hoặc vendor SDK (Ingenico, Verifone, PAX)
- Semi-integrated: EDC handle card data, POS nhận approval code
- Không lưu card data trên POS (PCI-DSS)

CUSTOMER DISPLAY (optional):
- Hiển thị: item vừa scan, giá, subtotal, payment received, change
- Có thể hiển thị quảng cáo / promotion khi idle

SCALE (nếu có):
- Kết nối qua RS-232 hoặc USB
- Tự động đọc cân nặng khi đặt sản phẩm
- Tính giá = weight × unit_price
```

### Bước 8: Feature Spec Output

```markdown
# Feature Spec: POS System

## Overview
[Mô tả module POS]

## User Stories
- As a Cashier, I want to scan items quickly so that checkout time < 3 minutes for a typical basket
- As a Store Manager, I want offline mode so that sales continue when internet is down
- As a Customer, I want to pay with multiple methods so that I can split payment

## Functional Requirements
REQ-RETAIL-POS-001: Transaction flow (scan → discount → payment → receipt)
REQ-RETAIL-POS-002: Offline mode — tiếp tục bán hàng khi mất kết nối
REQ-RETAIL-POS-003: Offline sync — đồng bộ transactions khi online trở lại
REQ-RETAIL-PAY-001: Cash payment + thối tiền
REQ-RETAIL-PAY-002: Card payment qua EDC terminal (semi-integrated)
REQ-RETAIL-PAY-003: E-wallet (VNPay, MoMo, ZaloPay, ShopeePay)
REQ-RETAIL-PAY-004: Split payment (nhiều phương thức trong 1 đơn)
REQ-RETAIL-PAY-005: Loyalty points redemption tại POS
REQ-RETAIL-POS-004: Return và exchange workflow
REQ-RETAIL-POS-005: End-of-day cash reconciliation
REQ-RETAIL-POS-006: Receipt in / email / SMS
REQ-RETAIL-HW-001: Barcode scanner integration
REQ-RETAIL-HW-002: Receipt printer integration
REQ-RETAIL-HW-003: Cash drawer integration
REQ-RETAIL-HW-004: EDC terminal integration (semi-integrated, PCI-DSS)

## Data Model
[ERD hoặc field definitions cho Transaction, TransactionItem, Payment, OfflineQueue]

## Non-functional Requirements
- Checkout time: < 3 phút cho giỏ hàng 10 items
- Offline startup: < 5 giây để vào offline mode
- Sync: Offline transactions upload trong < 30s khi online trở lại
- PCI-DSS: Không lưu card data trên POS
- Availability: 99.5% uptime (offline mode đảm bảo không gián đoạn kinh doanh)
```

---

## Checklist trước khi submit

```
□ Transaction state machine đã đầy đủ (bao gồm void, suspend, offline states)
□ Offline mode requirements chi tiết (detection, capabilities, restrictions, sync)
□ Conflict resolution khi sync đã được define
□ Split payment flow đã được spec
□ PCI-DSS compliance: card data không lưu trên POS
□ Cash reconciliation workflow đã có
□ Return/exchange workflow đã có supervisor approval gate
□ Hardware integration requirements đã listed
□ REQ-ID đúng format REQ-RETAIL-POS-[NNN] và REQ-RETAIL-PAY-[NNN]
□ Performance targets đã define
```
