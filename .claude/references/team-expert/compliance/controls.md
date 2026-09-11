# Compliance Controls Reference

> Reference file cho compliance-expert agent
> Load file này khi cần thiết kế controls trong domain Compliance

## Internal Control Framework

### COSO Components

| Component | Description | Key Elements |
|-----------|-------------|--------------|
| Control Environment | Foundation of controls | Tone at top, integrity, competence |
| Risk Assessment | Identify and analyze risks | Objectives, risk identification, analysis |
| Control Activities | Policies and procedures | Authorizations, reconciliations, segregation |
| Information & Communication | Quality information | Systems, reporting, communication |
| Monitoring | Ongoing evaluation | Ongoing monitoring, separate evaluations |

---

## Control Types

### By Function

| Type | Description | Examples |
|------|-------------|----------|
| Preventive | Prevent errors/fraud before occurrence | Access controls, approvals |
| Detective | Identify errors/fraud after occurrence | Reconciliations, audits, monitoring |
| Corrective | Fix identified issues | Incident response, retraining |
| Directive | Guide behavior toward objectives | Policies, training, incentives |

### By Automation Level

| Type | Description | Reliability |
|------|-------------|-------------|
| Manual | Human-performed | Variable |
| IT-dependent | Manual using system data | Moderate |
| Automated | System-enforced | High |
| Semi-automated | System + human review | High |

---

## Common Control Activities

### Authorization Controls

| Control | Purpose | Implementation |
|---------|---------|----------------|
| Approval limits | Ensure appropriate authority | Threshold-based workflow |
| Dual approval | Segregation of duties | Two-person rule |
| System access | Limit access to authorized users | Role-based access control |
| Transaction approval | Verify legitimacy before processing | Workflow with escalation |

### Segregation of Duties (SoD)

| Function | Must Be Separate From |
|----------|----------------------|
| Authorization | Custody, Recording |
| Custody | Authorization, Recording |
| Recording | Authorization, Custody |

**Common SoD Matrix:**

| Role | Create | Approve | Execute | Record | Reconcile |
|------|--------|---------|---------|--------|-----------|
| Requester | ✓ | ✗ | ✗ | ✗ | ✗ |
| Approver | ✗ | ✓ | ✗ | ✗ | ✗ |
| Processor | ✗ | ✗ | ✓ | ✓ | ✗ |
| Reviewer | ✗ | ✗ | ✗ | ✗ | ✓ |

### Reconciliation Controls

| Type | Frequency | Purpose |
|------|-----------|---------|
| Bank reconciliation | Daily/Weekly | Cash accuracy |
| Account reconciliation | Monthly | GL accuracy |
| Inventory count | Periodic | Stock accuracy |
| Inter-company | Monthly | Elimination accuracy |

---

## Control Documentation

### Control Description Template

```
Control ID: C-[Process]-[Number]
Control Name: [Descriptive name]
Process: [Business process]
Objective: [What the control achieves]
Type: Preventive/Detective
Frequency: [How often performed]
Owner: [Responsible role]
Procedure:
  1. [Step 1]
  2. [Step 2]
  3. [Step 3]
Evidence: [What proves control was performed]
Exception Handling: [What happens when control fails]
```

### Example Control

```
Control ID: C-AP-001
Control Name: Three-Way Match
Process: Accounts Payable
Objective: Ensure payments are made only for authorized, received goods
Type: Preventive
Frequency: Per transaction
Owner: AP Supervisor
Procedure:
  1. System compares PO quantity/price to invoice
  2. System compares goods receipt to invoice
  3. Match within tolerance → auto-approve
  4. Mismatch → hold for review
Evidence: System match report, approval log
Exception Handling: Manual review, escalation to buyer
```

---

## Control Testing

### Testing Methods

| Method | Description | When to Use |
|--------|-------------|-------------|
| Inquiry | Ask about control | Initial understanding |
| Observation | Watch control being performed | Operational controls |
| Inspection | Examine evidence | Documentation-based controls |
| Reperformance | Execute control yourself | Verify accuracy |

### Sample Sizes

| Population | Sample Size |
|------------|-------------|
| < 25 | Test all |
| 25-100 | 25 |
| 101-500 | 50 |
| 501-1,000 | 75 |
| > 1,000 | 100 |

### Deficiency Classification

| Rating | Criteria | Action |
|--------|----------|--------|
| Material Weakness | Reasonable possibility of material misstatement | Immediate remediation, disclose |
| Significant Deficiency | Less than material but important | Priority remediation |
| Control Deficiency | Minor issue | Remediate in normal course |

---

## Control Monitoring

### Continuous Monitoring Controls

| Area | Control | Alert Condition |
|------|---------|-----------------|
| Access | Failed login attempts | > 5 failures |
| Transactions | Duplicate payments | Same amount, vendor, date |
| Data | Data changes | Unauthorized modifications |
| Compliance | Policy violations | Threshold breaches |

### Key Control Indicators (KCIs)

| KCI | Target | Frequency |
|-----|--------|-----------|
| Control effectiveness rate | > 95% | Monthly |
| Control testing coverage | 100% | Annual |
| Open deficiencies | < 10 | Monthly |
| Remediation on-time | > 90% | Monthly |
| Control exceptions | < 1% | Daily |

---

## Control Framework by Process

### Financial Controls

| Process | Key Controls |
|---------|--------------|
| Revenue | Credit approval, shipment authorization, invoice accuracy |
| Purchasing | PO approval, three-way match, vendor master changes |
| Treasury | Bank account changes, payment approval, cash count |
| Financial Close | Account reconciliation, journal entry review, variance analysis |

### IT Controls

| Domain | Key Controls |
|--------|--------------|
| Access | User provisioning, access reviews, privileged access |
| Change | Change approval, testing, deployment |
| Operations | Backup, monitoring, incident management |
| Security | Vulnerability scanning, patching, encryption |

### Compliance Controls

| Area | Key Controls |
|------|--------------|
| Regulatory | License tracking, reporting calendar, regulatory monitoring |
| Policy | Policy acknowledgment, training completion, exception tracking |
| Privacy | Consent management, data subject requests, retention |
