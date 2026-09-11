# Engineering - DevOps IaC Templates & Advanced Patterns

> **Domain**: Engineering / DevOps & Infrastructure
> **Last Updated**: 2026-03-15
> **Nguồn**: HashiCorp Terraform best practices, Prometheus documentation, Kubernetes docs

---

## 1. Terraform Production Template (AWS)

```hcl
# main.tf — Terraform template với auto-scaling, ALB, CloudWatch alarm

provider "aws" {
  region = var.aws_region
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                      = "${var.app_name}-asg"
  min_size                  = 2
  max_size                  = 10
  desired_capacity          = 2
  vpc_zone_identifier       = var.subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = var.app_name
    propagate_at_launch = true
  }
}

# Application Load Balancer
resource "aws_lb" "app" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  enable_deletion_protection = true

  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Auto Scaling Policy
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.app_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 2
  cooldown               = 300
}

# CloudWatch Alarm — CPU cao kích hoạt scale out
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.app_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "Scale out khi CPU > 75% trong 4 phút"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

# CloudWatch Alarm — Error rate cao, notify SNS
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.app_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Cảnh báo khi số lượng lỗi 5xx vượt ngưỡng"
  alarm_actions       = [var.sns_alert_topic_arn]

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }
}
```

---

## 2. Prometheus Monitoring Configuration

```yaml
# prometheus.yml — Prometheus scrape config
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: production
    region: ap-southeast-1

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

rule_files:
  - /etc/prometheus/rules/*.yml

scrape_configs:
  - job_name: app-backend
    metrics_path: /metrics
    scrape_interval: 10s
    static_configs:
      - targets: [app-backend:8080]

  - job_name: node-exporter
    static_configs:
      - targets: [node-exporter:9100]

  - job_name: cadvisor
    static_configs:
      - targets: [cadvisor:8080]
```

```yaml
# /etc/prometheus/rules/app-alerts.yml
groups:
  - name: HighErrorRate
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: |
          rate(http_requests_total{status=~"5.."}[5m])
          / rate(http_requests_total[5m]) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Tỷ lệ lỗi HTTP 5xx cao (instance {{ $labels.instance }})"
          description: "Tỷ lệ lỗi 5xx = {{ $value | humanizePercentage }}. Vượt ngưỡng 5% trong 2 phút."
          runbook: https://wiki.internal/runbooks/high-error-rate

  - name: HighResponseTime
    rules:
      - alert: HighResponseTime
        expr: |
          histogram_quantile(0.95,
            rate(http_request_duration_seconds_bucket[5m])
          ) > 2.0
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "Response time P95 vượt 2 giây (instance {{ $labels.instance }})"
          runbook: https://wiki.internal/runbooks/high-response-time

  - name: ServiceDown
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service không phản hồi (instance {{ $labels.instance }})"

  - name: HighMemoryUsage
    rules:
      - alert: HighMemoryUsage
        expr: |
          (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
          / node_memory_MemTotal_bytes > 0.90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Memory sử dụng > 90% (host {{ $labels.instance }})"
```

---

## 3. Deployment Guide Template

```markdown
# Deployment Guide: [System Name]

## Environments

| Environment | URL | Purpose |
|-------------|-----|---------|
| Development | | Development testing |
| Staging | | Pre-production testing |
| Production | | Live system |

## Infrastructure Diagram

Load Balancer → [App 1, App 2, App 3] → Database

## CI/CD Pipeline

Commit → Build → Test → Deploy Staging → Smoke Test → Deploy Production

## Deployment Checklist
- [ ] All tests passing
- [ ] Database migrations run
- [ ] Environment variables set
- [ ] Health checks passing
- [ ] Monitoring alerts configured
- [ ] Security scanning passed
- [ ] Rollback plan documented
```

---

## 4. GitOps Workflow

```
Developer commit → Git repo (desired state)
     ↓
ArgoCD/Flux (reconciliation loop)
     ↓
Kubernetes cluster (actual state)
     ↓
Audit trail: mọi infrastructure change = git commit có thể revert
```

**Lợi ích GitOps:**
- Mọi thay đổi infrastructure có PR review
- Rollback = revert git commit
- Audit trail đầy đủ theo thời gian

---

## 5. Distributed Tracing Setup

- Implement OpenTelemetry SDK across tất cả services
- Visualize trong Jaeger hoặc Grafana Tempo
- Trace context propagation qua service boundaries (W3C Trace Context standard)
- Mục tiêu: trả lời "Tại sao request này chậm?" trong < 30 giây
- Sampling strategy: 100% cho errors, 5-10% cho normal traffic

---

## 6. Cost Optimization Patterns

| Pattern | Cách thực hiện | Target savings |
|---------|----------------|----------------|
| Right-sizing | Monitor utilization 30 ngày, resize khi < 30% liên tục 2 tuần | Giảm over-provisioning |
| Spot instances | Dùng cho batch jobs và non-critical workloads, pair với on-demand baseline | 30–40% vs on-demand |
| Reserved Instances | Mua RI cho baseline load (1-year / 3-year), Savings Plans cho flexibility | 20–30% trên compute |
| Auto-scaling | Scale dựa trên custom metrics, không chỉ CPU | 60–75% average utilization |

---

## 7. Advanced Kubernetes Patterns

```yaml
# Horizontal Pod Autoscaler — scale dựa trên custom metrics
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"
```

**Network Policies** — zero-trust networking trong K8s:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-only-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
```
