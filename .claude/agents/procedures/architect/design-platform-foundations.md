# Playbook: Thiết kế Platform Foundations

> **Type**: Agent Skill Playbook
> **Agent**: architect
> **Triggered by**: /wf-design — Phase 3 khi bắt đầu dự án mới cần thiết lập platform
> **Output**: `.mc-data/docs/phase3-architecture/platform-foundations.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design` ngay sau khi system architecture style đã chọn
- Khi bắt đầu dự án mới và cần định nghĩa nền tảng chung cho toàn bộ hệ thống
- Khi hệ thống có nhiều modules/services cần chia sẻ infrastructure chung
- Khi cần xác định cross-cutting concerns trước khi các team bắt đầu code module riêng

**Lý do platform-first**: Mỗi module tự chế auth, caching, logging riêng là anti-pattern. Platform foundations đảm bảo consistency, tránh duplication, và giảm security risks.

---

## Procedure

### Bước 1: Đọc context đầu vào

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2 (features), PHASE3 (system architecture)

Cần xác định:
□ Architectural style đã chọn (Monolith / Modular Monolith / Microservices)
□ Client types (Web, Mobile, 3rd-party, B2B API)
□ Number of distinct user roles (để chọn RBAC vs ABAC)
□ Integration requirements (SSO với hệ thống có sẵn không?)
□ Compliance requirements (audit trail bắt buộc không? GDPR? SOC2?)
□ Team size (ảnh hưởng đến complexity budget)
□ Cloud provider hoặc on-premise constraints

READ: .claude/references/team-expert/engineering/architecture-patterns.md (Section 3c — API Gateway, 3d — BFF)
READ: .claude/references/team-expert/engineering/security-checklist.md (Section 2 — Authentication, Section 3 — Authorization)
```

### Bước 2: Auth Strategy — Identity & Access Management

```
READ: .claude/references/team-expert/engineering/security-checklist.md (Section 2, 3)

a) Chọn Identity Provider:

| Option | Pros | Cons | Phù hợp |
|--------|------|------|---------|
| Keycloak (self-hosted) | Full control, free, feature-rich | Ops overhead | On-premise, regulated |
| Auth0 | Managed, easy setup, enterprise features | Cost, vendor lock-in | SaaS, startup |
| AWS Cognito | Integrated với AWS ecosystem | AWS lock-in | AWS-based systems |
| Custom (JWT-based) | Full control, no vendor | Security responsibility cao | Simple systems |

→ Ghi ADR: "Chọn [IdP] vì [lý do: cost / compliance / team expertise / ops overhead]"

b) Token Strategy:
□ Access Token: JWT, RS256, TTL = 15 phút
□ Refresh Token: Opaque, HttpOnly cookie, TTL = 7-30 ngày
□ Token rotation: Refresh token rotate mỗi lần use
□ Token validation: Verify exp, iss, aud mỗi request — KHÔNG trust client claims
□ Blacklist: Redis-based token blacklist cho forced logout (logout, password change)

c) Authentication flows:
□ Standard login: Email/password + optional MFA
□ Social login: Google, Facebook (nếu B2C)
□ SSO: SAML 2.0 hoặc OIDC (nếu enterprise B2B)
□ API Key: Machine-to-machine, partner integrations

d) MFA strategy:
□ TOTP (Google Authenticator) — khuyến nghị cho admin roles
□ SMS OTP — backup option (kém an toàn hơn TOTP)
□ WebAuthn — future-proof, passwordless
```

### Bước 3: Authorization Framework — RBAC/ABAC Design

```
READ: .claude/references/team-expert/engineering/security-checklist.md (Section 3)

a) Chọn authorization model:

RBAC (Role-Based Access Control):
  Phù hợp khi: Roles rõ ràng, ít rules động
  Ví dụ: admin, manager, employee, viewer
  Implementation:
  - Roles lưu trong DB: roles table
  - Permissions lưu trong DB: permissions table
  - User → Roles: user_roles (M:N)
  - Role → Permissions: role_permissions (M:N)

ABAC (Attribute-Based Access Control):
  Phù hợp khi: Rules phức tạp, dynamic policies
  Ví dụ: "Manager chỉ approve orders trong department + working hours"
  Implementation:
  - Policy engine (OPA — Open Policy Agent)
  - Attributes: user.department, resource.owner, env.time
  - Policy files: .rego files

Hybrid (khuyến nghị cho enterprise):
  - RBAC cho coarse-grained access (có vào module không?)
  - ABAC/Ownership cho fine-grained access (xem record cụ thể không?)

b) Permission design:
□ Format: {resource}:{action} — orders:read, orders:write, users:admin
□ Deny by default: nếu không có explicit grant → DENY
□ Principle of least privilege: chỉ grant quyền tối thiểu cần thiết
□ Role hierarchy: admin > manager > employee > viewer

c) Authorization enforcement:
□ Server-side ONLY — không trust client-side checks
□ Middleware/decorator pattern — không viết authz logic trong business logic
□ Test với user không có quyền cho mọi protected endpoint
□ Log authorization failures (dấu hiệu attack hoặc bug)
```

### Bước 4: API Gateway Design

```
READ: .claude/references/team-expert/engineering/architecture-patterns.md (Section 3c — API Gateway)

a) API Gateway responsibilities:
□ SSL termination (nhận HTTPS, forward HTTP nội bộ)
□ Authentication verification (validate JWT, inject user claims)
□ Rate limiting (per-user, per-IP, per-endpoint)
□ Request routing (path-based, header-based)
□ Response aggregation (nếu cần, hoặc delegate cho BFF)
□ Protocol translation (REST → gRPC nội bộ)
□ Logging & tracing (inject trace-id vào mọi request)
□ CORS handling

b) BFF (Backend for Frontend) — chọn khi:
□ Web và Mobile có data requirements khác nhau đáng kể
□ Cần reduce round-trips cho mobile
□ Muốn tách frontend concerns khỏi core services

BFF structure:
  Web App → Web BFF → Core Services
  Mobile App → Mobile BFF → Core Services
  3rd-party → Public API Gateway → Core Services

→ Ghi ADR: "Có/không dùng BFF vì [lý do]"

c) Technology options:
| Option | Phù hợp | Pros | Cons |
|--------|---------|------|------|
| Kong | Microservices, plugin ecosystem | Mature, plugin-rich | Ops overhead |
| AWS API Gateway | AWS-based | Managed, auto-scale | AWS lock-in, cost |
| Nginx + custom | Monolith/Simple | Lightweight, flexible | Manual config |
| Envoy | Service mesh, gRPC | High-performance, cloud-native | Complex config |
| Traefik | Docker/K8s | Auto service discovery | Less features |

d) Rate limiting configuration:
| Category | Limit | Algorithm |
|---------|-------|-----------|
| Auth endpoints | 5 req/phút/IP | Token Bucket |
| Read API | 100 req/phút/user | Sliding Window |
| Write API | 30 req/phút/user | Token Bucket |
| Webhook delivery | 1000 req/phút | Fixed Window |
```

### Bước 5: Shared Services Catalog

```
Xác định shared services nào cần build/adopt, cái nào defer:

NOTIFICATION SERVICE:
□ Channels: Email (SMTP/SES), Push (FCM/APNs), SMS (Twilio), In-app
□ Template engine (Handlebars/Mjml cho email)
□ Delivery queue (async, không block request)
□ Delivery tracking & retry
□ Consent management (opt-in/opt-out per channel)
□ → Ghi ADR: "Build vs Buy notification service"

FILE STORAGE:
□ Provider: AWS S3 / MinIO (self-hosted) / Google Cloud Storage
□ Pre-signed URLs cho direct upload từ client (không qua server)
□ Virus scanning pipeline (ClamAV hoặc cloud service)
□ File type validation (MIME type + magic bytes)
□ Bucket per purpose: uploads/, exports/, backups/
□ Lifecycle policy: auto-delete temp files sau 24h

AUDIT LOGGING:
□ Immutable append-only log (không UPDATE/DELETE audit records)
□ Schema: (id, tenant_id, user_id, action, resource_type, resource_id, before, after, ip, user_agent, timestamp)
□ Write path: async qua queue (không impact request latency)
□ Storage: dedicated DB table hoặc append-only log system (Loki/Elasticsearch)
□ Retention: theo compliance requirements (thường 1-7 năm)
□ GDPR: không lưu PII trong audit logs — dùng user_id reference thay vì tên/email

JOB QUEUE / BACKGROUND PROCESSING:
□ Technology: BullMQ (Node.js/Redis), Celery (Python), Sidekiq (Ruby)
□ Job types: email delivery, report generation, data export, sync jobs
□ Dead letter queue cho failed jobs
□ Job monitoring dashboard (Bull Board, Flower)
□ Idempotency: mỗi job có unique job_id, safe to retry

SEARCH SERVICE (chỉ khi có search requirements):
□ Elasticsearch / OpenSearch cho full-text search
□ Hoặc PostgreSQL full-text search (pg_trgm) cho đơn giản hơn
□ Index sync strategy: real-time via events hoặc batch sync
```

### Bước 6: Cross-cutting Concerns

```
a) CACHING STRATEGY:

L1 — In-process cache:
  TTL: 30-60 giây
  Dùng cho: config, feature flags, reference data ít thay đổi
  Library: node-cache, functools.lru_cache

L2 — Distributed cache (Redis):
  TTL: 5-30 phút tùy use case
  Dùng cho: user sessions, API response cache, rate limit counters, job locks
  Pattern:
    Cache-aside: app check cache → miss → query DB → populate cache
    Write-through: write DB và cache cùng lúc (strong consistency)

Cache invalidation strategy:
□ TTL-based (đơn giản, acceptable staleness)
□ Event-based (invalidate khi data thay đổi — phức tạp hơn, consistent hơn)
□ Pattern: cache key = "{entity}:{id}:{version}" để dễ invalidate

b) ERROR HANDLING STANDARDS:

Global error handler pattern:
  1. Catch unhandled exceptions ở outermost layer
  2. Log đầy đủ: error message, stack trace, request context, trace_id
  3. Transform thành RFC 7807 response — KHÔNG leak internal details
  4. Alert khi error rate vượt threshold

Error classification:
□ Operational errors (expected): validation, not found, auth failure → 4xx
□ Programming errors (bugs): unhandled exceptions → 500 + alert
□ External dependency errors: timeout, 5xx from 3rd party → 502/503 + circuit breaker

c) DISTRIBUTED TRACING:

READ: .claude/references/team-expert/engineering/architecture-patterns.md (Section 7 — Observability)

□ Standard: OpenTelemetry (vendor-neutral)
□ Trace-ID: inject vào mọi request tại API Gateway, propagate qua toàn bộ call chain
□ Span creation: mỗi service boundary, DB query, external call
□ Sampling: 100% trong development, 10-20% trong production (adjustable)
□ Backend: Jaeger (self-hosted) hoặc Datadog/NewRelic (managed)

d) LOGGING STANDARDS:

□ Format: JSON structured logs (không plain text) — dễ parse và query
□ Required fields mỗi log entry:
  { timestamp, level, service, trace_id, span_id, user_id, message, ...context }
□ Log levels: ERROR (alert), WARN (investigate), INFO (business events), DEBUG (dev only)
□ KHÔNG log sensitive data: passwords, tokens, PII, card numbers
□ Centralized: ship logs → ELK Stack hoặc Grafana Loki
□ Retention: ERROR = 90 ngày, INFO = 30 ngày, DEBUG = 7 ngày
```

### Bước 7: Environment & Configuration Management

```
a) Environment hierarchy:
  local → development → staging → production
  Staging phải mirror production về config structure (khác values)

b) Configuration management:
□ Environment variables cho tất cả config (không hardcode)
□ Secrets: KHÔNG trong env files; dùng Vault / AWS Secrets Manager / Azure Key Vault
□ Config validation tại startup: fail fast nếu required config thiếu
□ .env.example file trong repo với placeholder values (không real secrets)

c) Feature flags:
□ Dùng cho: gradual rollout, A/B testing, kill switches
□ Simple: environment variable bật/tắt feature
□ Advanced: LaunchDarkly, Unleash, hoặc custom DB-based flags
□ Flag naming: FEATURE_[MODULE]_[NAME] = true/false

d) Secret management pattern:
□ Development: .env file local (gitignored)
□ CI/CD: GitHub Secrets / GitLab Variables
□ Production: Vault / AWS Secrets Manager / K8s Secrets (encrypted)
□ Rotation: tự động rotate secrets định kỳ (rotation schedule)
```

### Bước 8: Monitoring & Observability Stack

```
READ: .claude/references/team-expert/engineering/architecture-patterns.md (Section 7 — Observability)

Ba trụ cột bắt buộc:

METRICS (What is happening?):
□ Application metrics: request rate, error rate, latency P50/P95/P99
□ Business metrics: orders/minute, signup rate, revenue/hour
□ Infrastructure metrics: CPU, memory, disk, network
□ Stack: Prometheus + Grafana hoặc Datadog
□ Alert rules: error rate > 1%, P95 latency > 500ms, disk > 80%

LOGS (Why did it happen?):
□ Centralized log aggregation
□ Full-text search capability
□ Stack: ELK (Elasticsearch + Logstash + Kibana) hoặc Grafana Loki
□ Log-based alerts: error log patterns

TRACES (Where is it happening?):
□ Distributed tracing across services
□ Stack: Jaeger / Zipkin / AWS X-Ray (với OpenTelemetry instrumentation)
□ MTTD target: < 5 phút

HEALTH CHECKS:
□ Liveness probe: /health → 200 OK (app đang chạy)
□ Readiness probe: /health/ready → 200 OK (app ready nhận traffic, DB connected)
□ Deep health: /health/detailed → chi tiết từng dependency

SLA / UPTIME MONITORING:
□ External monitoring: Uptime Robot hoặc Pingdom
□ SLA dashboard visible to stakeholders
```

### Bước 9: Service Mesh Decisions (chỉ cho Microservices)

```
Chỉ áp dụng nếu architectural style = Microservices:

Service mesh options:
| Option | Pros | Cons | Phù hợp |
|--------|------|------|---------|
| Istio | Feature-rich, mTLS, traffic management | Complex, steep learning curve | Large orgs |
| Linkerd | Lightweight, simpler | Less features | Mid-size |
| Consul Connect | HashiCorp ecosystem | Consul dependency | HashiCorp shops |
| None (API Gateway only) | Simpler | Less capabilities | Small microservices |

Service mesh provides:
□ Mutual TLS (mTLS) giữa services
□ Automatic retries và circuit breaking
□ Canary deployments
□ Traffic mirroring

→ Ghi ADR: "Deploy service mesh vì [lý do] / Defer vì [lý do]"
→ Default: Bắt đầu không có service mesh, thêm khi có concrete need
```

### Bước 10: Viết Output

```
Ghi vào: .mc-data/docs/phase3-architecture/platform-foundations.md

Cấu trúc output:

# Platform Foundations — [Tên dự án]

## 1. Overview
[Tổng quan các foundations cần thiết, approach được chọn]

## 2. Identity & Authentication
[IdP được chọn, token strategy, authentication flows, MFA]

## 3. Authorization Framework
[Model được chọn (RBAC/ABAC/Hybrid), roles/permissions design, enforcement approach]

## 4. API Gateway & BFF
[Technology được chọn, routing rules, rate limiting config]

## 5. Shared Services
[Notification, File Storage, Audit Logging, Job Queue — technology + design decisions]

## 6. Cross-cutting Concerns
[Caching strategy, Error handling standards, Distributed tracing, Logging standards]

## 7. Configuration & Secrets Management
[Environment structure, secrets management approach, feature flags]

## 8. Observability Stack
[Metrics, Logs, Traces — technology stack, alert thresholds, health check endpoints]

## 9. Architecture Decision Records
[Link đến ADR files: IdP choice, API Gateway choice, Authorization model, Service mesh decision]

## 10. Deferred Decisions
[Những gì được defer và khi nào sẽ revisit — with trigger conditions]
```

---

## Checklist trước khi submit

```
□ ADR cho mỗi tech choice (IdP, Gateway, Cache, Observability)
□ Token strategy rõ: TTL, rotation, blacklist
□ Authorization model justified, secrets không hardcode
□ Audit logging cho state-changing operations, rate limiting per endpoint category
□ Observability 3 trụ cột + health checks (/health, /health/ready)
□ Cross-cutting concerns centralized, shared services có ownership, deferred decisions có trigger
```
