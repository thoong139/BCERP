# Infrastructure Specification — SYS-CORE-BACKEND (Core Backend)

> Session: 20260913-053848-f4d7 | Lane: core-backend | TRIO: architect + dba + devops
> READS: `P3-01-architecture.md` (§1, §3, §7, §8, §10), `lanes/core-backend/arch-draft.md`
> OUTPUT: Container specs, networking, storage/retention, monitoring cho nền tảng identity/audit/analytics
> USED BY: `phase6-deployment/deployment-guide.md`, `technical-specs/infra-spec.md` (tổng platform)
> DATE: 2026-09-13
>
> **Scope:** hạ tầng phục vụ 11 COMP-CORE (IdP, PDP, Access Review, Audit, WORM, PII/KMS, CDC/ETL, Warehouse, P&L Compute, BI Serving, Alert Engine) của MOD-RBAC-AUDIT + MOD-DATAHUB-BI. Kafka/Redis là infra platform dùng chung — Core liệt kê phần tiêu thụ, chốt stack platform [NEEDS_REVIEW: Phụ lục A #11].

## 1. Environments

Theo P3-01 §7: Development `localhost:8080` (docker-compose, thủ công) · Staging `staging.bcerp.bcagency.vn` branch `develop` auto-deploy · Production `bcerp.bcagency.vn` branch `main` deploy thủ công cần phê duyệt. Riêng WORM store (INFRA-CORE-010) **không deploy bản staging-riêng-bị-xóa**: bucket staging dùng Object Lock governance-mode để test, bucket production dùng compliance-mode — không bao giờ hạ lock compliance.

## 2. Required Environment Variables (đặc thù Core)

Chuẩn chung platform: `DATABASE_URL`, `REDIS_URL`, `PORT`, `NODE_ENV`, `LOG_LEVEL`, `TZ=UTC`, `INTERNAL_SERVICE_TOKEN`, `CORS_ORIGINS` (xem infra-spec tổng). Bổ sung của Core: `OIDC_ISSUER_URL` + `OIDC_REALM_INTERNAL/_PORTAL` (2 realms); `JWT_ACCESS_TTL=900s`, `JWT_REFRESH_TTL=604800s`, `MFA_STEPUP_TTL=300s`; `PDP_CACHE_TTL=60s`; `KMS_ENDPOINT` + `KMS_KEY_ID_PII`; `WORM_ENDPOINT/_BUCKET/_OBJECT_LOCK_MODE` + `WORM_RETENTION_FINANCIAL_YEARS≥10` (REQ-FIN-012); `CH_URL`, `KAFKA_BROKERS`; `PNL_FRESHNESS_SLA_MIN=15` (đề xuất feed ví 5 [NEEDS_REVIEW]); `WAREHOUSE_RETENTION_RAW_YEARS=2`, `_MARTS_YEARS=5` [NEEDS_REVIEW]; `DLQ_ALERT_THRESHOLD` [NEEDS_REVIEW].

## 3. Server / Container Specs

| INFRA ID | Service | Image/runtime | CPU | RAM | Storage | Replicas (prod) | Ghi chú |
|----------|---------|--------------|-----|-----|---------|-----------------|---------|
| INFRA-CORE-001 | `svc-idp` (Keycloak đề xuất) | Keycloak 25+ | 2 vCPU | 2GB | — | 2 | OIDC/OAuth2 2 realms; user session phía IdP; HA active-active sau LB |
| INFRA-CORE-002 | `svc-core-api` (NestJS) | Node LTS container | 2 vCPU | 2GB | — | 2 | Auth admin API, PDP, PII, BI Serving (COMP-CORE-010), Alert API, ingest admin; stateless |
| INFRA-CORE-003 | `worker-access-review` | Node LTS | 1 vCPU | 1GB | — | 1 (+lock Redis) | COMP-CORE-003: cron quarterly + recertification event-driven |
| INFRA-CORE-004 | `worker-etl-ingest` | Node LTS + Kafka consumer | 2 vCPU | 2GB | — | 2 | COMP-CORE-007: CDC/event/pull consume, gates G0–G5, watermark |
| INFRA-CORE-005 | `worker-pnl-compute` | Node LTS (stream agg) | 2 vCPU | 2GB | — | 1–2 | COMP-CORE-009: aggregation stream + batch nightly reconcile |
| INFRA-CORE-012 | `worker-alert-engine` | Node LTS | 1 vCPU | 1GB | — | 1 (+lock) | COMP-CORE-011: eval rule, lifecycle alert, push dispatch qua SLANOT |
| INFRA-CORE-006 | `pg-core` | PostgreSQL 16 | 4 vCPU | 8GB | 100GB SSD | 1 primary + 1 replica | 3 schema `core_identity/core_audit/core_dhub`; partition audit_log theo tháng |
| INFRA-CORE-007 | `clickhouse-olap` | ClickHouse (đề xuất) | 4 vCPU | 16GB | 500GB SSD | 1 single-node (scale-out sau) | raw/staged/marts; TTL theo retention §5.3 |
| INFRA-CORE-008 | `redis-core` (platform dùng chung) | Redis 7 | 1 vCPU | 2GB | — | 1 (+sentinel sau) | Session registry, PDP decision cache 60s, BI cache 1–15 phút |
| INFRA-CORE-009 | `kafka-bus` (platform dùng chung) | Kafka (đề xuất) | 2 vCPU | 4GB | 100GB | 3 (quorum) | Topics CDC/event per module + DLQ per topic; thuộc platform nhưng Core là consumer/producer chính |
| INFRA-CORE-010 | `worm-store` | S3-compatible (MinIO/S3) + Object Lock | 2 vCPU | 2GB | Theo tăng trưởng evidence | 1 (bucket versioning + lock) | COMP-CORE-005: retention compliance ≥10 năm REQ-FIN-012 |
| INFRA-CORE-011 | `kms-pii` | KMS (Vault/KMS đề xuất) | 0.5 vCPU | 512MB | — | 2 | Envelope key PII field-level; tách biệt credentials vault của MOD-SETTINGS-GW |

Orchestration đề xuất: Docker Compose cho dev/staging; production bắt đầu single-host + LB, sẵn seam chuyển Kubernetes khi scale (nhất quán modular monolith P3-01 §1). Scale trigger: PDP/BI API CPU > 70% sustained → thêm replica `svc-core-api`; ClickHouse disk > 70% → mở rộng volume trước, shard sau.

## 4. Networking

Nội bộ (VPN/intranet agency) — Core KHÔNG expose public: Users → LB :443 → svc-idp + svc-core-api (`/api/v1/core/*`); 5 systems (RP/PEP) gọi introspect/pdp-check/audit-append bằng service token; worker-etl-ingest → Kafka :9092 + GW pull API + ClickHouse :9000; svc-core-api → pg-core :5432 (primary ghi, replica đọc) + Redis :6379 + KMS.

Firewall: pg-core chỉ accept từ svc-core-api + workers; ClickHouse chỉ accept từ workers + svc-core-api — KHÔNG có đường query warehouse từ client (P3-01 §10.5); worm-store chỉ accept từ svc-core-api (đường ghi duy nhất) + job verify; kms-pii chỉ accept từ svc-core-api; Kafka nội bộ network; portal DMZ không route vào core network.

## 5. Storage

### 5.1. Storage Types

| Loại | Lựa chọn | Mục đích | Ghi chú |
|------|----------|----------|---------|
| OLTP | PostgreSQL 16 | identity/policy/audit-metadata/contract/alert | ACID cho hash-chain append + duyệt policy |
| OLAP | ClickHouse (đề xuất) | raw → staged → marts | Tách OLAP khỏi OLTP (P3-01 §1) |
| WORM | S3-compatible + Object Lock | Evidence ≥10 năm: log tiền, chứng từ, decision log access review, export audit | Compliance mode, versioning, MFA-delete off |
| Cache | Redis | Session, PDP cache, BI cache | Ephemeral, regenerable |
| Bus | Kafka | CDC/event/DLQ | Retention topic 7 ngày (replay qua watermark + raw layer) |

### 5.2. Backup Strategy

| Storage | Phương thức | Tần suất | Kiểm tra restore |
|---------|------------|---------|------------------|
| pg-core | WAL streaming + snapshot | WAL liên tục; snapshot hàng ngày 02:00 UTC | Hàng tháng restore staging |
| clickhouse-olap | Backup table-level + raw layer replay được từ nguồn (nguyên tắc ELT — P3-01 §10.1) | Hàng ngày | Hàng quý — khôi phục 1 mart |
| worm-store | Không backup truyền thống — durability của object storage + replication nội bộ; verify integrity định kỳ (re-hash chain API-CORE-032) | Verify hàng tuần | Hàng quý spot-check 10 objects |
| redis/kafka | Không backup (regenerable/replay) | — | — |

### 5.3. Retention Policy (đặc thù Core)

| Dữ liệu | Thời gian giữ | Căn cứ |
|---------|--------------|--------|
| Audit log class `financial`/`evidence` (WORM) | **≥10 năm**, legal hold | REQ-FIN-012 |
| Audit log class `operational` | ≥3 năm đề xuất [NEEDS_REVIEW] | arch-draft §6 |
| pii_access_log (break-glass) | ≥10 năm (đi kèm evidence PII) | REQ-HR-010 |
| Warehouse raw layer | 2 năm [NEEDS_REVIEW] | P3-01 §10.5 |
| Warehouse marts | 5 năm [NEEDS_REVIEW] | P3-01 §10.5 |
| Kafka topics | 7 ngày | Replay qua watermark + raw |
| Session/refresh token | TTL 7 ngày | P3-01 §8.1 |
| alert_instances resolved | 2 năm đề xuất | REQ-BOD-006 truy vết |

## 6. Deployment Setup

Container Docker; CI/CD tự động lên staging, prod thủ công có phê duyệt (P3-01 §7). Thứ tự deploy đặc thù Core: (1) pg-core migration → (2) contract registry sync (cùng release module nguồn — spec-db §5) → (3) svc-idp cấu hình realm → (4) svc-core-api → (5) workers → (6) smoke health + verify hash chain. Rolling update svc-core-api; worker có distributed lock Redis nên deploy không tạo job trùng.

## 7. Health Check Endpoints

`GET /health` (app), `/health/db` (pg-core + latency), `/health/redis`, `/health/kafka` (consumer lag), `/health/ch` (ClickHouse), `/health/ready` (sẵn sàng nhận traffic — IdP + PDP reachable). Expected chuẩn `{ "status": "ok" | "ready" }`.

## 8. Monitoring & Alerting

Chuẩn platform (error rate >1%/5min HIGH, P95 >2s HIGH, CPU >85% MEDIUM, DB pool >80% MEDIUM, disk >80% MEDIUM, health fail 2 lần CRITICAL) + metric đặc thù Core:

| Metric | Threshold | Severity |
|--------|-----------|----------|
| PDP check latency P95 | > 100ms (PEP timeout 3s) | HIGH |
| PDP unavailable (fail-closed path) | 1 lần | CRITICAL |
| Hash chain verify failed | 1 lần | CRITICAL |
| DLQ depth | > [NEEDS_REVIEW ngưỡng] hoặc tăng liên tục 30 phút | HIGH |
| Ingest freshness vi phạm SLA per nhóm nguồn (§10.3) | 1 kỳ liên tiếp | MEDIUM (ví/P&L: HIGH) |
| Login fail rate | > 20/phút/IP hoặc ≥5 fail/user | HIGH + lock tạm |
| WORM verify failure / retention chạm hạn không gia hạn | 1 lần | CRITICAL |
| Alert engine không eval rule > 5 phút | 1 lần | HIGH |

Kênh + dashboard: alert CRITICAL/HIGH đi qua COMP-CORE-011 → MOD-SLA-NOTIF dispatch (on-call 4h ngoài giờ DI-005); dashboard Grafana đề xuất cho pipeline freshness + DLQ + auth anomalies.

## 9. Non-Functional Requirements (Kỹ thuật hóa)

| Metric | Target | Đo bằng | Action nếu vượt |
|--------|--------|---------|-----------------|
| PDP decision P95 | < 50ms cache hit / < 150ms miss | APM | Giữ cache 60s, thêm replica |
| Auth token issue P95 | < 300ms | APM | — |
| Audit append P95 | < 100ms | APM | Buffer + batch insert giữ thứ tự seq |
| BI query P95 (mart) | < 500ms | APM | Index/partition ClickHouse |
| P&L freshness | ≤ 15 phút (đề xuất feed ví ≤5 [NEEDS_REVIEW]) | freshness metadata | Alert HIGH + điều tra ingest |
| Uptime svc-idp/PDP | 99.9% (mọi system phụ thuộc) | Health check | HA 2 replicas |

**DR:** pg-core RTO 4h / RPO 15 phút (WAL streaming); warehouse RPO 24h (replay từ raw + nguồn — chấp nhận được vì pipeline không chặn nghiệp vụ, manual mode sẵn DI-007); WORM zero data loss (durability object storage — evidence 10 năm không được phép mất).
