# API Contract — SYS-PORTAL-WEB (Client Portal Web)

> Session: 20260913-053848-f4d7 | Lane: portal-web | TRIO: architect + dba + devops
> READS: `phase2-features/portal-web/client-portal/*.md`, `portal-web/wallet-recon/*.md`, `portal-web/campaign-deliverable/*.md`, `portal-web/ticket-cskh/*.md`, `P3-01-architecture.md` (§1, §5, §6, §8), `lanes/portal-web/arch-draft.md`
> OUTPUT: API conventions, response formats, endpoint registry portal client-facing
> USED BY: `integration-map.md`, `phase4-ux/portal-web/*`, `phase5-implementation/tasks/portal-web/*`
> DATE: 2026-09-13 | VERSION: v1
>
> **Scope guard:** chỉ MOD-CLIENT-PORTAL. Ví/campaign/ticket/invoice là **read-model** từ SYS-BCERP-WEB/CORE — portal không tái định nghĩa nghiệp vụ gốc, không có endpoint ghi lên dữ liệu tài chính. Điểm ghi: ticket + comment (REQ-OPS-009), xác nhận nghiệm thu milestone (REQ-OPS-006), account self-service, exports, incidents.

---

## 1. Global Conventions

Tham chiếu quy ước platform P3-01 §6: base URL `/api/v1/portal/`, UUID v4, UTC/ISO 8601, pagination `page/limit` (mặc định 20, max 100) server-side, format lỗi `{success, error, code}`, versioning `/api/v1/`. Đặc thù portal:

```
Auth:            Bearer JWT do COMP-CORE-001 phát hành, audience="portal".
                 Client identity TÁCH internal identity — tài khoản nội bộ đăng nhập
                 portal bị từ chối ngay ở BFF (COMP-PORTAL-002).
Claims:          sub (portal_user id), tenant_id, role (CLIENT_ADMIN|CLIENT_USER),
                 amr (2FA đã verify hay chưa)
Tenant scoping:  tenant_id lấy từ token claim — client KHÔNG được truyền tenant_id
                 ở body/query; mọi query tự gắn filter tenant_id. Dùng tenant_id khác
                 → 403 TENANT_CROSS_ACCESS + log cảnh báo; lặp lại → khóa phiên.
Read-only:       nhóm read-model (wallet/campaign/invoice/freshness) CHỈ GET; method
                 khác → 403 READ_ONLY_VIOLATION. Write giới hạn: ticket (+comment),
                 milestone acceptance, account self-service, exports, incidents.
[OTP]:           marker endpoint hành động nhạy cảm (BR-008 CPORT-002): thêm user,
                 xuất dữ liệu, đổi mật khẩu — phải mang otp_proof còn hạn (5 phút);
                 thiếu → 401 OTP_REQUIRED.
Freshness:       mọi read response bắt buộc meta.freshness — thiếu → client không
                 render số (BR-007 CPORT-001 / BR-004, BR-012).
Correlation ID:  header X-Correlation-ID xuyên suốt; mọi 401/403 ghi portal_access_log.
```

## 2. Standard Response Envelopes

Envelope chuẩn template (`success/data/meta`, lỗi `{success:false,error,code,details}`). Portal thêm envelope freshness bắt buộc cho mọi read-model response:

```typescript
{
  "success": true,
  "data": [ ...rows ],
  "meta": {
    "total": 42, "page": 1, "limit": 20, "totalPages": 3,
    "freshness": {
      "view_group": "wallet_balances",
      "source_label": "api" | "manual" | "recon",   // nhãn nguồn từ GW/CORE, immutable
      "updated_at": "2026-09-13T04:32:11Z",
      "freshness_sla_minutes": 15,     // số dư 15–24h; chi tiêu daily 3–24h; nạp/ticket/tiến độ realtime
      "is_stale": false,
      "disclaimer": "Số dư tham chiếu; số chính thức theo đối soát cuối ngày với platform"
    }
  }
}
```

**Quy tắc mask/whitelist payload (áp dụng mọi endpoint):** payload theo whitelist trường do FIN_L1 duyệt trong view share model (counterpart CORE REQ-FIN-017). Trường giá vốn, chiết khấu, P&L, tỷ giá nội bộ, ghi chú nội bộ, health score/churn **không tồn tại trong payload** — mask ở tầng API (CORE), không chỉ ẩn UI. Giao dịch `DISPUTED` trả `recon_status_display="Đang đối soát"` + `recon_ref`; `ADJUSTED` trả nhãn "Điều chỉnh đối soát" — không trả số tranh chấp như số chính thức.

## 3. HTTP Status Codes

Chuẩn template (200/201/400/401/403/404/409/429/500/503). Đặc thù portal:

| Code | Khi nào — đặc thù portal |
|------|--------------------------|
| 401 | Chưa auth; 2FA chưa verify (`2FA_REQUIRED`); thiếu OTP (`OTP_REQUIRED`) |
| 403 | `TENANT_CROSS_ACCESS`, `READ_ONLY_VIOLATION`, `INTERNAL_IDENTITY_REJECTED`, `DPA_NOT_SIGNED` |
| 409 | `QUOTA_EXCEEDED` (vượt hạn mức user), `INVITE_EXPIRED`, `MILESTONE_WINDOW_CLOSED` |
| 503 | CORE read-view / IdP / watermark service không phản hồi; read-model vẫn trả cache kèm `is_stale=true` khi còn TTL thay vì fail cứng |

## 4. Error Codes Registry

Ngoài registry chuẩn template, portal định nghĩa:

| Code | HTTP | Mô tả |
|------|------|-------|
| `TENANT_CROSS_ACCESS` | 403 | Truy cập dữ liệu ngoài tenant — log cảnh báo, lặp lại khóa phiên (SC-008) |
| `READ_ONLY_VIOLATION` | 403 | Method ghi lên read-model tài chính (SC-005 CPORT-001) |
| `INTERNAL_IDENTITY_REJECTED` | 403 | Tài khoản nội bộ đăng nhập portal — bị từ chối ở BFF |
| `OTP_REQUIRED` / `OTP_INVALID` | 401 / 400 | Thiếu / sai hoặc hết hạn OTP cho hành động nhạy cảm (BR-008) |
| `2FA_REQUIRED` | 401 | Tài khoản chưa bật 2FA — không tồn tại ACTIVE chưa 2FA |
| `QUOTA_EXCEEDED` | 409 | Vượt hạn mức user theo hợp đồng — "liên hệ AM" (BR-003, SC-002) |
| `INVITE_EXPIRED` | 409 | Token invite hết hạn hoặc đã dùng — gửi lại invite mới |
| `DPA_NOT_SIGNED` | 403 | Tenant chưa ký DPA — chặn kích hoạt + xem ví (BR-FIN-605) |
| `WATERMARK_UNAVAILABLE` | 503 | Không tạo được watermark → chặn xuất (BR-011) |
| `MILESTONE_WINDOW_CLOSED` | 409 | Ngoài khung nghiệm thu 3 ngày làm việc — escalate nội bộ theo REQ-OPS-006 |

## 5. Authentication Endpoints

Chi tiết mẫu 2 luồng chính; còn lại theo registry mục 6.

### POST /api/v1/portal/auth/invites/:token/accept
```
Response 200: { success: true, data: { invite: { email_masked, tenant_legal_name,
  role, expires_at }, next_step: "activate" } }
Error 409 INVITE_EXPIRED | 403 DPA_NOT_SIGNED (tenant chưa ký DPA — chặn)
```

### POST /api/v1/portal/auth/invites/:token/activate
```
Request:  { password, otp_code, totp_enrollment: { secret, first_code } }
Điều kiện: token một-lần còn hạn; OTP email xác minh; bật 2FA bắt buộc —
thiếu 2FA → 401 2FA_REQUIRED (không tồn tại ACTIVE chưa 2FA).
Response 201: { success: true, data: { user_id, status: "ACTIVE", tenant_id } }
```

### POST /api/v1/portal/auth/login + POST /api/v1/portal/auth/2fa/verify
```
Login (bước 1): { email, password } → 200 { challenge_id, methods: ["totp","otp"] }
  — internal identity → 403 INTERNAL_IDENTITY_REJECTED; sai liên tục 5 lần → LOCKED tự động
2FA verify (bước 2): { challenge_id, code } → 200 { accessToken, refreshToken, expiresIn, user }
  — refreshToken TTL 12 giờ (đề xuất — cấu hình; session timeout theo BR-005)
```

## 6. Endpoints — SYS-PORTAL-WEB (MOD-CLIENT-PORTAL)

Quy ước cột Permission: `BOTH` = CLIENT_ADMIN + CLIENT_USER; `ADMIN` = chỉ CLIENT_ADMIN; `PUB` = pre-auth (token/challenge). Tenant scoping bắt buộc 100% (mục 1) — không lặp lại từng dòng.

### 6.1 Portal auth & phiên — FEAT-PORTAL-CPORT-002 / FEAT-PORTAL-RBAC-001

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú |
|--------|--------|------|-----------|---------|--------|---------|
| API-PORTAL-001 | POST | `/auth/invites/:token/accept` | PUB | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Token 1 lần; trả email masked |
| API-PORTAL-002 | POST | `/auth/invites/:token/activate` | PUB | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Kích hoạt + OTP + 2FA bắt buộc |
| API-PORTAL-003 | POST | `/auth/login` | PUB | FEAT-PORTAL-CPORT-002 | REQ-OPS-010, REQ-BOD-011 | Bước 1; khóa sau 5 lần sai |
| API-PORTAL-004 | POST | `/auth/2fa/verify` | PUB | FEAT-PORTAL-CPORT-002 | REQ-OPS-010, REQ-BOD-011 | Bước 2; phát access + refresh |
| API-PORTAL-005 | POST | `/auth/otp/requests` | BOTH | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Purpose: SENSITIVE_ACTION / PASSWORD_RESET; kênh gửi OTP [NEEDS_REVIEW: kênh notification — Phụ lục A #3] |
| API-PORTAL-006 | POST | `/auth/otp/verifications` | BOTH | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Trả otp_proof TTL 5 phút |
| API-PORTAL-007 | POST | `/auth/token/refresh` | PUB | FEAT-PORTAL-RBAC-001 | REQ-BOD-011 | Xoay refresh token |
| API-PORTAL-008 | POST | `/auth/logout` | BOTH | FEAT-PORTAL-RBAC-001 | REQ-BOD-011 | Revoke session hiện tại |
| API-PORTAL-009 | POST | `/auth/password/reset-requests` | PUB | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | OTP về email đăng ký/POC |
| API-PORTAL-010 | POST | `/auth/password/resets` | PUB | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Đặt lại xong bắt buộc 2FA |
| API-PORTAL-011 | GET | `/auth/sessions` | BOTH | FEAT-PORTAL-RBAC-001 | REQ-BOD-011 | Danh sách phiên của chính mình |
| API-PORTAL-012 | DELETE | `/auth/sessions/:sessionId` | BOTH | FEAT-PORTAL-RBAC-001 | REQ-BOD-011 | Thu hồi phiên; thu hồi quyền user có hiệu lực tại request kế tiếp (BR-FIN-603 — trong 24h) |

### 6.2 Account self-service (CLIENT_ADMIN tự quản user trong quota) — FEAT-PORTAL-CPORT-002

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú |
|--------|--------|------|-----------|---------|--------|---------|
| API-PORTAL-013 | GET | `/accounts/users` | ADMIN | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Trả kèm quota_used/quota_limit theo role; không lộ gate nội bộ |
| API-PORTAL-014 | POST | `/accounts/users` | ADMIN [OTP] | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Tạo user → sinh invite; vượt quota → 409 QUOTA_EXCEEDED; nội bộ không có đường tạo hộ (SC-003) |
| API-PORTAL-015 | POST | `/accounts/users/:userId/transitions` | ADMIN | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | re_invite (EXPIRED→INVITED, token cũ vô hiệu); unlock (LOCKED→ACTIVE sau xác minh POC); revoke (ACTIVE→DISABLED, giải phóng suất quota); thu hồi CLIENT_ADMIN cần dấu vết xác nhận POC (BR-004) |
| API-PORTAL-016 | GET | `/accounts/me` | BOTH | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Profile + trạng thái 2FA + locale/timezone |
| API-PORTAL-017 | PUT | `/accounts/me/password` | BOTH [OTP] | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Đổi mật khẩu — BR-008 |
| API-PORTAL-018 | GET | `/accounts/tenant` | BOTH | FEAT-PORTAL-CPORT-002 | REQ-OPS-010, REQ-FIN-017 | tenant_ref: legal_name, tier, quota, dpa_signed — không chứa dữ liệu giá nội bộ |

### 6.3 Read-model ví (GET only — read-only tuyệt đối, BR-001 CPORT-001) — FEAT-PORTAL-CPORT-001

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú whitelist/mask |
|--------|--------|------|-----------|---------|--------|------------------------|
| API-PORTAL-019 | GET | `/wallet/adaccounts/balances` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Số dư theo TKQC, per-currency không quy đổi (BR-009); không có fx_snapshot; freshness 15 phút–24h |
| API-PORTAL-020 | GET | `/wallet/spend-daily` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Chi tiêu daily theo TK/campaign; disclaimer hồi tố timezone platform |
| API-PORTAL-021 | GET | `/wallet/transactions` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Whitelist: type, amount, currency, recon_status_display, recon_ref, ts; DISPUTED → "Đang đối soát"; ADJUSTED → "Điều chỉnh đối soát"; không có giá vốn/chiết khấu |
| API-PORTAL-022 | GET | `/wallet/deposits` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Lịch nạp đã thực hiện + kế hoạch cam kết — realtime |
| API-PORTAL-023 | GET | `/wallet/alerts` | BOTH | FEAT-PORTAL-WALLET-001 | REQ-OPS-003, REQ-FIN-017 | Cảnh báo chậm nạp/sắp PAUSE theo mốc cấu hình 15/30 ngày [KXN-22]; trước khi chốt → thông báo trung tính |

### 6.4 Campaign / milestone (GET only + confirm nghiệm thu) — FEAT-PORTAL-CAMP-001

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú |
|--------|--------|------|-----------|---------|--------|---------|
| API-PORTAL-024 | GET | `/campaigns` | BOTH | FEAT-PORTAL-CAMP-001 | REQ-OPS-006 | List campaign + trạng thái + freshness realtime [NEEDS_REVIEW: bộ trường hiển thị khách — Phụ lục A #19] |
| API-PORTAL-025 | GET | `/campaigns/:campaignId` | BOTH | FEAT-PORTAL-CAMP-001 | REQ-OPS-006 | Chi tiết + milestones + khung nghiệm thu còn lại (3 ngày làm việc, nhắc ngày 2, escalate ngày 4) |
| API-PORTAL-026 | POST | `/campaigns/:campaignId/milestones/:milestoneId/acceptance` | BOTH | FEAT-PORTAL-CAMP-001 | REQ-OPS-006 | Ghi nhận quyết định khách `accepted`/`disputed` trong khung 3 ngày — không áp "im lặng = đồng ý"; disputed → gợi ý tạo ticket kèm ref; state machine nghiệm thu thực thi ở CAMP (SYS-BCERP-WEB), portal chỉ tiếp nhận; ngoài khung → 409 MILESTONE_WINDOW_CLOSED |

### 6.5 Ticket (điểm ghi business duy nhất) — FEAT-PORTAL-CSKH-001

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú |
|--------|--------|------|-----------|---------|--------|---------|
| API-PORTAL-027 | GET | `/tickets` | BOTH | FEAT-PORTAL-CSKH-001 | REQ-OPS-009 | Ticket của tenant + trạng thái SLA tier×priority |
| API-PORTAL-028 | GET | `/tickets/:ticketId` | BOTH | FEAT-PORTAL-CSKH-001 | REQ-OPS-009 | Detail + timeline; whitelist — ghi chú nội bộ không vào payload |
| API-PORTAL-029 | POST | `/tickets` | BOTH | FEAT-PORTAL-CSKH-001 | REQ-OPS-009 | Tạo vào queue hợp nhất: `source=PORTAL`, context refs (transaction_id/campaign_id/invoice_id), category; dedupe tầng ERP; khiếu nại nghiêm trọng (Tier D/E, mất tiền, sai sót đối soát, đạo đức) gắn flag escalate BOD 24h kèm hồ sơ (BR-009) |
| API-PORTAL-030 | POST | `/tickets/:ticketId/comments` | BOTH | FEAT-PORTAL-CSKH-001 | REQ-OPS-009 | Comment khách; không đổi state ticket — state machine thuộc CSKH (SYS-BCERP-WEB) |

### 6.6 Invoice (GET only) — FEAT-PORTAL-CPORT-001

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú |
|--------|--------|------|-----------|---------|--------|---------|
| API-PORTAL-031 | GET | `/invoices` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | List invoice của tenant từ ARAP [NEEDS_REVIEW: bộ trường invoice chia sẻ + quy trình duyệt view — Phụ lục A #19; đề xuất áp mô hình FIN_L1 duyệt view ví] |
| API-PORTAL-032 | GET | `/invoices/:invoiceId` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Chi tiết theo whitelist đã duyệt |
| API-PORTAL-033 | GET | `/invoices/:invoiceId/file` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Tải file qua watermark service — log portal_download_log (BR-011) |

### 6.7 Export, incident, meta

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú |
|--------|--------|------|-----------|---------|--------|---------|
| API-PORTAL-034 | POST | `/exports` | BOTH [OTP] | FEAT-PORTAL-CPORT-001 | REQ-FIN-017, REQ-OPS-010 | Scope: wallet_balances/transactions/deposits/invoices; watermark server-side bắt buộc — fail → 503 WATERMARK_UNAVAILABLE, chặn xuất (BR-011) |
| API-PORTAL-035 | GET | `/exports/:exportId` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Trạng thái job + link tải (expires 24h) |
| API-PORTAL-036 | GET | `/meta/freshness` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Tổng hợp freshness các view_group — nguồn cho trang trạng thái khi nguồn trễ/degraded (DI-007) |
| API-PORTAL-037 | POST | `/incidents` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Điểm phát hiện sự cố phía khách (BR-FIN-604) → đẩy incident intake CORE trong 4h đầu, timer 72h theo NĐ 13/2023 + GDPR/DPA |

## 7. Internal API (Service-to-Service)

Prefix `/internal/` — không expose ra DMZ edge; auth service token (`X-Internal-Token`), timeout 3s, retry 3 lần exponential backoff.

| API-ID | Method | Path | Caller → Receiver | Purpose |
|--------|--------|------|-------------------|---------|
| API-PORTAL-038 | POST | `/internal/portal/adoption-events` | COMP-PORTAL-003/004/005 → COMP-PORTAL-006 | Buffer sự kiện adoption (invite/activate/login/create_user/ticket — BR-010), idempotent natural key `(user_id, event_type, ts)`; forward về CORE (event `portal.adoption.*` cho gate Day 1/7/14/30) — portal không giữ số adoption cục bộ |
| API-PORTAL-039 | POST | `/internal/portal/watermark/render` | COMP-PORTAL-002 → COMP-PORTAL-005 | Render watermark (tên user + thời điểm) server-side cho file xuất; fail → chặn xuất |

Lưu ý biên giới outbound (thuộc integration-map, không phải endpoint của lane này): BFF pull read-view `GET /core/portal-views/*` (CORE, RLS + tenant filter + mask); tạo ticket đẩy qua `POST /erp/tickets` (SYS-BCERP-WEB, điểm ghi duy nhất).

## 8. Rate Limiting

| Endpoint group | Limit | Window | Ghi chú |
|----------------|-------|--------|---------|
| `/auth/login`, `/auth/2fa/*`, password reset | 10 req | 1 phút/user | Vượt → 429; sai liên tục 5 lần → LOCKED (BR-005) |
| `/auth/otp/*` | 5 req | 15 phút/user | Chống spam OTP |
| General API (JWT) | 200 req | 1 phút/user | — |
| `/exports` | 5 req | 1 giờ/user | Chống download hàng loạt (anomaly — COMP-PORTAL-005) |
| Read-model ví | 60 req | 1 phút/user | Bảo vệ CORE khỏi polling quá mức (1000+ khách, 2600+ TKQC) |

Hành vi anomaly (quét dữ liệu, thử chéo tenant, download hàng loạt): rate limit → alert; lặp lại → khóa phiên + escalate SYS_ADMIN/FIN_L2 — ghi `portal_anomaly_event` (TBL-PORTAL-009).
