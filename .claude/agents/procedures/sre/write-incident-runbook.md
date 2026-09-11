# Playbook: Viết Incident Runbook

> **Type**: Agent Skill Playbook
> **Agent**: sre
> **Triggered by**: Khi cần tạo runbooks cho incidents — thường sau alert configuration hoặc pre-deployment
> **Output**: `.mc-data/docs/phase3-architecture/runbooks/[service-name]-[incident-type].md`

---

## Khi nào dùng playbook này

- Sau khi thiết kế SLO/SLI (`design-slo-sli.md`) và đã xác định alert triggers
- Trước production deployment khi cần on-call readiness
- Sau post-mortem khi phát hiện failure mode chưa có runbook
- Khi alert mới được thêm vào monitoring stack

---

## Procedure

### Bước 1: Service overview — dependencies và data flow

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (architecture)
READ: sre-patterns.md (Severity matrix, On-Call design)

Thu thập:
□ Service name và version
□ Upstream dependencies (services gọi service này)
□ Downstream dependencies (services service này gọi)
□ Data stores (DB, cache, queue)
□ External integrations (third-party APIs)
□ Owner team và on-call rotation
□ Service criticality (P1/P2/P3)
```

Tạo service card tóm tắt:

```markdown
## Service Card: [service-name]

| Thuộc tính | Giá trị |
|-----------|---------|
| Owner | [team-name] |
| On-call | [rotation-link hoặc contact] |
| Criticality | P[1/2/3] |
| SLO | [X]% availability, P95 < [Y]ms |
| Upstream | [service-a, service-b] |
| Downstream | [service-c, service-d] |
| Data stores | [postgres-main, redis-cache] |
| Dashboard | [link] |
| Logs | [link] |
| Traces | [link] |
```

### Bước 2: Alert triggers — điều kiện kích hoạt runbook này

Document chính xác alert nào dẫn đến runbook này:

```markdown
## Khi nào runbook này được kích hoạt

Alert: `[alert-name]`
Condition: `[burn_rate > X trong Y phút]`
Severity: P[1/2/3]
Expected frequency: [daily/weekly/rare]

Không phải alerts này:
- `[alert-b]` → dùng runbook [other-runbook.md]
```

### Bước 3: Triage steps — xác định severity trong 5 phút đầu

Triage PHẢI hoàn thành trong 5 phút đầu của incident:

```markdown
## Triage (5 phút đầu)

### Câu hỏi 1: Scope — bao nhiêu users bị ảnh hưởng?
- [ ] Chạy: `[query hoặc dashboard link]`
- Tất cả users → P1, escalate ngay
- Một phần users → P2, tiếp tục triage
- Chỉ một customer/region → P2/P3

### Câu hỏi 2: Duration — bắt đầu từ khi nào?
- [ ] Chạy: `[PromQL hoặc log query]`
- < 5 phút → có thể transient, quan sát thêm
- 5-15 phút → investigate ngay
- > 15 phút → P1 nếu user-facing

### Câu hỏi 3: Recent changes — có deployment/config change không?
- [ ] Kiểm tra: `[deployment dashboard hoặc git log]`
- Có change trong 30 phút gần nhất → nghi ngờ regression
- Không có change → look at upstream dependencies
```

### Bước 4: Diagnosis commands

Cung cấp commands copy-paste ready, có output example:

```markdown
## Diagnosis Commands

### Kiểm tra service health
```bash
# Health check endpoint
curl -s https://[service-url]/health | jq .

# Expected output khi healthy:
# { "status": "ok", "version": "1.2.3", "dependencies": { "db": "ok", "cache": "ok" } }
```

### Kiểm tra error rate (PromQL)
```promql
# Error rate 5 phút gần nhất
rate(http_requests_total{job="[service]", status=~"5.."}[5m])
/ rate(http_requests_total{job="[service]"}[5m])
```

### Kiểm tra latency percentiles
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="[service]"}[5m]))
```

### Kiểm tra logs lỗi gần nhất
```bash
# Kibana/Loki query
{service="[service-name]"} |= "ERROR" | json | line_format "{{.timestamp}} {{.message}}"
```

### Kiểm tra database connections
```bash
# PostgreSQL
psql -h [host] -U [user] -c "SELECT count(*), state FROM pg_stat_activity GROUP BY state;"
```

Sau mỗi command, ghi lại output thực tế để so sánh. Document rõ: output bình thường trông như thế nào.

### Bước 5: Common failure modes và fixes

Format mỗi failure mode như sau:

```markdown
### Failure Mode 1: [Tên ngắn gọn]

**Triệu chứng**:
- [Metric/log pattern cụ thể]
- Ví dụ: "Error rate > 5%, logs có 'connection refused' từ upstream-service"

**Root cause**: [Giải thích tại sao xảy ra]

**Verify**:
```bash
[command để confirm đây là failure mode này]
```

**Fix**:
```bash
[commands để fix, step by step]
```

**Expected outcome**: [Kết quả sau khi fix thành công]

**Nếu fix không hiệu quả**: → Xem Failure Mode 2 hoặc escalate
```

Liệt kê ít nhất 3-5 failure modes phổ biến nhất dựa trên service characteristics.

### Bước 6: Escalation path

Document rõ ai cần liên hệ khi nào:

```markdown
## Escalation

| Trigger | Escalate đến | Cách liên hệ | SLA phản hồi |
|---------|-------------|--------------|--------------|
| P1: > 5 phút không resolve | Tech Lead [tên] | Phone: [số], Slack: @[handle] | 5 phút |
| P1: Database issue | DBA on-call | PagerDuty: [link] | 10 phút |
| P1: > 30 phút không resolve | Engineering Manager | Phone: [số] | 15 phút |
| Khách hàng Enterprise bị ảnh hưởng | Customer Success | Slack: #cs-escalation | Ngay lập tức |
| Security incident suspected | Security team | [security-contact] | Ngay lập tức |

Quy tắc: KHÔNG escalate skip level trừ khi P1 và không liên hệ được
```

### Bước 7: Rollback procedure

Cung cấp rollback steps cụ thể:

```markdown
## Rollback Procedure

### Khi nào rollback:
- Error rate > [X]% sau [Y] phút investigate
- Data corruption detected
- Không xác định được root cause sau 30 phút

### Rollback steps:

**Option 1: Rollback deployment** (preferred cho regression)
```bash
# Kubernetes
kubectl rollout undo deployment/[service-name] -n [namespace]
kubectl rollout status deployment/[service-name] -n [namespace]

# Verify rollback
kubectl get pods -n [namespace] -l app=[service-name]
```

**Option 2: Feature flag disable** (cho feature-specific issues)
```bash
# LaunchDarkly / feature flag system
[command hoặc UI steps]
```

**Option 3: Traffic cutover** (cho regional issues)
```bash
[load balancer commands]
```

**Post-rollback verification**:
- [ ] Error rate trở về baseline
- [ ] Latency P95 trở về bình thường
- [ ] Không có data inconsistency
```

### Bước 8: Communication template

```markdown
## Communication Templates

### Initial notification (trong 5 phút đầu)
```
[P1/P2] Incident: [service-name] — [1-line mô tả]

Status: Investigating
Impact: [Ước tính % users bị ảnh hưởng]
Started: [HH:MM UTC]
Next update: [HH:MM UTC — 30 phút sau]

Incident channel: #incident-[YYYYMMDD-NNN]
```

### Update mỗi 30 phút (P1) / 1 giờ (P2)
```
Update [HH:MM UTC]
Status: [Investigating / Mitigated / Resolved]
Progress: [Tóm tắt đã làm gì, phát hiện gì]
Impact: [Cập nhật scope]
Next update: [HH:MM UTC]
```

### Resolution notification
```
[RESOLVED] Incident: [service-name] — [1-line mô tả]

Duration: [X giờ Y phút]
Root cause: [1-2 câu]
Impact: [Final scope]
Follow-up: Post-mortem scheduled [link]
```
```

### Bước 9: Post-incident checklist

```markdown
## Post-Incident Checklist

### Ngay sau resolve (trong 1 giờ):
- [ ] Confirm service fully restored — tất cả SLIs trở về baseline
- [ ] Notify stakeholders về resolution
- [ ] Preserve evidence: logs, traces, screenshots
- [ ] Tạo incident record với timeline

### Trong 24 giờ:
- [ ] Assign post-mortem facilitator
- [ ] Schedule post-mortem (trong 48 giờ với P1)
- [ ] Preliminary root cause documented

### Post-mortem (trong 48 giờ với P1):
- [ ] Timeline đầy đủ từ first symptom đến resolve
- [ ] 5 Whys analysis
- [ ] Action items với owner và deadline
- [ ] Runbook update nếu cần (playbook này)
- [ ] Share với team — blameless, focus vào system
```

---

## Checklist trước khi submit runbook

```
□ Service card đầy đủ (owner, contacts, links)
□ Alert trigger được document chính xác
□ Triage flow hoàn thành trong 5 phút
□ Tất cả commands đã test và có expected output
□ Ít nhất 3 failure modes với fix steps
□ Escalation path rõ ràng với contacts thực
□ Rollback procedure có ít nhất 2 options
□ Communication templates đầy đủ 3 phases
□ Post-incident checklist đầy đủ
```

---

## Lưu ý kỹ thuật

- **Tần suất review**: Runbook PHẢI được review sau mỗi major incident và quarterly
- **Test runbook**: Chaos engineering game day để verify runbook có correct trong thực tế
- **Command currency**: Kiểm tra commands sau mỗi infrastructure change
- **Single runbook per alert**: 1 alert = 1 runbook, không merge nhiều alerts vào 1 runbook
