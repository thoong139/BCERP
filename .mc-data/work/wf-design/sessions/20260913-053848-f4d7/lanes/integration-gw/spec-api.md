# API Contract — SYS-INTEGRATION-GW (API Integration Gateway)

> READS: `phase2-features/integration-gw/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` (FEAT-GW-STGW-001 / REQ-BOD-008), `phase2-features/integration-gw/settings-gw/api-7-nen-tang-degraded-mode-manual.md` (FEAT-GW-STGW-002 / REQ-FIN-005), `phase2-features/integration-gw/tiktok-shop/tiktok-shop-monitoring.md` (FEAT-GW-TIKTOK-001 / REQ-OPS-011), `P3-01-architecture.md`
> OUTPUT: API conventions, response formats, endpoint registry của SYS-INTEGRATION-GW
> USED BY: `integration-map.md`, `phase4-ux/bcerp-web/settings-gw|tiktok-shop/` (counterpart console), `phase5-implementation/tasks/integration-gw/`
> DATE: 2026-09-13 | VERSION: v1 | Scope: MOD-SETTINGS-GW + MOD-TIKTOK-SHOP

---

## 1. Global Conventions

```
Base URL:      /api/v1/gw
Auth:          Bearer JWT (SSO tập trung COMP-CORE-001) — claims: user_id, roles[], dept, data_scope, client_type
Content-Type:  application/json
Date format:   ISO 8601 (2026-09-13T10:30:00Z) — UTC
ID format:     UUID v4; mã nghiệp vụ code (vd CN-META-01) theo sequence
Soft delete:   KHÔNG áp dụng cho vault/audit/statement (immutable); connection_profile dùng status, không xóa
Pagination:    ?page=1&limit=20 (default 20, max 100) — server-side filter/sort bắt buộc
State machine: transition qua endpoint tường minh POST /{object}/{id}/transitions — guard role + state + audit mỗi lần
```

**Quy tắc đặc thù gateway (bắt buộc):**

1. **MFA step-up (REQ-BOD-008):** mọi thao tác ghi lên vault (`/vault/*` POST/PUT) và transition kết nối yêu cầu header `X-MFA-Step-Up: <token>` do COMP-CORE-001 cấp (TOTP, TTL 5 phút, một lần dùng). Thiếu/hết hạn → 403 `MFA_REQUIRED`. Gateway không tự dựng MFA — chỉ verify claim.
2. **CẤM mobile cho vault (BR-GW-STGW-005):** JWT claim `client_type=mobile_internal` trúng bất kỳ path `/gw/vault/*` hoặc `/gw/connections/*/transitions` → 403 `MOBILE_VAULT_FORBIDDEN` + ghi cảnh báo bảo mật vào `gateway_audit`. Mobile chỉ gọi được health/statement/shop-alert (read-only).
3. **Mask-only (BR-GW-STGW-002):** không tồn tại endpoint trả plaintext credential; mọi response chỉ chứa `masked_value` (vd `****last4`) + metadata.
4. **Nhãn nguồn `api`/`manual` (BR-FIN-205a):** gắn tại thời điểm ghi, immutable; record thiếu nhãn hoặc (với `manual`) thiếu `entered_by` + `evidence_ref` bị reject.
5. **Không quy đổi tỷ giá:** statement giữ nguyên `amount_original` + `currency`; snapshot tỷ giá ở core (REQ-FIN-004).

## 2. Standard Response Envelopes

Chuẩn dùng chung toàn platform (xem template root): `{ success, data, meta }` và lỗi `{ success, error, code, details }`. Bổ sung của GW:

```typescript
// Vault response — mask-only
{ "success": true, "data": {
    "id": "uuid", "profileId": "uuid",
    "maskedValue": "****a1b2", "keyId": "kms-key-ref",   // không có trường secret
    "issuedAt": "...", "rotateDueAt": "...", "status": "active" } }

// Import response — chặn lỗi theo dòng (BR-FIN-205b)
{ "success": true, "data": { "batchId": "uuid",
    "totalRows": 100, "acceptedRows": 97, "rejectedRows": 3,
    "rowErrors": [ { "row": 14, "code": "SCHEMA_FIELD_MISSING",
                     "field": "reference_code", "message": "..." } ] } }
```

## 3. HTTP Status Codes

Chuẩn dùng chung (200/201/400/401/403/404/409/429/500/503) + case riêng GW:

| Code | Khi nào |
|------|---------|
| 403 `MOBILE_VAULT_FORBIDDEN` | Request vault từ touchpoint mobile (BR-GW-STGW-005) |
| 403 `MFA_REQUIRED` | Thiếu step-up MFA hợp lệ cho thao tác vault/transition |
| 409 `NATURAL_KEY_DUPLICATE` | Trùng khóa tự nhiên statement/metric (platform+TKQC/shop+ngày+loại+mã tham chiếu) |
| 409 `JOB_OVERLAP` | Job sync chồng lấn cùng adapter (BR-GW-STGW-008) |
| 422 `SCHEMA_ROW_REJECTED` | Dòng import sai schema — trả lỗi theo dòng, batch vẫn nhận dòng hợp lệ |
| 423 `CREDENTIAL_LOCKED` | Profile đang REVOKED — cấm nạp token mới tại chỗ, phải qua revoke trước |

## 4. Error Codes Registry (bổ sung GW)

| Code | HTTP | Mô tả |
|------|------|-------|
| `CONNECTOR_NOT_IN_REGISTRY` | 400 | Tạo/kích hoạt connector ngoài registry Settings (BR-GW-STGW-001) |
| `LABEL_MISSING` | 422 | Record ingest thiếu nhãn `api`/`manual` (BR-FIN-205a) |
| `EVIDENCE_MISSING` | 422 | Record `manual` thiếu `entered_by`/`evidence_ref` (BR-FIN-205c) |
| `MAPPING_NOT_FOUND` | 422 | Thiếu FieldMapping cho trường — dòng vào hàng lỗi, không suy diễn (BR-FIN-STGW-004) |
| `GATE2_NOT_SIGNED` | 409 | Pull shop trước tín hiệu Gate 2 (BR-OPS-4.5) |
| `OAUTH_EXPIRED` | 423 | OAuth shop hết hạn — dừng pull, không retry bằng credential cũ (BR-OPS-4.1b) |
| `PII_SESSION_REQUIRED` | 403 | Đọc trường PII ngoài phiên TTL (BR-OPS-4.2a) |
| `REFERENCE_ONLY_VIOLATION` | 409 | Attempt mapping GMV vào doanh thu — chặn tầng API (BR-OPS-4.4) |
| `AUDIT_IMMUTABLE` | 405 | Không có API sửa/xóa audit entry (BR-GW-STGW-007) |

## 5. Authentication & MFA Step-Up (phụ thuộc SYS-CORE-BACKEND)

Gateway KHÔNG sở hữu login/refresh — dùng chung IdP core (`POST /core/auth/token`, `POST /core/auth/mfa/step-up`). Gateway chỉ: verify JWT + gọi PDP (cache TTL 60s), verify `X-MFA-Step-Up` cho path nhạy cảm, phân biệt `client_type` để cấm mobile vault. Mọi access-denied ghi audit.

## 6. Endpoints By System — SYS-INTEGRATION-GW

> FEAT-ID traceability: FEAT-GW-STGW-001 (REQ-BOD-008), FEAT-GW-STGW-002 (REQ-FIN-005; cross REQ-FIN-013, REQ-FIN-004), FEAT-GW-TIKTOK-001 (REQ-OPS-011).

### 6.1. Module: Settings & Gateway Config (MOD-SETTINGS-GW)

#### Connection Profile & Lifecycle (FEAT-GW-STGW-001)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|--------|------|------|-------------|--------|
| API-GW-001 | GET | `/gw/connections` | JWT | List profile, filter `platform,status,connection_type` | REQ-BOD-008 |
| API-GW-002 | POST | `/gw/connections` | JWT+CTO | Tạo profile vendor-agnostic (platform enum, connection_type `api_adapter`\|`import_export`) | REQ-BOD-008, REQ-FIN-013 |
| API-GW-003 | GET | `/gw/connections/:id` | JWT | Chi tiết profile + credential version hiện tại (mask) | REQ-BOD-008 |
| API-GW-004 | PUT | `/gw/connections/:id` | JWT+CTO | Cập nhật config (endpoint, môi trường, owner) | REQ-BOD-008 |
| API-GW-005 | POST | `/gw/connections/:id/transitions` | JWT+MFA | State machine: activate / mark_degraded / disable / revoke / reactivate | REQ-BOD-008 |
| API-GW-006 | GET | `/gw/connections/:id/health` | JWT | Health check + data_freshness + rotate_due của profile | REQ-BOD-008 |
| API-GW-024 | GET | `/gw/health` | JWT | Aggregate 7 adapter + freshness + scheduler state (BCERP-WEB tiêu thụ) | REQ-BOD-008, REQ-FIN-005 |

**API-GW-005 — transition contract:**
```
Request:  { "action": "activate|mark_degraded|disable|revoke|reactivate",
            "reason": "string (bắt buộc cho disable/revoke)",
            "trigger": { "type": "manual|system", "jobId": "uuid?", "errorCode": "string?" } }
Guard:    activate/reactivate → credential active trong vault + MFA + health check đầu tiên OK (CTO);
          mark_degraded → hệ thống tự động hoặc CTO (mất quyền / job fail vượt ngưỡng);
          revoke → chỉ CTO, vô hiệu token tức thì; bắt buộc trước khi nạp credential mới.
Response: 200 { success, data: { id, status, changedAt, changedBy, auditRef } }
Error:    409 INVALID_STATE; 403 MFA_REQUIRED / FORBIDDEN; 423 CREDENTIAL_LOCKED
```

#### Credentials Vault (FEAT-GW-STGW-001) — mask-only, MFA, cấm mobile

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|--------|------|------|-------------|--------|
| API-GW-007 | GET | `/gw/vault/credentials` | JWT+CTO | List credential (mask + metadata), filter `profileId,status,rotateDueBefore` | REQ-BOD-008 |
| API-GW-008 | GET | `/gw/vault/credentials/:id` | JWT+CTO | Chi tiết mask-only; việc XEM cũng ghi audit (BR-GW-STGW-007) | REQ-BOD-008 |
| API-GW-009 | POST | `/gw/vault/credentials` | JWT+CTO+MFA | Nạp credential mới (encrypted blob + masked_value + rotate_due_at) | REQ-BOD-008 |
| API-GW-010 | POST | `/gw/vault/credentials/:id/rotate` | JWT+CTO+MFA | Rotate → version mới giữ lịch sử; reset rotate_due (≥90 ngày) | REQ-BOD-008, REQ-BOD-007 |
| API-GW-011 | POST | `/gw/vault/credentials/:id/revoke` | JWT+CTO+MFA | Thu hồi khẩn — vô hiệu token tức thì ở mức khả thi; offboarding ≤24h | REQ-BOD-008, REQ-BOD-007 |

```
API-GW-009/010/010 — request chung: { "maskedHint": "****a1b2", "secretRef": "<envelope-ref từ vault-service>",
                                     "rotateDueAt": "2026-12-12T00:00:00Z" }
Response: 201/200 { success, data: { id, version, maskedValue, rotateDueAt, status } } — không có plaintext
Error:    403 MFA_REQUIRED / MOBILE_VAULT_FORBIDDEN; 423 CREDENTIAL_LOCKED (revoke trước khi nạp mới)
```

#### Sync Job Admin (FEAT-GW-STGW-001)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|--------|------|------|-------------|--------|
| API-GW-012 | GET | `/gw/sync/schedules` | JWT | List schedule (cadence, batch_size, retry_policy, priority_rules) | REQ-BOD-008 |
| API-GW-013 | PUT | `/gw/sync/schedules/:id` | JWT+CTO | Cập nhật schedule (SYS_ADMIN thực thi sau duyệt) | REQ-BOD-008 |
| API-GW-014 | POST | `/gw/sync/jobs` | JWT+CTO | Kích hoạt run on-demand cho window `{platform, windowFrom, windowTo}` | REQ-FIN-005 |
| API-GW-015 | GET | `/gw/sync/jobs` | JWT | List job: filter `profileId,status` (queued/running/success/failed/retrying) | REQ-FIN-005 |
| API-GW-016 | GET | `/gw/sync/jobs/:id` | JWT | Chi tiết job + attempt + error_code + raw payload refs | REQ-FIN-005 |
| API-GW-017 | POST | `/gw/sync/jobs/:id/retry` | JWT+CTO | Retry tay sau khi hết retry tự động | REQ-FIN-005 |

#### Policy Config & Field Mapping (FEAT-GW-STGW-001/002)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|--------|------|------|-------------|--------|
| API-GW-018 | GET | `/gw/policies` | JWT | Tham số hiệu lực tại thời điểm `?at=` (effective-dated) | REQ-BOD-009 |
| API-GW-019 | GET | `/gw/policies/:paramKey/versions` | JWT | Lịch sử version + người duyệt + reason | REQ-BOD-009 |
| API-GW-020 | POST | `/gw/policies/:paramKey` | JWT+BOD | Ban hành version mới (chỉ BOD_CEO/BOD_CFO_CTO) — không hồi tố | REQ-BOD-008, REQ-BOD-009 |
| API-GW-021 | GET | `/gw/mappings` | JWT | List field mapping + import/export template theo profile | REQ-FIN-005, REQ-FIN-013 |
| API-GW-022 | PUT | `/gw/mappings/:id` | JWT+CTO | Cập nhật mapping (DI-004 — thêm nguồn = thêm profile, không sửa code) | REQ-FIN-013 |
| API-GW-023 | POST | `/gw/exports` | JWT | Sinh file xuất chuẩn schema cho connector VAS import_export + log lượt xuất | REQ-FIN-013 |

#### Degraded/Backfill Status & Trigger (FEAT-GW-STGW-002)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|--------|------|------|-------------|--------|
| API-GW-025 | GET | `/gw/degraded/status` | JWT | State luồng per-platform: MANUAL ↔ API ↔ BACKFILL + tuổi dữ liệu | REQ-FIN-005 |
| API-GW-026 | POST | `/gw/backfill/runs` | JWT+CTO | Kích hoạt backfill `{platform, gapFrom, gapTo}` — theo sự kiện cấp quyền, không đặt lịch | REQ-FIN-005 |
| API-GW-027 | GET | `/gw/backfill/runs` | JWT | List backfill run + progress + recheck_status kỳ manual | REQ-FIN-005 |

#### Import Manual Channels (FEAT-GW-STGW-002) — chặn lỗi theo dòng

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|--------|------|------|-------------|--------|
| API-GW-028 | POST | `/gw/imports/statements` | JWT+FIN_L1 | Import file statement schema 8 trường; nhận dòng hợp lệ, trả lỗi từng dòng | REQ-FIN-005 |
| API-GW-029 | POST | `/gw/imports/rows` | JWT+FIN_L1 | Nhập tay có cấu trúc 1 dòng (không có lối nhập tự do) | REQ-FIN-005 |
| API-GW-030 | GET | `/gw/imports/batches/:id` | JWT | Kết quả batch + error report theo dòng | REQ-FIN-005 |
| API-GW-031 | POST | `/gw/imports/batches/:id/retry-rows` | JWT+FIN_L1 | Nạp lại CHỈ các dòng lỗi đã sửa (idempotent theo khóa tự nhiên) | REQ-FIN-005 |

```
API-GW-028 — statement schema 8 trường (BR-FIN-205b):
  platform (META|GOOGLE|TIKTOK|BING|X|PINTEREST|YANDEX), adaccount_ref, txn_date,
  txn_type, amount_original, currency, fee, reference_code
  + metadata bắt buộc: entered_by (từ JWT), evidence_ref (statement file/ảnh chứng từ)
Request:  multipart/form-data: file (CSV/XLSX) + evidenceRef (object-storage key)
Response: 202 { success, data: { batchId, totalRows, acceptedRows, rejectedRows, rowErrors[] } }
Rule:     natural key (platform+adaccount_ref+txn_date+txn_type+reference_code) trùng → dòng lỗi
          NATURAL_KEY_DUPLICATE; batch KHÔNG nhận mù — dòng hợp lệ vẫn nhận.
API-GW-042 — tiktok metrics schema 6 trường (BR-GW-TT-001):
  shop_ref, metric_date, metric_type, amount_original, currency, reference_code
  + entered_by + evidence_ref — cùng cơ chế chặn theo dòng với API-GW-028.
```

#### Statement Query cho Đối Trừ + Raw Payload + Audit (FEAT-GW-STGW-002)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|------|------|------|-------------|--------|
| API-GW-032 | GET | `/gw/statements` | JWT (FIN/OPS scope) | Query statement gắn nhãn: filter `platform,adaccountRef,windowFrom,windowTo,sourceLabel` | REQ-FIN-005, REQ-FIN-004 |
| API-GW-033 | GET | `/gw/raw-payloads` | JWT+CTO | List raw payload theo job/batch + parse_status | REQ-BOD-008 |
| API-GW-034 | POST | `/gw/raw-payloads/:id/reprocess` | JWT+CTO | Chạy lại chuẩn hóa sau khi mapping đổi (raw lưu trước parse) | REQ-FIN-005 |
| API-GW-035 | GET | `/gw/audit-logs` | JWT (CTO/CEO) | Xem gateway audit + API call log; việc xem cũng bị log | REQ-BOD-008, REQ-FIN-012 |

**API-GW-032 — hợp đồng dữ liệu cho đối trừ 3 số (BR-FIN-205a):** response mỗi bản ghi gồm `platform, adaccountRef, txnDate, txnType, amountOriginal, currency, fee, referenceCode, sourceLabel (api|manual, immutable), enteredBy?, evidenceRef?, freshness`; core chỉ đưa bản ghi đủ nhãn (+ evidence với `manual`) vào đối trừ. Không có endpoint sửa nhãn — attempt → 405 `AUDIT_IMMUTABLE` + audit.

### 6.2. Module: TikTok Shop Monitoring (MOD-TIKTOK-SHOP)

#### Shop Connection & Lifecycle 3-Gate (FEAT-GW-TIKTOK-001)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|------|------|------|-------------|--------|
| API-GW-036 | POST | `/gw/shop/connections` | JWT (OPS_AM) | Đề xuất kết nối OAuth per-client (1 shop-1 ủy quyền-1 khách, scope ghi rõ) | REQ-OPS-011 |
| API-GW-037 | GET | `/gw/shop/connections` | JWT | List tenant-scoped, filter `tenantId,status,gateStage` | REQ-OPS-011 |
| API-GW-038 | GET | `/gw/shop/connections/:id` | JWT | Chi tiết + scope + gate_stage + expires_at | REQ-OPS-011 |
| API-GW-039 | POST | `/gw/shop/connections/:id/transitions` | JWT (SALES_L4/SYS_ADMIN) | Transition: approve / reject / go_live / mark_degraded / revoke (≤24h) | REQ-OPS-011 |
| API-GW-040 | GET | `/gw/shop/connections/:id/access-logs` | JWT (CTO/OPS_AM) | Access log bất biến (ai, khi nào, api_object, scope_used) | REQ-OPS-011 |

**API-GW-039 — ràng buộc:** `go_live` yêu cầu tín hiệu Gate 2 từ core (workflow 3 Gate sở hữu ở core — gateway chỉ phản chiếu + tự gate-check trước mỗi job); `revoke` theo sự kiện hợp đồng/khách yêu cầu, hoàn tất ≤24h, sau đó mọi pull vô hiệu vĩnh viễn kể cả backfill (BR-OPS-4.1c); shop bị platform khóa KHÔNG đổi trạng thái kết nối — chỉ gắn cờ health + alert.

#### Metrics, PII Session, Alert & Portal Feed (FEAT-GW-TIKTOK-001)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|------|------|------|-------------|--------|
| API-GW-041 | GET | `/gw/shop/metrics` | JWT (OPS/FIN scope) | Query ShopMetricDaily: filter `shopId,window,metricType,sourceLabel`; luôn `referenceOnly=true` | REQ-OPS-011 |
| API-GW-042 | POST | `/gw/shop/imports/metrics` | JWT (OPS_ADS/OPS_AM) | Import degraded schema 6 trường, chặn lỗi theo dòng | REQ-OPS-011 |
| API-GW-043 | GET | `/gw/shop/imports/batches/:id` | JWT | Kết quả batch metric + rowErrors | REQ-OPS-011 |
| API-GW-044 | POST | `/gw/shop/pii-sessions` | JWT (OPS_ADS/OPS_AM) | Mở phiên PII TTL `{connectionId, reason}` — reason bắt buộc; dữ liệu đầy đủ KHÔNG persist | REQ-OPS-011 |
| API-GW-045 | DELETE | `/gw/shop/pii-sessions/:id` | JWT | Đóng phiên sớm; hết TTL tự đóng | REQ-OPS-011 |
| API-GW-046 | GET | `/gw/shop/alerts` | JWT | Alert feed: shop khóa, settlement lệch, giấy phép/OAuth hết hạn, baseline lệch (web + M-INT push tiêu thụ) | REQ-OPS-011 |

#### Internal API (Service-to-Service)

| API-ID | Method | Path | Caller | Purpose | REQ-ID |
|--------|------|------|--------|---------|--------|
| API-GW-047 | GET | `/internal/gw/shop/portal-feed?tenantId=&period=` | SYS-CORE-BACKEND (Portal API Gateway) | PortalReportFeed đã mask + tổng hợp, tenant-scoped, read-only — gateway không serve portal trực tiếp (BR-GW-TT-002) | REQ-OPS-011 |
| API-GW-048 | GET | `/internal/gw/feed/wallet-status?window=` | SYS-CORE-BACKEND | Fact feed PlatformStatement gắn nhãn cho đối trừ 3 số + cảnh báo ví (bên cạnh event `wallet.sync.completed`) | REQ-FIN-005, REQ-OPS-003 |

Auth internal: `X-Internal-Token` service-to-service; timeout 3s/10s heavy; tenant filter bắt buộc — feed thiếu filter tenant bị chặn.

## 7. Internal API (Service-to-Service)

Ngoài 2 endpoint trên, gateway tiêu thụ internal của core: PDP check, MFA step-up verify, audit SDK (hash-chain), gate-stage signal, sự kiện hợp đồng (kích hoạt thu hồi shop). Không mở webhook receiver — cả 3 spec đều pull-based [NEEDS_REVIEW: nếu nền tảng hỗ trợ push (vd TikTok Shop event feed), bổ sung component nhận webhook khi API được cấp quyền].

## 8. Rate Limiting

| Endpoint group | Limit | Window | Ghi chú |
|---------------|-------|--------|---------|
| `/gw/vault/*` | 10 req | 1 phút | Cạo guess window + MFA |
| `/gw/connections/*/transitions`, `/gw/shop/connections/*/transitions` | 30 req | 1 phút | — |
| `/gw/imports/*` | 5 req | 1 phút | Batch nặng; queue phía sau |
| `/gw/statements`, `/gw/shop/metrics` | 200 req | 1 phút | Đối soát đọc nhiều |
| `/internal/gw/*` | 1000 req | 1 phút | Service-to-service |
| Outbound per-platform (worker) | Theo quota từng nền tảng | hourly window | Circuit breaker per-platform; không share limit giữa 7 nguồn |

---

> **[NEEDS_REVIEW] (API):** (1) webhook receiver chưa trong phạm vi — pull-based theo cả 3 spec; (2) cơ chế kết nối chính xác VAS (API hay import file) chưa xác định [KXN-9] — API-GW-002/022/023 thiết kế tổng quát cho cả 2; (3) gatewayAudit truy vấn có cần API riêng tách khỏi COMP-CORE-004 hay chỉ proxy — chờ lane CORE chốt contract audit store.
