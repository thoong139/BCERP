# Incident Response Runbook — [TÊN DỰ ÁN]

> READS: `deployment-guide.md`, `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/infra-spec.md`
> USED BY: Operations team, On-call engineers
> DATE: YYYY-MM-DD | VERSION: v[X.Y]

---

## 1. Mức Độ Nghiêm Trọng (Severity Classification)

| Severity | Định nghĩa | Ví dụ | Response Time | Escalation |
|----------|-----------|-------|--------------|------------|
| **P0 — Critical** | Hệ thống down hoàn toàn, mất dữ liệu, vi phạm bảo mật | DB corruption, DDoS, auth system failure, data breach | **Ngay lập tức** (all hands) | Ngay khi phát hiện |
| **P1 — High** | Tính năng core không hoạt động, hiệu năng suy giảm nghiêm trọng | Payment processing down, error rate > 50%, latency tăng 10x | **< 1 giờ** | Sau 30 phút không fix |
| **P2 — Medium** | Tính năng phụ bị ảnh hưởng, có workaround | Search không hoạt động, non-critical API errors | **< 4 giờ** | Sau 2 giờ |
| **P3 — Low** | Lỗi nhỏ, ảnh hưởng ít users | Styling bug, typo, minor UI glitch | **1 ngày làm việc** | Không cần |

---

## 2. Response Team Theo Severity

### P0 — Critical Response Team

| Vai trò | Trách nhiệm | Hành động |
|---------|-------------|-----------|
| **Incident Commander** | Điều phối toàn bộ response | Đánh giá scope, phân công, quyết định rollback |
| **DevOps Engineer** | Deployment/rollback | Thực hiện rollback nếu cần, quản lý infrastructure |
| **Backend Lead** | Điều tra root cause | Kiểm tra DB, API, service communication |
| **Frontend Lead** | Điều tra phía client | Kiểm tra client-side errors, UI rendering |
| **Support/Comms** | Thông báo stakeholders | Cập nhật status page, thông báo users |

### P1 — High Response Team

| Vai trò | Trách nhiệm |
|---------|-------------|
| **Incident Commander** | Điều phối response |
| **DevOps Engineer** | Deployment support |
| **Developer liên quan** | Implement fix |
| **Support/Comms** | Thông báo users nếu cần |

### P2 — Medium Response

| Vai trò | Trách nhiệm |
|---------|-------------|
| **Developer liên quan** | Implement fix |
| **QA** | Verify fix trước deploy |

### P3 — Low Response

| Vai trò | Trách nhiệm |
|---------|-------------|
| **Dev Lead** | Thêm vào backlog sprint tiếp theo |

---

## 3. Quy Trình Xử Lý Sự Cố (5 Steps)

### Step 1: Phát Hiện & Phân Loại (0–5 phút)

```
TRIGGER: Alert từ monitoring / User report / Tự phát hiện

Incident Commander:
1. Acknowledge alert
2. Đánh giá scope và impact:
   - Bao nhiêu users bị ảnh hưởng?
   - Services nào bị impact?
   - Dữ liệu có bị rủi ro không?
3. Phân loại severity (P0/P1/P2/P3)
4. Kích hoạt response team phù hợp
5. Tạo incident channel/thread

OUTPUT: Incident classification + response team activated
```

**Incident Log — Entry đầu tiên:**

```
[YYYY-MM-DD HH:MM] — INCIDENT DETECTED
Severity: P[N]
Impact: [Mô tả ngắn]
Assigned to: [Incident Commander]
Channel: [Link incident channel]
```

---

### Step 2: Điều Tra (5–30 phút)

```
PARALLEL INVESTIGATION:

Incident Commander / DevOps:
├── Kiểm tra system metrics (CPU, memory, network, disk)
├── Review error logs (kubectl logs / application logs)
├── Kiểm tra recent deployments (git log --oneline -5)
└── Verify external dependencies (third-party APIs, DNS)

Backend Lead (nếu P0/P1):
├── Kiểm tra database health (connections, locks, replication)
├── Review API error rates
├── Kiểm tra service-to-service communication
└── Xác định failing component

DevOps:
├── Review deployment history gần đây
├── Kiểm tra CI/CD pipeline status
├── Chuẩn bị rollback nếu cần
└── Verify infrastructure state (pods, nodes, load balancer)

OUTPUT: Root cause identified (hoặc narrowed down)
```

**Useful Investigation Commands:**

```bash
# Application logs — 100 dòng gần nhất
kubectl logs deployment/[app-name] -n production --tail=100

# Logs trong 1 giờ qua
kubectl logs deployment/[app-name] -n production --since=1h

# DB connections đang active
psql $DATABASE_URL -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"

# Slow queries (> 5 giây)
psql $DATABASE_URL -c "SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity WHERE (now() - query_start) > interval '5 seconds';"

# Disk usage
df -h

# Memory usage top processes
ps aux --sort=-%mem | head -10

# Recent deployments
kubectl rollout history deployment/[app-name] -n production
```

---

### Step 3: Khắc Phục (15–60 phút)

```
DECISION TREE:

IF nguyên nhân do recent deployment:
  → DevOps: Thực hiện rollback (kubectl rollout undo)
  → Incident Commander: Verify recovery
  → QA: Confirm fix

IF nguyên nhân do infrastructure:
  → DevOps: Scale/restart/failover
  → Verify recovery
  → Monitor stabilization

IF nguyên nhân do code bug:
  → Developer: Implement hotfix (branch: hotfix/incident-YYYYMMDD)
  → QA: Verify fix trên staging
  → DevOps: Deploy hotfix
  → Incident Commander: Monitor recovery

IF nguyên nhân do external dependency:
  → DevOps: Kích hoạt fallback/cache
  → Support: Thông báo users
  → Monitor cho đến khi external service recovery

XUYÊN SUỐT:
  → Support: Cập nhật status page mỗi 15 phút
  → Incident Commander: Brief stakeholders (P0 only)
```

**Rollback Commands:**

```bash
# Rollback deployment về version trước
kubectl rollout undo deployment/[app-name] -n production
kubectl rollout status deployment/[app-name] -n production

# Verify rollback thành công
kubectl get deployment [app-name] -n production \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Health check sau rollback
curl -f https://[domain]/health
```

---

### Step 4: Xác Nhận Khắc Phục (Post-fix)

```
QA / Developer:
1. Verify fix giải quyết đúng vấn đề
2. Kiểm tra không có side effects mới
3. Confirm trên production

Incident Commander:
1. Verify metrics đang trở về bình thường
2. Xác nhận không có cascading failures
3. Monitor 30 phút sau fix

DevOps (nếu API-related):
1. Kiểm tra affected endpoints hoạt động bình thường
2. Verify response times đã normalize
3. Confirm error rates ở baseline

OUTPUT: Incident resolved confirmation
```

**Confirmation Checklist:**

```
□ Root cause đã được fix/mitigated
□ Affected services trả response bình thường
□ Error rate < 0.1%
□ Response time P95 < 500ms
□ Không có cascading failures
□ Users đã có thể sử dụng bình thường
□ Status page đã cập nhật "Resolved"
```

---

### Step 5: Post-Mortem (Trong 48 giờ — BẮT BUỘC cho P0/P1)

#### Template Post-Mortem:

```markdown
# Post-Mortem: [Incident Title]

**Date:** YYYY-MM-DD
**Severity:** P[N]
**Duration:** [Thời gian từ detect → resolve]
**Author:** [Incident Commander]

## Timeline

| Thời gian | Sự kiện |
|-----------|---------|
| HH:MM | Incident detected — [trigger] |
| HH:MM | Severity classified as P[N] |
| HH:MM | Response team activated |
| HH:MM | Root cause identified: [description] |
| HH:MM | Fix applied: [description] |
| HH:MM | Fix verified — incident resolved |
| HH:MM | Monitoring confirmed stable (30 min) |

## Root Cause Analysis

**Nguyên nhân trực tiếp:** [What failed]

**Nguyên nhân gốc (5 Whys):**
1. Why: [Direct cause]
2. Why: [Deeper cause]
3. Why: [Even deeper]
4. Why: [Systemic issue]
5. Why: [Root root cause]

## Impact Assessment

| Impact | Detail |
|--------|--------|
| **Users affected** | [Number / percentage] |
| **Duration** | [Total downtime / degradation time] |
| **Revenue impact** | [Estimate if applicable] |
| **Data impact** | [Any data loss / corruption?] |

## Prevention Actions

| # | Action | Owner | Deadline | Status |
|---|--------|-------|----------|--------|
| 1 | [Monitoring improvement] | [Who] | [When] | Pending |
| 2 | [Testing improvement] | [Who] | [When] | Pending |
| 3 | [Process change] | [Who] | [When] | Pending |
| 4 | [Infrastructure change] | [Who] | [When] | Pending |

## Lessons Learned

**Tốt:** [Điều gì response team làm tốt]
**Cần cải thiện:** [Điều gì cần làm tốt hơn]
**Lucky:** [Điều gì may mắn không xảy ra]
```

---

## 4. Communication Templates

### Status Page Update

```
[YYYY-MM-DD HH:MM] — [SERVICE NAME] Incident

Status: [Investigating / Identified / Monitoring / Resolved]
Impact: [Mô tả ảnh hưởng đến users]
Action: [Đang làm gì để xử lý]
Next update: [Khi nào cập nhật tiếp]
```

### Stakeholder Update (P0 only)

```
INCIDENT BRIEF — [YYYY-MM-DD HH:MM]

SITUATION: [Service] đang [down/degraded], ảnh hưởng [N users / X% traffic]
CAUSE: [Known / Đang điều tra] — [Mô tả ngắn nếu biết]
ACTION: [Đang làm gì] — ETA [thời gian dự kiến]
IMPACT: [Ảnh hưởng business — revenue, users, reputation]
NEXT UPDATE: [Thời gian]
```

### Resolved Notification

```
[RESOLVED] [SERVICE NAME] — [YYYY-MM-DD HH:MM]

Sự cố đã được xử lý. Hệ thống hoạt động bình thường.
Duration: [HH:MM — HH:MM] ([N] phút)
Root cause: [Mô tả ngắn]
Prevention: [Hành động ngăn tái diễn]
```

---

## 5. Escalation Matrix

| Điều kiện | Escalate To | Hành động |
|-----------|------------|-----------|
| P0 không resolve trong 30 phút | CTO / VP Engineering | Bổ sung resources, vendor escalation |
| P1 không resolve trong 2 giờ | Engineering Manager | Reassign resources |
| Nghi ngờ data breach | Security Lead + Legal | Đánh giá regulatory notification (GDPR/CCPA) |
| User data bị ảnh hưởng | Legal + Support Lead | Chuẩn bị user notification |
| Revenue impact > threshold | Finance + Business Lead | Business impact assessment |
| Third-party dependency down | Vendor contact + DevOps | Kích hoạt fallback, liên hệ vendor |

---

## 6. On-Call Checklist

### Khi bắt đầu ca on-call:

```
□ Confirm access vào monitoring dashboards
□ Kiểm tra alerting channels hoạt động (Slack, PagerDuty, email)
□ Review recent deployments (có gì mới deploy không?)
□ Review open incidents (có incident nào đang pending?)
□ Confirm rollback procedures (biết cách rollback nếu cần)
□ Confirm escalation contacts (biết liên hệ ai nếu cần)
```

### Khi kết thúc ca on-call:

```
□ Handoff tất cả open incidents cho ca tiếp theo
□ Document bất kỳ anomaly nào đã thấy
□ Update on-call log
```

---

## 7. Monitoring Dashboards & Alert Rules

> *Điền URLs và thresholds thực tế cho dự án.*

> **Hướng dẫn populate [URL]:** Điền URL monitoring sau khi monitoring stack được setup trong `/wf-prepare-deployment`. URLs PHẢI accessible bởi on-call engineers (không cần VPN nếu có thể). Ví dụ: Grafana dashboard, Sentry project, PagerDuty service page.

### Dashboard Links

| Dashboard | URL | Mục đích |
|-----------|-----|----------|
| Application Overview | [URL] | Health, error rate, response time |
| Database | [URL] | Connections, query performance |
| Infrastructure | [URL] | CPU, memory, disk, network |
| Business Metrics | [URL] | Active users, transactions |

### Alert Rules

| Alert | Condition | Severity | Action |
|-------|-----------|----------|--------|
| Error Rate High | error_rate > 1% trong 5 phút | P1 | Investigate immediately |
| Response Time High | p95_latency > 2s trong 5 phút | P2 | Check DB queries, external deps |
| CPU High | cpu > 90% trong 10 phút | P2 | Scale up or investigate |
| Memory High | memory > 85% trong 10 phút | P2 | Check memory leaks |
| Disk Full | disk > 90% | P1 | Clear logs, expand storage |
| DB Connections | active > 80% pool trong 5 phút | P1 | Check connection leaks |
| Health Check Fail | /health returns non-200 | P0 | Immediate investigation |
| SSL Expiry | cert expires < 7 days | P2 | Renew certificate |

---

*Tài liệu được tạo bởi DEVKIT `/wf-prepare-deployment`*
