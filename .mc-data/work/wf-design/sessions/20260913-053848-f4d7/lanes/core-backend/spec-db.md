# Database Design — SYS-CORE-BACKEND (Core Backend)

> Session: 20260913-053848-f4d7 | Lane: core-backend | TRIO: architect + dba + devops
> READS: `phase2-features/core-backend/rbac-audit/*.md`, `phase2-features/core-backend/datahub-bi/*.md`, `P3-01-architecture.md` (§1, §3, §4, §10), `lanes/core-backend/arch-draft.md`
> OUTPUT: DDL, indexes, migration strategy cho 3 schema `core_identity`, `core_audit`, `core_dhub`
> USED BY: `phase5-implementation/tasks/core-backend/*`
> DATE: 2026-09-13 | DB: PostgreSQL 16 (OLTP) + ClickHouse (đề xuất — OLAP warehouse)
>
> **Scope guard:** chỉ MOD-RBAC-AUDIT + MOD-DATAHUB-BI. Bảng business object (lead, ví, lệnh chi, TKQC...) thuộc schema `erp_*` do lane SYS-BCERP-WEB sở hữu — Core chỉ giữ bản sao phân tích trong warehouse, không FK chéo sang schema business.

---

> **ID format:** `TBL-CORE-NNN` tăng dần toàn system. Mỗi table SQL comment phải có TBL-ID + REQ-ID + FEAT-ID tương ứng.

## 1. Schema Organization

| Schema | System | Mục đích |
|--------|--------|---------|
| `core_identity` | SYS-CORE-BACKEND (MOD-RBAC-AUDIT) | Định danh, MFA, session, vai/permission/policy, access review |
| `core_audit` | SYS-CORE-BACKEND (MOD-RBAC-AUDIT) | Audit log hash-chain append-only, WORM evidence ref, PII classification |
| `core_dhub` | SYS-CORE-BACKEND (MOD-DATAHUB-BI) | Contract registry, ingest run/DLQ, layout warehouse, alert rules/instances |

Quyết định phân chia: template mặc định để `users/roles/permissions` ở schema `public`, nhưng theo P3-01 §3 Core Backend sở hữu identity — nên toàn bộ đặt trong `core_identity`, schema `public` để trống (không có bảng dùng chung xuyên system; các system khác KHÔNG join thẳng vào `core_*` — chỉ qua API, P3-01 §4).

Naming chuẩn template: table snake_case plural, cột snake_case, index `idx_[table]_[cols]`, FK `fk_[table]_[ref]`. UUID v4 PK; timestamp `TIMESTAMPTZ` UTC.

## 2. Shared Tables (schema: public)

Không có. Lý do xem §1.

## 3. CORE-BACKEND Tables

### Module: RBAC & Audit Log — schema `core_identity`

#### 3.1 Identity, MFA, Session (COMP-CORE-001)

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

#### 3.2 RBAC 4 chiều — Role × Permission × Dept × Data-scope (COMP-CORE-002)

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

### Module: RBAC & Audit Log — schema `core_audit`

#### 3.3 Audit hash-chain + WORM (COMP-CORE-004, 005)

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

#### 3.4 PII classification (COMP-CORE-006)

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

### Module: Data Integration Hub & BI — schema `core_dhub`

#### 3.5 Contract registry + ingest run (COMP-CORE-007)

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

#### 3.6 Warehouse layout registry (COMP-CORE-008 — OLAP ClickHouse, đề xuất)

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

#### 3.7 Alert Center (COMP-CORE-011)

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

## 4. Common Patterns

**Append-only + hash chain (TBL-CORE-015):** `entry_hash = SHA-256(prev_hash || canonical_json(record))`; insert trong transaction duy nhất qua đường ghi COMP-CORE-004; trigger cấm UPDATE/DELETE (lỗi `AUDIT_IMMUTABLE`); job verify định kỳ re-hash theo seq_no (API-CORE-032), lệch → alert HIGH + snapshot evidence sang WORM.

**Khác biệt soft delete:** chuẩn platform soft delete `deleted_at`; ngoại lệ — `audit_log` + `worm_evidence_refs` + `pii_access_log` không có cột soft delete (bất biến); `sessions`/`ingest_runs` dùng `revoked_at`/`finished_at` thay vì xóa.

**Row-level filter theo data-scope:** mọi list query của Core tự áp `data_scope` từ PDP (all/own-dept/own-objects) tại tầng repository; RLS PostgreSQL bắt buộc cho tenant portal (REQ-FIN-017) — core chỉ đọc tham chiếu, bản thân core_identity dùng filter application-level.

**Idempotency ingest:** `natural_key` trong contract + `event_id` unique; upsert theo natural key, drop trùng đếm metric (gate G1).

## 5. Migration Strategy

Chuẩn template: `migrations/[YYYYMMDDHHMMSS]_[description].sql`, 1 DDL/migration, UP+DOWN, test dev/staging trước prod, backup trước migration prod, không sửa migration đã chạy, không drop column ngay (deprecate → migrate → drop).

Riêng Core bổ sung 2 quy tắc:
1. **Contract registry migration phải song hành schema event:** đổi `ingestion_contracts.schema_version` phải deploy cùng release với module nguồn — compatibility gate trong CI module nguồn (P3-01 §10.5), không có migration schema drift một mình.
2. **Không bao giờ có migration ghi vào `audit_log`** (trừ tạo bảng/index); backfill dữ liệu audit lịch sử (nếu có) phải qua API append để giữ chuỗi hash liên tục.

## 6. Index Strategy

Theo chuẩn template (PK UUID, FK index, partial index `WHERE deleted_at IS NULL`, GIN full-text khi cần search). Bổ sung đặc thù:

| Table | Index | Lý do |
|-------|-------|-------|
| `audit_log` | `(object_type, object_id, occurred_at)`, `(actor_id, occurred_at)`, `(record_class, occurred_at)` | Query giám sát REQ-BOD-005 + timeline per object; partition theo tháng `occurred_at` khi >1 năm dữ liệu |
| `sessions` | partial `user_id WHERE revoked_at IS NULL AND expires_at > NOW()` | Thu hồi tức thời offboarding |
| `alert_instances` | `(state, severity, first_seen_at DESC)`, unique `(rule_id, dedup_key)` | Queue alert center + dedup |
| `ingest_runs` | `(contract_id, started_at DESC)` | Status + freshness per nguồn |
| `access_review_items` | `(campaign_id, reviewer_id, decision)` | Track tiến độ review quý |
| `user_roles` | partial `user_id WHERE state='active'` | PDP check nóng (cache 60s phía trên) |
