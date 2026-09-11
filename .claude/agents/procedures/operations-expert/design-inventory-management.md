# Playbook: Design Inventory Management Module

> **Type**: Agent Skill Playbook
> **Agent**: operations-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi có Inventory module
> **Output**: Feature spec inventory module tại phase2-features/ hoặc phase3-architecture/

---

## Khi nào dùng playbook này

- Khi cần spec module "Quản lý Tồn kho" hoặc "Inventory Management"
- Khi cần thiết kế data model cho inventory
- Khi review/audit hệ thống inventory hiện có

---

## Procedure

### Bước 1: Xác định scope và đặc thù inventory

```
Đọc requirements đã có tại phase1-business/operations-requirements.md
Hỏi hoặc suy luận từ context:

□ Multi-location: Bao nhiêu kho/locations? Có inter-warehouse transfer không?
□ Lot tracking: Có cần track lô sản xuất/nhập khẩu không?
□ Serial number tracking: Có SKU nào cần track từng unit không?
□ Expiry date: Có hàng có hạn sử dụng không? → Cần FEFO (First Expire First Out)
□ Unit of Measure: Có UOM conversion không? (hộp/cái, thùng/lít...)
□ Costing method: FIFO / Average / Standard (đã xác định ở phase1)
□ Barcode/RFID: Scanning required hay manual entry?
```

### Bước 2: Thiết kế Inventory Model

```
READ: operations.md → Section 1 (Value Chain), Section 2 (Core Processes)

Data model cốt lõi:

Item Master:
  - item_code, item_name, item_category, item_type (stock / non-stock / service)
  - uom_base, uom_conversions (JSON)
  - track_lot: boolean
  - track_serial: boolean
  - has_expiry: boolean
  - costing_method: FIFO | Average | Standard
  - reorder_point, reorder_qty, min_qty, max_qty
  - abc_class: A | B | C
  - storage_requirements (temp, hazmat, etc.)
  - is_active: boolean

Location Master:
  - location_code, location_name, warehouse_id
  - location_type: Receiving | Bulk | Pick | Packing | Shipping | Quarantine
  - zone, aisle, rack, bin
  - capacity_weight, capacity_volume
  - is_active: boolean

Inventory Balance:
  - item_id, location_id, lot_id (nullable), serial_id (nullable)
  - qty_on_hand, qty_reserved, qty_available (= on_hand - reserved)
  - unit_cost (FIFO layer cost hoặc average cost)
  - last_counted_date, last_movement_date

Lot Master (nếu lot tracking):
  - lot_id, item_id, lot_number
  - manufacture_date, expiry_date
  - supplier_lot_ref
  - qty_received, qty_remaining

Inventory Transaction:
  - txn_id, txn_type (GRN | GI | Transfer | Adjustment | Count)
  - txn_date, posting_date
  - item_id, location_from_id, location_to_id
  - lot_id, serial_id
  - qty, unit_cost, total_cost
  - reference_type, reference_id (PO, SO, WO, etc.)
  - created_by, approved_by, status
```

### Bước 3: Thiết kế Reorder Point Calculation

```
READ: operations.md → Quick Reference: Reorder Point Formula
READ: controls.md → Section 4: ABC Classification Controls

Công thức ROP:
ROP = (Average Daily Usage × Lead Time) + Safety Stock
Safety Stock = Z-score × Std Dev × √Lead Time

Hệ thống phải:
□ Tự động tính Average Daily Usage từ lịch sử giao dịch (rolling 90 ngày)
□ Tự động tính Std Dev của demand
□ Cho phép config Service Level per item (90% / 95% / 99%)
□ Tự động điều chỉnh ROP khi lead time thay đổi
□ Alert khi stock ≤ ROP → Auto-generate Purchase Requisition (nếu configured)
□ Dashboard "Items Below ROP" với priority ranking
```

### Bước 4: Thiết kế Replenishment Methods

```
Hỗ trợ ít nhất 2 phương pháp, configure per item:

Method 1 — Min/Max:
  - Khi stock < Min → order lên Max
  - Phù hợp: C items, simple operations
  - Thông số: min_qty, max_qty (configure trên Item Master)

Method 2 — EOQ (Economic Order Quantity):
  - EOQ = √(2DS/H) với D=demand/năm, S=ordering cost, H=holding cost
  - Phù hợp: B items, moderate value
  - Tự động tính và đề xuất order qty

Method 3 — MRP-driven:
  - Driven by Sales Orders hoặc Production Orders
  - Net Requirement = Gross Requirement - On-hand - On-order
  - Phù hợp: A items, manufacturing, make-to-order
  - Cần integration với Sales Module và Production Module

Config per item:
  - replenishment_method: MinMax | EOQ | MRP
  - preferred_vendor_id
  - standard_lead_time_days
  - order_multiple (pack size constraint)
```

### Bước 5: Thiết kế Goods Receipt (GRN) Workflow

```
READ: operations.md → Process 1: Goods Receipt (GRN)
READ: controls.md → Quick Reference: Before GRN Posting

States:
Draft → QC Hold (if required) → Approved → Posted

Workflow:
1. Nhận hàng → Tạo GRN draft (reference PO nếu có)
2. Nhập quantity từng dòng (bằng tay hoặc scan barcode)
3. Nếu item requires_qc = true → Status = "QC Hold", notify QC Inspector
4. QC Inspector inspect → Pass → Status = "Approved" | Fail → Reject với lý do
5. Warehouse Manager review → Post GRN → Cập nhật inventory balance
6. System tự động tính cost: FIFO layer mới hoặc recalc average cost

Validation bắt buộc:
□ PO phải tồn tại và status = Approved (nếu GRN linked to PO)
□ Qty nhận ≤ Qty còn lại trên PO (hoặc flag Over-receipt)
□ Location phải tồn tại và active
□ Lot number bắt buộc nếu item.track_lot = true
□ Expiry date bắt buộc nếu item.has_expiry = true
```

### Bước 6: Thiết kế Goods Issue (GI) Workflow

```
READ: operations.md → Process 2: Goods Issue (GI)
READ: controls.md → Section 2: Negative Stock Prevention + Quick Reference

States:
Draft → Pick List Generated → Picked → Packed → Shipped → Posted

Allocation logic:
□ Khi GI created → Reserve (allocate) stock ngay
□ FIFO: Lấy từ lot cũ nhất trước
□ FEFO: Lấy từ lot hết hạn sớm nhất (nếu has_expiry = true)
□ Nếu stock không đủ → Block, hiển thị qty available, suggested alternatives

Negative stock prevention:
□ System KHÔNG cho phép post GI nếu qty_available < qty_required
□ Exception: Manager override với reason code (chỉ khi configured)
□ Mọi override phải được log với user, timestamp, reason
```

### Bước 7: Stock Adjustment và Cycle Count

```
READ: controls.md → Section 1 (Authorization Matrix), Section 5 (Approval Workflows)
READ: operations.md → Process 3: Stock Taking

Adjustment Types:
- Positive adjustment (thêm stock)
- Negative adjustment (giảm stock)
- Location transfer
- Lot/Serial correction

Authorization:
□ Variance ≤5% → Inventory Clerk tự approve
□ Variance 5-10% → Warehouse Manager approve
□ Variance >10% → Director approve, nếu >50M VND → Finance approve thêm
□ Write-off → Finance approval bắt buộc (mọi giá trị)

Cycle Count:
□ Hệ thống tự động generate Cycle Count schedule theo ABC class
□ A items: Weekly counting
□ B items: Monthly counting
□ C items: Quarterly counting
□ Cho phép tạo ad-hoc count request
□ Freeze transactions trong scope count (hoặc allow concurrent với blind count)
□ System qty vs counted qty → Variance report → Investigation → Adjustment
```

### Bước 8: Inventory Valuation

```
READ: controls.md → Section 3: Valuation Method Controls

FIFO Valuation:
□ Mỗi GRN tạo một cost layer mới (receipt_date, qty, unit_cost)
□ Mỗi GI depletes layers từ oldest đến newest
□ Nếu một GI depletes multiple layers → blended cost = tổng cost / tổng qty
□ Daily validation: tổng layer qty = qty on hand

Average Cost Valuation:
□ Khi GRN nhận hàng mới:
  New Avg Cost = (Old Qty × Old Avg + New Qty × New Cost) / (Old Qty + New Qty)
□ GI dùng current average cost tại thời điểm issue
□ Revaluation khi phát hiện cost error → Adjustment layer

Báo cáo định giá:
□ Inventory Valuation Report: Item, Qty, Unit Cost, Total Value theo ngày
□ COGS Report: Cost of Goods Sold theo period
□ Inventory Aging Report: By last movement date
```

### Bước 9: KPIs và Dashboards

```
READ: operations.md → Section 4 (Decision Support) + Section 6 (KPIs)

Dashboards cần có:
1. Inventory Status Dashboard (Warehouse Manager)
   - Stock levels vs ROP cho tất cả items
   - Items below ROP (alert list)
   - Items expiring within 30/60/90 days
   - Dead stock (no movement > threshold)
   - Storage utilization per location

2. Operations Overview (Director)
   - Inventory Accuracy %
   - Fill Rate, On-time Shipment
   - Inventory Turnover (annualized)
   - Carrying cost
   - Slow-moving % of total inventory value

Real-time alerts:
□ Stock ≤ ROP → notify Procurement
□ Expiry trong 30 ngày → notify Manager
□ Dead stock > 90 ngày không movement → notify Manager
□ Inventory Accuracy < target sau cycle count → notify Manager
```

### Bước 10: Feature Spec Output

```markdown
# Feature Spec: Inventory Management

## Overview
[Mô tả module, scope, costing method đã chọn]

## User Stories
- As a Warehouse Manager, I want to...
- As an Inventory Clerk, I want to...

## Functional Requirements
REQ-OPS-INV-001: Item Master với multi-UOM, lot/serial tracking config
REQ-OPS-INV-002: Location Master với zone/aisle/bin hierarchy
REQ-OPS-INV-003: Goods Receipt (GRN) workflow với QC hold
REQ-OPS-INV-004: Goods Issue (GI) với FIFO/FEFO allocation
REQ-OPS-INV-005: Stock Transfer giữa locations/warehouses
REQ-OPS-INV-006: Inventory Adjustment với approval workflow
REQ-OPS-INV-007: Cycle Count scheduling và execution
REQ-OPS-INV-008: Inventory Valuation (FIFO/Average Cost)
REQ-OPS-INV-009: Reorder Point calculation và auto-PR generation
REQ-OPS-INV-010: Inventory dashboards và KPI reporting

## Data Model
[ERD hoặc field definitions từ Bước 2]

## Non-functional Requirements
- Performance: Inventory balance query < 500ms (với 100k+ SKU)
- Concurrency: Xử lý simultaneous picks không gây race condition (optimistic locking)
- Accuracy: FIFO layer calculation phải 100% accurate (financial impact)
- Audit: Mọi inventory transaction không được xóa, chỉ void với audit trail
```

---

## Checklist trước khi submit

```
□ Costing method được document rõ ràng và consistent với phase1
□ Negative stock prevention logic được spec rõ (hard stop + exception)
□ FIFO/FEFO lot selection logic được mô tả
□ Approval thresholds cho adjustments nhất quán với controls.md
□ Concurrency handling được addressed (simultaneous picks)
□ Integration points với Finance (valuation posting) đã được noted
□ KPIs và dashboards được spec với targets cụ thể
□ All REQ-IDs theo format REQ-OPS-INV-[NNN]
```
