# Playbook: Audit Existing Manufacturing Systems

> **Type**: Agent Skill Playbook
> **Agent**: manufacturing-expert
> **Triggered by**: /wf-legacy-scan khi có manufacturing ERP/MES cũ
> **Output**: `.mc-data/docs/phase1-business/manufacturing-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống Manufacturing ERP/MES hiện hữu
- Khi cần đánh giá production data quality trước khi migration
- Khi cần tìm gaps giữa hệ thống cũ và yêu cầu mới
- Khi cần xác định migration risks từ active Work Orders, open BOMs

---

## Procedure

### Bước 1: Inventory hệ thống hiện tại

```
Thu thập từ stakeholders hoặc codebase:

Hệ thống đang dùng:
□ ERP module sản xuất: SAP PP? Oracle WIP? Odoo MRP? Microsoft Dynamics? Custom?
□ MES riêng không? → Hãng nào? Version?
□ Scheduling tool: APS (Advanced Planning)? Excel? Màn bảng tay?
□ Quality system: QMS riêng? Module trong ERP? Paper-based?
□ Maintenance: CMMS riêng? Module trong ERP? Sổ tay?
□ Báo cáo: BI tool? Crystal Reports? Excel macro?
□ Các spreadsheet Excel quan trọng: chúng cover gì mà ERP không làm được?

Integrations hiện có:
□ ERP ↔ WMS: Có không? Tự động hay thủ công?
□ ERP ↔ Procurement: PO, GRN sync ra sao?
□ ERP ↔ Sales: SO → Production demand flow thế nào?
□ ERP ↔ Finance: WO costing posting như thế nào?
□ MES ↔ ERP: Bidirectional hay 1 chiều?
□ Shop floor terminals: Barcode scanners? Tablets? Giấy?
```

### Bước 2: Audit Production Data Quality

```
READ: processes.md → để hiểu data nào là critical

BOM data quality:
□ Tổng số BOMs hiện có: [N] items có BOM
□ % BOMs có đủ thông tin (quantity, UOM, scrap factor)?
□ BOMs có multi-level đúng không hay bị flat?
□ Version nào đang active? Có expired versions chưa được clean up?
□ BOM vs thực tế sản xuất: có deviation không? (hỏi Production Manager)
□ Phantom items có được flag đúng không?
□ Scrap factors có realistic không hay bị set = 0 tất cả?

Routing data quality:
□ Tổng số routings: [N]
□ % routings có standard times (setup + run time)?
□ Work center data đầy đủ không? (capacity, shifts)
□ Routings có được maintain khi process thay đổi không?

Work Order history:
□ WO completion rate: % WOs closed vs total created (12 tháng gần nhất)
□ WOs còn open lâu bất thường (> 30 ngày): bao nhiêu? Lý do?
□ WOs chưa có goods receipt: inventory sẽ sai nếu migrate
□ WO variance: actual vs planned > 20%? (chỉ ra data quality hoặc planning issue)

Inventory data:
□ Tổng số inventory records: [N] locations × [M] items
□ Negative inventory: có không? Bao nhiêu SKUs?
  → Negative inventory = dấu hiệu nghiêm trọng của data integrity issue
□ Last cycle count: khi nào? Kết quả adjustment có lớn không?
□ On-hold / quarantine inventory: đã được xử lý chưa hay bỏ quên?
□ Expired lots: còn trong hệ thống không?
```

### Bước 3: Phân tích Planning Accuracy History

```
READ: processes.md → Section 1: Production Planning & Scheduling → Key Metrics

MRP/MPS effectiveness:
□ Schedule adherence: Actual production vs planned (% on-time)
□ MRP run frequency: Hàng ngày? Hàng tuần? Thủ công khi cần?
□ Planning horizon đang dùng: mấy tuần/tháng?
□ Bao nhiêu "action messages" được xử lý sau mỗi MRP run?
  (nếu Planner ignore action messages → MRP không hiệu quả)
□ Demand accuracy: Forecast vs actual orders (last 12 months MAE/MAPE)
□ Emergency/rush orders: % so với total? Nguyên nhân chủ yếu?

Shortage incidents:
□ Tần suất shortage gây dừng dây chuyền: bao nhiêu lần/tháng?
□ Lead time từ phát hiện shortage đến có hàng: bao lâu?
□ Top 10 items hay bị shortage → vấn đề ở planning hay supplier?

Capacity:
□ Có bottleneck work centers đã biết không? Chúng là gì?
□ Overtime frequency: bao nhiêu ca overtime/tháng?
□ Subcontracting hiện tại: bao nhiêu % value outsource?
```

### Bước 4: Audit Quality Data Gaps

```
READ: controls.md → Section 2: Quality Control Gates + Section 7: Audit Trail

IQC (Incoming):
□ Có hệ thống IQC không? Hay chỉ visual check và ký giấy?
□ AQL sampling đang theo standard nào?
□ Rejection rate by vendor: có data không?
□ NCRs cho vendor: có được gửi và theo dõi không?
□ COA (Certificate of Analysis/Conformance) từ vendor: lưu ở đâu?

IPQC (In-process):
□ In-process checkpoints có được ghi lại không? Ở đâu? (paper/system)
□ First Pass Yield per operation: có track không?
□ Defect data: có phân loại defect type không?
□ Control charts / SPC: có không? Đang dùng gì?

OQC (Outgoing):
□ Final inspection records: đầy đủ không?
□ Customer complaints linked về production lots: có trace được không?
□ Retention samples: policy có không?

Non-conformance:
□ NCR system: có không? Bao nhiêu open NCRs?
□ Corrective actions: có được theo dõi completion không?
□ CAPA effectiveness: có measure không?
□ Quality cost (CoQ): có track không?
```

### Bước 5: Audit Downtime / OEE Tracking

```
READ: processes.md → Key Metrics: OEE

OEE hiện tại:
□ Có OEE tracking không? Tool gì?
□ OEE tổng thể của nhà máy: bao nhiêu %? (target vs actual)
□ Downtime reasons: có được phân loại không? (breakdown/PM/setup/changeover)
□ MTBF và MTTR per critical equipment: có data không?
□ Planned maintenance compliance: % PMs hoàn thành đúng hạn?

Maintenance data:
□ Asset registry: danh sách máy móc/thiết bị đầy đủ không?
□ Maintenance history: có không? Đủ detail không?
□ Spare parts inventory: đang quản lý thế nào? Có minimum stock không?
□ Maintenance cost: có track per asset không?
```

### Bước 6: Audit Integration Health

```
Mỗi integration hiện có:
□ Direction: 1-way hay 2-way?
□ Method: real-time API / batch file / manual export-import?
□ Frequency: mỗi bao lâu sync 1 lần?
□ Error handling: có monitoring không? Ai nhận alert khi lỗi?
□ Data mismatches: có không? Tần suất? Ai reconcile?
□ Workarounds: có điểm nào team đang làm thủ công vì integration không đủ tốt?

Critical integration issues (thường gặp):
□ Inventory sync giữa ERP và WMS bị lệch
□ WO completion không tự động update tồn kho
□ MRP chạy không có đủ data từ Sales (SO thiếu)
□ Quality hold không block production picking
```

### Bước 7: Xác định Migration Risks

```
Active Work Orders:
□ Tổng WOs đang In Progress: [N]
□ Mỗi WO: đã dùng bao nhiêu material? Đã hoàn thành bao nhiêu operations?
□ Strategy: migrate mid-stream hay close tất cả trước cutover?
□ WOs không thể close: sẽ xử lý thế nào?

Open BOMs:
□ BOMs đang ở Draft/Pending Approval: [N]
□ Engineering Changes in-flight: có ECOs pending không?
□ BOM đang dùng cho WOs chưa complete: không được change đột ngột

Inventory với đặc thù:
□ Lots cần thay đổi storage location trong hệ thống mới
□ Lots có expiry gần: phải migrate với alert
□ WIP inventory (gắn với WOs): cần migrate cùng WO

Data cleansing trước migration:
□ Items nào không active: archive, không migrate
□ BOMs obsolete: đánh dấu, không migrate active
□ Negative inventory phải được điều chỉnh trước D-day
□ Open NCRs: resolution plan trước cutover
```

### Bước 8: Output — As-Is Analysis Report

```markdown
# Manufacturing As-Is Analysis Report

## Executive Summary
[3-5 dòng: hệ thống hiện tại, điểm mạnh chính, vấn đề nghiêm trọng nhất, risk migration]

## Current Systems Inventory
| System | Purpose | Version | Integration | Health |
|--------|---------|---------|-------------|--------|

## Production Data Quality Assessment

### BOM Data
| Item | Status | Issues | Impact |
|------|--------|--------|--------|

### Work Order Status
- Total open WOs: [N]
- At-risk WOs (migration concern): [N]
- Recommendation: [close all before cutover / migrate với plan]

### Inventory Integrity
- SKUs với negative inventory: [N] → phải giải quyết trước migration
- Lots expired still in system: [N]
- Last cycle count: [date] — adjustment % [X%]

## Planning Effectiveness
| Metric | Current | Benchmark | Gap |
|--------|---------|-----------|-----|
| Schedule adherence | X% | >95% | |
| MRP run frequency | weekly | daily | |
| Shortage incidents/month | N | <2 | |

## Quality System Gaps
### Critical Gaps (block compliance)
- [Gap]: [Impact] → [Recommendation]

### Important Gaps (risk quality)
- [Gap]: [Impact] → [Recommendation]

## OEE & Maintenance
- Current OEE: X% (target: Y%)
- Top downtime causes: [List]
- PM compliance: X%

## Integration Health
| Integration | Direction | Method | Issues |
|-------------|-----------|--------|--------|

## Migration Risk Assessment
### High Risk Items
- [Item]: [Risk] → [Mitigation]

### Data Cleansing Required Before Migration
- [ ] Resolve [N] negative inventory records
- [ ] Close or document [N] stale open WOs
- [ ] Archive [N] obsolete BOMs
- [ ] Resolve [N] open NCRs

## Priority Recommendations
1. [Highest impact] — Effort: [X], Impact: [Y]
2. ...

## Implementation Roadmap
- Pre-migration (D-90 đến D-30): [Data cleansing tasks]
- Cutover (D-day): [Go-live tasks]
- Post-migration (D+30): [Validation tasks]
```

---

## Checklist trước khi submit

```
□ Đã inventory đủ hệ thống hiện tại (ERP, MES, standalone tools, Excel)
□ BOM data quality đã assessed: % đủ data, % có deviation
□ Negative inventory đã identified và quantified
□ Open WOs đã counted và migration strategy đề xuất
□ NCR open count và resolution plan
□ Migration risks đã phân loại theo High/Medium/Low
□ Data cleansing checklist đã cụ thể, có owner
□ Output ghi tại: .mc-data/docs/phase1-business/manufacturing-as-is-analysis.md
```
