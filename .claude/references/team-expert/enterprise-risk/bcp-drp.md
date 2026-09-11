# Enterprise Risk Management - BCP & DRP

> **Domain**: Enterprise Risk Management / Quản trị Rủi ro Doanh nghiệp
> **Last Updated**: 2026-03-22
> **Nguồn**: ISO 22301:2019 (Business Continuity), NIST SP 800-34 (IT Contingency Planning)

---

## 1. Business Impact Analysis (BIA)

### Definition
BIA là nền tảng của BCP — xác định chức năng nào là quan trọng và tổ chức có thể chịu đựng downtime bao lâu.

### BIA Process

```
Step 1: Inventory critical business functions
   → Liệt kê mọi business processes
   → Classify: Critical / Important / Normal / Low priority

Step 2: Impact analysis per function (nếu bị gián đoạn)
   → Financial impact: revenue loss per hour/day
   → Operational impact: gì bị ảnh hưởng downstream
   → Reputational impact: khách hàng, đối tác bị ảnh hưởng thế nào
   → Regulatory impact: có vi phạm SLA/compliance không?

Step 3: Recovery Time Objectives (RTO/RPO)
   → Business owner xác định maximum tolerable downtime
   → IT translate sang technical RTO/RPO

Step 4: Dependencies mapping
   → Mỗi function cần gì: systems, people, facilities, vendors
   → Identify single points of failure
```

### Key Definitions

| Term | Definition | Ví dụ |
|------|-----------|-------|
| **RTO** (Recovery Time Objective) | Thời gian tối đa hệ thống có thể down trước khi gây tổn thất không chấp nhận được | Core banking: RTO = 4h |
| **RPO** (Recovery Point Objective) | Lượng data tối đa có thể mất (tính bằng thời gian) | Financial transactions: RPO = 0 (no data loss) |
| **MTD** (Maximum Tolerable Downtime) | Thời gian tối đa tổ chức có thể sống sót mà không có function này | E-commerce platform: MTD = 24h |
| **WRT** (Work Recovery Time) | Thời gian cần để recover work backlog sau khi system restored | = MTD - RTO |

### BIA Template per Critical Function

```
FUNCTION: [Tên function]
Department: [Phòng ban]
Function Owner: [Tên + chức danh]

IMPACT ANALYSIS (nếu gián đoạn):
Financial impact:
  - Per hour: [VND / USD]
  - Per day: [VND / USD]
  - Critical threshold (khi nào impact trở thành material): [giờ]

Operational dependencies:
  - IT systems required: [list]
  - Staff minimum required: [số lượng + roles]
  - Facilities required: [office / data center / alternative site]
  - External dependencies: [vendors, partners, utilities]

Recovery objectives:
  - RTO: [giờ]
  - RPO: [giờ / phút]
  - MTD: [giờ]

Priority tier: [Tier 1 Critical / Tier 2 Important / Tier 3 Normal]
```

### Priority Tiers

| Tier | Definition | Target RTO | Target RPO |
|------|-----------|------------|------------|
| **Tier 1 — Mission Critical** | Tổ chức không thể hoạt động nếu thiếu | < 4 giờ | < 1 giờ |
| **Tier 2 — Business Critical** | Ảnh hưởng nghiêm trọng nếu down >24h | < 24 giờ | < 4 giờ |
| **Tier 3 — Important** | Ảnh hưởng nhưng có workaround manual | < 72 giờ | < 24 giờ |
| **Tier 4 — Normal** | Low impact, manual workaround available | < 1 tuần | < 24 giờ |

---

## 2. BCP Structure

### Activation Criteria và Trigger Levels

```
LEVEL 1 — INCIDENT (Phòng ban xử lý)
├── Trigger: Gián đoạn cục bộ, ảnh hưởng < 1 team
├── Decision: Department Head
├── Actions: Local workarounds, notify Risk Manager
└── Threshold: Expected resolution < 2 giờ

LEVEL 2 — DISRUPTION (BCP Partial Activation)
├── Trigger: Gián đoạn ảnh hưởng 1-2 departments hoặc 1 critical function
├── Decision: COO + CRO
├── Actions: Activate relevant BCP procedures, assemble CMT
└── Threshold: Expected resolution 2-24 giờ

LEVEL 3 — CRISIS (Full BCP Activation)
├── Trigger: Gián đoạn ảnh hưởng multiple departments hoặc Tier 1 systems
├── Decision: CEO + CRO + Board notification
├── Actions: Full CMT activation, invoke alternate operating procedures
└── Threshold: Expected resolution > 24 giờ hoặc không xác định

LEVEL 4 — DISASTER (DRP + BCP Full)
├── Trigger: Physical facility unavailable, data center down, regional disaster
├── Decision: CEO + Board
├── Actions: Full crisis management, DRP activation, external communications
└── Threshold: Potential MTD breach for Tier 1 functions
```

### Crisis Management Team (CMT) Composition

| Role | Primary | Alternate | Responsibilities |
|------|---------|-----------|-----------------|
| CMT Chair | CEO | CRO | Overall decision authority, external communications |
| Operations Lead | COO | VP Operations | Coordinate recovery operations |
| Technology Lead | CTO | VP IT | Oversee DRP execution |
| Risk Lead | CRO | Risk Manager | Risk assessment, escalation decisions |
| Communications Lead | CMO / PR Director | HR Director | Internal + external communications |
| Finance Lead | CFO | Controller | Financial impact monitoring, insurance |
| Legal/Compliance Lead | General Counsel | CCO | Regulatory notifications, legal obligations |
| Business Unit Leads | BU Heads | Deputy BU Heads | Business continuity for their units |

### Communication Plan

**Internal communication:**
```
Immediate (within 1 hour):
  CMT Chair → All CMT members (SMS + phone call)
  CMT Chair → Board Chair (phone call)

Within 4 hours:
  CMT Chair → All employees (email + intranet announcement)
  Operations Lead → Key vendors/partners (phone)

Ongoing:
  CMT internal updates: Every 4 hours during crisis
  All-employee updates: Every 12 hours
```

**External communication:**
```
Customers:
  - Notification within [SLA-defined timeframe]
  - Status page update: real-time
  - Direct communication to affected customers: within 24h

Regulators:
  - Notify per regulatory requirements (ví dụ: NHNN yêu cầu 24h cho banks)
  - Legal counsel involved in all regulatory communications

Media:
  - Single spokesperson: CMO / CEO
  - No comment until approved message ready
  - PR agency on standby
```

### Alternate Operating Procedures
- Manual fallback cho mỗi critical process khi system down
- Paper forms, phone trees, offline spreadsheets
- Documented, trained, tested — không chỉ "nếu cần thì tính"

---

## 3. DRP (Disaster Recovery Plan)

### IT Systems Classification

| Tier | Definition | Recovery Strategy | RTO | RPO |
|------|-----------|------------------|-----|-----|
| **Gold** | Mission-critical: core business systems | Hot standby | < 1 giờ | Near-zero |
| **Silver** | Business-critical: important but not immediate | Warm standby | 4-8 giờ | < 1 giờ |
| **Bronze** | Important: significant impact if down | Cold standby | 24-48 giờ | < 24 giờ |
| **Iron** | Normal: minimal immediate impact | Restore from backup | 72h+ | < 24 giờ |

### Recovery Strategies

**Hot Standby (Gold tier):**
- Secondary environment fully operational và synced in real-time
- Failover automated hoặc < 5 phút manual
- Cost cao nhất — chỉ cho Tier 1 critical systems
- Ví dụ: Active-active data center, database replication, load balancing

**Warm Standby (Silver tier):**
- Secondary environment configured và có recent data backup
- Failover trong vài giờ — cần manual steps
- Cost moderate — phù hợp cho business-critical systems

**Cold Standby (Bronze tier):**
- Infrastructure available nhưng không configured
- Cần time để setup và restore data
- 24-48 giờ recovery time

**Backup & Restore (Iron tier):**
- Regular backups (daily/weekly)
- Restore từ backup khi cần
- Phù hợp cho non-critical systems

### Backup và Restoration Procedures

**Backup strategy (3-2-1 Rule):**
```
3 copies of data
2 different storage media types
1 copy offsite (hoặc cloud)
```

**Backup frequency by tier:**
| Data type | Frequency | Retention | Offsite copy |
|-----------|-----------|-----------|-------------|
| Transaction data | Real-time replication | 7 năm (financial) | ✅ Required |
| Database (Gold) | Continuous + daily snapshot | 90 ngày | ✅ Required |
| Database (Silver) | Daily | 30 ngày | ✅ Required |
| Files/Documents | Daily | 1 năm | ✅ Required |
| System configs | Weekly + trước mỗi change | 6 tháng | ✅ Required |

**Restoration procedure (mẫu):**
```
1. ASSESS: Xác định scope của disaster — systems affected, data loss extent
2. DECIDE: Recovery strategy (failover vs restore) + tier priority
3. EXECUTE:
   a. Failover: Activate standby environment → update DNS → verify → notify users
   b. Restore: Identify latest clean backup → restore → verify integrity → patch gap data
4. VERIFY: Chạy test transactions, verify data integrity
5. NOTIFY: Thông báo stakeholders hệ thống recovered
6. DOCUMENT: Log mọi actions với timestamp → post-incident review
```

---

## 4. Testing and Exercising

### Exercise Types

| Type | Mô tả | Effort | Frequency |
|------|-------|--------|-----------|
| **Tabletop** | Discussion-based scenario walk-through, không activate thực tế | Low | Quarterly |
| **Functional** | Activate BCP procedures nhưng không full-scale | Medium | Semi-annual |
| **Full-scale** | Actual failover/recovery, toàn bộ teams tham gia | High | Annual |
| **Backup restore test** | Thực sự restore từ backup lên môi trường test, verify integrity | Medium | Quarterly |

### Annual Testing Schedule (Mẫu)

```
Q1:
- Tabletop exercise: Cyber attack scenario
- Backup restore test (Bronze tier systems)

Q2:
- Functional test: Partial failover Silver tier systems
- CMT training và roster update

Q3:
- Tabletop exercise: Natural disaster / office unavailable scenario
- Backup restore test (Gold tier systems)

Q4:
- Full-scale exercise: Annual DRP drill
- BCP documentation review và update
- Lessons learned từ năm: incorporate vào plans
```

### Lessons Learned Integration
Sau mỗi exercise hoặc real incident:
1. Post-exercise debrief: what went well, what failed, gaps
2. Update BCP/DRP documentation với lessons learned
3. Assign action items với owners và deadlines
4. Track completion trong risk management system
5. Report kết quả lên Board Risk Committee

---

## 5. Vietnam-Specific Considerations

### Common Disaster Scenarios (Vietnam context)
- **Typhoons / Storms**: Vùng Duyên hải miền Trung (Tháng 9-12 hàng năm) — office damage, flooding
- **Flooding**: Miền Nam (đặc biệt TP.HCM), miền Trung — data center risk nếu ở tầng thấp
- **Power outages**: Thiếu điện cục bộ, đặc biệt mùa hè miền Bắc — UPS, generator requirements
- **Internet disruptions**: Cáp quang biển đứt (đã xảy ra nhiều lần) — redundant ISP requirement
- **Social unrest** (low probability, high impact): Ảnh hưởng operations nếu xảy ra

### Regulatory Requirements (Finance / Healthcare)

**Financial institutions (ngân hàng, fintech):**
- Thông tư 09/2020/TT-NHNN: Yêu cầu BCP cho hệ thống thanh toán
- Phải có DR site tại địa điểm vật lý khác (cách xa > 20km theo best practice NHNN)
- Notification cho NHNN trong 24h khi xảy ra incident ảnh hưởng hệ thống thanh toán

**Healthcare:**
- Nghị định 117/2020/NĐ-CP: Yêu cầu bảo mật thông tin bệnh nhân
- Backup medical records phải tuân thủ yêu cầu lưu trữ

**General IT:**
- Luật An ninh mạng 2018: Yêu cầu lưu dữ liệu người dùng Việt Nam tại Việt Nam (data localization)
- Ảnh hưởng đến thiết kế DR site: không thể dùng cloud nước ngoài cho dữ liệu này
