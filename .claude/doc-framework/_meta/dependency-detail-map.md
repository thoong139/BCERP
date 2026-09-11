<!-- Status: reference-only template — dùng làm structured input cho dependency analysis, không có _contract.json reference riêng -->

# Bản Đồ Phụ Thuộc Chi Tiết Giữa Các Tài Liệu

> **Mục đích:** Kiểm soát nội dung liên quan giữa các tài liệu — phát hiện xung đột, thiếu sót,
> thừa nội dung giữa tài liệu trước và sau.
>
> **Cách sử dụng:**
>
> 1. Khi tạo tài liệu mới → tra bảng "Input chi tiết" để biết cần đọc file nào, lấy thông tin gì
> 2. Khi review tài liệu → dùng "Checklist kiểm tra xung đột" cuối mỗi phase
> 3. Khi phát hiện lỗi → tra "Ma trận field-level" để biết cần sửa ở đâu
>
> **Quan hệ với file khác trong `_meta/`:**
>
> - `dependency-detail-map.md` — **File này** — Chi tiết field-level + checklist kiểm tra xung đột
> - `README.md` — Tổng quan + AI Reading Guide + Verify Sync + Glossary

---

## Mục Lục

1. [Phase 0 → Phase 1: Dữ liệu truyền chi tiết](#1-phase-0--phase-1)
2. [Chuỗi phụ thuộc nội bộ Phase 1](#2-chuỗi-phụ-thuộc-nội-bộ-phase-1)
3. [Phase 1 → Phase 2: Ma trận field-level](#3-phase-1--phase-2)
4. [Phase 1 → Phase 3: Dữ liệu kiến trúc](#4-phase-1--phase-3)
5. [Chuỗi phụ thuộc nội bộ Phase 2 và Phase 3](#5-chuỗi-phụ-thuộc-nội-bộ-phase-2-và-phase-3)
6. [Phase 2+3 → Phase 4: Dữ liệu UX](#6-phase-23--phase-4)
7. [Phase 2+3+4 → Phase 5: Dữ liệu cho implementation](#7-phase-234--phase-5)
8. [Phase 3+4+5 → Phase 6: Dữ liệu cho vận hành](#8-phase-345--phase-6)
9. [Checklist kiểm tra xung đột theo từng cặp file](#9-checklist-kiểm-tra-xung-đột)
10. [Bảng tổng hợp toàn bộ file-to-file](#10-bảng-tổng-hợp)
11. [Change Propagation — Lan truyền thay đổi](#11-change-propagation)

---

## 1. Phase 0 → Phase 1

### 1a. Nội bộ Phase 0: P0-01 → P0-02

P0-01 là file duy nhất không phụ thuộc file nào — điểm khởi đầu của toàn bộ chuỗi.
P0-02 đọc P0-01 để agents (architect, BA) phân tích hệ thống, users/roles, NFR, tech stack.

| Phần trong P0-01 | Dữ liệu cụ thể | Mục nhận trong P0-02 | Cách kiểm tra khớp |
| --- | --- | --- | --- |
| **Section 1** — Thông tin cơ bản | Ngành nghề, quy mô, nền tảng, ràng buộc KT | Section 1.1 (loại hệ thống), Section 3 (NFR scale), Section 4 (tech stack) | Nền tảng "Web+Mobile" → P0-02 phải có hệ thống Web + Mobile |
| **Section 2** — Phòng ban | Danh sách phòng ban + chức năng | Section 2.1 (roles suy từ phòng ban) | Mỗi PB "Sẽ dùng = Có" → ít nhất 1 role trong P0-02.Section2.1 |
| **Section 3** — Phạm vi hệ thống | Phân hệ + giai đoạn + hệ thống hiện có | Section 1.1 (hệ thống), Section 1.2 (quan hệ) | Phân hệ trong P0-01 → hệ thống phục vụ trong P0-02 |
| **Section 4** — Đối tượng người dùng | Hệ thống → nhóm người dùng (4.1), phân loại nhóm + cần đăng nhập không (4.2), nhận xét kiến trúc (4.3) | Section 1.1 (xác nhận loại hệ thống), Section 2.1 (roles suy từ nhóm người dùng) | Nhóm người dùng trong P0-01.Section4.2 → roles chi tiết trong P0-02.Section2; kiến trúc nội bộ/bên ngoài trong 4.3 → phải nhất quán với P0-02.Section2.4 (auth) |

### 1b. Nội bộ Phase 0: P0-01.Section 5.2/5.3 → policies/

| Phần trong P0-01 | Trigger | Output | Cách kiểm tra |
| --- | --- | --- | --- |
| **Section 5.2** — Chính sách "Chưa có" / "Có 1 phần" | Agent xác định gaps | `policies/[ten-chinh-sach].md` | Mỗi mục "Chưa có"/"Có 1 phần" → có file policy tương ứng |
| **Section 5.3** — Bảng agent phụ trách + nội dung soạn | Domain expert soạn thảo | `policies/[ten-chinh-sach].md` | Số dòng trong bảng 5.3 = số files thực tế trong policies/ |

### 1c. P0-01 → Các file Phase 1

| Phần trong P0-01 | Dữ liệu cụ thể | File nhận | Mục nhận cụ thể | Cách kiểm tra khớp |
| --- | --- | --- | --- | --- |
| **Section 1** — Thông tin cơ bản | Tên tổ chức, ngành nghề, quy mô | **P1-01** | Mục 1: Thông tin chung | Tên, ngành, quy mô phải giống nhau |
| Section 1 | Cách kiếm tiền, sản phẩm | **P1-02** | Mục 1: Mô hình kinh doanh | Loại hình KD, sản phẩm/dịch vụ phải khớp |
| Section 1 | Thời gian mong muốn | **P1-01** | Mục 1: Thời gian | Mốc thời gian phải nhất quán |
| **Section 2** — Phòng ban | Danh sách phòng ban + chức năng | **P1-02** | Mục 2: Các bộ phận tham gia | Số phòng ban, tên phải khớp |
| Section 2 | Phòng ban + chức năng → suy ra nhóm người dùng | **P1-01** | Mục 5: Đối tượng sử dụng | Mỗi PB "Có" → ít nhất 1 nhóm actor trong P1-01.Mục5 |
| Section 2 | Mỗi PB có "Sẽ dùng hệ thống? = Có" | **departments/** | Tạo 1 folder cho mỗi dept | Số folder = số PB đánh dấu "Có" |
| **Section 3** — Phạm vi | Danh sách phân hệ + giai đoạn | **P1-01** | Mục 4: Phạm vi hệ thống | Danh sách phân hệ, giai đoạn phải giống nhau |
| Section 3.2 | Mảng KHÔNG làm | **P1-01** | Mục 4: Không bao gồm | Exclusions phải khớp |
| Section 3.3 | Hệ thống bên ngoài cần kết nối | **P1-01** | Mục 6: Phối hợp giữa phân hệ | Tên hệ thống bên ngoài phải khớp |
| Section 3.3 | Hệ thống bên ngoài | **P1-02** | Mục 5: Bên liên quan bên ngoài | Tên + loại quan hệ phải khớp |
| **Section 4** — Đối tượng người dùng | Nhóm người dùng theo hệ thống (4.1) + phân loại nhóm (4.2) | **P1-01** | Mục 5: Đối tượng sử dụng | Nhóm người dùng P0-01.Section4 phải khớp với actors trong P1-01.Mục5 (có thể mở rộng, không được thu hẹp) |
| **Section 5.1** — Tuân thủ pháp lý | Quy định pháp luật (agent phân tích) | **P1-01** | Mục 7: Giới hạn & Giả định | Quy định phải xuất hiện đầy đủ, không mất |
| **Section 6** — Chốt khung | Tóm tắt dự án | **P1-01** | Mục 3: Mục tiêu dự án | Mục tiêu tóm tắt phải nhất quán |

### 1d. P0-02 → Các file Phase 1 và Phase 3

| Phần trong P0-02 | Dữ liệu cụ thể | File nhận | Mục nhận cụ thể | Cách kiểm tra khớp |
| --- | --- | --- | --- | --- |
| **Section 1** — Bản đồ hệ thống | Danh sách hệ thống + loại (Web/Mobile/API) | **P1-01** | Mục 4: Phạm vi hệ thống | Số hệ thống, tên, loại phải khớp |
| Section 1.2 | Quan hệ giữa các hệ thống (chung backend/riêng) | **P1-02** | Mục 3: Luồng KD — handoff points | Hệ thống chung/riêng phải khớp |
| Section 1.3 | Thứ tự xây dựng & phụ thuộc | **P1-01** | Mục 4: Giai đoạn triển khai | Thứ tự phải nhất quán |
| **Section 2** — Users & Roles | Danh sách roles toàn hệ thống | **P1-01** | Mục 5: Đối tượng sử dụng | Roles = actors (Vietnamese ↔ English mapping rõ ràng) |
| Section 2.2 | Phân quyền tổng quát (ai được làm gì) | **P1-01** | Mục 5: Đối tượng sử dụng | Context quyền phải nhất quán |
| Section 2.4 | Cơ chế xác thực đề xuất | **P3-01** | Mục 8.1: Auth & Authorization | Auth model phải nhất quán (trừ khi Phase 3 thay đổi có lý do) |
| Section 2.5 | Quản lý tài khoản | **P3-01** | Mục 8.1: Auth — account lifecycle | Quy tắc tạo/vô hiệu hóa TK phải khớp |
| **Section 3** — NFR | Concurrent users, transactions/ngày, response time | **P1-01** | Mục 9: Yêu cầu chất lượng (business language) | NFR kỹ thuật → business quality statement (khác ngôn ngữ, cùng ý nghĩa) |
| Section 3.2 | Uptime, maintenance window, backup | **P3-01** | Mục 8: Cross-cutting concerns | Availability/backup targets phải nhất quán |
| **Section 4** — Tech Stack Đề Xuất | Backend, Frontend, DB, Infra | **P3-01** | Mục 1: Quyết định kiến trúc | Tech stack P0 = starting point cho P3 (có thể thay đổi với lý do ghi nhận) |

### 1e. policies/ → Phase 1 và Phase 2

Các file policies được soạn bởi domain experts trong Phase 0. Chúng cung cấp business rules cho downstream.

| File policy | Dữ liệu | File nhận | Mục nhận | Cách kiểm tra |
| --- | --- | --- | --- | --- |
| `policies/[name].md` Section 2 | Quy tắc nghiệp vụ, mức, điều kiện | **[dept].md (Phần A)** | A3: Quy tắc nghiệp vụ (context) | Policy rules phải phản ánh trong REQ chi tiết |
| `policies/[name].md` Section 2 | Quy tắc nghiệp vụ | **phase2-features/[feature].md** | Mục 3: BR-xxx | Mỗi rule quan trọng trong policy → BR tương ứng |
| `policies/[name].md` Section 4 | Quy trình phê duyệt | **[dept].md (Phần B)** | B3: Quy trình phê duyệt | Luồng phê duyệt phải khớp |

### 1f. P0-01 + P0-02 → req-registry.json (gián tiếp qua /analyze-requirements)

| Dữ liệu | Phần nguồn | Field registry | Cách xác định |
| --- | --- | --- | --- |
| Loại giao diện (interface_type) | P0-01.Section1 (nền tảng) + P0-02.Section1 (hệ thống) | `interface_type` | "web" / "mobile" / "web+mobile" / "api-only" — suy từ nền tảng và loại hệ thống |

> **Tại sao quan trọng:** `interface_type` quyết định Phase 4 (UX/UI) có chạy hay không.
> Nếu `api-only` → bỏ qua Phase 4 hoàn toàn.
> `/wf-analyze-requirements` đọc P0-01 + P0-02 + P1-01.Mục7 để xác định và ghi vào registry.

### 1g. Tất cả Phase 0 → stakeholder-review.md (P0)

| Phần stakeholder-review | Input bắt buộc | Kiểm tra cụ thể |
| --- | --- | --- |
| **Phần B** Cross-Document Review | P0-01, P0-02, policies/ | 1) P0-01.§4.1 (hệ thống) = P0-02.§1.1 (hệ thống)? 2) P0-01.§4.2 (nhóm user) → P0-02.§2.1 (roles) đầy đủ? 3) PB (§2) → phân hệ (§3.1) → hệ thống (P0-02.§1.1) chuỗi ánh xạ đầy đủ? 4) P0-01.§5.3 gaps → policies/ files tương ứng? 5) P0-01.§4.3 kiến trúc → P0-02 phản ánh? |
| **Phần C** Consistency Check | TẤT CẢ Phase 0 files | 1) Thuật ngữ: cùng 1 khái niệm gọi giống nhau giữa P0-01, P0-02, policies? 2) Số liệu: phòng ban, hệ thống, phân hệ khớp nhau? 3) Phạm vi: platform, excluded scope, integrations nhất quán? 4) Phân quyền: nhóm user ↔ roles ↔ auth mechanism nhất quán? |
| **Phần D** Gap Analysis | TẤT CẢ Phase 0 files | 1) Thông tin cơ bản đủ? 2) PB/phân hệ thiếu? 3) Nhóm user thiếu? 4) Chính sách/tuân thủ thiếu? 5) Kỹ thuật P0-02 đủ? 6) Tính năng ngầm định bị bỏ sót? |

### Checklist kiểm tra Phase 0 nội bộ + P0→P1

```
□ Nội bộ Phase 0 (P0-01 ↔ P0-02):
  □ P0-01.Section1 (nền tảng) → P0-02.Section1 (loại hệ thống Web/Mobile/API) nhất quán
  □ P0-01.Section2 (PB "Có") → mỗi PB có ít nhất 1 role trong P0-02.Section2.1
  □ P0-01.Section3 (phân hệ) → mỗi phân hệ ánh xạ tới ít nhất 1 hệ thống trong P0-02.Section1.1
  □ P0-01.Section4.1 (hệ thống → đối tượng) → nhất quán với P0-02.Section1.1 (loại hệ thống)
  □ P0-01.Section4.2 (nhóm người dùng) → P0-02.Section2.1 (roles chi tiết hơn, không được thiếu nhóm)
  □ P0-01.Section4.3 (nhận xét kiến trúc) → nhất quán với P0-02.Section2.4 (auth mechanism)
  □ P0-02.Section4 (tech stack) nhất quán với P0-01.Section1 (ràng buộc KT)

□ Nội bộ Phase 0 (policies/):
  □ P0-01.Section5.2 mục "Chưa có"/"Có 1 phần" → có file tương ứng trong policies/
  □ P0-01.Section5.3 (bảng agent) → khớp với files thực tế trong policies/
  □ Mỗi policy file đã được user xác nhận (Section 5: Xác Nhận)

□ P0-01 → Phase 1:
  □ Tên tổ chức trong P0-01.Section1 = P1-01.Mục1
  □ Số PB trong P0-01.Section2 ("Sẽ dùng = Có") = số folder trong departments/
  □ Tên PB trong P0-01.Section2 = tên folder trong departments/
  □ Mỗi PB "Có" trong P0-01.Section2 → ít nhất 1 nhóm actor trong P1-01.Mục5
  □ Danh sách phân hệ trong P0-01.Section3 = P1-01.Mục4 (bao gồm giai đoạn)
  □ Danh sách "Không làm" trong P0-01.Section3.2 = P1-01.Mục4 "Không bao gồm"
  □ Hệ thống bên ngoài trong P0-01.Section3.3 = P1-02.Mục5
  □ Quy định pháp luật trong P0-01.Section5.1 = P1-01.Mục7 + P1-02.Mục7
  □ interface_type xác định từ P0-01.Section1 + P0-02.Section1 → req-registry.json

□ P0-02 → Phase 1 + Phase 3:
  □ P0-02.Section1.1 (hệ thống) = P1-01.Mục4 (phạm vi)
  □ P0-02.Section2.1 (roles) ⊇ P1-01.Mục5 (actors) — mapping Vietnamese ↔ English rõ ràng
  □ P0-02.Section3 (NFR kỹ thuật) → P1-01.Mục9 (business quality) — cùng ý nghĩa, khác ngôn ngữ
  □ P0-02.Section2.4 (auth đề xuất) → P3-01.Mục8.1 — nhất quán hoặc có lý do thay đổi
  □ P0-02.Section4 (tech stack) → P3-01.Mục1 — nhất quán hoặc có lý do thay đổi
  □ P1-02.Mục2 (số bộ phận) = P0-01.Section2 (số PB "Có")

□ stakeholder-review.md (Phase 0):
  □ Phần B — P0-01.§4.1 (hệ thống) = P0-02.§1.1 (hệ thống) — cùng danh sách
  □ Phần B — P0-01.§4.2 (nhóm user) → P0-02.§2.1 (roles) — không thiếu nhóm nào
  □ Phần B — PB (§2) → phân hệ (§3.1) → hệ thống (P0-02.§1.1) — chuỗi ánh xạ đầy đủ
  □ Phần B — P0-01.§5.3 gaps → policies/ files — mỗi gap có file
  □ Phần C — Thuật ngữ, số liệu, phạm vi nhất quán giữa P0-01, P0-02, policies
  □ Phần D — Không còn gap nghiêm trọng
  □ Phần A.3 — Tất cả vấn đề đã xử lý xong

□ policies/ → downstream:
  □ Quy tắc trong policies/ → phản ánh trong [dept].md (Phần A) REQ chi tiết
  □ Quy trình phê duyệt trong policies/ → phản ánh trong [dept].md (Phần B) workflow
  □ Business rules trong policies/ → phản ánh trong phase2-features/ BR-xxx
```

---

## 2. Chuỗi Phụ Thuộc Nội Bộ Phase 1

### P1-01 → P1-02

| Dữ liệu từ P1-01              | Mục P1-01            | Mục P1-02 nhận                                               | Cách kiểm tra                                                                        |
| -------------------------------- | --------------------- | -------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Danh sách phân hệ             | Mục 4: Phạm vi      | Mục 3: Luồng KD chính — phân hệ nào xử lý bước nào | Mọi phân hệ trong P1-01 phải xuất hiện ít nhất 1 lần trong luồng KD          |
| Đối tượng sử dụng (actors) | Mục 5: Đối tượng | Mục 2: Các bộ phận — vai trò tương ứng                | Actors trong P1-01 phải tương ứng với người tham gia trong P1-02                |
| Phối hợp phân hệ             | Mục 6                | Mục 3: Luồng KD — thể hiện qua handoff points             | Mô tả phối hợp trong P1-01 phải chi tiết hóa thành bước cụ thể trong P1-02 |

### P1-01 + P1-02 → [dept].md (Phần A)

| Dữ liệu nguồn                | Từ file nào | Section nào                 | Dùng ở [dept].md (Phần A)                         | Mục cụ thể                           | Cách kiểm tra                                                       |
| ------------------------------- | ------------- | ---------------------------- | ---------------------------------------------------- | --------------------------------------- | --------------------------------------------------------------------- |
| Phân hệ phòng ban liên quan | P1-01 Mục 4  | Bảng phân hệ + phòng ban | Nhu cầu chỉ liên quan đến phân hệ trong scope | A2: Tổng hợp nhu cầu                 | REQ-IDs không được tham chiếu phân hệ ngoài scope P1-01       |
| Actors của phòng ban          | P1-01 Mục 5  | Bảng đối tượng          | Ai cần dùng tính năng                            | A1: Những người sẽ dùng            | Vai trò phải nằm trong danh sách actors P1-01                     |
| Vai trò trong luồng KD        | P1-02 Mục 3  | Bảng phòng ban tham gia    | Context cho nhu cầu                                 | A1: Giới thiệu phòng ban             | Mô tả vai trò phải khớp với P1-02                               |
| Handoff points                  | P1-02 Mục 4  | Điểm chuyển giao          | Nhu cầu liên phòng ban                            | A3: REQ-xxx — tình huống đặc biệt | Handoff points trong P1-02 phải được xử lý bởi ít nhất 1 REQ |
| KPIs                            | P1-02 Mục 6  | Chỉ số kinh doanh          | Nhu cầu báo cáo                                   | A5: Báo cáo & Thống kê              | KPIs phải có báo cáo tương ứng                                 |

### P1-01 + P1-02 → [dept].md (Phần B: Workflow)

| Dữ liệu nguồn       | Từ file nào | Section nào         | Dùng ở [dept].md (Phần B) | Mục cụ thể                                    | Cách kiểm tra                                                          |
| ---------------------- | ------------- | -------------------- | ---------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------ |
| Actors của phòng ban | P1-01 Mục 5  | Bảng đối tượng  | Người tham gia quy trình  | B2.[X]: Bảng Người tham gia (trong mỗi quy trình) | Vai trò phải khớp P1-01                                               |
| Luồng KD tổng thể   | P1-02 Mục 3  | Luồng chính + phụ | Context cho AS-IS/TO-BE      | B2: Chi tiết quy trình                          | Quy trình phòng ban phải nhất quán với vị trí trong luồng P1-02 |
| Handoff points         | P1-02 Mục 4  | Điểm chuyển giao  | Điểm tiếp xúc PB khác   | B5: Điểm tiếp xúc                             | Handoff points phải khớp 2 chiều (gửi/nhận)                         |
| Quy định pháp luật | P1-02 Mục 7  | Ràng buộc          | Ràng buộc trong quy trình | B3: Quy trình phê duyệt                       | Nếu quy định yêu cầu phê duyệt → phải có trong quy trình      |

### [dept].md (Phần A) + [dept].md (Phần B) → departments/_index.md

| Dữ liệu tổng hợp                | Từ file nào                        | _index.md Mục nhận | Cách kiểm tra                                                                   |
| ---------------------------------- | ------------------------------------ | -------------------- | --------------------------------------------------------------------------------- |
| Trạng thái hoàn thành           | TẤT CẢ dept files                  | Mục 1              | Mỗi dept phải có [dept].md (Phần A + Phần B) hoàn thành                     |
| Danh sách REQ-IDs theo dept      | TẤT CẢ [dept].md (Phần A) Mục A2 | Mục 2              | Tổng REQ trong _index = tổng REQ trong tất cả [dept].md (Phần A) files       |
| Ưu tiên tổng hợp                | TẤT CẢ [dept].md (Phần A) Mục A2 | Mục 3              | Priority ranking phải nhất quán với mức ưu tiên trong từng file           |
| Nhu cầu liên phòng ban          | TẤT CẢ [dept].md (Phần A) A2 + (Phần B) B5 | Mục 4   | REQ-IDs trùng giữa các dept phải được liệt kê; B5 xác nhận luồng dữ liệu |
| Yêu cầu chất lượng (NFR)       | P1-01 Mục 9 + feedback từ các dept | Mục 5              | NFR phải bao gồm yêu cầu từ P1-01.Mục9 và nhu cầu chung từ các dept      |

### Tất cả Phase 1 → stakeholder-review.md (P1)

| Phần stakeholder-review            | Input bắt buộc                                                          | Kiểm tra cụ thể                                                                                                                                                                                                                                                            |
| -------------------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Phần B** Cross-dept Review    | P1-02, TẤT CẢ `[dept].md (Phần A)`, TẤT CẢ `[dept].md (Phần B)` | 1) B5 (Điểm tiếp xúc PB khác) của mỗi dept — thông tin gửi/nhận có khớp 2 chiều? 2) REQ-IDs có trùng lặp giữa các phòng ban? 3) Quy trình cùng 1 nghiệp vụ ở 2 dept có mâu thuẫn?                                                                |
| **Phần C** Consistency Check    | TẤT CẢ Phase 1 files                                                    | 1) Thuật ngữ: cùng 1 khái niệm có gọi giống nhau giữa P1-01, P1-02, mỗi dept docs? 2) Số liệu/ngưỡng (VD: ngưỡng phê duyệt) có khớp giữa các file? 3) Actors/vai trò có nhất quán? 4) User-needs ↔ workflow: mỗi REQ có quy trình tương ứng? |
| **Phần D** Gap Analysis         | TẤT CẢ Phase 1 files                                                    | 1) Phòng ban nào thiếu tài liệu? 2) Quy trình nào chưa mô tả? 3) Tính năng phổ biến (auth, search, export...) bị bỏ sót? 4) Loại dữ liệu quan trọng chưa liệt kê? 5) Edge cases chưa xử lý? 6) NFR chưa đề cập?                                |

### Checklist kiểm tra xung đột nội bộ Phase 1

```
□ P1-01.Mục4 (danh sách phân hệ) = P1-02.Mục3 (phân hệ xuất hiện trong luồng KD)
□ P1-01.Mục5 (actors) ⊇ tất cả vai trò trong mọi [dept].md (Phần A).A1
□ P1-01.Mục5 (actors) ⊇ tất cả vai trò trong mọi [dept].md (Phần B).B2.[X] (Bảng Người tham gia)
□ P1-02.Mục4 (handoff points) — mỗi điểm chuyển giao phải xuất hiện trong:
  □ [dept].md (Phần B).B5 (phía gửi)
  □ [dept].md (Phần B).B5 (phía nhận)
□ P1-02.Mục6 (KPIs) — mỗi KPI phải có ít nhất 1 REQ-ID tương ứng trong [dept].md (Phần A)
□ P1-02.Mục7 (quy định) — mỗi quy định phải phản ánh trong quy trình phê duyệt tương ứng
□ Mỗi phòng ban: tổng REQ-IDs trong [dept].md (Phần A).A2 = số REQ chi tiết trong A3
□ Mỗi phòng ban: mỗi REQ trong A3 phải có quy trình tương ứng trong [dept].md (Phần B).B2
□ _index.md Mục 4 (liên phòng ban) — REQ trùng giữa các dept phải được liệt kê đầy đủ
□ _index.md Mục 5 (NFR) — phải bao gồm P1-01.Mục9 và yêu cầu chất lượng từ các dept
□ Thuật ngữ: cùng 1 entity (VD: "khách hàng") phải gọi giống nhau ở TẤT CẢ files
□ Ngưỡng phê duyệt: nếu đề cập ở nhiều file, giá trị phải giống nhau
```

---

## 3. Phase 1 → Phase 2

### Phase 1 → phase2-features/[sys]/[mod]/[feature].md

`/wf-define-features` đọc Phase 1 để tạo feature specs trong Phase 2.

| Dữ liệu cần                         | Từ file Phase 1    | Mục nguồn               | Mục đích trong feature file                  | Cách kiểm tra khớp                                             |
| -------------------------------------- | ------------------- | ------------------------- | ----------------------------------------------- | ----------------------------------------------------------------- |
| REQ-IDs + tên nhu cầu                | [dept].md (Phần A) | Mục A2: Bảng tổng hợp | Header: Yêu cầu nghiệp vụ                   | REQ-IDs trong feature header ⊆ REQ-IDs trong [dept].md (Phần A) |
| "Tôi cần hệ thống làm được..." | [dept].md (Phần A) | Mục A3: Chi tiết REQ    | Mục 2: User Stories                            | Mỗi điều "tôi cần" → 1 user story                           |
| Quy tắc nghiệp vụ                   | [dept].md (Phần A) | Mục A3: Quy tắc         | Mục 3: Quy tắc nghiệp vụ (BR-xxx)           | Mỗi quy tắc = 1 BR-xxx, không được mất                     |
| Tình huống đặc biệt               | [dept].md (Phần A) | Mục A3: Tình huống     | Mục 5: Trường hợp đặc biệt               | Mỗi tình huống phải có xử lý tương ứng                  |
| Ai cần dùng + vai trò               | [dept].md (Phần A) | Mục A1 + A3              | Mục 4: Bảng phân quyền                      | Mỗi vai trò = 1 cột trong bảng phân quyền                   |
| Dữ liệu cần quản lý               | [dept].md (Phần A) | Mục A4                   | Mục 7: Tóm tắt Entity                        | Mỗi loại dữ liệu → entity fields                             |
| Nhu cầu báo cáo & thống kê          | [dept].md (Phần A) | Mục A5                   | Feature báo cáo: Mục 2 (User Stories) + Mục 7 (Entity) | Mỗi báo cáo cần → 1 feature spec (hoặc gộp vào feature dashboard) |
| Quy trình TO-BE                       | [dept].md (Phần B) | Mục 2: TO-BE             | Mục 6: State Machine                           | Trạng thái trong TO-BE → states; bước chuyển → transitions |
| Quy trình phê duyệt                 | [dept].md (Phần B) | Mục 3                    | Mục 4: Phân quyền (hành động cần duyệt) | Mỗi điểm phê duyệt → approval action trong state machine    |
| Ngoại lệ                             | [dept].md (Phần B) | Mục 4                    | Mục 5: Trường hợp đặc biệt               | Ngoại lệ từ workflow phải được xử lý trong feature       |
| Liên hệ PB khác                     | [dept].md (Phần B) | Mục 5                    | Header: Phụ thuộc (cross-system)              | Điểm tiếp xúc → dependency với feature khác                |
| Điều PB KHÔNG muốn                  | [dept].md (Phần A) | Mục A6                   | Mục 5: Trường hợp đặc biệt + Constraints | Mỗi exclusion → constraint hoặc note trong feature          |
| Đánh giá Team Expert                | [dept].md (Phần A) | Mục A7                   | Header: Ghi chú Expert (A7) + phản ánh trong Mục 1-7 | Điều chỉnh từ Expert phải ghi trong header + phản ánh trong feature specs |

### P1-01 Mục 8 (Các bên liên quan) → Downstream

| Dữ liệu từ P1-01 Mục 8              | Mục đích                                         | File nhận                    | Cách kiểm tra                                                    |
| -------------------------------------- | --------------------------------------------------- | ----------------------------- | ------------------------------------------------------------------ |
| Chủ dự án (Sponsor)                  | Người phê duyệt architecture decisions            | P3-01 (stakeholder approval) | Tên sponsor phải nhất quán                                      |
| Đại diện nghiệp vụ                  | Người xác nhận requirements + UAT                  | stakeholder-review (mọi phase) | Tên phải nhất quán qua các phase                                |
| Đội phát triển                       | Context cho resource planning                       | P5-00 roadmap                 | Team size ảnh hưởng sprint capacity                             |

### Phase 1 → req-registry.json

| Dữ liệu      | Từ file            | Mục                    | Field trong registry        |
| -------------- | ------------------- | ----------------------- | --------------------------- |
| REQ-IDs        | [dept].md (Phần A) | A2: Bảng tổng hợp    | `requirements[].id`       |
| Tên nhu cầu  | [dept].md (Phần A) | A2: Tên nhu cầu       | `requirements[].title`    |
| Phòng ban     | [dept].md (Phần A) | Header: Phòng ban      | `requirements[].dept`     |
| Mức ưu tiên | [dept].md (Phần A) | A2: Mức độ ưu tiên | `requirements[].priority` |
| FEAT mapping  | `/wf-define-features` output | Phase 2 feature specs | `requirements[].mapped_features[]` — cập nhật bởi `/wf-define-features` |
| REQ reverse   | `/wf-define-features` output | Phase 2 feature specs | `features[].req_ids[]` — reverse mapping FEAT→REQ |

### Checklist kiểm tra P1→P2

```
□ Mỗi "tôi cần" trong [dept].md (Phần A).A3 → có user story tương ứng trong feature file
□ Mỗi quy tắc nghiệp vụ trong [dept].md (Phần A).A3 → có BR-xxx trong feature file
□ Mỗi tình huống đặc biệt trong [dept].md (Phần A).A3 → có xử lý trong feature.Mục5
□ Mỗi loại dữ liệu trong [dept].md (Phần A).A4 → có entity trong feature.Mục7
□ Mỗi báo cáo trong [dept].md (Phần A).A5 → có feature spec báo cáo/dashboard tương ứng
□ Mỗi bước TO-BE trong workflow → có trạng thái/transition trong feature.Mục6
□ Mỗi điểm phê duyệt trong workflow.Mục3 → có permission check trong feature.Mục4
□ Mỗi exclusion trong [dept].md (Phần A).A6 → có constraint/note tương ứng trong feature
□ Mỗi điều chỉnh từ Expert trong [dept].md (Phần A).A7.3 → đã phản ánh trong feature specs + ghi tóm tắt trong header "Ghi chú Expert (A7)"
□ Mỗi REQ-ID trong req-registry.json → có ít nhất 1 FEAT-ID trong mapped_features[]
□ Mỗi FEAT-ID trong features[] → có req_ids[] trỏ ngược về đúng REQ-IDs (bidirectional mapping)
□ Issues từ P1 stakeholder-review.md → đã được xử lý (không còn outstanding)
```

### Tất cả Phase 2 → phase2-features/stakeholder-review.md

| File SO                                     | Input bắt buộc                              | Kiểm tra cụ thể                                                                                                                                          |
| ------------------------------------------- | --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Phần B** Feature Review            | TẤT CẢ phase2-features/*, req-registry.json | 1) REQ coverage: mỗi REQ-ID có feature tương ứng? 2) User stories đầy đủ? 3) Business rules không mâu thuẫn? 4) State machines hợp lý?        |
| **Phần C** Consistency Check         | TẤT CẢ phase2-features/*, Phase 1 docs      | 1) Thuật ngữ: entity names nhất quán giữa features và Phase 1? 2) Actors/roles nhất quán? 3) Scope: feature không vượt ngoài scope P1-01.Mục4? |
| **Phần D** Gap Analysis              | TẤT CẢ phase2-features/*                    | 1) REQ-ID nào chưa có feature? 2) Feature nào thiếu user stories? 3) Edge cases chưa xử lý? 4) Cross-system dependencies chưa khai báo?           |

---

## 4. Phase 1 → Phase 3

### Phase 1 → phase3-architecture/P3-01-architecture.md

`/wf-design` đọc Phase 1 để tạo kiến trúc tổng thể trong Phase 3.

| Dữ liệu cần                     | Từ file Phase 1                      | Mục nguồn           | Mục đích trong P3-01                      | Cách kiểm tra khớp                                                  |
| ---------------------------------- | ------------------------------------- | --------------------- | -------------------------------------------- | ---------------------------------------------------------------------- |
| Danh sách phân hệ + giai đoạn | P1-01                                 | Mục 4: Phạm vi      | Mục 3: Danh sách phân hệ (SYS-IDs)       | Mỗi phân hệ trong P1-01 = 1 dòng trong bảng P3-01.Mục3           |
| Actors/người dùng               | P1-01                                 | Mục 5: Đối tượng | Mục 8.1: Auth roles + permission model      | Mỗi nhóm actors = 1 role trong RBAC table                            |
| Phối hợp phân hệ               | P1-01                                 | Mục 6                | Mục 5: Giao tiếp giữa phân hệ           | Mỗi mô tả phối hợp → sync hoặc async call                       |
| Ràng buộc kỹ thuật             | P1-01                                 | Mục 7: Giới hạn    | Mục 1: Quyết định kiến trúc            | VD: "web-based" → frontend framework; "server nội bộ" → on-premise |
| Yêu cầu chất lượng            | P1-01                                 | Mục 9                | Mục 6: Quy ước + Mục 8.4: Caching        | VD: "phản hồi < 3s" → caching strategy                              |
| Tóm tắt nhu cầu tổng hợp      | dept/_index                           | Tổng hợp            | Mục 1: Quy mô → quyết định kiến trúc | Số REQ, số dept → monolith vs microservices                         |
| Issues đã phát hiện            | phase1-business/stakeholder-review.md | Tổng kết            | Giải quyết trước khi thiết kế          | Issues nghiêm trọng phải có giải pháp trong P3-01                |
| Hệ thống bên ngoài             | P1-02                                 | Mục 5                | Mục 5: External integrations                | Mỗi hệ thống bên ngoài = 1 integration point                      |
| Quy định pháp luật             | P1-02                                 | Mục 7                | Mục 8: Cross-cutting (audit, compliance)    | VD: "E-Invoice" → integration spec; "GDPR" → encryption              |

### Checklist kiểm tra P1→P3

```
□ Mỗi phân hệ trong P1-01.Mục4 → có 1 dòng trong P3-01.Mục3
□ Mỗi actor trong P1-01.Mục5 → có 1 role trong P3-01.Mục8.1
□ Mỗi hệ thống bên ngoài trong P1-02.Mục5 → có 1 entry trong P3-01.Mục5 hoặc integration-map
□ Mỗi quy định pháp luật trong P1-02.Mục7 → có giải pháp kỹ thuật trong P3-01.Mục8
□ Issues từ phase1-business/stakeholder-review.md → không còn outstanding
```

### Tất cả Phase 3 → phase3-architecture/stakeholder-review.md

| File SO                                     | Input bắt buộc                     | Kiểm tra cụ thể                                                                                                                                                                                                                                                                                                      |
| ------------------------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Phần B** Technical Review          | P3-01, TẤT CẢ technical-specs/*    | 1) Cross-spec relationship: API endpoint có table tương ứng? 2) Architecture conflict: P3-01 conventions có được tuân thủ? 3) Duplicate definitions: cùng 1 entity mô tả ở nhiều spec có khớp? 4) Integration points: sync/async patterns trong P3-01 ↔ integration-map?                              |
| **Phần C** Consistency Check         | TẤT CẢ Phase 3 + req-registry.json | 1) Thuật ngữ: entity names khớp giữa phase2-features, api-contract, database-design? 2) Status ENUMs: values giống nhau giữa feature state machine, DB CHECK, API ENUM? 3) API ↔ DB field matching: DTO fields khớp table columns? 4) Role definitions: nhất quán giữa P3-01, phase2-features, api-contract? |
| **Phần D** Gap Analysis              | TẤT CẢ Phase 3                     | 1) Missing API endpoints: feature có user story nhưng chưa có endpoint? 2) Missing DB tables: feature có entity nhưng chưa có DDL? 3) NFR gaps: P1-01.Mục9 có yêu cầu chưa kỹ thuật hóa? 4) Security gaps: auth, encryption, audit trail đủ chưa? 5) Edge cases chưa xử lý?                       |

---

## 5. Chuỗi Phụ Thuộc Nội Bộ Phase 2 và Phase 3

### P3-01 → phase2-features

> *Ghi chú: Đây là hướng kiểm tra nhất quán, không phải hướng tạo tài liệu.
> Features được tạo trước (Phase 2 bởi `/wf-define-features`), P3-01 tạo sau (Phase 3 bởi `/wf-design`)
> nhưng P3-01 phải tham chiếu và nhất quán với features đã định nghĩa.*

| Dữ liệu từ P3-01                   | Mục P3-01 | Dùng trong feature file           | Mục feature     | Cách kiểm tra                                |
| ------------------------------------- | ---------- | ---------------------------------- | ---------------- | ---------------------------------------------- |
| System ID (SYS-XXX)                   | Mục 3     | Header: Phân hệ                  | Header           | SYS-ID phải nằm trong danh sách P3-01.Mục3 |
| Schema DB                             | Mục 3     | Entity thuộc schema nào          | Mục 7           | Schema phải khớp với P3-01                  |
| Data ownership                        | Mục 4     | Entity thuộc system nào sở hữu | Mục 7: Ghi chú | Entity chỉ được ghi bởi system sở hữu   |
| Auth model (RBAC/ABAC)                | Mục 8.1   | Cách thiết kế phân quyền      | Mục 4           | Model phải nhất quán                        |
| Quy ước (ID format, soft delete...) | Mục 6     | Entity conventions                 | Mục 7           | UUID, soft delete, timestamps phải tuân thủ |

### P3-01 → Technical Specs

#### P3-01 → phase3-architecture/technical-specs/api-contract.md

| Dữ liệu từ P3-01                  | Mục P3-01                     | Mục api-contract                                      | Cách kiểm tra                                              |
| ------------------------------------ | ------------------------------ | ------------------------------------------------------ | ------------------------------------------------------------ |
| Pagination defaults (page size, max) | Mục 6: Quy ước              | Mục 1: Global Conventions — pagination               | Giá trị default/max phải giống nhau                      |
| ID format (UUID v4, etc.)            | Mục 6: Quy ước              | Mục 1: Global Conventions — ID format                | Format phải nhất quán                                     |
| Soft delete convention               | Mục 6: Quy ước              | Mục 1: Global Conventions — soft delete              | DELETE behavior phải khớp                                  |
| Auth model (RBAC/ABAC)               | Mục 8.1: Auth & Authorization | Mục 5: Authentication Endpoints                       | Auth flow phải khớp P3-01                                  |
| Auth roles + permissions             | Mục 8.1: RBAC table           | Mục 6: Endpoints — auth requirement per endpoint     | Roles trong api-contract ⊆ roles trong P3-01                |
| Error handling strategy              | Mục 8.2: Error Handling       | Mục 2-4: Response Envelopes, HTTP Status, Error Codes | Error format phải khớp P3-01                               |
| Logging correlation ID               | Mục 8.3: Logging              | Mục 1: Global Conventions — headers                  | Nếu P3-01 yêu cầu correlation → API phải truyền header |

#### P3-01 → phase3-architecture/technical-specs/database-design.md

| Dữ liệu từ P3-01                 | Mục P3-01                   | Mục database-design                               | Cách kiểm tra                                                 |
| ----------------------------------- | ---------------------------- | -------------------------------------------------- | --------------------------------------------------------------- |
| Danh sách phân hệ (SYS-IDs)      | Mục 3: System List          | Mục 1: Schema Organization — schema per system   | Mỗi SYS-ID = 1 schema (hoặc schema group)                     |
| Data ownership                      | Mục 4: Data Ownership       | Mục 3: System-Specific Tables — owner annotation | Entity chỉ thuộc schema của system sở hữu                  |
| ID format (UUID v4)                 | Mục 6: Quy ước            | Mục 4: Common Patterns — ID generation           | UUID format phải khớp                                         |
| Soft delete convention              | Mục 6: Quy ước            | Mục 4: Common Patterns — soft delete             | `deleted_at` pattern phải nhất quán                        |
| Timestamp convention                | Mục 6: Quy ước            | Mục 4: Common Patterns — auto-update             | `created_at`, `updated_at` phải có theo convention        |
| Communication patterns (sync/async) | Mục 5: System Communication | Mục 3: Cross-schema references                    | Nếu P3-01 nói "chỉ qua API" → DB KHÔNG có FK cross-schema |

#### P3-01 → phase3-architecture/technical-specs/integration-map.md

| Dữ liệu từ P3-01                   | Mục P3-01                   | Mục integration-map                                | Cách kiểm tra                                                    |
| ------------------------------------- | ---------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------ |
| Danh sách phân hệ (SYS-IDs)        | Mục 3: System List          | Mục 2-3: Caller/Callee systems                     | Systems trong integration phải ⊆ systems trong P3-01.Mục3      |
| Data ownership rules                 | Mục 4: Data Ownership       | Mục 1: Rules + Mục 8: Data Consistency Rules       | "Chỉ đọc qua API" → integration calls, không FK trực tiếp     |
| Giao tiếp giữa phân hệ (sync/async)| Mục 5: System Communication | Mục 2: Sync calls + Mục 3: Async events            | Mỗi entry trong P3-01.Mục5 phải có chi tiết trong integration   |
| Message queue technology              | Mục 1: Tech Stack           | Mục 5: Event Infrastructure                        | Queue technology (RabbitMQ/Kafka/...) phải khớp                   |
| Error handling strategy               | Mục 8.2: Error Handling     | Mục 2: Failure handling + Mục 9: Compensation      | Retry/timeout strategy phải nhất quán với P3-01                  |

#### P3-01 → phase3-architecture/technical-specs/infra-spec.md

| Dữ liệu từ P3-01                  | Mục P3-01                     | Mục infra-spec                                       | Cách kiểm tra                                                     |
| ------------------------------------ | ------------------------------ | ------------------------------------------------------ | ------------------------------------------------------------------- |
| Tech stack (DB, cache, queue)        | Mục 1: Quyết Định Kiến Trúc | Mục 2: ENV vars (DATABASE_URL, REDIS_URL)            | ENV vars phải khớp tech stack đã chọn trong P3-01               |
| Môi trường triển khai              | Mục 7: Environments           | Mục 1: Environments                                  | URL, branch, deploy strategy phải khớp giữa P3-01 và infra-spec |
| Caching strategy                     | Mục 8.4: Caching Strategy     | Mục 3: Server Specs (Redis)                          | Redis RAM/replicas phải đủ cho caching plan trong P3-01          |
| Logging format + level               | Mục 8.3: Logging              | Mục 2: LOG_LEVEL ENV + Mục 5: Storage (Logs)        | Log level, format, retention phải nhất quán                       |
| Auth token TTL                       | Mục 8.1: Auth Flow            | Mục 2: JWT_EXPIRES_IN, JWT_REFRESH_EXPIRES_IN        | Token TTL trong ENV vars phải khớp auth flow trong P3-01          |

### phase2-features → Technical Specs (Phase 3)

#### phase2-features → api-contract.md

| Dữ liệu từ feature          | Mục feature | Mục API contract                | Cách kiểm tra khớp                                             |
| ------------------------------ | ------------ | -------------------------------- | ----------------------------------------------------------------- |
| User Stories (CRUD operations) | Mục 2       | Mục 6: Endpoints by System      | Mỗi user story "tạo/xem/sửa/xóa" → có endpoint tương ứng |
| Quy tắc nghiệp vụ (BR-xxx)  | Mục 3       | Request validation + error codes | Mỗi BR → validation rule hoặc error code                       |
| Bảng phân quyền             | Mục 4       | Auth requirement per endpoint    | Endpoint phải ghi rõ role nào được gọi                     |
| State Machine transitions      | Mục 6       | State-change endpoints           | Mỗi transition → endpoint (VD: POST /orders/:id/approve)        |
| FEAT-ID                        | Header       | Mục 6: Cột FEAT-ID             | Mỗi endpoint phải reference FEAT-ID                             |

#### phase2-features → database-design.md

| Dữ liệu từ feature  | Mục feature             | Mục DB design            | Cách kiểm tra khớp                                                |
| ---------------------- | ------------------------ | ------------------------- | -------------------------------------------------------------------- |
| Entity + fields chính | Mục 7: Tóm tắt Entity | Mục 3: DDL tables        | Mỗi entity → 1 table; fields chính phải có columns tương ứng |
| Quan hệ (FK)          | Mục 7: Cột Quan hệ    | DDL: REFERENCES clauses   | FK trong feature.Mục7 = FK trong DDL                                |
| Status ENUM values     | Mục 6: State Machine    | DDL: CHECK constraints    | Giá trị status trong DDL = danh sách states trong feature         |
| Quy tắc unique        | Mục 3: BR-xxx           | DDL: UNIQUE constraints   | Nếu BR nói "không được trùng" → table phải có UNIQUE       |
| Soft delete            | Mục 7: Ghi chú         | DDL:`deleted_at` column | Nếu feature ghi "soft delete" → table phải có `deleted_at`     |
| REQ-ID, FEAT-ID        | Header                   | DDL: Comment header       | Mỗi table DDL phải ghi `-- REQ-ID: ...                             |

#### phase2-features (cross-system) → integration-map.md

| Dữ liệu từ feature                      | Mục feature | Mục integration-map                          | Cách kiểm tra khớp                                                |
| ------------------------------------------ | ------------ | --------------------------------------------- | -------------------------------------------------------------------- |
| Header: Phụ thuộc (FEAT khác system)    | Header       | Mục 2: Sync calls hoặc Mục 3: Async events | Nếu feature phụ thuộc system khác → phải có integration entry |
| BR-xxx liên quan system khác             | Mục 3       | Mục 7: Cross-System Business Rules           | Mỗi BR cross-system → có RULE-XXXX                                |
| State transition ảnh hưởng system khác | Mục 6       | Mục 3: Event khi state change                | VD: Order → APPROVED → publish event cho Warehouse                 |

### Tech Specs interdependencies (Phase 3)

| Spec A                    | Spec B                    | Điểm phải khớp                                                   | Cách kiểm tra                                                                    |
| ------------------------- | ------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **api-contract**    | **database-design** | Entity fields: API request/response body phải khớp DB columns      | So sánh DTO fields ↔ table columns — tên + kiểu dữ liệu                     |
| **api-contract**    | **integration-map** | Internal endpoints: API contract.Mục7 ↔ integration-map.Mục2      | Mỗi sync call trong integration → có endpoint trong api-contract                |
| **api-contract**    | **infra-spec**      | Rate limiting: api-contract.Mục8 ↔ infra-spec config               | Giá trị rate limit phải khớp                                                   |
| **database-design** | **integration-map** | Cross-schema FK: DB cross-schema references ↔ integration contracts | FK cross-schema phải có integration call tương ứng (không query trực tiếp) |
| **integration-map** | **P3-01**           | Communication patterns: P3-01.Mục5 ↔ integration-map.Mục1-3       | Pattern (sync/async) phải nhất quán                                             |
| **infra-spec**      | **P3-01**           | Tech stack: P3-01.Mục1 ↔ infra-spec ENV vars + server specs        | Database URL, Redis URL phải khớp tech stack đã chọn                          |
| **database-design** | **infra-spec**      | DB engine + specs: database-design dùng PostgreSQL features → infra-spec phải spec PostgreSQL | DB version, DB_POOL_SIZE, storage size trong infra-spec phải phù hợp với DB design |

### Checklist kiểm tra xung đột nội bộ Phase 2 và Phase 3

```
□ P3-01.Mục3 (systems) — mỗi SYS-ID phải có ít nhất 1 feature file trong phase2-features/
□ P3-01.Mục4 (data ownership) — entity owner trong P3-01 = schema owner trong database-design
□ P3-01.Mục5 (giao tiếp) — mỗi sync/async call có chi tiết trong integration-map
□ P3-01.Mục6 (quy ước) — ID format, soft delete, pagination áp dụng đồng bộ trong api-contract + database-design
□ P3-01.Mục8.1 (auth model) — RBAC roles khớp giữa P3-01, api-contract (auth header), feature files (phân quyền)
□ P3-01.Mục8.2 (error handling) — error format trong P3-01 = format trong api-contract.Mục2-4

□ Feature files (phase2-features/):
  □ Mỗi feature → có endpoints trong api-contract
  □ Mỗi feature → có tables trong database-design
  □ Mỗi feature cross-system → có rules trong integration-map

□ api-contract ↔ database-design:
  □ Mỗi POST/PUT DTO field → có DB column tương ứng (tên + kiểu phải khớp)
  □ Mỗi GET response field → có DB column hoặc computed field
  □ Status ENUM values: api-contract = database-design CHECK constraint = feature state machine
  □ Pagination default/max: api-contract.Mục1 = P3-01.Mục6

□ api-contract ↔ integration-map:
  □ Mỗi internal endpoint trong api-contract.Mục7 → có caller trong integration-map.Mục2
  □ Mỗi sync call trong integration-map → có endpoint trong api-contract.Mục7

□ P3-01 ↔ infra-spec:
  □ P3-01.Mục1 (tech stack) — ENV vars trong infra-spec phải khớp (DATABASE_URL cho PostgreSQL, REDIS_URL cho Redis, etc.)
  □ P3-01.Mục7 (environments) — infra-spec.Mục1 environments phải khớp URL, branch, deploy strategy
  □ P3-01.Mục8.1 (auth) — JWT_EXPIRES_IN, JWT_REFRESH_EXPIRES_IN trong infra-spec phải khớp auth flow TTL
  □ P3-01.Mục8.4 (caching) — infra-spec Redis specs (RAM, replicas) phải đủ cho caching plan

□ database-design ↔ infra-spec:
  □ DB engine trong database-design (PostgreSQL 15+) = DB trong infra-spec.Mục3 (server specs) + Mục2 (DATABASE_URL)
  □ DB_POOL_SIZE trong infra-spec phải phù hợp với số tables/queries trong database-design
  □ Storage size trong infra-spec.Mục3 phải đủ cho data volume ước tính từ database-design

□ P3-01 ↔ integration-map:
  □ P3-01.Mục5 sync/async entries → mỗi entry có chi tiết đầy đủ trong integration-map.Mục2-3
  □ P3-01.Mục1 message queue technology = integration-map.Mục5 Event Infrastructure
```

---

## 6. Phase 2+3 → Phase 4

### phase2-features → Phase 4 UX

`/wf-design-ux` đọc Phase 2 (features) và Phase 3 (architecture, api-contract) để tạo UX design trong Phase 4.

| Dữ liệu từ feature | Mục feature | File Phase 4 UX             | Mục UX                           | Cách kiểm tra                                                                 |
| --------------------- | ------------ | --------------------------- | --------------------------------- | ------------------------------------------------------------------------------- |
| User Stories          | Mục 2       | phase4-ux/[sys]/[screen-group].md | Layout + Actions                  | Mỗi story "xem danh sách" → screen có table; "tạo mới" → screen có form |
| Fields chính         | Mục 7       | phase4-ux screen            | Bảng field specs                 | Fields trong UI phải ⊆ fields trong feature entity                            |
| Phân quyền          | Mục 4       | phase4-ux screen            | Actions: Hiển thị/ẩn theo role | Nút/action chỉ visible cho role được phép                                 |
| State Machine         | Mục 6       | phase4-ux screen            | Status badges + action buttons    | Mỗi state → badge color; mỗi transition → button                            |

### UX dependencies (Phase 4)

| File UX                       | Input                                                    | Mục input                                | Cách kiểm tra                                                    |
| ----------------------------- | -------------------------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------ |
| **design-system.md**    | P1-01 (thông tin chung, actors), P3-01 (tech stack, conventions) | P1-01: Mục 1, 5; P3-01: Mục 1, 6       | Tech stack quyết định component library; actors quyết định UX complexity |
| **Navigation-[sys].md** | design-system.md, P3-01.Mục3 (systems), phase2-features/[sys]/* | Design tokens + Danh sách phân hệ + features | Icon library từ design-system; mỗi feature → ít nhất 1 menu item; không có menu item orphan |
| **[screen-group].md**   | phase2-features/[feature].md + design-system + Navigation-[sys].md + api-contract | Feature stories, design tokens, navigation context, endpoints | Mỗi action trong screen phải có API endpoint tương ứng; routes khớp Navigation |

### Checklist kiểm tra nội bộ Phase 4

```
□ Navigation ↔ screen-groups:
  □ Mỗi menu item trong Navigation → có [screen-group].md file tồn tại
  □ Mỗi screen file → có ít nhất 1 menu item trong Navigation
  □ Routes trong Navigation → không trùng lặp

□ UX screens ↔ api-contract:
  □ Mỗi action/button trong screen (save, delete, approve...) → có API endpoint
  □ Mỗi data table trong screen → có GET list endpoint với đúng fields

□ phase2-features → phase4-ux:
  □ Mỗi feature có UI → có screen file trong phase4-ux/
  □ Fields trong screen ⊆ fields trong feature entity (Mục 7)
  □ Role-based visibility trong screen khớp feature phân quyền (Mục 4)
```

### Tất cả Phase 4 → phase4-ux/stakeholder-review.md

| File SO                                      | Input bắt buộc                                                                        | Kiểm tra cụ thể                                                                                                                                                                                                                                                                                                         |
| -------------------------------------------- | --------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Phần B** UX Cross-Review            | design-system, TẤT CẢ Navigation-[sys], TẤT CẢ [screen-group].md, api-contract      | 1) Feature→Screen coverage: mỗi FEAT-ID có screen group? 2) Design system consistency: screens dùng đúng design tokens? 3) Navigation completeness: mọi screen có trong Navigation? 4) API endpoint references: actions trong screen có endpoint tương ứng trong api-contract?                                    |
| **Phần C** Consistency Check          | TẤT CẢ Phase 4 + phase2-features/* + P3-01                                            | 1) User stories reflected: UX design phản ánh đúng user stories từ features? 2) Business rules reflected: BR-xxx có trong UI validation/workflow? 3) Permissions matched: role-based visibility khớp feature phân quyền (Mục 4)? 4) Architecture alignment: UX phản ánh đúng architecture decisions (RBAC, multi-tenant)? |
| **Phần D** Gap Analysis               | TẤT CẢ Phase 4                                                                        | 1) Screen coverage gaps: FEAT-ID nào chưa có screen? 2) Component gaps: components cần nhưng chưa có trong design-system? 3) Accessibility gaps: keyboard nav, screen reader, color contrast, responsive? 4) Orphan screens: screen nào không link từ Navigation?                                                        |

### Checklist kiểm tra Phase 4 SOs

```
□ Phần B: Mỗi FEAT-ID có UI → có screen group tương ứng (không thiếu)
□ Phần B: Mọi screen groups sử dụng design tokens từ design-system (không custom)
□ Phần B: Mọi action/button trong screen → có API endpoint trong api-contract
□ Phần C: User stories trong phase2-features → reflected trong UX layout + actions
□ Phần C: Role-based visibility trong screen = permissions trong phase2-features Mục 4
□ Phần C: Architecture decisions (RBAC, multi-tenant) → reflected trong UI
□ Phần D: Không có orphan screens (screen không trong Navigation)
□ Phần D: Accessibility requirements đã được address
```

---

## 7. Phase 2+3+4 → Phase 5

### Phase 2+3 → phase5-implementation/P5-00-implementation-roadmap.md

`/wf-plan-modules` đọc Phase 2, 3, 4 để tạo roadmap triển khai trong Phase 5.

| Dữ liệu                     | Từ file                                                                                                                    | Mục                          | Mục đích trong P5-00       | Cách kiểm tra                                                 |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ----------------------------- | --------------------------------------------------------------- |
| Danh sách modules + features | req-registry.json                                                                                                            | `modules[]`, `features[]` | Mục 2: Thứ tự triển khai  | Tất cả modules trong registry phải xuất hiện trong roadmap |
| Dependencies giữa features   | phase2-features/*.md                                                                                                         | Header: Phụ thuộc           | Mục 2: Dependency graph      | Feature B phụ thuộc A → A phải implement trước B          |
| Cross-system dependencies     | integration-map.md                                                                                                           | Mục 7: RULE-XXXX             | Mục 2: Blocking dependencies | System A cần gọi B → B phải có API sẵn trước            |
| Design deferred findings      | .mc-data/work/wf-design/deferred-findings.md                                                                                    | DEFERRED items                | Mục: Risks & Blockers        | Blocking items phải giải quyết trước sprint 1               |
| Issues chưa giải quyết     | phase2-features/stakeholder-review.md + phase3-architecture/stakeholder-review.md + phase4-ux/stakeholder-review.md          | Tổng kết                    | Mục: Risks & Blockers        | Issues critical phải giải quyết trước sprint 1             |

### Phase 2+3+4 → phase5-implementation/tasks/[sys]/[mod]/[feature]-impl.md

`/wf-plan-modules` tạo impl plans tổng hợp TOÀN BỘ thông tin cần thiết để implement 1 feature:

| Dữ liệu                          | Từ file                       | Mục nguồn          | Dùng ở section nào trong plan | Cách kiểm tra                                    |
| ---------------------------------- | ------------------------------ | -------------------- | -------------------------------- | -------------------------------------------------- |
| User Stories + acceptance criteria | phase2-features/[feature].md   | Mục 2               | Story breakdown                  | Số stories trong plan = số stories trong feature |
| Business rules (BR-xxx)            | phase2-features/[feature].md   | Mục 3               | Task: Service layer validation   | Mỗi BR → 1 task hoặc subtask                    |
| Phân quyền                       | phase2-features/[feature].md   | Mục 4               | Task: Guard/middleware           | Mỗi role check → 1 subtask                       |
| State Machine                      | phase2-features/[feature].md   | Mục 6               | Task: State transition logic     | Mỗi transition → 1 subtask                       |
| Entity tóm tắt                   | phase2-features/[feature].md   | Mục 7               | Task: Entity/model creation      | Mỗi entity → 1 task (entity + repository)        |
| DDL + indexes                      | database-design.md          | Section tương ứng | Task: Migration file             | 1 task migration per table                         |
| API endpoints                      | api-contract.md             | Section tương ứng | Task: Controller + DTO           | 1 task per endpoint group                          |
| Cross-system rules                 | integration-map.md          | RULE-XXXX liên quan | Task: Integration logic          | 1 task per RULE nếu có                           |
| Screen layout                      | phase4-ux/[sys]/[screen-group].md | Layout + components  | Task: Frontend components        | 1 task per screen/component                        |
| REQ-IDs, FEAT-IDs                  | req-registry.json           | IDs                  | Header: metadata                 | IDs phải khớp registry                           |

### [feature]-impl.md (Phần A) → [feature]-impl.md (Phần B)

| Dữ liệu            | Từ plan                       | Dùng trong tasks   | Cách kiểm tra                                 |
| -------------------- | ------------------------------ | ------------------- | ----------------------------------------------- |
| Task list + subtasks | Story breakdown + Task details | Checklist thực thi | Tổng tasks trong tasks file = tổng trong plan |
| Execution strategy   | Batch recommendations          | Session planning    | Batch size nhất quán                          |
| Testing strategy     | Test approach                  | TDD cycle log       | Test types khớp                                |

### Checklist kiểm tra P2+3+4→P5

```
□ Mọi modules trong req-registry.json xuất hiện trong P5-00 roadmap
□ Thứ tự implement tôn trọng dependency graph (không implement B trước A nếu B phụ thuộc A)
□ Mỗi feature có [feature]-impl.md chứa:
  □ Tất cả user stories từ feature file (phase2-features/)
  □ Tất cả BR-xxx từ feature file
  □ Tất cả endpoints từ api-contract cho feature này
  □ Tất cả tables từ database-design cho feature này
  □ Integration rules từ integration-map (nếu cross-system)
  □ Screen specs từ phase4-ux (nếu có UI)
□ [feature]-impl.md (Phần B) = executable version của [feature]-impl.md (Phần A) (không thiếu task)
```

### Tất cả Phase 5 → phase5-implementation/stakeholder-review.md

| File SO                                     | Input bắt buộc                                | Kiểm tra cụ thể                                                                                                                                                                                                                                                                                 |
| ------------------------------------------- | ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Phần B** Plan Review               | P5-00, TẤT CẢ [feature]-impl, TẤT CẢ sprints/* | 1) Timeline: thứ tự implement tôn trọng dependency graph? 2) Sprint scope: mỗi sprint có khối lượng hợp lý? 3) Blocking dependencies: items blocking đã được giải quyết? 4) Resource conflicts: cùng 1 task không nằm trong nhiều sprints?                                   |
| **Phần C** Consistency Check         | TẤT CẢ Phase 5 + P5-00                           | 1) Task coverage: mỗi FEAT-ID trong registry có [feature]-impl tương ứng? 2) Story count: số stories trong plan = số stories trong feature file? 3) Sprint assignments: mỗi feature trong P5-00 có sprint assignment? 4) Priority: thứ tự sprint nhất quán với priority trong registry? |
| **Phần D** Gap Analysis              | TẤT CẢ Phase 5                                | 1) Missing plans: FEAT-ID nào chưa có plan? 2) Missing tasks: plan có story nhưng tasks thiếu? 3) Test coverage: mỗi task có test case tương ứng? 4) Edge cases: tình huống đặc biệt từ features có task xử lý?                                                                |

### Checklist kiểm tra Phase 5 SOs

```
□ Phần B: Mỗi feature trong P5-00 → có sprint assignment
□ Phần B: Dependency order trong P5-00 → nhất quán với feature headers (Phụ thuộc)
□ Phần C: Mỗi FEAT-ID trong registry → có [feature]-impl.md
□ Phần C: Số stories trong [feature]-impl = số stories trong phase2-features/[feature].md
□ Phần D: Mỗi BR-xxx trong feature → có task tương ứng trong [feature]-impl
□ Phần D: Mỗi integration RULE-XXXX liên quan → có task trong plan
```

---

## 8. Phase 3+4+5 → Phase 6

### Nguồn dữ liệu cho từng file Phase 6

`/wf-prepare-deployment` đọc Phase 1, 2, 3, 4, 5 để tạo tài liệu vận hành trong Phase 6.

| File Phase 6                                      | Input file                             | Mục nguồn cụ thể                           | Lấy thông tin gì                       | Cách kiểm tra                                             |
| ------------------------------------------------- | -------------------------------------- | ---------------------------------------------- | ----------------------------------------- | ----------------------------------------------------------- |
| **deployment-guide**                        | infra-spec.md                          | Mục 1: Environments                           | URLs, branches, auto-deploy settings      | Environment names + URLs phải khớp                        |
|                                                   | infra-spec.md                          | Mục 2: ENV variables                          | Danh sách biến môi trường            | ENV vars trong deploy guide = infra-spec                    |
|                                                   | infra-spec.md                          | Mục 3-5: Server, network, storage             | Server specs, ports, storage              | Specs phải khớp                                           |
|                                                   | P3-01                                  | Mục 7: Môi trường                          | Deploy URLs, branch mapping               | URLs khớp                                                  |
|                                                   | database-design.md                     | Mục 5: Migration strategy                     | Migration commands + rollback             | Convention phải nhất quán                                |
| **user-guide**                              | TẤT CẢ phase2-features/[sys]/[mod]/* | Mục 1: Mô tả + Mục 2: User Stories         | Hướng dẫn từng tính năng            | Mỗi feature → 1 section trong user guide                  |
|                                                   | TẤT CẢ phase4-ux/[sys]/*             | Layout + screenshots                           | Ảnh minh họa thao tác                  | Screen descriptions khớp thực tế                         |
|                                                   | P1-01                                  | Mục 5: Actors                                 | Phân hướng dẫn theo role              | Role names nhất quán                                      |
|                                                   | P1-01                                  | Mục 9: Yêu cầu chất lượng                  | FAQ: kỳ vọng hiệu năng              | VD: "phản hồi < 3s" → FAQ "chậm bao lâu là bình thường?" |
|                                                   | P1-02                                  | Mục 3: Luồng KD chính + phụ                 | **Hướng dẫn theo quy trình end-to-end** | Mỗi luồng KD → 1 section hướng dẫn quy trình           |
|                                                   | TẤT CẢ [dept].md (Phần B)            | Mục B2: TO-BE workflow                        | Hướng dẫn thao tác từng bước        | TO-BE steps → hướng dẫn cụ thể trên hệ thống          |
| **deployment-guide (Mục 9: Account Mgmt)** | P3-01                                  | Mục 8.1: Auth model + RBAC roles              | Danh sách roles                          | Roles phải = P3-01 roles                                   |
|                                                   | TẤT CẢ phase2-features/[sys]/[mod]/* | Mục 4: Phân Quyền (permission matrix)        | Permissions chi tiết theo feature       | Tổng hợp permissions từ tất cả features                 |
|                                                   | P1-01                                  | Mục 5: Actors                                 | Nhóm người dùng                       | Actor→role mapping nhất quán                             |
|                                                   | phase2-features/auth/*                 | Auth feature specs                             | Login flow, password policy               | Auth rules phải khớp feature spec                         |
| **deployment-guide (Mục 10: Maintenance)** | deployment-guide                       | Mục: Environments + deploy steps              | Context cho monitoring/upgrade            | Environments phải khớp                                    |
|                                                   | infra-spec.md                          | Mục 7-8: Health checks, monitoring & alerting | Health endpoints, alert rules, dashboards | Health check URLs + alert thresholds phải khớp infra-spec |
|                                                   | P3-01                                  | Mục 8.3: Logging & Observability              | Log format, correlation ID                | Log spec phải khớp                                        |
|                                                   | database-design.md                     | Mục 5: Migration strategy                     | Upgrade/migration procedures              | Convention phải khớp                                      |

### Checklist kiểm tra Phase 6

```
□ deployment-guide:
  □ ENV variables = infra-spec.Mục2 (đầy đủ, không thiếu, không thừa)
  □ Environments = infra-spec.Mục1 = P3-01.Mục7
  □ Migration commands nhất quán với database-design.Mục5

□ user-guide:
  □ Mỗi feature trong req-registry → có section hướng dẫn
  □ Role names = P3-01.Mục8.1 = P1-01.Mục5
  □ Tên tính năng = tên trong phase2-features/ files (không đổi tên)
  □ Mỗi luồng KD chính trong P1-02.Mục3 → có section "Hướng dẫn quy trình" trong user-guide
  □ TO-BE workflow trong [dept].md (Phần B) → phản ánh đúng trong hướng dẫn thao tác
  □ Yêu cầu chất lượng P1-01.Mục9 → phản ánh trong FAQ / Troubleshooting

□ deployment-guide (Mục 9: Account Mgmt):
  □ Default roles = P3-01.Mục8.1 RBAC table
  □ Permissions = phase2-features/ files.Mục4 (tổng hợp)
  □ Login flow = phase2-features/auth spec

□ deployment-guide (Mục 10: Maintenance):
  □ Health check URLs = infra-spec.Mục7 health endpoints
  □ Alert thresholds = infra-spec.Mục8 monitoring rules
  □ Log format = P3-01.Mục8.3
  □ Backup strategy = infra-spec.Mục5 + database-design.Mục5
```

### Tất cả Phase 6 → phase6-deployment/stakeholder-review.md

| File SO                                     | Input bắt buộc                              | Kiểm tra cụ thể                                                                                                                                                                                                                                                                                                    |
| ------------------------------------------- | --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Phần B** Deployment Review         | deployment-guide, infra-spec, database-design | 1) ENV variables đầy đủ? 2) Deploy steps khớp infra-spec? 3) Rollback procedures rõ ràng? 4) Migration commands nhất quán với database-design.Mục5?                                                                                                                                                        |
| **Phần C** Consistency Check         | TẤT CẢ Phase 6 docs                         | 1) Environment names nhất quán giữa deployment-guide, infra-spec, P3-01? 2) Role names trong user-guide = deployment-guide (Mục 9: Account Mgmt) = P3-01.Mục8.1? 3) Feature names trong user-guide = feature file titles? 4) Health check URLs trong deployment-guide (Mục 10: Maintenance) = infra-spec.Mục7? |
| **Phần D** Gap Analysis              | TẤT CẢ Phase 6 docs                         | D.1) Rollback — đủ rollback procedures cho mọi deploy steps? D.2) Monitoring & Alerting — health checks, alert rules, dashboards? D.3) Security Hardening — firewall, SSL, secrets, rate limiting? D.4) Training & Onboarding — user/admin training plan? D.5) Disaster Recovery — backup verification, RTO/RPO, failover? D.6) SLA & Support — support tiers, escalation, SLA targets? D.7) Tổng kết gaps |

### Checklist kiểm tra Phase 6 SOs

```
□ Phần B: deployment-guide ENV vars = infra-spec.Mục2 (đủ, không thừa thiếu)
□ Phần B: Deploy steps có rollback tương ứng
□ Phần C: Role names nhất quán: user-guide = deployment-guide (Mục 9: Account Mgmt) = P3-01.Mục8.1 = P1-01.Mục5
□ Phần C: Environment names: deployment-guide = infra-spec.Mục1 = P3-01.Mục7
□ Phần D.1: Rollback procedures đủ cho mọi deploy steps (app, DB, config, data, DNS)
□ Phần D.2: Monitoring & Alerting — health checks, error rate, performance, log aggregation
□ Phần D.3: Security Hardening — SSL/TLS, firewall, secrets management, rate limiting, security headers
□ Phần D.4: Training & Onboarding — user training plan, admin onboarding, FAQ
□ Phần D.5: Disaster Recovery — backup verification, RTO/RPO targets, failover procedure, DR drill
□ Phần D.6: SLA & Support — support tiers (L1/L2/L3), escalation matrix, SLA response times
□ Phần D.7: Tổng kết — tổng số gaps theo severity, hành động ưu tiên
```

---

## 9. Checklist Kiểm Tra Xung Đột Theo Từng Cặp File

> **Cách dùng:** Khi review 1 file cụ thể, tra bảng này để biết cần đối chiếu với file nào
> và kiểm tra những gì.

### 9.1. Xung đột về THUẬT NGỮ

| Điểm kiểm tra | File A                           | File B                   | Ví dụ xung đột                                                                     |
| ---------------- | -------------------------------- | ------------------------ | -------------------------------------------------------------------------------------- |
| Tên entity      | phase2-features/[feature].md Mục 7 | database-design.md DDL   | Feature gọi "Customer", DB table là "clients"                                        |
| Tên entity      | phase2-features/[feature].md Mục 7 | api-contract.md DTO      | Feature: "SalesOrder", API: "order"                                                    |
| Tên phân hệ   | P1-01 Mục 4                     | P3-01 Mục 3             | P1-01: "Quản lý bán hàng", P3-01: "Sales Management System" (OK nếu ánh xạ rõ) |
| Tên phòng ban  | P0-01 Phần 2                    | P1-02 Mục 2             | P0-01: "Kinh doanh", P1-02: "Sales"                                                    |
| Status values    | phase2-features/[feature].md Mục 6 | database-design.md CHECK | Feature: PENDING, DB: AWAITING                                                         |
| Status values    | phase2-features/[feature].md Mục 6 | api-contract.md ENUM     | Feature: 5 statuses, API: 4 statuses                                                   |
| Role names       | P1-01 Mục 5                     | P3-01 Mục 8.1           | P1-01: "Trưởng phòng", P3-01: "manager" (OK nếu mapping rõ)                       |

### 9.2. Xung đột về SỐ LIỆU / NGƯỠNG

| Điểm kiểm tra     | File A                     | File B                                  | Ví dụ xung đột                           |
| -------------------- | -------------------------- | --------------------------------------- | -------------------------------------------- |
| Ngưỡng phê duyệt | [dept].md (Phần B) Mục 3 | phase2-features/[feature].md Mục 3 BR-xxx | Workflow: > 10tr, Feature: > 20tr            |
| Rate limiting        | api-contract Mục 8        | infra-spec                              | API: 200 req/min, Infra: 100 req/min         |
| Pagination max       | api-contract Mục 1        | P3-01 Mục 6                            | API: max 200, Architecture: max 100          |
| JWT TTL              | P3-01 Mục 8.1             | api-contract Mục 5                     | Architecture: 1h, API: 30min                 |
| JWT TTL              | P3-01 Mục 8.1             | infra-spec ENV vars                     | Architecture: 1h, Infra: JWT_EXPIRES_IN=7200 |

### 9.3. Xung đột về PHẠM VI (thừa/thiếu)

| Điểm kiểm tra | Nguồn gốc (ít hơn = thiếu)     | Nơi mở rộng (nhiều hơn = thừa) | Hành động                                                                      |
| ---------------- | ----------------------------------- | ------------------------------------ | --------------------------------------------------------------------------------- |
| Phân hệ        | P1-01 Mục 4                        | P3-01 Mục 3                         | Nếu P3-01 có system không trong P1-01 → thừa, cần xóa hoặc bổ sung P1-01 |
| REQ-IDs          | req-registry.json                   | phase2-features/*.md                 | Feature reference REQ-ID không trong registry → thừa, lỗi                     |
| Endpoints        | phase2-features/*.md (user stories) | api-contract.md                      | API có endpoint không từ feature nào → thừa                                 |
| Tables           | phase2-features/*.md (entities)     | database-design.md                   | DB có table không từ feature nào → thừa (trừ shared tables)                |
| Screens          | phase2-features/*.md                | Navigation-[sys].md                  | Nav có menu item không từ feature nào → thừa                                |
| Roles            | P1-01 Mục 5                        | P3-01 Mục 8.1                       | Auth có role không trong actors list → thừa hoặc cần bổ sung               |

### 9.4. Xung đột về LOGIC

| Điểm kiểm tra                | File A                           | File B                           | Ví dụ xung đột                                                                                                |
| ------------------------------- | -------------------------------- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| State Machine vs Business Rules | phase2-features/[feature].md Mục 6 | phase2-features/[feature].md Mục 3 | BR nói "có thể hủy bất kỳ lúc nào", nhưng State Machine không có transition từ COMPLETED → CANCELLED |
| Data ownership vs Direct query  | P3-01 Mục 4                     | database-design.md FK            | P3-01 nói "chỉ đọc qua API", nhưng DB có direct FK cross-schema                                             |
| Sync vs Async                   | P3-01 Mục 5                     | integration-map Mục 2-3         | Architecture nói async, nhưng integration-map dùng sync REST                                                   |
| Auth model vs Permission check  | P3-01 Mục 8.1                   | api-contract Mục 5-6            | Architecture: RBAC, nhưng API không enforce role check                                                          |
| Error handling strategy         | P3-01 Mục 8.2                   | api-contract Mục 3-4            | Architecture: retry 3x, nhưng API error codes không cover retry scenarios                                       |

---

## 10. Bảng Tổng Hợp Toàn Bộ File-to-File

### Bảng: Mỗi file cần đọc chính xác file nào

| #  | File được tạo                       | Input bắt buộc (phải đọc trước)                                                     | Dữ liệu chính lấy từ input                                               |
| -- | --------------------------------------- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| 1  | P0-01 brainstorm                        | _(không phụ thuộc)_                                                                   | Ý tưởng từ user + BA/domain expert analysis                              |
| 1a | P0-02 systems-users                     | P0-01                                                                                      | Org context → systems map, roles, NFR, tech stack                             |
| 1b | policies/[name].md                      | P0-01 (Section 5.2/5.3)                                                                   | Chính sách "Chưa có"/"Có 1 phần" → policy framework do domain experts soạn |
| 1c | P0 stakeholder-review Phần B            | P0-01, P0-02, policies/                                                                    | Cross-doc: hệ thống khớp? users→roles khớp? PB→phân hệ→HT? policies đủ?     |
| 1d | P0 stakeholder-review Phần C            | TẤT CẢ Phase 0                                                                            | Consistency: thuật ngữ, số liệu, phạm vi, phân quyền nhất quán              |
| 1e | P0 stakeholder-review Phần D            | TẤT CẢ Phase 0                                                                            | Gaps: thông tin thiếu? PB/phân hệ thiếu? user thiếu? chính sách thiếu?       |
| 2  | P1-01 project-overview                  | P0-01, P0-02                                                                               | Scope, dept list, system list, constraints, roles, quality requirements       |
| 3  | P1-02 business-workflow                 | P0-01, P1-01                                                                               | Systems + actors → luồng KD, KPIs, handoffs                                 |
| 4  | [dept].md (Phần A)                     | P1-01, P1-02                                                                               | Context phân hệ + luồng → REQ-IDs, rules, data                            |
| 5  | [dept].md (Phần B)                     | P1-01, P1-02                                                                               | Context actors + luồng → AS-IS/TO-BE, phê duyệt                           |
| 6  | dept/_index                             | TẤT CẢ [dept].md (Phần A) + workflow                                                    | Tổng hợp trạng thái, nhu cầu, ưu tiên                                  |
| 7  | P1 stakeholder Phần B (Cross-dept)      | P1-02 + TẤT CẢ dept docs                                                                 | Cross-dept: gửi/nhận khớp? trùng? mâu thuẫn?                            |
| 8  | P1 stakeholder Phần C (Consistency)     | TẤT CẢ Phase 1                                                                           | Consistency: thuật ngữ, số liệu, vai trò, scope                          |
| 9  | P1 stakeholder Phần D (Gaps)            | TẤT CẢ Phase 1                                                                           | Gaps: dept thiếu? quy trình thiếu? feature thiếu?                         |
| 10 | req-registry.json                       | TẤT CẢ [dept].md (Phần A), P0-01 + P1-01.Mục7 (interface_type)                          | REQ-IDs + metadata (title, dept, priority) + interface_type                   |
| 11 | phase2-features/[s]/[m]/[f]             | [dept].md (Phần A), [dept].md (Phần B), registry                                         | REQ → FEAT: stories, rules, perms, states, entities                          |
| 12 | P2 stakeholder Phần B (Feature Review)  | TẤT CẢ phase2-features/*, req-registry.json                                              | REQ coverage, user stories đầy đủ, business rules                         |
| 13 | P2 stakeholder Phần C (Consistency)     | TẤT CẢ phase2-features/*, Phase 1 docs                                                   | Thuật ngữ, actors, scope nhất quán                                        |
| 14 | P2 stakeholder Phần D (Gaps)            | TẤT CẢ phase2-features/*                                                                 | REQ chưa có feature, edge cases, cross-system deps                          |
| 15 | P3-01 architecture                      | P0-02 (NFR, tech stack), P1-01, P1-02, dept/_index, P1 stakeholder-review.md               | Systems → tech stack, auth, cross-cutting, external integrations, compliance |
| 16 | api-contract                            | TẤT CẢ phase2-features/*, P3-01 (toàn bộ — Mục1: REST/GraphQL, Mục5: cross-system, Mục6: conventions, Mục7: environments, Mục8: auth+RBAC) | Endpoints, DTOs, auth, error codes                                            |
| 17 | database-design                         | TẤT CẢ phase2-features/*, P3-01 (toàn bộ — Mục1-2: arch decisions, Mục3-4: systems+data ownership, Mục6: conventions) | DDL, indexes, constraints, migration                                          |
| 18 | integration-map                         | P3-01.Mục5, phase2-features/* (cross-system)                                              | Sync/async calls, event payloads, RULE-XXXX                                   |
| 19 | infra-spec                              | P3-01 (toàn bộ — chủ yếu Mục1: arch decisions, Mục7: environments)                     | Environments, ENV vars, servers, monitoring                                   |
| 20 | P3 stakeholder Phần B (Technical)       | P3-01 + TẤT CẢ technical-specs/*                                                         | Xung đột kiến trúc, API↔DB mismatch                                      |
| 21 | P3 stakeholder Phần C (Consistency)     | TẤT CẢ Phase 3 + registry                                                                | REQ coverage, thuật ngữ, data models, scope                                 |
| 22 | P3 stakeholder Phần D (Gaps)            | TẤT CẢ Phase 3                                                                           | Gaps: API, DB, infra, security, NFR, edge cases                               |
| 23 | design-system                           | P1-01 (thông tin chung, actors), P3-01 (tech stack, conventions)                           | Design tokens, components, tech stack → component library                    |
| 24 | Navigation-[sys]                        | P3-01.Mục3, phase2-features/[sys]/*                                                       | Menu structure, screen registry                                               |
| 25 | phase4-ux/[s]/[screen]                  | design-system, Navigation-[sys], phase2-features/[feature], api-contract                      | Layout, fields, actions, API mapping, route validation                        |
| 26 | P4 stakeholder Phần B (UX Cross)        | design-system, TẤT CẢ Navigation-[sys], TẤT CẢ [screen-group], api-contract              | Feature→Screen coverage, design consistency, API refs                        |
| 27 | P4 stakeholder Phần C (Consistency)     | TẤT CẢ Phase 4 + phase2-features/* + P3-01                                                | User stories, BR reflected, permissions, arch alignment                      |
| 28 | P4 stakeholder Phần D (Gaps)            | TẤT CẢ Phase 4                                                                            | Screen gaps, component gaps, accessibility, orphan screens                   |
| 29 | P5-00 roadmap                           | registry, phase2-features/* (dependencies), integration-map, P2+P3+P4 SOs                  | Implementation order, sprint plan                                             |
| 30 | sprints/S0X                             | P5-00 (feature queue)                                                                      | Sprint scope, goals                                                           |
| 31 | [feature]-impl                             | phase2-features/[feature], api-contract, database-design, integration-map, phase4-ux/[screen] | Story → task breakdown + executable checklist, TDD log                       |
| 32 | P5 stakeholder Phần B (Plan Review)     | P5-00, TẤT CẢ [feature]-impl, TẤT CẢ sprints/*                                            | Timeline, dependency order, sprint scope                                      |
| 33 | P5 stakeholder Phần C (Consistency)     | TẤT CẢ Phase 5 + P5-00                                                                   | Task coverage, story count, sprint assignments                                |
| 34 | P5 stakeholder Phần D (Gaps)            | TẤT CẢ Phase 5                                                                           | Missing plans, tasks, test coverage                                           |
| 35 | deployment-guide                        | infra-spec, P3-01.Mục7, database-design.Mục5                                             | Deploy steps, ENV, rollback, CI/CD                                            |
| 36 | user-guide                              | P1-01, P1-02, [dept].md (B), TẤT CẢ phase2-features/*, TẤT CẢ phase4-ux/*, P5-00-roadmap, deployment-guide | Hướng dẫn theo role + theo quy trình end-to-end                           |
| 37 | deployment-guide (Mục 9: Account Mgmt) | P3-01.Mục8.1, P1-01.Mục5, phase2-features/auth/*                                         | Roles, accounts, permissions                                                  |
| 38 | deployment-guide (Mục 10: Maintenance) | deployment-guide, infra-spec.Mục7-8, P3-01.Mục8.3                                        | Monitoring, backup, upgrade                                                   |
| 39 | P6 stakeholder Phần B (Deployment)      | deployment-guide, infra-spec, database-design                                              | ENV vars, deploy steps, rollback, migrations                                  |
| 40 | P6 stakeholder Phần C (Consistency)     | TẤT CẢ Phase 6 docs                                                                      | Environment names, role names, feature names consistency                      |
| 41 | P6 stakeholder Phần D (Gaps)            | TẤT CẢ Phase 6 docs                                                                      | Feature coverage, role coverage, monitoring gaps                              |

### Sơ đồ tổng quan dạng text

```
PHASE 0              PHASE 1              PHASE 2          PHASE 3                PHASE 4       PHASE 5       PHASE 6
═══════              ═══════              ═══════          ═══════                ═══════       ═══════       ═══════

P0-01 ──┬──► P0-02 ──────────────────────────────────────────────────────────┐
        │    (systems, roles,                                                 │
        │     NFR, tech stack)                                                │
        │         │                                                           │
        ├──► policies/ (chính sách nghiệp vụ do domain experts soạn)        │
        │         │                                                           │
        └──► stakeholder-review (P0)                                         │
                  │                                                           │
        ▼         ▼                                                           │
   P1-01 ◄── P0-02                                                           │
   (scope, actors, constraints, quality)                                      │
                │                                                             │
                ▼                                                             │
          P1-02 ─────────────────────────┐                                   │
          (luồng KD, KPIs,               │                                   │
           external, compliance)         │                                   │
                │                        │                                   │
                ▼                        │                                   │
          [dept].md ──────────►          │                                   │
          (Phần A: needs  ──► req-registry.json (REQ-IDs)                   │
           Phần B: workflow)             │                                   │
          policies/ ─► (BR context)      │                                   │
                │                        │                        │
                ▼                        │                        │
          dept/_index ──────────────────┤                        │
                │                        │                        │
                ▼                        │                        │
          stakeholder-review (P1)        │                        │
                │                        ▼                        ▼
                └──────────► phase2-features/         P3-01 ◄── P0-02 (NFR, tech) ┐
                             [sys]/[mod]/[feature]      (architecture)              │
                                  │                         │                      │
                                  │                    ┌────┼─────────────┐        │
                                  │                    │    │             │        │
                                  │                    ▼    ▼             ▼        │
                                  │            technical-specs/:     infra-spec    │
                                  │            ├ api-contract                     │
                                  │            ├ db-design                        │
                                  │            └ integration-map                  │
                                  │                    │                           │
                                  ▼                    ▼                           │
                             stakeholder-review   stakeholder-review               │
                             (phase2-features)    (phase3-arch)                    │
                                  │                    │                           │
                                  └──────────┬─────────┘                           │
                                             ▼                                     │
                                        phase4-ux/          ◄─────────────────────┤
                                        design-system                              │
                                        Navigation-[sys] ──► [screen].md           │
                                        [screen].md ◄── api-contract              │
                                             │                                     │
                                             ▼                                     │
                                        stakeholder-review                         │
                                        (phase4-ux)                                │
                                             │                                     │
                                             ▼                                     │
                                        P5-00 roadmap ◄────────────────────────────┘
                                             │
                                        ┌────┴────┐
                                        ▼         ▼
                                   sprints/   [feature]-impl
                                   S01..Sn    (plan + tasks)
                                        │         │ ◄── integration-map
                                        ▼         ▼
                                   stakeholder-  IMPLEMENT
                                   review (P5)   CODE
                                                  │
                                                  ▼
                                            phase6-deployment/
                                            deployment-guide
                                            user-guide ◄── P1-01, P1-02 (luồng KD)
                                                       ◄── [dept].md (TO-BE workflow)
                                                       ◄── P5-00-roadmap, deployment-guide
                                            stakeholder-review (P6)
```

---

## 11. Change Propagation — Lan Truyền Thay Đổi

> **Mục đích:** Khi 1 file thay đổi, biết chính xác file nào downstream cần cập nhật theo.
> Tài liệu này mô tả thứ tự **tạo mới** ở các sections trên. Section này bổ sung hướng dẫn
> khi **cập nhật** file đã có.

### 11.1. Impact Matrix — File thay đổi → Files cần review/update

| File thay đổi                                             | Files downstream cần review                                                                                | Mức độ ảnh hưởng                              |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| **P0-01** (scope, depts, systems, policies)           | P0-02, policies/, P1-01, P1-02, tất cả dept docs                                                          | Critical — thay đổi scope ảnh hưởng toàn bộ |
| **P0-02** (systems, roles, NFR, tech stack)           | P1-01, P1-02 (systems context), P3-01 (auth, NFR, tech stack)                                              | High — thay đổi hệ thống/roles ảnh hưởng Phase 1+3 |
| **policies/** (business rules, approval flows)        | [dept].md (Phần A: BR context), [dept].md (Phần B: approval), phase2-features/ (BR-xxx)                   | High — thay đổi chính sách ảnh hưởng requirements + features |
| **P1-01** (systems, actors, constraints)              | P1-02, tất cả dept docs, P3-01, phase2-features/*, design-system, deployment-guide (Mục 9: Account Mgmt), user-guide | Critical                                            |
| **P1-02** (luồng KD, handoffs, KPIs)                 | Tất cả dept docs, P3-01, integration-map, user-guide                                                      | High                                                |
| **[dept].md (Phần A)** (REQ-IDs, rules)              | dept/_index, req-registry.json, phase2-features/[feature], api-contract, database-design                       | High                                                |
| **[dept].md (Phần B)** (quy trình, phê duyệt)     | dept/_index, phase2-features/[feature] (state machine, permissions), user-guide                                 | High                                                |
| **req-registry.json** (IDs, metadata)                 | Tất cả files reference REQ/FEAT-IDs                                                                       | Critical — SSOT                                    |
| **P3-01** (architecture, conventions)                 | Tất cả technical-specs/* (api-contract, db-design, integration-map, infra-spec), phase4-ux/*, deployment-guide (Mục 9: Account Mgmt) | Critical                                            |
| **phase2-features/[feature]** (stories, rules, entities) | api-contract, database-design, integration-map, phase4-ux/[screen], [feature]-impl, user-guide                  | High                                                |
| **api-contract** (endpoints, DTOs)                    | phase4-ux/[screen] (action mapping), [feature]-impl, deployment-guide                                          | Medium                                              |
| **database-design** (DDL, constraints)                | [feature]-impl, deployment-guide (migrations)                                                                  | Medium                                              |
| **integration-map** (sync/async, RULE-xxx)            | [feature]-impl, P5-00 (blocking dependencies)                                                                  | High                                                |
| **phase4-ux/** (screens, design-system, navigation)   | [feature]-impl (frontend tasks), user-guide (hướng dẫn thao tác + screenshots)                               | High — thay đổi UX ảnh hưởng code + docs          |
| **design-system** (colors, tokens, components)        | TẤT CẢ phase4-ux/[screen], user-guide                                                                      | Medium                                              |
| **Navigation-[sys]** (menu structure, routes)         | phase4-ux/[screen] (route validation, parent menu)                                                          | Medium                                              |
| **P5-00 roadmap** (implementation order, sprints)     | sprints/S0X, [feature]-impl, user-guide (feature rollout sequence)                                          | High                                                |
| **deployment-guide** (deploy steps, ENV, rollback)    | user-guide (Account Mgmt, Maintenance references)                                                           | Medium                                              |
| **infra-spec** (ENV, servers, monitoring)             | deployment-guide, deployment-guide (Mục 10: Maintenance), api-contract (rate limiting)                      | Medium                                              |

### 11.2. Registry Update Lifecycle

`req-registry.json` là living document — được nhiều skills cập nhật ở các giai đoạn khác nhau:

| Phase       | Skill cập nhật          | Fields được update                                                                   | Trigger                              |
| ----------- | ------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------ |
| Phase 1     | `/wf-analyze-requirements` | `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `interface_type` | Phân tích xong [dept].md (Phần A) |
| Phase 2     | `/wf-define-features`      | `features[]`                                                                          | Tạo xong feature specs              |
| Phase 3     | `/wf-design`               | `design_status` (top-level)                                                           | Thiết kế xong toàn bộ modules     |
| Phase 5     | `/wf-plan-modules`         | `implementation_order`                                                                | Phân tích xong dependency graph    |
| Phase 5+    | `/wf-implement-feature`    | `impl_status` (per REQ-ID)                                                            | Code xong 1 feature                  |
| Pre-release | `/wf-verify-sync`          | `impl_status` (safe-update only, **không downgrade** done)                     | Kiểm tra sync                       |

```
QUY TẮC REGISTRY UPDATE:
1. ĐỌC registry NGAY TRƯỚC KHI GHI — không cache từ đầu session
2. CHỈ MODIFY fields được phân công — giữ nguyên mọi fields khác
3. GHI ATOMIC — single write operation
4. VALIDATE sau ghi — JSON phải valid
5. KHÔNG downgrade impl_status từ "done" → giá trị khác
```

### 11.3. Quy Trình Khi Thay Đổi Mid-Stream

**Thêm phòng ban mới (mid-project):**

```
1. Cập nhật P0-01.Section2 (thêm phòng ban)
2. Cập nhật P0-02.Section2 (thêm roles mới nếu cần)
3. Kiểm tra P0-01.Section4.2 — PB mới có chính sách riêng cần bổ sung?
4. Cập nhật P1-01.Mục4-5 (thêm vào scope, actors)
5. Cập nhật P1-02.Mục2-3 (thêm vào luồng KD)
6. Tạo [dept].md (Phần A) + [dept].md (Phần B)
7. Cập nhật dept/_index.md
8. Re-run stakeholder-review.md (Phase 1)
9. Cập nhật req-registry.json (thêm REQ-IDs mới)
10. Cập nhật P3-01 nếu ảnh hưởng architecture
11. Tạo/cập nhật feature files liên quan trong phase2-features/
```

**Thay đổi business rule (BR-xxx):**

```
1. Sửa [dept].md (Phần A) (rule gốc)
2. Sửa phase2-features/[feature].md Mục 3 (BR-xxx)
3. Kiểm tra api-contract (validation rules, error codes)
4. Kiểm tra database-design (CHECK constraints)
5. Kiểm tra integration-map nếu rule cross-system
6. Cập nhật [feature]-impl.md (task tương ứng)
```

**Thay đổi chính sách nghiệp vụ (policies/):**

```
1. Sửa policies/[name].md (cập nhật nội dung chính sách)
2. Cập nhật P0-01.Section4.2 (trạng thái nếu cần)
3. Sửa [dept].md (Phần A) — REQ liên quan đến policy
4. Sửa [dept].md (Phần B) — quy trình phê duyệt nếu ảnh hưởng
5. Sửa phase2-features/[feature].md Mục 3 (BR-xxx tương ứng)
6. Kiểm tra api-contract (validation rules)
7. Kiểm tra database-design (CHECK constraints nếu áp dụng)
```

**Thêm/xóa phân hệ (system):**

```
1. Cập nhật P0-01.Section3 + P0-02.Section1 (hệ thống) + P1-01.Mục4
2. Cập nhật P3-01.Mục3-5 (system list, data ownership, communication)
3. Cập nhật req-registry.json (systems[])
4. Tạo/xóa feature files trong phase2-features/[sys]/
5. Cập nhật api-contract, database-design, integration-map
6. Cập nhật Navigation-[sys].md, phase4-ux/[sys]/
7. Re-run phase2-features/stakeholder-review.md + phase3-architecture/stakeholder-review.md
8. Cập nhật P5-00 roadmap
```

---

## Nguyên Tắc Phát Hiện Xung Đột

| Loại xung đột                 | Cách phát hiện                                                          | Ưu tiên sửa                                                                 |
| -------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| **Thuật ngữ khác nhau** | So sánh tên entity/role/status giữa các files cùng nói về 1 thứ    | Medium — sửa bằng cách chốt tên chuẩn trong README.md (Phần: Glossary) |
| **Số liệu mâu thuẫn**  | So sánh ngưỡng/giá trị/timeout giữa các specs                       | High — chọn 1 giá trị đúng, sửa tất cả files                          |
| **Phạm vi thừa**         | File sau có nội dung không từ file trước nào                        | High — xóa nội dung thừa, hoặc bổ sung vào file trước                 |
| **Phạm vi thiếu**        | File trước có nội dung nhưng file sau không cover                    | Critical — bổ sung vào file sau                                             |
| **Logic mâu thuẫn**      | Quy tắc trong file A xung đột với quy tắc file B                      | Critical — phải giải quyết trước khi implement                           |
| **ID orphan**              | REQ/FEAT/UI/API/DB-ID xuất hiện ở file nhưng không có trong registry | High — đăng ký vào registry hoặc xóa khỏi file                         |
| **ID phantom**             | Registry có ID nhưng không file nào reference                          | Medium — tạo file hoặc xóa khỏi registry                                  |
