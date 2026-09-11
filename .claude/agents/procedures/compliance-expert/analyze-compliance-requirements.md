# Playbook: Phân tích Compliance Requirements

> **Type**: Agent Skill Playbook
> **Agent**: compliance-expert
> **Triggered by**: /wf-analyze-requirements khi phát hiện module liên quan đến compliance, audit, risk management
> **Output**: `.mc-data/docs/phase1-business/compliance-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: compliance management, audit trail, risk register, internal controls, regulatory reporting, data protection
- Khi keywords xuất hiện trong brainstorm: tuân thủ, kiểm toán, rủi ro, quy định, GDPR, SOC2, ISO 27001, PCI-DSS, HIPAA, kiểm soát nội bộ

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Industry / ngành nghề (Financial services, Healthcare, SaaS, E-commerce, Manufacturing...)
□ Jurisdictions (Vietnam, EU, US, multi-jurisdictional)
□ Business model (B2B enterprise / B2C / regulated market player)
□ Giai đoạn công ty (startup / growth / pre-IPO / public company)
□ Đã có compliance program chưa? Nếu có → đang ở mức nào?
□ Certifications mục tiêu (SOC 2, ISO 27001, PCI-DSS, HIPAA, hay internal chỉ cần COSO?)
```

### Bước 2: Xác định regulatory scope

```
READ: .claude/references/team-expert/compliance/regulations.md

Dựa trên Industry + Jurisdictions, map applicable regulations:

Financial Services:
□ Basel II/III (banking capital adequacy)
□ AML/CTF + KYC (anti-money laundering)
□ PCI-DSS (nếu xử lý thẻ tín dụng)
□ MiFID II (nếu investment services)

Healthcare:
□ HIPAA (US patients)
□ Decree 117/2020 (Vietnam healthcare)
□ GDPR (EU patients)

SaaS / Cloud Services:
□ SOC 2 Type II (Trust Service Criteria)
□ ISO 27001 (ISMS)
□ GDPR / Decree 13/2023 (data protection)

E-commerce / Payments:
□ PCI-DSS (card data)
□ GDPR / Decree 13/2023 (customer data)
□ Consumer protection laws

General Corporate:
□ COSO Framework (internal controls)
□ ISO 19600 (compliance management)
□ SOX Section 404 (nếu public company)
□ ISO 37001 (anti-bribery)

Sau khi xác định → ghi rõ: Mandatory (bắt buộc pháp lý) vs Discretionary (best practice)
```

### Bước 3: Map personas sử dụng compliance system

```
Xác định ai sẽ interact với compliance module:

□ CISO (Chief Information Security Officer)
  → Cần: Security control dashboard, risk posture overview, incident management
  → Pain point: Không có visibility real-time vào control effectiveness

□ Compliance Officer / Chief Compliance Officer
  → Cần: Control library, assessment scheduling, regulatory tracking, reporting
  → Pain point: Quản lý evidence thủ công, khó prove compliance với auditors

□ Internal Auditor
  → Cần: Audit plan management, testing workpapers, findings tracking, remediation follow-up
  → Pain point: Fragmented tools, manual evidence collection

□ Data Protection Officer (DPO)
  → Cần: Data mapping, DPIA workflow, consent management, data subject request handling
  → Pain point: Không track được data flows và consent status

□ Risk Manager
  → Cần: Risk register, risk scoring, control linkage, KRI dashboard
  → Pain point: Risk register là spreadsheet, không liên kết với controls và incidents

□ Business Unit Manager (control owner)
  → Cần: Control testing notifications, evidence submission, exception requests
  → Pain point: Không biết mình phải làm gì khi đến hạn control testing

□ Auditor (External / nếu cần access)
  → Cần: Read-only audit portal, evidence packages, audit trail
  → Pain point: Manual document request process, chậm
```

### Bước 4: Phân biệt Mandatory vs Discretionary controls

```
READ: .claude/references/team-expert/compliance/controls.md → Control Types

Mandatory controls (bắt buộc — không có → vi phạm regulation):
□ Audit trail cho mọi data changes (PCI-DSS Req 10, SOX, GDPR Art 30)
□ Access control với least privilege (SOC 2 CC6, ISO 27001 A.9)
□ Incident response và breach notification (GDPR Art 33, HIPAA)
□ Consent management và data subject rights (GDPR, Decree 13/2023)
□ Data retention và deletion (GDPR Art 17, tax laws)
□ Segregation of duties cho financial transactions (SOX, COSO)
□ Encryption at rest và in transit (PCI-DSS, HIPAA, SOC 2)

Discretionary controls (best practice — thêm điểm audit readiness):
□ Continuous monitoring dashboard
□ Control effectiveness scoring
□ Automated evidence collection
□ Third-party/vendor risk management
□ Compliance training tracking
□ Policy attestation workflow
```

### Bước 5: Risk appetite assessment

```
READ: .claude/references/team-expert/compliance/risk-matrix.md

Xác định risk tolerance của tổ chức:

Conservative (regulated industry: banking, healthcare):
→ Tất cả High + Critical risks phải có controls
→ Zero tolerance cho data breaches và regulatory violations
→ Prefer automated controls over manual

Moderate (SaaS, E-commerce):
→ Critical risks phải có controls, High risks cần mitigation plan
→ Accept một số manual controls với compensating measures
→ Risk appetite review hàng năm

Pragmatic (startup, pre-compliance):
→ Focus vào Critical và top 5 High risks trước
→ Build minimum viable compliance program
→ Roadmap rõ ràng để reach target state

Sau đó xác định:
□ Risk appetite statement cần capture trong requirements không?
□ Exception management process cần design không?
□ Risk escalation thresholds là bao nhiêu?
```

### Bước 6: Viết requirements

Format mỗi requirement:

```markdown
### REQ-COMP-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này — CISO / Compliance Officer / Internal Auditor / DPO / Risk Manager]
**Business Value**: [Tại sao cần — tránh penalty? giảm audit effort? prove compliance?]
**Regulatory Basis**: [GDPR Art X / SOC 2 CC X / ISO 27001 A.X / PCI-DSS Req X / N/A nếu discretionary]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
**Control Type**: [Preventive / Detective / Corrective / Directive]
```

**REQ-ID Format:**

```
REQ-COMP-FW-[NNN]    → Compliance Framework (control library, assessment, reporting)
REQ-COMP-AUDIT-[NNN] → Audit Trail / Logging system
REQ-COMP-RISK-[NNN]  → Risk Register & Risk Management
REQ-COMP-PRIV-[NNN]  → Privacy & Data Protection (GDPR, consent)
REQ-COMP-POL-[NNN]   → Policy Management & attestation
REQ-COMP-INC-[NNN]   → Incident & Breach Management
REQ-COMP-VEND-[NNN]  → Vendor / Third-party Risk
REQ-COMP-RPT-[NNN]   → Compliance Reporting & Dashboards
```

### Bước 7: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/compliance-requirements.md

Cấu trúc output:
1. Executive Summary
   - Regulatory scope (applicable frameworks)
   - Risk appetite summary
   - Compliance program maturity target

2. Applicable Regulations & Frameworks
   - Mandatory obligations (bắt buộc pháp lý)
   - Certifications mục tiêu (nếu có)

3. Personas & Pain Points
   - Mỗi persona: role, pain points, must-have features

4. Requirements (theo module, có REQ-ID)
   - Nhóm theo REQ-COMP-[MODULE]
   - Ghi rõ Mandatory vs Discretionary

5. Integration requirements
   - Với IT/Security systems (SIEM, IAM, vulnerability scanner)
   - Với Finance (audit trail cho financial transactions)
   - Với HR (training tracking, policy attestation)

6. Non-functional requirements
   - Audit log immutability
   - Retention periods
   - Access control cho compliance data

7. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-COMP-[MODULE]-[NNN]
□ Mỗi REQ có Regulatory Basis (hoặc ghi rõ N/A nếu discretionary)
□ Mandatory controls được phân biệt rõ với discretionary
□ Audit trail requirements đã covered
□ Data retention requirements đã included
□ Access control / Segregation of Duties đã addressed
□ Incident response / breach notification đã noted
□ Privacy requirements (consent, data subject rights) đã covered nếu applicable
□ Open questions được list ra để stakeholders review
```
