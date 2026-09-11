# Compliance Risk Matrix

> Reference file cho compliance-expert agent
> Load file này khi cần đánh giá rủi ro trong domain Compliance

## Risk Assessment Framework

### Risk Categories

| Category | Description | Examples |
|----------|-------------|----------|
| Regulatory | Non-compliance with laws | Tax penalties, license revocation |
| Operational | Process failures | Data breaches, fraud |
| Financial | Monetary impact | Fines, settlements, remediation costs |
| Reputational | Brand damage | Negative publicity, customer loss |
| Strategic | Business model impact | Market access, competitive position |

---

## Risk Scoring Methodology

### Likelihood Scale

| Level | Description | Frequency |
|-------|-------------|-----------|
| 1 - Rare | Highly unlikely | Once in 10+ years |
| 2 - Unlikely | Could occur | Once in 5-10 years |
| 3 - Possible | May occur | Once in 2-5 years |
| 4 - Likely | Expected to occur | Once per year |
| 5 - Almost Certain | Will occur | Multiple times per year |

### Impact Scale

| Level | Financial | Operational | Reputational |
|-------|-----------|-------------|--------------|
| 1 - Insignificant | < $10K | Minor disruption | Internal only |
| 2 - Minor | $10K - $100K | Short-term impact | Local media |
| 3 - Moderate | $100K - $1M | Significant disruption | National media |
| 4 - Major | $1M - $10M | Long-term impact | International media |
| 5 - Catastrophic | > $10M | Business continuity | Major brand damage |

---

## Risk Matrix

```
                    IMPACT
              1    2    3    4    5
         ┌────┬────┬────┬────┬────┐
       5 │ M  │ H  │ H  │ C  │ C  │
    L    ├────┼────┼────┼────┼────┤
    I  4 │ L  │ M  │ H  │ H  │ C  │
    K    ├────┼────┼────┼────┼────┤
    E  3 │ L  │ M  │ M  │ H  │ H  │
    L    ├────┼────┼────┼────┼────┤
    I  2 │ L  │ L  │ M  │ M  │ H  │
    H    ├────┼────┼────┼────┼────┤
    O  1 │ L  │ L  │ L  │ M  │ M  │
    O    └────┴────┴────┴────┴────┘

    L = Low (Accept/Monitor)
    M = Medium (Mitigate)
    H = High (Priority Mitigation)
    C = Critical (Immediate Action)
```

---

## Common Compliance Risks

### 1. Data Protection Risks

| Risk | Likelihood | Impact | Score | Mitigation |
|------|------------|--------|-------|------------|
| Data breach | 3 | 5 | H | Encryption, access control, monitoring |
| Unauthorized access | 4 | 4 | H | MFA, least privilege, audit logs |
| Data loss | 2 | 4 | M | Backup, disaster recovery |
| Non-compliant processing | 3 | 4 | H | Privacy by design, consent management |

### 2. Financial Compliance Risks

| Risk | Likelihood | Impact | Score | Mitigation |
|------|------------|--------|-------|------------|
| Tax non-compliance | 2 | 4 | M | Tax system integration, expert review |
| Financial misstatement | 2 | 5 | H | Internal controls, audit procedures |
| Fraud | 3 | 4 | H | Segregation of duties, monitoring |
| AML violations | 2 | 5 | H | KYC procedures, transaction monitoring |

### 3. Operational Compliance Risks

| Risk | Likelihood | Impact | Score | Mitigation |
|------|------------|--------|-------|------------|
| Policy violations | 4 | 3 | M | Training, monitoring, enforcement |
| Vendor non-compliance | 3 | 3 | M | Due diligence, contract terms, audits |
| Regulatory changes | 4 | 3 | M | Monitoring, change management |
| License/permit issues | 2 | 4 | M | Renewal tracking, compliance calendar |

### 4. HR Compliance Risks

| Risk | Likelihood | Impact | Score | Mitigation |
|------|------------|--------|-------|------------|
| Discrimination claims | 2 | 4 | M | Training, clear policies, documentation |
| Wage/hour violations | 3 | 3 | M | Time tracking, compliance review |
| Safety violations | 2 | 4 | M | Safety training, inspections |
| Wrongful termination | 2 | 4 | M | Documentation, legal review |

---

## Risk Register Template

| ID | Risk | Category | Owner | L | I | Score | Controls | Status |
|----|------|----------|-------|---|---|-------|----------|--------|
| R001 | Data breach | Regulatory | CISO | 3 | 5 | H | Encryption, MFA | Active |
| R002 | Tax penalty | Financial | CFO | 2 | 4 | M | Tax system | Active |
| R003 | License expiry | Operational | COO | 2 | 3 | L | Calendar alerts | Monitoring |

---

## Control Effectiveness Assessment

### Control Types

| Type | Purpose | Examples |
|------|---------|----------|
| Preventive | Stop risk from occurring | Access controls, approvals |
| Detective | Identify when risk occurs | Monitoring, audits, reconciliations |
| Corrective | Remediate after occurrence | Incident response, backups |

### Control Testing

| Rating | Criteria |
|--------|----------|
| Effective | Control operating as designed, no exceptions |
| Partially Effective | Control operating but with minor exceptions |
| Ineffective | Control not operating or major exceptions |
| Not Tested | Control not yet assessed |

---

## Risk Response Options

| Response | When to Use | Example |
|----------|-------------|---------|
| Accept | Low risk, cost of mitigation > impact | Minor policy violations |
| Mitigate | Medium to high risk, cost-effective controls | Data encryption |
| Transfer | Risk can be insured or contracted | Cyber insurance |
| Avoid | Risk exceeds tolerance, cannot mitigate | Exit business activity |

---

## Risk Monitoring Dashboard

### Key Risk Indicators (KRIs)

| KRI | Threshold | Current | Trend |
|-----|-----------|---------|-------|
| Compliance incidents | <5/month | 3 | ↓ |
| Policy violations | <2% | 1.5% | → |
| Audit findings | <10 open | 7 | ↓ |
| Training completion | >95% | 92% | ↑ |
| Access review completion | 100% | 100% | → |

### Escalation Triggers

| Trigger | Action |
|---------|--------|
| Risk score increases to Critical | Immediate escalation to Board |
| Control failure | Root cause analysis, remediation |
| Regulatory finding | Incident response protocol |
| Threshold breach | Management notification |
