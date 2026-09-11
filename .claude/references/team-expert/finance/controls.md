# Finance Control Requirements

> Reference file cho finance-expert agent
> Load file này khi cần define authorization, SoD, audit trail

## 1. Authorization Matrix

### Standard Finance Authorization

| Action | Accountant | Chief Accountant | CFO | CEO |
|--------|:----------:|:----------------:|:---:|:---:|
| Create Invoice (own dept) | ✅ | ✅ | ❌ | ❌ |
| View All Invoices | ✅ | ✅ | ✅ | ✅ |
| Edit Invoice (draft) | ✅ | ✅ | ❌ | ❌ |
| Edit Invoice (posted) | ❌ | ✅ (w/ reason) | ✅ | ❌ |
| Void Invoice | ❌ | ✅ (≤50M) | ✅ | ✅ |
| Approve Invoice (≤10M) | ❌ | ✅ | ✅ | ✅ |
| Approve Invoice (10-50M) | ❌ | ✅ (2 approvers) | ✅ | ✅ |
| Approve Invoice (>50M) | ❌ | ❌ | ✅ | ✅ |
| Create Journal Entry | ✅ | ✅ | ❌ | ❌ |
| Post Journal Entry | ❌ | ✅ | ✅ | ❌ |
| Access Bank Account Info | ❌ | ✅ | ✅ | ✅ |
| Export Financial Data | ✅ (own work) | ✅ | ✅ | ✅ |

### Payment Authorization Limits

<!-- BIZ-RULE: id=R-FINANCE-001 entity=Payment action=approve severity=CRITICAL
     Yêu cầu: CFO phê duyệt nếu amount > 50M VND; CFO+CEO nếu > 200M VND -->

| Amount Range | Required Approvers |
|--------------|-------------------|
| ≤ 10M VND | Chief Accountant |
| 10M - 50M VND | Chief Accountant + One Director |
| 50M - 200M VND | CFO |
| > 200M VND | CFO + CEO |

<!-- BIZ-RULE: id=R-FINANCE-002 entity=Invoice action=void req_id=REQ-FIN-002 severity=HIGH
     Yêu cầu: Không thể void Invoice đã posted mà không có approval Chief Accountant (≤50M) hoặc CFO (>50M) -->

---

## 2. Segregation of Duties (SoD)

### SoD Matrix

| Task A | Task B | Risk | Allowed Together? | Notes |
|--------|--------|------|:-----------------:|-------|
| Create Vendor | Create PO for Vendor | Fraud (fake vendor) | ❌ | Separate roles |
| Create Invoice | Approve Invoice | Fraud | ❌ | Never same person |
| Create Payment | Approve Payment | Theft | ❌ | Never same person |
| Receive Goods | Create GRN | Theft | ⚠️ | Require verification |
| Post Journal Entry | Approve Journal | Fraud | ❌ | Separate roles |
| View Salary Data | Edit Own Salary | Fraud | ❌ | System prevented |
| Create Customer | Apply Credit Limit | Credit risk | ⚠️ | Supervisor review |
| Open Period | Post to Period | Cut-off violation | ⚠️ | Different timing OK |

### SoD Rules by Module

**Accounts Payable:**
- Invoice Creator ≠ Invoice Approver
- Payment Creator ≠ Payment Approver
- Vendor Master Creator ≠ PO Creator

**Accounts Receivable:**
- Invoice Creator ≠ Credit Note Approver
- Customer Creator ≠ Credit Limit Setter

**General Ledger:**
- JE Creator ≠ JE Poster
- Period Opener ≠ Period Closer (same person OK if different time)

---

## 3. Audit Trail Requirements

### Standard Finance Audit Events

| Event | Data to Capture | Retention | Encryption | Access |
|-------|-----------------|-----------|:----------:|--------|
| Create Invoice | User, Timestamp, All fields, IP | 10 years | ✅ | All finance users |
| Edit Invoice | User, Timestamp, Old→New values, Reason | 10 years | ✅ | Manager+ |
| Delete/Void Invoice | User, Timestamp, Reason, Reference | 10 years | ✅ | Director+ |
| Approve Transaction | User, Timestamp, Comments, Decision | 10 years | ✅ | Manager+ |
| Post Journal Entry | User, Timestamp, Debits/Credits | 10 years | ✅ | Manager+ |
| Payment Execution | User, Timestamp, Amount, Bank, Ref | 10 years | ✅ | Director+ |
| Export Data | User, Timestamp, What exported, Format | 5 years | ✅ | IT Admin |
| Period Close | User, Timestamp, Period, Modules closed | 10 years | ✅ | Director+ |

### Required Fields for Every Audit Entry

```
{
  "event_type": "CREATE|EDIT|DELETE|APPROVE|POST|EXPORT",
  "user_id": "string",
  "timestamp": "ISO 8601",
  "ip_address": "string",
  "entity_type": "invoice|payment|journal|...",
  "entity_id": "string",
  "old_value": "object|null",
  "new_value": "object",
  "reason": "string|null",
  "approval_chain": "array|null"
}
```

---

## 4. Risk Control Matrix

### Finance Risks & Controls

| Risk | Likelihood | Impact | Control Type | Implementation |
|------|:----------:|:------:|--------------|----------------|
| Duplicate payment | Medium | High | Preventive | System check invoice# + vendor |
| Fraudulent vendor | Low | High | Preventive | Vendor creation requires approval |
| Unauthorized payment | Medium | High | Preventive | Dual approval > threshold |
| Data entry error | High | Medium | Detective | Exception reports, reconciliation |
| Cut-off violation | Medium | High | Preventive | Period lock, post-dated entries alert |
| Unauthorized access | Low | High | Preventive | Role-based access, MFA |
| Financial statement fraud | Low | Critical | Detective | Independent review, audit trail |
| Tax calculation error | Medium | High | Detective | Automated tax engine, validation |

### Control Categories

| Type | Purpose | Examples |
|------|---------|----------|
| **Preventive** | Ngăn chặn trước khi xảy ra | Authorization, SoD, Validation |
| **Detective** | Phát hiện sau khi xảy ra | Reconciliation, Exception reports, Audit |
| **Corrective** | Sửa chữa sau khi phát hiện | Adjustments, Corrections workflow |

---

## 5. Period-End Controls

### Month-End Close Checklist

| Step | Responsible | Control |
|------|-------------|---------|
| 1. Cut-off all shipments | Operations | GRN cutoff timestamp |
| 2. Accrue unbilled revenue | AR Accountant | Auto-accrual from unbilled items |
| 3. Accrue unbilled expenses | AP Accountant | Auto-accrual from GRN not invoiced |
| 4. Bank reconciliation | Chief Accountant | Match all transactions |
| 5. Intercompany elimination | Chief Accountant | Match IC balances |
| 6. Review unusual items | CFO | Variance analysis |
| 7. Lock sub-ledgers | Chief Accountant | System lock |
| 8. Post closing entries | Chief Accountant | Automated entries |
| 9. Generate financials | System | Automated reports |
| 10. Review & sign-off | CFO | Digital signature |

### Period Lock Rules

| Action | Before Close | After Close |
|--------|:------------:|:-----------:|
| Post transactions | ✅ Allowed | ❌ Blocked |
| Create adjusting entries | ✅ Allowed | ⚠️ Requires override |
| View reports | ✅ Allowed | ✅ Allowed |
| Reopen period | ❌ Not allowed | ⚠️ CFO approval + audit trail |

---

## 6. Compliance Requirements

### Vietnamese Accounting Standards (VAS)

| Requirement | Implementation |
|-------------|----------------|
| Circular 200/2014 | Chart of Accounts structure |
| VAT reporting | Monthly VAT report generation |
| CIT calculation | Quarterly CIT estimation |
| FCT (Foreign Contractor Tax) | Auto-calculation for foreign payments |

### Data Retention

| Document Type | Retention Period |
|---------------|-----------------|
| Invoices (input/output) | 10 years |
| Bank statements | 10 years |
| Contracts | 10 years after expiry |
| Tax reports | 10 years |
| Audit logs | 10 years |
| Employee records | 10 years after termination |

---

## Quick Reference

### Approval Thresholds Summary

| Transaction Type | Threshold | Approver |
|-----------------|-----------|----------|
| Invoice | ≤10M | Chief Accountant |
| Invoice | 10-50M | Chief + Director |
| Invoice | >50M | CFO |
| Payment | ≤10M | Chief Accountant |
| Payment | 10-50M | Chief + Director |
| Payment | >50M | CFO |
| Journal Entry | Any | Chief Accountant |
| Credit Note | ≤5M | Chief Accountant |
| Credit Note | >5M | CFO |

### SoD Violation Detection

```
IF (creator_id == approver_id) THEN
  → Block approval
  → Log violation attempt
  → Notify supervisor
```
