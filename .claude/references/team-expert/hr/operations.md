# HR Domain - Operational Analysis Framework

> **Domain**: Human Resources / Quản trị Nhân sự
> **Last Updated**: 2026-03-07

---

## 1. Employee Lifecycle Stages

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│Attraction│──▶│Recruitment│──▶│Onboarding│──▶│Development│──▶│Retention │──▶│Separation│
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
     │              │              │              │              │              │
     ▼              ▼              ▼              ▼              ▼              ▼
 Marketing      Job Post      Orientation    Training       Benefits       Exit Process
 Employer       Screening     Setup          Performance    Engagement     Offboarding
 Branding       Interview     Compliance     Career Path    Recognition    Knowledge
                Offer         Equipment                      Wellness       Transfer
```

### Stage Details

| Stage | Key Activities | System Support | Success Metrics |
|-------|----------------|----------------|-----------------|
| **Attraction** | Employer branding, Job postings | Career site, Social integration | Applications per role |
| **Recruitment** | Screening, Interview, Offer | ATS, Interview scheduling | Time to hire, Offer acceptance |
| **Onboarding** | Orientation, Setup, Training | Onboarding workflow, Task tracking | Time to productivity |
| **Development** | Performance, Training, Career | Performance mgmt, LMS | Training completion, Promotion rate |
| **Retention** | Benefits, Engagement, Recognition | Benefits admin, Survey tools | Turnover rate, Engagement score |
| **Separation** | Exit process, Knowledge transfer | Exit workflow, Offboarding tasks | Exit interview completion |

---

## 2. Core HR Processes

### Process 1: Recruitment (End-to-End)

```
Requisition → Sourcing → Screening → Interview → Offer → Onboarding
     │            │           │           │         │         │
     ▼            ▼           ▼           ▼         ▼         ▼
  Approve      Post Job    Screen      Schedule   Approve   Setup
  Budget       Sources     Resume      Interview  Offer     Employee
```

| Step | Owner | System Actions | Data Required |
|------|-------|----------------|---------------|
| 1. Requisition | Hiring Manager | Create request → Approval workflow | JD, Budget, Headcount |
| 2. Sourcing | Recruiter | Post to job boards, Career site | Job posting templates |
| 3. Screening | Recruiter | Filter applicants, Score | Screening criteria |
| 4. Interview | Recruiter + Panel | Schedule, Send invites, Collect feedback | Interviewers, Slots |
| 5. Offer | HR Manager | Generate offer letter, Approval | Salary, Benefits, Start date |
| 6. Onboarding | HR Admin | Create employee, Setup tasks | Personal info, Equipment |

### Process 2: Leave Management

```
Request → Validation → Approval → Balance Update → Notification
    │         │            │            │               │
    ▼         ▼            ▼            ▼               ▼
 Employee   System      Manager      Auto-calc       Employee
 Submit     Check       Approve      Balance         + Manager
```

| Step | System Validation | Approval Rule |
|------|-------------------|---------------|
| Submit | Check leave type, balance, dates | - |
| Validate | Overlapping requests, Blackout periods | Auto-reject if invalid |
| Approve | Update team calendar | Per approval matrix |
| Update | Deduct from balance | Effective immediately |
| Notify | Email + push notification | To employee + manager |

### Process 3: Performance Review Cycle

```
Q1: Goal Setting → Q2: Mid-Year Review → Q3: Check-in → Q4: Year-End Review
        │                   │                  │                │
        ▼                   ▼                  ▼                ▼
   Set OKRs          Progress Update    Manager Feedback   Final Rating
   Manager Align     Self Assessment    Coaching           Calibration
```

| Phase | Timing | Participants | System Actions |
|-------|--------|--------------|----------------|
| Goal Setting | Jan | Employee + Manager | Create goals, Align to company |
| Mid-Year | Jun | Employee + Manager | Progress update, Adjustments |
| Check-in | Sep | Manager | Feedback log, Development plan |
| Year-End | Dec | Employee + Manager + Skip-level | Self-assess, Manager assess, Calibrate |

### Process 4: Payroll Processing

```
Time Data → Validation → Calculation → Approval → Payment → GL Posting
     │          │            │            │          │          │
     ▼          ▼            ▼            ▼          ▼          ▼
 Timesheet   Check All    Apply Rules   HR/Finance  Bank       Finance
 + Leave     Data         Tax/Ins       Review      Transfer   System
```

| Step | Owner | Validation | Output |
|------|-------|------------|--------|
| Time Data | Employees + Managers | Complete timesheets, Leave recorded | Validated input |
| Validation | System + HR | New hires, Terminations, Salary changes | Exception report |
| Calculation | System | Tax tables, Insurance rates | Payslips |
| Approval | HR Manager + Finance | Variance analysis | Approved payroll |
| Payment | Finance | Bank file generation | Payment confirmation |
| GL Posting | System | Cost center allocation | Journal entries |

---

## 3. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Respond employee queries | HR Admin | 2-3 hours | Scattered info, slow response |
| Process leave requests | Managers | 30 min | No mobile access |
| Update candidate status | Recruiter | 1 hour | Manual updates |
| Check attendance exceptions | HR Admin | 30 min | Manual review |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Review recruitment pipeline | HR Manager | 2 hours | Manual reporting |
| Approve timesheets | Managers | 1 hour | Late submissions |
| New hire orientation | HR Admin | 4 hours | Manual checklists |
| Training completion check | HR Admin | 1 hour | No visibility |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Payroll processing | HR + Finance | 3-5 days | Manual validations |
| Headcount report | HR Manager | 2 hours | Manual compilation |
| Leave balance reconciliation | HR Admin | 2 hours | Spreadsheet work |
| Training report | HR Admin | 1 hour | Multiple sources |

### Annual Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Performance review cycle | All | 2-3 months | Paper-based |
| Salary review | HR + Finance | 1 month | Spreadsheet chaos |
| Contract renewals | HR Admin | Ongoing | Manual tracking |
| Compliance audit prep | HR Manager | 1 week | Document gathering |

---

## 4. Decision Support Requirements

### Real-Time Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| HR Overview | HR Manager, HR Director | Headcount, Turnover, Open positions |
| Recruitment | Recruiter, HR Manager | Pipeline, Time to hire, Offer rate |
| Attendance | HR Admin, Managers | Leave trends, Absenteeism rate |
| Performance | Managers, HR | Goal completion, Review status |
| Compensation | HR Director, Finance | Salary costs, Budget variance |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Headcount Report | Monthly | Track workforce size | HR, Finance, Management |
| Turnover Analysis | Monthly | Understand attrition | HR, Management |
| Time to Hire | Weekly | Recruitment efficiency | Recruiter, HR Manager |
| Training Compliance | Monthly | Ensure completion | HR, Managers |
| Cost per Hire | Quarterly | Budget tracking | HR, Finance |
| Diversity Report | Annually | Compliance, Goals | HR, Management |

---

## 5. Integration Touchpoints

### Internal Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **Finance/Accounting** | HR → Finance | Payroll GL posting, Cost allocation |
| **Project Management** | HR → Projects | Resource allocation, Time tracking |
| **Access Management** | HR → IT | Auto-provisioning, Deprovisioning |
| **Communication** | HR → Email/Chat | Notifications, Directory sync |

### External Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **Job Boards** | Bi-directional | Post jobs, Receive applications |
| **Background Check** | HR → Vendor | Initiate checks, Receive results |
| **Insurance Providers** | Bi-directional | Submit enrollment, Receive confirmations |
| **Government (Tax/Insurance)** | HR → Government | Submit reports, Compliance |

---

## 6. KPIs & Metrics

### Recruitment Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Time to Hire | Days from requisition to offer acceptance | <30 days |
| Cost per Hire | Total recruitment cost / # hires | Per budget |
| Offer Acceptance Rate | Accepted / Total offers | >85% |
| Quality of Hire | Performance rating at 6 months | >3.5/5 |
| Source Effectiveness | Hires by source | Track over time |

### Retention Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Turnover Rate | Separations / Avg headcount × 100 | <15% |
| Voluntary Turnover | Voluntary separations / Avg headcount | <10% |
| Retention Rate | Employees retained / Total × 100 | >85% |
| Average Tenure | Sum of tenure / # employees | Track over time |

### Engagement Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| eNPS (Employee NPS) | Promoters - Detractors | >30 |
| Survey Participation | Respondents / Total employees | >80% |
| Training Completion | Completed / Assigned | >90% |
| Performance Review Completion | Completed / Required | 100% |

### Efficiency Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| HR-to-Employee Ratio | Total employees / HR staff | 50:1 - 100:1 |
| Time to Onboard | Days to full productivity | <90 days |
| Payroll Accuracy | Correct payments / Total | >99.9% |
| Self-Service Adoption | Self-service requests / Total | >70% |

---

## Quick Reference: Process Owner Matrix

| Process Area | Primary Owner | Secondary Owner | Escalation |
|--------------|---------------|-----------------|------------|
| Recruitment | Recruiter | HR Manager | HR Director |
| Onboarding | HR Admin | Hiring Manager | HR Manager |
| Performance | Manager | HR Admin | HR Manager |
| Compensation | HR Manager | Finance | HR Director |
| Leave Management | HR Admin | Manager | HR Manager |
| Termination | HR Manager | Legal (if needed) | HR Director |
| Training | HR Admin | Manager | HR Manager |
| Payroll | HR Admin | Finance | HR Manager + Finance |
