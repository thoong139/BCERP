# HR Domain - User Personas

> **Domain**: Human Resources / Quản trị Nhân sự
> **Last Updated**: 2026-03-07

---

## Persona 1: HR Admin

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | HR Administrator |
| **Experience** | 1-3 năm |
| **Report to** | HR Manager |
| **Focus** | Daily HR operations, data management |

### Daily Tasks
1. Maintain employee records trong HRIS
2. Process leave requests và attendance
3. Prepare HR documents (contracts, letters)
4. Respond employee queries về policies
5. Support recruitment admin tasks

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Approve leave request (≤3 days) | Approve | Leave balance, team calendar |
| Update employee information | Execute | Verification documents |
| Generate HR reports | Execute | Report parameters |

### Pain Points
- Manual data entry, duplicate work
- Difficult tracking document expiry dates
- No visibility vào request status
- Scattered information across systems

### Must-have Features
- ✅ Self-service portal cho employees
- ✅ Automated leave calculation
- ✅ Document templates với auto-fill
- ✅ Centralized employee database

---

## Persona 2: HR Manager

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | HR Manager |
| **Experience** | 5-10 năm |
| **Report to** | HR Director / CEO |
| **Focus** | Strategy, compliance, team management |

### Daily Tasks
1. Review và approve employee status changes
2. Monitor headcount và budget
3. Handle employee relations issues
4. Ensure compliance với labor laws
5. Coordinate với department heads

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Approve salary changes | Approve | Budget, market data |
| Approve promotion/transfer | Approve | Performance data |
| Terminate employment | Recommend | Documentation |
| Update HR policies | Recommend | Legal requirements |

### Pain Points
- Lack of analytics cho workforce planning
- Manual tracking của compliance deadlines
- Difficulty tracking training completion
- No integration với payroll

### Must-have Features
- ✅ HR dashboard với KPIs
- ✅ Compliance calendar
- ✅ Approval workflows
- ✅ Budget tracking

---

## Persona 3: Recruiter

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Recruiter / Talent Acquisition |
| **Experience** | 2-5 năm |
| **Report to** | HR Manager |
| **Focus** | Sourcing, screening, hiring |

### Daily Tasks
1. Post job advertisements
2. Screen resumes và applications
3. Schedule và conduct interviews
4. Coordinate với hiring managers
5. Manage candidate pipeline

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Shortlist candidates | Recommend | JD, candidate profile |
| Schedule interview | Execute | Calendar availability |
| Reject candidates | Execute | Interview feedback |

### Pain Points
- Manual tracking of candidates across channels
- No visibility into pipeline status
- Duplicate data entry
- Slow communication với candidates

### Must-have Features
- ✅ Applicant Tracking System (ATS)
- ✅ Career page integration
- ✅ Interview scheduling
- ✅ Candidate communication templates

---

## Persona 4: Employee (Self-Service User)

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Employee |
| **Experience** | Varies |
| **Report to** | Direct Manager |
| **Focus** | Personal information, leave, payslips |

### Daily Tasks
1. View payslips và tax documents
2. Submit leave requests
3. Update personal information
4. Access company policies
5. Complete training assignments

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Request leave | Request | Leave balance |
| Update contact info | Execute (own data) | New information |
| View salary info | View only | - |

### Pain Points
- Cannot access info outside office hours
- Unclear leave balance
- Slow approval notifications
- No mobile access

### Must-have Features
- ✅ Mobile-friendly self-service
- ✅ Real-time leave balance
- ✅ Push notifications
- ✅ Digital payslips

---

## Persona 5: Manager (Department Head)

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Department Manager |
| **Experience** | 5+ năm |
| **Report to** | Director / VP |
| **Focus** | Team management, performance |

### Daily Tasks
1. Approve team leave requests
2. Conduct performance reviews
3. Manage team goals và OKRs
4. Approve timesheets (if applicable)
5. Participate in recruitment

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Approve team leave | Approve | Team calendar, workload |
| Rate employee performance | Recommend | Performance data |
| Request new headcount | Request | Budget, justification |

### Pain Points
- No visibility into team leave calendar
- Manual performance tracking
- Difficult to track team training
- No integration với project systems

### Must-have Features
- ✅ Team calendar view
- ✅ Performance review workflow
- ✅ Goal tracking
- ✅ Team training dashboard

---

## Quick Reference: Persona Access Matrix

| Data/Function | HR Admin | HR Manager | Recruiter | Employee | Manager |
|---------------|:--------:|:----------:|:---------:|:--------:|:-------:|
| Own profile | ✅ View | ✅ Full | ✅ View | ✅ Edit | ✅ View |
| Own salary | ❌ | ❌ | ❌ | ✅ View | ❌ |
| Team profiles | ✅ View | ✅ Full | ❌ | ❌ | ✅ View |
| Team salaries | ❌ | ✅ View | ❌ | ❌ | ⚠️ Limited |
| All employees | ✅ Full | ✅ Full | ⚠ Limited | ❌ | ❌ |
| Recruitment | ✅ Support | ✅ Full | ✅ Full | ❌ | ⚠ Limited |
| Reports | ✅ Generate | ✅ Full | ⚠ Limited | ❌ | ⚠ Team only |
