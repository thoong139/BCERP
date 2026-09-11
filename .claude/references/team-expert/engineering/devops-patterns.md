# DevOps Patterns - CI/CD và Infrastructure

> **Domain**: Engineering / DevOps & Infrastructure
> **Last Updated**: 2026-03-15
> **Nguồn**: DORA metrics research, Kubernetes docs, HashiCorp Terraform best practices, Google SRE Book

---

## 1. CI/CD Pipeline Stages

Pipeline chuẩn cho mọi dự án — thứ tự bắt buộc:

```
┌─────────┐   ┌─────────┐   ┌─────────┐   ┌──────────────┐   ┌─────────┐   ┌────────────┐
│  LINT   │ → │  TEST   │ → │  BUILD  │ → │ SECURITY     │ → │ DEPLOY  │ → │ SMOKE TEST │
│         │   │         │   │         │   │ SCAN         │   │         │   │            │
│ format  │   │ unit    │   │ compile │   │ SAST         │   │ staging │   │ health     │
│ lint    │   │ integr. │   │ docker  │   │ dependency   │   │ prod    │   │ check      │
│ type    │   │ e2e     │   │ image   │   │ scan         │   │         │   │ key flows  │
└─────────┘   └─────────┘   └─────────┘   └──────────────┘   └─────────┘   └────────────┘
  < 2 min       < 10 min      < 5 min        < 5 min           < 10 min       < 5 min
```

**Fail-fast principle:** Lint trước để không tốn thời gian test khi code lỗi format.

### Pipeline Template (GitHub Actions)

```yaml
# .github/workflows/ci.yml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run lint && npm run type-check

  test:
    needs: lint
    runs-on: ubuntu-latest
    steps:
      - run: npm run test:unit -- --coverage
      - run: npm run test:integration

  build:
    needs: test
    steps:
      - run: docker build --target production -t app:${{ github.sha }} .
      - run: docker push $REGISTRY/app:${{ github.sha }}

  security-scan:
    needs: build
    steps:
      - uses: aquasecurity/trivy-action@master  # Container scanning
      - run: npm audit --audit-level=high        # Dependency scanning

  deploy-staging:
    needs: security-scan
    environment: staging
    steps:
      - run: helm upgrade --install app ./charts --set image.tag=${{ github.sha }}
```

---

## 2. Deployment Strategies Comparison

| Strategy | Mô tả | Downtime | Rollback | Phù hợp |
|----------|-------|----------|----------|---------|
| Recreate | Stop old → start new | Có | Chậm | Dev/Test environments |
| Rolling Update | Thay thế dần từng instance | Không | Tự động | Stateless services thông thường |
| Blue-Green | Hai môi trường song song, switch traffic | Không | Tức thì (switch lại) | Critical services, database changes |
| Canary | Route X% traffic sang version mới | Không | Tức thì | Risk-sensitive features |
| Feature Flags | Deploy code, bật tính năng dần | Không | Instant toggle | Controlled rollout theo user segment |

### Canary Deployment Example

```
100% traffic → v1.0

Canary phase 1:  5% → v1.1  |  95% → v1.0
Canary phase 2: 25% → v1.1  |  75% → v1.0   (monitor error rate, latency)
Canary phase 3: 50% → v1.1  |  50% → v1.0
Full rollout:  100% → v1.1
```

**Tiêu chí promote:** Error rate < 0.1%, Latency P99 không tăng > 10%, no critical alerts trong 15 phút.

---

## 3. Container Best Practices

### Dockerfile Optimization

```dockerfile
# Multi-stage build: giảm image size tới 80%
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production    # Layer cache: chỉ rebuild khi package.json đổi

COPY . .
RUN npm run build

# Production stage: chỉ chứa artifacts cần thiết
FROM node:20-alpine AS production
WORKDIR /app

# Chạy với non-root user (security best practice)
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -s /bin/sh -D appuser

COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules

USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/main.js"]
```

**Security checklist cho Docker image:**
- [ ] Non-root user
- [ ] Minimal base image (Alpine, Distroless)
- [ ] Không copy `.env`, `.git`, `node_modules` nguồn vào
- [ ] Scan image với Trivy hoặc Snyk trước khi push
- [ ] Pin base image tag cụ thể (không dùng `latest`)

### Docker Compose vs Kubernetes Decision Matrix

| Tiêu chí | Docker Compose | Kubernetes |
|---------|---------------|------------|
| Team size | 1–5 devs | 5+ devs, Ops team |
| Services count | < 10 | 10+ |
| Scaling needs | Manual | Auto-scaling |
| HA requirement | Không | Có |
| Phù hợp cho | Local dev, staging đơn giản | Production workloads |

---

## 4. Infrastructure as Code Patterns

### Terraform Module Structure

```
infrastructure/
├── modules/
│   ├── vpc/          # Reusable VPC module
│   ├── eks/          # EKS cluster module
│   └── rds/          # Database module
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── production/
└── shared/           # Shared resources (DNS, certificates)
```

### State Management

```hcl
# Backend S3 (AWS) — state lưu tập trung, lock qua DynamoDB
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "production/app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Workspace Strategy:**

| Workspace | Mục đích | Approve required |
|-----------|---------|-----------------|
| `dev` | Thử nghiệm thay đổi | Không |
| `staging` | Pre-production validation | Tech lead |
| `production` | Live environment | Senior engineer + Manager |

---

## 5. Environment Strategy

### Environment Parity

```
Development → Staging → Production
     │            │           │
     └────────────┴───────────┘
          Cùng Dockerfile
          Cùng Helm charts
          Cùng config structure
          Khác: resources, credentials, replicas
```

**12-factor App — Environment Variables:**
- Không hardcode config trong code
- Mỗi env có `.env.[environment]` hoặc secrets manager riêng
- Không commit secrets vào git (dùng `.gitignore` + pre-commit hook)

---

## 6. Monitoring Stack Reference

### Metrics (Prometheus + Grafana)

```
Application → /metrics endpoint (Prometheus format)
                    │
             Prometheus scrape (30s interval)
                    │
             Grafana dashboards
                    │
             AlertManager → PagerDuty / Slack
```

**Metrics cần có cho mọi service:**
- `http_requests_total` (counter, labels: method, status, endpoint)
- `http_request_duration_seconds` (histogram, P50/P95/P99)
- `db_query_duration_seconds` (histogram)
- `cache_hit_ratio` (gauge)
- Business metrics cụ thể (orders_created_total, payment_failures_total)

### Logs (Structured JSON)

```json
{
  "timestamp": "2026-03-15T10:30:00Z",
  "level": "error",
  "message": "Payment processing failed",
  "trace_id": "abc123",
  "span_id": "def456",
  "user_id": 12345,
  "order_id": 67890,
  "error": "timeout connecting to payment gateway",
  "duration_ms": 5001
}
```

**Logging levels:**
- `ERROR`: Cần action ngay, ảnh hưởng user
- `WARN`: Degraded state, chưa cần action ngay
- `INFO`: Business events quan trọng (order created, user logged in)
- `DEBUG`: Chỉ bật trong dev/staging

---

## 7. Alerting Rules Template

| Severity | Định nghĩa | Response time | Kênh thông báo |
|---------|-----------|--------------|----------------|
| P0 - Critical | Service down, data loss | < 5 phút | Phone call + PagerDuty |
| P1 - High | Tính năng core bị lỗi | < 15 phút | PagerDuty + Slack #alerts |
| P2 - Medium | Degraded performance | < 1 giờ | Slack #alerts |
| P3 - Low | Non-critical issues | Trong ngày | Slack #monitoring |

```yaml
# Prometheus alert ví dụ
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) /
        rate(http_requests_total[5m]) > 0.01
  for: 2m
  labels:
    severity: P1
  annotations:
    summary: "Error rate > 1% trong 2 phút liên tiếp"
    runbook: "https://wiki.company.com/runbooks/high-error-rate"
```

**Runbook phải có:** nguyên nhân phổ biến, các bước diagnosis, commands để check, escalation path.

---

## 8. Secrets Management Patterns

| Tool | Phù hợp | Cách hoạt động |
|------|---------|---------------|
| HashiCorp Vault | Self-hosted, compliance cần thiết | Dynamic secrets, lease/renew |
| AWS Secrets Manager | AWS workloads | Rotation tự động, native IAM |
| GitHub Actions Secrets | CI/CD only | Encrypted, masked in logs |
| Kubernetes Secrets + RBAC | K8s workloads | Base64 encoded, cần encryption at rest |

**Nguyên tắc secrets:**
- Không log secrets (mask trong CI, structured logging)
- Rotate credentials định kỳ (tối thiểu 90 ngày)
- Principle of least privilege: mỗi service chỉ có secrets nó cần
- Audit access: biết ai đã access secret nào, khi nào

```bash
# Pre-commit hook ngăn commit secrets
# Dùng git-secrets hoặc detect-secrets
detect-secrets scan --baseline .secrets.baseline
```

## 9. Xem thêm

Chi tiết Terraform IaC templates, Prometheus config, Deployment Guide template và Advanced Patterns (GitOps, Distributed Tracing, Cost Optimization):
→ `.claude/references/team-expert/engineering/devops-iac-templates.md`
