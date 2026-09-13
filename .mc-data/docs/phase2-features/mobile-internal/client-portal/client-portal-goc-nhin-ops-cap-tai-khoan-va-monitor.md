# Tính Năng: Client Portal Góc Nhìn Ops — Cấp Tài Khoản & Monitor (Mobile Nội Bộ)

> **Dựa trên:** REQ-OPS-010 trong `phase1-business/departments/operations/operations.md` (Phần A, B — B.5) và REQ-FIN-017 trong `phase1-business/departments/finance/finance.md` (Phần A, B.6)
> **Phân hệ:** Mobile Nội Bộ (SYS-MOBILE-INTERNAL)
> **Module:** Client Portal (MOD-CLIENT-PORTAL)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Fan-out:** REQ-OPS-010 xuất hiện ở 5 hệ thống (CORE-BACKEND, BCERP-WEB, MOBILE-INTERNAL, PORTAL-WEB, MOBILE-PORTAL). Bản spec này là **bản riêng cho SYS-MOBILE-INTERNAL** — mobile nội bộ (React Native, offline-capable) cho staff di động: duyệt-on-the-go, xem dashboard, nhận push cảnh báo. Trải nghiệm khách nằm ở counterpart PORTAL-WEB / MOBILE-PORTAL; provisioning dữ liệu ở CORE-BACKEND; thao tác cấp tài khoản đầy đủ ở BCERP-WEB.
> **Cross-dependency:** REQ-FIN-017 — ví read-only cho Client Portal (Finance cung cấp view tổng hợp đã lọc tenant; M-INT chỉ hiển thị view-only, không ghi).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-CPORT-001 |
| Module | MOD-CLIENT-PORTAL |
| Yêu cầu nghiệp vụ | [REQ-OPS-010, REQ-FIN-017] |
| Người dùng liên quan | OPS_AM (chính), OPS_PLAN, OPS_ADS, OPS_CONT, OPS_DES, OPS_EDIT, CUSTOMER (qua counterpart PORTAL/M-PORTAL) |
| Độ ưu tiên | Cao (HIGH — Bắt buộc) |
| Giai đoạn | Giai đoạn 3 (Phase3) |
| Phụ thuộc | REQ-FIN-017 (view ví read-only phải sẵn có trước khi hiển thị số dư cho khách và cho AM trên mobile); FEAT counterpart của REQ-OPS-010 tại SYS-CORE-BACKEND (provisioning + tenant isolation) và SYS-BCERP-WEB (màn hình cấp/kích hoạt đầy đủ) |
| Ghi chú Expert (A7) | Dept doc có Mục A7 nhưng expert review **chưa thực hiện** — chưa có điều chỉnh; giữ chỗ để append kết quả A7.3 sau |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa góc nhìn vận hành của Client Portal vào mobile nội bộ để OPS_AM (và TL/Planner) không phải ngồi máy trạm mới theo dõi được tiến trình cấp/kích hoạt tài khoản portal của khách: nhận push khi khách tạo ticket/phản hồi, theo dõi adoption theo khách, nhận cảnh báo tức thì khi Gate Day 14 có nguy cơ trượt. Tính năng cũng là kênh eyes-on bảo đảm ranh giới dữ liệu biên cương: khách chỉ thấy ví read-only (REQ-FIN-017), tuyệt đối không thấy giá vốn, biên lợi nhuận hay dữ liệu nội bộ.

**Phạm vi:**
- Bao gồm:
  - Nhận push khi khách tạo ticket/phản hồi mới trên portal, và khi phát sinh khiếu nại cần leo thang.
  - Dashboard adoption góc mobile: mốc Day 1/7/14/30 theo khách, tỷ lệ user kích hoạt, trạng thái 2FA, login/tuần, trạng thái Gate Day 14 (đạt/trượt/nguy cơ).
  - Cảnh báo trượt gate kèm deep-link về WEB để AM xử lý hồ sơ đầy đủ.
  - Đề xuất cấp/thu hồi CLIENT_ADMIN từ mobile (provisioning chính vẫn qua CORE; xác nhận danh tính POC theo SLA 1 ngày làm việc).
  - Xem số dư ví theo khách mức **view-only** (nguồn: view tổng hợp đã lọc tenant của REQ-FIN-017) kèm nhãn nguồn + timestamp độ trễ.
  - Offline-capable: cache đọc-được khi mất mạng cho dashboard/ticket đã tải, tự sync khi có mạng.
- Không bao gồm:
  - Trải nghiệm khách trên portal (đọc số dư, chi tiêu, tạo ticket) — thuộc counterpart SYS-PORTAL-WEB và SYS-MOBILE-PORTAL (touchpoint rút gọn: số dư, thông báo, ticket).
  - Tạo/sửa lệnh ví — **cấm trên mọi mobile/portal** theo nguyên tắc chống bypass của Financial Hard Stop; lệnh chỉ tạo trên WEB nội bộ (REQ-FIN-001/003).
  - Quản lý credentials/vault Business Verification — chỉ WEB nội bộ với MFA (BR-OPS-1.8).
  - Đối soát/discrepancy — AM khởi tạo trên WEB, FIN_L1 xử lý (REQ-FIN-004).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Nhận push ngay khi khách tạo ticket/phản hồi mới trên portal | Phản hồi đầu tiên đúng SLA tier×priority kể cả khi đang di chuyển |
| 2 | OPS_AM | Xem dashboard adoption khách đang onboarding (mốc Day 1/7/14/30, % user kích hoạt, 2FA, login/tuần) | Chủ động phát hiện nguy cơ trượt Gate Day 14 trước khi gate trượt |
| 3 | OPS_AM | Nhận cảnh báo "nguy cơ trượt gate" và "đã trượt gate" kèm tiêu chí chưa đạt | Escalate root cause lên CS TL trong 24h, triển khai kế hoạch khắc phục có owner + deadline |
| 4 | OPS_AM | Gửi đề xuất cấp/thu hồi CLIENT_ADMIN từ mobile và nhận kết quả xác nhận danh tính POC | Rút ngắn thời gian xử lý yêu cầu cấp quyền khi ở ngoài văn phòng |
| 5 | OPS_PLAN | Xem tổng quan adoption + tình trạng gate theo toàn bộ khách phụ trách | Điều phối nguồn lực, theo dõi compliance SLA và khiếu nại nghiêm trọng cần leo thang BOD 24h |
| 6 | OPS_ADS/CONT/DES/EDIT | Nhận push khi có ticket/comment thuộc đầu việc của mình gắn portal khách | Phản hồi phần chuyên môn (ads/creative) trong hàng đợi hợp nhất không bỏ sót |
| 7 | CUSTOMER | (Qua counterpart SYS-MOBILE-PORTAL — touchpoint rút gọn) Xem số dư ví read-only, nhận thông báo, tạo/theo dõi ticket | Tự phục vụ minh bạch dữ liệu mà không phải hỏi AM, đúng biên REQ-FIN-017 |
| 8 | SYS_ADMIN | Nhận cảnh báo thiết bị mobile nội bộ mất/khả nghi để thu hồi session/device token | Chặn truy cập dữ liệu khách từ thiết bị thất lạc, giữ tenant isolation tuyệt đối |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Enforcement chính ở service layer (SYS-CORE-BACKEND); M-INT là điểm hiển thị/điều khiển, không phải nơi giữ quy tắc.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Mốc onboarding portal Day 1/7/14/30 bắt buộc** (BR-OPS-5.1/3.2): Day 1 — AM tạo CLIENT_ADMIN đầu tiên + gửi invite, khách đăng nhập lần đầu; Day 7 — ≥80% user kích hoạt, 2FA 100%; **Day 14 — GATE "khách kích hoạt portal thành công"**: khách tự xem được số dư + chi tiêu + ticket, ≥1 login/tuần từ ≥2 user; Day 30 — review adoption + thu feedback. M-INT hiển thị trạng thái từng mốc và push trước ngày gate. | Trượt gate → cảnh báo đỏ + escalate root cause lên CS TL trong 24h, kế hoạch khắc phục có owner + deadline; không đánh "đạt" tay — gate machine-checkable, là điều kiện nghiệm thu onboarding. |
| BR-002 | **Số portal user theo hợp đồng**: mặc định 2 CLIENT_ADMIN + 10 CLIENT_USER, mở rộng theo tier. CLIENT_ADMIN tự quản portal user của mình; **nội bộ/SYS_ADMIN không tạo hộ** tài khoản portal cho khách. | Vượt hạn mức → chặn đề xuất cấp và báo "vượt số user theo hợp đồng — cần mở rộng theo tier"; AM xử lý mở rộng hợp đồng trước. |
| BR-003 | **Cấp/thu hồi CLIENT_ADMIN**: AM đề xuất (được từ mobile) + xác nhận danh tính POC trong 1 ngày làm việc; thu hồi phải có căn cứ (nghỉ POC, đổi nhân sự khách, rủi ro an ninh). Portal user thường do CLIENT_ADMIN tự quản. | Thiếu xác nhận POC → không chuyển bước provisioning; CORE từ chối tạo/thu hồi khi thiếu hội đủ: đề xuất AM + xác nhận POC + audit log. |
| BR-004 | **Tenant isolation tuyệt đối**: mọi dữ liệu trên M-INT gắn chặt `tenant_id`; khách đa nhãn hàng thì mỗi pháp nhân/nhãn hàng 1 tenant riêng, không gộp, không hiển thị chéo. Mobile chỉ gọi API có filter `tenant_id` ở tầng service, không truy vấn thô xuống DB nội bộ. | Request thiếu/không khớp `tenant_id` → từ chối 403 + audit log bất biến; dữ liệu tenant khác không bao giờ render, kể cả khi sync lại cache lúc mạng chập chờn. |
| BR-005 | **Ranh giới dữ liệu khách/nội bộ**: khách chỉ thấy ví read-only, chi tiêu daily, tiến độ nghiệm thu, ticket của mình, lịch nạp (REQ-FIN-017/BR-OPS-5.3). **Không lộ dữ liệu nội bộ** cho phía khách: giá vốn, chiết khấu, P&L/biên lợi nhuận, tỷ giá hoạch định, health score/churn, ghi chú nội bộ, PII nhân sự BC. Mask "điều chỉnh đối soát" áp cho mọi nội dung chảy về phía khách. | Push/preview không bao giờ kèm nội dung bị mask; phát hiện payload portal chứa trường nội bộ → chặn ở tầng API (không chỉ ẩn UI), log sự cố, cảnh báo SYS_ADMIN. |
| BR-006 | **Ví read-only trên mobile (REQ-FIN-017)**: AM xem số dư ví khách view-only kèm nhãn nguồn + timestamp + disclaimer độ trễ (số dư 15 phút–24h tùy nền tảng; chi tiêu daily 3–24h; tiến độ/ticket/lịch nạp realtime). **Cấm tạo lệnh ví trên mọi mobile/portal** — nhất quán Hard Stop không mobile/portal (chống bypass). | Mobile không render nút tạo lệnh; API tạo lệnh từ mobile bị từ chối + audit log. Số tranh chấp hiển thị "Đang đối soát" + số tham chiếu; cấm hiển thị số dư/chi tiêu thiếu timestamp. |
| BR-007 | **Touchpoint rút gọn mobile-portal (counterpart)**: trên SYS-MOBILE-PORTAL khách chỉ thấy 3 nhóm — số dư (read-only), thông báo (push), ticket. Tính năng ngoài 3 nhóm (adoption, dashboard nội bộ, cấu hình) không xuất hiện phía khách. | API portal kiểu nội bộ gọi từ thiết bị khách → RBAC từ chối; audit log ghi nỗ lực vượt biên. |
| BR-008 | **Offline-capable có kiểm soát**: cache dữ liệu đã tải (dashboard, ticket) cho chế độ offline; cache **mã hóa trên thiết bị**, kích thước giới hạn, loại PII nhân sự/credentials khỏi cache; sync + đối chiếu phiên bản khi có mạng. Watermark (tên user + thời điểm) áp cho mọi download/preview từ mobile. | Hết phiên hoặc thiết bị bị đánh dấu mất → cache vô hiệu từ xa (remote wipe), bắt đăng nhập lại; download thiếu watermark bị chặn + log. |
| BR-009 | **Phản hồi khách trên portal** (BR-OPS-5.5): ticket/comment khách đổ về queue hợp nhất CORE (REQ-OPS-009, chống trùng lặp); AM nhận push M-INT; SLA theo ma trận tier×priority (REQ-OPS-008). Khách phản đối số liệu → AM khởi tạo đối soát, portal hiển thị "Đang đối soát". Khiếu nại nghiêm trọng (Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên) leo thang BOD 24h kèm hồ sơ, OPS_PLAN điều phối. | Trượt SLA → cảnh báo leo thang theo REQ-OPS-008; khiếu nại nghiêm trọng quá 24h → cảnh báo đỏ OPS_PLAN + BOD, không dismiss nếu chưa có hành động khắc phục gắn ticket gốc. |
| BR-010 | **Hành động nhạy cảm thêm lớp OTP** (BR-OPS-5.5): thao tác mobile chạm dữ liệu/hành động nhạy cảm phía khách (duyệt thêm user portal, xuất dữ liệu, reset mật khẩu khách) yêu cầu OTP bổ sung ngoài phiên 2FA. | Thiếu OTP → từ chối thao tác, giữ trạng thái, ghi audit log; lặp nỗ lực thất bại → khóa phiên + cảnh báo SYS_ADMIN. |

---

## 4. Phân Quyền

> *Ứng dụng mobile nội bộ (M-INT) — vai theo 18 vai registry; CUSTOMER thao tác trên counterpart portal/mobile-portal, liệt kê để đối chiếu biên.*

| Hành động | OPS_AM | OPS_PLAN | OPS_ADS/CONT/DES/EDIT | SYS_ADMIN | CUSTOMER (portal counterpart) |
|-----------|--------|----------|------------------------|-----------|-------------------------------|
| Xem dashboard adoption theo khách | ✅ (khách mình) | ✅ (toàn bộ phạm vi) | ❌ | ✅ | ❌ (chỉ nội bộ) |
| Nhận push ticket mới/phản hồi khách | ✅ | ✅ | ✅ (ticket đầu việc mình) | ❌ | ❌ |
| Nhận cảnh báo trượt Gate Day 14 | ✅ | ✅ | ❌ | ✅ (kỹ thuật) | ❌ |
| Xem số dư ví khách trên mobile | ✅ view-only | ✅ view-only | ❌ | ✅ view-only | ✅ view-only (M-PORTAL, tenant mình) |
| Tạo lệnh ví (top-up/refund/điều chỉnh) | ❌ (chỉ WEB nội bộ) | ❌ | ❌ | ❌ | ❌ (read-only — REQ-FIN-017) |
| Đề xuất cấp/thu hồi CLIENT_ADMIN | ✅ | ❌ | ❌ | ❌ (không tạo hộ portal user) | ❌ |
| Xác nhận danh tính POC khi cấp CLIENT_ADMIN | ✅ (SLA 1 ngày LV) | ✅ (phối hợp) | ❌ | ❌ | ❌ (CLIENT_ADMIN tự quản user) |
| Tạo/quản lý portal user của khách | ❌ | ❌ | ❌ | ❌ | ✅ (CLIENT_ADMIN, trên PORTAL) |
| Thao tác nhạy cảm (duyệt thêm user, xuất dữ liệu, reset mật khẩu khách) | ✅ + OTP | ❌ | ❌ | ✅ + OTP | ❌ |
| Xem dữ liệu nội bộ (giá vốn, P&L, ghi chú nội bộ) trên mobile | ❌ | ❌ | ❌ | ❌ | ❌ (tuyệt đối — BR-005) |
| Đánh dấu Gate Day 14 đạt | ❌ (hệ thống tự đánh) | ❌ | ❌ | ❌ | ❌ |
| Thu hồi phiên/thiết bị mobile | ❌ | ❌ | ❌ | ✅ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Gate Day 14 trượt do phía khách** (thiếu user kích hoạt, thiếu login/tuần) → hệ thống không tự fail dự án: push đỏ cho AM + OPS_PLAN, escalate root cause lên CS TL trong 24h, kế hoạch khắc phục có owner + deadline; gate vẫn là điều kiện nghiệm thu onboarding tới khi đạt lại tiêu chí.
- **Khách đa nhãn hàng/multi-tenant** → mỗi pháp nhân/nhãn hàng 1 tenant riêng; AM quản nhiều tenant phải chuyển ngữ cảnh tenant tường minh, dashboard tổng không trộn dữ liệu chéo tenant.
- **AM nghỉ việc/đổi phụ trách** → subscription push và assignment ticket chuyển cho AM mới theo handoff (thu hồi quyền trong 24h khi có sự kiện HR — BR-OPS-1.7); dashboard adoption chuyển theo khách, không để cảnh báo "mồ côi".
- **Mất mạng (offline)** → dashboard/ticket hiển thị từ cache mã hóa kèm nhãn "dữ liệu lúc [timestamp] — chưa đồng bộ"; thao tác ghi vào hàng đợi cục bộ, gửi khi có mạng, chống trùng lặp khi retry.
- **Thiết bị mất/đánh cắp** → SYS_ADMIN thu hồi phiên + device token; cache bị vô hiệu; đăng nhập lại trên thiết bị mới yêu cầu 2FA đầy đủ.
- **Khách phản đối số liệu trên portal** → AM nhận push, khởi tạo đối soát; cả portal khách và mobile AM hiển thị "Đang đối soát" + số tham chiếu, không trình bày như số chính thức.
- **Khiếu nại nghiêm trọng ngoài giờ** → push không im lặng theo cấu hình on-call (SLA 4h ngoài giờ); đường leo thang BOD 24h vẫn chạy trên CORE kể cả khi AM chưa mở app.
- **Dữ liệu degraded (nhãn `manual`)** → khi GW thiếu quyền API/connector lỗi, số dư/chi tiêu kèm nhãn nguồn `manual` + disclaimer độ trễ; AM được cảnh báo số liệu có thể lệch đối soát cuối ngày.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Tài khoản portal user (`PortalUserAccount` — đối tượng provisioning chính của tính năng; khách thao tác trên PORTAL/M-PORTAL, nội bộ theo dõi trên WEB/M-INT).

**Sơ đồ trạng thái:**
```
[INVITED] ──(kích hoạt + 2FA)──► [ACTIVE] ──(thu hồi)──► [REVOKED]
    │                               │
    │ (hết hạn invite 7 ngày)       │ (khóa tạm: 5 lần sai mật khẩu / yêu cầu AM)
    ▼                               ▼
[EXPIRED] ──(gửi lại invite)──► [INVITED]      [SUSPENDED] ──(mở khóa)──► [ACTIVE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `INVITED` | Kích hoạt (khách xác nhận email + bật 2FA + đăng nhập đầu tiên) | `ACTIVE` | Chính user được mời | Trong hạn invite; 2FA bật 100% là điều kiện mốc Day 7 |
| `INVITED` | Hết hạn invite | `EXPIRED` | Hệ thống | Quá 7 ngày không kích hoạt — M-INT push nhắc AM |
| `EXPIRED` | Gửi lại invite | `INVITED` | CLIENT_ADMIN (tự quản user) hoặc AM (CLIENT_ADMIN đầu tiên) | Ghi audit log; đếm về lại hạn 7 ngày |
| `ACTIVE` | Khóa tạm | `SUSPENDED` | Hệ thống (5 lần sai mật khẩu) hoặc CLIENT_ADMIN | Lý do khóa ghi audit log |
| `SUSPENDED` | Mở khóa | `ACTIVE` | CLIENT_ADMIN (hoặc AM phối hợp xác minh POC) | Xác minh danh tính xong mới mở |
| `ACTIVE` | Thu hồi | `REVOKED` | AM đề xuất + xác nhận POC (CLIENT_ADMIN); hệ thống tự động khi HR phát sự kiện nghỉ việc liên quan | Căn cứ thu hồi bắt buộc; thu hồi trong 24h khi có sự kiện HR |
| `REVOKED` | Cấp lại | `INVITED` | AM đề xuất như BR-003 | Coi như tài khoản mới; dữ liệu cũ không kế thừa phiên |

**Quy tắc:**
- `REVOKED` là trạng thái kết thúc cho phiên sống — không khôi phục trực tiếp, phải đi lại qua `INVITED`.
- Mọi chuyển trạng thái ghi audit log bất biến (ai, khi nào, từ/sang, căn cứ) — đồng bộ nguyên tắc audit log của CORE.
- Gate Day 14 chỉ tính từ user ở trạng thái `ACTIVE`: tiêu chí ≥1 login/tuần từ ≥2 user không đếm user `INVITED`/`EXPIRED`/`SUSPENDED`/`REVOKED`.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `PortalUserAccount` | `id`, `tenant_id`, `email`, `role_type` (CLIENT_ADMIN/CLIENT_USER), `status`, `two_fa_enabled`, `activated_at` | FK → `tenants.id` | Trạng thái theo Mục 6; số user theo hợp đồng (2+10 mặc định) |
| `PortalInvite` | `id`, `portal_user_id`, `token_hash`, `sent_at`, `expires_at`, `invited_by` | FK → `PortalUserAccount.id` | Hạn 7 ngày; resend tạo invite mới |
| `OnboardingMilestone` | `id`, `tenant_id`, `milestone` (D1/D7/D14/D30), `criteria_json`, `status` (ON_TRACK/PASSED/SLIPPED), `checked_at` | FK → `tenants.id` | Gate D14 machine-checkable, không đánh tay; nguồn cảnh báo M-INT |
| `AdoptionMetric` | `tenant_id`, `date`, `active_users`, `login_count_week`, `two_fa_coverage`, `ticket_via_portal_count` | FK → `tenants.id` | Nguồn dashboard adoption M-INT; snapshot theo ngày |
| `PortalSession` | `id`, `portal_user_id`, `device_id`, `issued_at`, `expires_at`, `revoked_at` | FK → `PortalUserAccount.id` | Hỗ trợ thu hồi phiên/thiết bị từ xa (BR-008) |
| `PushNotificationLog` | `id`, `recipient_staff_id`, `tenant_id`, `type` (ticket/gate/escalation), `payload_masked`, `sent_at`, `read_at` | FK → staff + tenant | Payload không chứa trường nội bộ bị mask (BR-005) |
| `AuditEvent` | `id`, `actor_id`, `tenant_id`, `entity`, `entity_id`, `action`, `from_status`, `to_status`, `reason`, `created_at` | FK → mọi entity trên | Append-only, bất biến |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ ở Phase 2; chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Nhận push ticket mới | AM đã đăng nhập M-INT, khách Tenant X tạo ticket trên portal | Ticket đổ về queue hợp nhất CORE | AM nhận push ≤1 phút, payload không chứa giá vốn/PII nội bộ, deep-link mở được ticket | [ ] |
| SC-002: Gate Day 14 đạt | Khách đạt tiêu chí D14 (xem số dư + chi tiêu + ticket tự phục vụ; ≥1 login/tuần từ ≥2 user `ACTIVE`) | Hệ thống chạy đánh giá ngày Day 14 | Gate đánh dấu PASSED tự động (không đánh tay), AM + OPS_PLAN nhận push xác nhận | [ ] |
| SC-003: Gate Day 14 trượt | Khách chỉ có 1 user `ACTIVE` tính tới Day 14 | Gate evaluation chạy | Trạng thái SLIPPED; push đỏ cho AM + OPS_PLAN; yêu cầu escalate CS TL 24h hiển thị kèm tiêu chí chưa đạt | [ ] |
| SC-004: Số dư view-only kèm disclaimer | View ví REQ-FIN-017 có sẵn | AM mở màn hình số dư trên mobile | Số dư read-only + nhãn nguồn + timestamp + disclaimer độ trễ; thiếu timestamp → không hiển thị số | [ ] |
| SC-005: Offline cache an toàn | M-INT mất mạng sau khi đã tải dashboard | AM mở app offline | Dashboard hiển thị từ cache mã hóa kèm nhãn "dữ liệu lúc [timestamp] — chưa đồng bộ"; sync khi có mạng không tạo bản ghi trùng | [ ] |

> **Liên kết:** SC-001/002/003/005 map REQ-OPS-010 (Mục 2, B.5 — BR-OPS-3.2/5.1); SC-004 map REQ-FIN-017. Chặn tạo lệnh ví từ mobile (BR-006) và tenant isolation (BR-004) được test qua acceptance của Phase 5 + test chéo định kỳ theo BR-OPS-4.2.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/SYS-MOBILE-INTERNAL/MOD-CLIENT-PORTAL/[screen-group].md` |
| Counterpart cùng REQ | `phase2-features/core-backend/client-portal/`, `phase2-features/bcerp-web/client-portal/`, `phase2-features/portal-web/client-portal/`, `phase2-features/mobile-portal/client-portal/` (nếu có trong lane tương ứng) |
