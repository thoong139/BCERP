# Playbook: Review Kiến trúc

> **Type**: Agent Skill Playbook
> **Agent**: architect
> **Triggered by**: Post-design review hoặc post-implementation architecture check
> **Output**: Architecture review report tại `.mc-data/docs/phase3-architecture/architecture-review-[YYYYMMDD].md`

---

## Khi nào dùng playbook này

- Sau khi thiết kế Phase 3 hoàn tất — pre-implementation review
- Khi có thay đổi lớn trong requirements làm ảnh hưởng đến kiến trúc
- Sau sprint implementation — kiểm tra code có align với architecture không
- Khi có performance issues hoặc scalability concerns xuất hiện trong production
- Periodic architecture review (quarterly)

---

## Procedure

### Bước 1: Đọc context đầu vào

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (architecture docs), PHASE2 (features)

Cần thu thập:
□ .mc-data/docs/phase3-architecture/system-architecture.md
□ .mc-data/docs/phase3-architecture/platform-foundations.md
□ .mc-data/docs/phase3-architecture/api-contracts.md
□ .mc-data/docs/phase3-architecture/database-schema.md
□ .mc-data/docs/phase3-architecture/adr/*.md (tất cả ADRs)
□ .mc-data/docs/_meta/req-registry.json (requirements coverage check)
□ Code structure (nếu là post-implementation review): scan qua Glob + Grep

READ: .claude/references/team-expert/engineering/architecture-patterns.md
READ: .claude/references/team-expert/engineering/security-checklist.md
```

### Bước 2: Requirements Coverage Check

```
Mục tiêu: Mọi requirement trong registry đều có thiết kế kiến trúc tương ứng.

a) Đọc req-registry.json → lấy danh sách tất cả REQ-IDs và features

b) Với mỗi REQ-ID:
   □ Có system/module trong architecture tương ứng không?
   □ Có endpoint trong api-contracts.md cover use case không?
   □ Có table/schema trong database-schema.md lưu data cần thiết không?
   □ Nếu cần integration bên ngoài — có documented trong architecture không?

c) Flag:
   🔴 CRITICAL: REQ-ID không có coverage → missing design
   🟡 WARNING: REQ-ID có coverage mờ nhạt → cần clarify
   🟢 OK: Coverage đầy đủ

d) Ghi vào report:
   | REQ-ID | Description | Coverage Status | Gap |
   |--------|-------------|----------------|-----|
   | REQ-AUTH-001 | User login | OK | — |
   | REQ-RPT-005 | Real-time dashboard | WARNING | Stream processing chưa designed |
```

### Bước 3: ADR Completeness Check

```
Mục tiêu: Mọi quyết định kiến trúc quan trọng phải có ADR.

Checklist ADRs bắt buộc:
□ ADR cho architectural style selection (Monolith vs Microservices)
□ ADR cho database technology (mỗi loại DB được dùng)
□ ADR cho caching technology
□ ADR cho message broker (nếu có)
□ ADR cho auth/identity provider
□ ADR cho API style (REST/GraphQL/gRPC)
□ ADR cho cloud provider / deployment platform
□ ADR cho multi-tenancy model (nếu SaaS)

Với mỗi ADR, kiểm tra:
□ Có "Bối cảnh" rõ ràng (vấn đề là gì)?
□ Có ít nhất 2 options được so sánh?
□ Có lý do chọn option được chọn (không chỉ "chúng tôi thích X")?
□ Có liệt kê hệ quả tiêu cực / trade-offs?
□ Có ghi technical debt nếu có?
□ Status field được cập nhật?

Flag:
🔴 MISSING: Quyết định quan trọng không có ADR
🟡 INCOMPLETE: ADR thiếu sections hoặc thiếu options comparison
🟢 OK: ADR đầy đủ
```

### Bước 4: Single Points of Failure (SPOF) Analysis

```
Mục tiêu: Xác định component nào nếu fail sẽ làm toàn hệ thống down.

Scan kiến trúc cho các SPOF patterns:

DATABASE:
□ Chỉ 1 DB instance không có replica → SPOF
□ Không có read replicas → SPOF cho read-heavy workloads
□ Shared DB giữa nhiều services → blast radius lớn khi schema change
→ Mitigation: Primary + Read Replica + Automatic failover

CACHE:
□ Redis single instance → SPOF cho session-dependent flows
→ Mitigation: Redis Sentinel hoặc Redis Cluster

AUTH SERVICE:
□ Không có fallback nếu IdP down
→ Mitigation: Short-lived JWT cho offline validation, local validation cache

MESSAGE QUEUE:
□ Single broker không có replication
→ Mitigation: RabbitMQ Mirrored Queue hoặc Kafka với replication factor >= 3

API GATEWAY:
□ Single gateway instance
→ Mitigation: Multiple instances behind load balancer

EXTERNAL DEPENDENCIES:
□ Payment gateway, SMS provider, Email service không có fallback
→ Mitigation: Circuit Breaker + fallback queue + alternative provider

Format report:
| Component | SPOF Risk | Impact | Current Mitigation | Recommendation |
|-----------|----------|--------|-------------------|----------------|
| PostgreSQL | HIGH | Full system down | Không có | Add read replica + failover |
| Redis | MEDIUM | Auth flows slow | Không có | Redis Sentinel |
| Payment GW | MEDIUM | No new payments | Không có | Circuit Breaker + retry queue |
```

### Bước 5: Security Architecture Checklist

```
READ: .claude/references/team-expert/engineering/security-checklist.md

a) Authentication & Authorization:
□ Auth check tại API Gateway level (không chỉ application level)?
□ JWT validated: exp, iss, aud mỗi request?
□ No sensitive data trong JWT payload?
□ Refresh token rotation được implement?
□ MFA bắt buộc cho admin roles?
□ Authorization deny-by-default?
□ Ownership checks (user chỉ xem data của mình)?

b) Data Security:
□ PII được encrypt at rest?
□ TLS 1.2+ cho tất cả in-transit?
□ Database credentials không hardcode?
□ Audit log cover mọi state-changing operations?
□ GDPR compliance: right to erasure có mechanism không?

c) API Security:
□ Rate limiting trên auth endpoints?
□ CORS configured đúng (không dùng * với credentials)?
□ Input validation cho mọi endpoint?
□ No stack traces trong error responses?
□ SQL parameterized queries (không string concatenation)?

d) Infrastructure Security:
□ Secrets trong Vault / Secrets Manager (không trong code)?
□ Least privilege cho service accounts và DB users?
□ Network segmentation (DB không exposed ra internet)?
□ Security headers được set?
□ Dependency scanning trong CI/CD pipeline?

e) STRIDE Threat Model:
READ: .claude/references/team-expert/engineering/security-checklist.md (Section 10)

Với mỗi threat category, xác định:
□ Spoofing: Auth mechanism đủ mạnh?
□ Tampering: Input validation, HMAC cho webhooks?
□ Repudiation: Audit trail đầy đủ?
□ Information Disclosure: Data masking, encryption đúng?
□ Denial of Service: Rate limiting, circuit breaker?
□ Elevation of Privilege: RBAC, least privilege?

Format:
| Threat | Component at Risk | Current Control | Gap | Severity |
|--------|-----------------|----------------|-----|---------|
| Spoofing | Login endpoint | Password + JWT | Không có MFA | HIGH |
```

### Bước 6: Scalability Bottleneck Analysis

```
Mục tiêu: Xác định component nào sẽ fail đầu tiên khi traffic tăng 10x.

READ: .claude/references/team-expert/engineering/architecture-patterns.md (Section 5 — Quality Attributes)

a) Database scaling:
□ Có N+1 query patterns không? (cần index hoặc eager loading)
□ Missing indexes cho WHERE clauses thường dùng?
□ Large table scans không có pagination?
□ Connection pool sizing phù hợp?
□ Có cơ chế archive / partition data lớn?

b) Application layer scaling:
□ Stateless services (có thể scale horizontal)?
□ Có shared mutable state không được thread-safe?
□ Synchronous calls chaining nhiều services?
□ Missing caching cho expensive computations?

c) API scalability:
□ Endpoints không có rate limiting?
□ Large payload không có streaming/pagination?
□ Webhooks không có queue buffer (có thể overwhelm receiver)?

d) Infrastructure:
□ Auto-scaling configured?
□ CDN cho static assets?
□ Read replicas cho read-heavy queries?

Format:
| Component | Current Capacity | Bottleneck Risk | Priority | Recommendation |
|-----------|----------------|----------------|---------|----------------|
| User DB | ~10K req/s est | MEDIUM | P2 | Add read replica |
| Search endpoint | No index | HIGH | P1 | Add composite index |
| Report generation | Synchronous | HIGH | P1 | Move to async job |
```

### Bước 7: Operational Complexity Assessment

```
Mục tiêu: Đảm bảo team có thể maintain và debug hệ thống.

a) Observability readiness:
□ Distributed tracing được implement?
□ Structured logs (JSON) với trace_id?
□ Business metrics có dashboards?
□ Alert rules được configure?
□ On-call runbooks cho common failures?
□ MTTD target < 5 phút khả thi với monitoring hiện tại?

b) Deployment complexity:
□ Deployment process documented?
□ Rollback procedure rõ ràng và tested?
□ Zero-downtime deployment được support?
□ Environment parity (staging mirrors production)?
□ Database migrations có thể run safely?

c) Operational documentation:
□ Runbook cho mỗi service?
□ Dependency diagram updated?
□ SLA/SLO được documented?
□ Escalation path cho incidents?

d) Team knowledge:
□ Mọi thành viên team hiểu kiến trúc tổng thể?
□ Knowledge được documented (không bị bus factor)?
□ Onboarding guide có cập nhật?
```

### Bước 8: Cost Estimation

```
Mục tiêu: Estimate chi phí infrastructure để stakeholders có informed decision.

a) Compute costs:
□ Số lượng servers/containers cần?
□ CPU/Memory requirements mỗi service?
□ Reserved instances vs on-demand?

b) Storage costs:
□ Database storage estimate (data growth rate × 2 năm)?
□ Object storage (file uploads, backups)?
□ Log retention storage?
□ CDN bandwidth?

c) Service costs:
□ Managed services fees (Auth0, Datadog, etc.)?
□ 3rd party API costs (SMS, Email, Payment)?
□ Support tier costs?

d) Format estimate:
| Resource | Monthly Cost | Annual Cost | Notes |
|---------|-------------|------------|-------|
| Compute (2 app servers) | $200 | $2,400 | t3.medium × 2 |
| Database (RDS Multi-AZ) | $150 | $1,800 | db.t3.medium |
| Redis | $50 | $600 | cache.t3.micro |
| Total | $400 | $4,800 | |

→ Flag nếu cost estimate vượt budget assumption trong requirements
```

### Bước 9: Dependency Risk Assessment

```
Mục tiêu: Xác định vendor lock-in và EOL risks.

a) Vendor lock-in analysis:
□ Cloud provider-specific services nào được dùng? (AWS Lambda, Azure Functions, GCP BigQuery)
□ Chi phí migrate sang provider khác?
□ Có thể abstract với adapter pattern không?
□ Ghi vào ADR: nhận thức về lock-in, risk acceptance

b) Technology EOL check:
□ Mỗi dependency: version đang dùng, latest stable, EOL date
□ Node.js, Python, Java runtime versions
□ Database versions (PostgreSQL, MongoDB)
□ Framework versions (Express, Django, Spring Boot)

c) Third-party risk:
□ Payment Gateway: có SLA contractual? Có alternative provider?
□ Email service: có fallback nếu provider down?
□ Maps/Geolocation: cost model, SLA?
□ SMS provider: coverage của thị trường target?

d) Open-source risk:
□ Core libraries có actively maintained?
□ License compatibility với commercial use?
□ Single maintainer projects trong critical path?

Format:
| Dependency | Type | Lock-in Risk | EOL Risk | Mitigation |
|-----------|------|-------------|---------|------------|
| AWS S3 | Cloud storage | MEDIUM | None | Use S3-compatible interface |
| Auth0 | Managed IAM | HIGH | None | Abstract auth layer |
| Stripe | Payment | HIGH | None | Accept risk, document migration plan |
```

### Bước 10: Viết Review Report

```
Ghi vào: .mc-data/docs/phase3-architecture/architecture-review-[YYYYMMDD].md

Cấu trúc output:

# Architecture Review Report — [Tên dự án]

**Ngày review:** [YYYY-MM-DD]
**Reviewer:** architect agent
**Review scope:** [Phase 3 design review / Post-implementation check / Quarterly review]
**Review type:** [Pre-implementation / Post-implementation / Periodic]

## Executive Summary

| Mức độ | Số lượng | Tóm tắt |
|--------|---------|---------|
| 🔴 Critical | N | [Tóm tắt critical findings] |
| 🟡 Warning | N | [Tóm tắt warnings] |
| 🟢 OK | N | [Areas đang tốt] |

**Recommendation:** [GO / GO with conditions / NO-GO — với lý do rõ ràng]

## 1. Requirements Coverage
[Kết quả từ Bước 2 — bảng coverage]

## 2. ADR Completeness
[Kết quả từ Bước 3 — missing/incomplete ADRs]

## 3. Single Points of Failure
[Kết quả từ Bước 4 — SPOF analysis]

## 4. Security Architecture
[Kết quả từ Bước 5 — security checklist + STRIDE]

## 5. Scalability Assessment
[Kết quả từ Bước 6 — bottlenecks]

## 6. Operational Complexity
[Kết quả từ Bước 7 — ops assessment]

## 7. Cost Estimate
[Kết quả từ Bước 8 — cost table]

## 8. Dependency & Vendor Risk
[Kết quả từ Bước 9 — risk table]

## 9. Action Items

| Priority | Finding | Recommendation | Owner | Deadline |
|---------|---------|----------------|-------|---------|
| P0 | Auth không có MFA | Thêm TOTP cho admin | Security team | Sprint 2 |
| P1 | Missing index orders.status | Thêm composite index | DBA | Sprint 1 |
| P2 | Redis single instance | Thêm Redis Sentinel | DevOps | Sprint 3 |

## 10. Sign-off Conditions
[Nếu recommendation là "GO with conditions": liệt kê conditions phải met trước khi proceed]
```

---

## Checklist trước khi submit

```
□ Tất cả REQ-IDs trong registry đã được check coverage
□ SPOF analysis cover tất cả external dependencies
□ Security checklist đã completed — STRIDE threat model có
□ Action items có Priority (P0/P1/P2), Owner, Deadline
□ Cost estimate đã include để stakeholders có informed decision
□ Vendor lock-in risks đã acknowledged trong ADRs
□ Executive summary đủ rõ để non-technical stakeholders hiểu
□ Recommendation (GO/NO-GO) rõ ràng với lý do
□ Sign-off conditions cụ thể nếu "GO with conditions"
```
