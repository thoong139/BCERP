# Playbook: Review Retail Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: retail-expert
> **Triggered by**: /wf-implement-feature sau khi code retail module hoàn thành
> **Output**: Retail implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của retail / POS module
- Khi cần validate implementation từ business logic và operations perspective
- Khi cần check correctness của transaction processing, offline mode, payment reconciliation

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type và load controls tương ứng:

□ POS / Transaction Processing
  → review transaction state machine, payment processing, receipt
□ Offline Mode & Sync
  → review offline detection, local storage, sync conflict resolution
□ Payment Processing
  → review split payment, e-wallet integration, PCI-DSS compliance
□ Return & Exchange
  → review authorization gates, inventory reversal, loyalty adjustment
□ Store Management / Shift
  → review opening/closing procedures, cash reconciliation logic
□ Inventory Management (store level)
  → review stock deduction, receiving, transfer, shrinkage
□ Reporting & Dashboard
  → review KPI calculations, data freshness, multi-store queries
□ Franchise Management
  → review royalty calculation, billing generation, compliance tracking

READ: .claude/references/team-expert/retail/controls.md → Luôn đọc, bất kể module nào
```

### Bước 2: Transaction State Machine Integrity

```
Chỉ thực hiện cho POS / Transaction module.

□ States đầy đủ: IDLE → SCANNING → DISCOUNT_APPLIED → PAYMENT → COMPLETED / VOIDED / SUSPENDED
□ State transitions: Không thể nhảy state bất hợp lý
   (ví dụ: COMPLETED → SCANNING không được phép)
□ Concurrent transaction protection: 1 cashier không thể mở 2 transactions cùng lúc
□ Transaction timeout: Có auto-void sau thời gian idle không? (ví dụ: 30 phút)
□ Transaction ID uniqueness: Có đảm bảo globally unique không? (quan trọng khi offline)
□ Void authorization: Chỉ supervisor hoặc manager mới được void?
□ Post-void inventory: Khi void → inventory có được cộng lại không?
□ Immutability: Completed transactions không thể edit, chỉ có thể create refund
□ Audit trail: Mỗi state change có log (actor, timestamp, reason) không?
```

### Bước 3: Offline Mode Reliability

```
Đây là critical review — offline mode phải hoàn toàn reliable.

OFFLINE DETECTION:
□ Health check implementation: Lightweight endpoint, không phải full API call
□ Detection threshold: 3 consecutive failures (không quá sensitive, không quá chậm)
□ UI indicator: Hiển thị rõ "OFFLINE MODE" khi mất mạng
□ Fallback behavior: Chỉ cho phép cash khi offline (không accept e-wallet/card nếu cần verify)

LOCAL STORAGE:
□ Transaction queue: Lưu đầy đủ transaction data locally (không chỉ ID)
□ Price cache: Có timestamp, biết khi nào cần refresh
□ Promotion cache: Có timestamp, valid rules được cache
□ Queue persistence: Data survive app crash và reboot không?
□ Storage limit: Xử lý thế nào khi local storage đầy?

SYNC LOGIC:
□ Auto-sync trigger: Bắt đầu sync ngay khi detect online
□ Order preservation: Sync theo thứ tự thời gian giao dịch
□ Idempotency: Re-sync không tạo duplicate (kiểm tra transaction_id)
□ Partial sync handling: Nếu sync bị interrupt giữa chừng → tiếp tục từ đâu?
□ Error handling per transaction: 1 transaction fail không block cả queue
□ Conflict resolution:
   - Duplicate transaction_id: Skip + log warning
   - Stock âm sau sync: Ghi nhận, tạo alert, không rollback giao dịch đã xảy ra
   - Price đã thay đổi: Ghi nhận giá cũ, không recharge khách
   - Loyalty vượt balance: Ghi nhận, flag for manual review

NOTIFICATION:
□ Store Manager được thông báo khi: mất mạng, có N transactions offline, sync hoàn thành
□ HQ được thông báo khi: store offline > X phút, sync failures
```

### Bước 4: Payment Processing Accuracy

```
READ: .claude/references/team-expert/retail/controls.md → Payment Controls

CASH:
□ Change calculation: Correct rounding (không làm tròn có lợi cho store)
□ Zero change: Không hiển thị "Tiền thối: -5,000 VND" (phải validate amount_tendered)
□ Denominations: Nếu có tracking denominations → tính toán đúng không?

CARD (EDC):
□ Semi-integrated: POS chỉ gửi amount, không xử lý card data trực tiếp
□ PCI-DSS: Không log card number, CVV, full PAN anywhere
□ Timeout handling: Sau 60s không có response → không tự approve, yêu cầu xác nhận
□ Decline handling: Hiển thị thông báo phù hợp, không expose internal error codes
□ Approval code lưu: approval_code, last4, card_scheme (không lưu full PAN)

E-WALLET:
□ Idempotency key: Mỗi payment request có unique key → không charge 2 lần
□ QR expiry: QR code hết hạn sau 5 phút, không accept payment sau expiry
□ Status polling: Interval hợp lý (mỗi 3s), có maximum retry count
□ Webhook signature: Verify signature của webhook từ payment provider
□ Amount mismatch: Nếu amount thanh toán ≠ amount expected → reject, alert

SPLIT PAYMENT:
□ Remaining amount tracking: remaining = grand_total - Σ(payments_made) luôn chính xác
□ Overpayment prevention: Không cho phép total_paid > grand_total
□ Partial failure: Nếu 1 method fail sau 1 method đã success → không rollback thành công, hiển thị hướng dẫn cashier
□ Receipt: Liệt kê rõ từng phương thức và số tiền

LOYALTY REDEMPTION:
□ Balance check: Kiểm tra điểm thực tế trước khi redeem (không cache cũ)
□ Minimum unit: Enforce minimum redemption unit
□ Redemption rate: Tính toán đúng (points → VND)
□ Deduction: Deduct points ngay khi transaction complete, không trước đó
□ Failure rollback: Nếu transaction cancelled/voided → cộng điểm lại
```

### Bước 5: Inventory Deduction Real-time

```
□ Deduction timing: Inventory deducted tại thời điểm nào?
   - Correct: Khi transaction COMPLETED (không phải khi start scanning)
   - Nếu void: Inventory cộng lại ngay

□ Concurrency: 2 cashiers cùng bán sản phẩm cuối cùng trong kho → xử lý thế nào?
   - Phải có optimistic lock hoặc database-level constraint

□ Negative inventory handling:
   - Cho phép hay không? (cần có setting per product/store)
   - Nếu cho phép → phải alert

□ Offline deduction:
   - Local queue ghi nhận đúng items và quantities
   - Khi sync → áp dụng theo thứ tự
   - Flag nếu gây ra negative inventory

□ Return reversal: Khi return hoàn thành → inventory tăng lại đúng SKU, đúng store
□ Transfer: Deduct đúng source store, credit đúng destination store
□ Receiving: Tăng inventory chỉ sau khi manager confirm receipt (không phải khi PO tạo)
```

### Bước 6: Discount Stacking Rules

```
READ: .claude/references/team-expert/retail/controls.md → Discount Rules

□ Promotion types: Percentage, fixed amount, BOGO, bundle — tính toán đúng không?
□ Stacking rules: Có enforce "không stack promotion X với Y" không?
□ Priority order: Khi nhiều promotions eligible → áp dụng order đúng không?
□ Max discount cap: Có enforce max discount per transaction không?
□ Supervisor threshold: Discount > threshold yêu cầu supervisor PIN không?
□ Employee discount: Có bị stack với customer promotion không? (thường không cho phép)
□ Coupon validation: Coupon đã used / expired / wrong store / wrong product → reject đúng không?
□ Discount on top of discount: "Giảm thêm 10% trên giá đã giảm" — tính đúng không?
   Example: 500k giảm 20% = 400k, rồi giảm thêm 10% = 360k (không phải 500k × 30%)
□ Discount audit: Mọi discount có log: type, amount, who approved
```

### Bước 7: Return Policy Enforcement

```
□ Return window: Tính đúng số ngày (từ purchase_date, không phải delivery_date cho store)
□ After-deadline return: Blocked hoặc yêu cầu manager approval?
□ No-receipt return: Có flow lookup bằng phone/customer ID không? Approval gate?
□ Condition check: UI có bắt cashier confirm điều kiện sản phẩm không?
□ Refund method restriction:
   - Cash return chỉ cho giao dịch gốc là cash (không hoàn cash cho giao dịch card)
   - Giá trị return ≤ giá trị giao dịch gốc
□ Partial return: Return 1 trong nhiều items → tính refund đúng không? (có xét discount đã apply không?)
□ Loyalty points adjustment:
   - Full return: Thu hồi toàn bộ điểm đã tích
   - Partial return: Thu hồi proportional points
   - Đã redeem điểm: Xử lý thế nào? (hoàn điểm hay hoàn tiền?)
□ Exchange: Tính đúng difference (có thể charge thêm hoặc refund một phần)
□ Return fraud prevention: Flag nếu customer có return rate bất thường (> 3 returns/tháng)
```

### Bước 8: Cash Reconciliation Logic

```
□ Opening float: Yêu cầu nhập và validate trước khi mở ca
□ Expected closing calculation:
   Opening float + Cash sales - Cash refunds - Cash payouts = Expected
□ Cash payout tracking: Mỗi cash payout ra khỏi drawer có ghi nhận không? (ví dụ: trả tiền lẻ, tip)
□ Variance calculation: Actual - Expected = Variance (+ là over, - là short)
□ Variance thresholds: Enforce đúng rules (auto-approve, manager review, escalate)
□ Submission: Report chỉ submit được khi manager đã review/approve
□ Immutability: Cash reconciliation đã submit không thể edit (chỉ audit note)
□ Multi-terminal: Nếu store có nhiều terminals → tổng hợp đúng không?
□ Discrepancy investigation: Có workflow để ghi nhận investigation và kết quả không?
```

### Bước 9: Performance — Black Friday Load per Terminal

```
POS là critical path — performance failure = doanh thu mất trực tiếp.

TRANSACTION THROUGHPUT:
□ Target: 1 transaction checkout < 30s (P95) trong điều kiện peak load
□ Item lookup: barcode scan → price displayed < 200ms
□ Payment initiation: < 1s từ lúc bấm "Pay" đến EDC/QR ready
□ Receipt generation: < 2s sau payment confirm

PEAK LOAD TESTING:
□ Simulate peak: Black Friday = 3-5x normal transaction volume
□ Concurrent terminals: Tất cả terminals của 1 store active cùng lúc
□ DB query performance: Inventory lookup, price lookup có index phù hợp chưa?
□ N+1 queries: Checkout flow không có N+1 queries

OFFLINE PERFORMANCE:
□ Offline startup time: < 5s để switch sang offline mode
□ Local DB performance: Queries trên local cache không chậm hơn 2x so với online

SYNC PERFORMANCE:
□ Batch size: Sync 1000 offline transactions trong < 60s
□ Non-blocking: Sync chạy background, không ảnh hưởng ongoing sales
```

### Bước 10: Output — Review Report

```markdown
# Retail Implementation Review: [Module Name]

## Tổng kết: ✅ PASS / ❌ FAIL / ⚠️ CẦN XỬ LÝ

## Critical Issues (chặn go-live)
- [ ] [Issue]: [Vị trí trong code] → [Fix yêu cầu]

## Important Issues (fix trước sprint tiếp theo)
- [ ] [Issue]: [Vị trí] → [Khuyến nghị]

## Suggestions (cải thiện)
- [ ] [Gợi ý]

## Checklist Chi tiết

### Transaction Integrity
[Table: Item | Status | Notes]

### Offline Mode
[Table: Item | Status | Notes]

### Payment Processing
[Table: Item | Status | Notes]

### Inventory Deduction
[Table: Item | Status | Notes]

### Discount & Promotion
[Table: Item | Status | Notes]

### Return Policy
[Table: Item | Status | Notes]

### Cash Reconciliation
[Table: Item | Status | Notes]

### Performance
[Table: Metric | Measured | Target | Pass?]

## Sign-off
□ Transaction state machine integrity: OK / ISSUE
□ Offline mode reliability: OK / ISSUE
□ Payment accuracy (bao gồm PCI-DSS): OK / ISSUE
□ Inventory deduction correctness: OK / ISSUE
□ Discount stacking rules: OK / ISSUE
□ Return policy enforcement: OK / ISSUE
□ Cash reconciliation logic: OK / ISSUE
□ Performance targets: OK / ISSUE
```

---

## Checklist trước khi submit

```
□ Tất cả modules trong scope đã được review
□ Offline mode đã được test kỹ (đây là critical requirement)
□ PCI-DSS compliance đã check (không lưu card data)
□ Concurrent transaction scenarios đã được verify
□ Inventory deduction timing đã đúng (at completion, not at scan)
□ Discount stacking logic đã review kỹ
□ Return policy enforcement đã có approval gates đúng
□ Performance measurements đã được thực hiện
□ Output report có đủ evidence (code location references)
```
