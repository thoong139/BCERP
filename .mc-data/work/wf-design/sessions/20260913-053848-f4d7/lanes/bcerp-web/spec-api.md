# API Contract — SYS-BCERP-WEB (BCERP Web nội bộ) [fragment]

> READS: `phase2-features/bcerp-web/**` (business rules), `P3-01-architecture.md` (§1 quyết định, §4 ownership, §5 events, §6 quy ước), `lanes/bcerp-web/arch-draft.md`, `business-context.md` v4.1
> OUTPUT: Endpoint registry + contract chi tiết cho 14 module business của SYS-BCERP-WEB
> USED BY: `technical-specs/api-contract.md` (aggregation), `integration-map.md`, `phase4-ux/**`, `phase5-implementation/**`
> DATE: 2026-09-13 | VERSION: v1
> API ID convention: `API-ERP-NNN` — đánh ID mọi endpoint chính; Phase 3 aggregation dedup chéo lane.

---

## 1. Global Conventions

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

## 2. Standard Response Envelopes

Theo template chung (success/data/meta; error/error/code/details — xem `api-contract.md` §2 nền tảng). Mở rộng riêng: response của state-transition trả kèm trạng thái mới + guards đã qua:

```json
{ "success": true, "data": { "id": "uuid", "status": "active",
  "transition": { "from": "pre_spend_hardstop_check", "to": "active", "at": "2026-09-13T04:00:00Z",
                  "by": "uuid", "guards_passed": ["hard_stop_matched", "kyc_verified"] } } }
```

## 3. HTTP Status Codes & 4. Error Codes Registry

Dùng bảng chuẩn template (200/201/400/401/403/404/409/429/500/503). Bổ sung error codes nghiệp vụ ERP:

| Code | HTTP | Mô tả | REQ liên quan |
|------|------|-------|---------------|
| `LEAD_DUPLICATE` | 409 | Anti-duplicate chặn lead trùng (merge/từ chối) | REQ-SALES-001 |
| `HARD_STOP_ACTIVE` | 409 | Chưa "đã khớp tiền" (FIN_L1) — chặn active TKQC | REQ-FIN-006, REQ-OPS-002 |
| `PERIOD_LOCKED` | 409 | Kỳ đã khóa — cấm ghi sổ/sửa dữ liệu kỳ | REQ-FIN-004 |
| `DISCOUNT_OVER_LIMIT` | 409 | Chiết khấu vượt định mức tier — buộc duyệt GM | REQ-SALES-006 |
| `APPROVAL_REQUIRED` | 409 | Action cần approval engine (ngưỡng/dual/SoD) trước khi thực thi | REQ-FIN-008 |
| `SOD_VIOLATION` | 403 | Cùng người 2 chân duyệt (kiêm nhiệm CFO=CTO) — fail-closed | REQ-BOD-002 |
| `AML_FLAGGED` | 409 | Giao dịch gắn cờ AML T1–T6 — chờ điều tra | REQ-FIN-010 |
| `PII_ACCESS_DENIED` | 403 | Trường lương Confidential/Restricted — thiếu classification | REQ-HR-010 |
| `DEGRADED_MODE` | 200 | (warn) Dữ liệu nền tảng là bản nhập `manual` — kèm `source_label` | REQ-FIN-005 |

## 5. Authentication Endpoints

**KHÔNG thuộc scope này.** Login/refresh/logout/MFA step-up thuộc SYS-CORE-BACKEND (`/api/v1/core/auth/*`, COMP-CORE-001). BFF của SYS-BCERP-WEB chỉ proxy và xử lý redirect. REQ-BOD-011.

## 6. Endpoints By System — SYS-BCERP-WEB

> 14 module, 7 components. Mỗi endpoint: role tối thiểu được phép (PDP enforce), request/response chính, REQ-ID. FEAT-ID liệt kê theo nhóm. List endpoints đều có `page/limit/sort/order` + filter nêu ở cột Mô tả (không lặp lại).

### 6.1. COMP-ERP-001 — Sales & Pipeline (MOD-CRM-PIPELINE, MOD-QUOTATION-DEALDESK, MOD-HANDOFF-ONBOARD)

**FEAT: FEAT-ERP-CRM-001…005, FEAT-ERP-QDD-001/002, FEAT-ERP-HONB-001/002.**

#### MOD-CRM-PIPELINE — Leads (FEAT-ERP-CRM-001…005)

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

#### MOD-QUOTATION-DEALDESK — Quotation/Contract (FEAT-ERP-QDD-001/002)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-010 | POST | `/api/v1/erp/quotations` | SALES (AM sở hữu) | Tạo quotation gắn lead + tier; margin_check định mức theo tier | REQ-SALES-006 |
| API-ERP-011 | GET | `/api/v1/erp/quotations`, `/quotations/{id}` | SALES/FIN/BOD (scope) | List filter `status,tier,owner_id,period`; detail margin + approval chain | REQ-SALES-006 |
| API-ERP-012 | POST | `/api/v1/erp/quotations/{id}/transitions` | SALES + approver | draft→margin_check→discount_approval→approved→contracting→signed/rejected | REQ-SALES-006 |
| API-ERP-013 | POST | `/api/v1/erp/quotations/{id}/discount-approval` | SALES_L2/L3 (trong định mức), GM (vượt định mức) | Duyệt chiết khấu phân cấp; vượt định mức → `DISCOUNT_OVER_LIMIT` cho tới khi GM duyệt | REQ-SALES-006 |
| API-ERP-014 | POST | `/api/v1/erp/contracts/{id}/esign-complete` | SALES + khách (e-sign) | Hoàn tất HD/LOI/NDA + brand safety checklist; phát event `deal.signed` | REQ-SALES-007 |

> [NEEDS_REVIEW] e-sign provider + đường dẫn (trực tiếp hay qua GW) — P3-01 Phụ lục A #4. Body API-ERP-014 giữ dạng provider-agnostic: `{ "provider_ref": string, "signed_document_uri": string }`.

#### MOD-HANDOFF-ONBOARD — Handoff Package (FEAT-ERP-HONB-001/002)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-015 | POST | `/api/v1/erp/handoffs` | SALES (auto từ `deal.signed` + manual) | Tạo draft với 5 nhóm bắt buộc | REQ-SALES-008 |
| API-ERP-016 | GET | `/api/v1/erp/handoffs`, `/handoffs/{id}` | SALES/OPS (scope) | List filter `status,customer_id,owner_id`; detail + onboarding tasks | REQ-OPS-004 |
| API-ERP-017 | POST | `/api/v1/erp/handoffs/{id}/sales-submit` | SALES | draft→sales_submit; chặn thiếu 5 nhóm bắt buộc | REQ-SALES-008 |
| API-ERP-018 | POST | `/api/v1/erp/handoffs/{id}/ops-ack` | OPS_AM | ops_ack ký nhận 2 phía → sinh onboarding tasks; phát event `handoff.ops_ack` | REQ-OPS-004 |
| API-ERP-019 | GET/PATCH | `/api/v1/erp/handoffs/{id}/onboarding-tasks[/{taskId}]` | OPS_AM/OPS_CONT | Checklist Day 1/7/14/30 cho ADACC/PORTAL/CAMP; PATCH trạng thái task | REQ-OPS-004 |

### 6.2. COMP-ERP-002 — Finance & Treasury (MOD-WALLET-RECON, MOD-ARAP-PAYMENT, MOD-COMMISSION-QUOTA)

**FEAT: FEAT-ERP-WALLET-001…007, FEAT-ERP-ARAP-001…007, FEAT-ERP-COMM-001.** Mọi endpoint tiền yêu cầu MFA step-up + `Idempotency-Key`.

#### MOD-WALLET-RECON — Ví & đối soát (FEAT-ERP-WALLET-001…007)

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

#### MOD-ARAP-PAYMENT — Công nợ & giải ngân (FEAT-ERP-ARAP-001…007)

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

#### MOD-COMMISSION-QUOTA (FEAT-ERP-COMM-001)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-039 | GET | `/api/v1/erp/commissions` | SALES (của mình), FIN, HR (scope) | List filter `period,sales_id,status`; computed theo thực nhận | REQ-SALES-009 |
| API-ERP-040 | POST | `/api/v1/erp/commissions/{id}/approve` | FIN_L1 | Duyệt trả hoa hồng sau clawback_check | REQ-SALES-009 |
| API-ERP-041 | GET/POST | `/api/v1/erp/clawbacks[/{id}/approve]` | GET: FIN/SALES; POST: FIN_L1 | Clawback khi hoàn tiền/hủy (>90 ngày); sweep tự tính, người duyệt | REQ-SALES-009 |
| API-ERP-042 | GET | `/api/v1/erp/quotas` | SALES/HR/BOD | Quota coverage ≥3× per sales [NEEDS_REVIEW: công thức tử/mẫu số — P3-01 Phụ lục A #7] | REQ-SALES-009 |

### 6.3. COMP-ERP-003 — Ad Account & Delivery (MOD-ADACCOUNT-CC, MOD-PROPOSAL-PLANNING, MOD-CAMPAIGN-DELIVERABLE)

**FEAT: FEAT-ERP-ADACC-001…003, FEAT-ERP-PROPLN-001, FEAT-ERP-CAMP-001/002, FEAT-ERP-TIKTOK-001, FEAT-ERP-CPORT-001.**

#### MOD-ADACCOUNT-CC — TKQC Registry (FEAT-ERP-ADACC-001…003)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-043 | POST | `/api/v1/erp/ad-accounts` | OPS_AM | Đăng ký TKQC; bắt buộc KYC pháp nhân trước (`kyc_required`); naming/UTM chuẩn | REQ-FIN-009, REQ-OPS-001 |
| API-ERP-044 | GET | `/api/v1/erp/ad-accounts` | OPS/FIN/SALES (scope) | List 2.600+: filter `platform,status,customer_id,tier,search`; detail gắn trạng thái sync/manual từ GW | REQ-OPS-001, REQ-FIN-005 |
| API-ERP-045 | POST | `/api/v1/erp/ad-accounts/{id}/transitions` | OPS_AM; guard hard stop FIN | kyc_required→kyc_verified→registered→pre_spend_hardstop_check→active→suspended/closed; chưa khớp tiền → `HARD_STOP_ACTIVE` (check API-ERP-027 tại nguồn) | REQ-OPS-001/002, REQ-FIN-006 |
| API-ERP-046 | POST | `/api/v1/erp/ad-accounts/{id}/revoke` | OPS_AM | Thu hồi 24h / đánh dấu die account; phát alert (SLANOT) | REQ-OPS-001 |

#### MOD-PROPOSAL-PLANNING (FEAT-ERP-PROPLN-001)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-047 | POST/GET | `/api/v1/erp/proposals[/{id}]` | OPS_PLAN soạn; OPS duyệt theo gate | CRUD proposal; list filter `stage,owner_id,customer_id` | REQ-OPS-005 |
| API-ERP-048 | POST | `/api/v1/erp/proposals/{id}/stage-transitions` | OPS_PLAN + approver gate | Stage-gate V6.0: 30 stage, done-criteria machine-checkable — hệ thống tự validate criteria trước khi cho chuyển | REQ-OPS-005 |

> [NEEDS_REVIEW] Tên + done-criteria 30 stage — đọc spec `proposal-va-planning-workspace-stage-gate-v6-0.md` (P3-01 Phụ lục A #1). Contract giữ generic: `{ "to_stage": string, "criteria_evidence": object }`.

#### MOD-CAMPAIGN-DELIVERABLE (FEAT-ERP-CAMP-001/002)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-049 | POST/GET | `/api/v1/erp/campaigns[/{id}]` | OPS_AM lập | CRUD campaign gắn handoff + TKQC; filter `status,customer_id,owner_id` | REQ-OPS-006 |
| API-ERP-050 | POST | `/api/v1/erp/campaigns/{id}/deliverables` | OPS_AM | Tạo deliverable theo WBS + assign OPS_CONT (bulk cho WBS lớn) | REQ-OPS-006 |
| API-ERP-051 | POST | `/api/v1/erp/deliverables/{id}/transitions` | OPS_CONT | planned→in_flight→delivered→reported; variant A/B [NEEDS_REVIEW: state chi tiết] | REQ-OPS-006/012 |
| API-ERP-052 | POST | `/api/v1/erp/deliverables/{id}/acceptance` | OPS_AM (khách nghiệm thu qua portal) | Nghiệm thu 3 ngày làm việc: nhắc ngày 2, escalate AD ngày 4; KHÔNG "im lặng = đồng ý" | REQ-OPS-006 |
| API-ERP-053 | POST | `/api/v1/erp/campaigns/{id}/ab-tests` | OPS_CONT | Tạo variant A/B theo mục tiêu khách | REQ-OPS-012 |

#### Touchpoint consumption: TikTok Shop + Portal account (FEAT-ERP-TIKTOK-001, FEAT-ERP-CPORT-001)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-054 | GET | `/api/v1/erp/tiktok-shop/monitor` | OPS | View GMV shop vs NSQC ads (feed GW, `reference_only=true`); hiển thị nhãn api/manual khi degraded | REQ-OPS-011, REQ-FIN-005 |
| API-ERP-055 | POST/DELETE | `/api/v1/erp/portal-accounts` | OPS_AM | Cấp/thu hồi tài khoản client portal (Day 14) — phát lệnh sang SYS-PORTAL-WEB | REQ-OPS-010 |
| API-ERP-056 | GET | `/api/v1/erp/portal-accounts/{customerId}/usage` | OPS_AM | Monitor adoption phục vụ Gate Day 14 | REQ-OPS-010 |

### 6.4. COMP-ERP-004 — Client Care (MOD-TICKET-CSKH) — FEAT-ERP-CSKH-001

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-057 | POST | `/api/v1/erp/tickets` | Nội bộ (role tương ứng) + SYS-PORTAL-WEB (service token — điểm ghi duy nhất) | Tạo ticket; gắn tier khách + priority; start SLA timer | REQ-OPS-009 |
| API-ERP-058 | GET | `/api/v1/erp/tickets` | OPS (queue theo scope) | Queue filter `status,tier,priority,assignee_id,sla_state` | REQ-OPS-009 |
| API-ERP-059 | POST | `/api/v1/erp/tickets/{id}/assign` | OPS_AM | Assign/reassign; ghi assignment_history | REQ-OPS-009 |
| API-ERP-060 | POST | `/api/v1/erp/tickets/{id}/transitions` | OPS_CONT | open→assigned→in_progress→resolved→closed; reset/adjust SLA timer theo transition | REQ-OPS-009 |
| API-ERP-061 | GET | `/api/v1/erp/tickets/{id}/activity` | OPS | Timeline + context campaign/TKQC + escalation AM→AD→BOD | REQ-OPS-009 |

### 6.5. COMP-ERP-005 — People & Performance (MOD-HR-CORE, MOD-CAPACITY-TIMESHEET, MOD-KPI-PERFORMANCE)

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

### 6.6. COMP-ERP-006 — SLA & Notification Worker (MOD-SLA-NOTIF) — FEAT-ERP-SLANOT-001

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-072 | GET/PUT | `/api/v1/erp/sla-policies[/{id}]` | GET: OPS/FIN; PUT: cấu hình qua phê duyệt tham số (REQ-BOD-009 — BOD) | Instance ma trận tier×priority GMT+7; effective-dated | REQ-OPS-008, REQ-BOD-009 |
| API-ERP-073 | GET | `/api/v1/erp/sla-timers` | OPS/FIN (scope) | Trạng thái timer per object (`object_type,object_id,sla_state`); timer persist sống qua restart | REQ-OPS-008 |
| API-ERP-074 | GET | `/api/v1/erp/notifications` | role sở hữu object | Log dispatch đa kênh (idempotent + retry); kênh ngoài in-app [NEEDS_REVIEW: P3-01 Phụ lục A #3] | REQ-OPS-008 |

### 6.7. COMP-ERP-007 — Batch & Recon Scheduler (jobs cross-module)

| API ID | Method | Path | Permission | Mô tả | REQ-ID |
|--------|--------|------|-----------|-------|--------|
| API-ERP-075 | GET | `/api/v1/erp/jobs` | SYS_ADMIN, FIN (job tiền) | Job registry + run history (đối trừ 3 số, sweep hard stop, aging, HĐLĐ 90/60/30, KPI aggregate, clawback, capacity, checkpoint handoff) | REQ-FIN-004/006, REQ-OPS-008 |
| API-ERP-076 | POST | `/api/v1/erp/jobs/{key}/trigger` | SYS_ADMIN (không tự duyệt thay người) | Re-run manual theo window; idempotency key (job, window); audit `triggered_by=manual` | REQ-FIN-006 |
| API-ERP-077 | GET/POST | `/api/v1/erp/jobs/dead-letters[/{id}/replay]` | SYS_ADMIN + owner module | DLQ view; replay là hành động người, không auto-replay | REQ-OPS-008 |

## 7. Internal API (Service-to-Service)

Kiến trúc **modular monolith** (P3-01 §1): giao tiếp giữa COMP-ERP-001…007 là **internal method call qua module interface** — không network hop ngày 1. Chỉ 2 tuyến REST external thực sự:

| Method | Path | Caller | Purpose | REQ-ID |
|--------|------|--------|---------|--------|
| POST | `/api/v1/erp/tickets` (API-ERP-057, header `X-Portal-Service-Token`) | SYS-PORTAL-WEB | Điểm ghi duy nhất ticket từ portal | REQ-OPS-009 |
| POST | `/internal/erp/portal-read-model/publish` | COMP-ERP-002/003 | Publish read-model ví read-only + invoice + campaign status sang PORTAL [NEEDS_REVIEW: contract API — P3-01 Phụ lục A #6] | REQ-FIN-017, REQ-OPS-010 |

Event (outbox, consumer idempotent, DLQ) theo §5 P3-01 + arch-draft §5: `wallet.matched`, `wallet.low_balance`, `recon.mismatch`, `handoff.ops_ack`, `deal.signed`, `payment.received`, `refund.executed`, `invoice.issued`, `timesheet.approved`, `kpi.below_threshold`, `sla.warning`, `sla.breach`, `deliverable.acceptance_due`. Payload schema versioned — chi tiết ở `integration-map.md` (aggregation).

## 8. Rate Limiting

| Endpoint group | Limit | Window |
|---------------|-------|--------|
| Money commands (`/wallets/*/transactions`, `/ar-invoices/*/payments`, `/payment-orders/*`, `/einvoices/*/issue`) | 60 req | 1 phút/user |
| Bulk import (`/leads/bulk-import`) | 5 req | 1 phút |
| Export/báo cáo (`/platform-fees`, `/commissions`, `/capacity`, read-model publish) | 10 req | 1 phút |
| General ERP API | 200 req | 1 phút/user |
| Internal (portal publish, service token) | 1000 req | 1 phút |
