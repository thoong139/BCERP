# Tính Năng: Client Portal Góc Nhìn Ops — Cấp Tài Khoản & Monitor

> **Dựa trên:** REQ-OPS-010 trong `phase1-business/departments/operations/operations.md` (Phần A3, B.5 — BR-OPS-5.1/5.2/5.5); REQ-FIN-017 trong `phase1-business/departments/finance/finance.md` (portal ví read-only từ FIN — share model chung)
> **Phân hệ:** Vận hành & Marketing nội bộ — Onboarding/CS, phối hợp Tài chính (SYS-CORE-BACKEND)
> **Module:** Client Portal (MOD-CLIENT-PORTAL)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/finance/finance.md`, `policies/client-portal-minh-bach-bao-mat.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/client-portal/[screen-group].md`, `phase5-implementation/tasks/core-backend/client-portal/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp. REQ-OPS-010 fan-out ra 5 systems — bản này là bản riêng cho **SYS-CORE-BACKEND**; counterparts: SYS-BCERP-WEB (nơi AM thao tác), SYS-MOBILE-INTERNAL (push AM), SYS-PORTAL-WEB (trải nghiệm khách web), SYS-MOBILE-PORTAL (touchpoint rút gọn). Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CPORT-002 |
| Module | MOD-CLIENT-PORTAL (SYS-CORE-BACKEND — BCERP Core Backend, headless API/domain service) |
| Yêu cầu nghiệp vụ | REQ-OPS-010 (Client Portal góc nhìn ops — cấp tài khoản & monitor — HIGH · GĐ3); REQ-FIN-017 (portal ví read-only — nội dung hiển thị do FEAT-CORE-CPORT-001 phục vụ) |
| Người dùng liên quan | OPS_AM (cấp/kích hoạt, monitor adoption — chính); OPS_PLAN (điều phối escalation, khóa tài khoản xâm phạm); OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (xem adoption/ticket tenant mình phụ trách); CUSTOMER (CLIENT_ADMIN tự quản user, CLIENT_USER dùng portal) |
| Độ ưu tiên | Cao (HIGH · Phase3 · GĐ3) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-CPORT-001 (dữ liệu ví read-only — điều kiện "khách tự xem được số dư" ở gate Day 14); queue ticket hợp nhất (REQ-OPS-009); onboarding tự sinh dự án (REQ-OPS-004 — milestone chạy trên dự án đó); RBAC/2FA nền chung (REQ-BOD-007) |
| Ghi chú Expert (A7) | Expert review Phần A `operations.md` chưa thực hiện (chờ review); đã chốt: KHÔNG lập vai OPS_CX theo quyết định stakeholder DI-006 — điều phối escalation gán OPS_PLAN; hình thức thu feedback Day 30 (AM tay / hệ thống) còn mở `[KXN-15]` — spec tham số hóa, không hardcode |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Là phần enforce phía core backend của góc nhìn ops đối với Client Portal: **cấp/kích hoạt tài khoản portal theo mốc onboarding Day 1/7/14/30** (Day 14 là gate bắt buộc "khách kích hoạt portal thành công") và **cung cấp dữ liệu monitor adoption + phản hồi ticket theo khách** cho dashboard nội bộ. Core backend là nguồn sự thật của provisioning (tạo CLIENT_ADMIN đầu tiên, invite, quota user theo hợp đồng), của tenant isolation tuyệt đối và của gate engine machine-checkable — mọi rule được kiểm tra lại ở tầng service, không tin UI.

**Phạm vi:**
- Bao gồm: provisioning API cho WEB (tạo CLIENT_ADMIN đầu tiên + invite tại Day 1; thu hồi CLIENT_ADMIN có xác nhận danh tính POC trong 1 ngày làm việc); self-service user management do CLIENT_ADMIN vận hành — nội bộ/SYS_ADMIN không tạo hộ; quota user theo hợp đồng (mặc định 2 CLIENT_ADMIN + 10 CLIENT_USER, mở rộng theo tier); gate engine Day 1/7/14/30 — Day 14 machine-checkable (khách tự xem được số dư + chi tiêu + ticket; ≥1 login/tuần từ ≥2 user), trượt gate tự sinh escalation CS TL trong 24h kèm kế hoạch khắc phục có owner + deadline, gate là điều kiện nghiệm thu onboarding; monitor API adoption (activation, 2FA coverage, login/tuần) và phản hồi ticket theo khách/tier; tenant isolation 2 lớp, 2FA/OTP bắt buộc, session timeout 30 phút, khóa sau 5 lần sai mật khẩu; audit log bất biến mọi sự kiện provisioning/thu hồi/milestone; mobile-portal dùng chung service với touchpoint rút gọn — số dư, thông báo, ticket.
- Không bao gồm: màn hình thao tác AM (SYS-BCERP-WEB), push cảnh báo tới AM (SYS-MOBILE-INTERNAL — core chỉ phát sự kiện), UI portal phía khách (SYS-PORTAL-WEB / SYS-MOBILE-PORTAL), dữ liệu ví read-only (FEAT-CORE-CPORT-001), SLA clock & escalation engine + CSAT của ticket (REQ-OPS-009).

---

## 2. Luồng Người Dùng (User Stories)

AM thao tác trên WEB nội bộ; core backend xác thực lại mọi điều kiện ở tầng API. Khách (CUSTOMER) tương tác qua portal counterparts — dưới đây chỉ mô tả phần service phía core backend phục vụ.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Tạo CLIENT_ADMIN đầu tiên + gửi invite ngay Day 1, hệ thống ghi mốc tự động | Đúng quy trình — không dựa trí nhớ hay Excel cá nhân |
| 2 | OPS_AM | Thấy adoption theo khách: % kích hoạt, 2FA coverage, login/tuần, trạng thái gate Day 14 | Chủ động đôn trước khi gate trượt, không bị động chờ ngày 14 |
| 3 | OPS_AM | Đề xuất cấp/thu hồi CLIENT_ADMIN với bước ép xác nhận danh tính POC trong 1 ngày làm việc | Phòng cấp quyền cho người không phải POC — rủi ro pháp lý đối ngoại |
| 4 | OPS_PLAN | Nhận escalation trượt gate Day 14 kèm root cause + kế hoạch khắc phục có owner/deadline | Điều phối đúng SLA 24h, chấm dứt "trượt im lặng" |
| 5 | OPS_PLAN | Khóa tức thì tài khoản portal khách có dấu hiệu xâm phạm | Chặn rò rỉ dữ liệu tenant trước khi điều tra xong |
| 6 | OPS_CONT / OPS_DES / OPS_EDIT / OPS_ADS | Xem adoption + ticket của tenant mình phụ trách | Biết khách có đang "mù thông tin" không để phối hợp AM |
| 7 | CUSTOMER (CLIENT_ADMIN) | Tự tạo/khóa CLIENT_USER trong hạn mức, tự reset mật khẩu qua OTP | Không phụ thuộc nội bộ BC cho quản trị user hàng ngày |
| 8 | CUSTOMER (CLIENT_USER) | Kích hoạt qua invite + 2FA, tự xem số dư, chi tiêu và ticket của mình | Minh bạch — không hỏi AM mỗi lần cần số |
| 9 | BOD (điều phối qua OPS_PLAN) | Gate Day 14 là điều kiện nghiệm thu onboarding bị chặn cứng | Onboarding không "nghiệm thu trên giấy" khi khách chưa dùng portal |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Đặc thù touchpoint core backend: mọi rule enforce ở tầng service (không tin UI), audit log hash-chain + tenant isolation tuyệt đối; portal chỉ đọc qua Portal API Gateway riêng — không chạm DB nội bộ.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Provisioning chỉ qua core backend:** AM tạo CLIENT_ADMIN đầu tiên trên WEB → CORE sinh tài khoản `INVITED` + invite token (một lần, có hạn); mọi sự kiện provisioning/thu hồi ghi audit log bất biến (ai, khi nào, tenant, old→new); không có đường tạo tài khoản portal ngoài luồng này. Nguồn: BR-OPS-5.1, policy §2.6. | Không invite token hợp lệ → kích hoạt từ chối; provisioning ngoài luồng → alert bảo mật |
| BR-002 | **Nội bộ không tạo hộ user portal:** endpoint tạo/sửa/xóa CLIENT_USER chỉ chấp nhận caller là CLIENT_ADMIN của chính tenant (self-service); SYS_ADMIN và mọi vai nội bộ bị từ chối hành động tạo/sửa user phía khách — trừ duy nhất khóa/suspend vì bảo mật (BR-005). Nguồn: REQ-OPS-010 A3, BR-OPS-5.1. | Từ chối "SELF_SERVICE_ONLY" + audit log; lặp ≥2 lần → alert OPS_PLAN |
| BR-003 | **Quota user theo hợp đồng:** mặc định 2 CLIENT_ADMIN + 10 CLIENT_USER; hạn mức mở rộng theo tier lấy từ cấu hình hợp đồng effective-dated; CORE chặn vượt quota ở tầng service. Nguồn: REQ-OPS-010, policy §2.3. | Từ chối "QUOTA_EXCEEDED"; đổi quota không qua hợp đồng → chặn |
| BR-004 | **Xác nhận danh tính POC khi cấp/thu hồi CLIENT_ADMIN:** AM đề xuất + xác nhận POC trong 1 ngày làm việc (bằng chứng gắn vào yêu cầu); quá hạn → yêu cầu tự hủy, phải đề xuất lại; thu hồi CLIENT_ADMIN thu hồi đồng thời toàn bộ session active. Nguồn: BR-OPS-5.1, policy §4. | Thiếu bằng chứng POC → không submit; quá 1 ngày LV → tự hủy + log |
| BR-005 | **Khóa tài khoản xâm phạm tức thì:** OPS_PLAN khóa ngay tài khoản có dấu hiệu xâm phạm; khóa ghi reason code, thu hồi session, mọi action tiếp theo từ chối; mở lại sau khi điều tra kết luận có phê duyệt. Nguồn: policy §4. | Không reason code → không submit; mở lại thiếu kết luận → từ chối |
| BR-006 | **Milestone Day 1/7/14/30 do gate engine tự tính:** Day 1 — CLIENT_ADMIN đầu tiên được tạo + invite, khách login lần đầu; Day 7 — ≥80% user kích hoạt, 2FA 100%; Day 14 — GATE "khách kích hoạt portal thành công": khách tự xem được số dư + chi tiêu + ticket VÀ ≥1 login/tuần từ ≥2 user; Day 30 — review adoption + feedback. Engine đọc event (login, activation, 2FA) từ audit log, không nhận trạng thái do client báo. Nguồn: BR-OPS-5.1, REQ-OPS-004, policy §2.6. | Thiếu bất kỳ tiêu chí Day 14 → gate `SLIPPED`; báo "đạt" tay không được chấp nhận |
| BR-007 | **Trượt gate Day 14 → escalation 24h:** gate `SLIPPED` → core tự sinh escalation root cause lên CS TL trong 24 giờ kèm dữ liệu adoption; kế hoạch khắc phục bắt buộc có owner + deadline trên hệ thống; gate Day 14 là điều kiện nghiệm thu onboarding — hard gate chặn cả UI lẫn API. Nguồn: BR-OPS-5.1, policy §2.6. | Nghiệm thu khi gate chưa `PASSED` → chặn "GATE_DAY14_NOT_PASSED"; escalation quá 24h → nhắc + escalate tiếp |
| BR-008 | **Tenant isolation + bảo mật phiên:** RLS DB + filter `tenant_id` tầng API 2 lớp; portal qua Portal API Gateway riêng, network zone tách biệt, chỉ đọc view tổng hợp đã lọc — không chạm DB nội bộ; 2FA/OTP bắt buộc đăng nhập, thêm một lớp OTP cho hành động nhạy cảm (đổi mật khẩu, thêm user, xuất dữ liệu); session timeout 30 phút; khóa sau 5 lần sai mật khẩu. Khách đa nhãn hàng: 1 tenant/pháp nhân. Nguồn: BR-OPS-5.2, REQ-FIN-017, policy §2.4. | Thiếu `tenant_id` → từ chối; thiếu 2FA → không vào dữ liệu; sai 5 lần → lockout tự động |
| BR-009 | **Monitor adoption & phản hồi ticket theo khách:** tổng hợp adoption (activation, 2FA coverage, login/tuần) + trạng thái ticket theo khách/tier phục vụ dashboard WEB; ticket đọc từ queue hợp nhất REQ-OPS-009 (portal/Zalo/email — chống trùng lặp); khách phản đối số liệu → hiển thị "Đang đối soát" (FEAT-CORE-CPORT-001); khiếu nại nghiêm trọng (Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên) leo thang BOD trong 24h — OPS_PLAN điều phối. Nguồn: BR-OPS-5.5, REQ-OPS-009. | Dữ liệu monitor không gắn tenant → từ chối; khiếu nại quá 24h → escalate BOD trực tiếp |
| BR-010 | **Mobile-portal touchpoint rút gọn:** MOBILE-PORTAL tiêu dùng cùng domain service, cùng RBAC + tenant isolation; phạm vi cố định: số dư, thông báo, ticket — không mở thêm surface dữ liệu; BR-001..009 áp dụng nguyên verbatim. Nguồn: REQ-FIN-017 (dùng chung view), Notes lane. | Endpoint mobile trả ngoài phạm vi → chặn ở scope filter; mở surface mới phải sửa spec này trước |
| BR-011 | **Cờ DPA chặn kích hoạt khách EU/US:** tài khoản portal chỉ kích hoạt khi khách EU/US đã ký DPA (cờ trên hợp đồng); BC = processor — chỉ xử lý theo chỉ dẫn controller. Nguồn: BR-FIN-605, REQ-FIN-017. | Thiếu DPA signed → "DPA_REQUIRED", không sinh invite token |
| BR-012 | **Audit log bất biến + meta-log:** mọi sự kiện (provisioning, invite, kích hoạt, 2FA bật/tắt, khóa/mở, thu hồi, milestone chuyển trạng thái, escalation) ghi append-only + hash-chain với reason code bắt buộc cho hành động nhạy cảm; lockout/đăng nhập bất thường là tín hiệu đầu vào breach detection (BR-FIN-604). Nguồn: BR-FIN-501, BR-OPS-5.2. | Thiếu reason code → không submit; đứt hash-chain → alert CTO + BOD_CEO |

---

## 4. Phân Quyền

| Hành động | OPS_AM | OPS_PLAN | OPS_CONT/DES/EDIT/ADS | CUSTOMER — CLIENT_ADMIN | CUSTOMER — CLIENT_USER | SYS_ADMIN |
|-----------|--------|----------|------------------------|--------------------------|------------------------|-----------|
| Tạo CLIENT_ADMIN đầu tiên + invite (Day 1) | ✅ (WEB, enforce ở CORE) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Tạo/khóa CLIENT_USER trong quota | ❌ | ❌ | ❌ | ✅ (self-service, +OTP) | ❌ | ❌ (không tạo hộ — endpoint từ chối vai nội bộ) |
| Đề xuất cấp/thu hồi CLIENT_ADMIN | ✅ (Xác nhận POC 1 ngày LV bắt buộc) | ✅ (duyệt ngoại lệ quy trình) | ❌ | ❌ | ❌ | ❌ |
| Xem monitor adoption + trạng thái gate | ✅ (tenant phụ trách) | ✅ (toàn bộ) | ✅ (tenant mình phụ trách) | ❌ | ❌ | ❌ |
| Xử lý escalation trượt gate (owner kế hoạch) | ✅ | ✅ (điều phối) | ❌ | ❌ | ❌ | ❌ |
| Khóa/mở tài khoản có dấu hiệu xâm phạm | ❌ | ✅ (tức thì, reason code) | ❌ | ✅ (khóa user tenant mình) | ❌ | ✅ (khóa kỹ thuật, có log — không tạo hộ user) |
| Reset mật khẩu user | ❌ | ❌ | ❌ | ✅ (user tenant mình, +OTP) | ✅ (của mình) | ❌ |
| Chấm gate Day 14 tay (bỏ tiêu chí máy) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại — gate chỉ từ event log) |
| Nghiệm thu onboarding khi gate chưa PASSED | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Xem/xóa audit log provisioning | ❌ | ✅ (xem) | ❌ | ❌ | ❌ | ✅ (xem) / ❌ (xóa — không tồn tại mọi vai) |

> Ghi chú touchpoint: toàn bộ quyền enforce bằng vai tại tầng API core backend cho cả 5 counterparts — UI chỉ là bề mặt thao tác; CLIENT_ADMIN/CLIENT_USER là hai role phụ phía customer thuộc đại diện vai CUSTOMER của registry 18 vai.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách từ chối dùng portal (chỉ làm việc qua AM/email):** ghi ngoại lệ vào profile tenant; gate Day 14 vẫn giữ `SLIPPED` theo tiêu chí máy — AM chịu trách nhiệm báo cáo thay thế đúng cam kết (tính workload KPI AM); khi khách quay lại, milestone chạy tiếp từ mốc đang dừng.
- **Gate Day 14 trượt vì lỗi hệ thống (không phải phía khách):** root cause ghi phân loại nguyên nhân (lỗi hệ thống vs khách); gate vẫn chỉ `PASSED` khi khách thực sự đạt tiêu chí — không "tín nhiệm" thay bằng chứng.
- **CLIENT_ADMIN rời tổ chức / thôi nhận POC:** AM đề xuất thu hồi + xác nhận POC mới trong 1 ngày làm việc; tenant không được rơi vào "0 CLIENT_ADMIN" quá hạn — nếu rơi, escalation tự sinh cho AM.
- **Khách đa nhãn hàng (mỗi pháp nhân 1 tenant):** provisioning nhân bản cấu hình cho từng tenant; không shared account chéo tenant; adoption gộp theo hợp đồng để báo cáo nhưng dữ liệu tách tenant tuyệt đối.
- **Cần vượt quota user (khách tier cao):** cập nhật cấu hình hợp đồng effective-dated → CORE mở hạn mức từ ngày hiệu lực; không mở "tạm" ngoài hợp đồng.
- **Đăng nhập bất thường (VPN lạ, giờ lạ, nhiều IP):** lockout/OTP step-up tự kích hoạt; sự kiện đưa vào breach detection BR-FIN-604 — portal là điểm phát hiện sự cố phía khách.
- **Khách EU/US chưa ký DPA đặt hàng gấp:** provisioning đứng ở `DPA_REQUIRED` — không có luồng "kích hoạt trước ký sau"; chỉ legal xác nhận DPA signed thì invite token mới sinh được.
- **Feedback Day 30:** hình thức thu (AM tay hay survey hệ thống) chưa chốt `[KXN-15]` — core lưu feedback dạng bản ghi gắn tenant/milestone, chấp nhận cả hai nguồn, không hardcode kênh.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity chính:** Mốc onboarding portal (`PortalOnboardingMilestone`) — engine tự tính từ event log. **Entity phụ:** tài khoản user phía khách (`PortalAccount`) — vòng đời do CLIENT_ADMIN vận hành.

**Sơ đồ trạng thái (entity chính):**
```
[NOT_STARTED] ──(Day 1: CLIENT_ADMIN đầu tiên + invite; khách login lần đầu)──► [DAY1_DONE]
                                                                                     │
                                                                                     │ (Day 7: ≥80% activated + 2FA 100%)
                                                                                     ▼
                                                                                [DAY7_DONE]
                                                                                     │
                                      (Day 14: đủ tiêu chí)                          │ (Day 14: thiếu tiêu chí)
                                    ┌────────────────────────────────────────────────┤
                                    ▼                                                ▼
                             [DAY14_PASSED] ◄── (đạt lại tiêu chí sau khắc phục) [DAY14_SLIPPED]
                                    │                 (escalation 24h + kế hoạch owner/deadline)
                                    │ (Day 30: review adoption + feedback)
                                    ▼
                             [DAY30_REVIEWED]  (trạng thái kết thúc)
```

**Bảng chuyển đổi (entity chính):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NOT_STARTED` | Day 1 provisioning | `DAY1_DONE` | OPS_AM (CORE xác thực) | CLIENT_ADMIN đầu tiên được tạo + invite gửi; khách login lần đầu (event) |
| `DAY1_DONE` | Day 7 kiểm tra | `DAY7_DONE` | Hệ thống (engine) | ≥80% user kích hoạt; 2FA bật 100% user |
| `DAY7_DONE` | Day 14 đánh gate | `DAY14_PASSED` | Hệ thống (engine) | Khách tự xem được số dư + chi tiêu + ticket; ≥1 login/tuần từ ≥2 user (event log) |
| `DAY7_DONE` | Day 14 đánh gate | `DAY14_SLIPPED` | Hệ thống (engine) | Thiếu bất kỳ tiêu chí; tự sinh escalation CS TL 24h + yêu cầu kế hoạch owner/deadline |
| `DAY14_SLIPPED` | Đạt lại tiêu chí | `DAY14_PASSED` | Hệ thống (engine) | Đủ tiêu chí từ event log; kế hoạch khắc phục đã ghi trên hệ thống |
| `DAY14_PASSED` | Day 30 review | `DAY30_REVIEWED` | OPS_AM (ghi review + feedback) | Feedback ghi nhận gắn tenant; ticket đầu tiên qua portal (nếu phát sinh) |

**Quy tắc:**
- Chỉ engine được chuyển trạng thái milestone — AM/OPS không chấm tay; mọi chuyển đổi đọc từ event log (append-only), không tin tham số client.
- `DAY30_REVIEWED` là trạng thái kết thúc; gate Day 14 chưa `PASSED` thì milestone không thể kết thúc — hard gate chặn nghiệm thu onboarding ở cả UI lẫn API.
- `DAY14_SLIPPED` không quay thẳng `DAY7_DONE` — luồng khắc phục luôn đi qua đủ lại tiêu chí Day 14.

**Vòng đời `PortalAccount` (entity phụ, rút gọn):** `INVITED` → (kích hoạt + 2FA) → `ACTIVE` → [`LOCKED` (5 lần sai — mở theo luồng reset OTP) | `SUSPENDED` (OPS_PLAN/CLIENT_ADMIN khóa — reason code) | `REVOKED` (thu hồi CLIENT_ADMIN có xác nhận POC / offboard ≤24h theo BR-FIN-603)]; `REVOKED` là trạng thái kết thúc — tái tham gia tạo tài khoản mới, lịch sử giữ nguyên.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL tại `technical-specs/database-design.md`; state machine ticket và CSAT thuộc REQ-OPS-009.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `PortalOnboardingMilestone` | `tenant_id`, `project_id`, `state` (`NOT_STARTED/DAY1_DONE/DAY7_DONE/DAY14_PASSED/DAY14_SLIPPED/DAY30_REVIEWED`), `slipped_at`, `root_cause`, `plan_owner`, `plan_deadline` | FK → `tenants`, `projects` | Engine tự tính; gate Day 14 là điều kiện nghiệm thu onboarding (hard gate) |
| `PortalAccount` | `tenant_id`, `user_ref`, `role` (`CLIENT_ADMIN/CLIENT_USER`), `state` (`INVITED/ACTIVE/LOCKED/SUSPENDED/REVOKED`), `two_fa_enabled`, `last_login_at`, `invited_by` | FK → `tenants` | Nội bộ không tạo hộ (BR-002); quota theo hợp đồng (BR-003) |
| `InviteToken` | `portal_account_id`, `token_hash`, `expires_at`, `used_at`, `single_use` | FK → `portal_accounts` | Một lần, có hạn; lưu hash — không lưu token thô |
| `TenantPortalQuota` | `tenant_id`, `contract_id`, `max_admins` (2), `max_users` (10), `effective_from/to` | FK → `tenants`, `contracts` | Effective-dated theo hợp đồng/tier; nguồn cho BR-003 |
| `PocVerification` | `portal_account_id`, `requested_by` (OPS_AM), `evidence_ref`, `verified_at`, `expires_at` (1 ngày LV) | FK → `portal_accounts` | Bắt buộc cấp/thu hồi CLIENT_ADMIN (BR-004) |
| `MilestoneEscalation` | `milestone_id`, `triggered_at`, `sla_due_at` (24h), `assignee` (CS TL), `plan_ref`, `status` | FK → `portal_onboarding_milestones` | Tự sinh khi `DAY14_SLIPPED`; gắn escalation engine REQ-OPS-008/009 |
| `PortalProvisioningAuditLog` | `actor_id`, `role`, `action`, `entity`, `tenant_id`, `old_value`, `new_value`, `reason_code`, `prev_hash` | FK → đối tượng log | Append-only + hash-chain; không interface xóa/sửa mọi vai |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-OPS-010 (`operations.md` A3/B.5) và REQ-FIN-017 (`finance.md` A3).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Day 1 provisioning đúng luồng (REQ-OPS-010) | Dự án onboarding vừa handoff, milestone `NOT_STARTED` | OPS_AM tạo CLIENT_ADMIN đầu tiên qua WEB | CORE sinh `INVITED` + invite token một lần; milestone chuyển `DAY1_DONE` khi khách login lần đầu; audit log đủ | [ ] |
| SC-002: Nội bộ không tạo hộ user (REQ-OPS-010) | Tenant đã ACTIVE | SYS_ADMIN gọi endpoint tạo CLIENT_USER | Từ chối "SELF_SERVICE_ONLY" + audit log; CLIENT_ADMIN tự tạo thành công trong quota | [ ] |
| SC-003: Chặn vượt quota (REQ-OPS-010) | Tenant đủ 2 CLIENT_ADMIN + 10 CLIENT_USER | CLIENT_ADMIN tạo user thứ 13 | Từ chối "QUOTA_EXCEEDED"; sau khi hợp đồng nâng hạn mức effective-dated, tạo thành công | [ ] |
| SC-004: Gate Day 14 machine-checkable (REQ-OPS-010) | Day 14, tenant có 3 user nhưng chỉ 1 login/tuần | Engine đánh gate | Gate `SLIPPED`; escalation CS TL tự sinh trong 24h; kế hoạch có owner + deadline; không ai chấm "đạt" tay | [ ] |
| SC-005: Gate là điều kiện nghiệm thu (REQ-OPS-010) | Milestone ở `DAY14_SLIPPED` | AM thao tác nghiệm thu onboarding | Chặn "GATE_DAY14_NOT_PASSED" ở tầng API (gọi thẳng API cũng bị); sau khi đủ tiêu chí, nghiệm thu thông | [ ] |
| SC-006: 2FA + lockout bắt buộc (REQ-OPS-010) | User chưa bật 2FA; sau đó sai mật khẩu 5 lần | Đăng nhập | Thiếu 2FA → không vào dữ liệu; sai 5 lần → `LOCKED`, session thu hồi, mở theo reset OTP | [ ] |
| SC-007: Tenant isolation chặn chéo (REQ-FIN-017) | CLIENT_USER tenant A | Gọi API adoption/ticket với `tenant_id` tenant B | Từ chối + audit log bảo mật; test chéo hằng quý PASS | [ ] |
| SC-008: Khách EU/US thiếu DPA (REQ-FIN-017) | Hợp đồng khách EU cờ `eu_us = true`, chưa DPA signed | OPS_AM tạo CLIENT_ADMIN Day 1 | Chặn "DPA_REQUIRED", không sinh invite token; sau khi legal ghi nhận DPA signed, provisioning chạy bình thường | [ ] |
| SC-009: Mobile touchpoint rút gọn (REQ-FIN-017) | CLIENT_USER đăng nhập MOBILE-PORTAL | Duyệt API khả dụng | Chỉ số dư, thông báo, ticket; BR-001..009 vẫn enforce; không surface mở rộng | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` (provisioning API cho WEB; monitor adoption API; RBAC + 2FA/OTP + session timeout enforce tầng service) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (sự kiện trượt gate → M-INT push; ticket từ queue hợp nhất REQ-OPS-009; cờ DPA từ hợp đồng; Portal API Gateway tách network zone) |
| Màn hình UI (WEB — thao tác AM; PORTAL — counterpart khách) | `phase4-ux/bcerp-web/client-portal/[screen-group].md`, `phase4-ux/portal-web/client-portal/[screen-group].md`, `phase4-ux/mobile-portal/client-portal/[screen-group].md` |
| Policy nghiệp vụ | `policies/client-portal-minh-bach-bao-mat.md` §2.3–2.6, §4; `policies/sla-khach-hang.md` (escalation); `policies/rbac-phan-loai-du-lieu-credentials.md` (password/credential) |
| Feature liên quan cùng module | `du-lieu-vi-read-only-cho-client-portal.md` (FEAT-CORE-CPORT-001 — nội dung read-only để khách đạt gate Day 14) |
| Workflow tổng | `phase1-business/P1-02-business-workflow.md` (Luồng 1 — GATE portal Day 14; Luồng 5 — khách tạo ticket qua portal; KPI #12 onboarding adoption portal) |
