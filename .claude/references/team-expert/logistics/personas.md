# Logistics Domain - User Personas

> **Domain**: Logistics / Xuất nhập khẩu
> **Last Updated**: 2026-03-07

---

## Persona 1: Logistics Coordinator

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Logistics Coordinator |
| **Experience** | 2-5 năm |
| **Report to** | Logistics Manager |
| **Focus** | Shipment coordination, Documentation |

### Daily Tasks
1. Create và track shipments
2. Coordinate with carriers
3. Process customs documents
4. Monitor shipment status
5. Handle exceptions

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Select carrier | Execute | Rates, Transit time |
| Book shipment | Execute | Approved carrier |
| Reschedule delivery | Execute | Customer approval |
| Void shipment | Request | Manager approval |

### Pain Points
- Multiple carrier systems
- Manual tracking in spreadsheets
- Late status updates
- Document delays

### Must-have Features
- ✅ Carrier integration
- ✅ Real-time tracking
- ✅ Document management
- ✅ Exception alerts

---

## Persona 2: Customs Specialist

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Customs Specialist / Customs Broker |
| **Experience** | 3-7 năm |
| **Report to** | Logistics Manager |
| **Focus** | Customs clearance, Compliance |

### Daily Tasks
1. Prepare customs declarations
2. Classify HS codes
3. Calculate duties và taxes
4. Submit declarations
5. Track clearance status

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| HS Code selection | Execute | Product specs |
| Declaration type | Execute | Shipment type |
| Duty calculation | Execute | HS Code, Value |
| Expedite clearance | Request | Reason, Cost |

### Pain Points
- Manual HS Code lookup
- Complex duty calculations
- VNACCS system integration
- Clearance delays

### Must-have Features
- ✅ HS Code database
- ✅ Auto duty calculator
- ✅ VNACCS integration
- ✅ Clearance tracking

---

## Persona 3: Warehouse Supervisor (Logistics)

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Warehouse Supervisor (Logistics focus) |
| **Experience** | 3-5 năm |
| **Report to** | Warehouse Manager |
| **Focus** | Cross-dock, Staging |

### Daily Tasks
1. Coordinate cross-docking
2. Manage staging areas
3. Track inbound/outbound timing
4. Coordinate with carriers
5. Handle storage exceptions

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Allocate staging | Execute | Shipment schedule |
| Prioritize shipments | Execute | Delivery urgency |
| Authorize overtime | Execute | Workload data |
| Escalate delays | Execute | Impact assessment |

### Pain Points
- No visibility into carrier ETAs
- Manual dock scheduling
- Space constraints
- Communication gaps

### Must-have Features
- ✅ Dock scheduling
- ✅ Space management
- ✅ Carrier portal
- ✅ Exception handling

---

## Persona 4: Fleet Manager

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Fleet Manager (if own fleet) |
| **Experience** | 5-10 năm |
| **Report to** | Logistics Director |
| **Focus** | Fleet operations, Driver management |

### Daily Tasks
1. Schedule drivers and routes
2. Monitor fleet utilization
3. Track fuel và maintenance
4. Handle driver issues
5. Optimize routes

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Assign driver | Execute | Availability, Route |
| Approve maintenance | Execute | Cost, Urgency |
| Route optimization | Execute | Delivery data |
| Driver disciplinary | Execute | Incident report |

### Pain Points
- Manual route planning
- No real-time vehicle tracking
- Driver communication gaps
- Maintenance tracking

### Must-have Features
- ✅ Route optimization
- ✅ GPS tracking
- ✅ Driver mobile app
- ✅ Maintenance scheduling

---

## Persona 5: Freight Forwarder (3PL)

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Freight Forwarder Agent |
| **Experience** | 5-10 năm |
| **Report to** | Logistics Manager |
| **Focus** | International freight, Carrier relationships |

### Daily Tasks
1. Book freight with carriers
2. Negotiate rates
3. Track shipments
4. Handle claims
5. Manage carrier relationships

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Select carrier route | Execute | Cost, Transit time |
| Negotiate rates | Execute | Volume history |
| File claims | Execute | Documentation |
| Change routing | Execute | Customer approval |

### Pain Points
- Multiple carrier communication
- Rate volatility
- Claim processing
- Tracking gaps

### Must-have Features
- ✅ Carrier rate management
- ✅ Claims management
- ✅ Multi-modal tracking
- ✅ Rate comparison

---

## Quick Reference: Logistics Persona Access Matrix

| Data/Function | Coordinator | Customs Specialist | Warehouse Supervisor | Fleet Manager | Freight Forwarder |
|---------------|:-----------:|:------------------:|:--------------------:|:-------------:|:-----------------:|
| Shipments (own) | ✅ Full | ⚠ View | ✅ Full | ✅ Full | ✅ Full |
| Shipments (all) | ⚠ Territory | ⚠ Customs only | ⚠ Own warehouse | ✅ Own fleet | ✅ Own routes |
| Customs docs | ✅ View | ✅ Full | ⚠ Limited | ❌ | ⚠ View |
| Carrier rates | ✅ View | ❌ | ⚠ Limited | ✅ Negotiate | ✅ Full |
| Tracking | ✅ View | ⚠ Status only | ✅ Full | ✅ Full | ✅ Full |
| Reports | ⚠ Own | ⚠ Customs | ⚠ Own | ⚠ Own | ✅ Own |

---

## Quick Reference: Transport Modes

| Mode | Best For | Key Considerations |
|------|----------|---------------------|
| Sea Freight | Large volumes, Long distance | Container type, Transit time |
| Air Freight | Urgent, High-value | Cost, Customs speed |
| Road | Regional, Door-to-door | Route conditions, Border crossing |
| Rail | Bulk, Landlocked | Infrastructure, Scheduling |
| Multimodal | Complex routes | Coordination, Handoff points |
