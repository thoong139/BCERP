# Playbook: Review Real Estate Implementation

> **Type**: Agent Procedure
> **Agent**: real-estate-expert
> **Triggered by**: /wf-implement-feature review pass cho BĐS modules
> **Output**: Review report (inline hoặc .mc-data/work/wf-implement-feature/review-re-[module]-[date].md)

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-implement-feature` phase review
- Khi code BĐS modules đã được implement và cần verify trước khi mark done
- Khi cần đảm bảo implementation đúng business logic, compliance, và controls

---

## Procedure

### Bước 1: Xác định scope review

```
INPUT: Module được implement, feature spec, REQ-ID liên quan

Đọc:
□ Feature spec: .mc-data/docs/phase2-features/[sys]/[mod]/[feat].md
□ Task file: .mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md
□ REQ-IDs từ task file → đọc requirements gốc
□ Design doc (nếu có): .mc-data/docs/phase3-architecture/real-estate/

Xác định module loại gì:
□ Inventory / Booking (giỏ hàng)
□ Payment Schedule (tiến độ thu tiền)
□ Legal Workflow (HĐMB, sổ đỏ)
□ Property Management (lease, maintenance)
□ Commission (hoa hồng broker)
□ Financial (escrow, revenue recognition)
```

### Bước 2: Review theo Checklist

---

#### Category 1 — Pháp lý & Compliance

- [ ] **AML check hook active** cho giao dịch > ngưỡng (300 triệu VND tiền mặt)
  - Verify: Function/middleware AML check có được gọi trước khi confirm giao dịch không?
  - Verify: Giao dịch đủ điều kiện có được flag/report không?

- [ ] **KYC data fields đầy đủ**
  - Verify: Entity Buyer/Customer có CCCD, nguồn thu nhập, beneficial_owner fields
  - Verify: Không thể proceed booking nếu KYC chưa completed

- [ ] **Luật KDBĐS 2023 workflow compliance**
  - Verify: Bảo lãnh ngân hàng được check trước khi mở bán (bank_guarantee_status)
  - Verify: Điều kiện mở bán (giấy phép, 1/500 approved) có được gate không?

- [ ] **STR capability**
  - Verify: Có mechanism để flag suspicious transactions không?
  - Verify: Report generation cho STR (ngay cả khi còn manual trigger)

---

#### Category 2 — Tài chính & Escrow

- [ ] **Escrow account tách biệt**
  - Verify: Payment flow ghi tiền vào escrow account (không phải operating)
  - Verify: Không có direct transfer từ customer payment sang operating expenses

- [ ] **Release conditions được enforce**
  - Verify: Release escrow chỉ được trigger khi milestone confirmed (không auto)
  - Verify: Milestone confirmation có approval workflow không?

- [ ] **Revenue recognition logic đúng**
  - Verify: Tiền đặt cọc được ghi là "deposit_received" (liability), không phải revenue
  - Verify: Revenue chỉ được ghi nhận khi có handover_confirmed = true
  - Verify: Report tài chính phân biệt rõ Cash Collected vs Revenue Recognized

- [ ] **Installment schedule calculation chính xác**
  - Test: Tạo installment từ policy template → Verify tổng % = 100%
  - Test: Verify dates tính đúng từ event triggers
  - Test: Late fee calculation (amount × rate × overdue_days)

---

#### Category 3 — Inventory & Booking

- [ ] **Hold timer chạy đúng, auto-release sau timeout**
  - Test: Create hold → wait for expiry → verify unit status = available
  - Test: Broker receives notification khi hold expired
  - Verify: Cron job / background task cho auto-release hoạt động

- [ ] **Concurrent booking conflict prevention**
  - Test: Simulate 2 requests đồng thời hold cùng 1 unit
  - Verify: Chỉ 1 request succeed, 1 nhận error ngay
  - Verify: Database transaction / optimistic locking implemented

- [ ] **Real-time inventory sync**
  - Test: Broker A hold unit → Broker B refresh → unit hiển thị "held" ngay
  - Verify: WebSocket / SSE / short polling interval đủ responsive

- [ ] **Status machine transitions đúng**
  - Test: Các transition hợp lệ: Available→Held, Held→Reserved, Reserved→Sold
  - Test: Các transition không hợp lệ bị block: Available→Sold (không qua Held)
  - Verify: Không có orphan states (held units không có hold record)

---

#### Category 4 — Commission & Hoa hồng

- [ ] **Commission calculation khớp policy**
  - Test: Tính commission với policy template → Verify = gtch × rate
  - Test: Thay đổi GTCH (discount) không ảnh hưởng base commission (tính theo giá gốc)
  - Verify: Policy lookup đúng theo project + batch

- [ ] **Dual control workflow implemented**
  - Verify: Status machine: Calculated → Pending Verification → Verified → Approved → Paid
  - Verify: KD team không thể self-approve
  - Verify: Kế toán không thể skip verification step

- [ ] **Clawback conditions tracked và auto-adjust**
  - Test: Cancel HĐMB trong clawback period → commission bị flagged
  - Test: Clawback deducted từ next payment batch (không yêu cầu cash return)
  - Verify: Clawback history log với reasons

- [ ] **Payment chỉ sau deposit cleared**
  - Verify: Commission status không thể move sang Approved nếu deposit_cleared = false
  - Test: Payment timing logic đúng (KH phải đóng đủ threshold trước)

---

#### Category 5 — Data Security & Privacy

- [ ] **KH financial data encrypted at rest**
  - Verify: Fields nhạy cảm (CCCD, tài khoản NH, income) được encrypted
  - Verify: Encryption key management (không hardcode key trong code)

- [ ] **Document access logged**
  - Verify: Mọi download HĐMB, sổ đỏ scan được ghi vào access_log
  - Verify: Log có: user_id, document_id, action (view/download), timestamp, IP

- [ ] **Legal documents không thể delete**
  - Test: Attempt delete HĐMB → phải fail với error message
  - Verify: Chỉ có archive action (với approval), không có hard delete
  - Verify: Archive requires reason + admin approval

- [ ] **Audit trail đầy đủ cho tất cả status changes**
  - Verify: Mọi status change có audit record: who, when, from_status, to_status, reason
  - Verify: Audit trail không thể bị sửa/xóa (immutable log)

---

### Bước 3: Edge Cases và Performance

```
Edge cases quan trọng cần test:

Booking / Hold:
□ Unit bị hold → Hệ thống restart → Hold vẫn active và timer tiếp tục đúng
□ KH chuyển khoản sai số tiền → System xử lý thế nào?
□ KH chuyển khoản đúng nhưng nội dung CK sai → Matching fail → Xử lý thế nào?
□ Broker A đang hold → Broker A bị deactivate → Unit tự release không?

Payment:
□ KH đóng 2 đợt cùng ngày → System record đúng cả 2 không?
□ KH refund yêu cầu → Reverse entries đúng chưa?
□ Currency edge case nếu có FDI buyer (USD → VND)

Legal:
□ HĐMB đã ký → KH yêu cầu thay đổi thông tin → Version control đúng chưa?
□ Beneficial owner thay đổi sau khi ký → Có alert / workflow xử lý không?

Performance:
□ Floor plan grid với 500+ units → Load time acceptable?
□ Real-time sync với 100 concurrent brokers → Không có race conditions?
□ Month-end invoice generation cho 1000+ tenants → Batch job timeout?
```

### Bước 4: Output Review Report

```
Format report:

## Review Result: [Module Name] — [PASS / FAIL / NEEDS WORK]

### Summary
[2-3 dòng tóm tắt]

### Passed Checks
- [Danh sách checks đã pass]

### Failed Checks (nếu có)
- [CHECK NAME]: [Mô tả lỗi cụ thể]
  - File: [path:line]
  - Expected: [behavior đúng]
  - Found: [behavior thực tế]
  - Fix: [đề xuất sửa]

### Risk Flags
- [Các vấn đề không fail nhưng cần chú ý]

### REQ Coverage
- [REQ-IDs covered]: [list]
- [REQ-IDs không covered]: [list nếu có]

### Recommendation
[ ] APPROVE — Implementation đạt chuẩn
[ ] APPROVE WITH CONDITIONS — [list conditions]
[ ] REJECT — [list blocking issues]
```
