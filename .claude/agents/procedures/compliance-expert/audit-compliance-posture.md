# Playbook: Audit Compliance Posture của Hệ thống Hiện có

> **Type**: Agent Skill Playbook
> **Agent**: compliance-expert
> **Triggered by**: /wf-legacy-scan khi cần assess compliance posture của hệ thống đang chạy
> **Output**: `.mc-data/docs/phase1-business/compliance-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống đang vận hành
- Khi cần đánh giá compliance posture trước khi thiết kế lại hoặc mở rộng
- Khi chuẩn bị cho audit (SOC 2, ISO 27001, PCI-DSS) và cần biết điểm xuất phát
- Khi phát hiện compliance gaps trong codebase hiện tại

---

## Procedure

### Bước 1: Identify applicable regulations

```
READ: .claude/references/team-expert/compliance/regulations.md

Từ context dự án (brainstorm, tech stack, business model), xác định:

□ Industry: Financial / Healthcare / SaaS / E-commerce / Manufacturing / Other?
□ Jurisdictions: Vietnam / EU / US / APAC / Multi-jurisdictional?
□ Data processed: PII? Financial records? Health data? Payment card?
□ Business model: B2B enterprise (SOC 2 pressure) / Consumer (GDPR/PDPA) / Regulated market?
□ Certifications đang có hoặc đang hướng tới?
□ Có customer contracts yêu cầu compliance không? (Enterprise SLAs thường có)

Output: Danh sách regulations applicable với mức độ Priority:
- Mandatory: Bắt buộc pháp lý — vi phạm → penalty trực tiếp
- Customer-required: Khách hàng yêu cầu — không có → mất deal
- Best practice: Không bắt buộc nhưng expected trong industry
```

### Bước 2: Current control inventory

```
READ: .claude/references/team-expert/compliance/controls.md → Common Control Activities

Scan codebase và documentation để inventory controls hiện có:

Authentication & Access Control:
□ Có authentication mechanism không? (Password / SSO / MFA)
□ MFA được enforce cho privileged accounts không?
□ Role-based access control (RBAC) có không? Granularity đến đâu?
□ Session management: timeout, token expiry, concurrent sessions?
□ Password policy: complexity, rotation, history?
□ Privileged account management: service accounts, admin accounts?

Audit & Logging:
□ Có audit log không? Capture những gì? (xem design-audit-trail.md về taxonomy)
□ Logs có immutable không? Ai có thể xóa?
□ Retention policy là bao nhiêu?
□ SIEM hoặc log aggregation có không?
□ Alerting trên anomalies có không?

Data Protection:
□ Encryption at rest: database encrypted không? Key management?
□ Encryption in transit: TLS 1.2+ everywhere? HSTS?
□ PII handling: có mask / tokenize không? Trong logs? Trong exports?
□ Backup: có không? Encrypted? Tested recovery?
□ Data retention & deletion: có enforcement không?

Vulnerability & Change Management:
□ Dependency scanning: automated? How often?
□ SAST/DAST: có không?
□ Patching policy: SLA cho critical vulnerabilities?
□ Change management: approval process trước deployment?
□ Code review: required? Security review?

Incident Response:
□ Có Incident Response Plan (IRP) không? Documented?
□ Có breach notification procedure không? (GDPR 72h, HIPAA 60 days)
□ Contact list cho security incidents?
□ Post-mortem process?

Vendor / Third-party:
□ Vendor security assessment process?
□ Data Processing Agreements (DPA) với vendors xử lý customer data?
□ Sub-processor list (GDPR requirement)?
```

### Bước 3: Gap analysis

```
READ: .claude/references/team-expert/compliance/audit-templates.md → Gap Assessment

Với mỗi regulation trong scope, đánh giá từng control domain:

Status Rating:
- Full: Control exists và operating effectively
- Partial: Control exists nhưng có gaps hoặc exceptions
- Missing: Control không có
- Unknown: Không đủ information để assess

Gap Severity (dùng để prioritize remediation):
- Critical: Vi phạm trực tiếp regulation / immediate risk / deal-blocking
- High: Significant compliance risk / sẽ fail audit / customer concern
- Medium: Partial compliance / audit finding likely / should fix
- Low: Best practice gap / improve posture / nice-to-have

Gap Finding Format:
  Control Area: [Tên control area, VD: "Logical Access Controls"]
  Framework Reference: [SOC 2 CC6.1 / ISO 27001 A.9.2.1 / PCI-DSS Req 7]
  Status: Full / Partial / Missing
  Current State: [Mô tả thực tế hiện tại — specific và factual]
  Target State: [Mô tả cần đạt để compliant]
  Gap Description: [Cụ thể gap là gì]
  Severity: Critical / High / Medium / Low
  Estimated Effort: [S/M/L/XL hoặc số ngày]
  Owner Suggestion: [CISO / DevOps / Engineering / Legal]
```

### Bước 4: Risk rating (Inherent vs Residual)

```
READ: .claude/references/team-expert/compliance/risk-matrix.md

Với mỗi Critical và High gap, perform risk rating:

Inherent Risk (không có controls):
□ Likelihood: 1-5 (dùng Likelihood Scale từ risk-matrix.md)
□ Impact: 1-5 (dùng Impact Scale — xét financial + operational + reputational)
□ Inherent Score: Likelihood × Impact → map to L/M/H/C

Residual Risk (với controls hiện có, dù partial):
□ Đánh giá controls hiện có giảm được Likelihood hay Impact bao nhiêu?
□ Residual Score: thấp hơn Inherent nếu có controls, bằng Inherent nếu không có
□ Gap = Inherent Risk - Residual Risk → effort cần bỏ ra

Risk Register Summary:
  Top 5 risks by residual score → danh sách cho leadership
  Ví dụ:
  R001: Unauthorized PII access — Inherent: H (4×4=16), Residual: H (không có MFA) → Critical action needed
  R002: Audit log tampering — Inherent: H (3×5=15), Residual: M (có logs nhưng not immutable) → High priority
```

### Bước 5: Documentation quality assessment

```
Compliance không chỉ là technology — documentation là bằng chứng với auditors.

Đánh giá documentation hiện có:

□ Information Security Policy: có không? Last updated?
□ Data Privacy Policy (Privacy Notice): published? Covers GDPR/PDPA?
□ Acceptable Use Policy: có không?
□ Incident Response Plan: có, tested, last drill khi nào?
□ Business Continuity / Disaster Recovery Plan: có không? RTO/RPO?
□ Vendor Management Policy: có không?
□ Data Retention Policy: có, enforced?
□ Change Management Procedure: documented?

Documentation Quality Rating:
- Comprehensive: Đầy đủ, up-to-date, staff biết và tuân thủ
- Exists but outdated: Có nhưng > 1 năm không update
- Draft only: Có draft nhưng chưa approved/published
- Missing: Không có

Lưu ý (từ audit-templates.md principle "Substance Over Checkbox"):
→ Policy không ai tuân theo tệ hơn không có policy — tạo false confidence
→ Flag "policy exists but not enforced" là HIGH severity gap
```

### Bước 6: Audit history review

```
Nếu có audit history (previous internal/external audit reports):

□ Last audit date và firm là gì?
□ Findings từ last audit: bao nhiêu? Severity distribution?
□ Remediation status: bao nhiêu đã close? Bao nhiêu còn open?
□ Repeat findings (same finding nhiều năm liên tiếp) → red flag, must address
□ Management letter từ external auditors: có concerns nào?

Nếu không có audit history:
→ Note: "No prior audit history — this assessment represents baseline"
→ Treat organization as audit-naive, assume more gaps
```

### Bước 7: Compliance debt assessment

```
WHY: Compliance debt = technical debt nhưng cho compliance — accumulated risks và missing controls.

Compliance Debt Categories:

1. Security debt:
   □ Unpatched dependencies (CVEs)
   □ Hardcoded credentials trong codebase (scan với truffleHog, gitleaks)
   □ Missing encryption, weak cipher suites
   □ Overly permissive IAM roles

2. Process debt:
   □ Manual processes thay thế automated controls (fragile)
   □ Single point of knowledge (1 người biết procedure)
   □ No documentation / undocumented workarounds

3. Documentation debt:
   □ Missing policies
   □ Policies không reflect actual practice (drift)
   □ No evidence of control operation

4. Architectural debt:
   □ Monolith gây khó implement SoD (Segregation of Duties)
   □ No environment separation (dev/staging/prod share data)
   □ PII commingled với non-PII data (làm khó implement data minimization)

Compliance Debt Score (qualitative):
□ Low: Minor gaps, mostly process/doc issues
□ Medium: Structural gaps, will require 3-6 months to remediate
□ High: Fundamental control failures, deal-blocking for enterprise customers
□ Critical: Regulatory exposure now, immediate action required
```

### Bước 8: Output — Compliance As-Is Analysis

```
Ghi vào: .mc-data/docs/phase1-business/compliance-as-is-analysis.md

Cấu trúc output:

# Compliance As-Is Analysis

## Executive Summary
[3-5 dòng: Overall compliance posture score, top 3 strengths, top 3 critical gaps]
[Overall Readiness: X/100 — phương pháp tính toán]

## Scope
- Regulations assessed: [list]
- Systems trong scope: [list]
- Assessment date: [date]
- Methodology: document review, codebase scan, stakeholder input

## Applicable Regulations
[Table: Regulation | Priority | Key Requirements | Current Gap Summary]

## Current Control Inventory
[Table: Control Area | Controls Present | Automation Level | Status]

## Gap Analysis

### Critical Gaps (immediate action)
[Gap ID | Area | Framework Ref | Current State | Target State | Severity | Effort | Owner]

### High Priority Gaps
[Same format]

### Medium Priority Gaps
[Same format]

### Low Priority Gaps
[Same format]

## Risk Assessment
### Risk Register (Top 10)
[ID | Risk | Inherent | Residual | Controls Present | Priority]

### Risk Heatmap
[Likelihood × Impact grid với risks plotted]

## Documentation Quality
[Table: Document | Status | Last Updated | Notes]

## Compliance Debt Summary
[Category | Debt Items | Severity | Estimated Effort]

## Audit History
[Prior audits nếu có, repeat findings, open items]

## Priority Recommendations
1. [Highest impact, regulation-mandatory] — Effort: [X], Deadline: [nếu regulatory]
2. ...

## Remediation Roadmap
Quick Wins (< 30 ngày):
- [Action] → Owner: [role] → Impact: [regulation/risk addressed]

Short-term (30-90 ngày):
- [Action] ...

Medium-term (90-180 ngày):
- [Action] ...

Long-term (180+ ngày — structural changes):
- [Action] ...

## Open Questions
[Items cần confirm với stakeholders trước khi finalize remediation plan]
```

---

## Checklist trước khi submit

```
□ Regulations applicable đã xác định: Mandatory vs Customer-required vs Best practice
□ Control inventory cover đủ: Access / Audit / Data Protection / Vuln Mgmt / IR / Vendor
□ Gap analysis có Framework Reference cụ thể (không chỉ "missing")
□ Severity rating có basis rõ ràng
□ Risk rating: Inherent vs Residual với methodology
□ Repeat findings (nếu có audit history) được flag rõ
□ Compliance debt categorized đầy đủ
□ Hardcoded credentials scan đã check (hoặc note "không scan được")
□ Remediation roadmap realistic (không phải laundry list không có owner)
□ Open questions được list để stakeholders confirm
```
