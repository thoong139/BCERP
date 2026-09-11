# Quality Excellence - Controls & Authorization

> **Domain**: Quality Excellence / Quality Gates, Inspection Authority & Sign-off Matrix
> **Last Updated**: 2026-03-22
> **Nguồn**: ISO 9001:2015 Clause 8.6, 8.7, 10.2; AIAG standards; industry practice

---

## 1. Quality Gate Framework

Quality Gates là checkpoints chính thức — production/release DỪNG cho đến khi gate criteria được xác nhận.

### Software/Product Quality Gates

| Gate | Phase | Entry Criteria | Exit Criteria | Sign-off Authority |
|------|-------|---------------|---------------|-------------------|
| **Gate 0** | Requirements → Design | Approved requirements | Quality checklist: complete, measurable, no contradictions | QA Lead + Product Owner |
| **Gate 1** | Design → Build | Gate 0 passed | FMEA reviewed, design standards met, risk addressed | Quality Engineer + Architect |
| **Gate 2** | Build → Test | Gate 1 passed | Code review complete, unit tests ≥ 80%, no critical compiler warnings | Tech Lead + QA Lead |
| **Gate 3** | Test → Release | Gate 2 passed | 0 critical defects open, test execution ≥ 95%, regression pass 100% | QA Lead (major defects: Director) |
| **Gate 4** | Release → Production | Gate 3 passed | Stakeholder sign-off, deployment checklist complete, rollback plan ready | Quality Director + Product Owner |

### Gate Sign-off Matrix

| Gate | QA Analyst | QA Lead | Quality Manager | Quality Director | Product Owner | Tech Lead |
|------|:----------:|:-------:|:---------------:|:----------------:|:-------------:|:---------:|
| Gate 0 | Review | **Sign** | Inform | — | **Sign** | Review |
| Gate 1 | Review | **Sign** | Inform | — | Inform | **Sign** |
| Gate 2 | **Sign** | **Sign** | — | — | — | **Sign** |
| Gate 3 | Review | **Sign** | Escalation only | Escalation only | **Sign** | — |
| Gate 4 | — | **Sign** | Review | **Sign** | **Sign** | — |

**Gate escalation rule**: Nếu gate criteria không đạt mà vẫn muốn proceed → escalate một cấp, đưa ra written risk acceptance, document trong deviation log.

---

## 2. Inspection and Testing Authority

### Inspection Types and Authority

| Inspection Type | Triggered By | Performed By | Accept/Reject Authority | Re-inspection After Fail |
|-----------------|-------------|-------------|------------------------|--------------------------|
| Incoming inspection | Receiving | QA Analyst | QA Analyst (per criteria) | QA Analyst |
| First Article Inspection (FAI) | New supplier, new part | Quality Engineer | Quality Engineer | Mandatory |
| In-process inspection | Per control plan | QA Analyst / Operator | QA Analyst | QA Analyst |
| Final inspection | Before ship/release | QA Analyst | Quality Manager (for deviations) | QA Lead |
| Skip-lot inspection | Qualified supplier | Per sampling plan | QA Analyst | Full inspection triggered |

### First Article Inspection (FAI) Requirements

FAI bắt buộc khi:
- New supplier hoặc new part number
- Engineering change (design or specification)
- Production break > 12 months
- Transfer from another manufacturing site
- Change of material or manufacturing process

FAI sign-off: Quality Engineer + Design Engineer (for design characteristics).

### Skip-Lot Inspection Criteria

Supplier được skip-lot inspection khi:
- Minimum 12 consecutive acceptable lots
- No major NCRs in last 6 months
- Supplier quality score ≥ 90%
- Formal skip-lot agreement in place

Skip-lot suspension triggered by:
- Any major NCR from that supplier
- Customer complaint traceable to that supplier
- Supplier quality score drops below 80%

---

## 3. Disposition Authority for Nonconformances

### NCR Disposition Options

| Disposition | Definition | Approval Required | Conditions |
|------------|------------|-------------------|-----------|
| **Use As-Is** | Accept nonconforming item without rework | Quality Manager | Minor deviation, form/fit/function not affected |
| **Rework** | Return to specification through defined process | Per procedure + re-inspect | Re-inspection mandatory before release |
| **Repair** | Not to specification but functional | Quality Manager + Engineering | Customer notification may be required |
| **Reject / Scrap** | Dispose; not for intended use | QA + Operations | Record for CoQ — scrap cost tracking |
| **Return to Supplier** | Supplier NCR — return for replacement | QA + Procurement | Supplier NCR issuance required |
| **Customer Deviation Request** | Ship nonconforming with customer approval | Customer + QA + Engineering | Written customer approval mandatory |

### Escaping Defect Escalation (Defect reaches customer)

```
Defect reported by customer
  ↓
QA Analyst: Create NCR + Initial containment within 4h
  ↓
Quality Manager: notified within 4h, assess severity
  ↓
If Major/Critical → Quality Director within 24h
  ↓
If recall trigger → CEO escalation + legal within 24h
  ↓
Customer notification: within 24h (Critical) / 72h (Major) / 7 days (Minor)
  ↓
CAPA opened: Critical → 24h; Major → 3 days
```

### Use-As-Is Authorization Limits

| Deviation Type | Authorized By | Limit |
|---------------|---------------|-------|
| Minor dimensional out-of-tolerance (form only) | Quality Manager | Up to 5% beyond tolerance |
| Cosmetic defect (no functional impact) | Quality Manager | Per visual standard |
| Documentation error (no physical defect) | QA Lead | Administrative correction only |
| Any functional deviation | Quality Director + Customer | Written deviation required |
| Safety-critical parameter deviation | NEVER use-as-is | Scrap or customer deviation only |

---

## 4. Quality Document Approval Authority

| Document Type | Author | Reviewer | Approver | Re-approval Trigger |
|--------------|--------|----------|---------|---------------------|
| Quality Policy | Quality Director draft | Management Team | CEO / Top Management | Annual or strategic change |
| Quality Manual | Quality Manager | Quality Director | Quality Director | Major scope change |
| Quality Procedures (QP) | Process Owner / QA | Quality Manager | Quality Director | Every revision |
| Work Instructions (WI) | Process Owner | QA Analyst | Process Owner + Quality Manager | Every revision |
| Inspection Checklists | QA Analyst | Quality Manager | Quality Manager | Every revision |
| FMEA | Quality/Process Engineer | Quality Manager | Quality Manager | Per FMEA review schedule |
| Control Plan | Quality Engineer | Quality Manager | Quality Manager + Engineering | Per change control |
| Audit Program | Lead Auditor | Quality Manager | Quality Director | Annual |

**Principle**: No document goes into use without documented approval. Electronic approval acceptable with audit trail.

---

## 5. Audit Escalation Protocol

### Internal Audit Findings Escalation

| Finding Type | Escalation Path | Timeline | Required Action |
|-------------|-----------------|---------|----------------|
| Observation | Auditee → Action (voluntary) | No mandatory deadline | Voluntary improvement |
| Minor NC | Auditee → Quality Manager review | CAR: 30 days | Root cause + corrective action |
| Major NC | Quality Manager → Quality Director within 24h | CAR: 7-14 days | Immediate CAPA, systemic review |
| Repeat Major NC (same clause) | Quality Director → CEO | Immediate | Mandatory systemic review, may affect certification |

### External Audit (ISO 9001 Certification) Escalation

| Scenario | Action | Timeline |
|---------|--------|---------|
| Observation from registrar | Voluntary improvement plan | Before next surveillance |
| Minor NC from registrar | CAPA submitted to registrar | 30 days |
| Major NC from registrar | CAPA submitted + CEO aware | 7-14 days; may require follow-up audit |
| Multiple major NCs | CEO escalation + emergency management review | Immediate; certification at risk |
| Repeat major NC (same clause) | Mandatory systemic audit + board awareness | Immediate |

### Audit Confidentiality Rules

- Audit findings shared with: Auditee, Quality Director, Top Management (if Major NC)
- NOT shared with: customers (without management approval), competitors, public
- Audit records retained: minimum 5 years per ISO 9001 Clause 9.2
- Auditor independence: auditor KHÔNG được audit process mình own/manage

---

## 6. Access Control Matrix for Quality System

| Role | Quality Policy | NCR Create | NCR Close | CAPA Approve | FMEA Edit | Audit Report | Document Approve | KPI Dashboard |
|------|:--------------:|:----------:|:---------:|:------------:|:---------:|:------------:|:----------------:|:-------------:|
| Quality Director | Edit | View | View | Final (Critical) | Approve | View all | Full | Full |
| Quality Manager | View | View | Approve | Approve (Major) | Edit | Edit | Most types | Full |
| Quality Engineer | View | Create | — | Initiate | Edit | View own | Work Instructions | View |
| QA Analyst | View | Create | — | Initiate | View | View own | Draft only | Limited |
| Process Owner | View | Create | — | Own scope | Own scope | View own process | Own WIs | Own process |
| Internal Auditor | View | Create (audit) | — | View | View | Edit own | View | View |
| Black Belt | View | View | — | Advisory | Edit | View | View | Full |
| Operations Staff | — | Report only | — | — | View only | — | — | — |
