# Architecture Draft — SYS-MOBILE-PORTAL (Mobile App BC Portal)

> Lane: system/mobile-portal | Session 20260913-053848-f4d7 | Baseline: business-context.md v4.1 + feature-digest SYS-MOBILE-PORTAL (5 touchpoints) + specs gốc mobile-portal/.

## 1. Vai trò client-facing mobile + biên giới

SYS-MOBILE-PORTAL là app di động dành riêng cho khách hàng — **thin client, touchpoint rút gọn của Client Portal**, phục vụ actor "Khách hàng (external client)" trong baseline §1 (PORTAL-WEB + MOBILE-PORTAL, module owner MOD-CLIENT-PORTAL). Triết lý dùng: "mở ra nhìn 30 giây" (số dư, thông báo, ticket) và "xử lý việc nhẹ" (confirm nghiệm thu, trả lời ticket).

Biên giới kiến trúc:
- **Không chứa business logic, không có read-model riêng, không owns dữ liệu nghiệp vụ.** Mọi số liệu là machine-state đọc từ CORE-BACKEND qua view tổng hợp đã lọc tenant dùng chung với PORTAL-WEB (REQ-FIN-017).
- **Trust boundary riêng**: app chạy ngoài mạng công ty; chỉ portal user tenant (CLIENT_ADMIN/CLIENT_USER) đăng nhập được — tài khoản nội bộ BCERP bị Portal API Gateway từ chối (SC-010); vai OPS_*/FIN_* không có tài khoản trên app, thao tác đầy đủ ở hệ nội bộ.
- **Tài chính read-only tuyệt đối**: không tồn tại nút/endpoint ghi dữ liệu ví để loại nguy cơ bypass (spec ví BR-008, CPORT BR-002 — lỗi kiến trúc P0 nếu vi phạm).
- 5 touchpoints: FEAT-MPO-WALLET-001, FEAT-MPO-CAMP-001, FEAT-MPO-SLANOT-001, FEAT-MPO-CSKH-001, FEAT-MPO-CPORT-001.

## 2. Components & trách nhiệm

| Component | Loại | Module | Trách nhiệm chính | Phụ thuộc |
|---|---|---|---|---|
| COMP-MPO-001 — BC Portal Mobile App | app | MOD-CLIENT-PORTAL | Màn tổng hợp; ví read-only USD/VND tách sổ + disclaimer độ trễ 15 phút–24h; lịch sử lệnh mask giá vốn ("Điều chỉnh đối soát"); tiến độ nghiệm thu + confirm nhẹ; ticket tạo/comment/CSAT; invite/activate/2FA; CLIENT_ADMIN quản portal user (OTP); offline cache chỉ đọc; che số dư khi background | SYS-PORTAL-WEB, SYS-CORE-BACKEND |
| COMP-MPO-002 — Portal Mobile BFF | bff | MOD-CLIENT-PORTAL | Shape dữ liệu mobile từ view dùng chung PORTAL-WEB; forward tenant context (isolation RLS + filter API 2 lớp); field whitelist/mask (giá vốn, chiết khấu, P&L, AML/KYC); endpoint push token (MobileDevice); phiên SSO/2FA, timeout, khóa 5 lần sai, thu hồi từ xa; chặn ghi tài chính 403 + log | SYS-PORTAL-WEB, SYS-CORE-BACKEND |
| COMP-MPO-003 — Portal Push Worker | push-worker | MOD-SLA-NOTIF | Tiêu thụ sự kiện SLA-NOTIF/PORTAL (ví chuyển mức ≤5 phút từ sync, phản hồi ticket, nghiệm thu chờ confirm); fan-out FCM/APNs; body push chỉ loại sự kiện, không số liệu; token registry gắn user+tenant, revoke khi DISABLED; opt-in per-thiết bị; fallback in-app inbox | SYS-PORTAL-WEB, SYS-CORE-BACKEND |

## 3. Business layer: client xem gì trên mobile, quyền theo tier

- **Ví read-only** (FEAT-MPO-WALLET-001): available/frozen theo tiền gốc — USD và VND là 2 sổ độc lập, cấm màn cộng tổng quy đổi; chi tiêu daily + số ngày chạy dự kiến + mức Xanh/Vàng/Đỏ per TKQC/nền tảng do engine CORE tính (ADS 7 ngày rolling), app chỉ render; lệnh đang dual approval (PENDING/STEP1_APPROVED) hiện khối "Chờ phê duyệt" riêng, không đổi số dư khả dụng; trạng thái đối soát mức khách (Đã/Đang đối soát); deep-link Portal Web tải sổ phụ PDF watermark (CLIENT_ADMIN).
- **Campaign/deliverable** (FEAT-MPO-CAMP-001): tiến độ theo milestone, confirm nghiệm thu nhẹ — phê duyệt phi tài chính duy nhất trên app; đồng hồ song song giờ địa phương khách + GMT+7.
- **Ticket** (FEAT-MPO-CSKH-001): tạo/comment/theo dõi vào queue hợp nhất REQ-OPS-009; SLA tier×priority GMT+7 từ SLANOT; CSAT sau Closed; khiếu nại Tier D/E escalate BOD 24h (app chỉ hiện trạng thái).
- **Portal account** (FEAT-MPO-CPORT-001): invite → activate + 2FA (state machine INVITED→ACTIVE→LOCKED/DISABLED thực thi ở CORE); CLIENT_ADMIN thêm/thu hồi user trong hạn mức theo tier (mặc định 2 admin + 10 user); gate Day 14 đo từ login thực — app không lộ tín hiệu gate nội bộ.
- Quyền ghi trên app chỉ 4 nhóm: ticket, confirm nghiệm thu, quản lý portal user, cấu hình push. Còn lại read-only.

## 4. Data ownership: chỉ device/push token/cache

SYS-MOBILE-PORTAL chỉ sở hữu dữ liệu kỹ thuật phía thiết bị: encrypted local cache (gắn nhãn "dữ liệu cũ", không cho thao tác trên cache), push token + cấu hình opt-in per-device, device id/session. Toàn bộ entity nghiệp vụ (Wallet, WalletTransaction, portal_user, portal_invite, ticket, push_notification, portal_access_log, portal_download_log) thuộc CORE-BACKEND/PORTAL-WEB; app tiêu thụ qua view (PortalWalletView, PortalAdjustmentHistoryView). Không có chế độ ghi offline — mọi thao tác khách phải có vết thời gian thực trên CORE.

## 5. Giao tiếp

- **Read path**: app → COMP-MPO-002 → read-model API/Portal API Gateway dùng chung với PORTAL-WEB (view đã lọc tenant, RLS + filter API 2 lớp). Freshness metadata (last_updated, data_source api/manual — DI-007) là điều kiện render; gateway chặn mọi endpoint ghi tài chính (403 + log bảo mật).
- **Identity**: SSO/2FA client identity từ CORE-BACKEND; hai danh tính portal user và tài khoản nội bộ không trộn lẫn.
- **Push**: SLANOT phát sự kiện (ví chuyển mức, ticket, nghiệm thu) qua PORTAL-WEB/CORE → COMP-MPO-003 fan-out FCM/APNs. Push không phải nguồn sự thật — deep-link luôn fetch fresh sau 2FA.
- Registry cross-system của các FEAT-MPO liệt kê cả SYS-INTEGRATION-GW/SYS-BCERP-WEB/SYS-MOBILE-INTERNAL — đó là đỉnh shared-feature, **không phải call path trực tiếp từ app**.

## 6. Quy ước kỹ thuật đề xuất

- Cross-platform 1 codebase (Flutter/React Native); BFF cùng stack PORTAL-WEB, stateless scale ngang.
- Bảo mật: sinh trắc học/PIN, che số dư khi background/screenshot app switcher, session timeout, khóa sau 5 lần sai, đăng xuất từ xa toàn bộ thiết bị, watermark mọi tệp tải về + log download bất biến.
- API: pagination limit 20/max 100, ETag, disclaimer + timestamp bắt buộc trên mọi con số; multi-currency giữ đơn vị gốc.
- Deep-link chuẩn hóa push → screen sau 2FA; min-version gating cho force update; tenant switcher chỉ liệt kê tenant được gán.

## 7. Rủi ro & trade-offs + [NEEDS_REVIEW]

- **Rủi ro lộ số dư** (lock screen, screenshot, mất thiết bị) → push payload chỉ loại sự kiện + che background + thu hồi từ xa; vi phạm là lỗi nghiệm thu chặn release.
- **Cache stale gây tranh chấp đối soát** → nhãn "dữ liệu cũ"/"số dư tham chiếu" + nguồn + timestamp bắt buộc; push không suy diễn trạng thái.
- **Độ trễ push cảnh báo ví (≤5 phút từ sync)** phụ thuộc pipeline PORTAL-WEB/CORE → worker stateless, monitor riêng cho pipeline.
- **Trade-off**: thêm 1 hop BFF mỏng so với gọi thẳng gateway — chấp nhận để giữ mobile tách khỏi CORE và tập trung whitelist/mask một chỗ.
- [NEEDS_REVIEW] Ownership của **Portal API Gateway** dùng chung PORTAL-WEB/MOBILE-PORTAL: spec nói "dùng chung" nhưng chưa gán owner system — cần chốt ở lane SYS-PORTAL-WEB (BFF mobile có thể là adapter của gateway chung).
- [NEEDS_REVIEW] **Invoice trên mobile**: baseline §1 khách "nhận invoice" nhưng spec CPORT không liệt kê màn invoice — xác nhận scope hiển thị hóa đơn.
- [NEEDS_REVIEW] **Công nghệ 2FA/OTP** (TOTP/SMS/email) chưa chỉ định trong spec — chọn provider cần quyết thiết kế chung với CORE-BACKEND.
- [NEEDS_REVIEW] Các KXN mở ảnh hưởng hiển thị, không đổi kiến trúc: [KXN-15] kênh gửi CSAT, [KXN-20] mức cảnh báo mở rộng, [KXN-22] PAUSE non-payment 15/30 ngày.
