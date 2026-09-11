# Playbook: Design Customs Declaration Module

> **Type**: Agent Skill Playbook
> **Agent**: logistics-expert
> **Triggered by**: /wf-design hoặc /wf-define-features khi cần design customs/XNK module
> **Output**: Feature spec cho Customs Declaration module

---

## Khi nào dùng playbook này

- Khi cần spec module "Khai báo Hải quan" hoặc "Customs Clearance" hoặc "XNK"
- Khi cần thiết kế workflow tích hợp VNACCS/VCIS
- Khi dự án có xuất nhập khẩu qua cửa khẩu Việt Nam

---

## Procedure

### Bước 1: Xác định scope

```
Hỏi hoặc suy luận từ context:
□ Chiều: Nhập khẩu / Xuất khẩu / Cả hai?
□ Loại hàng chủ yếu: Nguyên liệu sản xuất / Hàng tiêu dùng / Hàng gia công / Hàng tái xuất?
□ FTA áp dụng: ATIGA / EVFTA / RCEP / VKFTA / khác? (ảnh hưởng C/O và thuế suất)
□ Bonded warehouse / Deferred duty cần không?
□ Dangerous goods (IMO): Có không?
□ Customs broker: Internal team hay outsource 3PL broker?
□ Volume khai báo: Bao nhiêu tờ khai/tháng?
□ Kết nối VNACCS: Direct API hay qua phần mềm hải quan (ECUS, iDec...)?
```

### Bước 2: Thiết kế Import/Export Flow

```
READ: operations.md → Process 3: Customs Declaration (Vietnam)
READ: controls.md → Section 2: Customs Compliance Controls

IMPORT FLOW:
Chuẩn bị hồ sơ → HS Code tra cứu → Tính thuế → Soạn tờ khai →
Nộp VNACCS → Nhận phân luồng → Xử lý theo luồng → Thanh toán thuế → Thông quan

EXPORT FLOW:
Chuẩn bị hồ sơ → HS Code tra cứu → Xác nhận C/O → Soạn tờ khai →
Nộp VNACCS → Nhận phân luồng → Xử lý theo luồng → Thông quan → Lưu hồ sơ

Phân luồng VNACCS:
□ Green Channel (Luồng Xanh): Auto-cleared → Release ngay
□ Yellow Channel (Luồng Vàng): Document check → Nộp bổ sung docs → Wait for approval
□ Red Channel (Luồng Đỏ): Physical inspection → Coordinate kiểm tra thực tế → Wait
□ KHÔNG được bypass Red Channel workflow (xem constraints logistics-expert.md)
```

### Bước 3: Thiết kế HS Code Lookup & Classification

```
READ: controls.md → Section 2: HS Code Validation Rules
Tham khảo: Circular 14/2015/TT-BTC (danh mục hàng hóa Việt Nam)

HS Code data structure:
□ 8-digit HS Code (Việt Nam format: 4 digits heading + 4 digits subheading)
□ Description (Vietnamese + English)
□ Import tax rate (MFN — Most Favored Nation)
□ FTA preferential rates (ATIGA, EVFTA, RCEP... per applicable agreement)
□ VAT rate (thường 5% hoặc 10%)
□ Special consumption tax (nếu áp dụng)
□ Prohibited/restricted flag (cần import/export permit)
□ MSDS requirement flag (hàng hóa nguy hiểm)

HS Code Search UX:
□ Tìm theo mô tả sản phẩm (full-text search Vietnamese + English)
□ Tìm theo code (prefix search từ 2 ký tự)
□ Kết quả gợi ý top 5 theo relevance
□ History: Hiện HS Code đã dùng cho loại hàng này trước đây
□ Validation: Cảnh báo nếu HS Code đã hết hiệu lực hoặc đã thay đổi

Classification confidence levels:
□ CONFIRMED: Customs Specialist đã xác nhận
□ SUGGESTED: System gợi ý, cần review
□ DISPUTED: Có khiếu nại với cơ quan hải quan → lock declaration
```

### Bước 4: Thiết kế VNACCS Integration

```
READ: controls.md → Quick Reference: Vietnam Customs (VNACCS/VCIS)

VNACCS API Integration points:
□ Nộp tờ khai (submit declaration): POST /declarations
□ Tra cứu trạng thái (check status): GET /declarations/{id}/status
□ Nhận phân luồng (channel assignment): webhook hoặc polling
□ Nộp bổ sung hồ sơ (Yellow Channel): POST /declarations/{id}/documents
□ Thanh toán thuế điện tử (e-payment): link với BIDV/Vietinbank gateway
□ Nhận lệnh thông quan (release order): GET /declarations/{id}/release

Error handling:
□ VNACCS timeout (thường xảy ra giờ cao điểm sáng): Retry 3× với backoff
□ Validation error từ VNACCS: Parse error code → hiển thị hướng dẫn sửa
□ Connection failure: Alert customs specialist, lưu draft để retry thủ công
□ Lưu toàn bộ request/response payload cho audit (không xóa)

Fallback khi VNACCS down:
□ Lưu tờ khai ở trạng thái "Pending Submission"
□ Alert customs specialist + manager
□ Cho phép export tờ khai ra PDF để nộp thủ công
```

### Bước 5: Thiết kế Invoice & Packing List Generation

```
Documents phải generate được:

Commercial Invoice:
□ Seller & Buyer info (name, address, tax code)
□ Invoice number (auto-generate, unique)
□ Invoice date
□ Incoterm + Port of loading / Destination
□ Line items: Description, HS Code, Quantity, Unit, Unit price (USD/EUR/VND), Total
□ Total value, Freight value (nếu CIF), Insurance (nếu CIF)
□ Bank details (nếu T/T payment)
□ Authorized signature block

Packing List:
□ Linked to Invoice (same reference)
□ Line items: Description, Package type, Quantity, Gross weight, Net weight, Dimensions, CBM
□ Total packages, Gross weight, Net weight, CBM
□ Marks & Numbers (container/package identification)

Generation requirements:
□ Template editable (company logo, custom fields)
□ Export PDF + Excel
□ E-sign support (nếu cần)
□ Version control (mỗi lần chỉnh sửa → new version, giữ lịch sử)
```

### Bước 6: Thiết kế C/O (Certificate of Origin) Management

```
C/O types phổ biến tại Việt Nam:
□ Form D (ATIGA — ASEAN): Cơ quan cấp: VCCI / Bộ Công Thương
□ Form E (ACFTA — VN-China): Bộ Công Thương
□ EUR.1 (EVFTA — VN-EU): Bộ Công Thương
□ Form AK (AKFTA): Bộ Công Thương
□ Form RCEP: Bộ Công Thương / VCCI
□ Non-preferential C/O (Form B): VCCI

C/O Management workflow:
□ Link C/O với shipment và invoice cụ thể
□ Track C/O application status (Pending / Issued / Rejected)
□ Lưu scan bản gốc + số C/O
□ C/O expiry tracking (thường 12 tháng)
□ Alert khi C/O sắp hết hạn (30 ngày trước)
□ C/O số lượng sử dụng tracking (một C/O có thể dùng cho nhiều shipment cùng lô)
```

### Bước 7: Thiết kế Duty & Tax Calculation

```
READ: controls.md → Section 4: Incoterms 2020 (Cost allocation)

Duty calculation engine:

Import duty = Dutiable value × Import duty rate (%)
VAT          = (Dutiable value + Import duty) × VAT rate (%)
SCT          = Áp dụng nếu hàng thuộc danh mục SCT
Anti-dumping = Áp dụng nếu có quyết định chống bán phá giá

Dutiable value theo phương pháp:
□ Phương pháp 1 (Transaction value): Invoice value + Freight + Insurance (đến VN border)
□ Phương pháp 2-6: Backup khi method 1 không áp dụng được (do hải quan yêu cầu)
□ CIF value = Invoice value + Freight + Insurance (đến cảng nhập)

FTA rate selection:
□ Check xem C/O có hợp lệ không → áp dụng FTA rate
□ So sánh MFN vs FTA rate → gợi ý rate có lợi nhất
□ Log lý do chọn rate (audit trail)

Calculation phải:
□ Accuracy >99% (xem operations.md KPI: Duty accuracy target)
□ Auditable: Lưu input parameters + formula + output cho mỗi tính toán
□ Recalculate tự động khi HS Code hoặc invoice value thay đổi
□ Export chi tiết tính toán ra PDF (để trình hải quan nếu cần)
```

### Bước 8: Thiết kế Document Vault

```
READ: controls.md → Section 5: Document Retention Requirements

Documents cần lưu trữ:
□ Bill of Lading / Airway Bill (gốc + copy)
□ Commercial Invoice (mọi versions)
□ Packing List
□ Customs Declaration (VNACCS copy)
□ Certificate of Origin
□ Insurance Certificate
□ PoD / Delivery Receipt
□ Phytosanitary / Health certificate (nếu applicable)
□ Import/Export permit (nếu applicable)
□ MSDS (nếu dangerous goods)

Vault requirements:
□ Retention: Tối thiểu 5 năm, mặc định 7 năm (theo audit trail requirements)
□ Immutable: Không được xóa trong retention period
□ Searchable: Tìm theo shipment ID, declaration number, ngày, loại document
□ Access control: Customs Specialist full access; Coordinator view-only; Finance view-only customs docs
□ Download: PDF, original format
□ Physical archive flag: Đánh dấu document nào cần giữ bản gốc (BoL, C/O)
```

### Bước 9: Thiết kế Customs Status Tracking

```
Dashboard cho Customs Specialist:

View theo tờ khai:
□ Số tờ khai | Loại | Hàng hóa | Ngày nộp | Luồng | Trạng thái | SLA còn lại
□ Filter theo: luồng (Xanh/Vàng/Đỏ), trạng thái, ngày, customs specialist

Metrics:
□ Average clearance time (target <3 ngày — xem operations.md)
□ Inspection rate (target <10%)
□ Documentation accuracy (target >99%)
□ Tỷ lệ phân luồng Xanh/Vàng/Đỏ theo tuần

Alerts:
□ Yellow Channel: Cần nộp bổ sung docs trong 24h → alert customs specialist
□ Red Channel: Cần schedule physical inspection trong 48h → alert manager + customs specialist
□ Declaration pending quá SLA → escalate to manager
```

### Bước 10: Thiết kế Deferred Duty / Bonded Warehouse (nếu scope có)

```
Nếu dự án có bonded warehouse hoặc gia công xuất khẩu:

□ Bonded inventory: Track hàng nhập vào kho ngoại quan (chưa nộp thuế)
□ Usage tracking: Khi đưa ra sản xuất → trigger khai báo & nộp thuế
□ Balance: Tổng nhập - Tổng xuất dùng = Tồn kho ngoại quan
□ Periodic reconciliation: Đối chiếu với hải quan (thường quarterly)
□ Time limit: Hàng không được để quá thời hạn quy định (thường 12 tháng)
□ Alert khi hàng sắp quá hạn (30 ngày trước)
```

### Bước 11: Feature Spec Output

```markdown
# Feature Spec: Customs Declaration (XNK)

## Overview
[Mô tả module — scope, personas, business value]

## User Stories
- As a Customs Specialist, I want to...
- As a Logistics Coordinator, I want to...
- As a Finance team, I want to...

## Functional Requirements

### HS Code Management
REQ-LOG-HS-001: HS Code database với full-text search (Vietnamese + English)
REQ-LOG-HS-002: FTA preferential rates theo từng FTA agreement
REQ-LOG-HS-003: HS Code validation và history tracking

### Declaration Workflow
REQ-LOG-CUST-001: Import/Export declaration workflow (Draft → Submitted → Channel → Cleared)
REQ-LOG-CUST-002: VNACCS integration với retry và fallback
REQ-LOG-CUST-003: Red/Yellow/Green channel handling theo business rules

### Duty Calculation
REQ-LOG-CUST-004: Duty calculator (Import duty + VAT + SCT) với FTA rate selection
REQ-LOG-CUST-005: CIF value calculation theo Incoterm của shipment
REQ-LOG-CUST-006: Duty calculation audit trail (input + formula + output)

### Document Generation
REQ-LOG-DOC-001: Commercial Invoice generation (template-based, PDF + Excel)
REQ-LOG-DOC-002: Packing List generation linked với Invoice
REQ-LOG-DOC-003: Document versioning và e-sign support

### C/O Management
REQ-LOG-DOC-004: C/O application tracking (Form D, EUR.1, RCEP...)
REQ-LOG-DOC-005: C/O expiry alerts và usage tracking

### Document Vault
REQ-LOG-DOC-006: Immutable document vault 7-year retention
REQ-LOG-DOC-007: Document access control theo persona

### KPI Dashboard
REQ-LOG-KPI-002: Customs KPI (clearance time, inspection rate, doc accuracy)

## Data Model
[CustomsDeclaration, HSCode, DutyCalculation, Document, CO — field definitions]

## Non-functional Requirements
- Duty calculation accuracy: >99%
- VNACCS response handling: Timeout 30s → retry
- Document vault: Immutable, không xóa trong 7 năm
- Search performance: HS Code search < 1s cho 10,000+ codes
```

---

## Checklist trước khi submit

```
□ VNACCS integration đã thiết kế với đủ error handling + fallback
□ Red/Yellow/Green channel workflows đã define rõ
□ HS Code lookup có full-text search + history + validation
□ Duty calculation có audit trail đầy đủ
□ FTA rate selection có logic ưu tiên đúng
□ Document retention 5-7 năm đã noted trong data model
□ C/O management đã cover loại C/O phổ biến tại VN
□ Dangerous goods flag đã include nếu scope có hàng nguy hiểm
```
