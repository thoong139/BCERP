# Playbook: Design Compliance Framework Module

> **Type**: Agent Skill Playbook
> **Agent**: compliance-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần spec module Compliance Management
> **Output**: Feature spec cho Compliance Framework module

---

## Khi nào dùng playbook này

- Khi cần thiết kế module "Compliance Management" / "Quản lý Tuân thủ"
- Khi cần spec control library, assessment scheduling, evidence collection, remediation tracking
- Khi review/audit design của compliance management system hiện có

---

## Procedure

### Bước 1: Xác định scope và target frameworks

```
Hỏi hoặc suy luận từ context (requirements phase1 docs):

□ Frameworks/certifications trong scope: SOC 2 / ISO 27001 / PCI-DSS / HIPAA / COSO / custom?
□ Số lượng controls ước tính: <50 / 50-200 / 200+?
□ Assessment frequency: Continuous / Quarterly / Annual?
□ Automated evidence collection: Cần không? Integrate với hệ thống nào?
□ External auditor access: Cần audit portal riêng không?
□ Multi-framework support: Cần map common controls across frameworks không?
□ Risk linkage: Controls có cần link với Risk Register không?
```

### Bước 2: Thiết kế Control Library

```
READ: .claude/references/team-expert/compliance/controls.md → Control Documentation Template

Control Library là trung tâm của compliance framework. Mỗi control cần:

Control Entity:
  - control_id: string (C-[DOMAIN]-[NNN], ví dụ C-ACC-001)
  - name: string (tên ngắn gọn, mô tả)
  - description: text (mô tả đầy đủ thủ tục)
  - control_type: enum [preventive, detective, corrective, directive]
  - automation_level: enum [manual, it_dependent, automated, semi_automated]
  - frequency: enum [continuous, daily, weekly, monthly, quarterly, annual, per_event]
  - owner_role: string (role chịu trách nhiệm, không hardcode tên người)
  - reviewer_role: string (role review kết quả)
  - framework_mappings: array of {framework, control_reference}
    → Ví dụ: [{framework: "SOC2", ref: "CC6.1"}, {framework: "ISO27001", ref: "A.9.2.1"}]
  - evidence_requirements: array of string (loại evidence cần thu thập)
  - risk_ids: array (link tới Risk Register)
  - status: enum [active, deprecated, under_review]
  - effective_date, review_date: date

Framework Mapping Table (multi-framework view):
  → Mỗi requirement của SOC 2 / ISO 27001 / PCI-DSS có thể map tới 1 hoặc nhiều controls
  → Common controls thỏa mãn nhiều frameworks cùng lúc → giảm redundancy
```

### Bước 3: Thiết kế Assessment Scheduling

```
Assessment là lịch test control theo tần suất quy định:

Assessment Plan:
  - assessment_id: string
  - control_id: foreign key
  - scheduled_date: date
  - due_date: date
  - assigned_to: user_id (control owner)
  - reviewer_id: user_id
  - status: enum [scheduled, in_progress, completed, overdue, waived]
  - period_covered: date range (evidence phải cover toàn bộ period)

Assessment Result:
  - assessment_id: foreign key
  - result: enum [effective, partially_effective, ineffective, not_tested]
  - sample_size: integer (xem controls.md → Sample Sizes)
  - exceptions_found: integer
  - findings: text (mô tả nếu có exception)
  - evidence_ids: array (link tới Evidence store)
  - completed_at: timestamp
  - reviewed_by: user_id
  - reviewed_at: timestamp

Scheduling Logic:
□ Auto-generate assessment schedule dựa trên control.frequency
□ Gửi reminder 2 tuần trước due_date
□ Escalate nếu quá 5 ngày không có action
□ Không cho phép close assessment nếu chưa có evidence đính kèm
□ Quarterly trend: hiển thị effectiveness qua thời gian
```

### Bước 4: Thiết kế Evidence Collection Workflow

```
WHY: Evidence tự động đáng tin hơn evidence thủ công — automation-first là nguyên tắc.

Evidence Store:
  - evidence_id: string
  - control_id: foreign key
  - assessment_id: foreign key
  - evidence_type: enum [screenshot, log_export, report, config_export, api_response, document]
  - collection_method: enum [manual_upload, api_pull, scheduled_export, webhook]
  - source_system: string (tên hệ thống: Okta, AWS CloudTrail, Jira, Datadog...)
  - file_path: string (immutable storage — không cho phép overwrite)
  - hash: string (SHA-256 để verify integrity)
  - collected_at: timestamp
  - collected_by: user_id (hoặc "system" nếu automated)
  - period_start, period_end: date (evidence cover period nào)
  - retention_until: date (theo retention policy)

Automated Collection Integrations (cần spec API):
□ Access reviews: Okta / Azure AD → pull user access list
□ Vulnerability scanning: Qualys / Nessus / Snyk → pull scan results
□ Change management: Jira / ServiceNow → pull change tickets
□ Infrastructure: AWS Config / Azure Policy → pull compliance state
□ Monitoring: Datadog / Splunk → pull alert configs và dashboard screenshots

Manual Upload:
□ Drag-and-drop interface
□ Bulk upload với tagging
□ Link evidence tới nhiều controls (shared evidence)
□ Version control: cùng document upload mới → không xóa cũ (immutable log)
```

### Bước 5: Thiết kế Exception Management

```
WHY: Controls không phải lúc nào cũng applicable 100% — exceptions cần được formally managed.

Exception Request:
  - exception_id: string
  - control_id: foreign key
  - requested_by: user_id
  - business_justification: text (bắt buộc)
  - compensating_controls: text (biện pháp thay thế)
  - risk_acceptance_level: enum [low, medium, high, critical]
  - requested_expiry: date (max 1 năm, phải renew)
  - status: enum [pending, approved, rejected, expired]
  - approved_by: user_id (phải là Compliance Officer hoặc CISO)
  - approved_at: timestamp

Approval Logic:
□ Low risk exception → Compliance Officer approve
□ High/Critical risk exception → CISO + Board Audit Committee notify
□ Tất cả exceptions phải có compensating controls document
□ Auto-expire và notify 30 ngày trước hết hạn
□ Expired exception chưa renew → control tự động flag "non-compliant"
```

### Bước 6: Thiết kế Remediation Tracking

```
WHY: Finding không có owner + deadline = finding sẽ không bao giờ được fix.

Remediation Plan:
  - remediation_id: string
  - source: enum [internal_assessment, external_audit, regulatory_finding, self_identified]
  - finding_description: text
  - root_cause: text
  - affected_controls: array of control_id
  - risk_rating: enum [critical, high, medium, low] (theo risk-matrix.md)
  - owner_id: user_id
  - target_date: date
  - actual_completion_date: date (nullable)
  - status: enum [open, in_progress, pending_validation, closed, overdue]
  - remediation_steps: array of {step, responsible, due_date, status}
  - validation_evidence_id: foreign key (proof of fix)
  - validator_id: user_id (must be different from owner — SoD)

SLA theo Risk Rating:
□ Critical → close trong 30 ngày
□ High → close trong 90 ngày
□ Medium → close trong 180 ngày
□ Low → next regular cycle

Escalation:
□ Overdue critical → CISO notify ngay lập tức
□ Overdue high → Compliance Officer notify weekly
□ Aging report: top 10 oldest open items trong dashboard
```

### Bước 7: Thiết kế Risk Register Linkage

```
READ: .claude/references/team-expert/compliance/risk-matrix.md

Controls phải link với Risks để show:
  → Control → mitigates → Risk (many-to-many)
  → Risk inherent score vs residual score (sau khi có controls)
  → Control failure → Risk residual score tăng automatically

Risk Entity (nếu chưa có Risk Register module):
  - risk_id: string (R-[CATEGORY]-[NNN])
  - description: text
  - category: enum [regulatory, operational, financial, reputational, strategic]
  - likelihood: integer 1-5 (xem risk-matrix.md)
  - impact: integer 1-5
  - inherent_score: computed (likelihood × impact)
  - residual_score: computed (sau controls)
  - owner_role: string
  - review_date: date
  - treatment: enum [accept, mitigate, transfer, avoid]
  - linked_controls: array of control_id

Residual Risk Calculation:
□ Mỗi effective control → giảm 1 điểm likelihood hoặc impact
□ Ineffective control → không giảm residual score
□ Khi assessment result = ineffective → trigger re-score risk
```

### Bước 8: Thiết kế Management Reporting

```
READ: .claude/references/team-expert/compliance/regulations.md → Reporting Obligations

Compliance Dashboard (real-time):
□ Overall compliance score (% controls effective / tổng active controls)
□ Controls by status: Effective / Partially Effective / Ineffective / Not Tested / Overdue
□ Assessment calendar: upcoming + overdue assessments
□ Open findings by severity
□ Risk heatmap (likelihood × impact grid)
□ Exception register summary

Monthly Compliance Report (export PDF/XLSX):
□ Executive summary: compliance posture vs last month
□ Control effectiveness rate trend (12 months)
□ Top risks với residual scores
□ Findings opened / closed / overdue trong tháng
□ Exceptions về to expire

Audit Committee Report (Quarterly, Board-level):
□ Compliance program health
□ Regulatory changes và impact
□ Material findings và remediation status
□ Certifications status (SOC 2 / ISO 27001 / PCI-DSS)
```

### Bước 9: Feature Spec Output

```markdown
# Feature Spec: Compliance Framework Module

## Overview
[Mô tả module — scope, frameworks, business value]

## User Stories
- Là Compliance Officer, tôi muốn... [theo personas từ analyze-compliance-requirements.md]
- Là Internal Auditor, tôi muốn...
- Là CISO, tôi muốn...
- Là Control Owner, tôi muốn...

## Functional Requirements

### REQ-COMP-FW-001: Control Library với Framework Mapping
[Mô tả, acceptance criteria, dependencies]

### REQ-COMP-FW-002: Assessment Scheduling & Execution
...

### REQ-COMP-FW-003: Evidence Collection (Manual + Automated)
...

### REQ-COMP-FW-004: Exception Management với Approval Workflow
...

### REQ-COMP-FW-005: Remediation Tracking với SLA
...

### REQ-COMP-FW-006: Risk Register Linkage
...

### REQ-COMP-FW-007: Compliance Dashboard & Reporting
...

## Data Model
[Control, Assessment, Evidence, Exception, Remediation, Risk entities + relationships]

## API Endpoints
[CRUD operations + specific endpoints: /controls, /assessments, /evidence, /risks, /reports]

## Non-functional Requirements
- Evidence integrity: SHA-256 hash verification, immutable storage
- Audit log: mọi action trong compliance system phải được logged
- Performance: Dashboard load < 3s với 500+ controls
- Data retention: Evidence files retain theo control.retention_until
- Access control: RBAC strict — control owner chỉ thấy controls của mình
```

---

## Checklist trước khi submit

```
□ Control Library có đủ fields: ID, type, frequency, owner_role, framework_mapping
□ Framework mapping hỗ trợ multi-framework (SOC 2 + ISO 27001 cùng lúc)
□ Evidence immutability được address (hash + no-overwrite)
□ Evidence coverage: manual + automated collection
□ Exception management có approval workflow và auto-expire
□ Remediation có owner + SLA + SoD (validator ≠ owner)
□ Risk linkage: inherent vs residual score
□ Reporting: operational dashboard + board-level summary
□ RBAC được specify
□ REQ-IDs đúng format REQ-COMP-FW-[NNN]
```
