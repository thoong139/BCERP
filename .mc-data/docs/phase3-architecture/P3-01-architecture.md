# Thiết Kế Kiến Trúc — BCERP (BC Agency Enterprise Resource Planning)

> **Dựa trên:** Tổng quan dự án + Yêu cầu nghiệp vụ (Phase 1) + 170 feature specs (Phase 2) + Business Context Baseline v4.1
> **Cập nhật bởi:** wf-design Phase 1 (Lane Dispatch 6 systems — session 20260913-053848-f4d7)
> **Ngày:** 13/09/2026
>
> READS: `_meta/req-registry.json` (6 SYS / 19 MOD / 59 REQ / 170 FEAT), `phase2-features/**/*.md`, `work/wf-design/sessions/20260913-053848-f4d7/business-context.md`, `lanes/*/arch-draft.md`
> USED BY: `technical-specs/api-contract.md`, `technical-specs/database-design.md`, `technical-specs/integration-map.md`, `technical-specs/infra-spec.md`, `phase4-ux/design-system.md`

**Bối cảnh khách hàng:** BC Agency — digital marketing agency, trung gian quản lý TKQC đa nền tảng (Meta, Google, TikTok, Bing, X, Pinterest, Yandex), 1.000+ khách hàng, 2.600+ TKQC active. Vai đặc thù: BOD_CEO, BOD_CFO_CTO (kiêm nhiệm có compensating control — REQ-BOD-002), SYS_ADMIN, HR_L1/L2, FIN_L1/L2, SALES_L1–L3, OPS_PLAN/AM/CONT, ESS, CLIENT_ADMIN/CLIENT_USER (external).

**Quy ước label:** LEGACY_MODE=false → mọi decision là đề xuất mới (không ghi [RECOMMENDED]). Chỗ thiếu căn cứ → [NEEDS_REVIEW].

---

## 1. Quyết Định Kiến Trúc

| Hạng mục | Quyết định | Lý do |
|----------|-----------|-------|
| Kiến trúc tổng thể | **Modular Monolith** cho domain services (SYS-BCERP-WEB) + nền tảng tập trung (SYS-CORE-BACKEND) + headless gateway (SYS-INTEGRATION-GW) + thin clients (PORTAL-WEB, 2 mobile apps) | 1 team quy mô vừa, cần enforce SoD/hard stop xuyên module nhanh; biên giới module = code boundary + event contract, sẵn seam tách service sau này. REQ-BOD-002, REQ-FIN-006 đòi hỏi approval engine dùng chung — monolith giảm chi phí enforce |
| Frontend (web nội bộ) | React SPA + BFF (NestJS) | Đội quen Node/TS; BFF aggregation per working-surface, không expose domain service ra browser |
| Frontend (portal + mobile) | Portal: Next.js/React DMZ; Mobile: React Native (đề xuất — [NEEDS_REVIEW: chốt platform]) + BFF mỏng | Portal cần SSR/i18n/SEO-none + DMZ; RN 1 codebase iOS/Android + OTA |
| Backend | Node.js + NestJS (TypeScript) toàn platform | Nhất quán stack, recruitment nội bộ, typing hỗ trợ contract-first |
| Cơ sở dữ liệu chính | PostgreSQL 16 (per-system schema), RLS cho tenant isolation (portal) | ACID cho tiền giữ hộ + dual approval; RLS bắt buộc cho isolation 1.000+ khách client-facing (REQ-FIN-017) |
| Analytics warehouse | ClickHouse (đề xuất) — raw → staged → marts trong SYS-CORE-BACKEND | P&L realtime REQ-BOD-003/FIN-016 cần columnar stream aggregation; tách OLAP khỏi OLTP |
| Cache | Redis (cache TTL, distributed lock, rate limit, session) | Session SSO, idempotency, scheduler lock (COMP-ERP-007) |
| Hàng đợi tin nhắn | Kafka (đề xuất, platform infra dùng chung) cho CDC/event; Redis queue cho job nhẹ | Event contract xuyên module (ví.matched → hard stop) + CDC ingest DataHub; outbox pattern mọi publisher |
| Xác thực | OIDC/OAuth2 SSO tập trung (COMP-CORE-001) + MFA step-up (TOTP) cho action tài chính/vault | REQ-BOD-011 — 1 IdP duy nhất, 5 relying parties; MFA bắt buộc vault (REQ-BOD-008) |
| Định dạng API | REST + JSON, versioned `/api/v1/`, state-transition endpoint tường minh | REST đủ cho 6 systems; transition endpoint phục vụ state machine audit |
| Lưu trữ file | S3-compatible object storage + Object Lock (WORM) cho evidence ≥10 năm (REQ-FIN-012) | WORM compliance tiền/chứng từ; raw payload archival GW |

**Quyết định nền tảng khác:** (1) degraded mode `manual` là trạng thái khởi điểm toàn hệ thống (DI-007 — chưa có quyền developer API nền tảng), mọi luồng phải chạy được 100% manual từ ngày 1; (2) connector vendor-agnostic qua Settings (DI-004) — đổi phần mềm kế toán VAS = thêm profile, không sửa code; (3) Financial Hard Stop "đã khớp tiền" (FIN_L1) là điều kiện bắt buộc trước khi TKQC active — sweep re-validate tại nguồn, event chỉ là tối ưu.

---

## 2. Sơ Đồ Kiến Trúc Hệ Thống

```
                        ┌──────────────────── NGƯỜI DÙNG ────────────────────┐
                        │  Nội bộ: BOD, FIN, SALES, OPS, HR, ESS             │
                        │  Khách hàng: CLIENT_ADMIN / CLIENT_USER            │
                        └───┬──────────────┬──────────────┬──────────────────┘
                            │ HTTPS        │ HTTPS        │ HTTPS
                  ┌─────────▼─────┐ ┌──────▼───────┐ ┌────▼──────────┐
                  │ BCERP WEB     │ │ CLIENT PORTAL│ │ MOBILE APPS   │
                  │ (SPA+BFF)     │ │ (DMZ, SPA)   │ │ RN: Internal  │
                  │ [SYS-BCERP-WEB]│ │[SYS-PORTAL-WEB]│ │  + BC Portal │
                  └───────┬───────┘ └──────┬───────┘ └────┬──────────┘
                          │ REST /api/v1   │ read-model   │ REST + Push
                          ▼                ▼              ▼
        ┌───────────────────────────────────────────────────────────────┐
        │                 SYS-CORE-BACKEND (nền tảng)                   │
        │  IdP SSO/MFA · RBAC Policy Engine (PDP) · Audit/WORM ≥10 năm  │
        │  PII Field Protection · DataHub: CDC/ETL → Warehouse → P&L    │
        │  Realtime · BI Serving · Alert Center · Access Review         │
        └───────▲───────────────────────────────▲───────────────────────┘
                │ policy/token/serving          │ ingest (pull + CDC + event)
        ┌───────┴───────────────┐      ┌────────┴────────────────┐
        │ SYS-BCERP-WEB         │      │ SYS-INTEGRATION-GW      │
        │ Domain services:      │◄────►│ Connector Registry      │
        │ Sales & Pipeline      │event │ Credentials Vault       │
        │ Finance & Treasury    │      │ Sync/Rate-limit Queue   │
        │ Ad Account & Delivery │      │ Degraded/Backfill       │
        │ Client Care · People  │      │ TikTok Shop Monitor     │
        │ SLA&Notif · Scheduler │      │ (outbound 7 nền tảng +  │
        └───────────────────────┘      │  VAS, pull-based)       │
                │ read-view           └────────┬────────────────┘
                ▼                              │ outbound API
        ┌──────────────────┐          ┌──────────▼───────────────┐
        │ Nền tảng ngoài:  │          │ Meta Google TikTok Bing  │
        │ Portal read-model│          │ X Pinterest Yandex VAS   │
        └──────────────────┘          └──────────────────────────┘

  Mobile apps KHÔNG gọi trực tiếp GW — mọi dữ liệu nền tảng qua backend.
  Vault management CẤM từ mobile (BR-GW-STGW-005).
```

> **Chi tiết DDL:** Xem `technical-specs/database-design.md`. **Chi tiết integration:** `technical-specs/integration-map.md`.

---

## 3. Danh Sách Phân Hệ (Systems)

| Phân hệ | ID | Port (đề xuất) | Schema DB | URL prefix | Phòng ban phụ trách |
|---------|-----|------|----------|------------|-------------------|
| BCERP Web nội bộ (domain services + BFF) | SYS-BCERP-WEB | 8081 | `erp_sales`, `erp_finance`, `erp_ops`, `erp_people`, `erp_sla` | `/api/v1/erp/*` | SALES, FIN, OPS, HR, BOD |
| Core Backend (nền tảng) | SYS-CORE-BACKEND | 8080 | `core_identity`, `core_audit`, `core_dhub` | `/api/v1/core/*` | BOD (CTO), SYS_ADMIN |
| API Integration Gateway | SYS-INTEGRATION-GW | 8082 | `gw_connector`, `gw_tiktok` | `/api/v1/gw/*` | BOD (CTO) sở hữu, OPS tiêu thụ |
| Client Portal Web | SYS-PORTAL-WEB | 8083 | `portal_account` | `/api/v1/portal/*` | OPS quản trị, CUSTOMER sử dụng |
| Mobile App BCERP Internal | SYS-MOBILE-INTERNAL | — (BFF 8084) | `mbi_device` | `/api/v1/mbi/*` | Toàn bộ nội bộ |
| Mobile App BC Portal | SYS-MOBILE-PORTAL | — (BFF 8085) | `mpo_device` | `/api/v1/mpo/*` | CUSTOMER |

### 3.1 Thành phần chính theo phân hệ (60 components — chi tiết đầy đủ trong `$SESSION_DIR/lanes/*/signals.json`)

| System | Components |
|--------|-----------|
| SYS-BCERP-WEB (7) | COMP-ERP-001 Sales & Pipeline (CRM+QDD+HONB) · COMP-ERP-002 Finance & Treasury (WALLET+ARAP+COMM) · COMP-ERP-003 Ad Account & Delivery (ADACC+PROPLN+CAMP) · COMP-ERP-004 Client Care (CSKH) · COMP-ERP-005 People & Performance (HR+CAPTS+KPI) · COMP-ERP-006 SLA & Notification Worker (SLA-NOTIF) · COMP-ERP-007 Batch & Recon Scheduler |
| SYS-CORE-BACKEND (11) | COMP-CORE-001 IdP & SSO/MFA · 002 RBAC & Policy Engine (PDP) · 003 Access Review Worker · 004 Audit Log Service (hash-chain) · 005 WORM Evidence Store · 006 PII Field Protection · 007 CDC/ETL Ingest · 008 Analytics Warehouse · 009 Realtime P&L Compute · 010 BI Serving API · 011 Alert Engine |
| SYS-INTEGRATION-GW (13) | COMP-GW-001 Connector Registry & Adapter Framework (DI-004) · 002 Credentials Vault · 003 Sync Scheduler & Rate-Limited Queue · 004 Ingest & Normalization (nhãn api/manual bất biến) · 005 Degraded Mode & Backfill · 006 Health & Policy Config · 007 Gateway Audit & API Call Log · 008 VAS Accounting Connector · 009 Wallet & TKQC Feed Dispatcher · 010 TikTok Shop Connection Manager · 011 TikTok Shop Metrics Sync · 012 PII Guard & Tenant Isolation · 013 Shop Alert & Portal Feed Emitter |
| SYS-PORTAL-WEB (6) | COMP-PORTAL-001 Portal Web App · 002 Portal API Gateway/BFF (DMZ) · 003 Portal Identity & Account · 004 Read-Model Serving · 005 Audit, Watermark & Anomaly · 006 Adoption Event Forwarder |
| SYS-MOBILE-INTERNAL (20) | COMP-MBI-001 App Shell · 002 Offline Sync & Cache · 003 Mobile BFF · 004 Push Consumer · 005–020 surface theo 16 module (approval inbox, wallet, BI, gates, ESS, ticket, shop alert...) |
| SYS-MOBILE-PORTAL (3) | COMP-MPO-001 BC Portal Mobile App · 002 Portal Mobile BFF · 003 Portal Push Worker |

**Phạm vi biên giới (tóm tắt từ lane drafts):** SYS-BCERP-WEB sở hữu 14 business modules (canonical SSOT); SYS-CORE-BACKEND sở hữu identity/audit/analytics, KHÔNG sở hữu business object; SYS-INTEGRATION-GW là cổng outbound duy nhất, headless, chỉ dữ liệu gắn nhãn nguồn `api`/`manual`; PORTAL/MOBILE là thin clients không chứa business logic, mobile cấm vault + offline queue cấm cho lệnh tiền.

---

## 4. Phân Quyền Dữ Liệu (Data Ownership)

| Loại dữ liệu | Phân hệ sở hữu | Phân hệ được đọc |
|-------------|---------------|----------------|
| Identity, credential, session, role/permission/policy | SYS-CORE-BACKEND | Tất cả (qua OIDC + PDP) |
| Audit log, WORM evidence ≥10 năm | SYS-CORE-BACKEND | BOD_CEO giám sát; FIN truy xuất có kiểm soát |
| Analytics warehouse (raw/staged/marts), P&L, alert registry | SYS-CORE-BACKEND | BCERP-WEB, MOBILE-INTERNAL (BI serving) |
| Lead, tier, gate, quotation/contract/e-sign, handoff package | SYS-BCERP-WEB (COMP-ERP-001) | CORE (ingest), PORTAL (read-model qua share model) |
| Ví ledger, lệnh tiền, đối trừ 3 số, period lock, AR/AP, HĐĐT, commission | SYS-BCERP-WEB (COMP-ERP-002) | CORE (ingest), PORTAL (ví read-only — REQ-FIN-017), MOBILE-INTERNAL |
| TKQC registry + KYC state, proposal stage, campaign/deliverable | SYS-BCERP-WEB (COMP-ERP-003) | CORE, GW (gate stage tín hiệu), MOBILE-INTERNAL |
| Ticket CSKH | SYS-BCERP-WEB (COMP-ERP-004) | CORE, PORTAL (ticket của tenant), MOBILE-* |
| Hồ sơ HR, HĐLĐ, chấm công, nghỉ phép, rate card, KPI/PIP, timesheet | SYS-BCERP-WEB (COMP-ERP-005) | CORE (ingest có masking PII) |
| SLA policy instance, notification log | SYS-BCERP-WEB (COMP-ERP-006) | CORE, MOBILE (push consumer) |
| ConnectionProfile, CredentialVersion, SyncJob, PlatformStatement (gắn nhãn), raw payload, backfill run | SYS-INTEGRATION-GW | CORE (ingest + oversight), BCERP-WEB (health/degraded flag) |
| TikTok ShopConnection, ShopMetricDaily (`reference_only=true`), PortalReportFeed | SYS-INTEGRATION-GW (MOD-TIKTOK-SHOP) | CORE, PORTAL feed (đã mask, tenant-scoped) |
| portal_user, portal_invite, session 2FA, portal_access/download_log | SYS-PORTAL-WEB | CORE (gate Day 14 telemetry) |
| Device registration, push token, encrypted local cache | SYS-MOBILE-INTERNAL / SYS-MOBILE-PORTAL | Tương ứng backend |
| Số dư/spend platform (7 nền tảng) bản ghi thô | GW ghi, FACT tables + kết quả đối trừ thuộc BCERP-WEB (WALLET) | — |

**Quy tắc bắt buộc:**
- Phân hệ sở hữu: đọc + ghi. Phân hệ khác: chỉ qua REST API hoặc event — KHÔNG truy cập thẳng DB system khác.
- PII lương (Confidential/Restricted): chỉ HR_L1/L2 thấy rõ; ETL vào warehouse phải mask trước (REQ-HR-010).
- Nhãn nguồn `api`/`manual` do GW ghi tại thời điểm ghi, immutable, kể cả FIN không sửa tay — core đối soát lọc theo nhãn.
- GMV TikTok Shop là chỉ số tham chiếu của khách, cấm map vào doanh thu agency.

---

## 5. Giao Tiếp Giữa Các Phân Hệ

> **Chi tiết đầy đủ:** `technical-specs/integration-map.md` (Phase 3 — signal aggregation).

**Gọi đồng bộ (REST) — các tuyến chính:**

| Phân hệ gọi | Phân hệ nhận | Endpoint (khung) | Khi nào gọi |
|------------|-------------|---------|------------|
| Mọi system (RP) | SYS-CORE-BACKEND | `POST /core/auth/token`, `POST /core/auth/mfa/step-up` | Login, action tài chính/vault |
| Mọi service (PEP) | SYS-CORE-BACKEND | `POST /core/pdp/check` (hoặc embedded policy qua cache TTL) | Trước mọi business action |
| SYS-BCERP-WEB | SYS-CORE-BACKEND | `GET /core/bi/marts/*`, `GET /core/audit/*` | Render dashboard, truy xuất audit |
| SYS-BCERP-WEB | SYS-INTEGRATION-GW | `GET /gw/statements?platform=&adaccountRef=&windowFrom=&windowTo=&sourceLabel=`, `GET /gw/health` | Đối trừ 3 số, hiển thị trạng thái sync vs manual |
| SYS-INTEGRATION-GW | Nền tảng ngoài | Per-platform adapter API (pull-based, rate-limited) | Sync hourly + on-demand |
| SYS-PORTAL-WEB | SYS-CORE-BACKEND | `GET /core/portal-views/*` (RLS + tenant filter + mask) | Mọi view client-facing |
| SYS-MOBILE-* | Backend tương ứng | `/api/v1/mbi/*`, `/api/v1/mpo/*` qua BFF | Mọi thao tác mobile |
| SYS-PORTAL-WEB | SYS-BCERP-WEB | `POST /erp/tickets` (điểm ghi duy nhất), publish read-model contract | Tạo ticket từ portal; sync ví/campaign/invoice view |

**Gọi bất đồng bộ (Event) — các event tải trọng cao (outbox pattern, consumer idempotent, DLQ bắt buộc):**

| Phân hệ phát | Tên event | Phân hệ nhận | Khi nào phát |
|-------------|----------|-------------|-------------|
| COMP-ERP-002 | `wallet.matched` | COMP-ERP-003 (+ sweep re-validate tại nguồn) | FIN_L1 confirm sau khi đối trừ 3 số khớp (API-ERP-026) → mở hard stop TKQC |
| COMP-ERP-002 | `wallet.low_balance` | COMP-ERP-006 | Số dư < đủ chi ≥3 ngày → SLA đỏ 2h |
| COMP-ERP-001 | `handoff.ops_ack` | COMP-ERP-003, PORTAL | OPS ký nhận → sinh onboarding tasks (TKQC, portal account, campaign) |
| COMP-ERP-001 | `deal.signed` | COMP-ERP-002 | HĐ signed → mở AR schedule + handoff draft |
| COMP-ERP-002 | `payment.received` / `refund.executed` | COMP-ERP-002 (COMM) | Commission computed / clawback |
| COMP-ERP-005 | `timesheet.approved` | CORE DataHub, KPI | Giờ duyệt mới vào P&L + KPI |
| COMP-ERP-006 | `sla.warning` / `sla.breach` | Module owner + escalation path + MOBILE push | Timer SLA |
| COMP-GW-009 | `wallet.sync.completed` | CORE (WALLET feed, alert) | Mỗi sync window |
| COMP-GW-005 | `backfill.completed` | CORE (đối soát lại kỳ manual) | Backfill xong |
| COMP-GW-013 | `shop.alert` | CORE alert center, MOBILE-INTERNAL push | Anomaly shop |
| COMP-CORE-011 | `alert.raised` | COMP-ERP-006 (dispatch), MOBILE | Alert center sinh alert |
| COMP-PORTAL-006 | `portal.adoption.*` | CORE (gate Day 14) | Kích hoạt/login/tạo user portal |

---

## 6. Các Quy Ước Áp Dụng Toàn Hệ Thống

| Hạng mục | Quy ước |
|----------|--------|
| Định dạng ID | UUID v4; component/API theo convention `COMP-*`, `API-*` ở spec layer |
| Múi giờ lưu DB | UTC; SLA/timer hiển thị + tính theo GMT+7 (Asia/Ho_Chi_Minh) |
| Định dạng ngày | ISO 8601 (YYYY-MM-DD) |
| Xóa dữ liệu | Soft delete — `deleted_at` (riêng audit log/WORM: bất biến, không xóa) |
| Phân trang | `?page=1&limit=20` (mặc định 20, tối đa 100) — server-side filter/sort bắt buộc |
| Format lỗi | `{ "success": false, "error": "...", "code": "..." }` — error code registry tập trung |
| Logging | Structured JSON + correlationId xuyên suốt; audit nghiệp vụ ghi qua COMP-CORE-004 (hash-chain) |
| Versioning API | `/api/v1/` bắt buộc; breaking change → v2 + deprecation window |
| Tiền | DECIMAL per-currency (USD/VND không gộp); snapshot fee %/tỷ giá tại thời điểm giao dịch; Idempotency-Key cho mọi money command |
| State machine | Định nghĩa versioned (JSON), transition qua endpoint tường minh `POST /{object}/{id}/transitions`, guard role + state, audit every transition |
| Approval engine | Thư viện dùng chung: ngưỡng, dual approval, SoD 4 vai, delegate, cấm cùng người 2 chân (kiêm nhiệm) — fail-closed cho action tài chính |
| Multi-tenancy | Portal/mobile: tenant_id + RLS 2 lớp; nội bộ: dept data-scope (all/own-dept/own-objects) |
| Casing state values | DB CHECK giữ nguyên hiện trạng từng bảng; event payload + API response trả về **lowercase** (vd hard stop `matched`); docs viết lowercase — không trộn casing giữa các lớp |
| Input validation | Parameterized query bắt buộc (cấm ghép chuỗi SQL); schema validation mọi request + payload limit (≤1MB, depth ≤10 — đề xuất, cấm deserialization dữ liệu không tin cậy); file import kiểm MIME/size + antivirus scan trước parse (API-GW-028/042) |
| Cookie & CSRF | Portal DMZ dùng Bearer JWT — không dùng cookie cho state-changing request; cookie (nếu có, ví dụ SSO UI) phải HttpOnly + Secure + SameSite=Lax + double-submit token cho form nhạy cảm |
| CSP & XSS | Portal SPA + mobile webview: CSP `default-src 'self'`, cấm inline script không nonce; cấm `dangerouslySetInnerHTML` với dữ liệu động; nội dung user-generated sanitize server-side |

---

## 7. Môi Trường Triển Khai

| Môi trường | URL | Branch | Deploy |
|------------|-----|--------|--------|
| Development | `localhost:8080–8085` | bất kỳ | Thủ công (docker-compose) |
| Staging | `staging.bcerp.bcagency.vn` | `develop` | Tự động CI/CD |
| Production | `bcerp.bcagency.vn` (nội bộ) · `portal.bcagency.vn` (DMZ) | `main` | Thủ công, cần phê duyệt |

> Chi tiết container/network/backup: `technical-specs/infra-spec.md` (Phase 2), `phase6-deployment/deployment-guide.md`.

---

## 8. Cross-Cutting Concerns

### 8.1. Authentication & Authorization Flow

```
LOGIN FLOW (SSO tập trung — REQ-BOD-011):
  User → IdP (COMP-CORE-001): email+password (+TOTP MFA step-up cho vai tài chính)
    → Access Token (JWT, TTL 15 phút đề xuất) + Refresh Token (TTL 7 ngày)
    → Claims: user_id, roles[], dept, data_scope, tenant_id (portal)

REQUEST FLOW (PEP):
  Client → Service với Bearer token
    → PEP middleware: verify token + gọi PDP (COMP-CORE-002, cache TTL 60s)
    → Permission check: resource:action + state guard + data-scope filter
    → Thiếu quyền → 403 + audit access-denied

MFA STEP-UP (bắt buộc): lệnh tiền, dual approval, vault access, HĐĐT, khóa kỳ.
  Danh sách action step-up quản lý qua Policy (API-CORE-020) — không liệt kê cứng
  trong code; review định kỳ, bổ sung case import manual khối lượng lớn (nhập tay
  số tiền) theo chính sách + audit.
Vault management: CẤM từ mobile — request bị từ chối tầng gateway + log cảnh báo.

AUTHORIZATION MODEL: RBAC 4 chiều Role × Permission × Dept × Data-scope
  18 vai chuẩn (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1/L2, FIN_L1/L2,
  SALES_L1–L3, OPS_PLAN/AM/CONT, ESS, CLIENT_ADMIN/USER...).
  Compensating control CFO kiêm CTO (REQ-BOD-002): cờ combined_role →
  dual approval cứng khác người, mọi thao tác CTO ghi WORM + access review.
  Financial Hard Stop (FIN_L1 "đã khớp tiền") là policy rule — ADACC gọi
  kiểm tra trước khi TKQC active; sweep re-validate tại nguồn mỗi batch.
```

### 8.2. Error Handling Strategy

```
NGUYÊN TẮC:
  1. Error format chuẩn; không expose stack trace
  2. Correlation ID xuyên suốt REST + event
  3. 4xx client error vs 5xx server error phân biệt rõ
  4. External platform call fail → circuit breaker per-platform → degraded mode
     (nhãn manual tại thời điểm ghi) — nghiệp vụ KHÔNG dừng (DI-007 khởi điểm manual)

RETRY STRATEGY:
  - Platform API: retry 3 lần exponential backoff; circuit breaker per-platform
  - DB deadlock: retry 2 lần delay 100ms
  - Event publish: outbox + retry → DLQ; consumer idempotent (natural key)
  - Import manual: chặn lỗi theo dòng, dòng hợp lệ vẫn nhận
```

### 8.3. Logging & Observability

```
FORMAT: Structured JSON — timestamp (UTC), level, correlationId, service, action,
        userId, duration, error; audit nghiệp vụ tách luồng qua COMP-CORE-004
        (hash-chain append-only) → WORM (COMP-CORE-005) ≥10 năm cho log tiền + chứng từ.
LOG LEVELS: error (cần xử lý ngay — GW fail, hard stop bypass attempt),
        warn (degraded mode, rate limit gần đạt, mismatch đối soát),
        info (business events: deal.signed, wallet.matched, sla.breach),
        debug (dev/staging only).
ALERT: COMP-CORE-011 Alert Center — rule-based, lifecycle alert, dispatch ủy quyền
        MOD-SLA-NOTIF (đa kênh + on-call 4h ngoài giờ DI-005).
```

### 8.4. Caching Strategy

| Layer | Công cụ | Cache gì | TTL | Invalidation |
|-------|---------|----------|-----|-------------|
| PDP decision | Redis | Policy decision per (role,resource,action) | 60s | Role/policy change event |
| BI Serving | Redis | Mart aggregates dashboard | 1–15 phút theo mart | Rebuild mart |
| Portal read-model | Redis + BFF | View ví/campaign/ticket per tenant | 15 phút – 24h theo loại | TTL (polling; [NEEDS_REVIEW: event-driven nếu CORE hỗ trợ]) |
| Session | Redis | SSO session, refresh token registry | Theo token TTL | Logout/revoke/access review |
| Static assets | CDN | Portal SPA bundle | 30 ngày | Hash filename |

---

## 9. Ma Trận Vai Trò & Vòng Đời Nghiệp Vụ

> Nguồn: `business-context.md` Step 1.0 (bắt buộc nhất quán). Chi tiết đầy đủ 16 lifecycle ở file nguồn; dưới đây là matrix chính.

### 9.1. Ma Trận Vai Trò (Actor Matrix)

| Business Object | Role/Phòng ban | Hành động | Quyết định chính |
|-----------------|----------------|-----------|------------------|
| Lead | SALES_L1 (SALES) | create, update, submit | Ghi nhận — hard gate "không ghi nhận = không tồn tại" |
| Lead (Gate 1/2) | SALES_L2/L3 (SALES) | approve/reject gate | Go/No-Go; ký handoff |
| Deal/Quotation | SALES (AM) | create, quote | Định mức; vượt định mức → GM duyệt |
| Lệnh chi/giải ngân | FIN_L1 khởi tạo; FIN_L2 → CFO → CEO theo ngưỡng 5/50/200tr | approve (SoD 4 vai, delegate) | Duyệt chi; CFO độc quyền tài chính (REQ-BOD-010) |
| Ví — điều chỉnh/đổi tỷ giá/hoàn tiền | FIN_L1 + FIN_L2 | dual approval | Kiểm soát tiền giữ hộ |
| Hard Stop "đã khớp tiền" | FIN_L1 | confirm | Điều kiện bắt buộc TKQC active |
| TKQC (registry) | OPS_AM | register, lifecycle | Vòng đời TKQC; KYC pháp nhân trước cấp phát |
| Handoff | SALES submit → OPS_AM | sign 2 phía | Ký nhận bridge + sinh onboarding tasks |
| Campaign/Deliverable | OPS_AM (campaign), OPS_CONT (deliverable) | plan, execute, accept | Nghiệm thu 3 ngày (không "im lặng = đồng ý") |
| Ticket | OPS_CONT | resolve; escalate AM→AD→BOD | SLA tier×priority |
| Timesheet | Nhân viên nhập; OPS ∥ HR duyệt song song | submit, approve | Capacity + KPI feed |
| Nghỉ phép | Nhân viên; HR_L1→L2 duyệt phân cấp | request, approve | Số dư tự động |
| KPI/PIP | HR_L2 + quản lý | calibrate, finalize | PIP 30-60-90 |
| Connection/Credential (GW) | BOD_CFO_CTO (CTO) | approve, activate, revoke | Vault độc quyền CTO, MFA; SYS_ADMIN thực thi sau duyệt |
| Portal account | CLIENT_ADMIN tự quản (OPS_AM cấp admin đầu tiên) | invite, activate, revoke | Gate Day 14 từ dữ liệu thực |
| Policy/tham số/tier | BOD_CEO/CFO_CTO duyệt (REQ-BOD-009) | approve | Effective-dated config |

### 9.2. Vòng Đời Business Object (Lifecycle) — chính

| Business Object | State | Transitions hợp lệ | Bộ phận tạo/đổi state | Owner tại stage |
|-----------------|-------|--------------------|-----------------------|-----------------|
| Lead | new → dedup_check → assigned → scored → gate1_go/no_go → qualified → gate2_signed_handoff → handed_to_cs; rejected; recycled | theo ma trận | SALES (L1 ghi, L2/L3 gate); scoring tự động K1–K12 → Tier A–E | SALES_L1 → SALES_AM |
| Quotation/Deal | draft → margin_check → discount_approval → approved → contracting → signed/rejected | phân cấp duyệt + e-sign | SALES; GM (vượt định mức) | SALES AM |
| Handoff Package | draft → sales_submit → ops_ack → onboarding_tasks → completed | ký 2 phía | SALES → OPS_AM | OPS_AM sau ack |
| TKQC Ad Account | kyc_required → kyc_verified → registered → pre_spend_hardstop_check → active → suspended/dead/closed | hard stop gate bắt buộc; `dead` = die account (API-ERP-046 — DB CHECK có state `dead`) | OPS registry; FIN hard stop | OPS_AM |
| Ví & Lệnh tiền | entry → reconciling → matched/mismatch → period_locked; lệnh: draft → dual_approval → executed | đối trừ 3 số + dual approval | FIN | FIN_L1/L2 |
| AR/AP & Lệnh chi | invoice → aging → dunning → paid/overdue; chi: draft → approval(ngưỡng/SoD) → disbursed | ngưỡng 5/50/200 + delegate | FIN | FIN_L1 → CFO/CEO |
| HĐĐT | draft → issued (TT78/NĐ123) → delivered | phát hành e-invoice | FIN | FIN |
| Campaign/Deliverable | planned → in_flight → delivered → reported (+ A/B variant [NEEDS_REVIEW]) | stage-gate + nghiệm thu 3 ngày | OPS | OPS_AM/CONT |
| Timesheet | draft → submitted → reviewed → approved → capacity_computed | OPS ∥ HR | Nhân viên → OPS/HR | Nhân viên |
| Ticket | open → assigned → in_progress → resolved → closed | SLA timer | OPS_CONT | OPS_CONT |
| Commission | computed → clawback_check → approved → paid | theo thực nhận | tự động + FIN duyệt | FIN + SALES |
| Connection (GW) | configured → credentials_vaulted → active → degraded/disabled/revoked | CTO duyệt; tự mark degraded; disable/revoke do CTO (vault hóa qua API-GW-009) — khớp DB TBL-GW-001 + API-GW-005 | BOD_CFO_CTO | CTO/SYS_ADMIN |
| Portal Account | invited → active (2FA bắt buộc) → locked/disabled | CLIENT_ADMIN tự quản | CLIENT/OPS_AM | CLIENT_ADMIN |
| TikTok Shop | proposed → verifying (Gate 1) → gate2_signed → operating → degraded_manual/revoked | workflow 3 Gate | OPS_AM đề xuất, SALES_L4* duyệt (*vai mở rộng ngoài registry — chờ Phụ lục A #8) | OPS_AM |

*Ghi source: nhất quán với business-context.md (Step 1.0). States có [NEEDS_REVIEW] chi tiết ở §10 danh sách tổng hợp.*

---

## 10. Data Pipeline Architecture

> Chủ thiết kế: SYS-CORE-BACKEND — MOD-DATAHUB-BI (COMP-CORE-007 CDC/ETL Ingest · 008 Analytics Warehouse · 009 Realtime P&L Compute · 010 BI Serving API · 011 Alert Engine), phối hợp COMP-GW-003/004/005/009 ở SYS-INTEGRATION-GW. Kế thừa quyết định nền tảng §1: Kafka (đề xuất) cho CDC/event, ClickHouse (đề xuất) cho warehouse.

### 10.1. Nguyên tắc thiết kế

1. **ELT thay vì ETL chặt:** payload nguồn ghi vào lớp raw nguyên trạng (append-only) rồi mới transform trong warehouse — replay/audit được, sửa logic transform không phải pull lại nguồn.
2. **SSOT ở module gốc:** warehouse chỉ giữ bản sao phân tích (§4); pipeline không ghi ngược business object. Đây là điều kiện để reconcile ngược nguồn có nghĩa.
3. **Freshness là SLA trần, không phải tối đa:** P&L realtime mục tiêu ≤5 phút — đủ cho điều hành, rẻ hơn đáng kể so với sub-second.
4. **Pipeline lỗi không chặn nghiệp vụ:** mọi luồng nghiệp vụ chạy được 100% manual từ ngày 1 (DI-007); pipeline bắt kịp qua backfill khi nguồn khôi phục.
5. **Contract-first xuyên suốt:** schema của event và pull payload là hợp đồng versioned giữa module nguồn và DataHub.

### 10.2. Kiến trúc luồng dữ liệu: nguồn → ingest → raw → staged → marts

```
NGUỒN A — Business modules nội bộ (SSOT tại module gốc, canonical ở SYS-BCERP-WEB)
  DB CDC (WAL-based) + business event (outbox → Kafka đề xuất)
        │
        ▼
  Kafka topics theo module ─────────────┐
                                        ▼
NGUỒN B — SYS-INTEGRATION-GW      COMP-CORE-007 CDC/ETL INGEST
  pull batch theo schedule   ───►  consume idempotent (natural key + event_id)
  (COMP-GW-003) · chuẩn hóa +      gates G0–G5 (§10.4) · masking PII trước khi
  nhãn api/manual bất biến         ghi raw · watermark/LSN tracking · retry → DLQ
  (COMP-GW-004) · degraded
  manual import + backfill
  (COMP-GW-005)
                                        ▼
  COMP-CORE-008 ANALYTICS WAREHOUSE (ClickHouse đề xuất)
  raw (append-only nguyên trạng) → staged (typed, dedup, conform)
  → marts theo subject: pnl_realtime · wallet · ar_ap · sales_funnel
    · ops_delivery · people_cost · cs_sla · shop_reference
                                        ▼
  COMP-CORE-009 Realtime P&L Compute ──► COMP-CORE-010 BI Serving API
  (stream aggregation, snapshot kỳ;      (payload + freshness metadata —
   batch nightly reconcile)               điều kiện render, §10.6)
                                          ──► BCERP-WEB + MOBILE-INTERNAL
  COMP-CORE-011 Alert Engine (rule trên marts + event, lifecycle alert)
        └─► dispatch ủy quyền MOD-SLA-NOTIF (đa kênh + on-call DI-005)
```

Ba luồng ingest: **(A) stream** cho CDC + event các module nội bộ — không gọi API đồng bộ ngược module nghiệp vụ trong request path dashboard; **(B) pull batch** cho platform data 7 nền tảng + VAS + TikTok Shop qua GW (hourly + on-demand); **(C) manual import degraded** — khi nền tảng fail, GW chuyển manual mode, import hàng ngày, payload vẫn đi qua cùng ingest nhưng bắt buộc mang nhãn `manual` và tách dimension riêng ở marts (G4).

### 10.3. CDC strategy theo nhóm nguồn

| Nhóm nguồn | Kiểu ingest | Schedule đề xuất | SLA freshness đề xuất |
|---|---|---|---|
| WALLET, ARAP (FIN) | CDC/event stream | realtime | ≤5 phút (đầu vào P&L — REQ-BOD-003/FIN-016) |
| CRM, QDD, HONB, COMM | CDC/event | 1–5 phút | ≤15 phút |
| CAMP, CAPTS, HR-CORE, KPI, CSKH, PROPLN, ADACC | CDC | 5–15 phút | ≤1 giờ |
| Platform 7 nền tảng + VAS kế toán (qua GW) | pull batch | hourly | ≤4 giờ; degraded → manual import hàng ngày, gắn nhãn thủ công |
| TIKTOK Shop (qua GW) | pull | 15–60 phút | ≤2 giờ cho anomaly |
| PORTAL / SLANOT events | event | realtime | ≤15 phút |

WALLET/ARAP là nhóm duy nhất chạy realtime liên tục vì P&L và hard stop "đã khớp tiền" tiêu thụ trực tiếp; các nhóm còn lại dùng CDC checkpoint (LSN/offset) định kỳ để giảm tải, đủ SLA freshness của nhóm. Watermark per module cho phép replay từ vị trí cụ thể khi sửa transform hoặc rebuild mart. **[NEEDS_REVIEW: toàn bộ con số Schedule/SLA là đề xuất mặc định — registry không định nghĩa; cần FIN/OPS xác nhận, đặc biệt freshness P&L cho REQ-FIN-016 (Phụ lục A #10).]**

### 10.4. Data quality gates & validation rules

Gates chạy theo thứ tự tại COMP-CORE-007 (ingest) và COMP-CORE-008 (trước publish mart):

| Gate | Ràng buộc | Hành vi khi fail |
|---|---|---|
| G0 — Contract validation | Schema version hợp lệ + required fields + kiểu dữ kiện | Bản ghi vào DLQ + alert; không ghi raw |
| G1 — Idempotency & dedup | Natural key + event_id; consumer idempotent | Drop bản ghi trùng, đếm metric |
| G2 — PII masking trước ingest (REQ-HR-010) | Trường lương/PII Confidential/Restricted mask/tokenize theo classification registry (COMP-CORE-006) trước khi vào warehouse — PII không vào warehouse dạng clear | Chặn dòng + alert bảo mật |
| G3 — Nhãn nguồn bất biến | Dữ liệu platform phải mang nhãn `api`/`manual` do GW ghi tại thời điểm ghi (COMP-GW-004) — nhãn immutable, kể cả FIN không sửa tay; warehouse chỉ đọc nhãn, không ghi đè (backfill qua GW tạo bản ghi mới, không sửa nhãn cũ) | Từ chối payload thiếu nhãn → DLQ |
| G4 — Tách manual khỏi realtime | Dữ liệu manual (degraded/backfill) không trộn vào số realtime khi reconcile — marts tách dimension `source_label`, tổng hợp ghép lại theo kỳ khi reconcile | — |
| G5 — Business validation trước publish | Đối trừ 3 số khớp (portal vs bank vs ledger); tổng con = tổng cha; mốc thời gian UTC hợp lệ; TikTok GMV giữ `reference_only=true` — cấm map vào doanh thu agency | Flag reconciling/mismatch + alert; mart không publish |

Ngoài gates, ingest kế thừa retry strategy §8.2: import manual chặn theo dòng (dòng hợp lệ vẫn nhận); event consume retry → DLQ, theo dõi DLQ depth như một alert thường trực (khớp §11.4).

### 10.5. Data lineage & governance

- **Schema registry (contract-first):** event contract và pull payload schema versioned, đăng ký tập trung; compatibility gate (backward-compatible) chạy trong CI của module nguồn — schema drift của module nguồn không được phép phá ingest im lặng.
- **Lineage metadata:** mỗi dòng raw/staged/mart mang `(source_system, source_object, source_label, ingest_batch_id, event_id, watermark, loaded_at)` — trace ngược một ô dashboard về đến bản ghi nguồn để **reconcile ngược nguồn**: batch nightly đối chiếu marts vs module gốc và stream vs batch; lệch quá ngưỡng → alert + rebuild mart. [NEEDS_REVIEW: ngưỡng lệch chấp nhận được giữa stream và batch nightly.]
- **Retention:** warehouse raw 2 năm / marts 5 năm [NEEDS_REVIEW — không có căn cứ trong registry, Phụ lục A #12]; raw payload GW archival vào S3 Object Lock; log tiền + chứng từ KHÔNG đi pipeline analytics mà đi luồng audit hash-chain → WORM ≥10 năm (REQ-FIN-012).
- **Governance:** warehouse thuộc sở hữu CORE-BACKEND (§4); truy cập marts chỉ qua COMP-CORE-010 với PDP check theo role × dept × data-scope — không có đường query thẳng warehouse từ client; PORTAL không dùng BI serving (ví read-only đi share model riêng — REQ-FIN-017).

### 10.6. Phục vụ P&L realtime + Alert Center (ràng buộc ERP)

- **P&L realtime (REQ-BOD-003, REQ-FIN-016):** COMP-CORE-009 stream aggregation trên stream WALLET/ARAP, song song batch nightly trên marts, hai số reconcile với nhau; có rule timesheet-chưa-duyệt (chi phí nhân công chưa duyệt hiển thị tách dòng ước tính, không gộp vào số đã duyệt) [NEEDS_REVIEW: công thức rule]; snapshot kỳ phục vụ so sánh liên kỳ — `period_locked` của WALLET tại nguồn là cận dưới của snapshot (việc chốt kỳ thuộc FIN, không thuộc pipeline).
- **Freshness metadata là điều kiện render:** mỗi mart expose `(last_watermark, loaded_at, freshness_sla, is_stale)`; COMP-CORE-010 trả metadata kèm payload; BCERP-WEB/MOBILE-INTERNAL chỉ render số khi `is_stale=false` — khi stale, UI hiển thị nhãn "dữ liệu tính đến `<loaded_at>`" + trạng thái cảnh báo thay vì số cũ im lặng. Cache BI serving Redis (TTL 1–15 phút theo mart, §8.4) invalidate theo sự kiện rebuild mart.
- **Alert Center (REQ-BOD-006):** COMP-CORE-011 rule-based trên marts + event (`wallet.low_balance`, mismatch đối trừ 3 số, `sla.breach`, `shop.alert`, DLQ depth, freshness vi phạm SLA); alert có lifecycle (open → ack → closed) lưu alert registry; dispatch ủy quyền MOD-SLA-NOTIF (đa kênh + on-call 4h ngoài giờ DI-005).
- **Event nền tảng pipeline phụ thuộc (outbox, consumer idempotent, DLQ bắt buộc — §5):** `wallet.matched` (mở hard stop TKQC — sweep re-validate tại nguồn vẫn là chính, event chỉ tối ưu — nhất quán §11.4), `timesheet.approved` (giờ duyệt mới vào P&L/KPI), `backfill.completed` (đối soát lại kỳ từng nhập manual), `wallet.sync.completed` (cập nhật freshness nhóm platform).

### 10.7. [NEEDS_REVIEW] riêng section này

1. Toàn bộ Schedule/SLA ingest ở §10.3 — đề xuất mặc định, cần FIN/OPS chốt (Phụ lục A #10).
2. Retention raw/marts (2 năm/5 năm) + ngưỡng lệch reconcile stream↔batch (Phụ lục A #12).
3. Chốt stack Kafka/ClickHouse/connector CDC — phụ thuộc quyết định platform (Phụ lục A #11).
4. Công thức rule timesheet-chưa-duyệt trong P&L; mapping stage proposal V6.0 cho ingest khi lane OPS chốt tên stage.
5. SLA backfill sau khi nền tảng khôi phục từ degraded mode (thời gian tối đa cho phép dữ liệu bị trễ).

## 11. Workflow Automation Architecture (conditional — automation-architect)

> Nguồn: business-context.md §5 Exception Events + REQ-OPS-008 (SLA engine) + REQ-FIN-006 (hard stop "đã khớp tiền"). Nguyên tắc xuyên suốt: **automation tối ưu tốc độ và độ phủ, hard control vẫn còn người** — mọi automated workflow sai trên tiền giữ hộ phải có đường lùi về manual và re-validate tại nguồn.

### 11.1. Đánh Giá Giá Trị Automation vs Manual (ROI-driven)

Phân loại theo 3 mức: **A-full** (chạy tự động hoàn toàn, người chỉ xem exception), **B-human-in-loop** (automation chuẩn bị + người quyết định/duyệt), **C-manual bắt buộc** (người nhập/xác nhận, hệ thống chỉ hỗ trợ). Nguyên tắc phân loại: mọi bước là **hard control trên tiền** hoặc **phán quyết nghiệp vụ có tính phán đoán** → không tự động hóa quyết định.

| # | Workflow | Mức | Phạm vi automation | Căn cứ |
|---|----------|-----|--------------------|--------|
| 1 | Đối trừ 3 số (portal vs bank vs ledger) | **B** | Tự matching theo natural key (tx ref + amount + currency + window), tự gắn `matched/mismatch`; **mismatch bắt buộc người FIN điều tra + dual approval điều chỉnh**; chốt kỳ FIN_L2 là quyết định người | §5 — mismatch chặn đối soát, điều chỉnh cần dual approval |
| 2 | Cảnh báo số dư + SLA đỏ 2h | **A-full** | Event `wallet.low_balance` → COMP-ERP-006 timer đỏ 2h → escalation tự động theo ma trận (§4). Zero human touch đến khi có người tiếp nhận escalation | §5 — SLA đỏ 2h → escalation |
| 3 | Aging + dunning nhắc nợ | **A-full (nhắc) + B (sau)** | Nhắc nợ tự động theo aging bucket + escalation theo bucket; quyết định cơ chế xử lý đòi (giảm trừ, cắt commission, dừng serve) là người FIN/SALES | §5 — nhắc nợ tự động; escalation theo bucket |
| 4 | HĐLĐ expiry 90/60/30 | **A-full** | Cron daily → sinh cảnh báo cho HR_L1/L2 theo mốc 90/60/30; state `active → expiring` chuyển tự động. Gia hạn là hành động người HR | §2 lifecycle Hồ sơ & HĐLĐ |
| 5 | KPI auto-aggregate | **A-full (tính) + B (chốt)** | Event `timesheet.approved` + dữ liệu COMM/CRM → auto-aggregate 3 trụ cột; **calibration + finalize là người** (HR_L2 + ban điều hành); PIP trigger chỉ đề xuất, người phê | §2 — auto_aggregate → calibration → finalized |
| 6 | Clawback sweep | **B** | Event `refund.executed`/hủy → auto-tính số clawback theo deal/comm; **duyệt clawback là người FIN** trước khi trừ vào payroll/commission | §5 — clawback khi hoàn tiền/hủy |
| 7 | SLA timer + escalation | **A-full** | REQ-OPS-008: policy instance per (object, tier, priority); timer từ state transition; `sla.warning`/`sla.breach` → notification đa kênh + escalation tự động | §5 — SLA vỡ → notification + escalation tự động |
| 8 | Gate Day 14 portal adoption | **A-full (đo) + B (quyết)** | COMP-PORTAL-006 forward adoption events tự động; gate báo cáo từ dữ liệu thực; quyết định Go/No-Go là người sở hữu gate | §5 lifecycle Portal Account + lane PORTAL |
| 9 | Backfill GW sau degraded | **A-full (chạy) + B (xác nhận kỳ)** | COMP-GW-005 backfill tự chạy khi API phục hồi, ghi đè nhãn `manual` thành `api` theo window, phát `backfill.completed` → đối soát lại kỳ tự động; kết quả mismatch phát sinh lại đưa người xử lý | §5 — degraded mode + event `backfill.completed` |
| 10 | Chốt kỳ (period lock) | **C-manual bắt buộc** | Hệ thống aggregate checklist (đối trừ đã khớp, mismatch = 0 hoặc đã xử lý, HĐĐT issued...) + hard-stop chặn lock nếu còn violation; **bấm lock là FIN_L2** — không bao giờ tự động | §2 — chốt & khóa kỳ FIN_L2; tiền giữ hộ control chặt nhất |

**Nhập tay degraded mode (DI-007)** là trường hợp C đặc biệt: khi platform API fail, toàn bộ luồng sync chuyển nhập manual với nhãn `manual` — automation KHÔNG tự bấm thay người, chỉ bảo đảm form/import/validate đủ tốt để manual nhanh. Quy tắc: **mọi luồng phải chạy được 100% manual từ ngày 1** (quyết định nền tảng §1).

### 11.2. Business Process Automation Patterns

3 pattern duy nhất, khớp 3 nhóm trigger trong kiến trúc (§1, §5, §8.2):

| Pattern | Cơ chế | Áp dụng | Ràng buộc |
|---------|--------|---------|-----------|
| **Event-driven** | Outbox pattern tại publisher (ghi event cùng transaction DB) → Kafka → consumer idempotent (natural key) → DLQ | `wallet.matched` mở hard stop; `payment.received` tính commission; `handoff.ops_ack` sinh onboarding tasks; `deal.signed` mở AR schedule | Consumer KHÔNG là nguồn sự thật; event fail không làm mất nghiệp vụ (xem 11.4) |
| **Scheduled (batch)** | COMP-ERP-007 Batch & Recon Scheduler — cron job registry, distributed lock Redis (chỉ 1 instance chạy), mỗi job có owner module + idempotency key theo (job, window) | Đối trừ 3 số batch, aging sweep, HĐLĐ 90/60/30, KPI aggregate, clawback sweep, checklist chốt kỳ | Job re-run được (idempotent); lock hết hạn tự nhường; log run + result vào audit |
| **Timer/triggered (SLA)** | COMP-ERP-006 SLA worker: timer bắt đầu từ state transition (REQ-OPS-008), tính theo GMT+7, phát `sla.warning`/`sla.breach` + escalation path | SLA đỏ 2h số dư, ticket SLA tier×priority, deliverable overdue, nghiệm thu 3 ngày | Timer phải persist (sống qua restart); hủy/khoản adjust timer khi state đổi lại |

**Không dùng pattern mới** (BPM engine, rule engine riêng, RPA) ở giai đoạn này — 3 pattern trên đủ cho mọi workflow trong registry; thêm pattern mới = thay đổi kiến trúc, phải qua review.

### 11.3. Integration Governance

- **KHÔNG dùng n8n/Zapier/Make hoặc bất kỳ automation SaaS external.** Lý do: (1) dữ liệu tiền giữ hộ + PII không đi qua bên thứ ba chưa phê duyệt; (2) audit trail phải nằm trong COMP-CORE-004 hash-chain — công cụ external không ghi được; (3) automation engine internal = scheduler (COMP-ERP-007) + event bus (Kafka/outbox) + SLA worker (COMP-ERP-006), tất cả đã có ownership + observability.
- **Quy tắc thêm automated workflow mới** — phải thỏa ĐỒNG THỜI 4 điều kiện:
  1. **Contract**: có event/endpoint contract versioned trong spec layer (integration-map.md), payload có schema;
  2. **Idempotency**: natural key hoặc Idempotency-Key, consumer/job chạy lại an toàn;
  3. **Audit**: mọi action tự động ghi audit qua COMP-CORE-004 với `triggered_by=system:<job_or_event>`;
  4. **Escalation + manual fallback**: workflow phải định nghĩa ai nhận khi nó fail và đường manual tương đương (degraded mode).
  Thiếu bất kỳ điều nào → không merge; review bởi owner module + automation-architect.

### 11.4. Error Handling & Retry Strategy cho Automated Workflows

| Lớp lỗi | Xử lý |
|---------|-------|
| Lỗi tạm thời (network, DB deadlock, platform 5xx) | Retry exponential backoff theo §8.2 (3 lần platform, 2 lần DB); job/event idempotent nên retry an toàn |
| Lỗi đầu cuối (poison message, schema sai, business rule fail) | Sau khi hết retry → **DLQ** (Kafka DLQ per topic + dead-job registry cho scheduler); DLQ không auto-replay — replay là hành động người (owner module) qua màn hình ops |
| **Dead-letter alarm** | Mọi DLQ push + dead-job phải sinh alert ngay lập tức qua COMP-CORE-011 → COMP-ERP-006 dispatch; ngoài giờ → on-call 4h (DI-005). DLQ im lặng quá [NEEDS_REVIEW: ngưỡng cảnh báo backlog DLQ — không có căn cứ chính sách] phải escalate |
| **Sự thật tại nguồn (quan trọng nhất)** | Với hard control: **sweep re-validate hard stop tại nguồn mỗi batch (COMP-ERP-007) — event `wallet.matched` chỉ là tối ưu tốc độ**. Nếu event lost/DLQ, batch sweep vẫn phát hiện TKQC active mà chưa "đã khớp tiền" và tự revert/khóa. Áp dụng nguyên tắc tương tự cho commission/clawback: sweep định kỳ đối chiếu computed vs approved |
| Job overlap / mất lock | Distributed lock Redis + idempotency key (job, window); job cũ chưa xong → job mới skip + log; 3 lần skip liên tiếp → warn |

### 11.5. Rủi Ro Automation & Biện Pháp

| Rủi ro | Biện pháp |
|--------|-----------|
| Automation sai trên **tiền giữ hộ** (matching sai, lock kỳ sai, hard stop mở nhầm) | Hard control còn người: dual approval (điều chỉnh ví/đổi tỷ giá/hoàn tiền), FIN_L1 confirm hard stop, FIN_L2 chốt kỳ — **không tự động hóa các phán quyết này**; sweep re-validate tại nguồn là lưới an toàn độc lập với event; mọi tự động ghi WORM cho tiền |
| SoD bị bẻ bằng automation (job chạy với quyền gộp) | Job/service account chạy theo quyền tối thiểu per-module, không có quyền approval; automation KHÔNG tự duyệt thay người — chỉ chuẩn bị dữ liệu + phát alert; 4 vai SoD duyệt chi giữ nguyên |
| On-call không phản ứng kịp với SLA đỏ/DLQ | On-call 4h ngoài giờ (DI-005) + escalation tự động theo ma trận §4; alert lifecycle (COMP-CORE-011) không auto-close — phải người ack |
| Event storm / replay sai kỳ | Consumer idempotent + idempotency key theo window; replay backfill chỉ per-window, có audit |
| Quá tự động hóa sớm | Chỉ chuyển B→A-full khi có số liệu vận hành chứng minh tỷ lệ sai của automation < ngưỡng do BOD phê [NEEDS_REVIEW: ngưỡng chất lượng chuyển mức automation chưa có chính sách]; mặc định giữ mức đã phân loại ở 11.1 |

**Ghi chú [NEEDS_REVIEW] của section này:** (1) ngưỡng cảnh báo backlog DLQ; (2) ngưỡng chất lượng để nâng mức automation; (3) liệu cron窗口 đối trừ/khung giờ khuya có chính sách vận hành riêng — chưa thấy căn cứ trong registry.

---

## Phụ lục A — Danh sách [NEEDS_REVIEW] tổng hợp Phase 1 (23 mục)

| # | Hạng mục | Nguồn lane |
|---|----------|-----------|
| 1 | Tên + done-criteria 30 stage proposal V6.0 | ERP |
| 2 | Nguồn feed sao kê ngân hàng cho đối trừ 3 số | ERP |
| 3 | Kênh notification ngoài in-app (email/SMS/OTT) | ERP |
| 4 | E-sign provider + đường dẫn (qua GW hay trực tiếp) | ERP + GW |
| 5 | State chi tiết variant A/B Campaign | ERP |
| 6 | Contract API publish read-model sang PORTAL | ERP + PORTAL |
| 7 | Công thức "quota coverage ≥3×" | ERP |
| 8 | Danh mục đủ 18 vai chuẩn hóa — các vai mở rộng xuất hiện rải rác trong specs (GM, SALES_L4/L5, OPS_DES/EDIT/ADS) cần BOD chốt giữ hoặc thay bằng vai registry | CORE |
| 9 | Phương pháp MFA (TOTP/hardware key/passkey) | CORE + MPO |
| 10 | Schedule/SLA ingest DataHub (đề xuất mặc định) | CORE |
| 11 | Chốt stack hạ tầng (Kafka/ClickHouse/Keycloak/S3) | CORE |
| 12 | Retention audit vận hành + lớp warehouse | CORE |
| 13 | Delegate khi CFO kiêm CTO vắng | CORE |
| 14 | Fail-open/closed cho luồng đọc policy | CORE |
| 15 | Webhook receiver GW (pull-based hiện tại) | GW |
| 16 | Cơ chế kết nối VAS chính xác (API/import) [KXN-9] | GW |
| 17 | Phạm vi GMV hiển thị Portal [CẦN CHỐT SỐ] | GW |
| 18 | Mốc cấp quyền API từng nền tảng (DI-007) | GW |
| 19 | Bộ trường campaign/invoice hiển thị khách + duyệt view invoice | PORTAL |
| 20 | Ma trận tier → quota/SLA cụ thể | PORTAL |
| 21 | Touchpoint HR-CORE mobile (ESS) thiếu trong registry | MBI |
| 22 | Platform mobile (RN/Flutter/native) + quy tắc offline chấm công + mức MFA step-up mobile | MBI |
| 23 | Ownership Portal API Gateway dùng chung [KXN-15/20/22 hiển thị] | MPO + PORTAL |
