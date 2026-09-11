# Playbook: Threat Modeling Hệ thống

> **Type**: Agent Skill Playbook
> **Agent**: security
> **Triggered by**: Phase 3 architecture design, major architecture change, new system integration
> **Output**: `.mc-data/docs/phase3-architecture/threat-model.md`

---

## Khi nào dùng playbook này

- Khi `/wf-design` hoàn thành thiết kế kiến trúc Phase 3
- Khi có thay đổi lớn về kiến trúc (thêm microservice, thay đổi auth model, tích hợp third-party)
- Trước khi triển khai hệ thống mới ra production
- Khi phát hiện security gap trong quá trình review

---

## Procedure

### Bước 1: Đọc context hệ thống

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3, PHASE2, PHASE1

Cần đọc:
□ Architecture design document (phase3-architecture/)
□ API design + data model (phase3-architecture/)
□ req-registry.json — xác định systems, modules, interface_type
□ Feature specs liên quan đến auth, data access (phase2-features/)

Sau khi đọc, xác định:
□ Loại hệ thống: Web app / Mobile API / Microservices / Event-driven / ML pipeline
□ Interface type: REST API / GraphQL / gRPC / WebSocket
□ Data sensitivity: có PII, payment data, health records không?
□ Deployment target: cloud (AWS/GCP/Azure) / on-premise / hybrid
□ External integrations: third-party APIs, payment gateways, SSO providers
```

### Bước 2: Load knowledge

```
READ: .claude/references/team-expert/engineering/security-checklist.md
  → Section 10: STRIDE Threat Model (format và ví dụ)
  → Section 2: Authentication Patterns (khi có auth components)
  → Section 3: Authorization Patterns (khi có RBAC/ABAC)
  → Section 13: Compliance Mapping (nếu cần compliance mapping)
```

### Bước 3: Xác định phạm vi và trust boundaries

```
Vẽ (mô tả text) Data Flow Diagram mức cao:

Actors (External Entities):
□ End users (browser, mobile app)
□ Admin users
□ Third-party services (payment gateway, email provider, SSO)
□ Other internal services / microservices

Processes (phần hệ thống xử lý data):
□ API Gateway / Load Balancer
□ Application servers (API, web server)
□ Background workers / queues
□ Authentication service
□ Business logic services

Data Stores:
□ Primary database (PostgreSQL, MySQL...)
□ Cache (Redis, Memcached)
□ Message queues (Kafka, RabbitMQ)
□ File storage (S3, GCS)
□ Secrets manager (Vault, AWS Secrets Manager)

Trust Boundaries (đường phân tách giữa các zones):
□ Internet ↔ DMZ / Edge layer
□ DMZ ↔ Internal application tier
□ Application tier ↔ Data tier
□ Internal ↔ Third-party services

Ghi lại mọi data flows đi qua trust boundaries — đây là attack surface chính.
```

### Bước 4: Xác định tài sản cần bảo vệ (Asset Identification)

```
Liệt kê assets theo nhóm:

Data Assets (dữ liệu):
□ PII: tên, email, số điện thoại, địa chỉ, CCCD/hộ chiếu
□ Financial: số thẻ, tài khoản ngân hàng, lịch sử giao dịch
□ Credentials: passwords, API keys, tokens, certificates
□ Business data: orders, contracts, pricing, IP
□ System data: logs, config, infrastructure credentials

Service Assets (dịch vụ):
□ Authentication service — nếu down → toàn bộ hệ thống ngừng
□ Payment processing — nếu compromise → financial loss trực tiếp
□ Core business APIs — nếu down → doanh thu bị ảnh hưởng

Với mỗi asset: ghi Asset Value (High/Medium/Low) và lý do
→ Asset có giá trị cao → threat trên asset đó cần Mitigation mạnh hơn
```

### Bước 5: Liệt kê Threats theo STRIDE

Áp dụng STRIDE cho từng component và data flow đã xác định ở Bước 3.

#### S — Spoofing (Giả mạo danh tính)

```
Câu hỏi: "Attacker có thể giả mạo là ai/cái gì?"

Với mỗi actor/service trong DFD:
□ User authentication: có thể bypass login không?
□ Service-to-service: có verify identity của caller không? (mTLS, API key)
□ JWT/Token: có thể forge token không? (alg confusion, weak secret)
□ Email/SMS OTP: có thể predict hoặc reuse OTP không?
□ IP spoofing: X-Forwarded-For có thể bị manipulate không?
□ DNS spoofing: external service calls có verify TLS cert không?

Technique mapping: T1078 (Valid Accounts), T1566 (Phishing), T1190 (Exploit Public App)
```

#### T — Tampering (Giả mạo dữ liệu)

```
Câu hỏi: "Attacker có thể sửa đổi data ở đâu?"

□ Data in transit: API calls có TLS không? Internal calls có mTLS không?
□ Data at rest: DB records có thể bị sửa trực tiếp không? (DB access control)
□ Message queue: messages có được sign không?
□ File uploads: file content có được validate sau upload không?
□ Configuration: có ai có thể sửa config files trên server không?
□ Logs: logs có được protected khỏi modification không? (WORM storage)
□ Request parameters: có thể sửa price, quantity trong order không? (mass assignment)

Technique mapping: T1565 (Data Manipulation), T1492 (Stored Data Manipulation)
```

#### R — Repudiation (Chối bỏ hành động)

```
Câu hỏi: "User có thể phủ nhận đã thực hiện action không?"

□ Audit trail: mọi sensitive action có được log với user ID + timestamp không?
□ Immutable logs: logs có thể bị xóa hoặc sửa bởi user/admin không?
□ Transaction logs: payment, order changes có đầy đủ audit trail không?
□ Digital signature: quan trọng với contracts, approvals?
□ Log integrity: log service có tamper-evident (append-only, hash chain) không?

Technique mapping: T1070 (Indicator Removal), T1562 (Impair Defenses)
```

#### I — Information Disclosure (Lộ thông tin)

```
Câu hỏi: "Thông tin nhạy cảm nào có thể bị lộ?"

□ Error messages: stack trace, DB schema, internal paths có xuất hiện không?
□ API responses: trả về nhiều hơn cần thiết? (over-fetching PII)
□ Logs: PII, tokens, passwords có bị log không?
□ Debug endpoints: /debug, /metrics, /__admin có exposed không?
□ URL parameters: sensitive data có trong URL không? (xuất hiện trong logs)
□ Cache poisoning: CDN/cache có trả về private data cho người khác không?
□ Side-channel: timing attacks trên password/token comparison?
□ Cloud storage: S3/GCS buckets có public read không?

Technique mapping: T1552 (Unsecured Credentials), T1530 (Data from Cloud Storage)
```

#### D — Denial of Service (Từ chối dịch vụ)

```
Câu hỏi: "Attacker có thể làm hệ thống ngừng hoạt động bằng cách nào?"

□ Rate limiting: auth endpoints, API endpoints có rate limit không?
□ Resource exhaustion: request body size limit? Upload size limit?
□ Long-running queries: có timeout cho DB queries, external HTTP calls?
□ ReDoS: regex patterns trong validation có catastrophic backtracking không?
□ GraphQL: depth limit, complexity limit?
□ Slowloris / connection exhaustion: web server có limits không?
□ Amplification: có endpoint nào trả về response lớn hơn nhiều request?

Technique mapping: T1499 (Endpoint Denial of Service), T1498 (Network Denial of Service)
```

#### E — Elevation of Privilege (Leo thang đặc quyền)

```
Câu hỏi: "Attacker có thể nâng quyền hạn của mình không?"

□ IDOR: /api/users/{id}/data — có kiểm tra id thuộc về current user không?
□ Broken function-level access: user gọi admin API được không?
□ Mass assignment: user có thể set isAdmin=true qua request body không?
□ JWT role manipulation: role trong token có được verify server-side không?
□ SQL injection → admin access?
□ Path traversal: /../../../etc/passwd qua file endpoints?
□ Deserialization → RCE?
□ Container escape: nếu dùng containers, có privilege escalation risk không?

Technique mapping: T1548 (Abuse Elevation Control), T1134 (Access Token Manipulation)
```

### Bước 6: Risk Scoring

Với mỗi threat đã identify:

```
Risk Score = Likelihood × Impact

Likelihood (khả năng xảy ra):
- High (3): Lỗ hổng phổ biến, tool tự động exploit được, no skill required
- Medium (2): Cần skill nhất định, điều kiện cụ thể
- Low (1): Cần deep knowledge, rare conditions

Impact (mức độ ảnh hưởng):
- High (3): Data breach toàn bộ, system down, financial loss lớn
- Medium (2): Một phần data bị ảnh hưởng, service degradation
- Low (1): Minor information leak, limited scope

Risk Score:
- 7-9: CRITICAL → Phải có mitigation trước khi deploy
- 4-6: HIGH    → Fix trước khi deploy
- 2-3: MEDIUM  → Fix trong sprint
- 1:   LOW     → Backlog, monitor

Ghi lại trong Risk Register:
| Threat ID | STRIDE | Component | Likelihood | Impact | Score | Priority |
```

### Bước 7: Mitigation Controls

Với mỗi threat, xác định controls cần có:

```
Loại controls:
- Preventive: ngăn threat xảy ra (ví dụ: MFA, input validation)
- Detective: phát hiện khi threat xảy ra (ví dụ: anomaly detection, logging)
- Corrective: phục hồi sau khi threat xảy ra (ví dụ: incident response, backup)

Với mỗi threat:
□ Control đã có? (ký hiệu ✅)
□ Control thiếu → cần implement? (ký hiệu ⚠️ + viết Security Requirement mới)
□ Control partially implemented → cần strengthen? (ký hiệu 🔶)

Ví dụ mapping:
Threat: JWT alg confusion attack
→ Preventive: hardcode expected algorithm trong verify code (RS256 only)
→ Detective: log failed token verification attempts
→ Corrective: rotate keys, revoke affected sessions
```

### Bước 8: Residual Risk Assessment

```
Sau khi xác định mitigation controls:

□ Còn threats nào chưa có mitigation đầy đủ?
□ Residual risk có chấp nhận được không?
  - Critical residual risk → KHÔNG chấp nhận, phải address
  - High residual risk → cần approval từ stakeholder + ghi lý do accepted
  - Medium/Low residual risk → document + monitor

Format Accepted Risk:
| Threat ID | Residual Risk | Lý do Accept | Ngày review | Owner |
```

### Bước 9: Security Requirements Output

```
Từ kết quả threat modeling, tạo danh sách Security Requirements:

Format mỗi requirement:
REQ-SEC-[NNN]: [Tên requirement]
→ Mô tả: [Chi tiết implementation cần làm]
→ Priority: Critical/High/Medium
→ Threats addressed: [Threat IDs từ model này]
→ OWASP Mapping: [A01–A10]

Ví dụ:
REQ-SEC-001: Implement JWT algorithm pinning
→ Hardcode RS256 algorithm trong token verification middleware
→ Reject tokens với bất kỳ algorithm nào khác
→ Priority: Critical
→ Threats addressed: T-SPOOF-003
→ OWASP Mapping: A07 (Identification and Authentication Failures)
```

### Bước 10: Viết Threat Model Document

```
Ghi vào: .mc-data/docs/phase3-architecture/threat-model.md

Cấu trúc document:

1. Overview
   - System scope
   - Review date + reviewer
   - Methodology: STRIDE + Risk Scoring

2. System Context
   - DFD description (text-based)
   - Trust boundaries
   - Assets inventory

3. Threat Register
   - Bảng đầy đủ tất cả threats (STRIDE category, component, risk score, status)

4. Top Risks Summary
   - Top 5 critical/high risks với mô tả ngắn gọn

5. Security Requirements
   - Danh sách REQ-SEC-XXX cần implement

6. Residual Risk Register
   - Threats được accept với lý do

7. Next Review Date
   - Major architecture change → review lại
   - Không có change → review mỗi 6 tháng
```

---

## Output

```
Output chính: .mc-data/docs/phase3-architecture/threat-model.md

Nếu phát hiện Security Requirements mới:
→ Thông báo cho architect và developer để update req-registry.json
→ Ghi rõ REQ-ID format: REQ-SEC-[NNN]

Nếu có Critical threats chưa có mitigation:
→ Báo cáo rõ ràng: HỆ THỐNG CHƯA SẴN SÀNG DEPLOY
→ List cụ thể threats cần address trước
```

---

## Checklist trước khi submit

```
□ DFD đã identify đầy đủ actors, processes, data stores, trust boundaries
□ Đã apply STRIDE cho tất cả components và data flows qua trust boundaries
□ Mỗi threat có Risk Score (Likelihood × Impact)
□ Mỗi threat có ít nhất 1 mitigation control
□ Mỗi threat có MITRE ATT&CK technique mapping
□ Residual risks đã được document với lý do accept
□ Security Requirements mới được viết theo format REQ-SEC-XXX
□ Không có Critical residual risk chưa được address
□ Document có Next Review Date
```
