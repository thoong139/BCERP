# Playbook: Review Compliance Implementation

> **Type**: Agent Skill Playbook
> **Agent**: compliance-expert
> **Triggered by**: Post-implementation review hoặc /wf-verify-sync khi có compliance modules
> **Output**: Compliance Implementation Review Report

---

## Khi nào dùng playbook này

- Sau khi implement compliance features (audit trail, access control, data protection)
- Khi code-reviewer cần compliance perspective bổ sung góc nhìn security thuần túy
- Khi chuẩn bị cho external audit — verify implementation trước khi auditor đến
- Khi có regulatory change và cần assess impact lên implementation hiện tại

---

## Procedure

### Bước 1: Đọc compliance requirements gốc

```
INPUT: Paths do skill cung cấp qua prompt — trỏ tới implementation task file
FALLBACK: tra .mc-data/docs/phase1-business/compliance-requirements.md
          tra .mc-data/docs/phase5-implementation/ → task files cho compliance modules

Cần xác định:
□ REQ-IDs nào liên quan đến compliance trong implementation?
□ Regulatory basis của từng requirement (GDPR / SOC 2 / PCI-DSS / HIPAA)?
□ Acceptance criteria cụ thể đã được define?
□ Non-functional requirements (retention, performance, immutability)?
```

### Bước 2: Review audit trail completeness & immutability

```
WHY: Audit trail là xương sống của compliance — nếu sai ở đây, mọi thứ khác vô nghĩa.

Checklist — Completeness:
□ Tất cả sensitive operations có audit event không?
  → Authentication: login, logout, MFA challenges, failures
  → Authorization: permission_denied, role_changes
  → Data CRUD: create, update, delete cho sensitive entities
  → Bulk operations: bulk_update, bulk_delete, exports
  → Config changes: role assignments, settings, integrations
  → Compliance-specific: assessment submissions, exception requests

□ Mỗi event có đủ 5W + Result?
  → WHO: user_id, role, ip_address, session_id — KHÔNG log username (PII)
  → WHAT: action_type, resource_type, resource_id (không phải tên/value nhạy cảm)
  → WHEN: timestamp UTC millisecond precision — KHÔNG local timezone
  → WHERE: service_name, endpoint — trace back được origin
  → RESULT: success/failure, error_code nếu failure

□ PII trong audit logs có được xử lý đúng không?
  → Email, phone, CCCD, credit card KHÔNG được log in plaintext
  → Nếu cần log PII → hash (SHA-256) hoặc tokenize
  → before_value / after_value cho sensitive fields: chỉ log hash hoặc masked value
  → Test: grep codebase tìm log statements chứa email/phone/card patterns

Checklist — Immutability:
□ Audit log store có UPDATE/DELETE endpoint không? → KHÔNG được có
□ Database role của audit service có gì? → Chỉ INSERT được phép
□ Ai có thể xóa log records? → Answer phải là "không ai"
□ Cryptographic chain: có hash chaining không? Có verification job không?
□ External sink: có stream sang SIEM hoặc external storage không?
□ Integrity check job có chạy định kỳ không? Có alert khi fail không?

Red flags cần escalate:
❌ Admin có thể DELETE từ audit_logs table → Critical finding
❌ Log entries không có timestamp → Missing evidence
❌ Logs overwritten sau 30 ngày (log rotation xóa luôn) → Retention violation
❌ PII in plaintext trong logs → Potential GDPR violation
```

### Bước 3: Review access control segregation

```
READ: .claude/references/team-expert/compliance/controls.md → Segregation of Duties (SoD)

Segregation of Duties check:
□ Financial workflows: Người tạo payment ≠ Người approve payment ≠ Người reconcile
□ Compliance workflows: Control owner ≠ Control assessor (nếu cùng người → self-assessment, không valid)
□ Remediation: Finding owner ≠ Validator (người close finding phải khác người được assign)
□ User management: Người tạo user ≠ Người approve access
□ Privileged operations: DB admin access có dual approval không?

RBAC Implementation check:
□ Roles được define theo business function, không theo individual
□ Least privilege: mỗi role chỉ có permissions cần thiết cho job function
□ Permission creep: user có quyền cũ từ role trước không bị xóa khi chuyển role
□ Privileged roles (admin, CISO, super_user): có special logging không?
□ Service accounts: có human-like permissions không? (red flag)
□ Dormant accounts: user không login > 90 ngày có bị deactivated không?

Access review mechanism:
□ Quarterly access certification có implement không?
□ Manager/owner phải attest danh sách user của team họ?
□ Attestation record được kept (evidence cho auditors)?
□ Revocation workflow khi attestation fail?
```

### Bước 4: Review data encryption standards

```
Encryption at Rest:
□ Database: Transparent Data Encryption (TDE) hoặc field-level encryption?
□ PII columns: có column-level encryption không? Key management như thế nào?
□ Backup files: encrypted không?
□ Log files: encrypted tại rest không?
□ Key management: keys stored separately từ encrypted data? HSM / KMS?
□ Key rotation: có policy và implementation không? Frequency?

Encryption in Transit:
□ TLS version: minimum TLS 1.2, khuyến nghị TLS 1.3
□ Weak cipher suites: loại bỏ RC4, 3DES, MD5, SHA-1
□ HSTS: có enforce không? max-age tối thiểu 1 năm?
□ Certificate management: có auto-renewal không? Expiry monitoring?
□ Internal services: có TLS giữa microservices không? (mTLS ideal)
□ Database connections: encrypted không? Certificate validation?

Hashing:
□ Passwords: bcrypt / Argon2 / scrypt — KHÔNG MD5, SHA-1, SHA-256 plain
□ Sensitive lookups (email, phone): HMAC-SHA256 với secret key — cho phép lookup không expose plaintext
□ Audit log hashing: SHA-256 per event

Red flags:
❌ Passwords stored in plaintext hoặc MD5 → Critical
❌ HTTP (không phải HTTPS) cho production → Critical
❌ Self-signed certificates trong production → High
❌ Keys hardcoded trong source code → Critical (lộ lên Git)
❌ Encryption keys cùng storage với encrypted data → High
```

### Bước 5: Review PII handling (mask/tokenize)

```
READ: .claude/references/team-expert/compliance/regulations.md → Data Protection section

Data Minimization:
□ Chỉ collect PII thực sự cần thiết cho business purpose (không phải "might need someday")
□ Fields không còn cần → có data deletion/anonymization?

Display (UI layer):
□ Credit card: hiển thị **** **** **** 1234 (last 4 only)
□ Email: hiển thị j***@example.com
□ Phone: hiển thị +84 *** *** 123
□ CCCD/Passport: hiển thị *** *** 123
□ Account number: hiển thị ****1234

API responses:
□ PII fields có bị trả về khi client không cần không? (over-exposure)
□ List endpoints: có trả về PII không cần thiết không?
□ Error messages: có leak PII không? (VD: "User with email abc@xyz.com not found")

Logging:
□ Request/response logging: có filter PII fields không?
□ Error tracking (Sentry, Datadog): có scrub PII trước khi send không?
□ Analytics events: có include PII không?

Data Subject Rights (GDPR Art 15-20, Decree 13/2023):
□ Right to Access: user có thể download dữ liệu của họ không?
□ Right to Erasure: có xóa được không? Kể cả trong backups?
□ Right to Rectification: user có thể sửa thông tin không?
□ Data portability: export ở format machine-readable (JSON/CSV)?
□ Workflow: request → verify identity → fulfill trong 30 ngày → audit log

Consent Management:
□ Consent record: purpose, timestamp, version of privacy policy, channel
□ Withdrawal: user có thể withdraw consent không? Tác động là gì?
□ Consent không được bundled với ToS nếu processing là không bắt buộc
```

### Bước 6: Review retention enforcement

```
Retention Policy:
□ Data retention policy được define (số ngày, per data type)?
□ Enforcement: có automated job xóa / anonymize sau retention period không?
□ Legal hold: có mechanism giữ data khi có litigation hold không?
□ Backup retention: backup files có bị delete sau retention period không?

Deletion verification:
□ Delete là hard delete hay soft delete? (soft delete có thể không đủ cho GDPR)
□ Cascading delete: xóa user → xóa linked PII data không?
□ Backup purge: deleted data có bị xóa khỏi backups không? (GDPR yêu cầu)
□ Deletion audit trail: "what was deleted" kept, nhưng không phải content

Log retention:
□ Audit logs: minimum 1 năm online, 7 năm archive (xem regulations.md)
□ Log rotation policy: rotate nhưng KHÔNG xóa — move sang cold storage
□ Archive accessibility: archive logs có thể search được không khi auditor yêu cầu?
```

### Bước 7: Review incident response readiness

```
WHY: GDPR yêu cầu notify Data Protection Authority trong 72h khi có breach.
     Nếu không có IR plan sẵn → 72h là không đủ.

Incident Detection:
□ Có monitoring alert cho anomalous access patterns không?
□ Failed login rate threshold trigger alert không?
□ Bulk data export alert có không?
□ Data exfiltration detection (query result size > threshold)?

Incident Classification:
□ Có severity classification framework không?
□ Breach vs Security Incident vs Service Disruption được phân biệt không?
□ PII involved → automatically escalate to DPO?

Notification Workflow:
□ GDPR 72h notification: có template và workflow không?
□ Internal notification chain: Security → CISO → Legal → DPO → Board
□ Customer notification: có template? Khi nào send?
□ Regulatory notification: biết cần notify cơ quan nào không?

Incident Evidence:
□ Incident record: timeline, actions taken, data affected, individuals affected
□ Forensic evidence preservation: có procedure không?
□ Post-mortem template và process có không?

Red flag:
❌ Không có breach detection mechanism → không biết bị breach
❌ Không có notification workflow → vi phạm GDPR 72h rule
❌ Incident response là "informal" — chỉ trong đầu 1 người
```

### Bước 8: Output — Compliance Review Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase5-implementation/compliance-review-[module]-[date].md

Cấu trúc:

# Compliance Implementation Review: [Module/Feature Name]

**Review Date**: [date]
**Reviewed by**: compliance-expert
**Scope**: [Modules / REQ-IDs được review]
**Regulatory Basis**: [GDPR / SOC 2 / PCI-DSS / etc.]

## Executive Summary
[2-3 dòng: Overall compliance readiness, critical findings count, recommendation]

## Overall Status
- Audit Trail: PASS / PARTIAL / FAIL
- Access Control & SoD: PASS / PARTIAL / FAIL
- Encryption (at rest + in transit): PASS / PARTIAL / FAIL
- PII Handling: PASS / PARTIAL / FAIL
- Retention Enforcement: PASS / PARTIAL / FAIL
- Incident Response Readiness: PASS / PARTIAL / FAIL

## Findings

### Critical Findings (block go-live)
| ID | Area | Finding | Regulatory Basis | Recommendation |
|----|------|---------|-----------------|----------------|
| CF-001 | Audit Trail | Admin có thể DELETE audit_logs | PCI-DSS Req 10.5 | Remove DELETE privilege từ app DB role |

### High Priority Findings
[Same format]

### Medium Priority Findings
[Same format]

### Low Priority / Observations
[Same format]

## Requirements Compliance Matrix
| REQ-ID | Requirement | Status | Evidence | Gaps |
|--------|------------|--------|----------|------|
| REQ-COMP-AUDIT-001 | Audit event capture | Partial | Seen in codebase | Missing bulk_export events |

## Positive Observations
[Những gì đã implement tốt — không chỉ nêu vấn đề]

## Recommended Actions
1. [Critical — before go-live]: [Action] — Owner: [role] — Effort: [S/M/L]
2. [High — within 30 days]: ...
3. [Medium — within 90 days]: ...

## Sign-off Condition
Go-live approval condition: Tất cả Critical findings phải resolved.
High findings cần remediation plan với deadline trước khi approve.
```

---

## Checklist trước khi submit

```
□ Audit trail completeness: tất cả event types đã covered chưa?
□ Immutability: có path nào xóa/sửa log không?
□ PII trong logs: không có plaintext PII
□ SoD: financial + compliance workflows có tách biệt roles không?
□ RBAC: least privilege, không có permission creep
□ Encryption: at rest + in transit đủ standards
□ PII masking: UI, API responses, logs đều handle đúng
□ Data subject rights: implemented và auditable
□ Retention: automated enforcement, không chỉ policy trên giấy
□ Incident response: detection + notification workflow có
□ Findings được classify đúng severity
□ Positive observations được ghi nhận (không chỉ tiêu cực)
□ Recommended actions có owner và effort estimate
```
