# Enterprise Risk Management - Operations & Operational Framework

> **Domain**: Enterprise Risk Management / Quản trị Rủi ro Doanh nghiệp
> **Last Updated**: 2026-03-22
> **Nguồn**: IRM Operational Risk Management Framework, COSO ERM 2017 Component 3

---

## 1. Risk Management Calendar

### Daily Activities
| Activity | Who | Time spent | Tool / Channel |
|----------|-----|------------|----------------|
| KRI dashboard review | Risk Manager | 15-30 min | Risk Management System |
| Alert triage: Green/Amber/Red status | Risk Manager | Variable | Dashboard + email alerts |
| Operational incident log review | Risk Manager | 15 min | Incident management module |
| Near-miss reports received | Risk Manager | Variable (triage) | Reporting form |

### Weekly Activities
| Activity | Who | Time spent | Channel |
|----------|-----|------------|---------|
| Risk status update | Risk Manager → CRO | 30 min | Weekly report |
| Escalation review: any new issues? | CRO | 30 min | Risk dashboard |
| Action plan progress check | Risk Manager | 1 hour | Action tracker |
| Risk Champion network check-in | Risk Manager | 30 min | Email / Slack |

### Monthly Activities
| Activity | Who | Time spent | Output |
|----------|-----|------------|--------|
| Risk register update (new, closed, changed) | Risk Manager | 3-4 hours | Updated risk register |
| Monthly KRI performance report | Risk Manager | 2 hours | Report |
| Control testing execution (per schedule) | Risk Manager + Control Owners | Variable | Testing workpapers |
| Management Risk Committee meeting | CRO + C-suite | 2 hours | Minutes + decisions |
| Operational loss event data compilation | Risk Manager | 1 hour | Loss data report |
| Action plan deadline tracking + follow-up | Risk Manager | 2 hours | Overdue action report |

### Quarterly Activities
| Activity | Who | Time spent | Output |
|----------|-----|------------|--------|
| Board Risk Committee preparation | CRO + Risk Manager | 3 days | Board report + presentation |
| RCSA update (trigger-based) | Risk Manager + BU Heads | 1-2 days | Updated RCSA |
| Risk appetite review (check still appropriate) | CRO | 2 hours | RAS confirmation or change proposal |
| BCP testing / tabletop exercise | Risk Manager + CMT | 4 hours | Exercise report |
| KRI threshold review: are thresholds still right? | Risk Manager | 2 hours | Threshold update |

### Annual Activities
| Activity | Who | Time spent | Output |
|----------|-----|------------|--------|
| Comprehensive RCSA (all business units) | Risk Manager + All BU Heads | 2-3 weeks | Full RCSA update |
| Risk appetite review và Board approval | CRO + Board | RAS version update | Board-approved RAS |
| ERM program effectiveness assessment | CRO + Internal Audit | 1 week | Program assessment report |
| Full BCP/DRP testing (full-scale exercise) | Risk Manager + CRO + IT | 1-2 days | DRP test report |
| Risk taxonomy review: categories still relevant? | Risk Manager | 1 day | Updated risk taxonomy |
| Risk Management training program | Risk Manager + HR | Ongoing | Training completion data |

---

## 2. Risk Register Management

### New Risk Identification and Registration Workflow

```
TRIGGER: Risk identified via:
  - RCSA workshop
  - Incident/near-miss analysis
  - KRI breach
  - External: industry news, regulatory change
  - Management escalation

STEP 1: Risk Champion hoặc BU Risk Owner → submit risk form
  Fields: Description, Category, Potential causes, Potential consequences

STEP 2: Risk Manager → triage và validate
  - Duplicate check: risk này đã có trong register chưa?
  - Category confirmation: đúng category không?
  - Scope: enterprise-wide hay BU-specific?

STEP 3: Initial scoring
  - Inherent risk: likelihood × impact (TRƯỚC controls)
  - Identify existing controls
  - Residual risk: likelihood × impact (SAU controls)
  - Velocity: Rapid / Moderate / Slow

STEP 4: Assign ownership
  - Risk Owner: phòng ban/cá nhân chịu trách nhiệm
  - Control Owner(s): ai vận hành controls

STEP 5: Approve và add vào register
  - Low/Medium: Risk Manager approve
  - High: CRO approve
  - Critical: Management Risk Committee approve

STEP 6: Action planning (nếu residual > risk appetite)
  - Owner tạo action plan
  - Risk Manager review và set deadline
  - Track trong action plan module
```

### Risk Change Management

**Khi nào cần update risk:**
- Material change trong likelihood hoặc impact (thay đổi ≥ 1 bậc trong 5×5 matrix)
- New controls được implement → reassess residual risk
- Control effectiveness changed (test result: từ Effective → Partially Effective)
- Contextual change: market, regulatory, technology, organizational

**Risk Closure Criteria:**
- Risk no longer relevant (business activity đã dừng, regulation đã thay đổi)
- Risk transferred hoàn toàn ra ngoài tổ chức
- Inherent risk score giảm xuống Low sau major mitigation
- Phải có: closure justification + CRO approval + audit trail

### Risk Aggregation và Concentration Analysis
- Monthly: Review risks cùng category — có concentration không?
- Correlation analysis: Risk A và Risk B cùng xảy ra không?
- Scenario modeling: Nếu risk group materialize cùng lúc, combined impact là bao nhiêu?
- Ví dụ: 3 vendor risks cùng supplier → concentration → treat as 1 aggregate risk

---

## 3. Incident Management

### Near-Miss Reporting (No-Blame Culture)
- **Definition**: Sự kiện/tình huống có thể gây tổn thất nhưng không xảy ra (either prevented or lucky)
- **Why report**: Mỗi near-miss là "free lesson" — học được mà không mất tiền
- **Culture yêu cầu**: Không phạt người báo cáo near-miss; ghi nhận và cảm ơn

**Near-Miss Report Form (5 fields):**
```
1. Mô tả sự việc: Chuyện gì xảy ra / suýt xảy ra?
2. Nguyên nhân: Tại sao xảy ra? (process failure, system issue, human error)
3. Ngăn chặn thế nào: Gì đã ngăn tổn thất (may mắn? control hoạt động?)
4. Nếu không ngăn được: Tác động ước tính là gì?
5. Đề xuất: Làm gì để ngăn lần sau?
```

### Incident Classification (Basel Operational Risk Categories)
| Category | Định nghĩa | Ví dụ |
|----------|-----------|-------|
| **Internal Fraud** | Gian lận bởi nhân viên | Biển thủ, expense fraud |
| **External Fraud** | Gian lận bởi bên ngoài | Phishing, hacker, vendor fraud |
| **Employment Practices** | Vi phạm labor law, discrimination | Wrongful termination, harassment |
| **Clients, Products, Business Practices** | Lỗi liên quan đến sản phẩm/khách hàng | Mis-selling, data breach |
| **Damage to Physical Assets** | Hỏng tài sản vật chất | Natural disaster, vandalism |
| **Business Disruption & System Failure** | Gián đoạn hệ thống | Server crash, power outage |
| **Execution, Delivery & Process Management** | Lỗi trong thực hiện giao dịch/quy trình | Settlement fail, wrong payment |

### Post-Incident Review / Root Cause Analysis
**5-Whys method:**
```
Incident: [Mô tả]
Why 1: Tại sao incident xảy ra?
Why 2: Tại sao cause #1 xảy ra?
Why 3: Tại sao cause #2 xảy ra?
Why 4: Tại sao cause #3 xảy ra?
Why 5: Root cause — đây là gốc rễ cần fix

Actions: Fix root cause, không chỉ symptom
```

**Timeframe:**
- Immediate review (Hot debrief): Within 24-48 hours of resolution
- Full RCA: Within 5-10 business days

---

## 4. KPIs for ERM Function

### Core ERM Program KPIs

| KPI | Formula | Target | Frequency |
|-----|---------|--------|-----------|
| Risk register coverage | % BUs có updated risk register (≤3 months) | 100% | Monthly |
| Risk ownership | % risks có Risk Owner assigned | 100% | Monthly |
| Action plan compliance | % risk actions on track or complete | ≥90% | Monthly |
| Overdue actions | % actions past deadline | <5% | Monthly |
| KRI breach response | % KRI Red breaches với action plan <5 days | 100% | Monthly |
| RCSA completion rate | % BUs completed RCSA on schedule | 100% | Quarterly |
| Control testing completion | % controls tested per annual plan | ≥95% | Quarterly |
| Board reporting timeliness | Board report submitted on time | 100% | Quarterly |
| Risk training completion | % employees completed annual risk training | ≥90% | Annual |
| Near-miss reporting rate | Number of near-misses reported per quarter | Trending up | Quarterly |

### Risk Culture KPIs (Leading indicators)
| KPI | Target | Interpretation |
|-----|--------|---------------|
| Near-miss reports per month | Increasing over time | More reports = better culture, not more problems |
| RCSA participation rate | >90% of Business Risk Owners actively participate | High = ownership culture |
| Risk Champion network active | >80% Risk Champions submitted ≥1 report last quarter | Engagement level |
| Risk escalation accuracy | % escalations that were appropriately escalated | Calibration quality |

---

## 5. Integration Points

### Finance Integration
- **Data needed from Finance**: P&L exposure per risk scenario, FX positions, liquidity ratios, financial loss data
- **Data provided to Finance**: Risk-adjusted financial planning inputs, risk quantification for capital allocation
- **Touchpoint**: Monthly: Risk Manager ↔ CFO/Controller — shared risk-financial view

### IT / Information Security Integration
- **Data needed from IT/Security**: System uptime data, vulnerability counts, MTTD/MTTR, incident logs
- **Data provided to IT**: Risk appetite for technology risks, KRI thresholds for cyber/IT
- **Touchpoint**: Weekly: Risk Manager ↔ CISO — shared cyber risk dashboard

### HR Integration
- **Data needed from HR**: Staff turnover rates, key person dependency analysis, training completion, engagement scores
- **Data provided to HR**: People risk profile, training requirements from ERM perspective
- **Touchpoint**: Monthly: Risk Manager ↔ HR Director — people risk indicators

### Operations Integration
- **Data needed from Operations**: Process failure rates, SLA breaches, supplier performance, operational incidents
- **Data provided to Operations**: Operational risk profile, process risk assessments, BCP requirements
- **Touchpoint**: Monthly: Risk Manager ↔ COO — operational risk review

### Compliance Integration
> **Phân biệt**: Compliance function (compliance-expert) focus vào regulatory requirements và legal obligations.
> Risk Management function (enterprise-risk-expert) focus vào risk governance và ERM framework.
> Hai functions phối hợp chặt chẽ — compliance risks là 1 trong 7 risk categories của ERM.
- Shared risk register: Compliance risks appear in enterprise risk register
- RCSA inputs: Compliance team contributes to self-assessment for compliance category
- Touchpoint: Monthly: CRO ↔ CCO — integrated risk-compliance view for Board reporting
