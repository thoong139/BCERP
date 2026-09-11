# Stakeholder Review — Phase 1 Business

> Tổng hợp 3 góc đánh giá: Cross-Department Review, Consistency Check, Gap Analysis.
> Mục tiêu: Đảm bảo nhất quán, phát hiện thiếu sót, xác nhận đầy đủ trước Phase 2.
>
> READS: `P1-01-project-overview.md`, `P1-02-business-workflow.md`, `departments/[dept]/[dept].md`, `departments/_index.md`
> USED BY: `phase2-features/[sys]/[mod]/[feat].md`, `.mc-data/work/wf-analyze-requirements/deferred-issues.md`

---

## Phần A: Dashboard & Trạng Thái

> **Loại tài liệu:** Stakeholder Review — Tổng hợp quá trình rà soát & đánh giá Phase 1
> **Cập nhật bởi:** [Tên người phụ trách]
> **Ngày cập nhật:** [Ngày/Tháng/Năm]

**Quy trình:**
1. Hoàn thành P1-01, P1-02, và tất cả tài liệu departments/
2. Stakeholder thực hiện review theo 3 góc độ (Phần B, C, D bên dưới)
3. Ghi lại kết quả → Quay lại sửa tài liệu gốc nếu cần
4. Xác nhận Phase 1 hoàn thành → Chuyển sang Phase 2

### A.1. Trạng Thái Tài Liệu Đầu Vào

> *Kiểm tra tất cả tài liệu Phase 1 đã hoàn thành chưa trước khi bắt đầu review.*

| Tài liệu | File | Trạng thái | Ghi chú |
|-----------|------|-----------|---------|
| Tổng quan dự án | `P1-01-project-overview.md` | ⬜ Chưa / 🔄 Đang viết / ✅ Xong | |
| Quy trình kinh doanh | `P1-02-business-workflow.md` | ⬜ / 🔄 / ✅ | |
| [Phòng ban 1] — Phần A + B | `departments/[tên-1]/[tên-1].md` | ⬜ / 🔄 / ✅ | Phần A: User Needs, Phần B: Workflow |
| [Phòng ban 2] — Phần A + B | `departments/[tên-2]/[tên-2].md` | ⬜ / 🔄 / ✅ | Phần A: User Needs, Phần B: Workflow |

**Sẵn sàng review:** ⬜ Chưa sẵn sàng / ✅ Sẵn sàng

### A.2. Trạng Thái Review

| Review | Người thực hiện | Trạng thái | Số vấn đề tìm thấy |
|--------|----------------|-----------|-------------------|
| Rà soát xuyên phòng ban | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Kiểm tra nhất quán | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Phân tích thiếu sót | [Tên] | ⬜ / 🔄 / ✅ | [Số] |

> *Chi tiết xem tại: Phần B (Rà soát xuyên phòng ban), Phần C (Kiểm tra nhất quán), Phần D (Phân tích thiếu sót)*

### A.3. Tổng Hợp Vấn Đề & Hành Động

> *Tổng hợp tất cả vấn đề phát hiện từ 3 góc review — theo dõi việc xử lý.*

| # | Vấn đề | Phát hiện từ | Mức độ | Hành động cần làm | File cần sửa | Người xử lý | Trạng thái |
|---|--------|-------------|--------|------------------|-------------|-------------|-----------|
| 1 | [Mô tả vấn đề] | Phần B/C/D | Nghiêm trọng / Trung bình / Nhỏ | [Sửa gì] | [File nào] | [Ai] | Chờ / Đang sửa / Xong |
| 2 | [Mô tả] | [Nguồn] | [Mức độ] | [Hành động] | [File] | [Ai] | [Trạng thái] |

### A.4. Xác Nhận Phase 1 Hoàn Thành

> *Checklist cuối cùng trước khi bàn giao cho Phase 2.*

```
□ P1-01 Project Overview — đã xác nhận bởi Chủ dự án
□ P1-02 Business Workflow — đã xác nhận bởi stakeholder
□ Tất cả departments/ — đã hoàn thành Phần A + Phần B
□ Phần B (Cross-Dept Review) — hoàn thành, không còn vấn đề mở
□ Phần C (Consistency Check) — hoàn thành, đã sửa tất cả inconsistency
□ Phần D (Gap Analysis) — hoàn thành, không còn gap nghiêm trọng
□ Tổng hợp vấn đề (mục A.3) — tất cả đã xử lý xong
□ Tài liệu gốc đã được cập nhật theo kết quả review
```

**Ngày xác nhận Phase 1 hoàn thành:** [Ngày/Tháng/Năm]

**Người xác nhận:**

| Vai trò | Tên | Chữ ký |
|---------|-----|--------|
| Chủ dự án / Sponsor | [Tên] | |
| Quản lý dự án | [Tên] | |
| Đại diện nghiệp vụ | [Tên] | |

---

## Phần B: Rà Soát Xuyên Phòng Ban (Cross-Department Review)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Tài liệu cần đọc trước khi review:**
- `P1-02-business-workflow.md` — Luồng kinh doanh tổng thể
- Tất cả `departments/[dept]/[dept].md` (Phần A: User Needs + Phần B: Workflow)

### B.1. Ma Trận Liên Hệ Giữa Các Phòng Ban

> *Đối chiếu phần "Liên hệ với phòng ban khác" của TẤT CẢ phòng ban — kiểm tra xem
> thông tin gửi đi và nhận về có khớp nhau không.*

| Phòng ban A | Nói gửi cho B | Phòng ban B | Nói nhận từ A | Khớp? | Ghi chú |
|-------------|-------------|-------------|-------------|-------|---------|
| [Sales] | [Đơn hàng đã xác nhận] | [Kho vận] | [Đơn hàng đã duyệt] | ✅ / ❌ | [Nếu không khớp — mô tả] |
| [Sales] | [Yêu cầu xuất HĐ] | [Kế toán] | [Thông tin lập HĐ] | ✅ / ❌ | |
| [Kho vận] | [Trạng thái giao hàng] | [Sales] | [Kết quả giao hàng] | ✅ / ❌ | |

### B.2. Kiểm Tra Trùng Lặp Yêu Cầu

> *Phát hiện nhu cầu giống nhau từ nhiều phòng ban — cần gộp lại hay tách riêng.*

| Nhu cầu | Phòng ban A | Mã A | Phòng ban B | Mã B | Đánh giá | Hành động |
|---------|-------------|------|-------------|------|----------|-----------|
| [VD: Quản lý thông tin khách hàng] | [Sales] | REQ-SALES-001 | [CSKH] | REQ-CSKH-003 | Trùng lặp / Tương tự / Khác biệt | Gộp / Giữ riêng / Cần bàn thêm |
| [VD: Báo cáo doanh số] | [Sales] | REQ-SALES-005 | [Kế toán] | REQ-KT-004 | [Đánh giá] | [Hành động] |

### B.3. Kiểm Tra Mâu Thuẫn Quy Trình

> *Phát hiện khi 2 phòng ban mô tả cùng 1 quy trình nhưng khác nhau.*

| Quy trình | Theo phòng ban A | Theo phòng ban B | Điểm mâu thuẫn | Đề xuất giải quyết |
|-----------|-----------------|-----------------|----------------|-------------------|
| [VD: Phê duyệt đơn hàng] | [Sales: Trưởng phòng duyệt tất cả] | [Kế toán: Chỉ duyệt đơn > 10tr] | [Ai duyệt đơn < 10tr?] | [Thống nhất: NV tự duyệt < 10tr] |
| [VD: Xử lý đổi trả] | [CSKH: CSKH quyết định] | [Sales: Sales quyết định] | [Ai là người quyết?] | [Cần họp thống nhất] |

### B.4. Kiểm Tra Điểm Chuyển Giao

> *So sánh với P1-02 Business Workflow — các điểm chuyển giao có được cả 2 phía mô tả không.*

| Điểm chuyển giao (từ P1-02) | Phòng A mô tả? | Phòng B mô tả? | Đánh giá |
|-----------------------------|----------------|----------------|----------|
| [Sales → Kho vận: Đơn hàng] | ✅ Có trong P1-04-sales | ✅ Có trong P1-04-kho | Đầy đủ |
| [Kho vận → Kế toán: Phiếu xuất] | ✅ Có | ❌ Thiếu trong P1-04-ketoan | Cần bổ sung |
| [CSKH → Kho: Yêu cầu đổi trả] | ❌ Thiếu | ❌ Thiếu | Cần bổ sung cả 2 |

### B.5. Tổng Kết Cross-Dept Review

**Số vấn đề phát hiện:**

| Loại | Số lượng | Nghiêm trọng | Trung bình | Nhỏ |
|------|----------|-------------|-----------|-----|
| Trùng lặp | [Số] | [Số] | [Số] | [Số] |
| Mâu thuẫn | [Số] | [Số] | [Số] | [Số] |
| Thiếu điểm chuyển giao | [Số] | [Số] | [Số] | [Số] |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Các phòng ban phối hợp tốt / Cần sửa X điểm trước khi đạt / Cần review lại nghiêm túc]

---

## Phần C: Kiểm Tra Tính Nhất Quán (Consistency Check)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Tài liệu cần đọc:**
- Tất cả file trong `phase1-business/`

### C.1. Nhất Quán Về Thuật Ngữ

> *Kiểm tra xem cùng 1 khái niệm có được gọi cùng tên ở tất cả tài liệu không.*

| Khái niệm | P1-01 gọi là | P1-02 gọi là | Phòng ban A gọi là | Phòng ban B gọi là | Thống nhất? | Tên chuẩn |
|-----------|-------------|-------------|--------------------|--------------------|------------|-----------|
| [VD: Người mua hàng] | Khách hàng | Người mua | Customer | Khách | ❌ | [Chọn 1: "Khách hàng"] |
| [VD: Đơn đặt hàng] | Đơn hàng | Order | Đơn đặt hàng | Phiếu bán hàng | ❌ | [Chọn 1: "Đơn hàng"] |

**Danh sách thuật ngữ chuẩn (sau khi thống nhất):**

| STT | Thuật ngữ chuẩn | Nghĩa | Không dùng |
|-----|----------------|-------|-----------|
| 1 | [Khách hàng] | [Người/tổ chức mua sản phẩm/dịch vụ] | [Customer, người mua, khách] |
| 2 | [Đơn hàng] | [Yêu cầu mua hàng đã được xác nhận] | [Order, phiếu bán, đơn đặt hàng] |
| 3 | [Sản phẩm] | [Hàng hóa/dịch vụ doanh nghiệp cung cấp] | [Product, mặt hàng, SP] |

### C.2. Nhất Quán Về Số Liệu & Quy Tắc

> *Kiểm tra các con số, ngưỡng, quy tắc có giống nhau ở các tài liệu khác nhau không.*

| Quy tắc / Số liệu | File A nói | File B nói | Khớp? | Ghi chú |
|-------------------|-----------|-----------|-------|---------|
| [VD: Ngưỡng phê duyệt đơn hàng] | [P1-04-sales: > 10tr cần duyệt] | [P1-04-ketoan: > 20tr cần duyệt] | ❌ | [Cần thống nhất] |
| [VD: Thời hạn thanh toán] | [P1-03-sales: 30 ngày] | [P1-03-ketoan: 45 ngày] | ❌ | [Hỏi lại chính sách] |
| [VD: Số phòng ban] | [P1-01: 4 phòng ban] | [P1-02: 5 phòng ban] | ❌ | [P1-02 thêm phòng IT] |

### C.3. Nhất Quán Về Phạm Vi

> *Kiểm tra phạm vi hệ thống có nhất quán giữa P1-01 và các tài liệu phòng ban.*

| Phân hệ trong P1-01 | Phòng ban nào yêu cầu? | Có User Needs? | Có Workflow? | Đánh giá |
|---------------------|----------------------|----------------|-------------|----------|
| [VD: Quản lý bán hàng] | [Sales] | ✅ | ✅ | Đầy đủ |
| [VD: Quản lý kho] | [Kho vận] | ✅ | ❌ Thiếu | Cần bổ sung workflow |
| [VD: Báo cáo] | [Ban GĐ, Kế toán] | ❌ Thiếu | — | Không có phòng ban nào viết chi tiết |

**Nhu cầu ngoài phạm vi P1-01:**

| Nhu cầu | Phòng ban | Mã | Có trong P1-01? | Hành động |
|---------|-----------|-----|----------------|-----------|
| [VD: App di động cho sales] | [Sales] | REQ-SALES-010 | ❌ Không | Bổ sung vào P1-01 / Loại khỏi scope |
| [VD: Tích hợp kế toán bên thứ 3] | [Kế toán] | REQ-KT-008 | ❌ Không | [Hành động] |

### C.4. Nhất Quán Về Vai Trò & Người Dùng

> *Kiểm tra danh sách người dùng/vai trò có khớp giữa P1-01 và các phòng ban.*

| Vai trò trong P1-01 | Phòng ban đề cập | Mô tả có khớp? | Ghi chú |
|---------------------|------------------|----------------|---------|
| [VD: Nhân viên KD] | [Sales — A1] | ✅ / ❌ | [Khác biệt gì] |
| [VD: Trưởng phòng] | [Sales, Kế toán] | ✅ / ❌ | [Quyền hạn mô tả khác nhau] |
| [VD: Quản trị hệ thống] | [Không phòng ban nào đề cập] | ❌ Thiếu | [Cần bổ sung vào phòng IT] |

### C.5. Nhất Quán Giữa User Needs & Workflow

> *Kiểm tra mỗi phòng ban: nhu cầu (P1-03) có tương ứng với quy trình (P1-04) không.*

| Phòng ban | Nhu cầu (P1-03) | Có quy trình tương ứng (P1-04)? | Ghi chú |
|-----------|----------------|--------------------------------|---------|
| [Sales] | REQ-SALES-001: Quản lý KH | ✅ QT1: Tiếp nhận KH mới | Khớp |
| [Sales] | REQ-SALES-003: Báo cáo doanh số | ❌ Không có quy trình | Thiếu — cần bổ sung |
| [Kho vận] | REQ-KHO-002: Kiểm kê tồn kho | ✅ QT3: Kiểm kê cuối tuần | Khớp |

### C.6. Tổng Kết Consistency Check

**Số vấn đề phát hiện:**

| Loại | Số lượng | Nghiêm trọng | Trung bình | Nhỏ |
|------|----------|-------------|-----------|-----|
| Thuật ngữ không nhất quán | [Số] | | | |
| Số liệu/quy tắc mâu thuẫn | [Số] | | | |
| Phạm vi không khớp | [Số] | | | |
| Vai trò không khớp | [Số] | | | |
| Needs vs Workflow không khớp | [Số] | | | |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Tài liệu nhất quán / Cần sửa X điểm / Cần review lại nghiêm túc]

---

## Phần D: Phân Tích Thiếu Sót (Gap Analysis)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Cách thực hiện:**
1. Đọc toàn bộ tài liệu Phase 1
2. Dùng các checklist bên dưới để kiểm tra
3. Ghi lại gap + đề xuất hành động
4. Quay lại sửa tài liệu gốc

### D.1. Gap Về Phòng Ban / Vai Trò

> *Kiểm tra: có phòng ban nào hoặc vai trò nào chưa được phỏng vấn / chưa có tài liệu?*

| STT | Phòng ban / Vai trò | Có tài liệu? | Mức ảnh hưởng | Hành động |
|-----|---------------------|--------------|--------------|-----------|
| 1 | [VD: Phòng IT / Quản trị hệ thống] | ❌ Chưa có | Cao — quản lý user, phân quyền | Cần tạo P1-03 + P1-04 |
| 2 | [VD: Ban Giám đốc] | ❌ Chỉ xuất hiện trong P1-01 | Trung bình — cần dashboard | Cần bổ sung yêu cầu báo cáo |
| 3 | [VD: Nhân viên giao hàng] | ❌ Chưa phỏng vấn | Cao — sẽ dùng app | Cần phỏng vấn |

### D.2. Gap Về Quy Trình

> *Kiểm tra: có quy trình kinh doanh nào CHƯA được mô tả ở bất kỳ tài liệu nào?*

| STT | Quy trình còn thiếu | Tại sao quan trọng | Phòng ban liên quan | Hành động |
|-----|---------------------|-------------------|--------------------|-----------|
| 1 | [VD: Quy trình xử lý đổi trả hàng] | [Ảnh hưởng tồn kho + kế toán] | [CSKH, Kho, Kế toán] | [Bổ sung vào P1-04 của 3 phòng ban] |
| 2 | [VD: Quy trình onboarding nhân viên mới] | [Cần tạo tài khoản, phân quyền] | [HR, IT] | [Tạo tài liệu riêng hoặc bổ sung] |
| 3 | [VD: Quy trình backup/khôi phục dữ liệu] | [Đảm bảo không mất dữ liệu] | [IT] | [Thêm vào yêu cầu chất lượng] |

### D.3. Gap Về Tính Năng

> *Kiểm tra: có nhu cầu/tính năng nào quan trọng mà KHÔNG phòng ban nào đề cập?*

#### Checklist tính năng thường gặp

| STT | Tính năng | Có được đề cập? | Ở đâu | Ghi chú |
|-----|----------|----------------|-------|---------|
| 1 | Đăng nhập / Phân quyền | ✅ / ❌ | [File nào] | |
| 2 | Quản lý tài khoản người dùng | ✅ / ❌ | | |
| 3 | Tìm kiếm / Lọc dữ liệu | ✅ / ❌ | | |
| 4 | Xuất báo cáo Excel / PDF | ✅ / ❌ | | |
| 5 | Thông báo / Nhắc nhở | ✅ / ❌ | | |
| 6 | Lịch sử thao tác (Audit log) | ✅ / ❌ | | |
| 7 | Sao lưu / Khôi phục dữ liệu | ✅ / ❌ | | |
| 8 | Nhập dữ liệu hàng loạt (Import) | ✅ / ❌ | | |
| 9 | Giao diện trên điện thoại / Tablet | ✅ / ❌ | | |
| 10 | Đa ngôn ngữ | ✅ / ❌ | | |
| 11 | In ấn (phiếu, hóa đơn, báo cáo) | ✅ / ❌ | | |
| 12 | Tích hợp email / SMS | ✅ / ❌ | | |

### D.4. Gap Về Dữ Liệu

> *Kiểm tra: có loại dữ liệu nào quan trọng nhưng chưa được phòng ban nào liệt kê?*

| STT | Loại dữ liệu | Ai sở hữu? | Được đề cập? | Ghi chú |
|-----|-------------|-----------|-------------|---------|
| 1 | [VD: Dữ liệu lịch sử từ hệ thống cũ] | [Chưa rõ] | ❌ | [Cần kế hoạch migrate] |
| 2 | [VD: File đính kèm (hình ảnh, PDF)] | [Nhiều phòng ban] | ❌ | [Cần quy ước lưu trữ] |
| 3 | [VD: Nhật ký thao tác người dùng] | [IT] | ❌ | [Cần cho bảo mật] |

### D.5. Gap Về Tình Huống Ngoại Lệ

> *Kiểm tra: các tình huống bất thường/edge case có được xử lý chưa?*

| STT | Tình huống | Có được mô tả? | Ở phòng ban nào | Ghi chú |
|-----|-----------|---------------|----------------|---------|
| 1 | [VD: Mất kết nối internet khi làm việc] | ❌ | | [Cần quy ước: offline mode hay không?] |
| 2 | [VD: Dữ liệu bị nhập sai, cần sửa/xóa] | ❌ | | [Ai có quyền sửa? Có log không?] |
| 3 | [VD: Hệ thống bị sự cố, cần khôi phục] | ❌ | | [Thời gian chấp nhận được?] |
| 4 | [VD: Nhân viên cố tình gian lận dữ liệu] | ❌ | | [Kiểm soát nội bộ?] |
| 5 | [VD: Quy mô doanh nghiệp tăng gấp đôi] | ❌ | | [Hệ thống có mở rộng được?] |

### D.6. Gap Về Yêu Cầu Phi Chức Năng

> **Hướng dẫn:** ✅ = Feature đã được đề cập trong P1-01, P1-02, hoặc departments/ docs; ❌ = Không có tài liệu nào đề cập → bắt buộc bổ sung vào mục D.2 (deferred issues).

> *Kiểm tra: P1-01 mục 9 và các phòng ban có đề cập đủ yêu cầu chất lượng chưa?*

| Yêu cầu | Có đề cập? | Ở đâu | Đủ chi tiết? | Ghi chú |
|---------|-----------|-------|-------------|---------|
| Hiệu năng (tốc độ) | ✅ / ❌ | | ✅ / ❌ | |
| Bảo mật | ✅ / ❌ | | ✅ / ❌ | |
| Khả dụng (uptime) | ✅ / ❌ | | ✅ / ❌ | |
| Dễ sử dụng | ✅ / ❌ | | ✅ / ❌ | |
| Khả năng mở rộng | ✅ / ❌ | | ✅ / ❌ | |
| Sao lưu & khôi phục | ✅ / ❌ | | ✅ / ❌ | |
| Tuân thủ pháp luật | ✅ / ❌ | | ✅ / ❌ | |

### D.7. Tổng Kết Gap Analysis

**Tổng số gap phát hiện:**

| Loại gap | Số lượng | Nghiêm trọng | Trung bình | Nhỏ |
|----------|----------|-------------|-----------|-----|
| Phòng ban / Vai trò | [Số] | | | |
| Quy trình | [Số] | | | |
| Tính năng | [Số] | | | |
| Dữ liệu | [Số] | | | |
| Tình huống ngoại lệ | [Số] | | | |
| Phi chức năng | [Số] | | | |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Không có gap nghiêm trọng / Cần bổ sung X điểm / Nhiều gap — cần review lại]

**Hành động ưu tiên cao nhất:**

1. [Gap quan trọng nhất — cần sửa ngay]
2. [Gap quan trọng thứ 2]
3. [Gap quan trọng thứ 3]
