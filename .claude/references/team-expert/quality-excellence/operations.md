# Quality Excellence - QMS Operational Framework

> **Domain**: Quality Excellence / QMS Operations & Workflows
> **Last Updated**: 2026-03-22
> **Nguồn**: ISO 9001:2015 Clause 8-10, CAPA best practices, industry operations

---

## 1. QMS Operation Calendar

### Daily Activities

| Activity | Owner | Time Required |
|----------|-------|--------------|
| Check NCR dashboard — any new critical NCRs? | QA Analyst | 15 min |
| Review CAPA overdue alerts | QA Analyst | 10 min |
| Defect logging từ production/service (if applicable) | QA Analyst | Ongoing |
| Escalate critical NCRs to Quality Manager | QA Analyst | As needed |

### Weekly Activities

| Activity | Owner | Time Required |
|----------|-------|--------------|
| Quality team standup: NCR/CAPA weekly status | Quality Manager | 30 min |
| Supplier quality issues review | Quality Manager + Procurement | 30 min |
| NCR aging review: flag items approaching 14-day mark | QA Analyst | 20 min |
| CAPA action update requests: remind owners | QA Analyst | 15 min |

### Monthly Activities

| Activity | Owner | Deliverable |
|----------|-------|-------------|
| Quality KPI report (NCR rate, CAPA status, customer complaints) | Quality Manager | Monthly quality report |
| Management quality meeting | Quality Director + Managers | Meeting minutes |
| Internal audit (portion — 1 area per month for full coverage) | Internal Auditor | Audit notes |
| Supplier quality scorecard update | QA Analyst | Supplier dashboard |
| CoQ data collection and report | Quality Manager | CoQ monthly report |

### Quarterly Activities

| Activity | Owner | Deliverable |
|----------|-------|-------------|
| Management review meeting | Quality Director + Top Mgmt | Management review minutes |
| Supplier quality review | Quality Director + Procurement | Supplier action plan |
| Customer quality review | Quality Director + Account Mgmt | Customer quality report |
| Quality objectives progress review | Quality Director | Objectives status update |
| Risk register review and update | Quality Manager | Updated risk register |

### Annual Activities

| Activity | Owner | Deliverable |
|----------|-------|-------------|
| Full management review (ISO 9001 Clause 9.3) | Quality Director + C-suite | Formal MR minutes + actions |
| ISO 9001 surveillance audit (year 1, 2) or recertification (year 3) | Quality Director | Audit report, CAPA |
| Full FMEA review cycle | Quality Engineer + Process Owners | Updated FMEA register |
| Quality policy and objectives review | Quality Director + Top Mgmt | Updated policy, new objectives |
| Internal audit program planning for next year | Lead Auditor | Annual audit plan |
| Quality training needs analysis | Quality Manager + HR | Annual training plan |

---

## 2. NCR (Nonconformance Report) Workflow

```
Detection (anyone) → NCR Creation (QA) → Classification → Containment → RCA → CAPA → Verify → Close
```

### NCR Workflow Detail

**Step 1: Detection**
- Anyone can detect and report: operator, QA, customer, auditor
- Detection sources: inspection, test failure, customer complaint, audit finding, near-miss

**Step 2: NCR Creation (QA Analyst, within 24h of detection)**
- NCR Number (auto-generated: NCR-[YYYY]-[NNNN])
- Description: what was found, where, when, how much/many
- Classification: Critical / Major / Minor (see criteria below)
- Affected product/service/process identification
- Photo documentation attached

**NCR Classification Criteria:**

| Class | Criteria | Examples |
|-------|----------|---------|
| Critical | Safety hazard, regulatory violation, potential customer harm | Product recall trigger, safety incident |
| Major | Significant non-conformance, high-volume affected, customer impact | Systematic process failure, >100 units affected |
| Minor | Isolated incident, low impact, no customer impact | Single-unit defect, documentation error |

**Step 3: Immediate Containment (within 4h for Critical, 24h for Major)**
- Stop using/shipping nonconforming product
- Quarantine and label affected material
- Define containment scope (lot, date range, batch)
- Notify affected parties (downstream, customers if escaped)

**Step 4: Root Cause Analysis**
- Minimum tool: 5 Whys
- For Major/Critical: Fishbone diagram (6M)
- Output: identified root cause statement (not symptom)
- Timeline: Critical ≤ 48h; Major ≤ 7 days; Minor ≤ 14 days

**Step 5: CAPA Development → see CAPA workflow below**

**Step 6: Verification of Effectiveness**
- After corrective action implemented: verify defect does not recur
- Check period: 30 days (minor), 60 days (major), 90 days (critical)

**Step 7: NCR Closure**
- Quality Manager approves closure
- All evidence attached
- Lessons learned captured

---

## 3. CAPA Workflow

```
Trigger → CAPA Creation → RCA → Action Plan → Approval → Implementation → Verification → Closure
```

### CAPA Trigger Sources

| Source | Example |
|--------|---------|
| NCR (internal) | Production defect, inspection failure |
| Customer complaint | Customer returns, field failure |
| Audit finding | Internal or external audit NC |
| Process data | SPC out-of-control, trend deterioration |
| Near-miss | Incident that almost caused problem |
| Management review | Recurring issue identified in review |

### CAPA Template

```
CAPA Number    : [Auto: CAPA-[YYYY]-[NNNN]]
Date Opened    : [Date]
Initiated By   : [Name / Department]
Triggered By   : [NCR-XXXX / Audit CAR / Customer complaint ref]
Severity       : [Critical / Major / Minor]
Problem Stmt   : [Clear, measurable: What, Where, When, How many]

Root Cause Analysis:
  Method Used  : [5 Whys / Fishbone / Other]
  Root Cause   : [Root cause statement — must be specific, not "human error"]
  Evidence     : [What evidence confirms this is root cause]

Corrective Actions (eliminate root cause):
  Action 1     : [Specific action]  Owner: [Name]  Due: [Date]
  Action 2     : [Specific action]  Owner: [Name]  Due: [Date]

Preventive Actions (prevent recurrence elsewhere):
  Action       : [What systemic change prevents same issue in other areas]
  Owner        : [Name]  Due: [Date]

Effectiveness Criteria : [How will we know the CAPA worked?]
Verification Date      : [30/60/90 days after closure per severity]
Status                 : [Open / In Progress / Pending Verification / Closed]
Closure Date           : [Date]
Approved By            : [Quality Manager / Director per severity]
```

### CAPA Timing Standards

| Severity | Initial Response | RCA Complete | Action Plan Approved | Implementation | Effectiveness Check |
|---------|-----------------|-------------|---------------------|----------------|---------------------|
| Critical | 24 hours | 48 hours | 5 days | 30 days | 30 days post-close |
| Major | 3 days | 7 days | 14 days | 60 days | 60 days post-close |
| Minor | 7 days | 14 days | 21 days | 90 days | 90 days post-close |

---

## 4. Document Control

### Document Lifecycle

```
Draft → Review → Approval → Issue (effective) → Controlled Distribution → Review cycle → Obsolete
```

### Document Control Requirements

| Requirement | Detail |
|-------------|--------|
| **Document ID** | [TYPE]-[DEPT]-[NNN] (e.g., QP-QA-001 = Quality Procedure, QA dept) |
| **Revision numbering** | Rev 0 (initial), Rev 1, Rev 2... Or A, B, C... |
| **Approval authority** | Per type: Policy (Director), Procedure (Manager), WI (Process Owner + QA) |
| **Review cycle** | Minimum every 2 years, or when process changes |
| **Obsolete handling** | Stamp "OBSOLETE", retain for minimum required period, remove from active use |
| **Distribution** | Document master list shows who holds which documents |

### Document Types and Retention

| Document Type | Code | Approval | Retention |
|--------------|------|---------|-----------|
| Quality Manual / Policy | QM | Quality Director | Indefinite (current + last 2 versions) |
| Quality Procedures | QP | Quality Manager | 5 years after superseded |
| Work Instructions | WI | Process Owner + QA | 5 years after superseded |
| Inspection Checklists | IC | Quality Manager | Current + 1 previous version |
| Quality Records | QR | Per procedure | See mandatory records table |
| NCR Records | NCR | Quality Manager | 5 years minimum |
| CAPA Records | CAPA | Quality Director | 5 years minimum |
| Audit Reports | AR | Lead Auditor | 5 years minimum |
| Management Review | MR | Quality Director | 10 years |
| Calibration Records | CAL | Metrology | Equipment lifetime + 3 years |

---

## 5. Integration with Software Development

### Quality Gates in SDLC

| Phase | Gate | Quality Check | Authority |
|-------|------|---------------|-----------|
| Requirements | Gate 0 | Requirements completeness, measurability | QA Lead + Product Owner |
| Design | Gate 1 | FMEA reviewed, design standards followed | Quality Engineer |
| Development | Gate 2 | Code review done, unit test >80% coverage | Tech Lead |
| Testing | Gate 3 | No open critical defects, acceptance criteria met | QA Lead |
| Release | Gate 4 | Exit criteria met, stakeholder sign-off | Quality Director / Product Owner |
| Post-release | Monitor | Defect escape rate, production issues | QA Analyst |

### Defect Tracking → Quality Metrics Integration

```
Defect tracking tool (JIRA / GitHub Issues)
  → Tag with: [Severity], [Component], [Found at stage]
  → Export to Quality KPI system
    → Calculate: DPM per release, Defect Removal Efficiency, Test Coverage
    → Feed into: Quality Dashboard, Management Review inputs
```

### Release Quality Criteria (Exit Criteria)

| Criterion | Target |
|-----------|--------|
| Critical defects open | 0 |
| Major defects open | 0 (or approved exceptions with workaround) |
| Minor defects open | ≤ defined threshold (per product agreement) |
| Test case execution | ≥ 95% of planned test cases |
| Test pass rate | ≥ 98% |
| Performance benchmarks | Met (per NFR specification) |
| Security scan | No critical/high vulnerabilities open |
| Regression suite | 100% pass |
