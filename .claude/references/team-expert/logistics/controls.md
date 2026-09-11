# Logistics Domain - Controls & Compliance

> **Domain**: Logistics / Xuất nhập khẩu
> **Last Updated**: 2026-03-07

---

## 1. Shipment Authorization Matrix

### By Shipment Value

| Shipment Value | Coordinator | Manager | Director | CEO |
|-----------------|:-----------:|:------:|:--------:|:---:|
| ≤50M VND | ✅ | ✅ | ✅ | ✅ |
| 50M-200M VND | ⚠ Request | ✅ | ✅ | ✅ |
| 200M-1B VND | ❌ | ⚠ Request | ✅ | ✅ |
| >1B VND | ❌ | ❌ | ⚠ Request | ✅ |

### By Shipment Type
| Shipment Type | Standard Process | Additional Approvals |
|----------------|------------------|-------------------|
| Domestic | Coordinator creates | None |
| Export | Coordinator creates | Manager review |
| Import | Coordinator creates | Manager + Finance (duty) |
| Cross-border (complex) | Manager creates | Director + Legal |

---

## 2. Customs Compliance Controls
### Declaration Types by Shipment

| Declaration Type | Code | Use Case | Documents Required |
|-------------------|------|----------|-------------------|
| Nhập khẩu kinh doanh | A11 | Raw materials | Invoice, Packing list, Contract |
| Nhập tiêu dùng | A12 | Consumables | Invoice, Packing list |
| Xuất khẩu thương mại | E31 | Finished goods | Invoice, Packing list, Contract |
| Xuất uỷ | E62 | Export processing | Invoice, Processing contract |
| Tạm nhập tái xuất | A43 | Re-export | Original import docs |
| Chuyển cả | | Cửa khẩu | | Internal transfer | Transfer documents |

### HS Code Validation Rules

| Product Category | Validation Level | Documentation |
|------------------|-----------------|--------------|
| Standard products | Auto-validate | HS Code certificate |
| Chemical products | Manual + Legal | MSDS, Permit |
| Electronics | Auto-validate | Certificate of origin |
| Food products | Manual + Health | Health certificate |
| Restricted items | Manual + Permit | Import/export permit |

---

## 3. Carrier Management Controls
### Carrier Selection Criteria
| Criterion | Weight | Verification |
|----------|--------|------------|
| Rate competitiveness | 30% | Market comparison |
| Service quality | 25% | Performance history |
| Coverage | 20% | Route availability |
| Financial stability | 15% | Credit check |
| Compliance | 10% | License verification |

### Carrier Performance Monitoring
| KPI | Target | Action if Missed |
|-----|--------|-------------------|
| On-time pickup | >95% | Warning at 90% |
| On-time delivery | >95% | Warning at 90% |
| Damage rate | <1% | Review at 1% |
| Documentation accuracy | 100% | Warning at 99% |
| Customer complaints | <2% | Review at 2% |

---

## 4. Incoterms 2020 Controls
### Responsibility Matrix
| Incoterm | Seller Risk Until | Buyer Risk From | Recommended For |
|---------|---------------------|------------------|-----------------|
| EXW | Seller's premises | Seller's premises | Maximum buyer control |
| FOB | On board vessel | On board vessel | Sea freight, standard |
| CIF | Named port of destination | Named port of destination | Sea freight, convenience |
| DAP | Named place of destination | Named place of destination | Full seller service |
| DDP | Final destination | Final destination | Full service, hassle-free |

### Cost Allocation by Incoterm
| Cost Component | EXW | FOB | CIF | DAP | DDP |
|----------------|:---:|---:|:---:|:---:|:---:|
| Packaging | Seller | Seller | Seller | Seller | Seller |
| Loading | Buyer | Seller | Seller | Seller | Seller |
| Main carriage | Buyer | Seller | Seller | Seller | Seller |
| Export clearance | Buyer | Seller | Seller | Seller | Seller |
| Freight | Buyer | Buyer | Seller | Seller | Seller |
| Import clearance | Buyer | Buyer | Buyer | Seller | Seller |
| Destination delivery | Buyer | Buyer | Buyer | Buyer | Seller |
| Import duty | Buyer | Buyer | Buyer | Buyer | Seller |

---

## 5. Document Retention Requirements
### Mandatory Retention
| Document | Retention Period | Storage | Notes |
|----------|------------------|--------|-------|
| Bill of Lading | 5+ years | Digital + Physical | Original required |
| Commercial Invoice | 5+ years | Digital + Physical | For customs |
| Packing List | 5+ years | Digital | Detailed contents |
| Customs Declaration | 5+ years | Digital | VNACCS records |
| Certificate of Origin | 5+ years | Digital + Physical | If applicable |
| Insurance Certificate | Policy term | Digital | As long as valid |
| Delivery Receipt (POD) | 5+ years | Digital | Proof of delivery |

---

## 6. Insurance Controls
### Coverage Requirements
| Shipment Type | Min Coverage | Recommended | Notes |
|----------------|--------------|-------------|-------|
| Domestic | Invoice value | Invoice + 10% | Standard cargo |
| International (sea) | CIF value | All-risk | Marine cargo clauses |
| International (air) | Invoice value | All-risk | Air cargo clauses |
| High-value | Declared value | All-risk + War risk | Electronics, luxury |
| Dangerous goods | Declared value | Specialized | IMO compliance required |

---

## 7. Audit Trail Requirements
### Events to Log
| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Shipment create | User, Details, Carrier, Value | 7 years |
| Status update | User, Old→New, Timestamp, Location | 7 years |
| Customs declaration | User, Declaration#, Status | 7 years |
| Document upload | User, Document type, Reference | 7 years |
| Cost change | User, Old→New, Reason | 7 years |
| Exception log | User, Issue, Resolution | 7 years |

---

## Quick Reference: Vietnam Customs (VNACCS/VCIS)
| Declaration Stage | System Status | Next Action |
|-------------------|---------------|-------------|
| Draft | Saved | Submit to customs |
| Submitted | Pending | Wait for processing |
| Accepted | Registered | Wait for channel |
| Green Channel | Auto-cleared | Release goods |
| Yellow Channel | Document check | Submit additional docs |
| Red Channel | Physical inspection | Coordinate inspection |

---

## Quick Reference: Control Checklist
### Before Shipment Booking
- [ ] Carrier selected and approved
- [ ] Rate verified within budget
- [ ] Insurance coverage confirmed
- [ ] Incoterm agreed with customer
- [ ] Customs requirements identified

### Before Customs Declaration
- [ ] HS Codes verified
- [ ] Documents complete
- [ ] Values accurate
- [ ] Origin confirmed
- [ ] Duties calculated

### Before Delivery Confirmation
- [ ] POD received
- [ ] Documents archived
- [ ] Costs finalized
- [ ] Performance logged
