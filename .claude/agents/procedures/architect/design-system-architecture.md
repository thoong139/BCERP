# Playbook: Thiết kế Kiến trúc Hệ thống

> **Type**: Agent Skill Playbook
> **Agent**: architect
> **Triggered by**: /wf-design — Phase 3 khi cần thiết kế kiến trúc hệ thống tổng thể
> **Output**: `.mc-data/docs/phase3-architecture/system-architecture.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design` ở bước thiết kế kiến trúc tổng thể
- Khi bắt đầu một hệ thống mới và cần xác định style kiến trúc
- Khi có yêu cầu scalability, multi-tenancy, hoặc distributed systems
- Khi cần vẽ C4 diagrams và ghi lại ADRs cho stakeholders

---

## Procedure

### Bước 1: Đọc context đầu vào

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2 (feature specs), PHASE1 (business requirements)

Cần xác định:
□ Danh sách hệ thống/modules trong req-registry.json
□ Non-functional requirements (performance targets, SLA, concurrent users)
□ Business constraints (team size, budget, timeline, existing infrastructure)
□ Interface type (Web, Mobile, API-only, Hybrid)
□ Multi-tenancy requirements (single-tenant / multi-tenant / hybrid)
□ Compliance/regulatory constraints (GDPR, HIPAA, PCI-DSS, SOC2)
□ Integration points với hệ thống bên ngoài

READ: .claude/references/team-expert/engineering/architecture-patterns.md (Section 1 — Selection Matrix)
```

### Bước 2: Phân tích Non-functional Requirements (NFRs)

```
Định lượng hóa từng NFR trước khi ra quyết định:

PERFORMANCE:
□ Expected concurrent users (peak): ___
□ API latency target P95: ___ ms
□ Page load target: ___ s
□ Throughput: ___ req/s

SCALABILITY:
□ Data growth rate: ___ GB/tháng
□ User growth dự kiến 12 tháng: ___
□ Peak-to-average traffic ratio: ___

AVAILABILITY:
□ SLA target: ___% (99.9% = 8.7h downtime/năm)
□ RPO (Recovery Point Objective): ___
□ RTO (Recovery Time Objective): ___

SECURITY:
□ Authentication method (SSO / JWT / OAuth2)
□ Data classification level (Public / Internal / Confidential / Restricted)
□ Encryption requirements at rest / in transit

→ Tổng hợp NFR Profile: ghi vào section "Non-functional Requirements" trong output
```

### Bước 3: Chọn Architectural Style với Trade-offs

**Assumption Gate — DỪNG và hỏi nếu: (BHV-001)**
- NFRs chưa định lượng (VD: "nhanh" nhưng không có số liệu latency cụ thể)
- Team size/budget/constraints chưa rõ — ảnh hưởng trực tiếp architectural choice
- Multi-tenancy requirement ambiguous (single-tenant / multi-tenant / hybrid)
- Compliance requirements chưa confirm (GDPR, HIPAA, PCI-DSS, SOC2)

```
READ: .claude/references/team-expert/engineering/architecture-patterns.md (Section 1 — Decision Flowchart)

Áp dụng Decision Flowchart:

IF team < 10 người hoặc domain chưa rõ ràng:
    → Modular Monolith
    → Ghi ADR: "Chọn Modular Monolith vì [lý do cụ thể]"

ELSE IF cần scale từng component độc lập + nhiều team:
    → Microservices
    → Xác định service boundaries theo Domain-Driven Design
    → Ghi ADR: "Chọn Microservices vì [lý do cụ thể]"

ELSE IF workload sporadic, event-triggered:
    → Serverless / Event-Driven Hybrid
    → Ghi ADR

LUÔN trình bày ít nhất 2 phương án với bảng so sánh:

| Tiêu chí | Option A | Option B |
|---------|---------|---------|
| Deploy complexity | ... | ... |
| Scalability | ... | ... |
| Team overhead | ... | ... |
| Time to market | ... | ... |

→ Nêu rõ WHY chọn option được chọn, không chỉ WHAT
```

### Bước 4: Xác định Platform Foundations

```
Trước khi thiết kế các module cụ thể, chốt nền tảng chung:

AUTH & IDENTITY:
□ SSO Provider (Keycloak / Auth0 / AWS Cognito / Custom)
□ Token standard (JWT với RS256)
□ Authorization model (RBAC / ABAC / ReBAC)
□ MFA requirements

API LAYER:
□ API Gateway (Kong / AWS API GW / Nginx / Envoy)
□ BFF pattern cần không? (nếu có cả Web + Mobile + 3rd party)
□ Rate limiting strategy (Token Bucket khuyến nghị)

SHARED SERVICES (xác định cái nào cần ngay, cái nào defer):
□ Notification Service (Email, Push, SMS)
□ File Storage (S3-compatible)
□ Audit Logging
□ Search (Elasticsearch / OpenSearch)
□ Job Queue (Redis/BullMQ hoặc RabbitMQ)

CROSS-CUTTING CONCERNS:
□ Caching layer (Redis — L1 in-process, L2 Redis)
□ Distributed tracing (OpenTelemetry)
□ Centralized logging (ELK / Loki)
□ Error handling standards

→ Ghi ADR cho mỗi technology choice quan trọng
→ Playbook chi tiết: design-platform-foundations.md
```

### Bước 5: Service Boundaries & Data Isolation

```
Áp dụng Domain-Driven Design để phân tách boundaries:

Với mỗi hệ thống/module trong req-registry.json:
□ Xác định Bounded Context
□ Xác định Aggregate Root
□ Xác định mối quan hệ (Shared Kernel / Customer-Supplier / Anti-Corruption Layer)

DATA ISOLATION STRATEGY:
- Shared Database: Phù hợp Modular Monolith — 1 DB, schema riêng per module
- Database per Service: Phù hợp Microservices — isolation hoàn toàn
- Hybrid: Core shared DB + Analytics riêng + Cache layer

DISTRIBUTED TRANSACTION (nếu cần):
□ Saga pattern (Orchestration vs Choreography)
□ Xác định compensating transactions cho mỗi step

READ: .claude/references/team-expert/engineering/architecture-patterns.md (Section 3b — Saga)

→ Ghi data isolation decision vào ADR
```

### Bước 6: Vẽ C4 Diagrams

```
READ: .claude/references/team-expert/engineering/architecture-patterns.md (Section 2 — C4 Model)

MANDATORY — Level 1: System Context Diagram
  Mô tả: Ai dùng hệ thống? Hệ thống nào bên ngoài kết nối?
  Format: Dùng PlantUML hoặc Mermaid
  Audience: Business stakeholders

  Ví dụ Mermaid:
  ```
  graph TB
    User[Người dùng] -->|HTTPS| System[Hệ thống XYZ]
    System -->|REST API| Payment[Payment Gateway]
    System -->|SMTP| Email[Email Service]
    Admin[Admin] -->|HTTPS| System
  ```

MANDATORY — Level 2: Container Diagram
  Mô tả: Web App, API Server, Database, Message Queue, Cache
  Audience: Developers, architects

  Ví dụ Mermaid:
  ```
  graph LR
    WebApp[Web App\nReact/Next.js] -->|HTTPS/REST| API[API Server\nNode.js]
    MobileApp[Mobile App\nReact Native] -->|HTTPS/REST| API
    API -->|SQL| DB[(PostgreSQL)]
    API -->|Cache| Redis[(Redis)]
    API -->|Events| Queue[Message Queue\nRabbitMQ]
  ```

OPTIONAL — Level 3: Component Diagram
  Chỉ vẽ khi module phức tạp và team cần hiểu internal structure

→ Nhúng diagrams vào document output
```

### Bước 7: Failure Mode Analysis

```
Với mỗi external dependency và critical path:

Template phân tích:

| Component | Failure Mode | Impact | Probability | Mitigation |
|-----------|-------------|--------|-------------|------------|
| Payment Gateway | Timeout / 5xx | Không thể thanh toán | MEDIUM | Circuit Breaker + Retry + Fallback queue |
| Database Primary | Crash | Data unavailable | LOW | Read replicas + Automatic failover |
| Auth Service | Down | All users locked out | LOW | JWT validation local cache (30s TTL) |
| Message Queue | Down | Events lost | LOW | Persistent queue + Dead Letter Queue |
| 3rd party API | Rate limit | Feature degraded | MEDIUM | Exponential backoff + Cached response |

Resiliency patterns áp dụng:
□ Circuit Breaker (Hystrix / Resilience4j / custom)
□ Retry với exponential backoff + jitter
□ Bulkhead (tách thread pool cho external calls)
□ Fallback (degrade gracefully, không throw error)
□ Health check endpoints

READ: .claude/references/team-expert/engineering/architecture-patterns.md (Section 5 — Quality Attributes)
```

### Bước 8: Ghi ADRs

**Success Criteria:**
□ Mỗi quyết định quan trọng có ADR riêng (≥1 ADR cho architectural style, database, auth, caching)
□ Mỗi ADR có đủ: Bối cảnh + Các lựa chọn + Quyết định + Hệ quả
□ ADR status đã set (Proposed/Accepted/Deprecated)

```
READ: .claude/references/team-expert/engineering/architecture-patterns.md (Section 4 — ADR Template)

Tạo ADR cho MỌI quyết định kiến trúc quan trọng:
□ ADR-001: Lựa chọn architectural style (Monolith vs Microservices)
□ ADR-002: Database technology (PostgreSQL vs MongoDB vs ...)
□ ADR-003: Caching strategy (Redis vs Memcached vs ...)
□ ADR-004: Message broker (RabbitMQ vs Kafka vs ...)
□ ADR-005: Auth provider (Keycloak vs Auth0 vs ...)
□ [Thêm ADR cho mỗi quyết định quan trọng khác]

Format ADR:
---
# ADR-[NNN]: [Tiêu đề quyết định]

**Ngày:** YYYY-MM-DD
**Trạng thái:** Proposed | Accepted | Deprecated
**Người quyết định:** [Names]

## Bối cảnh
[Vấn đề cần giải quyết]

## Các lựa chọn đã xem xét
1. Option A — [Mô tả ngắn]
2. Option B — [Mô tả ngắn]

## Quyết định
Chọn [Option] vì [lý do cụ thể, số liệu hỗ trợ]

## Hệ quả
- Tích cực: [...]
- Tiêu cực: [...]
- Technical debt: [Nếu có]
---

Lưu ADRs tại: .mc-data/docs/phase3-architecture/adr/ADR-[NNN]-[slug].md
```

### Bước 9: Viết Output

```
Ghi vào: .mc-data/docs/phase3-architecture/system-architecture.md

Cấu trúc output:

# Kiến trúc Hệ thống — [Tên dự án]

## 1. Executive Summary
[3-5 dòng: style kiến trúc được chọn, lý do chính, key constraints]

## 2. Non-functional Requirements
[Bảng định lượng NFRs từ Bước 2]

## 3. Architectural Decision
[Style được chọn + bảng so sánh 2 options + lý do]

## 4. System Context Diagram (C4 Level 1)
[Mermaid diagram]

## 5. Container Diagram (C4 Level 2)
[Mermaid diagram]

## 6. Platform Foundations
[Auth, Gateway, Shared Services, Cross-cutting concerns — summary]

## 7. Service Boundaries
[Bảng: Service / Bounded Context / Data Store / Owner team]

## 8. Failure Mode Analysis
[Bảng từ Bước 7]

## 9. Technology Stack
[Bảng: Layer / Technology / Version / Lý do chọn]

## 10. Architecture Decision Records (ADRs)
[Link đến từng ADR file hoặc nhúng inline nếu ngắn]

## 11. Open Items & Risks
[Các quyết định còn defer, risks cần theo dõi]
```

---

## Checklist trước khi submit

```
□ Tất cả systems trong req-registry.json đều được cover
□ Ít nhất 2 architectural options đã được so sánh
□ ADR tồn tại cho mỗi quyết định technology quan trọng
□ C4 Level 1 và Level 2 đã được vẽ
□ Failure mode analysis đã cover mọi external dependencies
□ NFRs được định lượng (số liệu cụ thể, không mơ hồ)
□ Technical debt ghi rõ trong ADR "Hệ quả"
□ Platform foundations chốt trước module details
□ Không thiết kế module nào không có trong req-registry.json
```
