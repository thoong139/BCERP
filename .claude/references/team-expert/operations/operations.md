# Operations Domain - Operational Analysis Framework

> **Domain**: Operations / Vận hành Doanh nghiệp
> **Last Updated**: 2026-03-07

---

## 1. Value Chain Stages

```
┌──────────────┐   ┌───────────────┐   ┌────────────────┐   ┌──────────────┐
│Inbound Logis.│──▶│  Operations   │──▶│Outbound Logis. │──▶│  After-sales │
└──────────────┘   └───────────────┘   └────────────────┘   └──────────────┘
       │                  │                     │                   │
       ▼                  ▼                     ▼                   ▼
   Receiving         Production/           Shipping            Returns
   Inspection        Assembly              Delivery            Support
   Put-away          Packaging             Tracking            Warranty
```

### Stage Activities

| Stage | Key Activities | System Support |
|-------|----------------|----------------|
| **Inbound Logistics** | Receiving, QC, Put-away | GRN, Location management |
| **Operations** | Production, Assembly, Packaging | WO, Routing, BOM |
| **Outbound Logistics** | Picking, Packing, Shipping | SO, Pick/Pack, Ship |
| **After-sales** | Returns, Warranty, Support | RMA, Service orders |

---

## 2. Core Operations Processes

### Process 1: Goods Receipt (GRN)

```
Truck Arrival → Unload → QC Check → Accept/Reject → Put-away → System Update
      │           │          │           │             │           │
      ▼           ▼          ▼           ▼             ▼           ▼
   Check ASN   Count items Inspect    Decision      Find bin    Post GRN
   Schedule    Note qty   Sample     Document      Scan to     Update
              Discrepancy Test       Results       Location    Stock
```

| Step | Owner | System Actions | SLA |
|------|-------|----------------|-----|
| Arrival | Receiving | Check ASN | <30 min |
| Unload | Receiving | Create receipt | <2 hours |
| QC | QC Inspector | Hold if needed | <4 hours |
| Accept | Receiving | Update status | Immediate |
| Put-away | Warehouse | Assign location | <8 hours |
| Post | System | Update inventory | Immediate |

### Process 2: Goods Issue (GI)

```
Order Release → Pick List → Picking → Verification → Packing → Ship
      │            │           │           │            │        │
      ▼            ▼           ▼           ▼            ▼        ▼
   Allocate     Generate    Scan pick   Match order   Pack    Manifest
   Stock        Routes      Items       to pick list  Label   Update
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Release | System | Allocate stock | Stock available |
| Pick list | System | Generate routes | Optimize path |
| Picking | Picker | Scan items | Location match |
| Verify | Packer | Validate qty | Order match |
| Pack | Packer | Generate labels | Weight check |
| Ship | Shipping | Create manifest | Complete order |

### Process 3: Stock Taking

```
Plan → Freeze → Count → Reconcile → Investigate → Adjust → Unfreeze
   │      │        │         │            │          │        │
   ▼      ▼        ▼         ▼            ▼          ▼        ▼
 Select  Block   Physical  Compare    Find root   Post     Resume
 Items   Txns     Count    Variances   Cause      Adj      Operations
```

| Type | Frequency | Scope | Tolerance |
|------|-----------|-------|-----------|
| Cycle count | Daily | ABC A items | 0.5% |
| Cycle count | Weekly | ABC B items | 1% |
| Full count | Annual | All items | 2% |
| Spot check | Ad-hoc | Suspicion | 0% |

### Process 4: Inventory Replenishment

```
ROP Check → Generate PR → Approve → Create PO → Receive → Update
    │          │            │          │         │        │
    ▼          ▼            ▼          ▼         ▼        ▼
 Auto-check  System      Manager    Procure  Warehouse  ROP
 vs ROP      creates     reviews    Orders   Receives   Recalc
```

| Trigger | Action | System Support |
|---------|--------|----------------|
| Stock ≤ ROP | Auto-generate PR | Alert + PR creation |
| PR approved | Create PO | PO generation |
| PO received | Update stock | GRN process |
| Stock updated | Recalculate ROP | Auto-adjust |

---

## 3. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Receive goods | Receiving clerk | 2-3 hours | Paper process |
| Pick orders | Picker | 4-5 hours | Manual routes |
| Pack shipments | Packer | 3-4 hours | No automation |
| Update records | Inventory clerk | 1-2 hours | Manual entry |
| Check stock levels | Manager | 30 min | No alerts |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Cycle counting | Inventory clerk | 4 hours | Manual process |
| Replenishment planning | Manager | 2 hours | Spreadsheet |
| Vendor follow-up | Procurement | 2 hours | No tracking |
| Performance review | Manager | 1 hour | Manual reports |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Inventory reconciliation | Manager + Finance | 4-8 hours | Manual matching |
| ABC classification | Manager | 2 hours | Spreadsheet |
| Slow-moving analysis | Manager | 2 hours | Manual analysis |
| KPI reporting | Manager | 2 hours | Manual compilation |

### Annual Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Physical inventory count | All warehouse | 2-3 days | Operations halt |
| Warehouse reorganization | Manager | 1 week | Manual planning |
| Vendor evaluation | Procurement | 4 hours | Manual data |
| Budget planning | Manager | 4 hours | Spreadsheet |

---

## 4. Decision Support Requirements

### Real-Time Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| Inventory Status | Warehouse Manager | Stock levels, ROP alerts, Aging |
| Receiving | Receiving clerk | Pending receipts, Dock utilization |
| Shipping | Shipping clerk | Orders to ship, Carrier schedule |
| Operations Overview | Director | Throughput, Accuracy, Efficiency |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Stock status | Daily | Current inventory | Operations, Sales |
| Movement report | Daily | Transactions | Manager |
| Variance report | Weekly | Accuracy tracking | Manager, Finance |
| Aging report | Weekly | Slow-moving items | Manager, Finance |
| Vendor performance | Monthly | Delivery, Quality | Procurement |
| KPI dashboard | Monthly | Performance review | Director |

---

## 5. Integration Touchpoints

### Internal Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **Sales/CRM** | Sales → Operations | Orders, Reservations |
| **Finance** | Bi-directional | Valuation, GL posting |
| **Procurement** | Bi-directional | PO, Receiving |
| **Production** | Bi-directional | WO, Material issue |

### External Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **Carriers** | Bi-directional | Shipping labels, Tracking |
| **Vendors** | Bi-directional | ASN, PO status |
| **WMS devices** | Bi-directional | Scanning, Mobile |
| **Warehouse automation** | Bi-directional | AS/RS, Conveyors |

---

## 6. KPIs & Metrics

### Accuracy Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Inventory Accuracy | Correct items / Total items × 100 | >99% |
| Location Accuracy | Correct locations / Total × 100 | >99.5% |
| Pick Accuracy | Correct picks / Total picks × 100 | >99.9% |
| Ship Accuracy | Correct shipments / Total × 100 | >99.5% |

### Efficiency Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Receiving Productivity | Units received / Labor hours | Per benchmark |
| Picking Productivity | Lines picked / Labor hours | Per benchmark |
| Dock-to-Stock Time | Hours from receipt to put-away | <24 hours |
| Order Cycle Time | Hours from release to ship | <4 hours |

### Service Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Fill Rate | Orders filled complete / Total orders | >98% |
| On-time Shipment | Shipments on time / Total shipments | >95% |
| Stock-out Rate | Stock-outs / Total items | <2% |

### Inventory Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Inventory Turnover | COGS / Average inventory | >12x/year |
| Days of Inventory | Avg inventory / Daily COGS | <30 days |
| Slow-moving % | Slow-moving value / Total value | <10% |
| Carrying Cost | Total carrying cost / Avg inventory | <25% |

---

## Quick Reference: Storage Strategies

| Strategy | Description | Best For |
|----------|-------------|----------|
| **Fixed Location** | Each SKU has permanent location | Small operations |
| **Random Location** | Put-away to any available bin | High-volume, WMS |
| **Zone Picking** | Pick by zone, consolidate | Large warehouses |
| **Wave Picking** | Batch orders by time window | E-commerce |
| **Cross-docking** | Skip storage, direct to shipping | High-turnover |

## Quick Reference: Reorder Point Formula

```
ROP = (Average Daily Usage × Lead Time) + Safety Stock

Where:
- Average Daily Usage = Annual demand / 365
- Lead Time = Days from order to receipt
- Safety Stock = Z-score × Std Dev × √Lead Time

Typical Z-scores:
- 90% service level: 1.28
- 95% service level: 1.65
- 99% service level: 2.33
```
