# Playbook: Design Production Planning Module

> **Type**: Agent Skill Playbook
> **Agent**: manufacturing-expert
> **Triggered by**: /wf-design hoặc /wf-define-features khi có MRP / Production Planning module
> **Output**: Feature spec cho Production Planning module

---

## Khi nào dùng playbook này

- Khi cần spec module "Hoạch định Sản xuất" hoặc "Production Planning / MRP"
- Khi cần thiết kế MRP run logic, capacity planning, shop floor scheduling
- Khi review hệ thống planning hiện có và cần gap analysis

---

## Procedure

### Bước 1: Xác định scope planning

```
Hỏi hoặc suy luận từ context:

Demand Input sources:
□ Sales Orders (Make-to-Order) → MTO scenario
□ Demand Forecast (Make-to-Stock) → MTS scenario
□ Cả hai → Mixed mode (phổ biến nhất)
□ Kanban / Reorder point only → không cần MRP đầy đủ

Planning Horizon:
□ Short-term: 1-4 tuần (shop floor scheduling)
□ Medium-term: 1-3 tháng (MPS/MRP)
□ Long-term: 3-12 tháng (capacity planning thô)

Scheduling strategy:
□ Forward scheduling: bắt đầu từ hôm nay, tính end date
□ Backward scheduling: bắt đầu từ due date, tính start date cần thiết
□ Finite capacity: respect capacity constraints (phức tạp hơn)
□ Infinite capacity: bỏ qua capacity constraints, plan trước, adjust sau
```

### Bước 2: Thiết kế MRP Run Logic

```
READ: processes.md → Section 1: Production Planning & Scheduling

MRP Net Requirements Calculation (công thức cốt lõi):

Net Requirement = Gross Requirement - On Hand (available) - On Order (scheduled receipts) + Safety Stock

Gross Requirement đến từ:
  - Sales Order quantities (nếu MTO)
  - Forecast quantities (nếu MTS)
  - Phụ tùng bảo trì (nếu có module Maintenance)

On Hand phải trừ:
  - Quantity available (không bao gồm QC Hold, Reserved cho WO khác)
  - Chỉ count tồn kho tại location sản xuất (không phải kho thành phẩm)

On Order bao gồm:
  - Open Purchase Orders chưa nhận
  - Planned Work Orders chưa hoàn thành
  - Transfers đang in transit
```

**Data model MRP:**

```
MRPRun:
  - id, run_date, run_type (full/net_change), horizon_days
  - status (running/completed/failed), run_by
  - total_recommendations, processing_time_ms

MRPRecommendation:
  - mrp_run_id, item_id, due_date
  - type (production_order / purchase_order / transfer_order)
  - gross_requirement, on_hand, on_order, safety_stock
  - net_requirement, planned_quantity, planned_start_date
  - action_code (new/expedite/defer/cancel/no_action)
  - action_message (text mô tả hành động cần thực hiện)

MRPParameter (per item):
  - item_id, lot_sizing_rule (lot_for_lot/fixed_qty/eoq/min_max)
  - min_order_qty, max_order_qty, fixed_order_qty
  - lead_time_days, safety_stock_qty
  - planning_method (mrp/reorder_point/kanban)
```

### Bước 3: Thiết kế Work Order Generation

```
READ: controls.md → Section 3: Production Workflow — Approval Levels

Work Order được tạo từ:
□ MRP recommendations (auto-propose, user confirm)
□ Manual creation (Planner tạo tay cho rush orders)
□ Sales Order trực tiếp (MTO scenario)

Work Order state machine:
Draft → Released → In Progress → Completed → Closed
  │         │            │             │
  │         │            │             └── Financials posted, archive
  │         │            └── Operations đang thực hiện, có thể log time
  │         └── Materials reserved, operator có thể bắt đầu
  └── Planner đang plan, chưa confirm

Transitions cần control:
- Released: Production Manager phải approve (xem controls.md)
- Completed → Closed: System auto sau khi variance report được review
- Cancel từ In Progress: phải có Plant Manager approval

Work Order fields:
  - wo_number (auto-generate, format: WO-YYYY-NNNNN)
  - item_id, planned_qty, actual_qty, scrap_qty
  - planned_start, planned_end, actual_start, actual_end
  - work_center_id, routing_id, bom_id, bom_version
  - status, priority (urgent/high/normal/low)
  - source_type (mrp/sales_order/manual/maintenance)
  - source_ref_id (ID của SO hoặc MRP run)
  - material_reservations (JSON array)
  - operations (JSON array, mỗi operation có status riêng)
```

### Bước 4: Thiết kế Capacity Planning (CRP)

```
Capacity Resource Planning — validate work orders có thể thực hiện không:

Work Center:
  - id, name, type (machine/labor/both)
  - shifts (JSON: days/hours per day)
  - efficiency_pct (thực tế thường < 100%)
  - capacity_unit (hours/day)

Capacity Calculation:
  Available Capacity = Shift Hours × Efficiency%
  Required Capacity = SUM(setup_time + run_time × qty) per WO per Work Center per Day

Capacity Report output:
  □ Bảng: Work Center | Date | Available hrs | Required hrs | Over/Under
  □ Highlight overload (Required > Available) bằng màu đỏ
  □ Suggest: Reschedule WOs, add shift, subcontract
  □ Drill-down: Click vào work center → xem WOs nào đang load

CRP chạy sau MRP, báo cáo cho Planner biết:
  - Ngày nào overloaded tại work center nào
  - WOs nào cần reschedule để giải phóng bottleneck
```

### Bước 5: Thiết kế Production Schedule Board

```
UI requirements cho Schedule Board (Gantt-style):

Axes:
  - X axis: Thời gian (ngày, tuần, tháng)
  - Y axis: Work Centers hoặc Work Orders

Hiển thị:
  □ Mỗi WO = 1 bar, màu theo status (blue=planned, green=in progress, red=overdue)
  □ Dependency lines giữa WOs nếu cần (A phải xong trước B)
  □ Maintenance downtime blocks (xem MNT module)
  □ Capacity load % bên trên mỗi work center

Interactions:
  □ Drag & drop để reschedule WO
  □ Click WO → side panel với details
  □ Filter: by status, work center, due date, priority
  □ Export: in lịch sản xuất ra PDF / Excel

Shortage alerts hiển thị trên board:
  □ Badge đỏ trên WOs bị thiếu material
  □ Tooltip giải thích thiếu item gì, thiếu bao nhiêu
  □ Link đến PR/PO suggestion
```

### Bước 6: Thiết kế Material Shortage Management

```
READ: controls.md → Section 4: Material Handling Controls

Shortage detection logic:
  Khi MRP run xong → so sánh net requirement vs available
  Nếu net_requirement > 0 và không có scheduled receipt kịp → SHORTAGE

Shortage record:
  - item_id, required_date, required_qty
  - shortage_qty (= net_requirement)
  - wo_ids_affected (array)
  - suggested_action (expedite_po/create_pr/find_substitute)
  - status (open/acknowledged/resolved)

Shortage alert flow:
  1. MRP tạo shortage list
  2. Planner nhận notification
  3. Planner xử lý: expedite PO hoặc tạo PR emergency
  4. Procurement confirm → shortage resolved
  5. WO status cập nhật: có thể release
```

### Bước 7: Feature Spec Output

```markdown
# Feature Spec: Production Planning Module

## Overview
Module hoạch định sản xuất hỗ trợ MRP (Material Requirements Planning) và MPS
(Master Production Schedule), tự động tính toán nhu cầu sản xuất từ demand,
tạo Work Orders, và quản lý công suất nhà máy.

## User Stories
- Là Production Planner, tôi muốn chạy MRP hàng ngày để biết cần sản xuất gì
- Là Production Manager, tôi muốn xem schedule board để ưu tiên WOs
- Là Planner, tôi muốn nhận cảnh báo thiếu material trước khi release WO

## Functional Requirements
REQ-MFG-PLAN-001: MRP run với net requirements calculation
REQ-MFG-PLAN-002: Work Order creation từ MRP recommendations
REQ-MFG-PLAN-003: Work Order state machine (Draft→Released→In Progress→Completed→Closed)
REQ-MFG-PLAN-004: Capacity Resource Planning (CRP) — load vs available
REQ-MFG-PLAN-005: Production Schedule Board (Gantt-style với drag & drop)
REQ-MFG-PLAN-006: Material shortage detection và alert
REQ-MFG-PLAN-007: MRP parameters per item (lot sizing, lead time, safety stock)
REQ-MFG-PLAN-008: Forward/backward scheduling modes
REQ-MFG-PLAN-009: Rush order handling với impact analysis
REQ-MFG-PLAN-010: MRP run history và recommendation audit trail

## Data Model
[Xem Bước 2+4 bên trên: MRPRun, MRPRecommendation, MRPParameter, WorkCenter]

## API Endpoints
POST /api/mrp/run — Kích hoạt MRP run
GET  /api/mrp/runs/{id}/recommendations — Danh sách recommendations
POST /api/work-orders — Tạo WO từ recommendation
PATCH /api/work-orders/{id}/release — Release WO (trigger approval workflow)
GET  /api/capacity/load — CRP report
GET  /api/shortages — Danh sách shortage alerts hiện tại

## Non-functional Requirements
- MRP run time: < 5 phút cho 10.000 SKUs
- Schedule board: load < 3s với 500 WOs hiển thị
- MRP run: chạy không ảnh hưởng đến user operations (background job)
- Audit trail: mọi WO change phải ghi user, timestamp, before/after
```

---

## Checklist trước khi submit

```
□ MRP net requirements formula đúng và documented
□ WO state machine đủ transitions, không có orphaned states
□ Capacity planning có xét đến shifts và efficiency %
□ Material shortage có alert flow rõ ràng
□ Approval levels của WO release đúng với controls.md
□ REQ-IDs format: REQ-MFG-PLAN-[NNN]
□ API endpoints đủ cho frontend implement schedule board
□ Non-functional requirements về performance đã specified
```
