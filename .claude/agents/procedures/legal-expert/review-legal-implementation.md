# Playbook: Review Legal Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: legal-expert
> **Triggered by**: /wf-implement-feature khi review code của legal/compliance module
> **Output**: Legal implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của legal module
- Khi cần validate implementation từ legal domain perspective
- Khi cần check compliance: e-signature, data privacy, audit trail, access control
- Trước go-live của bất kỳ module nào xử lý contracts hoặc dữ liệu pháp lý

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type:
□ Contract Management → check lifecycle states, approval workflow, version control
□ Compliance Tracking → check control library, evidence management, deadlines
□ Policy Management → check version control, acknowledgment, distribution
□ E-Signature → check audit trail, provider integration, authentication
□ Document Repository → check access control, encryption, retention policy
□ Audit Trail Module → check event completeness, immutability, retention

Nếu module là Contract Management → ưu tiên Bước 3a
Nếu module là Compliance Tracking → ưu tiên Bước 3b
```

### Bước 2: Load controls knowledge

```
READ: controls.md → Luôn làm, bất kể module nào

Compliance checklist bắt buộc cho mọi legal module:
□ Access control: Có RBAC đúng không? (Role-based theo personas.md)
□ Audit trail: Mọi document action đều được log không?
□ Encryption: Dữ liệu nhạy cảm được encrypt at rest không?
□ Soft delete: Contracts không bị hard delete (retention policy)
□ Version immutability: Version đã lock không thể modify
□ Data retention: Có enforce retention period không? (contracts: 10 năm)
```

### Bước 3a: Review Contract Management Implementation

```
CONTRACT LIFECYCLE:
□ State machine đúng không?
  → DRAFT → INTERNAL_REVIEW → APPROVED_FOR_SEND → NEGOTIATION →
     FINAL_REVIEW → APPROVAL_PENDING → EXECUTION → ACTIVE →
     EXPIRING_SOON → EXPIRED / RENEWED / TERMINATED
□ Có chặn invalid state transitions không? (ví dụ: DRAFT → EXECUTION trực tiếp)
□ State history được log không? (ai thay đổi state, khi nào, lý do)

AUTHORIZATION MATRIX:
□ Contract value được validate khi set không? (không cho save âm, không cho vượt budget)
□ Approval routing: Routing đúng theo value threshold và contract type?
□ Có bypass approval không? (phải không được có)
□ Timeout escalation: Có implement auto-escalate khi approver không respond?
□ Parallel vs Sequential approval: Đúng theo thiết kế?

VERSION CONTROL:
□ Mỗi save/update có tạo version mới không?
□ Version immutability: Có prevent edit version cũ không?
□ "Final" và "Signed" version có watermark không?
□ File hash (SHA-256) có được store để verify integrity không?
□ Signed contract có bị locked (read-only) không?

OBLIGATION TRACKING:
□ Obligations được create tự động từ contract terms không?
□ Alert schedule: [90, 60, 30, 7] ngày trước deadline có fire không?
□ Alert recipients đúng không? (owner + Legal Manager cho urgent)
□ Overdue obligations có escalate lên Legal Manager không?
```

### Bước 3b: Review Compliance Tracking Implementation

```
CONTROL LIBRARY:
□ Control CRUD có require owner assignment không? (không được có orphan controls)
□ Testing frequency: Có calculate next_test_date tự động không?
□ Assessment status: Có update control effectiveness tự động sau assessment không?
□ Framework mapping: N-to-N relationship giữa controls và requirements đúng không?

EVIDENCE MANAGEMENT:
□ Evidence immutability: Evidence submitted không được sửa/xóa không?
□ Evidence expiry: Có alert khi evidence sắp expire không?
□ File integrity: Hash check khi retrieve evidence không?
□ Auditor access: Có read-only portal cho external auditor không?

COMPLIANCE CALENDAR:
□ Recurring deadlines: Có auto-generate kỳ tiếp theo khi complete không?
□ Alert automation: Đúng schedule [90, 60, 30, 14, 7, 1] ngày không?
□ ICS export: Có generate calendar feed không?
□ Overdue handling: Có auto-notify Legal Manager khi deadline bị miss không?

RISK REGISTER:
□ Residual score calculation: likelihood × impact đúng không?
□ Control linkage: Khi control effectiveness thay đổi → risk re-scored không?
□ Critical risk escalation: score ≥ 17 → CEO/Board notification không?
□ Risk review cycle: Có auto-remind owner khi đến review_date không?
```

### Bước 4: Review E-Signature Implementation

```
READ: controls.md → Section 5 (E-Signature Controls)

PROVIDER INTEGRATION:
□ Webhook/callback đang xử lý events nào? (SENT, VIEWED, SIGNED, DECLINED)
□ Webhook có signature verification không? (prevent webhook spoofing)
□ Retry logic: Nếu webhook fail → có retry với backoff không?
□ Idempotency: Duplicate webhook events có được handle không?

AUTHENTICATION LEVELS:
□ NDA → Email OTP đúng không? (không dùng weak auth cho documents nhạy cảm hơn)
□ Vendor/Customer → 2FA đúng không?
□ Board resolutions → Digital certificate configured không?
□ Authentication level có thể bị bypass bởi user không? (phải không được)

AUDIT TRAIL COMPLETENESS:
□ Capture: Sent timestamp + IP ✓ Viewed timestamp + IP ✓
   Signed timestamp + IP + certificate ✓ Downloaded timestamp + IP ✓
□ Tất cả events đang được stored không?
□ Retention: 10 năm cho e-sign audit trail?

EXTERNAL PARTY SIGNING:
□ External signer không cần account trong hệ thống không?
□ Signing link có expiry không? (không nên vô thời hạn)
□ Signing link có one-time use không? (không share được)
□ Có notify khi signing link expire chưa ký không?
```

### Bước 5: Review Access Control và Security

```
READ: controls.md → Section 3 (Document Security Controls)

RBAC IMPLEMENTATION:
□ Roles đúng theo personas: Legal Counsel, Legal Manager, Compliance Officer,
  Contract Admin, Company Secretary, Business User?
□ Permission matrix đúng không?
  → Business user: chỉ xem contracts của dept mình
  → Legal Counsel: xem contracts được assigned
  → Legal Manager: xem tất cả
  → Compliance Officer: xem compliance docs + view contracts
□ Row-level security: Có enforce "chỉ xem của dept mình" ở DB level không?
  (không nên chỉ filter ở application layer)

ENCRYPTION:
□ Contracts (files): Encrypted at rest (AES-256) trong storage?
□ Database fields nhạy cảm: counterparty name, contract value có encrypted không?
□ Transmission: HTTPS everywhere? (không có plain HTTP endpoint)
□ Key management: Encryption keys lưu ở đâu? (không hardcode trong code)

DOCUMENT PROTECTION:
□ Signed contracts: Watermark được apply khi render/download?
□ Download control: Có log khi user download contract không?
□ External sharing: Có tạo shareable link với expiry không? (không email file trực tiếp)
□ Print tracking: Có log khi print không?

PII HANDLING:
□ Counterparty personal data trong contracts có được encrypted/masked không?
□ Logs không chứa PII (tên, số CMND, email) ở plain text?
□ Search index: Có index PII fields không? Nếu có → có secure không?
```

### Bước 6: Review Data Retention và Disposal

```
READ: controls.md → Section 6 (Retention & Disposal)

RETENTION ENFORCEMENT:
□ Hard delete bị blocked không? (phải soft delete)
□ Scheduled disposal: Có auto-archive/notify khi retention period sắp kết thúc?
□ Retention schedule đúng không?
  → Contracts: 10 năm sau expiry
  → Corporate records: vĩnh viễn
  → Compliance records: 7 năm
  → Employment records: 5 năm sau termination

DISPOSAL PROCESS:
□ Disposal cần approve (Legal Manager) trước khi thực hiện?
□ Disposal action được log (certificate of destruction)?
□ External counsel files: Có process riêng không?

DATA PRIVACY (GDPR/PDP):
□ Personal data trong contracts: Có thể pseudonymize sau khi hết retention?
□ Right to erasure: Nếu contract chứa PII của người yêu cầu xóa → xử lý thế nào?
  (Retention period pháp lý override right to erasure → cần document)
□ DSAR workflow: Có thể extract tất cả data liên quan đến 1 person không?
```

### Bước 7: Review Audit Trail Completeness

```
READ: controls.md → Section 7 (Audit Trail Requirements)

Mọi event sau đây phải được log (KHÔNG được thiếu bất kỳ event nào):
□ Contract create: user_id, template_id, counterparty, timestamp
□ Contract edit: user_id, version, fields_changed (diff), timestamp
□ Contract share: user_id, recipient, access_level, timestamp
□ Contract sign: signer_id, method (e-sign/wet), certificate, timestamp
□ Document access: user_id, document_id, action (view/download/print), timestamp
□ Policy update: user_id, change_summary, effective_date, timestamp
□ Compliance check: assessor_id, control_id, finding, resolution, timestamp

AUDIT LOG INTEGRITY:
□ Audit logs có immutable không? (không ai có thể delete/edit logs)
□ Logs stored ở separate system không? (không cùng DB với contracts)
□ Log tampering detection: hash chain hoặc WORM storage?
□ Retention: 5-10 năm theo event type (xem controls.md Section 7)
```

### Bước 8: Output — Review Report

```markdown
# Legal Implementation Review: [Module Name]

## Tổng quan
**Module**: [Tên module]
**Reviewer**: legal-expert
**Review Date**: [Date]
**Overall Status**: ✅ PASS / ❌ FAIL / ⚠ NEEDS ATTENTION

---

## Critical Issues (block go-live – phải fix trước khi deploy)
- [ ] **[Issue]**: [Mô tả vấn đề] → [File/Function location]
  **Required fix**: [Action cụ thể]
  **Risk if not fixed**: [Legal/compliance risk]

## Important Issues (fix trước sprint tiếp theo)
- [ ] **[Issue]**: [Mô tả] → [Location]
  **Recommendation**: [Action]

## Suggestions (nice-to-have, backlog)
- [ ] [Suggestion]

---

## Compliance Checklist

### Access Control
| Tiêu chí | Status | Notes |
|----------|:------:|-------|
| RBAC theo personas | ✅/❌/⚠ | |
| Row-level security tại DB | ✅/❌/⚠ | |
| External party access controlled | ✅/❌/⚠ | |

### Audit Trail
| Event | Captured | Immutable | Retention | Notes |
|-------|:--------:|:---------:|:---------:|-------|
| Contract create | ✅/❌ | ✅/❌ | OK/Issue | |
| Contract sign | ✅/❌ | ✅/❌ | OK/Issue | |
| Document access | ✅/❌ | ✅/❌ | OK/Issue | |

### Data Privacy & Encryption
| Tiêu chí | Status | Notes |
|----------|:------:|-------|
| Files encrypted at rest | ✅/❌/⚠ | |
| PII không exposed trong logs | ✅/❌/⚠ | |
| Retention policy enforced | ✅/❌/⚠ | |

### E-Signature (nếu applicable)
| Tiêu chí | Status | Notes |
|----------|:------:|-------|
| Webhook verification | ✅/❌/⚠ | |
| Authentication level per contract type | ✅/❌/⚠ | |
| Audit trail đầy đủ (sent/viewed/signed) | ✅/❌/⚠ | |

---

## Performance Concerns
[Các vấn đề performance nếu có]

---

## Sign-off

| Area | Status | Blocker |
|------|:------:|:-------:|
| Access control | OK / ISSUE | Có/Không |
| Audit trail completeness | OK / ISSUE | Có/Không |
| E-signature compliance | OK / ISSUE | Có/Không |
| Data privacy (GDPR/PDP) | OK / ISSUE | Có/Không |
| Retention policy | OK / ISSUE | Có/Không |
| Encryption at rest | OK / ISSUE | Có/Không |
| Business logic (state machine, authorization) | OK / ISSUE | Có/Không |

**Go-live recommendation**: ✅ APPROVED / ❌ BLOCKED (list blockers) / ⚠ CONDITIONAL
```

---

## Checklist trước khi submit review

```
□ Đã review access control theo RBAC model (personas.md)
□ Đã verify audit trail cover đủ 7 event types (controls.md Section 7)
□ Đã check encryption at rest cho files và PII fields
□ Đã verify data retention enforcement (soft delete, retention schedule)
□ Đã review e-signature audit trail nếu module có e-sign
□ Đã check state machine validity (no invalid transitions)
□ Đã verify authorization matrix đúng (no bypass)
□ Đã check PII không exposed trong logs/errors
□ Critical issues đều có recommended fix và risk statement
□ Sign-off table đầy đủ tất cả areas
□ Go-live recommendation rõ ràng (Approved / Blocked / Conditional)
```
