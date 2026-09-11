# Data & Analytics - Controls & Access Management

> **Domain**: Data & Analytics / Dữ liệu & Phân tích
> **Last Updated**: 2026-03-19

---

## 1. Approval Matrix

### Dashboard Publication Approval

| Dashboard Type | Data Analyst | Analytics Manager | Department Head | CDO / VP Data |
|----------------|:------------:|:-----------------:|:---------------:|:-------------:|
| Internal exploratory (draft) | ✅ Self-approve | — | — | — |
| Team-level operational | ⚠ Submit for review | ✅ Approve | — | — |
| Cross-department / company-wide | ⚠ Submit for review | ⚠ Recommend | ✅ Approve | — |
| Executive / Board-level | ⚠ Submit for review | ⚠ Recommend | ⚠ Recommend | ✅ Approve |
| External sharing (client, partner) | ❌ | ⚠ Recommend | ⚠ Recommend | ✅ Approve |

### Data Access Grant Approval

| Access Tier | Requester Self-serve | Analytics Manager | Department Head | CDO |
|-------------|:--------------------:|:-----------------:|:---------------:|:---:|
| Tier 1 — Public / Aggregated | ✅ Auto-provisioned | — | — | — |
| Tier 2 — Internal business data | ❌ | ✅ Approve | — | — |
| Tier 3 — Sensitive / PII masked | ❌ | ⚠ Recommend | ✅ Approve | — |
| Tier 4 — Raw PII / Financial | ❌ | ❌ | ⚠ Recommend | ✅ Approve |
| Tier 5 — Regulated data (GDPR, HIPAA) | ❌ | ❌ | ❌ | ✅ + Legal sign-off |

### Schema Change Approval

| Change Type | BI Engineer | Analytics Manager | Architect / DBA |
|-------------|:-----------:|:-----------------:|:---------------:|
| Add non-breaking column | ✅ Self-execute + document | — | — |
| Rename / remove column | ⚠ Impact analysis required | ✅ Approve after analysis | — |
| Change data type (breaking) | ❌ | ⚠ Recommend | ✅ Approve |
| Add new fact table | ⚠ Propose with ERD | ✅ Approve | ✅ Review |
| Change grain of existing fact | ❌ | ⚠ Recommend | ✅ Approve |
| Drop table / deprecate dataset | ❌ | ⚠ Recommend | ✅ Approve + 30-day notice |

---

## 2. Access Control

### Data Classification Tiers

| Tier | Label | Description | Example Data |
|------|-------|-------------|--------------|
| Tier 1 | Public | Aggregated, non-identifiable, safe to share | Monthly revenue total, product category sales |
| Tier 2 | Internal | Business data for internal use | Department-level KPIs, pipeline metrics |
| Tier 3 | Confidential | Sensitive business data, limited access | Customer segment data (masked ID), margins |
| Tier 4 | Restricted | Personal data, financial details | Customer PII (name, email), salary data |
| Tier 5 | Regulated | Subject to legal compliance requirements | Health data (HIPAA), EU personal data (GDPR) |

### Role-Based Access Matrix

| Data Asset | Data Analyst | BI Engineer | Analytics Manager | Business Stakeholder | Data Consumer (Ext) |
|-----------|:------------:|:-----------:|:-----------------:|:--------------------:|:-------------------:|
| Tier 1 — Aggregated dashboards | ✅ | ✅ | ✅ | ✅ | ✅ (with auth) |
| Tier 2 — Internal reports | ✅ | ✅ | ✅ | ✅ | ❌ |
| Tier 3 — Confidential datasets | ⚠ Masked PII | ⚠ Masked PII | ✅ Read-only | ❌ | ❌ |
| Tier 4 — Restricted / PII | ❌ | ❌ | ⚠ Approved use only | ❌ | ❌ |
| Tier 5 — Regulated | ❌ | ❌ | ❌ | ❌ | ❌ |
| Data warehouse (raw layer) | ❌ | ✅ | ⚠ Read-only | ❌ | ❌ |
| Data warehouse (curated) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Data mart / reporting layer | ✅ | ✅ | ✅ | ✅ (via BI tool) | ❌ |
| Pipeline configs & dbt models | ❌ | ✅ | ⚠ Read-only | ❌ | ❌ |

### PII Masking Rules

| Data Type | Masking Method | Visible to |
|-----------|----------------|------------|
| Email address | Hash (SHA-256) hoặc partial mask (`j***@domain.com`) | None by default |
| Phone number | Partial mask (`+84 ***-***-6789`) | Tier 4+ approved roles only |
| Full name | Tokenize hoặc initial only | Tier 4+ approved roles only |
| Date of birth | Year only (DOB → birth year) | Tier 3+ |
| Customer ID | Internal ID substitution (no raw source ID) | Tier 3+ |
| Financial account | Last 4 digits only | Tier 4+ approved roles only |
| IP Address | Truncate to /24 subnet | Tier 3+ |

### Ownership Rules

| Scenario | Rule | Override Authority |
|----------|------|--------------------|
| Dataset owner leaves company | Ownership transfers to Analytics Manager within 5 ngày | CDO |
| Multiple teams claim same dataset | Analytics Manager arbitrates, CDO final decision | CDO |
| Abandoned dashboard (no views >90 ngày) | Owner notified → Archived after 30 ngày | Analytics Manager |
| Access request denied by manager | Escalation path to CDO with business justification | CDO |
| Emergency access (incident response) | Time-limited 24h access, auto-revoked, full audit log | Analytics Manager |

---

## 3. Workflow Controls

### Report Lifecycle: State Transitions

| From | To | Criteria | Validation |
|------|----|----------|------------|
| — | Draft | Business request logged, assignee set | Backlog item created |
| Draft | In Review | Build complete, self-QA passed | QA checklist submitted |
| In Review | Revisions Required | Reviewer found data discrepancy or UX issue | Review comments documented |
| Revisions Required | In Review | Issues addressed, re-submitted | Updated QA checklist |
| In Review | Approved | Analytics Manager sign-off | Approval recorded in backlog |
| Approved | Published | Access permissions set, URL communicated | Published notification sent |
| Published | Deprecated | Low usage (<5 views/month ×3 consecutive months) or superseded | Owner notified 30 ngày trước |
| Deprecated | Retired | Confirmation from owner, links redirected | Archive log updated |

### Dashboard Hygiene Controls

| Control | Frequency | Enforcement |
|---------|-----------|-------------|
| Stale dashboard detection (no views >60 ngày) | Monthly | Automated report + owner notification |
| Broken data source check | Weekly | Automated test run, fail = alert |
| Duplicate metric check (same KPI in multiple dashboards) | Quarterly | Manual audit by Analytics Manager |
| Outdated filter / date range check | Monthly | Automated check for dashboards with hardcoded dates |
| Access list review | Quarterly | Analytics Manager reviews and removes inactive users |

### Data Pipeline Controls

| Control | Trigger | Enforcement |
|---------|---------|-------------|
| Schema drift detection | Every pipeline run | Automated alert if schema deviates from contract |
| Row count anomaly detection | Every load | Alert if row count ±20% vs 30-day average |
| Freshness SLA breach | Threshold: 4h for batch, 15 min for streaming | PagerDuty alert to BI Engineer on-call |
| dbt test failure | Every dbt run | Block downstream models, alert Slack channel |
| Query cost spike | Daily | Alert if single query exceeds $5 or team cost +50% WoW |

---

## 4. Audit Trail

### Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Dashboard view | User ID, dashboard ID, timestamp, filters applied | 1 năm |
| Report export (PDF/CSV/Excel) | User ID, report ID, timestamp, export format, row count | 2 năm |
| Data access request | Requester, data asset, justification, approver, outcome | 3 năm |
| Access grant / revoke | Admin user, target user, data asset, tier, timestamp | 3 năm |
| Schema change | Changed by, change type, before/after schema, PR link | Permanent |
| Pipeline failure | Pipeline ID, failure reason, affected tables, resolution time | 1 năm |
| Dashboard publish / deprecate | Actor, dashboard ID, state change, timestamp | 2 năm |
| PII data access | User ID, table, columns accessed, purpose, timestamp | 5 năm (compliance) |
| Metric definition change | Changed by, old definition, new definition, effective date | Permanent |
| dbt test failure | Test name, model, failure details, run ID | 6 tháng |

### Sensitive Data Access Log

| Data Accessed | Who Can Access | Purpose | Logged Fields |
|---------------|----------------|---------|---------------|
| Customer PII (name, email) | Tier 4 approved roles only | Specific incident investigation | User, timestamp, query, row count |
| Financial transaction detail | Finance Director + CDO | Audit, reconciliation | User, timestamp, table, purpose |
| Employee salary data | HR Director + CDO | Payroll verification | User, timestamp, access duration |
| Health / medical data | Compliance Officer + CDO | Regulatory requirement only | Full audit with purpose code |
| Authentication tokens / credentials | Security team only | Security incident | Automated SIEM capture |

### Schema Change History

| Field | Content |
|-------|---------|
| Change ID | Sequential ID per schema change event |
| Table / View affected | Fully qualified name (schema.table) |
| Change type | Add column, rename, drop, type change, new table, deprecate |
| Performed by | BI Engineer (user ID) |
| Approved by | Analytics Manager / Architect (user ID) |
| Effective date | Timestamp of deployment |
| Impact assessment | List of downstream dashboards and reports affected |
| Rollback plan | Steps to revert, linked PR / migration script |

---

## Quick Reference: Approval Checklist

### Before Publishing a Dashboard

- [ ] Data numbers spot-checked against source system (tolerance ±0.1%)
- [ ] KPI definitions documented and signed off by business owner
- [ ] Access permissions configured correctly per data classification tier
- [ ] Data freshness indicator visible on dashboard
- [ ] Analytics Manager approval recorded in project backlog
- [ ] Published URL communicated to intended audience

### Before Granting Data Access

- [ ] Requester has submitted business justification
- [ ] Data classification tier identified
- [ ] Appropriate approver has signed off per approval matrix
- [ ] Access grant logged in audit trail with expiry date (if time-limited)
- [ ] PII masking applied where required for the tier

### Before Executing Schema Change

- [ ] Impact analysis completed — list of affected dashboards, reports, downstream models
- [ ] Change type categorized (breaking vs non-breaking)
- [ ] Approval obtained from required authority per matrix
- [ ] Migration script tested in staging environment
- [ ] Rollback plan documented
- [ ] Schema change logged with all required fields
