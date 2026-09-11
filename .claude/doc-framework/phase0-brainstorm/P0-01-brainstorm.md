# Thông Tin Tổ Chức & Phạm Vi Dự Án — [TÊN DỰ ÁN]

## Mục Đích (Purpose)

Template này được điền trong `/wf-brainstorm` — giai đoạn đầu tiên của DEVKIT workflow.
**Khi nào dùng:** Khi bắt đầu một dự án mới hoặc onboard dự án hiện có.
**Output của template này được dùng bởi:** `/wf-analyze-requirements` (Phase 1 context).

---

> **Loại tài liệu:** Discovery Phase 0
> **Ngày:** [Ngày/Tháng/Năm]
> **Trạng thái:** Đang khám phá → Đã chốt → Chuyển sang Phase 1
>
> READS: (user input + BA/domain expert analysis)
> USED BY: `P0-02-systems-users.md`, `stakeholder-review.md`, `phase1-business/P1-01-project-overview.md`, `phase1-business/P1-02-business-workflow.md`, `phase1-business/departments/`

---

> ## Hướng Dẫn Sử Dụng File Này
>
> File này tổng hợp từ 2 nguồn:
>
> - **📝 Người dùng cung cấp:** Thông tin tổ chức, nền tảng mong muốn, những gì KHÔNG muốn làm, hệ thống hiện có
> - **🤖 Agents phân tích:** BA gợi ý phòng ban và phân hệ, domain experts + legal-expert phân tích chính sách và tuân thủ
>
> **User KHÔNG cần trả lời** về luật pháp, compliance, hay quy định kỹ thuật — các agent chuyên gia sẽ tự phân tích dựa trên ngành nghề và bối cảnh.
>
> *Xóa phần hướng dẫn này sau khi hoàn thành.*

---

## 1. Thông Tin Cơ Bản

> **📝 Người dùng cung cấp** — Trả lời trực tiếp, không cần kiến thức chuyên sâu

| Câu hỏi                                     | Trả lời                                                                                |
| --------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Tên tổ chức / Công ty?                    | [Điền]                                                                                 |
| Ngành nghề kinh doanh?                      | [Điền]                                                                                 |
| Quy mô (số nhân viên ước tính)?        | [Điền]                                                                                 |
| Doanh nghiệp kiếm tiền bằng cách nào?   | [Mô tả ngắn — VD: "Sản xuất thiết bị y tế, bán qua đại lý và bệnh viện"] |
| Nền tảng mong muốn?                        | [Web / Mobile / Web + Mobile / API-only]                                                 |
| Thời gian mong muốn giai đoạn 1?          | [VD: 3 tháng / 6 tháng / "Chưa xác định"]                                          |
| Có ràng buộc kỹ thuật bắt buộc không? | [VD: Phải dùng .NET, Oracle, On-premise / "Không có"]                                |

---

## 2. Phòng Ban Tham Gia

> **🤖 Phân tích bởi `business-analyst`** — Gợi ý dựa trên ngành nghề + bối cảnh → User xác nhận
> Dựa trên: `industry`, `business_model`, `pain_points[]` từ buổi brainstorm

| STT | Tên phòng ban | Chức năng chính | Sẽ dùng hệ thống? |
| --- | --------------- | ------------------ | --------------------- |
| 1   | [BA điền]     | [BA điền]        | Có / Không          |
| 2   | [BA điền]     | [BA điền]        | Có / Không          |
| 3   | [BA điền]     | [BA điền]        | Có / Không          |
| 4   | [BA điền]     | [BA điền]        | Có / Không          |
| 5   |                 |                    |                       |

---

## 3. Phạm Vi Hệ Thống

### 3.1. Phân hệ cần có

> **🤖 Phân tích bởi domain experts** — Gợi ý dựa trên ngành + phòng ban đã xác định → User xác nhận

| STT | Phân hệ      | Phòng ban liên quan | Giai đoạn       | Ưu tiên        |
| --- | -------------- | --------------------- | ----------------- | ---------------- |
| 1   | [Agent điền] | [Agent điền]        | GĐ1 / GĐ2 / Sau | Cao / TB / Thấp |
| 2   | [Agent điền] | [Agent điền]        |                   |                  |
| 3   | [Agent điền] | [Agent điền]        |                   |                  |
| 4   |                |                       |                   |                  |

### 3.2. Ngoài phạm vi — KHÔNG làm

> **📝 Người dùng xác nhận** — Những mảng đã có sẵn hoặc không thuộc scope

- [Mảng — Lý do: VD "Đã có phần mềm MISA, không thay thế"]
- [Mảng — Lý do]

### 3.3. Hệ thống hiện có cần tích hợp

> **📝 Người dùng cung cấp** — Phần mềm / công cụ đang dùng mà dự án cần kết nối

- [VD: Phần mềm kế toán MISA — chỉ kết nối, không thay thế]
- [VD: E-Invoice VNPT — tích hợp xuất hóa đơn]
- [VD: Không có — xây mới hoàn toàn]

---

## 4. Đối Tượng Người Dùng Theo Hệ Thống

> **📝 Người dùng cung cấp nếu biết** — **🤖 `architect` + `business-analyst` phân tích và điền** nếu chưa đủ thông tin
> Dựa trên: platform (Section 1), phân hệ (Section 3), phòng ban (Section 2), ngành nghề, mô hình kinh doanh
>
> *Ví dụ đơn giản: Website trang chủ thôi → chỉ 1 dòng: Khách hàng/Khách vãng lai dùng Website.*
> *Ví dụ phức tạp: ERP + Website + 2 Mobile App → mỗi hệ thống một dòng riêng, đối tượng khác nhau.*

### 4.1. Bảng Ánh Xạ Hệ Thống → Đối Tượng Người Dùng

| STT | Hệ thống / Phân hệ        | Loại  | Đối tượng người dùng          | Ghi chú                                                  |
| --- | ----------------------------- | ------ | ------------------------------------ | --------------------------------------------------------- |
| 1   | [VD: Website trang chủ]      | Web    | [VD: Khách hàng, Khách vãng lai] | [VD: Truy cập công khai, không cần đăng nhập]      |
| 2   | [VD: ERP / CMS nội bộ]      | Web    | [VD: Nhân viên, Quản lý, Admin]  | [VD: Đăng nhập nội bộ, phân quyền theo phòng ban] |
| 3   | [VD: Mobile App Khách hàng] | Mobile | [VD: Khách hàng]                   | [VD: Tự đăng ký, iOS + Android]                       |
| 4   | [VD: Mobile App Nhân viên]  | Mobile | [VD: Nhân viên nội bộ]           | [VD: IT tạo tài khoản, không đăng ký tự do]       |
| 5   |                               |        |                                      |                                                           |

**Loại hệ thống:** `Web` / `Mobile (iOS)` / `Mobile (Android)` / `Mobile (cross-platform)` / `Desktop` / `API-only` / `Bot/Automation`

### 4.2. Phân Loại Nhóm Người Dùng

> **🤖 Phân tích bởi `business-analyst`** — Tổng hợp tất cả nhóm người dùng từ Section 4.1

| Nhóm người dùng                   | Mô tả                                           | Dùng hệ thống nào | Cần đăng nhập? |
| ------------------------------------- | ------------------------------------------------- | --------------------- | ------------------ |
| [VD: Khách hàng / Khách vãng lai] | [VD: Doanh nghiệp hoặc cá nhân mua dịch vụ] | [Điền]              | Không / Có       |
| [VD: Nhân viên nội bộ]            | [VD: Toàn bộ nhân viên các phòng ban]       | [Điền]              | Có                |
| [VD: Quản lý / Supervisor]          | [VD: Trưởng phòng, Ban giám đốc]            | [Điền]              | Có                |
| [VD: Admin hệ thống]                | [VD: IT vận hành, cấu hình hệ thống]        | [Điền]              | Có                |
| [VD: Đối tác / Nhà cung cấp]     | [VD: Đối tác truy cập portal riêng]          | [Điền]              | Không / Có       |

### 4.3. Lưu Ý Kiến Trúc Sơ Bộ

> **🤖 Nhận xét bởi `architect`** — Hệ quả thiết kế từ phân bổ người dùng, làm input cho P0-02

- [VD: ERP + Mobile NV phục vụ nội bộ → có thể dùng chung backend + auth layer]
- [VD: Website + Mobile KH phục vụ bên ngoài → cần public API, rate limiting, bảo mật cao hơn]
- [VD: Website tĩnh → không cần backend riêng, triển khai qua CDN]
- [VD: Nhiều nhóm người dùng truy cập cùng hệ thống → cần thiết kế RBAC từ sớm]

---

## 5. Chính Sách & Tuân Thủ

### 5.0. Đánh Giá Mức Độ Cần Chính Sách

> **🤖 Tự động đánh giá** — Dựa trên `project_complexity` từ `/wf-brainstorm` Phase 2 step 2.4
> Quyết định có cần phân tích chính sách doanh nghiệp hay không.

| Tiêu chí                               | Giá trị                        |
| ---------------------------------------- | -------------------------------- |
| Loại dự án (`project_complexity`)   | [SIMPLE / STANDARD / ENTERPRISE] |
| Số phòng ban tham gia                  | [N]                              |
| Có modules quản trị/vận hành?       | Có / Không                     |
| Keywords phát hiện                     | [Liệt kê keywords đã detect] |
| **Cần phân tích chính sách?** | **Có / Không**           |

> **Nếu SIMPLE:** Sections 5.1-5.3 ghi "N/A — Dự án không yêu cầu phân tích chính sách doanh nghiệp."
> **Nếu STANDARD:** Chỉ phân tích chính sách core liên quan trực tiếp đến nghiệp vụ chính.
> **Nếu ENTERPRISE:** Phân tích đầy đủ — bao gồm cả chính sách do experts chủ động đề xuất.

---

### 5.1. Tuân Thủ Pháp Lý & Quy Định

> **🤖 Phân tích bởi `legal-expert`**, **`compliance-expert`**
> Dựa trên: ngành nghề, loại dữ liệu xử lý, thị trường hoạt động, loại giao dịch tài chính

| Quy định / Luật                                                | Áp dụng?   | Yêu cầu cụ thể với dự án | Ưu tiên        |
| ----------------------------------------------------------------- | ------------ | ------------------------------- | ---------------- |
| [Agent điền]                                                    | Có / Không | [Agent điền]                  | Cao / TB / Thấp |
| [VD: Nghị định 13/2023/NĐ-CP — bảo vệ dữ liệu cá nhân] |              |                                 |                  |
| [VD: Thông tư 78/2021/TT-BTC — hóa đơn điện tử]          |              |                                 |                  |
| [Quy định ngành đặc thù nếu có]                           |              |                                 |                  |

### 5.2. Chính Sách Công ty

> **📝 Người dùng điền** — Đánh trạng thái và ghi chú ngắn nếu có đặc thù riêng
> Chỉ điền những lĩnh vực phù hợp với ngành — bỏ qua dòng không áp dụng

| Lĩnh vực             | Chính sách                                                | Trạng thái                       | Ghi chú đặc thù |
| ---------------------- | ----------------------------------------------------------- | ---------------------------------- | ------------------- |
| **Khách hàng** | Phân loại khách hàng (VIP, thường, đại lý, CTV...) | Đã có / Có 1 phần / Chưa có |                     |
| **Bán hàng**   | Bảng giá / pricing tiers                                  | Đã có / Có 1 phần / Chưa có |                     |
| **Bán hàng**   | Chiết khấu / khuyến mãi / ưu đãi                     | Đã có / Có 1 phần / Chưa có |                     |
| **Bán hàng**   | Hoa hồng / commission sales                                | Đã có / Có 1 phần / Chưa có |                     |
| **Bán hàng**   | Đổi trả / bảo hành                                     | Đã có / Có 1 phần / Chưa có |                     |
| **Nhân sự**    | Cơ cấu tổ chức / phân cấp & phê duyệt          | Đã có / Có 1 phần / Chưa có |                     |
| **Nhân sự**    | Tuyển dụng & onboarding (incl. nhân viên nước ngoài) | Đã có / Có 1 phần / Chưa có |                     |
| **Nhân sự**    | Cơ chế lương (cứng, KPI, thưởng, phụ cấp...)   | Đã có / Có 1 phần / Chưa có |                     |
| **Nhân sự**    | Nghỉ phép / chấm công / overtime                  | Đã có / Có 1 phần / Chưa có |                     |
| **Nhân sự**    | Đánh giá hiệu suất & kỷ luật (PIP)             | Đã có / Có 1 phần / Chưa có |                     |
| **Nhân sự**    | Đào tạo & phát triển năng lực                    | Đã có / Có 1 phần / Chưa có |                     |
| **Mua hàng**   | Quy trình phê duyệt mua & hạn mức chi (ma trận SoD) | Đã có / Có 1 phần / Chưa có |                     |
| **Kho**         | Quy tắc xuất nhập kho (FIFO / LIFO / khác)       | Đã có / Có 1 phần / Chưa có |                     |
| **Tài chính**  | Phân quyền phê duyệt thanh toán                  | Đã có / Có 1 phần / Chưa có |                     |
| **Tài chính**  | Chính sách công nợ / thu tiền                    | Đã có / Có 1 phần / Chưa có |                     |
| **Vận hành**   | SLA / quy trình phục vụ khách hàng               | Đã có / Có 1 phần / Chưa có |                     |
| **Công nghệ**  | Change management hệ thống & SLA nội bộ IT       | Đã có / Có 1 phần / Chưa có |                     |
| **Công nghệ**  | Data backup, recovery & incident response         | Đã có / Có 1 phần / Chưa có |                     |
| [Lĩnh vực khác] | [Theo đặc thù ngành]                             |                                    |                     |

### 5.3. Chính Sách Cần Xây Dựng / Bổ Sung

> **🤖 Phân tích và soạn thảo bởi domain experts**
> Nguồn: (1) trạng thái "Chưa có" / "Có 1 phần" ở §5.2 + (2) chính sách experts **chủ động đề xuất** dựa trên ngành nghề + phân hệ (Section 3)
> `final_policy_gaps[] = user_gaps ∪ expert_recommended_gaps` (dedup)
> Kết quả lưu tại: `phase0-brainstorm/policies/[ten-chinh-sach].md`

| STT | Chính sách   | Nguồn                       | Agent phụ trách     | Nội dung cốt lõi sẽ soạn                               | Ưu tiên                          |
| --- | -------------- | ---------------------------- | --------------------- | ----------------------------------------------------------- | ---------------------------------- |
| 1   | [Agent điền] | User gap / Expert đề xuất | [VD:`sales-expert`] | [VD: Bảng giá 3 tiers, quy tắc chiết khấu theo volume] | Bắt buộc / Nên có / Tùy chọn |
| 2   | [Agent điền] | User gap / Expert đề xuất | [VD:`hr-expert`]    | [Agent điền]                                              |                                    |
| 3   |                |                              |                       |                                                             |                                    |

> **Ghi chú:** Chính sách "Expert đề xuất" là những chính sách mà domain experts nhận thấy CẦN THIẾT cho việc vận hành, quản trị, kiểm soát doanh nghiệp và hệ thống cần phải đáp ứng được.
> nhưng user có thể chưa nghĩ tới. Xem chi tiết phân tích tại `.mc-data/work/wf-brainstorm/policy-analysis.md`

---

## 6. Chốt Khung Dự Án

### 6.1. Tóm tắt dự án (1-2 câu)

[VD: "Xây dựng hệ thống ERP quản lý bán hàng, kho, kế toán cho công ty ABC — 3 hệ thống: Web admin, Web khách hàng, Mobile tài xế."]

### 6.2. Xác nhận sẵn sàng sang Phase 1

```
□ Đã hoàn thành P0-01 (Thông tin tổ chức, phòng ban, phân hệ, đối tượng người dùng, chính sách nghiệp vụ)
□ Đã hoàn thành P0-02 (Bản đồ hệ thống chi tiết, roles & quyền, NFR, tech stack)
□ Chính sách còn thiếu đã được agents soạn thảo (policies/)
□ interface_type đã xác định (web / mobile / web+mobile / api-only)
□ Đã hoàn thành stakeholder-review.md (3 góc review: Cross-Document, Consistency, Gap Analysis)
□ Người phê duyệt đã đồng ý với phạm vi
```

**Ngày chốt:** [Ngày/Tháng/Năm]
**Người chốt:** [Tên] — [Vai trò]

---

**→ Bước tiếp theo:** Hoàn thành `P0-02-systems-users.md`, ký `stakeholder-review.md` (Phase 0), rồi chuyển sang Phase 1 — điền `P1-01-project-overview.md` và tạo folders trong `departments/`.
