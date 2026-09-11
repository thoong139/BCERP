# HR Domain - Controls & Access Management

> **Domain**: Human Resources / Quản trị Nhân sự
> **Last Updated**: 2026-03-07
> **CRITICAL**: HR data contains PII - strict access control required

---

## 1. Data Access Control Matrix

### Employee Data Classification

| Data Type | Classification | Access Level |
|-----------|----------------|--------------|
| Name, Position | Internal | All employees (view) |
| Contact Info | Internal | Manager, HR |
| Salary, Benefits | **Confidential** | HR Manager+, Employee (own) |
| Performance Reviews | Confidential | Manager chain, HR |
| Disciplinary Records | **Restricted** | HR Manager+, Legal |
| Medical Info | **Highly Restricted** | HR Manager only |

### Access by Role

| Data Category | Employee | Manager | HR Admin | HR Manager | HR Director |
|---------------|:--------:|:-------:|:--------:|:----------:|:-----------:|
| Own Profile | ✅ View/Edit | ✅ View/Edit | ✅ View/Edit | ✅ Full | ✅ Full |
| Own Salary | ✅ View | ✅ View | ❌ | ✅ View | ✅ Full |
| Team Profiles | ❌ | ✅ View | ✅ View | ✅ Full | ✅ Full |
| Team Salaries | ❌ | ⚠️ Budget only | ❌ | ✅ View | ✅ Full |
| All Salaries | ❌ | ❌ | ❌ | ⚠️ Limited | ✅ Full |
| Recruitment | ❌ | ⚠️ Own team | ✅ Support | ✅ Full | ✅ Full |
| Reports | ❌ | ⚠️ Team only | ✅ Generate | ✅ Full | ✅ Full |

---

## 2. PII Classification & Protection

### PII Categories

| Category | Data Elements | Protection Required |
|----------|---------------|---------------------|
| **Standard PII** | Name, Employee ID, Position | Encryption at rest |
| **Sensitive PII** | Address, Phone, Email | Encryption at rest + transit |
| **Financial PII** | Salary, Bank Account, Tax ID | Encryption + Access logging |
| **Health PII** | Medical records, Insurance claims | Encryption + Restricted access |

### Data Handling Rules

| Action | Standard PII | Sensitive PII | Financial PII | Health PII |
|--------|:------------:|:-------------:|:-------------:|:----------:|
| View | Per role matrix | Per role matrix | HR Manager+ only | HR Manager only |
| Edit | Owner + HR Admin | Owner + HR Admin | HR Manager+ | HR Manager |
| Export | ❌ | ❌ | ❌ | ❌ |
| Delete | ❌ (Archive only) | ❌ (Archive only) | ❌ (Archive only) | ❌ (Archive only) |

---

## 3. Approval Workflows

### Employee Status Changes

| Action | Initiator | Approver 1 | Approver 2 | Documentation |
|--------|----------|------------|------------|---------------|
| New Hire | Recruiter | HR Manager | Department Head (budget) | Contract, Offer letter |
| Promotion | Manager | HR Manager | Department Head | Performance review |
| Transfer | Manager (sending) | Manager (receiving) | HR Manager | Transfer request |
| Salary Change | Manager | HR Manager | Finance (budget) | Compensation review |
| Termination | Manager | HR Manager | Legal (if needed) | Exit documents |

### Leave Approvals

| Leave Type | Duration | Approver 1 | Approver 2 |
|------------|----------|------------|------------|
| Annual Leave | ≤3 days | Manager | - |
| Annual Leave | 4-14 days | Manager | HR Admin |
| Annual Leave | >14 days | Manager | HR Manager |
| Sick Leave | ≤3 days | Manager (notification) | - |
| Sick Leave | >3 days | Manager | HR Admin (medical cert) |
| Unpaid Leave | Any | Manager | HR Manager |

### Recruitment Approvals

| Action | Initiator | Approver |
|--------|----------|----------|
| Create Job Requisition | Manager | HR Manager |
| Approve Job Requisition | HR Manager | Finance (budget) |
| Extend Offer | Recruiter | HR Manager + Manager |
| Approve Offer (>20% premium) | HR Manager | HR Director + Finance |

---

## 4. Segregation of Duties (SoD)

### Critical SoD Rules

| Task A | Task B | Conflict Level | Allowed? |
|--------|--------|:--------------:|:--------:|
| Create Employee Record | Approve Own Salary | **Critical** | ❌ |
| Input Time Sheet | Approve Own Time Sheet | High | ❌ |
| Create Requisition | Approve Requisition | High | ❌ |
| Input Performance Rating | Calibrate Own Team | Medium | ⚠️ Review |
| Process Payroll | Approve Payroll | **Critical** | ❌ |

### SoD Matrix by Role

| Function | HR Admin | HR Manager | Recruiter | Manager |
|----------|:--------:|:----------:|:---------:|:-------:|
| Create Employee | ✅ | ✅ | ❌ | ❌ |
| Approve Employee | ❌ | ✅ | ❌ | ✅ (budget) |
| Input Salary | ❌ | ✅ | ❌ | ❌ |
| Approve Salary | ❌ | ❌ | ❌ | ❌ (Finance) |
| Create Requisition | ✅ Support | ✅ | ✅ | ✅ |
| Approve Requisition | ❌ | ✅ | ❌ | ✅ |
| Process Payroll | ✅ | ❌ | ❌ | ❌ |
| Approve Payroll | ❌ | ✅ Review | ❌ | ❌ |

---

## 5. Audit Trail Requirements

### Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Employee Create | User, Timestamp, All fields, Source | 7 years after termination |
| Employee Update | User, Timestamp, Field, Old→New, Reason | 7 years after termination |
| Salary Change | User, Timestamp, Old→New, Approver, Reason | 10 years |
| Status Change | User, Timestamp, Old→New, Effective date | 7 years after termination |
| Access Sensitive Data | User, Timestamp, Data accessed, Purpose | 3 years |
| Export Data | User, Timestamp, Data exported, Format | 5 years |

### Log Format

```json
{
  "event_type": "SALARY_CHANGE",
  "timestamp": "2024-01-15T10:30:00Z",
  "user_id": "hr_manager_001",
  "employee_id": "EMP12345",
  "old_value": "50000000",
  "new_value": "55000000",
  "approver": "hr_director_001",
  "reason": "Annual review - exceeds target",
  "effective_date": "2024-02-01"
}
```

---

## 6. Period Controls

### Monthly

| Control | Trigger | Enforcement |
|---------|---------|-------------|
| Payroll cutoff | Last day of month | System lock after run |
| Leave accrual | Month-end | Auto-calculate |
| New hire probation tracking | Monthly | Alert to HR |

### Quarterly

| Control | Trigger | Enforcement |
|---------|---------|-------------|
| Headcount report | Q-end | Auto-generate |
| Training compliance check | Q-end | Alert to Managers |

### Annual

| Control | Trigger | Enforcement |
|---------|---------|-------------|
| Performance review cycle | Q4 | Workflow initiation |
| Salary review cycle | Q1 | Budget allocation |
| Contract renewal check | Annual | Alert 60 days before |
| Compliance audit | Annual | Document retention check |

---

## 7. Compliance Requirements

### Vietnamese Labor Law

| Requirement | System Enforcement |
|-------------|-------------------|
| Working hours (max 48h/week) | Overtime tracking, alerts |
| Annual leave (min 12 days) | Leave balance calculation |
| Social insurance (BHXH) | Auto-calculation, reporting |
| Probation period limits | Contract type validation |
| Termination notice | Workflow enforcement |

### Data Privacy (PDP Bill)

| Requirement | System Enforcement |
|-------------|-------------------|
| Consent for data collection | Consent tracking |
| Right to access | Self-service portal |
| Right to rectification | Edit request workflow |
| Data retention limits | Auto-archive, delete |
| Breach notification | Audit alerts |

---

## Quick Reference: Control Checklist

### Before Employee Create
- [ ] Background check completed
- [ ] Contract approved
- [ ] Budget confirmed
- [ ] Start date validated

### Before Salary Change
- [ ] Budget available
- [ ] Manager approval
- [ ] HR Manager approval (if >10%)
- [ ] Documentation attached

### Before Termination
- [ ] Notice period met
- [ ] Exit interview scheduled
- [ ] Assets returned
- [ ] Access revoked
- [ ] Final pay calculated
