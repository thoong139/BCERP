# Sales Domain - Controls & Access Management

> **Domain**: Sales / Quản trị Bán hàng
> **Last Updated**: 2026-03-07

---

## 1. Discount Approval Matrix

### By Discount Percentage

| Discount Level | Sales Rep | Inside Sales | Sales Manager | Sales Director | CEO |
|----------------|:---------:|:------------:|:-------------:|:--------------:|:---:|
| Standard (0%) | ✅ | ✅ | ✅ | ✅ | ✅ |
| ≤5% | ✅ | ✅ | ✅ | ✅ | ✅ |
| 5-10% | ❌ | ❌ | ✅ | ✅ | ✅ |
| 10-15% | ❌ | ❌ | ✅ | ✅ | ✅ |
| 15-25% | ❌ | ❌ | ❌ | ✅ | ✅ |
| >25% | ❌ | ❌ | ❌ | ❌ | ✅ |

### By Deal Value

| Deal Value | Sales Rep | Sales Manager | Sales Director | CEO |
|------------|:---------:|:-------------:|:--------------:|:---:|
| <50M VND | ✅ | ✅ | ✅ | ✅ |
| 50M-200M VND | ⚠ Manager approve | ✅ | ✅ | ✅ |
| 200M-1B VND | ❌ | ⚠ Director approve | ✅ | ✅ |
| >1B VND | ❌ | ❌ | ⚠ CEO approve | ✅ |

---

## 2. Territory & Account Access

### Territory Rules

| Rule | Description | Enforcement |
|------|-------------|-------------|
| Geographic | By region/province | System assignment |
| Industry | By customer industry | System assignment |
| Product | By product line | System assignment |
| Named Account | Strategic accounts | Manual assignment |

### Account Access Matrix

| Account Type | Sales Rep | Inside Sales | Sales Manager | Sales Director |
|--------------|:---------:|:------------:|:-------------:|:--------------:|
| Own accounts | ✅ Full | ✅ Full | ✅ Full | ✅ Full |
| Team accounts | ❌ | ❌ | ✅ Full | ✅ Full |
| Named accounts | ⚠ Assigned only | ❌ | ✅ View | ✅ Full |
| All accounts | ❌ | ❌ | ⚠ Territory | ✅ Full |

### Account Ownership Rules

| Scenario | Rule | Override Authority |
|----------|------|--------------------|
| New account | Round-robin or Territory | Sales Manager |
| Unassigned account | Pool → Manager assigns | Sales Manager |
| Account conflict | Manager decides | Sales Director |
| Named account | Pre-assigned | Sales Director |

---

## 3. Quotation Controls

### Quotation Validity

| Quotation Type | Validity Period | Extension |
|----------------|-----------------|-----------|
| Standard | 30 days | 1 extension (15 days) |
| Project | 60 days | Case-by-case |
| Framework Agreement | 90 days | Renewal process |

### Version Control Rules

| Action | Rule | Audit |
|--------|------|-------|
| Create quote | Auto-version 1.0 | Log user, timestamp |
| Edit draft | Update in-place | Log changes |
| Send to customer | Lock version | Cannot edit, must create new |
| Customer revision | Create new version | Link to previous |
| Win/Lose | Close all versions | Final status |

### Quote Approval Workflow

```
Create → Calculate Margin → Check Discount → Approval → Send
   │           │                 │              │         │
   ▼           ▼                 ▼              ▼         ▼
 Rep       System            If >5%         Per matrix   Rep
                             Manager        matrix       (locked)
```

---

## 4. Pipeline Management Controls

### Stage Movement Rules

| From Stage | To Stage | Criteria | Validation |
|------------|----------|----------|------------|
| Lead | Qualified | BANT qualified | Required fields complete |
| Qualified | Proposal | Demo done, stakeholder identified | Opportunity value set |
| Proposal | Negotiation | Quote sent, customer feedback | Quote version locked |
| Negotiation | Closed Won | Contract signed, PO received | Won amount = contract |
| Any | Closed Lost | Reason documented | Loss reason required |

### Pipeline Hygiene Controls

| Control | Frequency | Enforcement |
|---------|-----------|-------------|
| Stale opportunity alert | Weekly | If no activity >14 days |
| Stage validation | On change | Required fields check |
| Close date sanity | Weekly | Flag past-due not closed |
| Duplicate detection | On create | Match by company, contact |

---

## 5. Commission Controls

### Commission Plan Types

| Plan Type | Calculation | Frequency |
|-----------|-------------|-----------|
| Revenue-based | % of revenue | Monthly |
| Gross Margin | % of gross margin | Monthly |
| Tiered | Rate increases at thresholds | Quarterly |
| MBO | % tied to objectives | Quarterly |

### Commission Calculation Rules

| Rule | Description |
|------|-------------|
| Credit date | Invoice date, not close date |
| Split credit | Requires manager approval |
| Clawback | If payment not received within 90 days |
| Draw | Recoverable advance against commission |

### Commission Approval

| Action | Initiator | Approver |
|--------|----------|----------|
| Calculate | System | Sales Ops review |
| Adjust | Sales Ops | Sales Director + Finance |
| Payroll submission | Sales Ops | Finance |

---

## 6. Audit Trail Requirements

### Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Opportunity create | User, Account, Value, Stage | 7 years |
| Opportunity update | User, Field, Old→New, Reason | 7 years |
| Quote create | User, Customer, Products, Price | 7 years |
| Quote approve | User, Discount, Margin, Reason | 7 years |
| Stage change | User, Old→New, Close date | 7 years |
| Win/Lose | User, Amount, Reason, Competitor | 7 years |
| Commission calc | User, Amount, Rate, Period | 7 years |

### Sensitive Data Access Log

| Data Accessed | Who | When | Purpose |
|---------------|-----|------|---------|
| Other rep's pipeline | Manager+ | Timestamp | Coaching, Forecast |
| Commission data | Ops, Director | Timestamp | Calculation, Review |
| Discount history | Manager+ | Timestamp | Approval analysis |

---

## 7. Integration Controls

### ERP Integration

| Data | Direction | Trigger | Validation |
|------|-----------|---------|------------|
| Customer | Bi-directional | Create/Update | Tax ID, Address |
| Product | ERP → CRM | Price change | Active status |
| Inventory | ERP → CRM | Real-time | Available quantity |
| Order | CRM → ERP | Closed Won | Credit check |
| Invoice | ERP → CRM | Invoice created | Revenue recognition |

### Finance Handoff

| Milestone | Trigger | Data Transferred |
|-----------|---------|------------------|
| Order creation | Closed Won | Customer, Products, Terms |
| Credit check | Pre-order | Customer credit status |
| Revenue recognition | Invoice | Amount, Date, GL codes |
| Commission calc | Post-payment | Sales credit, Amount |

---

## Quick Reference: Approval Checklist

### Before Discount Approval
- [ ] Margin impact calculated
- [ ] Customer history reviewed
- [ ] Competitive situation documented
- [ ] Strategic value assessed

### Before Quote Approval
- [ ] Product availability confirmed
- [ ] Payment terms appropriate
- [ ] Delivery date achievable
- [ ] Terms & conditions reviewed

### Before Commission Credit
- [ ] Deal properly closed
- [ ] Invoice generated
- [ ] Payment received (or per policy)
- [ ] Split credit approved
