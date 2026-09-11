# Playbook: Xác nhận sẵn sàng triển khai

> **Type**: Agent Skill Playbook
> **Agent**: reality-checker
> **Triggered by**: Deployment readiness gate — trước khi bắt đầu deployment process
> **Output**: Deployment Readiness Validation Report

---

## Khi nào dùng playbook này

- Ngay trước khi trigger deployment pipeline
- Khi `devops` cần confirmation từ reality-checker trước khi proceed
- Khi có deployment freeze exceptions (kiểm tra extra carefully)
- Khi deployment đã fail trước đó và cần re-validate trước khi retry

Khác với `final-production-check.md` (full quality review), playbook này focus vào DEPLOYMENT INFRASTRUCTURE — đảm bảo môi trường và pipeline sẵn sàng để deployment diễn ra an toàn. Thường chạy SAU `final-production-check.md`.

---

## Procedure

### Bước 1: CI/CD pipeline health

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE6

Verify CI/CD pipeline ở trạng thái healthy:
□ Pipeline đã chạy thành công với commit sắp deploy chưa?
   (Không deploy commit chưa qua CI)
□ Tất cả pipeline stages pass không? (lint, test, build, security scan)
□ Coverage gate không bị giảm dưới threshold không?
□ Security scan không có new CRITICAL/HIGH vulnerabilities không?
□ Build artifacts đã được created và stored đúng không?
□ Docker image đã được pushed lên registry chưa?
   (Verify bằng image tag, không chỉ dựa vào pipeline log)

Ghi nhận:
PIPELINE_RUN_ID | COMMIT_SHA | BRANCH | STATUS | DURATION | ARTIFACTS
```

### Bước 2: Infrastructure readiness

```
Verify production infrastructure đang ở trạng thái healthy TRƯỚC khi deploy:

Application layer:
□ Load balancer healthy, không có unhealthy targets
□ Current pods/instances đang running và healthy
□ No pending operations (scaling, configuration changes) trên current infrastructure
□ Enough capacity để handle traffic TRONG KHI deploy (rolling update)

Database:
□ Primary database healthy (latency normal, connections normal)
□ Read replicas (nếu có) healthy và không lagging
□ No long-running queries block tables
□ Disk space >= 20% free (đủ cho migration nếu có)
□ Backup recent (trong 24h)

Message queues:
□ No unusual backlog trên critical queues
□ Consumer healthy và processing normally

Network:
□ Internal service discovery working (services có thể resolve nhau)
□ External dependencies reachable (check DNS + connectivity)
```

### Bước 3: Feature flags state

```
Feature flags cho phép rollback mà không cần redeploy — phải verify trước khi deploy:

□ Danh sách feature flags liên quan đến release này là gì?
□ Mỗi flag có đúng state cho release này không?
   - New features: OFF by default (enable sau khi deploy)
   - Deprecated features: đang được sunset đúng schedule không?
□ Feature flag service healthy không?
□ Không có flags "stuck" (bị set wrong từ previous deploy)?
□ Emergency kill switch flags có accessible không? (cho rollback nếu cần)

Nếu không có feature flag system → ghi nhận risk:
Risk: Không thể disable features mà không cần redeploy
Mitigation: Rollback full version
```

### Bước 4: Database migrations verified

```
Migrations là nguyên nhân phổ biến nhất của deployment failures.

□ Có database migrations trong release này không?
   Nếu KHÔNG → skip bước này, note "No migrations in this release"
   Nếu CÓ → tiếp tục:

□ Migration scripts đã được review bởi DBA hoặc tech lead chưa?
□ Migration đã được test trên staging database chưa?
   (không phải dev database — staging phải có production-like data size)
□ Migration execution time trên staging là bao nhiêu?
   < 1 phút = safe để online migration
   1-10 phút = có thể cần maintenance window
   > 10 phút = CẦU maintenance window, nguy cơ lock table cao
□ Migration có backward compatible không?
   (Code cũ vẫn chạy với schema mới trong khi rolling update?)
□ Migration có rollback script (down migration) không?
□ Down migration đã được test chưa?

Nếu migration có risk cao (lock table, > 10 phút) → flag NEEDS WORK với plan cụ thể
```

### Bước 5: Third-party integrations confirmed

```
Verify external services sẵn sàng nhận traffic mới:

□ Check status pages của critical external services:
   Payment gateway (Stripe, PayPal, etc.)
   Email service (SendGrid, SES, etc.)
   SMS provider (Twilio, etc.)
   Authentication provider (Auth0, etc.)
   CDN (Cloudflare, etc.)
   Any other critical integrations

□ API keys/credentials cho production env đã được set chưa?
   (Không phải sandbox/staging credentials)
□ Rate limits: với traffic mới, có risk hit rate limits không?
□ Webhook endpoints: đã được updated nếu URL changes không?
□ Third-party contract changes (API version updates) đã handled không?

Nếu có active incident trên external service critical → NO-GO (wait for resolution)
```

### Bước 6: Backup verification

```
Trước deployment với database changes hoặc data migrations:

□ Full backup đã được tạo trong 4h qua không?
   (Ngay trước deploy là best practice)
□ Backup integrity đã được verified chưa? (restore test)
□ Backup location accessible và có đủ retention chưa?
□ Estimated restore time biết không?

Configuration backup:
□ Current environment variables đã được backed up chưa?
□ Current infrastructure-as-code state (Terraform tfstate) đã backup không?

⚠️ Deploy với DB migration mà không có recent backup = HIGH RISK
Khuyến nghị: trigger manual backup ngay trước khi run migration
```

### Bước 7: Load balancer configuration

```
Load balancer configuration sai có thể gây downtime:

□ Target groups / backends đang healthy không?
□ Health check path đúng không? (/health, /ready)
□ Health check frequency và threshold hợp lý không?
□ Session stickiness setting đúng cho rolling update không?
□ Timeout settings đủ cho slow requests không?
□ SSL/TLS termination configured correctly không?

Rolling update configuration (Kubernetes / ECS / similar):
□ maxSurge và maxUnavailable configured đúng không?
   maxSurge: 1 (hoặc 25%), maxUnavailable: 0 (zero-downtime)
□ minReadySeconds configured để không move traffic quá nhanh không?
□ livenessProbe và readinessProbe configured không?
   readinessProbe QUAN TRỌNG: pod không nhận traffic cho đến khi ready
```

### Bước 8: DNS và SSL certificate validity

```
□ DNS records đúng và propagated không?
□ SSL/TLS certificates valid không?
   - Không expire trong 30 ngày (tối thiểu)
   - Wildcard cert có cover tất cả subdomains không?
□ Certificate auto-renewal configured không? (Let's Encrypt, ACM)
□ CDN configuration valid không?
   - Cache invalidation đã được plan nếu static assets thay đổi
   - Cache TTL phù hợp với release frequency không?

Nếu certificate expire trong 7 ngày → NEEDS WORK, renew trước khi proceed
```

### Bước 9: Deployment window check

```
Deployment timing ảnh hưởng đến risk:

□ Deployment xảy ra trong maintenance window hoặc low-traffic time không?
   - Tránh: giờ cao điểm (business hours), cuối tuần trước holiday
   - Recommended: sáng sớm weekday sau maintenance window confirmed

□ Không có deployment freeze active không?
   - Code freeze trước major business events
   - Freeze sau 5PM Friday đến Monday morning (nhiều team)

□ On-call engineer đang on-duty và biết về deployment không?
   - Không deploy khi on-call không available
   - Không deploy khi senior engineer đang on leave

□ Rollback engineer identified chưa? (người thực hiện rollback nếu cần)
```

### Bước 10: Go-live checklist và output

```
Final compilation:

GO conditions:
□ CI/CD pipeline passed với correct commit
□ Infrastructure healthy trước deploy
□ Feature flags configured đúng
□ Database migrations verified (nếu có)
□ No active incidents trên external dependencies
□ Recent backup confirmed
□ Load balancer configured đúng
□ SSL/TLS valid > 30 ngày
□ Deployment window appropriate
□ On-call available

NO-GO conditions (bất kỳ một trong số sau):
□ Pipeline failed hoặc không có recent successful run
□ External service có active incident ảnh hưởng core features
□ Database backup outdated (> 4h nếu có migrations)
□ SSL certificate expire trong 7 ngày
□ Database migration chưa được tested trên staging
□ No on-call available

⚠️ MẶC ĐỊNH NO-GO — chỉ GO khi tất cả conditions pass.
```

### Bước 11: Output Deployment Readiness Validation Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/deployment-readiness-validation.md

Cấu trúc output (ngắn gọn — action-oriented):
1. GO / NO-GO Decision (timestamp)
2. Checklist Summary (table: category | status | notes)
3. Database Migration Risk Assessment (nếu applicable)
4. External Dependencies Status
5. Deployment Window Confirmation
6. Blocking Issues (nếu NO-GO)
7. Pre-deploy Actions (nếu GO — ví dụ: trigger backup trước khi run)
8. Post-deploy Verification Plan (first 15 phút sau deploy cần check gì)
```

---

## Checklist trước khi submit

```
□ Tất cả 10 categories đã được check (không skip)
□ CI/CD run ID và commit SHA được ghi nhận cụ thể
□ Database migrations risk đã được assessed (không bỏ qua dù "nhỏ")
□ External service status được check từ official status pages
□ SSL certificate expiry đã được check (không chỉ "probably OK")
□ On-call availability đã được confirmed
□ Decision GO/NO-GO có justification rõ ràng
□ Post-deploy verification plan có (không chỉ deploy xong là xong)
```
