# API Contract — BCERP

> **Dựa trên:** P3-01-architecture.md + feature specs Phase 2 + Business Context Baseline v4.1 | **Session:** 20260913-053848-f4d7 | **Ngày:** 13/09/2026
> **Cấu trúc:** Mỗi system 1 section (fragment do lane agent sinh, ID convention riêng: API-ERP/API-CORE/API-GW/API-PORTAL/API-MBI/API-MPO). Aggregation + dedup api_id ở Phase 3.
> Quy ước chung (error format, pagination 20/100, versioning /api/v1/, Idempotency-Key money commands, state-transition endpoints) xem P3-01 §6 — không lặp lại ở đây.


## Hệ thống: SYS-BCERP-WEB — BCERP Web nội bộ

## API Contract — SYS-BCERP-WEB (BCERP Web nội bộ) [fragment]

> READS: `phase2-features/bcerp-web/**` (business rules), `P3-01-architecture.md` (§1 quyết định, §4 ownership, §5 events, §6 quy ước), `lanes/bcerp-web/arch-draft.md`, `business-context.md` v4.1
> OUTPUT: Endpoint registry + contract chi tiết cho 14 module business của SYS-BCERP-WEB
> USED BY: `technical-specs/api-contract.md` (aggregation), `integration-map.md`, `phase4-ux/**`, `phase5-implementation/**`
> DATE: 2026-09-13 | VERSION: v1
> API ID convention: `API-ERP-NNN` — đánh ID mọi endpoint chính; Phase 3 aggregation dedup chéo lane.

---

### 1. Global Conventions

Quy ước nền tảng (base URL `/api/v1/`, Bearer JWT, ISO 8601 UTC, UUID v4, soft delete, pagination `page/limit` mặc định 20 tối đa 100, filter/sort server-side bắt buộc) **tham chiếu P3-01 §6 — không lặp lại**. Điểm riêng của system này:

```
Route prefix:   /api/v1/erp/...
AuthN/AuthZ:    Delegate toàn bộ cho SYS-CORE-BACKEND (SSO/MFA OIDC + PDP check);
                token claims: user_id, roles[], dept, data_scope, tenant_id.
                MFA step-up bắt buộc cho: lệnh tiền, dual approval, HĐĐT, khóa kỳ (P3-01 §8.1).
State machine:  Mọi object có vòng đời có endpoint tường minh POST /{object}/{id}/transitions
                — body { "to_state": "...", "reason?": "..." }, guard role + state hợp lệ,
                audit mỗi transition. Định nghĩa state machine versioned (JSON) dùng chung.
Money command:  Header "Idempotency-Key: <uuid>" BẮT BUỘC cho mọi endpoint ghi tiền
                (transactions, payments, disburse, issue, approvals tiền).
Idempotency-Key bị trùng → trả kết quả lần chạy đầu (200), không thực thi lại.
```

### 2. Standard Response Envelopes

Theo template chung (success/data/meta; error/error/code/details — xem `api-contract.md` §2 nền tảng). Mở rộng riêng: response của state-transition trả kèm trạng thái mới + guards đã qua:

```json
{ "success": true, "data": { "id": "uuid", "status": "active",
  "transition": { "from": "pre_spend_hardstop_check", "to": "active", "at": "2026-09-13T04:00:00Z",
                  "by": "uuid", "guards_passed": ["hard_stop_matched", "kyc_verified"] } } }
```

### 3. HTTP Status Codes & 4. Error Codes Registry

Dùng bảng chuẩn template (200/201/400/401/403/404/409/429/500/503). Bổ sung error codes nghiệp vụ ERP:

| Code | HTTP | Mô tả | REQ liên quan |
|------|------|-------|---------------|
| `LEAD_DUPLICATE` | 409 | Anti-duplicate chặn lead trùng (merge/từ chối) | REQ-SALES-001 |
| `HARD_STOP_ACTIVE` | 409 | Chưa "đã khớp tiền" (FIN_L1) — chặn active TKQC | REQ-FIN-006, REQ-OPS-002 |
| `PERIOD_LOCKED` | 409 | Kỳ đã khóa — cấm ghi sổ/sửa dữ liệu kỳ | REQ-FIN-004 |
| `DISCOUNT_OVER_LIMIT` | 409 | Chiết khấu vượt định mức tier — buộc duyệt GM | REQ-SALES-006 |
| `APPROVAL_REQUIRED` | 409 | Action cần approval engine (ngưỡng/dual/SoD) trước khi thực thi | REQ-FIN-008 |
| `SOD_VIOLATION` | 409 | Vi phạm tách nhiệm vụ: tự duyệt, cùng người 2 chân, combined-role thiếu 2 nấc khác người — fail-closed | REQ-BOD-002 |
| `AML_FLAGGED` | 409 | Giao dịch gắn cờ AML T1–T6 — chờ điều tra | REQ-FIN-010 |
| `PII_ACCESS_DENIED` | 403 | Trường lương Confidential/Restricted — thiếu classification | REQ-HR-010 |
| `DEGRADED_MODE` | 200 | (warn) Dữ liệu nền tảng là bản nhập `manual` — kèm `source_label` | REQ-FIN-005 |

### 5. Authentication Endpoints

**KHÔNG thuộc scope này.** Login/refresh/logout/MFA step-up thuộc SYS-CORE-BACKEND (`/api/v1/core/auth/*`, COMP-CORE-001). BFF của SYS-BCERP-WEB chỉ proxy và xử lý redirect. REQ-BOD-011.

### 6. Endpoints By System — SYS-BCERP-WEB

> 14 module, 7 components. Mỗi endpoint: role tối thiểu được phép (PDP enforce), request/response chính, REQ-ID. FEAT-ID liệt kê theo nhóm. List endpoints đều có `page/limit/sort/order` + filter nêu ở cột Mô tả (không lặp lại).

#### 6.1. COMP-ERP-001 — Sales & Pipeline (MOD-CRM-PIPELINE, MOD-QUOTATION-DEALDESK, MOD-HANDOFF-ONBOARD)

**FEAT: FEAT-ERP-CRM-001…005, FEAT-ERP-QDD-001/002, FEAT-ERP-HONB-001/002.**

##### MOD-CRM-PIPELINE — Leads (FEAT-ERP-CRM-001…005)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-001 | POST | `/api/v1/erp/leads` | SALES_L1 (data_scope theo dept) | Tạo lead đa kênh; hard gate "không ghi nhận = không tồn tại"; trigger dedup_check | REQ-SALES-001/002 |
| API-ERP-002 | POST | `/api/v1/erp/leads/bulk-import` | SALES_L1 | Import hàng loạt; chặn lỗi theo dòng, dòng hợp lệ vẫn nhận; mỗi dòng chạy anti-duplicate | REQ-SALES-001 |
| API-ERP-003 | GET | `/api/v1/erp/leads` | SALES/OPS (scope) | List server-side: filter `status,tier,owner_id,channel,search`; sort `createdAt/score` | REQ-SALES-002 |
| API-ERP-004 | GET | `/api/v1/erp/leads/{id}` | SALES/OPS (scope) | Detail: K1–K12 score, tier, gate history, owner | REQ-SALES-003 |
| API-ERP-005 | GET | `/api/v1/erp/leads/{id}/activity` | SALES/OPS (scope) | Timeline: tạo/sửa/transition/assign/gate/scoring | REQ-SALES-002 |
| API-ERP-006 | POST | `/api/v1/erp/leads/{id}/transitions` | theo state (SALES_L1 ghi; SALES_L2/L3 gate) | State machine: new→dedup_check→assigned→scored→gate1_go/no_go→qualified→gate2_signed_handoff→handed_to_cs; rejected; recycled. Trùng → `LEAD_DUPLICATE` (từ dedup) | REQ-SALES-002/004 |
| API-ERP-007 | POST | `/api/v1/erp/leads/{id}/assign` | SALES_L2+ | Assign/reassign theo rule; ghi assignment_history | REQ-SALES-002 |
| API-ERP-008 | POST | `/api/v1/erp/leads/{id}/gate-decision` | SALES_L2 (Gate 1), SALES_L3 (Gate 2) | Go/No-Go: `{ "gate": 1|2, "decision": "go|no_go", "note" }`; Gate 2 gắn chữ ký handoff | REQ-SALES-004 |
| API-ERP-009 | GET | `/api/v1/erp/customers/{id}/tier-review` + POST cùng path | GET: SALES; POST: SALES_L2+ | Xem/sửa tier rà soát quý; chuyển tier Sales→CS | REQ-SALES-005 |

Request/response chính (API-ERP-001):
```
Request:  { "channel": "referral|web|fb|tiktok|event", "company_name": string, "contact_name": string,
            "phone": string, "email": string, "source_note"?: string }
Response 201: { "success": true, "data": { "id": "uuid", "status": "dedup_check",
            "duplicate_of"?: "uuid" } }   // duplicate_of ≠ null → API-ERP-006 bị chặn LEAD_DUPLICATE
Error 409: { "code": "LEAD_DUPLICATE", "details": [{ "field": "duplicate_of", "message": "..." }] }
```

##### MOD-QUOTATION-DEALDESK — Quotation/Contract (FEAT-ERP-QDD-001/002)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-010 | POST | `/api/v1/erp/quotations` | SALES (AM sở hữu) | Tạo quotation gắn lead + tier; margin_check định mức theo tier | REQ-SALES-006 |
| API-ERP-011 | GET | `/api/v1/erp/quotations`, `/quotations/{id}` | SALES/FIN/BOD (scope) | List filter `status,tier,owner_id,period`; detail margin + approval chain | REQ-SALES-006 |
| API-ERP-012 | POST | `/api/v1/erp/quotations/{id}/transitions` | SALES + approver | draft→margin_check→discount_approval→approved→contracting→signed/rejected | REQ-SALES-006 |
| API-ERP-013 | POST | `/api/v1/erp/quotations/{id}/discount-approval` | SALES_L2/L3 (trong định mức), GM (vượt định mức) | Duyệt chiết khấu phân cấp; vượt định mức → `DISCOUNT_OVER_LIMIT` cho tới khi GM duyệt | REQ-SALES-006 |
| API-ERP-014 | POST | `/api/v1/erp/contracts/{id}/esign-complete` | SALES + khách (e-sign) | Hoàn tất HD/LOI/NDA + brand safety checklist; phát event `deal.signed` | REQ-SALES-007 |

> [NEEDS_REVIEW] e-sign provider + đường dẫn (trực tiếp hay qua GW) — P3-01 Phụ lục A #4. Body API-ERP-014 giữ dạng provider-agnostic: `{ "provider_ref": string, "signed_document_uri": string }`.

##### MOD-HANDOFF-ONBOARD — Handoff Package (FEAT-ERP-HONB-001/002)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-015 | POST | `/api/v1/erp/handoffs` | SALES (auto từ `deal.signed` + manual) | Tạo draft với 5 nhóm bắt buộc | REQ-SALES-008 |
| API-ERP-016 | GET | `/api/v1/erp/handoffs`, `/handoffs/{id}` | SALES/OPS (scope) | List filter `status,customer_id,owner_id`; detail + onboarding tasks | REQ-OPS-004 |
| API-ERP-017 | POST | `/api/v1/erp/handoffs/{id}/sales-submit` | SALES | draft→sales_submit; chặn thiếu 5 nhóm bắt buộc | REQ-SALES-008 |
| API-ERP-018 | POST | `/api/v1/erp/handoffs/{id}/ops-ack` | OPS_AM | ops_ack ký nhận 2 phía → sinh onboarding tasks; phát event `handoff.ops_ack` | REQ-OPS-004 |
| API-ERP-019 | GET/PATCH | `/api/v1/erp/handoffs/{id}/onboarding-tasks[/{taskId}]` | OPS_AM/OPS_CONT | Checklist Day 1/7/14/30 cho ADACC/PORTAL/CAMP; PATCH trạng thái task | REQ-OPS-004 |

#### 6.2. COMP-ERP-002 — Finance & Treasury (MOD-WALLET-RECON, MOD-ARAP-PAYMENT, MOD-COMMISSION-QUOTA)

**FEAT: FEAT-ERP-WALLET-001…007, FEAT-ERP-ARAP-001…007, FEAT-ERP-COMM-001.** Mọi endpoint tiền yêu cầu MFA step-up + `Idempotency-Key`.

##### MOD-WALLET-RECON — Ví & đối soát (FEAT-ERP-WALLET-001…007)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-020 | GET | `/api/v1/erp/wallets` | FIN_L1/L2, OPS_AM (đọc góc ops), BOD | Số dư per khách per currency (USD/VND không gộp); filter `balance_status=low` (dự chi <3 ngày — REQ-FIN-002) | REQ-FIN-001/002 |
| API-ERP-021 | GET | `/api/v1/erp/wallets/{id}/ledger` | FIN_L1/L2 | Sổ phụ double-entry: filter `period,entry_type,source(api|manual)` | REQ-FIN-001 |
| API-ERP-022 | POST | `/api/v1/erp/wallets/{id}/transactions` | FIN_L1 (khởi tạo) | Lệnh giao dịch tiền giữ hộ: nạp/chi/điều chỉnh/đổi tỷ giá/hoàn tiền; snapshot fee % tại thời điểm; ghi journal | REQ-FIN-001/003 |
| API-ERP-023 | POST | `/api/v1/erp/wallet-transactions/{id}/approvals` | FIN_L1 + FIN_L2 (khác người) | Dual approval điều chỉnh/đổi tỷ giá/hoàn tiền; cùng người → `SOD_VIOLATION`; gắn cờ AML → `AML_FLAGGED` | REQ-FIN-003, REQ-FIN-010, REQ-BOD-002 |
| API-ERP-024 | GET | `/api/v1/erp/reconciliation-runs` | FIN_L1/L2 | List kỳ đối trừ 3 số; detail gồm items matched/mismatch (portal vs bank vs ledger) | REQ-FIN-004 |
| API-ERP-025 | POST | `/api/v1/erp/reconciliation-runs/{period}/close` | FIN_L2 | Chốt & khóa kỳ; chặn khi còn mismatch chưa xử lý → `PERIOD_LOCKED` khi kỳ đóng | REQ-FIN-004 |
| API-ERP-026 | POST | `/api/v1/erp/wallets/{customerId}/hard-stop/confirm` | FIN_L1 | Xác nhận "đã khớp tiền" per khách; mở điều kiện hard stop; phát event `wallet.matched` | REQ-FIN-006 |
| API-ERP-027 | GET | `/api/v1/erp/wallets/{customerId}/hard-stop-status` | OPS_AM, FIN, hệ thống (sweep) | Trạng thái hard stop — điểm guard cho API-ERP-045; source of truth re-validate tại nguồn | REQ-FIN-006, REQ-OPS-002 |
| API-ERP-028 | GET/POST | `/api/v1/erp/aml-flags[/{id}/resolve]` | FIN_L1 xem; FIN_L1+L2 resolve | AML T1–T6; resolve hoàn tiền đúng nguồn cần dual approval | REQ-FIN-010 |

Request/response chính (API-ERP-022):
```
Headers: Idempotency-Key: uuid; Authorization: Bearer (MFA step-up claim `mfa_level>=stepup`)
Request:  { "type": "topup|spend|adjustment|revaluation|refund", "direction": "debit|credit",
            "currency": "USD|VND", "amount": "1500.00", "fee_percent_snapshot": "3.5",
            "related_payment_order_id"?: "uuid", "note": string }
Response 201: { "data": { "id": "uuid", "status": "draft", "approval_required": true } }
// draft → dual_approval (API-ERP-023) → executed; mismatch kỳ → chặn close (API-ERP-025)
Error 409: PERIOD_LOCKED | AML_FLAGGED | APPROVAL_REQUIRED
```

##### MOD-ARAP-PAYMENT — Công nợ & giải ngân (FEAT-ERP-ARAP-001…007)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-029 | POST | `/api/v1/erp/ar-invoices` | FIN_L1 | Tạo AR invoice (tự động từ `deal.signed` schedule + manual) | REQ-FIN-007 |
| API-ERP-030 | GET | `/api/v1/erp/ar-invoices` | FIN/BOD (scope) | List filter `aging_bucket,paid_status,customer_id,period` | REQ-FIN-007 |
| API-ERP-031 | POST | `/api/v1/erp/ar-invoices/{id}/payments` | FIN_L1 | Ghi nhận thanh toán (money command); phát `payment.received` → commission | REQ-FIN-007 |
| API-ERP-032 | POST | `/api/v1/erp/ar-invoices/{id}/dunning` | FIN_L1 | Gửi nhắc nợ theo aging bucket (cron tự động + manual trigger); log dunning | REQ-FIN-007 |
| API-ERP-033 | POST | `/api/v1/erp/payment-orders` | FIN_L1 | Tạo lệnh chi/giải ngân; kiểm tra số dư ví khả dụng + báo giá đính kèm | REQ-FIN-008 |
| API-ERP-034 | POST | `/api/v1/erp/payment-orders/{id}/approve` | FIN_L2 (<50tr) → CFO (<200tr) → CEO (≥200tr); delegate khi vắng | Duyệt theo ngưỡng 5/50/200 triệu; SoD 4 vai; CFO độc quyền (REQ-BOD-010); cùng người 2 chân → `SOD_VIOLATION` | REQ-FIN-008, REQ-BOD-001/010 |
| API-ERP-035 | POST | `/api/v1/erp/payment-orders/{id}/disburse` | FIN_L1 (thực thi, khác người duyệt) | Giải ngân; ghi journal trừ ví; hoàn tất SoD 4 vai | REQ-FIN-008 |
| API-ERP-036 | POST | `/api/v1/erp/einvoices/{id}/issue` | FIN_L1 (MFA) | Phát hành HĐĐT TT78/2021 + NĐ123/2020; draft→issued→delivered | REQ-FIN-011 |
| API-ERP-037 | GET | `/api/v1/erp/einvoices` | FIN | List filter `status,period,customer_id`; chứng từ evidence push WORM (CORE) | REQ-FIN-011, REQ-FIN-012 |
| API-ERP-038 | GET | `/api/v1/erp/platform-fees` | FIN | Phí nền tảng & nghĩa vụ thuế per kỳ (tổng hợp từ GW statements + ví) | REQ-FIN-014 |

> VAS kế toán (REQ-FIN-013, FEAT-ERP-ARAP-006): xuất dữ liệu qua SYS-INTEGRATION-GW connector (DI-004) — endpoint nằm ở GW (`/api/v1/gw/*`), ERP chỉ push gói export qua job scheduler (INFRA-ERP-004). Không định nghĩa lại ở đây.

##### MOD-COMMISSION-QUOTA (FEAT-ERP-COMM-001)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-039 | GET | `/api/v1/erp/commissions` | SALES (của mình), FIN, HR (scope) | List filter `period,sales_id,status`; computed theo thực nhận | REQ-SALES-009 |
| API-ERP-040 | POST | `/api/v1/erp/commissions/{id}/approve` | FIN_L1 | Duyệt trả hoa hồng sau clawback_check | REQ-SALES-009 |
| API-ERP-041 | GET/POST | `/api/v1/erp/clawbacks[/{id}/approve]` | GET: FIN/SALES; POST: FIN_L1 | Clawback khi hoàn tiền/hủy (>90 ngày); sweep tự tính, người duyệt | REQ-SALES-009 |
| API-ERP-042 | GET | `/api/v1/erp/quotas` | SALES/HR/BOD | Quota coverage ≥3× per sales [NEEDS_REVIEW: công thức tử/mẫu số — P3-01 Phụ lục A #7] | REQ-SALES-009 |

#### 6.3. COMP-ERP-003 — Ad Account & Delivery (MOD-ADACCOUNT-CC, MOD-PROPOSAL-PLANNING, MOD-CAMPAIGN-DELIVERABLE)

**FEAT: FEAT-ERP-ADACC-001…003, FEAT-ERP-PROPLN-001, FEAT-ERP-CAMP-001/002, FEAT-ERP-TIKTOK-001, FEAT-ERP-CPORT-001.**

##### MOD-ADACCOUNT-CC — TKQC Registry (FEAT-ERP-ADACC-001…003)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-043 | POST | `/api/v1/erp/ad-accounts` | OPS_AM | Đăng ký TKQC; bắt buộc KYC pháp nhân trước (`kyc_required`); naming/UTM chuẩn | REQ-FIN-009, REQ-OPS-001 |
| API-ERP-044 | GET | `/api/v1/erp/ad-accounts` | OPS/FIN/SALES (scope) | List 2.600+: filter `platform,status,customer_id,tier,search`; detail gắn trạng thái sync/manual từ GW | REQ-OPS-001, REQ-FIN-005 |
| API-ERP-045 | POST | `/api/v1/erp/ad-accounts/{id}/transitions` | OPS_AM; guard hard stop FIN | kyc_required→kyc_verified→registered→pre_spend_hardstop_check→active→suspended/closed; chưa khớp tiền → `HARD_STOP_ACTIVE` (check API-ERP-027 tại nguồn) | REQ-OPS-001/002, REQ-FIN-006 |
| API-ERP-046 | POST | `/api/v1/erp/ad-accounts/{id}/revoke` | OPS_AM | Thu hồi 24h / đánh dấu die account; phát alert (SLANOT) | REQ-OPS-001 |

##### MOD-PROPOSAL-PLANNING (FEAT-ERP-PROPLN-001)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-047 | POST/GET | `/api/v1/erp/proposals[/{id}]` | OPS_PLAN soạn; OPS duyệt theo gate | CRUD proposal; list filter `stage,owner_id,customer_id` | REQ-OPS-005 |
| API-ERP-048 | POST | `/api/v1/erp/proposals/{id}/stage-transitions` | OPS_PLAN + approver gate | Stage-gate V6.0: 30 stage, done-criteria machine-checkable — hệ thống tự validate criteria trước khi cho chuyển | REQ-OPS-005 |

> [NEEDS_REVIEW] Tên + done-criteria 30 stage — đọc spec `proposal-va-planning-workspace-stage-gate-v6-0.md` (P3-01 Phụ lục A #1). Contract giữ generic: `{ "to_stage": string, "criteria_evidence": object }`.

##### MOD-CAMPAIGN-DELIVERABLE (FEAT-ERP-CAMP-001/002)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-049 | POST/GET | `/api/v1/erp/campaigns[/{id}]` | OPS_AM lập | CRUD campaign gắn handoff + TKQC; filter `status,customer_id,owner_id` | REQ-OPS-006 |
| API-ERP-050 | POST | `/api/v1/erp/campaigns/{id}/deliverables` | OPS_AM | Tạo deliverable theo WBS + assign OPS_CONT (bulk cho WBS lớn) | REQ-OPS-006 |
| API-ERP-051 | POST | `/api/v1/erp/deliverables/{id}/transitions` | OPS_CONT | planned→in_flight→delivered→reported; variant A/B [NEEDS_REVIEW: state chi tiết] | REQ-OPS-006/012 |
| API-ERP-052 | POST | `/api/v1/erp/deliverables/{id}/acceptance` | OPS_AM (khách nghiệm thu qua portal) | Nghiệm thu 3 ngày làm việc: nhắc ngày 2, escalate AD ngày 4; KHÔNG "im lặng = đồng ý" | REQ-OPS-006 |
| API-ERP-053 | POST | `/api/v1/erp/campaigns/{id}/ab-tests` | OPS_CONT | Tạo variant A/B theo mục tiêu khách | REQ-OPS-012 |

##### Touchpoint consumption: TikTok Shop + Portal account (FEAT-ERP-TIKTOK-001, FEAT-ERP-CPORT-001)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-054 | GET | `/api/v1/erp/tiktok-shop/monitor` | OPS | View GMV shop vs NSQC ads (feed GW, `reference_only=true`); hiển thị nhãn api/manual khi degraded | REQ-OPS-011, REQ-FIN-005 |
| API-ERP-055 | POST/DELETE | `/api/v1/erp/portal-accounts` | OPS_AM | Cấp/thu hồi tài khoản client portal (Day 14) — phát lệnh sang SYS-PORTAL-WEB | REQ-OPS-010 |
| API-ERP-056 | GET | `/api/v1/erp/portal-accounts/{customerId}/usage` | OPS_AM | Monitor adoption phục vụ Gate Day 14 | REQ-OPS-010 |

#### 6.4. COMP-ERP-004 — Client Care (MOD-TICKET-CSKH) — FEAT-ERP-CSKH-001

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-057 | POST | `/api/v1/erp/tickets` | Nội bộ (role tương ứng) + SYS-PORTAL-WEB (service token — điểm ghi duy nhất) | Tạo ticket; gắn tier khách + priority; start SLA timer | REQ-OPS-009 |
| API-ERP-058 | GET | `/api/v1/erp/tickets` | OPS (queue theo scope) | Queue filter `status,tier,priority,assignee_id,sla_state` | REQ-OPS-009 |
| API-ERP-059 | POST | `/api/v1/erp/tickets/{id}/assign` | OPS_AM | Assign/reassign; ghi assignment_history | REQ-OPS-009 |
| API-ERP-060 | POST | `/api/v1/erp/tickets/{id}/transitions` | OPS_CONT | open→assigned→in_progress→resolved→closed; reset/adjust SLA timer theo transition | REQ-OPS-009 |
| API-ERP-061 | GET | `/api/v1/erp/tickets/{id}/activity` | OPS | Timeline + context campaign/TKQC + escalation AM→AD→BOD | REQ-OPS-009 |

#### 6.5. COMP-ERP-005 — People & Performance (MOD-HR-CORE, MOD-CAPACITY-TIMESHEET, MOD-KPI-PERFORMANCE)

**FEAT: FEAT-ERP-HRCORE-001…006, FEAT-ERP-CAPTS-001/002, FEAT-ERP-KPI-001/002.**

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-062 | POST/GET/PUT | `/api/v1/erp/employees[/{id}]` | HR_L1 (ghi), HR_L2 + quản lý (đọc mở rộng) | Hồ sơ L1–L5 + mã vai SSOT; trường lương masking theo classification — thiếu quyền → `PII_ACCESS_DENIED` | REQ-HR-001, REQ-HR-010 |
| API-ERP-063 | GET/POST | `/api/v1/erp/employees/{id}/contracts` | HR_L1/L2 | HĐLĐ + trạng thái expiring 90/60/30 (sweep tự chuyển active→expiring) | REQ-HR-002 |
| API-ERP-064 | POST | `/api/v1/erp/attendance` | ESS (bản thân), HR_L1 (bổ sung) | Chấm công + overtime; cùng API cho MOBILE-INTERNAL | REQ-HR-003 |
| API-ERP-065 | POST | `/api/v1/erp/leave-requests` + `/{id}/approve` | POST: ESS; approve: HR_L1→HR_L2 phân cấp | Nghỉ phép: balance_check tự động trước khi vào approval | REQ-HR-004 |
| API-ERP-066 | GET | `/api/v1/erp/ess/me` | ESS (bản thân) | Self-service: công, phép, timesheet, thông tin cá nhân | REQ-HR-005 |
| API-ERP-067 | POST | `/api/v1/erp/rate-cards` + `/{id}/finance-endorse` | POST: HR_L2; endorse: FIN_L1 | Cost rate card version hóa + thẩm định FIN trước effective date | REQ-HR-006 |
| API-ERP-068 | POST | `/api/v1/erp/timesheets` + `/{id}/transitions` | POST: nhân viên; transitions: OPS_AM ∥ HR duyệt song song | draft→submitted→reviewed→approved (2 chân duyệt độc lập)→capacity_computed; phát `timesheet.approved` | REQ-OPS-007, REQ-HR-009 |
| API-ERP-069 | GET | `/api/v1/erp/capacity` | OPS/HR/BOD | Capacity theo nhân sự/đội: vàng 90%, đỏ 100% | REQ-OPS-007 |
| API-ERP-070 | GET/POST | `/api/v1/erp/kpi-periods/{id}[/calibrate|/finalize]` | GET: HR/quản lý; calibrate: HR_L2 + ban điều hành; finalize: HR_L2 | KPI 3 trụ cột auto-aggregate (CAPTS/COMM/CRM) → calibration → finalized | REQ-HR-007 |
| API-ERP-071 | POST/PATCH | `/api/v1/erp/pips[/{id}[/checkpoints]]` | HR_L2 | PIP 30-60-90; trigger từ `kpi.below_threshold` (đề xuất, người phê) | REQ-HR-008 |

#### 6.6. COMP-ERP-006 — SLA & Notification Worker (MOD-SLA-NOTIF) — FEAT-ERP-SLANOT-001

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-072 | GET/PUT | `/api/v1/erp/sla-policies[/{id}]` | GET: OPS/FIN; PUT: cấu hình qua phê duyệt tham số (REQ-BOD-009 — BOD) | Instance ma trận tier×priority GMT+7; effective-dated | REQ-OPS-008, REQ-BOD-009 |
| API-ERP-073 | GET | `/api/v1/erp/sla-timers` | OPS/FIN (scope) | Trạng thái timer per object (`object_type,object_id,sla_state`); timer persist sống qua restart | REQ-OPS-008 |
| API-ERP-074 | GET | `/api/v1/erp/notifications` | role sở hữu object | Log dispatch đa kênh (idempotent + retry); kênh ngoài in-app [NEEDS_REVIEW: P3-01 Phụ lục A #3] | REQ-OPS-008 |

#### 6.7. COMP-ERP-007 — Batch & Recon Scheduler (jobs cross-module)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-075 | GET | `/api/v1/erp/jobs` | SYS_ADMIN, FIN (job tiền) | Job registry + run history (đối trừ 3 số, sweep hard stop, aging, HĐLĐ 90/60/30, KPI aggregate, clawback, capacity, checkpoint handoff) | REQ-FIN-004/006, REQ-OPS-008 |
| API-ERP-076 | POST | `/api/v1/erp/jobs/{key}/trigger` | SYS_ADMIN (không tự duyệt thay người) | Re-run manual theo window; idempotency key (job, window); audit `triggered_by=manual` | REQ-FIN-006 |
| API-ERP-077 | GET/POST | `/api/v1/erp/jobs/dead-letters[/{id}/replay]` | SYS_ADMIN + owner module | DLQ view; replay là hành động người, không auto-replay | REQ-OPS-008 |

### 7. Internal API (Service-to-Service)

Kiến trúc **modular monolith** (P3-01 §1): giao tiếp giữa COMP-ERP-001…007 là **internal method call qua module interface** — không network hop ngày 1. Chỉ 2 tuyến REST external thực sự:

| Method | Path | Caller | Purpose | REQ-ID |
|--------|------|--------|---------|--------|
| POST | `/api/v1/erp/tickets` (API-ERP-057, header `X-Portal-Service-Token`) | SYS-PORTAL-WEB | Điểm ghi duy nhất ticket từ portal | REQ-OPS-009 |
| POST | `/internal/erp/portal-read-model/publish` | COMP-ERP-002/003 | Publish read-model ví read-only + invoice + campaign status sang PORTAL [NEEDS_REVIEW: contract API — P3-01 Phụ lục A #6] | REQ-FIN-017, REQ-OPS-010 |

Event (outbox, consumer idempotent, DLQ) theo §5 P3-01 + arch-draft §5: `wallet.matched`, `wallet.low_balance`, `recon.mismatch`, `handoff.ops_ack`, `deal.signed`, `payment.received`, `refund.executed`, `invoice.issued`, `timesheet.approved`, `kpi.below_threshold`, `sla.warning`, `sla.breach`, `deliverable.acceptance_due`. Payload schema versioned — chi tiết ở `integration-map.md` (aggregation).

### 8. Rate Limiting

| Endpoint group | Limit | Window |
|---------------|-------|--------|
| Money commands (`/wallets/*/transactions`, `/ar-invoices/*/payments`, `/payment-orders/*`, `/einvoices/*/issue`) | 60 req | 1 phút/user |
| Bulk import (`/leads/bulk-import`) | 5 req | 1 phút |
| Export/báo cáo (`/platform-fees`, `/commissions`, `/capacity`, read-model publish) | 10 req | 1 phút |
| General ERP API | 200 req | 1 phút/user |
| Internal (portal publish, service token) | 1000 req | 1 phút |

## Hệ thống: SYS-CORE-BACKEND — Core Backend

## API Contract — SYS-CORE-BACKEND (Core Backend)

> Session: 20260913-053848-f4d7 | Lane: core-backend | TRIO: architect + dba + devops
> READS: `phase2-features/core-backend/rbac-audit/*.md`, `phase2-features/core-backend/datahub-bi/*.md`, `P3-01-architecture.md` (§1, §5, §6, §8, §10), `lanes/core-backend/arch-draft.md`
> OUTPUT: API conventions, response formats, endpoint registry cho nền tảng identity/audit/analytics
> USED BY: `integration-map.md`, `phase4-ux/core-backend/*`, `phase5-implementation/tasks/core-backend/*`
> DATE: 2026-09-13 | VERSION: v1
>
> **Scope guard:** chỉ MOD-RBAC-AUDIT + MOD-DATAHUB-BI. API nghiệp vụ của 15 business module (lead, ví, TKQC, lệnh chi...) là tài sản canonical của lane khác —Core chỉ cung cấp điểm neo: PDP check, audit append, BI serving. KHÔNG thiết kế lại business API.

---

### 1. Global Conventions

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

### 2. Standard Response Envelopes

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
      "loaded_at": "2026-09-13T04:35:02Z", "freshness_sla_minutes": 5,
      "is_stale": false
    }
  }
}
```

### 3. HTTP Status Codes

Chuẩn template (200/201/400/401/403/404/409/429/500/503) + quy ước Core:

| Code | Khi nào — đặc thù Core |
|------|------------------------|
| 401 | Token hết hạn hoặc thiếu MFA step-up cho endpoint lớp `[STEP-UP]` |
| 403 | PDP deny + ghi audit access-denied (bắt buộc, không bỏ qua) |
| 409 | State machine vi phạm: policy chưa approve, campaign đã đóng, alert đã resolved |
| 503 | PDP/KMS/warehouse không phản hồi — action tài chính fail-closed (đề xuất P3-01 §11; chốt fail-open/closed luồng đọc [NEEDS_REVIEW]) |

### 4. Error Codes Registry

Ngoài registry chuẩn template (`VALIDATION_ERROR`, `UNAUTHORIZED`, `TOKEN_EXPIRED`, `FORBIDDEN`, `NOT_FOUND`, `DUPLICATE`, `INVALID_STATE`, `RATE_LIMIT_EXCEEDED`, `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE`), Core định nghĩa:

| Code | HTTP | Mô tả |
|------|------|-------|
| `MFA_STEP_UP_REQUIRED` | 401 | Endpoint bắt buộc step-up, token chưa mang MFA |
| `MFA_ENROLLMENT_REQUIRED` | 403 | Vai tài chính/BOD/SYS_ADMIN chưa đăng ký MFA |
| `SOD_VIOLATION` | 409 | Vi phạm tách nhiệm vụ: tự duyệt, cùng người 2 chân, combined-role thiếu 2 nấc khác người — fail-closed |
| `POLICY_NOT_APPROVED` | 409 | Phiên bản policy chưa được duyệt theo REQ-BOD-009, không thể kích hoạt |
| `AUDIT_IMMUTABLE` | 409 | Cố update/delete bản ghi audit — bị chặn tầng DB + alert |
| `CHAIN_BROKEN` | 500 | Hash chain verify thất bại — severity HIGH, tự sinh alert |
| `PII_MASKED_FIELD` | 200 | Trường PII trả về dạng masked theo vai (không phải lỗi) |
| `BREAK_GLASS_REQUIRED` | 403 | Đọc PII Restricted ngoài vai — phải mở yêu cầu break-glass |
| `CONTRACT_SCHEMA_DRIFT` | 409 | Ingest payload lệch contract version đã đăng ký |
| `MART_STALE` | 200 | Kèm `is_stale=true` — dữ liệu quá freshness SLA, client hiển thị nhãn |

### 5. Authentication Endpoints

Core Backend là IdP duy nhất (COMP-CORE-001, REQ-BOD-011). 5 systems khác là Relying Party; không service nào tự quản password. IdP đề xuất Keycloak 2 realms (realm nội bộ MFA bắt buộc + realm portal OTP) theo FEAT-CORE-RBAC-005 — chốt phương pháp MFA [NEEDS_REVIEW: TOTP/hardware key/passkey].

#### API-CORE-001 — POST /api/v1/core/auth/token
```
Request:  { "grant_type": "password"|"authorization_code"|"refresh_token",
            "username", "password", "otp"?, "code"?, "refresh_token"? }
Response 200: { accessToken, refreshToken, expiresIn: 900, tokenType: "Bearer",
                user: { id, email, fullName, roles[], dept, dataScope } }
Error 401: INVALID_CREDENTIALS | MFA_ENROLLMENT_REQUIRED
Ghi audit: login_success / login_failed (IP, user_agent) — FEAT-CORE-RBAC-005
```

#### API-CORE-002 — POST /api/v1/core/auth/token/refresh
```
Request: { "refreshToken" } → 200 { accessToken, expiresIn }
Refresh token rotate: token cũ bị revoke ngay khi dùng; replay refresh token
đã dùng → revoke toàn bộ session + alert (phát hiện token theft).
```

#### API-CORE-003 — POST /api/v1/core/auth/mfa/step-up `[STEP-UP]`
```
Request: { "otp": "123456", "purpose": "payment_approval"|"vault_access"|
           "policy_approval"|"period_lock" }
Response 200: { verified: true, stepUpValidUntil: "...+5 phút" }
Bắt buộc trước: lệnh tiền, dual approval, vault, HĐĐT, khóa kỳ, duyệt policy
(P3-01 §8.1). Ghi audit step_up_success/failed.
```

#### API-CORE-004 — POST /api/v1/core/auth/mfa/enrollments
Bắt đầu đăng ký TOTP (trả provisioning URI + QR); xác nhận bằng lượt verify đầu. Vai tài chính/BOD/SYS_ADMIN bị chặn thao tác cho đến khi enroll xong (`MFA_ENROLLMENT_REQUIRED`).

#### API-CORE-005 — POST /api/v1/core/auth/logout
Revoke session hiện hành + refresh token. Server-side session registry là nguồn sự thật (không chỉ xóa cookie).

#### API-CORE-006 — GET/DELETE /api/v1/core/auth/sessions
GET: danh sách session active của user hiện tại (device, IP, last_seen). DELETE `/:sessionId`: thu hồi 1 session — hỗ trợ thu hồi tức thời khi offboarding/thu hồi quyền ≤24h (REQ-BOD-011, COMP-CORE-001).

#### API-CORE-007 — GET /api/v1/core/auth/.well-known/openid-configuration · /jwks.json
OIDC discovery + bộ khóa công khai cho 5 RP verify token. Public, rate-limit chặt.

#### API-CORE-008 — POST /api/v1/core/auth/introspect (internal)
RP/service kiểm tra trạng thái token (active, revocation tức thời). Auth bằng service token.

### 6. Endpoints By System — SYS-CORE-BACKEND

> Mọi endpoint có cột FEAT-ID (traceability bắt buộc theo template) + PERMISSION (vai theo registry business-context v4.1: BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1/L2, FIN_L1/L2, SALES_L1–L3, OPS_PLAN/AM/CONT, ESS + CLIENT_ADMIN/CLIENT_USER external. Các vai mở rộng xuất hiện rải rác trong specs — GM (API-ERP-013, API-MBI-011), SALES_L4 (API-GW-039), OPS_DES/EDIT/ADS — chờ BOD chốt trong [NEEDS_REVIEW #8, Phụ lục A P3-01]).

#### Module: RBAC & Audit Log (MOD-RBAC-AUDIT)

##### 6.1 Identity lifecycle (COMP-CORE-001)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-009 | GET | `/core/users` | SYS_ADMIN | List user + filter role/dept/status, pagination | FEAT-CORE-RBAC-005 / REQ-BOD-011 |
| API-CORE-010 | POST | `/core/users` | SYS_ADMIN | Tạo user (onboarding, trạng thái khởi điểm `probation` — người thử việc không có quyền phê duyệt) | FEAT-CORE-RBAC-005 / REQ-BOD-011 |
| API-CORE-011 | GET | `/core/users/:id` | SYS_ADMIN + chính chủ | Chi tiết user (roles, sessions, MFA state) | FEAT-CORE-RBAC-005 |
| API-CORE-012 | PUT | `/core/users/:id` | SYS_ADMIN | Cập nhật hồ sơ định danh (không đụng credential — thuộc IdP) | FEAT-CORE-RBAC-005 |
| API-CORE-013 | POST | `/core/users/:id/transitions` | SYS_ADMIN (thu hồi: SYS_ADMIN thực thi sau quyết định HR/BOD) | State machine `probation→active→suspended→locked→deactivated`; offboarding thu hồi mọi session + rotate ≤24h | FEAT-CORE-RBAC-005 / REQ-BOD-011 |
| API-CORE-050 | POST | `/core/users/:id/sessions/revoke-all` `[STEP-UP]` | SYS_ADMIN | Thu hồi TẬP TRUNG mọi session active của 1 user — tình huống nghi ngờ compromise khi chưa cần khóa/đổi state user; ghi audit + evidence WORM | FEAT-CORE-RBAC-002, 005 / REQ-BOD-005, REQ-BOD-011 |

##### 6.2 RBAC & Policy Engine — PDP (COMP-CORE-002)

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

##### 6.3 Quarterly Access Review (COMP-CORE-003)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-024 | GET/POST | `/core/access-reviews/campaigns` | SYS_ADMIN tạo/mở; BOD_CEO xem | Campaign quý: sinh items từ user×role×dept; tự trigger theo lịch + recertification khi đổi vai/phòng/kiêm nhiệm | FEAT-CORE-RBAC-003 / REQ-BOD-007 |
| API-CORE-025 | GET | `/core/access-reviews/campaigns/:id/items` | SYS_ADMIN + reviewer được phân công (chủ sở hữu vai) | List items chờ review, filter theo dept/role/đặc quyền nhạy cảm (vault CTO, Restricted) | FEAT-CORE-RBAC-003 |
| API-CORE-026 | POST | `/core/access-reviews/items/:id/decisions` | Reviewer phân công `[STEP-UP]` với đặc quyền nhạy cảm | approve / revoke / extend + lý do; revoke thực thi ngay | FEAT-CORE-RBAC-003 / REQ-BOD-007 |
| API-CORE-027 | POST | `/core/access-reviews/campaigns/:id/close` | SYS_ADMIN → BOD_CEO xác nhận | Đóng campaign, đóng gói decision log thành bằng chứng → WORM (API-CORE-031 cùng đường) | FEAT-CORE-RBAC-003, 007 / REQ-BOD-007, FIN-012 |

##### 6.4 Audit Log & WORM (COMP-CORE-004, 005)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-028 | POST | `/core/audit/events` | internal (service token — đường ghi DUY NHẤT mọi module) | Append event: who/what/object/state/before-after/when/ip/correlation_id; hash-chain server-side; không có update/delete | FEAT-CORE-RBAC-002 / REQ-BOD-005 |
| API-CORE-029 | GET | `/core/audit/events` | BOD_CEO (toàn bộ); SYS_ADMIN (vận hành); FIN_L2 (phạm vi tài chính) | Truy xuất có kiểm soát: filter actor/object/time/action, pagination 20/100; mọi lượt query tự ghi audit | FEAT-CORE-RBAC-002 / REQ-BOD-005 |
| API-CORE-030 | GET | `/core/audit/objects/:objectId/timeline` | Theo vai sở hữu object + SYS_ADMIN | Activity timeline per object (feed cho module có timeline: lệnh tiền, TKQC, ticket) | FEAT-CORE-RBAC-002 |
| API-CORE-031 | POST | `/core/audit/export-requests` | Yêu cầu: FIN_L2, SYS_ADMIN, BOD_CEO; Duyệt: BOD_CEO `[STEP-UP]` | Truy xuất có kiểm soát ra evidence package: request → approve → export vào WORM (object-lock ≥10 năm với log tiền/chứng từ) | FEAT-CORE-RBAC-002, 007 / REQ-BOD-005, FIN-012 |
| API-CORE-032 | GET | `/core/audit/chain/verify` | SYS_ADMIN chạy; BOD_CEO xem kết quả | Verify hash chain theo khoảng seq; kết quả + WORM ref integrity; lệch → alert HIGH | FEAT-CORE-RBAC-002, 007 / REQ-BOD-005, FIN-012 |

##### 6.5 PII Field Protection (COMP-CORE-006)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-033 | GET/POST/PUT | `/core/pii/classifications` | SYS_ADMIN quản trị; HR_L2 đồng duyệt với PII lương | Classification registry Public/Internal/Confidential/Restricted + tier C1–C3/T1–T4 gắn field | FEAT-CORE-RBAC-006 / REQ-HR-010 |
| API-CORE-034 | GET/PUT | `/core/pii/mask-configs` | SYS_ADMIN; HR_L2 đồng duyệt | Masking rule theo vai (HR_L1/L2 thấy rõ; ESS chỉ thông tin cá nhân) áp ở API layer + trước khi vào warehouse | FEAT-CORE-RBAC-006 / REQ-HR-010 |
| API-CORE-035 | POST | `/core/pii/break-glass-requests` | Đề xuất: mọi vai; Duyệt: BOD_CEO `[STEP-UP]` | Truy cập khẩn PII Restricted: yêu cầu → duyệt → mở có giờ + audit bắt buộc mọi lượt đọc [NEEDS_REVIEW: quy trình khẩn chưa định nghĩa trong registry — mặc định đề xuất này] | FEAT-CORE-RBAC-006 / REQ-HR-010 |

#### Module: Data Integration Hub & BI (MOD-DATAHUB-BI)

##### 6.6 BI Serving (COMP-CORE-010)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-036 | GET | `/core/bi/marts/:martName` | BOD_CEO, BOD_CFO_CTO, FIN_L1/L2 (finance marts); OPS theo scope (ops marts); SYS_ADMIN vận hành | Query mart (wallet, ar_ap, sales_funnel, ops_delivery, people_cost, cs_sla, shop_reference): filter/sort server-side, pagination, freshness metadata; PDP check bắt buộc | FEAT-CORE-DHUB-002, 004 / REQ-BOD-004, FIN-015 |
| API-CORE-037 | GET | `/core/bi/pnl` | BOD_CEO, BOD_CFO_CTO, FIN_L1/L2 | P&L realtime (freshness SLA stream P&L ≤5 phút theo REQ-BOD-003/FIN-016 — đồng bộ P3-01 §10.1/§10.3 [NEEDS_REVIEW: chốt FIN/BOD — Phụ lục A #10]) + snapshot kỳ so sánh liên kỳ + dòng tách timesheet-chưa-duyệt | FEAT-CORE-DHUB-001, 005 / REQ-BOD-003, FIN-016 |
| API-CORE-038 | GET | `/core/bi/dashboards` · `/:id` | BOD, FIN; layout theo vai | Dashboard registry + định nghĩa widget map vào marts; render chỉ khi `is_stale=false` | FEAT-CORE-DHUB-002, 005 / REQ-BOD-004, FIN-016 |
| API-CORE-039 | POST | `/core/bi/exports` | BOD_CEO, BOD_CFO_CTO, FIN_L1/L2 | Export CSV/PDF async job + audit truy xuất; scheduled snapshot định kỳ | FEAT-CORE-DHUB-004 / REQ-FIN-015 |
| API-CORE-040 | GET | `/core/bi/freshness` | Mọi consumer BI | Freshness per mart: last_watermark, loaded_at, sla, is_stale | FEAT-CORE-DHUB-001 |

##### 6.7 Alert Center (COMP-CORE-011)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-041 | GET/POST | `/core/alerts/rules` | Xem: BOD, FIN, SYS_ADMIN; Tạo: SYS_ADMIN → BOD_CEO duyệt | Rule-based trên marts + event: ví < đủ chi 3 ngày, mismatch đối trừ, aging, die account, shop anomaly, DLQ depth, freshness vi phạm | FEAT-CORE-DHUB-003 / REQ-BOD-006 |
| API-CORE-042 | PUT | `/core/alerts/rules/:id` `[STEP-UP]` khi đổi severity/routing | SYS_ADMIN → BOD_CEO duyệt | Sửa/tắt rule — audit mọi thay đổi | FEAT-CORE-DHUB-003 |
| API-CORE-043 | GET | `/core/alerts/instances` | BOD, FIN, OPS theo severity routing | List alert: filter status/severity/window, pagination | FEAT-CORE-DHUB-003 |
| API-CORE-044 | POST | `/core/alerts/instances/:id/transitions` | Theo severity routing (BOD/FIN/OPS) `[STEP-UP]` severity CRITICAL | Lifecycle `open→acknowledged→investigating→resolved`; không auto-close — người ack (P3-01 §11.5) | FEAT-CORE-DHUB-003 / REQ-BOD-006 |
| API-CORE-045 | GET/PUT | `/core/alerts/routing` | SYS_ADMIN → BOD_CFO_CTO duyệt | Severity → kênh + người nhận; dispatch ủy quyền MOD-SLA-NOTIF (on-call DI-005) | FEAT-CORE-DHUB-003 / REQ-BOD-006 |

##### 6.8 Ingest Admin (COMP-CORE-007, 008)

| API ID | Method | Path | Permission | Mô tả | FEAT-ID / REQ |
|--------|--------|------|-----------|-------|---------------|
| API-CORE-046 | GET/POST/PUT | `/core/ingest/contracts` | SYS_ADMIN; module nguồn đề xuất schema | Contract registry versioned (schema + natural key + compatibility mode); drift bị chặn ở gate G0 | FEAT-CORE-DHUB-001 / REQ-BOD-003, FIN-005 |
| API-CORE-047 | GET | `/core/ingest/runs` | SYS_ADMIN; BOD xem freshness | Status run theo nguồn: watermark/LSN, gate pass/fail, DLQ count, freshness vs SLA | FEAT-CORE-DHUB-001 |
| API-CORE-048 | GET/POST | `/core/ingest/dlq` · `/dlq/:id/replay` | SYS_ADMIN (replay ghi audit) | DLQ view + replay là hành động người (không auto-replay — P3-01 §11.4) | FEAT-CORE-DHUB-003 |
| API-CORE-049 | POST | `/core/ingest/backfills` | SYS_ADMIN → CTO (BOD_CFO_CTO) duyệt | Backfill/replay theo window (phối hợp COMP-GW-005 khi nền tảng khôi phục); phát `backfill.completed` | FEAT-CORE-DHUB-001 / REQ-FIN-005 |

### 7. Internal API (Service-to-Service)

> Kiến trúc modular monolith (P3-01 §1): domain services ở SYS-BCERP-WEB gọi PDP/audit qua REST vì Core là service nền tảng riêng, không cùng process. Auth bằng service token (`X-Internal-Token`), timeout 3s/10s heavy query, retry 3 lần backoff.

| Method | Path | Caller | Purpose |
|--------|------|--------|---------|
| POST | `/api/v1/core/pdp/check` | PEP middleware mọi system | Quyết định + scope filter + constraints (API-CORE-014); cache 60s phía PEP, invalidate theo event role/policy change |
| POST | `/api/v1/core/audit/events` | Mọi module (đường ghi duy nhất) | Append audit hash-chain (API-CORE-028); buffer local + retry khi Core chậm — không chặn nghiệp vụ trừ action tài chính |
| POST | `/api/v1/core/auth/introspect` | 5 RP | Verify token + revocation tức thời (API-CORE-008) |

Điểm neo nghiệp vụ nằm ở phía module gốc (canonical thuộc lane khác): lệnh chi gọi PDP pre-check SoD/ngưỡng trước `POST /erp/payment-orders/:id/transitions`; ADACC gọi rule hard stop "đã khớp tiền" qua PDP constraint check (REQ-FIN-006); sweep re-validate tại nguồn vẫn là chính, event chỉ tối ưu.

### 8. Rate Limiting

| Endpoint group | Limit | Window |
|---------------|-------|--------|
| `/core/auth/token`, `/core/auth/mfa/*` | 10 req/IP | 1 phút (login fail ≥5 → lock tạm + alert) |
| `/core/auth/.well-known/*`, `/core/auth/introspect` | 600 req | 1 phút |
| `/core/pdp/check`, `/core/audit/events` (internal) | 5000 req | 1 phút (theo service) |
| `/core/bi/*` | 200 req/user | 1 phút |
| `/core/bi/exports`, `/core/audit/export-requests` | 5 req/user | 1 phút |
| `/core/audit/events` GET (query) | 60 req/user | 1 phút |
| General `/core/*` | 200 req/user | 1 phút |

## Hệ thống: SYS-INTEGRATION-GW — API Integration Gateway

## API Contract — SYS-INTEGRATION-GW (API Integration Gateway)

> READS: `phase2-features/integration-gw/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` (FEAT-GW-STGW-001 / REQ-BOD-008), `phase2-features/integration-gw/settings-gw/api-7-nen-tang-degraded-mode-manual.md` (FEAT-GW-STGW-002 / REQ-FIN-005), `phase2-features/integration-gw/tiktok-shop/tiktok-shop-monitoring.md` (FEAT-GW-TIKTOK-001 / REQ-OPS-011), `P3-01-architecture.md`
> OUTPUT: API conventions, response formats, endpoint registry của SYS-INTEGRATION-GW
> USED BY: `integration-map.md`, `phase4-ux/bcerp-web/settings-gw|tiktok-shop/` (counterpart console), `phase5-implementation/tasks/integration-gw/`
> DATE: 2026-09-13 | VERSION: v1 | Scope: MOD-SETTINGS-GW + MOD-TIKTOK-SHOP

---

### 1. Global Conventions

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

### 2. Standard Response Envelopes

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

### 3. HTTP Status Codes

Chuẩn dùng chung (200/201/400/401/403/404/409/429/500/503) + case riêng GW:

| Code | Khi nào |
|------|---------|
| 403 `MOBILE_VAULT_FORBIDDEN` | Request vault từ touchpoint mobile (BR-GW-STGW-005) |
| 403 `MFA_REQUIRED` | Thiếu step-up MFA hợp lệ cho thao tác vault/transition |
| 409 `NATURAL_KEY_DUPLICATE` | Trùng khóa tự nhiên statement/metric (platform+TKQC/shop+ngày+loại+mã tham chiếu) |
| 409 `JOB_OVERLAP` | Job sync chồng lấn cùng adapter (BR-GW-STGW-008) |
| 422 `SCHEMA_ROW_REJECTED` | Dòng import sai schema — trả lỗi theo dòng, batch vẫn nhận dòng hợp lệ |
| 423 `CREDENTIAL_LOCKED` | Profile đang REVOKED — cấm nạp token mới tại chỗ, phải qua revoke trước |

### 4. Error Codes Registry (bổ sung GW)

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
| `AUDIT_MUTATION_NOT_SUPPORTED` | 405 | Không có API sửa/xóa audit entry (BR-GW-STGW-007) — tách khỏi `AUDIT_IMMUTABLE` (409, SYS-CORE-BACKEND: bản ghi audit bị chặn sửa tầng DB) |

### 5. Authentication & MFA Step-Up (phụ thuộc SYS-CORE-BACKEND)

Gateway KHÔNG sở hữu login/refresh — dùng chung IdP core (`POST /core/auth/token`, `POST /core/auth/mfa/step-up`). Gateway chỉ: verify JWT + gọi PDP (cache TTL 60s), verify `X-MFA-Step-Up` cho path nhạy cảm, phân biệt `client_type` để cấm mobile vault. Mọi access-denied ghi audit.

### 6. Endpoints By System — SYS-INTEGRATION-GW

> FEAT-ID traceability: FEAT-GW-STGW-001 (REQ-BOD-008), FEAT-GW-STGW-002 (REQ-FIN-005; cross REQ-FIN-013, REQ-FIN-004), FEAT-GW-TIKTOK-001 (REQ-OPS-011).

#### 6.1. Module: Settings & Gateway Config (MOD-SETTINGS-GW)

##### Connection Profile & Lifecycle (FEAT-GW-STGW-001)

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

##### Credentials Vault (FEAT-GW-STGW-001) — mask-only, MFA, cấm mobile

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

##### Sync Job Admin (FEAT-GW-STGW-001)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|--------|------|------|-------------|--------|
| API-GW-012 | GET | `/gw/sync/schedules` | JWT | List schedule (cadence, batch_size, retry_policy, priority_rules) | REQ-BOD-008 |
| API-GW-013 | PUT | `/gw/sync/schedules/:id` | JWT+CTO | Cập nhật schedule (SYS_ADMIN thực thi sau duyệt) | REQ-BOD-008 |
| API-GW-014 | POST | `/gw/sync/jobs` | JWT+CTO | Kích hoạt run on-demand cho window `{platform, windowFrom, windowTo}` | REQ-FIN-005 |
| API-GW-015 | GET | `/gw/sync/jobs` | JWT | List job: filter `profileId,status` (queued/running/success/failed/retrying) | REQ-FIN-005 |
| API-GW-016 | GET | `/gw/sync/jobs/:id` | JWT | Chi tiết job + attempt + error_code + raw payload refs | REQ-FIN-005 |
| API-GW-017 | POST | `/gw/sync/jobs/:id/retry` | JWT+CTO | Retry tay sau khi hết retry tự động | REQ-FIN-005 |

##### Policy Config & Field Mapping (FEAT-GW-STGW-001/002)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|--------|------|------|-------------|--------|
| API-GW-018 | GET | `/gw/policies` | JWT | Tham số hiệu lực tại thời điểm `?at=` (effective-dated) | REQ-BOD-009 |
| API-GW-019 | GET | `/gw/policies/:paramKey/versions` | JWT | Lịch sử version + người duyệt + reason | REQ-BOD-009 |
| API-GW-020 | POST | `/gw/policies/:paramKey` | JWT+BOD | Ban hành version mới (chỉ BOD_CEO/BOD_CFO_CTO) — không hồi tố | REQ-BOD-008, REQ-BOD-009 |
| API-GW-021 | GET | `/gw/mappings` | JWT | List field mapping + import/export template theo profile | REQ-FIN-005, REQ-FIN-013 |
| API-GW-022 | PUT | `/gw/mappings/:id` | JWT+CTO | Cập nhật mapping (DI-004 — thêm nguồn = thêm profile, không sửa code) | REQ-FIN-013 |
| API-GW-023 | POST | `/gw/exports` | JWT | Sinh file xuất chuẩn schema cho connector VAS import_export + log lượt xuất | REQ-FIN-013 |

##### Degraded/Backfill Status & Trigger (FEAT-GW-STGW-002)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|--------|------|------|-------------|--------|
| API-GW-025 | GET | `/gw/degraded/status` | JWT | State luồng per-platform: MANUAL ↔ API ↔ BACKFILL + tuổi dữ liệu | REQ-FIN-005 |
| API-GW-026 | POST | `/gw/backfill/runs` | JWT+CTO | Kích hoạt backfill `{platform, gapFrom, gapTo}` — theo sự kiện cấp quyền, không đặt lịch | REQ-FIN-005 |
| API-GW-027 | GET | `/gw/backfill/runs` | JWT | List backfill run + progress + recheck_status kỳ manual | REQ-FIN-005 |

##### Import Manual Channels (FEAT-GW-STGW-002) — chặn lỗi theo dòng

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

##### Statement Query cho Đối Trừ + Raw Payload + Audit (FEAT-GW-STGW-002)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|------|------|------|-------------|--------|
| API-GW-032 | GET | `/gw/statements` | JWT (FIN/OPS scope) | Query statement gắn nhãn: filter `platform,adaccountRef,windowFrom,windowTo,sourceLabel` | REQ-FIN-005, REQ-FIN-004 |
| API-GW-033 | GET | `/gw/raw-payloads` | JWT+CTO | List raw payload theo job/batch + parse_status | REQ-BOD-008 |
| API-GW-034 | POST | `/gw/raw-payloads/:id/reprocess` | JWT+CTO | Chạy lại chuẩn hóa sau khi mapping đổi (raw lưu trước parse) | REQ-FIN-005 |
| API-GW-035 | GET | `/gw/audit-logs` | JWT (CTO/CEO) | Xem gateway audit + API call log; việc xem cũng bị log | REQ-BOD-008, REQ-FIN-012 |

**API-GW-032 — hợp đồng dữ liệu cho đối trừ 3 số (BR-FIN-205a):** response mỗi bản ghi gồm `platform, adaccountRef, txnDate, txnType, amountOriginal, currency, fee, referenceCode, sourceLabel (api|manual, immutable), enteredBy?, evidenceRef?, freshness`; core chỉ đưa bản ghi đủ nhãn (+ evidence với `manual`) vào đối trừ. Không có endpoint sửa nhãn — attempt → 405 `AUDIT_MUTATION_NOT_SUPPORTED` + audit.

#### 6.2. Module: TikTok Shop Monitoring (MOD-TIKTOK-SHOP)

##### Shop Connection & Lifecycle 3-Gate (FEAT-GW-TIKTOK-001)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|------|------|------|-------------|--------|
| API-GW-036 | POST | `/gw/shop/connections` | JWT (OPS_AM) | Đề xuất kết nối OAuth per-client (1 shop-1 ủy quyền-1 khách, scope ghi rõ) | REQ-OPS-011 |
| API-GW-037 | GET | `/gw/shop/connections` | JWT | List tenant-scoped, filter `tenantId,status,gateStage` | REQ-OPS-011 |
| API-GW-038 | GET | `/gw/shop/connections/:id` | JWT | Chi tiết + scope + gate_stage + expires_at | REQ-OPS-011 |
| API-GW-039 | POST | `/gw/shop/connections/:id/transitions` | JWT (SALES_L4/SYS_ADMIN) | Transition: approve / reject / go_live / mark_degraded / revoke (≤24h) | REQ-OPS-011 |
| API-GW-040 | GET | `/gw/shop/connections/:id/access-logs` | JWT (CTO/OPS_AM) | Access log bất biến (ai, khi nào, api_object, scope_used) | REQ-OPS-011 |

**API-GW-039 — ràng buộc:** `go_live` yêu cầu tín hiệu Gate 2 từ core (workflow 3 Gate sở hữu ở core — gateway chỉ phản chiếu + tự gate-check trước mỗi job); `revoke` theo sự kiện hợp đồng/khách yêu cầu, hoàn tất ≤24h, sau đó mọi pull vô hiệu vĩnh viễn kể cả backfill (BR-OPS-4.1c); shop bị platform khóa KHÔNG đổi trạng thái kết nối — chỉ gắn cờ health + alert.

##### Metrics, PII Session, Alert & Portal Feed (FEAT-GW-TIKTOK-001)

| API-ID | Method | Path | Auth | Description | REQ-ID |
|--------|------|------|------|-------------|--------|
| API-GW-041 | GET | `/gw/shop/metrics` | JWT (OPS/FIN scope) | Query ShopMetricDaily: filter `shopId,window,metricType,sourceLabel`; luôn `referenceOnly=true` | REQ-OPS-011 |
| API-GW-042 | POST | `/gw/shop/imports/metrics` | JWT (OPS_ADS/OPS_AM) | Import degraded schema 6 trường, chặn lỗi theo dòng | REQ-OPS-011 |
| API-GW-043 | GET | `/gw/shop/imports/batches/:id` | JWT | Kết quả batch metric + rowErrors | REQ-OPS-011 |
| API-GW-044 | POST | `/gw/shop/pii-sessions` | JWT (OPS_ADS/OPS_AM) | Mở phiên PII TTL `{connectionId, reason}` — reason bắt buộc; dữ liệu đầy đủ KHÔNG persist | REQ-OPS-011 |
| API-GW-045 | DELETE | `/gw/shop/pii-sessions/:id` | JWT | Đóng phiên sớm; hết TTL tự đóng | REQ-OPS-011 |
| API-GW-046 | GET | `/gw/shop/alerts` | JWT | Alert feed: shop khóa, settlement lệch, giấy phép/OAuth hết hạn, baseline lệch (web + M-INT push tiêu thụ) | REQ-OPS-011 |

##### Internal API (Service-to-Service)

| API-ID | Method | Path | Caller | Purpose | REQ-ID |
|--------|------|------|--------|---------|--------|
| API-GW-047 | GET | `/internal/gw/shop/portal-feed?tenantId=&period=` | SYS-CORE-BACKEND (Portal API Gateway) | PortalReportFeed đã mask + tổng hợp, tenant-scoped, read-only — gateway không serve portal trực tiếp (BR-GW-TT-002) | REQ-OPS-011 |
| API-GW-048 | GET | `/internal/gw/feed/wallet-status?window=` | SYS-CORE-BACKEND | Fact feed PlatformStatement gắn nhãn cho đối trừ 3 số + cảnh báo ví (bên cạnh event `wallet.sync.completed`) | REQ-FIN-005, REQ-OPS-003 |

Auth internal: `X-Internal-Token` service-to-service; timeout 3s/10s heavy; tenant filter bắt buộc — feed thiếu filter tenant bị chặn.

### 7. Internal API (Service-to-Service)

Ngoài 2 endpoint trên, gateway tiêu thụ internal của core: PDP check, MFA step-up verify, audit SDK (hash-chain), gate-stage signal, sự kiện hợp đồng (kích hoạt thu hồi shop). Không mở webhook receiver — cả 3 spec đều pull-based [NEEDS_REVIEW: nếu nền tảng hỗ trợ push (vd TikTok Shop event feed), bổ sung component nhận webhook khi API được cấp quyền].

### 8. Rate Limiting

| Endpoint group | Limit | Window | Ghi chú |
|---------------|-------|--------|---------|
| `/gw/vault/*` | 10 req | 1 phút | Cạo guess window + MFA |
| `/gw/connections/*/transitions`, `/gw/shop/connections/*/transitions` | 30 req | 1 phút | — |
| `/gw/imports/*` | 5 req | 1 phút | Batch nặng; queue phía sau |
| `/gw/statements`, `/gw/shop/metrics` | 200 req | 1 phút | Đối soát đọc nhiều |
| `/internal/gw/*` | 1000 req | 1 phút | Service-to-service |
| Outbound per-platform (worker) | Theo quota từng nền tảng | hourly window | Circuit breaker per-platform; không share limit giữa 7 nguồn |

---

> **[NEEDS_REVIEW] (API):** (1) webhook receiver chưa trong phạm vi — pull-based theo cả 3 spec; (2) cơ chế kết nối chính xác VAS (API hay import file) chưa xác định [KXN-9] — API-GW-002/022/023 thiết kế tổng quát cho cả 2; (3) gatewayAudit truy vấn có cần API riêng tách khỏi COMP-CORE-004 hay chỉ proxy — chờ lane CORE chốt contract audit store; (4) vai `SALES_L4` (API-GW-039) và `GM` (API-ERP-013, API-MBI-011) là vai mở rộng ngoài danh mục registry hiện hành — chờ BOD chốt danh mục 18 vai (P3-01 Phụ lục A #8).

## Hệ thống: SYS-PORTAL-WEB — Client Portal Web

## API Contract — SYS-PORTAL-WEB (Client Portal Web)

> Session: 20260913-053848-f4d7 | Lane: portal-web | TRIO: architect + dba + devops
> READS: `phase2-features/portal-web/client-portal/*.md`, `portal-web/wallet-recon/*.md`, `portal-web/campaign-deliverable/*.md`, `portal-web/ticket-cskh/*.md`, `P3-01-architecture.md` (§1, §5, §6, §8), `lanes/portal-web/arch-draft.md`
> OUTPUT: API conventions, response formats, endpoint registry portal client-facing
> USED BY: `integration-map.md`, `phase4-ux/portal-web/*`, `phase5-implementation/tasks/portal-web/*`
> DATE: 2026-09-13 | VERSION: v1
>
> **Scope guard:** chỉ MOD-CLIENT-PORTAL. Ví/campaign/ticket/invoice là **read-model** từ SYS-BCERP-WEB/CORE — portal không tái định nghĩa nghiệp vụ gốc, không có endpoint ghi lên dữ liệu tài chính. Điểm ghi: ticket + comment (REQ-OPS-009), xác nhận nghiệm thu milestone (REQ-OPS-006), account self-service, exports, incidents.

---

### 1. Global Conventions

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

### 2. Standard Response Envelopes

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

### 3. HTTP Status Codes

Chuẩn template (200/201/400/401/403/404/409/429/500/503). Đặc thù portal:

| Code | Khi nào — đặc thù portal |
|------|--------------------------|
| 401 | Chưa auth; 2FA chưa verify (`2FA_REQUIRED`); thiếu OTP (`OTP_REQUIRED`) |
| 403 | `TENANT_CROSS_ACCESS`, `READ_ONLY_VIOLATION`, `INTERNAL_IDENTITY_REJECTED`, `DPA_NOT_SIGNED` |
| 409 | `QUOTA_EXCEEDED` (vượt hạn mức user), `INVITE_EXPIRED`, `MILESTONE_WINDOW_CLOSED` |
| 503 | CORE read-view / IdP / watermark service không phản hồi; read-model vẫn trả cache kèm `is_stale=true` khi còn TTL thay vì fail cứng |

### 4. Error Codes Registry

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

### 5. Authentication Endpoints

Chi tiết mẫu 2 luồng chính; còn lại theo registry mục 6.

#### POST /api/v1/portal/auth/invites/:token/accept
```
Response 200: { success: true, data: { invite: { email_masked, tenant_legal_name,
  role, expires_at }, next_step: "activate" } }
Error 409 INVITE_EXPIRED | 403 DPA_NOT_SIGNED (tenant chưa ký DPA — chặn)
```

#### POST /api/v1/portal/auth/invites/:token/activate
```
Request:  { password, otp_code, totp_enrollment: { secret, first_code } }
Điều kiện: token một-lần còn hạn; OTP email xác minh; bật 2FA bắt buộc —
thiếu 2FA → 401 2FA_REQUIRED (không tồn tại ACTIVE chưa 2FA).
Response 201: { success: true, data: { user_id, status: "ACTIVE", tenant_id } }
```

#### POST /api/v1/portal/auth/login + POST /api/v1/portal/auth/2fa/verify
```
Login (bước 1): { email, password } → 200 { challenge_id, methods: ["totp","otp"] }
  — internal identity → 403 INTERNAL_IDENTITY_REJECTED; sai liên tục 5 lần → LOCKED tự động
2FA verify (bước 2): { challenge_id, code } → 200 { accessToken, refreshToken, expiresIn, user }
  — refreshToken TTL 12 giờ (đề xuất — cấu hình; session timeout theo BR-005)
```

### 6. Endpoints — SYS-PORTAL-WEB (MOD-CLIENT-PORTAL)

Quy ước cột Permission: `BOTH` = CLIENT_ADMIN + CLIENT_USER; `ADMIN` = chỉ CLIENT_ADMIN; `PUB` = pre-auth (token/challenge). Tenant scoping bắt buộc 100% (mục 1) — không lặp lại từng dòng.

#### 6.1 Portal auth & phiên — FEAT-PORTAL-CPORT-002 / FEAT-PORTAL-RBAC-001

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

#### 6.2 Account self-service (CLIENT_ADMIN tự quản user trong quota) — FEAT-PORTAL-CPORT-002

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú |
|--------|--------|------|-----------|---------|--------|---------|
| API-PORTAL-013 | GET | `/accounts/users` | ADMIN | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Trả kèm quota_used/quota_limit theo role; không lộ gate nội bộ |
| API-PORTAL-014 | POST | `/accounts/users` | ADMIN [OTP] | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Tạo user → sinh invite; vượt quota → 409 QUOTA_EXCEEDED; nội bộ không có đường tạo hộ (SC-003) |
| API-PORTAL-015 | POST | `/accounts/users/:userId/transitions` | ADMIN | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | re_invite (EXPIRED→INVITED, token cũ vô hiệu); unlock (LOCKED→ACTIVE sau xác minh POC); revoke (ACTIVE→DISABLED, giải phóng suất quota); thu hồi CLIENT_ADMIN cần dấu vết xác nhận POC (BR-004) |
| API-PORTAL-016 | GET | `/accounts/me` | BOTH | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Profile + trạng thái 2FA + locale/timezone |
| API-PORTAL-017 | PUT | `/accounts/me/password` | BOTH [OTP] | FEAT-PORTAL-CPORT-002 | REQ-OPS-010 | Đổi mật khẩu — BR-008 |
| API-PORTAL-018 | GET | `/accounts/tenant` | BOTH | FEAT-PORTAL-CPORT-002 | REQ-OPS-010, REQ-FIN-017 | tenant_ref: legal_name, tier, quota, dpa_signed — không chứa dữ liệu giá nội bộ |

#### 6.3 Read-model ví (GET only — read-only tuyệt đối, BR-001 CPORT-001) — FEAT-PORTAL-CPORT-001

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú whitelist/mask |
|--------|--------|------|-----------|---------|--------|------------------------|
| API-PORTAL-019 | GET | `/wallet/adaccounts/balances` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Số dư theo TKQC, per-currency không quy đổi (BR-009); không có fx_snapshot; freshness 15 phút–24h |
| API-PORTAL-020 | GET | `/wallet/spend-daily` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Chi tiêu daily theo TK/campaign; disclaimer hồi tố timezone platform |
| API-PORTAL-021 | GET | `/wallet/transactions` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Whitelist: type, amount, currency, recon_status_display, recon_ref, ts; DISPUTED → "Đang đối soát"; ADJUSTED → "Điều chỉnh đối soát"; không có giá vốn/chiết khấu |
| API-PORTAL-022 | GET | `/wallet/deposits` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Lịch nạp đã thực hiện + kế hoạch cam kết — realtime |
| API-PORTAL-023 | GET | `/wallet/alerts` | BOTH | FEAT-PORTAL-WALLET-001 | REQ-OPS-003, REQ-FIN-017 | Cảnh báo chậm nạp/sắp PAUSE theo mốc cấu hình 15/30 ngày [KXN-22]; trước khi chốt → thông báo trung tính |

#### 6.4 Campaign / milestone (GET only + confirm nghiệm thu) — FEAT-PORTAL-CAMP-001

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú |
|--------|--------|------|-----------|---------|--------|---------|
| API-PORTAL-024 | GET | `/campaigns` | BOTH | FEAT-PORTAL-CAMP-001 | REQ-OPS-006 | List campaign + trạng thái + freshness realtime [NEEDS_REVIEW: bộ trường hiển thị khách — Phụ lục A #19] |
| API-PORTAL-025 | GET | `/campaigns/:campaignId` | BOTH | FEAT-PORTAL-CAMP-001 | REQ-OPS-006 | Chi tiết + milestones + khung nghiệm thu còn lại (3 ngày làm việc, nhắc ngày 2, escalate ngày 4) |
| API-PORTAL-026 | POST | `/campaigns/:campaignId/milestones/:milestoneId/acceptance` | BOTH | FEAT-PORTAL-CAMP-001 | REQ-OPS-006 | Ghi nhận quyết định khách `accepted`/`disputed` trong khung 3 ngày — không áp "im lặng = đồng ý"; disputed → gợi ý tạo ticket kèm ref; state machine nghiệm thu thực thi ở CAMP (SYS-BCERP-WEB), portal chỉ tiếp nhận; ngoài khung → 409 MILESTONE_WINDOW_CLOSED |

#### 6.5 Ticket (điểm ghi business duy nhất) — FEAT-PORTAL-CSKH-001

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú |
|--------|--------|------|-----------|---------|--------|---------|
| API-PORTAL-027 | GET | `/tickets` | BOTH | FEAT-PORTAL-CSKH-001 | REQ-OPS-009 | Ticket của tenant + trạng thái SLA tier×priority |
| API-PORTAL-028 | GET | `/tickets/:ticketId` | BOTH | FEAT-PORTAL-CSKH-001 | REQ-OPS-009 | Detail + timeline; whitelist — ghi chú nội bộ không vào payload |
| API-PORTAL-029 | POST | `/tickets` | BOTH | FEAT-PORTAL-CSKH-001 | REQ-OPS-009 | Tạo vào queue hợp nhất: `source=PORTAL`, context refs (transaction_id/campaign_id/invoice_id), category; dedupe tầng ERP; khiếu nại nghiêm trọng (Tier D/E, mất tiền, sai sót đối soát, đạo đức) gắn flag escalate BOD 24h kèm hồ sơ (BR-009) |
| API-PORTAL-030 | POST | `/tickets/:ticketId/comments` | BOTH | FEAT-PORTAL-CSKH-001 | REQ-OPS-009 | Comment khách; không đổi state ticket — state machine thuộc CSKH (SYS-BCERP-WEB) |

#### 6.6 Invoice (GET only) — FEAT-PORTAL-CPORT-001

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú |
|--------|--------|------|-----------|---------|--------|---------|
| API-PORTAL-031 | GET | `/invoices` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | List invoice của tenant từ ARAP [NEEDS_REVIEW: bộ trường invoice chia sẻ + quy trình duyệt view — Phụ lục A #19; đề xuất áp mô hình FIN_L1 duyệt view ví] |
| API-PORTAL-032 | GET | `/invoices/:invoiceId` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Chi tiết theo whitelist đã duyệt |
| API-PORTAL-033 | GET | `/invoices/:invoiceId/file` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Tải file qua watermark service — log portal_download_log (BR-011) |

#### 6.7 Export, incident, meta

| API-ID | Method | Path | Permission | FEAT-ID | REQ-ID | Ghi chú |
|--------|--------|------|-----------|---------|--------|---------|
| API-PORTAL-034 | POST | `/exports` | BOTH [OTP] | FEAT-PORTAL-CPORT-001 | REQ-FIN-017, REQ-OPS-010 | Scope: wallet_balances/transactions/deposits/invoices; watermark server-side bắt buộc — fail → 503 WATERMARK_UNAVAILABLE, chặn xuất (BR-011) |
| API-PORTAL-035 | GET | `/exports/:exportId` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Trạng thái job + link tải (expires 24h) |
| API-PORTAL-036 | GET | `/meta/freshness` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Tổng hợp freshness các view_group — nguồn cho trang trạng thái khi nguồn trễ/degraded (DI-007) |
| API-PORTAL-037 | POST | `/incidents` | BOTH | FEAT-PORTAL-CPORT-001 | REQ-FIN-017 | Điểm phát hiện sự cố phía khách (BR-FIN-604) → đẩy incident intake CORE trong 4h đầu, timer 72h theo NĐ 13/2023 + GDPR/DPA |

### 7. Internal API (Service-to-Service)

Prefix `/internal/` — không expose ra DMZ edge; auth service token (`X-Internal-Token`), timeout 3s, retry 3 lần exponential backoff.

| API-ID | Method | Path | Caller → Receiver | Purpose |
|--------|--------|------|-------------------|---------|
| API-PORTAL-038 | POST | `/internal/portal/adoption-events` | COMP-PORTAL-003/004/005 → COMP-PORTAL-006 | Buffer sự kiện adoption (invite/activate/login/create_user/ticket — BR-010), idempotent natural key `(user_id, event_type, ts)`; forward về CORE (event `portal.adoption.*` cho gate Day 1/7/14/30) — portal không giữ số adoption cục bộ |
| API-PORTAL-039 | POST | `/internal/portal/watermark/render` | COMP-PORTAL-002 → COMP-PORTAL-005 | Render watermark (tên user + thời điểm) server-side cho file xuất; fail → chặn xuất |

Lưu ý biên giới outbound (thuộc integration-map, không phải endpoint của lane này): BFF pull read-view `GET /core/portal-views/*` (CORE, RLS + tenant filter + mask); tạo ticket đẩy qua `POST /erp/tickets` (SYS-BCERP-WEB, điểm ghi duy nhất).

### 8. Rate Limiting

| Endpoint group | Limit | Window | Ghi chú |
|----------------|-------|--------|---------|
| `/auth/login`, `/auth/2fa/*`, password reset | 10 req | 1 phút/user | Vượt → 429; sai liên tục 5 lần → LOCKED (BR-005) |
| `/auth/otp/*` | 5 req | 15 phút/user | Chống spam OTP |
| General API (JWT) | 200 req | 1 phút/user | — |
| `/exports` | 5 req | 1 giờ/user | Chống download hàng loạt (anomaly — COMP-PORTAL-005) |
| Read-model ví | 60 req | 1 phút/user | Bảo vệ CORE khỏi polling quá mức (1000+ khách, 2600+ TKQC) |

Hành vi anomaly (quét dữ liệu, thử chéo tenant, download hàng loạt): rate limit → alert; lặp lại → khóa phiên + escalate SYS_ADMIN/FIN_L2 — ghi `portal_anomaly_event` (TBL-PORTAL-009).

## Hệ thống: SYS-MOBILE-INTERNAL — Mobile BCERP Internal

## API Contract — SYS-MOBILE-INTERNAL (Mobile BFF)

> READS: `phase2-features/mobile-internal/**/*.md` (30 FEAT touchpoints), `P3-01-architecture.md`, `business-context.md` v4.1, `lanes/mobile-internal/arch-draft.md`
> OUTPUT: API conventions, response formats, endpoint registry của Mobile BFF (COMP-MBI-003) + push consumer (COMP-MBI-004)
> USED BY: `integration-map.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
> DATE: 2026-09-13 | VERSION: v1

> **Biên scope (thin client):** File này CHỈ định nghĩa surface của Mobile BFF (`/api/v1/mbi/*`, port 8084). Mobile BFF là proxy mỏng + shaping view-model — **KHÔNG thiết kế lại business endpoints** của SYS-CORE-BACKEND / SYS-BCERP-WEB; mọi state-transition nghiệp vụ được **ỦY QUYỀN (REFERENCE)** về endpoint backend. Backend tự thực thi lại toàn bộ quy tắc (ngưỡng 5/50/200 triệu, SoD 4 vai, dual approval, delegate, escalation, balance check) bất kể request đến từ mobile hay web — mobile không tự tính, không bypass. Offline queue **CẤM** cho lệnh tiền và phê duyệt tài chính.

---

### 1. Global Conventions

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

### 2. Standard Response Envelopes

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

### 3. HTTP Status Codes

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

### 4. Error Codes Registry (bổ sung của MBI — ngoài registry chung template)

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

### 5. Authentication (proxy — REFERENCE, không thiết kế lại)

Mobile là client của SSO/MFA tập trung (REQ-BOD-011). BFF chỉ proxy sang core IdP và bổ sung ràng buộc device binding.

| API-ID | Method | Path | Hành vi | REFERENCE |
|--------|--------|------|---------|-----------|
| API-MBI-001 | POST | `/api/v1/mbi/auth/token` | Proxy đăng nhập → core IdP; thành công thì kiểm tra device binding, sai → `DEVICE_NOT_BOUND` | `POST /core/auth/token` (API-CORE-0xx) |
| API-MBI-002 | POST | `/api/v1/mbi/auth/mfa/step-up` | Proxy MFA step-up (TOTP/OTP) → trả step-up token TTL ngắn dùng cho endpoint MFA bắt buộc | `POST /core/auth/mfa/step-up` (API-CORE-0xx) |
| API-MBI-003 | POST | `/api/v1/mbi/auth/logout` | Revoke session + revoke push token + bảo client purge local cache (remote wipe) | — |

> [NEEDS_REVIEW] Ánh xạ ID `API-CORE-0xx` chính xác chờ spec-api lane core-backend (chạy song song); đồng bộ ở `integration-map.md` Phase 3. Mức step-up cho lệnh tài chính trên mobile: đề xuất OTP bắt buộc (biometric chỉ unlock local) — chờ xác nhận REQ-BOD-011 (Phụ lục A P3-01 #22).

---

### 6. Endpoints By System

> FEAT-ID traceability bắt buộc. FEAT-ID thuộc registry SYS-MOBILE-INTERNAL (30 touchpoints); action endpoint ủy quyền về canonical FEAT phía ERP.

#### 6.1 Device & Push (COMP-MBI-001, COMP-MBI-020 — module nền tảng MBI)

| API-ID | Method | Path | Permission | Offline | Mô tả | FEAT-ID |
|--------|--------|------|-----------|---------|-------|---------|
| API-MBI-004 | POST | `/api/v1/mbi/devices` | JWT (mọi vai nội bộ) | forbidden | Đăng ký device: device_id, platform, os/app version, push_token, provider (fcm/apns) → binding 1 user–1 thiết bị | FEAT-MBI-RBAC-002 |
| API-MBI-005 | PUT | `/api/v1/mbi/devices/:deviceId` | JWT + device owner | forbidden | Heartbeat last_seen, cập nhật push_token/app_version | FEAT-MBI-RBAC-002 |
| API-MBI-006 | DELETE | `/api/v1/mbi/devices/:deviceId` | JWT + device owner | forbidden | Revoke binding + vô hiệu push token (mất máy/thiết bị lạ) | FEAT-MBI-RBAC-002 |
| API-MBI-007 | GET | `/api/v1/mbi/devices` | JWT | forbidden | Danh sách thiết bị đã binding của user (state hiển thị cho compensating control) | FEAT-MBI-RBAC-001 |
| API-MBI-008 | GET | `/api/v1/mbi/push-preferences` | JWT | forbidden | Xem preference theo category (approval, sla_warning, sla_breach, wallet_alert, shop_alert, alert_center, ticket, campaign) | FEAT-MBI-SLANOT-001 |
| API-MBI-009 | PUT | `/api/v1/mbi/push-preferences` | JWT | forbidden | Bật/tắt theo category + quiet hours; cấm tắt kênh escalation SLA đỏ (chỉ backend quyết) | FEAT-MBI-SLANOT-001 |
| API-MBI-010 | GET | `/api/v1/mbi/app-config` | Public (payload ký số) | allowed (client cache) | Bootstrap: minimum version, force-update flag, cert pinning pinset version, role-aware surface map | FEAT-MBI-RBAC-002 |

#### 6.2 Approval Inbox (COMP-MBI-005, COMP-MBI-006)

| API-ID | Method | Path | Permission | Offline | MFA | Mô tả | FEAT-ID |
|--------|--------|------|-----------|---------|-----|-------|---------|
| API-MBI-011 | GET | `/api/v1/mbi/approvals` | Theo vai: BOD_CEO, BOD_CFO_CTO, FIN_L1/L2, SALES_L2/L3, GM, OPS_AM | forbidden | — | Inbox pending theo vai — BFF aggregate từ approval engine backend, filter `type`, `priority`, pagination | FEAT-MBI-ARAP-001, FEAT-MBI-ARAP-002 |
| API-MBI-012 | GET | `/api/v1/mbi/approvals/:approvalId` | Như trên + assignee | forbidden | — | Context tối thiểu bắt buộc: số tiền, ngưỡng áp dụng, người khởi tạo, chứng từ đính kèm, bước duyệt hiện tại (SoD position) | FEAT-MBI-ARAP-002, FEAT-MBI-WALLET-003 |
| API-MBI-013 | POST | `/api/v1/mbi/approvals/:approvalId/decision` | Như trên | **forbidden** | **bắt buộc** | Body `{ decision: approve|reject, step_up_token, note? }` + Idempotency-Key → ủy quyền transition backend (bảng §6.5); backend tự kiểm ngưỡng/SoD/dual approval | FEAT-MBI-ARAP-001, FEAT-MBI-ARAP-002, FEAT-MBI-WALLET-004 |

#### 6.3 Read Surfaces (COMP-MBI-006/007/011/012/017/018/019)

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

#### 6.4 ESS — offline-capable (COMP-MBI-015, COMP-MBI-016)

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

#### 6.5 Action Proxy — state-transition ủy quyền (các surface quyết định còn lại)

Một endpoint duy nhất giữ BFF mỏng: BFF tra mapping `objectType` → backend transition endpoint và forward nguyên payload (kèm step-up token khi cần). BFF không hiểu và không cache business rule.

| API-ID | Method | Path | Permission | Offline | MFA | FEAT-ID |
|--------|--------|------|-----------|---------|-----|---------|
| API-MBI-027 | POST | `/api/v1/mbi/actions/:objectType/:objectId/transitions` | Theo objectType (bảng dưới) | **forbidden** | bắt buộc với objectType tiền/hợp đồng | FEAT-MBI-CRM-001, FEAT-MBI-QDD-001, FEAT-MBI-QDD-002, FEAT-MBI-HONB-001, FEAT-MBI-HONB-002, FEAT-MBI-PROPLN-001, FEAT-MBI-CAMP-001, FEAT-MBI-CAMP-002, FEAT-MBI-CSKH-001 |

Mapping `objectType` → backend (REFERENCE — **canonical ERP đã đồng bộ API-ID**, thay bảng path khung lane-draft):

| objectType | Backend endpoint (canonical) | Canonical FEAT (ERP) |
|------------|------------------------------|----------------------|
| `crm_gate` | API-ERP-008 `POST /api/v1/erp/leads/{id}/gate-decision` | FEAT-ERP-CRM-* (Gate 1/2) |
| `qdd_discount` | API-ERP-013 `POST /api/v1/erp/quotations/{id}/discount-approval` | FEAT-ERP-QDD-* (duyệt GM vượt định mức) |
| `contract_esign` | API-ERP-014 `POST /api/v1/erp/contracts/{id}/esign-complete` | FEAT-ERP-QDD-* (e-sign HĐ/LOI/NDA) |
| `handoff_ack` | API-ERP-018 `POST /api/v1/erp/handoffs/{id}/ops-ack` | FEAT-ERP-HONB-* (ops_ack) |
| `proposal_gate` | API-ERP-048 `POST /api/v1/erp/proposals/{id}/stage-transitions` | FEAT-ERP-PROPLN-* (stage-gate V6.0) |
| `deliverable` | API-ERP-051 `POST /api/v1/erp/deliverables/{id}/transitions` (nghiệm thu khách: API-ERP-052 acceptance) | FEAT-ERP-CAMP-* (tick/nghiệm thu) |
| `ticket` | API-ERP-060 `POST /api/v1/erp/tickets/{id}/transitions` | FEAT-ERP-CSKH-* (reply/resolve) |
| `payment_order` | API-ERP-034 `POST /api/v1/erp/payment-orders/{id}/approve` (giải ngân: API-ERP-035 disburse) | FEAT-ERP-ARAP-002 (duyệt chi — dùng chung với API-MBI-013) |
| `wallet_adjustment` | API-ERP-023 `POST /api/v1/erp/wallet-transactions/{id}/approvals` | FEAT-ERP-WALLET-* (dual approval) |
| `wallet_hard_stop` | API-ERP-026 `POST /api/v1/erp/wallets/{customerId}/hard-stop/confirm` | FEAT-ERP-WALLET-* (hard stop FIN_L1) |

---

### 7. Internal API (Service-to-Service)

| API-ID | Method | Path | Caller | Purpose | FEAT-ID |
|--------|--------|------|--------|---------|---------|
| API-MBI-034 | POST | `/internal/mbi/push/dispatch` | COMP-ERP-006 (sla.warning/sla.breach), COMP-CORE-011 (alert.raised), COMP-GW-013 (shop.alert) | Nhận sự kiện notification (user target, category, deep_link surface) → Push Gateway đẩy FCM/APNs; consumer idempotent theo event_id; mất push không làm vỡ SLA | FEAT-MBI-SLANOT-001 |

Auth: `X-Internal-Token` service-to-service; timeout 3s; retry 3 lần backoff; payload phải mang `event_id` để dedup.

---

### 8. Rate Limiting

| Endpoint group | Limit | Window |
|----------------|-------|--------|
| Auth (`/mbi/auth/*`) | 10 req | 1 phút |
| `POST /ess/sync` | 30 req | 1 phút |
| `POST /app-config` | 60 req | 1 phút |
| General `/api/v1/mbi/*` | 200 req | 1 phút / device |
| Decision (`approvals/decision`, `actions/*/transitions`) | 60 req | 1 phút / user |
| Internal `/internal/mbi/*` | 1000 req | 1 phút |

## Hệ thống: SYS-MOBILE-PORTAL — Mobile BC Portal

## API Contract — SYS-MOBILE-PORTAL (Mobile App BC Portal)

> READS: `phase2-features/mobile-portal/**/*.md` (FEAT-MPO-WALLET-001, FEAT-MPO-CAMP-001, FEAT-MPO-SLANOT-001, FEAT-MPO-CSKH-001, FEAT-MPO-CPORT-001), `P3-01-architecture.md`, `lanes/mobile-portal/arch-draft.md`
> OUTPUT: Endpoint registry của Portal Mobile BFF (COMP-MPO-002, port 8085, prefix `/api/v1/mpo/*`)
> USED BY: `technical-specs/integration-map.md`, `phase4-ux/mobile-portal/*`, `phase5-implementation/tasks/mobile-portal/*`
> DATE: 2026-09-13 | VERSION: v1

> **Vị trí trong kiến trúc:** Mobile portal là thin client client-facing (CLIENT_ADMIN/CLIENT_USER). BFF không owns dữ liệu nghiệp vụ: READ path ủy quyền xuống read-model API dùng chung SYS-PORTAL-WEB (view đã lọc tenant, RLS + filter API 2 lớp — REQ-FIN-017), WRITE path chỉ 4 nhóm phi tài chính (ticket, confirm nghiệm thu, quản lý portal user, cấu hình push) và luôn forward xuống PORTAL-WEB/CORE xử lý. **Không tồn tại endpoint ghi dữ liệu ví** — request ghi tài chính bị chặn 403 + log bảo mật (BR-008 wallet).

---

### 1. Global Conventions

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

### 2. Standard Response Envelopes

Theo template chung (`{ success, data, meta }` / `{ success, error, code, details }`). Riêng list notification/ticket kèm `meta.unread_count`.

### 3. HTTP Status Codes & 4. Error Codes Registry

Theo template chung. Bổ sung MPO-specific:

| Code | HTTP | Ý nghĩa |
|------|------|---------|
| `FINANCIAL_WRITE_FORBIDDEN` | 403 | Request ghi dữ liệu tài chính từ mobile — chặn tầng gateway + log bảo mật (P0) |
| `QUOTA_EXCEEDED` | 409 | Vượt hạn mức user theo hợp đồng — "liên hệ AM" (BR-003, SC-002) |
| `INVITE_EXPIRED` | 409 | Token invite hết hạn hoặc đã dùng — gửi lại invite mới |
| `OTP_REQUIRED` / `OTP_INVALID` | 401 / 400 | Thiếu / sai hoặc hết hạn OTP cho hành động nhạy cảm (BR-008) |
| `ACCOUNT_LOCKED` | 423 | Sai mật khẩu/OTP 5 lần — khóa mọi thiết bị |
| `DPA_NOT_SIGNED` | 403 | Tenant chưa ký DPA — chặn kích hoạt + xem ví (BR-FIN-605) |

### 5. Authentication Endpoints

Ủ quyền: phiên SSO/2FA thực thi tại CORE-BACKEND (COMP-CORE-001) + provisioning portal user của PORTAL-WEB (`API-PORTAL-001`, `API-PORTAL-002` — [NEEDS_REVIEW: số thứ tự ID do lane PORTAL-WEB chốt]).

| API-ID | Method | Path | Mô tả | FEAT-ID |
|--------|--------|------|-------|---------|
| API-MPO-001 | POST | `/api/v1/mpo/auth/activate` | Kích hoạt invite (token một-lần) + xác minh OTP + bắt buộc bật 2FA; chặn khi tenant chưa DPA | FEAT-MPO-CPORT-001 |
| API-MPO-002 | POST | `/api/v1/mpo/auth/login` | Đăng nhập portal user (email + password + 2FA); sai 5 lần → `ACCOUNT_LOCKED`; tài khoản nội bộ bị từ chối (SC-010) | FEAT-MPO-CPORT-001 |
| API-MPO-003 | POST | `/api/v1/mpo/auth/otp` | Gửi OTP step-up cho hành động nhạy cảm (quản lý user, đổi mật khẩu, xuất dữ liệu) | FEAT-MPO-CPORT-001 |
| API-MPO-004 | POST | `/api/v1/mpo/auth/otp/verify` | Xác minh OTP step-up | FEAT-MPO-CPORT-001 |
| API-MPO-005 | POST | `/api/v1/mpo/auth/password-reset` | Quên mật khẩu qua OTP email/POC; sau đó bắt buộc bật lại 2FA | FEAT-MPO-CPORT-001 |
| API-MPO-006 | POST | `/api/v1/mpo/auth/logout` | Thu hồi phiên hiện tại + push token thiết bị gọi | FEAT-MPO-CPORT-001 |

### 6. Endpoints By System

#### SYS-MOBILE-PORTAL — Portal Mobile BFF (COMP-MPO-002)

##### 6.1. Hồ sơ & Portal Account (MOD-CLIENT-PORTAL)

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

##### 6.2. Thiết bị & Push (MOD-SLA-NOTIF)

| API-ID | Method | Path | Auth | Permission | Ghi chú | FEAT-ID |
|--------|--------|------|------|-----------|---------|---------|
| API-MPO-014 | POST | `/api/v1/mpo/devices` | JWT | mọi portal user | Đăng ký push token, binding user+tenant+platform | FEAT-MPO-SLANOT-001 |
| API-MPO-015 | PUT | `/api/v1/mpo/devices/:id` | JWT | chủ thiết bị | Opt-in + mức cảnh báo nhận + giờ im lặng (chỉ áp Low/Medium) | FEAT-MPO-SLANOT-001 |
| API-MPO-016 | DELETE | `/api/v1/mpo/devices/:id` | JWT | chủ thiết bị / CLIENT_ADMIN | Revoke token (soft), không ảnh hưởng thiết bị khác | FEAT-MPO-SLANOT-001 |
| API-MPO-017 | GET | `/api/v1/mpo/notifications` | JWT | mọi portal user | Inbox in-app; tách theo tenant đang chọn | FEAT-MPO-SLANOT-001 |
| API-MPO-018 | POST | `/api/v1/mpo/notifications/:id/read` | JWT | mọi portal user | Ghi read_at (AlertNotification) | FEAT-MPO-SLANOT-001 |

REQ-IDs: REQ-OPS-008, REQ-OPS-010. Token thu hồi ngay khi user DISABLED/LOCKED/logout (worker xử lý — không endpoint khách).

##### 6.3. Ví read-only (MOD-WALLET-RECON) — không có endpoint ghi

| API-ID | Method | Path | Auth | Permission | Ủy quyền (read-model dùng chung) | FEAT-ID |
|--------|--------|------|------|-----------|--------------------------------|---------|
| API-MPO-019 | GET | `/api/v1/mpo/wallet/summary` | JWT | mọi portal user | `API-PORTAL-0xx` (PortalWalletView) | FEAT-MPO-WALLET-001 |
| API-MPO-020 | GET | `/api/v1/mpo/wallet/spend` | JWT | mọi portal user | `API-PORTAL-0xx` (daily spend, runway, mức XVĐ per TKQC) | FEAT-MPO-WALLET-001 |
| API-MPO-021 | GET | `/api/v1/mpo/wallet/transactions` | JWT | mọi portal user | `API-PORTAL-0xx` (PortalAdjustmentHistoryView, mask) | FEAT-MPO-WALLET-001 |
| API-MPO-022 | GET | `/api/v1/mpo/wallet/statement-link` | JWT | CLIENT_ADMIN | Trả URL deep-link Portal Web tải sổ phụ PDF watermark + `portal_download_log` | FEAT-MPO-WALLET-001 |

REQ-IDs: REQ-OPS-003 (+ REQ-FIN-002, REQ-FIN-017). USD/VND tách sổ — không có trường tổng quy đổi; lệnh `PENDING`/`STEP1_APPROVED` trả trong khối `pendingApprovals` riêng, không cộng vào `availableBalance`. Mask giá vốn → "Điều chỉnh đối soát". Disclaimer độ trễ 15 phút–24h + nhãn `api`/`manual` bắt buộc kèm mọi con số.

##### 6.4. Campaign & Confirm nghiệm thu (MOD-CAMPAIGN-DELIVERABLE)

| API-ID | Method | Path | Auth | Permission | Ghi chú | FEAT-ID |
|--------|--------|------|------|-----------|---------|---------|
| API-MPO-023 | GET | `/api/v1/mpo/campaigns` | JWT | mọi portal user | Chỉ campaign có bản ghi share + `wbs_node_ref` hợp lệ | FEAT-MPO-CAMP-001 |
| API-MPO-024 | GET | `/api/v1/mpo/campaigns/:id` | JWT | mọi portal user | Milestone progress; không lộ SLA duyệt nội bộ | FEAT-MPO-CAMP-001 |
| API-MPO-025 | POST | `/api/v1/mpo/campaigns/:id/milestones/:mid/confirm` | JWT + step-up 2FA/biometric | **CLIENT_ADMIN** | Forward PORTAL/CORE; milestone phải đang chờ confirm | FEAT-MPO-CAMP-001 |
| API-MPO-026 | POST | `/api/v1/mpo/campaigns/:id/milestones/:mid/revision` | JWT | CLIENT_ADMIN/CLIENT_USER | Yêu cầu chỉnh sửa + comment bắt buộc | FEAT-MPO-CAMP-001 |

REQ-ID: REQ-OPS-006. Chỉ 2 hành động ghi này tồn tại trên campaign — hết 3 ngày làm việc app chỉ nhắc/hiện escalate, không tự "đạt" (không "im lặng = đồng ý").

##### 6.5. Ticket & CSAT (MOD-TICKET-CSKH)

| API-ID | Method | Path | Auth | Permission | Ghi chú | FEAT-ID |
|--------|--------|------|------|-----------|---------|---------|
| API-MPO-027 | GET | `/api/v1/mpo/tickets` | JWT | mọi portal user | SLA target read-only, song song múi giờ | FEAT-MPO-CSKH-001 |
| API-MPO-028 | GET | `/api/v1/mpo/tickets/:id` | JWT | mọi portal user | Không lộ chuỗi escalation nội bộ | FEAT-MPO-CSKH-001 |
| API-MPO-029 | POST | `/api/v1/mpo/tickets` | JWT | mọi portal user | `source=portal(mobile)`; CORE dedupe → trả ticket hiện có nếu trùng | FEAT-MPO-CSKH-001 |
| API-MPO-030 | POST | `/api/v1/mpo/tickets/:id/comments` | JWT | mọi portal user | Phản hồi chính thức, resume clock do CORE quyết | FEAT-MPO-CSKH-001 |
| API-MPO-031 | POST | `/api/v1/mpo/tickets/:id/reopen` | JWT | mọi portal user | Chỉ trong 7 ngày kể từ Closed | FEAT-MPO-CSKH-001 |
| API-MPO-032 | POST | `/api/v1/mpo/tickets/:id/csat` | JWT | mọi portal user | 1–5 + 1 câu mở; một CSAT/ticket; nhắc ≤1 lần/48h | FEAT-MPO-CSKH-001 |

REQ-ID: REQ-OPS-009. Mọi ghi forward queue hợp nhất của CORE (`POST /erp/tickets` — điểm ghi duy nhất, P3-01 §5); mobile không sở hữu state machine ticket.

##### 6.6. Cấu hình app

| API-ID | Method | Path | Auth | Ghi chú | FEAT-ID |
|--------|--------|------|------|---------|---------|
| API-MPO-033 | GET | `/api/v1/mpo/app-config` | Public (không chứa dữ liệu user) | Min-version gating (force update), deep-link base, bản text disclaimer | FEAT-MPO-CPORT-001 |

### 7. Internal API (Service-to-Service)

BFF (PEP phụ trợ) gọi nội bộ, không expose ra public:

| Method | Path | Caller | Purpose |
|--------|------|--------|---------|
| GET | `/api/v1/portal/*` (read-model) | mpo-bff | Toàn bộ read path — view đã lọc tenant dùng chung PORTAL-WEB |
| POST | `/api/v1/portal/*` (forward ghi phi tài chính) | mpo-bff | Ticket/confirm/user admin — CORE enforce quyền + state machine |
| POST | `/core/pdp/check` | mpo-bff | Xác minh quyền portal user trước khi forward (cache TTL 60s) |
| — | queue consumer | mpo-push-worker | Tiêu thụ event SLANOT/PORTAL (`sla.*`, `portal.*`, chuyển mức ví) → fan-out FCM/APNs |

Mobile app KHÔNG gọi trực tiếp SYS-INTEGRATION-GW hay SYS-CORE-BACKEND — mọi request qua BFF.

### 8. Rate Limiting

| Endpoint group | Limit | Window |
|---------------|-------|--------|
| `/mpo/auth/*` | 10 req | 1 phút |
| `/mpo/wallet/*`, `/mpo/campaigns/*`, `/mpo/tickets/*` (GET) | 200 req | 1 phút |
| POST ghi (ticket/comment/csat/confirm/invites) | 30 req | 1 phút |
| `/mpo/app-config` | 60 req | 1 phút |

---

#### [NEEDS_REVIEW] — tổng hợp

1. Số thứ tự chính xác `API-PORTAL-0xx` được ủy quyền — lane SYS-PORTAL-WEB song song chốt; BFF bind theo tên endpoint, mapping điền khi portal spec-api hợp nhất (Phụ lục A #23 — ownership Portal API Gateway dùng chung).
2. Công nghệ 2FA/OTP (TOTP/SMS/email) — quyết chung với CORE-BACKEND (Phụ lục A #9).
3. Invoice trên mobile: baseline §1 khách "nhận invoice" nhưng spec CPORT không liệt kê màn invoice — chờ xác nhận scope trước khi thêm endpoint.
4. Mức cảnh báo mở rộng ngoài Xanh/Vàng/Đỏ [KXN-20], PAUSE non-payment 15/30 ngày [KXN-22], kênh gửi CSAT [KXN-15] — chỉ ảnh hưởng payload hiển thị, không đổi shape API.

### 9. FEAT Traceability — cross-system variants (bổ sung Cross-Validation 2026-09-13)

> Phase 2 sinh FEAT-ID per-system (FEAT-CORE-* / FEAT-ERP-* / FEAT-GW-* / FEAT-MBI-* / FEAT-PORTAL-* / FEAT-MPO-*)
> với số thứ tự đồng bộ trong cùng module. Thiết kế Phase 3 **tập trung nghiệp vụ vào một touchpoint chính**
> (business services tại SYS-BCERP-WEB — COMP-ERP-001…007; identity/RBAC/datahub tại COMP-CORE-*; adapter tại GW;
> BFF read/action tại MBI/MPO/PORTAL), nên endpoint chỉ gắn nhãn FEAT của system sở hữu touchpoint.
> Bảng dưới map **70 FEAT variant chưa xuất hiện trực tiếp** trong hợp đồng này → touchpoint thi công thật
> (xác định bằng FEAT cùng số hiệu trong cùng module). Không endpoint nào bị bỏ sót capability — đây là chú giải traceability, không phải endpoint mới.

| FEAT variant | Cùng capability với | Touchpoint thi công | API IDs chính |
|--------------|---------------------|---------------------|----------------|
| `FEAT-CORE-ARAP-001` | `FEAT-ERP-ARAP-001`, `FEAT-MBI-ARAP-001` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-ARAP-PAYMENT — Công nợ & giải ngân (FEAT-ERP-ARAP-001…007) | API-ERP-029, API-ERP-030, API-ERP-031, API-ERP-032 (+6) |
| `FEAT-ERP-RBAC-001` | `FEAT-CORE-RBAC-001`, `FEAT-MBI-RBAC-001`, `FEAT-PORTAL-RBAC-001` | CORE §6.2 RBAC & Policy Engine — PDP (COMP-CORE-002) + MBI §6.1 Device & Push (COMP-MBI-001, COMP-MBI-020 — module nền tảng MBI) | API-CORE-014, API-CORE-015, API-CORE-016, API-CORE-017 (+6) |
| `FEAT-ERP-DHUB-001` | `FEAT-CORE-DHUB-001`, `FEAT-MBI-DHUB-001` | CORE §6.6 BI Serving (COMP-CORE-010) + CORE §6.8 Ingest Admin (COMP-CORE-007, 008) | API-CORE-008, API-CORE-014, API-CORE-028, API-CORE-036 (+6) |
| `FEAT-ERP-DHUB-002` | `FEAT-CORE-DHUB-002`, `FEAT-MBI-DHUB-002` | CORE §6.6 BI Serving (COMP-CORE-010) + MBI §6.3 Read Surfaces (COMP-MBI-006/007/011/012/017/018/019) | API-CORE-036, API-CORE-037, API-CORE-038, API-CORE-039 (+6) |
| `FEAT-ERP-RBAC-002` | `FEAT-CORE-RBAC-002`, `FEAT-MBI-RBAC-002` | CORE §6.4 Audit Log & WORM (COMP-CORE-004, 005) + MBI §6.1 Device & Push (COMP-MBI-001, COMP-MBI-020 — module nền tảng MBI) | API-CORE-028, API-CORE-029, API-CORE-030, API-CORE-031 (+6) |
| `FEAT-ERP-DHUB-003` | `FEAT-CORE-DHUB-003`, `FEAT-MBI-DHUB-003` | CORE §6.7 Alert Center (COMP-CORE-011) + CORE §6.8 Ingest Admin (COMP-CORE-007, 008) | API-CORE-008, API-CORE-014, API-CORE-028, API-CORE-041 (+6) |
| `FEAT-GW-RBAC-001` | `FEAT-CORE-RBAC-001`, `FEAT-MBI-RBAC-001`, `FEAT-PORTAL-RBAC-001` | CORE §6.2 RBAC & Policy Engine — PDP (COMP-CORE-002) + MBI §6.1 Device & Push (COMP-MBI-001, COMP-MBI-020 — module nền tảng MBI) | API-CORE-014, API-CORE-015, API-CORE-016, API-CORE-017 (+6) |
| `FEAT-ERP-RBAC-003` | `FEAT-CORE-RBAC-003` | CORE §6.2 RBAC & Policy Engine — PDP (COMP-CORE-002) + CORE §6.3 Quarterly Access Review (COMP-CORE-003) | API-CORE-014, API-CORE-015, API-CORE-016, API-CORE-017 (+6) |
| `FEAT-CORE-STGW-001` | `FEAT-GW-STGW-001` | CORE §6.8 Ingest Admin (COMP-CORE-007, 008) + GW §Connection Profile & Lifecycle (FEAT-GW-STGW-001) | API-CORE-008, API-CORE-014, API-CORE-028, API-CORE-046 (+6) |
| `FEAT-ERP-STGW-001` | `FEAT-GW-STGW-001` | CORE §6.8 Ingest Admin (COMP-CORE-007, 008) + GW §Connection Profile & Lifecycle (FEAT-GW-STGW-001) | API-CORE-008, API-CORE-014, API-CORE-028, API-CORE-046 (+6) |
| `FEAT-ERP-RBAC-004` | `FEAT-CORE-RBAC-004` | CORE §6.2 RBAC & Policy Engine — PDP (COMP-CORE-002) | API-CORE-014, API-CORE-015, API-CORE-016, API-CORE-017 (+4) |
| `FEAT-CORE-ARAP-002` | `FEAT-ERP-ARAP-002`, `FEAT-MBI-ARAP-002` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-ARAP-PAYMENT — Công nợ & giải ngân (FEAT-ERP-ARAP-001…007) | API-ERP-029, API-ERP-030, API-ERP-031, API-ERP-032 (+6) |
| `FEAT-ERP-RBAC-005` | `FEAT-CORE-RBAC-005` | WEB §6.7. COMP-ERP-007 — Batch & Recon Scheduler (jobs cross-module) + CORE §API-CORE-001 — POST /api/v1/core/auth/token | API-CORE-001, API-CORE-009, API-CORE-010, API-CORE-011 (+6) |
| `FEAT-CORE-HRCORE-001` | `FEAT-ERP-HRCORE-001` | WEB §6.5. COMP-ERP-005 — People & Performance | API-ERP-062, API-ERP-063, API-ERP-064, API-ERP-065 (+4) |
| `FEAT-CORE-HRCORE-002` | `FEAT-ERP-HRCORE-002` | WEB §6.5. COMP-ERP-005 — People & Performance | API-ERP-062, API-ERP-063, API-ERP-064, API-ERP-065 (+4) |
| `FEAT-CORE-HRCORE-003` | `FEAT-ERP-HRCORE-003` | WEB §6.5. COMP-ERP-005 — People & Performance | API-ERP-062, API-ERP-063, API-ERP-064, API-ERP-065 (+4) |
| `FEAT-CORE-HRCORE-004` | `FEAT-ERP-HRCORE-004` | WEB §6.5. COMP-ERP-005 — People & Performance | API-ERP-062, API-ERP-063, API-ERP-064, API-ERP-065 (+4) |
| `FEAT-CORE-HRCORE-005` | `FEAT-ERP-HRCORE-005` | WEB §6.5. COMP-ERP-005 — People & Performance | API-ERP-062, API-ERP-063, API-ERP-064, API-ERP-065 (+4) |
| `FEAT-CORE-HRCORE-006` | `FEAT-ERP-HRCORE-006` | WEB §6.5. COMP-ERP-005 — People & Performance | API-ERP-062, API-ERP-063, API-ERP-064, API-ERP-065 (+4) |
| `FEAT-CORE-KPI-001` | `FEAT-ERP-KPI-001` | WEB §6.5. COMP-ERP-005 — People & Performance | API-ERP-062, API-ERP-063, API-ERP-064, API-ERP-065 (+4) |
| `FEAT-CORE-KPI-002` | `FEAT-ERP-KPI-002` | WEB §6.5. COMP-ERP-005 — People & Performance | API-ERP-062, API-ERP-063, API-ERP-064, API-ERP-065 (+4) |
| `FEAT-CORE-CAPTS-001` | `FEAT-ERP-CAPTS-001`, `FEAT-MBI-CAPTS-001` | WEB §6.5. COMP-ERP-005 — People & Performance + MBI §6.4 ESS — offline-capable (COMP-MBI-015, COMP-MBI-016) | API-ERP-062, API-ERP-063, API-ERP-064, API-ERP-065 (+6) |
| `FEAT-ERP-RBAC-006` | `FEAT-CORE-RBAC-006` | CORE §6.5 PII Field Protection (COMP-CORE-006) | API-CORE-033, API-CORE-034, API-CORE-035 |
| `FEAT-CORE-WALLET-001` | `FEAT-ERP-WALLET-001`, `FEAT-MBI-WALLET-001`, `FEAT-PORTAL-WALLET-001`, `FEAT-MPO-WALLET-001` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-WALLET-RECON — Ví & đối soát (FEAT-ERP-WALLET-001…007) | API-ERP-020, API-ERP-021, API-ERP-022, API-ERP-023 (+6) |
| `FEAT-CORE-WALLET-002` | `FEAT-ERP-WALLET-002`, `FEAT-MBI-WALLET-002` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-WALLET-RECON — Ví & đối soát (FEAT-ERP-WALLET-001…007) | API-ERP-020, API-ERP-021, API-ERP-022, API-ERP-023 (+6) |
| `FEAT-CORE-WALLET-003` | `FEAT-ERP-WALLET-003`, `FEAT-MBI-WALLET-003` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-WALLET-RECON — Ví & đối soát (FEAT-ERP-WALLET-001…007) | API-ERP-020, API-ERP-021, API-ERP-022, API-ERP-023 (+6) |
| `FEAT-CORE-WALLET-004` | `FEAT-ERP-WALLET-004`, `FEAT-MBI-WALLET-004` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-WALLET-RECON — Ví & đối soát (FEAT-ERP-WALLET-001…007) | API-ERP-020, API-ERP-021, API-ERP-022, API-ERP-023 (+6) |
| `FEAT-GW-WALLET-001` | `FEAT-ERP-WALLET-001`, `FEAT-MBI-WALLET-001`, `FEAT-PORTAL-WALLET-001`, `FEAT-MPO-WALLET-001` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-WALLET-RECON — Ví & đối soát (FEAT-ERP-WALLET-001…007) | API-ERP-020, API-ERP-021, API-ERP-022, API-ERP-023 (+6) |
| `FEAT-CORE-STGW-002` | `FEAT-GW-STGW-002` | CORE §6.8 Ingest Admin (COMP-CORE-007, 008) + GW §Policy Config & Field Mapping (FEAT-GW-STGW-001/002) | API-CORE-008, API-CORE-014, API-CORE-028, API-CORE-046 (+6) |
| `FEAT-ERP-STGW-002` | `FEAT-GW-STGW-002` | CORE §6.8 Ingest Admin (COMP-CORE-007, 008) + GW §Policy Config & Field Mapping (FEAT-GW-STGW-001/002) | API-CORE-008, API-CORE-014, API-CORE-028, API-CORE-046 (+6) |
| `FEAT-CORE-WALLET-005` | `FEAT-ERP-WALLET-005`, `FEAT-MBI-WALLET-005` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-WALLET-RECON — Ví & đối soát (FEAT-ERP-WALLET-001…007) | API-ERP-020, API-ERP-021, API-ERP-022, API-ERP-023 (+6) |
| `FEAT-CORE-ARAP-003` | `FEAT-ERP-ARAP-003` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-ARAP-PAYMENT — Công nợ & giải ngân (FEAT-ERP-ARAP-001…007) | API-ERP-029, API-ERP-030, API-ERP-031, API-ERP-032 (+4) |
| `FEAT-CORE-ARAP-004` | `FEAT-ERP-ARAP-004` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-ARAP-PAYMENT — Công nợ & giải ngân (FEAT-ERP-ARAP-001…007) | API-ERP-029, API-ERP-030, API-ERP-031, API-ERP-032 (+4) |
| `FEAT-CORE-ADACC-001` | `FEAT-ERP-ADACC-001`, `FEAT-MBI-ADACC-001` | WEB §6.3. COMP-ERP-003 — Ad Account & Delivery + WEB §MOD-ADACCOUNT-CC — TKQC Registry (FEAT-ERP-ADACC-001…003) | API-ERP-027, API-ERP-043, API-ERP-044, API-ERP-045 (+6) |
| `FEAT-CORE-WALLET-006` | `FEAT-ERP-WALLET-006`, `FEAT-MBI-WALLET-006` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-WALLET-RECON — Ví & đối soát (FEAT-ERP-WALLET-001…007) | API-ERP-020, API-ERP-021, API-ERP-022, API-ERP-023 (+6) |
| `FEAT-CORE-ARAP-005` | `FEAT-ERP-ARAP-005` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-ARAP-PAYMENT — Công nợ & giải ngân (FEAT-ERP-ARAP-001…007) | API-ERP-029, API-ERP-030, API-ERP-031, API-ERP-032 (+4) |
| `FEAT-ERP-RBAC-007` | `FEAT-CORE-RBAC-007` | CORE §6.3 Quarterly Access Review (COMP-CORE-003) + CORE §6.4 Audit Log & WORM (COMP-CORE-004, 005) | API-CORE-024, API-CORE-025, API-CORE-026, API-CORE-027 (+5) |
| `FEAT-GW-ARAP-001` | `FEAT-ERP-ARAP-001`, `FEAT-MBI-ARAP-001` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-ARAP-PAYMENT — Công nợ & giải ngân (FEAT-ERP-ARAP-001…007) | API-ERP-029, API-ERP-030, API-ERP-031, API-ERP-032 (+6) |
| `FEAT-CORE-ARAP-006` | `FEAT-ERP-ARAP-006` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-ARAP-PAYMENT — Công nợ & giải ngân (FEAT-ERP-ARAP-001…007) | API-ERP-029, API-ERP-030, API-ERP-031, API-ERP-032 (+4) |
| `FEAT-CORE-ARAP-007` | `FEAT-ERP-ARAP-007` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-ARAP-PAYMENT — Công nợ & giải ngân (FEAT-ERP-ARAP-001…007) | API-ERP-029, API-ERP-030, API-ERP-031, API-ERP-032 (+4) |
| `FEAT-GW-ARAP-002` | `FEAT-ERP-ARAP-002`, `FEAT-MBI-ARAP-002` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-ARAP-PAYMENT — Công nợ & giải ngân (FEAT-ERP-ARAP-001…007) | API-ERP-029, API-ERP-030, API-ERP-031, API-ERP-032 (+6) |
| `FEAT-ERP-DHUB-004` | `FEAT-CORE-DHUB-004`, `FEAT-MBI-DHUB-004` | CORE §6.6 BI Serving (COMP-CORE-010) + MBI §6.3 Read Surfaces (COMP-MBI-006/007/011/012/017/018/019) | API-CORE-036, API-CORE-037, API-CORE-038, API-CORE-039 (+6) |
| `FEAT-ERP-DHUB-005` | `FEAT-CORE-DHUB-005`, `FEAT-MBI-DHUB-005` | CORE §6.6 BI Serving (COMP-CORE-010) + MBI §6.3 Read Surfaces (COMP-MBI-006/007/011/012/017/018/019) | API-CORE-036, API-CORE-037, API-CORE-038, API-CORE-039 (+6) |
| `FEAT-CORE-CPORT-001` | `FEAT-PORTAL-CPORT-001`, `FEAT-ERP-CPORT-001`, `FEAT-MBI-CPORT-001`, `FEAT-MPO-CPORT-001` | PORTAL §6.3 Read-model ví (GET only — read-only tuyệt đối, BR-001 CPORT-001) + PORTAL §6.6 Invoice (GET only) | API-ERP-054, API-ERP-055, API-ERP-056, API-MBI-001 (+6) |
| `FEAT-CORE-CRM-001` | `FEAT-ERP-CRM-001`, `FEAT-MBI-CRM-001` | WEB §6.1. COMP-ERP-001 — Sales & Pipeline + WEB §MOD-CRM-PIPELINE — Leads (FEAT-ERP-CRM-001…005) | API-ERP-001, API-ERP-002, API-ERP-003, API-ERP-004 (+6) |
| `FEAT-CORE-CRM-002` | `FEAT-ERP-CRM-002` | WEB §6.1. COMP-ERP-001 — Sales & Pipeline + WEB §MOD-CRM-PIPELINE — Leads (FEAT-ERP-CRM-001…005) | API-ERP-001, API-ERP-002, API-ERP-003, API-ERP-004 (+4) |
| `FEAT-CORE-CRM-003` | `FEAT-ERP-CRM-003` | WEB §6.1. COMP-ERP-001 — Sales & Pipeline + WEB §MOD-CRM-PIPELINE — Leads (FEAT-ERP-CRM-001…005) | API-ERP-001, API-ERP-002, API-ERP-003, API-ERP-004 (+4) |
| `FEAT-CORE-CRM-004` | `FEAT-ERP-CRM-004` | WEB §6.1. COMP-ERP-001 — Sales & Pipeline + WEB §MOD-CRM-PIPELINE — Leads (FEAT-ERP-CRM-001…005) | API-ERP-001, API-ERP-002, API-ERP-003, API-ERP-004 (+4) |
| `FEAT-CORE-CRM-005` | `FEAT-ERP-CRM-005` | WEB §6.1. COMP-ERP-001 — Sales & Pipeline + WEB §MOD-CRM-PIPELINE — Leads (FEAT-ERP-CRM-001…005) | API-ERP-001, API-ERP-002, API-ERP-003, API-ERP-004 (+4) |
| `FEAT-CORE-QDD-001` | `FEAT-ERP-QDD-001`, `FEAT-MBI-QDD-001` | WEB §6.1. COMP-ERP-001 — Sales & Pipeline + WEB §MOD-QUOTATION-DEALDESK — Quotation/Contract (FEAT-ERP-QDD-001/002) | API-ERP-010, API-ERP-011, API-ERP-012, API-ERP-013 (+6) |
| `FEAT-CORE-QDD-002` | `FEAT-ERP-QDD-002`, `FEAT-MBI-QDD-002` | WEB §6.1. COMP-ERP-001 — Sales & Pipeline + WEB §MOD-QUOTATION-DEALDESK — Quotation/Contract (FEAT-ERP-QDD-001/002) | API-ERP-010, API-ERP-011, API-ERP-012, API-ERP-013 (+6) |
| `FEAT-CORE-HONB-001` | `FEAT-ERP-HONB-001`, `FEAT-MBI-HONB-001` | WEB §6.1. COMP-ERP-001 — Sales & Pipeline + WEB §MOD-HANDOFF-ONBOARD — Handoff Package (FEAT-ERP-HONB-001/002) | API-ERP-015, API-ERP-016, API-ERP-017, API-ERP-018 (+6) |
| `FEAT-CORE-COMM-001` | `FEAT-ERP-COMM-001`, `FEAT-MBI-COMM-001` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-COMMISSION-QUOTA (FEAT-ERP-COMM-001) | API-ERP-039, API-ERP-040, API-ERP-041, API-ERP-042 (+6) |
| `FEAT-CORE-ADACC-002` | `FEAT-ERP-ADACC-002` | WEB §6.3. COMP-ERP-003 — Ad Account & Delivery + WEB §MOD-ADACCOUNT-CC — TKQC Registry (FEAT-ERP-ADACC-001…003) | API-ERP-027, API-ERP-043, API-ERP-044, API-ERP-045 (+1) |
| `FEAT-GW-ADACC-001` | `FEAT-ERP-ADACC-001`, `FEAT-MBI-ADACC-001` | WEB §6.3. COMP-ERP-003 — Ad Account & Delivery + WEB §MOD-ADACCOUNT-CC — TKQC Registry (FEAT-ERP-ADACC-001…003) | API-ERP-027, API-ERP-043, API-ERP-044, API-ERP-045 (+6) |
| `FEAT-CORE-ADACC-003` | `FEAT-ERP-ADACC-003` | WEB §6.3. COMP-ERP-003 — Ad Account & Delivery + WEB §MOD-ADACCOUNT-CC — TKQC Registry (FEAT-ERP-ADACC-001…003) | API-ERP-027, API-ERP-043, API-ERP-044, API-ERP-045 (+1) |
| `FEAT-CORE-WALLET-007` | `FEAT-ERP-WALLET-007` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-WALLET-RECON — Ví & đối soát (FEAT-ERP-WALLET-001…007) | API-ERP-020, API-ERP-021, API-ERP-022, API-ERP-023 (+4) |
| `FEAT-GW-WALLET-002` | `FEAT-ERP-WALLET-002`, `FEAT-MBI-WALLET-002` | WEB §6.2. COMP-ERP-002 — Finance & Treasury + WEB §MOD-WALLET-RECON — Ví & đối soát (FEAT-ERP-WALLET-001…007) | API-ERP-020, API-ERP-021, API-ERP-022, API-ERP-023 (+6) |
| `FEAT-CORE-HONB-002` | `FEAT-ERP-HONB-002`, `FEAT-MBI-HONB-002` | WEB §6.1. COMP-ERP-001 — Sales & Pipeline + WEB §MOD-HANDOFF-ONBOARD — Handoff Package (FEAT-ERP-HONB-001/002) | API-ERP-015, API-ERP-016, API-ERP-017, API-ERP-018 (+6) |
| `FEAT-CORE-PROPLN-001` | `FEAT-ERP-PROPLN-001`, `FEAT-MBI-PROPLN-001` | WEB §6.3. COMP-ERP-003 — Ad Account & Delivery + WEB §MOD-PROPOSAL-PLANNING (FEAT-ERP-PROPLN-001) | API-ERP-047, API-ERP-048, API-MBI-013, API-MBI-027 (+6) |
| `FEAT-CORE-CAMP-001` | `FEAT-ERP-CAMP-001`, `FEAT-MBI-CAMP-001`, `FEAT-PORTAL-CAMP-001`, `FEAT-MPO-CAMP-001` | WEB §6.3. COMP-ERP-003 — Ad Account & Delivery + WEB §MOD-CAMPAIGN-DELIVERABLE (FEAT-ERP-CAMP-001/002) | API-ERP-049, API-ERP-050, API-ERP-051, API-ERP-052 (+6) |
| `FEAT-GW-CAMP-001` | `FEAT-ERP-CAMP-001`, `FEAT-MBI-CAMP-001`, `FEAT-PORTAL-CAMP-001`, `FEAT-MPO-CAMP-001` | WEB §6.3. COMP-ERP-003 — Ad Account & Delivery + WEB §MOD-CAMPAIGN-DELIVERABLE (FEAT-ERP-CAMP-001/002) | API-ERP-049, API-ERP-050, API-ERP-051, API-ERP-052 (+6) |
| `FEAT-CORE-CAPTS-002` | `FEAT-ERP-CAPTS-002` | WEB §6.5. COMP-ERP-005 — People & Performance | API-ERP-062, API-ERP-063, API-ERP-064, API-ERP-065 (+4) |
| `FEAT-CORE-SLANOT-001` | `FEAT-ERP-SLANOT-001`, `FEAT-MBI-SLANOT-001`, `FEAT-MPO-SLANOT-001` | WEB §6.6. COMP-ERP-006 — SLA & Notification Worker (MOD-SLA-NOTIF) + MBI §6.1 Device & Push (COMP-MBI-001, COMP-MBI-020 — module nền tảng MBI) | API-ERP-072, API-ERP-073, API-ERP-074, API-MBI-004 (+6) |
| `FEAT-PORTAL-SLANOT-001` | `FEAT-ERP-SLANOT-001`, `FEAT-MBI-SLANOT-001`, `FEAT-MPO-SLANOT-001` | WEB §6.6. COMP-ERP-006 — SLA & Notification Worker (MOD-SLA-NOTIF) + MBI §6.1 Device & Push (COMP-MBI-001, COMP-MBI-020 — module nền tảng MBI) | API-ERP-072, API-ERP-073, API-ERP-074, API-MBI-004 (+6) |
| `FEAT-CORE-CSKH-001` | `FEAT-ERP-CSKH-001`, `FEAT-MBI-CSKH-001`, `FEAT-PORTAL-CSKH-001`, `FEAT-MPO-CSKH-001` | WEB §6.4. COMP-ERP-004 — Client Care (MOD-TICKET-CSKH) + MBI §6.3 Read Surfaces (COMP-MBI-006/007/011/012/017/018/019) | API-ERP-057, API-ERP-058, API-ERP-059, API-ERP-060 (+6) |
| `FEAT-CORE-CPORT-002` | `FEAT-PORTAL-CPORT-002` | PORTAL §6.1 Portal auth & phiên + PORTAL §6.2 Account self-service (CLIENT_ADMIN tự quản user trong quota) | API-PORTAL-001, API-PORTAL-002, API-PORTAL-003, API-PORTAL-004 (+6) |
| `FEAT-CORE-TIKTOK-001` | `FEAT-GW-TIKTOK-001`, `FEAT-ERP-TIKTOK-001`, `FEAT-MBI-TIKTOK-001` | CORE §6.8 Ingest Admin (COMP-CORE-007, 008) + GW §Shop Connection & Lifecycle 3-Gate (FEAT-GW-TIKTOK-001) | API-CORE-008, API-CORE-014, API-CORE-028, API-CORE-046 (+6) |
| `FEAT-CORE-CAMP-002` | `FEAT-ERP-CAMP-002`, `FEAT-MBI-CAMP-002` | WEB §6.3. COMP-ERP-003 — Ad Account & Delivery + WEB §MOD-CAMPAIGN-DELIVERABLE (FEAT-ERP-CAMP-001/002) | API-ERP-049, API-ERP-050, API-ERP-051, API-ERP-052 (+6) |
| `FEAT-GW-CAMP-002` | `FEAT-ERP-CAMP-002`, `FEAT-MBI-CAMP-002` | WEB §6.3. COMP-ERP-003 — Ad Account & Delivery + WEB §MOD-CAMPAIGN-DELIVERABLE (FEAT-ERP-CAMP-001/002) | API-ERP-049, API-ERP-050, API-ERP-051, API-ERP-052 (+6) |
