# [Tên Phân Tích] — [REQ-ID]

> **Domain Expert Template** — Dùng bởi domain experts (SALES, FINANCE, LEGAL, HR, LOGISTICS, OPERATIONS...)
> BA dùng `business-template.md` riêng. Domain experts dùng template này.
>
> **Structure:** Phần A (chung — mọi domain) + Phần B-[DOMAIN] (riêng theo lĩnh vực)
>
> **USED BY:** `sales-expert`, `finance-expert`, `legal-expert`, `hr-expert`, `logistics-expert`, `operations-expert`

## Tóm Tắt

[1-2 câu tóm tắt phát hiện chính — ngôn ngữ doanh nghiệp, không dùng thuật ngữ kỹ thuật]

---

## Phần A: Phân Tích Chung (Mọi Domain)

### A1. Bối Cảnh Nghiệp Vụ

- **Phòng ban:** [Tên phòng ban]
- **Phạm vi phân tích:** [Module / quy trình được phân tích]
- **REQ-IDs liên quan:** `REQ-[DEPT]-001`, `REQ-[DEPT]-002`...

### A2. Phát Hiện Chính

#### [Chủ đề 1 — VD: Quy trình hiện tại]
- Finding 1: [Mô tả cụ thể]
- Finding 2: [Mô tả cụ thể]

#### [Chủ đề 2 — VD: Điểm nghẽn / rủi ro]
- Finding 1: [Mô tả cụ thể]
- Finding 2: [Mô tả cụ thể]

### A3. Khuyến Nghị

| # | Khuyến nghị | Ưu tiên | REQ-ID liên quan |
|---|------------|---------|------------------|
| 1 | [Action item 1] | Bắt buộc / Quan trọng / Nên có | `REQ-XXX-001` |
| 2 | [Action item 2] | [Ưu tiên] | `REQ-XXX-002` |

### A4. Rủi Ro & Giả Định

- [Rủi ro 1 — VD: Dữ liệu lịch sử chưa đầy đủ]
- [Giả định 1 — VD: Giả định quy trình phê duyệt không thay đổi]
- [Ràng buộc 1 — VD: Phải tuân thủ quy định [X]]

---

## Phần B: Phân Tích Chuyên Sâu Theo Domain

> Domain expert chọn Phần B phù hợp với lĩnh vực của mình.
> Mỗi Phần B chứa domain-specific sections không có trong Phần A.

### Phần B-SALES: Phân Tích Bán Hàng

- **Pipeline & Quản lý Cơ hội:** [Phân tích sales pipeline, deal stages, forecast accuracy]
- **Báo giá & Chiết khấu:** [Quy trình báo giá, approval thresholds, discount matrix]
- **Hoa hồng & KPI:** [Cơ chế tính hoa hồng, sales targets, performance metrics]
- **CRM Integration:** [Touchpoints với marketing, customer service, logistics]

### Phần B-FINANCE: Phân Tích Tài Chính

- **Kế toán & Sổ cái:** [Chart of accounts, journal entries, period close]
- **Thanh toán & Công nợ:** [AP/AR workflows, payment terms, aging analysis]
- **Ngân sách & Dự toán:** [Budget planning, variance analysis, cost centers]
- **Tuân thủ & Audit:** [Tax compliance, audit trail, internal controls]

### Phần B-LEGAL: Phân Tích Pháp Lý

- **Quản lý Hợp đồng:** [Contract lifecycle, templates, approval workflows]
- **Tuân thủ Quy định:** [Regulatory requirements, compliance gaps, remediation]
- **Quản lý Rủi ro Pháp lý:** [Risk identification, mitigation strategies, liability]
- **Bảo vệ Dữ liệu:** [GDPR, data privacy, consent management]

### Phần B-HR: Phân Tích Nhân Sự

- **Tuyển dụng & Onboarding:** [Recruitment pipeline, onboarding checklist, probation]
- **Lương & Phúc lợi:** [Payroll calculation, benefits admin, tax withholding]
- **Đánh giá Hiệu suất:** [KPI/OKR framework, review cycles, promotion criteria]
- **Phát triển & Đào tạo:** [Training needs, skill matrix, career paths]

### Phần B-LOGISTICS: Phân Tích Logistics

- **Vận chuyển & Giao nhận:** [Shipping workflows, carrier management, tracking]
- **Kho bãi:** [Warehouse operations, inventory accuracy, picking/packing]
- **Hải quan & Xuất nhập khẩu:** [HS Code, customs declaration, compliance]
- **Chuỗi cung ứng:** [Supplier management, lead times, demand planning]

### Phần B-OPERATIONS: Phân Tích Vận Hành

- **Quản lý Tồn kho:** [Inventory tracking, reorder points, FIFO/LIFO]
- **Kiểm soát Chất lượng:** [QC processes, inspection workflows, non-conformance]
- **Sản xuất:** [Production planning, BOM management, capacity]
- **Mua sắm & Thu mua:** [Procurement workflows, vendor management, RFQ/PO]

---

## Xác Nhận

| Vai trò | Tên | Ngày |
|---------|-----|------|
| Domain Expert | [Tên] | [Ngày] |
| Business Analyst Review | [Tên] | [Ngày] |
