# Playbook: Phân tích Manufacturing Requirements

> **Type**: Agent Skill Playbook
> **Agent**: manufacturing-expert
> **Triggered by**: /wf-analyze-requirements khi có manufacturing, MES, ERP sản xuất modules
> **Output**: `.mc-data/docs/phase1-business/manufacturing-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: sản xuất, MES, MRP, BOM, work order, shop floor, quality control, OEE, nhà máy, dây chuyền sản xuất
- Khi cần xác định manufacturing requirements từ business idea hoặc mô tả nhà máy

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại hình sản xuất (xem bảng bên dưới để classify)
□ Quy mô: số nhà máy, số dây chuyền, số lao động
□ Sản phẩm: discrete parts hay process (liquid/gas/powder)?
□ Đã có ERP/MES chưa? Nếu có → đang dùng gì?
□ Compliance yêu cầu: ISO 9001? GMP? IATF 16949? AS9100?
□ Integration hiện có: WMS, Procurement, Sales, Finance?
```

**Classify loại hình sản xuất:**

| Loại | Đặc điểm | Ví dụ |
|------|----------|-------|
| Discrete Manufacturing | Đếm được đơn vị, BOM rõ ràng | Điện tử, cơ khí, lắp ráp |
| Process Manufacturing | Batch/continuous, recipe-based | Thực phẩm, dược phẩm, hóa chất |
| Job Shop | Make-to-order, quy trình linh hoạt | Gia công cơ khí theo đơn hàng |
| Repetitive Manufacturing | Volume cao, takt time ổn định | Dây chuyền lắp ráp xe, điện tử tiêu dùng |

### Bước 2: Xác định manufacturing modules cần có

```
READ: processes.md → để hiểu các quy trình liên quan
```

Dựa trên loại hình và scope, xác định modules:

| Module | Khi nào cần | Priority |
|--------|------------|----------|
| Production Planning (MRP/MPS) | Khi cần hoạch định sản xuất theo demand | Must-have |
| BOM Management | Khi có sản phẩm cấu thành từ nhiều components | Must-have |
| Work Order Management | Khi cần track tiến độ sản xuất | Must-have |
| Shop Floor Control (MES) | Khi cần real-time production tracking | Must-have |
| Quality Control (IQC/IPQC/OQC) | Khi có quality gates bắt buộc | Must-have |
| OEE Tracking | Khi cần đo hiệu suất máy móc | Should-have |
| Maintenance (CMMS) | Khi có thiết bị quan trọng cần TPM | Should-have |
| Costing (Standard/Actual) | Khi cần tính giá thành sản phẩm | Should-have |
| Lot/Serial Traceability | Khi có yêu cầu truy xuất nguồn gốc | Theo compliance |

### Bước 3: Identify personas bị ảnh hưởng

```
READ: personas.md

Xác định ai sẽ dùng manufacturing system:
□ Plant Manager / Giám đốc Nhà máy → cần dashboard tổng quan, OEE, KPI
□ Production Manager / Trưởng phòng Sản xuất → cần schedule board, WO status, exceptions
□ Production Planner / Kế hoạch viên → cần MRP run, capacity planning, shortage alerts
□ Line Supervisor / Tổ trưởng → cần WO detail, material pick, labor logging
□ Shop Floor Operator / Công nhân → cần work instructions, production logging, QC self-check
□ QC Inspector / Kiểm soát viên → cần inspection checklists, NCR management, sampling tools
□ Maintenance Technician / Thợ bảo trì → cần PM schedule, breakdown WO, spare parts
□ Cost Accountant → cần variance reports, WO costing, scrap cost

Với mỗi persona: ghi pain points và must-have features dựa trên personas.md
```

### Bước 4: Xác định production constraints

```
Capacity constraints:
□ Số lượng work centers / máy móc
□ Shift patterns: mấy ca/ngày, mấy ngày/tuần
□ Bottleneck operations đã biết không?
□ Setup time ảnh hưởng đến scheduling như thế nào?
□ Subcontracting có không? (outsource một số operations)

Material constraints:
□ Lead time từng loại nguyên vật liệu (ngày/tuần)
□ Safety stock policy hiện tại
□ Supplier reliability (vendor performance)
□ Min order quantities từ suppliers

Quality constraints:
□ Defect rate hiện tại / target
□ Regulatory inspection requirements
□ Customer-specific quality requirements
□ Traceability depth: lot-level hay serial-level?
```

### Bước 5: Xác định integration points

```
READ: controls.md → Authorization matrix, để hiểu workflow giữa departments

Integration cần thiết kế:
□ WMS / Kho: Material issue, goods receipt, inventory adjustments
□ Procurement / Mua hàng: Purchase requisition từ MRP, GRN
□ Sales / Kinh doanh: Sales orders → demand input cho MPS/MRP
□ Finance / Kế toán: WO costing, variance posting, depreciation
□ HR / Nhân sự: Labor time logging, overtime approval
□ Quality system: Certificate of Conformance, NCR escalation
□ Customer portals: Traceability reports theo yêu cầu khách hàng
```

### Bước 6: Xác định compliance requirements

```
Theo industry của dự án:

ISO 9001 (Mọi manufacturing):
□ Document control cho work instructions
□ Quality records retention (tối thiểu 7 năm)
□ NCR và corrective action process
□ Management review data

GMP (Thực phẩm / Dược phẩm):
□ Batch records đầy đủ
□ Equipment cleaning validation
□ Environmental monitoring
□ Ingredient traceability đến supplier COA

IATF 16949 (Automotive):
□ PPAP documentation
□ Control plans
□ MSA (Measurement System Analysis)
□ APQP process

Ghi rõ compliance level ảnh hưởng đến data retention, audit trail requirements
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-MFG-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần — impact gì đến production/quality/cost]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format:**

```
REQ-MFG-PLAN-001  → Production Planning / MRP / MPS
REQ-MFG-BOM-001   → Bill of Materials Management
REQ-MFG-WO-001    → Work Order Management
REQ-MFG-SFC-001   → Shop Floor Control / MES
REQ-MFG-QC-001    → Quality Control (IQC/IPQC/OQC)
REQ-MFG-OEE-001   → OEE Tracking và Equipment Performance
REQ-MFG-MNT-001   → Maintenance (CMMS / TPM)
REQ-MFG-COST-001  → Production Costing / Variance Analysis
REQ-MFG-TRACE-001 → Lot/Serial Traceability
REQ-MFG-RPT-001   → Manufacturing Reports và Dashboards
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/manufacturing-requirements.md

Cấu trúc output:
1. Executive Summary (loại hình sản xuất, scope, số lượng modules)
2. Manufacturing Modules cần build (bảng với priority)
3. Personas affected (summary với pain points chính)
4. Production Constraints (capacity, material, quality)
5. Requirements (theo module, có REQ-ID đầy đủ)
6. Integration requirements với các department khác
7. Compliance requirements áp dụng
8. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Loại hình sản xuất đã được classify rõ ràng
□ Mỗi REQ có REQ-ID đúng format REQ-MFG-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng (impact đến OEE, quality, cost)
□ Traceability requirements đã covered nếu có compliance
□ Integration với Procurement, WMS, Sales đã noted
□ Capacity constraints đã captured
□ Audit trail requirements đã included theo controls.md
□ Open questions được list ra để stakeholders review
```
