# Integration Map — BCERP (BC Agency Enterprise Resource Planning)

> READS: `phase3-architecture/P3-01-architecture.md` (§2 sơ đồ, §4 ownership, §5 giao tiếp, §8.1 auth, §10 data pipeline, §11 automation), `phase2-features/**`, `$SESSION_DIR/business-context.md` (§3 dependency map), `$SESSION_DIR/aggregation-result.json` (60 components, 280 APIs — nguồn tra cứu ID), `technical-specs/api-contract.md` (chi tiết endpoint)
> OUTPUT: Sync/async contracts, event payloads, external integrations, cross-system business rules, Object 360 data needs, propagation rules cross-department
> USED BY: `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
> DATE: 2026-09-13

---

## 1. Tổng Quan Tích Hợp

6 systems: SYS-CORE-BACKEND (nền tảng), SYS-BCERP-WEB (domain services, SSOT 14 module nghiệp vụ), SYS-INTEGRATION-GW (cổng outbound duy nhất), SYS-PORTAL-WEB (DMZ), SYS-MOBILE-INTERNAL, SYS-MOBILE-PORTAL.

```
SYNC (REST, service-to-service, X-Internal-Token / Bearer JWT):
  Mọi RP ──token/introspect/step-up──► CORE IdP (COMP-CORE-001)
  Mọi PEP ──pdp/check──► CORE PDP (COMP-CORE-002)  [cache 60s]
  Mọi module ──append audit──► CORE Audit (COMP-CORE-004, endpoint API-CORE-028)
  BCERP-WEB ──statements/health/degraded──► GW
  CORE ──fact feed──► GW (/internal/gw/feed/*)
  PORTAL ──read-model (RLS+mask)──► CORE read-views; ──ticket ghi──► BCERP-WEB
  MOBILE ──BFF──► CORE/BCERP-WEB/PORTAL backend (KHÔNG gọi GW trực tiếp)

ASYNC (Events, outbox pattern, consumer idempotent, DLQ bắt buộc):
  COMP-ERP-002 ──wallet.matched──► COMP-ERP-003 (mở hard stop TKQC)
  COMP-ERP-002 ──wallet.low_balance / payment.received / refund.executed──► SLANOT / COMM
  COMP-ERP-001 ──deal.signed / handoff.ops_ack──► COMP-ERP-002/003, PORTAL
  COMP-ERP-005 ──timesheet.approved──► CORE DataHub + KPI
  COMP-ERP-006 ──sla.warning/sla.breach──► module owner + MOBILE push
  COMP-GW-009/005/013 ──wallet.sync.completed / backfill.completed / shop.alert──► CORE
  COMP-CORE-011 ──alert.raised──► COMP-ERP-006 dispatch + MOBILE
  COMP-PORTAL-006 ──portal.adoption.*──► CORE (gate Day 14)

RULES:
  ✅ Cross-system chỉ qua REST API hoặc event — KHÔNG query thẳng DB system khác (P3-01 §4)
  ✅ Business object SSOT nằm ở SYS-BCERP-WEB; CORE/GW/PORTAL/MOBILE không sở hữu business object
  ❌ KHÔNG import code từ system khác; KHÔNG mở webhook receiver ở GW (pull-based — [NEEDS_REVIEW: Phụ lục A #15])
  ❌ Mobile CẤM vault (BR-GW-STGW-005); offline queue CẤM cho lệnh tiền
```

---

## 2. Synchronous Calls (REST)

> Auth service-to-service: `X-Internal-Token` (service) + Bearer JWT (user context); timeout 3s (10s heavy query); retry 3 lần exponential backoff (P3-01 §8.2). User-facing routes giữ prefix hệ (`/api/v1/core|erp|gw|portal|mbi|mpo/*`); route `/internal/*` dành riêng service-to-service.
> **Credential service-to-service (RULE bổ sung):** mỗi cặp service một credential riêng — mở rộng mô hình `CORE_INTERNAL_TOKEN`/`GW_INTERNAL_TOKEN`/`PORTAL_SERVICE_TOKEN` hiện có, không dùng chung 1 token platform; rotate định kỳ ≥90 ngày qua vault (dual-token window, không downtime); mTLS nội bộ bắt buộc cho Portal↔CORE (INFRA-PORTAL-010) và là mục tiêu mở rộng cho các cặp còn lại; audit SDK (API-CORE-028) chỉ nhận request từ allowlist service ID.

| ID | Caller | Callee | API-ID + Method + Path | Trigger | Timeout | Retry |
|----|--------|--------|------------------------|---------|---------|-------|
| INT-S-001 | 5 RP: BCERP-WEB, GW, PORTAL, MBI, MPO | CORE IdP (COMP-CORE-001) | API-CORE-001 `POST /core/auth/token`; API-CORE-002 refresh; API-CORE-003 `mfa/step-up`; API-CORE-008 introspect; API-CORE-005 logout | Login, refresh, action tài chính/vault, verify revocation | 3s | 1x (auth không retry mù) |
| INT-S-002 | Mọi service (PEP middleware) | CORE PDP (COMP-CORE-002) | API-CORE-014 `POST /core/pdp/check`; API-CORE-022 `pdp/sod-check` | Trước mọi business action; SoD check cho approval | 3s | 0 (cache 60s; fail-closed action tài chính — [NEEDS_REVIEW: fail-open/closed luồng đọc policy, Phụ lục A #14]) |
| INT-S-003 | Mọi module | CORE Audit (COMP-CORE-004) | API-CORE-028 `POST /core/audit/events`; API-CORE-030 timeline | Mọi state transition + access-denied; timeline object | 3s | 3x (buffer local; action tài chính fail-closed) |
| INT-S-004 | BCERP-WEB FIN (COMP-ERP-002, COMP-ERP-007) | GW (COMP-GW-004/009) | API-GW-032 `GET /gw/statements?platform=&adaccountRef=&windowFrom=&windowTo=&sourceLabel=` | Đối trừ 3 số (batch scheduler + on-demand); payload per record: platform, adaccountRef, txnDate, txnType, amountOriginal, currency, fee, referenceCode, sourceLabel, evidenceRef | 10s | 3x |
| INT-S-005 | BCERP-WEB OPS/FIN + oversight BOD | GW (COMP-GW-006) | API-GW-024 `GET /gw/health`; API-GW-025 `GET /gw/degraded/status`; API-GW-006 connection health | Hiển thị trạng thái sync vs manual, data freshness, hạn rotate | 3s | 3x |
| INT-S-006 | CORE (DataHub + Alert) | GW | API-GW-048 `GET /internal/gw/feed/wallet-status?window=` | Fact feed PlatformStatement gắn nhãn cho đối trừ + cảnh báo ví (bên cạnh event `wallet.sync.completed`) | 10s | 3x |
| INT-S-007 | CORE ingest (COMP-CORE-007) | GW (COMP-GW-003/011) | Pull batch theo schedule (API-GW-015 `GET /gw/sync/jobs` theo dõi); ingest contract qua API-CORE-046 | Nguồn B pipeline DataHub: 7 nền tảng + VAS + TikTok Shop | batch | n/a |
| INT-S-008 | PORTAL BFF (COMP-PORTAL-002/004) | CORE read-views + BCERP-WEB share model | API-PORTAL-019..023 (ví read-only); API-PORTAL-031..033 (invoice); API-PORTAL-024..026 (campaign) | Mọi view client-facing; RLS + tenant filter + mask tầng CORE | 3s/10s | 3x |
| INT-S-009 | PORTAL BFF | BCERP-WEB CSKH (COMP-ERP-004) | API-PORTAL-029 `POST /portal/tickets` → API-ERP-057 `POST /erp/tickets` (`source=PORTAL`, dedupe tầng ERP) | Tạo ticket hợp nhất — điểm ghi DUY NHẤT từ portal | 3s | 1x + idempotency key |
| INT-S-010 | BCERP-WEB/MOBILE-INTERNAL | CORE BI (COMP-CORE-010) | API-CORE-036 `bi/marts/:martName`; API-CORE-037 `bi/pnl`; API-CORE-038 dashboards; API-CORE-040 `bi/freshness` | Render dashboard P&L/BI (kèm freshness metadata — điều kiện render, RULE-X008) | 10s | 3x |
| INT-S-011 | MOBILE BFF (COMP-MBI-003/COMP-MPO-002) | Backend tương ứng | API-MBI-013 `POST /mbi/approvals/:id/decision` → forward API-ERP-023/034; API-MPO-019..022 → portal share model; API-MBI-027 generic transition | Mọi thao tác mobile — BFF shape, không chứa business logic | 3s | 1x |
| INT-S-012 | BCERP-WEB ADACC (COMP-ERP-003) | BCERP-WEB WALLET (COMP-ERP-002) | API-ERP-027 `GET /erp/wallets/{customerId}/hard-stop-status` — guard bắt buộc trước API-ERP-045 `POST /ad-accounts/{id}/transitions` (→ active) | Pre-spend hard-stop check tại nguồn (không phụ thuộc event) | in-process | n/a |
| INT-S-013 | GW TikTok (COMP-GW-010) | CORE (workflow 3-Gate) | Gate-stage signal (internal core, API khung [NEEDS_REVIEW: contract publish, Phụ lục A #6]) | Chỉ bật pull sau tín hiệu Gate 2; gate check tự kiểm tra trước mỗi job (BR-OPS-4.5) | 3s | 3x |
| INT-S-014 | BCERP-WEB FIN_L2 | GW VAS (COMP-GW-008) | API-GW-023 `POST /gw/exports` (file chuẩn qua FieldMapping); API-GW-021 mappings | Xuất dữ liệu kế toán VAS theo DI-004; đổi phần mềm = thêm profile | 10s | 3x |

**Failure handling chung:**
```
Timeout → caller throw ServiceUnavailableError → 503; action tài chính → fail-closed (không tạo gì)
PDP unreachable → 503 + audit; action tài chính từ chối (fail-closed)
Auth/introspect fail → 401/403 + audit access-denied (không expose chi tiết)
GW feed thiếu tenant filter → chặn tầng GW (INT-S-006/008 — RULE-X005)
```

---

## 3. Asynchronous Events

> Event name convention `[sys].[entity].[action]`; topic Kafka (đề xuất) `bcerp.[env].[event-name]`; outbox pattern — publisher phát SAU khi commit DB; consumer idempotent theo natural key + eventId; DLQ per topic, replay là hành động người.

| ID | Publisher | Event | Trigger | Subscribers | REQ-ID |
|----|-----------|-------|---------|-------------|--------|
| INT-E-001 | COMP-ERP-002 (WALLET) | `wallet.matched` | FIN_L1 confirm hard stop (API-ERP-026) — đối trừ 3 số khớp | COMP-ERP-003 (mở điều kiện active TKQC); CORE DataHub | REQ-FIN-006 |
| INT-E-002 | COMP-ERP-002 | `wallet.low_balance` | Số dư < đủ chi ≥3 ngày | COMP-ERP-006 (SLA đỏ 2h → escalation); COMP-CORE-011 | REQ-FIN-002, REQ-OPS-003 |
| INT-E-003 | COMP-ERP-001 (HONB) | `handoff.ops_ack` | OPS_AM ký nhận (API-ERP-018) | COMP-ERP-003 (task cấp TKQC); PORTAL (task portal account); COMP-ERP-003 CAMP (task campaign) — Day 1/7/14/30 | REQ-OPS-004, REQ-SALES-008 |
| INT-E-004 | COMP-ERP-001 (QDD) | `deal.signed` | E-sign hoàn tất (API-ERP-014) | COMP-ERP-002 (mở AR schedule + handoff draft) | REQ-SALES-007 |
| INT-E-005 | COMP-ERP-002 (ARAP) | `payment.received` / `refund.executed` | Ghi nhận thu / hoàn tiền | COMP-ERP-002 COMM (commission computed / clawback check) | REQ-SALES-009, REQ-FIN-010 |
| INT-E-006 | COMP-ERP-005 (CAPTS) | `timesheet.approved` | Duyệt song song OPS∥HR hoàn tất | CORE DataHub (giờ duyệt mới vào P&L); KPI auto-aggregate | REQ-OPS-007, REQ-HR-007 |
| INT-E-007 | COMP-ERP-006 (SLANOT) | `sla.warning` / `sla.breach` | Timer SLA (ticket, nghiệm thu, ví đỏ 2h, aging, handoff checkpoint) | Module owner + escalation path; COMP-MBI-004 push; COMP-MPO-003 push | REQ-OPS-008 |
| INT-E-008 | COMP-GW-009 | `wallet.sync.completed` | Mỗi sync window (platform, window, số bản ghi, nhãn nguồn) | CORE (freshness nhóm platform + alert SLA đỏ 2h) | REQ-FIN-005 |
| INT-E-009 | COMP-GW-005 | `backfill.completed` | Backfill xong sau degraded | CORE (đối soát lại kỳ từng nhập manual — discrepancy ticket) | REQ-FIN-005 |
| INT-E-010 | COMP-GW-013 | `shop.alert` | Anomaly shop: hạn chế/khóa, GMV lệch, OAuth sắp hết hạn | COMP-CORE-011 alert center; COMP-MBI-004 push OPS | REQ-OPS-011 |
| INT-E-011 | COMP-CORE-011 | `alert.raised` | Alert center sinh alert (rule trên marts + event) | COMP-ERP-006 (dispatch đa kênh); MOBILE push | REQ-BOD-006 |
| INT-E-012 | COMP-PORTAL-006 | `portal.adoption.*` | Kích hoạt/login/tạo user portal (forward qua API-PORTAL-038) | CORE (gate Day 14 từ dữ liệu thực) | REQ-OPS-010 |
| INT-E-013 | COMP-GW-005/006 | `connection.degraded` | Adapter fail vượt retry / mất quyền API / rotate quá hạn | COMP-CORE-011 (alert); BCERP-WEB (health flag OPS/FIN); MOBILE | REQ-BOD-008, REQ-FIN-005 |
| INT-E-014 | COMP-ERP-001 | `lead.assigned` / `lead.reassigned` | Phân bổ/reassign lead (API-ERP-007, SALES_L2+ duyệt reassign) | COMP-ERP-006 (SLA timer theo tier); COMP-ERP-003 (context campaign khi qualified) | REQ-SALES-002 |
| INT-E-015 | COMP-ERP-004 | `ticket.assigned` / `ticket.reassigned` | Assign/reassign queue OPS_CONT (API-ERP-059) | COMP-ERP-006 (reset/hẹn timer SLA); PORTAL read-model (refresh ticket tenant) | REQ-OPS-009 |
| INT-E-016 | COMP-ERP-003 / PORTAL | `portal.account.lifecycle` | Cấp/thu hồi portal account (API-ERP-055; invite API-PORTAL-014, transitions API-PORTAL-015) | CORE audit (thu hồi ≤24h BR-FIN-603); COMP-PORTAL-006 (adoption); FIN (phạm vi chia sẻ dữ liệu) | REQ-OPS-010 |
| INT-E-017 | COMP-ERP-002 (WALLET) | `recon.mismatch` | Kết quả đối trừ 3 số có mismatch (batch COMP-ERP-007 + on-demand API-ERP-024) | COMP-CORE-011 (alert mismatch); FIN exception §5 (mismatch chặn close kỳ — guard API-ERP-025); COMP-MBI-004 push FIN | REQ-FIN-004 |
| INT-E-018 | COMP-ERP-002 (ARAP) | `invoice.issued` | Phát hành HĐĐT (API-ERP-036 issue) | COMP-CORE-005 (evidence chứng từ push WORM — REQ-FIN-012); PORTAL read-model (invoice view API-PORTAL-031/032) | REQ-FIN-011, REQ-FIN-012 |
| INT-E-019 | COMP-ERP-005 (KPI) | `kpi.below_threshold` | KPI period aggregate dưới ngưỡng sau finalize | COMP-ERP-005 PIP (đề xuất mở PIP — HR_L2 phê qua API-ERP-071); COMP-CORE-011 (alert HR) | REQ-HR-008 |
| INT-E-020 | COMP-ERP-003 (CAMP) | `deliverable.acceptance_due` | Deliverable `delivered` chờ nghiệm thu — chạm mốc hạn 3 ngày làm việc | COMP-ERP-006 (SLA nhắc ngày 2 + escalate AD ngày 4); COMP-MBI-004 push OPS_AM | REQ-OPS-006 |

**Quy tắc event (bắt buộc):** (1) phát sau commit DB (outbox); (2) eventId UUID duy nhất; (3) consumer idempotent — natural key per event (ví: hard stop = customerId; commission = payment_id; sync = platform+adaccount+window); (4) không đặt hard control chỉ trong event handler — sweep re-validate tại nguồn là source of truth (P3-01 §11.4); (5) payload tự đủ, không gọi ngược publisher; (6) correlationId xuyên suốt REST + event.

---

## 4. Event Payload Schemas

### INT-E-001: `wallet.matched` (event quan trọng nhất — hard stop propagation)

```typescript
// Publisher: COMP-ERP-002 (MOD-WALLET-RECON). Trigger: API-ERP-026 confirm FIN_L1 (MFA step-up).
// Subscribers: COMP-ERP-003 mở điều kiện pre_spend_hardstop_check → active; CORE DataHub ghi mart wallet.
interface WalletMatchedPayload {
  eventId: string;            // UUID
  eventType: 'wallet.matched';
  version: '1';
  timestamp: string;          // ISO 8601 UTC
  correlationId: string;      // truy vết từ lệnh đối soát
  data: {
    customerId: string;       // natural key — consumer idempotent theo đây
    currency: 'USD' | 'VND';  // không gộp quy đổi
    matchedAmount: string;    // DECIMAL, đã khớp đối trừ 3 số
    period: string;           // kỳ đối soát YYYY-MM
    confirmedBy: string;      // user-id FIN_L1
    hardStopStatus: 'matched'; // casing lowercase theo quy ước P3-01 §6 (payload/API lowercase)
  };
}
// Subscriber COMP-ERP-003: validate schema → idempotency check theo customerId+period →
// cập nhật điều kiện hard stop (vẫn phải pass guard INT-S-012 khi transition) → audit → ACK/NACK.
// Consumer KHÔNG là nguồn sự thật: sweep COMP-ERP-007 re-validate API-ERP-027 mỗi batch.
```

### INT-E-003: `handoff.ops_ack`

```typescript
// Publisher: COMP-ERP-001 (MOD-HANDOFF-ONBOARD). Trigger: API-ERP-018 ops-ack (ký 2 phía).
interface HandoffOpsAckPayload {
  eventId: string; eventType: 'handoff.ops_ack'; version: '1'; timestamp: string;
  data: {
    handoffId: string; customerId: string; customerTier: 'A'|'B'|'C'|'D'|'E';
    contractRef: string;          // hợp đồng signed
    scopeCommitments: object;     // scope cam kết → sinh task
    onboardingTasks: Array<{      // Day 1/7/14/30
      taskType: 'ADACCOUNT_PROVISION' | 'PORTAL_ACCOUNT' | 'CAMPAIGN_SETUP';
      assigneeRole: string; dueDay: number;
    }>;
    ackBy: string; // OPS_AM
  };
}
// COMP-ERP-003: sinh task cấp TKQC (guard KYC + hard stop). PORTAL: task portal account
// (OPS_AM cấp CLIENT_ADMIN đầu tiên — Day 1). CAMP: task campaign setup.
// Task sinh idempotent theo (handoffId, taskType); fail → retry → DLQ → checkpoint sweep Day-1 bắt kịp.
```

Các event còn lại theo cùng pattern chung (eventId/eventType/version/timestamp/correlationId/data): `wallet.low_balance` (customerId, availableRunwayDays, severity), `deal.signed` (dealId, customerId, value, currency, signedAt), `payment.received|refund.executed` (paymentId, invoiceId, amount, currency, reason), `timesheet.approved` (employeeId, weekWindow, approvedHours, reviewerPair), `sla.breach` (objectType, objectId, tier, priority, breachedAt, escalationPath), `wallet.sync.completed` (platform, windowFrom/To, recordCount, sourceLabel), `backfill.completed` (platform, window, overwrittenManualCount — bản ghi manual giữ nguyên vết, không xóa), `shop.alert` (shopId, tenantId, alertType, deviation), `lead|ticket.assigned` (objectId, fromOwner, toOwner, reassignedBy, reason), `portal.account.lifecycle` (portalUserId, tenantId, action, actedBy). Breaking change → tăng `version`, thông báo subscriber trước (schema registry API-CORE-046).

Bổ sung 4 event ERP chưa có contract (payload theo cùng pattern chung): `recon.mismatch` (reconRunId, period, customerId, mismatchItems[], detectedAt — natural key `reconRunId+period+customerId`; mismatch là exception §5: close kỳ bị chặn tới khi xử lý xong), `invoice.issued` (invoiceId, customerId, issuerId, issuedAt, einvoiceRef, wormEvidenceRef — natural key `invoiceId`), `kpi.below_threshold` (employeeId, kpiPeriod, metric, threshold, actualValue — natural key `employeeId+kpiPeriod+metric`; PIP chỉ là đề xuất, HR_L2 phê), `deliverable.acceptance_due` (deliverableId, campaignId, dueAt, assigneeId — natural key `deliverableId`).

---

## 5. Event Infrastructure

```
Message Queue: Kafka (đề xuất — chốt theo Phụ lục A #11); job nhẹ dùng Redis queue
Topics:        bcerp.[env].[event-name] — per publisher module
Outbox:        mọi publisher — ghi event cùng transaction DB, dispatcher đẩy lên topic
DLQ:           bcerp.[env].dlq per topic + dead-job registry cho scheduler (API-CORE-048 view;
               API-ERP-077 dead-letters job-level). KHÔNG auto-replay — replay là hành động người
               (owner module, qua màn hình ops, ghi audit)
Retry:         3 lần backoff (1s/5s/30s) → DLQ; DLQ push → alert ngay COMP-CORE-011 → dispatch
               COMP-ERP-006; ngoài giờ → on-call 4h (DI-005). Backlog DLQ im lặng quá ngưỡng
               phải escalate [NEEDS_REVIEW: ngưỡng backlog DLQ — Phụ lục A, P3-01 §11.4]
Idempotency:   subscriber lưu eventId đã xử lý; natural key per event (xem §3); job scheduler
               idempotency key theo (job, window) + distributed lock Redis (COMP-ERP-007)
Sweep:         COMP-ERP-007 — lưới an toàn độc lập với event: re-validate hard stop, commission,
               clawback, checkpoint Day 1/7/14/30; event lost/DLQ vẫn được bắt kịp tại nguồn
```

---

## 6. External Integrations

> Mọi outbound ĐI QUA SYS-INTEGRATION-GW (COMP-GW-001 adapter framework, vendor-agnostic DI-004); pull-based, rate-limited (COMP-GW-003); raw payload lưu trước parse (COMP-GW-004); nhãn nguồn `api|manual` ghi tại thời điểm ghi. Khởi điểm toàn hệ thống là MANUAL mode (DI-007).

| Service/Nền tảng | Mục đích | Auth | Rate limit | Timeout | Ghi chú |
|------------------|----------|------|-----------|---------|---------|
| Meta / Google / TikTok / Bing / X / Pinterest / Yandex | Statement số dư + chi tiêu TKQC (feed ví, REQ-FIN-005) | OAuth/API key per connector trong vault (COMP-GW-002, MFA CTO) | Theo quota từng nền tảng — queue rate-limited | 30s/call, retry 3x backoff, circuit breaker per-platform → degraded | Ưu tiên TKQC active chi tiêu khi thiếu cửa sổ hourly |
| Phần mềm kế toán VAS | Xuất/nhập dữ liệu kế toán (REQ-FIN-013) | api_adapter HOẶC import_export theo profile | Theo profile | 30s | Đổi VAS = thêm profile, không sửa code [NEEDS_REVIEW: cơ chế kết nối VAS chính xác — KXN-9, Phụ lục A #16] |
| TikTok Shop API | OAuth per-client 1 shop/1 ủy quyền/1 khách; pull GMV/đơn/settlement/shop health (REQ-OPS-011) | OAuth per shop, scope ghi rõ; ShopAccessLog bất biến | Pull 15–60 phút | 30s | `reference_only=true` luôn bật — cấm map GMV vào doanh thu (RULE-X008); chỉ monitoring, không OMS/WMS |
| E-sign provider | Ký hợp đồng/LOI/NDA (API-ERP-014) | Theo provider | — | — | [NEEDS_REVIEW: provider + đường dẫn qua GW hay trực tiếp — Phụ lục A #4] |
| FCM / APNs | Push MOBILE-INTERNAL + MOBILE-PORTAL | Service credentials | — | 5s | Body push không chứa số liệu tài chính; push chỉ là kênh báo, SLA timer vẫn chạy backend |
| Email/SMS/OTT (nếu có) | Kênh notification ngoài in-app của SLANOT | — | — | — | [NEEDS_REVIEW: kênh ngoài in-app — Phụ lục A #3] |

Không dùng n8n/Zapier/Make hoặc automation SaaS external (P3-01 §11.3): dữ liệu tiền giữ hộ + PII không qua bên thứ ba chưa phê duyệt; audit trail phải nằm COMP-CORE-004 hash-chain.

---

## 7. Cross-System Business Rules

### RULE-X001: Financial Hard Stop propagation — WALLET → ADACC

**Systems:** SYS-BCERP-WEB (COMP-ERP-002 → COMP-ERP-003) + sweep COMP-ERP-007
**Trigger:** Trước mỗi transition TKQC → `active` (API-ERP-045); sau khi FIN_L1 confirm "đã khớp tiền" (API-ERP-026)
**Owner:** MOD-WALLET-RECON (FIN_L1 là người xác nhận); ADACC chỉ tiêu thụ

**Flow:**
```
1. FIN: đối trừ 3 số khớp → FIN_L1 MFA step-up → POST hard-stop/confirm (API-ERP-026)
2. COMP-ERP-002: cập nhật trạng thái `matched` per customerId + audit hash-chain
3. ASYNC: publish `wallet.matched` (INT-E-001) → COMP-ERP-003 cập nhật điều kiện (tối ưu tốc độ)
4. OPS_AM: transition TKQC (API-ERP-045) → guard SYNC gọi API-ERP-027 hard-stop-status (INT-S-012)
   IF status ≠ 'matched' → 409 `HARD_STOP_ACTIVE` (registry api-contract:54), chặn, DỪNG
5. SWEEP (COMP-ERP-007, batch): re-validate mọi TKQC active vs hard-stop-status tại nguồn
   IF phát hiện active mà chưa khớp → tự revert/khóa + alert FIN + audit
```

**Failure Handling:** event lost/DLQ → sweep vẫn phát hiện và revert (source of truth là guard + sweep, không phải event); guard query fail → fail-closed (chặn transition); confirm thiếu MFA → 403 + audit.

**Constraints:** REQ-FIN-006, REQ-OPS-002; không bao giờ mở hard stop chỉ dựa event; bypass attempt là log level error + alert BOD.

### RULE-X002: Degraded mode manual — GW → mọi consumer

**Systems:** SYS-INTEGRATION-GW (COMP-GW-005/006) → BCERP-WEB, CORE, MOBILE
**Trigger:** Platform API fail vượt retry / mất quyền developer / credential rotate quá hạn >7 ngày
**Owner:** SYS-INTEGRATION-GW (state machine per platform: MANUAL ↔ API ↔ BACKFILL — BR-FIN-301b)

**Flow:**
```
1. GW: adapter fail → circuit breaker → chuyển MANUAL (không cho phép fail câm — mất quyền mà
   không chuyển degraded là lỗi P1)
2. ASYNC: publish `connection.degraded` (INT-E-013) → CORE alert + BCERP-WEB flag health
3. FIN_L1 nhập statement thủ công: API-GW-028/029 imports (schema 8 trường, chặn lỗi theo dòng,
   dòng hợp lệ vẫn nhận; bắt buộc entered_by + evidence_ref — BR-FIN-205b/c)
4. GW ghi nhãn `manual` tại thời điểm ghi → đối trừ 3 số vẫn chạy (tách dimension source_label — gate G4)
5. API phục hồi → BACKFILL tự chạy theo thứ tự thời gian (API-GW-026), gắn nhãn `api` cho dữ liệu gốc,
   KHÔNG xóa bản ghi manual đã đối soát (giữ vết so sánh — BR-FIN-301c)
6. ASYNC: `backfill.completed` (INT-E-009) → CORE đối soát lại kỳ manual → lệch → discrepancy ticket
```

**Failure Handling:** nghiệp vụ KHÔNG dừng khi nền tảng fail (mọi luồng chạy được 100% manual từ ngày 1 — DI-007); import sai schema → hàng lỗi + retry-rows (API-GW-031); backfill fail → retry + alert.

**Constraints:** REQ-FIN-005, REQ-BOD-008; trạng thái degraded hiển thị cho OPS/FIN qua API-GW-025 (INT-S-005); freshness Portal gắn nhãn nguồn tương ứng.

### RULE-X003: Nhãn nguồn `api|manual` bất biến

**Systems:** SYS-INTEGRATION-GW (COMP-GW-004) → CORE ingest (gate G3) → mọi consumer
**Trigger:** Tại thời điểm ghi PlatformStatement/ShopMetricDaily; đọc qua API-GW-032
**Owner:** SYS-INTEGRATION-GW ghi; KHÔNG ai (kể cả FIN) sửa tay

**Flow:** ghi nhãn tại thời điểm ghi → core chỉ đưa bản ghi đủ nhãn (+evidence với `manual`) vào đối trừ → warehouse chỉ đọc nhãn, không ghi đè (gate G3: payload thiếu nhãn → DLQ) → backfill tạo bản ghi MỚI nhãn `api`, không sửa nhãn cũ.

**Failure Handling:** attempt sửa nhãn → 405 `AUDIT_MUTATION_NOT_SUPPORTED` + audit (api-contract §6 GW — tách khỏi `AUDIT_IMMUTABLE` 409 của SYS-CORE-BACKEND); thiếu mapping chuẩn hóa → dòng vào hàng lỗi, không suy diễn (BR-FIN-STGW-004).

**Constraints:** BR-FIN-205a; đối soát lọc theo nhãn; marts tách dimension `source_label` (G4).

### RULE-X004: RBAC/SSO enforcement tập trung — CORE → 5 relying parties

**Systems:** SYS-CORE-BACKEND (COMP-CORE-001/002) → BCERP-WEB, GW, PORTAL-WEB, MOBILE-INTERNAL, MOBILE-PORTAL
**Trigger:** Mọi login và mọi business action
**Owner:** MOD-RBAC-AUDIT (CORE); RP chỉ là PEP, không tự quyết quyền

**Flow:**
```
1. Login: IdP OIDC (API-CORE-001/007) → JWT 15 phút + refresh 7 ngày; claims: user_id, roles[],
   dept, data_scope, tenant_id. MFA step-up (API-CORE-003) bắt buộc: lệnh tiền, dual approval,
   vault, HĐĐT, khóa kỳ [NEEDS_REVIEW: phương pháp MFA — Phụ lục A #9]
2. Mọi request: PEP verify token + introspect (API-CORE-008) + PDP check (API-CORE-014, cache 60s,
   invalidate theo event role/policy change) → allow/deny + scope filter
3. SoD: API-CORE-022 — SoD 4 vai duyệt chi (5/50/200 triệu: FIN_L1 → FIN_L2 → CFO → CEO + delegate
   API-CORE-023); cấm tự-approve 2 nấc; kiêm nhiệm CFO kiêm CTO → cờ combined_role buộc dual approval
   khác người + escalation CEO (REQ-BOD-002)
4. Vault: chỉ BOD_CFO_CTO quản trị, MFA bắt buộc; request vault từ mobile bị chặn tầng gateway + log
   cảnh báo (BR-GW-STGW-005)
5. Offboarding/thu hồi: session revoke tức thời (API-CORE-006), portal user thu hồi ≤24h (BR-FIN-603)
```

**Failure Handling:** PDP unreachable → fail-closed cho action tài chính [NEEDS_REVIEW: fail-open/closed luồng đọc — #14]; deny → 403 + audit access-denied; mobile không tự cấp/bỏ quyền.

**Constraints:** REQ-BOD-011 (1 IdP, 5 RP), REQ-BOD-007 (quarterly access review — API-CORE-024..027, bằng chứng nộp WORM); 18 vai chuẩn [NEEDS_REVIEW: liệt kê đủ — #8].

### RULE-X005: Tenant isolation — PORTAL / MPO

**Systems:** SYS-PORTAL-WEB + SYS-MOBILE-PORTAL ↔ CORE (RLS + mask) + GW feed
**Trigger:** Mọi request client-facing
**Owner:** COMP-PORTAL-002 (BFF DMZ, tenant_id bắt buộc) + COMP-GW-012 (PII guard) + CORE RLS

**Flow:** mọi request scoping tenant_id (RLS DB + filter API 2 lớp) → read-model đã mask + freshness metadata (thiếu metadata → không render số) → chặn cứng route ghi tài chính (403 + log — ví read-only tuyệt đối REQ-FIN-017) → từ chối đăng nhập tài khoản nội bộ (client identity tách internal) → GMV Portal giữ reference_only + phạm vi hiển thị [NEEDS_REVIEW: Phụ lục A #17].

**Failure Handling:** thử chéo tenant/quét dữ liệu → rate limit + alert, lặp lại → khóa phiên + escalate SYS_ADMIN/FIN_L2 (COMP-PORTAL-005); GW feed thiếu tenant filter → chặn (api-contract §6.4); test truy cập chéo hàng quý (BR-OPS-4.2b).

**Constraints:** REQ-FIN-017; giá vốn/chiết khấu/P&L/tỷ giá nội bộ không bao giờ vào payload khách; PortalReportFeed đã mask + tenant-scoped (BR-GW-TT-002).

### RULE-X006: WORM audit path

**Systems:** Mọi module → CORE COMP-CORE-004 (hash-chain) → COMP-CORE-005 (Object Lock ≥10 năm); GW COMP-GW-007 dùng chung hạ tầng
**Trigger:** Mọi state transition, action tiền/chứng từ, thao tác vault (kể cả "xem log cũng bị log")
**Owner:** SYS-CORE-BACKEND

**Flow:** ghi qua API-CORE-028 (đường append DUY NHẤT, không update/xóa) → hash-chain tamper-evident → export định kỳ → WORM ≥10 năm cho log tiền + chứng từ (REQ-FIN-012); GW audit (API-GW-035) append-only cùng chuẩn; integrity verify định kỳ (API-CORE-032), bất thường hash-chain → alert BOD (REQ-BOD-005).

**Failure Handling:** Core chậm → buffer local + retry, KHÔNG chặn nghiệp vụ — trừ action tài chính (fail-closed); log tiền + chứng từ KHÔNG đi pipeline analytics, chỉ đi luồng audit → WORM.

**Constraints:** Truy xuất có kiểm soát (BOD_CEO giám sát; FIN truy xuất có phạm vi); PII break-glass đọc phải log [NEEDS_REVIEW: quy trình khẩn cấp — Phụ lục A, COMP-CORE-006].

### RULE-X007: Freshness metadata là điều kiện render (P&L/BI/Portal)

**Systems:** CORE COMP-CORE-010 → BCERP-WEB + MOBILE-INTERNAL; PORTAL read-model
**Trigger:** Mọi lần render số liệu BI/ví/spend
**Owner:** MOD-DATAHUB-BI (cung cấp metadata); consumer chịu trách nhiệm render

**Flow:** mỗi mart/read-view expose `(last_watermark, loaded_at, freshness_sla, is_stale)` (API-CORE-040, API-PORTAL-036) → consumer chỉ render khi `is_stale=false`; stale → hiển thị nhãn "dữ liệu tính đến `<loaded_at>`" + cảnh báo, không render số cũ im lặng → Portal gắn thêm nhãn nguồn `api|manual` + disclaimer độ trễ (số dư 15 phút–24h; chi tiêu daily 3–24h).

**Failure Handling:** thiếu metadata → chặn render; Freshness vi phạm SLA → alert (COMP-CORE-011 rule).

**Constraints:** REQ-BOD-003/004, REQ-FIN-015/016/017; P&L realtime target ≤5 phút [NEEDS_REVIEW: SLA ingest toàn bảng — Phụ lục A #10].

### RULE-X008: GMV firewall — reference_only tuyệt đối

**Systems:** GW (COMP-GW-011/012) → CORE marts (gate G5) → mọi consumer nội bộ + Portal
**Trigger:** Mọi tổng hợp có mặt TikTok Shop GMV/settlement
**Owner:** SYS-INTEGRATION-GW

**Flow:** ShopMetricDaily ghi với `reference_only=true` luôn bật → chặn cứng TẦNG API mọi attempt mapping GMV/settlement vào tài khoản doanh thu (không chỉ UI) → marts tách luồng `shop_reference` khỏi `pnl_realtime`, join chỉ qua mã tham chiếu ở lớp tổng hợp (BR-OPS-4.3a) → Portal scope hiển thị theo cấu hình hợp đồng.

**Failure Handling:** gate G5 fail → mart không publish + alert; attempt map doanh thu → chặn + audit.

**Constraints:** BR-OPS-4.4; GMV là chỉ số tham chiếu của khách, cấm tính vào P&L agency.

### RULE-X009: GW outbound endpoint allowlist (SSRF guard)

**Systems:** SYS-INTEGRATION-GW (COMP-GW-001/002/003 + INFRA-GW-007 egress proxy)
**Trigger:** Tạo/cập nhật ConnectionProfile (API-GW-002/004) và mỗi lần adapter thực hiện outbound
**Owner:** SYS-INTEGRATION-GW (profile do CTO duyệt — REQ-BOD-008)

**Flow:** `config_json.endpoint` chỉ được chấp nhận khi khớp allowlist domain per-platform đã đăng ký trong Connector Registry → không khớp → từ chối lưu/kích hoạt + audit + alert; egress proxy chỉ route theo registry, chặn dải IP nội bộ/private-range và domain ngoài allowlist (bổ trợ firewall deny-all infra-spec GW §4).

**Failure Handling:** endpoint sai allowlist → 400 `CONNECTOR_NOT_IN_REGISTRY` (ngoài registry) hoặc `VALIDATION_ERROR` + audit; phát hiện endpoint trỏ dải nội bộ → alert CRITICAL (nghi ý đồ quét mạng trong).

**Constraints:** REQ-BOD-008; Rule bổ sung từ Gap Analysis F-D-14 — giảm rủi ro GW bị dùng làm cầu nối SSRF khi `config_json` cho phép tự cấu hình endpoint.

### 7.A Object 360 — data needs aggregation (v4.1)

> Mỗi working surface (web + mobile) tổng hợp dữ liệu đa module để user không phải rời màn hình. Aggregation do BFF/surface thực hiện qua API-ID sau (đã có trong aggregation-result); không nhân bản business logic.

| Object 360 | Data cần (nguồn module) | Kênh + API-ID chính | Client-facing |
|------------|--------------------------|---------------------|---------------|
| **Lead 360** (SALES) | Lead lifecycle (CRM) + tier + activity timeline (CRM) + deal/quotation liên quan (QDD) + gate history | API-ERP-004 detail, API-ERP-005 activity, API-ERP-009 tier-review, API-ERP-011 quotations; timeline audit API-CORE-030 | Nội bộ (BCERP-WEB, MBI-008) |
| **Deal 360** (SALES+FIN) | Quotation/contract (QDD) + margin/discount approval (QDD) + AR invoice + payment status (ARAP) + commission theo deal (COMM) | API-ERP-012/013/014 + API-ERP-030 + API-ERP-039 + API-ERP-042 | Nội bộ (BCERP-WEB, MBI-009/011) |
| **TKQC 360** (OPS+FIN) | Registry + lifecycle + KYC state (ADACC) + hard-stop status (WALLET) + spend/số dư feed (GW) + freshness + nhãn nguồn | API-ERP-044/045 + API-ERP-027 + API-GW-032 + API-GW-048 + API-GW-025 | Nội bộ (BCERP-WEB, MBI-012); khách chỉ thấy per-tenant qua Portal ví views |
| **Ví/KH 360** (FIN+OPS) | Sổ phụ + lệnh tiền + dual approval state (WALLET) + đối trừ + period lock (WALLET) + AR aging (ARAP) + portal accounts (PORTAL module) | API-ERP-020/021/022/023/024/025 + API-ERP-030/032 + API-ERP-055/056; cảnh báo qua API-PORTAL-023 | Nội bộ; khách: API-PORTAL-019..023 (read-only) |
| **Campaign 360** (OPS) | Campaign/deliverable (CAMP) + stage proposal (PROPLN) + handoff scope (HONB) + TKQC active (ADACC) + nghiệm thu milestone | API-ERP-047/048/049/050/051/052/053 + API-ERP-019 | Nội bộ; khách: API-PORTAL-024..026, API-MPO-023..026 (confirm nghiệm thu nhẹ) |
| **Ticket 360** (OPS+CSKH) | Ticket + queue + SLA state (CSKH) + tier khách (CRM) + context campaign/TKQC + portal origin | API-ERP-058/059/060/061 + API-PORTAL-027/028/029/030; SLA API-ERP-072/073 | Nội bộ (MBI-017); khách: API-PORTAL-027..030, API-MPO-027..032 |

### 7.B Propagation rules cross-department (v4.1)

> Mức lan truyền để working surface của phòng ban liên quan cập nhật mà không cần user rời màn hình.

| Mức | Đối tượng lan truyền | Cơ chế | Người nhận (surface) |
|-----|----------------------|--------|----------------------|
| **Realtime** (event push) | Tiền: `wallet.matched`, `wallet.low_balance` (SLA đỏ 2h), dual approval cần quyết; hard stop mở/chặn TKQC; `sla.breach` + escalation; `connection.degraded`; `shop.alert` | Event Kafka → SLANOT dispatch → in-app + push (API-MBI-034, COMP-MPO-003); PDP cache invalidate event | FIN, OPS, BOD (approval inbox MBI-005/006, alert center MBI-007/017/018) |
| **Near-realtime** (≤5 phút) | Business events: `deal.signed`, `handoff.ops_ack` + onboarding tasks, `payment.received`/`refund.executed` (commission/clawback), `timesheet.approved`, ticket/lead reassign, portal account lifecycle, `portal.adoption.*` | Event → consumer cập nhật state + read-model; freshness mart ≤5 phút cho nhóm FIN | SALES, OPS, HR, PORTAL read-model |
| **Batch** (định kỳ) | BI/P&L dashboard, đối trừ 3 số + reconcile, aging/dunning, KPI auto-aggregate, HĐLĐ 90/60/30, clawback sweep, checkpoint Day 1/7/14/30, gate Day-14 report, access review quarterly | COMP-ERP-007 scheduler + COMP-CORE-007 ingest pull/CDC + COMP-CORE-008 marts (SLA freshness theo nhóm — P3-01 §10.3) | BOD/FIN (BI serving), HR (KPI), OPS (checkpoint) |

### 7.C Assignment / ownership change events (v4.1)

| Sự kiện | API gốc | Event | Phòng ban khác cần biết gì |
|---------|---------|-------|---------------------------|
| Lead reassign | API-ERP-007 (SALES_L2+ duyệt) | `lead.assigned` / `lead.reassigned` (INT-E-014) | OPS: context tiếp thị lại khi lead qualified; CSKH: tier owner đổi → SLA theo tier mới; KPI: pipeline attribution |
| Ticket reassign | API-ERP-059 | `ticket.assigned` / `ticket.reassigned` (INT-E-015) | SLANOT: reset/hẹn timer SLA theo assignee mới; PORTAL: khách thấy trạng thái "đang xử lý bởi" refreshed; escalation path AM→AD→BOD giữ nguyên |
| Handoff ack | API-ERP-018 (ký 2 phía) | `handoff.ops_ack` (INT-E-003) | FIN: mở theo dõi ví khách mới; OPS: sinh task TKQC + portal + campaign; BOD: gate Day-14 adoption bắt đầu đo |
| Portal account cấp/thu hồi | API-ERP-055; API-PORTAL-014/015 | `portal.account.lifecycle` (INT-E-016) | FIN: phạm vi chia sẻ dữ liệu tài chính đổi → kiểm soát REQ-FIN-017; SYS_ADMIN: thu hồi ≤24h; OPS: monitor adoption (API-ERP-056 usage) |
| Đổi vai/phòng (RBAC) | API-CORE-017/018 | role/policy change event (invalidate PDP cache) | Module owner: recertification tự động (COMP-CORE-003); GW: rà soát quyền vault |

---

## 8. Data Consistency Rules

| Rule | Mô tả | Owner System |
|------|-------|-------------|
| DC-001 | Trạng thái hard stop tại ADACC guard phải khớp hard-stop-status tại nguồn (WALLET) — sweep re-validate mỗi batch; lệch → revert TKQC | SYS-BCERP-WEB |
| DC-002 | Nhãn nguồn `api|manual` immutable — record thiếu nhãn bị reject vào ingest (gate G3), attempt sửa → 405 `AUDIT_MUTATION_NOT_SUPPORTED` | SYS-INTEGRATION-GW |
| DC-003 | PlatformStatement (GW) là bản ghi thô gắn nhãn; kết quả đối trừ 3 số thuộc WALLET (BCERP-WEB) — GW không tự quy đổi tỷ giá, lưu amount_original + currency nguyên vẹn | GW ghi / BCERP-WEB reconcile |
| DC-004 | Commission computed phải truy vết được về ARAP đã thu + QDD deal value + tier nhân viên; clawback sweep đối chiếu computed vs approved | SYS-BCERP-WEB (COMM) |
| DC-005 | Giờ timesheet chưa `approved` không được vào P&L (hiển thị tách dòng ước tính) | BCERP-WEB ghi / CORE compute |
| DC-006 | Portal read-model phải mang freshness metadata theo SLA (số dư 15 phút–24h, chi tiêu daily 3–24h); thiếu → không render | SYS-PORTAL-WEB |
| DC-007 | Marts vs nguồn: reconcile stream vs batch nightly; lệch quá ngưỡng → alert + rebuild [NEEDS_REVIEW: ngưỡng — P3-01 §10.5] | SYS-CORE-BACKEND |
| DC-008 | TKQC `active` đòi hỏi KYC verified + hard stop `matched` (2 điều kiện độc lập, cùng guard tại transition) | SYS-BCERP-WEB (ADACC) |
| DC-009 | Currency USD/VND không gộp quy đổi tùy tiện; snapshot fee %/tỷ giá tại thời điểm giao dịch; Idempotency-Key cho mọi money command | SYS-BCERP-WEB (WALLET) |
| DC-010 | Portal adoption số liệu tính tại CORE từ dữ liệu thực (portal không giữ số cục bộ) | SYS-CORE-BACKEND |

---

## 9. Compensation Patterns

```
Saga — Handoff → Onboarding (INT-E-003):
  1. COMP-ERP-001: ops_ack commit (ký 2 phía) — nguồn sự thật
  2. ASYNC sinh 3 nhóm task (ADACC / PORTAL / CAMP), idempotent theo (handoffId, taskType)
  3. Task fail → retry → DLQ → alert; checkpoint sweep Day-1 (COMP-ERP-007) bắt kịp task thiếu
  → Không rollback ops_ack: onboarding là hệ quả có thể tái tạo (replay event + sweep)

Compensating control — Event lost trên hard control (RULE-X001):
  Event `wallet.matched` lost/DLQ → sweep re-validate tại nguồn phát hiện lệch → tự revert/khóa TKQC
  → event là tối ưu tốc độ, sweep là an toàn; mọi revert ghi audit + alert FIN

Idempotency:
  - Consumer: natural key per event (customerId+period / handoffId+taskType / paymentId /
    platform+adaccount+window) + eventId dedup
  - Command tiền: Idempotency-Key header bắt buộc (API-ERP-022/033...)
  - Scheduler: key (job, window) + distributed lock Redis; re-run an toàn

Backfill (RULE-X002): dữ liệu manual đã đối soát KHÔNG bị ghi đè/xóa khi API sống lại —
  backfill tạo bản ghi `api` mới, giữ bản ghi manual làm vết so sánh (BR-FIN-301c)

DLQ discipline: không auto-replay; replay = hành động người qua API-CORE-048 (ingest) /
  API-ERP-077 (job), ghi audit; DLQ depth là alert thường trực
```

---

## Metadata

| Field | Value |
|-------|-------|
| **Tài liệu** | Integration Map — BCERP |
| **Phiên bản** | v1.0 |
| **Tạo bởi** | ARCHITECT (wf-design Phase 3 — session 20260913-053848-f4d7) |
| **Ngày tạo** | 2026-09-13 |
| **Cập nhật lần cuối** | 2026-09-13 |
| **Trạng thái** | Draft |
| **Nguồn tra cứu ID** | `$SESSION_DIR/aggregation-result.json` — 60 components / 280 APIs (14 sync points INT-S, 16 events INT-E) |
| **[NEEDS_REVIEW] chính** | #2 nguồn sao kê ngân hàng; #3 kênh notification ngoài; #4 e-sign path; #6 contract publish read-model PORTAL; #8 liệt kê 18 vai; #9 phương pháp MFA; #10 SLA ingest; #14 fail-open/closed PDP; #15 webhook receiver GW; #16 cơ chế VAS; #17 phạm vi GMV Portal |

> Tài liệu này cập nhật bất cứ khi nào thêm integration mới, thay đổi event schema (tăng version), hoặc thêm cross-system rule. Không đổi schema event đã published mà không thông báo subscribers trước.
