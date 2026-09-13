# Infrastructure Specification — SYS-MOBILE-PORTAL (Mobile App BC Portal)

> READS: `P3-01-architecture.md`, `lanes/mobile-portal/arch-draft.md`, `lanes/mobile-portal/spec-api.md`, `spec-db.md`
> OUTPUT: Môi trường, container, push worker, distribution, min-version gating, monitoring
> USED BY: `phase6-deployment/deployment-guide.md`
> DATE: 2026-09-13

---

## 1. Environments

| Env | URL | Branch | Auto-deploy | Mục đích |
|-----|-----|--------|------------|----------|
| Development | `localhost:8085` (docker-compose) | any | No | Dev BFF + worker |
| Staging | `staging.bcerp.bcagency.vn/api/v1/mpo` | `develop` | Yes | QA + build test mobile (TestFlight/Internal Testing) |
| Production | `portal.bcagency.vn/api/v1/mpo` (DMZ) | `main` | Manual approval | Live khách hàng |

## 2. Required Environment Variables

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

## 3. Server / Container Specs

| Service | Loại | CPU | RAM | Replicas (prod) | Ghi chú |
|---------|------|-----|-----|-----------------|---------|
| INFRA-MPO-001 `mpo-bff` | service (Node.js/NestJS, cùng stack PORTAL-WEB) | 1 vCPU | 1GB | 2 | Stateless, port 8085; không chứa business logic; mask whitelist + freshness check tại đây |
| INFRA-MPO-002 `mpo-push-worker` | worker | 1 vCPU | 512MB | 2 | Queue consumer (Redis Streams + DLQ); fan-out FCM/APNs; check `status='ACTIVE'` + opt-in trước khi bắn |
| INFRA-MPO-003 `mpo_device` (PostgreSQL) | database | dùng chung instance | — | primary + replica | 2 bảng, RLS tenant; backup theo chuẩn nền tảng |
| INFRA-MPO-004 Redis namespace `mpo:*` | cache/queue | dùng chung | — | 1 | Session, OTP, rate-limit, idempotency key, push queue (ephemeral, không backup) |
| INFRA-MPO-005 Push credentials | secret | — | — | — | FCM service account + APNs key trong vault; xoay vòng ≥90 ngày |

## 4. Networking (INFRA-MPO-008)

```
Public (DMZ — cùng zone PORTAL-WEB):
  Mobile app → HTTPS :443 → LB/WAF → mpo-bff (chỉ /api/v1/mpo/*)

Internal (không expose):
  mpo-bff → PORTAL-WEB read-model + CORE (IdP, PDP): internal network
  mpo-push-worker → Redis queue + FCM/APNs outbound :443
  CẤM: mobile/bff gọi trực tiếp SYS-INTEGRATION-GW; vault management bị từ chối (BR-GW-STGW-005)

Firewall: chỉ 443 public; DB/Redis chỉ accept từ backend IP/VPC
```

## 5. Storage

BFF/worker stateless — không local disk prod. Dữ liệu sở hữu: schema `mpo_device` (PostgreSQL) + Redis ephemeral. Không object storage riêng; sổ phụ PDF do PORTAL-WEB sinh + watermark — mobile chỉ deep-link.

## 6. Deployment Setup

```
Container: Docker; Orchestration: cùng platform PORTAL-WEB (compose dev / K8s hoặc ECS prod — chốt chung, Phụ lục A #11)
CI/CD: build image theo Git SHA → registry → deploy rolling; health check gate
Mobile (INFRA-MPO-006 Distribution): iOS App Store + Google Play; staging qua TestFlight / Play Internal
  Testing; code signing key/keystore trong CI secret vault.
  [NEEDS_REVIEW: kênh phân phối ngoài store (MDM/APK direct) cho khách doanh nghiệp không dùng store]
INFRA-MPO-007 Min-version gating: GET /api/v1/mpo/app-config trả min_version + force_update flag
  (versioned, cache 5 phút); app dưới ngưỡng → chặn API, ép update; nâng ngưỡng khẩn không cần release.
```

## 7. Health Check Endpoints

| Endpoint | Checks | Expected |
|----------|--------|----------|
| `GET /health` | App running | `{ "status": "ok" }` |
| `GET /health/ready` | PORTAL reachable, CORE IdP reachable, Redis, DB `mpo_device` | `{ "status": "ready" }` |
| `GET /health/push` (worker) | Queue lag, FCM/APNs handshake gần nhất | `{ "status": "ok", "queue_lag": N }` |

## 8. Monitoring & Alerting

| Metric | Threshold Alert | Severity |
|--------|----------------|----------|
| Push latency p95 (event khẩn: chuyển mức ví) | > 5 phút từ lúc sync | HIGH (vi phạm nghiệm thu BR-003) |
| FCM/APNs error rate | > 2% / 5 min | HIGH |
| Push tới token REVOKED (phải = 0) | > 0 | CRITICAL |
| BFF error rate / P95 latency; queue lag + DLQ depth | > 1% hoặc > 2s; DLQ > 0 | HIGH — DLQ alert ngay qua COMP-CORE-011 |
| Client version dưới min_version | > 5% session | MEDIUM |

Dashboards: Grafana chung nền tảng; alert dispatch qua COMP-CORE-011 → MOD-SLA-NOTIF (on-call 4h ngoài giờ, DI-005).

## 9. Non-Functional Requirements

| Metric | Target | Ghi chú |
|--------|--------|---------|
| API P95 | < 500ms (read, excludes upstream portal) | Freshness metadata vẫn bắt buộc kèm mọi số liệu |
| Uptime | Theo SLA nền tảng portal (99.5% đề xuất) | Mobile phụ thuộc PORTAL/CORE — không cam kết riêng |
| Push phân phối | ≤ 5 phút event khẩn; log queued→sent→delivered→read | Push không phải nguồn sự thật |
| Session | Timeout theo portal; thu hồi từ xa hiệu lực tức thì | Token revoked không nhận push; RPO/RTO kế thừa nền tảng |

### [NEEDS_REVIEW]
1. Orchestration platform (K8s/ECS/compose prod) — chốt chung Phụ lục A #11; spec giữ neutral.
2. Kênh phân phối ngoài store cho khách doanh nghiệp (MDM/APK) — chưa có căn cứ registry.
3. Số replica worker theo volume push thực tế (1.000+ khách, tần suất chuyển mức) — ước lượng khởi điểm 2, review sau gate Day 14.
