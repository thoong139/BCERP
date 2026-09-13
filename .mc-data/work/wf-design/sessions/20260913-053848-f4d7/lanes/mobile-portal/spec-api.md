# API Contract — SYS-MOBILE-PORTAL (Mobile App BC Portal)

> READS: `phase2-features/mobile-portal/**/*.md` (FEAT-MPO-WALLET-001, FEAT-MPO-CAMP-001, FEAT-MPO-SLANOT-001, FEAT-MPO-CSKH-001, FEAT-MPO-CPORT-001), `P3-01-architecture.md`, `lanes/mobile-portal/arch-draft.md`
> OUTPUT: Endpoint registry của Portal Mobile BFF (COMP-MPO-002, port 8085, prefix `/api/v1/mpo/*`)
> USED BY: `technical-specs/integration-map.md`, `phase4-ux/mobile-portal/*`, `phase5-implementation/tasks/mobile-portal/*`
> DATE: 2026-09-13 | VERSION: v1

> **Vị trí trong kiến trúc:** Mobile portal là thin client client-facing (CLIENT_ADMIN/CLIENT_USER). BFF không owns dữ liệu nghiệp vụ: READ path ủy quyền xuống read-model API dùng chung SYS-PORTAL-WEB (view đã lọc tenant, RLS + filter API 2 lớp — REQ-FIN-017), WRITE path chỉ 4 nhóm phi tài chính (ticket, confirm nghiệm thu, quản lý portal user, cấu hình push) và luôn forward xuống PORTAL-WEB/CORE xử lý. **Không tồn tại endpoint ghi dữ liệu ví** — request ghi tài chính bị chặn 403 + log bảo mật (BR-008 wallet).

---

## 1. Global Conventions

```
Base URL:      /api/v1/mpo (DMZ, phía sau Portal API Gateway)
Auth:          Bearer JWT portal user (SSO/2FA từ CORE-BACKEND — COMP-CORE-001);
               claims: user_id, tenant_id, portal_role (CLIENT_ADMIN|CLIENT_USER), locale, timezone
Content-Type:  application/json
Date format:   ISO 8601 UTC; app hiển thị song song giờ địa phương tenant + GMT+7
ID format:     UUID v4
Danh tính:     Tài khoản nội bộ BCERP bị Portal API Gateway từ chối (SC-010) — chỉ portal user
Pagination:    ?page=1&limit=20 (max 100), sort, order — server-side filter bắt buộc
Idempotency:   Header `Idempotency-Key` bắt buộc cho mọi POST ghi (ticket, comment, CSAT, confirm)
ETag:          Mọi GET trả ETag; app gửi If-None-Match để tiết kiệm băng thông
Freshness:     Mọi payload số liệu bắt buộc kèm `freshness: { last_updated, data_source: api|manual, is_stale }`;
               thiếu metadata → app không render (BR-005 wallet, BR-MPO-CAMP-008)
```

**Tenant scoping (2 lớp):** BFF forward `tenant_id` từ token; mọi truy vấn qua view đã lọc tenant của PORTAL-WEB (RLS DB + filter API tầng CORE). Kết quả không khớp tenant → 403 + audit; không tiết lộ sự tồn tại dữ liệu. Tenant switcher chỉ liệt kê tenant được gán (claim `tenants[]`).

**Mask whitelist (cấm xuất hiện trong mọi payload):** giá vốn, chiết khấu, P&L/margin, tỷ giá nội bộ, ghi chú nội bộ, AML/KYC/UBO, health score/churn, PII nhân sự, trạng thái escalation nội bộ, chuỗi SLA nội bộ. Dòng điều chỉnh gắn giá vốn trả `display_type: "Điều chỉnh đối soát"` + `masked_fields[]`.

## 2. Standard Response Envelopes

Theo template chung (`{ success, data, meta }` / `{ success, error, code, details }`). Riêng list notification/ticket kèm `meta.unread_count`.

## 3. HTTP Status Codes & 4. Error Codes Registry

Theo template chung. Bổ sung MPO-specific:

| Code | HTTP | Ý nghĩa |
|------|------|---------|
| `FINANCIAL_WRITE_FORBIDDEN` | 403 | Request ghi dữ liệu tài chính từ mobile — chặn tầng gateway + log bảo mật (P0) |
| `QUOTA_EXCEEDED` | 409 | Vượt hạn mức portal user theo hợp đồng ("liên hệ AM") |
| `INVITE_EXPIRED` | 410 | Token invite quá 7 ngày hiệu lực mặc định |
| `OTP_REQUIRED` / `OTP_INVALID` | 403 | Thiếu/sai lớp OTP cho hành động nhạy cảm |
| `ACCOUNT_LOCKED` | 423 | Sai mật khẩu/OTP 5 lần — khóa mọi thiết bị |
| `DPA_NOT_SIGNED` | 409 | Tenant EU/US chưa có cờ DPA — chặn kích hoạt (BR-FIN-605) |

## 5. Authentication Endpoints

Ủ quyền: phiên SSO/2FA thực thi tại CORE-BACKEND (COMP-CORE-001) + provisioning portal user của PORTAL-WEB (`API-PORTAL-001`, `API-PORTAL-002` — [NEEDS_REVIEW: số thứ tự ID do lane PORTAL-WEB chốt]).

| API-ID | Method | Path | Mô tả | FEAT-ID |
|--------|--------|------|-------|---------|
| API-MPO-001 | POST | `/api/v1/mpo/auth/activate` | Kích hoạt invite (token một-lần) + xác minh OTP + bắt buộc bật 2FA; chặn khi tenant chưa DPA | FEAT-MPO-CPORT-001 |
| API-MPO-002 | POST | `/api/v1/mpo/auth/login` | Đăng nhập portal user (email + password + 2FA); sai 5 lần → `ACCOUNT_LOCKED`; tài khoản nội bộ bị từ chối (SC-010) | FEAT-MPO-CPORT-001 |
| API-MPO-003 | POST | `/api/v1/mpo/auth/otp` | Gửi OTP step-up cho hành động nhạy cảm (quản lý user, đổi mật khẩu, xuất dữ liệu) | FEAT-MPO-CPORT-001 |
| API-MPO-004 | POST | `/api/v1/mpo/auth/otp/verify` | Xác minh OTP step-up | FEAT-MPO-CPORT-001 |
| API-MPO-005 | POST | `/api/v1/mpo/auth/password-reset` | Quên mật khẩu qua OTP email/POC; sau đó bắt buộc bật lại 2FA | FEAT-MPO-CPORT-001 |
| API-MPO-006 | POST | `/api/v1/mpo/auth/logout` | Thu hồi phiên hiện tại + push token thiết bị gọi | FEAT-MPO-CPORT-001 |

## 6. Endpoints By System

### SYS-MOBILE-PORTAL — Portal Mobile BFF (COMP-MPO-002)

#### 6.1. Hồ sơ & Portal Account (MOD-CLIENT-PORTAL)

| API-ID | Method | Path | Auth | Permission | Ủy quyền xuống | FEAT-ID |
|--------|--------|------|------|-----------|----------------|---------|
| API-MPO-007 | GET | `/api/v1/mpo/me` | JWT | mọi portal user | `API-PORTAL-0xx` (portal_user view) | FEAT-MPO-CPORT-001 |
| API-MPO-008 | PUT | `/api/v1/mpo/me/preferences` | JWT | mọi portal user | `API-PORTAL-0xx` | FEAT-MPO-CPORT-001 |
| API-MPO-009 | GET | `/api/v1/mpo/portal-users` | JWT | CLIENT_ADMIN | `API-PORTAL-0xx` | FEAT-MPO-CPORT-001 |
| API-MPO-010 | POST | `/api/v1/mpo/portal-users/invites` | JWT + OTP | CLIENT_ADMIN | `API-PORTAL-0xx` (provisioning CORE) | FEAT-MPO-CPORT-001 |
| API-MPO-011 | POST | `/api/v1/mpo/portal-users/:id/invites/resend` | JWT + OTP | CLIENT_ADMIN | `API-PORTAL-0xx` | FEAT-MPO-CPORT-001 |
| API-MPO-012 | POST | `/api/v1/mpo/portal-users/:id/disable` | JWT + OTP | CLIENT_ADMIN | `API-PORTAL-0xx` + revoke session/push ngay | FEAT-MPO-CPORT-001 |
| API-MPO-013 | POST | `/api/v1/mpo/sessions/revoke-all` | JWT | CLIENT_ADMIN (mình) / POC | `API-PORTAL-0xx` | FEAT-MPO-CPORT-001 |

Quota 2 CLIENT_ADMIN + 10 CLIENT_USER (mặc định, theo tier) kiểm tra phía CORE — vượt → `QUOTA_EXCEEDED`. App không tăng quota. State machine portal user (INVITED→ACTIVE→LOCKED/DISABLED) thực thi ở CORE; BFF chỉ hiển thị.

#### 6.2. Thiết bị & Push (MOD-SLA-NOTIF)

| API-ID | Method | Path | Auth | Permission | Ghi chú | FEAT-ID |
|--------|--------|------|------|-----------|---------|---------|
| API-MPO-014 | POST | `/api/v1/mpo/devices` | JWT | mọi portal user | Đăng ký push token, binding user+tenant+platform | FEAT-MPO-SLANOT-001 |
| API-MPO-015 | PUT | `/api/v1/mpo/devices/:id` | JWT | chủ thiết bị | Opt-in + mức cảnh báo nhận + giờ im lặng (chỉ áp Low/Medium) | FEAT-MPO-SLANOT-001 |
| API-MPO-016 | DELETE | `/api/v1/mpo/devices/:id` | JWT | chủ thiết bị / CLIENT_ADMIN | Revoke token (soft), không ảnh hưởng thiết bị khác | FEAT-MPO-SLANOT-001 |
| API-MPO-017 | GET | `/api/v1/mpo/notifications` | JWT | mọi portal user | Inbox in-app; tách theo tenant đang chọn | FEAT-MPO-SLANOT-001 |
| API-MPO-018 | POST | `/api/v1/mpo/notifications/:id/read` | JWT | mọi portal user | Ghi read_at (AlertNotification) | FEAT-MPO-SLANOT-001 |

REQ-IDs: REQ-OPS-008, REQ-OPS-010. Token thu hồi ngay khi user DISABLED/LOCKED/logout (worker xử lý — không endpoint khách).

#### 6.3. Ví read-only (MOD-WALLET-RECON) — không có endpoint ghi

| API-ID | Method | Path | Auth | Permission | Ủy quyền (read-model dùng chung) | FEAT-ID |
|--------|--------|------|------|-----------|--------------------------------|---------|
| API-MPO-019 | GET | `/api/v1/mpo/wallet/summary` | JWT | mọi portal user | `API-PORTAL-0xx` (PortalWalletView) | FEAT-MPO-WALLET-001 |
| API-MPO-020 | GET | `/api/v1/mpo/wallet/spend` | JWT | mọi portal user | `API-PORTAL-0xx` (daily spend, runway, mức XVĐ per TKQC) | FEAT-MPO-WALLET-001 |
| API-MPO-021 | GET | `/api/v1/mpo/wallet/transactions` | JWT | mọi portal user | `API-PORTAL-0xx` (PortalAdjustmentHistoryView, mask) | FEAT-MPO-WALLET-001 |
| API-MPO-022 | GET | `/api/v1/mpo/wallet/statement-link` | JWT | CLIENT_ADMIN | Trả URL deep-link Portal Web tải sổ phụ PDF watermark + `portal_download_log` | FEAT-MPO-WALLET-001 |

REQ-IDs: REQ-OPS-003 (+ REQ-FIN-002, REQ-FIN-017). USD/VND tách sổ — không có trường tổng quy đổi; lệnh `PENDING`/`STEP1_APPROVED` trả trong khối `pendingApprovals` riêng, không cộng vào `availableBalance`. Mask giá vốn → "Điều chỉnh đối soát". Disclaimer độ trễ 15 phút–24h + nhãn `api`/`manual` bắt buộc kèm mọi con số.

#### 6.4. Campaign & Confirm nghiệm thu (MOD-CAMPAIGN-DELIVERABLE)

| API-ID | Method | Path | Auth | Permission | Ghi chú | FEAT-ID |
|--------|--------|------|------|-----------|---------|---------|
| API-MPO-023 | GET | `/api/v1/mpo/campaigns` | JWT | mọi portal user | Chỉ campaign có bản ghi share + `wbs_node_ref` hợp lệ | FEAT-MPO-CAMP-001 |
| API-MPO-024 | GET | `/api/v1/mpo/campaigns/:id` | JWT | mọi portal user | Milestone progress; không lộ SLA duyệt nội bộ | FEAT-MPO-CAMP-001 |
| API-MPO-025 | POST | `/api/v1/mpo/campaigns/:id/milestones/:mid/confirm` | JWT + step-up 2FA/biometric | **CLIENT_ADMIN** | Forward PORTAL/CORE; milestone phải đang chờ confirm | FEAT-MPO-CAMP-001 |
| API-MPO-026 | POST | `/api/v1/mpo/campaigns/:id/milestones/:mid/revision` | JWT | CLIENT_ADMIN/CLIENT_USER | Yêu cầu chỉnh sửa + comment bắt buộc | FEAT-MPO-CAMP-001 |

REQ-ID: REQ-OPS-006. Chỉ 2 hành động ghi này tồn tại trên campaign — hết 3 ngày làm việc app chỉ nhắc/hiện escalate, không tự "đạt" (không "im lặng = đồng ý").

#### 6.5. Ticket & CSAT (MOD-TICKET-CSKH)

| API-ID | Method | Path | Auth | Permission | Ghi chú | FEAT-ID |
|--------|--------|------|------|-----------|---------|---------|
| API-MPO-027 | GET | `/api/v1/mpo/tickets` | JWT | mọi portal user | SLA target read-only, song song múi giờ | FEAT-MPO-CSKH-001 |
| API-MPO-028 | GET | `/api/v1/mpo/tickets/:id` | JWT | mọi portal user | Không lộ chuỗi escalation nội bộ | FEAT-MPO-CSKH-001 |
| API-MPO-029 | POST | `/api/v1/mpo/tickets` | JWT | mọi portal user | `source=portal(mobile)`; CORE dedupe → trả ticket hiện có nếu trùng | FEAT-MPO-CSKH-001 |
| API-MPO-030 | POST | `/api/v1/mpo/tickets/:id/comments` | JWT | mọi portal user | Phản hồi chính thức, resume clock do CORE quyết | FEAT-MPO-CSKH-001 |
| API-MPO-031 | POST | `/api/v1/mpo/tickets/:id/reopen` | JWT | mọi portal user | Chỉ trong 7 ngày kể từ Closed | FEAT-MPO-CSKH-001 |
| API-MPO-032 | POST | `/api/v1/mpo/tickets/:id/csat` | JWT | mọi portal user | 1–5 + 1 câu mở; một CSAT/ticket; nhắc ≤1 lần/48h | FEAT-MPO-CSKH-001 |

REQ-ID: REQ-OPS-009. Mọi ghi forward queue hợp nhất của CORE (`POST /erp/tickets` — điểm ghi duy nhất, P3-01 §5); mobile không sở hữu state machine ticket.

#### 6.6. Cấu hình app

| API-ID | Method | Path | Auth | Ghi chú | FEAT-ID |
|--------|--------|------|------|---------|---------|
| API-MPO-033 | GET | `/api/v1/mpo/app-config` | Public (không chứa dữ liệu user) | Min-version gating (force update), deep-link base, bản text disclaimer | FEAT-MPO-CPORT-001 |

## 7. Internal API (Service-to-Service)

BFF (PEP phụ trợ) gọi nội bộ, không expose ra public:

| Method | Path | Caller | Purpose |
|--------|------|--------|---------|
| GET | `/api/v1/portal/*` (read-model) | mpo-bff | Toàn bộ read path — view đã lọc tenant dùng chung PORTAL-WEB |
| POST | `/api/v1/portal/*` (forward ghi phi tài chính) | mpo-bff | Ticket/confirm/user admin — CORE enforce quyền + state machine |
| POST | `/core/pdp/check` | mpo-bff | Xác minh quyền portal user trước khi forward (cache TTL 60s) |
| — | queue consumer | mpo-push-worker | Tiêu thụ event SLANOT/PORTAL (`sla.*`, `portal.*`, chuyển mức ví) → fan-out FCM/APNs |

Mobile app KHÔNG gọi trực tiếp SYS-INTEGRATION-GW hay SYS-CORE-BACKEND — mọi request qua BFF.

## 8. Rate Limiting

| Endpoint group | Limit | Window |
|---------------|-------|--------|
| `/mpo/auth/*` | 10 req | 1 phút |
| `/mpo/wallet/*`, `/mpo/campaigns/*`, `/mpo/tickets/*` (GET) | 200 req | 1 phút |
| POST ghi (ticket/comment/csat/confirm/invites) | 30 req | 1 phút |
| `/mpo/app-config` | 60 req | 1 phút |

---

### [NEEDS_REVIEW] — tổng hợp

1. Số thứ tự chính xác `API-PORTAL-0xx` được ủy quyền — lane SYS-PORTAL-WEB song song chốt; BFF bind theo tên endpoint, mapping điền khi portal spec-api hợp nhất (Phụ lục A #23 — ownership Portal API Gateway dùng chung).
2. Công nghệ 2FA/OTP (TOTP/SMS/email) — quyết chung với CORE-BACKEND (Phụ lục A #9).
3. Invoice trên mobile: baseline §1 khách "nhận invoice" nhưng spec CPORT không liệt kê màn invoice — chờ xác nhận scope trước khi thêm endpoint.
4. Mức cảnh báo mở rộng ngoài Xanh/Vàng/Đỏ [KXN-20], PAUSE non-payment 15/30 ngày [KXN-22], kênh gửi CSAT [KXN-15] — chỉ ảnh hưởng payload hiển thị, không đổi shape API.
