# Playbook: Audit Operations Systems

> **Type**: Agent Skill Playbook
> **Agent**: operations-expert
> **Triggered by**: /wf-legacy-scan khi có operations/inventory systems cũ
> **Output**: `.mc-data/docs/phase1-business/operations-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống Operations/Inventory/WMS/ERP
- Khi cần đánh giá current state trước khi thiết kế lại
- Khi cần tìm gaps, data quality issues, và migration risks

---

## Procedure

### Bước 1: Inventory công cụ và hệ thống hiện tại

```
Thu thập từ stakeholders hoặc codebase:

□ WMS (Warehouse Management System): Đang dùng phần mềm nào?
□ ERP modules: Inventory module của ERP nào? (SAP, Oracle, Microsoft, Odoo, v.v.)
□ Procurement tools: Có dedicated procurement system không?
□ Spreadsheet usage: Bao nhiêu % vận hành vẫn dùng Excel?
□ Barcode/RFID: Có thiết bị scanning không? Kết nối với hệ thống nào?
□ Mobile devices: Có dùng mobile/tablet trong kho không?
□ Integrations: Hệ thống operations kết nối với gì? (Accounting, Sales, Logistics)

Tạo bảng:
| Tool/System | Purpose | Vendor | Users | Issues |
|-------------|---------|--------|-------|--------|
| ...         | ...     | ...    | ...   | ...    |
```

### Bước 2: Đánh giá chất lượng dữ liệu (Data Quality)

```
READ: controls.md → Section 6: Audit Trail Requirements

Item Master quality:
□ Số lượng active items trong hệ thống
□ % items có đủ thông tin (unit price, UOM, category, reorder point)
□ Duplicate items: Có SKU bị nhập trùng dưới tên khác không?
□ Inactive items: Items không có movement trong 1 năm vẫn còn active?
□ Costing method: Có nhất quán không? Hay mỗi item một kiểu?

Location / Bin data:
□ Locations trong hệ thống có khớp với thực tế trong kho không?
□ % items có assigned location
□ Orphan stock: Inventory balance với location không tồn tại

Inventory balance accuracy:
□ Lần cuối physical count là khi nào?
□ % variance giữa system qty và actual qty (ước tính từ stakeholder)
□ Negative stock: Có items nào đang có qty âm trong system không?
□ Open transactions: Có GRNs/GIs nào chưa được post không?

On-hand value:
□ Inventory value trên hệ thống có khớp với sổ sách kế toán không?
□ Variance giữa Operations system và Finance system?
□ Tần suất reconciliation hiện tại là bao nhiêu?
```

### Bước 3: Process Gap Analysis

```
READ: operations.md → Section 2: Core Operations Processes
READ: personas.md → Quick Reference: Persona Access Matrix

RECEIVING:
□ Có check PO khi nhận hàng không? (hay nhận tự do)
□ QC inspection process: Paper hay digital? Có lưu results không?
□ Put-away: Có assigned location system không? Hay random?
□ Thời gian từ nhận hàng đến cập nhật system (Dock-to-Stock time)?
□ Discrepancies xử lý thế nào? Có documentation không?

PICKING / FULFILLMENT:
□ Pick list: Digital hay paper?
□ Pick path optimization: Có không?
□ Verification trước khi pack: Scanner hay visual check?
□ Ship confirmation: Cập nhật system ngay hay batch cuối ngày?
□ Returns handling: Có defined process không? Return vào kho hay xử lý thế nào?

INVENTORY CONTROL:
□ Cycle counting: Có schedule không? Ai thực hiện?
□ Discrepancy investigation: Có root cause analysis không?
□ Adjustment authorization: Có approval workflow không? Hay tự ý điều chỉnh?
□ Negative stock: Hệ thống có chặn không? Hay để negative xảy ra?

PROCUREMENT:
□ Purchase Requisition: Có workflow approval không?
□ Vendor selection: Có Approved Vendor List không?
□ PO matching: Có match với GRN trước khi approve invoice không?
□ Vendor performance: Có track và đánh giá không?
```

### Bước 4: KPI Baseline — Đo lường hiện trạng

```
READ: operations.md → Section 6: KPIs & Metrics

Thu thập metrics từ stakeholders (số thực tế hoặc ước tính):

Accuracy Metrics:
□ Inventory Accuracy hiện tại: ____% (target: >99%)
□ Pick Accuracy: ____% (target: >99.9%)
□ Location Accuracy: ____% (target: >99.5%)

Efficiency Metrics:
□ Dock-to-Stock Time trung bình: ____h (target: <24h)
□ Order Cycle Time: ____h (target: <4h)
□ Receiving Productivity: ____units/person/hour

Service Metrics:
□ Fill Rate: ____% (target: >98%)
□ On-time Shipment: ____% (target: >95%)
□ Stock-out incidents per month: ____

Inventory Metrics:
□ Inventory Turnover: ____x/năm (target: >12x)
□ Days of Inventory: ____ ngày (target: <30)
□ Slow-moving % of total value: ____% (target: <10%)
□ Carrying cost %: ____% (target: <25%)

So sánh với benchmarks → Highlight metrics nào đang kém nhất.
```

### Bước 5: Integration Health Assessment

```
READ: operations.md → Section 5: Integration Touchpoints

Kiểm tra từng integration hiện tại:

Sales → Operations (Order Fulfillment):
□ Orders có tự động chuyển sang Operations không? Hay manual?
□ Stock reservation: Khi SO confirmed, stock có được reserved không?
□ Backorder handling: Thiếu hàng xử lý thế nào?

Operations → Finance (Inventory Valuation):
□ GRN và GI có tự động tạo accounting entries không?
□ Month-end close: Operations và Finance có phối hợp không? Mất bao nhiêu ngày?
□ Inventory value reconciliation: Tần suất, có automation không?

Procurement → Operations:
□ POs có visible trong warehouse không?
□ GRN có linked về PO không? 3-way matching có không?

External (nếu có):
□ 3PL integration: Có không? Realtime hay batch?
□ E-commerce sync: Stock update sang platform có realtime không?
□ Carrier integration: Label printing, tracking updates?
```

### Bước 6: Migration Risk Assessment

```
Xác định risks khi migrate sang hệ thống mới:

Open Transactions:
□ Open Purchase Orders (POs chưa nhận hàng đủ): Số lượng? Giá trị?
□ Open Goods Receipts (chưa invoice): Số lượng?
□ Open Invoices chưa match: Số lượng? Giá trị?
□ Unposted adjustments: Có transactions pending không?
□ Active work orders / production orders (nếu manufacturing)

Data Migration Complexity:
□ Item Master: Số lượng? Cần cleansing không?
□ Inventory Balance: Cutover date? Negative balances cần xử lý?
□ Transaction History: Cần migrate lịch sử không? Bao nhiêu năm?
□ Cost Layers (FIFO): Có cần migrate cost layers không?
□ Vendor Master: Số lượng vendors? Dữ liệu quality?

Business Continuity Risks:
□ Thời điểm cutover an toàn nhất (low season?)
□ Parallel run: Chạy song song 2 hệ thống bao lâu?
□ Rollback plan: Nếu cutover thất bại, quay về được không?
□ Training: Bao nhiêu users cần training? Timeline?
□ Critical transactions: Peak season có operations nào không được gián đoạn?
```

### Bước 7: Output — Audit Report

```markdown
# Operations As-Is Analysis Report

## Executive Summary
[3-5 dòng: Overall health, biggest strengths, critical gaps, migration readiness score]

## Current Systems Inventory
| Tool/System | Purpose | Users | Issues |
|-------------|---------|-------|--------|

## Data Quality Assessment
### Item Master
[Findings + % quality score]

### Inventory Balance
[Findings + last count date + estimated accuracy]

### Open Transactions
[List pending transactions cần xử lý trước migration]

## Process Gap Analysis

### Critical Gaps (Block go-live nếu không fix)
- [Gap]: [Impact] → [Recommendation]

### Important Gaps (Cần address trong thiết kế mới)
- [Gap]: [Impact] → [Recommendation]

### Process hiện tại cần giữ lại (Working well)
- [Process]: [Why keep it]

## KPI Baseline vs Benchmark
| Metric | Current | Benchmark | Gap | Priority |
|--------|---------|-----------|-----|----------|

## Integration Health
| Integration | Current State | Issues | Risk |
|-------------|---------------|--------|------|

## Migration Risk Assessment
### Open Transactions (cần xử lý trước cutover)
[List với qty và value]

### Data Migration Complexity
[Score: Low / Medium / High per data type]

### Recommended Cutover Strategy
[Approach: Big bang / Phased / Parallel run + rationale]

## Priority Recommendations
1. [Highest priority — impact on migration feasibility]
2. ...

## Pre-Migration Checklist
- [ ] Data cleansing: Item Master
- [ ] Resolve negative stock
- [ ] Close open transactions
- [ ] Physical count before cutover
- [ ] Costing method confirmation
```

---

## Checklist trước khi submit

```
□ Tất cả current systems đã được inventoried
□ Negative stock items đã được identified và flagged
□ Open transactions (PO, GRN, Invoice) đã được counted
□ KPI baseline đã được captured (ngay cả khi là ước tính)
□ Migration risks đã được rated (Low / Medium / High)
□ Costing method hiện tại đã được xác định rõ
□ Integration gaps đã được documented cho design team
□ Recommended cutover strategy có rationale cụ thể
```
