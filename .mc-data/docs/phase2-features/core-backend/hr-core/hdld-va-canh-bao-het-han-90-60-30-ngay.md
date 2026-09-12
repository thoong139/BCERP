# Tính Năng: HĐLĐ & cảnh báo hết hạn 90/60/30 ngày

> **Dựa trên:** REQ-HR-002 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** Nhân sự — HR Core (SYS-CORE-BACKEND)
> **Module:** MOD-HR-CORE
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Với lane này FEAT-ID đã được registry fan-out chốt là `FEAT-CORE-HRCORE-002` (system SYS-CORE-BACKEND, module MOD-HR-CORE).

> **Phạm vi fan-out (touchpoint):** REQ-HR-002 xuất hiện ở 2 hệ thống — **SYS-CORE-BACKEND** (bản spec này: domain service lưu trữ, job quét cảnh báo, validation, mã hóa) và **SYS-BCERP-WEB** (counterpart: màn hình HR, thông báo, dashboard đỏ). Tại touchpoint core backend, mọi business rule phải được enforce ở tầng service (không tin UI); toàn bộ dữ liệu HĐLĐ thuộc nhóm C1 nên mã hóa khi lưu/truyền, mọi lượt xem/sửa có audit log bất biến và luôn xử lý trong tenant isolation.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-HRCORE-002 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-002 |
| Người dùng liên quan | HR_L1 (nhập dữ liệu), HR_L2 (chủ sở hữu cảnh báo, xử lý tái ký), TL nhận cảnh báo qua counterpart WEB, BOD_CEO/BOD_CFO_CTO (nhận escalate HĐ quá hạn) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | FEAT-CORE-HRCORE-001 (hồ sơ nhân sự SSOT — HĐLĐ gắn vào `employee`) |
| Ghi chú Expert (A7) | A7.2: need mobile HR (nhận nhắc khi di chuyển) ngoài scope SYS-MOBILE-INTERNAL hiện tại — xem lại khi mở rộng scope. Chi tiết tại `hr.md` Mục A7.3 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Lưu trữ hợp đồng lao động (HĐLĐ) dưới dạng domain service trên core backend — loại, số HĐ, ngày ký, hiệu lực, hết hạn, nội dung chính và file scan mã hóa — và vận hành cơ chế cảnh báo tự động trước ngày hết hạn theo 3 mốc **90/60/30 ngày** cho HR_L2 và TL. Mục tiêu kinh doanh là loại bỏ rủi ro pháp lý "HĐ xác định thời hạn hết hạn nhưng chưa ký tiếp", vốn hiện được quản lý thủ công trên Google Sheets và dễ bỏ sót.

**Phạm vi:**
- Bao gồm: domain entity HĐLĐ gắn hồ sơ nhân sự (SSOT của FEAT-CORE-HRCORE-001); job quét hằng ngày tính khoảng cách đến ngày hết hạn và phát sự kiện cảnh báo 90/60/30 ngày; trạng thái "cảnh báo đỏ" cho HĐ quá hạn chưa tái ký kèm escalate BOD theo tuần; luồng tái ký tạo bản ghi mới nối tiếp (HĐ cũ giữ nguyên lịch sử); luồng chấm dứt giữa hạn với căn cứ pháp lý; mã hóa file scan (C1), kiểm soát quyền mở file; audit log bất biến.
- Không bao gồm: UI dashboard đỏ, form nhập và hàng đợi thông báo (SYS-BCERP-WEB — counterpart); hồ sơ/thử việc (FEAT-CORE-HRCORE-001 — nhưng rule "đánh giá hết thử việc trước kết thúc ≥3 ngày" được expose như một ràng buộc API cho feature đó); chấm công, nghỉ phép, Rate Card (FEAT-CORE-HRCORE-003/004/006); retention chi tiết theo REQ-HR-010 (feature riêng, feature này chỉ tuân thủ trỏ tới).

**Nguồn domain bổ sung:** `documents/03_Quy_che_KPI_HR.md` — quy trình HR v3.9 (Phase 1 tuyển dụng/Phase 2 hội nhập có biểu mẫu hợp đồng và probation review), 4 track Sales/Business Ops/HCNS/Marketing-Creative; danh mục `contract_addendum` trong mô hình dữ liệu đề xuất (mục 9) dùng tham chiếu cho phụ lục hợp đồng.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | HR_L1 | Ghi nhận HĐLĐ qua API: loại, số HĐ, ngày ký, hiệu lực, hết hạn, nội dung chính + upload file scan | Dữ liệu HĐ được mã hóa ngay khi lưu và gắn đúng hồ sơ nhân sự SSOT |
| 2 | Hệ thống (job hằng ngày) | Quét toàn bộ HĐ xác định thời hạn và phát cảnh báo tại các mốc còn 90/60/30 ngày hết hạn | HR_L2 và TL nhận nhắc đúng thời điểm ra quyết định ký tiếp hay không |
| 3 | HR_L2 | Nhận cảnh báo phân tầng: 90 ngày = quyết định ký tiếp hay không; 60 ngày = chuẩn bị; 30 ngày = phải chốt phương án | Không bị nhồi thông báo cùng trọng lượng mà có lộ trình xử lý rõ |
| 4 | HR_L2 | Thấy HĐ xác định thời hạn đã quá hạn nhưng chưa ký tiếp được đánh dấu **cảnh báo đỏ** | Rủi ro pháp lý được lộ diện ngay trên counterpart dashboard |
| 5 | Hệ thống (escalation) | Escalate danh sách HĐ quá hạn lên BOD theo tuần cho đến khi được xử lý | Trường hợp chậm xử lý không nằm lại ở cấp HR |
| 6 | HR_L1 | Tạo bản ghi HĐ mới nối tiếp khi tái ký, HĐ cũ đóng lại giữ nguyên lịch sử | Lịch sử hợp đồng không bị mất và nhắc hạn tính trên HĐ mới |
| 7 | HR_L1 | Ghi nhận chấm dứt giữa hạn với căn cứ pháp lý (Điều 34/35/36 BLLĐ 2019) + file quyết định | HĐ đóng trạng thái đúng luật, có chứng từ tra cứu về sau |
| 8 | HR_L2 | Mở file scan HĐLĐ (duy nhất vai có quyền) | Nội dung hợp đồng không lộ cho vai khác; lượt mở bị log |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của SYS-CORE-BACKEND, không dựa vào validation phía UI.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-HR2-01 | Job quét hằng ngày: HĐ xác định thời hạn có ngày hết hạn còn đúng **90 / 60 / 30 ngày** → phát thông báo cho HR_L2 + TL (kênh counterpart WEB). Ba mốc là 3 sự kiện độc lập, không gộp | Thiếu 1 mốc nào của 1 HĐ là lỗi quét — job phải có đối soát số HĐ đã quét/ngày |
| BR-HR2-02 | HĐ xác định thời hạn **quá hạn chưa tái ký** → chuyển "cảnh báo đỏ"; escalate BOD theo tuần lặp lại đến khi HĐ được tái ký hoặc chấm dứt | Job không được im lặng — mỗi tuần tạo 1 bản ghi escalate mới |
| BR-HR2-03 | HĐ **không xác định thời hạn** → gắn flag tắt nhắc hết hạn | Job loại khỏi tập quét; flag sai làm phát cảnh báo giả là lỗi nghiệp vụ |
| BR-HR2-04 | Đánh giá hết thử việc phải thực hiện **trước khi kết thúc thử việc ≥3 ngày**; đạt mới được ký HĐLĐ chính thức | API từ chối tạo HĐ chính thức khi chưa có kết quả đánh giá đạt (đọc từ FEAT-CORE-HRCORE-001) |
| BR-HR2-05 | Tái ký = tạo **bản ghi HĐ mới nối tiếp**; cấm sửa trường ngày/hiệu lực của HĐ đã ký | Sửa HĐ cũ bị từ chối; correction chỉ qua bản ghi bổ sung có lý do + audit log |
| BR-HR2-06 | Chấm dứt giữa hạn bắt buộc có căn cứ pháp lý đúng luật + file quyết định; hệ thống đóng trạng thái và ngắt nhắc | Thiếu căn cứ thì API không cho đóng |
| BR-HR2-07 | File scan và trường C1 mã hóa khi lưu + truyền; chỉ HR_L2 mở được nội dung; **mọi lượt xem/sửa HĐLĐ có audit log bất biến** (ai — khi nào — trước/sau) | Vai khác gọi API đọc nội dung bị từ chối; xuất raw bị chặn ở service layer |
| BR-HR2-08 | Lưu trữ theo retention pháp luật lao động (chi tiết retention chuẩn hóa ở REQ-HR-010); dữ liệu trong tenant isolation | Xóa trước hạn retention bị chặn; nghĩa vụ lưu trữ luật định ưu tiên hơn yêu cầu xóa |

**Quy tắc xuyên phân hệ (bắt buộc cho toàn bộ REQ-HR lane, trích từ Phase 1 — không được bỏ khi implement feature nào của MOD-HR-CORE):**

1. Hồ sơ nhân sự L1–L5 + mã vai là **SSOT**; nguồn dữ liệu bổ sung: `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
2. HĐLĐ cảnh báo hết hạn **90/60/30 ngày** (nội dung feature này); chấm công 40h/tuần, trần 48h overtime (FEAT-CORE-HRCORE-003).
3. Nghỉ phép 12 ngày/năm, số dư tự động, duyệt phân cấp; nội quy nghỉ phép + chế tài xử phạt theo 03 §8 (FEAT-CORE-HRCORE-004).
4. Cost Rate Card version hóa (HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt); billable tại nguồn (FEAT-CORE-HRCORE-006).
5. **Delegate duyệt timesheet cho TL vẫn ở mức `[KXN]` chưa chốt** — spec theo assumption có tag `[KXN-DI006]`, không tự quyết; feature này không thiết kế cơ chế ủy quyền duyệt cho đến khi được chốt.

---

## 4. Phân Quyền

| Hành động | HR_L1 | HR_L2 | BOD_CEO / BOD_CFO_CTO | SYS_ADMIN | Vai khác (18-vai registry) |
|-----------|-------|-------|------------------------|-----------|-----------------------------|
| Xem metadata HĐ (loại, số, hiệu lực, hết hạn) | ✅ | ✅ | ✅ | ❌ | TL: ✅ (HĐ của thành viên nhóm, qua counterpart) |
| Xem nội dung chính + mở file scan (C1) | ❌ | ✅ | ✅ | ❌ | ❌ |
| Nhập / cập nhật HĐ (trước khi ký lưu hệ thống) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Tái ký (tạo HĐ mới nối tiếp) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Chấm dứt giữa hạn | ✅ (tạo) | ✅ (duyệt) | ❌ | ❌ | ❌ |
| Đặt flag "không xác định thời hạn" (tắt nhắc) | ❌ | ✅ | ❌ | ❌ | ❌ |
| Nhận cảnh báo 90/60/30 | ❌ | ✅ | ❌ | ❌ | TL ✅ (nhóm mình) |
| Nhận escalate cảnh báo đỏ theo tuần | ❌ | ✅ | ✅ | ❌ | ❌ |
| Xem audit log HĐLĐ | ✅ (log thao tác) | ✅ | ✅ | ✅ (xem log cũng bị log) | ❌ |

> Không dùng vai ngoài 18-vai registry; không tồn tại OPS_CX / FIN_COMPL (DI-006). SYS_ADMIN quản hạ tầng, không xem giá trị nội dung HĐ.

---

## 5. Trường Hợp Đặc Biệt

- HĐ không xác định thời hạn: tắt nhắc hết hạn bằng flag; khi nhân sự thôi việc, HĐ vẫn giữ trong lịch sử theo retention pháp luật lao động.
- HĐ thử việc → HĐ chính thức: HĐ chính thức chỉ tạo được khi đánh giá hết thử việc "đạt" đã ghi nhận trước kết thúc thử việc ≥3 ngày (BR-HR2-04); nếu thử việc kéo dài theo thỏa thuận hợp lệ, ngày kết thúc trên HĐ thử việc phải được cập nhật bằng bản ghi bổ sung có log.
- Chấm dứt giữa hạn trong thời gian cảnh báo đỏ: đóng trạng thái + ngắt escalate, nhưng chuỗi cảnh báo/escalate trước đó phải giữ lại làm bằng chứng xử lý.
- HĐ có phụ lục (`contract_addendum`): phụ lục là bản ghi con của HĐ gốc, không đổi ngày hết hạn trừ khi phụ lục quy định kéo/giãn — khi đó service tính lại mốc nhắc từ ngày hết hạn mới và log căn cứ.
- Nhân sự nghỉ việc giữa chu kỳ cảnh báo: nhắc cho HĐ của người đã "Nghỉ việc" tự dừng; hồ sơ HĐ chuyển chế độ retention.
- File scan lỗi/hỏng: service ghi nhận trạng thái file không đọc được và đưa vào danh sách cần nạp lại — không âm thầm bỏ sót.
- Tenant isolation: job quét chạy theo từng tenant; cảnh báo của tenant này không bao giờ phát sang hàng đợi tenant khác.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hợp đồng lao động (`labor_contract`)

**Sơ đồ trạng thái:**
```
[HIỆU LỰC] ──(còn 90/60/30 ngày)──► [SẮP HẾT HẠN (cảnh báo 1–3)] ──(hết hạn chưa tái ký)──► [QUÁ HẠN — CẢNH BÁO ĐỎ + escalate tuần]
    │                                      │                                                      │
    │ (chấm dứt giữa hạn)                  │ (tái ký — tạo HĐ mới)                                │ (tái ký muộn — tạo HĐ mới)
    ▼                                      ▼                                                      ▼
[CHẤM DỨT]                            [ĐÃ TÁI KÝ — đóng HĐ cũ]                              [ĐÃ TÁI KÝ — đóng HĐ cũ]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| (tạo mới) | Nhập + ký nội bộ | Hiệu lực | HR_L1 tạo, HR_L2 xác nhận | Đủ metadata + file scan mã hóa; với HĐ chính thức: đánh giá thử việc đạt (BR-HR2-04) |
| Hiệu lực | Job phát hiện mốc 90/60/30 | Sắp hết hạn (cấp 1/2/3) | Hệ thống | Ngày hết hạn − today ∈ {90, 60, 30}; chỉ với HĐ xác định thời hạn |
| Sắp hết hạn | Tái ký | Đã tái ký | HR_L1/HR_L2 | Bản ghi HĐ mới tạo thành công, nối tiếp `renewed_by` |
| Sắp hết hạn | Chấm dứt giữa hạn | Chấm dứt | HR_L2 duyệt | Căn cứ pháp lý + file quyết định |
| Sắp hết hạn / Hiệu lực | Quá ngày hết hạn | Quá hạn — cảnh báo đỏ | Hệ thống | Chưa có HĐ mới nối tiếp; escalate BOD theo tuần |
| Quá hạn | Tái ký muộn | Đã tái ký | HR_L1/HR_L2 | HĐ mới có ngày hiệu lực; chuỗi escalate dừng nhưng lưu lại |

**Quy tắc:**
- "Chấm dứt" và "Đã tái ký" là trạng thái kết thúc của bản ghi HĐ cũ — không chuyển tiếp; lifecycle tiếp theo nằm trên bản ghi HĐ mới.
- HĐ không xác định thời hạn chỉ có trạng thái Hiệu lực/Chấm dứt, không đi qua Sắp hết hạn/Quá hạn.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `labor_contract` | `contract_no`, `type`, `signed_at`, `valid_from`, `valid_to`, `indefinite` (flag), `summary`, `scan_file_ref`, `status` | FK → `employee` | C1 mã hóa; `valid_to` null khi indefinite |
| `contract_renewal_link` | `old_contract_id`, `new_contract_id`, `renewed_at`, `renewed_by` | FK → 2 `labor_contract` | Nối tiếp tái ký; HĐ cũ bất biến |
| `contract_warning_event` | `contract_id`, `milestone` (90/60/30), `fired_at`, `notified_roles` | FK → `labor_contract` | Job hằng ngày sinh; idempotent theo (contract, milestone) |
| `contract_escalation` | `contract_id`, `week_no`, `escalated_to` (BOD), `resolved_at` | FK → `labor_contract` | Lặp theo tuần đến khi xử lý |
| `contract_addendum` | `contract_id`, `no`, `content`, `effective_from`, `scan_file_ref` | FK → `labor_contract` | Tham chiếu nguồn 03 mục 9; thay đổi hạn → tính lại mốc nhắc |
| `audit_log` | `actor_id`, `entity`, `before/after`, `at`, `tenant_id` | — | Bất biến; gồm cả lượt xem file scan |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết đầy đủ được điền ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Ba mốc nhắc đúng | HĐ hết hạn 30/11/2026 | Job chạy ngày 02/09, 01/10, 31/10/2026 | Phát đúng 3 sự kiện 90/60/30; mỗi sự kiện 1 lần duy nhất (idempotent) khi job chạy lại trong ngày | [ ] |
| SC-002: Quá hạn → đỏ + escalate | HĐ quá hạn 7 ngày chưa tái ký | Job tuần chạy | HĐ đánh dấu cảnh báo đỏ; bản ghi escalate BOD tạo; escalate cũ chưa xử lý vẫn hiển thị | [ ] |
| SC-003: Không xác định thời hạn | HĐ có flag indefinite | Job quét hằng ngày | HĐ không sinh cảnh báo 90/60/30 và không bao giờ vào cảnh báo đỏ | [ ] |
| SC-004: Ký HĐ chính thức chặn thiếu đánh giá | Chưa có đánh giá hết thử việc đạt | HR_L1 tạo HĐLĐ chính thức | API từ chối với mã lỗi rõ ràng, trỏ thiếu điều kiện BR-HR2-04 | [ ] |
| SC-005: Quyền mở file scan | HR_L1 gọi API đọc file scan | Service kiểm tra quyền | Từ chối; lượt từ chối cũng được log | [ ] |

> **Liên kết:** Các scenario map đến REQ-HR-002 (`hr.md` Mục A3/B2) và BR-HR2-01..08 ở Mục 3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI (counterpart SYS-BCERP-WEB) | `phase4-ux/core-backend/hr-core/hdld-canh-bao.md` |
| Nguồn domain vòng đời HR v3.9 + biểu mẫu hợp đồng | `documents/03_Quy_che_KPI_HR.md` (mục 2, 3, 9) |
