# API Contract — SYS-CORE-BACKEND (Core Backend)

> Session: 20260913-053848-f4d7 | Lane: core-backend | TRIO: architect + dba + devops
> READS: `phase2-features/core-backend/rbac-audit/*.md`, `phase2-features/core-backend/datahub-bi/*.md`, `P3-01-architecture.md` (§1, §5, §6, §8, §10), `lanes/core-backend/arch-draft.md`
> OUTPUT: API conventions, response formats, endpoint registry cho nền tảng identity/audit/analytics
> USED BY: `integration-map.md`, `phase4-ux/core-backend/*`, `phase5-implementation/tasks/core-backend/*`
> DATE: 2026-09-13 | VERSION: v1
>
> **Scope guard:** chỉ MOD-RBAC-AUDIT + MOD-DATAHUB-BI. API nghiệp vụ của 15 business module (lead, ví, TKQC, lệnh chi...) là tài sản canonical của lane khác —Core chỉ cung cấp điểm neo: PDP check, audit append, BI serving. KHÔNG thiết kế lại business API.

---

## 1. Global Conventions

Tham chiếu quy ước platform P3-01 §6: base URL `/api/v1/core/`, Bearer JWT, UUID v4, UTC/ISO 8601, soft delete (`deleted_at`) — riêng audit/WORM bất biến không soft delete, pagination `page/limit` (20/100) server-side, format lỗi `{success, error, code}`, versioning `/api/v1/`, state transition qua `POST /{object}/{id}/transitions`, Idempotency-Key cho money command.

Đặc thù Core Backend bổ sung:

```
Auth:            Access Token JWT TTL 15 phút (đề xuất) + Refresh Token TTL 7 ngày
Claims:          user_id, roles[], dept, data_scope, tenant_id (portal), mfa_level,
                 amr (phương pháp xác thực hiện hành), combined_role (cờ REQ-BOD-002)
MFA step-up:     request tới endpoint lớp tài chính/vault/policy-approve phải mang
                 amr chứa mfa — thiếu → 401 MFA_STEP_UP_REQUIRED, client gọi
                 POST /auth/mfa/step-up rồi retry. Danh sách endpoint bắt buộc step-up
                 đánh dấu [STEP-UP] ở section 6.
Freshness:       mọi response BI mang envelope meta.freshness (mục 2) — client chỉ
                 render khi is_stale=false (P3-01 §10.6)
Correlation ID:  header X-Correlation-ID xuyên suốt; mọi endpoint nhạy cảm ghi audit
```

## 2. Standard Response Envelopes

Envelope chuẩn theo template (`success/data/meta/error/code`). Core thêm 2 envelope riêng:

```typescript
// PDP decision — POST /core/pdp/check
{
  "success": true,
  "data": {
    "decision": "allow" | "deny",
    "scope_filters": { "dept": "FIN", "data_scope": "own-dept", "tenant_id": null },
    "constraints": { "require_mfa": true, "require_dual_approval": true },
    "policy_version": "pv-2026-09-13.3",
    "cache_ttl_seconds": 60
  }
}

// BI payload — GET /core/bi/*
{
  "success": true,
  "data": [ ...rows ],
  "meta": {
    "total": 150, "page": 1, "limit": 20, "totalPages": 8,
    "freshness": {
      "mart": "pnl_realtime", "last_watermark": "2026-09-13T04:32:11Z",
      "loaded_at": "2026-09-13T04:35:02Z", "freshness_sla_minutes": 15,
      "is_stale": false
    }
  }
}
```

## 3. HTTP Status Codes

Chuẩn template (200/201/400/401/403/404/409/429/500/503) + quy ước Core:

| Code | Khi nào — đặc thù Core |
|------|------------------------|
| 401 | Token hết hạn hoặc thiếu MFA step-up cho endpoint lớp `[STEP-UP]` |
| 403 | PDP deny + ghi audit access-denied (bắt buộc, không bỏ qua) |
| 409 | State machine vi phạm: policy chưa approve, campaign đã đóng, alert đã resolved |
| 503 | PDP/KMS/warehouse không phản hồi — action tài chính fail-closed (đề xuất P3-01 §11; chốt fail-open/closed luồng đọc [NEEDS_REVIEW]) |

## 4. Error Codes Registry

Ngoài registry chuẩn template (`VALIDATION_ERROR`, `UNAUTHORIZED`, `TOKEN_EXPIRED`, `FORBIDDEN`, `NOT_FOUND`, `DUPLICATE`, `INVALID_STATE`, `RATE_LIMIT_EXCEEDED`, `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE`), Core định nghĩa:

| Code | HTTP | Mô tả |
|------|------|-------|
| `MFA_STEP_UP_REQUIRED` | 401 | Endpoint bắt buộc step-up, token chưa mang MFA |
| `MFA_ENROLLMENT_REQUIRED` | 403 | Vai tài chính/BOD/SYS_ADMIN chưa đăng ký MFA |
| `SOD_VIOLATION` | 409 | Vi phạm tách nhiệm vụ: tự duyệt, cùng người 2 chân, combined-role thiếu 2 nấc khác người |
| `POLICY_NOT_APPROVED` | 409 | Phiên bản policy chưa được duyệt theo REQ-BOD-009, không thể kích hoạt |
| `AUDIT_IMMUTABLE` | 409 | Cố update/delete bản ghi audit — bị chặn tầng DB + alert |
| `CHAIN_BROKEN` | 500 | Hash chain verify thất bại — severity HIGH, tự sinh alert |
| `PII_MASKED_FIELD` | 200 | Trường PII trả về dạng masked theo vai (không phải lỗi) |
| `BREAK_GLASS_REQUIRED` | 403 | Đọc PII Restricted ngoài vai — phải mở yêu cầu break-glass |
| `CONTRACT_SCHEMA_DRIFT` | 409 | Ingest payload lệch contract version đã đăng ký |
| `MART_STALE` | 200 | Kèm `is_stale=true` — dữ liệu quá freshness SLA, client hiển thị nhãn |

## 5. Authentication Endpoints

Core Backend là IdP duy nhất (COMP-CORE-001, REQ-BOD-011). 5 systems khác là Relying Party; không service nào tự quản password. IdP đề xuất Keycloak 2 realms (realm nội bộ MFA bắt buộc + realm portal OTP) theo FEAT-CORE-RBAC-005 — chốt phương pháp MFA [NEEDS_REVIEW: TOTP/hardware key/passkey].

### API-CORE-001 — POST /api/v1/core/auth/token
```
Request:  { "grant_type": "password"|"authorization_code"|"refresh_token",
            "username", "password", "otp"?, "code"?, "refresh_token"? }
Response 200: { accessToken, refreshToken, expiresIn: 900, tokenType: "Bearer",
                user: { id, email, fullName, roles[], dept, dataScope } }
Error 401: INVALID_CREDENTIALS | MFA_ENROLLMENT_REQUIRED
Ghi audit: login_success / login_failed (IP, user_agent) — FEAT-CORE-RBAC-005
```

### API-CORE-002 — POST /api/v1/core/auth/token/refresh
```
Request: { "refreshToken" } → 200 { accessToken, expiresIn }
Refresh token rotate: token cũ bị revoke ngay khi dùng; replay refresh token
đã dùng → revoke toàn bộ session + alert (phát hiện token theft).
```

### API-CORE-003 — POST /api/v1/core/auth/mfa/step-up `[STEP-UP]`
```
Request: { "otp": "123456", "purpose": "payment_approval"|"vault_access"|
           "policy_approval"|"period_lock" }
Response 200: { verified: true, stepUpValidUntil: "...+5 phút" }
Bắt buộc trước: lệnh tiền, dual approval, vault, HĐĐT, khóa kỳ, duyệt policy
(P3-01 §8.1). Ghi audit step_up_success/failed.
```

### API-CORE-004 — POST /api/v1/core/auth/mfa/enrollments
Bắt đầu đăng ký TOTP (trả provisioning URI + QR); xác nhận bằng lượt verify đầu. Vai tài chính/BOD/SYS_ADMIN bị chặn thao tác cho đến khi enroll xong (`MFA_ENROLLMENT_REQUIRED`).

### API-CORE-005 — POST /api/v1/core/auth/logout
Revoke session hiện hành + refresh token. Server-side session registry là nguồn sự thật (không chỉ xóa cookie).

### API-CORE-006 — GET/DELETE /api/v1/core/auth/sessions
GET: danh sách session active của user hiện tại (device, IP, last_seen). DELETE `/:sessionId`: thu hồi 1 session — hỗ trợ thu hồi tức thời khi offboarding/thu hồi quyền ≤24h (REQ-BOD-011, COMP-CORE-001).

### API-CORE-007 — GET /api/v1/core/auth/.well-known/openid-configuration · /jwks.json
OIDC discovery + bộ khóa công khai cho 5 RP verify token. Public, rate-limit chặt.

### API-CORE-008 — POST /api/v1/core/auth/introspect (internal)
RP/service kiểm tra trạng thái token (active, revocation tức thời). Auth bằng service token.

## 6. Endpoints By System — SYS-CORE-BACKEND

> Mọi endpoint có cột FEAT-ID (traceability bắt buộc theo template) + PERMISSION (vai theo registry: BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1/L2, FIN_L1/L2, SALES_L1–L5, OPS_PLAN/AM/CONT/DES/EDIT/ADS, ESS — chốt danh mục đủ 18 vai [NEEDS_REVIEW]).

### Module: RBAC & Audit Log (MOD-RBAC-AUDIT)

#### 6.1 Identity lifecycle (COMP-CORE-001)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-009 | GET | `/core/users` | SYS_ADMIN | List user + filter role/dept/status, pagination | FEAT-CORE-RBAC-005 / REQ-BOD-011 |
| API-CORE-010 | POST | `/core/users` | SYS_ADMIN | Tạo user (onboarding, trạng thái khởi điểm `probation` — người thử việc không có quyền phê duyệt) | FEAT-CORE-RBAC-005 / REQ-BOD-011 |
| API-CORE-011 | GET | `/core/users/:id` | SYS_ADMIN + chính chủ | Chi tiết user (roles, sessions, MFA state) | FEAT-CORE-RBAC-005 |
| API-CORE-012 | PUT | `/core/users/:id` | SYS_ADMIN | Cập nhật hồ sơ định danh (không đụng credential — thuộc IdP) | FEAT-CORE-RBAC-005 |
| API-CORE-013 | POST | `/core/users/:id/transitions` | SYS_ADMIN (thu hồi: SYS_ADMIN thực thi sau quyết định HR/BOD) | State machine `probation→active→suspended→locked→deactivated`; offboarding thu hồi mọi session + rotate ≤24h | FEAT-CORE-RBAC-005 / REQ-BOD-011 |

#### 6.2 RBAC & Policy Engine — PDP (COMP-CORE-002)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-014 | POST | `/core/pdp/check` | internal (service token, PEP middleware mọi system) | Ra quyết định allow/deny + scope filter + constraints; batch nhiều check 1 lần; cache TTL 60s | FEAT-CORE-RBAC-005 / REQ-BOD-011 |
| API-CORE-015 | GET | `/core/roles` | SYS_ADMIN; BOD_CEO xem | Danh mục vai chuẩn hóa + ma trận Role×Permission×Dept×Data-scope | FEAT-CORE-RBAC-005 / REQ-BOD-011 |
| API-CORE-016 | POST/PUT | `/core/roles` | SYS_ADMIN đề xuất → BOD_CEO duyệt | CRUD role + gắn permission set | FEAT-CORE-RBAC-005 |
| API-CORE-017 | POST | `/core/roles/:id/assignments` | SYS_ADMIN đề xuất → BOD_CEO duyệt | Gán vai cho user; preflight SoD (SOD_VIOLATION nếu trùng 2 chân cấm); set cờ `combined_role` khi 1 người giữ cả vai tài chính + hạ tầng | FEAT-CORE-RBAC-001, 003 / REQ-BOD-002, 007 |
| API-CORE-018 | DELETE | `/core/roles/:id/assignments/:userId` | SYS_ADMIN đề xuất → BOD_CEO duyệt | Thu hồi vai — effective ngay + revoke session liên quan | FEAT-CORE-RBAC-003 / REQ-BOD-007 |
| API-CORE-019 | GET/POST/PUT | `/core/permissions` | SYS_ADMIN; BOD_CEO xem | Catalog permission `resource:action` gắn state guard | FEAT-CORE-RBAC-005 |
| API-CORE-020 | GET/POST | `/core/policies` | Đọc: BOD_CEO, BOD_CFO_CTO, SYS_ADMIN; Draft: SYS_ADMIN | Policy versioned effective-dated: ngưỡng duyệt 5/50/200tr, tier, capacity vàng/đỏ, threshold alert, mask rule | FEAT-CORE-RBAC-004 / REQ-BOD-009 |
| API-CORE-021 | POST | `/core/policies/:id/transitions` `[STEP-UP]` | BOD_CEO + BOD_CFO_CTO dual approval khác người | `draft→submitted→approved→activated→superseded`; audit mọi transition; hiệu lực theo effective_date | FEAT-CORE-RBAC-004 / REQ-BOD-009 |
| API-CORE-022 | POST | `/core/pdp/sod-check` | SYS_ADMIN; internal | Kiểm tra 1 user/gán vai: xung đột SoD, self-approve, combined-role; trả violation list | FEAT-CORE-RBAC-001 / REQ-BOD-002 |
| API-CORE-023 | GET/PUT | `/core/policies/delegates` `[STEP-UP]` | BOD_CEO (delegate CFO), FIN_L2 (delegate FIN) | Delegate map khi vắng — cơ chế delegate khi CFO kiêm CTO vắng [NEEDS_REVIEW: CEO thay nấc hay defer] | FEAT-CORE-RBAC-001, 004 / REQ-BOD-002, FIN-008 |

#### 6.3 Quarterly Access Review (COMP-CORE-003)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-024 | GET/POST | `/core/access-reviews/campaigns` | SYS_ADMIN tạo/mở; BOD_CEO xem | Campaign quý: sinh items từ user×role×dept; tự trigger theo lịch + recertification khi đổi vai/phòng/kiêm nhiệm | FEAT-CORE-RBAC-003 / REQ-BOD-007 |
| API-CORE-025 | GET | `/core/access-reviews/campaigns/:id/items` | SYS_ADMIN + reviewer được phân công (chủ sở hữu vai) | List items chờ review, filter theo dept/role/đặc quyền nhạy cảm (vault CTO, Restricted) | FEAT-CORE-RBAC-003 |
| API-CORE-026 | POST | `/core/access-reviews/items/:id/decisions` | Reviewer phân công `[STEP-UP]` với đặc quyền nhạy cảm | approve / revoke / extend + lý do; revoke thực thi ngay | FEAT-CORE-RBAC-003 / REQ-BOD-007 |
| API-CORE-027 | POST | `/core/access-reviews/campaigns/:id/close` | SYS_ADMIN → BOD_CEO xác nhận | Đóng campaign, đóng gói decision log thành bằng chứng → WORM (API-CORE-031 cùng đường) | FEAT-CORE-RBAC-003, 007 / REQ-BOD-007, FIN-012 |

#### 6.4 Audit Log & WORM (COMP-CORE-004, 005)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-028 | POST | `/core/audit/events` | internal (service token — đường ghi DUY NHẤT mọi module) | Append event: who/what/object/state/before-after/when/ip/correlation_id; hash-chain server-side; không có update/delete | FEAT-CORE-RBAC-002 / REQ-BOD-005 |
| API-CORE-029 | GET | `/core/audit/events` | BOD_CEO (toàn bộ); SYS_ADMIN (vận hành); FIN_L2 (phạm vi tài chính) | Truy xuất có kiểm soát: filter actor/object/time/action, pagination 20/100; mọi lượt query tự ghi audit | FEAT-CORE-RBAC-002 / REQ-BOD-005 |
| API-CORE-030 | GET | `/core/audit/objects/:objectId/timeline` | Theo vai sở hữu object + SYS_ADMIN | Activity timeline per object (feed cho module có timeline: lệnh tiền, TKQC, ticket) | FEAT-CORE-RBAC-002 |
| API-CORE-031 | POST | `/core/audit/export-requests` | Yêu cầu: FIN_L2, SYS_ADMIN, BOD_CEO; Duyệt: BOD_CEO `[STEP-UP]` | Truy xuất có kiểm soát ra evidence package: request → approve → export vào WORM (object-lock ≥10 năm với log tiền/chứng từ) | FEAT-CORE-RBAC-002, 007 / REQ-BOD-005, FIN-012 |
| API-CORE-032 | GET | `/core/audit/chain/verify` | SYS_ADMIN chạy; BOD_CEO xem kết quả | Verify hash chain theo khoảng seq; kết quả + WORM ref integrity; lệch → alert HIGH | FEAT-CORE-RBAC-002, 007 / REQ-BOD-005, FIN-012 |

#### 6.5 PII Field Protection (COMP-CORE-006)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-033 | GET/POST/PUT | `/core/pii/classifications` | SYS_ADMIN quản trị; HR_L2 đồng duyệt với PII lương | Classification registry Public/Internal/Confidential/Restricted + tier C1–C3/T1–T4 gắn field | FEAT-CORE-RBAC-006 / REQ-HR-010 |
| API-CORE-034 | GET/PUT | `/core/pii/mask-configs` | SYS_ADMIN; HR_L2 đồng duyệt | Masking rule theo vai (HR_L1/L2 thấy rõ; ESS chỉ thông tin cá nhân) áp ở API layer + trước khi vào warehouse | FEAT-CORE-RBAC-006 / REQ-HR-010 |
| API-CORE-035 | POST | `/core/pii/break-glass-requests` | Đề xuất: mọi vai; Duyệt: BOD_CEO `[STEP-UP]` | Truy cập khẩn PII Restricted: yêu cầu → duyệt → mở có giờ + audit bắt buộc mọi lượt đọc [NEEDS_REVIEW: quy trình khẩn chưa định nghĩa trong registry — mặc định đề xuất này] | FEAT-CORE-RBAC-006 / REQ-HR-010 |

### Module: Data Integration Hub & BI (MOD-DATAHUB-BI)

#### 6.6 BI Serving (COMP-CORE-010)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-036 | GET | `/core/bi/marts/:martName` | BOD_CEO, BOD_CFO_CTO, FIN_L1/L2 (finance marts); OPS theo scope (ops marts); SYS_ADMIN vận hành | Query mart (wallet, ar_ap, sales_funnel, ops_delivery, people_cost, cs_sla, shop_reference): filter/sort server-side, pagination, freshness metadata; PDP check bắt buộc | FEAT-CORE-DHUB-002, 004 / REQ-BOD-004, FIN-015 |
| API-CORE-037 | GET | `/core/bi/pnl` | BOD_CEO, BOD_CFO_CTO, FIN_L1/L2 | P&L realtime (freshness SLA ≤15 phút theo REQ-BOD-003; đề xuất feed ví ≤5 phút [NEEDS_REVIEW]) + snapshot kỳ so sánh liên kỳ + dòng tách timesheet-chưa-duyệt | FEAT-CORE-DHUB-001, 005 / REQ-BOD-003, FIN-016 |
| API-CORE-038 | GET | `/core/bi/dashboards` · `/:id` | BOD, FIN; layout theo vai | Dashboard registry + định nghĩa widget map vào marts; render chỉ khi `is_stale=false` | FEAT-CORE-DHUB-002, 005 / REQ-BOD-004, FIN-016 |
| API-CORE-039 | POST | `/core/bi/exports` | BOD_CEO, BOD_CFO_CTO, FIN_L1/L2 | Export CSV/PDF async job + audit truy xuất; scheduled snapshot định kỳ | FEAT-CORE-DHUB-004 / REQ-FIN-015 |
| API-CORE-040 | GET | `/core/bi/freshness` | Mọi consumer BI | Freshness per mart: last_watermark, loaded_at, sla, is_stale | FEAT-CORE-DHUB-001 |

#### 6.7 Alert Center (COMP-CORE-011)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-041 | GET/POST | `/core/alerts/rules` | Xem: BOD, FIN, SYS_ADMIN; Tạo: SYS_ADMIN → BOD_CEO duyệt | Rule-based trên marts + event: ví < đủ chi 3 ngày, mismatch đối trừ, aging, die account, shop anomaly, DLQ depth, freshness vi phạm | FEAT-CORE-DHUB-003 / REQ-BOD-006 |
| API-CORE-042 | PUT | `/core/alerts/rules/:id` `[STEP-UP]` khi đổi severity/routing | SYS_ADMIN → BOD_CEO duyệt | Sửa/tắt rule — audit mọi thay đổi | FEAT-CORE-DHUB-003 |
| API-CORE-043 | GET | `/core/alerts/instances` | BOD, FIN, OPS theo severity routing | List alert: filter status/severity/window, pagination | FEAT-CORE-DHUB-003 |
| API-CORE-044 | POST | `/core/alerts/instances/:id/transitions` | Theo severity routing (BOD/FIN/OPS) `[STEP-UP]` severity CRITICAL | Lifecycle `open→acknowledged→investigating→resolved`; không auto-close — người ack (P3-01 §11.5) | FEAT-CORE-DHUB-003 / REQ-BOD-006 |
| API-CORE-045 | GET/PUT | `/core/alerts/routing` | SYS_ADMIN → BOD_CFO_CTO duyệt | Severity → kênh + người nhận; dispatch ủy quyền MOD-SLA-NOTIF (on-call DI-005) | FEAT-CORE-DHUB-003 / REQ-BOD-006 |

#### 6.8 Ingest Admin (COMP-CORE-007, 008)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-046 | GET/POST/PUT | `/core/ingest/contracts` | SYS_ADMIN; module nguồn đề xuất schema | Contract registry versioned (schema + natural key + compatibility mode); drift bị chặn ở gate G0 | FEAT-CORE-DHUB-001 / REQ-BOD-003, FIN-005 |
| API-CORE-047 | GET | `/core/ingest/runs` | SYS_ADMIN; BOD xem freshness | Status run theo nguồn: watermark/LSN, gate pass/fail, DLQ count, freshness vs SLA | FEAT-CORE-DHUB-001 |
| API-CORE-048 | GET/POST | `/core/ingest/dlq` · `/dlq/:id/replay` | SYS_ADMIN (replay ghi audit) | DLQ view + replay là hành động người (không auto-replay — P3-01 §11.4) | FEAT-CORE-DHUB-003 |
| API-CORE-049 | POST | `/core/ingest/backfills` | SYS_ADMIN → CTO (BOD_CFO_CTO) duyệt | Backfill/replay theo window (phối hợp COMP-GW-005 khi nền tảng khôi phục); phát `backfill.completed` | FEAT-CORE-DHUB-001 / REQ-FIN-005 |

## 7. Internal API (Service-to-Service)

> Kiến trúc modular monolith (P3-01 §1): domain services ở SYS-BCERP-WEB gọi PDP/audit qua REST vì Core là service nền tảng riêng, không cùng process. Auth bằng service token (`X-Internal-Token`), timeout 3s/10s heavy query, retry 3 lần backoff.

| Method | Path | Caller | Purpose |
|--------|------|--------|---------|
| POST | `/api/v1/core/pdp/check` | PEP middleware mọi system | Quyết định + scope filter + constraints (API-CORE-014); cache 60s phía PEP, invalidate theo event role/policy change |
| POST | `/api/v1/core/audit/events` | Mọi module (đường ghi duy nhất) | Append audit hash-chain (API-CORE-028); buffer local + retry khi Core chậm — không chặn nghiệp vụ trừ action tài chính |
| POST | `/api/v1/core/auth/introspect` | 5 RP | Verify token + revocation tức thời (API-CORE-008) |

Điểm neo nghiệp vụ nằm ở phía module gốc (canonical thuộc lane khác): lệnh chi gọi PDP pre-check SoD/ngưỡng trước `POST /erp/payment-orders/:id/transitions`; ADACC gọi rule hard stop "đã khớp tiền" qua PDP constraint check (REQ-FIN-006); sweep re-validate tại nguồn vẫn là chính, event chỉ tối ưu.

## 8. Rate Limiting

| Endpoint group | Limit | Window |
|---------------|-------|--------|
| `/core/auth/token`, `/core/auth/mfa/*` | 10 req/IP | 1 phút (login fail ≥5 → lock tạm + alert) |
| `/core/auth/.well-known/*`, `/core/auth/introspect` | 600 req | 1 phút |
| `/core/pdp/check`, `/core/audit/events` (internal) | 5000 req | 1 phút (theo service) |
| `/core/bi/*` | 200 req/user | 1 phút |
| `/core/bi/exports`, `/core/audit/export-requests` | 5 req/user | 1 phút |
| `/core/audit/events` GET (query) | 60 req/user | 1 phút |
| General `/core/*` | 200 req/user | 1 phút |
