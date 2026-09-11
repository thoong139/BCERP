# Operations Domain - Controls & Access Management

> **Domain**: Operations / Vận hành Doanh nghiệp
> **Last Updated**: 2026-03-07

---

## 1. Stock Authorization Matrix

### By Action Type

| Action | Inventory Clerk | Warehouse Manager | Operations Director | Finance |
|--------|:---------------:|:-----------------:|:-------------------:|:-------:|
| Receive goods (GRN) | ✅ | ✅ | ✅ | ⚠ View |
| Issue goods (GI) | ✅ | ✅ | ✅ | ⚠ View |
| Transfer (warehouse) | ✅ | ✅ | ✅ | ⚠ View |
| Adjust (+/- small) | ⚠ ≤5% | ✅ ≤10% | ✅ | ✅ Approve |
| Adjust (+/- large) | ❌ | ⚠ Request | ✅ Approve | ✅ Approve |
| Write-off | ❌ | ⚠ Request | ✅ Recommend | ✅ Approve |
| Void transaction | ❌ | ✅ | ✅ | ⚠ View |

### Adjustment Thresholds

| Adjustment Type | Clerk | Manager | Director | Finance Approval |
|-----------------|:-----:|:-------:|:--------:|:----------------:|
| Quantity variance (≤5%) | ✅ | - | - | No |
| Quantity variance (5-10%) | ❌ | ✅ | - | No |
| Quantity variance (>10%) | ❌ | ⚠ | ✅ | If >50M VND |
| Value adjustment | ❌ | ⚠ | ✅ | If >20M VND |
| Write-off (any) | ❌ | ⚠ | ⚠ | ✅ Required |

---

## 2. Negative Stock Prevention

### Hard Stop Rules

| Condition | System Action | Override |
|-----------|---------------|----------|
| GI would cause negative stock | Block transaction | Manager override with reason |
| Transfer from insufficient stock | Block transaction | Manager override with reason |
| SO allocation exceeds available | Block allocation | Director approval required |

### Negative Stock Exceptions

| Exception | Allowed When | Requires |
|-----------|--------------|----------|
| Emergency issue | Production down | Director approval +补货 plan |
| Interim receipt | Goods received, not posted | Must post within 24 hours |

---

## 3. Valuation Method Controls

### FIFO Enforcement

| Rule | Description |
|------|-------------|
| Layer tracking | System tracks cost layers by receipt date |
| Issue logic | Always issue from oldest layer first |
| Layer depletion | Alert when layer drops below threshold |
| Audit | Daily layer balance validation |

### Cost Layer Rules

| Event | System Action |
|-------|---------------|
| Receipt | Create new cost layer |
| Issue | Deplete oldest layers |
| Transfer | Move layers as-is |
| Adjustment | Adjust at current average |
| Revaluation | Create adjustment layer |

---

## 4. ABC Classification Controls

### Classification Rules

| Class | % Items | % Value | Control Level | Review Frequency |
|-------|:-------:|:-------:|:-------------:|:----------------:|
| **A** | 10-20% | 70-80% | Tight | Weekly |
| **B** | 20-30% | 15-25% | Moderate | Monthly |
| **C** | 50-60% | 5-10% | Simple | Quarterly |

### Control by Class

| Control | A Items | B Items | C Items |
|---------|:-------:|:-------:|:-------:|
| Physical count | Monthly | Quarterly | Annual |
| Reorder point | Tight monitoring | Standard | Min/max |
| Safety stock | Higher | Moderate | Lower |
| Cycle count | Weekly | Monthly | Quarterly |
| Bin accuracy | 99.5% | 98% | 95% |

---

## 5. Approval Workflows

### Purchase Requisition Approval

| PR Value | Requester | Manager | Procurement | Director | Finance |
|----------|:---------:|:-------:|:-----------:|:--------:|:-------:|
| ≤20M VND | ✅ | ✅ | - | - | - |
| 20-100M VND | ✅ | ✅ | ✅ | - | - |
| 100-500M VND | ✅ | ✅ | ✅ | ✅ | - |
| >500M VND | ✅ | ✅ | ✅ | ✅ | ✅ |

### Stock Adjustment Approval

```
Adjustment Request → Validation → Approval → Post → Audit
        │               │            │         │       │
        ▼               ▼            ▼         ▼       ▼
    Clerk/Manager    System       Per        System   Log
    identifies       validates   matrix     posts    for audit
    variance         reason      approves   entry    review
```

### Write-off Approval

| Value | Initiator | Manager | Director | Finance | CEO |
|-------|:---------:|:-------:|:--------:|:-------:|:---:|
| ≤5M VND | ✅ | ✅ | - | ⚠ | - |
| 5-20M VND | ✅ | ✅ | ✅ | ⚠ | - |
| 20-100M VND | ✅ | ✅ | ✅ | ✅ | - |
| >100M VND | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 6. Audit Trail Requirements

### Transactions to Log

| Transaction | Data Captured | Retention |
|-------------|---------------|-----------|
| GRN (Receipt) | User, PO#, Vendor, Items, Qty, Location | 10 years |
| GI (Issue) | User, Order#, Items, Qty, Cost, Reason | 10 years |
| Transfer | User, From/To, Items, Qty, Reason | 10 years |
| Adjustment | User, Old→New, Reason, Approver | 10 years |
| Write-off | User, Items, Value, Reason, Approvals | 10 years |
| Void | User, Original ref, Reason | 10 years |

### Physical Count Audit

| Event | Data Captured |
|-------|---------------|
| Count start | User, Date/Time, Location |
| Count entry | User, Item, System qty, Counted qty |
| Variance approval | User, Variance, Reason, Approver |
| Adjustment post | User, Adjustment details |

---

## 7. Period Controls

### Month-End Close

| Step | Action | Owner | Deadline |
|------|--------|-------|----------|
| 1 | Freeze transactions | System | D+1 9AM |
| 2 | Complete GRN/GI pending | Warehouse | D+1 12PM |
| 3 | Run inventory valuation | System | D+1 2PM |
| 4 | Review adjustments | Manager | D+1 4PM |
| 5 | Close period | Finance | D+2 |
| 6 | Post to GL | System | D+2 |

### Year-End Physical Count

| Activity | Timing | Participants |
|----------|--------|--------------|
| Pre-count planning | 2 weeks before | Manager, Finance |
| Freeze inventory | Count day 0:00 | System |
| Physical count | Count day | All warehouse staff |
| Variance investigation | D+1 | Manager, QC |
| Adjustments | D+2 | Manager, Finance approval |
| Unfreeze | D+3 | System |

---

## Quick Reference: Control Checklist

### Before GRN Posting
- [ ] PO exists and approved
- [ ] Vendor delivery note matches
- [ ] Quantity matches PO
- [ ] Quality inspection complete
- [ ] Location assigned

### Before GI Posting
- [ ] Sufficient stock available
- [ ] Order/requisition approved
- [ ] Picked items verified
- [ ] Cost calculated

### Before Adjustment
- [ ] Physical count completed
- [ ] Variance investigated
- [ ] Root cause documented
- [ ] Approval obtained

### Before Period Close
- [ ] All transactions posted
- [ ] Reconciliations complete
- [ ] Adjustments reviewed
- [ ] Valuation run completed
