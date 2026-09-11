# Manufacturing Processes Reference

> Reference file cho manufacturing-expert agent
> Load file này khi cần hiểu về quy trình trong domain Manufacturing

## Core Manufacturing Processes

### 1. Production Planning & Scheduling

```
┌─────────────────────────────────────────────────────────────┐
│                  PRODUCTION PLANNING FLOW                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [Demand Forecast]                                          │
│        │                                                    │
│        ▼                                                    │
│  [MPS - Master Production Schedule]                         │
│        │                                                    │
│        ▼                                                    │
│  [MRP - Material Requirements Planning]                     │
│        │                                                    │
│        ├──────────────┬──────────────┐                     │
│        ▼              ▼              ▼                     │
│   [PR - Purchase   [WO - Work    [Transfer                 │
│    Requisition]     Order]        Orders]                  │
│        │              │              │                     │
│        ▼              ▼              ▼                     │
│   [Execute]       [Execute]      [Execute]                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### MRP Inputs & Outputs

**Inputs:**
- Master Production Schedule (MPS)
- Bill of Materials (BOM)
- Inventory records
- Lead times

**Outputs:**
- Planned orders (production & purchase)
- Action messages (release, expedite, cancel)
- Exception messages

---

### 2. Shop Floor Control

```
┌─────────────────────────────────────────────────────────────┐
│                   WORK ORDER LIFECYCLE                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Created → Released → In Progress → Completed → Closed      │
│     │         │           │            │          │         │
│     │         │           │            │          │         │
│   Plan     Start       Track        Finish    Archive       │
│   dates    materials   production   goods     history       │
│            labor       progress     receipt                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Work Order States:**

| State | Description | Actions |
|-------|-------------|---------|
| Created | Planned but not started | Edit, delete |
| Released | Ready for production | Start operations |
| In Progress | Currently being worked | Log time, complete ops |
| Completed | All operations done | Receive to inventory |
| Closed | Financials settled | Archive, analysis |

---

### 3. BOM Management

**BOM Structure:**

```
Finished Product (Level 0)
    │
    ├── Sub-Assembly A (Level 1)
    │   ├── Component A1 (Level 2)
    │   ├── Component A2 (Level 2)
    │   └── Sub-Sub Assembly (Level 2)
    │       └── Part X (Level 3)
    │
    ├── Sub-Assembly B (Level 1)
    │   └── Component B1 (Level 2)
    │
    └── Raw Material C (Level 1)
```

**BOM Types:**

| Type | Purpose | Example |
|------|---------|---------|
| Engineering BOM | Design view | CAD output |
| Manufacturing BOM | Production view | With routings |
| Sales BOM | Customer view | Configurable |
| Service BOM | Maintenance view | Spare parts |

---

### 4. Routing & Operations

**Routing Structure:**

| Op # | Operation | Work Center | Setup Time | Run Time |
|------|-----------|-------------|------------|----------|
| 10 | Cut material | CUT-01 | 30 min | 5 min/pc |
| 20 | Form shape | FORM-01 | 15 min | 3 min/pc |
| 30 | Weld joints | WELD-01 | 20 min | 8 min/pc |
| 40 | Paint | PAINT-01 | 45 min | 2 min/pc |
| 50 | Inspect | QC-01 | 0 min | 1 min/pc |

---

### 5. Quality Control Process

```
┌─────────────────────────────────────────────────────────────┐
│                    QUALITY CONTROL FLOW                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [Production Complete]                                      │
│         │                                                   │
│         ▼                                                   │
│  [Inspection Required?]                                     │
│         │                                                   │
│    YES  │  NO                                               │
│         │  └──→ [Accept] → [Continue]                       │
│         ▼                                                   │
│  [Perform Inspection]                                       │
│         │                                                   │
│         ▼                                                   │
│  [Result?]                                                  │
│         │                                                   │
│    PASS │  FAIL                                             │
│         │     │                                             │
│         │     ├──→ [Rework] → [Re-inspect]                  │
│         │     │                                             │
│         │     ├──→ [Scrap] → [Record]                       │
│         │     │                                             │
│         │     └──→ [Return to Vendor]                       │
│         │                                                   │
│         ▼                                                   │
│  [Accept] → [Continue Process]                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Inspection Types:**

| Type | When | Sample Size |
|------|------|-------------|
| Receiving | Before stock-in | AQL sampling |
| In-process | During production | Per operation |
| Final | Before stock-in | 100% or sampling |
| Outgoing | Before ship | As required |

---

### 6. Maintenance Process (TPM)

**Maintenance Types:**

| Type | Description | Trigger |
|------|-------------|---------|
| Reactive | Fix when broken | Breakdown |
| Preventive | Scheduled maintenance | Time/usage |
| Predictive | Based on condition | Sensor data |
| Autonomous | Operator daily checks | Shift start |

**Maintenance Workflow:**

```
[Issue Detected]
      │
      ▼
[Create Work Order]
      │
      ▼
[Plan & Schedule]
      │
      ▼
[Assign Technician]
      │
      ▼
[Execute Work]
      │
      ▼
[Complete & Close]
      │
      ▼
[Update History]
```

---

## Key Metrics

### OEE (Overall Equipment Effectiveness)

```
OEE = Availability × Performance × Quality

Availability = Run Time / Planned Production Time
Performance = (Ideal Cycle Time × Total Count) / Run Time
Quality = Good Count / Total Count
```

| OEE Level | Interpretation |
|-----------|----------------|
| < 65% | Needs improvement |
| 65-80% | Average |
| 80-90% | Good |
| > 90% | World class |

### Other Key Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Schedule adherence | Actual / Planned | > 95% |
| First pass yield | Good units / Total | > 98% |
| Scrap rate | Scrap / Total produced | < 2% |
| On-time delivery | On-time orders / Total | > 95% |
| MTBF | Operating time / Failures | Maximize |
| MTTR | Total repair time / Repairs | Minimize |

---

## Production Control Reports

| Report | Frequency | Purpose |
|--------|-----------|---------|
| Production schedule | Daily | Plan execution |
| WIP status | Real-time | Track progress |
| Exception report | Daily | Identify issues |
| Efficiency report | Weekly | Performance review |
| Quality summary | Daily/Weekly | Track quality |
| OEE report | Daily/Weekly | Equipment effectiveness |
