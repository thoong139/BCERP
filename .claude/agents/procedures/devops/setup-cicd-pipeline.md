# Playbook: Thiết lập CI/CD Pipeline

> **Type**: Agent Skill Playbook
> **Agent**: devops
> **Triggered by**: `/wf-prepare-deployment` hoặc khi skill yêu cầu CI/CD setup
> **Output**: CI/CD pipeline configuration files tại phase6-deployment/

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-prepare-deployment` để tạo deployment pipeline cho dự án
- Khi architect hoặc developer yêu cầu thiết lập CI/CD mới
- Khi dự án chuyển từ manual deployment sang automated pipeline
- Khi cần chuẩn hóa pipeline cho monorepo hoặc multi-service projects

---

## Procedure

### Bước 1: Đọc context dự án và deployment requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (architecture), PHASE6 (deployment)

READ: devops-patterns.md (Section 1: CI/CD Pipeline Stages)

Cần xác định:
□ Loại project structure: monorepo / polyrepo / single-service
□ Tech stack: Node.js / Python / Go / Java / mixed
□ Container runtime: Docker (bắt buộc) — Kubernetes hay Docker Compose?
□ Cloud provider: AWS / GCP / Azure / self-hosted
□ Git provider: GitHub / GitLab / Bitbucket → xác định CI system phù hợp
□ Số lượng environments: dev / staging / prod (tối thiểu 3)
□ Team size: ảnh hưởng đến branch strategy và review gates
□ Performance requirements từ phase3-architecture (SLA, uptime targets)
```

### Bước 2: Thiết kế branch strategy và environment mapping

```
READ: devops-patterns.md (Section 5: Environment Strategy)

Quyết định branch strategy dựa trên team size:

Team < 5 người → Trunk-based development:
  main → production
  feature/* → merge trực tiếp vào main (short-lived branches < 2 ngày)
  release tags → trigger production deploy

Team >= 5 người → GitFlow:
  main → production
  develop → staging
  feature/* → merge vào develop
  release/* → merge vào main + develop
  hotfix/* → merge vào main + develop

Environment mapping (bắt buộc — không được bỏ qua):
  Push to feature/* → build + lint + test (không deploy)
  Push to develop/main → deploy staging + smoke test
  Tag v*.*.* hoặc manual approval → deploy production + full validation
```

### Bước 3: Thiết kế pipeline stages

```
READ: devops-patterns.md (Section 1: CI/CD Pipeline Stages, Pipeline Template)

Pipeline bắt buộc theo thứ tự fail-fast (WHY: phát hiện lỗi sớm tiết kiệm compute):

Stage 1 — LINT (< 2 phút):
  □ Code formatting (Prettier, Black, gofmt...)
  □ Linting (ESLint, Pylint, golangci-lint...)
  □ Type checking (TypeScript, mypy...)
  □ Commit message format (conventional commits)
  Fail → STOP pipeline ngay, không chạy stages tiếp theo

Stage 2 — TEST (< 10 phút):
  □ Unit tests với coverage report (threshold >= 80%)
  □ Integration tests (với test database — không dùng production DB)
  □ Coverage gate: FAIL nếu coverage giảm dưới threshold
  Lưu ý: chạy parallel nếu test suite > 5 phút

Stage 3 — BUILD (< 5 phút):
  □ Compile / transpile code
  □ Docker multi-stage build (xem devops-patterns.md Section 3)
  □ Tag image với git SHA (không dùng 'latest')
  □ Push image lên container registry
  Build args: không hardcode secrets → dùng build secrets hoặc env vars

Stage 4 — SECURITY SCAN (< 5 phút):
  □ SAST: Semgrep hoặc CodeQL (tự động detect language)
  □ Dependency scan: npm audit / pip-audit / govulncheck
  □ Container scan: Trivy (CRITICAL/HIGH severity → FAIL pipeline)
  □ Secrets detection: detect-secrets scan
  WHY: security scan sau build vì cần image để scan container

Stage 5 — DEPLOY (< 10 phút):
  Staging deploy (auto, không cần approval):
    □ Chạy database migrations (nếu có)
    □ Deploy với Helm upgrade --atomic hoặc kubectl apply
    □ Health check sau deploy (5 phút timeout)
  Production deploy (cần manual approval hoặc tag trigger):
    □ Deployment freeze check (không deploy giờ cao điểm: 17:00-23:00)
    □ Canary deploy → monitoring 15 phút → full rollout
    □ Automated rollback nếu error rate > 1%

Stage 6 — SMOKE TEST (< 5 phút):
  □ Health endpoint check (/health, /ready)
  □ Critical user flows (login, main feature, payment nếu có)
  □ FAIL → trigger automatic rollback
```

### Bước 4: Thiết kế secrets management

```
READ: devops-patterns.md (Section 8: Secrets Management)

Mapping secrets theo provider:

GitHub Actions → GitHub Secrets (CI/CD variables chỉ, không phải app secrets)
AWS workloads → AWS Secrets Manager + IAM Role (không dùng static credentials)
K8s workloads → External Secrets Operator sync từ Vault/AWS SM → K8s Secrets
Self-hosted → HashiCorp Vault với AppRole authentication

Bắt buộc tất cả môi trường:
□ KHÔNG hardcode bất kỳ credential nào trong code hoặc pipeline YAML
□ KHÔNG log secrets (dùng ::add-mask:: trong GitHub Actions)
□ KHÔNG dùng same secret cho dev và production
□ Rotation schedule: database passwords mỗi 90 ngày, API keys mỗi 30 ngày
□ Pre-commit hook: detect-secrets scan để chặn accidental commit

Secret naming convention:
  [ENV]_[SERVICE]_[TYPE]  →  PROD_DB_PASSWORD, STAGING_STRIPE_API_KEY
```

### Bước 5: Thiết kế Docker và container build optimization

```
READ: devops-patterns.md (Section 3: Container Best Practices)

Dockerfile checklist bắt buộc:
□ Multi-stage build (builder stage + production stage)
□ Non-root user (adduser với UID > 1000)
□ Alpine hoặc Distroless base image
□ Pin base image tag cụ thể (node:20.11-alpine3.19, không phải node:20-alpine)
□ HEALTHCHECK instruction trong Dockerfile
□ .dockerignore file bao gồm: .env*, .git, node_modules (nguồn), test/, docs/

Registry setup:
□ ECR (AWS) / Artifact Registry (GCP) / ACR (Azure) — không dùng Docker Hub cho production
□ Image retention policy: giữ tối đa 30 tagged images, xóa untagged sau 7 ngày
□ Immutable tags trong production registry (không cho phép overwrite)

Layer cache strategy:
□ COPY package*.json → RUN npm ci TRƯỚC KHI copy source code
□ WHY: package.json ít thay đổi hơn source → cache hit cao hơn, build nhanh hơn
```

### Bước 6: Thiết kế deployment strategy cho production

```
READ: devops-patterns.md (Section 2: Deployment Strategies Comparison)

Chọn deployment strategy dựa trên yêu cầu:

Stateless web services (API, frontend) → Canary deployment:
  WHY: kiểm soát risk tốt nhất, rollback tức thì nếu có vấn đề
  - Phase 1: 5% traffic → v_new (monitor 10 phút)
  - Phase 2: 25% traffic → v_new (monitor 10 phút)
  - Phase 3: 100% traffic → v_new
  - Promote criteria: error rate < 0.1%, P99 latency không tăng > 10%

Database migration → Blue-Green:
  WHY: có thể rollback toàn bộ stack nếu migration có vấn đề
  - Blue (current prod) giữ nguyên trong khi Green chạy migration
  - Switch traffic sang Green sau khi validation
  - Blue còn sống thêm 30 phút để rollback nếu cần

Batch jobs / Workers → Rolling Update:
  WHY: không cần zero-downtime phức tạp, đơn giản hơn
  - maxSurge: 1, maxUnavailable: 0 trong K8s rolling update config

Rollback triggers (automatic):
□ Error rate > 1% trong 2 phút sau deploy
□ P95 latency tăng > 50% so với baseline
□ Health check fail trên > 20% pods
□ Smoke test fail
```

### Bước 7: Thiết kế notification và observability hooks

```
Notification khi pipeline events xảy ra:

Slack #deployments:
  - Deploy bắt đầu: [ENV] Deploying [service] v[SHA] by [actor]
  - Deploy thành công: [ENV] Deployed [service] v[SHA] - Duration: Xm Ys
  - Deploy thất bại: @channel [ENV] FAILED deploying [service] - Action: [rollback/manual]
  - Rollback: @channel [ENV] ROLLED BACK [service] to v[prev-SHA]

PagerDuty / OpsGenie (chỉ cho production failures):
  - Production deploy fail → P1 alert
  - Automatic rollback triggered → P1 alert
  - Smoke test fail → P1 alert

DORA metrics tracking:
□ Log deploy timestamp để tính deployment frequency
□ Log lead time from commit → production
□ Log rollback events để tính change failure rate
```

### Bước 8: Viết pipeline configuration files

```
Tạo files dựa trên Git provider đã xác định ở Bước 1:

GitHub Actions:
  .github/workflows/ci.yml          → CI pipeline (lint, test, build, scan)
  .github/workflows/deploy.yml      → CD pipeline (staging + prod)
  .github/workflows/rollback.yml    → Manual rollback workflow

GitLab CI:
  .gitlab-ci.yml                    → Unified pipeline file với stages

Output deployment docs:
  Ghi vào path do skill cung cấp.
  Fallback: .mc-data/docs/phase6-deployment/cicd-pipeline-guide.md

Cấu trúc output docs:
  1. Pipeline architecture diagram (text-based)
  2. Branch strategy và environment mapping
  3. Stage-by-stage explanation với thời gian kỳ vọng
  4. Secrets management guide
  5. Rollback procedure
  6. DORA metrics baseline targets
```

---

## Checklist trước khi submit

```
□ Pipeline có đủ 6 stages theo thứ tự fail-fast
□ Security scan là bắt buộc (không thể skip)
□ Không có secrets hardcoded trong pipeline YAML
□ Docker image dùng non-root user và pinned base tag
□ Production deploy có approval gate hoặc tag-based trigger
□ Rollback được trigger tự động khi health check fail
□ Smoke test chạy sau mỗi deployment (staging và prod)
□ Notification đã setup cho Slack + PagerDuty
□ DORA metrics được tracked
□ Deployment freeze hours được config (nếu yêu cầu)
```
