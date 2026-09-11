# Manufacturing User Personas

> Reference file cho manufacturing-expert agent
> Load file này khi cần hiểu về users trong domain Manufacturing

## Danh sách Personas

### 1. Production Manager

**Profile:**
- Chức danh: Production Manager / Trưởng phòng Sản xuất
- Kinh nghiệm: Senior level (7+ năm)
- Technical skill: High
- Tần suất sử dụng hệ thống: Daily (6-8 hours/day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Review production schedule | Daily AM | 30 min | Critical |
| Monitor production status | Ongoing | Continuous | Critical |
| Address production issues | As needed | Variable | Critical |
| Coordinate with departments | Multiple/day | 1-2 hours | High |
| Report to operations director | Daily | 30 min | High |

**Key Decisions:**
| Decision | Based On | System Support |
|----------|----------|----------------|
| Prioritize work orders | Due dates, capacity | Production schedule board |
| Resource allocation | Skills, availability | Resource planning |
| Accept rush orders | Capacity, impact | What-if analysis |

**Pain Points:**
1. **Limited visibility**: Real-time production status unclear
2. **Capacity planning**: Difficult to forecast resource needs
3. **Information silos**: Data scattered across systems
4. **Manual reporting**: Time-consuming report generation

---

### 2. Production Planner

**Profile:**
- Chức danh: Production Planner / Kế hoạch viên Sản xuất
- Kinh nghiệm: Mid level (3-7 năm)
- Technical skill: Medium to High
- Tần suất sử dụng hệ thống: Daily (full day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Run MRP | Daily/Weekly | 2-4 hours | Critical |
| Create production orders | Multiple/day | 1-2 hours | High |
| Balance workload | Daily | 1 hour | High |
| Coordinate material availability | Daily | 1-2 hours | Critical |
| Update schedule | As needed | Ongoing | High |

**Key Decisions:**
| Decision | Based On | System Support |
|----------|----------|----------------|
| Lot sizing | Setup costs, carrying costs | MRP parameters |
| Schedule changes | Priorities, constraints | Scheduling software |
| Safety stock levels | Demand variability | Inventory analysis |

**Pain Points:**
1. **Demand volatility**: Frequent schedule changes
2. **Material constraints**: Parts not available when needed
3. **Capacity bottlenecks**: Uneven workload distribution
4. **Manual planning**: Spreadsheets instead of integrated tools

---

### 3. Shop Floor Operator

**Profile:**
- Chức danh: Machine Operator / Worker
- Kinh nghiệm: Entry to Mid level
- Technical skill: Low to Medium
- Tần suất sử dụng hệ thống: Continuous during shift

**Daily Tasks:**
| Task | Frequency | Time Spent |
|------|-----------|------------|
| Clock in/out | 2x/day | 1 min |
| View work assignment | Multiple/day | 5 min |
| Log production | Per unit/batch | 1-2 min |
| Report issues | As needed | 5-10 min |
| Complete quality checks | Per operation | 2-5 min |

**Key Information Needed:**
- Current work order details
- Production specifications
- Quality standards
- Machine status
- Material locations

**Pain Points:**
1. **Paper-based instructions**: Hard to read, update
2. **Manual logging**: Time-consuming data entry
3. **No real-time feedback**: Don't know if on target
4. **Communication gaps**: Issues not quickly communicated

---

### 4. Quality Inspector

**Profile:**
- Chức danh: QC Inspector / Quality Technician
- Kinh nghiệm: Mid level
- Technical skill: Medium
- Tần suất sử dụng hệ thống: Daily (full day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Perform inspections | Per lot/batch | Variable | Critical |
| Record results | Per inspection | 2-5 min | Critical |
| Handle non-conformances | As needed | 15-30 min each | High |
| Generate quality reports | Daily | 30 min | High |
| Calibrate equipment | Per schedule | Variable | High |

**Key Decisions:**
| Decision | Based On | System Support |
|----------|----------|----------------|
| Accept/reject lot | Quality criteria | Inspection checklist |
| Hold for review | Borderline cases | Escalation workflow |
| Rework vs scrap | Cost analysis | Cost comparison |

**Pain Points:**
1. **Paper checklists**: Lost, incomplete records
2. **Manual data entry**: Duplicate entry in multiple systems
3. **No trend visibility**: Patterns not visible
4. **Slow non-conformance process**: Delays production

---

### 5. Maintenance Technician

**Profile:**
- Chức danh: Maintenance Tech / Mechanic
- Kinh nghiệm: Mid to Senior level
- Technical skill: High
- Tần suất sử dụng hệ thống: Daily

**Daily Tasks:**
| Task | Frequency | Time Spent |
|------|-----------|------------|
| Review work orders | Daily | 15 min |
| Perform preventive maintenance | Per schedule | Variable |
| Respond to breakdowns | As needed | Variable |
| Log maintenance activities | Per job | 5-10 min |
| Order spare parts | As needed | 15-30 min |

**Key Information Needed:**
- Equipment history
- Maintenance schedules
- Spare parts availability
- Technical documentation
- Safety procedures

**Pain Points:**
1. **Reactive maintenance**: Always fighting fires
2. **Parts availability**: Long lead times
3. **Equipment history**: Scattered records
4. **Communication**: Production doesn't report issues early

---

## Quick Reference

| Persona | Primary Focus | Key Metric |
|---------|---------------|------------|
| Production Manager | Output, efficiency | OEE, throughput |
| Planner | Schedule adherence | Plan vs actual |
| Operator | Execute work | Units produced |
| QC Inspector | Quality | Defect rate |
| Maintenance Tech | Uptime | MTBF, MTTR |
