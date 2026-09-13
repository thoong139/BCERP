# Database Design — BCERP

> **Dựa trên:** P3-01-architecture.md + feature specs Phase 2 + Business Context Baseline v4.1 | **Session:** 20260913-053848-f4d7 | **Ngày:** 13/09/2026
> **Cấu trúc:** Mỗi system 1 section (fragment do lane agent sinh, ID convention riêng: API-ERP/API-CORE/API-GW/API-PORTAL/API-MBI/API-MPO). Aggregation + dedup api_id ở Phase 3.
> PostgreSQL 16 per-system schema; OLAP warehouse thuộc SYS-CORE-BACKEND (ClickHouse đề xuất). DDL chi tiết trong từng fragment.


## Hệ thống: SYS-BCERP-WEB — BCERP Web nội bộ

## Database Design — SYS-BCERP-WEB (BCERP Web nội bộ) [fragment]

> READS: `phase2-features/bcerp-web/**` (business rules, entities), `P3-01-architecture.md` (§1, §3 schema, §4 ownership, §6 quy ước), `lanes/bcerp-web/arch-draft.md`, `business-context.md` v4.1
> OUTPUT: DDL core tables, indexes, migration strategy cho 5 schema ERP
> USED BY: `technical-specs/database-design.md` (aggregation), `phase5-implementation/**`
> DATE: 2026-09-13 | DB: PostgreSQL 16
> Table ID convention (lane contract): `TBL-ERP-NNN`. Mỗi SQL comment có TBL-ID + REQ-ID + FEAT-ID.

---

### 1. Schema Organization

| Schema | System | Mục đích |
|--------|--------|---------|
| `erp_sales` | SYS-BCERP-WEB (COMP-ERP-001) | Customer/tier, lead, quotation, contract, handoff |
| `erp_finance` | SYS-BCERP-WEB (COMP-ERP-002) | Ví tiền giữ hộ, journal, đối trừ, period lock, AR/AP, HĐĐT, commission |
| `erp_ops` | SYS-BCERP-WEB (COMP-ERP-003/004) | TKQC registry, proposal stage-gate, campaign/deliverable, ticket, portal account request |
| `erp_people` | SYS-BCERP-WEB (COMP-ERP-005) | Hồ sơ, HĐLĐ, chấm công, nghỉ phép, rate card, timesheet, capacity, KPI/PIP |
| `erp_sla` | SYS-BCERP-WEB (COMP-ERP-006/007) | SLA policy/timer, notification log, job registry, outbox |

**Quy tắc naming:** theo template (`snake_case`, bảng số nhiều, `idx_[table]_[cols]`, `fk_[table]_[ref]`).

**Quy ước column dùng chung cho mọi business object có workflow (bắt buộc theo baseline ghi chú agent):**
```sql
  status        VARCHAR(30) NOT NULL CHECK (status IN (...)),  -- state machine versioned (JSON definition dùng chung)
  owner_id      UUID NOT NULL REFERENCES core_identity.users(id),  -- CROSS-SCHEMA FK (SYS-CORE-BACKEND sở hữu users)
  assignee_id   UUID REFERENCES core_identity.users(id),           -- object có handoff/queue
  created_by    UUID NOT NULL REFERENCES core_identity.users(id),
  updated_by    UUID REFERENCES core_identity.users(id),
  created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,               -- UTC (P3-01 §6)
  updated_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at    TIMESTAMPTZ                                        -- soft delete; audit/WORM bất biến
```
Tenant: nội bộ không có tenant_id (dept data-scope tại PDP); bảng phục vụ client-facing portal có `customer_id` bắt buộc và RLS 2 lớp khi publish read-model.

**Tiền:** `DECIMAL(18,2)` per-currency — USD/VND không gộp, không quy đổi chéo; snapshot fee %/tỷ giá tại thời điểm giao dịch; mọi money command có `idempotency_key UUID UNIQUE`; ghi sổ ví **double-entry** (journal + lines debit/credit balance 0); kỳ đối soát có `period_locks` cản ghi.

### 2. Shared Tables

Không sở hữu bảng shared. `core_identity.users`, `core_identity.roles` thuộc SYS-CORE-BACKEND — FK tham chiếu qua schema boundary (`-- CROSS-SCHEMA FK`), chỉ đọc. Audit compliance (hash-chain, WORM ≥10 năm) ghi qua COMP-CORE-004 — bảng `*_activities` dưới đây chỉ là **activity/timeline nghiệp vụ** phục vụ UI, không thay thế audit log platform (REQ-BOD-005, REQ-FIN-012).

### 3. SYS-BCERP-WEB Tables

#### 3.1. Schema `erp_sales` (COMP-ERP-001) — FEAT-ERP-CRM-*, FEAT-ERP-QDD-*, FEAT-ERP-HONB-*

```sql
-- TBL-ERP-001 | REQ-SALES-005 | FEAT-ERP-CRM-005 — Customer master + tier A–E
CREATE TABLE erp_sales.customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name VARCHAR(300) NOT NULL,
  tax_code VARCHAR(20),
  tier VARCHAR(2) NOT NULL DEFAULT 'C' CHECK (tier IN ('A','B','C','D','E')),
  tier_reviewed_at TIMESTAMPTZ,                      -- rà soát quý (scheduler)
  cs_owner_id UUID REFERENCES core_identity.users(id),
  created_by UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_customers_tier ON erp_sales.customers(tier) WHERE deleted_at IS NULL;

-- TBL-ERP-002 | REQ-SALES-001/002/003 | FEAT-ERP-CRM-001/002/003 — Lead pipeline V6.0
CREATE TABLE erp_sales.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(20) UNIQUE NOT NULL,                  -- seq: LD-000001
  channel VARCHAR(30) NOT NULL,                      -- referral|web|fb|tiktok|event...
  company_name VARCHAR(300) NOT NULL,
  contact_name VARCHAR(200), phone VARCHAR(30), email VARCHAR(255),
  fingerprint VARCHAR(64) NOT NULL,                  -- anti-duplicate hash (phone/email/domain)
  status VARCHAR(30) NOT NULL DEFAULT 'new'
    CHECK (status IN ('new','dedup_check','assigned','scored','gate1_go','gate1_no_go',
                      'qualified','gate2_signed_handoff','handed_to_cs','rejected','recycled')),
  tier VARCHAR(2) CHECK (tier IN ('A','B','C','D','E')),   -- A<1.5 AUTO LOST, E>=3.5 bypass
  score_total DECIMAL(5,2),                          -- K1–K12
  customer_id UUID REFERENCES erp_sales.customers(id),
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),
  assignee_id UUID REFERENCES core_identity.users(id),
  created_by UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX uq_leads_fingerprint ON erp_sales.leads(fingerprint) WHERE deleted_at IS NULL;
CREATE INDEX idx_leads_status_owner ON erp_sales.leads(status, owner_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_leads_tier_created ON erp_sales.leads(tier, created_at DESC) WHERE deleted_at IS NULL;

-- TBL-ERP-003 | REQ-SALES-002 | FEAT-ERP-CRM-002 — Assignment history (multi-stage handoff)
CREATE TABLE erp_sales.lead_assignment_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES erp_sales.leads(id),
  from_user_id UUID REFERENCES core_identity.users(id),
  to_user_id UUID NOT NULL REFERENCES core_identity.users(id),
  stage VARCHAR(30) NOT NULL,                        -- intake|gate1|gate2|handoff_to_cs
  assigned_by UUID NOT NULL REFERENCES core_identity.users(id),
  assigned_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_lah_lead ON erp_sales.lead_assignment_history(lead_id, assigned_at DESC);

-- TBL-ERP-004 | REQ-SALES-004 | FEAT-ERP-CRM-004 — Gate 1/Gate 2 Go-No-Go
CREATE TABLE erp_sales.lead_gate_decisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES erp_sales.leads(id),
  gate SMALLINT NOT NULL CHECK (gate IN (1,2)),
  decision VARCHAR(10) NOT NULL CHECK (decision IN ('go','no_go')),
  decided_by UUID NOT NULL REFERENCES core_identity.users(id),
  decided_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  note TEXT
);
CREATE INDEX idx_lgd_lead_gate ON erp_sales.lead_gate_decisions(lead_id, gate);

-- TBL-ERP-005 | REQ-SALES-006 | FEAT-ERP-QDD-001 — Quotation/Deal
CREATE TABLE erp_sales.quotations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(20) UNIQUE NOT NULL,                  -- QT-000001
  lead_id UUID REFERENCES erp_sales.leads(id),
  customer_id UUID NOT NULL REFERENCES erp_sales.customers(id),
  status VARCHAR(30) NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','margin_check','discount_approval','approved','contracting','signed','rejected')),
  deal_value DECIMAL(18,2) NOT NULL,
  currency VARCHAR(3) NOT NULL CHECK (currency IN ('USD','VND')),
  discount_percent DECIMAL(5,2) NOT NULL DEFAULT 0,
  discount_limit_percent DECIMAL(5,2) NOT NULL,      -- định mức theo tier (snapshot)
  requires_gm_approval BOOLEAN GENERATED ALWAYS AS (discount_percent > discount_limit_percent) STORED,
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),   -- AM sở hữu
  created_by UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_quot_status_owner ON erp_sales.quotations(status, owner_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_quot_customer ON erp_sales.quotations(customer_id);

-- TBL-ERP-006 | REQ-SALES-006 | FEAT-ERP-QDD-001 — Approval chain chiết khấu phân cấp + GM
CREATE TABLE erp_sales.quotation_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quotation_id UUID NOT NULL REFERENCES erp_sales.quotations(id),
  level VARCHAR(20) NOT NULL CHECK (level IN ('sales_l2','sales_l3','gm')),
  decision VARCHAR(10) CHECK (decision IN ('approved','rejected','pending')),
  approver_id UUID REFERENCES core_identity.users(id),
  requested_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  decided_at TIMESTAMPTZ
);

-- TBL-ERP-007 | REQ-SALES-007 | FEAT-ERP-QDD-002 — HD/LOI/NDA + brand safety + e-sign
CREATE TABLE erp_sales.contracts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quotation_id UUID NOT NULL REFERENCES erp_sales.quotations(id),
  contract_type VARCHAR(10) NOT NULL CHECK (contract_type IN ('HD','LOI','NDA')),
  status VARCHAR(20) NOT NULL DEFAULT 'drafting' CHECK (status IN ('drafting','sent_for_esign','signed','rejected')),
  brand_safety_checklist JSONB NOT NULL DEFAULT '[]',
  esign_provider_ref VARCHAR(200),                   -- [NEEDS_REVIEW] provider chưa chốt
  signed_document_uri VARCHAR(500),                  -- object storage (WORM cho evidence)
  signed_at TIMESTAMPTZ,
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),
  created_by UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);

-- TBL-ERP-008 | REQ-SALES-008/REQ-OPS-004 | FEAT-ERP-HONB-001/002 — Handoff Package
CREATE TABLE erp_sales.handoffs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id UUID REFERENCES erp_sales.contracts(id),
  customer_id UUID NOT NULL REFERENCES erp_sales.customers(id),
  status VARCHAR(30) NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','sales_submit','ops_ack','onboarding_tasks','completed')),
  package_payload JSONB NOT NULL,                    -- 5 nhóm bắt buộc (validate trước submit)
  sales_submitted_by UUID REFERENCES core_identity.users(id),
  sales_submitted_at TIMESTAMPTZ,
  ops_acked_by UUID REFERENCES core_identity.users(id),   -- ký nhận 2 phía
  ops_acked_at TIMESTAMPTZ,
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),
  created_by UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ,
  CHECK (status <> 'ops_ack' OR (ops_acked_by IS NOT NULL AND sales_submitted_by IS NOT NULL))
);
CREATE INDEX idx_handoff_status_customer ON erp_sales.handoffs(status, customer_id);

-- TBL-ERP-009 | REQ-OPS-004 | FEAT-ERP-HONB-002 — Onboarding tasks Day 1/7/14/30
CREATE TABLE erp_sales.handoff_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  handoff_id UUID NOT NULL REFERENCES erp_sales.handoffs(id),
  target_module VARCHAR(20) NOT NULL CHECK (target_module IN ('ADACC','PORTAL','CAMP')),
  checkpoint_day SMALLINT NOT NULL CHECK (checkpoint_day IN (1,7,14,30)),
  title VARCHAR(300) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','done','blocked','skipped')),
  assignee_id UUID REFERENCES core_identity.users(id),
  due_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);
CREATE INDEX idx_htask_handoff_due ON erp_sales.handoff_tasks(handoff_id, due_at);

-- TBL-ERP-010 | REQ-SALES-002 | FEAT-ERP-CRM-002 — Activity/timeline domain sales
CREATE TABLE erp_sales.sales_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  object_type VARCHAR(20) NOT NULL CHECK (object_type IN ('lead','quotation','contract','handoff','customer')),
  object_id UUID NOT NULL,
  activity_type VARCHAR(40) NOT NULL,                -- created|updated|transition|assigned|gate|scored|esign
  actor_id UUID REFERENCES core_identity.users(id),  -- NULL = system/scheduler
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_sact_object ON erp_sales.sales_activities(object_type, object_id, created_at DESC);
```

#### 3.2. Schema `erp_finance` (COMP-ERP-002) — FEAT-ERP-WALLET-*, FEAT-ERP-ARAP-*, FEAT-ERP-COMM-001

```sql
-- TBL-ERP-011 | REQ-FIN-001 | FEAT-ERP-WALLET-001 — Ví per khách per currency
CREATE TABLE erp_finance.wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES erp_sales.customers(id),
  currency VARCHAR(3) NOT NULL CHECK (currency IN ('USD','VND')),
  balance DECIMAL(18,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),   -- số dư tiền giữ hộ
  days_of_coverage DECIMAL(5,1),                     -- dự chi đủ >=3 ngày (job tính)
  low_balance_since TIMESTAMPTZ,                     -- mốc bắt cảnh báo + SLA đỏ 2h
  hard_stop_status VARCHAR(20) NOT NULL DEFAULT 'not_matched'
    CHECK (hard_stop_status IN ('not_matched','matched','revoked')),   -- REQ-FIN-006
  hard_stop_confirmed_by UUID REFERENCES core_identity.users(id),    -- FIN_L1
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (customer_id, currency)
);
CREATE INDEX idx_wallets_low ON erp_finance.wallets(low_balance_since) WHERE low_balance_since IS NOT NULL;

-- TBL-ERP-012/013 | REQ-FIN-001 | FEAT-ERP-WALLET-001 — Double-entry journal
CREATE TABLE erp_finance.wallet_journal (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_no BIGSERIAL UNIQUE,
  period VARCHAR(7) NOT NULL,                        -- YYYY-MM
  entry_source VARCHAR(10) NOT NULL DEFAULT 'api' CHECK (entry_source IN ('api','manual')),  -- nhãn nguồn bất biến
  posted_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  posted_by UUID NOT NULL REFERENCES core_identity.users(id),
  period_locked BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX idx_wj_period ON erp_finance.wallet_journal(period);

CREATE TABLE erp_finance.wallet_journal_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_id UUID NOT NULL REFERENCES erp_finance.wallet_journal(id),
  wallet_id UUID NOT NULL REFERENCES erp_finance.wallets(id),
  direction VARCHAR(6) NOT NULL CHECK (direction IN ('debit','credit')),
  amount DECIMAL(18,2) NOT NULL CHECK (amount > 0),
  fee_percent_snapshot DECIMAL(5,2),                 -- snapshot fee % tại thời điểm giao dịch
  entry_type VARCHAR(30) NOT NULL                    -- topup|spend|adjustment|revaluation|refund
);
CREATE INDEX idx_wjl_wallet ON erp_finance.wallet_journal_lines(wallet_id, id);
-- Bất biến: SUM(debit) = SUM(credit) per journal — enforce ở application + job validate.

-- TBL-ERP-014 | REQ-FIN-001/003 | FEAT-ERP-WALLET-001/003 — Lệnh giao dịch tiền (money command)
CREATE TABLE erp_finance.wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(20) UNIQUE NOT NULL,
  wallet_id UUID NOT NULL REFERENCES erp_finance.wallets(id),
  type VARCHAR(20) NOT NULL CHECK (type IN ('topup','spend','adjustment','revaluation','refund')),
  status VARCHAR(20) NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','dual_approval','aml_hold','executed','rejected')),
  currency VARCHAR(3) NOT NULL,
  amount DECIMAL(18,2) NOT NULL CHECK (amount > 0),
  fee_percent_snapshot DECIMAL(5,2),
  fx_rate_snapshot DECIMAL(18,8),                    -- cho revaluation
  aml_tier SMALLINT CHECK (aml_tier BETWEEN 1 AND 6),
  idempotency_key UUID NOT NULL UNIQUE,              -- bắt buộc mọi money command
  related_payment_order_id UUID REFERENCES erp_finance.payment_orders(id),  -- API-ERP-022: lệnh chi liên quan (refund/adjustment)
  note TEXT,                                         -- API-ERP-022: ghi chú lệnh giao dịch
  journal_id UUID REFERENCES erp_finance.wallet_journal(id),  -- fill khi executed
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),  -- FIN_L1 khởi tạo
  approver1_id UUID REFERENCES core_identity.users(id),       -- dual approval FIN_L1
  approver2_id UUID REFERENCES core_identity.users(id),       -- FIN_L2 — CHECK khác approver1 ở app layer (SOD)
  created_by UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_wtx_status_wallet ON erp_finance.wallet_transactions(status, wallet_id);

-- TBL-ERP-015/016 | REQ-FIN-004 | FEAT-ERP-WALLET-004 — Đối trừ 3 số
CREATE TABLE erp_finance.reconciliation_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period VARCHAR(7) NOT NULL,
  currency VARCHAR(3) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open','mismatch','closed')),
  portal_total DECIMAL(18,2), bank_total DECIMAL(18,2), ledger_total DECIMAL(18,2),
  closed_by UUID REFERENCES core_identity.users(id),   -- FIN_L2
  closed_at TIMESTAMPTZ,
  UNIQUE (period, currency)
);
CREATE TABLE erp_finance.reconciliation_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id UUID NOT NULL REFERENCES erp_finance.reconciliation_runs(id),
  match_key VARCHAR(200) NOT NULL,                   -- tx ref + amount + currency + window
  portal_amount DECIMAL(18,2), bank_amount DECIMAL(18,2), ledger_amount DECIMAL(18,2),
  state VARCHAR(12) NOT NULL DEFAULT 'reconciling' CHECK (state IN ('reconciling','matched','mismatch')),
  source_label VARCHAR(10) NOT NULL CHECK (source_label IN ('api','manual')),  -- bất biến
  investigation_note TEXT
);
CREATE INDEX idx_ri_run_state ON erp_finance.reconciliation_items(run_id, state);

-- TBL-ERP-017 | REQ-FIN-004 | FEAT-ERP-WALLET-004 — Period lock
CREATE TABLE erp_finance.period_locks (
  period VARCHAR(7) PRIMARY KEY,
  currency VARCHAR(3) NOT NULL,
  locked_by UUID NOT NULL REFERENCES core_identity.users(id),   -- FIN_L2
  locked_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  checklist JSONB NOT NULL                           -- đối trừ khớp, mismatch=0/đã xử lý, HĐĐT issued...
);

-- TBL-ERP-018 | REQ-FIN-006/REQ-OPS-002 | FEAT-ERP-WALLET-005 — Hard stop confirmations (WORM-feed)
CREATE TABLE erp_finance.hard_stop_confirmations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES erp_sales.customers(id),
  confirmed_by UUID NOT NULL REFERENCES core_identity.users(id),  -- FIN_L1
  confirmed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  basis_reconciliation_run_id UUID REFERENCES erp_finance.reconciliation_runs(id),
  evidence_uri VARCHAR(500)                          -- push WORM COMP-CORE-005 (REQ-FIN-012)
);
CREATE INDEX idx_hsc_customer ON erp_finance.hard_stop_confirmations(customer_id, confirmed_at DESC);

-- TBL-ERP-019 | REQ-FIN-010 | FEAT-ERP-WALLET-006 — AML flags T1–T6
CREATE TABLE erp_finance.aml_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_transaction_id UUID NOT NULL REFERENCES erp_finance.wallet_transactions(id),
  tier SMALLINT NOT NULL CHECK (tier BETWEEN 1 AND 6),
  status VARCHAR(15) NOT NULL DEFAULT 'open' CHECK (status IN ('open','investigating','resolved')),
  refund_source_verified BOOLEAN DEFAULT FALSE,      -- hoàn tiền đúng nguồn
  resolved_by UUID REFERENCES core_identity.users(id),
  resolved_at TIMESTAMPTZ
);

-- TBL-ERP-020/021 | REQ-FIN-007 | FEAT-ERP-ARAP-003 — AR invoice + dunning
CREATE TABLE erp_finance.ar_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(20) UNIQUE NOT NULL,
  customer_id UUID NOT NULL REFERENCES erp_sales.customers(id),
  contract_id UUID REFERENCES erp_sales.contracts(id),
  status VARCHAR(20) NOT NULL DEFAULT 'issued'
    CHECK (status IN ('draft','issued','partially_paid','paid','overdue','written_off')),
  aging_bucket SMALLINT NOT NULL DEFAULT 0 CHECK (aging_bucket IN (0,1,2,3)),  -- current|30|60|90+
  currency VARCHAR(3) NOT NULL,
  amount DECIMAL(18,2) NOT NULL,
  paid_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
  due_date DATE NOT NULL,
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),   -- FIN_L1
  created_by UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_ar_status_bucket_due ON erp_finance.ar_invoices(status, aging_bucket, due_date);
CREATE INDEX idx_ar_customer ON erp_finance.ar_invoices(customer_id);
CREATE TABLE erp_finance.dunning_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ar_invoice_id UUID NOT NULL REFERENCES erp_finance.ar_invoices(id),
  bucket SMALLINT NOT NULL,
  sent_by VARCHAR(10) NOT NULL DEFAULT 'system',     -- system|manual (FIN_L1)
  sent_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- TBL-ERP-022/023 | REQ-FIN-008/REQ-BOD-001/010 | FEAT-ERP-ARAP-001/002/004 — Lệnh chi + approval ngưỡng
CREATE TABLE erp_finance.payment_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(20) UNIQUE NOT NULL,
  customer_id UUID REFERENCES erp_sales.customers(id),      -- chi từ ví khách (giải ngân TKQC)
  status VARCHAR(20) NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','in_approval','approved','disbursed','rejected','cancelled')),
  currency VARCHAR(3) NOT NULL,
  amount DECIMAL(18,2) NOT NULL,
  threshold_level SMALLINT NOT NULL,                 -- 1: <50tr L2; 2: <200tr CFO; 3: >=200tr CEO (VND-equivalent policy)
  quotation_ref_uri VARCHAR(500),                    -- thiếu báo giá → chặn (exception §5)
  idempotency_key UUID NOT NULL UNIQUE,
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),   -- FIN_L1 khởi tạo
  created_by UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_po_status ON erp_finance.payment_orders(status, created_at DESC);
CREATE TABLE erp_finance.payment_order_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_order_id UUID NOT NULL REFERENCES erp_finance.payment_orders(id),
  step SMALLINT NOT NULL,                            -- SoD 4 vai: khởi tạo→kiểm soát→duyệt→thực thi
  role_required VARCHAR(20) NOT NULL,                -- FIN_L2|CFO|CEO|delegate
  approver_id UUID REFERENCES core_identity.users(id),
  decided_at TIMESTAMPTZ,
  decision VARCHAR(10) CHECK (decision IN ('approved','rejected','pending')),
  UNIQUE (payment_order_id, step)                    -- cấm cùng người 2 chân ở app layer (SOD/kiêm nhiệm REQ-BOD-002)
);

-- TBL-ERP-024 | REQ-FIN-011 | FEAT-ERP-ARAP-005 — HĐĐT TT78/NĐ123
CREATE TABLE erp_finance.einvoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ar_invoice_id UUID NOT NULL REFERENCES erp_finance.ar_invoices(id),
  status VARCHAR(15) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','issued','delivered','cancelled')),
  invoice_no VARCHAR(50),                            -- theo TT78/2021 + NĐ123/2020
  issued_at TIMESTAMPTZ,
  evidence_uri VARCHAR(500)                          -- WORM ≥10 năm (REQ-FIN-012)
);
-- TBL-ERP-025 | REQ-FIN-014 | FEAT-ERP-ARAP-007 — Phí nền tảng & nghĩa vụ thuế (tổng hợp, tóm gọn)
CREATE TABLE erp_finance.platform_fees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period VARCHAR(7) NOT NULL, platform VARCHAR(20) NOT NULL,
  fee_amount DECIMAL(18,2), tax_obligation DECIMAL(18,2), currency VARCHAR(3) NOT NULL,
  source_label VARCHAR(10) NOT NULL DEFAULT 'api',
  UNIQUE (period, platform, currency)
);
-- TBL-ERP-026/027/028 | REQ-SALES-009 | FEAT-ERP-COMM-001 — Commission/clawback/quota
CREATE TABLE erp_finance.commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sales_user_id UUID NOT NULL REFERENCES core_identity.users(id),
  period VARCHAR(7) NOT NULL,
  quotation_id UUID REFERENCES erp_sales.quotations(id),
  status VARCHAR(20) NOT NULL DEFAULT 'computed'
    CHECK (status IN ('computed','clawback_check','approved','paid','clawed_back')),
  realized_amount DECIMAL(18,2) NOT NULL,            -- theo thực nhận (AR đã thu)
  commission_amount DECIMAL(18,2) NOT NULL,
  approved_by UUID REFERENCES core_identity.users(id),  -- FIN_L1
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_comm_sales_period ON erp_finance.commissions(sales_user_id, period);
CREATE TABLE erp_finance.commission_clawbacks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commission_id UUID NOT NULL REFERENCES erp_finance.commissions(id),
  reason VARCHAR(20) NOT NULL CHECK (reason IN ('refund','deal_cancelled')),
  amount DECIMAL(18,2) NOT NULL,
  status VARCHAR(15) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','applied')),
  approved_by UUID REFERENCES core_identity.users(id)
);
CREATE TABLE erp_finance.quotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sales_user_id UUID NOT NULL REFERENCES core_identity.users(id),
  period VARCHAR(7) NOT NULL,
  quota_amount DECIMAL(18,2) NOT NULL,
  coverage_ratio DECIMAL(6,3),                       -- ≥3× [NEEDS_REVIEW: công thức — Phụ lục A #7]
  UNIQUE (sales_user_id, period)
);
-- TBL-ERP-029 | REQ-FIN-001 | FEAT-ERP-WALLET-001 — Activity domain finance (tiền vẫn ghi WORM qua CORE)
CREATE TABLE erp_finance.finance_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  object_type VARCHAR(20) NOT NULL CHECK (object_type IN ('wallet','wallet_transaction','reconciliation','ar_invoice','payment_order','einvoice','commission')),
  object_id UUID NOT NULL,
  activity_type VARCHAR(40) NOT NULL,
  actor_id UUID REFERENCES core_identity.users(id),
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_fact_object ON erp_finance.finance_activities(object_type, object_id, created_at DESC);
```

#### 3.3. Schema `erp_ops` (COMP-ERP-003/004) — FEAT-ERP-ADACC-*, FEAT-ERP-PROPLN-001, FEAT-ERP-CAMP-*, FEAT-ERP-CSKH-001, FEAT-ERP-CPORT-001

```sql
-- TBL-ERP-030 | REQ-OPS-001/REQ-FIN-009 | FEAT-ERP-ADACC-001/002/003 — TKQC registry
CREATE TABLE erp_ops.ad_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform VARCHAR(20) NOT NULL CHECK (platform IN ('meta','google','tiktok','bing','x','pinterest','yandex')),
  external_account_id VARCHAR(100),
  name_normalized VARCHAR(200) NOT NULL,             -- naming/UTM chuẩn
  status VARCHAR(30) NOT NULL DEFAULT 'kyc_required'
    CHECK (status IN ('kyc_required','kyc_verified','registered','pre_spend_hardstop_check','active','suspended','closed','dead')),
  kyc_verified_by UUID REFERENCES core_identity.users(id),
  kyc_verified_at TIMESTAMPTZ,
  customer_id UUID NOT NULL REFERENCES erp_sales.customers(id),
  source_label VARCHAR(10) NOT NULL DEFAULT 'api' CHECK (source_label IN ('api','manual')),  -- GW nhãn bất biến
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),   -- OPS_AM registry
  created_by UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_adacc_status_platform ON erp_ops.ad_accounts(status, platform) WHERE deleted_at IS NULL;
CREATE INDEX idx_adacc_customer ON erp_ops.ad_accounts(customer_id);
-- TBL-ERP-031 | REQ-OPS-001 | FEAT-ERP-ADACC-002 — Vòng đời + die account + thu hồi 24h
CREATE TABLE erp_ops.ad_account_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_account_id UUID NOT NULL REFERENCES erp_ops.ad_accounts(id),
  event_type VARCHAR(30) NOT NULL,                   -- transition|die_detected|revoked|hard_stop_blocked
  from_status VARCHAR(30), to_status VARCHAR(30),
  actor_id UUID REFERENCES core_identity.users(id),  -- NULL = sweep/event
  payload JSONB, created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_adae_account ON erp_ops.ad_account_events(ad_account_id, created_at DESC);

-- TBL-ERP-032/033 | REQ-OPS-005 | FEAT-ERP-PROPLN-001 — Proposal stage-gate V6.0
CREATE TABLE erp_ops.proposals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES erp_sales.customers(id),
  current_stage SMALLINT NOT NULL DEFAULT 1,         -- 30 stage V6.0 [NEEDS_REVIEW: tên stage]
  status VARCHAR(20) NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','approved','rejected')),
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),   -- OPS_PLAN
  created_by UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE TABLE erp_ops.proposal_stages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id UUID NOT NULL REFERENCES erp_ops.proposals(id),
  stage_no SMALLINT NOT NULL,
  stage_key VARCHAR(60) NOT NULL,
  done_criteria JSONB NOT NULL,                      -- machine-checkable (KXN-10)
  criteria_passed BOOLEAN NOT NULL DEFAULT FALSE,
  entered_at TIMESTAMPTZ, exited_at TIMESTAMPTZ,
  UNIQUE (proposal_id, stage_no)
);

-- TBL-ERP-034..037 | REQ-OPS-006/012 | FEAT-ERP-CAMP-001/002 — Campaign + deliverable + A/B
CREATE TABLE erp_ops.campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES erp_sales.customers(id),
  handoff_id UUID REFERENCES erp_sales.handoffs(id),
  status VARCHAR(20) NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned','in_flight','delivered','reported')),
  objective VARCHAR(60) NOT NULL,                    -- mục tiêu khách (A/B strategy)
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),   -- OPS_AM
  created_by UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_camp_status_customer ON erp_ops.campaigns(status, customer_id);
CREATE TABLE erp_ops.deliverables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES erp_ops.campaigns(id),
  wbs_code VARCHAR(20) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned','in_flight','delivered','reported')),   -- variant A/B [NEEDS_REVIEW]
  assignee_id UUID REFERENCES core_identity.users(id),         -- OPS_CONT
  acceptance_due_at TIMESTAMPTZ,                     -- nghiệm thu 3 ngày: nhắc D2, escalate D4
  acceptance_status VARCHAR(15) CHECK (acceptance_status IN ('pending','accepted','rejected','escalated')),
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_dlvr_assignee_status ON erp_ops.deliverables(assignee_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_dlvr_acceptance_due ON erp_ops.deliverables(acceptance_due_at) WHERE acceptance_status = 'pending';
CREATE TABLE erp_ops.deliverable_assignment_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deliverable_id UUID NOT NULL REFERENCES erp_ops.deliverables(id),
  from_user_id UUID REFERENCES core_identity.users(id),
  to_user_id UUID NOT NULL REFERENCES core_identity.users(id),
  assigned_by UUID NOT NULL REFERENCES core_identity.users(id),
  assigned_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE TABLE erp_ops.ab_tests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES erp_ops.campaigns(id),
  variant_label VARCHAR(10) NOT NULL,                -- A|B
  hypothesis TEXT, status VARCHAR(15) NOT NULL DEFAULT 'running',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- TBL-ERP-038/039 | REQ-OPS-009 | FEAT-ERP-CSKH-001 — Ticket
CREATE TABLE erp_ops.tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(20) UNIQUE NOT NULL,
  customer_id UUID NOT NULL REFERENCES erp_sales.customers(id),
  source VARCHAR(10) NOT NULL CHECK (source IN ('internal','portal')),
  status VARCHAR(20) NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','assigned','in_progress','resolved','closed')),
  priority VARCHAR(10) NOT NULL CHECK (priority IN ('low','medium','high','critical')),
  escalation_level SMALLINT NOT NULL DEFAULT 0 CHECK (escalation_level BETWEEN 0 AND 2),  -- AM→AD→BOD
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),
  assignee_id UUID REFERENCES core_identity.users(id),         -- OPS_CONT queue
  campaign_id UUID REFERENCES erp_ops.campaigns(id),           -- context
  ad_account_id UUID REFERENCES erp_ops.ad_accounts(id),
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_ticket_status_assignee ON erp_ops.tickets(status, assignee_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_ticket_sla ON erp_ops.tickets(priority, escalation_level);
CREATE TABLE erp_ops.ticket_assignment_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES erp_ops.tickets(id),
  from_user_id UUID REFERENCES core_identity.users(id),
  to_user_id UUID NOT NULL REFERENCES core_identity.users(id),
  assigned_by UUID NOT NULL,
  assigned_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- TBL-ERP-040 | REQ-OPS-010 | FEAT-ERP-CPORT-001 — Lệnh cấp/thu hồi portal account (Day 14)
CREATE TABLE erp_ops.portal_account_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES erp_sales.customers(id),
  action VARCHAR(10) NOT NULL CHECK (action IN ('provision','revoke')),
  status VARCHAR(15) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','done','failed')),
  requested_by UUID NOT NULL REFERENCES core_identity.users(id),  -- OPS_AM
  portal_ref VARCHAR(100),                           -- portal_user id bên SYS-PORTAL-WEB
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
-- TBL-ERP-041 | REQ-OPS-006 | FEAT-ERP-CAMP-001 — Activity domain ops
CREATE TABLE erp_ops.ops_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  object_type VARCHAR(20) NOT NULL CHECK (object_type IN ('ad_account','proposal','campaign','deliverable','ticket','portal_request')),
  object_id UUID NOT NULL,
  activity_type VARCHAR(40) NOT NULL,
  actor_id UUID REFERENCES core_identity.users(id),
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_opsact_object ON erp_ops.ops_activities(object_type, object_id, created_at DESC);
```

#### 3.4. Schema `erp_people` (COMP-ERP-005) — FEAT-ERP-HRCORE-*, FEAT-ERP-CAPTS-*, FEAT-ERP-KPI-*

```sql
-- TBL-ERP-042 | REQ-HR-001/REQ-HR-010 | FEAT-ERP-HRCORE-001 — Hồ sơ L1–L5 (SSOT), PII lương Restricted
CREATE TABLE erp_people.employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES core_identity.users(id),  -- CROSS-SCHEMA FK
  employee_code VARCHAR(20) UNIQUE NOT NULL,
  level VARCHAR(3) NOT NULL,                         -- L1–L5
  role_code VARCHAR(30) NOT NULL,                    -- mã vai (mapping 18 vai chuẩn)
  track VARCHAR(20) NOT NULL,                        -- Sales|BusinessOps|HCNS|MarketingCreative
  dept VARCHAR(20) NOT NULL,
  salary_base DECIMAL(18,2),                         -- Confidential/Restricted — field-level security (RBAC CORE) + masking trước ETL
  hr_owner_id UUID NOT NULL REFERENCES core_identity.users(id), -- HR_L1
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);

-- TBL-ERP-043 | REQ-HR-002 | FEAT-ERP-HRCORE-002 — HĐLĐ expiry 90/60/30
CREATE TABLE erp_people.employment_contracts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES erp_people.employees(id),
  status VARCHAR(15) NOT NULL DEFAULT 'active' CHECK (status IN ('active','expiring','renewed','expired')),
  end_date DATE NOT NULL,
  document_uri VARCHAR(500)
);
CREATE INDEX idx_contract_end ON erp_people.employment_contracts(end_date) WHERE status IN ('active','expiring');

-- TBL-ERP-044 | REQ-HR-003 | FEAT-ERP-HRCORE-003 — Chấm công + overtime
CREATE TABLE erp_people.attendance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES erp_people.employees(id),
  work_date DATE NOT NULL,
  check_in_at TIMESTAMPTZ, check_out_at TIMESTAMPTZ,
  overtime_minutes SMALLINT NOT NULL DEFAULT 0,
  source VARCHAR(10) NOT NULL DEFAULT 'web' CHECK (source IN ('web','mobile')),
  UNIQUE (employee_id, work_date)
);

-- TBL-ERP-045/046 | REQ-HR-004 | FEAT-ERP-HRCORE-004 — Nghỉ phép + số dư
CREATE TABLE erp_people.leave_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES erp_people.employees(id),
  status VARCHAR(20) NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','balance_check','hr_l1_approval','hr_l2_approval','approved','rejected')),
  start_date DATE NOT NULL, end_date DATE NOT NULL, days DECIMAL(4,1) NOT NULL,
  approver_l1_id UUID REFERENCES core_identity.users(id),
  approver_l2_id UUID REFERENCES core_identity.users(id),
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE TABLE erp_people.leave_balances (
  employee_id UUID REFERENCES erp_people.employees(id),
  year SMALLINT NOT NULL,
  entitled_days DECIMAL(5,1) NOT NULL, used_days DECIMAL(5,1) NOT NULL DEFAULT 0,
  PRIMARY KEY (employee_id, year)
);

-- TBL-ERP-047 | REQ-HR-006 | FEAT-ERP-HRCORE-006 — Rate card version hóa + thẩm định FIN
CREATE TABLE erp_people.rate_card_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES erp_people.employees(id),
  version_no SMALLINT NOT NULL,
  hourly_cost DECIMAL(18,2) NOT NULL,
  status VARCHAR(15) NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','fin_endorsed','effective','superseded')),   -- endorse: FIN_L1
  effective_from DATE NOT NULL, effective_to DATE,
  UNIQUE (employee_id, version_no)
);

-- TBL-ERP-048/049 | REQ-OPS-007/REQ-HR-009 | FEAT-ERP-CAPTS-001/002 — Timesheet + duyệt song song
CREATE TABLE erp_people.timesheets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES erp_people.employees(id),
  work_date DATE NOT NULL,
  hours DECIMAL(4,2) NOT NULL CHECK (hours > 0 AND hours <= 24),
  billable BOOLEAN NOT NULL DEFAULT TRUE,
  campaign_id UUID REFERENCES erp_ops.campaigns(id),
  status VARCHAR(20) NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','submitted','reviewed','approved','capacity_computed','rejected')),
  owner_id UUID NOT NULL REFERENCES core_identity.users(id),
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_ts_emp_date ON erp_people.timesheets(employee_id, work_date);
CREATE INDEX idx_ts_status ON erp_people.timesheets(status, work_date);
CREATE TABLE erp_people.timesheet_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  timesheet_id UUID NOT NULL REFERENCES erp_people.timesheets(id),
  channel VARCHAR(10) NOT NULL CHECK (channel IN ('ops','hr')),   -- duyệt song song 2 phòng
  approver_id UUID REFERENCES core_identity.users(id),
  decision VARCHAR(10) CHECK (decision IN ('approved','rejected','pending')),
  decided_at TIMESTAMPTZ,
  UNIQUE (timesheet_id, channel)                     -- 2 chân duyệt độc lập
);

-- TBL-ERP-050 | REQ-OPS-007 | FEAT-ERP-CAPTS-002 — Capacity snapshots (vàng 90%/đỏ 100%)
CREATE TABLE erp_people.capacity_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES erp_people.employees(id),
  snapshot_date DATE NOT NULL,
  utilization_percent DECIMAL(5,2) NOT NULL,         -- >=90 vàng, >=100 đỏ
  computed_by_job VARCHAR(60),
  UNIQUE (employee_id, snapshot_date)
);

-- TBL-ERP-051..054 | REQ-HR-007/008 | FEAT-ERP-KPI-001/002 — KPI 3 trụ cột + PIP 30-60-90
CREATE TABLE erp_people.kpi_periods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period VARCHAR(7) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'auto_aggregate'
    CHECK (status IN ('auto_aggregate','calibration','finalized')),
  finalized_by UUID REFERENCES core_identity.users(id)   -- HR_L2
);
CREATE TABLE erp_people.kpi_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kpi_period_id UUID NOT NULL REFERENCES erp_people.kpi_periods(id),
  employee_id UUID NOT NULL REFERENCES erp_people.employees(id),
  pillar VARCHAR(20) NOT NULL CHECK (pillar IN ('delivery','sales','people')),  -- 3 trụ cột
  score DECIMAL(6,2), source_module VARCHAR(20) NOT NULL,       -- CAPTS|COMM|CRM
  UNIQUE (kpi_period_id, employee_id, pillar)
);
CREATE TABLE erp_people.pip_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES erp_people.employees(id),
  status VARCHAR(15) NOT NULL DEFAULT 'triggered'
    CHECK (status IN ('triggered','active','closed')),
  start_date DATE NOT NULL, owner_id UUID NOT NULL REFERENCES core_identity.users(id)  -- HR_L2
);
CREATE TABLE erp_people.pip_checkpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pip_plan_id UUID NOT NULL REFERENCES erp_people.pip_plans(id),
  checkpoint VARCHAR(3) NOT NULL CHECK (checkpoint IN ('30','60','90')),
  result VARCHAR(10) CHECK (result IN ('pass','fail','pending')),
  note TEXT
);
-- TBL-ERP-055 | REQ-HR-001 — Activity domain people (PII: KHÔNG ghi lương vào payload)
CREATE TABLE erp_people.people_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  object_type VARCHAR(20) NOT NULL CHECK (object_type IN ('employee','contract','leave','rate_card','timesheet','kpi','pip')),
  object_id UUID NOT NULL,
  activity_type VARCHAR(40) NOT NULL,
  actor_id UUID REFERENCES core_identity.users(id),
  payload JSONB,                                     -- cấm chứa trường PII Restricted
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
```

#### 3.5. Schema `erp_sla` (COMP-ERP-006/007) — FEAT-ERP-SLANOT-001 + jobs

```sql
-- TBL-ERP-056 | REQ-OPS-008/REQ-BOD-009 | FEAT-ERP-SLANOT-001 — SLA policy tier×priority GMT+7
CREATE TABLE erp_sla.sla_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  object_type VARCHAR(20) NOT NULL,                  -- ticket|deliverable|wallet|handoff|ar_invoice
  customer_tier VARCHAR(2) NOT NULL CHECK (customer_tier IN ('A','B','C','D','E')),
  priority VARCHAR(10) NOT NULL CHECK (priority IN ('low','medium','high','critical')),
  warn_after_minutes INT NOT NULL, breach_after_minutes INT NOT NULL,   -- VD wallet đỏ 2h
  escalation_path JSONB NOT NULL,                    -- AM→AD→BOD / ops escalation
  effective_from DATE NOT NULL, effective_to DATE,   -- effective-dated (REQ-BOD-009)
  UNIQUE (object_type, customer_tier, priority, effective_from)
);
-- TBL-ERP-057 | REQ-OPS-008 | FEAT-ERP-SLANOT-001 — Timer persist (sống qua restart)
CREATE TABLE erp_sla.sla_timers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  object_type VARCHAR(20) NOT NULL, object_id UUID NOT NULL,
  policy_id UUID NOT NULL REFERENCES erp_sla.sla_policies(id),
  state VARCHAR(10) NOT NULL DEFAULT 'running' CHECK (state IN ('running','warned','breached','cancelled')),
  started_at TIMESTAMPTZ NOT NULL, warn_at TIMESTAMPTZ NOT NULL, breach_at TIMESTAMPTZ NOT NULL,
  tz VARCHAR(20) NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
  UNIQUE (object_type, object_id, state)
);
CREATE INDEX idx_timer_breach ON erp_sla.sla_timers(breach_at) WHERE state = 'running';
-- TBL-ERP-058 | REQ-OPS-008 | FEAT-ERP-SLANOT-001 — Notification log (idempotent, đa kênh [NEEDS_REVIEW: kênh ngoài in-app])
CREATE TABLE erp_sla.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  object_type VARCHAR(20), object_id UUID,
  channel VARCHAR(20) NOT NULL,                      -- in-app|email|sms|ott [NEEDS_REVIEW]
  recipient_id UUID NOT NULL REFERENCES core_identity.users(id),
  template_key VARCHAR(60) NOT NULL,
  idempotency_key UUID NOT NULL UNIQUE,
  status VARCHAR(10) NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','failed','retrying','dead')),
  sent_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
-- TBL-ERP-059/060/061 | REQ-FIN-004/006, REQ-OPS-008 | FEAT-ERP-WALLET-004/005 — Job registry/runs/DLQ
CREATE TABLE erp_sla.job_registry (
  job_key VARCHAR(60) PRIMARY KEY,                   -- recon_3way|hardstop_sweep|aging_dunning|contract_expiry|kpi_aggregate|clawback_sweep|capacity_compute|tier_review|handoff_checkpoint|period_close_checklist
  owner_module VARCHAR(20) NOT NULL,
  cron_expr VARCHAR(40) NOT NULL, enabled BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE erp_sla.job_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_key VARCHAR(60) NOT NULL REFERENCES erp_sla.job_registry(job_key),
  window_key VARCHAR(40) NOT NULL,                   -- idempotency: (job, window) — re-run an toàn
  status VARCHAR(10) NOT NULL DEFAULT 'running' CHECK (status IN ('running','success','failed','skipped')),
  triggered_by VARCHAR(30) NOT NULL DEFAULT 'system',  -- system|manual (SYS_ADMIN)
  result_summary JSONB,
  started_at TIMESTAMPTZ DEFAULT NOW() NOT NULL, finished_at TIMESTAMPTZ,
  UNIQUE (job_key, window_key)
);
CREATE TABLE erp_sla.job_dead_letters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_key VARCHAR(60), event_topic VARCHAR(60), payload JSONB NOT NULL,
  reason TEXT NOT NULL,
  status VARCHAR(10) NOT NULL DEFAULT 'open' CHECK (status IN ('open','replayed','discarded')),
  replayed_by UUID REFERENCES core_identity.users(id),   -- hành động người, không auto-replay
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
-- TBL-ERP-062 | P3-01 §5 | FEAT-ERP-COMM-001 — Outbox (event contract, publisher-side)
CREATE TABLE erp_sla.outbox_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic VARCHAR(60) NOT NULL,                        -- wallet.matched|deal.signed|...
  payload JSONB NOT NULL, event_id UUID NOT NULL UNIQUE,
  published_at TIMESTAMPTZ, created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
```

> Bảng phụ thuộc (configs/lookup) tóm gọn, không DDL chi tiết: `erp_sales.discount_limit_matrix` (định mức theo tier, effective-dated), `erp_sales.lead_score_weights` (K1–K12), `erp_finance.tax_obligation_configs` (REQ-FIN-014), `erp_ops.ad_account_name_rules` (naming/UTM), `erp_people.leave_policy_configs` (nghỉ phép theo level), `erp_people.kpi_pillar_weights` — đều theo pattern effective-dated + created_by/updated_by.

### 4. Common Patterns

- **Auto-generate code:** sequence per bảng (`leads_code_seq` → `LD-000001`) theo template §4.
- **Auto `updated_at`:** trigger dùng chung `update_updated_at_column()` theo template §4, áp cho mọi bảng có `updated_at`.
- **Soft delete:** mọi query thêm `WHERE deleted_at IS NULL`; riêng `wallet_journal`, `wallet_journal_lines`, `hard_stop_confirmations`, `erp_sla.job_runs`, `*_activities` **bất biến** — không soft delete (cơ sở đối soát + audit).
- **Optimistic locking:** money command dùng cột `updated_at` làm version check; conflict → 409 `INVALID_STATE`.
- **SOD constraint:** `approver1_id <> approver2_id` và chuỗi `payment_order_approvals` không trùng `approver_id` — enforce ở approval engine (app layer) + job validate định kỳ (không dùng trigger cứng vì có delegate — [NEEDS_REVIEW: delegate map ở DB hay policy service]).

### 5. Migration Strategy

Theo template §5: `migrations/[YYYYMMDDHHMMSS]_[description].sql`, 1 DDL/migration, UP + DOWN, không sửa migration đã chạy production. Riêng hệ này: (1) migration schema tiền phải chạy trong maintenance window (không có lệnh tiền đang bay); (2) bật `pg_dump` backup trước migration production; (3) state machine CHECK constraint thay đổi = migration riêng kèm data backfill trạng thái trước khi siết CHECK.

### 6. Index Strategy

| Loại | Pattern áp dụng |
|------|-----------------|
| Status filter | Partial `WHERE deleted_at IS NULL` trên mọi bảng workflow (idx_leads_status_owner, idx_po_status, idx_ticket_status_assignee...) |
| Composite lọc phổ biến | `(status, owner_id)`, `(status, aging_bucket, due_date)`, `(platform, status)`, `(employee_id, work_date)` |
| FK index | Mọi FK column (template §6) |
| Full-text search | GIN `to_tsvector('simple', company_name || contact_name)` trên `leads`, `customers` |
| Unique business | `uq_leads_fingerprint` (anti-duplicate), `UNIQUE(customer_id, currency)` (wallet), `UNIQUE(job_key, window_key)` (idempotency job), `idempotency_key` (money command) |
| Timer/queue scan | `idx_timer_breach (breach_at) WHERE state='running'`, `idx_wallets_low`, `idx_dlvr_acceptance_due` |

## Hệ thống: SYS-CORE-BACKEND — Core Backend

## Database Design — SYS-CORE-BACKEND (Core Backend)

> Session: 20260913-053848-f4d7 | Lane: core-backend | TRIO: architect + dba + devops
> READS: `phase2-features/core-backend/rbac-audit/*.md`, `phase2-features/core-backend/datahub-bi/*.md`, `P3-01-architecture.md` (§1, §3, §4, §10), `lanes/core-backend/arch-draft.md`
> OUTPUT: DDL, indexes, migration strategy cho 3 schema `core_identity`, `core_audit`, `core_dhub`
> USED BY: `phase5-implementation/tasks/core-backend/*`
> DATE: 2026-09-13 | DB: PostgreSQL 16 (OLTP) + ClickHouse (đề xuất — OLAP warehouse)
>
> **Scope guard:** chỉ MOD-RBAC-AUDIT + MOD-DATAHUB-BI. Bảng business object (lead, ví, lệnh chi, TKQC...) thuộc schema `erp_*` do lane SYS-BCERP-WEB sở hữu — Core chỉ giữ bản sao phân tích trong warehouse, không FK chéo sang schema business.

---

> **ID format:** `TBL-CORE-NNN` tăng dần toàn system. Mỗi table SQL comment phải có TBL-ID + REQ-ID + FEAT-ID tương ứng.

### 1. Schema Organization

| Schema | System | Mục đích |
|--------|--------|---------|
| `core_identity` | SYS-CORE-BACKEND (MOD-RBAC-AUDIT) | Định danh, MFA, session, vai/permission/policy, access review |
| `core_audit` | SYS-CORE-BACKEND (MOD-RBAC-AUDIT) | Audit log hash-chain append-only, WORM evidence ref, PII classification |
| `core_dhub` | SYS-CORE-BACKEND (MOD-DATAHUB-BI) | Contract registry, ingest run/DLQ, layout warehouse, alert rules/instances |

Quyết định phân chia: template mặc định để `users/roles/permissions` ở schema `public`, nhưng theo P3-01 §3 Core Backend sở hữu identity — nên toàn bộ đặt trong `core_identity`, schema `public` để trống (không có bảng dùng chung xuyên system; các system khác KHÔNG join thẳng vào `core_*` — chỉ qua API, P3-01 §4).

Naming chuẩn template: table snake_case plural, cột snake_case, index `idx_[table]_[cols]`, FK `fk_[table]_[ref]`. UUID v4 PK; timestamp `TIMESTAMPTZ` UTC.

### 2. Shared Tables (schema: public)

Không có. Lý do xem §1.

### 3. CORE-BACKEND Tables

#### Module: RBAC & Audit Log — schema `core_identity`

##### 3.1 Identity, MFA, Session (COMP-CORE-001)

```sql
-- TBL-CORE-001 | REQ-BOD-011 | FEAT-CORE-RBAC-005
CREATE TABLE core_identity.users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_code VARCHAR(20) UNIQUE,                -- map hồ sơ HR (SSOT HR-CORE qua ingest)
  email         VARCHAR(255) UNIQUE NOT NULL,
  full_name     VARCHAR(200) NOT NULL,
  dept_code     VARCHAR(20)  NOT NULL,             -- DEPT-BOD/HR/FIN/SALES/OPS
  idp_subject   VARCHAR(128) UNIQUE,               -- Keycloak sub (nội bộ realm)
  status        VARCHAR(20) DEFAULT 'probation' NOT NULL
                CHECK (status IN ('probation','active','suspended','locked','deactivated')),
  is_portal_user BOOLEAN DEFAULT false,            -- realm portal (OTP) — user portal do PORTAL-WEB sở hữu hồ sơ vận hành, Core giữ identity mapping
  tenant_id     UUID,                              -- chỉ portal user
  last_login_at TIMESTAMPTZ,
  created_by    UUID, created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at    TIMESTAMPTZ                        -- soft delete; user có audit lịch sử không xóa cứng
);
CREATE INDEX idx_users_dept_status ON core_identity.users(dept_code, status) WHERE deleted_at IS NULL;

-- TBL-CORE-002 | REQ-BOD-011 | FEAT-CORE-RBAC-005
CREATE TABLE core_identity.mfa_enrollments (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES core_identity.users(id) ON DELETE CASCADE,
  method         VARCHAR(20) NOT NULL DEFAULT 'totp'  -- [NEEDS_REVIEW: TOTP/passkey/hardware key]
                  CHECK (method IN ('totp','passkey','hardware_key','sms_otp')),
  secret_ciphertext BYTEA,                          -- TOTP secret mã hóa envelope KMS, không lưu clear
  kms_key_id     VARCHAR(200),                      -- KMS data-key id (đối chiếu TBL-GW-002.key_id) — rotate key không phải re-encrypt mù
  key_version    INT NOT NULL DEFAULT 1,            -- version data-key cho re-encrypt chọn lọc
  confirmed_at   TIMESTAMPTZ, revoked_at TIMESTAMPTZ,
  created_at     TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (user_id, method)
);

-- TBL-CORE-003 | REQ-BOD-011 | FEAT-CORE-RBAC-005
CREATE TABLE core_identity.sessions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES core_identity.users(id) ON DELETE CASCADE,
  refresh_token_hash CHAR(64) NOT NULL,            -- SHA-256, rotate mỗi refresh
  ip_address     INET, user_agent TEXT,
  amr            VARCHAR(50) NOT NULL,              -- pwd | pwd+mfa | mfa_step_up
  step_up_until  TIMESTAMPTZ,                       -- hạn hiệu lực step-up (5 phút)
  expires_at     TIMESTAMPTZ NOT NULL,
  revoked_at     TIMESTAMPTZ, revoked_reason VARCHAR(50),
  created_at     TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_sessions_user_active ON core_identity.sessions(user_id)
  WHERE revoked_at IS NULL AND expires_at > NOW();
```

##### 3.2 RBAC 4 chiều — Role × Permission × Dept × Data-scope (COMP-CORE-002)

```sql
-- TBL-CORE-004 | REQ-BOD-011 | FEAT-CORE-RBAC-005
CREATE TABLE core_identity.roles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        VARCHAR(30) UNIQUE NOT NULL,   -- BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1... 
              -- [NEEDS_REVIEW: chốt danh mục đủ 18 vai — Phụ lục A #8]
  dept_code   VARCHAR(20) NOT NULL,          -- vai gắn phòng ban
  is_finance_sensitive BOOLEAN DEFAULT false,-- vai tài chính → MFA bắt buộc
  is_infra_sensitive   BOOLEAN DEFAULT false,-- vai hạ tầng/vault (CTO) → WORM + access review
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL, updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at  TIMESTAMPTZ
);

-- TBL-CORE-005 | REQ-BOD-011 | FEAT-CORE-RBAC-005
CREATE TABLE core_identity.permissions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource       VARCHAR(80) NOT NULL,        -- 'payment-order', 'ad-account', 'audit'
  action         VARCHAR(40) NOT NULL,        -- view/approve/adjust/lock/export/transition
  state_guard    JSONB,                       -- trạng thái object hợp lệ, VD ["draft","dual_approval"]
  UNIQUE (resource, action)
);

-- TBL-CORE-006 | REQ-BOD-011 | FEAT-CORE-RBAC-005 — chiều 1-2: Role × Permission
CREATE TABLE core_identity.role_permissions (
  role_id       UUID REFERENCES core_identity.roles(id) ON DELETE CASCADE,
  permission_id UUID REFERENCES core_identity.permissions(id) ON DELETE CASCADE,
  policy_version_id UUID REFERENCES core_identity.policy_versions(id), -- gắn version policy
  PRIMARY KEY (role_id, permission_id)
);

-- TBL-CORE-007 | REQ-BOD-002, REQ-BOD-011 | FEAT-CORE-RBAC-001, 005 — chiều 3-4 + cờ kiêm nhiệm
CREATE TABLE core_identity.user_roles (
  user_id        UUID REFERENCES core_identity.users(id) ON DELETE CASCADE,
  role_id        UUID REFERENCES core_identity.roles(id) ON DELETE CASCADE,
  dept_code      VARCHAR(20) NOT NULL,                    -- chiều 3: phòng ban hiệu lực
  data_scope     VARCHAR(20) DEFAULT 'own-dept' NOT NULL  -- chiều 4: all | own-dept | own-objects
                 CHECK (data_scope IN ('all','own-dept','own-objects')),
  combined_role  BOOLEAN DEFAULT false NOT NULL,          -- compensating control REQ-BOD-002:
                 -- 1 người giữ cả vai is_finance_sensitive + is_infra_sensitive
                 -- → PDP buộc dual approval cứng khác người + mọi thao tác ghi WORM
  state          VARCHAR(20) DEFAULT 'pending_approve' NOT NULL
                 CHECK (state IN ('pending_approve','active','revoked')),
  approved_by    UUID REFERENCES core_identity.users(id), -- BOD_CEO duyệt gán/thu hồi
  effective_from TIMESTAMPTZ, effective_to TIMESTAMPTZ,
  granted_by     UUID REFERENCES core_identity.users(id),
  created_at     TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  PRIMARY KEY (user_id, role_id, dept_code)
);
CREATE INDEX idx_user_roles_active ON core_identity.user_roles(user_id) WHERE state = 'active';
```

Bảng phụ (DDL đầy đủ theo pattern chuẩn — cột chính liệt kê):

| TBL-ID | Table | Cột chính | REQ/FEAT |
|--------|-------|-----------|----------|
| TBL-CORE-008 | `core_identity.role_assignment_approvals` | user_id, role_id, action (grant/revoke), requested_by, approver_id (BOD_CEO), state (pending/approved/rejected), decided_at | REQ-BOD-007 / FEAT-CORE-RBAC-003 |
| TBL-CORE-009 | `core_identity.policy_versions` | policy_key, version, body JSONB (ngưỡng 5/50/200tr, tier, capacity vàng/đỏ, mask rule), state (draft→submitted→approved→activated→superseded), effective_from/to | REQ-BOD-009 / FEAT-CORE-RBAC-004 |
| TBL-CORE-010 | `core_identity.policy_approvals` | policy_version_id, approver_id, stage (1/2 — dual approval khác người), mfa_verified, decided_at | REQ-BOD-009 / FEAT-CORE-RBAC-004 |
| TBL-CORE-011 | `core_identity.sod_rules` | rule_key, conflicting_role_a/b (hoặc resource+action cấm cùng người), kind (sod_pairs | no_self_approve | dual_approval_required), threshold VND, enabled | REQ-BOD-002, REQ-FIN-008 / FEAT-CORE-RBAC-001 |
| TBL-CORE-012 | `core_identity.delegate_map` | principal_id, delegate_id, scope (approval-class), valid_from/to — delegate khi CFO kiêm CTO vắng [NEEDS_REVIEW: cơ chế] | REQ-BOD-002 / FEAT-CORE-RBAC-001 |
| TBL-CORE-013 | `core_identity.access_review_campaigns` | period (YYYY-QN), state (open→in_review→closed), opened_at, closed_at, evidence_ref → WORM | REQ-BOD-007 / FEAT-CORE-RBAC-003 |
| TBL-CORE-014 | `core_identity.access_review_items` | campaign_id, user_id, role_id, sensitivity (normal/privileged_vault/restricted_pii), reviewer_id, decision (approve/revoke/extend), reason, decided_at | REQ-BOD-007 / FEAT-CORE-RBAC-003 |

#### Module: RBAC & Audit Log — schema `core_audit`

##### 3.3 Audit hash-chain + WORM (COMP-CORE-004, 005)

```sql
-- TBL-CORE-015 | REQ-BOD-005, REQ-FIN-012 | FEAT-CORE-RBAC-002, 007 — APPEND-ONLY
CREATE TABLE core_audit.audit_log (
  seq_no        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id      UUID NOT NULL DEFAULT gen_random_uuid(),
  occurred_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  actor_id      UUID, actor_roles TEXT[],           -- null = system:<job_or_event>
  action        VARCHAR(80) NOT NULL,               -- state.transition, pii.read, auth.login...
  object_type   VARCHAR(60) NOT NULL, object_id    VARCHAR(64) NOT NULL,
  system_origin VARCHAR(30) NOT NULL,               -- SYS-CORE-BACKEND, SYS-BCERP-WEB...
  before_state  JSONB, after_state JSONB,
  ip_address    INET, correlation_id VARCHAR(64),
  record_class  VARCHAR(30) NOT NULL DEFAULT 'operational'
                CHECK (record_class IN ('operational','financial','evidence')),
                -- financial/evidence → đẩy WORM ≥10 năm (REQ-FIN-012);
                -- operational giữ ≥3 năm [NEEDS_REVIEW: chưa có căn cứ registry]
  prev_hash     CHAR(64) NOT NULL,
  entry_hash    CHAR(64) NOT NULL,                  -- SHA-256(prev_hash || canonical(payload))
  -- Không updated_at/deleted_at: append-only tuyệt đối
  UNIQUE (event_id)
);
CREATE INDEX idx_audit_object  ON core_audit.audit_log(object_type, object_id, occurred_at);
CREATE INDEX idx_audit_actor   ON core_audit.audit_log(actor_id, occurred_at);
CREATE INDEX idx_audit_class   ON core_audit.audit_log(record_class, occurred_at);
-- Bất biến tầng DB:
CREATE OR REPLACE FUNCTION core_audit.forbid_mutation() RETURNS trigger AS $$
BEGIN RAISE EXCEPTION 'AUDIT_IMMUTABLE: audit_log is append-only'; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_audit_immutable BEFORE UPDATE OR DELETE ON core_audit.audit_log
  FOR EACH ROW EXECUTE FUNCTION core_audit.forbid_mutation();
```

| TBL-ID | Table | Cột chính | REQ/FEAT |
|--------|-------|-----------|----------|
| TBL-CORE-016 | `core_audit.audit_export_requests` | requested_by, filter JSONB (khoảng time/object), state (requested→approved→exported→delivered), approver_id (BOD_CEO), evidence_ref | REQ-BOD-005, REQ-FIN-012 / FEAT-CORE-RBAC-002, 007 |
| TBL-CORE-017 | `core_audit.worm_evidence_refs` | object_key (S3), object_lock_mode ('compliance'), retention_until (**≥10 năm** với record_class=financial/evidence — REQ-FIN-012), legal_hold BOOLEAN, sha256, last_verified_at | REQ-FIN-012 / FEAT-CORE-RBAC-007 |
| TBL-CORE-020 | `core_audit.pii_access_log` | user_id, field_path, classification, decision (masked/plain/break_glass), request_id, accessed_at | REQ-HR-010 / FEAT-CORE-RBAC-006 |

##### 3.4 PII classification (COMP-CORE-006)

```sql
-- TBL-CORE-018 | REQ-HR-010 | FEAT-CORE-RBAC-006
CREATE TABLE core_audit.pii_classifications (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  system_origin VARCHAR(30) NOT NULL,               -- hệ nguồn sở hữu field
  object_type   VARCHAR(60) NOT NULL, field_path   VARCHAR(120) NOT NULL,
  level         VARCHAR(20) NOT NULL
                CHECK (level IN ('public','internal','confidential','restricted')),
  tier          VARCHAR(10),                        -- C1/C2/C3/T1–T4 (FEAT-CORE-RBAC-005)
  encryption_required BOOLEAN DEFAULT false,        -- envelope KMS field-level
  mask_by_default     BOOLEAN DEFAULT true,         -- mask trừ vai được cấp
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL, updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (system_origin, object_type, field_path)
);

-- TBL-CORE-019 | REQ-HR-010 | FEAT-CORE-RBAC-006
CREATE TABLE core_audit.pii_mask_configs (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  classification_id UUID REFERENCES core_audit.pii_classifications(id),
  viewer_role    VARCHAR(30) NOT NULL,              -- vai được thấy rõ, VD HR_L1/HR_L2
  reveal_mode    VARCHAR(20) DEFAULT 'masked' NOT NULL CHECK (reveal_mode IN ('plain','masked','hidden')),
  approved_by_hr BOOLEAN DEFAULT false,             -- HR_L2 đồng duyệt với PII lương
  updated_at     TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (classification_id, viewer_role)
);
```

#### Module: Data Integration Hub & BI — schema `core_dhub`

##### 3.5 Contract registry + ingest run (COMP-CORE-007)

```sql
-- TBL-CORE-021 | REQ-BOD-003, REQ-FIN-005 | FEAT-CORE-DHUB-001 — contract-first
CREATE TABLE core_dhub.ingestion_contracts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_system   VARCHAR(30) NOT NULL,             -- SYS-BCERP-WEB | SYS-INTEGRATION-GW | ...
  source_object   VARCHAR(80) NOT NULL,             -- wallet_entries, timesheets, statements...
  transport       VARCHAR(20) NOT NULL CHECK (transport IN ('cdc','event','pull_batch')),
  schema_version  VARCHAR(20) NOT NULL,
  schema_body     JSONB NOT NULL,                   -- JSON Schema, compatibility mode backward
  natural_key     TEXT[] NOT NULL,                  -- idempotency + dedup (gate G1)
  pii_scan        BOOLEAN DEFAULT true,             -- gate G2 qua COMP-CORE-006
  compat_mode     VARCHAR(20) DEFAULT 'backward' CHECK (compat_mode IN ('backward','none')),
  state           VARCHAR(20) DEFAULT 'active' CHECK (state IN ('draft','active','deprecated')),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (source_system, source_object, schema_version)
);

-- TBL-CORE-022 | REQ-BOD-003 | FEAT-CORE-DHUB-001
CREATE TABLE core_dhub.ingest_runs (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  contract_id    UUID REFERENCES core_dhub.ingestion_contracts(id),
  window_start   TIMESTAMPTZ, window_end TIMESTAMPTZ,
  watermark      JSONB,                             -- LSN/offset per partition — replay từ vị trí
  records_in     BIGINT DEFAULT 0, records_ok BIGINT DEFAULT 0,
  records_dedup  BIGINT DEFAULT 0, records_reject BIGINT DEFAULT 0,
  gate_summary   JSONB,                             -- G0–G5 pass/fail per gate (P3-01 §10.4)
  dlq_count      BIGINT DEFAULT 0,
  state          VARCHAR(20) DEFAULT 'running'
                 CHECK (state IN ('running','completed','failed','partial')),
  started_at TIMESTAMPTZ DEFAULT NOW() NOT NULL, finished_at TIMESTAMPTZ
);
CREATE INDEX idx_ingest_runs_contract ON core_dhub.ingest_runs(contract_id, started_at DESC);

-- TBL-CORE-023 | REQ-BOD-003 | FEAT-CORE-DHUB-001 — DLQ không auto-replay
CREATE TABLE core_dhub.ingest_dlq (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  contract_id UUID, run_id BIGINT, reason VARCHAR(40),      -- gate_g0_contract, schema_drift...
  payload JSONB NOT NULL, first_seen_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  replayed_run_id BIGINT, replayed_at TIMESTAMPTZ            -- replay là hành động người (audit)
);
```

##### 3.6 Warehouse layout registry (COMP-CORE-008 — OLAP ClickHouse, đề xuất)

Metadata layout + freshness sống ở PostgreSQL; dữ liệu thật trong ClickHouse 3 lớp raw → staged → marts:

| TBL-ID | Table (PG) | Vai trò |
|--------|-----------|---------|
| TBL-CORE-024 | `core_dhub.warehouse_datasets` | Registry dataset per layer: dataset_name, layer (raw/staged/mart), engine DDL ref, partition_key (tháng), retention_policy (raw 2 năm / marts 5 năm — đề xuất [NEEDS_REVIEW]), owner_module, source_label_required (G3: nhãn api/manual immutable) |
| TBL-CORE-025 | `core_dhub.mart_publish_log` | mart_name, period, reconcile_result (stream vs batch nightly, lệch quá ngưỡng → alert [NEEDS_REVIEW: ngưỡng]), freshness metadata (last_watermark, loaded_at, freshness_sla, is_stale), publish_at |

Layout OLAP (ClickHouse) — marts chuẩn P3-01 §10.2:

```sql
-- Ví dụ mart chính (ClickHouse, nhân bản theo warehouse_datasets)
CREATE TABLE dhub_marts.pnl_realtime
( period_date Date, tenant_id Nullable(UUID), customer_id UUID, currency LowCardinality(String),
  revenue DECIMAL(18,2), platform_cost DECIMAL(18,2), commission_cost DECIMAL(18,2),
  labor_cost_approved DECIMAL(18,2), labor_cost_estimated_unapproved DECIMAL(18,2),
  source_label LowCardinality(String),  -- api | manual — tách realtime vs degraded (G4)
  last_watermark DateTime, loaded_at DateTime DEFAULT now() )
ENGINE = ReplacingMergeTree(loaded_at)
PARTITION BY toYYYYMM(period_date)
TTL toDateTime(loaded_at) + INTERVAL 5 YEAR;   -- marts 5 năm [NEEDS_REVIEW]
-- raw_* TTL 2 năm [NEEDS_REVIEW]; log tiền/chứng từ KHÔNG vào warehouse —
-- đi luồng audit hash-chain → WORM (REQ-FIN-012)
```

##### 3.7 Alert Center (COMP-CORE-011)

```sql
-- TBL-CORE-026 | REQ-BOD-006 | FEAT-CORE-DHUB-003
CREATE TABLE core_dhub.alert_rules (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key    VARCHAR(60) UNIQUE NOT NULL,   -- wallet.low_balance, recon.mismatch, sla.breach,
                                             -- shop.anomaly, dlq.depth, freshness.violation
  source_type VARCHAR(20) NOT NULL CHECK (source_type IN ('mart','event')),
  source_name VARCHAR(80) NOT NULL,          -- mart hoặc event name
  condition   JSONB NOT NULL,                -- VD {balance_days_coverage_lt: 3}
  severity    VARCHAR(10) NOT NULL CHECK (severity IN ('info','warning','critical')),
  dedup_window_minutes INT DEFAULT 30,       -- throttle
  state       VARCHAR(20) DEFAULT 'active' CHECK (state IN ('draft','active','disabled')),
  approved_by UUID,                          -- BOD_CEO duyệt tạo/sửa rule
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL, updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- TBL-CORE-027 | REQ-BOD-006 | FEAT-CORE-DHUB-003 — lifecycle không auto-close
CREATE TABLE core_dhub.alert_instances (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id      UUID REFERENCES core_dhub.alert_rules(id),
  dedup_key    VARCHAR(200) NOT NULL,        -- natural key throttle
  object_ref   JSONB,                        -- object bị alert (ví, đối soát, ticket...)
  severity     VARCHAR(10) NOT NULL,
  state        VARCHAR(20) DEFAULT 'open' NOT NULL
               CHECK (state IN ('open','acknowledged','investigating','resolved')),
  acknowledged_by UUID, acknowledged_at TIMESTAMPTZ,
  resolved_by  UUID, resolved_at TIMESTAMPTZ, resolution_note TEXT,
  notified_via VARCHAR(30),                  -- kênh dispatch qua MOD-SLA-NOTIF
  first_seen_at TIMESTAMPTZ DEFAULT NOW() NOT NULL, last_seen_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (rule_id, dedup_key)
);
CREATE INDEX idx_alerts_state ON core_dhub.alert_instances(state, severity, first_seen_at DESC);

-- TBL-CORE-028 | REQ-BOD-006 | FEAT-CORE-DHUB-003 — severity routing
CREATE TABLE core_dhub.alert_routing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  severity VARCHAR(10) NOT NULL, rule_key VARCHAR(60),
  notify_roles TEXT[] NOT NULL,              -- vai nhận, dispatch qua SLANOT
  channel_hint VARCHAR(30),                  -- gợi ý kênh — kênh cuối do SLANOT quyết
  escalation_after_minutes INT,              -- SLA đỏ 2h theo ma trận §5 business-context
  updated_by UUID, updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
```

### 4. Common Patterns

**Append-only + hash chain (TBL-CORE-015):** `entry_hash = SHA-256(prev_hash || canonical_json(record))`; insert trong transaction duy nhất qua đường ghi COMP-CORE-004; trigger cấm UPDATE/DELETE (lỗi `AUDIT_IMMUTABLE`); job verify định kỳ re-hash theo seq_no (API-CORE-032), lệch → alert HIGH + snapshot evidence sang WORM.

**Khác biệt soft delete:** chuẩn platform soft delete `deleted_at`; ngoại lệ — `audit_log` + `worm_evidence_refs` + `pii_access_log` không có cột soft delete (bất biến); `sessions`/`ingest_runs` dùng `revoked_at`/`finished_at` thay vì xóa.

**Row-level filter theo data-scope:** mọi list query của Core tự áp `data_scope` từ PDP (all/own-dept/own-objects) tại tầng repository; RLS PostgreSQL bắt buộc cho tenant portal (REQ-FIN-017) — core chỉ đọc tham chiếu, bản thân core_identity dùng filter application-level.

**Idempotency ingest:** `natural_key` trong contract + `event_id` unique; upsert theo natural key, drop trùng đếm metric (gate G1).

### 5. Migration Strategy

Chuẩn template: `migrations/[YYYYMMDDHHMMSS]_[description].sql`, 1 DDL/migration, UP+DOWN, test dev/staging trước prod, backup trước migration prod, không sửa migration đã chạy, không drop column ngay (deprecate → migrate → drop).

Riêng Core bổ sung 2 quy tắc:
1. **Contract registry migration phải song hành schema event:** đổi `ingestion_contracts.schema_version` phải deploy cùng release với module nguồn — compatibility gate trong CI module nguồn (P3-01 §10.5), không có migration schema drift một mình.
2. **Không bao giờ có migration ghi vào `audit_log`** (trừ tạo bảng/index); backfill dữ liệu audit lịch sử (nếu có) phải qua API append để giữ chuỗi hash liên tục.

### 6. Index Strategy

Theo chuẩn template (PK UUID, FK index, partial index `WHERE deleted_at IS NULL`, GIN full-text khi cần search). Bổ sung đặc thù:

| Table | Index | Lý do |
|-------|-------|-------|
| `audit_log` | `(object_type, object_id, occurred_at)`, `(actor_id, occurred_at)`, `(record_class, occurred_at)` | Query giám sát REQ-BOD-005 + timeline per object; partition theo tháng `occurred_at` khi >1 năm dữ liệu |
| `sessions` | partial `user_id WHERE revoked_at IS NULL AND expires_at > NOW()` | Thu hồi tức thời offboarding |
| `alert_instances` | `(state, severity, first_seen_at DESC)`, unique `(rule_id, dedup_key)` | Queue alert center + dedup |
| `ingest_runs` | `(contract_id, started_at DESC)` | Status + freshness per nguồn |
| `access_review_items` | `(campaign_id, reviewer_id, decision)` | Track tiến độ review quý |
| `user_roles` | partial `user_id WHERE state='active'` | PDP check nóng (cache 60s phía trên) |

## Hệ thống: SYS-INTEGRATION-GW — API Integration Gateway

## Database Design — SYS-INTEGRATION-GW

> READS: `phase2-features/integration-gw/settings-gw/*.md` (FEAT-GW-STGW-001/002), `phase2-features/integration-gw/tiktok-shop/tiktok-shop-monitoring.md` (FEAT-GW-TIKTOK-001), `P3-01-architecture.md`
> OUTPUT: DDL, indexes, migration strategy của SYS-INTEGRATION-GW
> USED BY: `phase5-implementation/tasks/integration-gw/`, `integration-map.md`
> DATE: 2026-09-13 | DB: PostgreSQL 16 | Scope: MOD-SETTINGS-GW (schema `gw_connector`) + MOD-TIKTOK-SHOP (schema `gw_tiktok`)

> ID format lane: `TBL-GW-NNN` (nối liên tục 2 schema để registry tra 1 dải).

---

### 1. Schema Organization

| Schema | System | Module | Mục đích |
|--------|--------|--------|---------|
| `gw_connector` | SYS-INTEGRATION-GW | MOD-SETTINGS-GW | Connector registry, credential vault, sync/ingest, nhãn nguồn, backfill, gateway audit |
| `gw_tiktok` | SYS-INTEGRATION-GW | MOD-TIKTOK-SHOP | Shop connection OAuth per-client, shop metrics `reference_only`, PII session, portal feed |

**Quy tắc naming:** tables snake_case plural; indexes `idx_[table]_[cols]`; FK `fk_[table]_[ref]`. RLS bật trên `gw_tiktok` (tenant isolation — BR-OPS-4.2b); `gw_connector` không tenant-scoped (nội bộ BOD/FIN, data-scope tầng app).

**Nguyên tắc bất biến:** (1) `source_label` (`api`/`manual`) gắn tại thời điểm ghi — REVOKE UPDATE trên cột; (2) `gateway_audit`, `shop_access_log` append-only hash-chain — trigger chặn UPDATE/DELETE; (3) raw payload chỉ lưu object-storage ref trong DB; (4) gateway KHÔNG lưu plaintext secret, KHÔNG persist PII đầy đủ.

---

### 2. Shared Tables

Không sở hữu bảng dùng chung — users/roles/policy của SYS-CORE-BACKEND, tham chiếu qua `user_id UUID` (không FK cross-system trừ audit hash node). Kết quả đối trừ 3 số, ledger ví, TKQC registry thuộc core/BCERP-WEB — gateway chỉ giữ bản ghi thô gắn nhãn.

---

### 3. GW Tables

#### 3.1. Module: Settings & Gateway Config (MOD-SETTINGS-GW, schema `gw_connector`)

##### connection_profile (TBL-GW-001)

```sql
-- TBL-GW-001 | REQ-ID: REQ-BOD-008 | FEAT-ID: FEAT-GW-STGW-001
-- State machine: configured → credentials_vaulted → active → degraded / disabled / revoked
CREATE TABLE gw_connector.connection_profile (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code            VARCHAR(30) UNIQUE NOT NULL,          -- CN-META-01, CN-VAS-01 (sequence)
  external_system VARCHAR(20) NOT NULL CHECK (external_system IN
                    ('META','GOOGLE','TIKTOK','BING','X','PINTEREST','YANDEX','VAS','OTHER')),
  display_name    VARCHAR(200) NOT NULL,                -- tên vendor là giá trị cấu hình (DI-004), không hardcode code
  connection_type VARCHAR(20) NOT NULL CHECK (connection_type IN ('api_adapter','import_export')),
  status          VARCHAR(30) NOT NULL DEFAULT 'configured' CHECK (status IN
                    ('configured','credentials_vaulted','active','degraded','disabled','revoked')),
  feed_state      VARCHAR(20) NOT NULL DEFAULT 'MANUAL' CHECK (feed_state IN ('MANUAL','API','BACKFILL')),
  owner_role      VARCHAR(30) NOT NULL DEFAULT 'BOD_CFO_CTO',
  config_json     JSONB NOT NULL DEFAULT '{}',          -- endpoint/env theo môi trường — không chứa secret
  revoked_at      TIMESTAMPTZ,
  last_error_code VARCHAR(50),
  created_by      UUID NOT NULL,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_conn_profile_status   ON gw_connector.connection_profile(status);
CREATE INDEX idx_conn_profile_system   ON gw_connector.connection_profile(external_system, status);
```

`feed_state` = trạng thái luồng dữ liệu (FEAT-GW-STGW-002) tách khỏi `status` hạ tầng adapter — một profile `active` vẫn có thể `BACKFILL`. Transition mọi cột state qua service layer + ghi TBL-GW-013.

##### credential_version (TBL-GW-002)

```sql
-- TBL-GW-002 | REQ-ID: REQ-BOD-008 | FEAT-ID: FEAT-GW-STGW-001
-- Envelope encryption: KMS master key + per-credential data key; plaintext không bao giờ ở DB
CREATE TABLE gw_connector.credential_version (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id     UUID NOT NULL REFERENCES gw_connector.connection_profile(id),
  version_no     INT NOT NULL,
  encrypted_ref  VARCHAR(500) NOT NULL,      -- object-storage/KMS ref của encrypted blob (không chứa blob)
  key_id         VARCHAR(200) NOT NULL,      -- KMS data-key id phục vụ rotate/thu hồi
  masked_value   VARCHAR(50) NOT NULL,       -- '****last4' — giá trị duy nhất UI/API được thấy
  status         VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','revoked','expired')),
  issued_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  rotate_due_at  TIMESTAMPTZ NOT NULL,       -- issued_at + ≥90 ngày; alert T-7; quá hạn >7d → adapter degraded
  revoked_at     TIMESTAMPTZ,
  revoked_reason TEXT,
  created_by     UUID NOT NULL,              -- BOD_CFO_CTO (MFA bắt buộc ở tầng service)
  UNIQUE (profile_id, version_no)
);
CREATE INDEX idx_cred_version_profile  ON gw_connector.credential_version(profile_id, status);
CREATE INDEX idx_cred_version_rotate   ON gw_connector.credential_version(status, rotate_due_at);
```

##### sync_schedule (TBL-GW-003) & sync_job (TBL-GW-004)

```sql
-- TBL-GW-003 | REQ-ID: REQ-BOD-008 | FEAT-ID: FEAT-GW-STGW-001
CREATE TABLE gw_connector.sync_schedule (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id     UUID NOT NULL REFERENCES gw_connector.connection_profile(id),
  cadence        VARCHAR(20) NOT NULL DEFAULT 'hourly',   -- hourly | weekly (nguồn không có API statement)
  batch_size     INT NOT NULL DEFAULT 100,
  queue_config   JSONB NOT NULL DEFAULT '{}',             -- concurrency, rate limit per quota nền tảng
  retry_policy   JSONB NOT NULL DEFAULT '{"maxAttempts":3,"backoff":"exponential"}',
  priority_rules JSONB NOT NULL DEFAULT '{}',             -- ưu tiên TKQC active chi tiêu khi không kịp cửa sổ
  is_enabled     BOOLEAN NOT NULL DEFAULT TRUE,
  approved_by    UUID NOT NULL, updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (profile_id)
);

-- TBL-GW-004 | REQ-ID: REQ-FIN-005 | FEAT-ID: FEAT-GW-STGW-002
CREATE TABLE gw_connector.sync_job (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id   UUID NOT NULL REFERENCES gw_connector.connection_profile(id),
  job_type     VARCHAR(20) NOT NULL DEFAULT 'scheduled' CHECK (job_type IN ('scheduled','on_demand','backfill')),
  window_from  TIMESTAMPTZ NOT NULL,
  window_to    TIMESTAMPTZ NOT NULL,
  status       VARCHAR(20) NOT NULL DEFAULT 'queued' CHECK (status IN
                 ('queued','running','success','failed','retrying','skipped_overlap')),
  attempt      INT NOT NULL DEFAULT 0,
  error_code   VARCHAR(50),
  records_synced INT NOT NULL DEFAULT 0,
  idempotency_key VARCHAR(120) NOT NULL,     -- profile_id + window — chống chạy chồng (BR-GW-STGW-008)
  started_at TIMESTAMPTZ, finished_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (idempotency_key)
);
CREATE INDEX idx_sync_job_profile ON gw_connector.sync_job(profile_id, status, created_at DESC);
```

##### adapter_health (TBL-GW-005)

```sql
-- TBL-GW-005 | REQ-ID: REQ-BOD-008 | FEAT-ID: FEAT-GW-STGW-001
CREATE TABLE gw_connector.adapter_health (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id     UUID NOT NULL REFERENCES gw_connector.connection_profile(id),
  checked_at     TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  result         VARCHAR(20) NOT NULL CHECK (result IN ('success','fail','degraded')),
  error_code     VARCHAR(50),
  data_freshness INTERVAL NOT NULL,           -- tuổi dữ liệu nguồn — đầu vào cảnh báo stale
  rotate_days_left INT,                       -- âm = quá hạn rotate
  detail_json    JSONB DEFAULT '{}'
);
CREATE INDEX idx_adapter_health_profile ON gw_connector.adapter_health(profile_id, checked_at DESC);
-- Partition theo tháng nếu >10M dòng; retention 12 tháng (chi tiết vận hành, không phải audit)
```

##### policy_config_version (TBL-GW-006) & field_mapping (TBL-GW-007)

```sql
-- TBL-GW-006 | REQ-ID: REQ-BOD-009 | FEAT-ID: FEAT-GW-STGW-001
-- Effective-dated, không hồi tố: tra giá trị = key + thời điểm hiệu lực
CREATE TABLE gw_connector.policy_config_version (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  param_key      VARCHAR(100) NOT NULL,       -- sync.frequency, sync.freshness_warn, recon.cycle_weekly...
  value_json     JSONB NOT NULL,
  version_no     INT NOT NULL,
  effective_from TIMESTAMPTZ NOT NULL,
  effective_to   TIMESTAMPTZ,                 -- NULL = đang hiệu lực
  approved_by    UUID NOT NULL,               -- chỉ BOD_CEO/BOD_CFO_CTO (BR-GW-STGW-004/BR-FIN-STGW-005)
  reason         TEXT NOT NULL,
  created_at     TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (param_key, version_no)
);
CREATE INDEX idx_policy_lookup ON gw_connector.policy_config_version(param_key, effective_from DESC);

-- TBL-GW-007 | REQ-ID: REQ-FIN-013 | FEAT-ID: FEAT-GW-STGW-002 (DI-004)
CREATE TABLE gw_connector.field_mapping (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id       UUID NOT NULL REFERENCES gw_connector.connection_profile(id),
  mapping_kind     VARCHAR(20) NOT NULL CHECK (mapping_kind IN ('ingest','export_template')),
  source_field     VARCHAR(200) NOT NULL,
  target_field     VARCHAR(200) NOT NULL,     -- trỏ schema 8/6 trường chuẩn
  transform_rule   JSONB DEFAULT '{}',
  template_version INT NOT NULL DEFAULT 1,
  approved_by      UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL, updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_field_mapping_profile ON gw_connector.field_mapping(profile_id, mapping_kind);
```

##### import_batch (TBL-GW-008) & import_row (TBL-GW-009) — chặn lỗi theo dòng

```sql
-- TBL-GW-008 | REQ-ID: REQ-FIN-005 | FEAT-ID: FEAT-GW-STGW-002
CREATE TABLE gw_connector.import_batch (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id    UUID REFERENCES gw_connector.connection_profile(id),  -- NULL với nhập tay lẻ
  import_kind   VARCHAR(20) NOT NULL CHECK (import_kind IN ('statement_file','statement_row',
                                                              'tiktok_metric_file','tiktok_metric_row')),
  file_ref      VARCHAR(500),                    -- object-storage key của file gốc (evidence)
  evidence_ref  VARCHAR(500) NOT NULL,           -- bắt buộc với mọi bản ghi manual (BR-FIN-205c)
  total_rows INT NOT NULL DEFAULT 0, accepted_rows INT NOT NULL DEFAULT 0, rejected_rows INT NOT NULL DEFAULT 0,
  imported_by   UUID NOT NULL,                   -- FIN_L1 / OPS_ADS
  imported_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_import_batch_importer ON gw_connector.import_batch(imported_by, imported_at DESC);

-- TBL-GW-009 | REQ-ID: REQ-FIN-005 | FEAT-ID: FEAT-GW-STGW-002
CREATE TABLE gw_connector.import_row (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id     UUID NOT NULL REFERENCES gw_connector.import_batch(id),
  row_no       INT NOT NULL,
  status       VARCHAR(20) NOT NULL DEFAULT 'accepted' CHECK (status IN ('accepted','rejected','reimported')),
  error_code   VARCHAR(50),                     -- SCHEMA_FIELD_MISSING / NATURAL_KEY_DUPLICATE / EVIDENCE_MISSING
  error_field  VARCHAR(100),
  raw_row_json JSONB NOT NULL,                  -- dòng nguyên trạng để nạp lại chỉ dòng lỗi
  UNIQUE (batch_id, row_no)
);
CREATE INDEX idx_import_row_errors ON gw_connector.import_row(batch_id) WHERE status = 'rejected';
```

##### raw_payload (TBL-GW-010)

```sql
-- TBL-GW-010 | REQ-ID: REQ-FIN-005 | FEAT-ID: FEAT-GW-STGW-002
-- Lưu TRƯỚC khi parse — căn cứ đối chiếu + reprocess khi mapping đổi
CREATE TABLE gw_connector.raw_payload (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id   UUID NOT NULL REFERENCES gw_connector.connection_profile(id),
  job_id       UUID REFERENCES gw_connector.sync_job(id),   -- NULL với raw của import file
  batch_id     UUID REFERENCES gw_connector.import_batch(id),
  payload_ref  VARCHAR(500) NOT NULL,           -- object-storage key (blob không nằm trong DB)
  pulled_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  parse_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (parse_status IN ('pending','parsed','failed','reprocessed')),
  parse_error  VARCHAR(50)
);
CREATE INDEX idx_raw_payload_job ON gw_connector.raw_payload(job_id, parse_status);
```

##### platform_statement (TBL-GW-011) — bản ghi thô gắn nhãn, natural key chống trùng

```sql
-- TBL-GW-011 | REQ-ID: REQ-FIN-005, REQ-FIN-004 | FEAT-ID: FEAT-GW-STGW-002
CREATE TABLE gw_connector.platform_statement (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform       VARCHAR(20) NOT NULL CHECK (platform IN
                   ('META','GOOGLE','TIKTOK','BING','X','PINTEREST','YANDEX')),
  adaccount_ref  VARCHAR(100) NOT NULL,         -- FK logic → TKQC registry (core, REQ-OPS-001)
  txn_date       DATE NOT NULL,
  txn_type       VARCHAR(50) NOT NULL,
  amount_original NUMERIC(20,4) NOT NULL,       -- giữ nguyên gốc, KHÔNG quy đổi tại gateway
  currency       CHAR(3) NOT NULL,
  fee            NUMERIC(20,4) NOT NULL DEFAULT 0,
  reference_code VARCHAR(120) NOT NULL,
  source_label   VARCHAR(10) NOT NULL CHECK (source_label IN ('api','manual')),
  sync_job_id    UUID REFERENCES gw_connector.sync_job(id),  -- path api
  import_row_id  UUID REFERENCES gw_connector.import_row(id), -- path manual
  entered_by     UUID,                          -- NOT NULL khi manual (CHECK dưới)
  evidence_ref   VARCHAR(500),                  -- NOT NULL khi manual
  rechecked_by_backfill UUID REFERENCES gw_connector.backfill_run(id), -- manual đã được backfill bù api
  created_at     TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT uq_statement_natural UNIQUE (platform, adaccount_ref, txn_date, txn_type, reference_code),
  CONSTRAINT ck_manual_trace CHECK (source_label = 'api' OR (entered_by IS NOT NULL AND evidence_ref IS NOT NULL))
);
CREATE INDEX idx_statement_recon ON gw_connector.platform_statement(platform, txn_date, source_label);
CREATE INDEX idx_statement_account ON gw_connector.platform_statement(adaccount_ref, txn_date);
-- Nhãn + entered_by/evidence: REVOKE UPDATE trên cột source_label ở tầng service; core lọc theo nhãn (BR-FIN-205a)
```

Backfill KHÔNG ghi đè bản ghi manual (BR-FIN-301c): dữ liệu api bù tạo bản ghi mới (natural key api khác vạch, dùng suffix reference theo raw), dòng manual chỉ được đánh dấu `rechecked_by_backfill` giữ làm vết so sánh — chênh lệch xử lý ở core.

##### backfill_run (TBL-GW-012)

```sql
-- TBL-GW-012 | REQ-ID: REQ-FIN-005 | FEAT-ID: FEAT-GW-STGW-002
CREATE TABLE gw_connector.backfill_run (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform          VARCHAR(20) NOT NULL,
  gap_from          TIMESTAMPTZ NOT NULL, gap_to TIMESTAMPTZ NOT NULL,
  status            VARCHAR(20) NOT NULL DEFAULT 'running' CHECK (status IN ('running','completed','failed','partial')),
  records_restored  INT NOT NULL DEFAULT 0,
  recheck_status    VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (recheck_status IN ('pending','triggered','done')),
  recheck_completed_at TIMESTAMPTZ,          -- đối soát lại kỳ manual — core xác nhận qua event
  started_by        UUID,                    -- NULL = hệ thống tự kích hoạt theo sự kiện cấp quyền
  started_at TIMESTAMPTZ DEFAULT NOW() NOT NULL, finished_at TIMESTAMPTZ
);
CREATE INDEX idx_backfill_platform ON gw_connector.backfill_run(platform, status, started_at DESC);
```

##### gateway_audit (TBL-GW-013) — hash-chain append-only

```sql
-- TBL-GW-013 | REQ-ID: REQ-BOD-008, REQ-FIN-012 | FEAT-ID: FEAT-GW-STGW-001
CREATE TABLE gw_connector.gateway_audit (
  seq          BIGSERIAL PRIMARY KEY,
  entry_id     UUID NOT NULL DEFAULT gen_random_uuid(),
  actor_id     UUID,                            -- NULL = system job
  actor_role   VARCHAR(30),
  action       VARCHAR(80) NOT NULL,            -- vault.view_mask, vault.rotate, conn.transition, api.call.outbound...
  object_type  VARCHAR(50) NOT NULL, object_id VARCHAR(64),
  before_json  JSONB, after_json JSONB,         --Vault: chỉ metadata/mask, không bao giờ giá trị secret
  trigger_json JSONB,                           -- jobId, mã lỗi API, sự kiện HĐ, lý do
  client_type  VARCHAR(30),                     -- mobile_internal → mọi attempt vault bị log cảnh báo
  occurred_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  hash_prev    CHAR(64) NOT NULL, hash_self CHAR(64) NOT NULL   -- SHA-256 chain; lệch chain → alert BOD
);
CREATE INDEX idx_gw_audit_object ON gw_connector.gateway_audit(object_type, object_id, occurred_at DESC);
CREATE INDEX idx_gw_audit_actor  ON gw_connector.gateway_audit(actor_id, occurred_at DESC);
-- Append-only: REVOKE UPDATE, DELETE; mirror WORM ≥10 năm theo REQ-FIN-012 (hash-chain hạ tầng dùng chung core)
```

#### 3.2. Module: TikTok Shop Monitoring (MOD-TIKTOK-SHOP, schema `gw_tiktok`)

##### shop_connection (TBL-GW-014)

```sql
-- TBL-GW-014 | REQ-ID: REQ-OPS-011 | FEAT-ID: FEAT-GW-TIKTOK-001
-- 3-gate state (phản chiếu workflow 3 Gate sở hữu ở core): 1 shop — 1 ủy quyền — 1 khách
CREATE TABLE gw_tiktok.shop_connection (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id         VARCHAR(120) NOT NULL,
  tenant_id       UUID NOT NULL,               -- FK logic → tenant/client registry (core); RLS key
  client_code     VARCHAR(50) NOT NULL,
  oauth_scope     TEXT NOT NULL,               -- scope đọc ghi rõ từng shop — cấm gom chung (BR-OPS-4.1a)
  status          VARCHAR(30) NOT NULL DEFAULT 'PROPOSED' CHECK (status IN
                    ('PROPOSED','VERIFYING','OPERATING','DEGRADED_MANUAL','REJECTED','REVOKED')),
  gate_stage      VARCHAR(20) NOT NULL DEFAULT 'NONE' CHECK (gate_stage IN ('NONE','GATE1','GATE2','GATE3')),
  proposed_by     UUID NOT NULL,
  approved_by     UUID,                        -- SALES_L4 (KXN-14; vai mở rộng ngoài registry — chờ Phụ lục A #8)
  authorized_at TIMESTAMPTZ, oauth_expires_at TIMESTAMPTZ,
  permit_expire_at DATE,                       -- giấy phép ngành hàng Gate 1 — cảnh báo trước hạn
  revoked_at TIMESTAMPTZ, revoked_reason TEXT, -- ≤24h theo sự kiện HĐ (BR-OPS-4.1c)
  health_flags    JSONB DEFAULT '{}',          -- shop bị platform khóa: gắn cờ, KHÔNG đổi status
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL, updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (shop_id, tenant_id)
);
CREATE INDEX idx_shop_conn_tenant ON gw_tiktok.shop_connection(tenant_id, status);
CREATE INDEX idx_shop_conn_expires ON gw_tiktok.shop_connection(status, oauth_expires_at);
-- RLS: USING (tenant_id = current_setting('app.tenant_id')::UUID) cho mọi role non-admin
```

##### shop_access_log (TBL-GW-015)

```sql
-- TBL-GW-015 | REQ-ID: REQ-OPS-011 | FEAT-ID: FEAT-GW-TIKTOK-001
CREATE TABLE gw_tiktok.shop_access_log (
  seq           BIGSERIAL PRIMARY KEY,
  entry_id      UUID NOT NULL DEFAULT gen_random_uuid(),
  connection_id UUID NOT NULL REFERENCES gw_tiktok.shop_connection(id),
  actor_id      UUID NOT NULL,                 -- ai
  action        VARCHAR(80) NOT NULL,          -- api.pull / pii.session.open / revoke...
  api_object    VARCHAR(200),                  -- API/đối tượng dữ liệu
  scope_used    TEXT,
  occurred_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  hash_prev     CHAR(64) NOT NULL, hash_self CHAR(64) NOT NULL
);
-- Append-only (REVOKE UPDATE/DELETE) — BR-OPS-4.1a; pull sau REVOKED log vi phạm
```

##### shop_metric_daily (TBL-GW-016) — reference_only bất biến

```sql
-- TBL-GW-016 | REQ-ID: REQ-OPS-011 | FEAT-ID: FEAT-GW-TIKTOK-001
CREATE TABLE gw_tiktok.shop_metric_daily (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  connection_id  UUID NOT NULL REFERENCES gw_tiktok.shop_connection(id),
  tenant_id      UUID NOT NULL,                -- denormalized cho RLS
  shop_ref       VARCHAR(120) NOT NULL,
  metric_date    DATE NOT NULL,
  metric_type    VARCHAR(50) NOT NULL,         -- gmv | order_count | settlement | shop_health
  amount_original NUMERIC(20,4),               -- với metric định lượng
  currency       CHAR(3),
  metric_value_json JSONB,                     -- flags/baseline cho shop_health
  reference_code VARCHAR(120) NOT NULL,        -- join với luồng NSQC ads CHỈ ở lớp tổng hợp core (BR-OPS-4.3a)
  reference_only BOOLEAN NOT NULL DEFAULT TRUE CHECK (reference_only = TRUE),  -- bất biến — chặn mapping doanh thu (BR-OPS-4.4)
  source_label   VARCHAR(10) NOT NULL CHECK (source_label IN ('api','manual')),
  sync_job_id    UUID REFERENCES gw_connector.sync_job(id),
  import_row_id  UUID REFERENCES gw_connector.import_row(id),
  entered_by     UUID, evidence_ref VARCHAR(500),
  created_at     TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT uq_shop_metric_natural UNIQUE (shop_ref, metric_date, metric_type, reference_code),
  CONSTRAINT ck_manual_trace CHECK (source_label = 'api' OR (entered_by IS NOT NULL AND evidence_ref IS NOT NULL))
);
CREATE INDEX idx_shop_metric_recon ON gw_tiktok.shop_metric_daily(tenant_id, shop_ref, metric_date, source_label);
-- RLS tenant_id; cột reference_only không có đường UPDATE hợp lệ nào ở service layer
```

##### pii_access_session (TBL-GW-017)

```sql
-- TBL-GW-017 | REQ-ID: REQ-OPS-011 | FEAT-ID: FEAT-GW-TIKTOK-001
-- KHÔNG lưu payload PII — chỉ phiên; dữ liệu đầy đủ chỉ sống trong TTL phiên (BR-OPS-4.2a)
CREATE TABLE gw_tiktok.pii_access_session (
  session_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  connection_id UUID NOT NULL REFERENCES gw_tiktok.shop_connection(id),
  requested_by  UUID NOT NULL,
  reason        TEXT NOT NULL,                 -- thiếu reason → từ chối mở phiên
  ttl_expires_at TIMESTAMPTZ NOT NULL,         -- đề xuất 15 phút [NEEDS_REVIEW: TTL cụ thể]
  closed_at     TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_pii_session_active ON gw_tiktok.pii_access_session(connection_id)
  WHERE closed_at IS NULL;
```

##### portal_report_feed (TBL-GW-018)

```sql
-- TBL-GW-018 | REQ-ID: REQ-OPS-011 | FEAT-ID: FEAT-GW-TIKTOK-001
-- Feed đã mask + tổng hợp, tenant-scoped, read-only — phát qua Portal API Gateway của core (BR-GW-TT-002)
CREATE TABLE gw_tiktok.portal_report_feed (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      UUID NOT NULL,
  report_period  VARCHAR(7) NOT NULL,          -- YYYY-MM
  metrics_payload JSONB NOT NULL,              -- chỉ trường theo visibility contract của tenant, đã mask
  visibility_config_version INT NOT NULL,      -- phạm vi hiển thị theo HĐ — [CẦN CHỐT SỐ] phạm vi chỉ số
  source_window_from DATE NOT NULL, source_window_to DATE NOT NULL,
  generated_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (tenant_id, report_period)
);
CREATE INDEX idx_portal_feed_tenant ON gw_tiktok.portal_report_feed(tenant_id, report_period DESC);
-- RLS tenant_id; không có endpoint ghi từ phía portal
```

> **[NEEDS_REVIEW] TBL SettlementReconPeriod:** arch-draft §4 ghi gateway khởi tạo kỳ đối soát settlement (đầu vào Gate 3) nhưng kết quả đối soát thuộc core; file table-plan của lane chỉ liệt kê 5 bảng `gw_tiktok`. Chưa đặt bảng — chốt cùng lane CORE (kỳ sở hữu ở core hay GW) trước khi thêm DDL.

---

### 4. Common Patterns

- **updated_at trigger:** áp dụng `update_updated_at_column()` cho các bảng có `updated_at` (connection_profile, sync_schedule, field_mapping, shop_connection).
- **Append-only enforcement:** trigger `BEFORE UPDATE OR DELETE ... RAISE EXCEPTION` trên gateway_audit, shop_access_log; statement/metric chặn UPDATE cột `source_label`, `reference_only` ở service layer + policy test.
- **Soft delete:** không dùng cho dữ liệu gắn nhãn/audit (immutable); connection_profile/credential dùng status; không có bảng nào của lane cần `deleted_at`.
- **Sequence code:** `connection_profile_code_seq` sinh `CN-[SYSTEM]-NN`.

### 5. Migration Strategy

```
Convention: migrations/[YYYYMMDDHHMMSS]_[description].sql — 1 DDL/migration, UP+DOWN, test staging trước prod.
Giai đoạn:  gw_connector tạo trước (GĐ1 — FEAT-GW-STGW-001/002);
            gw_tiktok thêm GĐ3 (FEAT-GW-TIKTOK-001) — không phụ thuộc ngược ngoài FK sang sync_job/import_row.
Quy tắc nhãn nguồn: không bao giờ migration sửa source_label/reference_only dữ liệu có sẵn;
            đổi schema bảng gắn nhãn → thêm cột mới + backfill có kiểm soát qua raw_payload (reprocess), không UPDATE nhãn.
RLS:        enable RLS gw_tiktok ngay từ migration đầu — không chạy prod thiếu policy.
```

### 6. Index Strategy

| Bảng | Index | Lý do |
|------|-------|-------|
| platform_statement | (platform, txn_date, source_label) + (adaccount_ref, txn_date) | Query đối trừ FIN_L2 lọc theo nhãn + window (API-GW-032) |
| platform_statement | UNIQUE natural key | Chống trùng import/sync (BR-FIN-205b) |
| shop_metric_daily | (tenant_id, shop_ref, metric_date, source_label) + UNIQUE natural key | Dashboard/Gate 3 + RLS |
| credential_version | (status, rotate_due_at) | Job quét T-7 alert + auto-degraded quá hạn |
| sync_job | idempotency_key UNIQUE + (profile_id, status) | Chống chồng job, list trạng thái |
| gateway_audit / shop_access_log | (object_type, object_id, occurred_at), (actor_id, occurred_at) | Truy vết transition + oversight BOD |
| shop_connection | (status, oauth_expires_at) | Cảnh báo OAuth/giấy phép hết hạn, thu hồi ≤24h |

> Retention đề xuất [NEEDS_REVIEW: chưa có chính sách retention vận hành trong registry]: raw_payload ref + object blob giữ tối thiểu 24 tháng phục vụ đối chiếu tiền; adapter_health 12 tháng; audit giữ theo WORM ≥10 năm (REQ-FIN-012) — không xóa.

## Hệ thống: SYS-PORTAL-WEB — Client Portal Web

## Database Design — SYS-PORTAL-WEB (Client Portal Web)

> READS: `phase2-features/portal-web/client-portal/*.md` (FEAT-PORTAL-CPORT-001/002, REQ-FIN-017, REQ-OPS-010), `P3-01-architecture.md` (§3, §4, §6), `lanes/portal-web/arch-draft.md`
> OUTPUT: DDL schema `portal_account`, indexes, RLS, migration strategy
> USED BY: `phase5-implementation/tasks/portal-web/*`
> DATE: 2026-09-13 | DB: PostgreSQL 16 (RLS bắt buộc cho tenant isolation — REQ-FIN-017)
>
> **Scope guard:** portal CHỈ sở hữu dữ liệu account/session/log/tenant_ref. Ví (ledger, đối soát), campaign/milestone, ticket, invoice, onboarding_gate_log là business data của module owner (SYS-BCERP-WEB / SYS-CORE-BACKEND) — KHÔNG thiết kế lại tại đây; portal đọc qua view CORE, chỉ cache Redis TTL ngắn, không lưu bản sao DB lâu dài.

---

### 1. Schema Organization

| Schema | System | Mục đích |
|--------|--------|---------|
| `portal_account` | SYS-PORTAL-WEB | portal_user, portal_invite, session/OTP, tenant_ref, access/download log, export job, anomaly event |

Quy tắc naming theo platform: table/column snake_case, index `idx_[table]_[columns]`, FK `fk_[table]_[ref_table]`. Mọi bảng tenant-scoped đều có `tenant_id` + RLS.

### 2. Tenant Reference — bảng duy nhất tham chiếu thế giới bên ngoài

#### tenant_ref (TBL-PORTAL-007)

Bản ghi tham chiếu tenant do CORE provisioning cấp đồng bộ (service-to-service, portal chỉ đọc — không UI ghi). Dùng để: chặn kích hoạt khi chưa ký DPA (BR-FIN-605), kiểm tra quota (BR-003), phân quyền theo tier.

```sql
-- TBL-PORTAL-007 | REQ-ID: REQ-OPS-010, REQ-FIN-017 | FEAT-ID: FEAT-PORTAL-CPORT-002
CREATE TABLE portal_account.tenant_ref (
  id                 UUID PRIMARY KEY,              -- = tenant id từ CORE provisioning
  legal_name         VARCHAR(300) NOT NULL,          -- mỗi pháp nhân/nhãn hàng 1 tenant (BR-008)
  contract_no        VARCHAR(100),
  tier               VARCHAR(20),                    -- điều khiển quota mở rộng + SLA priority
  admin_quota        SMALLINT NOT NULL DEFAULT 2,    -- CLIENT_ADMIN (mặc định — cấu hình theo tier [NEEDS_REVIEW: ma trận tier→quota, Phụ lục A #20])
  user_quota         SMALLINT NOT NULL DEFAULT 10,   -- CLIENT_USER (mặc định — cấu hình theo tier)
  dpa_signed         BOOLEAN NOT NULL DEFAULT false, -- chặn kích hoạt + xem ví khi false (khách EU/US)
  dpa_signed_at      TIMESTAMPTZ,
  provisioning_state VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  synced_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 3. MOD-CLIENT-PORTAL Tables (schema: portal_account)

#### 3.1 Identity & lifecycle tài khoản

```sql
-- TBL-PORTAL-001 | REQ-ID: REQ-OPS-010, REQ-BOD-011 | FEAT-ID: FEAT-PORTAL-CPORT-002, FEAT-PORTAL-RBAC-001
CREATE TABLE portal_account.portal_user (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES portal_account.tenant_ref(id),
  idp_subject         VARCHAR(128) UNIQUE,            -- OIDC sub từ COMP-CORE-001 (realm portal); NULL khi INVITED
  email               VARCHAR(255) NOT NULL,
  password_hash       VARCHAR(255),                   -- bcrypt rounds=12; NULL đến khi activate
  full_name           VARCHAR(200) NOT NULL,
  role                VARCHAR(20) NOT NULL CHECK (role IN ('CLIENT_ADMIN','CLIENT_USER')),
  status              VARCHAR(20) NOT NULL DEFAULT 'INVITED'
                      CHECK (status IN ('INVITED','ACTIVE','LOCKED','DISABLED','EXPIRED')),
  two_fa_enabled      BOOLEAN NOT NULL DEFAULT false,
  totp_secret_encrypted BYTEA,                        -- AES-256-GCM qua KMS; bắt buộc NOT NULL khi ACTIVE
  kms_key_id           VARCHAR(200),                  -- KMS data-key id — rotate không re-encrypt mù (đối chiếu TBL-GW-002.key_id)
  key_version          INT NOT NULL DEFAULT 1,        -- version data-key cho re-encrypt chọn lọc
  failed_login_count  SMALLINT NOT NULL DEFAULT 0,    -- 5 lần sai → LOCKED (BR-005)
  locked_at           TIMESTAMPTZ,
  locale              VARCHAR(10) NOT NULL DEFAULT 'vi-VN',
  timezone            VARCHAR(40) NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
  invited_by_user_id  UUID REFERENCES portal_account.portal_user(id), -- NULL = CLIENT_ADMIN đầu tiên do OPS_AM provision (Day 1)
  last_login_at       TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT uq_portal_user_tenant_email UNIQUE (tenant_id, email),
  -- Không tồn tại ACTIVE chưa 2FA (điều kiện kích hoạt BR-005/BR-001)
  CONSTRAINT ck_active_requires_2fa CHECK (status <> 'ACTIVE' OR two_fa_enabled = true)
);
-- DISABLED là trạng thái kết thúc: giữ row làm dấu vết audit, suất quota được giải phóng khi đếm
-- (quota tính trên status IN ('INVITED','ACTIVE','LOCKED')). Không soft-delete user portal.

-- TBL-PORTAL-002 | REQ-ID: REQ-OPS-010 | FEAT-ID: FEAT-PORTAL-CPORT-002
CREATE TABLE portal_account.portal_invite (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portal_user_id      UUID NOT NULL REFERENCES portal_account.portal_user(id),
  token_hash          CHAR(64) NOT NULL UNIQUE,       -- SHA-256 của token; token gốc chỉ có trong email
  invited_by_source   VARCHAR(30) NOT NULL
                      CHECK (invited_by_source IN ('OPS_AM_PROVISION','CLIENT_ADMIN')),
  invited_by_user_id  UUID REFERENCES portal_account.portal_user(id), -- NULL khi OPS_AM provision
  status              VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING','ACCEPTED','EXPIRED','REVOKED')),
  expires_at          TIMESTAMPTZ NOT NULL,           -- mặc định +7 ngày (tham số cấu hình)
  accepted_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
-- Chỉ 1 invite PENDING mỗi user; re-invite → REVOKED token cũ + PENDING token mới
CREATE UNIQUE INDEX uq_invite_pending_per_user ON portal_account.portal_invite(portal_user_id)
  WHERE status = 'PENDING';

-- TBL-PORTAL-003 | REQ-ID: REQ-OPS-010, REQ-BOD-011 | FEAT-ID: FEAT-PORTAL-RBAC-001
CREATE TABLE portal_account.portal_session (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portal_user_id      UUID NOT NULL REFERENCES portal_account.portal_user(id),
  tenant_id           UUID NOT NULL REFERENCES portal_account.tenant_ref(id),
  refresh_token_hash  CHAR(64) NOT NULL UNIQUE,       -- xoay mỗi refresh (API-PORTAL-007)
  mfa_amr             VARCHAR(30) NOT NULL,           -- bằng chứng 2FA đã pass trong phiên
  ip                  INET,
  user_agent          VARCHAR(400),
  created_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  last_seen_at        TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  expires_at          TIMESTAMPTZ NOT NULL,           -- TTL 12h đề xuất (idle timeout 30 phút ở Redis)
  revoked_at          TIMESTAMPTZ,                    -- thu hồi có hiệu lực ngay tại request kế tiếp (BR-FIN-603)
  revoked_reason      VARCHAR(40)                     -- LOGOUT / USER_REVOKED / ANOMALY_KILL
);

-- TBL-PORTAL-004 | REQ-ID: REQ-OPS-010 | FEAT-ID: FEAT-PORTAL-CPORT-002
CREATE TABLE portal_account.portal_otp_challenge (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portal_user_id      UUID REFERENCES portal_account.portal_user(id), -- NULL khi pre-auth activation
  challenge_key       VARCHAR(128),                   -- liên kết challenge login/invite token
  purpose             VARCHAR(30) NOT NULL
                      CHECK (purpose IN ('ACTIVATION','LOGIN_2FA_FALLBACK','SENSITIVE_ACTION','PASSWORD_RESET')),
  code_hash           CHAR(64) NOT NULL,
  channel             VARCHAR(20) NOT NULL DEFAULT 'EMAIL', -- [NEEDS_REVIEW: kênh gửi OTP — Phụ lục A #3]
  attempts            SMALLINT NOT NULL DEFAULT 0,    -- max 5, sai quá → vô hiệu
  expires_at          TIMESTAMPTZ NOT NULL,           -- TTL 5 phút (đề xuất)
  consumed_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
```

#### 3.2 Audit append-only + vận hành

```sql
-- TBL-PORTAL-005 | REQ-ID: REQ-FIN-017 (BR-FIN-603) | FEAT-ID: FEAT-PORTAL-CPORT-001
-- Append-only hash-chain: REVOKE UPDATE/DELETE + trigger chặn; phục vụ điều tra rò rỉ (FIN_L2)
CREATE TABLE portal_account.portal_access_log (
  seq                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id           UUID NOT NULL,
  portal_user_id      UUID,
  action              VARCHAR(60) NOT NULL,           -- LOGIN / VIEW_WALLET / EXPORT / DENY ...
  resource            VARCHAR(200),
  outcome             VARCHAR(10) NOT NULL CHECK (outcome IN ('ALLOW','DENY')),
  http_status         SMALLINT,
  ip                  INET,
  user_agent          VARCHAR(400),
  ts                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  prev_hash           CHAR(64) NOT NULL,              -- hash của dòng trước (genesis = 0*64)
  row_hash            CHAR(64) NOT NULL               -- SHA-256(seq, tenant_id, action, ..., prev_hash)
);

-- TBL-PORTAL-006 | REQ-ID: REQ-OPS-010 (BR-011), REQ-FIN-017 | FEAT-ID: FEAT-PORTAL-CPORT-001
-- Ghi mọi download có watermark; thiếu bản ghi = fail audit toàn vẹn
CREATE TABLE portal_account.portal_download_log (
  seq                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id           UUID NOT NULL,
  portal_user_id      UUID NOT NULL,
  resource            VARCHAR(200) NOT NULL,
  watermark_text      VARCHAR(200) NOT NULL,          -- "<full_name> + <thời điểm UTC+7>"
  export_job_id       UUID,                           -- FK logic → portal_export_job
  ts                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  prev_hash           CHAR(64) NOT NULL,
  row_hash            CHAR(64) NOT NULL
);

-- TBL-PORTAL-008 | REQ-ID: REQ-FIN-017 | FEAT-ID: FEAT-PORTAL-CPORT-001
CREATE TABLE portal_account.portal_export_job (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES portal_account.tenant_ref(id),
  requested_by        UUID NOT NULL REFERENCES portal_account.portal_user(id),
  scope               VARCHAR(30) NOT NULL
                      CHECK (scope IN ('WALLET_BALANCES','TRANSACTIONS','DEPOSITS','INVOICES')),
  params              JSONB NOT NULL DEFAULT '{}',
  status              VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING','RENDERING','READY','FAILED','EXPIRED')),
  watermark_text      VARCHAR(200),
  file_ref            VARCHAR(500),                   -- object storage, private bucket, không public URL
  error_code          VARCHAR(60),                    -- WATERMARK_UNAVAILABLE ...
  otp_proof_ref       VARCHAR(128) NOT NULL,          -- bằng chứng OTP (BR-008)
  created_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  ready_at            TIMESTAMPTZ,
  expires_at          TIMESTAMPTZ NOT NULL            -- +24h; hết hạn dọn file + mark EXPIRED
);

-- TBL-PORTAL-009 | REQ-ID: REQ-FIN-017 (BR-002, BR-FIN-603) | FEAT-ID: FEAT-PORTAL-CPORT-005 (COMP-PORTAL-005)
CREATE TABLE portal_account.portal_anomaly_event (
  seq                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id           UUID,
  portal_user_id      UUID,
  anomaly_type        VARCHAR(40) NOT NULL
                      CHECK (anomaly_type IN ('CROSS_TENANT_ATTEMPT','BULK_DOWNLOAD','DATA_SCANNING','RATE_ABUSE')),
  severity            VARCHAR(10) NOT NULL CHECK (severity IN ('LOW','MEDIUM','HIGH')),
  detail              JSONB NOT NULL DEFAULT '{}',
  action_taken        VARCHAR(30) NOT NULL
                      CHECK (action_taken IN ('RATE_LIMITED','SESSION_KILLED','ESCALATED')),
  escalated_to        VARCHAR(20),                    -- SYS_ADMIN / FIN_L2
  ts                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Bảng không thuộc portal (chỉ tham chiếu, không DDL tại đây):** `wallet_transaction` + trạng thái đối soát (WALLET, SYS-BCERP-WEB), campaign/milestone (CAMP), `ticket` + timeline (CSKH — queue hợp nhất REQ-OPS-009), invoice (ARAP), `onboarding_gate_log` (CORE). Portal đọc qua `GET /core/portal-views/*`, cache Redis gắn freshness; `ticket_id`/`invoice_id` chỉ xuất hiện trong portal payload dạng tham chiếu.

### 4. Common Patterns

**RLS tenant isolation (bắt buộc mọi bảng có tenant_id):**
```sql
ALTER TABLE portal_account.portal_user ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_tenant_isolation ON portal_account.portal_user
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
-- Lặp lại cho: portal_invite, portal_session, portal_otp_challenge, tenant_ref,
-- portal_export_job, portal_access_log, portal_download_log, portal_anomaly_event
```

**Append-only enforcement (TBL-PORTAL-005/006/009):**
```sql
REVOKE UPDATE, DELETE ON portal_account.portal_access_log, portal_account.portal_download_log,
  portal_account.portal_anomaly_event FROM portal_app_rw;
CREATE OR REPLACE FUNCTION block_mutation() RETURNS trigger AS $$
BEGIN RAISE EXCEPTION 'append-only table — cập nhật/xóa bị cấm'; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_access_log_append_only BEFORE UPDATE OR DELETE
  ON portal_account.portal_access_log FOR EACH ROW EXECUTE FUNCTION block_mutation();
-- Tương tự cho portal_download_log, portal_anomaly_event
-- row_hash: tính trong application layer trong cùng transaction ghi; job ngày verify chuỗi,
-- lệch chuỗi → alert CRITICAL (COMP-PORTAL-005)
```

**updated_at trigger:** áp `update_updated_at_column()` (platform pattern) cho `portal_user`, `tenant_ref`.

**Cleanup job:** `portal_otp_challenge` hết hạn >24h xóa; `portal_session` hết hạn >30 ngày xóa; export file xóa tại `expires_at` — không đụng bảng append-only.

### 5. Migration Strategy

Theo platform: `migrations/[YYYYMMDDHHMMSS]_[description].sql`, 1 DDL mỗi migration, UP + DOWN, test staging trước prod, không sửa migration đã chạy. Thứ tự khởi tạo: `tenant_ref` → `portal_user` → `portal_invite` → `portal_session` → `portal_otp_challenge` → log/export/anomaly → RLS policies (migration riêng, bắt buộc có test isolation SC-001/SC-008 trước khi mở traffic).

### 6. Index Strategy

| Index | Bảng | Lý do |
|-------|------|-------|
| `idx_portal_user_tenant_status` (tenant_id, status) WHERE deleted_at IS NULL | portal_user | Đếm quota (BR-003) + list user CLIENT_ADMIN |
| `uq_portal_user_tenant_email` | portal_user | Trùng email trong tenant |
| `idx_invite_token_hash` (UNIQUE) + partial PENDING | portal_invite | Xác thực token 1 lần |
| `idx_session_user_expires` (portal_user_id, expires_at) | portal_session | Thu hồi phiên + cleanup |
| `idx_otp_user_purpose_expires` | portal_otp_challenge | Verify OTP + cleanup |
| `idx_access_log_tenant_ts` (tenant_id, ts DESC) | portal_access_log | Điều tra rò rỉ theo khung thời gian (FIN_L2) |
| `idx_access_log_user_ts` (portal_user_id, ts DESC) | portal_access_log | Truy vết một user |
| `idx_download_tenant_ts`, `idx_download_user_ts` | portal_download_log | Như trên cho download |
| `idx_anomaly_ts` (ts DESC) WHERE severity IN ('HIGH','MEDIUM') | portal_anomaly_event | Bảng alert bảo mật |
| `idx_export_tenant_status` (tenant_id, status) | portal_export_job | Theo dõi job xuất |

Full-text search không cần thiết ở schema portal (danh sách user/ticket ngắn theo tenant); search ticket thực hiện ở ERP side.

## Hệ thống: SYS-MOBILE-INTERNAL — Mobile BCERP Internal

## Database Design — SYS-MOBILE-INTERNAL (schema: mbi_device)

> READS: `phase2-features/mobile-internal/**/*.md`, `P3-01-architecture.md` (§3: schema `mbi_device`, §4: ownership device/push token), `lanes/mobile-internal/arch-draft.md`
> OUTPUT: DDL, indexes, migration strategy cho dữ liệu mobile sở hữu
> USED BY: `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
> DATE: 2026-09-13 | DB: PostgreSQL 16 (instance dùng chung platform)

> **Biên scope:** SYS-MOBILE-INTERNAL **không sở hữu bất kỳ business object nào** — ví, lệnh chi, timesheet, ticket, lead… thuộc module owner ở SYS-BCERP-WEB (xem database-design lane bcerp-web). Schema `mbi_device` chỉ chứa 3 nhóm dữ liệu mobile là SSOT: thiết bị + push token, push preference, outbox nhận offline từ thiết bị. **Local cache trên thiết bị (SQLite mã hóa, TTL, purge khi logout/remote wipe) KHÔNG có schema server** — server không phản chiếu và không khôi phục được nội dung cache.

---

### 1. Schema Organization

| Schema | System | Mục đích |
|--------|--------|---------|
| `mbi_device` | SYS-MOBILE-INTERNAL | Device registration, push preference, offline outbox nhận về |

**Quy tắc naming:** bảng `snake_case` số nhiều; cột `snake_case`; index `idx_[table]_[columns]`; FK `fk_[table]_[ref_table]`.

**Liên kết chéo hệ thống:** `user_id` tham chiếu logic tới `core_identity.users` nhưng **KHÔNG đặt FK cross-schema** (khác phân hệ, chỉ được truy cập qua REST/event theo P3-01 §4) — integrity bảo đảm ở tầng ứng dụng + audit.

---

### 2. mbi_device Tables (schema: mbi_device)

#### TBL-MBI-001 — mobile_device

```sql
-- TBL-MBI-001 | REQ-ID: REQ-BOD-011 | FEAT-ID: FEAT-MBI-RBAC-002
CREATE TABLE mbi_device.mobile_device (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL,                     -- REF logic core_identity.users (không FK cross-schema)
  device_id        VARCHAR(128) NOT NULL,             -- định danh cứng thiết bị do app sinh
  platform         VARCHAR(10) NOT NULL
                   CHECK (platform IN ('ios', 'android')),
  os_version       VARCHAR(32),
  app_version      VARCHAR(32) NOT NULL,              -- đối chiếu min-version gating (INFRA-MBI-005)
  push_token       VARCHAR(512),
  push_provider    VARCHAR(10)
                   CHECK (push_provider IN ('fcm', 'apns')),
  binding_status   VARCHAR(20) DEFAULT 'pending' NOT NULL
                   CHECK (binding_status IN ('pending', 'active', 'revoked', 'locked')),
  device_model     VARCHAR(128),
  bound_at         TIMESTAMPTZ,
  last_seen_at     TIMESTAMPTZ,
  revoked_at       TIMESTAMPTZ,
  revoked_reason   VARCHAR(255),                      -- user_logout | device_replaced | lost_device | admin_revoke
  created_at       TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at       TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at       TIMESTAMPTZ,                       -- soft delete (chính sách chung P3-01 §6)
  CONSTRAINT uq_device_user UNIQUE (user_id, device_id)   -- binding 1 user–1 thiết bị
);

CREATE INDEX idx_mdevice_user        ON mbi_device.mobile_device(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_mdevice_status      ON mbi_device.mobile_device(binding_status) WHERE deleted_at IS NULL;
CREATE INDEX idx_mdevice_push_token  ON mbi_device.mobile_device(push_token);
CREATE INDEX idx_mdevice_last_seen   ON mbi_device.mobile_device(last_seen_at);
```

State machine `binding_status`: `pending → active` (user xác thực thành công trên thiết bị) → `revoked` (logout, mất máy, thiết bị lạ, admin revoke) / `locked` (bất thường bảo mật). Chỉ `active` được gọi `/api/v1/mbi/*`. Mọi transition ghi audit qua COMP-CORE-004 (mobile chỉ log kỹ thuật).

#### TBL-MBI-002 — push_preference

```sql
-- TBL-MBI-002 | REQ-ID: REQ-OPS-008 | FEAT-ID: FEAT-MBI-SLANOT-001
CREATE TABLE mbi_device.push_preference (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL,                        -- REF logic core_identity.users
  device_id     UUID REFERENCES mbi_device.mobile_device(id),  -- NULL = preference toàn user
  category      VARCHAR(30) NOT NULL
                CHECK (category IN ('approval', 'sla_warning', 'sla_breach', 'wallet_alert',
                                    'shop_alert', 'alert_center', 'ticket', 'campaign')),
  enabled       BOOLEAN DEFAULT true NOT NULL,
  quiet_hours   JSONB,                                -- {"from":"22:00","to":"07:00","tz":"Asia/Ho_Chi_Minh"}
  updated_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT uq_push_pref UNIQUE (user_id, device_id, category)
);

CREATE INDEX idx_ppref_user      ON mbi_device.push_preference(user_id);
CREATE INDEX idx_ppref_category  ON mbi_device.push_preference(category) WHERE enabled = true;
```

Ràng buộc nghiệp vụ: category `sla_breach` (escalation) **không cho tắt ở client** — API-MBI-009 từ chối với `VALIDATION_ERROR`; escalation vẫn chạy phía backend kể cả preference = off (push chỉ là kênh báo).

#### TBL-MBI-003 — offline_outbox (server-side nhận)

```sql
-- TBL-MBI-003 | REQ-ID: REQ-OPS-007, REQ-HR-003 | FEAT-ID: FEAT-MBI-CAPTS-001 [NEEDS_REVIEW: touchpoint HR-CORE]
CREATE TABLE mbi_device.offline_outbox (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL,
  device_id         UUID REFERENCES mbi_device.mobile_device(id) NOT NULL,
  idempotency_key   UUID NOT NULL,                    -- sinh trên thiết bị lúc offline
  action_type       VARCHAR(40) NOT NULL
                    CHECK (action_type IN ('attendance_checkin', 'attendance_checkout',
                                           'timesheet_submit', 'leave_request')),
  payload           JSONB NOT NULL,                   -- nguyên trạng bản ghi outbox từ thiết bị
  client_timestamp  TIMESTAMPTZ NOT NULL,             -- do thiết bị ghi lúc offline (chỉ tham chiếu)
  server_received_at TIMESTAMPTZ DEFAULT NOW() NOT NULL, -- TRỌNG TÀI thời gian
  status            VARCHAR(30) DEFAULT 'received' NOT NULL
                    CHECK (status IN ('received', 'accepted', 'rejected_duplicate',
                                      'rejected_invalid', 'forwarded')),
  rejection_code    VARCHAR(40),                      -- OFFLINE_NOT_ALLOWED | VALIDATION_ERROR | INVALID_STATE | ...
  backend_object_id UUID,                             -- id object backend khi forward thành công
  processed_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT uq_outbox_idem UNIQUE (idempotency_key)
);

CREATE INDEX idx_outbox_user_status ON mbi_device.offline_outbox(user_id, status);
CREATE INDEX idx_outbox_device      ON mbi_device.offline_outbox(device_id);
CREATE INDEX idx_outbox_received    ON mbi_device.offline_outbox(server_received_at);
```

`action_type` bị chặn **chỉ nhóm ESS** — replay chứa loại khác bị từ chối `OFFLINE_NOT_ALLOWED` (scope guard: cấm offline cho lệnh tiền/phê duyệt). Replay trùng key + payload → trả kết quả gốc (`rejected_duplicate`/`IDEMPOTENCY_REPLAYED`), an toàn cho retry mạng. `client_timestamp` và `server_received_at` đều lưu để HR-CORE đối chiếu khi chốt chấm công. [NEEDS_REVIEW] Retention outbox: đề xuất purge bản ghi đã xử lý sau 90 ngày — chưa có căn cứ chính sách.

---

### 3. Common Patterns

Áp dụng chuẩn chung: trigger `updated_at`; mọi query thêm `WHERE deleted_at IS NULL`; UUID v4; UTC lưu DB, hiển thị GMT+7. Không dùng full-text search (không có trường văn bản nghiệp vụ).

---

### 4. Migration Strategy

```
Convention: migrations/mbi/[YYYYMMDDHHMMSS]_[description].sql
Rules: 1 DDL/migration; có UP + DOWN; test dev/staging trước prod; không sửa migration đã chạy prod.
Khởi điểm: 20260913000000_create_mbi_device_schema.sql (schema + 3 bảng + indexes).
```

Volume nhỏ (≈ số nhân viên nội bộ) — không cần partitioning; outbox trim theo retention.

---

### 5. Index Strategy

| Bảng | Index | Lý do |
|------|-------|-------|
| mobile_device | `uq_device_user (user_id, device_id)` | Binding 1 user–1 thiết bị — kiểm tra mỗi request |
| mobile_device | `idx_mdevice_status` (partial), `idx_mdevice_last_seen` | Lọc active khi push dispatch; sweep thiết bị ngủ lâu |
| push_preference | `uq_push_pref` | Idempotency khi PUT preference |
| offline_outbox | `uq_outbox_idem` | Chống replay trùng — ràng buộc cứng mức DB |
| offline_outbox | `idx_outbox_user_status` | Theo dõi sync fail của user |

## Hệ thống: SYS-MOBILE-PORTAL — Mobile BC Portal

## Database Design — SYS-MOBILE-PORTAL (Mobile App BC Portal)

> READS: `phase2-features/mobile-portal/**/*.md`, `P3-01-architecture.md`, `lanes/mobile-portal/arch-draft.md`
> OUTPUT: DDL, indexes, migration strategy cho schema `mpo_device`
> USED BY: `phase5-implementation/tasks/mobile-portal/*`
> DATE: 2026-09-13 | DB: PostgreSQL 16

> **Nguyên tắc scope:** SYS-MOBILE-PORTAL là thin client — **KHÔNG sở hữu bảng nghiệp vụ nào** (Wallet, WalletTransaction, portal_user, portal_invite, ticket, push_notification, portal_access/download_log thuộc CORE-BACKEND/PORTAL-WEB). Schema này chỉ chứa dữ liệu kỹ thuật phía thiết bị: đăng ký thiết bị + push token + cấu hình opt-in. App tiêu thụ nghiệp vụ qua view đã lọc tenant của PORTAL-WEB; không có chế độ ghi offline.

---

### 1. Schema Organization

| Schema | System | Mục đích |
|--------|--------|---------|
| `mpo_device` | SYS-MOBILE-PORTAL | Thiết bị di động, push token, cấu hình nhận push per-device |
| `portal_account` | SYS-PORTAL-WEB | portal_user, portal_invite, session 2FA, access/download log (tham chiếu, không owned) |

Quy tắc naming theo template: bảng snake_case số nhiều, cột snake_case, index `idx_[table]_[columns]`.

### 2. Shared Tables

Không có. Identity/sesion dùng chung nền tảng: portal user + 2FA thuộc `portal_account` (SYS-PORTAL-WEB), phiên mobile lưu Redis (không có bảng `mobile_session` ở đây — [NEEDS_REVIEW: nếu lane PORTAL-WEB đặt session table dùng chung, mpo tham chiếu logical]).

### 3. MPO Tables (schema: mpo_device)

#### Module: Client Portal — device & push (MOD-CLIENT-PORTAL, MOD-SLA-NOTIF)

```sql
-- TBL-MPO-001 | REQ-ID: REQ-OPS-010, REQ-OPS-008 | FEAT-ID: FEAT-MPO-SLANOT-001, FEAT-MPO-CPORT-001
CREATE TABLE mpo_device.devices (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL,                    -- CROSS-SCHEMA ref portal_account.portal_user (logical, không FK vật lý)
  tenant_id      UUID NOT NULL,                    -- CROSS-SCHEMA ref tenant — phục vụ RLS
  platform       VARCHAR(10) NOT NULL CHECK (platform IN ('ios','android')),
  device_name    VARCHAR(200),
  app_version    VARCHAR(20),
  push_token     TEXT NOT NULL,                    -- FCM/APNs token, mã hóa at rest
  push_opt_in    BOOLEAN NOT NULL DEFAULT true,    -- opt-in per-thiết bị
  status         VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','REVOKED')),
  revoked_at     TIMESTAMPTZ,
  revoked_reason VARCHAR(200),                     -- logout | disabled | device_lost | re_register
  last_seen_at   TIMESTAMPTZ,
  created_at     TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at     TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE UNIQUE INDEX uq_devices_push_token ON mpo_device.devices(push_token);
CREATE INDEX idx_devices_user_tenant ON mpo_device.devices(user_id, tenant_id) WHERE status = 'ACTIVE';
CREATE INDEX idx_devices_tenant ON mpo_device.devices(tenant_id);

-- RLS tenant isolation (bắt buộc, khớp quy ước portal/mobile 2 lớp)
ALTER TABLE mpo_device.devices ENABLE ROW LEVEL SECURITY;
CREATE POLICY devices_tenant_isolation ON mpo_device.devices
  USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- TBL-MPO-002 | REQ-ID: REQ-OPS-008 | FEAT-ID: FEAT-MPO-SLANOT-001
CREATE TABLE mpo_device.push_preferences (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id        UUID NOT NULL REFERENCES mpo_device.devices(id) ON DELETE CASCADE,
  user_id          UUID NOT NULL,
  tenant_id        UUID NOT NULL,
  event_type       VARCHAR(30) NOT NULL CHECK (event_type IN
                     ('WALLET_LEVEL','TICKET_REPLY','APPROVAL_WAIT','PORTAL_ACCOUNT')),
  min_alert_level  VARCHAR(10) CHECK (min_alert_level IN ('XANH','VANG','DO')),  -- cho WALLET_LEVEL
  quiet_hours      BOOLEAN NOT NULL DEFAULT false,  -- chỉ áp mức Low/Medium; Critical/breach luôn xuyên qua
  enabled          BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at       TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (device_id, event_type)
);

CREATE INDEX idx_push_pref_device ON mpo_device.push_preferences(device_id) WHERE enabled = true;
CREATE INDEX idx_push_pref_tenant ON mpo_device.push_preferences(tenant_id);

ALTER TABLE mpo_device.push_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY push_pref_tenant_isolation ON mpo_device.push_preferences
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

Trigger `update_updated_at_column()` áp cho cả 2 bảng theo template.

### 4. Common Patterns

- **Soft delete/revoke:** thiết bị không xóa cứng — `status='REVOKED'` + `revoked_at`/`revoked_reason`; token cũ không bao giờ được push tới (worker check `status='ACTIVE'`).
- **Re-register trùng token:** unique `push_token` → đăng ký lại trên thiết bị mới cập nhật bản ghi (upsert), không tạo dòng trùng.
- **Tham chiếu chéo schema:** `user_id`/`tenant_id` là logical reference (không FK vật lý sang `portal_account`) — nhất quán quy tắc "không truy cập thẳng DB system khác".

### 5. Migration Strategy

Theo template: `migrations/[YYYYMMDDHHMMSS]_[description].sql`, 1 DDL mỗi migration, UP+DOWN, test staging trước prod. Migration đầu tạo schema + 2 bảng + RLS trong 1 transaction; không có data migration — bảng khởi tạo rỗng.

### 6. Index Strategy

| Index | Loại | Lý do |
|-------|------|-------|
| `uq_devices_push_token` | Unique | Fan-out push lookup chính + chống trùng token |
| `idx_devices_user_tenant` | Partial (ACTIVE) | Revoke khi user DISABLED; liệt kê thiết bị của user |
| `idx_devices_tenant` | B-tree | Vận hành theo tenant + RLS |
| `idx_push_pref_device` | Partial (enabled) | Worker đọc cấu hình lúc fan-out |
| `UNIQUE (device_id, event_type)` | Composite unique | Một cấu hình mỗi loại sự kiện per thiết bị |

#### [NEEDS_REVIEW]
1. Bảng lưu session mobile (nếu không dùng Redis thuần) — chốt cùng lane PORTAL-WEB khi hợp nhất `portal_account`.
2. Retention dòng `REVOKED` (đề xuất 12 tháng rồi purge) — chưa có chính sách retention thiết bị trong registry.
