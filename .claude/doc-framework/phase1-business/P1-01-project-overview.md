# Tổng Quan Dự Án — [TÊN DỰ ÁN]

> **Loại tài liệu:** Tổng quan — Mọi thành viên dự án đều cần đọc
> **Cập nhật bởi:** [Tên người phụ trách]
> **Ngày cập nhật:** [Ngày/Tháng/Năm]
>
> READS: `phase0-brainstorm/P0-01-brainstorm.md`, `phase0-brainstorm/P0-02-systems-users.md`
> USED BY: `P1-02-business-workflow.md`, `departments/[dept]/[dept].md`, `_meta/req-registry.json`

---

## 1. Thông Tin Chung

| Thông tin | Nội dung |
|-----------|---------|
| Tên dự án | [Tên đầy đủ của dự án] |
| Mục tiêu | [1-2 câu mô tả dự án xây dựng để làm gì, phục vụ ai] |
| Phạm vi | [Dự án này bao gồm những gì, áp dụng cho đơn vị/tổ chức nào] |
| Thời gian | [Ngày bắt đầu] → [Ngày dự kiến hoàn thành] |
| Trạng thái | Đang lên kế hoạch / Đang phát triển / Đã vận hành |
| Đơn vị chủ quản | [Tên công ty / tổ chức] |
| Người phụ trách | [Tên] — [Chức vụ] |

---

## 2. Bối Cảnh & Lý Do Thực Hiện

> *Mô tả tình hình hiện tại và lý do dự án này cần được triển khai.*

**Tình hình hiện tại:**

[Mô tả ngắn gọn những khó khăn, bất cập hoặc cơ hội mà tổ chức đang gặp phải. Ví dụ: quy trình thủ công tốn nhiều thời gian, dữ liệu không đồng bộ giữa các phòng ban, khó theo dõi hiệu quả kinh doanh...]

**Dự án này sẽ giải quyết:**

- [Vấn đề 1 được giải quyết như thế nào]
- [Vấn đề 2 được giải quyết như thế nào]
- [Vấn đề 3 được giải quyết như thế nào]

---

## 3. Mục Tiêu Dự Án

**Mục tiêu chính:**

[Viết 1-2 câu mô tả rõ nhất mục tiêu cốt lõi. Ví dụ: "Xây dựng hệ thống quản lý bán hàng tập trung, giúp đội ngũ sales theo dõi cơ hội kinh doanh và ban lãnh đạo nắm bắt hiệu quả kinh doanh theo thời gian thực."]

**Kết quả mong đợi:**

| Kết quả cụ thể | Cách đo lường | Mốc thời gian |
|----------------|--------------|--------------|
| [Kết quả 1] | [VD: giảm X%, tiết kiệm Y giờ/tuần] | [Sau bao lâu kể từ triển khai] |
| [Kết quả 2] | [Đo bằng gì] | [Sau bao lâu] |
| [Kết quả 3] | [Đo bằng gì] | [Sau bao lâu] |

---

## 4. Phạm Vi Hệ Thống

> *Liệt kê các nhóm chức năng / phân hệ sẽ được xây dựng.*

**Bao gồm trong dự án:**

| STT | Phân hệ / Nhóm chức năng | Mô tả ngắn | Giai đoạn |
|-----|--------------------------|-----------|-----------|
| 1 | [Tên phân hệ 1] | [Phân hệ này quản lý / xử lý cái gì] | Giai đoạn 1 |
| 2 | [Tên phân hệ 2] | [Phân hệ này quản lý / xử lý cái gì] | Giai đoạn 1 |
| 3 | [Tên phân hệ 3] | [Phân hệ này quản lý / xử lý cái gì] | Giai đoạn 2 |

**Không bao gồm trong dự án này:**

- [Chức năng nào không làm — lý do hoặc sẽ làm giai đoạn sau]
- [Ví dụ: Ứng dụng di động — dự kiến giai đoạn 3]
- [Ví dụ: Tích hợp phần mềm kế toán hiện tại — ngoài phạm vi hợp đồng]

---

## 5. Đối Tượng Sử Dụng

> *Liệt kê các nhóm người sẽ sử dụng hệ thống.*

| STT | Nhóm người dùng | Họ là ai | Họ dùng hệ thống để làm gì |
|-----|----------------|---------|--------------------------|
| 1 | [Tên nhóm 1] | [VD: Nhân viên kinh doanh] | [Công việc hàng ngày trên hệ thống] |
| 2 | [Tên nhóm 2] | [VD: Trưởng phòng] | [Công việc họ sẽ làm] |
| 3 | [Tên nhóm 3] | [VD: Ban Giám đốc] | [VD: Xem báo cáo, theo dõi KPI] |
| 4 | Quản trị hệ thống | Bộ phận IT / Vận hành | Quản lý tài khoản, cấu hình hệ thống |

---

## 6. Phối Hợp Giữa Các Phân Hệ

> *Mô tả cách các phân hệ làm việc cùng nhau trong nghiệp vụ thực tế.*

[Ví dụ — Điền luồng thực tế của dự án:]

```
Khi nhân viên sales chốt được một hợp đồng:
  Phân hệ Bán hàng  →  tự động chuyển thông tin sang  →  Phân hệ Kế toán
  Phân hệ Kế toán   →  xuất hóa đơn  →  gửi cho khách hàng
  Phân hệ Báo cáo   →  cập nhật doanh số  →  Ban lãnh đạo xem ngay
```

---

## 7. Giới Hạn & Giả Định

**Những điều đã xác định (không thay đổi):**

- [VD: Hệ thống chạy trên trình duyệt web, không cần cài đặt phần mềm]
- [VD: Ngôn ngữ giao diện là Tiếng Việt]
- [VD: Dữ liệu lưu trữ trên server nội bộ công ty]

**Những điều đang được giả định:**

- [VD: Người dùng có kết nối internet khi làm việc]
- [VD: Mỗi nhân viên có 1 tài khoản riêng]
- [VD: Dữ liệu lịch sử sẽ được nhập tay trong giai đoạn đầu]

---

## 8. Các Bên Liên Quan

| Vai trò | Tên / Bộ phận | Trách nhiệm trong dự án |
|---------|--------------|------------------------|
| Chủ dự án (Sponsor) | [Tên] | Phê duyệt ngân sách, quyết định cuối cùng |
| Đại diện nghiệp vụ | [Tên / Phòng ban] | Cung cấp yêu cầu, xác nhận nghiệm thu |
| Quản lý dự án | [Tên] | Điều phối tiến độ, báo cáo |
| Đội phát triển | [Tên nhóm / Công ty] | Thiết kế và xây dựng hệ thống |
| [Bên liên quan khác] | [Tên] | [Trách nhiệm] |

---

## 9. Yêu Cầu Chất Lượng Tổng Thể

| Tiêu chí | Yêu cầu |
|----------|---------|
| Tốc độ | Hệ thống phản hồi nhanh, không để người dùng chờ quá [X] giây |
| Độ ổn định | Hệ thống hoạt động liên tục, ít gián đoạn |
| Bảo mật | Chỉ người có tài khoản mới truy cập được; phân quyền rõ ràng theo vai trò |
| Dễ sử dụng | Nhân viên mới có thể thao tác cơ bản sau [X] giờ hướng dẫn |
| Lưu trữ dữ liệu | Lưu trữ dữ liệu tối thiểu [X] năm |
