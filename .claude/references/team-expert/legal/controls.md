# Legal Domain - Controls & Access Management

> **Domain**: Legal / Pháp lý và Compliance
> **Last Updated**: 2026-03-07

---

## 1. Contract Authorization Matrix

### By Contract Value

| Contract Value | Initiator | Reviewer | Approver | Signatory |
|----------------|:---------:|:--------:|:--------:|:---------:|
| ≤50M VND | Department | Legal Counsel | Manager | Manager |
| 50-200M VND | Department | Legal Counsel | Legal Manager | Director |
| 200M-1B VND | Department | Legal Counsel | Legal Manager | Director |
| >1B VND | Department | Legal Manager | Legal Director | CEO/Board |
| Strategic/High Risk | Department | Legal Director | CEO | Board |

### By Contract Type

| Contract Type | Counsel Review | Manager Approval | Director Approval | External Counsel |
|---------------|:--------------:|:----------------:|:-----------------:|:----------------:|
| NDA | ✅ | ✅ | - | ⚠ If cross-border |
| Service Agreement | ✅ | ✅ | ⚠ If >200M | ⚠ If complex |
| Software License | ✅ | ✅ | ⚠ If >100M | ⚠ If custom |
| Vendor Contract | ✅ | ✅ | ⚠ If >500M | ⚠ If high risk |
| Customer Contract | ✅ | ✅ | ⚠ If >500M | ⚠ If non-standard |
| Employment Contract | ✅ | HR Manager | ⚠ Senior roles | ⚠ Executive |
| Partnership | ✅ | ✅ | ✅ | ✅ Recommended |

---

## 2. Contract Workflow Rules

### Review Workflow

```
Request → Triage → Draft/Review → Negotiate → Approve → Sign → Archive
    │        │          │            │          │        │       │
    ▼        ▼          ▼            ▼          ▼        ▼       ▼
 Dept     Legal     Counsel      Parties    Managers  Auth    System
 Request  Assigns   Reviews      Negotiate  Approve   Sign   Files
```

### Workflow Stages

| Stage | Owner | Actions | SLA |
|-------|-------|---------|-----|
| Request | Business | Submit request, Attach draft | - |
| Triage | Contract Admin | Assign to counsel, Set priority | <4 hours |
| Review | Counsel | Review terms, Flag risks, Suggest changes | Per complexity |
| Negotiate | Business + Legal | Negotiate terms, Track versions | Per deal |
| Approve | Managers | Approve per matrix | <48 hours |
| Sign | Authorized signatory | E-sign or wet ink | <24 hours |
| Archive | System | Store in repository, Set alerts | Immediate |

### Version Control Rules

| Action | Rule |
|--------|------|
| Create draft | Version 1.0 |
| Internal revision | Version 1.1, 1.2... |
| Sent to counterparty | Version 2.0 |
| Counterparty revision | Version 2.1, 2.2... |
| Final agreed | Version "Final" |
| Signed | Lock, no further edits |

---

## 3. Document Security Controls

### Access Control by Document Type

| Document Type | Business | Legal Counsel | Legal Manager | External |
|---------------|:--------:|:-------------:|:-------------:|:--------:|
| Draft contracts | ⚠ Own dept | ✅ Full | ✅ Full | ❌ |
| Under negotiation | ⚠ Own dept | ✅ Full | ✅ Full | ⚠ Shared |
| Signed contracts | ⚠ View | ✅ View | ✅ Full | ❌ |
| Legal opinions | ❌ | ✅ Full | ✅ Full | ❌ |
| Board minutes | ❌ | ⚠ Limited | ⚠ Limited | ❌ |
| Compliance reports | ⚠ View | ⚠ View | ✅ Full | ⚠ Auditor |

### Document Protection

| Protection | Draft | Negotiation | Signed | Archived |
|------------|:-----:|:-----------:|:------:|:--------:|
| Encryption | ✅ | ✅ | ✅ | ✅ |
| Watermark | ⚠ Optional | ⚠ Optional | ✅ | ✅ |
| Download control | ⚠ | ⚠ | ⚠ | ⚠ |
| Print tracking | ⚠ | ⚠ | ✅ | ✅ |
| External sharing | ⚠ Controlled | ⚠ Controlled | ❌ | ❌ |

---

## 4. Compliance Calendar Controls

### Regulatory Deadlines

| Requirement | Frequency | Responsible | Penalty Risk |
|-------------|-----------|-------------|--------------|
| Annual report filing | Annual | Company Secretary | High |
| Tax declarations | Monthly/Quarterly | Finance + Legal | High |
| License renewals | Varies | Compliance | Medium |
| Data protection review | Annual | Compliance + IT | High |
| AML reporting | Ongoing | Compliance | Critical |
| Industry-specific | Varies | Relevant dept | Varies |

### Compliance Monitoring

| Control | Frequency | Owner | Escalation |
|---------|-----------|-------|------------|
| Regulatory scan | Weekly | Compliance | Legal Manager |
| Policy review | Quarterly | Compliance | Legal Director |
| Training compliance | Monthly | Compliance + HR | Department head |
| Audit trail review | Monthly | Compliance | Legal Director |

---

## 5. E-Signature Controls

### E-Signature Authorization

| Document Type | E-Signature Allowed | Provider | Authentication |
|---------------|:-------------------:|----------|----------------|
| NDA | ✅ | Approved provider | Email OTP |
| Internal approvals | ✅ | Approved provider | SSO |
| Vendor contracts | ✅ | Approved provider | 2FA |
| Customer contracts | ⚠ Per policy | Approved provider | 2FA |
| Board resolutions | ⚠ Per jurisdiction | Approved provider | Digital cert |
| Employment contracts | ✅ | Approved provider | Email OTP |

### E-Signature Audit

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Document sent | Sender, Recipient, Timestamp | 10 years |
| Document viewed | Viewer, IP, Timestamp | 10 years |
| Signature completed | Signer, IP, Timestamp, Certificate | 10 years |
| Document downloaded | User, IP, Timestamp | 10 years |

---

## 6. Retention & Disposal

### Retention Schedule

| Document Type | Retention Period | Legal Basis |
|---------------|------------------|-------------|
| Contracts | 10 years after expiry | Commercial Law |
| Corporate records | Permanent | Enterprise Law |
| Tax documents | 10 years | Tax Law |
| Employment records | 5 years after termination | Labor Law |
| Litigation files | 10 years after closure | Limitation period |
| Compliance records | 7 years | Regulatory requirement |
| General correspondence | 3 years | Business need |

### Disposal Process

```
Review → Approve → Certify → Destroy → Log
   │        │         │         │       │
   ▼        ▼         ▼         ▼       ▼
 Identify  Manager   Legal    Secure   Audit
 Expired   Approves  Certifies Destroy  Record
 Items     Disposal  Safe     Method   Details
```

---

## 7. Audit Trail Requirements

### Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Contract create | User, Template, Counterparty | 10 years |
| Contract edit | User, Version, Changes | 10 years |
| Contract share | User, Recipient, Access level | 7 years |
| Contract sign | Signer, Method, Certificate | 10 years |
| Document access | User, Document, Action | 5 years |
| Policy update | User, Change, Effective date | 10 years |
| Compliance check | User, Finding, Resolution | 7 years |

---

## Quick Reference: Risk Assessment Matrix

### Contract Risk Scoring

| Factor | Low (1) | Medium (2) | High (3) |
|--------|---------|------------|----------|
| Value | <100M | 100M-1B | >1B |
| Term | <1 year | 1-3 years | >3 years |
| Liability | Standard | Limited cap | Uncapped |
| IP | No IP involved | License grant | IP transfer |
| Data | No personal data | Limited personal data | Sensitive data |
| Jurisdiction | Vietnam only | Multi-country | Global/Unknown |

**Risk Level**: Sum of factors
- **Low Risk**: 5-7 → Counsel review
- **Medium Risk**: 8-10 → Counsel + Manager review
- **High Risk**: 11-15 → Full legal review + external counsel consideration

---

## Quick Reference: Contract Checklist

### Before Signing
- [ ] All parties identified correctly
- [ ] Terms match agreed negotiation
- [ ] All exhibits/attachments included
- [ ] Signature blocks correct
- [ ] Authority to sign confirmed
- [ ] Internal approvals obtained
- [ ] No blank spaces
- [ ] Date and place of signing
