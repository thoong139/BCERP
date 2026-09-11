# Procurement Processes

> Reference file cho procurement-expert agent
> Load file này khi cần hiểu về quy trình trong domain Procurement

## Core Processes

### 1. Purchase Requisition to Purchase Order (PR-to-PO)

```
┌─────────────────────────────────────────────────────────────────┐
│                    PR-TO-PO FLOW                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Requester]          [Manager]        [Procurement]            │
│       │                   │                   │                 │
│       │  Create PR        │                   │                 │
│       │──────────────────>│                   │                 │
│       │                   │                   │                 │
│       │                   │ Approve/Reject    │                 │
│       │                   │──────────────────>│                 │
│       │                   │                   │                 │
│       │                   │                   │ Check budget    │
│       │                   │                   │──────┐          │
│       │                   │                   │<─────┘          │
│       │                   │                   │                 │
│       │                   │                   │ Route:          │
│       │                   │                   │ ├─ Catalog      │
│       │                   │                   │ ├─ RFQ          │
│       │                   │                   │ └─ Direct PO    │
│       │                   │                   │                 │
│       │                   │                   │ Create PO       │
│       │                   │                   │──────┐          │
│       │                   │                   │<─────┘          │
│       │                   │                   │                 │
│       │                   │    PO for Approval (if needed)      │
│       │                   │                   │                 │
│       │                   │                   │ Send to Vendor  │
│       │                   │                   │────────────────>│
│       │                   │                   │                 │
└─────────────────────────────────────────────────────────────────┘
```

**Process Steps:**

| Step | Actor | Action | System Support |
|------|-------|--------|----------------|
| 1 | Requester | Create PR with item details | Form validation, catalog lookup |
| 2 | Manager | Review & approve PR | Approval workflow, notifications |
| 3 | Procurement | Check budget availability | Budget integration |
| 4 | Procurement | Determine sourcing method | Rules engine |
| 5 | Procurement | Issue RFQ or create PO | RFQ template, PO generation |
| 6 | Procurement | Get approval (if over threshold) | Escalation workflow |
| 7 | System | Send PO to vendor | Email/EDI/vendor portal |

---

### 2. RFQ (Request for Quotation) Process

```
Create RFQ → Identify Vendors → Send RFQ → Collect Quotes →
Compare & Score → Recommend → Create PO
```

**RFQ Comparison Matrix:**

| Criteria | Weight | Vendor A | Vendor B | Vendor C |
|----------|--------|----------|----------|----------|
| Price | 40% | $1,000 | $950 | $1,100 |
| Lead Time | 25% | 5 days | 7 days | 3 days |
| Quality Score | 20% | 4.5/5 | 4.0/5 | 4.8/5 |
| Terms | 15% | Net 30 | Net 45 | Net 30 |
| **Total Score** | 100% | **85** | **82** | **88** |

---

### 3. Vendor Onboarding

```
┌─────────────────────────────────────────────────────────┐
│              VENDOR ONBOARDING FLOW                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [Vendor Self-Reg]    [Procurement]    [Finance]        │
│        │                   │               │            │
│        │ Submit application│               │            │
│        │──────────────────>│               │            │
│        │                   │               │            │
│        │                   │ Verify info   │            │
│        │                   │──────┐        │            │
│        │                   │<─────┘        │            │
│        │                   │               │            │
│        │                   │ For financial review       │
│        │                   │──────────────>│            │
│        │                   │               │            │
│        │                   │               │ Check credit│
│        │                   │               │ Setup bank  │
│        │                   │               │            │
│        │                   │<──────────────│            │
│        │                   │               │            │
│        │                   │ Activate vendor            │
│        │                   │──────┐        │            │
│        │                   │<─────┘        │            │
│        │<──────────────────│               │            │
│        │  Welcome email    │               │            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Required Documents:**
- Business registration
- Tax certificates
- Bank account info
- Insurance certificates (if applicable)
- Quality certifications (if applicable)

---

### 4. Vendor Evaluation (Vendor Scorecard)

**Evaluation Dimensions:**

| Dimension | Metrics | Weight |
|-----------|---------|--------|
| Quality | Defect rate, returns, compliance | 25% |
| Delivery | On-time %, lead time accuracy | 25% |
| Cost | Price competitiveness, cost reduction | 25% |
| Service | Responsiveness, issue resolution | 15% |
| Compliance | Documentation, contract terms | 10% |

**Score Bands:**

| Score | Classification | Action |
|-------|----------------|--------|
| 90-100 | Preferred | First choice for orders |
| 75-89 | Approved | Normal ordering |
| 60-74 | Probation | Improvement plan required |
| <60 | Suspended | New orders blocked |

---

## Approval Matrix

### Purchase Order Approval Thresholds

| PO Value | Approver | Turnaround |
|----------|----------|------------|
| < $1,000 | Auto-approve | Immediate |
| $1,000 - $5,000 | Procurement Officer | 1 day |
| $5,000 - $25,000 | Procurement Manager | 2 days |
| $25,000 - $100,000 | Finance Director | 3 days |
| > $100,000 | CFO + CEO | 5 days |

### Policy Exceptions

| Exception Type | Required Approval |
|----------------|-------------------|
| Single source (no competition) | Procurement Manager + Requester's VP |
| Emergency order | Procurement Manager (retro approval) |
| Vendor not in system | Procurement + Finance |
| Override preferred vendor | Category Manager |

---

## Integration Points

| System | Data Flow | Frequency |
|--------|-----------|-----------|
| ERP | PO data, goods receipt | Real-time |
| Finance | Budget check, invoice match | Real-time |
| Inventory | Stock levels, reorder points | Real-time |
| Vendor Portal | RFQ, PO, invoice | Event-driven |

---

## KPIs

| KPI | Target | Measurement |
|-----|--------|-------------|
| PR-to-PO cycle time | <3 days | Average days from PR to PO |
| Cost savings | 5% YoY | (Baseline - Actual) / Baseline |
| Contract compliance | >90% | % spend under contract |
| Vendor on-time delivery | >95% | On-time deliveries / Total |
| Maverick spend | <5% | Non-compliant purchases / Total |
