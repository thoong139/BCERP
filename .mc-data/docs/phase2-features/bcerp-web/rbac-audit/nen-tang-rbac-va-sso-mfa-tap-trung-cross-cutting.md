# Tính Năng: Nền Tảng RBAC & SSO/MFA Tập Trung (Cross-Cutting)

> **Dựa trên:** REQ-BOD-011 trong `phase1-business/departments/bod/bod.md` (Phần A — Bổ sung Phase 6d)
> **Phân hệ:** RBAC & Audit Log (SYS-BCERP-WEB)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/rbac-audit/feat-005-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Bản fan-out này dùng ID lane `FEAT-ERP-RBAC-005` — bản riêng của touchpoint SYS-BCERP-WEB (các bản counterpart: SYS-CORE-BACKEND, SYS-PORTAL-WEB, SYS-MOBILE-INTERNAL).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-RBAC-005 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-011 |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, CUSTOMER (SSO realm portal — truy cập qua SYS-PORTAL-WEB, không đăng nhập web nội bộ) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — GĐ1 nền móng: RBAC engine là dependency của TẤT CẢ phân hệ) |
| Phụ thuộc | Không có (điểm khởi đầu của chuỗi FEAT-ERP-RBAC-001..004, 006, 007 — mọi feature khác tham chiếu nền tảng này) |
| Ghi chú Expert (A7) | Mục A7 của `bod.md` đang chờ đánh giá chuyên gia đầy đủ; điều chỉnh liên quan đã chốt qua stakeholder review 12/09: DI-006 gỡ OPS_CX/FIN_COMPL — registry chuẩn hóa 18 vai (CX Head → OPS_PLAN, Compliance → FIN_L2 + BOD oversight); REQ-BOD-011 sinh từ resolve SO3-01 (phân hệ RBAC & Audit Log chưa có REQ sở hữu); chi tiết tại `bod.md` Mục A7 và `stakeholder-review.md` Phần F.3 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đây là nền tảng cross-cutting của toàn bộ BCERP: một điểm phân quyền tập trung (mô hình vai × Level × phạm vi dữ liệu) và một điểm xác thực tập trung (SSO Keycloak 2 realms với MFA bắt buộc cho nội bộ, OTP cho portal khách). Trên web nội bộ, nền tảng này hiện thực hóa thành các màn hình quản trị vai/phân quyền, hồ sơ user và đăng ký MFA TOTP — bảo đảm không một phân hệ nào tự dựng RBAC/SSO riêng lẻ và mọi điểm check quyền đi qua đúng một cổng duy nhất.

**Phạm vi:**
- Bao gồm: màn hình quản trị vai/phân quyền (18 vai × Level × phạm vi dữ liệu 4-tier C1/C2/C3/T1–T4) — hiển thị và đề xuất thay đổi, thực thi sau phê duyệt CEO; hồ sơ user nội bộ với lifecycle tài khoản (tạo → thử việc → chính thức → offboarding); màn đăng ký/quản lý MFA TOTP cho nhân viên nội bộ; hiển thị xung đột SoD khi 1 người giữ nhiều vai (tách xung đột duyệt theo luồng); cấu hình chính sách session/refresh theo tier dữ liệu truy cập; hiển thị mask/ẩn tự động theo vai cho dữ liệu phân loại.
- Không bao gồm: enforcement check quyền trên từng API (SYS-CORE-BACKEND — một điểm check duy nhất, web cấm check cục bộ); xác thực OTP cho user portal và reset/tạm khóa tài khoản portal (SYS-PORTAL-WEB — counterpart); đăng ký/xác thực thiết bị MFA cho duyệt mobile step-up (SYS-MOBILE-INTERNAL — counterpart); chu kỳ quarterly access review chi tiết (FEAT-ERP-RBAC-003 — nền tảng chỉ cung cấp dữ liệu vai); quản trị credentials vault (REQ-BOD-008).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Duyệt từng yêu cầu gán/thu hồi vai trên web với ngữ cảnh đầy đủ (ai đề xuất, vì sao, xung đột nào) | Giữ quyền quyết định phân quyền tối cao theo đúng nguyên tắc "chỉ CEO duyệt vai" |
| 2 | BOD_CFO_CTO | Quản trị cấu hình Keycloak 2 realms (realm nội bộ + realm portal khách) từ web nội bộ, với MFA bắt buộc | SSO tập trung một nơi — không dàn trải tài khoản xác thực rời rạc |
| 3 | SYS_ADMIN | Thực thi provisioning sau phê duyệt: tạo user, gán vai theo lệnh đã duyệt, đăng ký MFA TOTP cùng nhân viên | Thao tác đúng hạn mức thẩm quyền — đề xuất được nhưng không tự quyết |
| 4 | BOD_CEO | Xem bản đồ vai × Level × phạm vi dữ liệu toàn công ty và các cặp xung đột SoD đang tồn tại | Phát hiện sớm rủi ro lạm quyền và chuẩn bị cho kỳ access review |
| 5 | Nhân viên nội bộ (mọi vai registry) | Đăng nhập web bằng SSO và tự đăng ký MFA TOTP theo hướng dẫn từng bước | Vào được hệ thống an toàn mà không cần nhờ ai "cấu hình giùm" ngoài luồng |
| 6 | CUSTOMER (portal khách) | Được cấp tài khoản realm portal với OTP khi kích hoạt dịch vụ (thao tác trên portal — nền tảng này quản lifecycle realm) | Truy cập dữ liệu tenant của mình qua cổng xác thực thống nhất của BCERP |
| 7 | SYS_ADMIN | Xem trạng thái lifecycle từng tài khoản (thử việc/chính thức/offboarding) và hạn mức quyền tương ứng | Bảo đảm người thử việc không có quyền phê duyệt, người nghỉ đã bị thu hồi đúng hạn |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Enforcement RBAC nằm ở SYS-CORE-BACKEND — cấm mọi phân hệ tự check quyền cục bộ; web chỉ gọi điểm check tập trung và hiển thị kết quả.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | RBAC chuẩn hóa đúng 18 vai registry (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5, HR_L1/L2, FIN_L1/L2, OPS_AM/CONT/DES/EDIT, BOD_CEO, BOD_CFO_CTO, SYS_ADMIN); không tồn tại OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight; CUSTOMER chỉ tồn tại ở realm portal | Yêu cầu tạo/gán vai ngoài 18 vai bị từ chối; màn quản trị không có tùy chọn vai không hợp lệ |
| BR-002 | Mọi thao tác gán/thu hồi vai, tạo/khóa tài khoản, đăng ký MFA ghi audit log bất biến hash-chain (≥10 năm WORM với log phân quyền); mỗi thao tác có actor + timestamp + lý do | Thiếu lý do → không cho submit yêu cầu; thao tác không vết bị job đối chiếu phát hiện và gắn cờ |
| BR-003 | Gán/thu hồi vai chỉ thực thi sau phê duyệt CEO (nối REQ-BOD-007); SYS_ADMIN không tự gán quyền kể cả cho chính mình; gán/thu hồi vai chỉ áp cho tài khoản trạng thái hợp lệ | Vai trong `SUSPENDED` (không qua access review) không thể thực thi gán vai; attempt tự gán bị từ chối + log |
| BR-004 | Quarterly access review bắt buộc cho mọi vai (chu trình ở FEAT-ERP-RBAC-003); kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002) — 1 người nhiều vai không vi phạm SoD: hệ thống phát hiện cặp xung đột và tách luồng duyệt | Cặp vai xung đột SoD cùng luồng bị chặn gán; bản đồ vai hiển thị cờ xung đột bắt buộc xử lý |
| BR-005 | SSO Keycloak 2 realms: realm nội bộ (nhân viên, MFA TOTP bắt buộc) + realm portal (khách, OTP); chính sách session/refresh theo tier dữ liệu truy cập — tier cao (T3/T4, Restricted) có session ngắn hơn và bắt buộc step-up | Thiếu MFA TOTP → không vào được chức năng nội bộ; session tier cao hết hạn → bắt đăng ký lại, không có "ghi nhớ máy" |
| BR-006 | PII nhân sự (lương, cost) phân loại Confidential/Restricted: mask/ẩn tự động theo vai trên mọi màn hình (nối REQ-HR-010); phân loại dữ liệu toàn cục C1/C2/C3/T1–T4 gắn quyền truy cập | Vai không phép thấy giá trị Restricted → lỗi kiểm soát nghiêm trọng; web hiển thị masked, không có nút bỏ mask |
| BR-007 | Lifecycle tài khoản nội bộ: thử việc không có quyền phê duyệt; offboarding thu hồi quyền ≤24h (checklist nối REQ-BOD-007); guest tối đa 90 ngày | Gán quyền duyệt cho tài khoản thử việc/freelancer → chặn khi lưu; tài khoản offboard gọi API → từ chối mọi request |
| BR-008 | Các luồng phê duyệt kinh doanh tham chiếu nền tảng này bám khung ngưỡng 5/50/200 triệu VND đã chốt (DI-001) + escalation lên cấp trên khi vượt thẩm quyền; hạn mức theo vai là tham số effective-dated do REQ-BOD-009 quản | Vai chưa có tham số hạn mức hiệu lực → mọi giao dịch vượt 5tr hiển thị "chưa cấu hình thẩm quyền" và không cho duyệt |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | CUSTOMER (portal) | Vai nghiệp vụ (registry 18 vai) |
|-----------|---------|-------------|-----------|-------------------|----------------------------------|
| Đăng nhập SSO + tự đăng ký MFA TOTP | ✅ | ✅ | ✅ | ◐ (realm portal — OTP, qua PORTAL) | ✅ |
| Xem bản đồ vai × Level × dữ liệu toàn công ty | ✅ | ✅ | ◐ (phần kỹ thuật, không giá trị PII) | ❌ | ❌ |
| Đề xuất gán/thu hồi vai | ❌ | ✅ (đề xuất) | ✅ (đề xuất theo lệnh đã duyệt) | ❌ | ❌ |
| Duyệt gán/thu hồi vai | ✅ (độc quyền) | ❌ | ❌ | ❌ | ❌ |
| Quản trị cấu hình Keycloak 2 realms | ❌ | ✅ (MFA bắt buộc) | ◐ (thực thi change đã CTO duyệt) | ❌ | ❌ |
| Xem hồ sơ user (thông tin công việc C3) | ✅ | ✅ | ✅ | ❌ | ◐ (trong phạm vi nhóm mình) |
| Xem lương/cost cá nhân trong hồ sơ (Restricted) | ✅ | ✅ | ❌ | ❌ | ❌ (theo ma trận REQ-HR-010) |
| Tự gán vai/thay quyền của chính mình | ❌ | ❌ | ❌ | ❌ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- Một người giữ nhiều vai (ví dụ OPS_PLAN kiêm OPS_AM): hợp lệ — hệ thống hiển thị tổng hợp quyền theo hợp vai và tự tách xung đột duyệt theo luồng (không cho 1 người cả hai bước của cùng một luồng phê duyệt); cặp xung đột tiền báo vào thống kê SoD cho CFO rà (REQ-BOD-006).
- Nhân viên thử việc cần xem dữ liệu để làm việc: chỉ gán quyền xem C2/C3 theo phạm vi nhóm; mọi quyền phê duyệt bị khóa ở tầng vai cho đến khi chuyển trạng thái "chính thức" (hiệu lực theo ngày — SCD2).
- Mất thiết bị MFA: quy trình reset MFA qua SYS_ADMIN sau xác minh — yêu cầu có lý do, mọi bước log; không tồn tại đường "bỏ MFA vĩnh viễn" trên web nội bộ.
- Tổ chức thay đổi (thêm/sát nhập vị trí): chỉ cập nhật binding vai hiệu lực theo ngày — không đổi 18 vai registry; vai mới thực sự cần thiết phải qua quyết định stakeholder cập nhật registry (không thêm vai cục bộ theo phân hệ — bài học DI-006).
- Khách hàng portal bị khóa tài khoản: xử lý ở counterpart SYS-PORTAL-WEB (reset/tạm khóa có audit log); web nội bộ chỉ tra cứu trạng thái tài khoản portal ở chế độ read-only, không tự mở khóa hộ khách.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Tài khoản người dùng nội bộ

**Sơ đồ trạng thái:**
```
[CREATED] ──(onboarding xong)──► [PROBATION] ──(hết thử việc / chính thức)──► [ACTIVE]
                                     │                                          │
                                     │ (nghỉ/loại trong thử việc)               │ (nghỉ việc)
                                     ▼                                          ▼
                               [OFFBOARDING] ◄───────────────────────── [OFFBOARDING]
                                     │                                          │
                                     ▼                                          ▼
                              [DEACTIVATED] ──────────────────────────► (kết thúc — mọi quyền thu hồi ≤24h)
[ACTIVE] ──(vi phạm / treo review 2 quý)──► [SUSPENDED] ──(review xong / gỡ khóa CEO)──► [ACTIVE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `CREATED` | Onboarding hoàn tất | `PROBATION` | SYS_ADMIN (sau lệnh duyệt) | Hồ sơ nhân sự tồn tại (nối REQ-HR-001); chưa có quyền phê duyệt |
| `PROBATION` | Hết thử việc | `ACTIVE` | HR phát lệnh, SYS_ADMIN thực thi | Ngày hiệu lực theo SCD2 |
| `PROBATION` / `ACTIVE` | Khởi động offboarding | `OFFBOARDING` | HR + SYS_ADMIN | Checklist 24h kích hoạt (nối FEAT-ERP-RBAC-003) |
| `OFFBOARDING` | Thu hồi xong + checklist xác nhận | `DEACTIVATED` | SYS_ADMIN + CTO xác nhận | Toàn bộ vai thu hồi, credentials liên quan rotate |
| `ACTIVE` | Treo (vi phạm / review overdue 2 quý) | `SUSPENDED` | Hệ thống / CEO | Nguyên nhân ghi rõ; quyền phê duyệt đóng băng |
| `SUSPENDED` | Gỡ khóa | `ACTIVE` | CEO (duyệt) | Review hoàn tất hoặc lý do gỡ khóa có phê duyệt |

**Quy tắc:**
- `DEACTIVATED` là trạng thái kết thúc — tài khoản không tái kích hoạt; quay lại làm việc tạo tài khoản mới với lịch sử SCD2 giữ nguyên.
- `SUSPENDED` không mất dữ liệu vai — chỉ đóng băng hiệu lực; khôi phục theo đúng nguyên nhân gỡ.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `user_account` | `id`, `employee_code`, `realm`, `account_state`, `mfa_state`, `sso_id` | FK → `employees.id` | realm = internal/portal; MFA TOTP bắt buộc internal |
| `role_binding` | `id`, `user_id`, `role`, `level`, `data_scope` (C1/C2/C3/T1–T4), `effective_from`, `effective_to` | FK → `user_account.id` | SCD2 — sửa là thêm version mới; nguồn cho access review |
| `sod_conflict_flag` | `id`, `user_id`, `conflict_pair`, `detected_at`, `resolution_state` | FK → `user_account.id` | Sinh tự động khi gán vai; nguồn thống kê SoD |
| `provisioning_order` | `id`, `user_id`, `action`, `requested_by`, `approved_by`, `executed_by`, `state` | FK → `user_account.id` | Chỉ thực thi sau duyệt CEO; log từng lệnh |
| `mfa_enrollment` | `id`, `user_id`, `enrolled_at`, `device_label`, `reset_history` | FK → `user_account.id` | Reset qua quy trình có lý do + log |
| `session_policy` | `data_tier`, `session_ttl`, `refresh_ttl`, `stepup_required` | — | Theo tier dữ liệu truy cập; effective-dated |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ — chi tiết ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn vai ngoài registry | SYS_ADMIN đề xuất gán vai mới tự chế | Submit yêu cầu | Từ chối khi lưu; danh sách vai chỉ hiển thị 18 vai hợp lệ (+ CUSTOMER ở realm portal) | [ ] |
| SC-002: Gán vai thiếu duyệt CEO | Yêu cầu gán vai đã soạn | SYS_ADMIN cố thực thi trực tiếp | CORE từ chối — trạng thái `PENDING_CEO_APPROVAL`; chỉ sinh lệnh thực thi sau duyệt | [ ] |
| SC-003: Thử việc không duyệt được | Tài khoản ở trạng thái `PROBATION` | Người dùng mở luồng phê duyệt bất kỳ | Nút duyệt không xuất hiện; gọi API trực tiếp bị từ chối theo vai × trạng thái | [ ] |
| SC-004: MFA bắt buộc nội bộ | Nhân viên đăng nhập SSO lần đầu, chưa MFA | Vào chức năng nội bộ | Bắt buộc đăng ký MFA TOTP trước; không có đường bỏ qua | [ ] |
| SC-005: Mask dữ liệu Restricted | Vai nghiệp vụ mở hồ sơ có lương/cost | Hiển thị trang | Giá trị lương/cost mask; không có nút hiện giá trị; lượt truy cập meta-log | [ ] |

> **Liên kết:** SC-001/SC-002 → REQ-BOD-011 (18 vai + duyệt CEO); SC-003 → REQ-BOD-011 (lifecycle thử việc); SC-004 → REQ-BOD-011 (MFA TOTP bắt buộc); SC-005 → REQ-BOD-011 (mask theo vai, nối REQ-HR-010).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/rbac-audit/[screen-group].md` |
| Bản counterpart (enforcement + realms) | `.mc-data/docs/phase2-features/core-backend/rbac-audit/`, `.mc-data/docs/phase2-features/portal-web/rbac-audit/`, `.mc-data/docs/phase2-features/mobile-internal/rbac-audit/` |
