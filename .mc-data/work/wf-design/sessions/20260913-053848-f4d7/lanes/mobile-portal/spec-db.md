# Database Design — SYS-MOBILE-PORTAL (Mobile App BC Portal)

> READS: `phase2-features/mobile-portal/**/*.md`, `P3-01-architecture.md`, `lanes/mobile-portal/arch-draft.md`
> OUTPUT: DDL, indexes, migration strategy cho schema `mpo_device`
> USED BY: `phase5-implementation/tasks/mobile-portal/*`
> DATE: 2026-09-13 | DB: PostgreSQL 16

> **Nguyên tắc scope:** SYS-MOBILE-PORTAL là thin client — **KHÔNG sở hữu bảng nghiệp vụ nào** (Wallet, WalletTransaction, portal_user, portal_invite, ticket, push_notification, portal_access/download_log thuộc CORE-BACKEND/PORTAL-WEB). Schema này chỉ chứa dữ liệu kỹ thuật phía thiết bị: đăng ký thiết bị + push token + cấu hình opt-in. App tiêu thụ nghiệp vụ qua view đã lọc tenant của PORTAL-WEB; không có chế độ ghi offline.

---

## 1. Schema Organization

| Schema | System | Mục đích |
|--------|--------|---------|
| `mpo_device` | SYS-MOBILE-PORTAL | Thiết bị di động, push token, cấu hình nhận push per-device |
| `portal_account` | SYS-PORTAL-WEB | portal_user, portal_invite, session 2FA, access/download log (tham chiếu, không owned) |

Quy tắc naming theo template: bảng snake_case số nhiều, cột snake_case, index `idx_[table]_[columns]`.

## 2. Shared Tables

Không có. Identity/sesion dùng chung nền tảng: portal user + 2FA thuộc `portal_account` (SYS-PORTAL-WEB), phiên mobile lưu Redis (không có bảng `mobile_session` ở đây — [NEEDS_REVIEW: nếu lane PORTAL-WEB đặt session table dùng chung, mpo tham chiếu logical]).

## 3. MPO Tables (schema: mpo_device)

### Module: Client Portal — device & push (MOD-CLIENT-PORTAL, MOD-SLA-NOTIF)

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

## 4. Common Patterns

- **Soft delete/revoke:** thiết bị không xóa cứng — `status='REVOKED'` + `revoked_at`/`revoked_reason`; token cũ không bao giờ được push tới (worker check `status='ACTIVE'`).
- **Re-register trùng token:** unique `push_token` → đăng ký lại trên thiết bị mới cập nhật bản ghi (upsert), không tạo dòng trùng.
- **Tham chiếu chéo schema:** `user_id`/`tenant_id` là logical reference (không FK vật lý sang `portal_account`) — nhất quán quy tắc "không truy cập thẳng DB system khác".

## 5. Migration Strategy

Theo template: `migrations/[YYYYMMDDHHMMSS]_[description].sql`, 1 DDL mỗi migration, UP+DOWN, test staging trước prod. Migration đầu tạo schema + 2 bảng + RLS trong 1 transaction; không có data migration — bảng khởi tạo rỗng.

## 6. Index Strategy

| Index | Loại | Lý do |
|-------|------|-------|
| `uq_devices_push_token` | Unique | Fan-out push lookup chính + chống trùng token |
| `idx_devices_user_tenant` | Partial (ACTIVE) | Revoke khi user DISABLED; liệt kê thiết bị của user |
| `idx_devices_tenant` | B-tree | Vận hành theo tenant + RLS |
| `idx_push_pref_device` | Partial (enabled) | Worker đọc cấu hình lúc fan-out |
| `UNIQUE (device_id, event_type)` | Composite unique | Một cấu hình mỗi loại sự kiện per thiết bị |

### [NEEDS_REVIEW]
1. Bảng lưu session mobile (nếu không dùng Redis thuần) — chốt cùng lane PORTAL-WEB khi hợp nhất `portal_account`.
2. Retention dòng `REVOKED` (đề xuất 12 tháng rồi purge) — chưa có chính sách retention thiết bị trong registry.
