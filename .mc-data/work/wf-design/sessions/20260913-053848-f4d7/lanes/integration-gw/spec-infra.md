# Infrastructure Specification — SYS-INTEGRATION-GW

> READS: `P3-01-architecture.md`, `lanes/integration-gw/arch-draft.md`, `spec-api.md`, `spec-db.md`
> OUTPUT: Môi trường, container specs, networking egress, storage, monitoring của gateway
> USED BY: `phase6-deployment/deployment-guide.md`
> DATE: 2026-09-13 | Scope: gateway service, vault (KMS envelope), sync/backfill workers + queue, raw payload storage, egress per-platform

---

## 1. Environments

| Env | URL | Branch | Auto-deploy |
|-----|-----|--------|------------|
| Development | `localhost:8082` | any | No — docker-compose, adapter mock (không gọi nền tảng thật) |
| Staging | `staging.bcerp.bcagency.vn` (`/api/v1/gw/*`) | `develop` | Yes; sandbox API nếu đã có quyền |
| Production | `bcerp.bcagency.vn` (`/api/v1/gw/*`) | `main` | Manual approval — pull 2.600+ TKQC |

Gateway là headless data plane: KHÔNG public ingress; chỉ nhận request nội bộ (BCERP-WEB BFF, SYS-CORE-BACKEND) trên internal network; duy nhất luồng **egress** đi ra 7 nền tảng + VAS.

## 2. Required Environment Variables (bổ sung cho gateway)

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

## 3. Server / Container Specs

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

## 4. Networking

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

## 5. Storage

| Loại | Công nghệ | Mục đích | Ghi chú |
|------|-----------|----------|---------|
| Application DB | PostgreSQL (schema `gw_connector`, `gw_tiktok`) | Registry, vault metadata, sync job, statement gắn nhãn, audit hash | Backup theo chuẩn platform; RLS gw_tiktok |
| Vault blob store | S3 + SSE + KMS data keys (INFRA-GW-002) | Encrypted credential blob | Bucket riêng, quyền ghi chỉ gw-vault; versioning bắt buộc |
| Raw payload | S3 + Object Lock (INFRA-GW-006) | Payload gốc trước parse + import file evidence (evidence_ref) | Reprocess được khi mapping đổi; retention 24 tháng [NEEDS_REVIEW] |
| Cache/queue | Redis (INFRA-GW-004) | Queue + distributed lock + adapter-lock | AOF bật — job không mất khi restart |

Backup: chuẩn cluster PostgreSQL (daily + PITR); bucket vault + raw dùng versioning + cross-region replication nếu provider hỗ trợ. **Không backup plaintext credential** — chỉ encrypted blob + KMS key (key escrow theo policy KMS).

## 6. Deployment Setup

```
Container: Docker | Orchestration: Docker Compose (dev) / K8s hoặc ECS [NEEDS_REVIEW: theo platform — P3-01 §7]
CI/CD:    pipeline dùng chung platform; prod deploy manual approval
Build:    npm ci → test → image (Git SHA) → registry → rolling update → health check
Secrets deploy: chỉ env hạ tầng; KHÔNG BAO GIỜ inject credential nền tảng qua env/CI
Migrate:  job migration trước rolling update; RLS policy bắt buộc present trước khi mở traffic
```

## 7. Health Check Endpoints

| Endpoint | Checks | Expected |
|----------|--------|----------|
| `GET /health` | App running | `{ "status": "ok" }` |
| `GET /health/db` | DB + RLS session | `{ "status": "ok", "latency": "Xms" }` |
| `GET /health/queue` | Redis consumer group lag | `{ "status": "ok", "lag": N }` |
| `GET /health/kms` | KMS reachable (không expose key) | `{ "status": "ok" }` |
| `GET /health/ready` | Sẵn sàng nhận traffic | `{ "status": "ready" }` |

Health chi tiết 7 adapter (thành công/fail/degraded + freshness) là business data — phục vụ qua `GET /gw/health` (API-GW-024) cho console, không trộn vào infra health.

## 8. Monitoring & Alerting

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

## 9. Non-Functional Requirements

| Metric | Target | Action nếu vượt |
|--------|--------|-----------------|
| API P95 `/gw/statements` | < 500ms | Index review (idx_statement_recon) |
| Cửa sổ pull hourly hoàn tất | 100% trong 60 phút | Tăng batch/worker; ưu tiên TKQC active |
| Vault decrypt (P95) | < 200ms | KMS data-key cache trong bộ nhớ service |
| Backfill throughput | [NEEDS_REVIEW: chốt khi có volume thực] | Scale backfill worker |
| Uptime gateway | 99.5% (đồng bộ platform) | HA replicas; degraded manual là lưới an toàn nghiệp vụ |
| RTO / RPO | 4h / 1h | Queue AOF + PITR DB |

**Secrets rotation vận hành (REQ-BOD-008/REQ-BOD-007):** job hàng ngày quét `rotate_due_at` → T-7 alert CTO → đến hạn: SYS_ADMIN thực thi rotate sau duyệt (tạo CredentialVersion mới, giữ lịch sử) → quá hạn >7 ngày: adapter tự `degraded` + escalation. Offboarding/thu hồi khẩn ≤24h theo checklist CTO; thu hồi vô hiệu token ở nền tảng ở mức khả thi, REVOKED bắt buộc trước khi nạp credential mới.
