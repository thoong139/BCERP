# Tính Năng: Client Portal góc nhìn ops — cấp tài khoản & monitor

> **Dựa trên:** REQ-OPS-010 trong `phase1-business/departments/operations/operations.md` (Phần A — Mục REQ-OPS-010; Phần B — B.5, BR-OPS-5.1→5.5)
> **Phân hệ:** Client Portal (SYS-PORTAL-WEB)
> **Module:** Client Portal (MOD-CLIENT-PORTAL)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md` (B.5), `phase1-business/departments/finance/finance.md` (REQ-FIN-017), `phase1-business/P1-02-business-workflow.md` (Luồng 1, Luồng 5)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/portal-web/client-portal/*.md`, `phase5-implementation/tasks/portal-web/client-portal/feat-cport-002-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-PORTAL-CPORT-002 |
| Module | MOD-CLIENT-PORTAL |
| Yêu cầu nghiệp vụ | [REQ-OPS-010 (chính), REQ-FIN-017 (phụ thuộc chéo — portal ví read-only từ FIN)] |
| Người dùng liên quan | CUSTOMER (CLIENT_ADMIN, CLIENT_USER), OPS_AM (chính), OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS |
| Độ ưu tiên | Cao (HIGH — Bắt buộc) |
| Giai đoạn | Giai đoạn 3 (GĐ3) |
| Phụ thuộc | FEAT-PORTAL-CPORT-001 (ví read-only — nội dung khách phải tự xem được tại gate Day 14); provisioning CORE + màn AM trên WEB nội bộ (counterpart REQ-OPS-010) |
| Ghi chú Expert (A7) | A7 trong `operations.md` đang chờ expert review — chưa có điều chỉnh A7 nào áp dụng tại thời điểm viết |

> **Fan-out:** REQ-OPS-010 có ở 5 systems; file này là bản riêng cho **SYS-PORTAL-WEB** — góc trải nghiệm khách. Counterparts: SYS-CORE-BACKEND (provisioning + tenant isolation), SYS-BCERP-WEB (AM cấp tài khoản + monitor adoption), SYS-MOBILE-INTERNAL (push ticket/cảnh báo trượt gate), SYS-MOBILE-PORTAL (cùng nội dung kèm push).

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa góc nhìn vận hành của REQ-OPS-010 vào Client Portal: phía khách là trải nghiệm nhận invite, kích hoạt tài khoản với 2FA, tự quản portal user và thao tác với dữ liệu được chia sẻ; phía ops là trạng thái kích hoạt/adoption phản hồi về hệ thống nội bộ để theo dõi gate Day 1/7/14/30. Gate Day 14 là điều kiện nghiệm thu giai đoạn onboarding — khách chưa kích hoạt portal thành công thì onboarding chưa hoàn tất.

**Phạm vi:**
- Bao gồm:
  - Màn nhận invite + kích hoạt + bật 2FA trên Portal Web cho CLIENT_ADMIN/CLIENT_USER (portal đa ngôn ngữ/múi giờ cho khách quốc tế).
  - CLIENT_ADMIN tự quản portal user trong hạn mức theo hợp đồng (mặc định 2 CLIENT_ADMIN + 10 CLIENT_USER, mở rộng theo tier) — nội bộ không tạo hộ.
  - Hiển thị dữ liệu chia sẻ theo portal share model: ví read-only (FEAT-PORTAL-CPORT-001), tiến độ nghiệm thu theo milestone, ticket của chính khách, lịch nạp.
  - Trạng thái kích hoạt/adoption ghi log về CORE để WEB nội bộ monitor gate; hành động nhạy cảm (thêm user, xuất dữ liệu, đổi mật khẩu) thêm một lớp OTP.
- Không bao gồm:
  - Thao tác cấp chính thức bởi AM (tạo CLIENT_ADMIN đầu tiên, gửi invite, escalate trượt gate) — AM làm trên SYS-BCERP-WEB; portal tiếp nhận và phản hồi trạng thái.
  - Provisioning engine, hạ tầng tenant isolation (RLS, network zone) — SYS-CORE-BACKEND (counterpart).
  - Queue hợp nhất ticket + CSAT engine — REQ-OPS-009; portal chỉ là điểm tiếp nhận.
  - Dữ liệu ví và mask tầng API — FEAT-PORTAL-CPORT-001 và counterpart CORE REQ-FIN-017.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (CLIENT_ADMIN) | Nhận email invite từ AM, tự kích hoạt và bật 2FA trên portal | Bắt đầu dùng portal theo mốc Day 1 onboarding |
| 2 | CUSTOMER (CLIENT_USER) | Nhận invite do CLIENT_ADMIN tạo, tự kích hoạt tài khoản | Truy cập dữ liệu tenant mình, không phụ thuộc nội bộ BC |
| 3 | CUSTOMER (CLIENT_ADMIN) | Tự tạo/quản lý portal user trong hạn mức theo hợp đồng | Chủ động khi người vào/ra, không chờ BC |
| 4 | CUSTOMER (CLIENT_USER) | Xem ví read-only, tiến độ nghiệm thu theo milestone và lịch nạp sau khi đăng nhập | Nắm tình trạng dự án mỗi tuần, không phải hỏi AM |
| 5 | CUSTOMER (CLIENT_USER) | Tạo ticket/comment trên portal và xem trạng thái xử lý theo SLA | Vấn đề vào queue hợp nhất có dedupe, không thất lạc |
| 6 | CUSTOMER (CLIENT_ADMIN) | Xác minh OTP khi thêm user, xuất dữ liệu, đổi mật khẩu | Tài khoản tenant không bị lợi dụng khi mật khẩu lộ |
| 7 | OPS_AM | Thấy trạng thái kích hoạt từng portal user phản ánh realtime về hệ thống nội bộ | Theo dõi mốc Day 7 (≥80% + 2FA 100%) và gate Day 14 trên WEB nội bộ |
| 8 | OPS_PLAN | Nhận escalation khi gate Day 14 trượt | Điều phối khắc phục — gate là điều kiện nghiệm thu onboarding |
| 9 | OPS_CONT/DES/EDIT/ADS | Thấy ticket và phản hồi khách gắn đúng người phụ trách khi khách thao tác trên portal | Phản hồi đúng SLA tier×priority theo REQ-OPS-008/009 |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — enforce chính ở service layer (CORE); portal là touchpoint tiếp nhận và hiển thị, không chống lệnh thay backend.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Milestone cấp/kích hoạt**: Day 1 — AM tạo CLIENT_ADMIN đầu tiên + gửi invite (WEB → CORE provisioning, portal hiện màn kích hoạt); Day 7 — ≥80% user kích hoạt, 2FA 100%; Day 14 — GATE; Day 30 — review adoption + feedback | Thiếu mốc → tracking gate thiếu dữ kiện, không chốt nghiệm thu onboarding |
| BR-002 | **Gate Day 14**: khách tự xem được số dư + chi tiêu + ticket; ≥1 login/tuần từ ≥2 user. Gate là điều kiện nghiệm thu onboarding; trượt → escalate root cause lên CS TL trong 24h, kế hoạch khắc phục có owner + deadline | Trượt gate không escalate → vi phạm SLA onboarding; gate chỉ chốt từ dữ liệu activation thực, cấm chốt tay |
| BR-003 | **Hạn mức user theo hợp đồng**: mặc định 2 CLIENT_ADMIN + 10 CLIENT_USER, mở rộng theo tier; chặn tạo vượt hạn mức ở tầng service | Tạo vượt hạn mức → báo lỗi "Vượt hạn mức theo hợp đồng, liên hệ AM" |
| BR-004 | **CLIENT_ADMIN tự quản portal user** — nội bộ/SYS_ADMIN không tạo hộ; cấp/thu hồi CLIENT_ADMIN do AM đề xuất + xác nhận danh tính POC trong 1 ngày làm việc | User do nội bộ tạo hộ → audit fail; thu hồi CLIENT_ADMIN phải có dấu vết xác nhận POC |
| BR-005 | **Tenant isolation + bảo mật**: 2FA/OTP bắt buộc; session timeout; khóa sau 5 lần sai mật khẩu; Portal API Gateway riêng tách network zone; mỗi pháp nhân/nhãn hàng 1 tenant riêng, không chia sẻ chéo | Không 2FA → từ chối; sai 5 lần → khóa tự động, mở khóa sau xác minh |
| BR-006 | **Ranh giới dữ liệu portal**: khách thấy ví read-only (REQ-FIN-017), chi tiêu daily, tiến độ nghiệm thu, ticket của mình, lịch nạp; KHÔNG thấy giá vốn, chiết khấu, P&L, tỷ giá nội bộ, ghi chú nội bộ, health score/churn | Mask tầng API (CORE) — payload không chứa trường nội bộ |
| BR-007 | **Disclaimer độ trễ + timestamp bắt buộc**: số dư 15 phút–24h; chi tiêu daily 3–24h; tiến độ/ticket/lịch nạp realtime | Thiếu freshness metadata → component không render |
| BR-008 | **Hành động nhạy cảm thêm lớp OTP**: thêm user, xuất dữ liệu, đổi mật khẩu phải xác minh OTP thứ hai | Thiếu OTP → từ chối hành động + ghi log |
| BR-009 | **Ticket từ portal vào queue hợp nhất** (REQ-OPS-009): dedupe theo khách/tier; ngoài scope tự tách change request; AM nhận push M-INT; SLA tier×priority; khiếu nại nghiêm trọng (Tier D/E, mất tiền, sai sót đối soát, đạo đức) leo thang BOD 24h kèm hồ sơ, OPS_PLAN điều phối | Ticket không vào queue hợp nhất → thất lạc SLA; escalate thiếu hồ sơ → vi phạm quy trình |
| BR-010 | **Monitor phản hồi ticket + adoption**: tạo user, kích hoạt, login, ticket từ portal ghi log về CORE; AM monitor trên WEB nội bộ; M-INT nhận push ticket mới + cảnh báo trượt gate | Adoption thiếu → gate Day 14 không xác định; portal không giữ số adoption cục bộ |
| BR-011 | **Watermark mọi download** (tên user + thời điểm) + log download bất biến | Xuất thiếu watermark → chặn; log thiếu → fail audit toàn vẹn |
| BR-012 | **Khách phản đối số liệu**: phản đối từ portal → AM khởi tạo đối soát; portal hiển thị "Đang đối soát" + số tham chiếu đến khi chốt | Hiện số tranh chấp như số chính thức → cảnh báo FIN_L1, sửa ngay |

---

## 4. Phân Quyền

> Touchpoint **SYS-PORTAL-WEB**. OPS_AM thao tác cấp tài khoản chính thức trên WEB nội bộ (counterpart); cột OPS_AM thể hiện hành động được phản ánh/truy xuất liên quan portal.

| Hành động | OPS_AM | OPS_PLAN | OPS_CONT/DES/EDIT/ADS | CUSTOMER (CLIENT_ADMIN) | CUSTOMER (CLIENT_USER) |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Tạo CLIENT_ADMIN đầu tiên + invite (Day 1) | ✅ (WEB nội bộ) | ❌ | ❌ | ❌ | ❌ |
| Nhận invite + kích hoạt + bật 2FA | ❌ | ❌ | ❌ | ✅ | ✅ |
| Tạo/quản lý portal user trong hạn mức | ❌ (chỉ đề xuất/thu hồi CLIENT_ADMIN sau xác nhận POC) | ❌ | ❌ | ✅ | ❌ |
| Xem ví read-only / chi tiêu tenant mình | ❌ | ❌ | ❌ | ✅ | ✅ |
| Xem tiến độ nghiệm thu + lịch nạp | ❌ | ❌ | ❌ | ✅ | ✅ |
| Tạo ticket/comment trên portal | ❌ | ❌ | ❌ | ✅ | ✅ |
| Trả lời ticket khách (WEB/M-INT — portal hiển thị phản hồi) | ✅ | ❌ | ✅ | ❌ | ❌ |
| Trả lời CSAT sau ticket Closed | ❌ | ❌ | ❌ | ✅ | ✅ |
| Monitor adoption + gate Day 14 (dashboard nội bộ) | ✅ | ✅ (oversight) | ❌ | ❌ | ❌ |
| Điều phối khiếu nại nghiêm trọng leo thang BOD 24h | ❌ (cung cấp hồ sơ) | ✅ | ❌ | ❌ | ❌ |
| Thấy dữ liệu tenant khác / ghi chú nội bộ | ❌ | ❌ | ❌ | ❌ | ❌ |

Quy tắc bổ sung: OPS_CONT/DES/EDIT/ADS không đăng nhập portal — các vai này tương tác khách qua luồng ticket nội bộ (WEB/M-INT), phản hồi hiển thị lại cho khách trên portal; portal user chỉ tồn tại cho CUSTOMER, tài khoản nội bộ đăng nhập portal bị từ chối.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Gate Day 14 trượt:** escalate CS TL trong 24h với kế hoạch khắc phục có owner + deadline; portal không hiển thị thông tin gate nội bộ cho khách — khách chỉ thấy trạng thái user của mình.
- **Khách đa nhãn hàng:** mỗi pháp nhân 1 tenant riêng với bộ portal user riêng; CLIENT_ADMIN tenant này không mời user cho tenant khác.
- **CLIENT_ADMIN nghỉ việc/thu hồi giữa kỳ:** AM đề xuất + xác nhận POC trong 1 ngày làm việc; session user bị thu hồi hết hiệu lực ngay; các user do CLIENT_ADMIN cũ quản vẫn hoạt động, cần thay thế trong hạn mức.
- **Invite hết hạn:** invite có thời hạn hiệu lực (mặc định 7 ngày, chốt khi cấu hình); hết hạn → CLIENT_ADMIN/AM gửi lại invite mới, token cũ vô hiệu.
- **Quên mật khẩu/2FA:** đặt lại qua OTP gửi email đăng ký/POC; sau đặt lại bắt buộc 2FA; khóa sau 5 lần sai được mở sau xác minh danh tính.
- **Khách EU/US:** DPA phải ký trước kích hoạt portal — tenant chưa có cờ "DPA signed" không hoàn tất kích hoạt (chặn tầng service, BR-FIN-605).
- **Nguồn dữ liệu trễ/degraded** (DI-007 — chưa có quyền API developer): portal vẫn hiển thị kèm nhãn nguồn + timestamp; không có trang ví trắng do một nguồn trễ.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> Entity chính là **tài khoản portal user** (CLIENT_ADMIN/CLIENT_USER). Chuyển trạng thái thực thi ở service layer (CORE); portal là nơi khách thực hiện hành động kích hoạt và thấy trạng thái.

**Entity:** Tài khoản portal user

**Sơ đồ trạng thái:**
```
[INVITED] ──(kích hoạt + bật 2FA)──► [ACTIVE] ──(sai mật khẩu/OTP 5 lần)──► [LOCKED]
    │                                   │   ▲                                  │
    │ (invite hết hạn)                  │   └────(mở khóa sau xác minh)────────┘
    ▼                                   │
[EXPIRED]                               └──(thu hồi / offboard)──► [DISABLED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `INVITED` | Kích hoạt + bật 2FA | `ACTIVE` | Chính user được invite | Invite hợp lệ; xác minh OTP; bật 2FA thành công |
| `INVITED` | Hết hạn invite | `EXPIRED` | Hệ thống | Quá thời hạn hiệu lực (mặc định 7 ngày — chốt khi cấu hình) |
| `EXPIRED` | Gửi lại invite | `INVITED` (token mới) | CLIENT_ADMIN (user của mình) / OPS_AM (CLIENT_ADMIN đầu tiên) | Token cũ vô hiệu; còn hạn mức |
| `ACTIVE` | Sai mật khẩu/OTP 5 lần | `LOCKED` | Hệ thống | Tự động theo BR-005 |
| `LOCKED` | Mở khóa sau xác minh | `ACTIVE` | CLIENT_ADMIN / xác minh qua POC | Xác minh danh tính + đặt lại mật khẩu + 2FA |
| `ACTIVE` | Thu hồi / offboard | `DISABLED` | CLIENT_ADMIN (user của mình); OPS_AM đề xuất thu hồi CLIENT_ADMIN sau xác nhận POC | Thu hồi quyền trong 24h khi offboard (BR-FIN-603) |

**Quy tắc:**
- `DISABLED` là trạng thái kết thúc — không chuyển tiếp; user mới tạo được nếu còn hạn mức (suất user DISABLED được giải phóng).
- Không tồn tại `ACTIVE` mà chưa bật 2FA: điều kiện sang `ACTIVE` bao gồm bắt buộc 2FA (khớp mốc Day 7).
- Gate Day 14 là trạng thái của tenant (tính từ dữ liệu activation/login tổng hợp), không phải của user; không ai chốt gate thủ công trái dữ liệu.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `portal_user` | `id`, `tenant_id`, `email`, `role` (CLIENT_ADMIN/CLIENT_USER), `status`, `two_fa_enabled`, `last_login_ts` | FK → `tenant.id` | Chỉ CUSTOMER có portal user; nội bộ không có |
| `portal_invite` | `id`, `portal_user_id`, `token`, `expires_at`, `invited_by`, `status` | FK → `portal_user.id` | Token một-lần; hết hạn → `EXPIRED` |
| `tenant` | `id`, `legal_name`, `contract_no`, `admin_quota` (2), `user_quota` (10), `tier`, `dpa_signed` | 1 tenant — nhiều portal user | Mỗi pháp nhân/nhãn hàng 1 tenant; quota mở rộng theo tier |
| `onboarding_gate_log` | `tenant_id`, `milestone_day` (1/7/14/30), `criteria`, `result`, `checked_at` | FK → `tenant.id` | Gate Day 14 tính từ dữ liệu thực, không chốt tay |
| `portal_access_log` | `user_id`, `tenant_id`, `action`, `resource`, `ts`, `ip` | FK → `portal_user.id` | Append-only, hash-chain (BR-FIN-501/603) |
| `portal_download_log` | `user_id`, `tenant_id`, `resource`, `watermark_text`, `ts` | FK → `portal_user.id` | Ghi mọi download có watermark (BR-011) |
| `ticket` (tham chiếu REQ-OPS-009) | `id`, `tenant_id`, `source`, `status`, `assignee`, `sla_clock` | FK → `tenant.id` | Portal là điểm tạo; queue hợp nhất + state machine ở CORE |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — test được. Chi tiết hóa ở Phase 5; dưới đây là phác thảo map về REQ.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Invite Day 1 | Tenant mới handoff xong, AM tạo CLIENT_ADMIN đầu tiên | CLIENT_ADMIN mở link invite | Kích hoạt được, bắt buộc bật 2FA; trạng thái ACTIVE phản ánh về CORE | [ ] |
| SC-002: Hạn mức user | Quota 2 CLIENT_ADMIN + 10 CLIENT_USER | CLIENT_ADMIN tạo user thứ 11 | Chặn tầng service: thông báo vượt hạn mức + hướng dẫn liên hệ AM | [ ] |
| SC-003: Nội bộ không tạo hộ | SYS_ADMIN/OPS_AM đăng nhập nội bộ | Thử tạo portal user cho khách | Không có đường tạo hộ — chỉ CLIENT_ADMIN tạo user; AM chỉ invite + đề xuất/thu hồi qua POC | [ ] |
| SC-004: Gate Day 14 đạt | Tenant có ≥2 user ACTIVE | Đo tiêu chí gate | PASS khi khách tự xem được số dư + chi tiêu + ticket và ≥1 login/tuần từ ≥2 user; log gate không sửa tay được | [ ] |
| SC-005: Gate Day 14 trượt | Tenant chưa đạt tiêu chí gate | Hệ thống đánh giá gate | Escalate CS TL 24h, kế hoạch khắc phục có owner + deadline; onboarding chưa nghiệm thu | [ ] |
| SC-006: Khóa sau 5 lần sai | User ACTIVE nhập sai mật khẩu | Sai lần thứ 5 liên tiếp | Chuyển LOCKED tự động; mở khóa cần xác minh danh tính | [ ] |
| SC-007: OTP hành động nhạy cảm | CLIENT_ADMIN đã đăng nhập | Thêm user / xuất dữ liệu / đổi mật khẩu | Bắt buộc lớp OTP thứ hai; thiếu OTP → từ chối + log | [ ] |
| SC-008: Tenant isolation | Hai tenant A, B cùng portal | User A truy cập dữ liệu tenant B | 403 tầng service + log cảnh báo; UI không render dữ liệu chéo tenant | [ ] |

> **Liên kết:** SC-001/003 → REQ-OPS-010 (BR-OPS-5.1); SC-002 → REQ-OPS-010 (hạn mức theo hợp đồng); SC-004/005 → REQ-OPS-010 (gate Day 14); SC-006/007 → REQ-OPS-010 (BR-OPS-5.2/5.5); SC-008 → REQ-OPS-010 (BR-OPS-5.2) + REQ-FIN-017.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/portal-web/client-portal/cap-tai-khoan-kich-hoat-monitor.md` |
| Bản counterparts (CORE, WEB, M-INT, M-PORTAL) | `phase2-features/core-backend/client-portal/`, `phase2-features/bcerp-web/`, `phase2-features/mobile-internal/`, `phase2-features/mobile-portal/` (fan-out REQ-OPS-010) |
| Nguồn nghiệp vụ | `operations.md` (REQ-OPS-010, B.5 — BR-OPS-5.1→5.5), `finance.md` (REQ-FIN-017, BR-FIN-603/605), `P1-02-business-workflow.md` (Luồng 1 — GATE Day 14; Luồng 5 — ticket) |
| Policy tham chiếu | `client-portal-minh-bach-bao-mat.md`, `sla-khach-hang.md` (tham chiếu trong operations.md B.6) |
