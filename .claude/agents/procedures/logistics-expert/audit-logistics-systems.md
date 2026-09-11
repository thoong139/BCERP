# Playbook: Audit Existing Logistics Systems

> **Type**: Agent Skill Playbook
> **Agent**: logistics-expert
> **Triggered by**: /wf-legacy-scan khi có logistics system cũ
> **Output**: `.mc-data/docs/phase1-business/logistics-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống Logistics / TMS / WMS / customs management
- Khi cần đánh giá tech stack logistics hiện tại
- Khi cần tìm gaps, migration risks và automation opportunities trước khi thiết kế lại

---

## Procedure

### Bước 1: Inventory current tools

```
Thu thập từ stakeholders hoặc codebase:

Tools đang dùng:
□ TMS: Phần mềm vận tải (SAP TM, Oracle TMS, Cargowise, tự phát triển, Excel)?
□ WMS: Phần mềm kho (SAP WM, WMS Cloud, tự phát triển, Excel)?
□ Customs: Phần mềm hải quan (ECUS, iDec, Hải quan điện tử, Excel + manual)?
□ ERP: SAP / Oracle / Odoo / FAST / MISA / tự phát triển?
□ Carrier portals: Maersk / DHL / FedEx / Viettel Post... (portal riêng từng hãng)?
□ Tracking: Đang dùng công cụ nào để track shipment?
□ Document management: Lưu docs ở đâu (email, Google Drive, SharePoint, local folders)?
□ Reporting: Excel báo cáo thủ công hay có dashboard?

Với mỗi tool:
□ Số năm đã dùng
□ Số user thường xuyên
□ Có integrate với tool khác không?
□ Chi phí license/năm (nếu biết)
□ Mức độ hài lòng (thấp/trung bình/cao)
```

### Bước 2: Data quality assessment

```
READ: operations.md → Section 3: Task Frequency Analysis (để hiểu daily pain points)

Đánh giá chất lượng dữ liệu:

SHIPMENT DATA:
□ Dữ liệu lịch sử: Có data lịch sử shipments không? Bao nhiêu năm?
□ Completeness: Tỷ lệ shipments có đầy đủ fields (carrier, cost, ETA, status)?
□ Accuracy: Có bao nhiêu % shipments có sai thông tin (địa chỉ, cân nặng, HS Code)?
□ Duplicate: Có shipment trùng lặp không?
□ Status updates: Cập nhật manual hay auto? Tần suất?

ROUTE & CARRIER DATA:
□ Carrier list: Danh sách carrier có được maintain không?
□ Rate cards: Có rate cards carrier cập nhật không? Độ mới?
□ Performance data: Có historical OTD, damage rate theo carrier không?

CUSTOMS DATA:
□ Declaration history: Có lưu số tờ khai, ngày, kết quả không?
□ HS Code database: Có maintain danh sách HS Code đang dùng không?
□ Duty records: Có lưu số thuế đã nộp per shipment không?
□ Document archive: Docs được lưu đủ retention period (5+ năm)?
□ C/O records: Có track C/O đã xin, số hiệu, FTA nào không?
```

### Bước 3: Compliance gaps assessment

```
READ: controls.md → Section 2, 3, 4, 5, 7

CUSTOMS COMPLIANCE:
□ HS Code validation: Có process kiểm tra HS Code trước khi khai báo không?
□ VNACCS: Đang khai báo trực tiếp hay qua broker? Có log số tờ khai VNACCS không?
□ Document retention: Docs có được lưu đủ 5+ năm không? Format nào?
□ Red Channel: Có process xử lý Red Channel documented không?
□ C/O: Có quản lý C/O có hệ thống không? Hay rải rác email/folder?
□ Duty accuracy: Có kiểm tra lại tính thuế trước khi nộp không?

SHIPMENT CONTROLS:
□ Authorization matrix: Shipment value >50M VND có approval flow không?
□ Void/Cancel: Có process authorized void shipment không?
□ Audit trail: Ai thay đổi gì, khi nào? Có log không?
□ Insurance: Có track insurance coverage per shipment không?

INCOTERMS:
□ Có record Incoterm đã thỏa thuận với từng đối tác không?
□ Cost allocation có đúng theo Incoterm không?
```

### Bước 4: Integration health check

```
READ: operations.md → Section 5: Integration Touchpoints

Đánh giá integrations hiện tại:

ERP/Finance integration:
□ Freight cost có được đưa vào ERP tự động không?
□ Duty payment có reconcile với ERP không?
□ Có manual data entry giữa logistics và finance không?

Carrier integrations:
□ Có API connection với carrier nào không?
□ Tracking update: Auto từ carrier hay nhân viên tự check portal?
□ Booking: Qua portal riêng từng hãng hay có unified booking?
□ EDI connections: Có không? Với hãng nào?

VNACCS:
□ Kết nối trực tiếp hay thông qua phần mềm trung gian?
□ Có auto-sync status từ VNACCS về không?
□ Khi VNACCS down: Process hiện tại là gì?

Sales/CRM:
□ Order từ Sales có đẩy tự động sang logistics không?
□ Logistics có update delivery status về Sales/CRM không?
```

### Bước 5: Process automation opportunities

```
READ: operations.md → Section 3: Task Frequency Analysis

Phân tích manual tasks tốn thời gian nhất:

DAILY TASKS (2-3h/ngày — từ operations.md):
□ Track shipments: Đang check bao nhiêu portal/ngày? → Cơ hội: Unified tracking dashboard
□ Update statuses: Có bao nhiêu manual entry/ngày? → Cơ hội: Carrier API integration
□ Process documents: Có bao nhiêu paper-based? → Cơ hội: Digital document workflow
□ Carrier communication: Email/phone bao nhiêu lần/ngày? → Cơ hội: Carrier portal

WEEKLY TASKS:
□ Carrier performance review: Có được thực hiện không? Mất bao lâu? → Cơ hội: Auto-generated report
□ Route optimization: Đang làm thủ công không? → Cơ hội: Route optimization engine

CUSTOMS TASKS:
□ HS Code lookup: Mỗi lần mất bao lâu? → Cơ hội: Searchable HS Code database
□ Duty calculation: Manual trong Excel không? → Cơ hội: Auto-calculator tích hợp HS Code + rates
□ Declaration preparation: Bao nhiêu % thông tin phải nhập tay? → Cơ hội: Auto-populate từ invoice/PoL

Tính toán ROI tiềm năng:
□ Giờ tiết kiệm/ngày × số nhân viên × lương/h = Monthly savings
□ Error rate reduction → giảm chi phí phạt, re-clearance, delay
```

### Bước 6: Migration risks assessment

```
Nếu sẽ replace hệ thống cũ:

DATA MIGRATION RISKS:
□ Shipment history: Bao nhiêu records? Format? Data quality?
□ HS Code mappings: Đang dùng custom HS Code hay standard?
□ Carrier profiles: Có migrate rates, contacts, credentials không?
□ Document archive: Cần migrate document vault không? Storage size?
□ Open customs declarations: Tờ khai đang xử lý mid-flight xử lý thế nào?

OPERATIONAL RISKS:
□ Cutover timing: Tránh cao điểm xuất nhập khẩu (Tết, end of quarter)
□ Training: Customs Specialist cần bao lâu để thành thạo hệ thống mới?
□ Parallel run: Cần chạy song song bao lâu (khuyến nghị: tối thiểu 1 tháng)?
□ VNACCS re-registration: Cần đăng ký lại với hải quan nếu đổi phần mềm?

COMPLIANCE RISKS:
□ Audit in progress: Có đang bị kiểm tra hải quan không?
□ Pending declarations: Tờ khai đang chờ xử lý phải handle thế nào trong migration?
□ Document vault: Phải đảm bảo retention continuity (không được mất docs cũ)
```

### Bước 7: Output — As-Is Analysis Report

```markdown
# Logistics As-Is Analysis Report

## Executive Summary
[3-5 dòng: overall health, biggest strengths, critical gaps, migration readiness]

## Current State Inventory

### Tech Stack
| Tool | Purpose | Vendor | Years Used | Users | Integration | Satisfaction |
|------|---------|--------|-----------|-------|-------------|--------------|

### Process Coverage
| Process | Current Tool | Automation Level | Pain Points |
|---------|-------------|-----------------|-------------|
| Shipment booking | | Manual/Semi/Auto | |
| Tracking | | | |
| Customs declaration | | | |
| Document management | | | |
| Reporting | | | |

## Data Quality Assessment
| Data Domain | Completeness | Accuracy | Issues Found |
|-------------|-------------|----------|--------------|

## Compliance Gaps
### Critical Gaps (block go-live nếu không fix)
- [Gap]: [Impact] → [Required action]

### Important Gaps (fix trong 3 tháng đầu)
- [Gap]: [Impact] → [Recommendation]

### Nice-to-have Improvements
- [Gap]: [Impact] → [Recommendation]

## Integration Health
| Integration | Current State | Issues | Recommendation |
|-------------|--------------|--------|----------------|

## Automation Opportunities
| Task | Current Time Spent | Automation Potential | Estimated Savings |
|------|-------------------|---------------------|-------------------|

## Migration Risks
### High Risk
- [Risk]: [Mitigation]

### Medium Risk
- [Risk]: [Mitigation]

### Low Risk
- [Risk]: [Mitigation]

## Recommendations Priority
1. [Highest impact action] — Effort: [Low/Med/High], Impact: [High/Med/Low]
2. ...

## Implementation Roadmap
Quick wins (< 1 tháng) / Medium term (1-3 tháng) / Long term (3+ tháng)
```

---

## Checklist trước khi submit

```
□ Tất cả tools hiện tại đã được inventory
□ Data quality issues đã được quantify (%, số records)
□ Compliance gaps đã phân loại Critical / Important / Nice-to-have
□ VNACCS integration status đã được đánh giá
□ Document retention compliance đã được check
□ Migration risks đã được identify với mitigation
□ Automation opportunities đã estimate ROI
□ Parallel run recommendation đã included
```
