# Tính Năng: Quản trị Integration Gateway & credentials vault (vai CTO)

> **Dựa trên:** REQ-BOD-008 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** Nền tảng Core Backend — cấu hình & tích hợp (SYS-CORE-BACKEND)
> **Module:** Quản trị Cấu hình & Integration Gateway (MOD-SETTINGS-GW)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/settings-gw/*.md`, `phase5-implementation/tasks/core-backend/settings-gw/feat-core-stgw-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc:
> `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`
> Tra `req-registry.json` để xác nhận SYS và MOD tương ứng.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-STGW-001 |
| Module | MOD-SETTINGS-GW |
| Yêu cầu nghiệp vụ | REQ-BOD-008 |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO (CTO/Super Admin), SYS_ADMIN |
| Độ ưu tiên | Cao (HIGH · MVP — phân hệ GĐ1) |
| Giai đoạn | Giai đoạn 1 |
| Phụ thuộc | Nền tảng RBAC & SSO/MFA tập trung (REQ-BOD-011 — MFA TOTP và RBAC engine); audit log WORM (REQ-FIN-012); REQ-BOD-007 (access review dùng inventory credentials) |
| Ghi chú Expert (A7) | A7 của `bod.md` đang chờ expert ký xác nhận — chưa có điều chỉnh chính thức; bối cảnh A7 `finance.md`: REQ-FIN-005 phụ thuộc tiến trình Business Verification API 7 nền tảng, ảnh hưởng trực tiếp đến degraded mode trong spec này |

**Fan-out REQ-BOD-008:** REQ xuất hiện ở 3 systems (SYS-INTEGRATION-GW, SYS-CORE-BACKEND, SYS-BCERP-WEB). Bản này là bản riêng cho **SYS-CORE-BACKEND** (headless API/domain services): mọi business rule được enforce ở tầng service — không tin UI; audit log + tenant isolation bắt buộc. Counterparts: SYS-INTEGRATION-GW (vault mã hóa, scheduler sync, adapter), SYS-BCERP-WEB (console quản trị).

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp tầng domain service trên core backend để quản trị tập trung mọi kết nối ngoại vi của BCERP: connection profile, vòng đời credentials trong vault mã hóa, sức khỏe adapter và sync scheduler — giúp vai CTO kiểm soát tài sản "chìa khóa truy cập" của 2.600+ TKQC active trên 7 nền tảng. Bảo đảm không credentials nào rời vault dạng plaintext; mọi thao tác quản trị qua change control và ghi immutable audit log.

**Phạm vi:**
- Bao gồm:
  - Service connection profile cho TẤT CẢ kết nối ngoại vi theo DI-004 (12/09): 7 nền tảng QC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) và connector phần mềm kế toán VAS (REQ-FIN-013) — vendor-agnostic, cấu hình một nơi duy nhất.
  - Service credentials vault phía core backend: CRUD có kiểm soát, tham chiếu mã hóa, rotate ≥90 ngày, thu hồi khẩn revoke + rotate ≤24h.
  - API sức khỏe 7 adapter (ok/fail/degraded + tuổi dữ liệu từng nguồn); job queue + monitoring sync nhận sự kiện từ GW.
  - Service tham số quản trị (ngưỡng, tier, SLA) — version + audit, chỉ ADMIN/BOD sửa.
  - Enforcement tầng service: MFA TOTP cho tài khoản quản trị vault, tenant isolation, audit mọi thao tác.
- Không bao gồm:
  - Vault mã hóa vật lý, adapter gọi API nền tảng, scheduler pull hourly — thuộc SYS-INTEGRATION-GW.
  - Console UI quản trị credentials — thuộc SYS-BCERP-WEB; core backend chỉ cung cấp headless API.
  - Đối trừ 3 số, ticket discrepancy, màn import/nhập tay của FIN_L1 — thuộc REQ-FIN-004/REQ-FIN-005 (FEAT-CORE-STGW-002).
  - RBAC engine chung — thuộc REQ-BOD-011; tính năng này chỉ tiêu thụ.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CFO_CTO (CTO) | Quản trị vòng đời connection profile + credentials (thêm/sửa/rotate/thu hồi) qua headless API với MFA TOTP | Kiểm soát tập trung toàn bộ "chìa khóa" truy cập 7 nền tảng QC và phần mềm kế toán VAS tại một module, không phụ thuộc vendor |
| 2 | BOD_CFO_CTO (CTO) | Xem sức khỏe realtime 7 adapter (ok/fail/degraded) và tuổi dữ liệu từng nguồn | Phát hiện sớm nguồn dữ liệu ôi, điều phối backfill trước khi ảnh hưởng đối soát |
| 3 | BOD_CFO_CTO (CTO) | Duyệt hoặc từ chối change request kỹ thuật do SYS_ADMIN đề xuất | Giữ quyền quyết cuối trên mọi thay đổi vault dù việc thực thi được ủy cho SYS_ADMIN |
| 4 | SYS_ADMIN | Thực thi change đã được CTO duyệt qua API (không thấy plaintext) | Cấu hình/provisioning đúng thẩm quyền, không chịu trách nhiệm cho quyết định không thuộc mình |
| 5 | SYS_ADMIN | Theo dõi hạn rotate của từng credential, nhận cảnh báo trước khi quá hạn 90 ngày | Chủ động lên lịch rotate, tránh sync đứt đột ngột do token hết hạn |
| 6 | BOD_CEO | Xem báo cáo trạng thái kết nối ngoại vi, số lần thu hồi khẩn và audit trail quý | Thực hiện compensating control cho kiêm nhiệm CFO kiêm CTO và quarterly access review (REQ-BOD-007, REQ-BOD-002) |
| 7 | Hệ thống (job service) | Tự khóa sync của kết nối mất quyền API, chuyển degraded mode "manual" kèm nhãn nguồn | Dòng dữ liệu đối soát không đứt khi Business Verification chưa cấp (DI-007) và tự backfill khi được cấp lại |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code (enforce ở tầng service của SYS-CORE-BACKEND, không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 ngày 12/09):** mọi kết nối ngoài (7 nền tảng QC + phần mềm kế toán VAS) phải đăng ký dưới dạng connection profile tại MOD-SETTINGS-GW gồm connection profile, credentials vault, field mapping và import/export template — vendor-agnostic, KHÔNG hardcode tên phần mềm; tên vendor cụ thể sẽ cấu hình khi triển khai | Service chặn kết nối không đi qua connection profile; mã hóa vendor hardcode bị chặn ở review kiến trúc — connector VAS của REQ-FIN-013 khai báo như 1 profile trong registry này |
| BR-002 | **API 7 nền tảng QC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex):** mỗi nền tảng 1 credentials record trong vault + 1 sync scheduler config; service chỉ cấp tham chiếu credential cho GW khi profile `ACTIVE`, không trả secret về UI/API | Sync không có credential hợp lệ bị từ chối tại service layer; response lộ secret bị middleware chặn + ghi audit vi phạm |
| BR-003 | **Degraded mode "manual" + backfill (DI-007):** mọi integration phải có chế độ suy giảm "manual" khi mất quyền API (Business Verification 7 nền tảng chưa có quyền developer); khi mất quyền, service chuyển profile sang `DEGRADED`, gắn nhãn nguồn "manual" và lập backfill task tự động khi quyền được cấp; chênh lệch manual vs API >±0,1% đưa vào báo cáo đối soát | Dữ liệu thiếu nhãn nguồn không vào pipeline đối soát; cấp quyền mà không kích hoạt backfill bị cảnh báo; sai khác >±0,1% buộc phát sinh ticket đối soát |
| BR-004 | **Cấu hình chính sách/tham số quản trị (ngưỡng, tier, SLA):** chỉ ADMIN (SYS_ADMIN thực thi sau phê duyệt) và BOD (phê duyệt) được sửa; tham số bắt buộc effective-dated + version + người duyệt; không sửa hồi tố giá trị đã phát hiệu lực; mọi thay đổi trace về audit log | Service chặn WRITE từ vai khác; ghi thiếu version/ngày hiệu lực bị chặn; yêu cầu sửa giá trị quá khứ bị từ chối + log nỗ lực |
| BR-005 | MFA TOTP bắt buộc cho mọi tài khoản quản trị vault (BR-BOD-008.1) | API quản trị vault từ chối phiên không có step-up MFA hợp lệ; trả 403 + ghi audit |
| BR-006 | Credentials chỉ tồn tại trong vault mã hóa — không plaintext ở bất kỳ UI/API nào; SYS_ADMIN thao tác qua tham chiếu; hành vi quản trị vault KHÔNG ủy quyền (delegate) | API chứa secret bị chặn cứng; yêu cầu ủy quyền hành vi vault bị từ chối ngay tại service |
| BR-007 | Vòng đời credential: rotate định kỳ ≥90 ngày; thu hồi khẩn revoke + rotate ≤24h khi nghi ngờ rò rỉ hoặc liên quan nghỉ việc (nối offboarding REQ-BOD-007) | Credential quá hạn rotate đưa profile sang cảnh báo `GRACE`; sync của credential đã revoke bị chặn tức thì |
| BR-008 | Immutable audit log cho mọi thao tác vault và mọi lần gọi API nền tảng (hash-chain WORM ≥10 năm — REQ-FIN-012); không ai, kể cả Super Admin, xóa/sửa log của chính mình | Nỗ lực sửa/xóa audit log bị chặn ở tầng dữ liệu append-only + phát alert cho BOD_CEO (REQ-BOD-002) |
| BR-009 | MOBILE cấm toàn bộ thao tác vault (BR-BOD-008.2) — enforcement ở service layer: API quản trị vault chỉ nhận request từ kênh web nội bộ hợp lệ, không tin client tự khai báo; mobile chỉ nhận alert sức khỏe adapter (REQ-BOD-006) | Request quản trị vault từ mobile bị từ chối + log; chỉ alert sức khỏe được phát ra kênh mobile |
| BR-010 | SYS_ADMIN chỉ thực thi thay đổi vault/change kỹ thuật SAU khi CTO duyệt (change management); không tự gán quyền kể cả cho chính mình | Change chưa `APPROVED` không thể thực thi; nỗ lực thực thi trước duyệt bị chặn + log |
| BR-011 | Tenant isolation: connection profile gắn tenant (khách) hoặc phạm vi công ty; mọi truy vấn service lọc bắt buộc theo tenant context của phiên | Truy vấn chéo tenant trả rỗng + log vi phạm; không có endpoint đọc "tất cả tenant" cho vai không đủ quyền |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO (CTO) | SYS_ADMIN | FIN/OPS/SALES/HR | CUSTOMER (portal) |
|-----------|---------|-------------------|-----------|------------------|-------------------|
| Xem sức khỏe adapter & tuổi dữ liệu | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xem danh sách connection profile (không có secret) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xem giá trị credentials (plaintext) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Tạo/sửa connection profile | ❌ | ✅ (duyệt + trực tiếp) | ✅ (theo change đã duyệt) | ❌ | ❌ |
| Rotate credentials | ❌ | ✅ | ✅ (theo change đã duyệt) | ❌ | ❌ |
| Thu hồi khẩn (revoke) | ❌ | ✅ | ❌ (chỉ CTO) | ❌ | ❌ |
| Duyệt/từ chối change request kỹ thuật | ❌ | ✅ | ❌ | ❌ | ❌ |
| Sửa tham số quản trị (ngưỡng, tier, SLA) | ✅ (phê duyệt) | ✅ | ✅ (thực thi sau duyệt) | ❌ | ❌ |
| Xem audit log vault | ✅ (giám sát độc lập) | ✅ | ✅ (phần mình thực thi) | ❌ | ❌ |
| Xóa/sửa audit log | ❌ | ❌ | ❌ | ❌ | ❌ |
| Ủy quyền hành vi vault cho người khác | ❌ | ❌ (không ủy được) | ❌ | ❌ | ❌ |

> Ghi chú: mọi hành động ghi audit log bất biến kèm danh tính + timestamp + reason code; BOD_CEO không thao tác trực tiếp vault nhưng giữ quyền giám sát độc lập (compensating control REQ-BOD-002).

---

## 5. Trường Hợp Đặc Biệt

- **Chưa có quyền API developer (DI-007 đang theo dõi):** cả 7 adapter vận hành degraded mode "manual" — service vẫn cấp đủ import template + nhãn nguồn để FIN_L1 nhập liệu có cấu trúc; khi Business Verification được cấp, service tự lập backfill task cho các kỳ đã nhập tay.
- **CTO nghi ngờ rò rỉ credentials hoặc nhân sự liên quan nghỉ việc:** thu hồi khẩn không ủy quyền — revoke + rotate ≤24h; nếu đồng thời có offboarding, revoke ưu tiên trước khi hoàn tất checklist offboarding 24h (REQ-BOD-007).
- **Connector VAS chưa chốt tên vendor (DI-004 nửa còn mở):** connection profile thiết kế trống vendor, chỉ điền field mapping + import/export template khi triển khai — không chặn thiết kế hay lập trình.
- **SYS_ADMIN vắng:** dịch vụ thiết kế cho 1–2 SYS_ADMIN; nếu cả hai vắng, CTO trực tiếp thao tác (không ngược lại — SYS_ADMIN không tự thao tác khi chưa có change duyệt).
- **Cần kết nối ngoại vi mới ngoài 7 nền tảng + VAS (ví dụ CMS/TMS/AI Agent thuộc phạm vi "tương lai" chưa chốt `[KXN-9]`):** registry chấp nhận thêm profile mới theo quy trình change; phạm vi hệ thống nào được kết nối là quyết định kinh doanh chờ xác nhận — spec không tự quyết, chỉ bảo đảm mở rộng không cần sửa code lõi.
- **Super Admin thao tác trên vault:** audit log không thể xóa bởi chính Super Admin; BOD_CEO nhận báo cáo quý toàn bộ hành vi vault của CFO/CTO để ký review (REQ-BOD-002.4).

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Connection Profile (kết nối ngoại vi, bao gồm cả connector VAS)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit change)──► [PENDING_APPROVAL] ──(CTO approve)──► [ACTIVE] ──(mất quyền API)──► [DEGRADED]
                                      │                              │  ▲                          │
                                      │ (CTO reject)                 │  └──(backfill xong/        │ (được cấp lại API
                                      ▼                              │      quyền cấp lại)────────┘  → backfill tự động)
                                  [REJECTED]                         ├──(tạm dừng định kỳ)──► [SUSPENDED]
                                                                     └──(nghi ngờ rò rỉ/offboarding)──► [REVOKED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit change | `PENDING_APPROVAL` | SYS_ADMIN | Profile đủ connection info, field mapping, không chứa secret plaintext |
| `PENDING_APPROVAL` | Approve | `ACTIVE` | BOD_CFO_CTO (CTO) | Credentials đã nạp vault + MFA phiên hợp lệ; scheduler config hoàn chỉnh |
| `PENDING_APPROVAL` | Reject | `REJECTED` | BOD_CFO_CTO (CTO) | Bắt buộc nhập lý do từ chối (reason code) |
| `ACTIVE` | Mất quyền API / lỗi kéo dài | `DEGRADED` | Hệ thống (tự động) | Gắn nhãn nguồn "manual"; lập kế hoạch backfill khi khôi phục |
| `DEGRADED` | Được cấp quyền API | `ACTIVE` | Hệ thống (tự động) + xác nhận CTO | Backfill task đã tạo cho các kỳ nhập tay; chênh lệch >±0,1% đẩy vào báo cáo đối soát |
| `ACTIVE` | Tạm dừng (nhà cung cấp bảo trì, tạm ngưng dịch vụ) | `SUSPENDED` | BOD_CFO_CTO | Ghi lý do + thời hạn dự kiến |
| `SUSPENDED` | Kích hoạt lại | `ACTIVE` | BOD_CFO_CTO | Kiểm tra credential còn hạn rotate |
| `ACTIVE`/`SUSPENDED`/`DEGRADED` | Thu hồi khẩn (revoke) | `REVOKED` | BOD_CFO_CTO (không ủy quyền) | Nghi ngờ rò rỉ hoặc liên quan nghỉ việc; sync bị chặn tức thì |
| `REVOKED` | Rotate + tái cấp | `ACTIVE` | BOD_CFO_CTO → SYS_ADMIN thực thi | Credential mới đã vào vault; hoàn tất trong ≤24h kể từ revoke khẩn |

**Quy tắc:**
- `REVOKED` và `REJECTED` là trạng thái kết thúc — không quay trực tiếp về `ACTIVE`; phải tạo vòng đời credential/profile mới.
- Không quay về trạng thái trước tùy ý; mọi chuyển trạng thái ghi audit log bất biến (ai, khi nào, từ/đến trạng thái nào, reason code).
- Ở `DEGRADED`, scheduler vẫn chạy mức được phép nhưng dữ liệu phát sinh luôn mang nhãn "manual" (BR-003).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `connection_profile` | `code`, `name`, `vendor_type` (platform/vas), `tenant_id`, `base_url`, `status`, `scheduler_config`, `field_mapping` | FK → `tenants.id`; 1–N `credential` | Vendor-agnostic; không có cột tên vendor hardcode |
| `credential` | `profile_id`, `vault_ref`, `key_alias`, `issued_at`, `last_rotated_at`, `rotate_due_at`, `status` | FK → `connection_profile.id` | Chỉ lưu tham chiếu vault; giá trị secret nằm ở GW vault mã hóa |
| `policy_parameter` | `param_key`, `value`, `version`, `effective_from`, `effective_to`, `approved_by`, `category` (ngưỡng/tier/SLA) | FK → `users.id` (approved_by) | Effective-dated; chặn UPDATE giá trị đã hết hiệu lực |
| `vault_audit_log` | `actor_id`, `action`, `profile_id`, `credential_id`, `reason_code`, `at`, `prev_hash` | FK → `users.id`, `credential.id` | Append-only hash-chain WORM ≥10 năm |
| `adapter_health_snapshot` | `profile_id`, `platform` (7 enum), `health` (ok/fail/degraded), `data_age`, `last_success_at`, `error_summary` | FK → `connection_profile.id` | Sinh từ sự kiện GW; cấp dữ liệu cho alert REQ-BOD-006 |
| `change_request` | `target_type`, `target_id`, `proposed_payload`, `requested_by`, `approved_by`, `status`, `executed_at` | FK → `users.id` | SYS_ADMIN thực thi chỉ khi `APPROVED` |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ ở Phase 2; chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Không plaintext rò rỉ | Profile `ACTIVE` với credential trong vault | Bất kỳ vai nào gọi API đọc profile/credential | Response chỉ chứa tham chiếu + trạng thái; không có secret dưới mọi hình thức (kể cả log) | [ ] |
| SC-002: Rotate đúng hạn | Credential sắp đến hạn rotate 90 ngày | Job kiểm tra hạn chạy | Cảnh báo `GRACE` trước hạn; quá hạn sync bị chặn đến khi rotate xong | [ ] |
| SC-003: Thu hồi khẩn ≤24h | CTO phát hiện nghi ngờ rò rỉ | CTO thực hiện revoke | Sync chặn tức thì; revoke + rotate hoàn tất ≤24h; immutable audit đầy đủ | [ ] |
| SC-004: MFA bắt buộc | Tài khoản quản trị chưa step-up MFA | Gọi API quản trị vault | Trả 403, không thực thi, ghi audit nỗ lực | [ ] |
| SC-005: Degraded + backfill | Nền tảng mất quyền API rồi được cấp lại | Profile `DEGRADED` → quyền cấp lại | Dữ liệu giai đoạn degraded nhãn "manual"; backfill tự động chạy; sai khác >±0,1% vào báo cáo đối soát | [ ] |
| SC-006: Tham số chỉ BOD/ADMIN sửa | Vai FIN/OPS bất kỳ | Gọi API sửa `policy_parameter` | Chặn 403 + log; SYS_ADMIN (sau duyệt) và BOD sửa được, mỗi lần ghi có version + ngày hiệu lực | [ ] |
| SC-007: Chặn connector hardcode | Developer thêm kết nối ngoài Settings | Review/build | Kiến trúc chặn mã hóa vendor cố định; kết nối mới phải qua connection profile | [ ] |

> **Liên kết:** SC-001→004 map REQ-BOD-008; SC-005 map REQ-BOD-008 + DI-007; SC-006 map REQ-BOD-009 (tham số quản trị); SC-007 map DI-004.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI (console quản trị — counterpart WEB) | `phase4-ux/bcerp-web/settings-gw/*.md` |
| Bản GW của cùng REQ (vault mã hóa, scheduler, adapter) | `phase2-features/integration-gw/settings-gw/*.md` |
| Nguồn nghiệp vụ gốc | `phase1-business/departments/bod/bod.md` (A3 REQ-BOD-008, B8) · `_meta/req-registry.json` |
| Quyết định deferred liên quan | `work/wf-analyze-requirements/deferred-issues.md` (DI-004, DI-007) |
