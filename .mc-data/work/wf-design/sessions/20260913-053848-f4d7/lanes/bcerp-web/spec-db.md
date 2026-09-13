# Database Design — SYS-BCERP-WEB (BCERP Web nội bộ) [fragment]

> READS: `phase2-features/bcerp-web/**` (business rules, entities), `P3-01-architecture.md` (§1, §3 schema, §4 ownership, §6 quy ước), `lanes/bcerp-web/arch-draft.md`, `business-context.md` v4.1
> OUTPUT: DDL core tables, indexes, migration strategy cho 5 schema ERP
> USED BY: `technical-specs/database-design.md` (aggregation), `phase5-implementation/**`
> DATE: 2026-09-13 | DB: PostgreSQL 16
> Table ID convention (lane contract): `TBL-ERP-NNN`. Mỗi SQL comment có TBL-ID + REQ-ID + FEAT-ID.

---

## 1. Schema Organization

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

## 2. Shared Tables

Không sở hữu bảng shared. `core_identity.users`, `core_identity.roles` thuộc SYS-CORE-BACKEND — FK tham chiếu qua schema boundary (`-- CROSS-SCHEMA FK`), chỉ đọc. Audit compliance (hash-chain, WORM ≥10 năm) ghi qua COMP-CORE-004 — bảng `*_activities` dưới đây chỉ là **activity/timeline nghiệp vụ** phục vụ UI, không thay thế audit log platform (REQ-BOD-005, REQ-FIN-012).

## 3. SYS-BCERP-WEB Tables

### 3.1. Schema `erp_sales` (COMP-ERP-001) — FEAT-ERP-CRM-*, FEAT-ERP-QDD-*, FEAT-ERP-HONB-*

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

### 3.2. Schema `erp_finance` (COMP-ERP-002) — FEAT-ERP-WALLET-*, FEAT-ERP-ARAP-*, FEAT-ERP-COMM-001

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

### 3.3. Schema `erp_ops` (COMP-ERP-003/004) — FEAT-ERP-ADACC-*, FEAT-ERP-PROPLN-001, FEAT-ERP-CAMP-*, FEAT-ERP-CSKH-001, FEAT-ERP-CPORT-001

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

### 3.4. Schema `erp_people` (COMP-ERP-005) — FEAT-ERP-HRCORE-*, FEAT-ERP-CAPTS-*, FEAT-ERP-KPI-*

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

### 3.5. Schema `erp_sla` (COMP-ERP-006/007) — FEAT-ERP-SLANOT-001 + jobs

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

## 4. Common Patterns

- **Auto-generate code:** sequence per bảng (`leads_code_seq` → `LD-000001`) theo template §4.
- **Auto `updated_at`:** trigger dùng chung `update_updated_at_column()` theo template §4, áp cho mọi bảng có `updated_at`.
- **Soft delete:** mọi query thêm `WHERE deleted_at IS NULL`; riêng `wallet_journal`, `wallet_journal_lines`, `hard_stop_confirmations`, `erp_sla.job_runs`, `*_activities` **bất biến** — không soft delete (cơ sở đối soát + audit).
- **Optimistic locking:** money command dùng cột `updated_at` làm version check; conflict → 409 `INVALID_STATE`.
- **SOD constraint:** `approver1_id <> approver2_id` và chuỗi `payment_order_approvals` không trùng `approver_id` — enforce ở approval engine (app layer) + job validate định kỳ (không dùng trigger cứng vì có delegate — [NEEDS_REVIEW: delegate map ở DB hay policy service]).

## 5. Migration Strategy

Theo template §5: `migrations/[YYYYMMDDHHMMSS]_[description].sql`, 1 DDL/migration, UP + DOWN, không sửa migration đã chạy production. Riêng hệ này: (1) migration schema tiền phải chạy trong maintenance window (không có lệnh tiền đang bay); (2) bật `pg_dump` backup trước migration production; (3) state machine CHECK constraint thay đổi = migration riêng kèm data backfill trạng thái trước khi siết CHECK.

## 6. Index Strategy

| Loại | Pattern áp dụng |
|------|-----------------|
| Status filter | Partial `WHERE deleted_at IS NULL` trên mọi bảng workflow (idx_leads_status_owner, idx_po_status, idx_ticket_status_assignee...) |
| Composite lọc phổ biến | `(status, owner_id)`, `(status, aging_bucket, due_date)`, `(platform, status)`, `(employee_id, work_date)` |
| FK index | Mọi FK column (template §6) |
| Full-text search | GIN `to_tsvector('simple', company_name || contact_name)` trên `leads`, `customers` |
| Unique business | `uq_leads_fingerprint` (anti-duplicate), `UNIQUE(customer_id, currency)` (wallet), `UNIQUE(job_key, window_key)` (idempotency job), `idempotency_key` (money command) |
| Timer/queue scan | `idx_timer_breach (breach_at) WHERE state='running'`, `idx_wallets_low`, `idx_dlvr_acceptance_due` |
