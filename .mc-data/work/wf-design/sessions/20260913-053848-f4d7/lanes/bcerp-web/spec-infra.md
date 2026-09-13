# Infrastructure Specification — SYS-BCERP-WEB [fragment]

> READS: `P3-01-architecture.md` (§1 stack, §3 ports/schemas, §7 môi trường), `lanes/bcerp-web/arch-draft.md` + `signals.json` (tech_recommendations)
> OUTPUT: Containers/services riêng của SYS-BCERP-WEB, env vars, scale policy, consumption requirements tới CORE/GW
> USED BY: `technical-specs/infra-spec.md` (aggregation), `phase6-deployment/deployment-guide.md`
> DATE: 2026-09-13 | Infra ID convention: `INFRA-ERP-NNN`

> **Phạm vi (scope guard):** chỉ định nghĩa container/service của SYS-BCERP-WEB. PostgreSQL cluster, Redis, Kafka/event bus, K8s/Docker orchestration, backup platform là **nền tảng dùng chung** — không định nghĩa lại ở đây, chỉ nêu yêu cầu consumption (§5). REQ-BOD-011 (SSO/MFA), REQ-FIN-012 (WORM), REQ-HR-010 (PII masking) tiêu thụ dịch vụ của SYS-CORE-BACKEND; REQ-FIN-005 (API 7 nền tảng + degraded mode) tiêu thụ SYS-INTEGRATION-GW.

## 1. Environments

Theo P3-01 §7 (không lặp lại): Dev `localhost:8080–8085` docker-compose; Staging `staging.bcerp.bcagency.vn` branch `develop` auto-deploy; Prod `bcerp.bcagency.vn` branch `main` deploy thủ công có phê duyệt. SYS-BCERP-WEB chiếm **port 8081** (domain API + BFF cùng deployment monolith).

## 2. Required Environment Variables

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

## 3. Server / Container Specs

| ID | Service | Loại | CPU | RAM | Replicas (prod) | Nội dung |
|----|---------|------|-----|-----|-----------------|----------|
| INFRA-ERP-001 | `erp-bff` | container (process) | 1 vCPU | 1GB | 2 | BFF aggregation cho web SPA (NestJS), proxy auth sang CORE, không chứa business logic |
| INFRA-ERP-002 | `erp-domain-api` | container (process) | 2 vCPU | 2GB | 2 | Modular monolith 5 bounded context (sales/finance/delivery/care/people) + approval engine dùng chung; expose `/api/v1/erp/*` |
| INFRA-ERP-003 | `erp-sla-worker` | container (worker) | 1 vCPU | 1GB | 2 (active-active, lock Redis per timer) | COMP-ERP-006: quét/đổ timer SLA, phát `sla.warning/breach`, dispatch notification idempotent |
| INFRA-ERP-004 | `erp-scheduler` | container (worker) | 1 vCPU | 1GB | 1 (leader election qua Redis lock) | COMP-ERP-007: đối trừ 3 số, sweep hard stop tại nguồn (REQ-FIN-006), aging/dunning, HĐLĐ 90/60/30, KPI aggregate, clawback, capacity, checkpoint handoff |
| INFRA-ERP-005 | Web SPA static (React) | static bundle trên CDN/nginx | — | — | theo CDN | Frontend web nội bộ; gọi duy nhất qua `erp-bff` |

Replicas tính cho ~100–200 user nội bộ đồng thời + 2.600 TKQC registry read; không auto-scale ngày 1 (REQ [NEEDS_REVIEW: quy mô user nội bộ chưa có căn cứ — đề xuất kiểm chứng khi load test]).

## 4. Networking

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

## 5. Storage & Dependencies Consumption

| ID | Nguồn tiêu thụ | Yêu cầu của SYS-BCERP-WEB | REQ |
|----|----------------|---------------------------|-----|
| INFRA-ERP-006 | PostgreSQL 16 platform cluster | 5 schemas riêng (erp_sales/finance/ops/people/sla); isolation cấp schema; backup theo policy platform; connection pool ~10/container prod | REQ-FIN-001…011 |
| INFRA-ERP-007 | Redis platform | SLA timer scan + distributed lock scheduler + idempotency registry tiền + cache PDP/BFF | REQ-OPS-008, REQ-FIN-001 |
| INFRA-ERP-008 | Event bus (Kafka đề xuất) + outbox DB | Topic ERP events (§7 spec-api); outbox table `erp_sla.outbox_events`; DLQ per topic + `job_dead_letters`; consumer ERP idempotent | P3-01 §5 |
| INFRA-ERP-009 | Object storage S3-compatible + WORM Object Lock (qua CORE COMP-CORE-005) | Chứng từ tiền/HĐĐT/evidence hard stop ≥10 năm — ERP push URI, không tự quản retention | REQ-FIN-012 |
| — | SYS-CORE-BACKEND BI Serving | Render dashboard P&L với freshness metadata (`is_stale`) — không tự query warehouse | REQ-BOD-003/004 |
| — | SYS-INTEGRATION-GW health/feed | statements 7 nền tảng phục vụ đối trừ; hiển thị `source_label` api/manual khi degraded (DI-007) | REQ-FIN-004/005 |

## 6. Deployment Setup

Container Docker; orchestration + CI/CD theo platform chung (P3-01 §7, chi tiết ở deployment-guide). Yêu cầu riêng: (1) deploy `erp-scheduler` sau `erp-domain-api` (migration chạy trước bởi api container); (2) health-check gate trước khi cắt traffic: `/health/ready` phải xanh và lock Redis khả dụng; (3) roll-back image cũ phải bảo đảm SLA timer không mất (timer persist trong DB — restart an toàn).

## 7. Health Check Endpoints

| Endpoint | Checks | Expected |
|----------|--------|----------|
| `GET /health` | App running | `{ "status": "ok" }` |
| `GET /health/db` | 5 schema ERP reachable | `{ "status": "ok", "latency": "Xms" }` |
| `GET /health/redis` | Lock + idempotency registry | `{ "status": "ok" }` |
| `GET /health/ready` | DB + Redis + CORE PDP reachable | `{ "status": "ready", "deps": { "core": "ok" } }` |
| `GET /health/sla-worker` (INFRA-ERP-003) | Timer lag, lock holder | `{ "status": "ok", "timer_lag_seconds": N }` |
| `GET /health/scheduler` (INFRA-ERP-004) | Lock state, job backlog, DLQ depth | `{ "status": "ok", "dlq_depth": N }` |

## 8. Monitoring & Alerting

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

## 9. Non-Functional Requirements (Kỹ Thuật Hóa)

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
