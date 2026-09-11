# Playbook: Design Purchase Request & Purchase Order Module

> **Type**: Agent Skill Playbook
> **Agent**: procurement-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần design PR/PO module
> **Output**: Feature spec cho Purchase Request và Purchase Order module

---

## Khi nào dùng playbook này

- Khi cần spec module "Purchase Order" / "Quản lý Đặt hàng" / "Procure-to-Pay"
- Khi cần thiết kế PR approval routing, RFQ process, PO lifecycle, 3-way matching
- Khi review/audit hệ thống PO hiện có

---

## Procedure

### Bước 1: Xác định scope

```
Hỏi hoặc suy luận từ context:
□ Có catalog mua hàng không? (items định sẵn vs. free-text PR)
□ Approval routing: Chỉ theo amount hay cả category-based?
□ RFQ process: Cần không? Tối thiểu bao nhiêu quotes?
□ PO gửi cho vendor qua kênh nào? (Email / EDI / Vendor Portal)
□ Goods Receipt: Ai thực hiện? (Warehouse / Requester / Procurement?)
□ 3-way matching: Auto hay manual? Tolerance bao nhiêu %?
□ Change Order: Có cần không? (thay đổi PO sau khi đã gửi vendor)
□ Blanket PO: Có cần không? (PO khung cho nhiều delivery trong kỳ)
```

### Bước 2: Thiết kế Purchase Request (PR) Creation

```
READ: processes.md → PR-to-PO Flow (Process 1)
READ: personas.md → Requisitioner, Buyer personas

PR creation fields:
□ Item description (free-text hoặc từ catalog)
□ Quantity + Unit of Measure
□ Target delivery date
□ Estimated unit price (optional nhưng giúp budget check)
□ Budget / Cost center allocation
□ Preferred vendor (optional — buyer sẽ validate)
□ Justification / Business reason
□ Attach supporting documents (e.g., specs, quotations đã có sẵn)

Catalog integration:
- Nếu có catalog → typeahead search item
- System auto-populate: Unit price (last purchase price), preferred vendor
- Non-catalog PR: Require justification field bắt buộc

Guided wizard cho Requisitioner:
□ Step 1: Chọn category (giúp routing đúng)
□ Step 2: Chọn từ catalog hoặc mô tả item
□ Step 3: Số lượng + ngày cần
□ Step 4: Budget allocation
□ Step 5: Review + Submit

Budget pre-check khi submit PR:
- Check available budget của cost center
- Warn nếu < 20% budget còn lại
- Block nếu budget đã hết (yêu cầu budget amendment trước)
```

### Bước 3: Thiết kế PR Approval Routing

```
READ: controls.md → Authorization Matrix + Approval Limits Detail

Amount-based routing (ví dụ mặc định — cấu hình được):
< $1,000      → Auto-approve (nếu trong budget)
$1,001–$10,000  → Department Manager (1 ngày)
$10,001–$50,000 → Dept Manager + Procurement Officer (2 ngày)
$50,001–$200,000 → + Procurement Manager (3 ngày)
> $200,000    → + Finance Director + CFO (5 ngày)

Category-based routing (thêm vào amount-based):
- IT equipment → IT Manager approval bắt buộc
- Marketing spend → Marketing Director approval
- Legal services → Legal approval

Approval workflow engine:
□ Sequential hoặc parallel approval (configurable per threshold level)
□ Escalation: Nếu approver không phản hồi trong SLA → auto-escalate to supervisor
□ Delegate: Approver có thể delegate khi nghỉ phép (với date range)
□ Comment/Reject reason: Bắt buộc khi reject
□ Recall: Requester có thể recall PR chưa được approve
□ Notification: Email + in-app notification tại mỗi step

Exception routing:
□ Sole-source (chỉ có 1 vendor) → thêm Procurement Manager + Dept VP sign-off
□ Emergency → verbal approval first, retroactive trong 24h
□ Capital Expense → route sang CapEx approval process riêng
```

### Bước 4: Thiết kế RFQ (Request for Quotation) Process

```
READ: processes.md → RFQ Process (Process 2)

Khi nào trigger RFQ:
- PR được approve + giá trị vượt threshold "Three-quotes rule" (configurable)
- Không có preferred vendor hoặc buyer muốn cạnh tranh giá

RFQ workflow:
1. Buyer tạo RFQ từ approved PR (auto-populate item, qty, delivery date)
2. Buyer chọn vendors từ AVL (tối thiểu 3 vendors theo 3-quotes rule)
3. System gửi RFQ tới vendors (email + vendor portal notification)
4. Vendors submit quotes qua portal (hoặc buyer nhập manual nếu vendor không có portal)
5. System tổng hợp quotes → Quote Comparison Matrix tự động
6. Buyer/Procurement Manager review comparison → chọn vendor
7. Nếu chọn vendor không phải lowest price → require justification

Quote Comparison Matrix (auto-generate):
| Tiêu chí | Trọng số | Vendor A | Vendor B | Vendor C |
|----------|----------|----------|----------|----------|
| Đơn giá | 40% | ... | ... | ... |
| Lead time | 25% | ... | ... | ... |
| Quality score | 20% | ... | ... | ... |
| Payment terms | 15% | ... | ... | ... |
| **Tổng điểm** | 100% | ... | ... | ... |

RFQ deadline management:
□ Buyer đặt deadline cho vendors respond
□ Auto-reminder tới vendors 48h trước deadline
□ Sau deadline: auto-close RFQ (vendors không thể submit thêm)
□ Nếu < 3 vendors respond → alert buyer; có thể extend deadline hoặc add more vendors
```

### Bước 5: Thiết kế Purchase Order Generation

```
READ: processes.md → PR-to-PO Flow (Process 1) — phần Create PO
READ: controls.md → Authorization Matrix (PO approval thresholds)

PO generation từ PR (sau khi vendor được chọn):
□ Auto-populate từ PR: items, quantities, delivery address, cost center
□ Auto-populate từ vendor: payment terms, bank details
□ Buyer confirm/adjust: unit price (từ quote), delivery date
□ System generate PO number (sequential, unique, có year prefix)

PO approval (riêng với PR approval):
< $5,000      → Auto-approve
$5,001–$50,000  → Procurement Officer
$50,001–$200,000 → Procurement Manager
> $200,000    → Finance Director (CEO nếu > $500K)

PO state machine:
Draft → Pending Approval → Approved → Sent → Acknowledged → Partially Received
     → Fully Received → Invoiced → Matched → Closed
     → Cancelled (trước khi Sent)

PO sending channels:
□ Email (PDF attachment) — default
□ Vendor Portal (in-app notification + PDF)
□ EDI (nếu vendor support — enterprise feature)

PO Acknowledgment:
□ Vendor confirm nhận PO + xác nhận delivery date
□ Nếu vendor không confirm trong 2 ngày → alert buyer
□ Vendor có thể request change (delivery date, partial delivery) → buyer review
```

### Bước 6: Thiết kế Change Order Management

```
Change Order (CO) được tạo khi cần sửa PO đã gửi cho vendor:

Tình huống cần CO:
- Thay đổi quantity
- Thay đổi delivery date
- Thêm item vào PO
- Thay đổi giá (sau negotiation)
- Thay đổi delivery address

CO workflow:
1. Buyer tạo CO → ghi rõ lý do thay đổi
2. CO approval: Theo PO approval thresholds (re-approve nếu giá trị tăng thêm)
3. Approved CO → system gửi CO notification tới vendor
4. Vendor acknowledge CO
5. CO version history được lưu đầy đủ (PO v1, v2, v3...)

Business rules:
□ Không được CO sau khi PO đã Fully Received
□ CO giảm quantity: Phải check hàng chưa nhận; tự động điều chỉnh PO balance
□ CO tăng giá trị: Cần re-approve theo threshold mới
```

### Bước 7: Thiết kế Goods Receipt và 3-Way Matching

```
READ: controls.md → Three-Way Matching Process + Tolerance Matrix

Goods Receipt Note (GRN) creation:
□ Warehouse/Receiver tạo GRN khi nhận hàng
□ Link GRN với PO (scan PO number hoặc chọn từ list)
□ Nhập: Quantity received, condition, date received
□ Note discrepancies (hàng hỏng, sai specs, thiếu số lượng)
□ GRN không thể tạo nếu PO không ở trạng thái "Sent" hoặc "Acknowledged"

SoD enforcement:
□ Người tạo PR ≠ người tạo GRN (system enforce)
□ Warehouse role: chỉ được tạo GRN, không được tạo PO

3-Way Matching logic:
PO (qty + price) ↔ GRN (qty received) ↔ Invoice (qty + price billed)

Tolerance rules (configurable):
| Sai lệch | Tolerance | Hành động |
|----------|-----------|-----------|
| Qty variance ≤ 2% | Auto-approve | Ghi nhận variance |
| Price variance ≤ 1% | Auto-approve | Ghi nhận variance |
| Qty variance 2–5% | Cần Finance review | Hold invoice |
| Price variance 1–5% | Cần Procurement review | Hold invoice |
| Variance > 5% | Full investigation | Hold; notify cả 2 bên |
| Invoice không có PO | Tự động reject | Yêu cầu tạo PO trước |

PO Closure:
□ Fully Received + Matched → auto-close PO
□ Partially received sau 30 ngày kể từ delivery date → alert, buyer quyết định close/extend
□ Cancelled PO: Ghi rõ reason, notify vendor, rollback budget reservation
```

### Bước 8: Feature Spec Output

```markdown
# Feature Spec: Purchase Request & Purchase Order Management

## Overview
[Mô tả module PR-to-PO end-to-end]

## User Stories
- As a Requisitioner, I want to create a purchase request easily...
- As a Department Manager, I want to approve PRs on mobile...
- As a Buyer, I want to compare quotes in one screen...
- As a Vendor, I want to acknowledge POs via portal...

## Functional Requirements

### REQ-PROC-PR-001: Purchase Requisition Creation với Catalog
### REQ-PROC-PR-002: PR Approval Routing (Amount + Category based)
### REQ-PROC-PR-003: Budget Check tại điểm tạo PR
### REQ-PROC-RFQ-001: RFQ Creation và Distribution
### REQ-PROC-RFQ-002: Quote Comparison Matrix tự động
### REQ-PROC-RFQ-003: Three-quotes Rule Enforcement
### REQ-PROC-PO-001: PO Generation từ Approved PR
### REQ-PROC-PO-002: PO Approval Workflow
### REQ-PROC-PO-003: PO Sending (Email / Portal / EDI)
### REQ-PROC-PO-004: Change Order Management
### REQ-PROC-GRN-001: Goods Receipt Note Creation
### REQ-PROC-INV-001: 3-Way Matching với Configurable Tolerances
### REQ-PROC-PO-005: PO Closure và Budget Reconciliation

## Data Model
[PurchaseRequisition, PurchaseOrder, ChangeOrder, GoodsReceiptNote,
 RFQ, Quote, InvoiceMatch entities]

## State Machines
[PR states, PO states — diagram]

## Non-functional Requirements
- PR creation: < 3 phút với guided wizard
- PO search: < 2s response time
- 3-way matching batch: Process 10,000 invoices/giờ
- Audit log: Mọi state transition đều có timestamp + actor
```

---

## Checklist trước khi submit

```
□ PR fields đủ để Buyer xử lý mà không cần hỏi thêm
□ Approval routing matrix đầy đủ (amount + category)
□ Exception paths đã thiết kế (sole-source, emergency)
□ RFQ: Minimum 3 vendors enforced (với override mechanism)
□ PO state machine đầy đủ (không có dead-end state)
□ Change Order workflow có versioning
□ GRN: SoD enforcement — creator ≠ PO creator
□ 3-way matching tolerance matrix configurable
□ PO closure logic cho partially-received POs
```
