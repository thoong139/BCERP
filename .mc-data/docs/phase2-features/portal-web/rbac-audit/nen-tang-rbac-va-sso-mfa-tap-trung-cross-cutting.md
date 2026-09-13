# Tính Năng: Nền Tảng RBAC & SSO/MFA Tập Trung (Cross-Cutting) — Touchpoint Client Portal

> **Dựa trên:** REQ-BOD-011 trong `phase1-business/departments/bod/bod.md` (Phần A — Bổ sung Phase 6d)
> **Phân hệ:** BCERP Client Portal (SYS-PORTAL-WEB)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/portal-web/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/portal-web/rbac-audit/feat-portal-rbac-001-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| ID tính năng | FEAT-PORTAL-RBAC-001 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-011 |
| Người dùng liên quan | CUSTOMER (CLIENT_USER, CLIENT_ADMIN), SYS_ADMIN (reset/khóa tài khoản portal), BOD_CEO (oversight an ninh truy cập), BOD_CFO_CTO (quản trị realm portal) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — GATE kích hoạt portal Day 14 của onboarding không chạy được nếu xác thực portal chưa có) |
| Phụ thuộc | FEAT-CORE-RBAC-005 (RBAC engine + SSO Keycloak 2 realms + enforcement tập trung ở core — làm trước hoặc song song chặt); FEAT-CORE-RBAC-002 (service lưu trữ audit nhận sự kiện từ portal) |
| Ghi chú Expert (A7) | bod.md Mục A7 chưa ghi điều chỉnh riêng cho REQ-BOD-011; REQ là bổ sung Phase 6d (resolve SO3-01) và đã chịu 1 điều chỉnh sau đánh giá: DI-006 — vai OPS_CX/FIN_COMPL bị TỪ CHỐI, registry chuẩn hóa còn 18 vai (chi tiết BR-001) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**

Đưa nền tảng RBAC & SSO/MFA tập trung của REQ-BOD-011 vào touchpoint **Client Portal (SYS-PORTAL-WEB)** — cổng dành cho khách hàng: khách đăng nhập bằng OTP trên realm portal (không chung tài khoản với nội bộ), chỉ thấy **phần dữ liệu read-only đã được chia sẻ của tenant mình**, với tenant isolation tuyệt đối và không lộ dữ liệu nội bộ. Đây là bản riêng của SYS-PORTAL-WEB trong fan-out 4 hệ thống của REQ-BOD-011 (counterparts: SYS-CORE-BACKEND, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL) — portal không dựng RBAC/SSO riêng lẻ mà tiêu dùng policy và claim từ nền tảng tập trung.

**Phạm vi:**

- Bao gồm:
  - Xác thực OTP cho user portal trên realm portal của Keycloak: gửi OTP qua kênh đã KYC, giới hạn thử, khóa tạm khi lạm dụng; chính sách session/refresh theo tier dữ liệu do nền tảng phát hành.
  - Tenant isolation và biên dữ liệu portal: mọi API chỉ trả dữ liệu đã bật chia sẻ (share scope) của đúng tenant trong session; mask giá vốn thành "điều chỉnh đối soát", disclaimer độ trễ, watermark (nối REQ-FIN-017).
  - Read-only tuyệt đối cho phần tài chính hiển thị portal (số dư ví, chi tiêu daily, trạng thái đối soát); hành động khách (ticket, confirm nghiệm thu, CSAT) đi qua API nghiệp vụ riêng có audit.
  - Quản trị tài khoản portal có audit: CLIENT_ADMIN tự mời/thu hồi user cùng tenant; SYS_ADMIN reset/tạm khóa sau xác minh đầu mối, bắt buộc nhập lý do.
  - Ghi sự kiện đăng nhập/xác thực/truy cập bất thường về service audit tập trung (hash-chain, WORM ≥10 năm).
- Không bao gồm:
  - RBAC engine, điểm check quyền tập trung, lifecycle tài khoản nội bộ, cấu hình gốc Keycloak — thuộc FEAT-CORE-RBAC-005; portal chỉ tích hợp.
  - Màn hình quản trị vai nội bộ + MFA TOTP nhân viên (SYS-BCERP-WEB) và MFA step-up duyệt mobile (SYS-MOBILE-INTERNAL).
  - Quarterly access review (FEAT-CORE-RBAC-003), compensating control CFO/CTO (FEAT-CORE-RBAC-001), lưu trữ WORM (FEAT-CORE-RBAC-002) — giữ scope riêng ở core, portal tham chiếu.
  - Nội dung nghiệp vụ các trang portal (ví, đối soát, nghiệm thu, ticket, CSAT) — thuộc module CLIENT-PORTAL của cùng hệ thống; feature này định nghĩa lớp xác thực/phân quyền/isolation mà các trang đó bắt buộc dùng.

**Giả định (không tự quyết):** các `[KXN]` còn mở (KXN-6, 7, 9, 15–22) thuộc quy trình sales/ops/HR nội bộ, không chặn spec này; riêng `[KXN-18]` (quy trình HR) ảnh hưởng gián tiếp qua luồng offboarding nội bộ → thu hồi portal access — spec dùng mặc định "thu hồi + rotate ≤24h" của REQ-BOD-011 và cập nhật lại khi KXN chốt. Thông số OTP/session là mặc định đề xuất, số cụ thể do BOD_CFO_CTO chốt khi cấu hình realm (nối REQ-BOD-009).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint là **portal web cho khách hàng**: quyền của phiên không do giao diện quyết mà do claim/tenant trong token do nền tảng tập trung phát hành, kiểm chứng lại tại service layer.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (CLIENT_USER) | Đăng nhập portal bằng OTP gửi vào email/điện thoại đã KYC | Truy cập an toàn không phải nhớ thêm mật khẩu |
| 2 | CUSTOMER (CLIENT_USER) | Xem số dư ví, chi tiêu ngày, trạng thái đối soát của tenant tôi — read-only, có disclaimer độ trễ | Minh bạch tài chính mà không cần hỏi AM |
| 3 | CUSTOMER (CLIENT_USER) | Chỉ thấy dữ liệu tenant của tôi kể cả khi tự sửa URL/tham số | Dữ liệu của tôi không lộ cho bên thứ ba |
| 4 | CUSTOMER (CLIENT_ADMIN) | Tự mời/thu hồi user portal cùng tenant | Chủ động quản lý đầu mối bên tôi |
| 5 | CUSTOMER (mọi user portal) | Khi không nhận được OTP, được hỗ trợ reset/khóa có kiểm soát | Tài khoản không treo vĩnh viễn nhưng không ai mở hộ trái phép |
| 6 | SYS_ADMIN | Reset/tạm khóa tài khoản portal sau xác minh đúng đầu mối, nhập lý do bắt buộc | Mọi thao tác trên tài khoản khách có vết kiểm toán |
| 7 | BOD_CFO_CTO | Quản trị chính sách realm portal (OTP, session, share scope mặc định), mọi thay đổi ghi immutable audit | Điều chỉnh biên an ninh portal theo vai CTO mà vẫn chịu giám sát |
| 8 | BOD_CEO | Nhận báo cáo an ninh truy cập portal (đăng nhập bất thường, tỷ lệ khóa, reset) theo quý | Oversight độc lập, gắn với quarterly access review |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer phải xử lý đúng trong code. BR-001 → BR-005 dùng chung lane MOD-RBAC-AUDIT (đồng bộ counterpart); BR-006 trở đi đặc thù touchpoint portal.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|-------------------|
| BR-001 | (Dùng chung lane) RBAC chuẩn hóa **18 vai registry** (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS); **KHÔNG tồn tại OPS_CX/FIN_COMPL (DI-006 bị từ chối)** — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight. Vai khách trên portal/mobile-portal là CUSTOMER (CLIENT_USER, CLIENT_ADMIN), thuộc realm portal, tách biệt 18 vai nội bộ | Role/group ngoài registry khi cấu hình realm bị từ chối; token portal mang role nội bộ → xác thực thất bại ở service layer + audit mức nghiêm trọng |
| BR-002 | (Dùng chung lane) Audit log **bất biến hash-chain, lưu ≥10 năm (WORM) với log tiền**; mọi thao tác ghi có **actor + timestamp + lý do**. Riêng portal: đăng nhập thành công/thất bại, gửi OTP, khóa tự động, reset/tạm khóa, mời/thu hồi user của CLIENT_ADMIN, mọi lần truy cập view tài chính đều phát sự kiện về service audit tập trung | Thao tác thiếu 1 trong 3 thành phần → fail security review; service audit không nhận sự kiện → không được mở GATE Day 14 |
| BR-003 | (Dùng chung lane) **Quarterly access review bắt buộc** — danh sách user portal từng tenant là một phần inventory bị review (nối REQ-BOD-007); **kiêm nhiệm CFO/CTO phải có compensating control** (REQ-BOD-002) — mọi cấu hình realm portal của BOD_CFO_CTO nằm trong phạm vi CEO ký review quý | User portal không còn hợp đồng mà vẫn ACTIVE đến kỳ review → tự vô hiệu + vào báo cáo; cấu hình chưa ký review 2 quý liên tiếp tự vô hiệu (bám BR-BOD-002.3) |
| BR-004 | (Dùng chung lane) **SSO/MFA tập trung**: nội bộ MFA TOTP bắt buộc, portal khách OTP trên realm riêng; **PII nhân sự (lương) ở mức Confidential/Restricted** — tuyệt đối không xuất hiện ở bất kỳ view/API/watermark nào của portal | Realm portal nhận group nội bộ → chặn khi phát hành token; phản hồi API chứa PII nhân sự → defect bảo mật mức chặn release |
| BR-005 | (Dùng chung lane) **Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền** là luồng nội bộ do RBAC engine kiểm soát — portal KHÔNG có quyền phê duyệt tài chính; giao dịch điều chỉnh/hoàn tiền liên quan tiền khách chỉ hiển thị ở dạng kết quả đã duyệt, tổng hợp theo share scope | Endpoint portal nhận thao tác "duyệt/ghi số liệu tài chính" → sai kiến trúc, chặn ở review; khách thấy giao dịch chưa phê duyệt → sự cố lộ dữ liệu nội bộ P0 |
| BR-006 | **Tenant isolation tuyệt đối**: tenant_id chỉ lấy từ claim trong token, cấm nhận từ tham số client; bảo vệ 2 lớp — RLS ở DB + filter tenant ở service layer; nỗ lực truy cập chéo tenant (kể cả đoán URL/ID) bị từ chối và ghi sự kiện bảo mật | Khách thấy dữ liệu tenant khác → **sự cố P0, breach flow thông báo 72h** (nối REQ-FIN-017/REQ-OPS-010); lặp lại → tự khóa phiên + alert |
| BR-007 | **Read-only tuyệt đối** cho phần tài chính portal: không API portal nào ghi/sửa/xóa số dư, chi tiêu, đối soát; hành động khách được phép (ticket, confirm nghiệm thu, CSAT) qua API nghiệp vụ riêng, actor là user portal, không ảnh hưởng số liệu | Endpoint portal có hiệu ứng ghi vào tài chính → fail kiến trúc; sửa tham số để xem ngoài share scope → 403 + audit |
| BR-008 | **Chỉ hiển thị dữ liệu đã chia sẻ**: nội dung portal điều khiển bằng share scope từng tenant (mặc định TẮT, bật tại GATE Day 14); giá vốn luôn mask "điều chỉnh đối soát", disclaimer độ trễ 15 phút–24h, watermark user + tenant + thời điểm trên mọi view tài chính (nối REQ-FIN-017) | Share scope chưa bật mà view trả dữ liệu → lỗi cấu hình, API mặc đóng; view tài chính thiếu watermark/disclaimer → không đạt nghiệm thu UI |
| BR-009 | **Chính sách OTP mặc định** (số cụ thể BOD_CFO_CTO chốt khi cấu hình): mã 6 chữ số, hiệu lực 5 phút, gửi tới kênh đã KYC, tối đa 5 lần sai/24h → khóa 30 phút + thông báo CLIENT_ADMIN; không gửi OTP qua kênh chưa xác minh | Vượt hạn mức sai → khóa tạm + audit; đổi kênh nhận OTP phải qua luồng xác minh riêng, không gửi ngay |
| BR-010 | **Reset/tạm khóa tài khoản portal chỉ do SYS_ADMIN** sau xác minh đầu mối (đối chiếu CLIENT_ADMIN/đầu mối hợp đồng), bắt buộc nhập lý do; CLIENT_ADMIN tự thu hồi user cùng tenant mình; SYS_ADMIN không tự tạo user portal thay khách | Thiếu lý do/bằng chứng xác minh → từ chối thao tác; toàn bộ hành động kèm ticket/đề nghị gốc ghi audit cho CFO/BOD rà |
| BR-011 | **Session theo tier dữ liệu** (mặc định đề xuất — chốt khi cấu hình): idle quá 30 phút hoặc tối đa 12 giờ thì hết hạn; xem nội dung tài chính T3/T4 đòi hỏi xác thực OTP còn hiệu lực trong phiên; user bị khóa/DEACTIVATED → hủy ngay mọi phiên | Phiên hết hạn giữa thao tác → bắt đăng nhập lại; token user bị khóa còn gọi API → 401 + audit |

---

## 4. Phân Quyền

| Hành động | CUSTOMER (CLIENT_USER) | CUSTOMER (CLIENT_ADMIN) | SYS_ADMIN | BOD_CEO | BOD_CFO_CTO |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Đăng nhập OTP portal | ✅ | ✅ | ❌ (kênh nội bộ riêng) | ❌ | ❌ |
| Xem dữ liệu tài chính tenant mình (read-only, mask giá vốn) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem dữ liệu tenant khác | ❌ | ❌ | ❌ | ❌ | ❌ |
| Mời/thu hồi user portal cùng tenant | ❌ | ✅ | ❌ (chỉ hỗ trợ) | ❌ | ❌ |
| Reset/tạm khóa tài khoản portal (nhập lý do) | ❌ | ❌ | ✅ | ❌ | ❌ |
| Bật/tắt share scope tenant | ❌ | ❌ | ✅ (theo change được duyệt) | ❌ | ✅ |
| Quản trị chính sách realm portal (OTP, session) | ❌ | ❌ | ❌ (thực thi sau duyệt) | ❌ | ✅ |
| Ký quarterly access review (gồm inventory portal) | ❌ | ❌ | ❌ | ✅ | ❌ |
| Xem báo cáo an ninh truy cập portal | ❌ | ❌ | ✅ (vận hành) | ✅ (oversight) | ✅ |
| Đề xuất/cấu hình role ngoài 18 vai + CUSTOMER | ❌ | ❌ | ❌ | ❌ | ❌ |

Bảng trên mô tả ý định phân quyền ở touchpoint portal; quyết định cuối cùng do RBAC engine ở SYS-CORE-BACKEND ra theo claim vai × tenant × tier — giao diện chỉ ẩn/hiện theo kết quả engine. CUSTOMER không thể nhận hay đại diện bất kỳ vai nội bộ nào; SYS_ADMIN thao tác trên portal với tư cách SYS_ADMIN, kèm tham chiếu phê duyệt theo BR-010.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách có nhiều đầu mối cùng tenant:** nhiều user portal chung share scope của tenant; thu hồi 1 user không ảnh hưởng user khác; user bị khóa giữa phiên bị hủy phiên ngay trên mọi thiết bị.
- **Khách hết hợp đồng/kết thúc hợp tác:** toàn bộ user portal của tenant chuyển DEACTIVATED theo checklist offboarding, share scope tắt; dữ liệu tenant khác không bị ảnh hưởng — không có "khóa chéo" giữa tenant.
- **Sai OTP lặp/quét IP bất thường:** vượt 5 lần sai/24h → khóa tự động 30 phút + audit + báo CLIENT_ADMIN; dấu hiệu brute force → escalation sự kiện bảo mật cho SYS_ADMIN và BOD qua alert center.
- **CLIENT_ADMIN rời khỏi khách hàng:** tenant tạm không có admin — SYS_ADMIN chuyển quyền theo yêu cầu chính thức của khách (email/ticket từ đầu mối hợp đồng), có audit; không tự phong CLIENT_ADMIN mới không căn cứ.
- **Nhân viên BC phụ trách khách nghỉ việc `[KXN-18]`:** quy trình HR chưa chốt — dùng mặc định offboarding nội bộ (thu hồi + rotate ≤24h, FEAT-CORE-RBAC-005); cập nhật khi `[KXN-18]` chốt.
- **Nỗ lực truy cập chéo tenant (kể cả do share link):** chặn 403 + ghi sự kiện bảo mật; lặp ≥2 lần từ cùng user → khóa phiên, yêu cầu đăng nhập lại; nghiêm trọng thì breach flow 72h.
- **Trùng email/điện thoại giữa user portal và nhân viên nội bộ:** chặn dùng chung định danh chéo realm — đầu mối khách phải dùng kênh liên hệ riêng, không mượn tài khoản nội bộ nhận OTP.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Áp dụng cho entity chính của touchpoint này: tài khoản user portal khách.*

**Entity:** Tài Khoản Portal Khách (Portal User Account)

**Sơ đồ trạng thái:**
```
[INVITED] ──(kích hoạt - OTP đầu tiên đúng)──► [ACTIVE] ──(SYS_ADMIN tạm khóa)──► [SUSPENDED]
    │                                            │  ▲                               │
    │ (quá 30 ngày không kích hoạt)              │  │ (hết 30 phút / SYS_ADMIN mở)  │ (khóa vĩnh viễn)
    ▼                                            ▼  │                               ▼
[EXPIRED_INVITE]                            [LOCKED] ┘                        [DEACTIVATED]
                                                 │ (khóa vĩnh viễn / hết hợp đồng)
                                                 ▼
                                           [DEACTIVATED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `INVITED` | Kích hoạt (OTP đầu tiên) | `ACTIVE` | CLIENT_USER được mời | Email/điện thoại khớp lời mời; OTP đúng |
| `INVITED` | Quá 30 ngày không kích hoạt | `EXPIRED_INVITE` | Hệ thống | CLIENT_ADMIN phải mời lại |
| `ACTIVE` | Sai OTP quá 5 lần/24h | `LOCKED` | Hệ thống | Tự khóa 30 phút; audit + báo CLIENT_ADMIN |
| `LOCKED` | Hết 30 phút / SYS_ADMIN mở sớm | `ACTIVE` | Hệ thống / SYS_ADMIN | Mở sớm phải nhập lý do (audit) |
| `ACTIVE` | SYS_ADMIN tạm khóa | `SUSPENDED` | SYS_ADMIN | Xác minh đầu mối + lý do; hủy phiên ngay |
| `SUSPENDED` | SYS_ADMIN mở lại | `ACTIVE` | SYS_ADMIN | Có xác nhận đầu mối hợp đồng; lý do ghi audit |
| `ACTIVE`/`LOCKED`/`SUSPENDED` | Khóa vĩnh viễn (hết HĐ, rời tenant, yêu cầu xóa) | `DEACTIVATED` | SYS_ADMIN / CLIENT_ADMIN (user cùng tenant) | Checklist offboarding; share scope của user tắt ngay |

**Quy tắc:**
- `DEACTIVATED` là trạng thái kết thúc — không chuyển tiếp; user quay lại phải được mời tạo tài khoản mới.
- `LOCKED` tự hồi phục theo thời hạn 30 phút, không cần can thiệp; mọi chuyển đổi do con người thực hiện bắt buộc nhập lý do.
- Mọi chuyển đổi phát sự kiện audit (BR-002) và đồng bộ hủy phiên đang mở (BR-011).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL tại `database-design.md`; RBAC engine, realms, vai nội bộ thuộc sở hữu FEAT-CORE-RBAC-005.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `portal_user` | `id`, `tenant_id`, `display_name`, `email`, `phone`, `portal_role` (CLIENT_USER/CLIENT_ADMIN), `status`, `invited_by`, `last_login_at` | FK → `tenant.id` | Trạng thái theo State Machine Mục 6; không chứa PII nhân sự (BR-004) |
| `tenant` | `id`, `name`, `contract_status`, `share_scope_enabled`, `kyc_status` | 1-N → `portal_user` | Share scope mặc định TẮT, bật tại GATE Day 14 (BR-008) |
| `portal_session` | `id`, `portal_user_id`, `tenant_id`, `issued_at`, `idle_expires_at`, `absolute_expires_at`, `ip`, `status` | FK → `portal_user.id` | Policy theo BR-011; hủy ngay khi user rời ACTIVE |
| `auth_event` | `id`, `portal_user_id`, `tenant_id`, `event_type`, `result`, `reason`, `actor`, `timestamp` | FK → `portal_user.id` | Append-only; đẩy về service audit hash-chain WORM (BR-002) |
| `share_scope` | `tenant_id`, `resource_type` (ví/chi tiêu/đối soát/nghiệm thu/ticket), `enabled`, `updated_by`, `updated_at` | FK → `tenant.id` | Thay đổi có lý do + audit; nguồn quyết định nội dung portal hiển thị |
| `admin_action_log` | `id`, `actor_admin_id`, `target_portal_user_id`, `action` (reset/lock/unlock/scope), `reason`, `approval_ref` | FK → `portal_user.id` | Bắt buộc với mọi thao tác SYS_ADMIN (BR-010) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5; đây là phác thảo bắt buộc pass trước khi mở GATE Day 14.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Đăng nhập OTP thành công | User portal ACTIVE, kênh nhận OTP đã KYC | Nhập đúng OTP trong 5 phút | Vào đúng view tenant mình; phiên có idle/absolute timeout theo BR-011 | [ ] |
| SC-002: Tenant isolation | Tenant A, B cùng hệ thống | User A gọi API với ID resource của tenant B | 403, sự kiện bảo mật ghi audit, dữ liệu B không xuất hiện trong response | [ ] |
| SC-003: Mask & disclaimer giá vốn | Share scope tenant đã bật, có dữ liệu chi tiêu | Xem view chi tiêu daily | Giá vốn hiển thị "điều chỉnh đối soát", có disclaimer độ trễ + watermark | [ ] |
| SC-004: Reset có kiểm soát | SYS_ADMIN nhận yêu cầu reset từ đầu mối hợp đồng | Reset tài khoản kèm lý do | User nhận OTP mới qua kênh đã KYC; `admin_action_log` đủ actor + lý do | [ ] |
| SC-005: Không lộ dữ liệu nội bộ | Token và mọi response API portal | Rà soát tự động trường nhạy cảm | Không role nội bộ trong token; không PII nhân sự/duyệt chi nội bộ trong response | [ ] |
| SC-006: Khóa tự động OTP | User ACTIVE | Sai OTP lần thứ 5 trong 24h | Tài khoản LOCKED 30 phút, phiên hủy, CLIENT_ADMIN nhận thông báo, audit có sự kiện | [ ] |

> **Liên kết:** SC-001/SC-004/SC-006 map REQ-BOD-011 (SSO/OTP, lifecycle portal); SC-002/SC-005 map REQ-BOD-011 + REQ-FIN-017 (biên portal, không lộ nội bộ); SC-003 map REQ-FIN-017; nền tảng tham chiếu REQ-BOD-002 (immutable audit) và REQ-BOD-007 (quarterly review).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (portal auth, share scope, admin action) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp Keycloak realm portal + RBAC engine (core) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (đăng nhập OTP, lock/reset, view tài chính portal) | `phase4-ux/portal-web/rbac-audit/` |
| Counterpart nền tảng (enforcement, realms, WORM) | `phase2-features/core-backend/rbac-audit/nen-tang-rbac-va-sso-mfa-tap-trung-cross-cutting.md` (FEAT-CORE-RBAC-005) |
| Task triển khai | `phase5-implementation/tasks/portal-web/rbac-audit/feat-portal-rbac-001-impl.md` |
