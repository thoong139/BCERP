# Playbook: Design Contract Management Module

> **Type**: Agent Skill Playbook
> **Agent**: legal-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần thiết kế CLM module
> **Output**: Feature spec + Data model cho Contract Lifecycle Management

---

## Khi nào dùng playbook này

- Khi cần spec module "Contract Management" hoặc "Quản lý Hợp đồng"
- Khi cần thiết kế CLM (Contract Lifecycle Management) system
- Khi review/audit luồng hợp đồng hiện có và cần redesign

---

## Procedure

### Bước 1: Xác định scope CLM

```
Hỏi hoặc suy luận từ context (requirements + brainstorm docs):

□ Contract types cần support: NDA? MSA? SOW? Employment? Vendor? Customer?
□ Volume: Bao nhiêu contracts/tháng? (ảnh hưởng indexing + performance)
□ External counterparties: Chỉ nội bộ hay có external signing portal?
□ E-signature: Cần không? Provider nào? (DocuSign, Adobe Sign, local provider)
□ Template library: Có cần template management không?
□ Redlining/negotiation: Track changes trong system hay gửi Word ra ngoài?
□ Obligation tracking: Có cần theo dõi cam kết sau khi ký không?
□ Multi-currency: Hợp đồng ngoại tệ có cần không?
□ Multilingual: Có cần song ngữ (VN/EN) không?
```

### Bước 2: Thiết kế Contract Types và Template Library

```
READ: personas.md → Contract Types table
READ: controls.md → Section 1 (Authorization Matrix by Contract Type)

Standard contract types (gợi ý):

| Contract Type   | Risk Level | Template Required | Auto-expiry Alert |
|-----------------|:----------:|:-----------------:|:-----------------:|
| NDA             | Thấp       | ✅                | 1 năm            |
| MSA             | Trung bình | ✅                | Per term          |
| SOW/PO          | Trung bình | ✅                | Per project       |
| Employment      | Trung bình | ✅                | Probation end     |
| Vendor Agreement| Trung bình | ✅                | Annual            |
| Customer Contract| Cao       | ✅                | Per term          |
| Partnership     | Cao        | ✅                | Annual            |
| License         | Cao        | ✅                | Per term          |

Template fields cần thiết kế:
□ Template name + contract type + jurisdiction
□ Body text với placeholder variables ({{party_name}}, {{effective_date}}...)
□ Optional clauses (có thể bật/tắt theo từng trường hợp)
□ Annexes/Exhibits (có thể attach)
□ Version history của template
□ Approved by (Legal Manager review template)
□ Effective date của template version
```

### Bước 3: Thiết kế Contract Lifecycle States

```
READ: operations.md → Section 1 (Contract Lifecycle Management)
READ: controls.md → Section 2 (Workflow Stages)

State machine:

DRAFT → INTERNAL_REVIEW → APPROVED_FOR_SEND → NEGOTIATION →
FINAL_REVIEW → APPROVAL_PENDING → EXECUTION → ACTIVE →
EXPIRING_SOON → EXPIRED / RENEWED / TERMINATED

Chi tiết transitions:

DRAFT:
  → INTERNAL_REVIEW: Counsel submits cho Legal Manager review
  → (stay) DRAFT: Counsel save as draft

INTERNAL_REVIEW:
  → DRAFT: Reviewer yêu cầu chỉnh sửa + comments
  → APPROVED_FOR_SEND: Reviewer approve gửi cho counterparty

NEGOTIATION:
  → INTERNAL_REVIEW: Nhận redlines từ counterparty, review lại
  → FINAL_REVIEW: Hai bên đồng ý terms

APPROVAL_PENDING:
  → EXECUTION: Tất cả approvers theo authorization matrix đã ký duyệt
  → NEGOTIATION: Approver reject, cần negotiation lại

EXECUTION:
  → ACTIVE: Tất cả signatures obtained (e-sign hoặc wet ink confirmed)

ACTIVE:
  → EXPIRING_SOON: Alert khi còn N ngày (configurable: 30/60/90 ngày)
  → EXPIRED: Hết hạn không renew
  → RENEWED: Tạo contract mới với terms updated
  → TERMINATED: Chấm dứt trước hạn (cần termination notice)
```

### Bước 4: Thiết kế Approval Routing

```
READ: controls.md → Section 1 (Authorization Matrix)

Approval logic theo contract value:

| Giá trị Hợp đồng | Người review  | Người duyệt   | Người ký      |
|-------------------|:-------------:|:-------------:|:-------------:|
| ≤50M VND          | Legal Counsel | Dept Manager  | Dept Manager  |
| 50M-200M VND      | Legal Counsel | Legal Manager | Director      |
| 200M-1B VND       | Legal Counsel | Legal Manager | Director      |
| >1B VND           | Legal Manager | Legal Director| CEO/Board     |
| Strategic/High Risk| Legal Director| CEO          | Board          |

Parallel approval (cùng lúc):
□ Legal approval
□ Finance approval (nếu có payment terms hoặc value > threshold)
□ Department head approval

Sequential approval (tuần tự):
□ Counsel review → Manager approve → Signatory sign

Timeout rules:
□ Approver không phản hồi trong 48 giờ → escalate tới backup approver
□ Escalation sau 72 giờ → notify Legal Manager
```

### Bước 5: Thiết kế Redlining và Version Control

```
READ: controls.md → Version Control Rules

Version numbering:
□ Create initial draft: v1.0
□ Internal revision: v1.1, v1.2...
□ Sent to counterparty: v2.0
□ Counterparty returns with changes: v2.1
□ Counter-proposal: v2.2
□ Agreed final: version "Final"
□ Signed: Lock – không cho edit

Redlining features:
□ Import counterparty redlines (Word .docx với tracked changes)
□ Hiển thị changes với màu sắc: thêm (xanh), xóa (đỏ), comment (vàng)
□ Accept/Reject từng change
□ Side-by-side comparison với version trước
□ Audit trail: ai accept/reject change nào, khi nào

Storage:
□ Mỗi version là immutable snapshot
□ Chỉ version "Final" và "Signed" có watermark
□ Signed contract: encrypted + hash checksum cho integrity verification
```

### Bước 6: Thiết kế E-Signature Integration

```
READ: controls.md → Section 5 (E-Signature Controls)

E-signature requirements:
□ Provider: Chọn approved provider (DocuSign, Adobe Sign, VietSign...)
□ Authentication level per contract type:
   - NDA, employment: Email OTP
   - Vendor/Customer: 2FA (OTP + SMS)
   - Board resolutions: Digital certificate
□ Signing order: Sequential (legal → manager → signatory) hay Parallel
□ External party signing: Portal riêng, không cần account trong hệ thống
□ Wet ink fallback: Scan upload + manual confirmation khi e-sign không applicable

Audit trail e-signature phải capture:
□ Thời điểm gửi document (timestamp + IP)
□ Thời điểm mở document (timestamp + IP)
□ Thời điểm ký (timestamp + IP + device + certificate)
□ Thời điểm download (timestamp + IP)
□ Retention: 10 năm (theo Commercial Law)
```

### Bước 7: Thiết kế Obligation Tracking và Alerts

```
Obligation types cần track sau khi contract ACTIVE:
□ Payment milestones (Payment schedule)
□ Renewal deadline
□ Notice period (cần notice X ngày trước khi terminate)
□ Reporting obligations (gửi report định kỳ cho counterparty)
□ Performance milestones (Deliverables theo SOW)
□ Compliance certifications (Audit reports, certificates)

Alert schedule (configurable):
□ 90 ngày trước expiry: First alert
□ 60 ngày trước expiry: Second alert + Renewal initiation prompt
□ 30 ngày trước expiry: Urgent alert + escalate to Legal Manager
□ Notice period deadline: Critical alert
□ Payment due date: 7 ngày trước

Người nhận alert:
□ Contract Administrator (all alerts)
□ Legal Counsel phụ trách (all alerts)
□ Legal Manager (urgent + critical)
□ Business owner (expiry + payment)
```

### Bước 8: Thiết kế Data Model

```
Contract:
  - id (UUID), contract_number (auto-generated, unique)
  - contract_type (enum: NDA/MSA/SOW/Employment/Vendor/Customer/Partnership/License)
  - title, description
  - status (enum: DRAFT/INTERNAL_REVIEW/APPROVED_FOR_SEND/NEGOTIATION/...)
  - counterparty_name, counterparty_id (FK → Company nếu có)
  - effective_date, expiry_date, notice_period_days
  - value_amount, value_currency
  - jurisdiction (Vietnam/Multi-country/Global)
  - template_id (FK → ContractTemplate)
  - owner_id (FK → User – Legal Counsel phụ trách)
  - department_id (FK → Department – business owner)
  - risk_score (calculated: 5-15)
  - tags (JSON array)
  - metadata (JSON – flexible fields)
  - created_at, updated_at, deleted_at (soft delete)

ContractVersion:
  - id, contract_id (FK)
  - version_number (string: "1.0", "2.1", "Final")
  - file_url (S3/GCS path)
  - file_hash (SHA-256 integrity check)
  - change_summary (text)
  - sent_to_counterparty (boolean)
  - created_by (FK → User)
  - created_at

ContractApproval:
  - id, contract_id (FK)
  - approver_id (FK → User)
  - approval_type (enum: LEGAL/FINANCE/DEPARTMENT/SIGNATORY)
  - status (enum: PENDING/APPROVED/REJECTED/TIMEOUT)
  - comment (text – required khi REJECTED)
  - decided_at, deadline_at

ContractObligation:
  - id, contract_id (FK)
  - obligation_type (enum: PAYMENT/RENEWAL/NOTICE/REPORTING/DELIVERABLE/CERT)
  - description
  - due_date, recurrence (nullable)
  - owner_id (FK → User)
  - status (enum: PENDING/COMPLETED/OVERDUE)
  - alert_days_before (array: [90, 60, 30, 7])

ContractTemplate:
  - id, name, contract_type
  - body_html (template với {{placeholders}})
  - optional_clauses (JSON array)
  - jurisdiction
  - version, approved_by (FK → User)
  - is_active
  - effective_from, effective_until
```

### Bước 9: Feature Spec Output

```markdown
# Feature Spec: Contract Lifecycle Management (CLM)

## REQ-ID: REQ-LEGAL-CLM-[NNN]

## Overview
[Mô tả module – 3-5 dòng]

## User Stories
- Legal Counsel: Tôi muốn tạo hợp đồng từ template để giảm thời gian soạn thảo
- Contract Admin: Tôi muốn nhận alert 60 ngày trước khi hợp đồng hết hạn để kịp renew
- Legal Manager: Tôi muốn xem pipeline hợp đồng đang chờ duyệt để ưu tiên review

## Functional Requirements

### REQ-LEGAL-CLM-001: Contract Creation và Template Library
### REQ-LEGAL-CLM-002: Approval Workflow theo Authorization Matrix
### REQ-LEGAL-CLM-003: Version Control và Redlining
### REQ-LEGAL-CLM-004: E-Signature Integration
### REQ-LEGAL-CLM-005: Obligation Tracking và Alerts
### REQ-LEGAL-CLM-006: Contract Repository và Search
### REQ-LEGAL-CLM-007: Renewal Management
### REQ-LEGAL-CLM-008: Audit Trail (toàn bộ actions)
### REQ-LEGAL-CLM-009: Reporting Dashboard (pipeline, expiry, stats)

## Data Model
[Entity diagram hoặc field definitions từ Bước 8]

## API Endpoints (nếu cần)
[Danh sách endpoints chính]

## Non-functional Requirements
- Performance: Contract search < 1s với 100,000+ contracts
- Security: Signed contracts encrypted at rest (AES-256)
- Audit: Mọi document access được logged với retention 10 năm
- Availability: 99.9% uptime – legal deadlines không thể bị miss

## Integration Points
- HR system: Employment contracts
- CRM/Sales: Customer contracts
- Procurement: Vendor contracts
- Finance: Payment obligations, contract values
- E-signature provider: DocuSign/Adobe Sign API
- Document storage: S3/GCS với encryption
```

---

## Checklist trước khi submit

```
□ Contract types đã cover theo business need
□ Authorization matrix đã mapped (value-based + type-based)
□ Version control rules đã định nghĩa rõ
□ E-signature compliance đã xác định (provider + authentication level)
□ Obligation tracking đã cover (renewal, payment, notice period)
□ Alert schedule đã có (90/60/30 ngày trước expiry)
□ Data retention policy đã mapping (10 năm cho contracts)
□ Audit trail requirements đã đầy đủ (ai làm gì, khi nào)
□ Data model có đủ fields để support toàn bộ requirements
□ Integration touchpoints với HR, Finance, Sales, Procurement đã noted
□ Security: Encryption, access control, soft delete đã specified
```
