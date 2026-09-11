# Playbook: Design Supply Chain Module

> **Type**: Agent Skill Playbook
> **Agent**: operations-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi có Supply Chain / Procurement module
> **Output**: Feature spec supply chain module tại phase2-features/ hoặc phase3-architecture/

---

## Khi nào dùng playbook này

- Khi cần spec module "Quản lý Chuỗi Cung Ứng", "Mua Hàng", hoặc "Supply Chain Management"
- Khi cần thiết kế procurement workflow (PR → PO → GRN → Invoice → Payment)
- Khi cần thiết kế vendor management, demand forecasting, hoặc S&OP

---

## Procedure

### Bước 1: Xác định scope SCM

```
Đọc requirements đã có tại phase1-business/operations-requirements.md

Hỏi hoặc suy luận từ context:
□ Supplier portal cần không? (Vendors tự nhập ASN, invoice)
□ 3-way matching automation mức nào? (PO / GRN / Invoice)
□ Demand forecasting: Cần dự báo không? Horizon bao xa?
□ Multi-currency: Có mua hàng ngoại tệ không?
□ Blanket PO / Long-term agreement có không?
□ Drop-ship: Vendor giao thẳng đến customer không?
□ Số lượng vendors: Bao nhiêu? AVL (Approved Vendor List) cần quản lý?
```

### Bước 2: Thiết kế Supplier Management

```
READ: personas.md → Persona 5: Procurement Specialist

Approved Vendor List (AVL):
□ Vendor Master: code, name, tax_id, payment_terms, currency, lead_time_days
□ Contact management: email, phone, address (billing + shipping)
□ Bank account (cho payment)
□ Vendor Category (raw material, packaging, services...)
□ AVL Status: Approved | Conditional | Blocked | Blacklisted
□ Blocking reason (nếu blocked) + review date

Vendor Performance Scorecard:
□ On-time Delivery Rate = Deliveries on time / Total deliveries
□ Quality Acceptance Rate = Accepted qty / Total received qty
□ Price Accuracy = POs with correct price / Total POs
□ Invoice Accuracy = Correct invoices / Total invoices
□ Response Time = Avg hours from PO to acknowledgment
□ Composite score = Weighted average (configurable weights)
□ Score band: Excellent (>90) / Good (75-90) / Marginal (60-75) / Poor (<60)

Tần suất đánh giá:
□ Tự động update score sau mỗi GRN và Invoice match
□ Monthly vendor report card tự động gửi email
□ Annual formal review → update AVL status
```

### Bước 3: Thiết kế Purchase Requisition Workflow

```
READ: controls.md → Section 5: Purchase Requisition Approval

States:
Draft → Submitted → Department Approved → Procurement Review → Approved → Converted to PO | Rejected

Data model PR:
  - pr_id, pr_number, pr_date, requested_by, department_id
  - needed_by_date, priority (Urgent / Normal / Low)
  - status, rejection_reason
  - Lines: item_id, qty, uom, estimated_unit_price, total_estimated
  - total_value (sum of lines)
  - approved_by, approved_at (per approval level)

Approval routing (theo controls.md):
□ ≤20M VND → Department Manager approve
□ 20-100M VND → Department Manager + Procurement Manager approve
□ 100-500M VND → thêm Operations Director approve
□ >500M VND → thêm Finance Director approve
□ Mỗi level có deadline SLA (default 24h), escalate nếu không action
□ Người approve có thể comment và request thêm thông tin
□ Rejection → PR về Draft với reason, requester nhận notification
```

### Bước 4: Thiết kế Purchase Order Workflow

```
States:
Draft → Sent to Vendor → Acknowledged → Partially Received → Fully Received | Cancelled

Data model PO:
  - po_id, po_number, po_date, vendor_id
  - currency, exchange_rate (nếu foreign currency)
  - payment_terms, delivery_terms (Incoterms)
  - delivery_address, expected_delivery_date
  - status, pr_ref_ids (linked PRs)
  - Lines: item_id, qty_ordered, qty_received, unit_price, discount%, tax%, total
  - total_amount, approved_by

Tạo PO:
□ Từ PR đã approved → Convert to PO (chọn vendor từ AVL)
□ Từ MRP suggestion → Bulk convert với vendor assignment
□ Emergency PO trực tiếp (cần approval riêng)
□ Auto-fill lead_time từ Vendor Master
□ Price check: So sánh với last purchase price, alert nếu deviation >10%

Gửi PO cho vendor:
□ Email PDF tự động khi PO status = Sent
□ Vendor Portal: Vendor login xem PO và confirm delivery schedule
□ Vendor Acknowledgment → cập nhật PO status
□ PO Amendment: Khi thay đổi qty/price → tạo PO Amendment, vendor reconfirm
```

### Bước 5: Thiết kế Goods Receipt và 3-Way Matching

```
READ: operations.md → Process 1: Goods Receipt (GRN)
READ: controls.md → Quick Reference: Before GRN Posting

3-Way Matching logic:
  PO (what was ordered) ↔ GRN (what was received) ↔ Invoice (what was billed)

GRN vs PO matching:
□ Qty received vs Qty ordered → Variance %
□ Under-delivery: Partial receipt → Open PO qty giảm tương ứng
□ Over-delivery: Alert nếu vượt PO qty + allowed tolerance (default 5%)
□ Price discrepancy: GRN dùng PO price → Không cho sửa unit price tại GRN

Invoice matching:
□ Nhập Vendor Invoice → System tự động match với GRN(s) liên quan
□ 3-way match check:
  - Invoice qty ≤ GRN qty
  - Invoice price = PO price (hoặc trong tolerance)
  - Invoice total = matched GRN value
□ Match result:
  - Full match → Auto-approve invoice → Forward to Finance for payment
  - Partial match → Highlight discrepancy → Procurement review
  - Price mismatch → Hold → Procurement negotiate với vendor
□ Credit note: Khi reject hàng sau khi invoice đã nhận → Tạo Credit Note

Ghi nhận tại Bước 5: Huy động finance-expert nếu cần spec GL posting rules chi tiết.
```

### Bước 6: Thiết kế Supplier Portal

```
Chức năng cho Vendor (nếu scope yêu cầu):
□ Login với credentials riêng (không access nội bộ)
□ Xem POs gửi đến → Confirm/Decline từng PO
□ Cập nhật Expected Delivery Date khi delay
□ Tạo ASN (Advanced Shipment Notice) trước khi giao hàng
□ Nhập Invoice online → Auto-match với GRN
□ Xem payment status của invoices đã submit
□ Xem Vendor Scorecard của mình

Quyền Vendor Portal (restricted):
□ Chỉ xem POs của vendor mình
□ Không xem pricing của vendor khác
□ Không xem thông tin nội bộ (approval history, nhận xét)
□ Session timeout sau 30 phút idle
```

### Bước 7: Thiết kế Demand Forecasting (nếu trong scope)

```
Nếu project yêu cầu demand forecasting:

Input data:
□ Lịch sử bán hàng (24+ tháng để detect seasonality)
□ Sales Orders đã confirmed nhưng chưa fulfilled
□ Seasonal adjustments (calendar events, promotions)

Forecasting methods (tự động chọn hoặc config per item):
□ Moving Average: Đơn giản, C items
□ Exponential Smoothing (Holt-Winters): Có trend + seasonality, B items
□ MRP net change: Driven by SO/WO, A items

Output:
□ Demand forecast theo tuần/tháng (horizon 3-12 tháng)
□ Suggested Purchase Plan = Demand Forecast - On-hand - On-order
□ S&OP Review: Bảng so sánh Forecast vs Actual theo tháng
□ Forecast accuracy metric: MAPE (Mean Absolute Percentage Error)
□ Override: Planner có thể manual adjust forecast

Ghi nhận: Forecast phức tạp (ML-based) cần huy động data-expert.
```

### Bước 8: Thiết kế Lead Time Management

```
Lead Time tracking per vendor per item:
□ Standard Lead Time: Từ Vendor Master
□ Actual Lead Time: Tính từ PO date đến GRN date
□ Rolling Average LT: Average của 6 GRNs gần nhất
□ Alert: Khi Actual LT > Standard LT × 1.2 → Flag vendor performance

Lead Time ảnh hưởng đến:
□ ROP calculation (Bước 3 của design-inventory-management.md)
□ PO expected delivery date suggestion
□ MRP planning horizon

Early/Late delivery tracking:
□ Early: Received trước expected date (có thể gây storage issue)
□ On-time: Trong ±2 ngày
□ Late: Sau expected date → Tác động đến vendor score
□ Report: Delivery Performance by Vendor theo tháng
```

### Bước 9: Thiết kế Supply Chain Visibility Dashboard

```
READ: operations.md → Section 4: Decision Support Requirements, Section 6: KPIs

Dashboard 1 — Procurement Overview (Procurement Manager):
□ PRs Pending Approval (by level, by aging)
□ POs Outstanding (by vendor, by expected delivery)
□ Overdue Deliveries (POs past expected date)
□ 3-Way Match exceptions (invoices on hold)
□ PO value by period (spend trend)

Dashboard 2 — Supply Chain Health (Operations Director):
□ Vendor Performance Heatmap (score matrix)
□ Spend by Category (Pareto chart)
□ On-time Delivery Rate trend
□ Invoice Cycle Time (PO → Invoice → Payment)
□ Fill Rate impact from supply delays

Alerts:
□ PR chờ approve > SLA (24h) → Escalate
□ PO delivery overdue > 3 ngày → Alert Procurement
□ Vendor score drop below 60 → Alert Manager, review AVL
□ Invoice match fail → Alert Procurement trong 24h
```

### Bước 10: Feature Spec Output

```markdown
# Feature Spec: Supply Chain Management

## Overview
[Mô tả module, scope, integration points]

## User Stories
- As a Procurement Specialist, I want to...
- As a Vendor, I want to...

## Functional Requirements
REQ-OPS-SCM-001: Vendor Master với AVL status và performance tracking
REQ-OPS-SCM-002: Purchase Requisition với multi-level approval workflow
REQ-OPS-SCM-003: Purchase Order với vendor acknowledgment
REQ-OPS-SCM-004: Goods Receipt linked to PO với over-delivery control
REQ-OPS-SCM-005: 3-Way Matching (PO / GRN / Invoice)
REQ-OPS-SCM-006: Vendor Scorecard tự động cập nhật
REQ-OPS-SCM-007: Supplier Portal (nếu in scope)
REQ-OPS-SCM-008: Demand Forecasting và Suggested Purchase Plan (nếu in scope)
REQ-OPS-SCM-009: Lead Time tracking và alert
REQ-OPS-SCM-010: Supply Chain Visibility Dashboard

## Data Model
[ERD hoặc field definitions từ các bước trên]

## Integration Points
- Inventory Module: GRN → cập nhật inventory balance
- Finance Module: Approved invoice → AP entry; PO → budget commitment
- Sales Module: SO → trigger demand; Delivery → trigger GI

## Non-functional Requirements
- Performance: PO List page < 1s (với 10k+ POs)
- Data integrity: 3-way matching không được có false matches
- Security: Vendor Portal chỉ access data của vendor mình
- Audit: Mọi PO/PR thay đổi phải có full change history
```

---

## Checklist trước khi submit

```
□ Approval thresholds nhất quán với controls.md
□ 3-way matching logic được spec đầy đủ (full match / partial / exception)
□ Vendor Portal security được addressed nếu in scope
□ Lead time tracking và impact trên ROP được documented
□ Integration với Finance (invoice → AP) đã được noted → huy động finance-expert nếu cần
□ Vendor Scorecard formula được document với weights rõ ràng
□ All REQ-IDs theo format REQ-OPS-SCM-[NNN]
```
