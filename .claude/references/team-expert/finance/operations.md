# Finance Operational Analysis

> Reference file cho finance-expert agent
> Load file này khi cần phân tích từ góc độ vận hành (Operational View)

## 1. Operational Analysis Framework

### Questions to Ask

**Daily Operations:**
- Kế toán spend bao nhiêu time cho task nào mỗi ngày?
- Task nào repetitive, manual, error-prone?
- Peak period (month-end, year-end) khác gì bình thường?

**Decision Points:**
- Decision nào cần data gì, khi nào, từ đâu?
- Decision nào có time pressure?
- Consequence của wrong decision?

**Pain Points:**
- Bottleneck nào trong quy trình hiện tại?
- Workaround nào đang được dùng?
- Task nào nhân viên ghét nhất?

---

## 2. Typical Finance Processes

### 2.1. Invoice Processing (Accounts Payable)

**Current State Flow:**
```
1. Receive invoice (paper/email)     → Vendor
2. Manual data entry into Excel      → AP Clerk (10 min/invoice)
3. Match with PO                     → AP Clerk (3 min/invoice)
4. Match with GRN                    → AP Clerk (3 min/invoice)
5. Code to GL                        → AP Clerk (2 min/invoice)
6. Submit for approval               → AP Clerk (1 min)
7. Review & Approve                  → Chief Accountant (5 min/invoice)
8. Schedule payment                  → Treasury (2 min/invoice)
9. Execute payment                   → Treasury (varies)
10. Record payment                   → AP Clerk (2 min)
```

**Pain Points:**
- Step 2: Manual entry → typos, duplicates
- Step 3-4: If no PO/GRN → invoice sits in "holding"
- Step 7: Approval bottleneck if Chief Accountant busy

**Total time:** 30+ minutes per invoice

**Opportunities:**
- OCR for step 2
- Auto-match for steps 3-4
- Mobile approval for step 7

---

### 2.2. Collections Process (Accounts Receivable)

**Current State Flow:**
```
1. Generate & send invoice           → AR Clerk (5 min/invoice)
2. Monitor aging                     → AR Clerk (daily, 30 min)
3. Send reminders                    → AR Clerk (weekly, 2 hours)
4. Receive payment                   → Bank (auto-import)
5. Identify customer/invoice         → AR Clerk (3 min/payment)
6. Apply payment                     → AR Clerk (2 min/payment)
7. Handle disputes                   → AR Clerk + Sales (varies)
8. Follow up overdue                 → AR Clerk (daily calls)
```

**Pain Points:**
- Step 5: Payment without reference → manual investigation
- Step 7: Disputes require multiple parties
- Step 8: Manual calls inefficient

**Opportunities:**
- Customer portal for payment allocation
- Automated dunning sequences
- Dispute workflow with SLAs

---

### 2.3. Month-End Close

**Typical Timeline:**
```
Day -2:  Pre-close prep (accruals estimate)
Day -1:  Cut-off activities
Day 0:   Period end
Day 1-2: Sub-ledger close (AR, AP, Inventory)
Day 3:   Bank reconciliation
Day 4:   Intercompany elimination
Day 5:   Management reporting
Day 7:   Financial statements ready
```

**Pain Points:**
- Late arriving invoices → accruals inaccurate
- Multi-entity consolidation manual
- Waiting for other departments (Inventory, HR)

**Opportunities:**
- Continuous close (daily reconciliations)
- Automated intercompany matching
- Close checklist with deadlines & alerts

---

## 3. Task Frequency Analysis

### By Persona

| Persona | High Frequency Tasks | Medium Frequency | Low Frequency |
|---------|---------------------|------------------|---------------|
| Accountant | Data entry, reconciliation | Reports | Policy updates |
| Chief Accountant | Approvals, review | Close activities | Audits |
| CFO | Dashboard review | Board reports | Strategy |
| AP Clerk | Invoice processing | Payment batch | Vendor setup |
| AR Clerk | Invoicing, collections | Statements | Credit review |

### Time Distribution (Typical Day)

```
Accountant (8 hours):
├── Data entry:           3 hours (37.5%)
├── Reconciliation:       2 hours (25%)
├── Communication:        1 hour  (12.5%)
├── Reporting:            1 hour  (12.5%)
└── Other:                1 hour  (12.5%)

Chief Accountant (8 hours):
├── Review & Approve:     3 hours (37.5%)
├── Problem solving:      2 hours (25%)
├── Meetings:             2 hours (25%)
└── Reporting:            1 hour  (12.5%)
```

---

## 4. Decision Support Requirements

### Decision Matrix

| Decision Point | Frequency | Data Needed | Current Pain | System Support Needed |
|----------------|-----------|-------------|--------------|----------------------|
| Approve payment | 20/day | Cash position, due date, amount | No real-time cash view | Cash dashboard |
| Prioritize payments | 5/day | Aging, vendor importance | Manual sorting | Auto-prioritize rules |
| Write off bad debt | 5/month | Aging history, collection efforts | Manual calculation | Auto provision calc |
| GL coding | 50/day | Vendor history, expense type | Memorize codes | Auto-suggest coding |
| Release shipment | 30/day | Credit status, outstanding | Check multiple screens | Credit alert on order |
| Approve discount | 10/day | Margin, customer history | No quick view | Margin calculator |

---

## 5. Integration Touchpoints

### Finance ↔ Other Departments

| Department | Data Flow | Frequency | Pain Point |
|------------|-----------|-----------|------------|
| Sales | AR invoices, credit status | Real-time | Credit check delay |
| Procurement | AP invoices, PO matching | Daily | PO-invoice mismatch |
| Warehouse | Inventory valuation | Daily | GRN delay |
| HR | Payroll data | Monthly | Manual file transfer |
| Operations | Cost allocation | Monthly | Allocation rules unclear |

### Finance ↔ External Systems

| System | Data Flow | Frequency | Integration Type |
|--------|-----------|-----------|-----------------|
| Bank | Statements, payments | Daily | API/Batch |
| Tax Authority | VAT, CIT reports | Monthly/Quarterly | API |
| Auditor | Trial balance, samples | Annual | Export |
| Customers | Invoices, statements | Daily | Email/Portal |
| Vendors | Payments, remittance | Weekly | Email/Portal |

---

## 6. Operational Metrics (KPIs)

### Efficiency Metrics

| Metric | Formula | Target | Typical Baseline |
|--------|---------|--------|-----------------|
| Invoice processing time | Total time / # invoices | <15 min | 30-45 min |
| First-pass match rate | Matched first try / Total | >80% | 50-60% |
| Payment on-time rate | On-time / Total | >95% | 80-85% |
| Collection effectiveness | Collected / Billed | >95% | 85-90% |
| Close cycle time | Days to close | ≤5 days | 7-10 days |

### Quality Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Data entry error rate | Errors / Transactions | <1% |
| Journal entry corrections | Corrections / Total | <5% |
| Duplicate payment rate | Duplicates / Payments | <0.1% |
| Reconciliation variance | Variance / Volume | <$1,000 |

---

## 7. Operational Analysis Template

Khi phân tích một process, sử dụng template sau:

```markdown
## Process: [Name]

### Current State
| Step | Actor | Tool | Time | Pain Point |
|------|-------|------|------|------------|
| 1 | | | | |
| 2 | | | | |

### Decision Points
| Decision | Made By | Data Needed | Consequence |
|----------|---------|-------------|-------------|
| | | | |

### Bottlenecks
1. [Bottleneck 1]: [Why it's slow]
2. [Bottleneck 2]: [Why it's slow]

### Opportunities
1. [Opportunity 1]: [Expected improvement]
2. [Opportunity 2]: [Expected improvement]

### Recommended System Support
| Requirement | Supports Step | Expected Benefit |
|-------------|---------------|-----------------|
| | | |
```

---

## Quick Reference

### Common Pain Points by Area

| Area | #1 Pain Point | #2 Pain Point |
|------|---------------|---------------|
| AP | Manual data entry | PO matching failures |
| AR | Unidentified payments | Collection follow-up |
| GL | Month-end close time | Intercompany reconciliation |
| Treasury | Cash visibility | Bank connectivity |
| Reporting | Manual consolidation | Drill-down capability |

### Quick Wins (Low effort, High impact)

1. **Automated bank feeds** - Eliminates manual statement download
2. **Invoice OCR** - Reduces data entry time by 70%
3. **Approval workflows** - Mobile approval reduces cycle time
4. **Customer portal** - Self-service reduces AR calls
5. **Auto-matching rules** - Increases first-pass match rate
