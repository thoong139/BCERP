# Logistics Domain - Operational Analysis Framework

> **Domain**: Logistics / Xuất nhập khẩu
> **Last Updated**: 2026-03-07

---

## 1. Supply Chain Stages
```
┌─────────────┐   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────┐   ┌─────────────┐
│ First-mile  │──▶│ Cross-border    │──▶│ Customs        │──▶│ Last-mile   │──▶│ Warehousing │
│ (Origin)    │   │ Transport        │   │ Clearance      │   │ Delivery    │   │ (If needed)  │
└─────────────┘   └─────────────────┘   └─────────────────┘   └─────────────┘   └─────────────┘
       │                  │                    │                   │                │
       ▼                  ▼                    ▼                   ▼                ▼
    Pickup           Sea/Air/Road       Declaration          Distribution      Storage
    Consolidation    Transit            Inspection           POD              Cross-dock
```

### Stage Details
| Stage | Key Activities | Typical Duration | Critical Metrics |
|-------|----------------|-------------------|-------------------|
| **First-mile** | Pickup, Consolidation, Documentation | 1-3 days | Pickup accuracy, Consolidation efficiency |
| **Cross-border** | Main carriage, Tracking | 7-45 days (sea), 2-7 days (air) | Transit time, Damage rate |
| **Customs** | Declaration, Inspection, Clearance | 1-5 days | Clearance time, Inspection rate |
| **Last-mile** | Distribution, Delivery, POD | 1-3 days | On-time delivery, POD capture |
| **Warehousing** | Receipt, Storage, Dispatch | Variable | Inventory accuracy, Turnaround |

---

## 2. Core Logistics Processes
### Process 1: Export Shipment
```
Order → Booking → Pickup → Consolidation → Customs → Loading → Transit → POD
   │       │        │          │           │        │        │       │
   ▼       ▼        ▼          ▼           ▼        ▼        ▼       ▼
Validate  Carrier  Collect    Combine     Submit   Container Track   Confirm
Terms    Select   Goods      Shipments   Declare  Load     Status  Receipt
```

| Step | Owner | Documents | SLA |
|------|-------|-----------|-----|
| Order | Sales/CS | Proforma invoice | - |
| Booking | Coordinator | Booking confirmation | <4 hours |
| Pickup | Carrier | Pickup receipt | Per schedule |
| Consolidation | Warehouse | Consolidation report | <24 hours |
| Customs | Customs Specialist | Declaration | <24 hours |
| Loading | Terminal | Loading report | Per vessel schedule |
| Transit | Carrier | Tracking updates | Daily |
| POD | Consignee | Delivery receipt | <24 hours after delivery |

### Process 2: Import Shipment
```
Arrival → Unload → Customs → Clearance → Delivery → Receipt → Put-away
    │        │        │          │          │        │        │
    ▼        ▼        ▼          ▼          ▼        ▼        ▼
  Notice  Terminal  Declare    Pay Duty   Schedule Confirm  Store
  Vessel  Handle   Submit     Release    Delivery Goods   Goods
```

| Step | Owner | Documents | SLA |
|------|-------|-----------|-----|
| Arrival | Carrier | Arrival notice | - |
| Unload | Terminal | Cargo manifest | <24 hours |
| Customs | Customs Specialist | Import declaration | <48 hours |
| Clearance | Customs | Release order | Per channel |
| Delivery | Carrier | Delivery order | <48 hours after clearance |
| Receipt | Warehouse | GRN | <24 hours |
| Put-away | Warehouse | Location update | <24 hours |

### Process 3: Customs Declaration (Vietnam)
```
Preparation → HS Code → Valuation → Declaration → Payment → Release
      │           │          │            │          │        │
      ▼           ▼          ▼            ▼          ▼        ▼
   Gather docs Classify Calculate Submit to Duty Green/Yellow/
   Invoice    Product  Duties    VNACCS    Payment   Red Channel
   Contract   HS Code  VAT      System             Processing
```

| Step | Owner | System Actions | Timeline |
|------|-------|----------------|----------|
| Preparation | Customs Specialist | Validate documents | 2-4 hours |
| HS Code | Customs Specialist | Search HS database | 30 min |
| Valuation | System | Auto-calculate duties | 5 min |
| Declaration | Customs Specialist | Submit to VNACCS | 1 hour |
| Payment | Finance | Process duty payment | <4 hours |
| Release | Customs | System release | Per channel |

### Process 4: Cross-docking
```
Inbound → QC → Staging → Outbound → Ship
    │       │      │         │        │
    ▼       ▼      ▼         ▼        ▼
  Receive Check   Hold     Load      Dispatch
  Scan   Sort   Transfer Manifest Depart
```

| Step | Duration | System Support | Success Criteria |
|------|----------|----------------|-------------------|
| Inbound | <1 hour | ASN validation | Complete receipt |
| QC | <30 min | Hold management | Quality passed |
| Staging | <2 hours | Location assignment | Sorted by destination |
| Outbound | <1 hour | Load planning | Complete load |
| Ship | <30 min | Manifest generation | On-time departure |

---

## 3. Task Frequency Analysis
### Daily Tasks
| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Track shipments | Coordinator | 2-3 hours | Multiple systems |
| Update statuses | Coordinator | 1 hour | Manual updates |
| Process documents | Customs Specialist | 2-3 hours | Paper-based |
| Carrier communication | Coordinator | 1-2 hours | Response delays |
| Exception handling | Manager | 1-2 hours | Lack of visibility |

### Weekly Tasks
| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Carrier performance review | Manager | 2 hours | Manual data compilation |
| Cost analysis | Finance + Logistics | 2 hours | Spreadsheet work |
| Route optimization | Coordinator | 2 hours | No tools |
| Compliance check | Customs Specialist | 1 hour | Manual audit |

### Monthly Tasks
| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Carrier evaluation | Manager | 4 hours | Data scattered |
| Cost reporting | Finance + Logistics | 4 hours | Manual consolidation |
| Compliance audit | Compliance | 4 hours | Document gathering |
| Performance review | Manager | 2 hours | Manual KPI tracking |

---

## 4. Decision Support Requirements
### Real-Time Dashboards
| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| Shipment Tracking | Coordinator | Location, Status, ETA, Exceptions |
| Customs Status | Customs Specialist | Declaration status, Clearance time |
| Carrier Performance | Manager | On-time rate, Cost per unit, Damage rate |
| Cost Overview | Director | Freight spend, Cost trends |

### Reports
| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Shipment status | Daily | Operations tracking | Logistics team |
| Customs summary | Daily | Clearance status | Customs team |
| Carrier performance | Weekly | Vendor evaluation | Manager, Director |
| Cost analysis | Monthly | Budget tracking | Finance, Director |
| Compliance report | Monthly | Audit preparation | Compliance, Legal |

---

## 5. Integration Touchpoints
### Internal Integrations
| System | Data Flow | Purpose |
|--------|-----------|---------|
| **Sales/CRM** | Sales → Logistics | Orders, Delivery requirements |
| **Inventory** | Bi-directional | Stock availability, GRN/GI |
| **Finance** | Bi-directional | Cost tracking, Duty payments |
| **Purchasing** | Purchasing → Logistics | Supplier orders, Import docs |

### External Integrations
| System | Data Flow | Purpose |
|--------|-----------|---------|
| **Carriers** | Bi-directional | Booking, Tracking, POD |
| **VNACCS/VCIS** | Bi-directional | Customs declaration, Status |
| **Port Systems** | Read-only | Vessel schedule, Terminal status |
| **Insurance** | Bi-directional | Coverage, Claims |

---

## 6. KPIs & Metrics
### Delivery Metrics
| Metric | Formula | Target |
|--------|---------|--------|
| On-time delivery | On-time / Total × 100 | >95% |
| Transit time | Actual vs. estimated | ≤110% of estimate |
| POD capture rate | With POD / Total × 100 | 100% |
| Damage rate | Damaged / Total × 100 | <1% |

### Cost Metrics
| Metric | Formula | Target |
|--------|---------|--------|
| Cost per unit | Total cost / Units | Per budget |
| Freight cost % | Freight / Product value | <15% |
| Duty accuracy | Accurate / Total × 100 | >99% |

### Compliance Metrics
| Metric | Formula | Target |
|--------|---------|--------|
| Customs clearance time | Avg days to clear | <3 days |
| Inspection rate | Inspected / Total × 100 | <10% |
| Documentation accuracy | Error-free / Total × 100 | >99% |

### Carrier Performance
| Metric | Formula | Target |
|--------|---------|--------|
| On-time pickup | On-time / Total × 100 | >95% |
| Claim rate | Claims / Total shipments | <2% |
| Response time | Avg hours to respond | <4 hours |

---

## Quick Reference: Container Types
| Type | Size (ft) | Capacity (cbm) | Best For |
|------|-----------|----------------|---------|
| 20' Standard | 20 × 8 × 8.5 | 33.2 | Dry cargo, Palletized |
| 40' Standard | 40 × 8 × 8.5 | 67.6 | General cargo |
| 40' High Cube | 40 × 8 × 9.5 | 76.3 | Light, voluminous |
| 45' High Cube | 45 × 8 × 9.5 | 86.1 | Maximum volume |
| Refrigerated | Various | Various | Perishables, Pharma |

## Quick Reference: Transit Times (Vietnam-China)
| Mode | Origin | Destination | Typical Transit |
|------|--------|-------------|------------------|
| Sea | Ho Chi Minh | Shanghai | 7-10 days |
| Sea | Ho Chi Minh | Shenzhen | 6-9 days |
| Sea | Hai Phong | Shanghai | 5-8 days |
| Air | Hanoi | Shanghai | 1-2 days |
| Air | HCMC | Guangzhou | 1-2 days |
| Road | HCMC | Shenzhen | 2-3 days |
