# Database Design — SYS-PORTAL-WEB (Client Portal Web)

> READS: `phase2-features/portal-web/client-portal/*.md` (FEAT-PORTAL-CPORT-001/002, REQ-FIN-017, REQ-OPS-010), `P3-01-architecture.md` (§3, §4, §6), `lanes/portal-web/arch-draft.md`
> OUTPUT: DDL schema `portal_account`, indexes, RLS, migration strategy
> USED BY: `phase5-implementation/tasks/portal-web/*`
> DATE: 2026-09-13 | DB: PostgreSQL 16 (RLS bắt buộc cho tenant isolation — REQ-FIN-017)
>
> **Scope guard:** portal CHỈ sở hữu dữ liệu account/session/log/tenant_ref. Ví (ledger, đối soát), campaign/milestone, ticket, invoice, onboarding_gate_log là business data của module owner (SYS-BCERP-WEB / SYS-CORE-BACKEND) — KHÔNG thiết kế lại tại đây; portal đọc qua view CORE, chỉ cache Redis TTL ngắn, không lưu bản sao DB lâu dài.

---

## 1. Schema Organization

| Schema | System | Mục đích |
|--------|--------|---------|
| `portal_account` | SYS-PORTAL-WEB | portal_user, portal_invite, session/OTP, tenant_ref, access/download log, export job, anomaly event |

Quy tắc naming theo platform: table/column snake_case, index `idx_[table]_[columns]`, FK `fk_[table]_[ref_table]`. Mọi bảng tenant-scoped đều có `tenant_id` + RLS.

## 2. Tenant Reference — bảng duy nhất tham chiếu thế giới bên ngoài

### tenant_ref (TBL-PORTAL-007)

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

## 3. MOD-CLIENT-PORTAL Tables (schema: portal_account)

### 3.1 Identity & lifecycle tài khoản

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

### 3.2 Audit append-only + vận hành

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

## 4. Common Patterns

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

## 5. Migration Strategy

Theo platform: `migrations/[YYYYMMDDHHMMSS]_[description].sql`, 1 DDL mỗi migration, UP + DOWN, test staging trước prod, không sửa migration đã chạy. Thứ tự khởi tạo: `tenant_ref` → `portal_user` → `portal_invite` → `portal_session` → `portal_otp_challenge` → log/export/anomaly → RLS policies (migration riêng, bắt buộc có test isolation SC-001/SC-008 trước khi mở traffic).

## 6. Index Strategy

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
