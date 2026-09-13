# Tính Năng: Nền Tảng RBAC & SSO/MFA Tập Trung (Cross-Cutting) — Mobile Nội Bộ

> **Dựa trên:** REQ-BOD-011 trong `phase1-business/departments/bod/bod.md` (Phần A — Bổ sung Phase 6d)
> **Phân hệ:** Mobile Nội Bộ BCERP (SYS-MOBILE-INTERNAL)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/mobile-internal/rbac-audit/FEAT-MBI-RBAC-002-impl.md`

> **Hướng dẫn ID:** FEAT-ID khai báo trong registry lane của `/wf-define-features`: REQ-BOD-011 (hệ thống đích SYS-MOBILE-INTERNAL) → FEAT-MBI-RBAC-002. REQ fan-out ở 4 hệ thống; bản CORE (RBAC engine + Keycloak 2 realms) là counterpart trong SYS-CORE-BACKEND; counterparts còn lại: SYS-BCERP-WEB (quản trị vai/hồ sơ/đăng ký MFA) và SYS-PORTAL-WEB (OTP portal khách) — một luồng nghiệp vụ, không nhân bản logic; mobile nội bộ là touchpoint xác thực thiết bị và step-up MFA cho duyệt-on-the-go.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-RBAC-002 |
| Module | MOD-RBAC-AUDIT — RBAC & Audit Log |
| Yêu cầu nghiệp vụ | REQ-BOD-011 (Nền tảng RBAC & SSO/MFA tập trung — cross-cutting) |
| Người dùng liên quan | Toàn bộ 18 vai nội bộ dùng mobile (danh mục chuẩn tại BR-001); CUSTOMER không có trên touchpoint này (chỉ portal/mobile-portal qua realm OTP riêng) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — nền móng cross-cutting; mobile phụ thuộc realm + policy do CORE dựng trước) |
| Phụ thuộc | FEAT-CORE-RBAC-005 (RBAC engine + SSO Keycloak 2 realms tại CORE — nguồn sự thật vai/quyền); MDM; các lane duyệt-on-the-go mobile (FEAT-MBI-RBAC-001) phụ thuộc NGƯỢC vào feature này |
| Ghi chú Expert (A7) | Mục A7 của `bod.md` chưa ghi nhận điều chỉnh Expert nào tại thời điểm viết spec (A7 chờ bước đánh giá chuyên gia); REQ-BOD-011 là bổ sung Phase 6d (resolve SO3-01) — spec bám mục Bổ sung Phase 6d và Phần B (B0) của `bod.md` |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Áp nền tảng RBAC & SSO/MFA tập trung của REQ-BOD-011 lên touchpoint mobile nội bộ: đăng nhập SSO một lần vào realm nội bộ với MFA TOTP bắt buộc, thiết bị MFA cho step-up duyệt-on-the-go, chính sách phiên theo tier dữ liệu, và offline-capable an toàn. Trên mobile, app không tự quyết quyền nào — vai, claim và phạm vi dữ liệu do RBAC engine CORE trả về; mobile chỉ render và thu thập yếu tố xác thực.

**Phạm vi:**
- Bao gồm:
  - Đăng nhập SSO realm nội bộ Keycloak (authorization code flow + PKCE): một lần đăng nhập dùng mọi phân hệ được quyền; mật khẩu không lưu trên thiết bị, token lưu secure storage.
  - Đăng ký/thay đổi thiết bị MFA (enroll TOTP) và step-up bắt buộc cho mọi lệnh duyệt/ký; thiết bị qua MDM, binding 1 user — thiết bị đã duyệt.
  - Chính sách phiên theo tier: T3/T4 → phiên ngắn, ép re-authenticate; thu hồi phiên từ xa khi mất thiết bị hoặc offboarding.
  - Cache offline read-only mã hóa theo tier (TTL, remote wipe MDM); T3/T4 không lên lock-screen/notification.
  - Hồ sơ vai/phạm vi của người dùng dạng read-only — nguồn từ RBAC engine.
  - Ghi audit bất biến mọi sự kiện xác thực trên mobile (đăng nhập, step-up, enroll, thu hồi phiên) kèm nhãn kênh MOBILE.
- Không bao gồm:
  - RBAC engine, mô hình vai × Level × tier, SoD engine, cấu hình Keycloak 2 realms — thuộc SYS-CORE-BACKEND (FEAT-CORE-RBAC-005).
  - Màn hình quản trị vai/phân quyền, hồ sơ user, workspace quarterly access review — thuộc SYS-BCERP-WEB (REQ-BOD-007).
  - OTP cho khách hàng trên portal — touchpoint thuộc SYS-PORTAL-WEB; CUSTOMER không đăng nhập mobile nội bộ.
  - Quản trị credentials vault — cấm trên mobile (REQ-BOD-008); tra cứu audit log nội dung — cấm trên mobile (REQ-BOD-005).
  - Ký quarterly review quyền CFO/CTO qua mobile — thuộc FEAT-MBI-RBAC-001.

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint là **mobile nội bộ** (React Native, offline-capable, MDM): mọi vai nội bộ đăng nhập an toàn, đăng ký thiết bị MFA, và có phiên đủ tin cậy để duyệt-on-the-go, xem dashboard, chấm công/timesheet — phân quyền luôn do CORE quyết định.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Nhân viên (mọi vai nội bộ) | Đăng nhập SSO một lần trên app với MFA TOTP và dùng mọi phân hệ được quyền | Không nhớ nhiều mật khẩu; quyền kiểm soát tập trung như web |
| 2 | Nhân viên (mọi vai nội bộ) | Đăng ký thiết bị của tôi làm MFA device ngay lần đầu kích hoạt app | Chỉ thiết bị duy nhất của tôi nhận challenge step-up khi duyệt |
| 3 | BOD_CEO | Mỗi lệnh duyệt/ký trên mobile yêu cầu step-up MFA tại thời điểm thao tác | Không ai mượn điện thoại mở app rồi duyệt hộ tôi được |
| 4 | BOD_CFO_CTO | Xem hồ sơ vai/phạm vi của mình (vai, ngưỡng duyệt, tier) dạng read-only | Biết hành động nào làm trên mobile, hành động nào phải lên WEB |
| 5 | BOD_CEO | Phiên truy cập dữ liệu T3/T4 ngắn hạn và ép re-authenticate khi hết hạn | Điện thoại thất lạc không đồng nghĩa dữ liệu nhạy cảm bị lộ |
| 6 | Nhân viên (mọi vai nội bộ) | Xem dashboard/timesheet/hàng đợi offline từ cache khi mất mạng | Công việc không dừng khi di chuyển, dữ liệu vẫn mã hóa trên máy |
| 7 | SYS_ADMIN | Khi nhân viên báo mất thiết bị, thu hồi phiên + vô hiệu MFA device sau phê duyệt | Thiết bị mất không đăng nhập được; nhân viên re-enroll nhanh |
| 8 | Hệ thống (offboarding) | Khi nhân viên nghỉ việc, phiên và MFA device trên mobile tự thu hồi ≤24h | Không còn "quyền tồn dư" sau offboarding (nối REQ-BOD-007) |

---

## 3. Quy Tắc Nghiệp Vụ

> *Nguồn sự thật về vai/quyền nằm ở SYS-CORE-BACKEND; mobile không tự quyết phân quyền.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | (Dùng chung lane) RBAC chuẩn hóa 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ cho portal/mobile-portal). KHÔNG tồn tại OPS_CX/FIN_COMPL (DI-006 bị từ chối): CX Head gán OPS_PLAN; Compliance gán FIN_L2 + BOD oversight | App chỉ render 18 vai trong claim; token chứa role/group ngoài registry bị API từ chối + ghi audit |
| BR-002 | (Dùng chung lane) Audit log bất biến append-only hash-chain: mọi thao tác ghi có actor + timestamp + lý do; log tiền WORM ≥10 năm. Trên mobile: mọi sự kiện đăng nhập, step-up (kể cả thất bại), enroll/thay đổi thiết bị, thu hồi phiên đều ghi log nhãn kênh MOBILE | Sự kiện xác thực không vết → cấu hình sai, audit bắt sửa; nỗ lực sửa log thất bại theo engine WORM ở CORE |
| BR-003 | (Dùng chung lane) Quarterly access review bắt buộc (REQ-BOD-007); kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002); vai CFO/CTO thiết kế tách rời. Mobile không có touchpoint review — chu trình quý trên WEB; mobile hiển thị đúng trạng thái quyền bị tự vô hiệu | Lệnh duyệt dùng quyền chưa review 2 quý liên tiếp bị chặn với thông báo "chờ kỳ review" |
| BR-004 | (Dùng chung lane) SSO/MFA tập trung: MFA TOTP bắt buộc mọi tài khoản nội bộ trên mobile; PII nhân sự (lương) Confidential/Restricted — mask/tier áp nguyên vẹn, không hiển thị PII T4 trên lock-screen | Token thiếu claim MFA gọi API nhạy cảm → từ chối; PII render không mask → defect bảo mật mức chặn |
| BR-005 | (Dùng chung lane) Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền — quyền duyệt theo vai × ngưỡng do RBAC engine cấp; mọi lệnh duyệt mobile bắt buộc step-up MFA | Vai không đủ ngưỡng bấm duyệt → CORE từ chối; escalation tự phát alert + push lên cấp duyệt trên |
| BR-006 | Enforcement tập trung: app không tự check quyền cục bộ, không hardcode phân quyền, không nhảy qua Keycloak — mọi quyết định (permission + data tier) do RBAC engine CORE trả qua token claim; app chỉ render theo kết quả check | Endpoint không qua permission check → fail security review; code phân quyền cục bộ cấm merge |
| BR-007 | Đăng nhập mobile dùng authorization code flow + PKCE với realm nội bộ; mật khẩu không lưu trên thiết bị; access/refresh token lưu secure storage (keychain/keystore); refresh token giới hạn theo tier dữ liệu | Jailbreak/root (MDM phát hiện) → chặn đăng nhập; token ngoài secure storage → defect bảo mật mức chặn |
| BR-008 | MFA TOTP bắt buộc mọi tài khoản nội bộ đăng nhập mobile; step-up bắt buộc tại thời điểm mọi lệnh duyệt/ký; thiết bị phải qua MDM và enroll TOTP trước khi nhận challenge; binding 1 user — thiết bị đã duyệt | Thiết bị chưa MDM/MFA → chặn kênh duyệt; thiết bị lạ không nhận challenge; step-up fail quá hạn mức → khóa phiên + alert |
| BR-009 | Chính sách phiên theo tier: T3/T4 → phiên ngắn + ép re-authenticate; cache offline mã hóa TTL theo tier; T4 (cost rate) và PII nhân sự không cache ngoài thiết bị; T3/T4 không lên lock-screen; mất thiết bị → remote wipe MDM + thu hồi phiên từ xa | Cache tier cao hết hạn → tự xóa + log; phiên T3/T4 quá hạn → API tier cao từ chối |
| BR-010 | Lifecycle khớp CORE: tài khoản PROBATION không nhận quyền phê duyệt; offboarding → thu hồi phiên + vô hiệu MFA device ≤24h có checklist (REQ-BOD-007); nghỉ đột xuất chạy offboarding khẩn 24h | Tài khoản PROBATION gọi API duyệt → từ chối; offboarding quá 24h chưa thu hồi phiên → alert đỏ |
| BR-011 | Mất thiết bị: SYS_ADMIN vô hiệu device + thu hồi toàn bộ phiên sau phê duyệt; ép re-enroll trên thiết bị mới; đăng nhập từ thiết bị cũ sau thu hồi thất bại và ghi log bất biến | Thu hồi không có phê duyệt → từ chối; thiết bị cũ vẫn nhận challenge sau thu hồi → sự cố P0, điều tra qua audit |
| BR-012 | Biên touchpoint mobile: không có quản trị Keycloak, quản trị vai, duyệt gán/thu hồi role, quản trị vault, tra cứu audit log nội dung — các thao tác này trên WEB/API; ngoại lệ được phép là lệnh duyệt/ký thuộc lane mobile (ký review tại FEAT-MBI-RBAC-001) | UI/endpoint quản trị không tồn tại trong app; gọi API quản trị từ kênh mobile bị CORE từ chối + log |
| BR-013 | CUSTOMER không đăng nhập mobile nội bộ: realm portal OTP tách biệt, không cấp vai nội bộ, không trao quyền chéo realm. Service account máy-máy (nếu có) dùng account riêng scope giới hạn, rotation định kỳ, có log — không mượn tài khoản cá nhân | Token realm portal dùng cho API mobile nội bộ → từ chối bắt buộc; service account vượt scope → fail security review |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | CUSTOMER |
|-----------|---------|-------------|-----------|----------|
| Đăng nhập SSO realm nội bộ trên mobile (MFA TOTP) | ✅ | ✅ | ✅ | ❌ (realm portal riêng) |
| Đăng ký/thay đổi MFA device của mình | ✅ | ✅ | ✅ | ❌ (OTP chỉ trên portal) |
| Step-up MFA cho lệnh duyệt/ký trên mobile | ✅ | ✅ | ❌ (không có lệnh duyệt) | ❌ |
| Xem hồ sơ vai/phạm vi của mình (read-only) | ✅ | ✅ | ✅ | ❌ |
| Xem dashboard/timesheet/hàng đợi offline theo tier | ✅ (T3/T4 theo vai) | ✅ (T3/T4 theo vai) | ❌ (không xem giá trị T3/T4) | ❌ |
| Vô hiệu MFA device + thu hồi phiên thiết bị mất (sau phê duyệt) | ✅ (phê duyệt khi liên quan BOD) | ✅ (CTO xác nhận checklist) | ✅ (thực thi sau duyệt, log từng bước) | ❌ |
| Duyệt gán/thu hồi vai | ✅ (chỉ trên WEB — REQ-BOD-007) | ❌ | ❌ | ❌ |
| Quản trị cấu hình Keycloak (2 realms) | ❌ | ✅ (chỉ WEB, immutable audit) | ✅ (thực thi sau duyệt trên WEB) | ❌ |
| Quản trị credentials vault | ❌ | ❌ (chỉ WEB console — REQ-BOD-008) | ❌ | ❌ |
| Tra cứu audit log nội dung | ❌ (chỉ WEB) | ❌ (chỉ WEB) | ❌ (cấm trên mobile) | ❌ |
| Truy cập dữ liệu tenant khách | ❌ | ❌ | ❌ | ❌ (kênh riêng SYS-PORTAL-WEB/SYS-MOBILE-PORTAL) |

> Ghi chú: các vai nghiệp vụ (HR, FIN, SALES, OPS) tiêu thụ nền theo claim — đăng nhập, step-up, xem theo tier giống dòng "Nhân viên". CUSTOMER thuộc actors của REQ-BOD-011 ở chiều nền tảng (realm portal) nhưng trên mobile nội bộ mọi hành động đều ❌ — biên này là chủ đích bảo mật.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Một người giữ nhiều vai (thực tế cty nhỏ, ví dụ CFO kiêm CTO):** app hiển thị hợp nhất claim nhiều vai; quyền duyệt theo vai × ngưỡng do engine quyết; xung đột SoD do CORE xử lý theo luồng — mobile không tự chặn hay tự mở nhánh duyệt nào.
- **Nhân viên thử việc:** tài khoản PROBATION đăng nhập được (xem timesheet, thông báo) nhưng role chứa quyền duyệt bị engine loại — nút duyệt không render, API từ chối đến khi chuyển chính thức.
- **Mất mạng kéo dài khi công tác:** offline cache cho dashboard/hàng đợi/timesheet theo tier (mã hóa + TTL); lệnh ghi (duyệt, chấm công bù) không xếp hàng cục bộ — phải online để bảo đảm audit timestamp duy nhất; chỉ xem là offline.
- **Tách vai CFO/CTO sau này:** chỉ tách gán 2 role definition đã tách rời ở CORE; app không đổi — claim và ngưỡng duyệt cập nhật tự theo engine.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Thiết bị MFA trên mobile nội bộ (MFA Device — mobile view của `mfa_device` do CORE sở hữu; enrollment thực hiện trên app, trạng thái nguồn sự thật ở CORE).

**Sơ đồ trạng thái:**
```
[UNENROLLED] ──(MDM hợp lệ + user enroll TOTP)──► [ENROLLED] ──(xác thực TOTP đầu thành công)──► [ACTIVE]
                                                       │                                          │
                                       (không hoàn tất enroll trong hạn)             (báo mất / offboarding / vi phạm MDM)
                                                       ▼                                          ▼
                                                 [EXPIRED_DRAFT] ─────────────────────► [SUSPENDED] ──(phê duyệt thu hồi)──► [REVOKED]
                                                                                                       │
                                                                                             (re-enroll thiết bị mới
                                                                                              sau phê duyệt)
                                                                                                       ▼
                                                                                                  [ENROLLED] (thiết bị mới)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `UNENROLLED` | Bắt đầu enroll TOTP | `ENROLLED` | Người dùng (thiết bị MDM hợp lệ) | Đã đăng nhập SSO; secret chỉ hiển thị 1 lần |
| `ENROLLED` | Xác thực TOTP đầu tiên thành công | `ACTIVE` | Hệ thống | Binding 1 user — thiết bị; ghi audit nhãn MOBILE |
| `ENROLLED` | Không hoàn tất xác thực trong hạn | `EXPIRED_DRAFT` | Hệ thống (tự động) | Draft hết hạn — enroll lại từ đầu |
| `ACTIVE` | Báo mất / offboarding / vi phạm MDM | `SUSPENDED` | SYS_ADMIN (sau phê duyệt theo REQ-BOD-011) | Toàn bộ phiên của thiết bị thu hồi ngay; challenge ngừng phát |
| `SUSPENDED` | Phê duyệt thu hồi chính thức | `REVOKED` | SYS_ADMIN thực thi + checklist (CTO xác nhận khi liên quan BOD) | Ghi audit từng bước; thiết bị không re-activate được |
| `SUSPENDED` | Người dùng có thiết bị mới | Re-enroll → `ENROLLED` | Người dùng + SYS_ADMIN (luồng BR-011) | Thiết bị mới qua MDM; thiết bị cũ giữ `REVOKED` |

**Quy tắc:**
- `REVOKED` và `EXPIRED_DRAFT` không chuyển ngược về trạng thái hoạt động trên cùng thiết bị — thiết bị bị thu hồi chỉ dùng lại được sau phê duyệt và enroll lại từ đầu trên thiết bị mới.
- Chỉ thiết bị `ACTIVE` nhận challenge step-up; mọi chuyển tiếp ghi audit hash-chain kèm nhãn kênh MOBILE.

**Entity phụ:** Phiên mobile (Mobile Session): `ACTIVE → EXPIRED` (hết hạn theo tier, ép re-authenticate + MFA) hoặc `REVOKED` (thu hồi từ xa khi mất thiết bị/offboarding); phiên không tồn tại ngoài thiết bị đã enroll.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Chi tiết DDL đầy đủ tại `database-design.md`; nguồn sự thật tại CORE, mobile giữ bản view/cache.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `mfa_device` (mobile view) | `device_id`, `user_id`, `type` (TOTP), `mdm_compliant`, `status`, `enrolled_at`, `revoked_at` | FK → `user_account` (CORE) | Chỉ `ACTIVE` nhận step-up; mất thiết bị → SUSPENDED → REVOKED sau duyệt |
| `mobile_session` | `session_id`, `device_id`, `user_id`, `max_data_tier`, `started_at`, `expires_at`, `state` | FK → `mfa_device` | Thời hạn theo tier (T3/T4 → ngắn); thu hồi từ xa khi mất thiết bị |
| `user_account` (read-only cache) | `user_id`, `employee_code`, `status`, `realm = INTERNAL` | 1-N → `mfa_device`, `mobile_session` | Nguồn sự thật tại CORE; CUSTOMER chỉ ở realm PORTAL |
| `role_assignment` (read-only cache) | `role_code` (18 vai), `data_tier_max`, `approval_threshold_band`, `status` | FK → `user_account` | Hồ sơ vai read-only; thay đổi do CORE sau phê duyệt CEO |
| `auth_event` (ghi vào `audit_event`) | `event_id`, `actor`, `device_id`, `action` (LOGIN/STEP_UP/ENROLL/REVOKE), `result`, `timestamp`, `channel = MOBILE`, `prev_hash`, `hash` | Ghi bởi mobile backend → engine WORM CORE | Bất biến; step-up thất bại cũng được log |
| `offline_cache_manifest` | `cache_key`, `user_id`, `data_tier`, `encrypted`, `ttl_expires_at`, `wiped_at` | FK → `mobile_session` | T4/PII không cache; TTL theo tier; remote wipe qua MDM cập nhật `wiped_at` |

---

## 8. Acceptance Criteria

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: SSO nội bộ MFA bắt buộc trên mobile | Nhân viên chưa đăng ký MFA, thiết bị ngoài MDM | Đăng nhập app lần đầu | Thiết bị chưa MDM bị chặn kèm hướng dẫn; ép enroll TOTP trước khi vào phân hệ; sau đó một lần đăng nhập dùng mọi phân hệ được quyền | [ ] |
| SC-002: Step-up cho mọi lệnh duyệt | Nhân viên có quyền duyệt, thiết bị ACTIVE | Thực hiện lệnh duyệt/ký | Step-up TOTP bắt buộc tại thời điểm thao tác; fail → nút vô hiệu + log; thiết bị lạ không nhận challenge | [ ] |
| SC-003: Session theo tier | Phiên truy cập dữ liệu T3/T4 | Hết hạn thời gian quy định | Ép re-authenticate + MFA; không giữ phiên tier cao; refresh token theo chính sách tier | [ ] |
| SC-004: PROBATION không có quyền duyệt | Tài khoản ở PROBATION | Đăng nhập và gọi API duyệt | Nút duyệt không render; API từ chối; chuyển ACTIVE mới có quyền theo phê duyệt CEO | [ ] |
| SC-005: Mất thiết bị — thu hồi | Nhân viên báo mất điện thoại ACTIVE | SYS_ADMIN thu hồi sau phê duyệt | Phiên thiết bị thu hồi ngay, device SUSPENDED → REVOKED có checklist; thiết bị cũ đăng nhập thất bại + log; thiết bị mới re-enroll được | [ ] |
| SC-006: Offline cache an toàn theo tier | Nhân viên mở dashboard/timesheet khi mất mạng | Kiểm tra cache trên thiết bị | Cache mã hóa theo tier; T4/PII không có trong cache; hết TTL tự xóa; T3/T4 không lên lock-screen | [ ] |
| SC-007: CUSTOMER không vào được app nội bộ | Token realm portal (khách) | Gọi API mobile nội bộ | Từ chối ở cửa xác thực; không có UI nhập OTP portal; log nỗ lực | [ ] |
| SC-008: Không có chức năng quản trị trên mobile | Bất kỳ vai nào (kể cả BOD_CFO_CTO) | Tìm chức năng quản trị Keycloak/vault/tra cứu log | Không tồn tại UI; API quản trị từ kênh mobile bị CORE từ chối + log | [ ] |
| SC-009: Offboarding thu hồi mobile ≤24h | Nhân viên nghỉ việc | Quá trình thu hồi chạy | Phiên + MFA device thu hồi ≤24h có checklist; quá hạn → alert đỏ; app đăng xuất vĩnh viễn | [ ] |

> **Liên kết:** SC-001→003 map REQ-BOD-011 (SSO/MFA + session theo tier); SC-004→005 map REQ-BOD-011/REQ-BOD-007 (lifecycle + offboarding ≤24h); SC-006→008 map REQ-BOD-011 + REQ-BOD-008/REQ-BOD-005 (biên touchpoint); SC-009 map REQ-BOD-007/REQ-BOD-011 (offboarding checklist).

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (SSO/PKCE, step-up MFA, device enrollment, session revoke) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (Keycloak realm nội bộ, MDM, offline sync, WORM) | `technical-specs/integration-map.md` |
| Màn hình UI (login, enroll MFA, hồ sơ vai — touchpoint mobile) | `phase4-ux/mobile-internal/rbac-audit/[screen-group].md` |
| Touchpoint counterpart | SYS-CORE-BACKEND (FEAT-CORE-RBAC-005), SYS-BCERP-WEB (quản trị vai, đăng ký MFA), SYS-PORTAL-WEB (OTP portal khách) — fan-out cùng REQ-BOD-011 |
