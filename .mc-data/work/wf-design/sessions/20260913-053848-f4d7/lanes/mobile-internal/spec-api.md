# API Contract — SYS-MOBILE-INTERNAL (Mobile BFF)

> READS: `phase2-features/mobile-internal/**/*.md` (30 FEAT touchpoints), `P3-01-architecture.md`, `business-context.md` v4.1, `lanes/mobile-internal/arch-draft.md`
> OUTPUT: API conventions, response formats, endpoint registry của Mobile BFF (COMP-MBI-003) + push consumer (COMP-MBI-004)
> USED BY: `integration-map.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
> DATE: 2026-09-13 | VERSION: v1

> **Biên scope (thin client):** File này CHỈ định nghĩa surface của Mobile BFF (`/api/v1/mbi/*`, port 8084). Mobile BFF là proxy mỏng + shaping view-model — **KHÔNG thiết kế lại business endpoints** của SYS-CORE-BACKEND / SYS-BCERP-WEB; mọi state-transition nghiệp vụ được **ỦY QUYỀN (REFERENCE)** về endpoint backend. Backend tự thực thi lại toàn bộ quy tắc (ngưỡng 5/50/200 triệu, SoD 4 vai, dual approval, delegate, escalation, balance check) bất kể request đến từ mobile hay web — mobile không tự tính, không bypass. Offline queue **CẤM** cho lệnh tiền và phê duyệt tài chính.

---

## 1. Global Conventions

```
Base URL:      /api/v1/mbi   (internal service-to-service: /internal/mbi)
Auth:          Bearer JWT do IdP tập trung phát (COMP-CORE-001) — BFF chỉ verify + pass-through
Device header: X-Device-Id: <uuid> — BẮT BUỘC trên mọi endpoint; device phải ở binding_status = 'active'
Step-up:       X-Step-Up-Token: <otp-scope-token> — bắt buộc cho endpoint có cột MFA = bắt buộc
Content-Type:  application/json
Date format:   ISO 8601 UTC
ID format:     UUID v4
Idempotency:   Header Idempotency-Key (UUID) — BẮT BUỘC cho mọi endpoint Offline = allowed và mọi decision endpoint
Soft delete:   N/A ở BFF (BFF không sở hữu business object; device/offline_outbox xử lý riêng — xem spec-db.md)
```

**Pagination (mọi list endpoint):** `?page=1&limit=20&sort=createdAt&order=desc` — mặc định 20, tối đa 100, server-side filter/sort (shaping do BFF thực hiện trên payload backend, không nhân bản logic).

**Quy ước cột `Offline` trong registry:**
- `allowed (ess)` — thao tác ESS được ghi vào outbox thiết bị khi offline, replay qua `POST /ess/sync` với Idempotency-Key; server timestamp là trọng tài.
- `forbidden` — bắt buộc online; client cấm xếp hàng offline, server từ chối replay loại này (`OFFLINE_NOT_ALLOWED`). Toàn bộ nhóm approval/decision/tiền thuộc loại này.

---

## 2. Standard Response Envelopes

```typescript
// Success — single item
{ "success": true, "data": { ...ViewModel } }

// Success — list + pagination
{ "success": true, "data": [ ... ], "meta": { "total": 150, "page": 1, "limit": 20, "totalPages": 8 } }

// Error
{ "success": false, "error": "...", "code": "MACHINE_READABLE_CODE", "details": [ ... ] }
```

**Bổ sung mobile:** mọi payload read có dữ liệu phân tích (BI, wallet summary) kèm `meta.freshness = { is_stale: boolean, loaded_at: ISO }` từ BI Serving (COMP-CORE-010) — client chỉ render số khi `is_stale = false`, ngược lại hiển thị nhãn "dữ liệu tính đến `<loaded_at>`".

---

## 3. HTTP Status Codes

| Code | Khi nào | Error code thường gặp |
|------|---------|----------------------|
| 200 / 201 | Success | — |
| 400 | Validation | `VALIDATION_ERROR` |
| 401 | Token hết hạn/thiếu | `UNAUTHORIZED`, `TOKEN_EXPIRED` |
| 403 | Thiếu quyền / device chưa binding / thiếu step-up | `FORBIDDEN`, `DEVICE_NOT_BOUND`, `MFA_REQUIRED` |
| 404 | Không tồn tại | `NOT_FOUND` |
| 409 | Conflict state / idempotency trùng khác payload | `INVALID_STATE`, `IDEMPOTENCY_CONFLICT` |
| 426 | App version dưới minimum supported | `VERSION_UNSUPPORTED` |
| 429 | Rate limit | `RATE_LIMIT_EXCEEDED` |
| 500 / 503 | Lỗi server / backend không phản hồi | `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE` |

---

## 4. Error Codes Registry (bổ sung của MBI — ngoài registry chung template)

| Code | HTTP | Mô tả |
|------|------|-------|
| `DEVICE_NOT_BOUND` | 403 | X-Device-Id chưa đăng ký, đã revoke hoặc khác user đang đăng nhập |
| `MFA_REQUIRED` | 403 | Endpoint nhạy cảm thiếu X-Step-Up-Token hợp lệ |
| `STEP_UP_INVALID` | 403 | OTP/step-up token sai hoặc hết hạn |
| `IDEMPOTENCY_CONFLICT` | 409 | Trùng Idempotency-Key nhưng payload khác |
| `IDEMPOTENCY_REPLAYED` | 200 | Replay trùng key + payload — trả kết quả gốc (an toàn cho outbox ESS) |
| `OFFLINE_NOT_ALLOWED` | 403 | Replay outbox chứa action không thuộc nhóm ESS — bị chặn |
| `PUSH_TOKEN_INVALID` | 400 | Push token sai định dạng hoặc không khớp provider |
| `APPROVAL_CONTEXT_INCOMPLETE` | 409 | Backend từ chối quyết định vì context tối thiểu chưa đủ (số tiền, ngưỡng, chứng từ) |
| `VERSION_UNSUPPORTED` | 426 | Phiên bản app dưới minimum — bắt buộc force-update |

---

## 5. Authentication (proxy — REFERENCE, không thiết kế lại)

Mobile là client của SSO/MFA tập trung (REQ-BOD-011). BFF chỉ proxy sang core IdP và bổ sung ràng buộc device binding.

| API-ID | Method | Path | Hành vi | REFERENCE |
|--------|--------|------|---------|-----------|
| API-MBI-001 | POST | `/api/v1/mbi/auth/token` | Proxy đăng nhập → core IdP; thành công thì kiểm tra device binding, sai → `DEVICE_NOT_BOUND` | `POST /core/auth/token` (API-CORE-0xx) |
| API-MBI-002 | POST | `/api/v1/mbi/auth/mfa/step-up` | Proxy MFA step-up (TOTP/OTP) → trả step-up token TTL ngắn dùng cho endpoint MFA bắt buộc | `POST /core/auth/mfa/step-up` (API-CORE-0xx) |
| API-MBI-003 | POST | `/api/v1/mbi/auth/logout` | Revoke session + revoke push token + bảo client purge local cache (remote wipe) | — |

> [NEEDS_REVIEW] Ánh xạ ID `API-CORE-0xx` chính xác chờ spec-api lane core-backend (chạy song song); đồng bộ ở `integration-map.md` Phase 3. Mức step-up cho lệnh tài chính trên mobile: đề xuất OTP bắt buộc (biometric chỉ unlock local) — chờ xác nhận REQ-BOD-011 (Phụ lục A P3-01 #22).

---

## 6. Endpoints By System

> FEAT-ID traceability bắt buộc. FEAT-ID thuộc registry SYS-MOBILE-INTERNAL (30 touchpoints); action endpoint ủy quyền về canonical FEAT phía ERP.

### 6.1 Device & Push (COMP-MBI-001, COMP-MBI-020 — module nền tảng MBI)

| API-ID | Method | Path | Permission | Offline | Mô tả | FEAT-ID |
|--------|--------|------|-----------|---------|-------|---------|
| API-MBI-004 | POST | `/api/v1/mbi/devices` | JWT (mọi vai nội bộ) | forbidden | Đăng ký device: device_id, platform, os/app version, push_token, provider (fcm/apns) → binding 1 user–1 thiết bị | FEAT-MBI-RBAC-002 |
| API-MBI-005 | PUT | `/api/v1/mbi/devices/:deviceId` | JWT + device owner | forbidden | Heartbeat last_seen, cập nhật push_token/app_version | FEAT-MBI-RBAC-002 |
| API-MBI-006 | DELETE | `/api/v1/mbi/devices/:deviceId` | JWT + device owner | forbidden | Revoke binding + vô hiệu push token (mất máy/thiết bị lạ) | FEAT-MBI-RBAC-002 |
| API-MBI-007 | GET | `/api/v1/mbi/devices` | JWT | forbidden | Danh sách thiết bị đã binding của user (state hiển thị cho compensating control) | FEAT-MBI-RBAC-001 |
| API-MBI-008 | GET | `/api/v1/mbi/push-preferences` | JWT | forbidden | Xem preference theo category (approval, sla_warning, sla_breach, wallet_alert, shop_alert, alert_center, ticket, campaign) | FEAT-MBI-SLANOT-001 |
| API-MBI-009 | PUT | `/api/v1/mbi/push-preferences` | JWT | forbidden | Bật/tắt theo category + quiet hours; cấm tắt kênh escalation SLA đỏ (chỉ backend quyết) | FEAT-MBI-SLANOT-001 |
| API-MBI-010 | GET | `/api/v1/mbi/app-config` | Public (payload ký số) | allowed (client cache) | Bootstrap: minimum version, force-update flag, cert pinning pinset version, role-aware surface map | FEAT-MBI-RBAC-002 |

### 6.2 Approval Inbox (COMP-MBI-005, COMP-MBI-006)

| API-ID | Method | Path | Permission | Offline | MFA | Mô tả | FEAT-ID |
|--------|--------|------|-----------|---------|-----|-------|---------|
| API-MBI-011 | GET | `/api/v1/mbi/approvals` | Theo vai: BOD_CEO, BOD_CFO_CTO, FIN_L1/L2, SALES_L2/L3, GM, OPS_AM | forbidden | — | Inbox pending theo vai — BFF aggregate từ approval engine backend, filter `type`, `priority`, pagination | FEAT-MBI-ARAP-001, FEAT-MBI-ARAP-002 |
| API-MBI-012 | GET | `/api/v1/mbi/approvals/:approvalId` | Như trên + assignee | forbidden | — | Context tối thiểu bắt buộc: số tiền, ngưỡng áp dụng, người khởi tạo, chứng từ đính kèm, bước duyệt hiện tại (SoD position) | FEAT-MBI-ARAP-002, FEAT-MBI-WALLET-003 |
| API-MBI-013 | POST | `/api/v1/mbi/approvals/:approvalId/decision` | Như trên | **forbidden** | **bắt buộc** | Body `{ decision: approve|reject, step_up_token, note? }` + Idempotency-Key → ủy quyền transition backend (bảng §6.5); backend tự kiểm ngưỡng/SoD/dual approval | FEAT-MBI-ARAP-001, FEAT-MBI-ARAP-002, FEAT-MBI-WALLET-004 |

### 6.3 Read Surfaces (COMP-MBI-006/007/011/012/017/018/019)

| API-ID | Method | Path | Permission | Offline | Mô tả | FEAT-ID |
|--------|--------|------|-----------|---------|-------|---------|
| API-MBI-014 | GET | `/api/v1/mbi/wallet/summary` | FIN_L1/L2, BOD_CFO_CTO, OPS (góc cảnh báo) | forbidden | Sổ phụ ví rút gọn theo khách + trạng thái cảnh báo số dư đủ chi ≥3 ngày; read-only | FEAT-MBI-WALLET-001, FEAT-MBI-WALLET-002, FEAT-MBI-WALLET-006 |
| API-MBI-015 | GET | `/api/v1/mbi/wallet/aml-flags` | FIN_L1/L2, BOD_CFO_CTO | forbidden | Danh sách flag AML T1–T6 chờ hoàn tiền đúng nguồn; read-only | FEAT-MBI-WALLET-005 |
| API-MBI-016 | GET | `/api/v1/mbi/bi/summary` | BOD_CEO, BOD_CFO_CTO, FIN_L2 | forbidden | P&L rút gọn + BI điều hành + dashboard TC nội bộ; kèm `meta.freshness` (is_stale) | FEAT-MBI-DHUB-001, FEAT-MBI-DHUB-002, FEAT-MBI-DHUB-004, FEAT-MBI-DHUB-005 |
| API-MBI-017 | GET | `/api/v1/mbi/alerts` | BOD, FIN, OPS (theo data-scope) | forbidden | Alert center list (lifecycle open/ack/closed từ COMP-CORE-011) | FEAT-MBI-DHUB-003 |
| API-MBI-018 | POST | `/api/v1/mbi/alerts/:alertId/ack` | Người nhận alert | forbidden | Ack alert (không auto-close) | FEAT-MBI-DHUB-003 |
| API-MBI-028 | GET | `/api/v1/mbi/tickets` | OPS_CONT | forbidden | Ticket queue theo assignee + SLA state | FEAT-MBI-CSKH-001 |
| API-MBI-029 | GET | `/api/v1/mbi/tickets/:ticketId` | OPS_CONT | forbidden | Chi tiết ticket + timeline + SLA timer state | FEAT-MBI-CSKH-001 |
| API-MBI-030 | GET | `/api/v1/mbi/shop-alerts` | OPS_AM, OPS_CONT | forbidden | Alert anomaly TikTok Shop + trạng thái monitoring | FEAT-MBI-TIKTOK-001 |
| API-MBI-031 | GET | `/api/v1/mbi/ad-accounts` | OPS_AM, OPS_CONT | forbidden | Tra cứu nhanh registry TKQC: `?search=`, lifecycle state, die account | FEAT-MBI-ADACC-001 |
| API-MBI-032 | GET | `/api/v1/mbi/portal-accounts` | OPS_AM | forbidden | Trạng thái tài khoản client portal + monitor cấp phát | FEAT-MBI-CPORT-001 |
| API-MBI-033 | GET | `/api/v1/mbi/commission/summary` | SALES (của bản thân), SALES_L2/L3 | forbidden | Hoa hồng theo thực nhận, clawback, quota coverage — read-only | FEAT-MBI-COMM-001 |

### 6.4 ESS — offline-capable (COMP-MBI-015, COMP-MBI-016)

> Offline queue chỉ cho phép nhóm ESS. Replay qua API-MBI-021; mọi bản ghi mang Idempotency-Key sinh tại thời điểm offline + client_timestamp — server timestamp và backend validation là trọng tài (chống chấm hộ). [NEEDS_REVIEW] REQ-HR-003/004/005 chưa có FEAT touchpoint MBI trong registry — thiết kế theo baseline §1 (actor ESS × MOBILE-INTERNAL), chờ bổ sung registry.

| API-ID | Method | Path | Permission | Offline | Mô tả | FEAT-ID |
|--------|--------|------|-----------|---------|-------|---------|
| API-MBI-019 | POST | `/api/v1/mbi/ess/attendance` | ESS (mọi nhân viên) | **allowed (ess)** | Check-in/out; body `{ action, client_timestamp, gps? }` + Idempotency-Key | REQ-HR-003 [NEEDS_REVIEW] |
| API-MBI-020 | GET | `/api/v1/mbi/ess/attendance/today` | ESS | forbidden (cache client) | Trạng thái chấm công hôm nay | REQ-HR-003 [NEEDS_REVIEW] |
| API-MBI-021 | POST | `/api/v1/mbi/ess/sync` | ESS | (chính là replay) | Batch replay outbox: mảng bản ghi offline (attendance/timesheet/leave), trả per-item accepted/rejected + lý do; reject `OFFLINE_NOT_ALLOWED` cho action lạ | FEAT-MBI-CAPTS-001 |
| API-MBI-022 | POST | `/api/v1/mbi/ess/leave-requests` | ESS | allowed (ess) | Tạo đơn nghỉ phép; balance check do HR-CORE thực khi nhận/replay | REQ-HR-004 [NEEDS_REVIEW] |
| API-MBI-023 | GET | `/api/v1/mbi/ess/leave-requests` | ESS | forbidden (cache client) | Danh sách đơn + trạng thái phân cấp duyệt L1→L2 | REQ-HR-004 [NEEDS_REVIEW] |
| API-MBI-024 | POST | `/api/v1/mbi/ess/timesheets` | ESS | allowed (ess) | Nhập/lưu draft + submit timesheet | FEAT-MBI-CAPTS-001 |
| API-MBI-025 | GET | `/api/v1/mbi/ess/timesheets` | ESS | forbidden (cache client) | Timesheet của bản thân + trạng thái duyệt OPS∥HR | FEAT-MBI-CAPTS-001 |
| API-MBI-026 | GET | `/api/v1/mbi/ess/profile` | ESS | forbidden (cache client) | Hồ sơ cá nhân — render theo field-level security backend; PII lương KHÔNG cache thiết bị | REQ-HR-005 [NEEDS_REVIEW] |

### 6.5 Action Proxy — state-transition ủy quyền (các surface quyết định còn lại)

Một endpoint duy nhất giữ BFF mỏng: BFF tra mapping `objectType` → backend transition endpoint và forward nguyên payload (kèm step-up token khi cần). BFF không hiểu và không cache business rule.

| API-ID | Method | Path | Permission | Offline | MFA | FEAT-ID |
|--------|--------|------|-----------|---------|-----|---------|
| API-MBI-027 | POST | `/api/v1/mbi/actions/:objectType/:objectId/transitions` | Theo objectType (bảng dưới) | **forbidden** | bắt buộc với objectType tiền/hợp đồng | FEAT-MBI-CRM-001, FEAT-MBI-QDD-001, FEAT-MBI-QDD-002, FEAT-MBI-HONB-001, FEAT-MBI-HONB-002, FEAT-MBI-PROPLN-001, FEAT-MBI-CAMP-001, FEAT-MBI-CAMP-002, FEAT-MBI-CSKH-001 |

Mapping `objectType` → backend (REFERENCE, path khung theo P3-01 §5):

| objectType | Backend endpoint (khung) | Canonical FEAT (ERP) |
|------------|--------------------------|----------------------|
| `crm_gate` | POST `/api/v1/erp/crm/leads/:id/gate-decisions` | FEAT-ERP-CRM-* (Gate 1/2) |
| `qdd_discount` | POST `/api/v1/erp/qdd/quotations/:id/approvals` | FEAT-ERP-QDD-* (duyệt GM) |
| `contract_esign` | POST `/api/v1/erp/qdd/contracts/:id/esign` | FEAT-ERP-QDD-* (e-sign HĐ/LOI/NDA) |
| `handoff_ack` | POST `/api/v1/erp/honb/handoffs/:id/ack` | FEAT-ERP-HONB-* (ops_ack) |
| `proposal_gate` | POST `/api/v1/erp/propln/proposals/:id/gate-decisions` | FEAT-ERP-PROPLN-* (stage-gate V6.0) |
| `deliverable` | POST `/api/v1/erp/camp/deliverables/:id/transitions` | FEAT-ERP-CAMP-* (tick/nghiệm thu) |
| `ticket` | POST `/api/v1/erp/tickets/:id/transitions` | FEAT-ERP-CSKH-* (reply/resolve) |
| `payment_order` | POST `/api/v1/erp/arap/payment-orders/:id/transitions` | FEAT-ERP-ARAP-002 (duyệt chi — dùng chung với API-MBI-013) |
| `wallet_adjustment` | POST `/api/v1/erp/wallet/adjustments/:id/transitions` | FEAT-ERP-WALLET-* (dual approval) |
| `wallet_hard_stop` | POST `/api/v1/erp/wallet/hard-stops/:id/confirm` | FEAT-ERP-WALLET-* (hard stop FIN_L1) |

> [NEEDS_REVIEW] ID `API-ERP-0xx` chính xác của từng dòng chờ spec-api lane bcerp-web (chạy song song) — đồng bộ ở `integration-map.md` Phase 3.

---

## 7. Internal API (Service-to-Service)

| API-ID | Method | Path | Caller | Purpose | FEAT-ID |
|--------|--------|------|--------|---------|---------|
| API-MBI-034 | POST | `/internal/mbi/push/dispatch` | COMP-ERP-006 (sla.warning/sla.breach), COMP-CORE-011 (alert.raised), COMP-GW-013 (shop.alert) | Nhận sự kiện notification (user target, category, deep_link surface) → Push Gateway đẩy FCM/APNs; consumer idempotent theo event_id; mất push không làm vỡ SLA | FEAT-MBI-SLANOT-001 |

Auth: `X-Internal-Token` service-to-service; timeout 3s; retry 3 lần backoff; payload phải mang `event_id` để dedup.

---

## 8. Rate Limiting

| Endpoint group | Limit | Window |
|----------------|-------|--------|
| Auth (`/mbi/auth/*`) | 10 req | 1 phút |
| `POST /ess/sync` | 30 req | 1 phút |
| `POST /app-config` | 60 req | 1 phút |
| General `/api/v1/mbi/*` | 200 req | 1 phút / device |
| Decision (`approvals/decision`, `actions/*/transitions`) | 60 req | 1 phút / user |
| Internal `/internal/mbi/*` | 1000 req | 1 phút |
