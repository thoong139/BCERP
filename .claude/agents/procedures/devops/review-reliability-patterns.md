# Procedure: Review Reliability Patterns

> **Owner agent:** `devops`
> **Use case:** Khi `devops` được spawn từ `/wf-fix-bugs` lane QD8 (Observability & Reliability)
> hoặc khi review infra-level reliability patterns trước go-live.

## Khi nào dùng

- QD8 lane: complement với `sre/audit-observability.md`. SRE focus code-level patterns;
  DevOps focus infra-level (CI/CD, deployment, runtime config).
- Pre-deployment review: rolling update strategy, autoscaling, resource limits.

## Đầu vào

- `$SESSION_DIR/scope.json`
- Infra config: `Dockerfile`, `docker-compose.yml`, `k8s/`, `terraform/`,
  `.github/workflows/`, `helm/`, `nginx.conf`, `pm2.config.js`
- `req-registry.json` — reliability requirements

## Đầu ra

JSON array signals theo CORE-029 schema (xem `sre/audit-observability.md`).

## Quy trình review

### Bước 1 — Container/runtime config

#### Resource Limits
- Container không set `memory.limit` → HIGH (OOM kill risk)
- Container không set `cpu.limit` → MEDIUM (noisy neighbor)
- Limit < request × 1.5 → MEDIUM (no headroom)

#### Liveness/Readiness Probes (k8s)
- Service không có `livenessProbe` → HIGH
- `readinessProbe` mismatch với health endpoint behavior → HIGH
- `initialDelaySeconds` quá thấp → MEDIUM (premature unready)

#### Restart Policy
- `restartPolicy: Never` cho long-running service → HIGH
- Backoff không exponential → MEDIUM

### Bước 2 — Deployment strategy

- Rolling update không set `maxUnavailable`/`maxSurge` → MEDIUM
- Service không có PDB (PodDisruptionBudget) cho production tier → HIGH
- Blue/green hoặc canary missing cho payment/auth → MEDIUM (suggest)
- Migration/seed job chạy trong startup hook (race condition) → HIGH

### Bước 3 — Auto-scaling

- HPA missing trên user-facing service → MEDIUM
- HPA dựa chỉ trên CPU (không có custom metric) → LOW
- `minReplicas: 1` cho production → HIGH (no redundancy)

### Bước 4 — CI/CD pipeline

- Deployment không có smoke test post-deploy → HIGH
- Rollback procedure không documented → HIGH
- Secret được commit vào pipeline yaml → CRITICAL
- Artifact không pin version (use `latest` tag) → HIGH

### Bước 5 — Networking

- Service expose internal-only port to public LB → CRITICAL (security + reliability)
- Timeout config trên LB không match service timeout → MEDIUM
- WAF/rate-limit thiếu trên auth endpoint → HIGH

### Bước 6 — Monitoring/Alerting infra

- Prometheus scrape config không cover production service → HIGH
- Alertmanager không route critical alert tới on-call → HIGH
- Log aggregation không retain ≥ 7 days cho production → MEDIUM

## Severity assignment

| Tình huống | Severity |
|---|---|
| Production secret hardcoded trong pipeline | CRITICAL |
| Service public-facing không có WAF/auth | CRITICAL |
| Production missing health probes | HIGH |
| HPA chỉ dựa CPU, không cover memory pressure | MEDIUM |
| Pipeline thiếu smoke test post-deploy | HIGH |
| Resource limit không set | HIGH |

## CDG flag

Khi finding ảnh hưởng production deployment:
- `cdg_flags: ["CDG-RELIABILITY-RISK"]` cho orchestrator review.

## Anti-patterns to ignore

- KHÔNG flag thiếu HPA trên dev-only service
- KHÔNG flag missing PDB nếu service single-replica by design (vd: stateful singleton)
- Suggest setup thay vì block khi infra primitive chưa có (vd: dự án mới chưa có Prometheus)

## Output validation (CORE-029)

Same as `sre/audit-observability.md` — signal-v2 schema, severity enum, evidence non-empty.
