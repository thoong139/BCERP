# Infrastructure Specification — [TÊN DỰ ÁN]

> READS: `phase3-architecture/P3-01-architecture.md`
> OUTPUT: Môi trường, server specs, networking, monitoring
> USED BY: `phase6-deployment/deployment-guide.md`
> DATE: YYYY-MM-DD

---

## 1. Environments

| Env | URL | Branch | Auto-deploy | Mục đích |
|-----|-----|--------|------------|---------|
| Development | `localhost` | any | No | Local dev |
| Staging | `staging.[domain]` | `develop` | Yes (on push) | QA testing |
| Production | `[domain]` | `main` | Manual approval | Live |

---

## 2. Required Environment Variables

> ⚠️ CRITICAL: Không hardcode giá trị này trong code. Luôn dùng ENV.

| Variable | Mô tả | Required | Ví dụ |
|----------|-------|---------|-------|
| `DATABASE_URL` | PostgreSQL connection string | ✅ | `postgresql://user:pass@host:5432/db` |
| `REDIS_URL` | Redis connection | ✅ | `redis://host:6379` |
| `JWT_SECRET` | JWT signing secret (min 64 chars) | ✅ | Random secure string |
| `JWT_EXPIRES_IN` | Access token TTL (seconds) | ✅ | `3600` |
| `JWT_REFRESH_EXPIRES_IN` | Refresh token TTL (seconds) | ✅ | `604800` (7 days) |
| `PORT` | Application port | ✅ | `3000` |
| `NODE_ENV` | Environment name | ✅ | `production` |
| `LOG_LEVEL` | Logging level | ✅ | `info` |
| `TZ` | Timezone | ✅ | `UTC` |
| `INTERNAL_SERVICE_TOKEN` | Service-to-service auth | ✅ | Random secure string |
| `[SERVICE]_API_KEY` | External service key | Theo service | — |
| `[SERVICE]_URL` | External service URL | Theo service | — |
| `DB_POOL_SIZE` | DB connection pool | Recommended | `10` |
| `CORS_ORIGINS` | Allowed CORS origins | ✅ | `https://[domain]` |

---

## 3. Server / Container Specs

> 📐 Scale Note: Dự án nhỏ — single server đủ. Dự án lớn — container orchestration.

| Service | CPU | RAM | Storage | Replicas |
|---------|-----|-----|---------|---------|
| Backend API | 2 vCPU | 2GB | — | 2 (prod) |
| Frontend | 1 vCPU | 512MB | — | 2 (prod) |
| PostgreSQL | 4 vCPU | 8GB | 100GB SSD | 1 primary + 1 replica |
| Redis | 1 vCPU | 1GB | — | 1 |
| [Other] | [specs] | [specs] | [specs] | [count] |

---

## 4. Networking

```
Public:
  Frontend: HTTPS :443 → CDN → Server
  API:      HTTPS :443 → Load Balancer → Backend instances

Internal (không expose ra ngoài):
  Backend ↔ Database: Port 5432 (PostgreSQL)
  Backend ↔ Redis:    Port 6379
  Service ↔ Service:  Internal network only

Firewall rules:
  - Chỉ port 80, 443 public
  - DB chỉ accept từ backend IP/VPC
  - Redis chỉ accept từ backend IP/VPC
```

---

## 5. Storage

### 5.1. Storage Types

| Loại | Options | Mục đích | Ghi chú |
|------|---------|---------|---------|
| Application DB | PostgreSQL | All business data | Primary data store |
| Cache | Redis | Sessions, app cache | Ephemeral — không cần backup |
| Object storage | S3 / MinIO / GCS / Azure Blob | User uploads, documents, exports | Chọn theo cloud provider |
| Local disk | NFS / EFS / host volume | Dev/staging only | Không dùng production |
| Logs | ELK / CloudWatch / Datadog | Application + audit logs | Retention theo mục 5.3 |
| CDN | CloudFront / Cloudflare | Static assets, file delivery | Cache layer cho object storage |

> Lựa chọn khuyến nghị: production dùng managed object storage (S3-compatible) để đảm bảo durability và scalability. Tránh local disk cho production.

### 5.2. Backup Strategy

| Storage | Phương thức | Tần suất | Kiểm tra restore |
|---------|------------|---------|-----------------|
| PostgreSQL | Automated snapshot (pg_dump hoặc cloud snapshot) | Hàng ngày (02:00 AM UTC) | Hàng tháng — restore vào staging |
| Object storage | Cross-region replication hoặc versioning bật | Liên tục (versioning) | Quý — spot check 10 files |
| Redis | Không backup (regenerable) | N/A | N/A |
| Logs | Archive to cold storage sau retention period | Liên tục | N/A |

> Backup files phải được lưu ở region / account khác với production để tránh single point of failure.

### 5.3. Retention Policy

| Loại dữ liệu | Giữ bao lâu | Sau khi hết hạn | Quy định |
|---------------|-------------|-----------------|----------|
| DB daily backup | [30] ngày | Tự động xóa | — |
| DB weekly snapshot | [12] tuần | Tự động xóa | — |
| DB monthly archive | [12] tháng | Cold storage hoặc xóa | Company policy |
| User uploaded files | Vĩnh viễn (khi còn active) | Xóa sau [90] ngày soft-delete | — |
| Application logs | [30] ngày hot | [12] tháng cold | — |
| Audit logs | [2] năm | Archive to cold storage | [Compliance requirement] |
| Temp files / uploads | [24] giờ | Auto-cleanup job | — |

---

## 6. Deployment Setup

```
Container: Docker
Orchestration: [Docker Compose / Kubernetes / ECS]
CI/CD: [GitHub Actions / GitLab CI / Jenkins]
Registry: [Docker Hub / ECR / GCR]

Build process:
  1. npm install / pip install
  2. Run tests (tự động block nếu fail)
  3. Build production bundle
  4. Build Docker image với Git SHA tag
  5. Push to registry
  6. Deploy (rolling update)
  7. Health check
```

---

## 7. Health Check Endpoints

| Endpoint | Checks | Expected response |
|----------|--------|------------------|
| `GET /health` | App is running | `{ "status": "ok" }` |
| `GET /health/db` | DB connection | `{ "status": "ok", "latency": "Xms" }` |
| `GET /health/redis` | Redis connection | `{ "status": "ok" }` |
| `GET /health/ready` | App ready to serve | `{ "status": "ready" }` |

---

## 8. Monitoring & Alerting

| Metric | Threshold Alert | Severity |
|--------|----------------|---------|
| Error rate | > 1% / 5 min | HIGH |
| P95 response time | > 2s | HIGH |
| CPU usage | > 85% | MEDIUM |
| Memory usage | > 90% | HIGH |
| DB connections | > 80% pool | MEDIUM |
| Disk usage | > 80% | MEDIUM |
| Failed health check | 2 consecutive | CRITICAL |

**Alert channels:** [Email / Slack / PagerDuty]
**Dashboards:** [Grafana / CloudWatch / Datadog]

---

## 9. Non-Functional Requirements (Kỹ Thuật Hóa)

> *Chuyển đổi yêu cầu chất lượng từ P1-01 thành target kỹ thuật đo lường được.*

### 9.1. Performance Targets

> *Các giá trị `[N]` là placeholder — thay bằng số thực tế từ Non-Functional Requirements trong `P1-01-business-overview.md` (phần Performance/SLA). Tham khảo P1-01 trước khi set target.*

| Metric | Target | Đo bằng | Action nếu vượt |
|--------|--------|---------|-----------------|
| API Response Time (P50) | < [200]ms | APM monitoring | Investigate |
| API Response Time (P95) | < [500]ms | APM monitoring | Alert MEDIUM |
| API Response Time (P99) | < [2000]ms | APM monitoring | Alert HIGH |
| Page Load Time (First Contentful Paint) | < [1.5]s | Real User Monitoring | Optimize assets |
| Database Query Time (P95) | < [100]ms | Slow query log | Index review |
| Throughput | [200] RPS per instance | Load balancer metrics | Auto-scale |

### 9.2. Scalability

| Hạng mục | Giới hạn hiện tại | Kế hoạch mở rộng | Trigger scale |
|----------|-------------------|-------------------|---------------|
| Concurrent users | [500] | Horizontal scale backend | CPU > 70% sustained |
| Database size | [100]GB | Read replicas, partitioning | Disk > 70% |
| File storage | [50]GB | Object storage (S3) | Disk > 80% |
| Message queue | [1000] msg/s | Partition/sharding | Consumer lag > [X]s |

### 9.3. Availability & Disaster Recovery

| Metric | Target | Ghi chú |
|--------|--------|---------|
| Uptime SLA | [99.5]% (~44h downtime/năm) | Không tính maintenance window |
| Maintenance Window | [Chủ nhật 2:00-6:00 AM] | Thông báo trước 48h |
| RTO (Recovery Time Objective) | [4] giờ | Thời gian tối đa để khôi phục |
| RPO (Recovery Point Objective) | [1] giờ | Dữ liệu mất tối đa 1 giờ |
| Backup frequency | Database: [daily], Files: [daily] | Retention: [30] ngày |
| Backup verification | [Monthly] restore test | Log kết quả test |

### 9.4. Data Retention

| Loại dữ liệu | Thời gian giữ | Sau khi hết hạn | Quy định |
|---------------|---------------|-----------------|----------|
| Business data (active) | Vĩnh viễn (soft delete) | — | — |
| Soft-deleted records | [90] ngày | Hard delete hoặc archive | Company policy |
| Audit logs | [2] năm | Archive to cold storage | [Compliance requirement] |
| Application logs | [30] ngày | Auto-delete | — |
| User sessions | [7] ngày | Auto-expire | — |
| Temp files / uploads | [24] giờ | Auto-cleanup job | — |
