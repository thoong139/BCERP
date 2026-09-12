# Tính Năng: Quarterly Access Review & Phân Quyền

> **Dựa trên:** REQ-BOD-007 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** BCERP Core Backend (SYS-CORE-BACKEND)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/core-backend/rbac-audit/feat-core-rbac-003-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-RBAC-003 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-007 |
| Người dùng liên quan | BOD_CEO (chủ trì, ký), BOD_CFO_CTO (xuất báo cáo, bị review), SYS_ADMIN (thực thi sau phê duyệt) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — RBAC nền GĐ1; chu kỳ review từ go-live) |
| Phụ thuộc | FEAT-CORE-RBAC-005 (nền tảng RBAC & SSO/MFA tập trung — bảng vai/role assignment do engine này quản); tiêu thụ credential inventory từ SYS-INTEGRATION-GW (REQ-BOD-008) |
| Ghi chú Expert (A7) | bod.md Mục A7 chưa ghi điều chỉnh nào sau Expert Review — spec bám nguồn Phần B (B7) của bod.md |

---

## 1. Mô Tả Tính Năng

**Mục đích:**

Bảo đảm quyền truy cập trong BCERP luôn phản ánh đúng cơ cấu tổ chức thực tế: mỗi quý hệ thống sinh báo cáo user × role × level kèm inventory credentials, CEO đối chiếu và ký duyệt trong 10 ngày đầu quý; gán/thu hồi role thuộc thẩm quyền độc quyền của CEO; quyền không được review 2 quý liên tiếp tự vô hiệu. Đây là vòng lặp kiểm soát đóng — không cho phép quyền "sống sót" âm thầm sau khi người dùng đã đổi vị trí hoặc nghỉ việc.

**Phạm vi:**

- Bao gồm:
  - Job sinh báo cáo access review tự động trong ngày 1–10 đầu quý: user × role × level, phạm vi dữ liệu tier (C1/C2/C3/T1–T4), trạng thái tài khoản (thử việc/chính thức/guest).
  - API đối chiếu: CEO đánh dấu giữ/thu hồi từng dòng, quyết định gán/thu hồi role; SYS_ADMIN thực thi sau phê duyệt; bằng chứng ký lưu vào access review record.
  - Cơ chế tự vô hiệu: quyền chưa được review 2 quý liên tiếp tự đóng băng đến khi review xong.
  - Giám sát liên tục ngoài chu kỳ quý: cảnh báo token/credential đến hạn rotate (T-7), offboarding → tự revoke + rotate ≤24h có checklist CTO xác nhận, offboarding khẩn 24h cho nghỉ đột xuất.
  - Kiểm soát tài khoản đặc biệt: người thử việc/freelancer không có quyền phê duyệt; guest tối đa 90 ngày (gia hạn phải duyệt).
- Không bao gồm:
  - Workspace review UI (bảng đối chiếu lớn, ký trên web) — do SYS-BCERP-WEB (counterpart); bản này là API/domain service.
  - Inventory credentials/token của 7 nền tảng và vault mã hóa — thuộc SYS-INTEGRATION-GW (REQ-BOD-008); bản này chỉ tiêu thụ inventory (token, ngày rotate) khi sinh báo cáo.
  - Chu trình offboarding HR đầy đủ (chốt phép, bàn giao tài sản) — thuộc DEPT-HR; bản này chỉ nhận sự kiện offboarding và thực thi thu hồi quyền + rotate.
  - RBAC engine định nghĩa vai/phạm vi — thuộc FEAT-CORE-RBAC-005; bản này là chu kỳ kiểm soát trên nền đó.

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint là **headless API/domain service trên core backend**: sinh báo cáo, nhận quyết định giữ/thu hồi, thực thi revoke và tự vô hiệu đều ở service layer; web chỉ render bảng đối chiếu và gọi API.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Nhận báo cáo user × role × level + inventory credentials trong ngày 1–10 đầu quý qua API | Có đầy đủ dữ liệu để đối chiếu với sơ đồ tổ chức, không phải xin tay từng phòng |
| 2 | BOD_CEO | Đánh dấu giữ/thu hồi từng dòng quyền và ký xác nhận qua API có MFA | Bằng chứng kiểm soát được lưu tự động, chuẩn cho thanh tra/kiểm toán |
| 3 | BOD_CEO | Là người duyệt duy nhất mọi quyết định gán/thu hồi role (kể cả role của SYS_ADMIN) | SYS_ADMIN không thể tự mở rộng quyền của chính mình — chặn leo thang đặc quyền |
| 4 | BOD_CFO_CTO | Xuất nộp báo cáo quyền của mình (bị review) kèm credentials inventory từ GW | Minh bạch vai CTO/Super Admin trước CEO theo compensating control REQ-BOD-002 |
| 5 | SYS_ADMIN | Thực thi lệnh revoke/rotate sau khi CEO duyệt, mỗi bước được ghi audit log | Thực thi rõ ràng có căn cứ, không bị nghi ngờ can thiệp trái |
| 6 | Hệ thống (job) | Tự vô hiệu quyền chưa được review 2 quý liên tiếp | Chu kỳ review không phụ thuộc trí nhớ — bỏ review thì quyền tự đóng băng, an toàn theo thiết kế |
| 7 | Hệ thống (job) | Cảnh báo token đến hạn rotate T-7 và tự revoke + rotate ≤24h khi nhận sự kiện offboarding | Credential của người nghỉ việc không còn giá trị ngay trong ngày |
| 8 | BOD_CEO | Chặn sẵn quyền phê duyệt cho người thử việc/freelancer và giới hạn guest tối đa 90 ngày | Quyền tạm thời không biến thành quyền vĩnh viễn |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | (Dùng chung lane) RBAC chuẩn hóa 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ portal/mobile-portal). KHÔNG có OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight | Báo cáo review không sinh dòng cho vai ngoài registry; gán vai ngoài registry bị chặn |
| BR-002 | (Dùng chung lane) Audit log bất biến hash-chain ≥10 năm WORM với log tiền; mọi thao tác ghi có actor + timestamp + lý do — bao gồm mọi quyết định giữ/thu hồi/gán role | Quyết định review thiếu reason code (khi thu hồi) không lưu được; thao tác gán/giữ không vết bị chặn |
| BR-003 | (Dùng chung lane) Quarterly access review bắt buộc; kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002): CEO ký review quyền CFO/CTO không ủy quyền, trong 10 ngày đầu quý | Quá ngày 10 chưa ký → cảnh báo đỏ; thiếu ký 2 quý liên tiếp → tự vô hiệu |
| BR-004 | (Dùng chung lane) SSO/MFA tập trung; PII nhân sự (lương) Confidential/Restricted — báo cáo review không hiển thị giá trị lương/cost cá nhân, chỉ hiển thị tier/vai/phạm vi | API trả báo cáo chứa giá trị PII cho vai không đủ tier → service mask |
| BR-005 | (Dùng chung lane) Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền — quyền phê duyệt tài chính gắn với vai được review hàng quý | Người dùng hết quyền phê duyệt sau review vẫn gọi API duyệt → bị chặn với thông báo quyền đã thu hồi |
| BR-006 | Chỉ BOD_CEO duyệt gán/thu hồi role — SYS_ADMIN không tự gán quyền kể cả cho chính mình; gán/thu hồi chỉ thực thi sau phê duyệt CEO (role assignment chỉ chuyển trạng thái qua chữ ký CEO) | Lệnh gán không có phê duyệt CEO bị RBAC engine từ chối thực thi; nỗ lực tự gán bị log để rà định kỳ |
| BR-007 | Quyền chưa được review 2 quý liên tiếp → service tự vô hiệu đến khi review xong (không xóa role — chỉ đóng băng); không review được ghi rõ là do bỏ lỡ chu kỳ, không quy trách nhiệm cho người dùng | API check quyền trả "quyền đóng băng chờ review"; giao dịch dùng quyền đóng băng bị từ chối |
| BR-008 | Người thử việc và freelancer không có quyền phê duyệt (mọi loại); guest account tối đa 90 ngày — gia hạn phải qua phê duyệt CEO | Gán role có quyền duyệt cho tài khoản thử việc/freelancer bị validation chặn; guest quá 90 ngày tự khóa |
| BR-009 | Cảnh báo token/credential đến hạn rotate tại T-7 (nguồn inventory GW); offboarding → tự revoke quyền RBAC + rotate credentials ≤24h, checklist CTO xác nhận; nghỉ đột xuất chạy offboarding khẩn 24h, lệch chuẩn ghi nhận vào kỳ review | Job phát hiện credential quá hạn rotate → alert; offboarding quá 24h chưa hoàn tất checklist → alert đỏ lên BOD |
| BR-010 | Chu trình review hoàn tất trong 10 ngày đầu quý; bằng chứng ký (ai ký, khi nào, nội dung version nào) lưu vào access review record bất biến | Ký ngoài 10 ngày được ghi nhận "lệch SLA" vào báo cáo kỳ; không được ghi đè bằng chứng cũ |
| BR-011 | MOBILE không có touchpoint riêng cho chu trình quý (bảng lớn, đối chiếu nhiều nguồn) — API từ chối thao tác review từ thiết bị mobile; chu trình thực hiện trên web nội bộ | Yêu cầu API review với context mobile bị từ chối; chỉ duyệt khẩn giao dịch tiền qua mobile theo REQ-BOD-002 |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Xem báo cáo access review (API) | ✅ | ✅ (phần mình bị review + tổng quan để xuất nộp) | ❌ (chỉ nhận lệnh thực thi chi tiết) |
| Sinh báo cáo review quý | ✅ (yêu cầu/xem) | ✅ (xuất nộp) | ✅ (vận hành job kỹ thuật, không nội dung) |
| Đánh dấu giữ/thu hồi từng dòng | ✅ | ❌ | ❌ |
| Ký quarterly review | ✅ (bắt buộc, không ủy quyền) | ❌ | ❌ |
| Duyệt gán/thu hồi role | ✅ (duy nhất) | ❌ | ❌ (không tự gán kể cả cho mình) |
| Thực thi revoke/rotate sau duyệt | ❌ | ✅ (checklist offboarding CTO xác nhận) | ✅ (thực thi sau duyệt, mọi bước log) |
| Đề xuất gia hạn guest >90 ngày | ❌ | ✅ (đề xuất) | ✅ (đề xuất) |
| Duyệt gia hạn guest | ✅ | ❌ | ❌ |
| Sửa báo cáo review đã ký | ❌ | ❌ | ❌ (bất biến) |

**Ghi chú phân quyền:** chỉ dùng 18 vai registry; không có CUSTOMER trên feature nội bộ này. Vai HR (HR_L1/HR_L2) cung cấp trạng thái thử việc/chính thức/nghỉ việc cho báo cáo qua integration nhưng không tham gia duyệt review.

---

## 5. Trường Hợp Đặc Biệt

- **CEO vắng dài ngày trong kỳ review:** không có cơ chế ủy quyền ký review (theo compensating control REQ-BOD-002); CEO ký từ xa qua kênh an toàn; nếu thực sự không ký — quyền chưa review tự vô hiệu theo BR-007: hệ thống an toàn theo thiết kế, không kẹt vì con người.
- **Nghỉ đột xuất (bỏ việc, kỷ luật):** HR phát sự kiện offboarding khẩn → service chạy revoke toàn bộ quyền RBAC trong 24h + phát yêu cầu thu hồi TKQC cho DEPT-OPS (thực thi trên nền tảng Ads, HR quản SLA) + rotate credentials liên quan; lệch chuẩn (quá 24h) ghi nhận vào kỳ review đang tới.
- **Một người nhiều vai (thường vụ vì cty nhỏ):** báo cáo review liệt kê từng role một dòng riêng; CEO đánh giá từng role; xung đột SoD giữa các role của cùng người được gắn cờ và tách theo luồng duyệt (nối REQ-BOD-002/REQ-BOD-011).
- **Nhân viên đổi phòng ban giữa kỳ:** role cũ giữ nguyên cho đến kỳ review hoặc đến khi có lệnh thu hồi riêng có phê duyệt CEO — không ai được thu hồi "tiện tay" không vết; đổi chức danh không tự đổi role.
- **Guest làm việc theo đợt >90 ngày (agency freelance dài hạn):** tài khoản tự khóa ở ngày 91; gia hạn phải duyệt trước khi hết hạn, không có hiệu lực hồi tố; guest không bao giờ được quyền phê duyệt kể cả đã gia hạn.
- **Credentials inventory từ GW thiếu (adapter mới chưa cấu hình):** báo cáo review vẫn sinh phần RBAC; phần credentials ghi trạng thái "thiếu dữ liệu inventory" và là alert riêng cho CTO — không được bỏ im phần thiếu.
- **Review kỳ trùng thời điểm thay đổi tổ chức lớn (tách bộ phận):** CEO có thể thu hồi hàng loạt trong một kỳ; thực thi theo lô có log, mỗi dòng một trạng thái riêng để rollback từng dòng khi sai.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Chu kỳ access review quý (Access Review Cycle)

**Sơ đồ trạng thái:**
```
[NOT_STARTED] ──(ngày 1 đầu quý, job sinh báo cáo)──► [IN_PROGRESS] ──(CEO ký đủ mọi dòng)──► [SIGNED] ──(thực thi revoke/gán xong)──► [CLOSED]
                                                           │
                                               (hết ngày 10 chưa ký)
                                                           ▼
                                                     [OVERDUE_ALERT] ──(vẫn phải ký để đóng)──► [SIGNED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NOT_STARTED` | Job sinh báo cáo | `IN_PROGRESS` | Hệ thống (ngày 1–10 đầu quý) | Báo cáo gồm user × role × level + credentials inventory |
| `IN_PROGRESS` | CEO ký | `SIGNED` | BOD_CEO (không ủy quyền) | MFA TOTP; mọi dòng có quyết định giữ/thu hồi; ký ghi access review record |
| `IN_PROGRESS` | Quá ngày 10 | `OVERDUE_ALERT` | Hệ thống | Alert đỏ lên CEO + CFO; chu kỳ vẫn phải hoàn tất |
| `SIGNED` | Thực thi quyết định | `CLOSED` | SYS_ADMIN (thực thi), hệ thống theo dõi | Mỗi revoke có log + reason; checklist offboarding (nếu có) CTO xác nhận |

**Quy tắc:** `CLOSED` là trạng thái kết thúc — không sửa nội dung kỳ đã đóng; sai sót xử lý bằng điều chỉnh trong kỳ kế tiếp có log. Role assignment riêng có state machine: `PROPOSED` → `CEO_APPROVED` → `ACTIVE` → `REVOKED`/`AUTO_DISABLED` (chưa review 2 quý); `PROPOSED` → `REJECTED`.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `access_review_cycle` | `cycle_id`, `quarter`, `status`, `opened_at`, `signed_by`, `signed_at`, `sla_status` | 1-N → `access_review_line` | Sinh tự động ngày 1–10 đầu quý; bằng chứng ký bất biến |
| `access_review_line` | `line_id`, `cycle_id`, `user_id`, `role_code`, `level`, `data_tier`, `decision` (`KEEP`/`REVOKE`), `reason` | FK → `access_review_cycle`, `user_account` | 1 dòng per user × role; decision bắt buộc trước khi ký |
| `role_assignment` | `assignment_id`, `user_id`, `role_code`, `status`, `approved_by_ceo_at`, `revoked_at`, `last_reviewed_quarter` | FK → `user_account` | Chỉ chuyển trạng thái sau chữ ký CEO; 2 quý không review → `AUTO_DISABLED` |
| `account_lifecycle_event` | `event_id`, `user_id`, `event_type` (`PROBATION_START`, `OFFICIAL`, `OFFBOARDING`, `GUEST_CREATED`...), `occurred_at`, `checklist_ref` | FK → `user_account` | Offboarding kích hoạt revoke ≤24h + rotate; khẩn 24h cho nghỉ đột xuất |
| `credential_rotation_watch` | `credential_ref`, `platform`, `last_rotated_at`, `next_due_at`, `alert_t7_sent` | Nguồn: inventory SYS-INTEGRATION-GW | Cảnh báo T-7; quá hạn → alert; liên quan nghỉ việc → rotate ≤24h |
| `audit_event` | (như FEAT-CORE-RBAC-002) | Ghi mọi quyết định review | Actor + timestamp + lý do; hash-chain |

---

## 8. Acceptance Criteria

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Sinh báo cáo đúng hạn | Ngày 1 đầu quý | Job chạy | Báo cáo user × role × level + credentials inventory sẵn sàng; CFO/CTO xuất nộp CEO qua API; không dòng nào thiếu role/trạng thái | [ ] |
| SC-002: CEO ký review không ủy quyền | Chu kỳ `IN_PROGRESS` | SYS_ADMIN hoặc CFO cố ký hộ | API từ chối (chỉ BOD_CEO); CEO ký thành công với MFA; bằng chứng ký lưu bất biến | [ ] |
| SC-003: SYS_ADMIN không tự gán role | SYS_ADMIN đăng nhập | Gọi API gán role cho chính mình | Từ chối — thiếu phê duyệt CEO; nỗ lực ghi log; role chỉ ACTIVE sau `CEO_APPROVED` | [ ] |
| SC-004: Tự vô hiệu 2 quý không review | Quyền X không xuất hiện trong ký review của 2 kỳ liên tiếp | Job cuối kỳ chạy | Quyền X chuyển `AUTO_DISABLED`; API check quyền trả "đóng băng chờ review"; giao dịch dùng quyền X bị chặn | [ ] |
| SC-005: Thử việc không có quyền duyệt | Tài khoản ở trạng thái thử việc | Gán role chứa quyền phê duyệt | Validation chặn; tài khoản thử việc chỉ nhận role vận hành không duyệt | [ ] |
| SC-006: Guest hết 90 ngày | Guest tạo từ 90 ngày trước, không gia hạn | Job ngày 91 chạy | Tài khoản tự khóa; gia hạn đã duyệt trước đó → tiếp tục hiệu lực có log | [ ] |
| SC-007: Offboarding 24h | HR phát sự kiện offboarding | Service xử lý | Toàn bộ quyền RBAC revoke ≤24h; yêu cầu thu hồi TKQC gửi OPS có SLA theo dõi; credentials liên quan rotate; checklist CTO xác nhận; quá hạn → alert đỏ | [ ] |

> **Liên kết:** SC-001→002 map REQ-BOD-007 (chu trình + ký); SC-003→004 map REQ-BOD-007/REQ-BOD-002 (thẩm quyền + compensating control); SC-005→006 map REQ-BOD-007 (thử việc/guest); SC-007 map REQ-BOD-007 + REQ-HR-001 (offboarding phối hợp OPS).

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (review cycle, role assignment, offboarding hook) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (credential inventory từ GW, sự kiện HR, alert REQ-BOD-006) | `technical-specs/integration-map.md` |
| Màn hình UI (workspace review, ký — counterpart WEB) | `phase4-ux/core-backend/rbac-audit/[screen-group].md` |
| Touchpoint counterpart | SYS-INTEGRATION-GW (inventory credentials), SYS-BCERP-WEB (fan-out cùng REQ-BOD-007) |
