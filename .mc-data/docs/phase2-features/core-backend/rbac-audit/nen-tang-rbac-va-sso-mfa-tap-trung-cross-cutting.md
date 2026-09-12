# Tính Năng: Nền Tảng RBAC & SSO/MFA Tập Trung (Cross-Cutting)

> **Dựa trên:** REQ-BOD-011 trong `phase1-business/departments/bod/bod.md` (Phần A — Bổ sung Phase 6d)
> **Phân hệ:** BCERP Core Backend (SYS-CORE-BACKEND)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/core-backend/rbac-audit/feat-core-rbac-005-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-RBAC-005 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-011 |
| Người dùng liên quan | Toàn bộ 18 vai nội bộ (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS), CUSTOMER (portal khách qua realm OTP) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — nền móng cross-cutting, dependency của TẤT CẢ phân hệ) |
| Phụ thuộc | Không có tính năng phụ thuộc trước (nền móng làm đầu tiên trong module); các feature FEAT-CORE-RBAC-001/002/003/004/006/007 của cùng module và mọi phân hệ khác phụ thuộc NGƯỢC vào feature này |
| Ghi chú Expert (A7) | bod.md Mục A7 chưa ghi điều chỉnh nào sau Expert Review; REQ-BOD-011 là bổ sung Phase 6d (resolve SO3-01 — phân hệ RBAC chưa có REQ sở hữu) — spec bám nguyên văn mục Bổ sung Phase 6d của bod.md |

---

## 1. Mô Tả Tính Năng

**Mục đích:**

Xây dựng điểm kiểm soát truy cập tập trung duy nhất của BCERP: RBAC engine theo mô hình vai × Level × phạm vi dữ liệu 4-tier (C1/C2/C3/T1–T4), SSO Keycloak 2 realms (nội bộ MFA TOTP bắt buộc + portal khách OTP), lifecycle tài khoản nội bộ từ tạo đến offboarding. Mọi API của mọi phân hệ đi qua một điểm check quyền duy nhất — cấm phân hệ nào tự dựng RBAC/SSO riêng lẻ.

**Phạm vi:**

- Bao gồm:
  - RBAC engine tập trung: mô hình vai × Level × data tier; 1 người nhiều vai với phát hiện xung đột SoD và tách luồng duyệt; mọi API check quyền tại 1 điểm duy nhất.
  - SSO Keycloak 2 realms: realm nội bộ (nhân viên, MFA TOTP bắt buộc) + realm portal (khách, OTP); chính sách session/refresh theo tier dữ liệu truy cập.
  - Phân loại dữ liệu toàn cục C1/C2/C3/T1–T4 gắn quyền truy cập; mask/ẩn tự động theo vai ở tầng service.
  - Lifecycle tài khoản nội bộ: tạo → thử việc → chính thức → offboarding (thu hồi + rotate ≤24h có checklist); người thử việc không có quyền phê duyệt.
  - Provisioning/thu hồi vai chỉ thực thi sau phê duyệt CEO (gắn FEAT-CORE-RBAC-003); enforcement tại SYS-CORE-BACKEND.
- Không bao gồm:
  - Màn hình quản trị vai/phân quyền, hồ sơ user, đăng ký MFA trên web — do SYS-BCERP-WEB (counterpart); bản này là API/domain service + cấu hình Keycloak.
  - Luồng OTP chi tiết và reset/tạm khóa tài khoản portal — touchpoint thuộc SYS-PORTAL-WEB; bản này cung cấp realm + policy.
  - Đăng ký/xác thực thiết bị MFA cho duyệt mobile (step-up) — touchpoint thuộc SYS-MOBILE-INTERNAL; bản này định nghĩa claim/policy step-up.
  - Chu kỳ quarterly access review — thuộc FEAT-CORE-RBAC-003; compensating control kiêm nhiệm CFO/CTO — thuộc FEAT-CORE-RBAC-001.
  - Lưu trữ log truy cập — thuộc FEAT-CORE-RBAC-002 (engine ghi audit event vào service đó).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint là **headless API/domain service trên core backend**: authentication đi qua Keycloak, authorization đi qua RBAC engine ở service layer; không client nào (web/mobile/portal) được tin quyết quyền ở phía UI.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Nhân viên (mọi vai nội bộ) | Đăng nhập SSO một lần vào realm nội bộ với MFA TOTP và dùng mọi phân hệ được quyền | Không phải nhớ nhiều mật khẩu, và quyền của tôi được kiểm soát tập trung nhất quán |
| 2 | BOD_CEO | Mọi lệnh gán/thu hồi vai chỉ có hiệu lực sau chữ ký của tôi | Không ai tự cấp quyền cho mình hay người khác — kể cả SYS_ADMIN |
| 3 | BOD_CFO_CTO (CTO/Super Admin) | Quản trị Keycloak 2 realms với mọi thao tác quản trị ghi immutable audit | Kiểm soát hạ tầng xác thực đúng vai CTO mà vẫn chịu giám sát |
| 4 | SYS_ADMIN | Thực thi provisioning/thu hồi tài khoản sau phê duyệt qua API, mỗi bước có log | Thao tác rõ căn cứ, không tự quyết thẩm quyền |
| 5 | CUSTOMER (khách trên portal) | Đăng nhập realm portal bằng OTP trên dữ liệu tenant của mình | Truy cập an toàn chỉ thấy dữ liệu của mình (tenant isolation) mà không cần tài khoản nội bộ |
| 6 | Hệ thống (mọi phân hệ) | Gọi một API check quyền duy nhất (permission + data tier) trước khi xử lý bất kỳ yêu cầu nào | Không phân hệ nào phải (hoặc được) tự check quyền cục bộ — một nguồn sự thật về quyền |
| 7 | Hệ thống (SoD engine) | Phát hiện 1 người nhiều vai tạo xung đột duyệt cùng luồng và tự tách theo luồng | Kiểm soát nguyên tắc người đề xuất ≠ người duyệt ngay ở tầng nền |
| 8 | HR_L2 | Khi nhân viên thử việc, tài khoản mới không có quyền phê duyệt; khi offboarding, quyền tự thu hồi trong 24h | Quyền luôn khớp trạng thái hợp đồng lao động, không để quyền "tồn dư" |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | (Dùng chung lane) RBAC chuẩn hóa 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ portal/mobile-portal). KHÔNG tồn tại OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight | Tạo/đề xuất vai ngoài 18 vai bị từ chối; cấu hình Keycloak nhóm ngoài registry bị audit cấu hình đánh lỗi |
| BR-002 | (Dùng chung lane) Audit log bất biến hash-chain ≥10 năm WORM với log tiền; mọi thao tác ghi có actor + timestamp + lý do — mọi sự kiện đăng nhập, xác thực MFA, check quyền bất thường, provisioning đều ghi log | Sự kiện đăng nhập/thay đổi quyền không vết → cấu hình sai, audit bắt sửa; nỗ lực sửa log thất bại theo FEAT-CORE-RBAC-002 |
| BR-003 | (Dùng chung lane) Quarterly access review bắt buộc (FEAT-CORE-RBAC-003); compensating control kiêm nhiệm CFO/CTO (FEAT-CORE-RBAC-001) — vai CFO/CTO thiết kế tách rời; SoD engine tách xung đột duyệt theo luồng | Người nhiều vai xung đột không được dùng vai thứ hai để duyệt chính luồng mình đề xuất — chặn ở engine |
| BR-004 | (Dùng chung lane) SSO/MFA tập trung (chính là tính năng này): MFA TOTP bắt buộc mọi tài khoản nội bộ, OTP cho portal khách; PII nhân sự (lương) Confidential/Restricted — RBAC tier Restricted, mask tự động | Phiên thiếu claim MFA gọi API nhạy cảm → từ chối 401/403; dữ liệu PII trả không mask → defect bảo mật mức chặn |
| BR-005 | (Dùng chung lane) Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền — quyền phê duyệt tài chính là quyền do RBAC engine cấp theo vai × ngưỡng | API duyệt với vai không đủ ngưỡng bị từ chối; escalation tự động phát sự kiện alert |
| BR-006 | Enforcement tập trung: mọi API của mọi phân hệ đi qua 1 điểm check quyền duy nhất trên SYS-CORE-BACKEND — cấm phân hệ nào tự check quyền cục bộ, cấm nhảy qua gateway xác thực | Bất kỳ endpoint nào không qua permission check → fail security review; code check quyền trùng lặp cấm merge |
| BR-007 | Gán/thu hồi vai chỉ thực thi sau phê duyệt CEO (nối FEAT-CORE-RBAC-003); SYS_ADMIN chỉ thực thi provisioning, không tự gán kể cả cho chính mình | Lệnh provisioning thiếu tham chiếu phê duyệt CEO bị engine từ chối thực thi |
| BR-008 | SSO Keycloak 2 realms tách biệt: realm nội bộ (nhân viên — MFA TOTP bắt buộc, nhóm map 18 vai) và realm portal (khách — OTP); không chung tài khoản chéo realm; chính sách session/refresh theo tier dữ liệu (tier cao → session ngắn, refresh giới hạn) | Tài khoản portal không được nhận role nội bộ bằng mọi cách; session tier T3/T4 quá hạn quy định bị ép re-authenticate |
| BR-009 | Phân loại dữ liệu toàn cục C1/C2/C3 + T1–T4 gắn trên mọi resource; API trả dữ liệu tự mask/ẩn theo vai ở service layer (nối REQ-FIN-017 cho biên portal); CUSTOMER trên portal chỉ truy cập view tổng hợp đã lọc tenant (RLS DB + filter API 2 lớp) | Dữ liệu tier cao trả về cho vai không đủ → chặn ở service; portal thấy dữ liệu tenant khác → sự cố P0, breach flow 72h |
| BR-010 | Lifecycle tài khoản nội bộ: `CREATED → PROBATION → ACTIVE → OFFBOARDING → DEACTIVATED`; người thử việc KHÔNG có quyền phê duyệt; offboarding thu hồi quyền + rotate credentials liên quan ≤24h có checklist (nối FEAT-CORE-RBAC-003) | Gán quyền duyệt cho tài khoản PROBATION bị chặn; offboarding quá 24h → alert đỏ |
| BR-011 | MFA TOTP bắt buộc cho mọi tài khoản quản trị (BOD, SYS_ADMIN) và mọi lệnh duyệt tiền; step-up MFA bắt buộc trên mobile-internal cho lệnh duyệt; đăng ký MFA device có audit log | Lệnh duyệt từ phiên không có MFA step-up bị từ chối; thiết bị chưa đăng ký không nhận step-up |
| BR-012 | Không phân hệ nào dựng RBAC/SSO riêng lẻ: FEAT-CORE-RBAC-003 (access review), FEAT-CORE-RBAC-007 (WORM), FEAT-CORE-RBAC-006 (PII) và các REQ MFA điểm chức năng giữ scope riêng nhưng tham chiếu nền tảng này | Thiết kế phân hệ có cơ chế xác thực/phân quyền riêng → kiến trúc chặn, phải tái dùng engine |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | CUSTOMER (portal) |
|-----------|---------|-------------|-----------|-------------------|
| Đăng nhập SSO realm nội bộ (MFA TOTP) | ✅ | ✅ | ✅ | ❌ (realm riêng) |
| Đăng nhập realm portal (OTP) | ❌ | ❌ | ❌ | ✅ |
| Duyệt gán/thu hồi vai | ✅ (duy nhất, nối FEAT-CORE-RBAC-003) | ❌ | ❌ | ❌ |
| Quản trị cấu hình Keycloak (2 realms) | ❌ | ✅ (vai CTO, immutable audit) | ✅ (thực thi sau duyệt) | ❌ |
| Thực thi provisioning/thu hồi tài khoản | ❌ | ❌ | ✅ (sau phê duyệt, log từng bước) | ❌ |
| Cấu hình chính sách session/refresh theo tier | ✅ (duyệt) | ✅ (đề xuất/vận hành theo change) | ✅ (áp sau duyệt) | ❌ |
| Đăng ký/thay đổi MFA device của mình | ✅ | ✅ | ✅ | ❌ (OTP do hệ thống phát) |
| Check quyền API (permission + data tier) | ✅ (đối với mọi phân hệ qua engine) | ✅ | ✅ | ✅ (chỉ view tenant đã lọc) |
| Xem/xóa log truy cập của chính mình | ❌ | ❌ | ❌ | ❌ (log bất biến — không interface xóa) |

**Ghi chú phân quyền:** bảng dùng đúng vai registry; các vai nghiệp vụ còn lại (HR, FIN, SALES, OPS) là người tiêu thụ engine theo claim; CUSTOMER không bao giờ có role nội bộ (BR-008).

---

## 5. Trường Hợp Đặc Biệt

- **Một người giữ nhiều vai (thực tế cty nhỏ, ví dụ CFO kiêm CTO):** engine hỗ trợ nhiều role trên một user; SoD engine phát hiện cặp vai xung đột cùng luồng và tách theo luồng — giao dịch do vai này khởi tạo phải do vai khác của người khác duyệt (chính là compensating control FEAT-CORE-RBAC-001); chặn ở cấp luồng cụ thể, không chặn vô lý ở cấp "có 2 vai".
- **Nhân viên thử việc:** tài khoản ở trạng thái PROBATION — mọi role chứa quyền phê duyệt bị engine loại bỏ tự động cho đến khi chuyển OFFICIAL (sự kiện HR).
- **Tách vai CFO/CTO trong tương lai:** chỉ tách gán 2 role definition đã thiết kế tách rời — realm, engine, luồng không đổi; không tồn tại "super role" gộp.
- **Khách quên/không nhận được OTP portal:** tạm khóa/reset qua API có audit log (touchpoint reset thuộc SYS-PORTAL-WEB); SYS_ADMIN không bao giờ xem hoặc đặt hộ OTP.
- **Thiết bị MFA mất:** người dùng báo mất → SYS_ADMIN vô hiệu device đăng ký sau phê duyệt, ép re-enroll MFA; mọi đăng nhập từ device cũ thất bại và ghi log bất biến.
- **Portal khách multi-tenant:** CUSTOMER chỉ truy cập qua 2 lớp bảo vệ (RLS DB + filter API); vi phạm tenant isolation phát hiện trong test tự động → chặn release.
- **Service account máy-máy (GW gọi API nội bộ):** dùng service account riêng trong realm nội bộ với scope giới hạn, rotation secret theo chu kỳ và có log — không mượn tài khoản cá nhân.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Tài khoản nội bộ (Internal User Account)

**Sơ đồ trạng thái:**
```
[CREATED] ──(ngày thử việc đầu)──► [PROBATION] ──(đạt thử việc / HR xác nhận)──► [ACTIVE] ──(sự kiện offboarding)──► [OFFBOARDING] ──(revoke + rotate ≤24h + checklist)──► [DEACTIVATED]
                                       │                                              │
                                (không đạt thử việc)                     (tạm ngưng: nghỉ không lương, điều tra)
                                       ▼                                              ▼
                                 [DEACTIVATED]                                  [SUSPENDED] ──(hết lý do)──► [ACTIVE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `CREATED` | Kích hoạt thử việc | `PROBATION` | SYS_ADMIN (sau duyệt CEO theo FEAT-CORE-RBAC-003) | Đủ hồ sơ HR; role gán không chứa quyền phê duyệt |
| `PROBATION` | HR xác nhận chính thức | `ACTIVE` | HR_L2 (sự kiện HR), SYS_ADMIN đồng bộ | Role đầy đủ theo phê duyệt CEO |
| `PROBATION` | Không đạt thử việc | `DEACTIVATED` | HR_L2 → SYS_ADMIN thực thi | Offboarding đầy đủ ≤24h + rotate |
| `ACTIVE` | Sự kiện offboarding | `OFFBOARDING` | HR_L2 phát, hệ thống kích hoạt | Checklist thu hồi khởi tạo; yêu cầu thu hồi TKQC gửi OPS |
| `OFFBOARDING` | Hoàn tất revoke + rotate | `DEACTIVATED` | SYS_ADMIN thực thi | ≤24h; checklist CTO xác nhận; log từng bước |
| `ACTIVE` | Tạm ngưng | `SUSPENDED` | BOD_CEO duyệt | Lý do rõ (nghỉ không lương, điều tra); toàn phiên hiện hữu bị thu hồi |

**Quy tắc:** `DEACTIVATED` là trạng thái kết thúc — tái tuyển dùng tài khoản mới (dữ liệu cũ retention theo REQ-HR-010); `SUSPENDED` có thể quay lại `ACTIVE` sau phê duyệt. Mọi chuyển tiếp ghi audit log hash-chain.

**Entity phụ:** Role Assignment: `PROPOSED → CEO_APPROVED → ACTIVE → REVOKED/AUTO_DISABLED` (chi tiết tại FEAT-CORE-RBAC-003).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `user_account` | `user_id`, `employee_code`, `realm` (`INTERNAL`/`PORTAL`), `status`, `keycloak_subject`, `mfa_enrolled` | 1-N → `role_assignment` | Nguồn sự thật lifecycle; CUSTOMER chỉ ở realm PORTAL |
| `role_definition` | `role_code` (18 vai), `permissions`, `data_tier_max`, `approval_threshold_band` | N-N → `user_account` qua `role_assignment` | CFO/CTO là 2 role tách rời; không có super role gộp |
| `role_assignment` | `assignment_id`, `user_id`, `role_code`, `status`, `ceo_approved_at`, `revoked_at` | FK → `user_account`, `role_definition` | Chỉ ACTIVE sau chữ ký CEO (nối FEAT-CORE-RBAC-003) |
| `data_classification` | `resource_ref`, `class` (C1/C2/C3), `tier` (T1–T4) | Gắn trên mọi resource | Nguồn cho mask tự động theo vai (BR-009) |
| `sod_conflict_rule` | `rule_code`, `conflict_role_pair`, `flow_scope` | Tham chiếu `role_definition` | Engine tách xung đột theo luồng (nối FEAT-CORE-RBAC-001) |
| `mfa_device` | `device_id`, `user_id`, `type` (TOTP), `enrolled_at`, `revoked_at` | FK → `user_account` | Bắt buộc nội bộ; mất device → revoke sau duyệt + re-enroll |
| `audit_event` | (như FEAT-CORE-RBAC-002) | Ghi mọi sự kiện xác thực/provisioning | Đăng nhập, MFA, check quyền bất thường đều log |

---

## 8. Acceptance Criteria

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: SSO nội bộ MFA bắt buộc | Nhân viên nội bộ chưa đăng ký MFA | Đăng nhập realm nội bộ | Ép enroll TOTP trước khi vào phân hệ; sau đó 1 lần đăng nhập dùng mọi phân hệ được quyền | [ ] |
| SC-002: Portal khách OTP tenant-isolated | CUSTOMER đăng nhập realm portal | Truy cập API portal | Chỉ thấy view tổng hợp tenant của mình (RLS + filter 2 lớp); không nhận được role nội bộ bằng mọi cách | [ ] |
| SC-003: Một điểm check quyền duy nhất | Audit kiến trúc quét mọi endpoint | Endpoint không qua permission check | Đánh dấu fail — bắt buộc sửa trước merge; không phân hệ nào có code check quyền cục bộ | [ ] |
| SC-004: Gán vai qua chữ ký CEO | SYS_ADMIN nhận yêu cầu gán role | Thực thi không có tham chiếu phê duyệt CEO | Engine từ chối; có phê duyệt → role ACTIVE và log đầy đủ | [ ] |
| SC-005: SoD tách theo luồng | Một user có 2 vai xung đột cùng luồng | User tự duyệt giao dịch mình đề xuất | Engine chặn; yêu cầu người khác ở vai đủ điều kiện duyệt; thử vi phạm ghi log | [ ] |
| SC-006: Thử việc không có quyền duyệt | Tài khoản ở PROBATION | Gọi API duyệt bất kỳ | Từ chối — role PROBATION không chứa quyền duyệt; chuyển OFFICIAL mới có | [ ] |
| SC-007: Offboarding ≤24h | Nhân viên nghỉ việc | Sự kiện offboarding phát | Revoke toàn bộ quyền + rotate credentials ≤24h, checklist CTO xác nhận; quá hạn → alert đỏ; phiên hiện hữu thu hồi ngay | [ ] |
| SC-008: Mask theo data tier | Resource tier T4 (cost rate cá nhân) | Vai không đủ tier gọi API | Giá trị masked ở service layer; vai đủ tier thấy đủ + meta-log | [ ] |
| SC-009: Session theo tier | Phiên truy cập dữ liệu T3/T4 | Hết hạn thời gian ngắn quy định | Ép re-authenticate + MFA; không giữ phiên tier cao | [ ] |

> **Liên kết:** SC-001→002 map REQ-BOD-011 (SSO 2 realms); SC-003→004 map REQ-BOD-011 (enforcement + duyệt CEO); SC-005 map REQ-BOD-011/REQ-BOD-002 (SoD); SC-006→007 map REQ-BOD-011 (lifecycle); SC-008→009 map REQ-BOD-011 + REQ-HR-010/REQ-FIN-017 (data tier + session).

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (permission check, provisioning, realm config, MFA) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (Keycloak 2 realms, sự kiện HR, tenant isolation portal) | `technical-specs/integration-map.md` |
| Màn hình UI (quản trị vai, hồ sơ user, đăng ký MFA — counterpart WEB; OTP — PORTAL) | `phase4-ux/core-backend/rbac-audit/[screen-group].md` |
| Touchpoint counterpart | SYS-BCERP-WEB, SYS-PORTAL-WEB, SYS-MOBILE-INTERNAL (fan-out cùng REQ-BOD-011) |
