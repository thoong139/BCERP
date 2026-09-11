# Playbook: Design Compliance Tracking Module

> **Type**: Agent Skill Playbook
> **Agent**: legal-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần thiết kế compliance/regulatory module
> **Output**: Feature spec + Data model cho Compliance Management

---

## Khi nào dùng playbook này

- Khi cần spec module "Compliance Management" hoặc "Quản lý Tuân thủ"
- Khi dự án thuộc ngành có regulatory requirements cao (Finance, Healthcare, Manufacturing)
- Khi cần thiết kế control library, compliance calendar, audit management
- Khi review/audit hệ thống compliance hiện có và cần redesign

---

## Procedure

### Bước 1: Xác định scope Compliance

```
Hỏi hoặc suy luận từ context:

□ Ngành nghề: Finance (NHNN/SBV) / Healthcare (BYT) / Manufacturing (ISO) /
              Technology (PDPA/GDPR) / Listed company (SSC/HNX)...
□ Certifications hiện có hoặc cần đạt: ISO 9001, ISO 27001, SOC2, PCI-DSS...
□ Regulatory bodies: Cơ quan nào giám sát? Báo cáo định kỳ cần gì?
□ Internal compliance: Policy management, Code of conduct, Training
□ External audit: Có audit bên ngoài không? Tần suất? Scope?
□ Risk management: Có risk register không? Có kết nối với compliance không?
□ Incident management: Có cần theo dõi compliance breaches không?
```

### Bước 2: Thiết kế Regulatory Inventory

```
READ: controls.md → Section 4 (Compliance Calendar Controls)
READ: operations.md → Section 4 (Compliance Monitoring)

Bước đầu tiên khi design compliance system:
tạo danh sách đầy đủ regulations/standards áp dụng.

Regulatory Inventory structure:

| Regulation      | Type         | Jurisdiction | Frequency  | Penalty Risk | Owner     |
|-----------------|-------------|:------------:|:----------:|:------------:|-----------|
| PDP (VN)        | Data Privacy | Vietnam      | Ongoing    | Cao          | DPO       |
| ISO 27001       | Security     | Global       | Annual     | Trung bình   | IT + Legal|
| Báo cáo thuế    | Tax          | Vietnam      | Monthly/Q  | Cao          | Finance   |
| ...             | ...          | ...          | ...        | ...          | ...       |

Với mỗi regulation:
□ Identify specific articles/requirements áp dụng
□ Map sang internal controls đang có
□ Identify gaps (requirements chưa có control tương ứng)
```

### Bước 3: Thiết kế Compliance Framework Mapping

```
Framework phổ biến cần support:

ISO 27001 (Information Security):
□ Annex A controls: 93 controls trong 4 themes
□ Statement of Applicability (SoA)
□ ISMS scope definition
□ Internal audit, Management review

GDPR / PDP Bill Vietnam:
□ Lawful basis for processing
□ Data Protection Impact Assessment (DPIA)
□ Records of Processing Activities (RoPA)
□ Breach notification workflow (72h GDPR / per PDP)
□ DSAR (Data Subject Access Request) workflow
□ Data transfer safeguards

SOC 2 (Type I / Type II):
□ Trust Services Criteria: Security, Availability, Confidentiality, Privacy, Processing Integrity
□ Control description + Evidence mapping
□ Continuous monitoring vs point-in-time

PCI-DSS:
□ 12 requirements → SAQ type (A, B, C, D...)
□ Quarterly vulnerability scans
□ Annual pen test

Thiết kế framework trong system:
□ Framework library (pre-loaded standards)
□ Control library (controls của từng framework)
□ Control mapping (1 internal control → nhiều framework requirements)
□ Gap analysis engine (so sánh current controls vs framework requirements)
```

### Bước 4: Thiết kế Control Library

```
Control structure:

Control:
  - ID (unique, auto-generated)
  - Name, Description
  - Control Type: Preventive / Detective / Corrective
  - Control Category: Technical / Administrative / Physical
  - Control Owner (FK → User)
  - Testing Frequency: Continuous / Monthly / Quarterly / Annual
  - Testing Method: Automated / Manual Interview / Observation / Inspection
  - Framework Mappings: [ISO 27001 A.8.1, GDPR Art.32, SOC2 CC6...]
  - Status: Active / Inactive / Under Review
  - Effectiveness: Effective / Partially Effective / Ineffective / Not Tested
  - Last Tested Date, Next Test Date
  - Evidence Required (list)
  - Risk Linkage (FK → Risk)

Assessment:
  - id, control_id (FK)
  - assessment_date
  - assessor_id (FK → User)
  - status: Pass / Fail / Partial
  - findings (text)
  - evidence_links (array of URLs/file paths)
  - remediation_required (boolean)
  - remediation_due_date
  - closed_at

Evidence:
  - id, control_id, assessment_id (FK)
  - evidence_type (enum: Document/Screenshot/Config/Log/Interview)
  - file_url, file_name
  - collected_by (FK → User)
  - collected_at, valid_until
  - description
```

### Bước 5: Thiết kế Compliance Calendar

```
READ: operations.md → Quick Reference: Compliance Calendar Template
READ: controls.md → Section 4 (Compliance Calendar Controls)

Calendar event structure:

ComplianceDeadline:
  - id, regulation_id (FK)
  - event_name, description
  - deadline_type: Statutory (luật định) / Internal (nội bộ) / Certification
  - recurrence: One-time / Monthly / Quarterly / Annual
  - deadline_date (cụ thể hoặc rule: "last day of Q1")
  - responsible_id (FK → User), backup_responsible_id
  - alert_schedule: [90, 60, 30, 14, 7, 1] ngày trước deadline
  - status: Upcoming / In Progress / Completed / Overdue / Waived
  - completion_evidence (file attachment)
  - completed_at, completed_by

Dashboard calendar cần hiển thị:
□ Monthly view: tất cả deadlines trong tháng
□ Color coding: Upcoming (xanh) / Due soon (vàng) / Overdue (đỏ) / Completed (xám)
□ Owner filter: "Chỉ show deadlines của tôi"
□ Export: ICS calendar feed để sync với Google Cal/Outlook
□ Summary stats: % on-time completion, overdue count
```

### Bước 6: Thiết kế Risk Register

```
READ: controls.md → Quick Reference: Risk Assessment Matrix

Risk structure:

Risk:
  - id, risk_code (REG-RISK-001...)
  - risk_title, description
  - risk_category: Regulatory / Operational / Reputational / Financial
  - risk_source: Regulation name / Internal process
  - inherent_likelihood: 1-5
  - inherent_impact: 1-5
  - inherent_score: likelihood × impact
  - control_ids (array FK – controls mitigating this risk)
  - residual_likelihood: 1-5 (sau khi có controls)
  - residual_impact: 1-5
  - residual_score
  - risk_owner_id (FK → User)
  - status: Open / Accepted / Mitigated / Transferred / Closed
  - review_date

Risk Level (residual_score):
□ 1-4: Low (theo dõi định kỳ)
□ 5-9: Medium (mitigate, review quarterly)
□ 10-16: High (priority action, review monthly)
□ 17-25: Critical (immediate escalation, CEO/Board aware)
```

### Bước 7: Thiết kế Remediation Tracking

```
Khi control assessment = Fail hoặc risk = High/Critical:
→ Tự động tạo Remediation Task

RemediationTask:
  - id, source_type (Control Assessment / Risk / Audit Finding)
  - source_id (FK)
  - title, description
  - root_cause (text)
  - remediation_plan (text – action steps)
  - assigned_to_id (FK → User)
  - due_date (SLA theo severity)
  - priority: Critical / High / Medium / Low
  - status: Open / In Progress / Pending Review / Closed / Accepted Risk
  - evidence_of_completion (file attachment)
  - verified_by_id (FK → User – Compliance Officer verifies)
  - verified_at, closed_at

SLA by severity:
□ Critical finding: 7 ngày
□ High finding: 30 ngày
□ Medium finding: 90 ngày
□ Low finding: 180 ngày (hoặc next review cycle)
```

### Bước 8: Thiết kế Reporting Dashboards

```
READ: operations.md → Section 4 (Decision Support Requirements)

Dashboard 1: Compliance Overview (Legal Director / Board)
□ Overall compliance score (% controls effective)
□ Framework coverage (% requirements with mapped controls)
□ Open findings by severity (Critical/High/Medium/Low)
□ Overdue deadlines count
□ Risk heat map (2×2: likelihood vs impact)
□ Trend: Month-over-month improvement

Dashboard 2: Control Testing Status (Compliance Officer)
□ Controls by test status: Tested / Overdue / Upcoming
□ Testing queue (controls due this month)
□ Pass rate by framework
□ Evidence collection progress

Dashboard 3: Compliance Calendar (All compliance team)
□ Upcoming deadlines (next 90 days)
□ My deadlines (personalized)
□ Overdue items

Reports cần generate:
□ Gap Analysis Report (requirements vs controls)
□ Risk Report (quarterly cho Board)
□ Compliance Status Report (monthly cho Management)
□ Audit Readiness Report (on-demand trước external audit)
□ Evidence Package (per control, để submit cho auditor)
```

### Bước 9: Feature Spec Output

```markdown
# Feature Spec: Compliance Tracking và Management

## REQ-ID: REQ-LEGAL-COMP-[NNN]

## Overview
[Mô tả module – 3-5 dòng]

## User Stories
- Compliance Officer: Tôi muốn xem tất cả regulatory deadlines trong 90 ngày tới
  để không bị miss deadline nào
- Legal Director: Tôi muốn xem compliance score theo từng framework
  để báo cáo cho Board
- IT Security: Tôi muốn map controls của mình vào ISO 27001 requirements
  để chuẩn bị cho audit

## Functional Requirements

### REQ-LEGAL-COMP-001: Regulatory Inventory và Framework Library
### REQ-LEGAL-COMP-002: Control Library với Framework Mapping
### REQ-LEGAL-COMP-003: Compliance Calendar với Alert Automation
### REQ-LEGAL-COMP-004: Control Assessment Workflow và Evidence Management
### REQ-LEGAL-COMP-005: Risk Register với Control Linkage
### REQ-LEGAL-COMP-006: Remediation Task Management
### REQ-LEGAL-COMP-007: Gap Analysis Engine
### REQ-LEGAL-COMP-008: Reporting Dashboards (Overview, Calendar, Control Testing)
### REQ-LEGAL-COMP-009: Audit Readiness Package Export

## Data Model
[Entity diagram hoặc field definitions từ Bước 4-7]

## Non-functional Requirements
- Evidence storage: Immutable (không thể modify sau khi submit)
- Audit log: Toàn bộ thay đổi trên compliance records được log
- Data retention: Compliance records giữ 7 năm
- Performance: Dashboard load < 3s với 500+ controls
- Export: PDF/Excel report generation trong < 30s

## Integration Points
- HR system: Training completion tracking
- IT/ITSM: Technical controls evidence (config exports, scan results)
- GRC platform: Nếu có (Archer, ServiceNow GRC...)
- External auditor portal: Evidence sharing (read-only access)
```

---

## Checklist trước khi submit

```
□ Regulatory inventory đã cover theo ngành nghề của dự án
□ Framework mapping đã xác định (ISO/GDPR/SOC2/PCI-DSS...)
□ Control library structure đã thiết kế (Control Type, Testing Method)
□ Compliance calendar có alert automation đầy đủ
□ Evidence management: immutable, có expiry date
□ Risk register có link với controls (residual risk calculation)
□ Remediation SLA đã định nghĩa theo severity
□ Dashboard coverage đủ cho từng audience (Board/Management/Compliance team)
□ Audit readiness report đã included
□ Data retention: 7 năm cho compliance records
□ Integration với HR (training) và IT (technical controls) đã noted
```
