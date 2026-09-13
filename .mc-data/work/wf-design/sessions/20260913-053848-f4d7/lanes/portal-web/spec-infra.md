# Infrastructure Specification — SYS-PORTAL-WEB (Client Portal Web)

> READS: `P3-01-architecture.md` (§1, §3, §7), `lanes/portal-web/arch-draft.md` (§5, §6, §7)
> OUTPUT: Môi trường, container specs, network DMZ, storage, monitoring cho portal client-facing
> USED BY: `phase6-deployment/deployment-guide.md`
> DATE: 2026-09-13

---

## 1. Environments

| Env | URL | Branch | Auto-deploy | Ghi chú |
|-----|-----|--------|------------|---------|
| Development | `localhost:8083` (docker-compose) | any | No | DMZ mô phỏng bằng docker network riêng |
| Staging | `staging-portal.bcagency.vn` (DMZ) | `develop` | Yes | Dữ liệu tổng hợp không phải dữ liệu khách thật |
| Production | `portal.bcagency.vn` (DMZ — domain riêng khỏi `bcerp.bcagency.vn` nội bộ) | `main` | Manual approval | — |

## 2. Required Environment Variables

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

## 3. Server / Container Specs

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

## 4. Networking (biên giới tin cậy — bắt buộc tách biệt nội bộ)

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

## 5. Storage

| Loại | Công cụ | Mục đích | Backup |
|------|---------|----------|--------|
| Portal DB | PostgreSQL `portal_account` | Account/session/tenant_ref/export job | Snapshot ngày (02:00 UTC) + restore test tháng |
| Cache | Redis (namespace `portal:*`) | Session, rate limit, read-model TTL | Không backup — regenerable |
| Audit log | Bảng append-only + archive object storage | access/download/anomaly log | Archive liên tục; verify chuỗi ngày; retention hot 90 ngày → archive [NEEDS_REVIEW: retention portal log — registry chưa định nghĩa] |
| Export file | Object storage private bucket | File watermark, expires 24h, xóa tự động | Không — ephemeral |
| SPA assets | CDN + immutable hash filename | Static bundle | Git + registry image |

## 6. Deployment Setup

Docker image per service (BFF, Identity, Watermark), Git SHA tag, registry nội bộ; deploy rolling 2 replicas qua CI/CD, production manual approval (P3-01 §7). Bắt buộc trước mở traffic: test isolation SC-001/SC-008, test read-only SC-005, test watermark SC-004 — fail → block deploy.

## 7. Health Check Endpoints

| Endpoint | Checks | Expected |
|----------|--------|----------|
| `GET /health` | App running | `{ "status": "ok" }` |
| `GET /health/db` | PG portal | `{ "status": "ok", "latency": "Xms" }` |
| `GET /health/redis` | Redis portal | `{ "status": "ok" }` |
| `GET /health/ready` | Sẵn sàng nhận traffic | `{ "status": "ready" }` |
| `GET /health/dependencies` | CORE read-views + IdP phản hồi | degrade → trang trạng thái, không hiện số cũ |

## 8. Monitoring & Alerting

| Metric | Threshold | Severity |
|--------|-----------|----------|
| `TENANT_CROSS_ACCESS` (403) / chain verify log fail | ≥1 lần | CRITICAL — escalate SYS_ADMIN/FIN_L2 |
| Watermark render fail khi xuất | ≥1 | HIGH — chặn xuất + alert |
| Freshness view vượt 2×SLA | 15 phút liên tục | MEDIUM — trang trạng thái thay số cũ |
| Login fail spike (>20/phút/tenant) | vượt ngưỡng | HIGH — kiểm tra brute force |
| Rate limit gần ngưỡng / adoption forward backlog-DLQ | >80% quota / >0 | MEDIUM (gate Day 14 thiếu dữ kiện) |
| Error rate / P95 / CPU / disk | chuẩn platform (1% / 2s / 85% / 80%) | theo platform |

Alert channels + dashboards: theo platform (COMP-CORE-011 alert center + on-call 4h ngoài giờ DI-005).

## 9. Non-Functional Requirements

| Metric | Target | Ghi chú |
|--------|--------|---------|
| API P95 (BFF) | < 500ms | Read-model hit cache; miss → kéo CORE |
| Page load (FCP) | < 1.5s | CDN + code splitting SPA |
| Concurrent users | 1.000+ tenant, ~12 user/tenant | BFF horizontal scale; cache Redis giảm tải CORE |
| Uptime portal | 99.5% (đề xuất) | Phụ thuộc availability CORE (SSO + read-view) — chấp nhận SSOT; fail → trang trạng thái |
| RTO / RPO | 4h / 1h (đề xuất — theo platform) | Portal DB nhỏ, restore nhanh |
| Retention | Session >30 ngày dọn; OTP >24h dọn; export file 24h; log portal 90 ngày hot + archive [NEEDS_REVIEW] | Không đụng WORM ≥10 năm (thuộc CORE) |
