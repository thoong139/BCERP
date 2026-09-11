# [Tên Chính Sách] — [TÊN DỰ ÁN]

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** [Bán hàng / Nhân sự / Mua hàng / Kho / Tài chính / Vận hành / Khách hàng]
> **Ngày soạn:** [Ngày/Tháng/Năm]
> **Agent soạn thảo:** [VD: sales-expert / hr-expert / procurement-expert]
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách)
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design)

---

> ## Hướng Dẫn Sử Dụng File Này
>
> File này do **agent domain expert soạn thảo** dựa trên ngành nghề + thông tin đã khai thác từ P0-01.
> User chỉ cần **xác nhận Section 5** — chỉnh sửa những điểm không khớp với thực tế.
>
> *Xóa phần hướng dẫn này sau khi hoàn thành.*

---

## 1. Phạm Vi Áp Dụng

> Đối tượng, tình huống, điều kiện áp dụng chính sách này

- **Áp dụng cho:** [VD: Tất cả đơn hàng qua kênh online và offline]
- **Không áp dụng cho:** [VD: Đơn hàng nội bộ, đơn xuất khẩu]
- **Effective từ:** [Agent điền hoặc để trống]

---

## 2. Nội Dung Chính Sách

> Các quy tắc, mức, điều kiện cụ thể — phần cốt lõi nhất của tài liệu này

### 2.1. [Phần A — VD: Phân loại / Mức áp dụng]

[Agent điền nội dung — VD: Bảng giá 3 tiers, quy tắc theo volume, ...]

| [Tiêu chí] | [Mức 1] | [Mức 2] | [Mức 3] |
|-----------|---------|---------|---------|
| [Agent điền] | | | |

### 2.2. [Phần B — VD: Điều kiện / Quy trình]

[Agent điền — VD: Điều kiện để áp dụng chiết khấu, quy trình xét duyệt...]

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

> Các tình huống nằm ngoài quy tắc chung

- [VD: Khách hàng đặc biệt được duyệt riêng bởi Giám đốc]
- [VD: Trong tháng ra mắt sản phẩm — áp dụng chính sách ưu đãi đặc biệt]

---

## 4. Quy Trình Phê Duyệt

> Ai phê duyệt, điều kiện kích hoạt, thời hạn xử lý

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| [Agent điền] | [Agent điền] | [Agent điền] |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

> **🤖 Agent điền** — Những gì hệ thống phần mềm PHẢI làm để chính sách này hoạt động
> Đây là input trực tiếp cho `/wf-analyze-requirements` và `/wf-design`

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| [VD: Block submit nếu chưa có approval của người có thẩm quyền] | Validation | [Module] | MUST / SHOULD |
| [VD: Ghi audit log bất biến mọi thay đổi trạng thái] | Audit Trail | [Module] | MUST |
| [VD: Alert tự động khi ngưỡng bị vượt quá] | Notification | [Module] | SHOULD |
| [VD: Báo cáo định kỳ tự động theo policy] | Reporting | [Module] | NICE |

**Cross-policy dependencies:** [VD: Policy này phụ thuộc vào C-03 SoD — cần triển khai cùng lúc]

---

## 6. Xác Nhận

> **📝 User xác nhận** — Chính sách này có phản ánh đúng thực tế doanh nghiệp không?

| Nội dung | Xác nhận | Điều chỉnh cần thiết |
|---------|---------|---------------------|
| Phạm vi áp dụng | Đúng / Cần sửa | |
| Nội dung chính sách | Đúng / Cần sửa | |
| Ngoại lệ | Đúng / Cần sửa | |
| Quy trình phê duyệt | Đúng / Cần sửa | |
| Yêu cầu hệ thống | Đúng / Cần sửa | |

**Người xác nhận:** [Tên] — [Vai trò]
**Ngày:** [Ngày/Tháng/Năm]

---

## Lịch Sử Phiên Bản

> *Ghi chú: Template chính sách dùng tiêu đề tiếng Việt theo quy ước văn bản nghiệp vụ — khác với templates kỹ thuật dùng "Section X" format.*

| Phiên bản | Ngày | Người cập nhật | Thay đổi |
|-----------|------|----------------|---------|
| 1.0 | [Ngày] | [Agent soạn] | Khởi tạo |
