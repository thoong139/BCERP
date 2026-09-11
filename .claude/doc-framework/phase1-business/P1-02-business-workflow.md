# Quy Trình Kinh Doanh Tổng Thể — [TÊN DỰ ÁN]

> **Loại tài liệu:** Mô hình kinh doanh — Toàn bộ luồng vận hành từ đầu đến cuối
> **Cập nhật bởi:** [Tên người phụ trách]
> **Ngày cập nhật:** [Ngày/Tháng/Năm]
> **Trạng thái:** Bản nháp → Đang đánh giá → Đã xác nhận
>
> READS: `phase0-brainstorm/P0-01-brainstorm.md`, `P1-01-project-overview.md`
> USED BY: `departments/[dept]/[dept].md`, `phase2-features/[sys]/[mod]/[feat].md`

---

> ## Hướng Dẫn Sử Dụng File Này
>
> File này mô tả **toàn bộ mô hình kinh doanh** của tổ chức — cách doanh nghiệp hoạt động
> từ đầu đến cuối, không phải góc nhìn kỹ thuật.
>
> **Ai viết:** Người hiểu rõ nhất mô hình kinh doanh (CEO, COO, BA, hoặc Quản lý dự án)
> **Viết cho ai:** Tất cả thành viên dự án — để mọi người cùng hiểu "doanh nghiệp này vận hành ra sao"
>
> *Xóa phần hướng dẫn này sau khi hoàn thành.*

---

## 1. Mô Hình Kinh Doanh

> *Mô tả ngắn gọn doanh nghiệp kiếm tiền bằng cách nào, phục vụ ai, thông qua kênh nào.*

**Loại hình kinh doanh:**

[VD: Sản xuất & phân phối / Dịch vụ / Thương mại điện tử / B2B SaaS / ...]

**Sản phẩm / Dịch vụ chính:**

| STT | Sản phẩm / Dịch vụ | Mô tả ngắn | Đối tượng khách hàng |
|-----|--------------------|-----------|--------------------|
| 1 | [Tên SP/DV 1] | [Mô tả] | [Ai mua / ai sử dụng] |
| 2 | [Tên SP/DV 2] | [Mô tả] | [Ai mua / ai sử dụng] |

---

## 2. Các Bộ Phận Tham Gia

> *Liệt kê các phòng ban / bộ phận tham gia vào quy trình kinh doanh.*

| STT | Phòng ban | Vai trò chính trong kinh doanh | Số người ước tính |
|-----|-----------|-------------------------------|------------------|
| 1 | [Tên phòng ban 1] | [Vai trò — VD: Tìm kiếm khách hàng, chốt đơn] | [Số] |
| 2 | [Tên phòng ban 2] | [Vai trò — VD: Xuất hóa đơn, thu tiền] | [Số] |
| 3 | [Tên phòng ban 3] | [Vai trò — VD: Nhập kho, xuất hàng, giao nhận] | [Số] |

---

## 3. Luồng Kinh Doanh Chính (End-to-End)

> **Mapping yêu cầu:** Mỗi luồng trong Mục 3 PHẢI được tham chiếu ít nhất 1 lần trong Mục 4 (Handoff Points). Mỗi hàng Mục 4 PHẢI ghi rõ bước cụ thể trong Mục 3 mà nó áp dụng (format: "Luồng [X], Bước [Y]").

> *Mô tả luồng vận hành chính của doanh nghiệp — từ khi tiếp cận khách hàng đến khi hoàn tất giao dịch.*
> *Đây là "con đường tiền đi" — money flow — của doanh nghiệp.*

> **Naming format:** `Luồng [N]: [Tên mô tả]` — VD: "Luồng 1: Bán hàng từ tiếp cận đến thu tiền". Mỗi luồng được tham chiếu trong Mục 4 theo format "Luồng 1, Bước 2". Không dùng FLOW-ID cho văn bản nghiệp vụ.

### 3.1. Luồng chính: [Tên luồng — VD: Bán hàng từ tiếp cận đến thu tiền]

```
[Vẽ luồng bằng text — VD:]

Khách hàng liên hệ / Nhân viên sales tiếp cận
    |
    v
Tư vấn sản phẩm → Gửi báo giá
    |
    v
Khách đồng ý → Tạo đơn hàng
    |
    v
[Có hàng trong kho?]
    |--- Có --→ Xuất kho → Đóng gói → Giao hàng
    |               |
    |               v
    |          Khách nhận hàng → Xác nhận
    |               |
    |               v
    |          Kế toán xuất hóa đơn → Gửi khách
    |               |
    |               v
    |          Khách thanh toán → Ghi nhận doanh thu
    |
    |--- Không → Đặt hàng nhà cung cấp → Nhập kho → [quay lại "Xuất kho"]
```

**Các phòng ban tham gia trong luồng này:**

| Bước | Phòng ban thực hiện | Công việc cụ thể |
|------|--------------------|-----------------|
| Tư vấn & báo giá | [Phòng Sales] | [Tư vấn, tạo báo giá, theo dõi] |
| Tạo đơn hàng | [Phòng Sales] | [Nhập đơn, xác nhận với khách] |
| Xuất kho & giao hàng | [Phòng Kho vận] | [Kiểm hàng, đóng gói, giao] |
| Hóa đơn & thu tiền | [Phòng Kế toán] | [Xuất hóa đơn, theo dõi thanh toán] |
| Hỗ trợ sau bán | [Phòng CSKH] | [Xử lý khiếu nại, đổi trả] |

---

### 3.2. Luồng phụ: [Tên luồng — VD: Mua hàng / Nhập kho]

```
[Vẽ luồng — Điền theo thực tế:]

Kho báo hết hàng / Tới mức tồn kho tối thiểu
    |
    v
Phòng Mua hàng → Liên hệ nhà cung cấp → Đàm phán giá
    |
    v
Tạo đơn mua hàng (PO) → Phê duyệt
    |
    v
Nhà cung cấp giao hàng → Kiểm tra chất lượng
    |
    v
Nhập kho → Cập nhật tồn kho
    |
    v
Kế toán ghi nhận công nợ → Thanh toán theo kỳ hạn
```

---

### 3.3. Luồng phụ: [Tên luồng — VD: Đổi trả / Hoàn tiền]

```
[Vẽ luồng — Điền theo thực tế]
```

---

*(Thêm luồng 3.4, 3.5... nếu doanh nghiệp có nhiều luồng kinh doanh)*

---

## 4. Các Điểm Chuyển Giao Giữa Phòng Ban

> *Liệt kê những điểm mà dữ liệu / công việc được chuyển từ phòng ban này sang phòng ban khác.*
> *Đây là những điểm dễ xảy ra sai sót, mất thông tin, hoặc chậm trễ nhất.*

| STT | Từ phòng ban | Sang phòng ban | Nội dung chuyển giao | Cách thực hiện hiện tại | Vấn đề thường gặp |
|-----|-------------|---------------|---------------------|------------------------|-------------------|
| 1 | [Sales] | [Kho vận] | [Đơn hàng đã xác nhận] | [Email / Excel / Giấy] | [Chậm, thiếu thông tin] |
| 2 | [Sales] | [Kế toán] | [Thông tin hóa đơn] | [Gọi điện / Chat] | [Sai số liệu, trùng lặp] |
| 3 | [Kho vận] | [Kế toán] | [Phiếu xuất kho] | [Giấy] | [Mất phiếu, không đối chiếu được] |
| 4 | [CSKH] | [Kho vận] | [Yêu cầu đổi trả] | [Email] | [Không theo dõi được trạng thái] |

---

## 5. Các Bên Liên Quan Bên Ngoài

> *Liệt kê các đối tác, nhà cung cấp, cơ quan bên ngoài mà doanh nghiệp tương tác thường xuyên.*

| STT | Bên ngoài | Loại quan hệ | Tương tác chính | Tần suất |
|-----|-----------|-------------|-----------------|----------|
| 1 | [VD: Nhà cung cấp A, B, C] | Cung ứng hàng hóa | [Đặt hàng, nhận hàng, thanh toán] | [Hàng tuần] |
| 2 | [VD: Đơn vị vận chuyển] | Giao nhận | [Giao hàng cho khách] | [Hàng ngày] |
| 3 | [VD: Ngân hàng] | Tài chính | [Thanh toán, sao kê] | [Hàng ngày] |
| 4 | [VD: Cơ quan thuế] | Pháp lý | [Kê khai, nộp thuế] | [Hàng tháng] |
| 5 | [VD: Nhà cung cấp E-Invoice] | Hóa đơn điện tử | [Xuất hóa đơn] | [Hàng ngày] |

---

## 6. Chỉ Số Kinh Doanh Quan Trọng (KPIs)

> *Liệt kê những số liệu mà Ban lãnh đạo quan tâm nhất — hệ thống cần hỗ trợ theo dõi.*

| STT | Chỉ số | Ý nghĩa | Ai theo dõi | Tần suất xem |
|-----|--------|---------|-------------|--------------|
| 1 | [VD: Doanh thu] | [Tổng tiền bán hàng theo ngày/tháng/quý] | [Ban GĐ, Sales] | [Hàng ngày] |
| 2 | [VD: Số đơn hàng mới] | [Số đơn tạo mới trong kỳ] | [Sales] | [Hàng ngày] |
| 3 | [VD: Công nợ phải thu] | [Tổng tiền khách chưa thanh toán] | [Kế toán, Ban GĐ] | [Hàng tuần] |
| 4 | [VD: Tồn kho] | [Giá trị hàng tồn / Số lượng theo SKU] | [Kho vận, Mua hàng] | [Hàng ngày] |
| 5 | [VD: Tỷ lệ đổi trả] | [% đơn bị trả / tổng đơn giao] | [CSKH, Ban GĐ] | [Hàng tháng] |

---

## 7. Quy Định & Ràng Buộc Kinh Doanh

> *Những quy định pháp luật hoặc nội bộ mà hệ thống phải tuân thủ.*

| STT | Quy định | Mô tả | Ảnh hưởng đến |
|-----|----------|-------|---------------|
| 1 | [VD: Hóa đơn điện tử] | [Bắt buộc xuất hóa đơn điện tử theo Nghị định 123/2020] | [Kế toán, Sales] |
| 2 | [VD: Kê khai thuế VAT] | [Hàng tháng theo mẫu 01/GTGT] | [Kế toán] |
| 3 | [VD: Bảo mật thông tin KH] | [Không chia sẻ dữ liệu khách ra ngoài] | [Toàn công ty] |

---

**Lưu ý:** Tài liệu này mô tả **mô hình kinh doanh thực tế** — không phải thiết kế kỹ thuật.
Nội dung sẽ được dùng làm căn cứ để Team Kỹ thuật thiết kế hệ thống trong Phase 2.
