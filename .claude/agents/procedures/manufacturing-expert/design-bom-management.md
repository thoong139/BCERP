# Playbook: Design BOM Management Module

> **Type**: Agent Skill Playbook
> **Agent**: manufacturing-expert
> **Triggered by**: /wf-design hoặc /wf-define-features khi có BOM / Bill of Materials module
> **Output**: Feature spec cho BOM Management module

---

## Khi nào dùng playbook này

- Khi cần spec module "Quản lý Định mức" hoặc "Bill of Materials"
- Khi cần thiết kế BOM structure, version control, ECO workflow
- Khi thiết kế data model để MRP có thể explosion BOM đúng
- Khi review BOM data hiện có để migration

---

## Procedure

### Bước 1: Xác định scope BOM

```
Hỏi hoặc suy luận từ context:

BOM complexity:
□ Single-level BOM: Finished goods + direct components (đơn giản)
□ Multi-level BOM: Sub-assemblies lồng nhau (phổ biến)
□ Phantom BOM: Sub-assembly chỉ tồn tại trên giấy, không tồn kho riêng
□ Configurable BOM: 1 product có nhiều variants (màu, size, option)

BOM types cần support:
□ Engineering BOM (EBOM): Góc nhìn thiết kế kỹ thuật
□ Manufacturing BOM (MBOM): Góc nhìn sản xuất thực tế (có routings)
□ Sales BOM: Góc nhìn báo giá/bán hàng (kit, bundle)
□ Service BOM: Spare parts cho maintenance

Version control:
□ Có cần quản lý nhiều versions không? (thường YES)
□ Effectivity dates: version nào active từ ngày nào đến ngày nào?
□ Engineering Change Order (ECO) process có không?
```

### Bước 2: Thiết kế BOM Structure

```
READ: processes.md → Section 3: BOM Management

BOM Header — thông tin chung:
  BOM:
    - id, bom_code (auto-generate, format: BOM-[ITEM_CODE]-V[NNN])
    - parent_item_id (finished good hoặc sub-assembly)
    - version, status (draft/active/obsolete)
    - effective_from_date, effective_to_date (null = vẫn còn hiệu lực)
    - unit_of_measure (UOM), base_quantity (thường = 1)
    - description, notes
    - created_by, approved_by, approved_date
    - routing_id (link đến routing cho bước sản xuất)

BOM Lines — từng component:
  BOMLine:
    - bom_id, line_number (tự động, bước 10-20-30...)
    - component_item_id
    - quantity_per (số lượng cần cho 1 unit parent)
    - uom
    - scrap_pct (% hao hụt, dùng để inflate planned qty)
      → Planned quantity = quantity_per × (1 + scrap_pct / 100)
    - component_type (normal/phantom/co_product/by_product)
    - effectivity_start, effectivity_end (per line, ghi đè BOM header nếu cần)
    - is_critical (boolean: thiếu component này thì không được sản xuất)
    - substitute_item_ids (JSON array: danh sách item có thể thay thế)
    - operation_link (liên kết component này được dùng ở operation số mấy)
    - notes
```

**BOM multi-level diagram:**

```
Finished Good: Product A (BOM ver 3)
    │
    ├── Sub-Assembly X [qty: 2] (→ phantom: tự động explode xuống)
    │   ├── Component X1 [qty: 3 pcs] scrap: 2%
    │   └── Component X2 [qty: 1 m] scrap: 5%
    │
    ├── Sub-Assembly Y [qty: 1] (→ có WO riêng, tồn kho riêng)
    │   ├── Component Y1 [qty: 10 g]
    │   └── Raw Material Z [qty: 0.5 kg]
    │
    └── Packaging P [qty: 1 set]
        ├── Box [qty: 1]
        └── Label [qty: 2]
```

### Bước 3: Thiết kế BOM Version Control

```
Version rules:
  - BOM mới tạo ở status "draft", không được dùng cho MRP
  - Chỉ 1 version "active" tại mỗi thời điểm per item
  - Version cũ → tự động "obsolete" khi version mới được activate
  - Effectivity dates cho phép schedule activation trước

Version workflow:
  Draft → Under Review → Approved → Active → Obsolete
    │           │              │
    │           │              └── QA/Engineering approve
    │           └── Engineering Change Request (ECR)
    └── Kỹ sư tạo mới hoặc copy từ version cũ

Copy from previous version:
  - Clone toàn bộ BOM lines từ version cũ
  - Increment version number
  - Set status = Draft
  - Tất cả changes phải được approve lại

Locks:
  - BOM đang active không được sửa trực tiếp
  - Phải tạo version mới (ECO process)
  - BOM đã dùng trong closed WOs: chỉ read-only vĩnh viễn
```

### Bước 4: Thiết kế Effectivity Dates

```
Effectivity cho phép 1 BOM version chỉ áp dụng trong khoảng thời gian:

Ví dụ:
  BOM v1: effective 01/01/2024 → 31/03/2024 (Component A = 3 pcs)
  BOM v2: effective 01/04/2024 → null     (Component A = 2 pcs — cải tiến)

Logic trong MRP:
  Khi MRP plan WO cho due date 15/04/2024 → dùng BOM v2
  Khi chạy WO cho SO cũ với due date 20/03/2024 → dùng BOM v1

Effectivity cũng áp dụng cho từng BOM Line (component-level):
  Ví dụ: Thay thế nhà cung cấp component từ ngày X → đổi component_item_id
  Line cũ: effectivity_end = X-1
  Line mới: effectivity_start = X
```

### Bước 5: Thiết kế Component Substitution Rules

```
READ: controls.md → Section 4: Material Handling Controls (Material substitution rules)

Substitute item:
  - Chỉ được dùng khi item chính bị shortage HOẶC được Engineering approve
  - Cần Engineering Change Notice (ECN) nếu đây là thay đổi vĩnh viễn
  - QA phải sign-off trước khi production dùng substitute

SubstituteRule:
  - primary_item_id, substitute_item_id
  - conversion_factor (ví dụ: 1 pcs primary = 1.2 pcs substitute)
  - valid_from, valid_to
  - approval_status (pending/approved/rejected)
  - approved_by, approval_date
  - conditions (chỉ cho customer X, chỉ dùng hết tồn thì mới dùng)

Khi MRP detect shortage primary → gợi ý substitute nếu:
  1. Substitute được approved
  2. Substitute có tồn kho đủ
  3. Còn trong valid date range
  → Alert Planner: "Gợi ý dùng [Substitute] — cần QA confirm"
```

### Bước 6: Thiết kế BOM Explosion

```
BOM explosion = tính toán toàn bộ materials cần để sản xuất X units

Top-down explosion (tính materials cho planned production):
  Input: item_id, quantity, planned_date
  Output: List of {item_id, required_qty, level} cho tất cả components

Algorithm:
  1. Fetch BOM version active tại planned_date
  2. Với mỗi line: required_qty = parent_qty × line.quantity_per × (1 + scrap_pct/100)
  3. Nếu component là phantom: explode tiếp xuống level dưới
  4. Nếu component là sub-assembly có BOM riêng: tạo WO con (nếu MTO) hoặc dừng (nếu tồn kho đủ)
  5. Accumulate quantities (cộng dồn nếu 1 item xuất hiện nhiều nhánh)

Bottom-up (where-used): Ngược lại — item này được dùng trong BOM nào?
  - Input: component_item_id
  - Output: List tất cả parent BOMs (và WOs) đang dùng item này
  - Use case: Khi phát hiện defect batch → biết WOs nào bị ảnh hưởng

Cost rollup (sau khi explosion):
  Standard cost = SUM(component_qty × component_standard_cost) + routing_cost
  → Cập nhật standard cost của parent item sau mỗi BOM change
```

### Bước 7: Thiết kế Engineering Change Order (ECO) Workflow

```
READ: controls.md → Section 1: Authorization Matrix (BOM Changes)

ECO = quy trình kiểm soát thay đổi BOM:

ECO fields:
  - eco_number (auto: ECO-YYYY-NNNNN)
  - title, description, reason (quality/cost/supplier_change/design_improvement)
  - affected_bom_ids (array), affected_item_ids (array)
  - requested_by (thường Engineering)
  - priority (urgent/normal)
  - target_effective_date
  - status (draft/under_review/approved/implemented/rejected)

ECO Workflow:
  Draft (Kỹ sư soạn) →
  Under Review (QA review + Production review) →
  Approved (Plant Manager sign-off cho BOM changes theo controls.md) →
  Implemented (BOM version mới được activate) →
  Closed (confirm production đã dùng BOM mới)

ECO implementation:
  1. Tạo BOM version mới từ version hiện tại (clone)
  2. Apply các changes theo ECO
  3. Set effectivity_from_date = ECO target_effective_date
  4. Activate → version cũ tự động obsolete
  5. Notify Planner, Procurement về changes

Audit trail cho BOM changes: 10 năm (xem controls.md Section 7)
```

### Bước 8: Feature Spec Output

```markdown
# Feature Spec: BOM Management Module

## Overview
Module quản lý Bill of Materials (Định mức Vật tư) hỗ trợ cấu trúc multi-level,
version control với effectivity dates, Engineering Change Order workflow,
và BOM explosion để phục vụ MRP planning và production costing.

## User Stories
- Là Kỹ sư, tôi muốn tạo BOM version mới không ảnh hưởng production đang chạy
- Là Planner, tôi muốn MRP tự động dùng đúng BOM version theo ngày kế hoạch
- Là QA, tôi muốn approve ECO trước khi BOM mới có hiệu lực

## Functional Requirements
REQ-MFG-BOM-001: BOM CRUD với multi-level structure
REQ-MFG-BOM-002: Version control (Draft/Active/Obsolete) với single active version
REQ-MFG-BOM-003: Effectivity dates per BOM version và per BOM line
REQ-MFG-BOM-004: Phantom BOM handling (auto-explode, không tạo WO con)
REQ-MFG-BOM-005: Component substitution rules với Engineering approval
REQ-MFG-BOM-006: BOM explosion (top-down) với scrap factor
REQ-MFG-BOM-007: Where-used (bottom-up) — tìm parent BOMs dùng 1 component
REQ-MFG-BOM-008: Engineering Change Order (ECO) workflow
REQ-MFG-BOM-009: Standard cost rollup sau khi BOM thay đổi
REQ-MFG-BOM-010: BOM comparison: diff giữa 2 versions

## Data Model
[Xem Bước 2: BOM, BOMLine, SubstituteRule]

## API Endpoints
GET  /api/boms?item_id={id}&effective_date={date} — BOM active tại ngày
GET  /api/boms/{id}/explosion?qty={n}&date={date} — BOM explosion
GET  /api/items/{id}/where-used — Where-used lookup
POST /api/ecos — Tạo ECO mới
PATCH /api/ecos/{id}/approve — Approve ECO
POST /api/ecos/{id}/implement — Activate BOM version mới

## Non-functional Requirements
- BOM explosion 10 levels deep < 500ms cho qty = 1
- BOM explosion cho MRP batch: xử lý 1000 BOMs/phút (background)
- BOM history: immutable sau khi WO đã closed (không xóa được)
- Audit trail: mọi BOM change ghi đủ who/when/what theo controls.md
```

---

## Checklist trước khi submit

```
□ BOM structure hỗ trợ đủ types: normal, phantom, co-product
□ Version control: chỉ 1 active version tại một thời điểm
□ Effectivity dates logic đã clear (cả header lẫn line level)
□ Scrap/yield factor đã tính vào planned quantity
□ ECO workflow align với authorization matrix trong controls.md
□ BOM explosion algorithm handle phantom items đúng
□ Where-used query có index đúng (thường là component_item_id)
□ REQ-IDs format: REQ-MFG-BOM-[NNN]
□ Cost rollup trigger đã defined (khi nào chạy?)
```
