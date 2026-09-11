# Healthcare Compliance Reference

> Reference file cho healthcare-expert agent
> Load file này khi cần hiểu về compliance trong domain Healthcare

## Regulatory Framework

### Key Regulations by Region

| Region | Regulation | Focus |
|--------|------------|-------|
| US | HIPAA | Patient privacy, security |
| US | HITECH | EHR meaningful use |
| US | 21 CFR Part 11 | Electronic signatures |
| EU | GDPR | Personal data protection |
| VN | Decree 117/2020 | Medical examination |
| VN | Decree 13/2023 | Personal data protection |

---

## HIPAA Compliance (US Reference)

### Privacy Rule

| Requirement | Description |
|-------------|-------------|
| Minimum necessary | Use/disclose only what's needed |
| Patient rights | Access, amend, accounting of disclosures |
| Authorization | Written consent for non-treatment uses |
| Notice of Privacy Practices | Inform patients of rights |

### Security Rule

| Safeguard Type | Requirements |
|----------------|--------------|
| Administrative | Risk analysis, training, policies |
| Physical | Facility access, workstation security |
| Technical | Access control, encryption, audit logs |

### Breach Notification

| Timeline | Action |
|----------|--------|
| Upon discovery | Begin investigation |
| 60 days | Notify affected individuals |
| 60 days (if >500) | Notify HHS, media |
| Annual | Report smaller breaches to HHS |

---

## Vietnam Healthcare Regulations

### Decree 117/2020/ND-CP

| Requirement | Description |
|-------------|-------------|
| Licensing | Medical facilities must be licensed |
| Personnel | Staff must have proper qualifications |
| Equipment | Must meet Ministry of Health standards |
| Records | Patient records must be maintained |
| Reporting | Incident reporting required |

### Patient Data Protection (Decree 13/2023)

| Requirement | Description |
|-------------|-------------|
| Consent | Required for data collection |
| Purpose limitation | Use only for stated purpose |
| Data minimization | Collect only necessary data |
| Retention | Delete when no longer needed |
| Security | Protect against unauthorized access |

---

## Access Control Requirements

### Role-Based Access Control (RBAC)

| Role | Access Level |
|------|--------------|
| Attending Physician | Full patient access (assigned patients) |
| Nurse | Care team patients |
| Consultant | Specific consultation access |
| Billing | Financial data only |
| Registration | Demographics, scheduling |
| Admin | Aggregate data, no clinical details |

### Break-the-Glass (Emergency Access)

```
┌─────────────────────────────────────────────────────────────┐
│                 EMERGENCY ACCESS                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [Normal Access Denied]                                     │
│         │                                                   │
│         ▼                                                   │
│  [Break-the-Glass Button]                                   │
│         │                                                   │
│         ▼                                                   │
│  [Reason Required]                                          │
│  ├─ Medical emergency                                       │
│  ├─ System downtime                                         │
│  └─ Other (specify)                                         │
│         │                                                   │
│         ▼                                                   │
│  [Access Granted]                                           │
│  ├─ Full access for limited time                            │
│  └─ All actions logged                                      │
│         │                                                   │
│         ▼                                                   │
│  [Audit Review]                                             │
│  └─ Compliance reviews all break-the-glass events           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Consent Management

### Types of Consent

| Type | Purpose |
|------|---------|
| Treatment consent | Consent for medical treatment |
| Consent to share | Allow sharing with family/others |
| Research consent | Participate in studies |
| Marketing consent | Receive marketing communications |

### Consent Workflow

```
[Patient Presents]
        │
        ▼
[Check Existing Consent]
        │
        ├── Valid consent on file → Proceed
        │
        └── No/expired consent
                │
                ▼
          [Obtain Consent]
                │
                ▼
          [Document in System]
                │
                ├─ Who obtained
                ├─ When
                ├─ What was consented
                └─ How (paper/electronic)
```

---

## Audit Trail Requirements

### What to Log

| Event Type | Data to Capture |
|------------|-----------------|
| Access | Who, when, what patient, what data |
| Create | Who, when, what record |
| Modify | Who, when, before, after values |
| Delete | Who, when, what was deleted |
| Print/Export | Who, when, what data |
| Login/Logout | Who, when, success/failure |

### Retention Periods

| Record Type | Retention |
|-------------|-----------|
| Adult medical records | 10 years after last encounter |
| Pediatric records | Until age 21 + statute of limitations |
| Audit logs | 6 years minimum |
| Consent forms | Duration of relationship + 6 years |

---

## Security Controls

### Authentication Requirements

| Level | Requirements |
|-------|--------------|
| Basic | Username/password |
| Standard | Password + complexity rules |
| Enhanced | Password + MFA |
| High | Password + MFA + badge |

### Password Policy

| Requirement | Standard |
|-------------|----------|
| Minimum length | 8 characters |
| Complexity | Upper, lower, number, special |
| Expiration | 90 days |
| History | 12 passwords |
| Lockout | 5 failed attempts |

---

## Incident Response

### Security Incident Types

| Type | Examples |
|------|----------|
| Unauthorized access | Someone accessing wrong records |
| Data breach | PHI exposed to unauthorized persons |
| Malware | Virus, ransomware |
| System failure | Downtime affecting patient care |
| Lost device | Laptop with PHI missing |

### Response Steps

```
1. IDENTIFY
   └─ Detect and confirm incident

2. CONTAIN
   └─ Limit damage, preserve evidence

3. INVESTIGATE
   └─ Determine scope, root cause

4. REMEDIATE
   └─ Fix vulnerability, restore systems

5. NOTIFY
   └─ Inform affected parties, regulators

6. DOCUMENT
   └─ Record all actions taken

7. IMPROVE
   └─ Update policies, training
```

---

## Compliance Training

### Required Training Topics

| Topic | Frequency |
|-------|-----------|
| HIPAA/Privacy | Annual |
| Security awareness | Annual |
| Phishing prevention | Quarterly |
| Password security | Annual |
| Incident reporting | Annual |
| Role-specific compliance | Annual |

### Training Tracking

| Data Point | Purpose |
|------------|---------|
| Training module | What was trained |
| Completion date | When completed |
| Score | Assessment results |
| Acknowledgment | Policy acceptance |
