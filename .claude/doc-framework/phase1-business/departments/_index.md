# Tổng Hợp Tài Liệu Phòng Ban — [TÊN DỰ ÁN]

> **Loại tài liệu:** Tổng hợp — Theo dõi tiến độ tài liệu tất cả phòng ban
> **Cập nhật bởi:** [Tên người phụ trách]
> **Ngày cập nhật:** [Ngày/Tháng/Năm]
>
> READS: `departments/[dept]/[dept].md`
> USED BY: `phase1-business/stakeholder-review.md`

---

## 1. Trạng Thái Tài Liệu Từng Phòng Ban

> Mỗi phòng ban có **1 folder riêng** chứa 1 tài liệu:
> - `[tên-phòng-ban]/[tên].md` — Phần A: Phòng ban CẦN gì (User Needs) + Phần B: LÀM VIỆC như thế nào (Workflow)
>
> Mỗi tài liệu gồm 2 phần: Phần A (User Needs, bao gồm A7 — đánh giá Team Expert) + Phần B (Workflow)
>
> **Cách thêm phòng ban:** Copy folder `[dept-name]/` → Đổi tên folder + đổi tên file bên trong
> VD: `[dept-name]/` → `sales/` → file: `sales.md`

| STT | Phòng ban | Folder | User Needs | Workflow | Trạng thái cuối |
|-----|-----------|--------|-----------|---------|----------------|
| 1 | [Tên PB 1] | `[dept-1]/` | ⬜ / 🔄 / ✅ | ⬜ / 🔄 / ✅ | Chưa bắt đầu / Đang làm / Đã xác nhận |
| 2 | [Tên PB 2] | `[dept-2]/` | ⬜ | ⬜ | Chưa bắt đầu |
| 3 | [Tên PB 3] | `[dept-3]/` | ⬜ | ⬜ | Chưa bắt đầu |

**Tiến độ tổng thể:**
```
User Needs hoàn thành:  [X] / [Tổng] phòng ban
Workflow hoàn thành:    [X] / [Tổng] phòng ban
Sẵn sàng cho review:   [X] / [Tổng] phòng ban
```

---

## 2. Tổng Hợp Nhu Cầu Người Dùng

> Sau khi tất cả P1-03 đã hoàn thành, tổng hợp toàn bộ nhu cầu vào bảng này.

| STT | Mã nhu cầu | Phòng ban | Tên nhu cầu | Mức độ ưu tiên | Ghi chú |
|-----|-----------|-----------|------------|---------------|---------|
| 1 | REQ-[PB]-001 | [Phòng ban] | [Tên nhu cầu] | Bắt buộc | |
| 2 | REQ-[PB]-002 | [Phòng ban] | [Tên nhu cầu] | Quan trọng | |
| 3 | REQ-[PB]-001 | [Phòng ban khác] | [Tên nhu cầu] | Bắt buộc | |

**Phân bố ưu tiên:**

| Mức độ | Số lượng | Tỷ lệ |
|--------|----------|-------|
| Bắt buộc | [Số] | [X%] |
| Quan trọng | [Số] | [X%] |
| Nên có | [Số] | [X%] |
| **Tổng** | **[Số]** | 100% |

---

## 3. Nhu Cầu Ưu Tiên Cao — Giai Đoạn 1

> Danh sách rút gọn — những nhu cầu BẮT BUỘC phải có ngay từ đầu.

| STT | Mã | Phòng ban | Nhu cầu | Lý do ưu tiên cao |
|-----|-----|-----------|---------|-------------------|
| 1 | REQ-[PB]-001 | [Phòng ban] | [Tên nhu cầu] | [VD: Nghiệp vụ cốt lõi] |
| 2 | REQ-[PB]-002 | [Phòng ban] | [Tên nhu cầu] | [VD: Pháp luật yêu cầu] |

---

## 4. Nhu Cầu Liên Phòng Ban

> Những nhu cầu được nhiều phòng ban cùng đề cập — cần thiết kế chung.

| Nhu cầu | Các phòng ban | Mã từ từng PB | Ghi chú |
|---------|--------------|-------------|---------|
| [VD: Quản lý thông tin KH] | [Sales, CSKH] | REQ-SALES-001, REQ-CSKH-003 | [Cần thiết kế module chung] |
| [VD: Báo cáo doanh số] | [Sales, Kế toán, Ban GĐ] | REQ-SALES-005, REQ-KT-004 | [Góc nhìn khác nhau cùng dữ liệu] |

---

## 5. Yêu Cầu Chất Lượng Chung (Phi Chức Năng)

> Tổng hợp từ tất cả phòng ban — những yêu cầu về chất lượng mà mọi người đều mong đợi.

| Tiêu chí | Yêu cầu | Mức độ quan trọng |
|----------|---------|------------------|
| Tốc độ | Hệ thống phản hồi nhanh, không phải chờ đợi lâu | Bắt buộc |
| Độ ổn định | Ít gián đoạn, không mất dữ liệu đang nhập | Bắt buộc |
| Dễ sử dụng | Nhân viên mới tự học cơ bản trong [X] ngày | Quan trọng |
| Bảo mật | Mỗi người chỉ thấy dữ liệu phù hợp quyền hạn | Bắt buộc |
| Truy cập | [Trình duyệt / Di động / Cả hai] | [Điền] |
| Lưu trữ | Dữ liệu lưu tối thiểu [X] năm | [Điền] |

---

## 6. Xác Nhận Hoàn Thành Tài Liệu Phòng Ban

> Checklist trước khi chuyển sang Stakeholder Review.

```
□ Tất cả [dept].md đã hoàn thành Phần A (User Needs) + Phần B (Workflow)
□ Bảng "Tổng Hợp Nhu Cầu" (mục 2) đã điền đầy đủ
□ Danh sách "Nhu Cầu Liên Phòng Ban" (mục 4) đã được xác định
□ Sẵn sàng chuyển cho stakeholder-review.md để review
```
