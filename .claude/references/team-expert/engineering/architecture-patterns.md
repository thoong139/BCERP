# Architecture Patterns - Hướng dẫn Quyết định Kiến trúc

> **Domain**: Engineering / Architecture
> **Last Updated**: 2026-03-15
> **Nguồn**: Industry best practices — Martin Fowler, Sam Newman, AWS Well-Architected Framework

---

## 1. Architecture Style Selection Matrix

Chọn kiến trúc dựa trên các tiêu chí dưới đây:

| Tiêu chí | Modular Monolith | Microservices | Serverless | Event-Driven |
|----------|-----------------|---------------|------------|--------------|
| Team size | 1–15 người | 15+ người (nhiều team) | Nhỏ, ít ops | Bất kỳ |
| Deploy frequency | Weekly–Monthly | Daily–Hourly | On-demand | Continuous |
| Scalability needs | Moderate | High, per-service | Auto, per-function | High throughput |
| Operational complexity | Thấp | Cao | Thấp (infra) | Trung bình |
| Latency requirement | Thấp (in-process) | Trung bình (network) | Cao (cold start) | Async-friendly |
| Data consistency | Strong (ACID) | Eventual consistency | Eventual | Eventual |
| Phù hợp khi | Startup, MVP, domain chưa rõ | Domain rõ, nhiều team độc lập | Workload spike, background jobs | Audit trail, decoupling |

### Decision Flowchart

```
Bắt đầu
    │
    ├─ Team < 10 người hoặc MVP?
    │       └─ YES → Modular Monolith
    │
    ├─ Cần scale từng component độc lập + nhiều team?
    │       └─ YES → Microservices
    │
    ├─ Workload sporadic, event-triggered, no persistent state?
    │       └─ YES → Serverless
    │
    └─ Cần decouple producers/consumers, audit log, replay?
            └─ YES → Event-Driven Architecture
```

---

## 2. C4 Model Quick Reference

Dùng C4 để document kiến trúc theo 4 mức độ chi tiết:

```
Level 1: CONTEXT (System Context Diagram)
    └── Ai dùng hệ thống? Hệ thống nào bên ngoài kết nối?
    └── Audience: Business stakeholders, non-technical

Level 2: CONTAINER (Container Diagram)
    └── Các deployable units: Web App, API, Database, Mobile App
    └── Audience: Developers, architects

Level 3: COMPONENT (Component Diagram)
    └── Các module/package bên trong một container
    └── Audience: Developers của container đó

Level 4: CODE (Class/Sequence Diagram)
    └── Chỉ vẽ khi thực sự cần giải thích logic phức tạp
    └── Audience: Developer implement trực tiếp
```

**Nguyên tắc:** Không phải lúc nào cũng cần Level 4. Level 1–2 là tối thiểu cho mọi dự án.

---

## 3. Common Architecture Patterns

### 3a. CQRS + Event Sourcing

**Dùng khi:** Cần audit log hoàn chỉnh, replay events, read/write scale khác nhau.

```
Write Side                     Read Side
─────────────────────          ──────────────────────
Command → Aggregate            Event → Projector → Read Model
            │                                          │
            └── Event Store ──────────────────────────┘
                (append-only)
```

**Trade-offs:**
- Eventual consistency giữa write và read model (delay thường < 100ms)
- Tăng độ phức tạp: cần event versioning, schema evolution strategy
- Storage tăng do lưu toàn bộ event history

### 3b. Saga Pattern

**Dùng khi:** Cần distributed transaction qua nhiều services.

| Loại | Cách hoạt động | Phù hợp |
|------|---------------|---------|
| Orchestration | Một Saga Orchestrator gọi từng service theo thứ tự | Luồng phức tạp, cần rollback rõ ràng |
| Choreography | Mỗi service lắng nghe event và tự quyết định bước tiếp | Luồng đơn giản, ít service |

```
Orchestration Saga — Đặt hàng:
Orchestrator → PaymentService (charge)
            → InventoryService (reserve stock)
            → ShippingService (create shipment)
            → [Nếu lỗi] → Compensating transactions ngược lại
```

### 3c. API Gateway Pattern

**Dùng khi:** Nhiều client (web, mobile, 3rd party) cần truy cập nhiều backend services.

```
Client
  │
  ▼
API Gateway
  ├── Auth / Rate Limiting / SSL Termination
  ├── Request Routing
  ├── Response Aggregation
  └── Protocol Translation (REST → gRPC)
        │
        ├── Service A
        ├── Service B
        └── Service C
```

### 3d. BFF (Backend for Frontend)

**Dùng khi:** Web và Mobile có data requirements khác nhau đáng kể.

```
Web App    Mobile App    3rd-party
    │           │            │
    ▼           ▼            ▼
Web BFF    Mobile BFF    Public API
    │           │            │
    └───────────┴────────────┘
                │
          Core Services
```

**Lý do chọn BFF:** Tránh over-fetching trên mobile; tránh nhiều roundtrips trên web; mỗi BFF do team frontend tương ứng own.

### 3e. Strangler Fig (Migration Pattern)

**Dùng khi:** Cần migrate từ monolith sang microservices dần dần.

```
Phase 1: Proxy trước monolith
Client → Proxy → [Legacy Monolith]

Phase 2: Tách dần từng module
Client → Proxy → [New Service A]
              → [New Service B]
              → [Legacy Monolith] (phần còn lại)

Phase 3: Monolith rỗng, decommission
Client → Proxy → [New Service A]
              → [New Service B]
              → [New Service C]
```

---

## 4. Architecture Decision Record (ADR) Template

Lưu mỗi quyết định kiến trúc quan trọng trong `.mc-data/docs/phase3-architecture/adr/`.

```markdown
# ADR-[NNN]: [Tiêu đề quyết định]

**Ngày:** YYYY-MM-DD
**Trạng thái:** Proposed | Accepted | Deprecated | Superseded by ADR-XXX
**Người quyết định:** [Names]

## Bối cảnh
[Vấn đề cần giải quyết, constraints hiện tại]

## Các lựa chọn đã xem xét
1. Option A — [Mô tả ngắn]
2. Option B — [Mô tả ngắn]

## Quyết định
Chọn Option A vì [lý do cụ thể, dữ liệu hỗ trợ].

## Hệ quả
- Tích cực: [...]
- Tiêu cực: [...]
- Technical debt: [Nếu có, khi nào sẽ giải quyết]
```

---

## 5. Quality Attributes Checklist

Kiểm tra trước khi chốt thiết kế kiến trúc:

| Attribute | Câu hỏi kiểm tra | Metric mục tiêu |
|-----------|-----------------|----------------|
| Performance | Latency P95 có đạt yêu cầu? | < 200ms API, < 1.5s page load |
| Scalability | Scale theo chiều ngang được không? | Horizontal scaling, stateless |
| Availability | SLA bao nhiêu? Có single point of failure? | 99.9% = 8.7h downtime/năm |
| Security | Auth, authz, encryption đầy đủ? | Zero-trust, least privilege |
| Maintainability | Team có thể onboard trong vài ngày? | Cyclomatic complexity < 10 |
| Observability | Có metrics, logs, traces không? | MTTD < 5 phút |
| Testability | Unit test, integration test dễ viết? | Coverage > 80% |
| Cost | Chi phí infra có trong ngân sách? | Estimate trước khi commit |

---

## 6. Anti-patterns Cần Tránh

| Anti-pattern | Dấu hiệu nhận biết | Hậu quả | Cách phòng tránh |
|-------------|-------------------|---------|-----------------|
| Distributed Monolith | Services deploy cùng nhau, gọi sync chằng chịt | Worse than monolith | Loose coupling, async events |
| Shared Database | Nhiều services đọc/ghi cùng DB schema | Schema change phá vỡ mọi thứ | Mỗi service own DB của mình |
| Chatty Services | Hàng chục synchronous calls cho 1 operation | Latency tích lũy, cascade failures | Aggregate data, use BFF hoặc GraphQL |
| Mega-Service | Service làm quá nhiều thứ | Monolith trá hình | Single responsibility principle |
| Premature Optimization | Dùng microservices ngay từ đầu khi chưa cần | Over-engineering, chậm phát triển | Bắt đầu bằng modular monolith |

---

## 7. Observability Stack Reference

Ba trụ cột của observability:

```
METRICS (What is happening?)
    └── Prometheus + Grafana
    └── CloudWatch / Datadog
    └── Dùng cho: alerts, dashboards, SLA tracking

LOGS (Why did it happen?)
    └── ELK Stack (Elasticsearch + Logstash + Kibana)
    └── Loki + Grafana
    └── Dùng cho: debugging, audit trail, error analysis

TRACES (Where is it happening?)
    └── Jaeger / Zipkin / AWS X-Ray
    └── OpenTelemetry (vendor-neutral standard)
    └── Dùng cho: latency profiling, bottleneck detection
```

**Nguyên tắc:** Implement logs trước, metrics sau, traces khi cần tối ưu performance cụ thể.
