# Database Design — SYS-INTEGRATION-GW

> READS: `phase2-features/integration-gw/settings-gw/*.md` (FEAT-GW-STGW-001/002), `phase2-features/integration-gw/tiktok-shop/tiktok-shop-monitoring.md` (FEAT-GW-TIKTOK-001), `P3-01-architecture.md`
> OUTPUT: DDL, indexes, migration strategy của SYS-INTEGRATION-GW
> USED BY: `phase5-implementation/tasks/integration-gw/`, `integration-map.md`
> DATE: 2026-09-13 | DB: PostgreSQL 16 | Scope: MOD-SETTINGS-GW (schema `gw_connector`) + MOD-TIKTOK-SHOP (schema `gw_tiktok`)

> ID format lane: `TBL-GW-NNN` (nối liên tục 2 schema để registry tra 1 dải).

---

## 1. Schema Organization

| Schema | System | Module | Mục đích |
|--------|--------|--------|---------|
| `gw_connector` | SYS-INTEGRATION-GW | MOD-SETTINGS-GW | Connector registry, credential vault, sync/ingest, nhãn nguồn, backfill, gateway audit |
| `gw_tiktok` | SYS-INTEGRATION-GW | MOD-TIKTOK-SHOP | Shop connection OAuth per-client, shop metrics `reference_only`, PII session, portal feed |

**Quy tắc naming:** tables snake_case plural; indexes `idx_[table]_[cols]`; FK `fk_[table]_[ref]`. RLS bật trên `gw_tiktok` (tenant isolation — BR-OPS-4.2b); `gw_connector` không tenant-scoped (nội bộ BOD/FIN, data-scope tầng app).

**Nguyên tắc bất biến:** (1) `source_label` (`api`/`manual`) gắn tại thời điểm ghi — REVOKE UPDATE trên cột; (2) `gateway_audit`, `shop_access_log` append-only hash-chain — trigger chặn UPDATE/DELETE; (3) raw payload chỉ lưu object-storage ref trong DB; (4) gateway KHÔNG lưu plaintext secret, KHÔNG persist PII đầy đủ.

---

## 2. Shared Tables

Không sở hữu bảng dùng chung — users/roles/policy của SYS-CORE-BACKEND, tham chiếu qua `user_id UUID` (không FK cross-system trừ audit hash node). Kết quả đối trừ 3 số, ledger ví, TKQC registry thuộc core/BCERP-WEB — gateway chỉ giữ bản ghi thô gắn nhãn.

---

## 3. GW Tables

### 3.1. Module: Settings & Gateway Config (MOD-SETTINGS-GW, schema `gw_connector`)

#### connection_profile (TBL-GW-001)

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

#### credential_version (TBL-GW-002)

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

#### sync_schedule (TBL-GW-003) & sync_job (TBL-GW-004)

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

#### adapter_health (TBL-GW-005)

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

#### policy_config_version (TBL-GW-006) & field_mapping (TBL-GW-007)

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

#### import_batch (TBL-GW-008) & import_row (TBL-GW-009) — chặn lỗi theo dòng

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

#### raw_payload (TBL-GW-010)

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

#### platform_statement (TBL-GW-011) — bản ghi thô gắn nhãn, natural key chống trùng

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

#### backfill_run (TBL-GW-012)

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

#### gateway_audit (TBL-GW-013) — hash-chain append-only

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

### 3.2. Module: TikTok Shop Monitoring (MOD-TIKTOK-SHOP, schema `gw_tiktok`)

#### shop_connection (TBL-GW-014)

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
  approved_by     UUID,                        -- SALES_L4 (KXN-14)
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

#### shop_access_log (TBL-GW-015)

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

#### shop_metric_daily (TBL-GW-016) — reference_only bất biến

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

#### pii_access_session (TBL-GW-017)

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

#### portal_report_feed (TBL-GW-018)

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

## 4. Common Patterns

- **updated_at trigger:** áp dụng `update_updated_at_column()` cho các bảng có `updated_at` (connection_profile, sync_schedule, field_mapping, shop_connection).
- **Append-only enforcement:** trigger `BEFORE UPDATE OR DELETE ... RAISE EXCEPTION` trên gateway_audit, shop_access_log; statement/metric chặn UPDATE cột `source_label`, `reference_only` ở service layer + policy test.
- **Soft delete:** không dùng cho dữ liệu gắn nhãn/audit (immutable); connection_profile/credential dùng status; không có bảng nào của lane cần `deleted_at`.
- **Sequence code:** `connection_profile_code_seq` sinh `CN-[SYSTEM]-NN`.

## 5. Migration Strategy

```
Convention: migrations/[YYYYMMDDHHMMSS]_[description].sql — 1 DDL/migration, UP+DOWN, test staging trước prod.
Giai đoạn:  gw_connector tạo trước (GĐ1 — FEAT-GW-STGW-001/002);
            gw_tiktok thêm GĐ3 (FEAT-GW-TIKTOK-001) — không phụ thuộc ngược ngoài FK sang sync_job/import_row.
Quy tắc nhãn nguồn: không bao giờ migration sửa source_label/reference_only dữ liệu có sẵn;
            đổi schema bảng gắn nhãn → thêm cột mới + backfill có kiểm soát qua raw_payload (reprocess), không UPDATE nhãn.
RLS:        enable RLS gw_tiktok ngay từ migration đầu — không chạy prod thiếu policy.
```

## 6. Index Strategy

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
