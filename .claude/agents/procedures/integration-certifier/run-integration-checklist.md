# Playbook: Kiểm tra sức khỏe tích hợp định kỳ

> **Type**: Agent Skill Playbook
> **Agent**: integration-certifier
> **Triggered by**: Kiểm tra sức khỏe tích hợp thường xuyên — hoặc trước deployment bất kỳ
> **Output**: Integration Health Check Report

---

## Khi nào dùng playbook này

- Kiểm tra định kỳ (hàng ngày/hàng tuần) trạng thái các integration
- Trước khi bắt đầu sprint mới có feature phụ thuộc external systems
- Khi có cảnh báo từ monitoring về integration degradation
- Khi `devops` hoặc `sre` báo cáo service health issues
- Khi muốn quick health snapshot — không cần full certification

Khác với `certify-integration-readiness.md` (deep-dive pre-deploy), playbook này là rapid health check — nhanh hơn, scope hẹp hơn, nhưng đủ để Go/No-Go quyết định.

---

## Procedure

### Bước 1: Đọc integration inventory

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3, PHASE6

Cần xác định danh sách integrations hiện có (từ phase3-architecture hoặc deployment docs):
□ Số lượng API endpoints — internal và external
□ Message queues đang active
□ External service dependencies (danh sách)
□ Database connections (primary + replicas)
□ Authentication systems (OAuth providers, SSO)

Nếu không có inventory sẵn → tạo nhanh từ codebase scan (Grep cho connection strings, API URLs)
```

### Bước 2: API health checks

```
Với mỗi API endpoint/service:

□ Health endpoint (/health, /ready, /ping) trả về 200 OK không?
□ Response time có nằm trong SLA không? (p95 < threshold đã cam kết)
□ Error rate trong 24h qua có < 1% không?
□ SSL certificate còn hạn ít nhất 30 ngày không?
□ API version contract không bị breaking change không?

Status cho mỗi API:
GREEN  = tất cả checks pass
YELLOW = 1-2 checks warning (không fail nhưng cần chú ý)
RED    = bất kỳ check nào fail

Phân loại API issues:
- Critical: ảnh hưởng đến user-facing functionality
- Warning: degraded performance hoặc tiếp cận threshold
- Info: minor inconsistency không ảnh hưởng ngay
```

### Bước 3: Database connection pool

```
□ Connection pool utilization < 80% không?
□ Không có long-running queries (> 30s) block pool không?
□ Replication lag < 5 giây không? (với read replicas)
□ Disk usage < 80% không? (bao gồm WAL/binlog space)
□ Backup đã chạy thành công trong 24h qua không?
□ No deadlock incidents trong 24h qua không?

Nếu connection pool > 90% → RED, phải escalate ngay
```

### Bước 4: External service dependencies

```
Với mỗi external service (payment, email, SMS, auth, etc.):

□ Service status page có incident active không?
   (Stripe, Twilio, SendGrid, Auth0 đều có public status pages)
□ Rate limit consumption: đã dùng bao nhiêu % quota trong 24h?
□ Average response time có tăng so với baseline không?
□ Circuit breaker status: CLOSED (bình thường) / OPEN (có vấn đề)?

Nếu external service có active incident → tự động flag toàn bộ dependent features
```

### Bước 5: Queue processing

```
Với mỗi message queue:

□ Consumer lag có tăng lên không? (backlog growing = processing too slow)
□ Dead letter queue (DLQ) có messages mới không? Nếu có → tại sao?
□ Consumer group healthy không? (không có rebalancing liên tục)
□ Message processing rate ổn định không?
□ Poison messages có được handle không? (không loop vô hạn)

Consumer lag thresholds:
< 100 messages = GREEN
100 - 1000 messages = YELLOW
> 1000 messages = RED
```

### Bước 6: Data sync jobs

```
Với mỗi scheduled job / cron job / ETL pipeline:

□ Job cuối cùng chạy có thành công không?
□ Thời gian chạy có trong khoảng bình thường không? (không bị hung)
□ Dữ liệu được sync có đúng số lượng/timestamp không?
□ Không có orphaned jobs (đang chạy quá lâu) không?
□ Retry failed jobs đã được config không?

Nếu critical sync job fail → KHÔNG deploy cho đến khi resolve
```

### Bước 7: Authentication systems

```
□ Auth provider (OAuth/OIDC/SAML) healthy không?
□ JWT/session token validation working không?
□ Token refresh mechanism hoạt động không?
□ SSO integration (nếu có) không bị broken không?
□ Service-to-service auth (mTLS, service account, JWT) working không?
□ Rate limiting trên auth endpoints active không? (brute-force protection)

Authentication failures = CRITICAL → không bao giờ deploy khi auth broken
```

### Bước 8: Go/No-Go decision

```
Tổng hợp results từ Bước 2-7:

GO điều kiện:
□ Tất cả critical systems GREEN
□ Không có active incidents trên external dependencies
□ Database healthy, backup recent
□ Queue consumer lag trong ngưỡng
□ Auth systems 100% operational

NO-GO nếu bất kỳ điều kiện nào:
□ Bất kỳ critical API nào RED
□ Database connection pool > 90%
□ External service có active incident ảnh hưởng core features
□ Queue consumer lag > 1000 messages và growing
□ Auth system có issues

⚠️ MẶC ĐỊNH NO-GO — chỉ GO khi tất cả critical systems GREEN.
```

### Bước 9: Output Integration Health Check Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/integration-health-check.md

Cấu trúc output (ngắn gọn, action-oriented):
1. Go/No-Go Decision (rõ ràng ở đầu report)
2. Health Dashboard (table: system | status | metric | threshold | actual)
3. RED items — phải fix ngay (với action owner)
4. YELLOW items — cần monitor (với timeline)
5. External dependencies status
6. Timestamp check thực hiện
```

---

## Checklist trước khi submit

```
□ Tất cả 7 categories đã được check (không skip bất kỳ)
□ Decision GO/NO-GO rõ ràng ở đầu report
□ RED items có action owner cụ thể
□ External service status được check từ official status pages (không tự đoán)
□ Database backup recency đã được xác nhận
□ Queue consumer lag đã được đo, không chỉ estimate
```
