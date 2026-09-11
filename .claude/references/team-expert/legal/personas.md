# Legal Domain - User Personas

> **Domain**: Legal / Pháp lý và Compliance
> **Last Updated**: 2026-03-07

---

## Persona 1: Legal Counsel

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Legal Counsel / Lawyer |
| **Experience** | 5-10 năm |
| **Report to** | Legal Director / General Counsel |
| **Focus** | Contract review, Legal advice |

### Daily Tasks
1. Review contracts và agreements
2. Provide legal advice to departments
3. Draft contract templates
4. Handle disputes
5. Research legal issues

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Contract risk assessment | Execute | Contract terms, Precedents |
| Template approval | Recommend | Business requirements |
| Escalate to external counsel | Recommend | Complexity, Risk level |
| Settlement recommendation | Recommend | Case analysis, Cost-benefit |

### Pain Points
- Manual contract tracking
- No centralized document repository
- Slow approval processes
- Version control issues

### Must-have Features
- ✅ Contract lifecycle management
- ✅ Document repository
- ✅ Workflow automation
- ✅ Version control

---

## Persona 2: Legal Manager

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Legal Manager / Head of Legal |
| **Experience** | 8-15 năm |
| **Report to** | General Counsel / CEO |
| **Focus** | Team management, Strategy, Compliance |

### Daily Tasks
1. Review high-value contracts
2. Manage team workload
3. Coordinate with external counsel
4. Report to leadership
5. Develop legal policies

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Approve contract (≤threshold) | Execute | Risk assessment, Budget |
| Approve external counsel | Execute | Complexity, Cost |
| Policy updates | Execute | Regulatory changes |
| Legal strategy | Recommend | Business impact |

### Pain Points
- No visibility into team workload
- Manual compliance tracking
- Fragmented reporting
- Risk oversight gaps

### Must-have Features
- ✅ Team dashboard
- ✅ Compliance calendar
- ✅ Risk register
- ✅ Automated reporting

---

## Persona 3: Compliance Officer

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Compliance Officer |
| **Experience** | 5-10 năm |
| **Report to** | Legal Director / CEO |
| **Focus** | Regulatory compliance, Risk management |

### Daily Tasks
1. Monitor regulatory changes
2. Conduct compliance checks
3. Update policies and procedures
4. Train employees
5. Report compliance status

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Flag compliance issue | Execute | Audit findings |
| Recommend policy change | Recommend | Gap analysis |
| Escalate violation | Execute | Severity assessment |
| Training requirements | Execute | Risk assessment |

### Pain Points
- Manual tracking of regulations
- No centralized policy management
- Training completion gaps
- No compliance dashboard

### Must-have Features
- ✅ Regulatory tracking
- ✅ Policy management
- ✅ Training tracking
- ✅ Compliance dashboard

---

## Persona 4: Contract Administrator

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Contract Administrator |
| **Experience** | 2-5 năm |
| **Report to** | Legal Manager |
| **Focus** | Contract administration, Documentation |

### Daily Tasks
1. Process contract requests
2. Maintain contract database
3. Track contract expiry dates
4. Coordinate signatures
5. File and archive documents

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Route contract for review | Execute | Contract type, Value |
| Request missing information | Execute | Checklist |
| Archive contract | Execute | Retention policy |
| Flag expiring contract | Execute | Expiry report |

### Pain Points
- Spreadsheet tracking
- Manual expiry monitoring
- Scanned documents
- No search capability

### Must-have Features
- ✅ Contract database
- ✅ Automated alerts
- ✅ E-signature
- ✅ Full-text search

---

## Persona 5: Company Secretary

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Company Secretary |
| **Experience** | 5-10 năm |
| **Report to** | Board / CEO |
| **Focus** | Corporate governance, Board support |

### Daily Tasks
1. Prepare board materials
2. Maintain corporate records
3. File regulatory documents
4. Manage board resolutions
5. Ensure governance compliance

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Board agenda | Recommend | Pending matters |
| Filing deadlines | Execute | Regulatory calendar |
| Document access | Execute | Authorization matrix |
| Resolution drafting | Execute | Board decision |

### Pain Points
- Manual board pack preparation
- Paper-based records
- Missed filing deadlines
- No digital signature for board

### Must-have Features
- ✅ Board portal
- ✅ Digital records
- ✅ Deadline alerts
- ✅ E-signature

---

## Quick Reference: Legal Persona Access Matrix

| Data/Function | Legal Counsel | Legal Manager | Compliance | Contract Admin | Company Sec |
|---------------|:-------------:|:-------------:|:----------:|:--------------:|:-----------:|
| Contracts (own) | ✅ Full | ✅ Full | ⚠ View | ✅ Admin | ⚠ Limited |
| Contracts (all) | ⚠ Department | ✅ Full | ⚠ View | ✅ Admin | ⚠ Board only |
| Legal advice | ✅ Full | ✅ Full | ⚠ Compliance | ❌ | ⚠ Governance |
| Compliance docs | ⚠ View | ✅ Full | ✅ Full | ❌ | ⚠ Governance |
| Corporate records | ⚠ View | ✅ Full | ⚠ View | ⚠ Limited | ✅ Full |
| Board materials | ⚠ As needed | ✅ Full | ⚠ Limited | ❌ | ✅ Full |
| External counsel | ✅ Coordinate | ✅ Approve | ❌ | ❌ | ⚠ Limited |

---

## Quick Reference: Contract Types

| Contract Type | Risk Level | Review Level | Typical Value |
|---------------|:----------:|:------------:|---------------|
| NDA | Low | Counsel | - |
| Vendor Agreement | Medium | Counsel + Manager | <500M VND |
| Customer Contract | Medium-High | Counsel + Manager | Varies |
| Partnership Agreement | High | Manager + Director | >500M VND |
| Employment Contract | Medium | HR + Counsel | - |
| License Agreement | High | Counsel + Director | >200M VND |
