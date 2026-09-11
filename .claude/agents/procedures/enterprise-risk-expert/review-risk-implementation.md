# Procedure: Review Risk Module Code Implementation

> **Type**: Agent Procedure
> **Agent**: enterprise-risk-expert
> **Triggered when**: wf-implement-feature hoặc code review request cho risk management module
> **Output**: Review report với ✅ PASS / ⚠️ WARN / ❌ FAIL per requirement, specific remediation recommendations

---

## Khi nào dùng procedure này

Khi `wf-implement-feature` hoặc code-reviewer invoke `enterprise-risk-expert` để review
implementation quality của risk management module code.

Dấu hiệu nhận biết:
- Code files chứa risk register, KRI, scoring, risk governance logic
- Yêu cầu review: "risk scoring logic đúng không?", "role-based access đủ không?"
- Context: post-implementation review trước khi merge

---

## Procedure

### Bước 1: Đọc code files và REQ-RISK specs

```
INPUT:
□ Code files được review (paths do skill cung cấp)
□ REQ-RISK-* feature specs từ .mc-data/docs/phase2-features/
□ Technical design từ .mc-data/docs/phase3-architecture/ (nếu có)

Grep code files:
□ Tìm REQ-ID comments: grep -r "REQ-RISK" [code_paths]
□ Identify: risk model, scoring logic, KRI handling, role/permission code, audit trail code
□ List mọi REQ-RISK-* requirements → sẽ verify từng cái
```

### Bước 2: Verify REQ-RISK traceability

```
Kiểm tra traceability:
□ Mỗi code file có REQ-ID comment không?
   PASS: // REQ-ID: REQ-RISK-REG-001 hoặc tương đương
   FAIL: Code file không có REQ-ID → kết luận không traceable

□ Mỗi REQ-RISK-* requirement có code implementation không?
   Tạo bảng mapping:
   | REQ-ID | Code file | Status |
   | REQ-RISK-REG-001 | risk-register.service.ts | ✅ Found |
   | REQ-RISK-KRI-003 | kri-monitoring.service.ts | ❌ Not found |

□ REQ-RISK-* không có code → FAIL với note "chưa implement"
□ Code không có REQ-ID → WARN với note "thiếu traceability"
```

### Bước 3: Validate risk scoring logic

```
READ: .claude/references/team-expert/enterprise-risk/risk-assessment.md
→ 5×5 matrix, likelihood scale, impact scale, velocity factor, rating bands

Kiểm tra scoring implementation:
□ Likelihood range: 1-5 được enforce không? (validation, not just type)
□ Impact range: 1-5 được enforce không?
□ Score = Likelihood × Impact → logic đúng không?
□ Risk rating bands đúng không?
   FAIL nếu: Low = 1-6, Medium = 7-12, High = 13-19, Critical = 20-25 không khớp implementation

□ Velocity field: có field velocity không? Rapid/Moderate/Slow enum?
□ Inherent vs Residual: code phân biệt inherent score và residual score không?
□ Residual recalculation: khi control effectiveness thay đổi → residual score có tự update không?

Ví dụ lỗi thường gặp:
  ❌ score = likelihood + impact (phải là multiplication)
  ❌ Không có velocity field
  ❌ Rating bands off-by-one (ví dụ Medium = 6-12 thay vì 7-12)
  ❌ Residual score là manual input thay vì calculated field
```

### Bước 4: Validate role-based access (Three Lines of Defense)

```
READ: .claude/references/team-expert/enterprise-risk/risk-governance.md
→ Three Lines of Defense, role responsibilities matrix

Kiểm tra authorization implementation:
□ Roles được define: RISK_OWNER (1st line), RISK_MANAGER (2nd line), INTERNAL_AUDITOR (3rd line), CRO?
□ 1st line (Business Risk Owner):
   MUST have: view own risks, update own action plans, submit RCSA, log incidents
   MUST NOT have: edit other BU risks, approve risk acceptance globally, access board reports

□ 2nd line (Risk Manager / CRO):
   MUST have: full risk register access, approve risk acceptance, generate all reports
   CRO specifically: risk appetite management

□ 3rd line (Internal Auditor):
   MUST have: read-only risk register + control testing results
   MUST NOT have: edit risk scores, update risk status, modify action plans

□ Privilege escalation: không có path nào cho 1st line access 2nd/3rd line data?

□ Approval workflow: High/Critical risk approval có enforce CRO sign-off không?
□ Risk acceptance: documented với justification field và authorized approver?
```

### Bước 5: Validate control library và treatment workflow

```
READ: .claude/references/team-expert/enterprise-risk/controls.md
→ Control types, effectiveness ratings, treatment options, action plan management

□ Control types: Preventive/Detective/Corrective/Directive enum — đủ 4?
□ Effectiveness: Effective/Partially Effective/Ineffective/Not Tested — đủ 4?
□ Treatment options: Avoid/Reduce/Transfer/Accept/Exploit — đủ 5?
□ Risk acceptance: FAIL nếu thiếu justification field hoặc approver_id
□ Risk acceptance: FAIL nếu không có expiry/review_date
□ Action plan: owner, deadline, progress, status, last_updated — đủ fields?
□ Overdue detection logic và alert trigger có không?
```

### Bước 6: Validate audit trail và KRI logic

**Audit trail:**
```
□ All key events phải có immutable log: risk status/score change, acceptance approval,
  KRI reading, control effectiveness change — mỗi event có user_id + timestamp
□ FAIL nếu: soft delete cho risk records (phải archive, không delete)
□ FAIL nếu: audit log có thể modified (append-only, no UPDATE/DELETE)
```

**KRI logic:**
```
READ: .claude/references/team-expert/enterprise-risk/risk-assessment.md → KRI Design

□ Threshold logic: Green ≤ green_max < Amber ≤ amber_max < Red ≤ red_min đúng không?
□ Status calculation: status tính dựa trên thresholds automatically, không manual input
□ Alert trigger: khi reading.status thay đổi sang Red → alert record created → notification sent?
□ Escalation: Amber alert không resolve trong [X hours] → auto-escalate to Red handling?
□ Historical readings: old readings preserved, không bị overwrite
```

### Bước 7: Output — Review Report

**Format:**
```markdown
## RISK MODULE CODE REVIEW REPORT
Module: [Risk Register / KRI / etc.]
Reviewed: [Date] | Reviewer: enterprise-risk-expert
Code paths: [list]

### Summary
- Total REQ-RISK requirements reviewed: [N]
- PASS: [N] | WARN: [N] | FAIL: [N]
- Critical issues requiring immediate fix: [N]

### REQ-ID Traceability
| REQ-ID | Status | Code Reference | Notes |
|--------|--------|----------------|-------|
| REQ-RISK-REG-001 | ✅ PASS | risk.service.ts:45 | |
| REQ-RISK-KRI-003 | ❌ FAIL | Not found | Not implemented |

### Risk Scoring / Role-Based Access / Control Workflow / Audit Trail / KRI Logic
[Section per topic — ✅/⚠️/❌ với specific line references]

### Critical Issues (must fix before merge)
1. [Issue] — File: [path]:Line → Fix: [remediation]

### Warnings (should fix)
1. [Issue] → Recommendation: [suggestion]

### Overall Verdict: [✅ PASS / ⚠️ CONDITIONAL PASS / ❌ FAIL]
```

---

## Checklist trước khi submit review

```
□ Mọi REQ-RISK-* đã được verify (không bỏ sót)
□ Scoring: likelihood × impact × velocity — đúng logic
□ Rating bands (Low/Medium/High/Critical) khớp 5×5 standard
□ Three Lines of Defense role separation — đã verify
□ Risk acceptance: justification + approver required — đã verify
□ Audit trail append-only, immutable — đã verify
□ KRI threshold: Green < Amber < Red — đã verify
□ Mỗi finding có: severity, file:line reference, remediation
□ Overall verdict rõ ràng với rationale
```
