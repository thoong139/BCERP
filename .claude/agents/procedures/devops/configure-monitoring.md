# Playbook: Cấu hình Monitoring & Observability

> **Type**: Agent Skill Playbook
> **Agent**: devops
> **Triggered by**: `/wf-prepare-deployment` hoặc khi cần setup monitoring/observability stack
> **Output**: Monitoring configuration + alert rules tại phase6-deployment/

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-prepare-deployment` để thiết lập observability stack
- Khi dự án chưa có monitoring và sắp go-live
- Khi cần standardize monitoring sau khi hệ thống đã chạy nhưng thiếu visibility
- Khi architect yêu cầu observability design review
- Lưu ý: playbook này focus vào setup và configuration — SLO definition và reliability engineering là domain của `sre` agent

---

## Procedure

### Bước 1: Đọc system architecture và SLA requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (architecture)

READ: devops-patterns.md (Section 6: Monitoring Stack, Section 7: Alerting Rules)
READ: devops-iac-templates.md (Section 2: Prometheus Config, Section 5: Distributed Tracing)

Cần xác định từ phase3-architecture:
□ Danh sách services và components cần monitor
□ Uptime target (99.9% / 99.99% → ảnh hưởng alert thresholds)
□ Business-critical flows (checkout, payment, login → cần business metrics)
□ External dependencies (third-party APIs, payment gateways → cần external monitoring)
□ Infrastructure: K8s / ECS / VMs → ảnh hưởng metric collection approach
□ Team size và on-call setup → ảnh hưởng notification routing
```

### Bước 2: Thiết kế observability pillars (Metrics, Logs, Traces)

```
Ba trụ cột observability — phải implement đủ cả 3:

PILLAR 1 — METRICS (cái gì đang xảy ra):
  Mục đích: đo lường trạng thái và performance theo thời gian
  Tool: Prometheus + Grafana (self-hosted) hoặc Datadog / CloudWatch (managed)
  WHY tự host Prometheus: không có vendor lock-in, chi phí thấp hơn ở scale
  WHY Datadog: operational overhead thấp hơn nếu team nhỏ, budget cho phép

PILLAR 2 — LOGS (tại sao xảy ra):
  Mục đích: context chi tiết khi investigate incidents
  Tool: ELK Stack (self-hosted) hoặc Loki + Grafana (lightweight)
  WHY Loki thay vì ELK: Loki chỉ index labels (không full-text), chi phí lưu trữ thấp hơn 5-10x
  WHY ELK: cần full-text search phức tạp, compliance log analytics

PILLAR 3 — TRACES (ở đâu xảy ra):
  Mục đích: trace request qua multiple services, tìm bottleneck
  Tool: Jaeger (self-hosted) hoặc Grafana Tempo
  WHY: không thể debug distributed system chỉ với metrics và logs
  WHY Tempo thay vì Jaeger: tích hợp native với Grafana, cùng storage layer với Loki

Tích hợp giữa 3 pillars:
□ Logs có trace_id → click từ log sang trace (exemplars)
□ Metrics dashboards link đến relevant logs
□ Alerts link đến runbook
```

### Bước 3: Thiết kế metrics collection

```
READ: devops-patterns.md (Section 6: Metrics cần có cho mọi service)
READ: devops-iac-templates.md (Section 2: Prometheus scrape config)

Application metrics (bắt buộc cho mọi service):
□ http_requests_total{method, status, endpoint}           → Counter
□ http_request_duration_seconds{method, endpoint}         → Histogram (P50/P95/P99)
□ db_query_duration_seconds{operation, table}             → Histogram
□ cache_hit_ratio{cache_name}                              → Gauge
□ active_connections{type}                                 → Gauge

Business metrics (tùy domain — phải định nghĩa với product team):
  E-commerce:
    □ orders_created_total, orders_failed_total
    □ payment_success_total, payment_failed_total
    □ checkout_funnel_drop_rate{step}
  SaaS:
    □ active_sessions_total
    □ api_quota_usage{tenant, endpoint}
    □ feature_usage_total{feature_name}
  Logistics:
    □ shipments_created_total, deliveries_completed_total
    □ route_optimization_duration_seconds

Infrastructure metrics (tự động qua exporters):
□ CPU: node_cpu_seconds_total → compute_cpu_utilization_percent
□ Memory: node_memory_MemAvailable_bytes
□ Disk: node_filesystem_avail_bytes → disk utilization
□ Network: node_network_receive_bytes_total, transmit_bytes_total
□ Container: cadvisor → container CPU, memory, network per pod

Prometheus scrape config:
□ scrape_interval: 15s mặc định, 10s cho critical services
□ Job naming: [service-name]-[environment]
□ Labels chuẩn hóa: environment, region, service, version
□ Service discovery: K8s annotations hoặc Consul (không hardcode targets)
```

### Bước 4: Thiết kế log aggregation

```
Logging standards (bắt buộc cho mọi service):
□ Format: JSON structured (không plain text)
□ Mọi log entry phải có: timestamp (RFC3339), level, message, service, trace_id
□ Business events phải log: user_id, entity_id, action
□ Logging levels (xem devops-patterns.md Section 6 — Logging levels)

READ: devops-patterns.md (Section 6: Logs structured JSON example)

Loki setup (nếu chọn Loki):
□ Promtail agent trên mỗi node để collect container logs
□ Labels cho Loki: job, namespace, pod, container (không label bằng content)
□ WHY: Loki index theo labels không theo content → giữ labels ở mức tối thiểu
□ Log retention: 30 ngày hot storage, 90 ngày cold storage (S3/GCS)
□ LogQL queries cho common patterns: error spike, latency spike, user journey

ELK setup (nếu chọn ELK):
□ Filebeat / Logstash collect từ containers
□ Elasticsearch index templates với ILM policy
□ Kibana dashboards: error rates, user activity, system health
□ Index naming: [service]-[env]-YYYY.MM.DD

Log security:
□ Mask PII trước khi log: email, phone, credit card, password → [REDACTED]
□ Không log request/response body mặc định (opt-in với debug flag)
□ Log access control: production logs chỉ accessible cho authorized users
```

### Bước 5: Thiết kế distributed tracing

```
READ: devops-iac-templates.md (Section 5: Distributed Tracing Setup)

OpenTelemetry instrumentation:
□ Implement OpenTelemetry SDK trong mọi service (không dùng vendor-specific SDK)
  WHY OpenTelemetry: vendor-neutral, có thể switch backend sau mà không đổi code
□ Auto-instrumentation: HTTP, gRPC, database, cache (hầu hết frameworks hỗ trợ)
□ Manual span: business transactions quan trọng (checkout, order processing)

Trace context propagation:
□ W3C Trace Context standard (traceparent, tracestate headers)
□ Propagate qua: HTTP headers, message queue metadata, gRPC metadata
□ End-to-end trace từ load balancer → API → service → DB

Sampling strategy:
□ 100% sampling cho errors và slow requests (> 2x P95 baseline)
□ 5-10% head-based sampling cho normal traffic
□ WHY: 100% sampling = tốn storage, 0% sampling = blind khi incident
□ Priority sampling: tăng sampling cho high-value user segments

Jaeger / Grafana Tempo setup:
□ Collector endpoint cho OpenTelemetry SDK gửi spans đến
□ Storage: Cassandra (Jaeger) hoặc object storage S3/GCS (Tempo)
□ Retention: 7 ngày default (tăng nếu compliance cần)
□ Service dependency graph: visualize service topology từ traces
```

### Bước 6: Thiết kế dashboard templates

```
READ: devops-iac-templates.md (Section 2: Prometheus config + alert rules)

Dashboard 1 — Service Health Overview (mọi team):
  Row 1: Traffic — RPS, error rate (%), P95/P99 latency
  Row 2: Saturation — CPU%, Memory%, active connections
  Row 3: Dependencies — DB query time, cache hit rate, external API success rate
  Row 4: Business — key business metrics theo domain

Dashboard 2 — Infrastructure Overview (DevOps/SRE):
  Row 1: Cluster health — node count, pod status, resource utilization
  Row 2: Networking — ALB request count, target response time, 5xx count
  Row 3: Database — connections, IOPS, replica lag
  Row 4: Cost indicators — est. daily cost trend

Dashboard 3 — Deployment Tracking (release view):
  Row 1: Deployment history — version rollout timeline
  Row 2: Post-deploy metrics — error rate before/after, latency before/after
  Row 3: DORA metrics — deployment frequency, lead time, MTTR, change failure rate

Dashboard 4 — Business KPIs (product/business):
  Tùy chỉnh theo domain — ví dụ e-commerce:
  - Conversion funnel (sessions → cart → checkout → order)
  - Revenue per hour (trend, anomaly detection)
  - Failed payments count

Grafana best practices:
□ Template variables cho environment, service, region (không hardcode)
□ Dashboard provisioning qua code (không click-ops trong Grafana UI)
□ Version control dashboards trong git repository
□ Alert từ dashboard panels (không định nghĩa riêng lẻ)
```

### Bước 7: Thiết kế alert rules

```
READ: devops-patterns.md (Section 7: Alerting Rules Template)
READ: devops-iac-templates.md (Section 2: Prometheus alert rules examples)

Alert severity tiers:

P0 - Critical (response: < 5 phút, phone call + PagerDuty):
  □ Service down (up == 0 trong 1 phút)
  □ Error rate > 5% trong 2 phút
  □ Database unreachable
  □ Disk full (> 95%)
  □ Security breach detected

P1 - High (response: < 15 phút, PagerDuty + Slack #incidents):
  □ Error rate > 1% trong 5 phút
  □ P99 latency > 5 giây trong 3 phút
  □ Certificate expiry < 7 ngày
  □ Deployment failed in production

P2 - Medium (response: < 1 giờ, Slack #alerts):
  □ CPU > 80% trong 10 phút
  □ Memory > 85% trong 10 phút
  □ P95 latency > 2 giây trong 5 phút
  □ Cache hit rate < 70%
  □ Disk > 80%

P3 - Low (response: trong ngày, Slack #monitoring):
  □ Test environment down
  □ Non-critical job failed
  □ Certificate expiry < 30 ngày

Alert quality rules (chống alert fatigue):
□ Mỗi alert phải có: summary, description, runbook link
□ Alert phải actionable — không alert nếu không có action cụ thể
□ for: duration (ít nhất 2 phút để tránh flapping, P0 có thể 1 phút)
□ Dead Man's Switch: alert khi monitoring system tự bị down
□ Alert volume target: < 5 alerts/ngày trong normal operations

Routing rules:
□ P0/P1: PagerDuty → on-call engineer phone
□ P2: Slack #alerts → team lead acknowledge
□ P3: Slack #monitoring → ticket creation
□ Business hours filter: P3 chỉ notify trong giờ làm việc
```

### Bước 8: Thiết kế on-call runbook templates

```
Mỗi P0/P1 alert phải có runbook tương ứng. Template:

---
# Runbook: [Alert Name]

## Mô tả
[1-2 câu mô tả alert này nghĩa là gì]

## Nguyên nhân phổ biến
1. [Nguyên nhân 1]
2. [Nguyên nhân 2]

## Diagnosis steps
```bash
# Step 1: Check service status
kubectl get pods -n [namespace] | grep [service]

# Step 2: Check recent logs
kubectl logs -n [namespace] -l app=[service] --since=10m | grep ERROR

# Step 3: Check metrics
# Link: [Grafana dashboard URL]
```

## Resolution
[Bước giải quyết từng case]

## Escalation
- Nếu không resolve trong 15 phút → escalate to [role]
- Nếu database liên quan → contact dba on-call

## Post-incident
□ Update incident ticket
□ Schedule post-mortem nếu impact > 30 phút
---

Danh sách runbooks cần tạo (tối thiểu):
□ HighErrorRate
□ ServiceDown
□ HighLatency
□ DatabaseUnreachable
□ DiskSpaceCritical
□ CertificateExpiringSoon
□ DeploymentFailed
```

### Bước 9: Tích hợp PagerDuty / OpsGenie

```
On-call rotation setup:
□ Primary on-call + Backup on-call (không để single point of failure)
□ Escalation policy: 5 phút → primary, 10 phút → backup, 15 phút → manager
□ On-call schedule: weekly rotation, không ai on-call > 2 tuần liên tiếp
□ Business hours vs off-hours routing khác nhau

Integration checklist:
□ AlertManager → PagerDuty webhook (P0, P1)
□ AlertManager → Slack channel (tất cả severity)
□ Incident response channel: tạo Slack channel riêng cho mỗi major incident
□ Status page update: tích hợp incident status với public status page
□ Post-incident: tự động tạo incident report template
```

### Bước 10: Viết monitoring configuration và docs

```
Output files:
  monitoring/
  ├── prometheus/
  │   ├── prometheus.yml               → Scrape config
  │   └── rules/
  │       ├── app-alerts.yml           → Application alert rules
  │       ├── infra-alerts.yml         → Infrastructure alert rules
  │       └── business-alerts.yml     → Business metric alerts
  ├── grafana/
  │   └── dashboards/
  │       ├── service-health.json      → Provisioned dashboard
  │       ├── infrastructure.json
  │       └── business-kpis.json
  ├── alertmanager/
  │   └── alertmanager.yml            → Routing + receivers config
  └── runbooks/
      ├── high-error-rate.md
      ├── service-down.md
      └── [alert-name].md

Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/monitoring-guide.md

Cấu trúc output docs:
  1. Observability architecture diagram
  2. Metrics catalog (mọi metrics được collect, ý nghĩa)
  3. Alert inventory (tên, severity, threshold, runbook link)
  4. Dashboard inventory (tên, audience, link)
  5. On-call setup và escalation policy
  6. Tracing setup và sampling strategy
  7. Log retention và access control policy
  8. Monthly observability cost estimate
```

---

## Checklist trước khi submit

```
□ Đủ 3 pillars: Metrics, Logs, Traces
□ Application metrics cover 4 golden signals: Latency, Traffic, Errors, Saturation
□ Business metrics được define theo domain
□ Alert rules đủ 4 severity tiers (P0-P3) với routing phù hợp
□ Mỗi P0/P1 alert có runbook link
□ Alert actionable — không có "informational" alerts
□ Dead Man's Switch alert đã setup
□ Dashboard cover: service health, infra, deployment tracking, business KPIs
□ Dashboard provisioned qua code (không manual click-ops trong Grafana)
□ PII data masked trong logs
□ On-call rotation và escalation policy đã define
□ Trace sampling strategy đã define (không 100% sampling cho normal traffic)
□ Monitoring stack có HA — không dùng single Prometheus instance cho production
```
