# Stakeholder Review — Phase 0 Brainstorm

> Tổng hợp 3 góc đánh giá: Cross-Document Review, Consistency Check, Gap Analysis.
> Mục tiêu: Đảm bảo nhất quán, phát hiện thiếu sót, xác nhận đầy đủ trước khi chuyển Phase 1.
>
> READS: `P0-01-brainstorm.md`, `P0-02-systems-users.md`, `policies/*.md`
> USED BY: `phase1-business/P1-01-project-overview.md` (Phase 0 → Phase 1 gate)

---

## Phần A: Dashboard & Trạng Thái

> **Loại tài liệu:** Stakeholder Review — Tổng hợp quá trình rà soát & đánh giá Phase 0
> **Cập nhật bởi:** [Tên người phụ trách]
> **Ngày cập nhật:** [Ngày/Tháng/Năm]

**Quy trình:**
1. Hoàn thành P0-01, P0-02, và policies/ (nếu cần)
2. Stakeholder thực hiện review theo 3 góc độ (Phần B, C, D bên dưới)
3. Ghi lại kết quả → Quay lại sửa tài liệu gốc nếu cần
4. Xác nhận Phase 0 hoàn thành → Chuyển sang Phase 1 (`/wf-analyze-requirements`)

### A.1. Trạng Thái Tài Liệu Đầu Vào

> *Kiểm tra tất cả tài liệu Phase 0 đã hoàn thành chưa trước khi bắt đầu review.*

| Tài liệu | File | Trạng thái | Ghi chú |
|-----------|------|-----------|---------|
| Thông tin tổ chức & Phạm vi | `P0-01-brainstorm.md` | ⬜ Chưa / 🔄 Đang viết / ✅ Xong | 6 sections |
| Bản đồ hệ thống & Người dùng | `P0-02-systems-users.md` | ⬜ / 🔄 / ✅ | 4 sections |
| Chính sách [1] | `policies/[tên-1].md` | ⬜ / 🔄 / ✅ / N/A | Nếu SIMPLE → N/A |
| Chính sách [2] | `policies/[tên-2].md` | ⬜ / 🔄 / ✅ / N/A | |

**Mức phức tạp dự án:** ⬜ SIMPLE / ⬜ STANDARD / ⬜ ENTERPRISE

**Sẵn sàng review:** ⬜ Chưa sẵn sàng / ✅ Sẵn sàng

### A.2. Trạng Thái Review

| Review | Người thực hiện | Trạng thái | Số vấn đề tìm thấy |
|--------|----------------|-----------|-------------------|
| Rà soát xuyên tài liệu | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Kiểm tra nhất quán | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Phân tích thiếu sót | [Tên] | ⬜ / 🔄 / ✅ | [Số] |

> *Chi tiết xem tại: Phần B (Rà soát xuyên tài liệu), Phần C (Kiểm tra nhất quán), Phần D (Phân tích thiếu sót)*

### A.3. Tổng Hợp Vấn Đề & Hành Động

> *Tổng hợp tất cả vấn đề phát hiện từ 3 góc review — theo dõi việc xử lý.*

| # | Vấn đề | Phát hiện từ | Mức độ | Hành động cần làm | File cần sửa | Người xử lý | Trạng thái |
|---|--------|-------------|--------|------------------|-------------|-------------|-----------|
| 1 | [Mô tả vấn đề] | Phần B/C/D | Nghiêm trọng / Trung bình / Nhỏ | [Sửa gì] | [File nào] | [Ai] | Chờ / Đang sửa / Xong |
| 2 | [Mô tả] | [Nguồn] | [Mức độ] | [Hành động] | [File] | [Ai] | [Trạng thái] |

### A.4. Approval Sign-Off

| Vai trò | Họ tên | Xác nhận | Ngày | Trạng thái |
|---------|--------|----------|------|------------|
| Stakeholder chính | | | | ☐ Approved / ☐ Cần làm rõ |
| Project Sponsor | | | | ☐ Approved / ☐ Cần làm rõ |

> **Quy tắc:** Ít nhất 1 stakeholder chính PHẢI approve trước khi chuyển sang `/wf-analyze-requirements`.

### A.5. Xác Nhận Phase 0 Hoàn Thành

> *Checklist cuối cùng trước khi chuyển sang Phase 1.*

```
□ P0-01 Brainstorm — đã điền đầy đủ 6 sections
  □ §1 Thông tin cơ bản — đủ company, industry, scale, platform
  □ §2 Phòng ban — ít nhất 1 phòng ban xác định
  □ §3 Phạm vi hệ thống — phân hệ, excluded scope, existing systems
  □ §4 Đối tượng người dùng — §4.1 mapping HT→user, §4.2 nhóm, §4.3 architect notes
  □ §5 Chính sách — §5.0 đánh giá, §5.1 tuân thủ (nếu có), §5.2+5.3 (nếu STANDARD/ENTERPRISE)
  □ §6 Chốt khung — tóm tắt + checklist
□ P0-02 Systems & Users — đã điền đầy đủ 4 sections
  □ §1 Bản đồ hệ thống — danh sách, quan hệ, thứ tự xây dựng
  □ §2 Users & Roles — roles, phân quyền, xác thực, quản lý tài khoản
  □ §3 NFR — scale, performance, availability
  □ §4 Tech stack — stack chính + phương án thay thế
□ Policies (nếu STANDARD/ENTERPRISE) — đã soạn cho mọi gap trong P0-01 §5.3
  □ Mỗi mục "Chưa có"/"Có 1 phần" trong P0-01 §5.2 → có file policy
  □ Mỗi policy đã có đủ 5 sections (Phạm vi, Nội dung, Ngoại lệ, Phê duyệt, Xác nhận)
□ interface_type đã xác định (web / mobile / web+mobile / api-only)
□ Phần B (Cross-Document Review) — hoàn thành, không còn vấn đề mở
□ Phần C (Consistency Check) — hoàn thành, đã sửa tất cả inconsistency
□ Phần D (Gap Analysis) — hoàn thành, không còn gap nghiêm trọng
□ Tổng hợp vấn đề (A.3) — tất cả đã xử lý xong
□ Tài liệu gốc đã được cập nhật theo kết quả review
```

**Ngày xác nhận Phase 0 hoàn thành:** [Ngày/Tháng/Năm]

**Người xác nhận:**

| Vai trò | Tên | Chữ ký |
|---------|-----|--------|
| Chủ dự án / Sponsor | [Tên] | |
| Quản lý dự án | [Tên] | |

---

## Phần B: Rà Soát Xuyên Tài Liệu (Cross-Document Review)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Tài liệu cần đọc trước khi review:**
- `P0-01-brainstorm.md` — Thông tin tổ chức, phòng ban, phân hệ, đối tượng người dùng, chính sách
- `P0-02-systems-users.md` — Bản đồ hệ thống, roles, NFR, tech stack
- `policies/*.md` — Chính sách nghiệp vụ (nếu có)

### B.1. Hệ Thống: P0-01 §4.1 ↔ P0-02 §1.1

> *Kiểm tra danh sách hệ thống trong P0-01 (Ánh xạ Hệ thống → Đối tượng Người dùng)
> có khớp với P0-02 (Bản đồ Hệ thống) không.*
> *Hai bảng PHẢI liệt kê cùng danh sách hệ thống — tên và loại phải nhất quán.*

| Hệ thống | Có trong P0-01 §4.1? | Có trong P0-02 §1.1? | Loại khớp? | Ghi chú |
|----------|---------------------|---------------------|-----------|---------|
| [VD: ERP Web Admin] | ✅ / ❌ | ✅ / ❌ | ✅ / ❌ | [Nếu không khớp — mô tả] |
| [VD: Mobile App KH] | ✅ / ❌ | ✅ / ❌ | ✅ / ❌ | |

### B.2. Người Dùng: P0-01 §4.2 ↔ P0-02 §2.1

> *Kiểm tra nhóm người dùng (P0-01) có được mapping đầy đủ thành roles (P0-02) không.*
> *Mỗi nhóm trong P0-01 phải có ít nhất 1 role tương ứng trong P0-02. Không được thiếu nhóm.*

| Nhóm người dùng (P0-01 §4.2) | Roles tương ứng (P0-02 §2.1) | Khớp? | Ghi chú |
|-------------------------------|------------------------------|-------|---------|
| [VD: Khách hàng] | [VD: ROLE-CUSTOMER] | ✅ / ❌ | |
| [VD: Nhân viên nội bộ] | [VD: ROLE-STAFF, ROLE-MANAGER] | ✅ / ❌ | |
| [VD: Admin hệ thống] | [VD: ROLE-ADMIN] | ✅ / ❌ | |

### B.3. Phòng Ban → Phân Hệ → Hệ Thống

> *Kiểm tra chuỗi ánh xạ: Mỗi phòng ban (P0-01 §2) có phân hệ liên quan (P0-01 §3.1)
> và phân hệ đó được phục vụ bởi hệ thống cụ thể (P0-02 §1.1).*

| Phòng ban (P0-01 §2) | Phân hệ liên quan (P0-01 §3.1) | Hệ thống chứa (P0-02 §1.1) | Đánh giá |
|-----------------------|-------------------------------|---------------------------|----------|
| [VD: Phòng Kinh doanh] | [VD: Bán hàng, CRM] | [VD: ERP Web Admin] | Đầy đủ / Thiếu phân hệ / Thiếu hệ thống |
| [VD: Phòng Kế toán] | [VD: Kế toán, Tài chính] | [VD: ERP Web Admin] | |
| [VD: Phòng Kho] | [VD: Quản lý kho] | [VD: ERP Web Admin + Mobile NV] | |

### B.4. Chính Sách: P0-01 §5.3 ↔ policies/

> *Kiểm tra mỗi gap trong P0-01 §5.3 có file chính sách tương ứng không.*
> *Chỉ áp dụng cho STANDARD / ENTERPRISE. SIMPLE → ghi "N/A".*

| Chính sách (P0-01 §5.3) | Agent phụ trách | File policies/ | Đủ 5 sections? | Ghi chú |
|--------------------------|----------------|---------------|----------------|---------|
| [VD: Bảng giá & chiết khấu] | [sales-expert] | `policies/bang-gia-chiet-khau.md` | ✅ / ❌ | |
| [VD: Quy chế lương] | [hr-expert] | `policies/quy-che-luong.md` | ✅ / ❌ | |

### B.5. Kiến Trúc Sơ Bộ: P0-01 §4.3 ↔ P0-02

> *Kiểm tra các nhận xét kiến trúc sơ bộ trong P0-01 §4.3 (bởi architect)
> có được phản ánh đầy đủ trong các quyết định kiến trúc ở P0-02 không.*

| Nhận xét kiến trúc (P0-01 §4.3) | Phản ánh trong P0-02? | Section | Ghi chú |
|----------------------------------|-----------------------|---------|---------|
| [VD: Cần shared backend + auth layer] | ✅ / ❌ | [§1.2 / §2.4] | |
| [VD: Cần public API, rate limiting] | ✅ / ❌ | [§3.1 / §2.4] | |
| [VD: Cần thiết kế RBAC từ sớm] | ✅ / ❌ | [§2.2 / §2.3] | |

### B.6. Tổng Kết Cross-Document Review

**Số vấn đề phát hiện:**

| Loại | Số lượng | Nghiêm trọng | Trung bình | Nhỏ |
|------|----------|-------------|-----------|-----|
| Hệ thống không khớp (B.1) | [Số] | [Số] | [Số] | [Số] |
| Người dùng/Roles không khớp (B.2) | [Số] | [Số] | [Số] | [Số] |
| PB → Phân hệ → HT gap (B.3) | [Số] | [Số] | [Số] | [Số] |
| Chính sách thiếu file (B.4) | [Số] | [Số] | [Số] | [Số] |
| Kiến trúc sơ bộ không khớp (B.5) | [Số] | [Số] | [Số] | [Số] |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Tài liệu phối hợp tốt / Cần sửa X điểm trước khi đạt / Cần review lại]

---

## Phần C: Kiểm Tra Tính Nhất Quán (Consistency Check)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Tài liệu cần đọc:**
- Tất cả file trong `phase0-brainstorm/`

### C.1. Nhất Quán Về Thuật Ngữ

> *Kiểm tra cùng 1 khái niệm có được gọi cùng tên ở tất cả tài liệu Phase 0 không.*

| Khái niệm | P0-01 gọi là | P0-02 gọi là | Policies gọi là | Thống nhất? | Tên chuẩn |
|-----------|-------------|-------------|----------------|------------|-----------|
| [VD: Hệ thống quản trị] | [VD: ERP nội bộ] | [VD: Admin Portal] | [VD: ERP] | ❌ | [Chọn 1] |
| [VD: Người mua hàng] | [VD: Khách hàng] | [VD: Customer] | [VD: KH] | ❌ | [Chọn 1] |

**Danh sách thuật ngữ chuẩn (sau khi thống nhất):**

| STT | Thuật ngữ chuẩn | Nghĩa | Không dùng |
|-----|----------------|-------|-----------|
| 1 | [Khách hàng] | [Người/tổ chức mua sản phẩm] | [Customer, KH, người mua] |
| 2 | [Đơn hàng] | [Yêu cầu mua hàng đã xác nhận] | [Order, phiếu bán] |

### C.2. Nhất Quán Về Số Liệu

> *Kiểm tra các con số có khớp nhau ở các tài liệu khác nhau không.*

| Số liệu | P0-01 nói | P0-02 nói | Khớp? | Ghi chú |
|---------|-----------|-----------|-------|---------|
| Số phòng ban tham gia | [P0-01 §2: N phòng ban] | [P0-02 §2: implicitly N roles] | ✅ / ❌ | |
| Số hệ thống / ứng dụng | [P0-01 §4.1: N hệ thống] | [P0-02 §1.1: M hệ thống] | ✅ / ❌ | [Phải bằng nhau] |
| Số phân hệ | [P0-01 §3.1: N phân hệ] | [P0-02 §1.1: ngầm chứa] | ✅ / ❌ | |
| Quy mô nhân viên | [P0-01 §1] | [P0-02 §3.1 — DAU estimate] | ✅ / ❌ | [DAU phải phù hợp quy mô] |

### C.3. Nhất Quán Về Phạm Vi

> *Kiểm tra phạm vi dự án có nhất quán giữa các tài liệu.*

| Khía cạnh | P0-01 | P0-02 | Khớp? | Ghi chú |
|-----------|-------|-------|-------|---------|
| Platform (web/mobile/api) | [§1: Nền tảng mong muốn] | [§1.1: Loại hệ thống] | ✅ / ❌ | |
| Ngoài phạm vi | [§3.2: KHÔNG làm] | [Không đề cập mảng đó] | ✅ / ❌ | |
| Hệ thống tích hợp | [§3.3: HT cần kết nối] | [§1.2: Tích hợp ngang] | ✅ / ❌ | |
| Giai đoạn triển khai | [§3.1: GĐ1/GĐ2] | [§1.3: Thứ tự xây dựng] | ✅ / ❌ | |

### C.4. Nhất Quán Về Phân Quyền & Xác Thực

> *Kiểm tra mô tả người dùng/phân quyền có khớp giữa P0-01 §4 và P0-02 §2.*

| Nhóm người dùng | P0-01 §4 mô tả | P0-02 §2 mô tả | Khớp? | Ghi chú |
|-----------------|----------------|----------------|-------|---------|
| [VD: Admin] | [§4.2: Quản trị hệ thống] | [§2.2: Toàn quyền] | ✅ / ❌ | |
| [VD: Nhân viên] | [§4.2: Nhân viên nội bộ, cần đăng nhập] | [§2.2: Xem + tạo data phòng ban mình] | ✅ / ❌ | |
| [VD: Khách hàng] | [§4.2: Không cần đăng nhập] | [§2.4: Public access, no auth] | ✅ / ❌ | |

### C.5. Tổng Kết Consistency Check

**Số vấn đề phát hiện:**

| Loại | Số lượng | Nghiêm trọng | Trung bình | Nhỏ |
|------|----------|-------------|-----------|-----|
| Thuật ngữ không nhất quán | [Số] | | | |
| Số liệu mâu thuẫn | [Số] | | | |
| Phạm vi không khớp | [Số] | | | |
| Phân quyền không khớp | [Số] | | | |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Tài liệu nhất quán / Cần sửa X điểm / Cần review lại nghiêm túc]

---

## Phần D: Phân Tích Thiếu Sót (Gap Analysis)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Cách thực hiện:**
1. Đọc toàn bộ tài liệu Phase 0
2. Dùng các checklist bên dưới để kiểm tra
3. Ghi lại gap + đề xuất hành động
4. Quay lại sửa tài liệu gốc

### D.1. Gap Về Thông Tin Cơ Bản (P0-01 §1)

> *Kiểm tra: thông tin cơ bản đã đầy đủ để tiến sang Phase 1 chưa?*

| Thông tin | Đã có? | Đủ chi tiết? | Ghi chú |
|----------|-------|-------------|---------|
| Tên tổ chức | ✅ / ❌ | ✅ / ❌ | |
| Ngành nghề | ✅ / ❌ | ✅ / ❌ | |
| Quy mô (nhân viên) | ✅ / ❌ | ✅ / ❌ | |
| Mô hình kinh doanh | ✅ / ❌ | ✅ / ❌ | |
| Nền tảng mong muốn | ✅ / ❌ | ✅ / ❌ | |
| Ràng buộc kỹ thuật | ✅ / ❌ | ✅ / ❌ | |
| Timeline giai đoạn 1 | ✅ / ❌ | ✅ / ❌ | |

### D.2. Gap Về Phòng Ban & Phân Hệ

> *Kiểm tra: có phòng ban hoặc phân hệ nào chưa được xác định nhưng cần thiết
> cho ngành nghề và mô hình kinh doanh?*

| STT | Phòng ban / Phân hệ thiếu | Tại sao cần | Mức ảnh hưởng | Hành động |
|-----|---------------------------|-------------|--------------|-----------|
| 1 | [VD: Phòng IT — quản trị hệ thống] | [Quản lý user, phân quyền, bảo trì] | Cao | Bổ sung vào P0-01 §2 |
| 2 | [VD: Module báo cáo BI] | [Ban GĐ cần dashboard] | Trung bình | Bổ sung vào P0-01 §3.1 |

### D.3. Gap Về Đối Tượng Người Dùng

> *Kiểm tra: có nhóm người dùng nào quan trọng nhưng chưa được liệt kê?*

| STT | Nhóm thiếu | Hệ thống liên quan | Mức ảnh hưởng | Hành động |
|-----|-----------|-------------------|--------------|-----------|
| 1 | [VD: Đối tác / Nhà cung cấp] | [VD: Portal đối tác] | Cao | Bổ sung P0-01 §4.1 + §4.2 |
| 2 | [VD: Khách vãng lai (không đăng nhập)] | [VD: Website] | Trung bình | Bổ sung P0-01 §4.1 |

### D.4. Gap Về Chính Sách & Tuân Thủ

> *Kiểm tra: có lĩnh vực chính sách hoặc tuân thủ pháp lý nào chưa được phân tích?*
> *Chỉ áp dụng cho STANDARD / ENTERPRISE. SIMPLE → ghi "N/A".*

| STT | Lĩnh vực thiếu | Tại sao cần | Agent cần phân tích | Hành động |
|-----|----------------|-------------|-------------------|-----------|
| 1 | [VD: Chính sách bảo mật dữ liệu] | [Xử lý DLCN khách hàng] | [legal-expert] | Bổ sung P0-01 §5.1 |
| 2 | [VD: Chính sách hoa hồng] | [Sales cần quy tắc tính] | [sales-expert] | Thêm vào P0-01 §5.3 + soạn policy |

### D.5. Gap Về Kỹ Thuật (P0-02)

> *Kiểm tra: P0-02 có đủ thông tin kỹ thuật sơ bộ cho Phase 1 chưa?*

| Yêu cầu | Có đề cập? | Đủ chi tiết? | Ghi chú |
|---------|-----------|-------------|---------|
| Danh sách hệ thống rõ ràng (§1.1) | ✅ / ❌ | ✅ / ❌ | |
| Quan hệ giữa các hệ thống (§1.2) | ✅ / ❌ | ✅ / ❌ | |
| Thứ tự xây dựng & phụ thuộc (§1.3) | ✅ / ❌ | ✅ / ❌ | |
| Danh sách roles đầy đủ (§2.1) | ✅ / ❌ | ✅ / ❌ | |
| Phân quyền tổng quát (§2.2) | ✅ / ❌ | ✅ / ❌ | |
| Phân cấp phê duyệt (§2.3) | ✅ / ❌ | ✅ / ❌ | |
| Cơ chế xác thực (§2.4) | ✅ / ❌ | ✅ / ❌ | |
| NFR cơ bản — scale, performance (§3) | ✅ / ❌ | ✅ / ❌ | |
| Tech stack đề xuất (§4) | ✅ / ❌ | ✅ / ❌ | |

### D.6. Checklist Tính Năng Ngầm Định

> **Hướng dẫn:** ✅ = Feature đã được đề cập trong P1-01, P1-02, hoặc departments/ docs; ❌ = Không có tài liệu nào đề cập → bắt buộc bổ sung vào mục D.2 (deferred issues).

> *Kiểm tra: các tính năng cơ bản thường cần cho mọi dự án đã được xem xét chưa?
> Dùng để bổ sung scope nếu bị bỏ sót ở Phase 0.*

| STT | Tính năng | Đã xem xét? | Ghi chú |
|-----|----------|-------------|---------|
| 1 | Đăng nhập / Xác thực | ✅ / ❌ | |
| 2 | Phân quyền theo vai trò | ✅ / ❌ | |
| 3 | Quản lý tài khoản người dùng | ✅ / ❌ | |
| 4 | Thông báo / Email | ✅ / ❌ | |
| 5 | Nhật ký hoạt động (Audit log) | ✅ / ❌ | |
| 6 | Sao lưu & Khôi phục | ✅ / ❌ | |
| 7 | Đa ngôn ngữ (nếu cần) | ✅ / ❌ | |

### D.7. Tổng Kết Gap Analysis

**Tổng số gap phát hiện:**

| Loại gap | Số lượng | Nghiêm trọng | Trung bình | Nhỏ |
|----------|----------|-------------|-----------|-----|
| Thông tin cơ bản (D.1) | [Số] | | | |
| Phòng ban / Phân hệ (D.2) | [Số] | | | |
| Đối tượng người dùng (D.3) | [Số] | | | |
| Chính sách & Tuân thủ (D.4) | [Số] | | | |
| Kỹ thuật (D.5) | [Số] | | | |
| Tính năng ngầm định (D.6) | [Số] | | | |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Không có gap nghiêm trọng / Cần bổ sung X điểm / Nhiều gap — cần review lại]

**Hành động ưu tiên cao nhất:**

1. [Gap quan trọng nhất — cần sửa ngay]
2. [Gap quan trọng thứ 2]
3. [Gap quan trọng thứ 3]
