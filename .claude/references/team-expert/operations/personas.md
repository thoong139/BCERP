# Operations Domain - User Personas

> **Domain**: Operations / Vận hành Doanh nghiệp
> **Last Updated**: 2026-03-07

---

## Persona 1: Warehouse Manager

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Warehouse Manager |
| **Experience** | 5-10 năm |
| **Report to** | Operations Director |
| **Focus** | Warehouse operations, Team management |

### Daily Tasks
1. Review daily receiving và shipping schedules
2. Monitor inventory levels
3. Coordinate with procurement and sales
4. Manage warehouse staff
5. Handle exception situations

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Prioritize orders | Execute | Order urgency, Stock availability |
| Approve overtime | Execute | Workload, Budget |
| Adjust bin locations | Execute | Inventory analysis |
| Write-off damaged goods | Recommend | Damage report, Value |

### Pain Points
- No real-time inventory visibility
- Manual picking routes
- Paper-based processes
- Poor space utilization

### Must-have Features
- ✅ Real-time inventory tracking
- ✅ Optimized pick paths
- ✅ Mobile scanning
- ✅ Space utilization analytics

---

## Persona 2: Inventory Clerk

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Inventory Clerk / Warehouse Staff |
| **Experience** | 1-3 năm |
| **Report to** | Warehouse Manager |
| **Focus** | Daily warehouse operations |

### Daily Tasks
1. Receive goods (GRN)
2. Pick and pack orders
3. Conduct stock counts
4. Update inventory records
5. Report discrepancies

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Accept delivery | Execute | PO match, Quality check |
| Pick order | Execute | Pick list, Location |
| Report damage | Execute | Photo, Description |
| Small adjustment (≤threshold) | Execute | Count variance |

### Pain Points
- Paper pick lists
- Inaccurate locations
- No mobile devices
- Hard to find items

### Must-have Features
- ✅ Mobile scanning app
- ✅ Digital pick lists
- ✅ Location accuracy
- ✅ Photo capture for exceptions

---

## Persona 3: Production Planner

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Production Planner |
| **Experience** | 3-5 năm |
| **Report to** | Operations Manager |
| **Focus** | Production scheduling, MRP |

### Daily Tasks
1. Review production schedules
2. Check material availability
3. Coordinate with production floor
4. Adjust plans for changes
5. Monitor WIP levels

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Adjust production schedule | Execute | Demand, Capacity |
| Release production order | Execute | Material availability |
| Expedite materials | Request | Shortage report |
| Reschedule order | Execute | Priority changes |

### Pain Points
- Manual MRP calculations
- Poor visibility into material availability
- Constant rescheduling
- No what-if analysis

### Must-have Features
- ✅ Automated MRP
- ✅ Real-time material visibility
- ✅ Drag-drop scheduling
- ✅ Scenario planning

---

## Persona 4: QC Inspector

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Quality Control Inspector |
| **Experience** | 2-5 năm |
| **Report to** | QC Manager |
| **Focus** | Quality inspection, Documentation |

### Daily Tasks
1. Inspect incoming materials
2. Perform in-process checks
3. Final product inspection
4. Document QC results
5. Handle non-conformances

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Pass/Fail inspection | Execute | QC criteria, Measurements |
| Hold material | Execute | Inspection result |
| Reject shipment | Recommend | Defect data |
| Release held material | Recommend | Resolution documentation |

### Pain Points
- Paper inspection forms
- Manual data entry
- No trend analysis
- Slow non-conformance handling

### Must-have Features
- ✅ Digital inspection forms
- ✅ Auto data capture
- ✅ QC trend dashboards
- ✅ NCR workflow

---

## Persona 5: Procurement Specialist

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Procurement / Purchasing Specialist |
| **Experience** | 2-5 năm |
| **Report to** | Procurement Manager |
| **Focus** | Purchasing, Vendor management |

### Daily Tasks
1. Process purchase requisitions
2. Create purchase orders
3. Follow up with vendors
4. Handle receiving issues
5. Update vendor performance

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Select vendor | Execute (approved list) | Price, Lead time, Terms |
| Create PO (≤limit) | Execute | PR approval, Budget |
| Expedite order | Execute | Delivery status |
| Approve invoice | Execute | PO match, Receipt |

### Pain Points
- Manual PO creation
- No vendor performance visibility
- Late deliveries
- Invoice matching errors

### Must-have Features
- ✅ Auto-PO from MRP
- ✅ Vendor portal
- ✅ Delivery tracking
- ✅ 3-way match automation

---

## Quick Reference: Operations Persona Access Matrix

| Data/Function | Inventory Clerk | Warehouse Manager | Production Planner | QC Inspector | Procurement |
|---------------|:---------------:|:-----------------:|:------------------:|:------------:|:-----------:|
| Inventory levels | ✅ View | ✅ Full | ✅ View | ⚠ Limited | ✅ View |
| Stock movements | ✅ Create | ✅ Full | ✅ View | ⚠ Limited | ✅ View |
| Adjustments | ⚠ Limited | ✅ Approve | ❌ | ❌ | ❌ |
| Production orders | ⚠ View | ✅ View | ✅ Full | ✅ View | ✅ View |
| Purchase orders | ❌ | ✅ View | ✅ View | ❌ | ✅ Full |
| QC records | ⚠ View | ✅ View | ✅ View | ✅ Full | ✅ View |
| Reports | ⚠ Own | ✅ Full | ✅ Department | ✅ Department | ✅ Department |

---

## Quick Reference: Warehouse Zones

| Zone | Purpose | Access |
|------|---------|--------|
| Receiving | Incoming goods, QC hold | Receiving staff, QC |
| Bulk Storage | High-volume items | All warehouse staff |
| Pick Zone | Fast-moving items | Pickers |
| Packing | Order consolidation | Packing staff |
| Shipping | Outbound staging | Shipping staff |
| Quarantine | QC hold, Damaged | QC, Manager only |
