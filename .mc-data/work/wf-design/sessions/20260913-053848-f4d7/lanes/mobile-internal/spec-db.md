# Database Design — SYS-MOBILE-INTERNAL (schema: mbi_device)

> READS: `phase2-features/mobile-internal/**/*.md`, `P3-01-architecture.md` (§3: schema `mbi_device`, §4: ownership device/push token), `lanes/mobile-internal/arch-draft.md`
> OUTPUT: DDL, indexes, migration strategy cho dữ liệu mobile sở hữu
> USED BY: `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
> DATE: 2026-09-13 | DB: PostgreSQL 16 (instance dùng chung platform)

> **Biên scope:** SYS-MOBILE-INTERNAL **không sở hữu bất kỳ business object nào** — ví, lệnh chi, timesheet, ticket, lead… thuộc module owner ở SYS-BCERP-WEB (xem database-design lane bcerp-web). Schema `mbi_device` chỉ chứa 3 nhóm dữ liệu mobile là SSOT: thiết bị + push token, push preference, outbox nhận offline từ thiết bị. **Local cache trên thiết bị (SQLite mã hóa, TTL, purge khi logout/remote wipe) KHÔNG có schema server** — server không phản chiếu và không khôi phục được nội dung cache.

---

## 1. Schema Organization

| Schema | System | Mục đích |
|--------|--------|---------|
| `mbi_device` | SYS-MOBILE-INTERNAL | Device registration, push preference, offline outbox nhận về |

**Quy tắc naming:** bảng `snake_case` số nhiều; cột `snake_case`; index `idx_[table]_[columns]`; FK `fk_[table]_[ref_table]`.

**Liên kết chéo hệ thống:** `user_id` tham chiếu logic tới `core_identity.users` nhưng **KHÔNG đặt FK cross-schema** (khác phân hệ, chỉ được truy cập qua REST/event theo P3-01 §4) — integrity bảo đảm ở tầng ứng dụng + audit.

---

## 2. mbi_device Tables (schema: mbi_device)

### TBL-MBI-001 — mobile_device

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

### TBL-MBI-002 — push_preference

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

### TBL-MBI-003 — offline_outbox (server-side nhận)

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

## 3. Common Patterns

Áp dụng chuẩn chung: trigger `updated_at`; mọi query thêm `WHERE deleted_at IS NULL`; UUID v4; UTC lưu DB, hiển thị GMT+7. Không dùng full-text search (không có trường văn bản nghiệp vụ).

---

## 4. Migration Strategy

```
Convention: migrations/mbi/[YYYYMMDDHHMMSS]_[description].sql
Rules: 1 DDL/migration; có UP + DOWN; test dev/staging trước prod; không sửa migration đã chạy prod.
Khởi điểm: 20260913000000_create_mbi_device_schema.sql (schema + 3 bảng + indexes).
```

Volume nhỏ (≈ số nhân viên nội bộ) — không cần partitioning; outbox trim theo retention.

---

## 5. Index Strategy

| Bảng | Index | Lý do |
|------|-------|-------|
| mobile_device | `uq_device_user (user_id, device_id)` | Binding 1 user–1 thiết bị — kiểm tra mỗi request |
| mobile_device | `idx_mdevice_status` (partial), `idx_mdevice_last_seen` | Lọc active khi push dispatch; sweep thiết bị ngủ lâu |
| push_preference | `uq_push_pref` | Idempotency khi PUT preference |
| offline_outbox | `uq_outbox_idem` | Chống replay trùng — ràng buộc cứng mức DB |
| offline_outbox | `idx_outbox_user_status` | Theo dõi sync fail của user |
