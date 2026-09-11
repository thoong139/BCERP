# Quality Excellence - User Personas

> **Domain**: Quality Excellence / Quản lý Chất lượng & Cải tiến Quy trình
> **Last Updated**: 2026-03-22
> **Nguồn**: ISO 9001:2015, ASQ Body of Knowledge, industry practice

---

## Persona 1: Quality Director / VP Quality

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| Role | Quality Director / VP of Quality / Chief Quality Officer |
| Experience | 15+ năm trong quality management |
| Report to | CEO / COO |
| Focus | Strategic quality leadership, certification, culture transformation |
| Team size | 5-30 người (tùy tổ chức) |

### Daily Tasks

- Review quality KPI dashboard (NCR open rate, CAPA closure, audit findings)
- Escalation handling: customer quality complaints, supplier quality failures
- Strategic decisions: quality budget, certification scope, major CAPA approval
- Management review preparation (quarterly/annual)
- Represent quality function với C-suite và khách hàng

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Quality policy approval | Full authority | Business objectives, customer requirements |
| Major CAPA approval (systemic issues) | Full authority | RCA, impact assessment, action plan |
| Certification scope & registrar selection | Full authority | Audit readiness, cost-benefit |
| Customer deviation/concession (tier 1) | Final approval | Product risk, customer agreement |
| Quality budget allocation | Recommend → CFO approve | CoQ analysis, ROI projection |

### Pain Points

- Silos giữa departments: production, engineering, procurement không "own" chất lượng
- Reactive quality culture: chỉ xử lý khi defect xảy ra, không phòng ngừa
- Manual reporting: KPI từ nhiều spreadsheet, không real-time, dễ sai
- CAPA không hiệu quả: action taken nhưng vấn đề tái phát
- Khó đo Cost of Quality: không có visibility vào failure costs ẩn

### Must-have Features

- Real-time quality KPI dashboard (NCR aging, CAPA status, sigma trends)
- Cross-functional visibility: ai own NCR nào, deadline, escalation status
- Management review report generation tự động
- CoQ tracking module (prevention + appraisal + failure costs)
- Trend analysis: quality metrics over time, predict deterioration

---

## Persona 2: Six Sigma Black Belt / Green Belt

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| Role | Six Sigma Black Belt (BB) / Green Belt (GB) |
| Experience | BB: 5-10 năm; GB: 2-5 năm |
| Report to | Quality Director hoặc Business Unit Director |
| Focus | DMAIC project execution, process improvement, statistical analysis |
| Certification | ASQ CSSBB/CSSGB hoặc equivalent |

### Daily Tasks

- DMAIC project execution: define, measure, analyze, improve, control phases
- Statistical analysis: hypothesis testing, regression, SPC chart monitoring
- Champion coaching: guide process owners through improvement methodology
- Data collection planning và validation (Gage R&R, MSA)
- Project reporting: status, financial benefits, timeline

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Project scope definition | Recommend → Champion approve | SIPOC, VOC, baseline data |
| Sample size for studies | Full authority (technical) | Confidence level, power analysis |
| Control strategy selection | Recommend → Process Owner approve | SPC capability, risk assessment |
| Root cause confirmation | Full authority (analytical) | Statistical evidence, hypothesis tests |

### Pain Points

- Thiếu data chất lượng: data không clean, không đủ history, manual collection sai
- Resistance to change: process owners không muốn thay đổi quy trình
- Không có digital tools: làm SPC bằng Excel, không real-time, không automated alerts
- Project tracking phân tán: mỗi BB tự theo dõi theo cách riêng
- Khó tính financial benefit: không có baseline cost tracking

### Must-have Features

- SPC charting tool: tự động plot X-bar & R, I-MR, p-chart với control limits
- DMAIC project workspace: charter, phase gates, deliverable tracking
- Data import/export: kết nối với ERP, MES, hoặc CSV upload
- Statistical calculator tích hợp: capability analysis, hypothesis testing
- Project portfolio view: tất cả DMAIC projects, status, financial impact

---

## Persona 3: QA/QC Analyst

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| Role | QA Analyst / QC Inspector / Quality Engineer |
| Experience | 2-7 năm |
| Report to | Quality Manager / Quality Director |
| Focus | Quality control execution, inspection, NCR logging, CAPA follow-up |
| Volume | Xử lý 5-30 NCR/tuần tùy ngành |

### Daily Tasks

- Inspection execution: incoming, in-process, final inspection theo checklist
- NCR (Nonconformance Report) creation và classification
- CAPA follow-up: track action items, verify closure, collect evidence
- Document control: update SOPs, work instructions, inspection forms
- Audit support: prepare evidence, accompany auditor, corrective action

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Accept/reject tại inspection (trong criteria) | Full authority | Inspection criteria, measurement results |
| NCR classification (minor/major/critical) | Full authority (minor) → Escalate (critical) | Defect severity matrix |
| NCR escalation threshold | Per procedure | NCR age, severity, impact |
| CAPA closure approval | Quality Manager approve | Effectiveness evidence |

### Pain Points

- Manual inspection logging: giấy tờ, khó tìm lại history, dễ mất
- Paper-based NCR: không track được aging, escalation trễ, evidence scattered
- Không có photo documentation tích hợp: gắn ảnh vào NCR phải copy thủ công
- Traceability kém: không biết NCR này liên quan CAPA nào, audit finding nào
- Nhập data 2 lần: inspection sheet → Excel → hệ thống

### Must-have Features

- Digital inspection forms: mobile-friendly, checklist-based, photo attachment
- NCR management: create, classify, assign, track aging, escalate automatically
- CAPA linkage: 1 NCR → 1 CAPA → evidence → closure
- Full traceability: NCR ↔ CAPA ↔ Audit Finding ↔ Product/Process
- Overdue alerts: tự động notify khi NCR/CAPA quá hạn

---

## Persona 4: Process Owner (Business Unit Manager)

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| Role | Production Manager / Operations Manager / Department Head |
| Experience | 8-15 năm |
| Report to | COO / VP Operations |
| Focus | Owns quality of their process; responsible for CAPA trong scope |
| Quality Role | CAPA Owner, process control, resource for improvement |

### Daily/Weekly Tasks

- Process KPI monitoring: throughput, defect rate, cycle time của process mình phụ trách
- CAPA ownership: approve action plans, assign resources, track progress
- Process change management: đảm bảo change có quality impact assessment
- Attend quality standup/review meetings: status update, escalation decisions
- Champion Six Sigma/Lean initiatives trong department

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Process changes trong scope | Full authority (với quality review) | FMEA update, impact assessment |
| CAPA action plan approval cho process mình | Full authority | RCA, feasibility, resource |
| Resource allocation cho improvement projects | Within budget authority | Project charter, ROI |
| Escalate CAPA ngoài scope | Trigger escalation | Issue description, impact |

### Pain Points

- "Quality là việc của phòng QA" — không cảm thấy mình own chất lượng
- Không có real-time process data: biết vấn đề trễ, sau khi defect đã lan rộng
- CAPA là "additional work" chồng lên công việc chính, thiếu tool hỗ trợ
- Không biết CAPA status của mình đang ở đâu mà không hỏi QA
- Data request từ QA team: mất nhiều thời gian để pull và format

### Must-have Features

- Process dashboard đơn giản: 3-5 KPI quan trọng nhất cho process của mình
- My CAPA list: tất cả CAPA mình đang own, deadline, status, next action
- Easy action update: mobile-friendly cập nhật CAPA progress, upload evidence
- Alert khi process metric vượt threshold
- One-click process change request với quality impact checklist

---

## Persona 5: Internal Quality Auditor

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| Role | Internal Quality Auditor (thường là part-time, kiêm nhiệm) |
| Experience | 3-10 năm trong domain; certified ISO 9001 Lead Auditor |
| Report to | Quality Director |
| Focus | QMS audit execution, findings management, CAR follow-up |
| Frequency | Audit 1-2 lần/năm mỗi area; hoặc theo audit program |

### Monthly/Quarterly Tasks

- Audit program planning: lịch audit, scope, auditor assignment (risk-based)
- Audit execution: opening meeting, evidence collection, interview, closing meeting
- Audit report: findings classification (observation/minor NC/major NC)
- CAR (Corrective Action Request) management: issue, track, verify closure
- Management review support: consolidate audit findings cho review input

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Finding severity classification | Full authority | ISO 9001 clause, evidence |
| Audit scope adjustment | Recommend → Quality Director approve | Risk assessment |
| CAR closure approval | Full authority (per procedure) | Effectiveness evidence |
| Escalate major NC | Mandatory → Quality Director 24h | Finding details, impact |

### Pain Points

- Manual audit scheduling: lịch trong email/spreadsheet, dễ miss, không track
- Evidence collection burden: in tài liệu, chụp ảnh, copy file — mất nhiều thời gian
- Report writing thủ công: mỗi audit viết report từ đầu, không template chuẩn
- CAR tracking phân tán: theo dõi qua email, không biết status real-time
- Tái phát finding: same finding từ audit năm ngoái vẫn open, không có systemic fix

### Must-have Features

- Audit program management: lịch, scope, auditor assignment, risk-based planning
- Digital audit checklist: theo ISO 9001 clauses, customizable, mobile-friendly
- Evidence attachment: photo, document link, screen capture trong audit session
- Finding template với severity classification guide
- CAR management: issue → track → verify → close với full audit trail

---

## Access Matrix

| Feature | Quality Director | Black Belt | QA Analyst | Process Owner | Auditor |
|---------|:----------------:|:----------:|:----------:|:-------------:|:-------:|
| Quality KPI Dashboard (all) | ✅ | ✅ | Read only | Own process | ✅ |
| NCR Create/Edit | ✅ | ✅ | ✅ | Own process | ✅ |
| CAPA Approve | ✅ | Advisory | Initiate | Own scope | ✅ |
| FMEA View/Edit | ✅ | ✅ | View | Own process | View |
| Audit Program Manage | ✅ | No | No | No | ✅ |
| Document Approve | ✅ | No | Draft only | Scope only | No |
| SPC Charts | ✅ | ✅ | View | Own process | View |
| Quality Objectives Edit | ✅ | Advisory | No | No | No |
| Management Review | ✅ | Input | Input | Input | Input |
| CoQ Report | ✅ | ✅ | No | No | No |
