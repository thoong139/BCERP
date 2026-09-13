# Architecture Draft — SYS-PORTAL-WEB (Client Portal Web)

> Session 20260913-053848-f4d7 | Lane: system | $APPROACH = Platform Design, LEGACY_MODE=false
> Module sở hữu duy nhất: MOD-CLIENT-PORTAL (scope guard CORE-006 — không thêm module).
> REQ nền: REQ-FIN-017 (ví read-only), REQ-OPS-010 (cấp tài khoản + monitor gate Day 14). Baseline: business-context.md v4.1.

## 1. Vai trò client-facing + biên giới (trust boundary ngoài)

SYS-PORTAL-WEB là bề mặt web duy nhất mà khách hàng của BC Agency (vai CUSTOMER: CLIENT_ADMIN, CLIENT_USER) đăng nhập trực tiếp. System nằm **ngoài trust boundary nội bộ**: tách network zone (DMZ) khỏi SYS-BCERP-WEB nội bộ, chỉ giao tiếp với hệ sinh thái qua Portal API Gateway riêng và các read-view đã lọc tenant của SYS-CORE-BACKEND — không bao giờ chạm DB nội bộ.

Đặc điểm nhận diện của biên giới này:

- **Read-only tuyệt đối** lên dữ liệu tài chính (BR-001, FEAT-PORTAL-CPORT-001): không có endpoint ghi nào lên ví/lệnh/đối soát; mọi thay đổi số dư do nội bộ thực hiện theo policy ví (REQ-FIN-001/002/003). Điểm ghi duy nhất của portal là tạo ticket vào queue hợp nhất (REQ-OPS-009).
- **Identity tách biệt**: portal user chỉ tồn tại cho CUSTOMER; tài khoản nội bộ đăng nhập portal bị từ chối ngay ở gateway. OPS_AM, OPS_CONT, FIN_L1/L2… không dùng portal — họ thao tác counterpart trên WEB nội bộ.
- **Điểm phát hiện sự cố phía khách** (BR-FIN-604): báo cáo sự cố từ portal → incident intake CORE, timer 72h theo NĐ 13/2023 + GDPR/DPA.
- 7 feature touchpoints của system (RBAC-SSO, ví, campaign, SLA, ticket, 2× client-portal) quy về 1 module sở hữu: các touchpoint còn lại chỉ là **bề mặt tiêu thụ read-model** từ module owner (WALLET, CAMP, CSKH, SLANOT ở SYS-BCERP-WEB) — portal không tái định nghĩa nghiệp vụ gốc.

## 2. Components & trách nhiệm

| Component | Loại | Trách nhiệm chính | Phụ thuộc |
|-----------|------|-------------------|-----------|
| COMP-PORTAL-001 — Portal Web App | app | SPA client-facing; i18n đa ngôn ngữ/múi giờ; render bắt buộc kèm freshness metadata; watermark download; luồng invite/kích hoạt/2FA/OTP; CLIENT_ADMIN tự quản user trong hạn mức | COMP-PORTAL-002 |
| COMP-PORTAL-002 — Portal API Gateway / BFF | bff | Cổng API duy nhất trong DMZ; session + rate limit; scoping tenant_id bắt buộc mọi request; chặn route ghi tài chính; từ chối internal identity; tổng hợp response | SYS-CORE-BACKEND, COMP-PORTAL-003/004/005 |
| COMP-PORTAL-003 — Portal Identity & Account Service | service | Sở hữu portal_user/portal_invite/session; lifecycle tài khoản; 2FA + OTP lớp 2; khóa 5 lần sai; kiểm tra quota + cờ dpa_signed; thu hồi trong 24h | SYS-CORE-BACKEND |
| COMP-PORTAL-004 — Portal Read-Model Serving Service | service | Pull/cache read-view từ CORE: ví read-only, đối soát mức khách, lịch nạp, campaign/milestone nghiệm thu, ticket, invoice; gắn nhãn nguồn + timestamp + disclaimer | SYS-CORE-BACKEND, SYS-BCERP-WEB, COMP-PORTAL-003 |
| COMP-PORTAL-005 — Portal Audit, Watermark & Anomaly Service | service | portal_access_log + portal_download_log append-only hash-chain; watermark server-side bắt buộc; phát hiện quét dữ liệu/download hàng loạt/chéo tenant → rate limit + alert | SYS-CORE-BACKEND, COMP-PORTAL-002 |
| COMP-PORTAL-006 — Portal Adoption Event Forwarder | service | Forward sự kiện kích hoạt/login/tạo user/ticket về CORE cho AM monitor gate Day 1/7/14/30; portal không giữ số adoption cục bộ; tiếp nhận báo cáo sự cố khách → intake CORE | SYS-CORE-BACKEND, COMP-PORTAL-003 |

## 3. Business layer: lifecycle tài khoản, read-model, quyền theo tier

**Lifecycle tài khoản portal** (state machine theo FEAT-PORTAL-CPORT-002 §6; transition thực thi ở CORE, portal là nơi khách hành động và thấy trạng thái):

- `INVITED` (token một-lần, hạn mặc định 7 ngày — chốt khi cấu hình) → `ACTIVE` khi chính user kích hoạt + OTP + bật 2FA. Không tồn tại `ACTIVE` chưa 2FA.
- `ACTIVE` → `LOCKED` (sai mật khẩu/OTP 5 lần, tự động) → mở khóa sau xác minh danh tính/POC. `ACTIVE` → `DISABLED` khi thu hồi/offboard (thu hồi trong 24h theo BR-FIN-603); `DISABLED` là trạng thái kết thúc, giải phóng suất quota.
- **Ai cấp**: CLIENT_ADMIN đầu tiên do OPS_AM tạo + gửi invite từ WEB nội bộ (mốc Day 1); các user sau do CLIENT_ADMIN **tự tạo** trong hạn mức hợp đồng (mặc định 2 ADMIN + 10 USER, mở rộng theo tier); nội bộ/SYS_ADMIN không có đường tạo hộ — vi phạm là audit fail.
- **Gate Day 14** là trạng thái của tenant, tính từ dữ liệu activation thực (khách tự xem được số dư + chi tiêu + ticket; ≥1 login/tuần từ ≥2 user); không ai chốt tay; trượt → escalate CS TL trong 24h, OPS_PLAN điều phối kế hoạch khắc phục có owner + deadline. Gate là điều kiện nghiệm thu onboarding.

**Read-model client thấy** (portal share model; FIN_L1 duyệt bộ trường chia sẻ ở counterpart CORE/WEB):

1. **Ví read-only**: số dư theo TKQC (theo loại tiền lệnh nạp, không quy đổi), chi tiêu daily theo TK/campaign, trạng thái đối soát mức khách (`DISPUTED` hiển thị "Đang đối soát" + số tham chiếu; `ADJUSTED` hiển thị "Điều chỉnh đối soát"), lịch nạp đã thực hiện + kế hoạch cam kết (realtime).
2. **Campaign/deliverable**: tiến độ nghiệm thu theo milestone (nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate ngày 4 — REQ-OPS-006). [NEEDS_REVIEW: bộ trường campaign/deliverable hiển thị cho khách chưa có spec portal riêng — cần chốt với OPS khi thiết kế view.]
3. **Ticket**: tạo/comment/xem trạng thái theo SLA tier×priority; khiếu nại nghiêm trọng (Tier D/E, mất tiền, sai sót đối soát, đạo đức) leo thang BOD 24h kèm hồ sơ.
4. **Invoice (ARAP)**: business context §3 xác nhận portal nhận invoice từ ARAP. [NEEDS_REVIEW: bộ trường invoice chia sẻ + quy trình duyệt view chưa có spec — đề xuất áp mô hình FIN_L1 duyệt view ví.]

**Quyền theo tier**: tenant.tier điều khiển hạn mức user mở rộng, SLA priority và escalation path; khách đa pháp nhân = mỗi pháp nhân 1 tenant riêng. [NEEDS_REVIEW: ma trận tier → quota/SLA số liệu cụ thể chưa chốt trong registry — đưa vào cấu hình, không hardcode.]

## 4. Data ownership

Portal **chỉ sở hữu**: `portal_user`, `portal_invite`, session/token 2FA-OTP, `portal_access_log`, `portal_download_log` (append-only, hash-chain), và bản ghi tham chiếu `tenant` (legal_name, contract_no, tier, quota, dpa_signed) do CORE provisioning cấp — dùng để chặn kích hoạt khi chưa ký DPA.

Business data (`wallet_transaction`, campaign/deliverable, ticket, invoice, ledger/đối soát) — **source of truth thuộc module owner ở SYS-BCERP-WEB** (WALLET, CAMP, CSKH, ARAP); portal chỉ đọc qua view tổng hợp đã lọc tenant + mask từ CORE, cache TTL ngắn gắn freshness metadata, không lưu bản sao lâu dài. `onboarding_gate_log` sở hữu ở CORE (tính từ dữ liệu tổng hợp, không chốt tay). Giá vốn, chiết khấu, P&L, tỷ giá nội bộ, health score/churn không bao giờ xuất hiện trong payload portal (mask tầng API, không chỉ ẩn UI).

## 5. Giao tiếp

- **AuthN/AuthZ**: SSO tập trung từ SYS-CORE-BACKEND (touchpoint FEAT-PORTAL-RBAC-001). Client identity khác internal identity — đề xuất OIDC/OAuth2 với audience riêng cho portal; 2FA là điều kiện `ACTIVE`; internal account bị từ chối ở gateway.
- **Read-model**: pull-based qua Portal API Gateway → CORE read-views (đã RLS + tenant_id filter + mask). Đề xuất polling + cache TTL theo cadence từng loại dữ liệu (số dư 15 phút–24h, chi tiêu daily 3–24h, lịch nạp/ticket/tiến độ realtime). [NEEDS_REVIEW: nếu CORE cung cấp event stream thì chuyển sang event-driven invalidation — cần xác nhận capability của CORE.]
- **Isolation tenant**: 2 lớp — RLS PostgreSQL + filter tenant_id tầng API (thực thi ở CORE); portal tự bảo vệ ở BFF (scoping bắt buộc, thử chéo tenant → 403 + log cảnh báo, lặp lại → khóa phiên + escalate SYS_ADMIN/FIN_L2). Một user chỉ thuộc 1 tenant; không gộp dữ liệu chéo.
- **Điểm ghi duy nhất**: ticket/comment từ portal → queue hợp nhất REQ-OPS-009 ở CORE (dedupe, SLA tier×priority, AM nhận push M-INT); phản hồi nội bộ hiển thị lại cho khách trên portal.
- **Telemetry outbound**: adoption events → CORE (COMP-PORTAL-006); báo cáo sự cố → intake CORE timer 72h.
- **Share model chung**: SYS-MOBILE-PORTAL (mobile rút gọn: số dư, thông báo, ticket) tái dùng cùng view portal — portal chỉ bảo đảm BFF contract ổn định, không thiết kế riêng cho mobile.
- **SLANOT**: notification hiển thị trên portal tiêu thụ engine REQ-OPS-008 qua CORE; portal không tự gửi kênh nội bộ.

## 6. Quy ước kỹ thuật đề xuất

- SPA (React/Next) host CDN, domain riêng; BFF Node.js (NestJS) trong DMZ; PostgreSQL schema riêng cho account/session/log; Redis cho session + rate limit + cache TTL ngắn.
- Không endpoint ghi tài chính (route whitelist); freshness metadata là điều kiện render (thiếu → không render số); watermark server-side bắt buộc mọi download; log append-only hash-chain; mã hóa at rest/in transit cho dữ liệu mức Restricted (BR-FIN-603, PDPA).
- i18n + múi giờ per-user (GMT+7 mặc định); tham số nghiệp vụ đưa vào cấu hình: mốc cảnh báo 15/30 ngày [KXN-22], hạn invite, hạn mức user theo tier.
- Test bắt buộc: tenant isolation (SC-001/SC-008), mask giá vốn (SC-002), watermark (SC-004), read-only tuyệt đối (SC-005), gate Day 14 từ dữ liệu thực (SC-004/005 của CPORT-002).

## 7. Rủi ro & trade-offs

| # | Rủi ro / trade-off | Giảm thiểu |
|---|--------------------|------------|
| 1 | Read-model lệch pha số chính thức → khách phản đối nhầm | Disclaimer + timestamp bắt buộc; `DISPUTED` hiển thị đúng trạng thái + số tham chiếu; ghim mốc số chốt đối soát |
| 2 | Pull polling tăng tải CORE (1000+ khách, 2600+ TKQC) | Cache TTL + giới hạn tần suất; theo dõi khi mở rộng; cân nhắc event-driven nếu CORE hỗ trợ |
| 3 | Rò rỉ dữ liệu chéo tenant — sự cố nghiêm trọng nhất | Test isolation bắt buộc; alert + khóa phiên; meta-log điều tra FIN_L2; review ma trận hằng quý |
| 4 | Nội bộ lỡ tay tạo hộ user (tiện nhưng mất kiểm soát) | Không có đường tạo hộ, audit fail — chấp nhận chậm hơn khi CLIENT_ADMIN vắng (trade-off có chủ đích của BR-004) |
| 5 | Portal phụ thuộc availability của CORE (SSO + read-view) | Chấp nhận single source of truth; hiển thị trang trạng thái thay vì số cũ |

**Tổng hợp [NEEDS_REVIEW]:** (1) bộ trường campaign/deliverable hiển thị cho khách; (2) bộ trường invoice + quy trình duyệt view invoice; (3) ma trận tier → quota/SLA; (4) cơ chế sync read-model (polling vs event stream) cần xác nhận capability CORE; (5) các tham số chờ cấu hình: [KXN-22] mốc 15/30 ngày, hạn invite 7 ngày.
