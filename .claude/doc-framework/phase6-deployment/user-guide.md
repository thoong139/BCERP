# User Guide — [TÊN DỰ ÁN]

> Hướng dẫn sử dụng hệ thống cho người dùng cuối.
>
> READS: `phase1-business/P1-01-project-overview.md`, `phase1-business/P1-02-business-workflow.md`, `phase1-business/departments/[dept]/[dept].md`, `phase2-features/[sys]/[mod]/[feat].md`, `phase4-ux/[sys]/[mod]/[screen-group].md` (chỉ nếu interface_type != api-only), `phase5-implementation/P5-00-implementation-roadmap.md`, `deployment-guide.md`
> USED BY: `phase6-deployment/stakeholder-review.md`
> DATE: YYYY-MM-DD | VERSION: v[X.Y]

---

## 1. Tổng Quan Hệ Thống

**[PROJECT_NAME]** là hệ thống [mô tả ngắn 1-2 câu].

| Thông tin | Chi tiết |
|-----------|---------|
| URL truy cập | `https://[domain]` |
| Trình duyệt hỗ trợ | Chrome, Edge (phiên bản mới nhất) |
| Màn hình tối thiểu | 1280 × 768px |
| Kết nối | Internet ổn định |

---

## 2. Đăng Nhập / Đăng Xuất

### Đăng nhập
```
1. Truy cập https://[domain]
2. Nhập Email và Mật khẩu
3. Nhấn "Đăng nhập"
4. Nếu có MFA → nhập mã OTP từ email/SMS

Lưu ý:
- Sau [DEFAULT: 5] lần nhập sai → tài khoản bị khóa [DEFAULT: 15 phút] <!-- Thay thế với giá trị thực từ policy bảo mật dự án -->
- Phiên đăng nhập tự động hết hạn sau [N] giờ không hoạt động
```

### Đổi mật khẩu
```
1. Click vào tên người dùng (góc trên phải)
2. Chọn "Đổi mật khẩu"
3. Nhập mật khẩu cũ và mật khẩu mới (tối thiểu [DEFAULT: 8] ký tự) <!-- Thay thế với độ dài tối thiểu thực của dự án -->
4. Nhấn "Lưu"
```

### Quên mật khẩu
```
1. Nhấn "Quên mật khẩu" tại trang đăng nhập
2. Nhập email đăng ký
3. Kiểm tra email → nhấn link đặt lại mật khẩu (hết hạn sau [DEFAULT: 30 phút]) <!-- Thay thế với TTL thực của dự án -->
```

---

## 3. Hướng Dẫn Theo Vai Trò

> Mỗi vai trò có quyền truy cập khác nhau. Xem chi tiết trong `deployment-guide.md` (Mục 9: Account Management).

---

### ACTOR-001: [Tên vai trò]

**Truy cập được:** [System A], [System B]

#### [Tính năng 1]

```
Mục đích: [Mô tả ngắn]
Truy cập: Menu → [Tên menu] → [Tên submenu]

Cách thực hiện:
1. [Bước 1]
2. [Bước 2]
3. [Bước 3]

Lưu ý:
- [Điều quan trọng cần biết]
- [Giới hạn hoặc quy tắc]
```

#### [Tính năng 2]

```
Mục đích: [Mô tả]
Truy cập: Menu → [...]

Cách thực hiện:
1. [Bước 1]
2. [Bước 2]
```

---

### ACTOR-002: [Tên vai trò]

**Truy cập được:** [System B]

#### [Tính năng theo vai trò này]

```
[Hướng dẫn tương tự format trên]
```

---

## 4. Hướng Dẫn Theo Quy Trình (End-to-End Workflows)

> Phần này hướng dẫn theo **luồng công việc thực tế** — cách thực hiện một nghiệp vụ từ đầu đến cuối trên hệ thống.
> Nguồn: `P1-02-business-workflow.md` (luồng KD) + `[dept].md Phần B` (quy trình TO-BE).
>
> **Traceability:** Mỗi workflow step có thể reference FEAT-ID tương ứng để trace back đến feature spec.
> Ví dụ: thêm ghi chú `[FEAT-CRM-ORD-001]` vào bước liên quan — giúp support team tra cứu nhanh khi gặp sự cố.
> Format: `[FEAT-[SYS]-[MOD]-[NNN]]` theo chuẩn registry. Việc thêm FEAT-ID là optional nhưng khuyến nghị cho workflows phức tạp.

---

### WORKFLOW-001: [Tên quy trình — VD: Xử lý đơn hàng từ tiếp nhận đến giao hàng]

> **Ai tham gia:** [EXAMPLE: Sales → Kho vận → Kế toán]
> **Tần suất:** [EXAMPLE: Hàng ngày]
> **Thời gian trung bình:** [EXAMPLE: 15 phút thay vì 2 giờ trước đây]

```
Bước 1: [Vai trò: Sales] — [Thao tác trên hệ thống]
  Menu → [Tên menu] → [Hành động]
  Lưu ý: [Quy tắc nghiệp vụ cần tuân thủ]
    |
    ▼
Bước 2: [Vai trò: Sales / Hệ thống tự động] — [Thao tác tiếp theo]
  [Hệ thống tự động chuyển sang bước tiếp / Người dùng cần nhấn nút gì]
    |
    ▼
Bước 3: [Vai trò: Trưởng phòng] — Phê duyệt (nếu cần)
  Nhận thông báo → Xem chi tiết → Nhấn "Duyệt" hoặc "Từ chối"
  Điều kiện: [EXAMPLE: Đơn hàng > 10 triệu cần duyệt]
    |
    ▼
Bước 4: [Vai trò: Kho vận] — [Nhận đơn đã duyệt → Xử lý]
  Menu → [Tên menu] → [Hành động]
    |
    ▼
Kết thúc: [Trạng thái cuối cùng]
```

**Xử lý ngoại lệ trong quy trình này:**

| Tình huống | Cách xử lý trên hệ thống |
|-----------|--------------------------|
| [EXAMPLE: Khách hủy đơn sau khi đã duyệt] | [EXAMPLE: Sales nhấn "Hủy đơn" → chọn lý do → Kho nhận thông báo dừng] |
| [EXAMPLE: Hết hàng trong kho] | [EXAMPLE: Hệ thống cảnh báo → tự tạo yêu cầu mua hàng] |

---

### WORKFLOW-002: [Tên quy trình — VD: Mua hàng từ yêu cầu đến nhập kho]

> **Ai tham gia:** [EXAMPLE: Kho → Mua hàng → Kế toán]

```
[Các bước tương tự format trên]
```

---

*(Thêm WORKFLOW-003, 004... cho mỗi luồng KD chính trong P1-02)*

---

## 5. Các Thao Tác Phổ Biến

> Các thao tác dùng chung ở tất cả tính năng.

### Tìm kiếm & Lọc dữ liệu

```
1. Dùng ô "Tìm kiếm" để tìm theo [tên, mã, ...]
2. Dùng bộ lọc "Trạng thái" để lọc theo [giá trị]
3. Nhấn tiêu đề cột để sắp xếp tăng/giảm dần
4. Kết quả cập nhật tự động sau khi gõ (không cần nhấn Enter)
```

### Xuất dữ liệu (Export)

```
1. Lọc dữ liệu cần xuất
2. Nhấn nút "Xuất Excel" / "Xuất PDF" (góc trên phải danh sách)
3. File tải xuống tự động

Giới hạn: Xuất tối đa [N] bản ghi mỗi lần.
```

### Import dữ liệu hàng loạt

```
1. Tải file mẫu: Nhấn "Tải template" → điền dữ liệu
2. Nhấn "Import" → chọn file đã điền
3. Hệ thống báo kết quả: số dòng thành công / lỗi
4. File lỗi được tải về để kiểm tra chi tiết
```

---

## 6. Thông Báo Hệ Thống

| Màu / Icon | Ý nghĩa | Hành động cần làm |
|-----------|---------|------------------|
| 🟢 Xanh lá | Thành công | Không cần làm gì |
| 🟡 Vàng | Cảnh báo, cần chú ý | Đọc thông báo và xử lý |
| 🔴 Đỏ | Lỗi, thất bại | Đọc lỗi, thử lại hoặc liên hệ admin |
| 🔵 Xanh dương | Thông tin | Đọc để biết |

---

## 7. Xử Lý Sự Cố (Troubleshooting)

> Hướng dẫn từng bước khi gặp lỗi phổ biến. Nếu không giải quyết được → liên hệ Mục 9.

### 7.1. Không đăng nhập được

| Triệu chứng | Nguyên nhân có thể | Cách xử lý |
|------------|-------------------|------------|
| "Sai email hoặc mật khẩu" | Nhập sai thông tin | Kiểm tra Caps Lock, thử lại |
| "Tài khoản bị khóa" | Đăng nhập sai [DEFAULT: 5] lần | Chờ [DEFAULT: 15 phút] hoặc liên hệ Admin | <!-- Thay thế với giá trị thực --> |
| "Phiên đã hết hạn" | Session timeout | Đăng nhập lại |
| Trang trắng / không tải | Lỗi kết nối / cache | Xóa cache (Ctrl+Shift+Delete) và thử lại |

### 7.2. Dữ liệu không hiển thị

```
1. Refresh trang (F5 hoặc Ctrl+R)
2. Kiểm tra bộ lọc — đảm bảo không có filter đang active
3. Kiểm tra phân quyền — liên hệ Admin nếu không có quyền truy cập
4. Kiểm tra kết nối internet
5. Nếu vẫn không có dữ liệu → liên hệ IT support với screenshot
```

### 7.3. Lỗi khi lưu / cập nhật

| Thông báo lỗi | Cách xử lý |
|--------------|------------|
| "Vui lòng điền đầy đủ thông tin bắt buộc" | Kiểm tra các trường có dấu * |
| "Dữ liệu đã tồn tại" | Kiểm tra trùng lặp theo hướng dẫn tính năng |
| "Không có quyền thực hiện" | Liên hệ quản lý để được cấp quyền |
| "Lỗi hệ thống — vui lòng thử lại" | Chờ 30 giây, thử lại. Nếu lỗi tiếp → liên hệ IT |
| "Session hết hạn" | Đăng nhập lại, dữ liệu nhập chưa lưu có thể mất |

### 7.4. Lỗi Import dữ liệu

```
Bước kiểm tra khi import thất bại:
1. Mở file lỗi được tải về — xem cột "Lý do lỗi"
2. Sửa dòng lỗi trong file Excel gốc
3. Import lại CHỈ dòng đã sửa (không cần import lại toàn bộ)

Lỗi phổ biến:
- Sai định dạng ngày (dùng DD/MM/YYYY)
- Giá trị không hợp lệ (xem ghi chú trong file template)
- Trùng mã/ID đã tồn tại trong hệ thống
```

### 7.5. Phục Hồi Sau Sự Cố (Error Recovery)

```
Nếu gặp sự cố nghiêm trọng (mất dữ liệu, hệ thống không phản hồi):

1. GHI LẠI: Thời gian xảy ra + thao tác đang làm + thông báo lỗi
2. CHỤP MÀN HÌNH: Screenshot lỗi (nếu có)
3. KHÔNG CỐ THỰC HIỆN LẠI nhiều lần — có thể tạo dữ liệu trùng
4. LIÊN HỆ IT SUPPORT ngay với thông tin đã ghi

Admin / IT có thể:
- Khôi phục dữ liệu đã xóa (trong vòng [N] ngày)
- Rollback thao tác import lỗi
- Trace lại lịch sử thay đổi qua audit log
```

---

## 8. FAQ — Câu Hỏi Thường Gặp

**Q: Tôi không thấy một số menu/tính năng?**
> Có thể bạn không có quyền truy cập. Liên hệ Admin để kiểm tra.

**Q: Dữ liệu không hiển thị hoặc tải lâu?**
> Thử refresh trang (F5). Nếu vẫn lỗi → kiểm tra kết nối internet → liên hệ IT support.

**Q: Tôi xóa nhầm dữ liệu, có lấy lại được không?**
> Liên hệ Admin ngay. Dữ liệu có thể khôi phục trong vòng [N] ngày.

**Q: Tôi muốn thêm người dùng mới?**
> Chỉ Admin mới có quyền tạo tài khoản. Xem `deployment-guide.md` (Mục 9: Account Management).

**Q: Hệ thống phản hồi chậm, bao lâu là bình thường?**
> Hệ thống được thiết kế phản hồi trong vòng [N] giây. Nếu chờ quá [N] giây → thử refresh trang → liên hệ IT support.
> *(Giá trị [N] lấy từ P1-01 Mục 9: Yêu cầu chất lượng)*

**Q: Dữ liệu tôi nhập có được lưu tự động không?**
> Hệ thống KHÔNG lưu tự động. Luôn nhấn "Lưu" trước khi thoát trang.

**Q: Tôi có thể dùng trên điện thoại không?**
> Hệ thống hỗ trợ trình duyệt di động nhưng được tối ưu cho màn hình 1280px+. Một số tính năng có thể hiển thị không tối ưu trên mobile.

**Q: [Câu hỏi phổ biến theo dự án]**
> [Câu trả lời]

---

## 9. Liên Hệ Hỗ Trợ

| Kênh | Thông tin | Thời gian |
|------|-----------|-----------|
| Email | [support-email] | Trả lời trong 24h |
| Hotline | [phone] | 8:00 - 17:30, T2-T6 |
| Ticket system | [ticket-url] | 24/7 |

**Khi liên hệ hỗ trợ, cung cấp:**
1. Tên tài khoản / Email
2. Mô tả vấn đề (càng chi tiết càng tốt)
3. Screenshot lỗi (nếu có)
4. Thời gian xảy ra lỗi
