# Playbook: Thiết kế Infrastructure

> **Type**: Agent Skill Playbook
> **Agent**: devops
> **Triggered by**: `/wf-prepare-deployment` hoặc khi cần thiết kế infrastructure cho deployment
> **Output**: Infrastructure design docs + IaC files tại phase6-deployment/

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-prepare-deployment` để thiết kế infrastructure production
- Khi architect yêu cầu infrastructure design review
- Khi dự án cần migrating từ shared hosting / VPS đơn lẻ sang cloud infrastructure có khả năng scale
- Khi cần thiết kế infrastructure cho micro-services hoặc monolith mới
- IaC là bắt buộc — không cho phép manual provisioning (click-ops)

---

## Procedure

### Bước 1: Đọc performance và scaling requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (architecture), PHASE1 (business reqs)

READ: devops-patterns.md (Section 4: IaC Patterns, Section 5: Environment Strategy)
READ: devops-iac-templates.md (Section 1: Terraform Production Template)

Cần xác định từ phase3-architecture:
□ Expected concurrent users (peak vs average)
□ Request rate (RPS) và data volume
□ SLA / uptime requirements (99.9% = ~8.7h downtime/year, 99.99% = ~52m/year)
□ Data residency requirements (GDPR → EU region, v.v.)
□ Compliance requirements: PCI-DSS, HIPAA, SOC2 ảnh hưởng đến architecture
□ Existing systems cần integrate (VPNs, databases, identity providers)
□ Budget constraints (cloud spend estimate)
```

### Bước 2: Chọn cloud provider và compute strategy

```
Cloud provider selection (dựa trên context dự án):

AWS → Default choice khi:
  - Team đã có AWS experience
  - Cần managed services phong phú (RDS, ElastiCache, SQS, Lambda)
  - Khách hàng có AWS enterprise agreement

GCP → Ưu tiên khi:
  - Nặng về data / ML workloads (BigQuery, Vertex AI)
  - Kubernetes native (GKE là managed K8s tốt nhất thị trường)

Azure → Ưu tiên khi:
  - Tổ chức dùng Microsoft 365 / Active Directory
  - .NET ecosystem

Compute strategy decision matrix:

Loại workload           → Compute approach
─────────────────────────────────────────────
Web API (stateless)     → ECS Fargate / Cloud Run (serverless containers)
                          WHY: không quản lý nodes, auto-scale, pay-per-use
Complex microservices   → EKS / GKE / AKS (managed Kubernetes)
                          WHY: fine-grained resource control, service mesh, RBAC
Monolith truyền thống   → EC2 Auto Scaling Group + ALB
                          WHY: quen thuộc với team, ít operational overhead ban đầu
Batch processing        → Lambda / Cloud Functions + SQS/Pub/Sub
                          WHY: chi phí thấp, không cần server running 24/7
Static + API hybrid     → CDN (CloudFront/Fastly) + serverless backend
                          WHY: global performance, minimal infra management
```

### Bước 3: Thiết kế networking (VPC, subnets, security groups)

```
READ: devops-iac-templates.md (Section 1: Terraform Production Template — VPC sections)

Network architecture bắt buộc (3-tier):

  Internet
     │
  [Internet Gateway]
     │
  ┌──────────────────────────────────────┐
  │           VPC (10.0.0.0/16)          │
  │                                      │
  │  Public Subnets (10.0.1.0/24, ...)   │
  │  [NAT Gateway] [Load Balancer]       │
  │         │                            │
  │  Private Subnets (10.0.10.0/24, ...) │
  │  [App Servers] [K8s Nodes]           │
  │         │                            │
  │  Data Subnets (10.0.20.0/24, ...)    │
  │  [RDS] [ElastiCache] [Kafka]         │
  └──────────────────────────────────────┘

Security group rules (principle of least privilege):
□ ALB security group: chỉ accept 80/443 từ 0.0.0.0/0
□ App security group: chỉ accept ports từ ALB security group
□ DB security group: chỉ accept port DB từ App security group
□ KHÔNG có security group với inbound 0.0.0.0/0 trừ ALB

Multi-AZ deployment (bắt buộc cho production):
□ Subnets trải đều ít nhất 2 AZs (khuyến nghị 3 AZs)
□ Load balancer span ít nhất 2 AZs
□ Database với Multi-AZ hoặc read replica trong AZ khác
WHY: Single-AZ = single point of failure, AZ outage = toàn bộ app down
```

### Bước 4: Thiết kế load balancing và auto-scaling

```
READ: devops-iac-templates.md (Section 1: ALB + ASG + CloudWatch template)

Load Balancer configuration:
□ Application Load Balancer (L7) — cho HTTP/HTTPS services
□ Network Load Balancer (L4) — cho TCP/UDP (game servers, low-latency)
□ SSL termination tại load balancer (không tại app servers)
□ SSL policy: TLS 1.2+ minimum (TLS 1.3 preferred)
□ Access logs bật để compliance và debugging
□ WAF integration cho public-facing services

Auto-scaling rules:
□ Scale-out trigger: CPU > 70% trong 2 phút
□ Scale-in trigger: CPU < 30% trong 10 phút (cooldown dài hơn để tránh flapping)
□ Minimum capacity: ≥ 2 instances (tránh single point of failure)
□ Maximum capacity: tính toán dựa trên budget và peak load estimate
□ Health check: ELB type (không phải EC2 type) để replace unhealthy instances

Kubernetes HPA (nếu dùng K8s):
  READ: devops-iac-templates.md (Section 7: K8s HPA config)
  □ Scale dựa trên CPU + custom metrics (HTTP RPS)
  □ minReplicas: 2, maxReplicas: định nghĩa rõ ràng
  □ PodDisruptionBudget: minAvailable: 1 để tránh down khi scale-down
```

### Bước 5: Thiết kế database infrastructure

```
Database infrastructure decision:

Relational (PostgreSQL/MySQL):
  Small-Medium (< 500 RPS DB reads) → RDS với Multi-AZ
  Large (> 500 RPS) → RDS Proxy + Read Replicas hoặc Aurora
  WHY RDS Proxy: connection pooling, giảm connection exhaustion

Non-relational:
  Cache layer → ElastiCache Redis (cluster mode cho HA)
  Document store → MongoDB Atlas (managed) hoặc DynamoDB
  Queue → SQS (simple) hoặc MSK/Kafka (complex event streaming)

Database high availability checklist:
□ Primary + standby trong AZs khác nhau (Multi-AZ hoặc replica)
□ Automated backups: daily, retention 7 ngày minimum (30 ngày cho production)
□ Point-in-time recovery bật
□ Encrypted at rest (AES-256) và in transit (TLS)
□ Maintenance window: thời gian thấp điểm, coordinate với business

Storage sizing:
□ Allocate 200% dung lượng dự kiến năm đầu (storage expansion tốn kém và rủi ro)
□ Enable Storage Auto Scaling (RDS) để tránh storage full
□ Monitor storage growth rate → cảnh báo khi reach 75%
```

### Bước 6: Thiết kế CDN strategy

```
CDN áp dụng cho:
□ Static assets: JS, CSS, images, fonts → cache tại edge (TTL: 1 năm với cache-busting hash)
□ API responses (public, không cần auth) → cache với TTL ngắn (TTL: 1-60 giây)
□ Media files (video, large images) → CDN với pre-signed URLs
□ Geographic distribution → chọn CDN provider có PoPs gần user base

CloudFront (AWS) configuration:
□ Origin access control cho S3 (không expose S3 bucket trực tiếp)
□ HTTPS only, redirect HTTP → HTTPS
□ Security headers: HSTS, X-Frame-Options, Content-Security-Policy
□ Custom error pages (404, 503) với branding
□ Real-time logging cho analytics và security monitoring

Cache invalidation strategy:
□ Content-addressed URLs: /assets/app.[hash].js → không cần invalidate
□ index.html và API responses: invalidate thủ công khi deploy
□ Tránh invalidate toàn bộ cache (tốn kém, làm tăng origin load đột biến)
```

### Bước 7: Thiết kế backup và disaster recovery

```
Recovery objectives (xác định từ business requirements):
□ RPO (Recovery Point Objective): data loss tối đa chấp nhận được
  - RPO = 0: real-time replication (tốn kém)
  - RPO = 1h: hourly snapshots
  - RPO = 24h: daily backups (minimum cho production)
□ RTO (Recovery Time Objective): thời gian downtime tối đa chấp nhận
  - RTO < 1h: hot standby (active-passive cluster)
  - RTO < 4h: warm standby
  - RTO < 24h: cold backup restore

Backup strategy:
□ Database: automated RDS snapshots + manual snapshot trước mỗi major deploy
□ Application state: stateless services không cần backup (state trong DB/cache)
□ Infrastructure state: Terraform state lưu trong S3 với versioning bật
□ Container images: lưu trong registry với immutable tags, retention 90 ngày
□ Secrets: Vault backup hoặc Secrets Manager với cross-region replication

DR runbook (phải document):
□ Failover steps từ primary region sang DR region
□ Database restore procedure với estimated time
□ DNS failover mechanism (Route53 health checks hoặc manual)
□ Validation checklist sau DR
□ DR drill schedule: test tối thiểu mỗi 6 tháng
```

### Bước 8: Tính toán cost estimation

```
READ: devops-iac-templates.md (Section 6: Cost Optimization Patterns)

Cost estimation framework:
□ Compute: [số instances] x [instance type price/h] x 730h/tháng
□ Database: RDS price + storage + I/O
□ Network: data transfer out (egress thường là chi phí bị quên nhiều nhất)
□ Load balancer: LCU-based pricing
□ CDN: requests + data transfer
□ Monitoring: custom metrics, log retention

Optimization strategies áp dụng ngay:
□ Dev environment: scale down sau 18:00 (saving ~60% compute)
□ Spot instances cho non-critical workloads: batch jobs, CI agents
□ Reserved Instances cho baseline production load: 1-year, 20-30% savings
□ S3 lifecycle policies: move logs sang Glacier sau 30 ngày

Cost alert:
□ Budget alerts tại 80% và 100% monthly budget
□ Cost anomaly detection bật
□ Tagging strategy: mọi resource phải có tags: Environment, Service, Team, CostCenter
```

### Bước 9: Viết IaC templates và infrastructure docs

```
READ: devops-iac-templates.md (Section 1: Terraform template, Section 4: GitOps)

IaC structure (bắt buộc sử dụng Terraform):
  infrastructure/
  ├── modules/
  │   ├── vpc/            → VPC, subnets, routing
  │   ├── compute/        → EC2 ASG hoặc EKS cluster
  │   ├── database/       → RDS, ElastiCache
  │   ├── networking/     → ALB, security groups, ACM
  │   └── monitoring/     → CloudWatch, SNS topics
  ├── environments/
  │   ├── dev/            → main.tf, variables.tf, terraform.tfvars
  │   ├── staging/
  │   └── production/
  └── shared/             → Route53, ACM certificates, ECR

Terraform best practices:
□ Remote state: S3 backend với DynamoDB locking (xem devops-patterns.md Section 4)
□ Workspace per environment (không dùng same state file)
□ Module versioning: pin module source với git tag cụ thể
□ Sensitive variables: terraform.tfvars không commit vào git
□ Plan trước khi apply: CI/CD chạy terraform plan, human approve, terraform apply
□ Taint và targeted apply: chỉ dùng khi thực sự cần (prefer full plan/apply)

GitOps cho infrastructure:
□ Infrastructure changes = PR → review → merge → auto-apply
□ terraform plan output trong PR comment để review trực quan
□ Mọi apply phải có audit trail (ai approve, khi nào, thay đổi gì)

Output:
□ Ghi vào path do skill cung cấp
□ Fallback: .mc-data/docs/phase6-deployment/infrastructure-design.md

Cấu trúc output docs:
  1. Infrastructure architecture diagram
  2. Cloud resource inventory (loại, size, số lượng, region)
  3. Network topology và security groups
  4. Database và cache setup
  5. Auto-scaling configuration
  6. Backup và DR plan
  7. Monthly cost estimate (base + peak)
  8. IaC module structure description
  9. Open questions cần xác nhận với stakeholders
```

---

## Checklist trước khi submit

```
□ Infrastructure design cover đủ 3 tiers: networking, compute, data
□ Multi-AZ deployment cho production (không single-AZ)
□ Security groups theo principle of least privilege
□ Database có Multi-AZ hoặc read replica + automated backups
□ Auto-scaling configured với scale-in và scale-out rules
□ CDN strategy cho static assets
□ RPO và RTO đã define và có DR plan tương ứng
□ Cost estimate đã có (base case + peak load case)
□ IaC templates sử dụng Terraform với remote state
□ Tất cả resource có tags theo naming convention
□ Không có manual provisioning steps trong design (100% IaC)
□ Open questions được list ra để stakeholders confirm
```
