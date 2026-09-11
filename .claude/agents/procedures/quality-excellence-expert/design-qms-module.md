# Procedure: Design Quality Management System Module

> **Type**: Agent Procedure
> **Agent**: quality-excellence-expert
> **Triggered when**: wf-design phase — thiết kế QMS module, quality dashboard, quality workflow
> **Output**: Data model, API specifications, workflow diagrams, dashboard specs

---

## Khi nào dùng procedure này

- Skill `wf-design` gọi quality-excellence-expert để thiết kế QMS module
- Có REQ-QMS-* requirements từ Phase 2 cần chuyển thành technical design
- Cần thiết kế: NCR/CAPA system, quality dashboard, FMEA module, audit management

---

## Procedure

### Bước 1: Đọc feature specs và architecture context

Đọc REQ-QMS-* specs từ phase2-features và architecture context từ phase3-architecture (nếu có).

Xác định:
- Modules trong scope: NCR? CAPA? Audit? Document Control? FMEA? KPI Dashboard?
- Technical stack đã chọn (backend framework, database type)
- Integration requirements: ERP, JIRA, Slack, email cho notifications?

### Bước 2: Thiết kế core QMS data model

READ `.claude/references/team-expert/quality-excellence/iso-9001.md`

Từ mandatory records (Section 2), thiết kế core entities:

```
Core Entities:
  Nonconformance (NCR)
    - id, ncr_number, title, description
    - classification: ENUM(critical, major, minor)
    - detection_source: ENUM(inspection, audit, customer, near_miss, process_data)
    - status: ENUM(open, contained, rca_pending, capa_linked, pending_verify, closed)
    - detected_at, detected_by, location, affected_quantity
    - photos: attachment array
    - capa_id: FK → CAPA

  CAPA (Corrective/Preventive Action)
    - id, capa_number, title, type: ENUM(corrective, preventive)
    - severity: ENUM(critical, major, minor)
    - trigger_source: FK to NCR / Audit Finding / Customer Complaint
    - problem_statement, root_cause_method, root_cause_description
    - status: ENUM(open, rca_done, plan_approved, in_progress, pending_verify, closed, ineffective)
    - due_date, closed_date
    - effectiveness_criteria, effectiveness_check_date
    - actions: [{ action_desc, owner_id, due_date, status, evidence }]

  AuditProgram
    - id, year, audit_schedule: [AuditEvent]

  AuditEvent
    - id, program_id, scope, auditor_ids, auditee_department
    - planned_date, actual_date, status
    - findings: [AuditFinding]

  AuditFinding
    - id, event_id, finding_type: ENUM(observation, minor_nc, major_nc)
    - description, iso_clause, evidence
    - car_id: FK → CAPA (for NC findings)

  QualityDocument
    - id, doc_number, title, type, version, revision
    - status: ENUM(draft, review, approved, issued, obsolete)
    - approved_by, effective_date, review_date
    - file_attachment

  QualityObjective
    - id, title, target_value, unit, measurement_frequency
    - responsible_id, reporting_period
    - actuals: [{ period, actual_value, status }]
```

### Bước 3: Thiết kế FMEA module (nếu trong scope)

READ `.claude/references/team-expert/quality-excellence/fmea.md`

Từ PFMEA Template (Section 3):

```
FMEA Entities:
  FMEARegister
    - id, title, type: ENUM(dfmea, pfmea, sfmea)
    - product_or_process, revision, review_date
    - owner_id, status: ENUM(draft, active, under_review, archived)

  FMEAEntry (one row = one failure mode)
    - id, fmea_id
    - process_step, failure_mode, failure_effect
    - severity (S): 1-10
    - failure_cause
    - occurrence (O): 1-10
    - current_controls
    - detection (D): 1-10
    - rpn: computed (S × O × D)
    - action_required: computed (RPN >= 100 OR S >= 9)
    - recommended_action, risk_owner_id, target_date
    - action_taken, new_severity, new_occurrence, new_detection, new_rpn
    - status: ENUM(open, in_progress, verified, accepted_risk)
```

Business rule: `rpn = severity × occurrence × detection` computed server-side.
Trigger: khi rpn >= 100 OR severity >= 9 → `action_required = true` → risk_owner_id required.

### Bước 4: Thiết kế quality gate và approval workflow

READ `.claude/references/team-expert/quality-excellence/controls.md`

Từ Gate Sign-off Matrix (Section 1) và Disposition Authority (Section 3):

```
API Endpoints — Approval workflows:

  CAPA approval workflow:
    POST /api/qms/capa/{id}/approve-rca        — QA Manager approve root cause
    POST /api/qms/capa/{id}/approve-action-plan — QA Manager approve action plan
    POST /api/qms/capa/{id}/submit-effectiveness — Owner submit effectiveness evidence
    POST /api/qms/capa/{id}/close               — Quality Manager close

  NCR disposition:
    POST /api/qms/ncr/{id}/disposition          — body: { disposition, justification, approved_by }
    Validation: disposition = "use_as_is" requires role = quality_manager or above

  Gate sign-off:
    POST /api/qms/gates/{gate_id}/sign-off      — body: { signer_role, outcome, comments }
    Business rule: each gate has required_signers list; gate = PASS when all sign
```

### Bước 5: Thiết kế KPI dashboard data model

READ `.claude/references/team-expert/quality-excellence/quality-metrics.md`

Từ KPI Master Table và Dashboard Layout (Section 5):

```
KPI Aggregation (computed, not stored raw):
  - ncr_closure_rate_on_time: COUNT(closed_on_time) / COUNT(total_closed) per period
  - capa_effectiveness_rate: COUNT(no_recurrence) / COUNT(verified_closed) per rolling 90d
  - audit_completion_rate: COUNT(completed) / COUNT(planned) per program year
  - open_ncr_count_by_age: GROUP BY age bucket (0-7d, 8-14d, 15-30d, >30d)

Dashboard API:
  GET /api/qms/dashboard/summary        — KPI tiles
  GET /api/qms/dashboard/ncr-aging      — NCR aging chart data
  GET /api/qms/dashboard/capa-status    — CAPA status distribution
  GET /api/qms/dashboard/top-defects    — Pareto data (top defect types)
  GET /api/qms/dashboard/audit-schedule — Upcoming audits calendar
```

### Bước 6: Finalize và produce design outputs

Produce:
1. **Entity Relationship Diagram** (text-based): tất cả entities + relationships
2. **API specification**: endpoints, methods, request/response format cho core workflows
3. **Workflow diagrams**: NCR workflow, CAPA workflow (sequence steps + actors)
4. **Dashboard wireframe spec**: panels, KPI tiles, chart types, data sources

### Checklist trước khi submit

- [ ] NCR ↔ CAPA link (1 NCR có thể trigger 1 CAPA; CAPA có reference về trigger source)
- [ ] FMEA RPN computation là server-side (không để client compute)
- [ ] Threshold automation: RPN ≥ 100 → flag action_required, require risk_owner
- [ ] Disposition authority enforced: use-as-is requires Quality Manager role
- [ ] Document version control: version number increments on each approved revision
- [ ] All notification triggers defined: overdue NCR, CAPA due date, gate pending sign-off
- [ ] Audit trail: created_by, created_at, updated_by, updated_at on all entities
