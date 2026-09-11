# Playbook: Chứng nhận sẵn sàng tích hợp

> **Type**: Agent Skill Playbook
> **Agent**: integration-certifier
> **Triggered by**: Pre-deployment — chứng nhận các integration points sẵn sàng production
> **Output**: Integration Certification Report tại phase6-deployment/ hoặc path do skill cung cấp

---

## Khi nào dùng playbook này

- Trước mỗi lần deployment lên production — bắt buộc
- Sau khi developer hoàn thành feature có integration với external systems
- Khi có thay đổi lớn ảnh hưởng đến API contracts, database schema, message queues
- Khi `reality-checker` hoặc `qa-lead` yêu cầu integration certification

---

## Procedure

### Bước 1: Đọc context và xác định integration points

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (architecture), PHASE6 (deployment)

READ: .claude/references/team-expert/testing/test-strategy-patterns.md

Cần xác định toàn bộ integration points của hệ thống:
□ REST/GraphQL/gRPC APIs — internal và external
□ Message queues / event buses (Kafka, RabbitMQ, SQS, Pub/Sub)
□ Webhooks — inbound và outbound
□ Databases — primary, replicas, read replicas
□ Cache layers (Redis, Memcached)
□ External service dependencies (payment, email, SMS, auth providers)
□ Data sync jobs / scheduled tasks / cron jobs
□ File storage (S3, GCS, local filesystem)

Với mỗi integration point, ghi nhận:
- Tên service/component
- Protocol và data format
- Owner team (internal/external)
- SLA đã cam kết
- REQ-ID liên quan
```

### Bước 2: Kiểm tra từng integration end-to-end

```
Với mỗi integration point đã xác định ở Bước 1, thực hiện theo trình tự:

[API integrations]
□ Health check endpoint có response đúng format không?
□ Authentication/authorization hoạt động đúng không? (Bearer token, API key, OAuth)
□ Request/response schema khớp với API contract không?
□ Rate limiting được implement và không bị vượt ngưỡng không?
□ Timeout được config hợp lý (không vô hạn) không?
□ Retry mechanism có exponential backoff không?

[Message queues]
□ Producer gửi được message với đúng format không?
□ Consumer nhận và xử lý được message không?
□ Dead letter queue (DLQ) được config và hoạt động không?
□ Message ordering đảm bảo khi cần không?
□ Consumer group offset được track đúng không?

[Webhooks]
□ Outbound webhook gửi được payload đến endpoint không?
□ Inbound webhook nhận và validate signature đúng không?
□ Retry khi webhook endpoint không available không?
□ Idempotency đảm bảo khi webhook deliver nhiều lần không?

[Database connections]
□ Connection pool size phù hợp với load dự kiến không?
□ Read replica routing hoạt động đúng không?
□ Migration đã chạy thành công chưa?
□ Index đã được áp dụng chưa?

[External services]
□ Credentials/API keys đang dùng đúng môi trường (không nhầm staging credentials vào prod)?
□ Rate limit của external service đủ cho traffic dự kiến không?
□ Fallback/circuit breaker được implement khi external service down không?
```

### Bước 3: Kiểm tra xử lý lỗi

```
Với mỗi integration point, simulate failure scenarios:

□ Timeout — system xử lý thế nào khi integration bị timeout?
□ Connection refused — có circuit breaker không? Fallback response là gì?
□ Invalid data format — có validation và error response rõ ràng không?
□ Authentication failure — có retry không? Có alert không?
□ Rate limit exceeded — có backoff không? Có logging không?
□ Partial failure — nếu 1 trong 5 external calls fail, system có rollback toàn bộ không?

Ghi nhận với mỗi failure case:
FAILURE TYPE | EXPECTED BEHAVIOR | ACTUAL BEHAVIOR | PASS/FAIL
```

### Bước 4: Kiểm tra tính nhất quán dữ liệu giữa các services

```
Chọn các critical data flows có cross-service data:

□ Tạo record ở Service A → Service B có nhận được event và sync đúng không?
□ Update record ở Service A → các service phụ thuộc có reflect đúng không?
□ Delete cascade — xóa ở service chính có propagate đúng không?
□ Transaction boundaries — nếu step 2/3 fail, step 1 có rollback không?
□ Eventual consistency — trong distributed systems, dữ liệu có converge trong thời gian SLA không?

Với mỗi data flow:
- Trace data từ source đến destination
- Verify data không bị mất, không bị duplicate, không bị corrupt
- Measure propagation latency (phải nằm trong SLA)
```

### Bước 5: Kiểm tra rollback và retry mechanisms

```
□ Có rollback plan được document không?
□ Rollback đã được test chưa? (không chỉ trên giấy)
□ Thời gian rollback ước tính là bao nhiêu?
□ Database rollback — migration down script đã test chưa?
□ Feature flags — có thể disable feature mà không cần redeploy không?
□ Retry idempotency — retry cùng operation nhiều lần có safe không?
□ Distributed saga rollback — các compensating transactions đã implement chưa?
```

### Bước 6: Kiểm tra monitoring và alerting

```
READ: .claude/references/team-expert/testing/load-testing-examples.md (SLA targets)

Với mỗi integration point, verify:
□ Metrics đang được collect (request count, latency, error rate)
□ Alert thresholds đã được set (error rate > 1%, latency > SLA)
□ Dashboard có thể quan sát health của từng integration không?
□ Logging đủ chi tiết để troubleshoot khi có incident không?
□ Distributed tracing được implement không? (trace ID propagated qua services)
□ On-call runbook cho integration failures đã được viết chưa?
```

### Bước 7: Final certification checklist và quyết định

```
Tổng hợp kết quả từ Bước 2-6:

CERTIFICATION CRITERIA:
- FAILED: Bất kỳ critical integration nào broken, data inconsistency nghiêm trọng,
           không có error handling cho failure cases chính
- NEEDS WORK (MẶC ĐỊNH): Có issues nhưng không critical, monitoring thiếu,
                          rollback chưa được test, rate limits chưa được verify
- READY: TẤT CẢ integration points pass, error handling verified,
         data consistency confirmed, monitoring active, rollback tested

⚠️ MẶC ĐỊNH LÀ "NEEDS WORK" — chỉ "READY" khi bằng chứng áp đảo từ TẤT CẢ bước trên.

Với mỗi NEEDS WORK item, ghi rõ:
- Integration point bị ảnh hưởng
- Issue cụ thể
- Action cần thực hiện
- Owner (team/agent)
- Deadline đề xuất
```

### Bước 8: Output Integration Certification Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/integration-certification-report.md

Cấu trúc output:
1. Certification Decision: FAILED / NEEDS WORK / READY (với timestamp)
2. Integration Points Summary (table: name | type | status | issues)
3. End-to-End Test Results (pass/fail với evidence)
4. Error Handling Assessment
5. Data Consistency Findings
6. Monitoring & Alerting Status
7. Rollback Readiness
8. Blocking Issues (phải fix trước deploy)
9. Non-blocking Issues (có thể fix sau deploy)
10. REQ-IDs đã verify compliance
```

---

## Checklist trước khi submit

```
□ Tất cả integration points đã được identify và test
□ Failure scenarios đã được simulate (không chỉ happy path)
□ Data consistency đã được verify cross-service
□ Monitoring và alerting đã được xác nhận active
□ Rollback mechanism đã được test (không chỉ document)
□ REQ-IDs được reference trong mọi compliance check
□ Certification decision có evidence cụ thể — không claim "READY" chung chung
□ Blocking vs non-blocking issues đã được phân loại rõ ràng
```
