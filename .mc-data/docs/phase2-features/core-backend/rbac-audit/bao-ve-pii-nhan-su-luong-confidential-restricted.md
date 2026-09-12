# Tính Năng: Bảo Vệ PII Nhân Sự (Lương Confidential/Restricted)

> **Dựa trên:** REQ-HR-010 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** BCERP Core Backend (SYS-CORE-BACKEND)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/core-backend/rbac-audit/feat-core-rbac-006-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-RBAC-006 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-HR-010 |
| Người dùng liên quan | HR_L1, HR_L2 (quản trị PII); FIN_L2 (thẩm định rate — có log); BOD_CEO, BOD_CFO_CTO (xem đầy đủ); SYS_ADMIN (thu hồi quyền, không xem giá trị); legal (breach) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (GĐ1 — security cross-cutting, ràng buộc NĐ 13/2023, áp cho mọi REQ) |
| Phụ thuộc | FEAT-CORE-RBAC-005 (nền tảng RBAC & SSO/MFA tập trung — ma trận quyền và data tier C1/C2/C3 do engine này cấp); FEAT-CORE-RBAC-002 (audit log bất biến cho mọi lượt xem/sửa PII) |
| Ghi chú Expert (A7) | hr.md Mục A7 đã thiết lập khung đánh giá; A7.3 chưa ghi điều chỉnh nào — các điểm A7.2 đang chờ đều không đổi phạm vi REQ-HR-010; quy trình HR tổng thể còn mở tại `[KXN-18]` nhưng không ảnh hưởng ma trận quyền/retention của REQ-HR-010 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**

Bảo vệ dữ liệu cá nhân nhân sự của BC Agency ở mức đúng quy định pháp luật (NĐ 13/2023) và đúng ranh giới tổ chức: lương, CCCD, tài khoản ngân hàng là dữ liệu C1 — mã hóa khi lưu và truyền, chỉ HR_L2 trở lên xem được giá trị, mọi lượt xem/sửa có audit log bất biến. Đây là ràng buộc cross-cutting áp cho mọi phân hệ chạm dữ liệu nhân sự (cost rate, P&L, hoa hồng, tuyển dụng), không phải một màn hình riêng.

**Phạm vi:**

- Bao gồm:
  - Phân loại PII toàn cục: C1 nhạy cảm (CCCD, lương, TK ngân hàng, dữ liệu y tế) — mã hóa khi lưu/truyền, cấm xuất raw; C2 định danh thường; C3 dữ liệu công việc.
  - Ma trận quyền lương/cost ở tier Restricted: chỉ HR_L2+ xem lương/cost cá nhân; HR_L1 không xem lương; manager chỉ tổng cost nhóm; FIN_L2 xem khi thẩm định rate (có log); SYS_ADMIN quản hạ tầng không xem giá trị.
  - Audit log bất biến cho mọi lượt xem/sửa lương, HĐLĐ, dữ liệu C1 (ai — khi nào — giá trị trước/sau); review ma trận truy cập C1 theo quý.
  - Retention: hồ sơ nhân sự theo pháp luật lao động; lương/chứng từ kế toán 10 năm (Luật Kế toán 2015); hồ sơ ứng tuyển không trúng 12 tháng; hết hạn → xóa/ẩn danh có log hủy có phê duyệt.
  - Data minimization cho form tuyển dụng/onboarding; quy trình breach phối hợp legal (thông báo 72h theo NĐ 13/2023).
- Không bao gồm:
  - Nghiệp vụ CRUD hồ sơ nhân sự, HĐLĐ, chấm công, nghỉ phép — thuộc phân hệ HR-CORE; bản này là lớp bảo vệ (classification, mask, audit, retention) phủ lên dữ liệu đó.
  - Màn hình UI masked và báo cáo review truy cập trên web — do SYS-BCERP-WEB (counterpart); bản này enforce ở service layer.
  - Retention WORM chứng từ tiền chung — thuộc FEAT-CORE-RBAC-007; bản này chia sẻ bảng retention cho nhóm hồ sơ lương.
  - DSAR/DPA của khách hàng — thuộc REQ-FIN-017; bản này chỉ áp nguyên tắc tương tự cho nhân sự.

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint là **headless API/domain service trên core backend**: mã hóa, mask, audit và retention enforce ở service layer; UI chỉ hiển thị trạng thái masked do API trả về, không tin UI.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | HR_L2 | Xem và sửa đầy đủ lương, HĐLĐ, dữ liệu C1 của nhân sự qua API, mỗi thao tác tự động có log | Quản trị hồ sơ đầy đủ mà mọi thao tác tự minh bạch, không phải tự ghi chép |
| 2 | HR_L1 | Xử lý nghiệp vụ hành chính mà không thấy giá trị lương cá nhân (chỉ masked), nhưng vẫn xem tổng cost nhóm | Làm đúng phần việc của mình, ranh giới trách nhiệm rõ ràng |
| 3 | Manager/TL | Xem tổng cost nhóm mình qua API (không lương, không cost cá nhân) | Quản lý chi phí đội nhóm mà không xâm phạm PII cá nhân |
| 4 | FIN_L2 | Xem cost/hour khi thẩm định Rate Card qua API có log | Thẩm định giá vốn đúng thẩm quyền, mỗi lần xem minh bạch |
| 5 | SYS_ADMIN | Thu hồi quyền truy cập PII trong 24h khi offboard, review ma trận C1 theo quý mà không xem giá trị lương | Vận hành an toàn theo least privilege |
| 6 | BOD_CEO / BOD_CFO_CTO | Xem đầy đủ lương/cost khi cần ra quyết định, có log | Quyết định trên dữ liệu thật với dấu vết kiểm soát |
| 7 | Hệ thống (retention job) | Tự phát hiện hồ sơ đến hạn (ứng tuyển 12 tháng, hồ sơ theo luật lao động) và đưa vào luồng xóa/ẩn danh có phê duyệt | Tuân thủ retention mà không ai phải nhớ tay, không xóa hồ sơ thuộc nghĩa vụ luật định |
| 8 | Legal/officer | Khi breach PII, nhận alert trong 4 giờ và có timer 72h cho thông báo A06 | Đáp ứng nghĩa vụ NĐ 13/2023 đúng hạn với bằng chứng |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | (Dùng chung lane) RBAC chuẩn hóa 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ portal). KHÔNG có OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight | Ma trận PII không cấu hình được vai ngoài registry; gán quyền xem C1 cho vai sai bị chặn |
| BR-002 | (Dùng chung lane) Audit log bất biến hash-chain ≥10 năm WORM với log tiền; mọi thao tác ghi có actor + timestamp + lý do — riêng PII: mọi lượt XEM/SỬA lương, HĐLĐ, dữ liệu C1 cũng có log bất biến (ai — khi nào — giá trị trước/sau); xem log PII cũng bị log (meta-log) | Lượt xem không log là bất khả thi về thiết kế (service ghi trước khi trả dữ liệu); nỗ lực xóa log thất bại |
| BR-003 | (Dùng chung lane) Quarterly access review bắt buộc (gắn review ma trận truy cập C1 — HR_L2 + SYS_ADMIN); compensating control kiêm nhiệm CFO/CTO (REQ-BOD-002) áp như mọi luồng phân quyền | Ma trận C1 chưa review vào kỳ → cờ "chờ review" trên báo cáo; quyền C1 của người không được review 2 quý tự vô hiệu theo FEAT-CORE-RBAC-003 |
| BR-004 | (Dùng chung lane) SSO/MFA tập trung; PII nhân sự (lương) ở mức Confidential/Restricted — đây là định nghĩa gốc của mức Confidential/Restricted: C1 mã hóa AES khi lưu và TLS khi truyền; session truy cập C1 có thời hạn ngắn theo tier (nối FEAT-CORE-RBAC-005) | Dữ liệu C1 lưu plaintext hoặc truyền không mã hóa → fail security review; phiên truy cập C1 không tier cao → từ chối |
| BR-005 | (Dùng chung lane) Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation khi vượt thẩm quyền — không trực tiếp trên dữ liệu PII, nhưng lệnh xóa/ẩn danh hồ sơ đến hạn và mọi duyệt liên quan hồ sơ nhân sự chạy luồng phê duyệt có log | Xóa/ẩn danh không phê duyệt bị chặn; duyệt sai vai bị từ chối |
| BR-006 | Phân loại bắt buộc: C1 (CCCD, lương, TK ngân hàng, dữ liệu y tế) — mã hóa lưu + truyền, cấm xuất raw; C2 định danh thường; C3 công việc; mọi entity chứa PII phải khai báo classification trước khi triển khai | API trả trường C1 cho vai không đủ tier → service mask bắt buộc; xuất file C1 raw → chặn với lỗi "cấm xuất raw" |
| BR-007 | Ma trận quyền lương/cost (Restricted): HR_L2 xem + sửa lương, xem cost, xem log PII; HR_L1 không xem lương/cost cá nhân, xem tổng cost nhóm; BOD xem đầy đủ; FIN_L2 xem khi thẩm định rate (log); manager chỉ tổng cost nhóm mình; SYS_ADMIN không xem giá trị, xem log PII — xem log cũng bị log | Truy cập ngoài ma trận → service từ chối; ngoại lệ điều tra phải có phê duyệt BOD_CEO + meta-log + giới hạn thời hạn phiếu |
| BR-008 | Offboard thu hồi quyền PII trong 24h (gắn checklist FEAT-CORE-RBAC-005/REQ-BOD-007); review ma trận truy cập C1 theo quý (HR_L2 + SYS_ADMIN) | Quá 24h chưa thu hồi → alert đỏ; kỳ review bỏ qua ma trận C1 → cảnh báo BOD |
| BR-009 | Retention phân tầng: hồ sơ nhân sự theo pháp luật lao động; lương/chứng từ kế toán 10 năm (Luật Kế toán 2015); ứng tuyển không trúng 12 tháng; hết hạn → xóa/ẩn danh có log hủy có phê duyệt; nghĩa vụ lưu trữ luật định ưu tiên hơn yêu cầu xóa | Xóa trước hạn → chặn; hết hạn không xử lý → xuất hiện trong báo cáo dữ liệu đến hạn hàng quý |
| BR-010 | Data minimization: form tuyển dụng/onboarding chỉ thu thập trường tối thiểu theo cấu hình phê duyệt; trường ngoài danh sách bị service loại bỏ | Form chứa trường PII không phê duyệt → validation chặn khi cấu hình form |
| BR-011 | Breach PII: người phát hiện báo legal trong 4 giờ; thông báo A06 trong 72h theo NĐ 13/2023; incident intake + timer 72h ở service (khớp BR-FIN-604) | Timer quá hạn chưa thông báo → alert đỏ BOD; hồ sơ breach lưu truy xuất |
| BR-012 | Xuất PII cho thuế/BHXH: theo mẫu chuẩn có phê duyệt, mỗi lần xuất có log (ai, khi nào, phạm vi); cấm xuất ad-hoc raw C1 (BR-006) | Xuất không theo mẫu/không log bị chặn; file xuất có watermark người dùng |

**Assumptions (ghi nhận, không tự quyết):** `[KXN-18]` quy trình HR trong bộ tài liệu quy trình v1.1 còn mở — spec này thiết kế lớp bảo vệ PII độc lập với chi tiết quy trình HR; khi KXN-18 chốt, chỉ cần rà lại danh sách trường thu thập (BR-010) và luồng sự kiện HR, không đổi kiến trúc.

---

## 4. Phân Quyền

Ma trận bám nguyên văn hr.md Phần B (B10) — tất cả enforce ở service layer:

| Hành động | HR_L1 | HR_L2 | FIN_L2 | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|-------|-------|--------|---------|-------------|-----------|
| Xem lương cá nhân (C1) | ❌ (masked) | ✅ (xem + sửa) | ❌ (chỉ khi thẩm định rate — log) | ✅ (log) | ✅ (log) | ❌ (không xem giá trị) |
| Sửa lương cá nhân (C1) | ❌ | ✅ (log before/after) | ❌ | ❌ | ❌ | ❌ |
| Xem cost/hour cá nhân | ❌ | ✅ | ✅ (khi thẩm định — log) | ✅ | ✅ | ❌ |
| Xem tổng cost nhóm | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem log truy cập PII | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (xem log cũng bị log) |
| Đề xuất xóa/ẩn danh hồ sơ đến hạn | ✅ (đề xuất) | ✅ (đề xuất) | ❌ | ✅ (duyệt) | ❌ | ❌ |
| Review ma trận truy cập C1 (quý) | ❌ | ✅ (chủ trì) | ❌ | ❌ | ❌ | ✅ (phối hợp kỹ thuật) |
| Mã hóa/khóa cấu hình classification C1 | ❌ | ❌ | ❌ | ✅ (duyệt) | ✅ (thực thi kỹ thuật) | ✅ (áp sau duyệt) |
| Xuất PII cho thuế/BHXH theo mẫu | ✅ (thực hiện) | ✅ (phê duyệt nội bộ) | ❌ | ❌ | ❌ | ❌ (hạ tầng file, không nội dung) |

**Ghi chú phân quyền:** chỉ dùng 18 vai registry; chức quản lý nhóm (thực chất các vai OPS_*/SALES_* giữ nhóm) không có quyền PII riêng ngoài "tổng cost nhóm mình", không tạo vai mới.

---

## 5. Trường Hợp Đặc Biệt

- **Yêu cầu xóa hồ sơ (DSAR nội bộ) trùng nghĩa vụ lưu trữ:** hồ sơ lương/chứng từ thuộc nghĩa vụ 10 năm — luật định ưu tiên; xóa/ẩn danh phần không thuộc nghĩa vụ, ghi nhận lý do có log.
- **Hồ sơ ứng tuyển không trúng quá 12 tháng:** retention job gom đề xuất xóa/ẩn danh theo quý; người duyệt xác nhận hàng loạt có log; CV có đồng ý lưu dài hạn thì gia hạn theo đồng ý.
- **FIN_L2 đối chiếu cost rate vs payroll (ngưỡng lệch ±10% đang chờ chốt theo hr.md):** xem giá trị trong phiên thẩm định có log và thời hạn; hết phiên, quyền tự đóng.
- **Lương nằm trong log giao dịch (ví dụ log chỉnh cost rate ảnh hưởng P&L):** log ghi full old → new ở tầng lưu, nhưng khi tra cứu giá trị PII bị mask theo vai người tra cứu (BR-002 + BR-006).
- **Báo cáo tổng cost nhóm cho manager:** service tổng hợp từ Rate Card không để lộ giá trị cá nhân; nhóm ít hơn ngưỡng tối thiểu người (chống suy ngược lương từ tổng) → ghi "không đủ cỡ mẫu".
- **Breach nghi ngờ từ truy cập bất thường:** anomaly trong log PII (xem hàng loạt ngoài giờ) kích hoạt cảnh báo review; xác nhận breach → chạy BR-011 (4h báo legal, 72h thông báo A06).

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Bản ghi hồ sơ PII đến hạn retention (PII Retention Item)

**Sơ đồ trạng thái:**
```
[ACTIVE] ──(job phát hiện đến hạn)──► [DUE] ──(gom đề xuất quý)──► [DISPOSAL_PROPOSED] ──(duyệt)──► [DISPOSAL_APPROVED] ──(thực thi)──► [DISPOSED]
    │                                     │
    │ (thuộc nghĩa vụ luật định /         │ (có yêu cầu pháp lý → giữ thêm)
    │  đồng ý lưu dài hạn)                ▼
    ▼                              [LEGAL_HOLD]
[RETENTION_LOCKED] (giữ theo hạn luật định, không vào luồng xóa)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ACTIVE` | Job quét hạn | `DUE` | Hệ thống | Ứng tuyển quá 12 tháng / hồ sơ hết hạn luật lao động; lương/chứng từ 10 năm → `RETENTION_LOCKED` đến đủ 10 năm |
| `ACTIVE` | Đánh dấu nghĩa vụ luật định | `RETENTION_LOCKED` | Hệ thống theo `retention_schedule` | Căn cứ Luật Kế toán 2015/pháp luật lao động |
| `DUE` | Đề xuất xóa/ẩn danh | `DISPOSAL_PROPOSED` | HR_L1/HR_L2 | Gom theo quý; liệt kê phạm vi từng hồ sơ |
| `DISPOSAL_PROPOSED` | Duyệt | `DISPOSAL_APPROVED` | BOD_CEO (luồng duyệt BR-005) | MFA; quá hạn đề xuất → nhắc lại kỳ sau |
| `DUE`/`DISPOSAL_PROPOSED` | Yêu cầu pháp lý | `LEGAL_HOLD` | Hệ thống khi có thanh tra/điều tra | Giữ đến khi hồ sơ pháp lý đóng, bất kể hạn |
| `DISPOSAL_APPROVED` | Thực thi xóa/ẩn danh | `DISPOSED` | SYS_ADMIN thực thi | Việc hủy ghi log có phê duyệt; ẩn danh bất khả nghịch |

**Quy tắc:** `DISPOSED` kết thúc — không hoàn tác; `LEGAL_HOLD` ưu tiên tuyệt đối. Mọi chuyển tiếp nằm trong audit log hash-chain.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `pii_field_classification` | `entity_name`, `field_name`, `class` (C1/C2/C3), `mask_strategy`, `encrypt_at_rest`, `encrypt_in_transit` | Áp cho mọi entity chứa PII | Khai báo bắt buộc trước triển khai (BR-006) |
| `pii_access_grant` | `grant_id`, `user_id`, `scope` (LƯONG/COST/LOG), `mode` (`FULL`/`MASKED`/`GROUP_TOTAL`/`AUDIT_ONLY`), `valid_until` | FK → `user_account` | Theo ma trận B10; phiên thẩm định FIN_L2 có `valid_until` |
| `pii_access_log` | `log_id`, `actor`, `action` (VIEW/EDIT/EXPORT), `object_ref`, `old_value_hash`, `new_value_hash`, `timestamp`, `reason_code` | Ghi bởi service PII | Bất biến hash-chain; giá trị lưu hash tham chiếu — nội dung full nằm trong audit_event mã hóa |
| `retention_schedule` | `record_type`, `min_retention`, `legal_basis` | Định tuyến `pii_retention_item` | Lương/chứng từ 10 năm; ứng tuyển 12 tháng; hồ sơ lao động theo luật |
| `pii_retention_item` | `item_id`, `record_ref`, `status` (ACTIVE/DUE/.../DISPOSED), `due_date` | FK → `retention_schedule` | State machine mục 6; job quét hằng ngày |
| `breach_incident` | `incident_id`, `detected_at`, `reported_to_legal_at`, `notify_deadline` (72h), `a06_sent_at` | Độc lập | Timer 72h NĐ 13/2023; alert đỏ nếu trễ |

---

## 8. Acceptance Criteria

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: HR_L1 không thấy lương | HR_L1 đăng nhập | Gọi API hồ sơ nhân sự | Trường lương/CCCD/TK ngân hàng masked ở service layer; không có endpoint nào trả raw cho HR_L1 | [ ] |
| SC-002: Mọi lượt xem C1 có log | HR_L2 xem lương một nhân viên | API trả dữ liệu | `pii_access_log` ghi trước khi trả kết quả: ai, khi nào, xem gì; meta-log áp cho cả người xem log | [ ] |
| SC-003: FIN_L2 thẩm định có thời hạn | Có phiên thẩm định Rate Card | FIN_L2 xem cost/hour trong phiên | Xem được có log, quyền tự đóng hết `valid_until`; ngoài phiên → bị từ chối | [ ] |
| SC-004: SYS_ADMIN không xem giá trị | SYS_ADMIN vận hành | Truy vấn dữ liệu C1 | Không có quyền giá trị — chỉ log PII (có meta-log); mã hóa chặn đọc trực tiếp DB | [ ] |
| SC-005: Cấm xuất raw C1 | Bất kỳ vai nào | Yêu cầu export chứa trường C1 raw | Service chặn với lỗi "cấm xuất raw"; xuất hợp lệ chỉ theo mẫu thuế/BHXH có log | [ ] |
| SC-006: Offboard thu hồi 24h | Nhân viên có quyền C1 nghỉ việc | Sự kiện offboarding phát | `pii_access_grant` thu hồi ≤24h trong checklist offboarding; quá hạn → alert đỏ | [ ] |
| SC-007: Retention đúng tầng | CV không trúng 12 tháng / lương đủ 10 năm | Job quét | CV vào luồng đề xuất xóa theo quý, duyệt rồi mới xóa có log; lương giữ `RETENTION_LOCKED` đủ 10 năm | [ ] |
| SC-008: Breach 72h | Phát hiện rò rỉ PII | Incident intake | Timer 72h bắt đầu; legal nhận alert trong 4h; A06 gửi đúng hạn có bằng chứng timestamp | [ ] |

> **Liên kết:** SC-001→002 map REQ-HR-010 (ma trận + audit); SC-003→004 map REQ-HR-010 + hr.md B10; SC-005→006 map REQ-HR-010 (xuất + offboard); SC-007 map REQ-HR-010 (retention, Luật Kế toán 2015); SC-008 map REQ-HR-010 (NĐ 13/2023).

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (grant, log PII, retention, breach intake) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (sự kiện HR, RBAC engine, alert REQ-BOD-006) | `technical-specs/integration-map.md` |
| Màn hình UI (masked UI, báo cáo review truy cập — counterpart WEB) | `phase4-ux/core-backend/rbac-audit/[screen-group].md` |
| Touchpoint counterpart | SYS-BCERP-WEB (fan-out cùng REQ-HR-010) |
