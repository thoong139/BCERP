# Infra Spec — BCERP

> **Dựa trên:** P3-01-architecture.md + feature specs Phase 2 + Business Context Baseline v4.1 | **Session:** 20260913-053848-f4d7 | **Ngày:** 13/09/2026
> **Cấu trúc:** Mỗi system 1 section (fragment do lane agent sinh, ID convention riêng: API-ERP/API-CORE/API-GW/API-PORTAL/API-MBI/API-MPO). Aggregation + dedup api_id ở Phase 3.
> Môi trường dev/staging/prod + nền tảng chung (K8s, Kafka, Redis, object storage WORM) được tham chiếu từ P3-01 §7; fragment mỗi system chỉ nêu thành phần riêng.


## Hệ thống: SYS-BCERP-WEB — BCERP Web nội bộ

## Infrastructure Specification — SYS-BCERP-WEB [fragment]

> READS: `P3-01-architecture.md` (§1 stack, §3 ports/schemas, §7 môi trường), `lanes/bcerp-web/arch-draft.md` + `signals.json` (tech_recommendations)
> OUTPUT: Containers/services riêng của SYS-BCERP-WEB, env vars, scale policy, consumption requirements tới CORE/GW
> USED BY: `technical-specs/infra-spec.md` (aggregation), `phase6-deployment/deployment-guide.md`
> DATE: 2026-09-13 | Infra ID convention: `INFRA-ERP-NNN`

> **Phạm vi (scope guard):** chỉ định nghĩa container/service của SYS-BCERP-WEB. PostgreSQL cluster, Redis, Kafka/event bus, K8s/Docker orchestration, backup platform là **nền tảng dùng chung** — không định nghĩa lại ở đây, chỉ nêu yêu cầu consumption (§5). REQ-BOD-011 (SSO/MFA), REQ-FIN-012 (WORM), REQ-HR-010 (PII masking) tiêu thụ dịch vụ của SYS-CORE-BACKEND; REQ-FIN-005 (API 7 nền tảng + degraded mode) tiêu thụ SYS-INTEGRATION-GW.

### 1. Environments

Theo P3-01 §7 (không lặp lại): Dev `localhost:8080–8085` docker-compose; Staging `staging.bcerp.bcagency.vn` branch `develop` auto-deploy; Prod `bcerp.bcagency.vn` branch `main` deploy thủ công có phê duyệt. SYS-BCERP-WEB chiếm **port 8081** (domain API + BFF cùng deployment monolith).

### 2. Required Environment Variables

Base (DATABASE_URL, REDIS_URL, PORT, NODE_ENV, LOG_LEVEL, TZ=UTC, CORS_ORIGINS) theo template chung. Biến riêng của SYS-BCERP-WEB:

| Variable | Mô tả | Required | Ví dụ |
|----------|-------|---------|-------|
| `ERP_DB_SCHEMA_LIST` | Schemas ERP sở hữu | ✅ | `erp_sales,erp_finance,erp_ops,erp_people,erp_sla` |
| `CORE_BASE_URL` | SYS-CORE-BACKEND (SSO/PDP/BI serving/audit API) | ✅ | `http://core-backend:8080` |
| `CORE_INTERNAL_TOKEN` | Service-to-service token gọi CORE (X-Internal-Token) | ✅ | Random secure string |
| `GW_BASE_URL` | SYS-INTEGRATION-GW (statements/health/degraded flag) | ✅ | `http://integration-gw:8082` |
| `GW_INTERNAL_TOKEN` | Token gọi GW | ✅ | Random secure string |
| `PORTAL_SERVICE_TOKEN` | Token xác thực SYS-PORTAL-WEB tạo ticket (API-ERP-057) | ✅ | Random secure string |
| `PDP_CACHE_TTL_SECONDS` | Cache PDP decision (mặc định 60) | Recommended | `60` |
| `MFA_STEPUP_CLAIM` | Claim mức MFA yêu cầu cho money command | ✅ | `stepup` |
| `SLA_WORKER_POLL_MS` | Chu kỳ quét sla_timers (fallback khi event trễ) | ✅ | `30000` |
| `SLA_TIMEZONE` | Timezone tính SLA | ✅ | `Asia/Ho_Chi_Minh` |
| `SCHEDULER_LOCK_TTL_SECONDS` | Distributed lock Redis cho cron job | ✅ | `600` |
| `MONEY_IDEMPOTENCY_TTL_HOURS` | TTL giữ kết quả Idempotency-Key tiền | ✅ | `48` |
| `OUTBOX_DISPATCH_BATCH` | Số event outbox dispatch mỗi lượt | Recommended | `100` |
| `LOW_BALANCE_COVERAGE_DAYS` | Ngưỡng dự chi cảnh báo (mặc định 3 ngày) | ✅ | `3` |

> Không có biến credentials nền tảng TKQC ở đây — connector + vault thuộc SYS-INTEGRATION-GW (REQ-BOD-008); ERP chỉ đọc health/degraded flag.

### 3. Server / Container Specs

| ID | Service | Loại | CPU | RAM | Replicas (prod) | Nội dung |
|----|---------|------|-----|-----|-----------------|----------|
| INFRA-ERP-001 | `erp-bff` | container (process) | 1 vCPU | 1GB | 2 | BFF aggregation cho web SPA (NestJS), proxy auth sang CORE, không chứa business logic |
| INFRA-ERP-002 | `erp-domain-api` | container (process) | 2 vCPU | 2GB | 2 | Modular monolith 5 bounded context (sales/finance/delivery/care/people) + approval engine dùng chung; expose `/api/v1/erp/*` |
| INFRA-ERP-003 | `erp-sla-worker` | container (worker) | 1 vCPU | 1GB | 2 (active-active, lock Redis per timer) | COMP-ERP-006: quét/đổ timer SLA, phát `sla.warning/breach`, dispatch notification idempotent |
| INFRA-ERP-004 | `erp-scheduler` | container (worker) | 1 vCPU | 1GB | 1 (leader election qua Redis lock) | COMP-ERP-007: đối trừ 3 số, sweep hard stop tại nguồn (REQ-FIN-006), aging/dunning, HĐLĐ 90/60/30, KPI aggregate, clawback, capacity, checkpoint handoff |
| INFRA-ERP-005 | Web SPA static (React) | static bundle trên CDN/nginx | — | — | theo CDN | Frontend web nội bộ; gọi duy nhất qua `erp-bff` |

Replicas tính cho ~100–200 user nội bộ đồng thời + 2.600 TKQC registry read; không auto-scale ngày 1 (REQ [NEEDS_REVIEW: quy mô user nội bộ chưa có căn cứ — đề xuất kiểm chứng khi load test]).

### 4. Networking

```
Nội bộ VPC:
  Web SPA → HTTPS :443 → erp-bff (8081) → erp-domain-api (8081, cùng network nội bộ)
  erp-domain-api → core-backend:8080 (auth/PDP/BI/audit) — internal only
  erp-domain-api / erp-scheduler → integration-gw:8082 (statements/health) — internal only
  erp-domain-api ← portal-bff:8083 (POST /api/v1/erp/tickets với service token) — internal only
  Tất cả container → PostgreSQL :5432, Redis :6379 — internal network only
Firewall: không expose 8081 ra ngoài công cộng; chỉ VPC + reverse proxy tổ chức.
Mobile apps (MOBILE-INTERNAL) tái sử dụng cùng /api/v1/erp/* qua BFF 8084 — không nhân bản API.
```

### 5. Storage & Dependencies Consumption

| ID | Nguồn tiêu thụ | Yêu cầu của SYS-BCERP-WEB | REQ |
|----|----------------|---------------------------|-----|
| INFRA-ERP-006 | PostgreSQL 16 platform cluster | 5 schemas riêng (erp_sales/finance/ops/people/sla); isolation cấp schema; backup theo policy platform; connection pool ~10/container prod | REQ-FIN-001…011 |
| INFRA-ERP-007 | Redis platform | SLA timer scan + distributed lock scheduler + idempotency registry tiền + cache PDP/BFF | REQ-OPS-008, REQ-FIN-001 |
| INFRA-ERP-008 | Event bus (Kafka đề xuất) + outbox DB | Topic ERP events (§7 spec-api); outbox table `erp_sla.outbox_events`; DLQ per topic + `job_dead_letters`; consumer ERP idempotent | P3-01 §5 |
| INFRA-ERP-009 | Object storage S3-compatible + WORM Object Lock (qua CORE COMP-CORE-005) | Chứng từ tiền/HĐĐT/evidence hard stop ≥10 năm — ERP push URI, không tự quản retention | REQ-FIN-012 |
| — | SYS-CORE-BACKEND BI Serving | Render dashboard P&L với freshness metadata (`is_stale`) — không tự query warehouse | REQ-BOD-003/004 |
| — | SYS-INTEGRATION-GW health/feed | statements 7 nền tảng phục vụ đối trừ; hiển thị `source_label` api/manual khi degraded (DI-007) | REQ-FIN-004/005 |

### 6. Deployment Setup

Container Docker; orchestration + CI/CD theo platform chung (P3-01 §7, chi tiết ở deployment-guide). Yêu cầu riêng: (1) deploy `erp-scheduler` sau `erp-domain-api` (migration chạy trước bởi api container); (2) health-check gate trước khi cắt traffic: `/health/ready` phải xanh và lock Redis khả dụng; (3) roll-back image cũ phải bảo đảm SLA timer không mất (timer persist trong DB — restart an toàn).

### 7. Health Check Endpoints

| Endpoint | Checks | Expected |
|----------|--------|----------|
| `GET /health` | App running | `{ "status": "ok" }` |
| `GET /health/db` | 5 schema ERP reachable | `{ "status": "ok", "latency": "Xms" }` |
| `GET /health/redis` | Lock + idempotency registry | `{ "status": "ok" }` |
| `GET /health/ready` | DB + Redis + CORE PDP reachable | `{ "status": "ready", "deps": { "core": "ok" } }` |
| `GET /health/sla-worker` (INFRA-ERP-003) | Timer lag, lock holder | `{ "status": "ok", "timer_lag_seconds": N }` |
| `GET /health/scheduler` (INFRA-ERP-004) | Lock state, job backlog, DLQ depth | `{ "status": "ok", "dlq_depth": N }` |

### 8. Monitoring & Alerting

Ngưỡng chung (error rate, P95, CPU, memory, DB pool) theo template platform. Metric riêng của ERP:

| Metric | Threshold Alert | Severity | REQ |
|--------|----------------|----------|-----|
| SLA timer lag (`sla-worker`) | > 60s | CRITICAL (SLA đỏ 2h phụ thuộc) | REQ-OPS-008 |
| Scheduler job fail / skip 3 lần liên tiếp | bất kỳ | HIGH | REQ-FIN-006 |
| DLQ depth (event + dead-job) | > 0, im lặng > [NEEDS_REVIEW: ngưỡng] | HIGH → escalate on-call 4h (DI-005) | P3-01 §11.4 |
| Outbox backlog | > 500 event / lag > 5 phút | HIGH | P3-01 §5 |
| Hard stop mismatch (sweep phát hiện TKQC active chưa khớp tiền) | > 0 | CRITICAL — auto alert FIN + revert | REQ-FIN-006, REQ-OPS-002 |
| Idempotency conflict rate tiền | > 1% money command | MEDIUM | REQ-FIN-001 |
| DB partition/schema disk | > 80% | MEDIUM | — |

Alert dispatch qua COMP-CORE-011 → COMP-ERP-006 (đa kênh + on-call ngoài giờ).

### 9. Non-Functional Requirements (Kỹ Thuật Hóa)

| Metric | Target đề xuất | Ghi chú |
|--------|----------------|---------|
| API P95 | < 500ms (đọc), < 1.5s (money command qua approval chain) | APM |
| List endpoint P95 | < 800ms với 2.600+ rows TKQC | index §6 spec-db |
| SLA breach detection latency | ≤ 60s kể từ breach_at | sla-worker poll 30s |
| P&L freshness hiển thị | tuân theo `is_stale` metadata từ CORE (≤5 phút target platform) | REQ-BOD-003, REQ-FIN-016 |
| Uptime (giờ làm việc 8–18h GMT+7) | 99.5% | nội bộ |
| RTO / RPO | 4h / 1h (theo platform backup) | restore test hàng tháng |
| Degraded mode | Mọi luồng ERP chạy được 100% manual từ ngày 1 (DI-007) — không phụ thuộc API nền tảng để ghi sổ | REQ-FIN-005 |
| Audit mọi transition | Ghi qua COMP-CORE-004 hash-chain; mất log = lỗi P1 | REQ-BOD-005 |

## Hệ thống: SYS-CORE-BACKEND — Core Backend

## Infrastructure Specification — SYS-CORE-BACKEND (Core Backend)

> Session: 20260913-053848-f4d7 | Lane: core-backend | TRIO: architect + dba + devops
> READS: `P3-01-architecture.md` (§1, §3, §7, §8, §10), `lanes/core-backend/arch-draft.md`
> OUTPUT: Container specs, networking, storage/retention, monitoring cho nền tảng identity/audit/analytics
> USED BY: `phase6-deployment/deployment-guide.md`, `technical-specs/infra-spec.md` (tổng platform)
> DATE: 2026-09-13
>
> **Scope:** hạ tầng phục vụ 11 COMP-CORE (IdP, PDP, Access Review, Audit, WORM, PII/KMS, CDC/ETL, Warehouse, P&L Compute, BI Serving, Alert Engine) của MOD-RBAC-AUDIT + MOD-DATAHUB-BI. Kafka/Redis là infra platform dùng chung — Core liệt kê phần tiêu thụ, chốt stack platform [NEEDS_REVIEW: Phụ lục A #11].

### 1. Environments

Theo P3-01 §7: Development `localhost:8080` (docker-compose, thủ công) · Staging `staging.bcerp.bcagency.vn` branch `develop` auto-deploy · Production `bcerp.bcagency.vn` branch `main` deploy thủ công cần phê duyệt. Riêng WORM store (INFRA-CORE-010) **không deploy bản staging-riêng-bị-xóa**: bucket staging dùng Object Lock governance-mode để test, bucket production dùng compliance-mode — không bao giờ hạ lock compliance.

### 2. Required Environment Variables (đặc thù Core)

Chuẩn chung platform: `DATABASE_URL`, `REDIS_URL`, `PORT`, `NODE_ENV`, `LOG_LEVEL`, `TZ=UTC`, `INTERNAL_SERVICE_TOKEN`, `CORS_ORIGINS` (xem infra-spec tổng). Bổ sung của Core: `OIDC_ISSUER_URL` + `OIDC_REALM_INTERNAL/_PORTAL` (2 realms); `JWT_ACCESS_TTL=900s`, `JWT_REFRESH_TTL=604800s`, `MFA_STEPUP_TTL=300s`; `PDP_CACHE_TTL=60s`; `KMS_ENDPOINT` + `KMS_KEY_ID_PII`; `WORM_ENDPOINT/_BUCKET/_OBJECT_LOCK_MODE` + `WORM_RETENTION_FINANCIAL_YEARS≥10` (REQ-FIN-012); `CH_URL`, `KAFKA_BROKERS`; `PNL_FRESHNESS_SLA_MIN=5` (stream P&L — đồng bộ P3-01 §10.1/§10.3, REQ-BOD-003/FIN-016 [NEEDS_REVIEW: chốt FIN/BOD — Phụ lục A #10]); `WAREHOUSE_RETENTION_RAW_YEARS=2`, `_MARTS_YEARS=5` [NEEDS_REVIEW]; `DLQ_ALERT_THRESHOLD` [NEEDS_REVIEW].

### 3. Server / Container Specs

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

### 4. Networking

Nội bộ (VPN/intranet agency) — Core KHÔNG expose public: Users → LB :443 → svc-idp + svc-core-api (`/api/v1/core/*`); 5 systems (RP/PEP) gọi introspect/pdp-check/audit-append bằng service token; worker-etl-ingest → Kafka :9092 + GW pull API + ClickHouse :9000; svc-core-api → pg-core :5432 (primary ghi, replica đọc) + Redis :6379 + KMS.

Firewall: pg-core chỉ accept từ svc-core-api + workers; ClickHouse chỉ accept từ workers + svc-core-api — KHÔNG có đường query warehouse từ client (P3-01 §10.5); worm-store chỉ accept từ svc-core-api (đường ghi duy nhất) + job verify; kms-pii chỉ accept từ svc-core-api; Kafka nội bộ network; portal DMZ không route vào core network.

### 5. Storage

#### 5.1. Storage Types

| Loại | Lựa chọn | Mục đích | Ghi chú |
|------|----------|----------|---------|
| OLTP | PostgreSQL 16 | identity/policy/audit-metadata/contract/alert | ACID cho hash-chain append + duyệt policy |
| OLAP | ClickHouse (đề xuất) | raw → staged → marts | Tách OLAP khỏi OLTP (P3-01 §1) |
| WORM | S3-compatible + Object Lock | Evidence ≥10 năm: log tiền, chứng từ, decision log access review, export audit | Compliance mode, versioning, MFA-delete off |
| Cache | Redis | Session, PDP cache, BI cache | Ephemeral, regenerable |
| Bus | Kafka | CDC/event/DLQ | Retention topic 7 ngày (replay qua watermark + raw layer) |

#### 5.2. Backup Strategy

| Storage | Phương thức | Tần suất | Kiểm tra restore |
|---------|------------|---------|------------------|
| pg-core | WAL streaming + snapshot | WAL liên tục; snapshot hàng ngày 02:00 UTC | Hàng tháng restore staging |
| clickhouse-olap | Backup table-level + raw layer replay được từ nguồn (nguyên tắc ELT — P3-01 §10.1) | Hàng ngày | Hàng quý — khôi phục 1 mart |
| worm-store | Không backup truyền thống — durability của object storage + replication nội bộ; verify integrity định kỳ (re-hash chain API-CORE-032) | Verify hàng tuần | Hàng quý spot-check 10 objects |
| redis/kafka | Không backup (regenerable/replay) | — | — |

#### 5.3. Retention Policy (đặc thù Core)

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

### 6. Deployment Setup

Container Docker; CI/CD tự động lên staging, prod thủ công có phê duyệt (P3-01 §7). Thứ tự deploy đặc thù Core: (1) pg-core migration → (2) contract registry sync (cùng release module nguồn — spec-db §5) → (3) svc-idp cấu hình realm → (4) svc-core-api → (5) workers → (6) smoke health + verify hash chain. Rolling update svc-core-api; worker có distributed lock Redis nên deploy không tạo job trùng.

### 7. Health Check Endpoints

`GET /health` (app), `/health/db` (pg-core + latency), `/health/redis`, `/health/kafka` (consumer lag), `/health/ch` (ClickHouse), `/health/ready` (sẵn sàng nhận traffic — IdP + PDP reachable). Expected chuẩn `{ "status": "ok" | "ready" }`.

### 8. Monitoring & Alerting

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

### 9. Non-Functional Requirements (Kỹ thuật hóa)

| Metric | Target | Đo bằng | Action nếu vượt |
|--------|--------|---------|-----------------|
| PDP decision P95 | < 50ms cache hit / < 150ms miss | APM | Giữ cache 60s, thêm replica |
| Auth token issue P95 | < 300ms | APM | — |
| Audit append P95 | < 100ms | APM | Buffer + batch insert giữ thứ tự seq |
| BI query P95 (mart) | < 500ms | APM | Index/partition ClickHouse |
| P&L freshness (stream WALLET/ARAP) | ≤ 5 phút (đồng bộ P3-01 §10.1/§10.3 — REQ-BOD-003/FIN-016) [NEEDS_REVIEW: chốt FIN/BOD — Phụ lục A #10] | freshness metadata | Alert HIGH + điều tra ingest |
| Uptime svc-idp/PDP | 99.9% (mọi system phụ thuộc) | Health check | HA 2 replicas |

**DR:** pg-core RTO 4h / RPO 15 phút (WAL streaming); warehouse RPO 24h (replay từ raw + nguồn — chấp nhận được vì pipeline không chặn nghiệp vụ, manual mode sẵn DI-007); WORM zero data loss (durability object storage — evidence 10 năm không được phép mất).

## Hệ thống: SYS-INTEGRATION-GW — API Integration Gateway

## Infrastructure Specification — SYS-INTEGRATION-GW

> READS: `P3-01-architecture.md`, `lanes/integration-gw/arch-draft.md`, `spec-api.md`, `spec-db.md`
> OUTPUT: Môi trường, container specs, networking egress, storage, monitoring của gateway
> USED BY: `phase6-deployment/deployment-guide.md`
> DATE: 2026-09-13 | Scope: gateway service, vault (KMS envelope), sync/backfill workers + queue, raw payload storage, egress per-platform

---

### 1. Environments

| Env | URL | Branch | Auto-deploy |
|-----|-----|--------|------------|
| Development | `localhost:8082` | any | No — docker-compose, adapter mock (không gọi nền tảng thật) |
| Staging | `staging.bcerp.bcagency.vn` (`/api/v1/gw/*`) | `develop` | Yes; sandbox API nếu đã có quyền |
| Production | `bcerp.bcagency.vn` (`/api/v1/gw/*`) | `main` | Manual approval — pull 2.600+ TKQC |

Gateway là headless data plane: KHÔNG public ingress; chỉ nhận request nội bộ (BCERP-WEB BFF, SYS-CORE-BACKEND) trên internal network; duy nhất luồng **egress** đi ra 7 nền tảng + VAS.

### 2. Required Environment Variables (bổ sung cho gateway)

| Variable | Mô tả | Required |
|----------|-------|----------|
| `GW_DATABASE_URL` | PostgreSQL schema `gw_connector`+`gw_tiktok` | ✅ |
| `GW_QUEUE_URL` | Redis Streams cho sync/backfill queue | ✅ |
| `GW_KMS_ENDPOINT` / `GW_KMS_KEY_ID` | KMS master key vault [NEEDS_REVIEW: chốt provider] | ✅ |
| `GW_VAULT_S3_BUCKET` / `GW_RAW_S3_BUCKET` | Bucket encrypted credential / raw payload + evidence | ✅ |
| `GW_RAW_S3_OBJECT_LOCK_DAYS` | Retention raw payload — `730` (24 tháng [NEEDS_REVIEW]) | ✅ |
| `GW_ROTATE_DAYS` / `GW_ROTATE_WARN_DAYS` / `GW_ROTATE_GRACE_DAYS` | `90` / `7` (T-7) / `7` (quá hạn → auto-degraded) | ✅ |
| `GW_EGRESS_PROXY_URL` | Egress proxy per-platform | ✅ |
| `CORE_PDP_URL`, `CORE_AUDIT_SDK_TOKEN`, `INTERNAL_SERVICE_TOKEN` | PDP + audit hash-chain SDK + auth service-to-service | ✅ |
| `PORT`, `NODE_ENV`, `LOG_LEVEL`, `TZ`, `CORS_ORIGINS` | Chuẩn platform (`8082`, `UTC`) | ✅ |

> Không có biến nào chứa secret của nền tảng bên ngoài — mọi credential nền tảng nằm trong vault (TBL-GW-002); đây là nguyên tắc REQ-BOD-008.

### 3. Server / Container Specs

| Service (Infra ID) | CPU | RAM | Storage | Replicas (prod) | Ghi chú |
|---------|-----|-----|---------|-----------------|---------|
| INFRA-GW-001 `gw-api` (REST `/api/v1/gw`) | 2 vCPU | 2GB | — | 2 | Stateless; enforce RBAC/MFA/mask-only; không serve UI |
| INFRA-GW-002 `gw-vault` (vault service) | 1 vCPU | 1GB | — | 2 | Envelope encryption: KMS master + per-credential data key; plaintext chỉ tồn tại trong bộ nhớ service, không log |
| INFRA-GW-003 `gw-sync-worker` | 2 vCPU | 2GB | — | 2–4 | Consumer của queue; 1 worker giữ adapter-lock (không 2 job cùng adapter — BR-GW-STGW-008) |
| INFRA-GW-004 `gw-queue` (Redis Streams) | 1 vCPU | 2GB | AOF | 1 primary + 1 replica | Consumer group per-platform; DLQ stream bắt buộc |
| INFRA-GW-005 `gw-backfill-worker` | 2 vCPU | 2GB | — | 1 (có thể scale) | Chạy theo sự kiện cấp quyền; throttle thấp để không vấp quota |
| INFRA-GW-006 raw payload object storage | — | — | S3-compatible | managed | Versioning + Object Lock; partition `platform/YYYY/MM/DD/jobId` |
| INFRA-GW-007 egress proxy per-platform | 1 vCPU | 1GB | — | 2 | Route riêng 7 nền tảng + VAS; rate limit theo quota từng nguồn; egress IP tĩnh whitelist |
| INFRA-GW-008 PostgreSQL (`gw_connector`, `gw_tiktok`) | dùng chung cluster core | — | SSD | 1 primary + 1 replica | Schema riêng trong DB platform (P3-01 §3); không deploy DB riêng |
| INFRA-GW-009 scheduler (cron + distributed lock Redis) | — | — | — | trên gw-sync-worker | Cửa sổ pull hourly; lock chống overlap |
| INFRA-GW-010 secrets-rotation pipeline | — | — | — | job trong scheduler | Quét `rotate_due_at`: alert T-7 → quá hạn >7 ngày auto-degraded adapter |

HA: `gw-api` + `gw-vault` + `gw-sync-worker` ≥2 replicas; consumer group cho phép worker chết không mất job (pending-redeliver). Sự cố gateway kéo dài không chặn nghiệp vụ — degraded manual vẫn nhập được khi gateway sống lại (DI-007), nhưng gateway vẫn là SPOF của dữ liệu platform: ưu tiên HA queue + worker.

### 4. Networking

```
Internal (không public ingress):
  BCERP-WEB BFF / CORE-BACKEND ──► gw-api :8082   (internal network, mTLS/service-token)
  gw-api ──► gw-vault :8083 (chỉ gw-api được gọi; network policy whitelist)
  workers ──► Redis :6379, PostgreSQL :5432 (VPC-only)

Egress (duy nhất luồng đi ra ngoài):
  gw-sync-worker / gw-backfill-worker ──► egress proxy (INFRA-GW-007) ──►
      Meta / Google / TikTok / Bing / X / Pinterest / Yandex / VAS / TikTok Shop API
      - Mỗi nền tảng 1 route + rate-limit riêng theo quota; không share pool
      - Egress IP tĩnh → whitelist Business Verification từng nền tảng (DI-007)
      - Timeouts: connect 5s, read 30s; circuit breaker per-platform (fail liên tục → mở mạch, adapter degraded, nguồn khác không dây chuyền)

Firewall: chặn mọi egress trực tiếp từ pod ra internet không qua proxy (deny-all + allowlist domain per-platform).
Mobile: không có route tới /gw/vault/* — chặn cả tầng network policy lẫn API (BR-GW-STGW-005).
```

### 5. Storage

| Loại | Công nghệ | Mục đích | Ghi chú |
|------|-----------|----------|---------|
| Application DB | PostgreSQL (schema `gw_connector`, `gw_tiktok`) | Registry, vault metadata, sync job, statement gắn nhãn, audit hash | Backup theo chuẩn platform; RLS gw_tiktok |
| Vault blob store | S3 + SSE + KMS data keys (INFRA-GW-002) | Encrypted credential blob | Bucket riêng, quyền ghi chỉ gw-vault; versioning bắt buộc |
| Raw payload | S3 + Object Lock (INFRA-GW-006) | Payload gốc trước parse + import file evidence (evidence_ref) | Reprocess được khi mapping đổi; retention 24 tháng [NEEDS_REVIEW] |
| Cache/queue | Redis (INFRA-GW-004) | Queue + distributed lock + adapter-lock | AOF bật — job không mất khi restart |

Backup: chuẩn cluster PostgreSQL (daily + PITR); bucket vault + raw dùng versioning + cross-region replication nếu provider hỗ trợ. **Không backup plaintext credential** — chỉ encrypted blob + KMS key (key escrow theo policy KMS).

### 6. Deployment Setup

```
Container: Docker | Orchestration: Docker Compose (dev) / K8s hoặc ECS [NEEDS_REVIEW: theo platform — P3-01 §7]
CI/CD:    pipeline dùng chung platform; prod deploy manual approval
Build:    npm ci → test → image (Git SHA) → registry → rolling update → health check
Secrets deploy: chỉ env hạ tầng; KHÔNG BAO GIỜ inject credential nền tảng qua env/CI
Migrate:  job migration trước rolling update; RLS policy bắt buộc present trước khi mở traffic
```

### 7. Health Check Endpoints

| Endpoint | Checks | Expected |
|----------|--------|----------|
| `GET /health` | App running | `{ "status": "ok" }` |
| `GET /health/db` | DB + RLS session | `{ "status": "ok", "latency": "Xms" }` |
| `GET /health/queue` | Redis consumer group lag | `{ "status": "ok", "lag": N }` |
| `GET /health/kms` | KMS reachable (không expose key) | `{ "status": "ok" }` |
| `GET /health/ready` | Sẵn sàng nhận traffic | `{ "status": "ready" }` |

Health chi tiết 7 adapter (thành công/fail/degraded + freshness) là business data — phục vụ qua `GET /gw/health` (API-GW-024) cho console, không trộn vào infra health.

### 8. Monitoring & Alerting

| Metric | Threshold Alert | Severity | Ghi chú |
|--------|-----------------|----------|---------|
| Sync job fail liên tục per-platform | >3 attempt / 1 nguồn | HIGH → auto-degraded + alert gộp theo nguồn | BR-GW-STGW-008 — không bắn từng job |
| Data freshness vượt SLA | >4h platform / >2h shop | HIGH | Đầu vào REQ-OPS-003 SLA đỏ |
| Credential quá hạn rotate | T-7 warn; >7 ngày | HIGH / CRITICAL → auto-degraded | INFRA-GW-010 |
| Rate-limit gần quota | >80% quota cửa sổ | MEDIUM | Throttle worker |
| Queue lag / DLQ depth | lag >15 phút / DLQ >0 | HIGH | DLQ replay là hành động người |
| Vault/MFA auth fail | ≥3 lần / 5 phút | CRITICAL | Kèm cảnh báo mobile-attempt |
| Hash-chain audit lệch | bất kỳ | CRITICAL → alert BOD | REQ-BOD-005 |
| CPU/RAM/Disk | >85% / >90% / >80% | MEDIUM/HIGH | Chuẩn platform |

**Alert channels:** qua COMP-CORE-011 + dispatch MOD-SLA-NOTIF (đa kênh; on-call 4h ngoài giờ — DI-005). **Dashboards:** Grafana — freshness 7 nguồn, job success rate, queue lag, rotate due timeline, egress error per-platform.

### 9. Non-Functional Requirements

| Metric | Target | Action nếu vượt |
|--------|--------|-----------------|
| API P95 `/gw/statements` | < 500ms | Index review (idx_statement_recon) |
| Cửa sổ pull hourly hoàn tất | 100% trong 60 phút | Tăng batch/worker; ưu tiên TKQC active |
| Vault decrypt (P95) | < 200ms | KMS data-key cache trong bộ nhớ service |
| Backfill throughput | [NEEDS_REVIEW: chốt khi có volume thực] | Scale backfill worker |
| Uptime gateway | 99.5% (đồng bộ platform) | HA replicas; degraded manual là lưới an toàn nghiệp vụ |
| RTO / RPO | 4h / 1h | Queue AOF + PITR DB |

**Secrets rotation vận hành (REQ-BOD-008/REQ-BOD-007):** job hàng ngày quét `rotate_due_at` → T-7 alert CTO → đến hạn: SYS_ADMIN thực thi rotate sau duyệt (tạo CredentialVersion mới, giữ lịch sử) → quá hạn >7 ngày: adapter tự `degraded` + escalation. Offboarding/thu hồi khẩn ≤24h theo checklist CTO; thu hồi vô hiệu token ở nền tảng ở mức khả thi, REVOKED bắt buộc trước khi nạp credential mới.

## Hệ thống: SYS-PORTAL-WEB — Client Portal Web

## Infrastructure Specification — SYS-PORTAL-WEB (Client Portal Web)

> READS: `P3-01-architecture.md` (§1, §3, §7), `lanes/portal-web/arch-draft.md` (§5, §6, §7)
> OUTPUT: Môi trường, container specs, network DMZ, storage, monitoring cho portal client-facing
> USED BY: `phase6-deployment/deployment-guide.md`
> DATE: 2026-09-13

---

### 1. Environments

| Env | URL | Branch | Auto-deploy | Ghi chú |
|-----|-----|--------|------------|---------|
| Development | `localhost:8083` (docker-compose) | any | No | DMZ mô phỏng bằng docker network riêng |
| Staging | `staging-portal.bcagency.vn` (DMZ) | `develop` | Yes | Dữ liệu tổng hợp không phải dữ liệu khách thật |
| Production | `portal.bcagency.vn` (DMZ — domain riêng khỏi `bcerp.bcagency.vn` nội bộ) | `main` | Manual approval | — |

### 2. Required Environment Variables

| Variable | Mô tả | Required | Ví dụ |
|----------|-------|----------|-------|
| `PORTAL_DATABASE_URL` | PostgreSQL schema `portal_account` (instance DMZ data subnet) | ✅ | `postgresql://…/portal` |
| `PORTAL_REDIS_URL` | Redis portal (namespace `portal:*`) | ✅ | `redis://…:6379/2` |
| `OIDC_ISSUER_URL`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` | IdP COMP-CORE-001 + OIDC client portal | ✅ | — |
| `OIDC_AUDIENCE` | Bắt buộc `portal` — internal token bị từ chối | ✅ | `portal` |
| `JWKS_URL` | Verify JWT qua JWKS (không share secret với internal) | ✅ | — |
| `CORE_PORTAL_VIEWS_URL` | Read-view CORE (RLS + tenant filter + mask) | ✅ | `https://core.internal/api/v1/core/portal-views` |
| `ERP_TICKETS_URL` | Điểm ghi ticket duy nhất (SYS-BCERP-WEB) | ✅ | `https://erp.internal/api/v1/erp/tickets` |
| `WATERMARK_SERVICE_URL`, `KMS_KEY_ID` | COMP-PORTAL-005; mã hóa totp_secret AES-256-GCM | ✅ | — |
| `PORTAL_SESSION_TTL_HOURS` | TTL refresh token (mặc định 12h — đề xuất) | ✅ | `12` |
| `OTP_TTL_MINUTES` / `INVITE_TTL_DAYS` | Mặc định 5 phút / 7 ngày — cấu hình, không hardcode | ✅ | `5` / `7` |
| `RATE_LIMIT_*`, `CORS_ORIGINS`, `TZ` | Ngưỡng theo spec-api mục 8; CORS chỉ domain portal; UTC lưu, GMT+7 hiển thị mặc định | ✅ | — |

### 3. Server / Container Specs

| INFRA-ID | Service | CPU | RAM | Replicas (prod) | Zone |
|----------|---------|-----|-----|-----------------|------|
| INFRA-PORTAL-001 | Portal SPA static — CDN host + edge WAF | CDN managed | — | — | Edge/DMZ |
| INFRA-PORTAL-002 | Portal BFF/API Gateway (NestJS, port 8083) | 2 vCPU | 2GB | 2 | DMZ-app |
| INFRA-PORTAL-003 | Portal Identity & Account service | 1 vCPU | 1GB | 2 | DMZ-app |
| INFRA-PORTAL-004 | Read-model cache Redis (TTL 15 phút–24h theo loại view) | 1 vCPU | 2GB | 1 (+ replica đề xuất) | DMZ-data |
| INFRA-PORTAL-005 | PostgreSQL `portal_account` (schema riêng, volume 50GB SSD) | 2 vCPU | 4GB | 1 primary | DMZ-data |
| INFRA-PORTAL-006 | Audit log store — bảng append-only hash-chain + job verify chuỗi ngày + archive | dùng INFRA-PORTAL-005 + object storage | — | — | DMZ-data |
| INFRA-PORTAL-007 | Watermark render service (nếu tách; mặc định sidecar cùng COMP-PORTAL-005) | 1 vCPU | 1GB | 2 | DMZ-app |
| INFRA-PORTAL-008 | Rate limit/WAF: WAF edge (OWASP CRS) + rate limiter ở BFF (Redis) + rules anomaly | đi kèm 001/002 | — | — | Edge + DMZ-app |
| INFRA-PORTAL-009 | Network segmentation DMZ (subnets + firewall + egress allowlist, mục 4) | — | — | — | Platform |
| INFRA-PORTAL-010 | TLS & secrets: cert portal domain, mTLS service-to-service, KMS key | — | — | — | Platform |

COMP-PORTAL-004 (Read-Model Serving) và COMP-PORTAL-006 (Adoption Forwarder) chạy trong runtime BFF (INFRA-PORTAL-002) như module riêng — không container riêng ở giai đoạn này.

### 4. Networking (biên giới tin cậy — bắt buộc tách biệt nội bộ)

```
Internet ──HTTPS 443──► [Edge: CDN + WAF] ──► [DMZ-app: BFF 8083, Identity, Watermark]
                                                │            │
                                     [DMZ-data: PG 5432]  [DMZ-data: Redis 6379]
                                                │
                            Egress allowlist (mTLS, dịch vụ tới dịch vụ):
                              DMZ-app ──► CORE IdP + /core/portal-views (REST, mTLS)
                              DMZ-app ──► ERP POST /erp/tickets (điểm ghi duy nhất)
                              Forwarder ──► CORE event bus (portal.adoption.*)
Firewall rules:
  - Chỉ 80/443 public tại edge; KHÔNG port quản trị nào public
  - DMZ KHÔNG có route tới DB nội bộ (ERP/CORE/GW) — deny all, chỉ allowlist ở trên
  - PG/Redis chỉ accept từ DMZ-app subnet
  - Vault management + mọi API GW nội bộ: KHÔNG reachable từ DMZ
```

Nguyên tắc: portal không bao giờ chạm DB nội bộ (arch-draft §1); vi phạm route là finding bảo mật P0.

### 5. Storage

| Loại | Công cụ | Mục đích | Backup |
|------|---------|----------|--------|
| Portal DB | PostgreSQL `portal_account` | Account/session/tenant_ref/export job | Snapshot ngày (02:00 UTC) + restore test tháng |
| Cache | Redis (namespace `portal:*`) | Session, rate limit, read-model TTL | Không backup — regenerable |
| Audit log | Bảng append-only + archive object storage | access/download/anomaly log | Archive liên tục; verify chuỗi ngày; retention hot 90 ngày → archive [NEEDS_REVIEW: retention portal log — registry chưa định nghĩa] |
| Export file | Object storage private bucket | File watermark, expires 24h, xóa tự động | Không — ephemeral |
| SPA assets | CDN + immutable hash filename | Static bundle | Git + registry image |

### 6. Deployment Setup

Docker image per service (BFF, Identity, Watermark), Git SHA tag, registry nội bộ; deploy rolling 2 replicas qua CI/CD, production manual approval (P3-01 §7). Bắt buộc trước mở traffic: test isolation SC-001/SC-008, test read-only SC-005, test watermark SC-004 — fail → block deploy.

### 7. Health Check Endpoints

| Endpoint | Checks | Expected |
|----------|--------|----------|
| `GET /health` | App running | `{ "status": "ok" }` |
| `GET /health/db` | PG portal | `{ "status": "ok", "latency": "Xms" }` |
| `GET /health/redis` | Redis portal | `{ "status": "ok" }` |
| `GET /health/ready` | Sẵn sàng nhận traffic | `{ "status": "ready" }` |
| `GET /health/dependencies` | CORE read-views + IdP phản hồi | degrade → trang trạng thái, không hiện số cũ |

### 8. Monitoring & Alerting

| Metric | Threshold | Severity |
|--------|-----------|----------|
| `TENANT_CROSS_ACCESS` (403) / chain verify log fail | ≥1 lần | CRITICAL — escalate SYS_ADMIN/FIN_L2 |
| Watermark render fail khi xuất | ≥1 | HIGH — chặn xuất + alert |
| Freshness view vượt 2×SLA | 15 phút liên tục | MEDIUM — trang trạng thái thay số cũ |
| Login fail spike (>20/phút/tenant) | vượt ngưỡng | HIGH — kiểm tra brute force |
| Rate limit gần ngưỡng / adoption forward backlog-DLQ | >80% quota / >0 | MEDIUM (gate Day 14 thiếu dữ kiện) |
| Error rate / P95 / CPU / disk | chuẩn platform (1% / 2s / 85% / 80%) | theo platform |

Alert channels + dashboards: theo platform (COMP-CORE-011 alert center + on-call 4h ngoài giờ DI-005).

### 9. Non-Functional Requirements

| Metric | Target | Ghi chú |
|--------|--------|---------|
| API P95 (BFF) | < 500ms | Read-model hit cache; miss → kéo CORE |
| Page load (FCP) | < 1.5s | CDN + code splitting SPA |
| Concurrent users | 1.000+ tenant, ~12 user/tenant | BFF horizontal scale; cache Redis giảm tải CORE |
| Uptime portal | 99.5% (đề xuất) | Phụ thuộc availability CORE (SSO + read-view) — chấp nhận SSOT; fail → trang trạng thái |
| RTO / RPO | 4h / 1h (đề xuất — theo platform) | Portal DB nhỏ, restore nhanh |
| Retention | Session >30 ngày dọn; OTP >24h dọn; export file 24h; log portal 90 ngày hot + archive [NEEDS_REVIEW] | Không đụng WORM ≥10 năm (thuộc CORE) |

## Hệ thống: SYS-MOBILE-INTERNAL — Mobile BCERP Internal

## Infrastructure Specification — SYS-MOBILE-INTERNAL

> READS: `P3-01-architecture.md` (§1, §3, §7), `lanes/mobile-internal/arch-draft.md`, `lanes/mobile-internal/spec-api.md`, `spec-db.md`
> OUTPUT: Môi trường, container specs, networking, push gateway, app distribution, cert pinning, min-version gating, monitoring
> USED BY: `phase6-deployment/deployment-guide.md`
> DATE: 2026-09-13

---

### 1. Environments

| Env | URL (BFF) | Branch | Auto-deploy | Mục đích |
|-----|-----------|--------|-------------|----------|
| Development | `localhost:8084` | any | No | Dev BFF + push gateway (push dùng sandbox FCM/APNs) |
| Staging | `staging.bcerp.bcagency.vn/mbi` | `develop` | Yes (on push) | QA app build qua TestFlight / Play internal track |
| Production | `bcerp.bcagency.vn/mbi` | `main` | Manual approval | Live cho toàn bộ nhân viên nội bộ |

> [NEEDS_REVIEW] P3-01 §7 ghi production `bcerp.bcagency.vn` là môi trường nội bộ, nhưng mobile app cần truy cập ngoài văn phòng (chấm công offline-sync, push, duyệt từ xa). Cần chốt chính sách truy cập BFF: (a) public endpoint + device binding + cert pinning + MFA, hoặc (b) VPN-only. Đề xuất (a).

---

### 2. Required Environment Variables

| Variable | Mô tả | Required |
|----------|-------|----------|
| `PORT` / `NODE_ENV` / `LOG_LEVEL` / `TZ` | Port 8084, env, logging, UTC | ✅ |
| `DATABASE_URL_MBI` | PostgreSQL schema `mbi_device` | ✅ |
| `REDIS_URL` | Rate limit + cache + push queue | ✅ |
| `CORE_BACKEND_URL` | SYS-CORE-BACKEND (IdP/PDP/BI serving) | ✅ |
| `ERP_BACKEND_URL` | SYS-BCERP-WEB (target state-transition) | ✅ |
| `INTERNAL_SERVICE_TOKEN` | Auth service-to-service (push dispatch) | ✅ |
| `JWKS_URL` | JWKS core IdP — BFF verify JWT, không giữ secret | ✅ |
| `FCM_CREDENTIALS_JSON` | Service account FCM (file path) | ✅ |
| `APNS_KEY_PATH` / `APNS_KEY_ID` / `APNS_TEAM_ID` / `APNS_ENV` | APNs token auth + sandbox/production | ✅ (iOS) |
| `MBI_BUNDLE_ID` | Bundle id app internal | ✅ |
| `MIN_APP_VERSION` / `PINSET_VERSION` | Min-version gating + pinset hiện hành | ✅ |

---

### 3. Server / Container Specs

| Service (INFRA-ID) | CPU | RAM | Replicas (prod) | Ghi chú |
|--------------------|-----|-----|-----------------|---------|
| Mobile BFF (INFRA-MBI-001) | 1 vCPU | 512MB | 2 | NestJS stateless; proxy + shaping; không queue lâu |
| Push Gateway (INFRA-MBI-002) | 1 vCPU | 512MB | 2 | Consumer SLA-NOTIF/alert/shop → FCM/APNs; queue Redis + retry + DLQ |
| PostgreSQL `mbi_device` (INFRA-MBI-006) | dùng chung cụm platform | — | 1 primary + 1 replica | Volume nhỏ (≈ số nhân viên), không instance riêng |
| Redis | dùng chung | — | 1 | Rate limit, idempotency cache, push queue |

Docker image theo CI/CD chung platform (build, test, Git SHA tag, rolling update, health check).

---

### 4. Networking

```
Mobile app (internet) ── HTTPS 443 ──► Reverse proxy ──► Mobile BFF :8084
Mobile BFF ──► SYS-CORE-BACKEND :8080 · SYS-BCERP-WEB :8081   [internal network]
Push Gateway ──► FCM + APNs (outbound 443, không mở inbound)
COMP-ERP-006 / COMP-CORE-011 / COMP-GW-013 ──► /internal/mbi/push/dispatch [internal]
```

Firewall: chỉ 443 public cho BFF qua reverse proxy — không expose endpoint module backend nào ra ngoài; DB/Redis/backend trong internal network; APNs/FCM outbound-only. Kênh app distribution không đi qua BFF.

---

### 5. App Distribution (INFRA-MBI-003)

| Hạng mục | Đề xuất |
|----------|---------|
| CI build | Fastlane/GitHub Actions: build React Native, sign, upload — secrets trong CI secrets manager, không vào repo |
| iOS | TestFlight Internal Testing theo phòng ban; không App Store public [NEEDS_REVIEW: xác nhận kênh Apple — Enterprise Program hay TestFlight] |
| Android | Google Play Internal Testing; production qua Managed Google Play/MDM hoặc APK ký nội bộ [NEEDS_REVIEW: chọn MDM — chưa có căn cứ] |
| OTA patch | OTA chỉ cho JS bundle UI — không OTA thay đổi native/permission |

Kênh distribution không đi qua BFF.

---

### 6. Cert Pinning & Min-Version Gating (INFRA-MBI-004, INFRA-MBI-005)

**Cert pinning (INFRA-MBI-004):** pin SPK leaf + 1 backup pin (khóa khác CA) cho `bcerp.bcagency.vn`; pinset phân phối qua `GET /api/v1/mbi/app-config` (ký số) + hard-code pin khởi điểm trong build. Rotation: thêm pin mới trước, bỏ pin cũ sau khi 100% app active chứa pin mới (`PINSET_VERSION` tracking). Fail pinning → chặn request + telemetry (không fallback non-pinned).

**Min-version gating (INFRA-MBI-005):** nguồn chân lý là cấu hình `MIN_APP_VERSION` + `platform → min_version` + `force_update` tại BFF app-config. App dưới minimum nhận `426 VERSION_UNSUPPORTED` + URL cài đặt → màn force-update. Thứ tự bắt buộc khi breaking change API: publish min-version mới → chờ adoption → mới deploy v2.

---

### 7. Health Check Endpoints

| Endpoint | Checks | Expected |
|----------|--------|----------|
| `GET /health` (BFF) | App running | `{ "status": "ok" }` |
| `GET /health/ready` (BFF) | JWKS core + ERP reachable | `{ "status": "ready" }` |
| `GET /health/db` | PostgreSQL `mbi_device` | `{ "status": "ok", "latency": "Xms" }` |
| `GET /health` (Push Gateway) | Running + queue depth | `{ "status": "ok", "queue": N }` |

---

### 8. Monitoring & Alerting

| Metric | Threshold Alert | Severity |
|--------|----------------|---------|
| BFF error rate | > 1% / 5 min | HIGH |
| BFF P95 response | > 2s | HIGH |
| Push delivery success (FCM/APNs) | < 95% / 15 min | HIGH |
| Push queue depth / DLQ > 0 | Bất kỳ | HIGH |
| Spike `DEVICE_NOT_BOUND`/revoke | > 5% login thất bại device | MEDIUM (báo hiệu mất máy/tấn công) |
| Cert pinning failure telemetry | > 1% session | HIGH |
| `VERSION_UNSUPPORTED` responses | > 5% request | MEDIUM (tín hiệu cần rollout) |
| Outbox ESS sync fail rate | > 2% replay rejected_invalid | MEDIUM |

Kênh alert + dashboard dùng chung platform (COMP-CORE-011 dispatch; cảnh báo tiền vẫn thuộc backend, push chỉ là kênh).

---

### 9. Non-Functional Requirements (trích — mobile-specific)

| Metric | Target | Đo bằng |
|--------|--------|---------|
| BFF proxy P95 | < 500ms | APM |
| Push latency event → thiết bị | < 30s (p95) | Push Gateway metric |
| Offline replay | 50 bản ghi/thiết bị < 10s | Load test |
| Availability BFF | 99,5% (mất BFF không vỡ SLA — escalation chạy phía backend) | Uptime monitor |
| Backup | `mbi_device` theo backup chung hàng ngày; cache thiết bị không backup | Backup job |

## Hệ thống: SYS-MOBILE-PORTAL — Mobile BC Portal

## Infrastructure Specification — SYS-MOBILE-PORTAL (Mobile App BC Portal)

> READS: `P3-01-architecture.md`, `lanes/mobile-portal/arch-draft.md`, `lanes/mobile-portal/spec-api.md`, `spec-db.md`
> OUTPUT: Môi trường, container, push worker, distribution, min-version gating, monitoring
> USED BY: `phase6-deployment/deployment-guide.md`
> DATE: 2026-09-13

---

### 1. Environments

| Env | URL | Branch | Auto-deploy | Mục đích |
|-----|-----|--------|------------|----------|
| Development | `localhost:8085` (docker-compose) | any | No | Dev BFF + worker |
| Staging | `staging.bcerp.bcagency.vn/api/v1/mpo` | `develop` | Yes | QA + build test mobile (TestFlight/Internal Testing) |
| Production | `portal.bcagency.vn/api/v1/mpo` (DMZ) | `main` | Manual approval | Live khách hàng |

### 2. Required Environment Variables

| Variable | Mô tả | Required |
|----------|-------|----------|
| `PORT` | 8085 | ✅ |
| `DATABASE_URL` | PostgreSQL — schema `mpo_device` | ✅ |
| `REDIS_URL` | Session mobile, OTP window, rate-limit, idempotency, queue push | ✅ |
| `PORTAL_API_BASE_URL` | Read-model API/Portal API Gateway dùng chung (tất cả read + forward ghi) | ✅ |
| `CORE_IDP_URL` | SSO/2FA portal user (COMP-CORE-001) | ✅ |
| `INTERNAL_SERVICE_TOKEN` | Service-to-service auth BFF → PORTAL/CORE | ✅ |
| `FCM_PROJECT_ID` + `FCM_SERVICE_ACCOUNT_JSON` | Android push (vault, không hardcode) | ✅ |
| `APNS_KEY_ID` / `APNS_TEAM_ID` / `APNS_PRIVATE_KEY_PATH` | iOS push token-based (vault) | ✅ |
| `PUSH_SLA_SECONDS` | Ngưỡng phân phối cảnh báo khẩn — 300 (≤5 phút) | ✅ |
| `MIN_VERSION_IOS` / `MIN_VERSION_ANDROID` | Min-version gating (mặc định; cho phép override qua app-config) | ✅ |
| `JWT_*`, `LOG_LEVEL`, `TZ=UTC`, `DB_POOL_SIZE` | Theo chuẩn nền tảng | ✅ |

### 3. Server / Container Specs

| Service | Loại | CPU | RAM | Replicas (prod) | Ghi chú |
|---------|------|-----|-----|-----------------|---------|
| INFRA-MPO-001 `mpo-bff` | service (Node.js/NestJS, cùng stack PORTAL-WEB) | 1 vCPU | 1GB | 2 | Stateless, port 8085; không chứa business logic; mask whitelist + freshness check tại đây |
| INFRA-MPO-002 `mpo-push-worker` | worker | 1 vCPU | 512MB | 2 | Queue consumer (Redis Streams + DLQ); fan-out FCM/APNs; check `status='ACTIVE'` + opt-in trước khi bắn |
| INFRA-MPO-003 `mpo_device` (PostgreSQL) | database | dùng chung instance | — | primary + replica | 2 bảng, RLS tenant; backup theo chuẩn nền tảng |
| INFRA-MPO-004 Redis namespace `mpo:*` | cache/queue | dùng chung | — | 1 | Session, OTP, rate-limit, idempotency key, push queue (ephemeral, không backup) |
| INFRA-MPO-005 Push credentials | secret | — | — | — | FCM service account + APNs key trong vault; xoay vòng ≥90 ngày |

### 4. Networking (INFRA-MPO-008)

```
Public (DMZ — cùng zone PORTAL-WEB):
  Mobile app → HTTPS :443 → LB/WAF → mpo-bff (chỉ /api/v1/mpo/*)

Internal (không expose):
  mpo-bff → PORTAL-WEB read-model + CORE (IdP, PDP): internal network
  mpo-push-worker → Redis queue + FCM/APNs outbound :443
  CẤM: mobile/bff gọi trực tiếp SYS-INTEGRATION-GW; vault management bị từ chối (BR-GW-STGW-005)

Firewall: chỉ 443 public; DB/Redis chỉ accept từ backend IP/VPC
```

### 5. Storage

BFF/worker stateless — không local disk prod. Dữ liệu sở hữu: schema `mpo_device` (PostgreSQL) + Redis ephemeral. Không object storage riêng; sổ phụ PDF do PORTAL-WEB sinh + watermark — mobile chỉ deep-link.

### 6. Deployment Setup

```
Container: Docker; Orchestration: cùng platform PORTAL-WEB (compose dev / K8s hoặc ECS prod — chốt chung, Phụ lục A #11)
CI/CD: build image theo Git SHA → registry → deploy rolling; health check gate
Mobile (INFRA-MPO-006 Distribution): iOS App Store + Google Play; staging qua TestFlight / Play Internal
  Testing; code signing key/keystore trong CI secret vault.
  [NEEDS_REVIEW: kênh phân phối ngoài store (MDM/APK direct) cho khách doanh nghiệp không dùng store]
INFRA-MPO-007 Min-version gating: GET /api/v1/mpo/app-config trả min_version + force_update flag
  (versioned, cache 5 phút); app dưới ngưỡng → chặn API, ép update; nâng ngưỡng khẩn không cần release.
```

### 7. Health Check Endpoints

| Endpoint | Checks | Expected |
|----------|--------|----------|
| `GET /health` | App running | `{ "status": "ok" }` |
| `GET /health/ready` | PORTAL reachable, CORE IdP reachable, Redis, DB `mpo_device` | `{ "status": "ready" }` |
| `GET /health/push` (worker) | Queue lag, FCM/APNs handshake gần nhất | `{ "status": "ok", "queue_lag": N }` |

### 8. Monitoring & Alerting

| Metric | Threshold Alert | Severity |
|--------|----------------|----------|
| Push latency p95 (event khẩn: chuyển mức ví) | > 5 phút từ lúc sync | HIGH (vi phạm nghiệm thu BR-003) |
| FCM/APNs error rate | > 2% / 5 min | HIGH |
| Push tới token REVOKED (phải = 0) | > 0 | CRITICAL |
| BFF error rate / P95 latency; queue lag + DLQ depth | > 1% hoặc > 2s; DLQ > 0 | HIGH — DLQ alert ngay qua COMP-CORE-011 |
| Client version dưới min_version | > 5% session | MEDIUM |

Dashboards: Grafana chung nền tảng; alert dispatch qua COMP-CORE-011 → MOD-SLA-NOTIF (on-call 4h ngoài giờ, DI-005).

### 9. Non-Functional Requirements

| Metric | Target | Ghi chú |
|--------|--------|---------|
| API P95 | < 500ms (read, excludes upstream portal) | Freshness metadata vẫn bắt buộc kèm mọi số liệu |
| Uptime | Theo SLA nền tảng portal (99.5% đề xuất) | Mobile phụ thuộc PORTAL/CORE — không cam kết riêng |
| Push phân phối | ≤ 5 phút event khẩn; log queued→sent→delivered→read | Push không phải nguồn sự thật |
| Session | Timeout theo portal; thu hồi từ xa hiệu lực tức thì | Token revoked không nhận push; RPO/RTO kế thừa nền tảng |

#### [NEEDS_REVIEW]
1. Orchestration platform (K8s/ECS/compose prod) — chốt chung Phụ lục A #11; spec giữ neutral.
2. Kênh phân phối ngoài store cho khách doanh nghiệp (MDM/APK) — chưa có căn cứ registry.
3. Số replica worker theo volume push thực tế (1.000+ khách, tần suất chuyển mức) — ước lượng khởi điểm 2, review sau gate Day 14.
