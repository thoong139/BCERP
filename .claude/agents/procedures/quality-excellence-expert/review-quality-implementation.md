# Procedure: Review Quality Module Code Implementation

> **Type**: Agent Procedure
> **Agent**: quality-excellence-expert
> **Triggered when**: wf-implement-feature hoặc code review cho quality management module
> **Output**: Review report với severity per requirement, remediation recommendations

---

## Khi nào dùng procedure này

- Skill `wf-implement-feature` hoàn tất, gọi quality-excellence-expert review
- Developer yêu cầu review QMS module trước khi merge
- REQ-QMS-* features đã được implemented, cần verify business logic đúng

---

## Procedure

### Bước 1: Thu thập code và requirements

Đọc code files liên quan đến quality module.

Dùng Grep để tìm:
- Files có REQ-QMS comments: `grep -r "REQ-QMS" --include="*.ts,*.py,*.go,*.java"`
- CAPA/NCR/Audit logic files
- FMEA calculation logic

Đọc REQ-QMS-* specs từ `.mc-data/docs/phase2-features/` — đây là acceptance criteria chuẩn.

Xác định: tất cả REQ-QMS IDs cần được covered trong review này.

### Bước 2: Verify REQ-QMS traceability

Cho mỗi REQ-QMS ID trong scope:
- Code file implement requirement này ở đâu? (class, function, endpoint)
- File có REQ-ID comment không? (pattern: `// REQ-QMS-NCR-001` hoặc `# REQ-QMS-CAPA-003`)
- Acceptance criteria từ feature spec: từng criteria có implementation không?

**Traceability failures (severity: WARN)**:
- Code file không có REQ-ID comment → WARN: thêm REQ-ID reference
- REQ-ID trong spec nhưng không có code → FAIL: missing implementation

### Bước 3: Validate QMS business logic (ISO 9001)

READ `.claude/references/team-expert/quality-excellence/iso-9001.md`

Kiểm tra theo mandatory requirements:

**NCR Workflow completeness (Clause 8.7):**
- [ ] NCR có 7 required states: open → contained → rca_pending → capa_linked → pending_verify → closed (+ rejected)
- [ ] State transitions validated: cannot skip states without authority
- [ ] Classification required: Critical/Major/Minor — not nullable
- [ ] Detection source required: not nullable
- [ ] Photo attachment supported

**CAPA Logic completeness (Clause 10.2):**
- [ ] CAPA có root_cause_description field — not nullable at plan_approved state
- [ ] RCA method field present (5 Whys / Fishbone / Other)
- [ ] Action items have: owner_id, due_date, status — all required
- [ ] Effectiveness criteria defined before closure
- [ ] Effectiveness check date enforced (not closeable without verification)

**Document Control (Clause 7.5) if in scope:**
- [ ] Version number increments on each approved revision
- [ ] Approval workflow: draft → review → approved → issued
- [ ] Obsolete status prevents document from appearing in active search
- [ ] Retention period tracked

**Audit Management (Clause 9.2) if in scope:**
- [ ] Audit findings have classification: observation/minor_nc/major_nc
- [ ] Major NC triggers CAR (CAPA) creation — auto-link
- [ ] Auditor cannot audit their own process (conflict of interest check)

### Bước 4: Validate FMEA module logic

READ `.claude/references/team-expert/quality-excellence/fmea.md`

Kiểm tra FMEA business rules:

**RPN Calculation:**
- [ ] `rpn = severity × occurrence × detection` computed server-side (not client)
- [ ] Test: S=9, O=5, D=4 → RPN=180; verify calculation
- [ ] Computed field, not manually enterable by user

**Action Required Threshold:**
- [ ] `action_required = true` when `rpn >= 100` OR `severity >= 9`
- [ ] Test case: S=9, O=1, D=1 → RPN=9 but action_required=true (S>=9 rule)
- [ ] Test case: S=5, O=5, D=5 → RPN=125, action_required=true (RPN>=100 rule)

**Risk Owner Assignment:**
- [ ] When action_required=true: risk_owner_id becomes required field
- [ ] Validation: cannot move status to "accepted_risk" without risk_owner assigned
- [ ] Risk owner must be valid user ID (foreign key constraint)

**AIAG-VDA Scale Enforcement:**
- [ ] S, O, D values constrained to 1-10 (validation at API layer)
- [ ] Reject values < 1 or > 10

### Bước 5: Validate controls and authorization

READ `.claude/references/team-expert/quality-excellence/controls.md`

**Disposition Authority:**
- [ ] NCR disposition "use_as_is" requires minimum role: quality_manager
- [ ] Test: QA Analyst attempting use-as-is disposition → 403 Forbidden
- [ ] Escaping defect (critical severity) triggers escalation notification to quality_director

**Gate Sign-off:**
- [ ] Gate cannot move to PASS without all required_signers having signed
- [ ] Test: Gate 4 missing Quality Director sign-off → status remains "pending"
- [ ] Sign-off creates audit log entry (who signed, when, comments)

**Audit Trail:**
- [ ] All status changes logged: who changed, from → to, timestamp
- [ ] NCR updates logged (not just creation)
- [ ] CAPA action item updates logged

**Access Control:**
- [ ] QA Analyst cannot close NCR (only Quality Manager)
- [ ] CAPA approval requires quality_manager role minimum
- [ ] FMEA risk owner assignment: creator can assign, quality_manager can override

### Bước 6: Produce review report

Format output:

```
# Quality Module Implementation Review
Date: [Date]
Reviewer: quality-excellence-expert
Scope: REQ-QMS-[list] | Code files: [list]

## Summary
| Status | Count |
|--------|-------|
| PASS   | [n] requirements |
| WARN   | [n] items |
| FAIL   | [n] requirements |

## Detailed Findings

### REQ-QMS-NCR-001: NCR Creation với Classification
Status: [PASS / WARN / FAIL]
File: [path/to/ncr-controller.ts], Line: [line number if applicable]
Finding: [What was found]
Remediation: [Specific fix required]

### REQ-QMS-FMEA-003: RPN Threshold Automation
Status: FAIL
File: [path/to/fmea-service.ts]
Finding: RPN threshold check only uses RPN >= 100; missing S >= 9 rule
Remediation: Add check: `action_required = rpn >= 100 || severity >= 9`

[... per requirement ...]

## Critical Issues (Must Fix Before Release)
1. [Issue — file — remediation]

## Recommended Improvements (Post-Release)
1. [Improvement]
```

### Checklist trước khi submit

- [ ] Tất cả REQ-QMS IDs trong scope đã reviewed (không skip)
- [ ] FMEA RPN calculation verified với test cases (không chỉ code inspection)
- [ ] Authorization checks verified: thử call API với wrong role
- [ ] Audit trail verified: status changes are logged
- [ ] PASS/WARN/FAIL severity được gán đúng (FAIL = blocking, WARN = non-blocking)
- [ ] Specific file paths và line numbers included cho FAIL findings
- [ ] Remediation actionable: developer biết phải làm gì
