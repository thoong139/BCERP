# Procedure: Design ERM System Module

> **Type**: Agent Procedure
> **Agent**: enterprise-risk-expert
> **Triggered when**: wf-design phase với ERM / GRC / Risk Management module trong feature specs
> **Output**: Data model, API specs, dashboard wireframe, module architecture notes

---

## Khi nào dùng procedure này

Khi `wf-design` invoke `enterprise-risk-expert` để thiết kế technical architecture cho
risk management module. Phải có REQ-RISK-* specs từ phase2 làm input.

Dấu hiệu nhận biết: feature specs bao gồm risk register, KRI system, risk committee workflow,
RCSA module, BCP management, risk reporting dashboard.

---

## Procedure

### Bước 1: Đọc feature specs và architecture context

```
INPUT:
□ Feature specs từ .mc-data/docs/phase2-features/ — REQ-RISK-* requirements
□ Architecture context từ .mc-data/docs/phase3-architecture/ (nếu đang build incrementally)
□ req-registry.json — xác nhận modules/features trong scope

Xác định:
□ ERM module nào cần design: Risk Register / KRI / Governance / Reporting / BCP / Incident?
□ Integration requirements: Finance system, HR system, IT monitoring feeds?
□ Tech stack đã quyết định (từ architecture phase)?
□ User volume: số lượng Risk Owners, số risks expected?
```

### Bước 2: Xác định risk hierarchy và scoring engine

```
READ: .claude/references/team-expert/enterprise-risk/erm-framework.md
→ Risk categories (7 types), risk appetite framework, COSO vs ISO alignment

Design risk data hierarchy:
RiskUniverse → RiskCategory → Risk → RiskAssessment → RiskTreatment → Control

Scoring engine spec:
□ Inherent risk score = Likelihood (1-5) × Impact (1-5) = 1-25
□ Residual risk score = Inherent score adjusted by control effectiveness
□ Velocity field: Rapid / Moderate / Slow → affects response playbook
□ Risk rating band: Low(1-6) / Medium(7-12) / High(13-19) / Critical(20-25)
□ Support cho cả COSO ERM categories và ISO 31000 — configurable taxonomy

READ: .claude/references/team-expert/enterprise-risk/risk-assessment.md
→ 5×5 matrix values, velocity definitions, KRI threshold setting methodology
```

### Bước 3: Design KRI monitoring system

```
READ: .claude/references/team-expert/enterprise-risk/risk-assessment.md → KRI Design section

KRI data model:
□ KRI definition: name, description, risk_id, indicator_type (leading/lagging), unit
□ KRI threshold: kri_id, green_max, amber_max, red_min (Green < Amber < Red)
□ KRI reading: kri_id, value, timestamp, data_source, status (green/amber/red)
□ KRI alert: kri_id, triggered_at, status, assignee, resolved_at

Architecture decisions:
□ Real-time vs scheduled KRI feeds — depends on data source
□ Manual entry vs automated API integration
□ Alert delivery: email, in-app notification, SMS (for Critical)
□ Alert escalation chain: Amber → Risk Manager; Red → CRO trong 4h
```

### Bước 4: Design governance và workflow layer

```
READ: .claude/references/team-expert/enterprise-risk/risk-governance.md
→ Three Lines of Defense, RCSA workflow, escalation paths, Risk Appetite Statement

Role-based access design (Three Lines of Defense mapping):
□ Line 1 (Business Owner): Own risks + RCSA + incident log + action plan update
□ Line 2 (Risk Manager/CRO): Full read + risk scoring + framework management + reports
□ Line 3 (Internal Auditor): Read-only risk register + control testing results + findings

RCSA workflow states:
SCHEDULED → IN_PROGRESS → SUBMITTED → UNDER_REVIEW → SIGNED_OFF → ARCHIVED

Risk status workflow:
IDENTIFIED → ASSESSED → TREATMENT_PLANNED → TREATMENT_IN_PROGRESS → MONITORED → CLOSED

Approval workflow cho High/Critical risks:
Risk Owner submits → Risk Manager reviews → CRO approves → Committee notified

Escalation engine:
□ KRI breach Red → auto-assign action → notify Risk Owner + Risk Manager
□ Action overdue 15+ days → escalate to Risk Owner's manager
□ Critical risk (score 20+) → Board Risk Committee notification trigger
```

### Bước 5: Design control library và treatment tracking

```
READ: .claude/references/team-expert/enterprise-risk/controls.md
→ Control types (Preventive/Detective/Corrective), effectiveness ratings, SMART action plans

Control data model:
□ Control: id, name, description, type (preventive/detective/corrective), nature (manual/automated/semi)
□ ControlOwner: control_id, owner_id, assigned_date
□ RiskControl: risk_id, control_id, effectiveness (effective/partial/ineffective), last_tested
□ ControlTest: control_id, test_date, tester_id, procedure, result, exceptions_count, finding
□ RiskTreatment: risk_id, option (avoid/reduce/transfer/accept/exploit), plan, deadline, owner, status
□ ActionPlan: risk_id, treatment_id, action, owner, deadline, progress, status, last_updated

Action plan tracking triggers:
□ 7 days before deadline → reminder notification
□ On deadline if incomplete → overdue alert
□ 15 days overdue → escalation
```

### Bước 6: Output artifacts

**Data Model (key tables):**
```sql
-- Core risk tables
Risk           (id, title, description, category_id, velocity, inherent_score,
                residual_score, risk_rating, owner_id, status, created_at, updated_at)
RiskCategory   (id, name, code, framework_ref)  -- 7 ERM categories
RiskAssessment (id, risk_id, likelihood, impact, score, assessed_by, assessed_at, notes)
RiskTreatment  (id, risk_id, option, description, owner_id, deadline, status)
ActionPlan     (id, risk_id, treatment_id, action, owner_id, deadline, progress, status)

-- KRI tables
KRI            (id, name, unit, indicator_type, risk_id, data_source)
KRIThreshold   (id, kri_id, green_max, amber_max, red_min)
KRIReading     (id, kri_id, value, timestamp, status, source)
KRIAlert       (id, kri_id, reading_id, triggered_at, assignee_id, resolved_at)

-- Control tables
Control        (id, name, type, nature, description, owner_id, effectiveness)
RiskControl    (risk_id, control_id, is_key_control, last_tested, test_result)
ControlTest    (id, control_id, test_date, tester_id, result, exceptions_count)

-- Governance tables
RCSA           (id, business_unit_id, period, status, facilitator_id, signed_off_by)
RiskCommittee  (id, name, type, meeting_frequency)
CommitteeMeeting (id, committee_id, date, agenda, minutes, decisions)
RiskAppetite   (id, category_id, appetite_level, tolerance_threshold, effective_date)
```

**API Design:**
```
Risk Register APIs:
  GET    /risks                    → list với filters (category, status, score range)
  POST   /risks                    → create risk
  PUT    /risks/:id/assess         → update assessment scores
  PUT    /risks/:id/status         → workflow transition
  GET    /risks/:id/history        → full audit trail

KRI APIs:
  GET    /kris                     → list KRIs với current status
  POST   /kris/:id/readings        → submit KRI reading
  GET    /kris/alerts              → active alerts requiring action
  PUT    /kris/alerts/:id/resolve  → resolve alert

Reporting APIs:
  GET    /reports/heat-map         → risk matrix data for visualization
  GET    /reports/top-risks        → top 10 risks với full details
  GET    /reports/board-report     → quarterly board report data
  GET    /reports/kri-dashboard    → KRI status summary
  POST   /reports/export           → generate PDF/Excel report
```

**Dashboard Wireframe (Executive View — key sections):**
```
Sections: [KPI bar: Critical N / High N / KRI Breaches N]
         [Risk Heat Map 5×5 — clickable cells → drill-down]
         [Top 5 Risks — rank, name, score, owner, trend]
         [Overdue Actions count] [KRI Trend: ↑/→/↓]
```

### Bước 7: Checklist trước khi submit design

```
□ Data model normalized (3NF minimum), audit trail fields (created_at, updated_at, created_by)
□ Risk scoring logic đúng: likelihood × impact, velocity field included
□ KRI threshold logic: Green < Amber < Red, alert trigger clear
□ Role-based access aligned với Three Lines of Defense
□ Approval workflow cho High/Critical risks có in design
□ Audit trail cho mọi risk status changes (immutable log, không soft delete)
□ All REQ-RISK-* features từ phase2 đã có corresponding design elements
□ Integration APIs với Finance/IT/HR data feeds đã được spec
□ Report generation covers: heat map, top risks, KRI dashboard, board report
```
