# Playbook: Phân tích Operations Requirements

> **Type**: Agent Skill Playbook
> **Agent**: operations-expert
> **Triggered by**: /wf-analyze-requirements khi có inventory/supply chain/operations modules
> **Output**: `.mc-data/docs/phase1-business/operations-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: inventory, warehouse, supply chain, procurement, quality control, production planning
- Khi cần xác định operations requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại hình doanh nghiệp (Manufacturing / Trading / Distribution / Service)
□ Quy mô operations (số kho, số SKU, volume giao dịch hàng ngày)
□ Đã có ERP/WMS chưa? Nếu có → đang dùng gì?
□ Kênh phân phối (B2B / B2C / Omnichannel / Export)
□ Sản phẩm có đặc thù gì? (Lot tracking, Serial number, Expiry date, Hazmat)
```

### Bước 2: Xác định scope operations cần build

Dựa trên loại business, map ra modules:

| Business Type | Modules thường cần |
|--------------|-------------------|
| Trading / Distribution | Inventory Management, Warehouse Operations, Procurement/SCM |
| Manufacturing | Tất cả trading + Production Planning (MRP), BOM, Work Orders |
| E-commerce | Inventory Management, Multi-location, Fulfillment, Returns |
| Retail | POS Inventory, Replenishment, Multi-store, Stock Transfer |
| Service | Spare parts inventory, Asset management |

Sau khi xác định → load knowledge file tương ứng:
```
Inventory / Warehouse → READ: operations.md (Process 1, 2, 3, 4)
Supply chain / Procurement → READ: operations.md (Process 4) + controls.md (Section 5)
Quality control → READ: operations.md (Stage Activities: QC)
Controls / Authorization → READ: controls.md (Section 1, 2, 5)
KPIs → READ: operations.md (Section 6)
```

### Bước 3: Identify personas bị ảnh hưởng

```
READ: personas.md

Xác định ai sẽ dùng operations system:
□ Operations Manager → cần dashboard tổng quan, KPI, approvals
□ Warehouse Manager → cần quản lý bin locations, nhân sự, exception handling
□ Inventory Clerk / Warehouse Staff → cần mobile scanning, pick list, GRN
□ Procurement Specialist → cần PO management, vendor tracking, 3-way match
□ QC Inspector → cần inspection forms, hold/release workflow, NCR

Với mỗi persona: note down pain points và must-have features
```

### Bước 4: Xác định phương pháp định giá tồn kho (Costing Method)

```
Câu hỏi quan trọng cần xác định sớm (ảnh hưởng toàn bộ data model):

□ FIFO (First In First Out) — áp dụng khi hàng có hạn sử dụng, lot tracking bắt buộc
□ LIFO (Last In First Out) — ít phổ biến, một số ngành đặc thù
□ Average Cost (Weighted Average) — đơn giản, phổ biến với trading
□ Standard Cost — manufacturing, cần variance analysis
□ Specific Identification — đồ trang sức, xe, high-value items

Ghi nhận vào requirements vì costing method = thiết kế DB và valuation logic.
```

### Bước 5: Xác định Service Level Targets

```
READ: operations.md → Section 6: KPIs & Metrics

Thu thập hoặc đề xuất mục tiêu cho dự án:
□ Inventory Accuracy: mục tiêu bao nhiêu %? (benchmark: >99%)
□ Fill Rate: % đơn hàng giao đủ? (benchmark: >98%)
□ On-time Shipment: % giao đúng hạn? (benchmark: >95%)
□ Dock-to-Stock Time: thời gian nhận hàng vào kho? (benchmark: <24h)
□ Order Cycle Time: thời gian từ release đến ship? (benchmark: <4h)
□ Stock-out Rate: tỷ lệ hết hàng? (benchmark: <2%)
□ Inventory Turnover: vòng quay tồn kho? (benchmark: >12x/năm)
```

### Bước 6: Xác định integration points

```
READ: operations.md → Section 5: Integration Touchpoints

Map integration với các hệ thống khác:
□ Sales/CRM → nhận Sales Orders, cấp phát tồn kho
□ Finance/Accounting → Goods Receipt posting, Inventory Valuation, GL entries
□ Procurement → Purchase Orders, GRN matching
□ Production → Work Orders, Material Issue, Finished Goods Receipt (nếu manufacturing)
□ E-commerce Platform → Real-time stock sync (nếu B2C)
□ 3PL/Logistics → Shipping labels, tracking numbers, carrier integration
□ Barcode / WMS devices → Mobile scanning, RFID (nếu có)
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-OPS-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần - impact gì]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format:**
```
REQ-OPS-INV-001  → Inventory Management (quản lý tồn kho)
REQ-OPS-WH-001   → Warehouse Operations (vận hành kho)
REQ-OPS-SCM-001  → Supply Chain / Procurement
REQ-OPS-QC-001   → Quality Control
REQ-OPS-PROD-001 → Production Planning / MRP
REQ-OPS-RPT-001  → Operations Reporting / KPIs
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/operations-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope operations)
2. Loại hình doanh nghiệp và đặc thù vận hành
3. Costing Method đã xác định (FIFO / Average Cost / ...)
4. Operations Modules cần build (list)
5. Personas affected (summary)
6. Service Level Targets
7. Requirements (theo module, có REQ-ID)
8. Integration requirements với các department khác
9. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Costing method đã được xác định và documented
□ Mỗi REQ có REQ-ID đúng format REQ-OPS-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng
□ Negative stock prevention policy đã được ghi nhận
□ Approval thresholds cho adjustments đã defined
□ Integration với Finance (inventory valuation) đã noted
□ Service Level Targets đã documented
□ Open questions được list ra để stakeholders review
```
