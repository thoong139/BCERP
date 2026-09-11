# [DEPARTMENT_NAME] — Phân Tích Nghiệp Vụ

> **Phòng ban:** [Tên phòng ban]
> **Ngày cập nhật:** [Ngày/Tháng/Năm]
> **Trạng thái:** Chưa bắt đầu → Đang phân tích → Hoàn thành
>
> READS: `P1-01-project-overview.md`, `P1-02-business-workflow.md`
> USED BY: `departments/_index.md`, `_meta/req-registry.json`, `phase2-features/[sys]/[mod]/[feat].md`

---

## Phần A: Nhu Cầu Người Dùng (User Needs)

### A1. Giới Thiệu Phòng Ban

**Phòng ban này làm gì:**

[Mô tả ngắn gọn vai trò và nhiệm vụ chính của phòng ban trong tổ chức.
VD: "Phòng Kinh doanh chịu trách nhiệm tìm kiếm khách hàng mới, duy trì quan hệ với khách
hàng hiện tại, và đạt chỉ tiêu doanh số theo tháng/quý/năm."]

**Những người sẽ dùng hệ thống:**

| Vai trò | Số lượng | Công việc hàng ngày | Cần hệ thống hỗ trợ gì |
|---------|----------|--------------------|-----------------------|
| [VD: Nhân viên kinh doanh] | [Số người] | [VD: Tìm kiếm, chăm sóc khách hàng] | [VD: Tra cứu nhanh, ghi chú liên hệ] |
| [VD: Trưởng phòng] | [Số người] | [VD: Theo dõi hiệu suất đội nhóm] | [VD: Xem báo cáo tổng hợp] |
| [VD: Ban lãnh đạo] | [Số người] | [VD: Ra quyết định kinh doanh] | [VD: Dashboard tổng quan, KPI] |

---

### A2. Tổng Hợp Nhu Cầu

> *Tổng quan trước khi đi vào chi tiết — giúp người đọc nắm bức tranh toàn cảnh.*

| STT | Mã nhu cầu | Tên nhu cầu | Mức độ ưu tiên |
|-----|-----------|------------|---------------|
| 1 | REQ-[DEPT]-001 | [Tên nhu cầu 1] | Bắt buộc |
| 2 | REQ-[DEPT]-002 | [Tên nhu cầu 2] | Bắt buộc |
| 3 | REQ-[DEPT]-003 | [Tên nhu cầu 3] | Quan trọng |
| 4 | REQ-[DEPT]-004 | [Tên nhu cầu 4] | Nên có |

> **Giải thích mức độ ưu tiên:**
> - **Bắt buộc:** Không có thì không thể vận hành — phải có trong giai đoạn đầu
> - **Quan trọng:** Cần thiết nhưng có thể dùng cách thủ công tạm thời
> - **Nên có:** Giúp làm việc tốt hơn, có thể làm ở giai đoạn sau

---

### A3. Chi Tiết Từng Nhu Cầu

---

#### REQ-[DEPT]-001: [Tên nhu cầu — VD: Quản lý danh sách khách hàng]

**Mức độ ưu tiên:** Bắt buộc / Quan trọng / Nên có

**Ai cần dùng:** [Nhóm người dùng — VD: Nhân viên kinh doanh, Trưởng phòng]

**Tôi cần hệ thống làm được:**

- [ ] [Điều 1 — VD: Tìm kiếm khách hàng theo tên, số điện thoại, email]
- [ ] [Điều 2 — VD: Xem toàn bộ lịch sử liên hệ với từng khách hàng]
- [ ] [Điều 3 — VD: Phân loại khách hàng theo nhóm / trạng thái / tiềm năng]
- [ ] [Điều 4 — VD: Xuất danh sách khách hàng ra Excel để báo cáo]

**Quy tắc nghiệp vụ phải tuân theo:**

- [Quy tắc 1 — VD: Mỗi khách hàng chỉ được phụ trách bởi 1 nhân viên]
- [Quy tắc 2 — VD: Chỉ Trưởng phòng mới được xem khách hàng của toàn đội]
- [Quy tắc 3 — VD: Khi thêm khách hàng mới, bắt buộc nhập số điện thoại]

**Tình huống đặc biệt cần xử lý:**

- [VD: Khách hàng doanh nghiệp có nhiều người liên hệ → cần lưu nhiều đầu mối]
- [VD: Nhân viên nghỉ việc → cần chuyển toàn bộ khách hàng sang người khác]
- [VD: Khách hàng trùng lặp → cần cách phát hiện và gộp]

---

#### REQ-[DEPT]-002: [Tên nhu cầu]

**Mức độ ưu tiên:** Bắt buộc / Quan trọng / Nên có

**Ai cần dùng:** [Nhóm người dùng]

**Tôi cần hệ thống làm được:**

- [ ] [Điều 1]
- [ ] [Điều 2]
- [ ] [Điều 3]

**Quy tắc nghiệp vụ phải tuân theo:**

- [Quy tắc 1]
- [Quy tắc 2]

**Tình huống đặc biệt cần xử lý:**

- [Tình huống 1]
- [Tình huống 2]

---

#### REQ-[DEPT]-003: [Tên nhu cầu]

*(Tiếp tục thêm REQ-[DEPT]-004, 005... theo format trên)*

---

### A4. Dữ Liệu Phòng Ban Cần Quản Lý

> *Liệt kê những loại thông tin mà phòng ban cần hệ thống lưu trữ.*

| STT | Loại dữ liệu | Thông tin cần lưu | Ghi chú quan trọng |
|-----|-------------|------------------|--------------------|
| 1 | [VD: Khách hàng] | [Tên, SĐT, email, địa chỉ, ngành nghề] | [Email không được trùng lặp] |
| 2 | [VD: Hợp đồng] | [Số HĐ, giá trị, ngày ký, ngày hết hạn] | [Lưu kèm file scan] |
| 3 | [VD: Báo giá] | [Danh sách sản phẩm, đơn giá, chiết khấu] | [Cho phép nhiều phiên bản] |

---

### A5. Báo Cáo & Thống Kê Cần Có

| STT | Tên báo cáo | Nội dung hiển thị | Tần suất xem | Người xem |
|-----|------------|-------------------|-------------|-----------|
| 1 | [Tên BC 1] | [Báo cáo này cho biết gì] | Hàng ngày / Tuần / Tháng | [Ai xem] |
| 2 | [Tên BC 2] | [Nội dung] | [Tần suất] | [Ai xem] |

---

### A6. Điều Phòng Ban KHÔNG Muốn

> *Những điều phòng ban KHÔNG muốn hệ thống thay đổi hoặc ảnh hưởng.*

- [VD: Không muốn thay đổi quy trình phê duyệt báo giá hiện tại]
- [VD: Không muốn nhân viên cấp dưới thấy được mức hoa hồng của nhau]
- [VD: Không muốn mất dữ liệu lịch sử từ hệ thống cũ]

---

### A7. Đánh Giá Của Team Expert

*Team Expert điền phần này sau khi đọc và đánh giá Phần A*

#### A7.1 Kết Quả Đánh Giá Tổng Thể

| Hạng mục | Kết quả | Ghi chú |
|----------|---------|---------|
| Mức độ đầy đủ | Đầy đủ / Cần bổ sung / Thiếu nhiều | [Ghi chú] |
| Tính khả thi | Khả thi / Cần thảo luận / Không khả thi | [Ghi chú] |
| Độ rõ ràng | Rõ ràng / Còn mơ hồ cần làm rõ | [Ghi chú] |
| Trùng lặp với PB khác | Không có / Có — cần hợp nhất | [Ghi chú] |

---

#### A7.2 Các Điểm Cần Làm Rõ / Bổ Sung

| # | Điểm cần làm rõ | Liên quan đến | Hành động | Trạng thái |
|---|----------------|--------------|-----------|-----------|
| 1 | [Câu hỏi hoặc điểm mơ hồ] | REQ-[DEPT]-[XXX] | Hỏi lại phòng ban / Tự điều chỉnh | Chờ / Đã xử lý |
| 2 | [Câu hỏi tiếp theo] | REQ-[DEPT]-[XXX] | [Hành động] | [Trạng thái] |

---

#### A7.3 Điều Chỉnh Sau Đánh Giá

| Điều chỉnh | Lý do | Người thực hiện |
|-----------|-------|----------------|
| [VD: Bổ sung quy tắc nghiệp vụ cho REQ-[DEPT]-002] | [Phòng ban bỏ sót, Expert bổ sung] | [Tên Expert] |
| [VD: Tách REQ-[DEPT]-003 thành 2 nhu cầu riêng] | [Quá rộng, cần tách để rõ ràng] | [Tên Expert] |

---

#### A7.4 Kết Luận & Xác Nhận

**Kết luận:** [Tài liệu đủ để chuyển sang Phase 2 / Cần bổ sung thêm trước khi chuyển]

**Ký xác nhận:**

| Vai trò | Tên | Ngày xác nhận |
|---------|-----|--------------|
| Expert phụ trách viết | [Tên] | [Ngày] |
| Team Expert review | [Tên] | [Ngày] |
| Đại diện phòng ban (nếu có) | [Tên] | [Ngày] |

---

## Phần B: Quy Trình Nghiệp Vụ (Workflow)

### B1. Tổng Quan Quy Trình

> *Liệt kê tất cả quy trình chính mà phòng ban thực hiện hàng ngày.*

| STT | Tên quy trình | Mô tả ngắn | Tần suất | Mức độ quan trọng |
|-----|-------------|------------|----------|------------------|
| 1 | [VD: Tiếp nhận đơn hàng] | [VD: Nhận yêu cầu từ khách, tạo đơn] | Hàng ngày | Cốt lõi |
| 2 | [VD: Xử lý thanh toán] | [VD: Ghi nhận tiền, đối chiếu] | Hàng ngày | Cốt lõi |
| 3 | [VD: Báo cáo cuối tháng] | [VD: Tổng hợp số liệu tháng] | Hàng tháng | Quan trọng |

---

### B2. Chi Tiết Quy Trình

---

#### Quy trình 1: [Tên quy trình — VD: Tiếp nhận và xử lý đơn hàng]

**Mục đích:** [Quy trình này phục vụ mục đích gì — VD: "Đảm bảo mọi đơn hàng được tiếp nhận, xác nhận và chuyển đi xử lý đúng thời hạn"]

**Người tham gia:**

| Vai trò | Ai | Trách nhiệm trong quy trình |
|---------|-----|---------------------------|
| Người thực hiện chính | [VD: Nhân viên sales] | [VD: Nhận yêu cầu, tạo đơn] |
| Người phê duyệt | [VD: Trưởng phòng] | [VD: Duyệt đơn trên X triệu] |
| Người nhận kết quả | [VD: Phòng Kho vận] | [VD: Nhận đơn đã duyệt để xuất hàng] |

##### Quy trình hiện tại (AS-IS)

> *Mô tả cách phòng ban đang làm việc HIỆN TẠI — trước khi có hệ thống mới.*

```
Bước 1: [Ai] làm [gì] — dùng [công cụ: Excel / email / điện thoại / giấy...]
    |
    v
Bước 2: [Ai] nhận thông tin → làm [gì]
    |
    v
Bước 3: [Kiểm tra điều kiện]
    |--- Nếu [A] → làm [X]
    |--- Nếu [B] → làm [Y]
    |
    v
Bước 4: Kết thúc khi [điều kiện gì]
```

**Vấn đề hiện tại:**

| Bước | Vấn đề | Hậu quả | Mức độ nghiêm trọng |
|------|--------|---------|---------------------|
| [Bước X] | [VD: Phải nhập lại thông tin từ email sang Excel] | [VD: Mất 30 phút/ngày, hay sai] | Cao / Trung bình / Thấp |
| [Bước Y] | [VD: Không biết đơn đang ở bước nào] | [VD: Khách hỏi không trả lời được] | Cao |

##### Quy trình mong muốn (TO-BE)

> *Mô tả cách phòng ban MUỐN làm việc SAU KHI có hệ thống — so sánh với AS-IS.*

```
Bước 1: [Ai] làm [gì] TRÊN HỆ THỐNG — thay vì [công cụ cũ]
    |
    v
Bước 2: Hệ thống tự động [làm gì] — KHÔNG CẦN làm thủ công nữa
    |
    v
Bước 3: [Kiểm tra] → Hệ thống tự [X], hoặc thông báo để [Ai] xử lý [Y]
    |
    v
Bước 4: Kết thúc — nhanh hơn [X phút/giờ] so với hiện tại
```

**Kết quả mong đợi:**

| Chỉ số | Hiện tại | Mong đợi |
|--------|---------|----------|
| [VD: Thời gian xử lý 1 đơn] | [VD: 30 phút] | [VD: 5 phút] |
| [VD: Tỷ lệ sai sót] | [VD: 5-10%] | [VD: < 1%] |
| [VD: Thông tin chuyển giao] | [VD: Qua email, hay lạc] | [VD: Tự động, không mất] |

---

#### Quy trình 2: [Tên quy trình]

**Mục đích:** [Mô tả mục đích]

**Người tham gia:**

| Vai trò | Ai | Trách nhiệm trong quy trình |
|---------|-----|---------------------------|
| Người thực hiện chính | [Tên vai trò] | [Trách nhiệm] |
| Người phê duyệt | [Tên vai trò] | [Khi nào cần duyệt] |

##### Quy trình hiện tại (AS-IS)

```
[Vẽ luồng — Điền theo thực tế]
```

**Vấn đề hiện tại:**

| Bước | Vấn đề | Hậu quả | Mức độ |
|------|--------|---------|--------|
| [Bước] | [Vấn đề] | [Hậu quả] | [Mức độ] |

##### Quy trình mong muốn (TO-BE)

```
[Vẽ luồng — Điền theo thực tế]
```

---

*(Thêm Quy trình 3, 4... theo format trên)*

---

### B3. Quy Trình Phê Duyệt

> *Liệt kê các điểm cần phê duyệt trong phòng ban — ai duyệt gì, theo ngưỡng nào.*

| Loại quyết định | Ai duyệt | Điều kiện / Ngưỡng | Thời gian duyệt mong đợi |
|----------------|---------|-------------------|--------------------------|
| [VD: Báo giá cho khách] | [Trưởng phòng] | [Tất cả báo giá] | [Trong ngày] |
| [VD: Chiết khấu đặc biệt] | [Giám đốc] | [Chiết khấu > 15%] | [1 ngày làm việc] |
| [VD: Tạo đơn hàng] | [Nhân viên tự duyệt] | [Đơn < 10 triệu] | [Ngay lập tức] |
| [VD: Tạo đơn hàng] | [Trưởng phòng] | [Đơn >= 10 triệu] | [Trong ngày] |

---

### B4. Ngoại Lệ & Tình Huống Đặc Biệt

> *Những tình huống không theo quy trình chuẩn — phòng ban xử lý thế nào.*

| STT | Tình huống | Xảy ra khi nào | Cách xử lý hiện tại | Người quyết định |
|-----|-----------|---------------|---------------------|-----------------|
| 1 | [VD: Khách hàng hủy đơn] | [Sau khi đã xuất kho] | [Gọi kho dừng giao, nhập lại] | [Trưởng phòng] |
| 2 | [VD: Nhân viên nghỉ đột xuất] | [Có deal đang xử lý] | [Trưởng phòng phân công lại] | [Trưởng phòng] |
| 3 | [VD: Hệ thống cũ bị lỗi] | [Không truy cập được dữ liệu] | [Dùng bản backup Excel] | [Trưởng phòng + IT] |

---

### B5. Điểm Tiếp Xúc Với Phòng Ban Khác

> *Tập trung vào luồng dữ liệu giữa phòng ban này với các phòng ban khác.*

| Từ / Đến | Phòng ban | Loại thông tin | Tần suất | Phương tiện hiện tại | Vấn đề |
|----------|-----------|---------------|----------|---------------------|--------|
| Gửi đi → | [Kho vận] | [Đơn hàng đã xác nhận] | Hàng ngày | [Email] | [Chậm, thiếu thông tin] |
| Nhận về ← | [Kho vận] | [Trạng thái giao hàng] | Hàng ngày | [Chat Zalo] | [Không lưu vết] |
| Gửi đi → | [Kế toán] | [Yêu cầu xuất hóa đơn] | Hàng ngày | [Giấy] | [Mất phiếu] |
| Nhận về ← | [Kế toán] | [Xác nhận thanh toán] | Hàng tuần | [Email] | [Chậm 1-2 ngày] |
