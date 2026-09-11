# Enterprise Risk Management - User Personas

> **Domain**: Enterprise Risk Management / Quản trị Rủi ro Doanh nghiệp
> **Last Updated**: 2026-03-22
> **Nguồn**: COSO ERM 2017, ISO 31000:2018, IRM (Institute of Risk Management) role definitions

---

## Persona 1: CRO (Chief Risk Officer)

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Chief Risk Officer / Group Head of Risk |
| **Experience** | 15-25 năm (quản lý rủi ro + lãnh đạo cấp C) |
| **Report to** | CEO hoặc trực tiếp Board of Directors / Board Risk Committee |
| **Focus** | Chiến lược ERM, risk appetite, Board-level risk reporting, risk culture |

### Daily Tasks
1. Review consolidated risk dashboard buổi sáng — xem KRI breaches và escalated risks
2. Quyết định escalation: rủi ro nào cần raise lên CEO/Board ngay trong tuần
3. Họp với Risk Manager để review emerging risks và thay đổi trong risk landscape
4. Chuẩn bị hoặc review nội dung cho Board Risk Committee meeting định kỳ
5. Trao đổi với business unit heads về risk appetite và risk treatment strategies

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Phê duyệt Risk Appetite Statement (RAS) trước khi trình Board | Approve | Enterprise risk profile, benchmarks |
| Phê duyệt risk treatment cho Critical risks (score ≥ 20) | Approve | Risk details, treatment options, cost |
| Quyết định activate BCP/crisis management | Approve | Trigger criteria, impact assessment |
| Phân bổ ngân sách risk management hàng năm | Recommend to Board | Risk program assessment, ROI |
| Xác nhận risk appetite thresholds cho từng risk category | Approve | Risk capacity analysis, business strategy |

### Pain Points
- Báo cáo rủi ro từ các phòng ban không đồng nhất — mỗi đơn vị dùng format khác nhau
- Thiếu consolidated view: không thể thấy tổng thể enterprise risk posture trong thời gian thực
- Risk reporting cho Board là manual, tốn nhiều giờ compile và format mỗi quý
- Không có hệ thống cảnh báo sớm khi KRI vượt ngưỡng amber — chỉ biết khi họp định kỳ

### Must-have Features
- Executive risk dashboard: top 10 risks, KRI status, heat map, portfolio view
- Automated board reporting: pull data từ risk register → generate quarterly report
- KRI alert system: real-time notification khi threshold bị breach
- Scenario analysis tool: model tác động của các risk scenarios lên business objectives

---

## Persona 2: Risk Manager / Enterprise Risk Analyst

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Enterprise Risk Manager / Senior Risk Analyst |
| **Experience** | 5-12 năm |
| **Report to** | CRO / CFO |
| **Focus** | Vận hành ERM framework, risk register management, KRI monitoring, RCSA facilitation |

### Daily Tasks
1. Cập nhật risk register khi có risk mới hoặc thay đổi trong existing risks
2. Monitor KRI dashboard và xử lý alerts — escalate nếu breach ngưỡng Red
3. Tổ chức và facilitate Risk and Control Self-Assessment (RCSA) workshops với các phòng ban
4. Chuẩn bị monthly risk report cho Management Risk Committee
5. Thu thập và phân tích operational loss event data

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Risk scoring (likelihood × impact) cho risks mới | Execute | Risk description, historical data, benchmarks |
| Xác định KRI threshold (Green/Amber/Red) | Recommend to CRO | Historical data, risk appetite, industry benchmarks |
| Đánh giá control effectiveness | Execute | Control testing results, incidents, RCSA data |
| Phân loại risk: inherent vs residual | Execute | Control inventory, testing evidence |

### Pain Points
- Risk register là spreadsheet — version control kém, merge conflicts khi nhiều người cùng edit
- Không có real-time data feed cho KRI — phải manually pull data từ nhiều hệ thống
- RCSA workshops tốn nhiều thời gian prep và consolidation — thiếu automation
- Khó track tiến độ action plans: owner không update, deadline trôi qua mà không có alert

### Must-have Features
- Risk register với version history, collaborative editing, change audit trail
- KRI monitoring với automated data feeds và threshold alerts
- RCSA workflow: facilitate → collect → consolidate → report trong cùng platform
- Action plan tracker với owner accountability và automated escalation

---

## Persona 3: Business Risk Owner (Department Head / Process Owner)

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Department Head / Senior Manager (kiêm Risk Owner trong phòng ban) |
| **Experience** | 8-20 năm (chuyên môn nghiệp vụ, không nhất thiết ERM) |
| **Report to** | C-suite (COO, CFO, CMO...) |
| **Focus** | Điều hành hoạt động + quản lý rủi ro trong phạm vi phòng ban |

### Daily Tasks
1. Điều hành hoạt động nghiệp vụ chính của phòng ban
2. Nhận alerts từ hệ thống ERM khi KRI của phòng ban vượt ngưỡng
3. Review và update status của action plans được assign trong risk register
4. Thực hiện self-assessment rủi ro cho phòng ban (RCSA) theo lịch định kỳ
5. Báo cáo operational incidents và near-miss lên Risk Manager

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Quyết định risk treatment trong phạm vi budget phòng ban | Approve | Risk details, treatment cost, residual risk |
| Escalate operational risk lên CRO/Risk Manager | Execute | Trigger criteria, urgency assessment |
| Accept residual risk dưới ngưỡng risk appetite | Approve | Risk details, justification, deadline |
| Phân bổ budget cho risk controls trong phòng ban | Approve | Control options, cost-benefit |

### Pain Points
- Risk management bị coi là overhead — thêm công việc ngoài nhiệm vụ chính
- Không có hướng dẫn rõ ràng về ngưỡng nào thì cần escalate vs tự xử lý
- Form RCSA phức tạp, mất nhiều thời gian điền và không có hướng dẫn
- Không biết mình đang chịu trách nhiệm cho những risks nào cụ thể

### Must-have Features
- Simple risk self-assessment form: guided questions, auto-scoring
- Clear escalation matrix: tình huống A → escalate; tình huống B → tự xử lý
- Accountability dashboard: danh sách risks và action plans tôi là owner
- Automated reminders cho upcoming RCSA và overdue actions

---

## Persona 4: Internal Auditor / Risk Assurance

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Senior Internal Auditor / Risk Assurance Manager |
| **Experience** | 4-10 năm |
| **Report to** | Chief Audit Executive / Audit Committee |
| **Focus** | Third line of defense — independent assurance về effectiveness của risk controls |

### Daily Tasks
1. Lên kế hoạch audit scope dựa trên risk register và risk ratings
2. Thực hiện control testing: inquiry, observation, inspection, re-performance
3. Thu thập và organize evidence cho các controls được kiểm tra
4. Ghi chép audit findings và phân loại severity (Critical / High / Medium / Low)
5. Theo dõi remediation của findings từ các audit trước

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Phân loại control: Effective / Partially Effective / Ineffective | Execute | Test results, sample, deviation analysis |
| Severity của finding (Critical → Low) | Execute | Impact assessment, regulatory implication |
| Xác định scope mở rộng khi phát hiện bất thường | Execute | Preliminary findings, risk threshold |
| Risk-based audit plan hàng năm | Recommend to CAE | Risk register, control universe, previous findings |

### Pain Points
- Phải access risk register và control library riêng biệt — thiếu integration
- Thu thập evidence thủ công từ nhiều hệ thống, mất 40-60% thời gian audit
- Finding remediation tracking là email-based — khó audit trail
- Risk-based audit planning thiếu data: không có real-time risk scores

### Must-have Features
- Integrated view: risk register + control library + audit findings trong cùng platform
- Evidence management: upload, organize, link đến control và finding
- Finding tracker với remediation workflow và audit trail
- Risk-based audit planning tool với risk score input

---

## Persona 5: Risk Champion (Business Unit Embedded)

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Risk Champion / Risk Focal Point (chức danh kiêm nhiệm) |
| **Experience** | 2-7 năm (chuyên môn nghiệp vụ) |
| **Report to** | Department Head (primary) + Risk Manager (dotted line) |
| **Focus** | First line risk awareness, incident identification, near-miss reporting, risk culture |

### Weekly Tasks
1. Review operational activities của tuần và identify potential risks hoặc near-misses
2. Log incidents và near-misses vào hệ thống risk management
3. Tham gia monthly Risk Champion network meeting do Risk Manager tổ chức
4. Trao đổi với đồng nghiệp để raise risk awareness trong phòng ban
5. Hỗ trợ Risk Manager trong RCSA data collection tại phòng ban

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Tự xử lý vs escalate risk/incident | Execute | Incident details, escalation criteria |
| Log near-miss vs không log (judgment call) | Execute | Incident description, potential impact |
| Risk classification ban đầu khi log | Execute | Incident template với guided categories |

### Pain Points
- Không có kênh báo cáo rõ ràng — không biết log ở đâu, nói với ai
- Thiếu training về risk management basics — định nghĩa risk, near-miss là gì
- Không thấy kết quả sau khi báo cáo: near-miss của mình được xử lý thế nào?
- Vai trò Risk Champion không được ghi nhận trong performance review

### Must-have Features
- Simple incident/near-miss reporting form: 5 fields, mobile-friendly
- Clear escalation guide: diagram "nếu A → gọi ai; nếu B → gọi ai"
- Feedback loop: sau khi log, thấy được status và kết quả xử lý
- Risk Champions community: shared learning, monthly briefing

---

## Quick Reference: Access Matrix

| Data / Function | CRO | Risk Manager | Business Risk Owner | Internal Auditor | Risk Champion |
|-----------------|:---:|:------------:|:-------------------:|:----------------:|:-------------:|
| Executive risk dashboard | ✅ | ✅ | ⚠ Phòng ban own | ✅ | ❌ |
| Risk register — view all | ✅ | ✅ | ⚠ Phòng ban own | ✅ | ❌ |
| Risk register — edit | ⚠ Approve only | ✅ | ⚠ Own risks only | ❌ | ❌ |
| Risk register — create new risk | ✅ | ✅ | ⚠ Own domain | ❌ | ⚠ Via workflow |
| KRI dashboard | ✅ | ✅ | ⚠ Own KRIs | ⚠ Read only | ❌ |
| Risk appetite — view | ✅ | ✅ | ✅ | ✅ | ⚠ Summary only |
| Risk appetite — edit | ✅ | ⚠ Recommend | ❌ | ❌ | ❌ |
| Control library — view | ✅ | ✅ | ⚠ Own controls | ✅ | ❌ |
| Control effectiveness — update | ❌ | ✅ | ⚠ Own controls | ⚠ Testing results | ❌ |
| RCSA — participate | ✅ | ✅ Facilitate | ✅ Self-assess | ⚠ Observe | ⚠ Support |
| Incident / near-miss — log | ✅ | ✅ | ✅ | ✅ | ✅ |
| Incident — review & close | ✅ | ✅ | ⚠ Own dept | ❌ | ❌ |
| BCP activation | ✅ | ⚠ Recommend | ❌ | ❌ | ❌ |
| Board risk report — generate | ✅ | ⚠ Prepare | ❌ | ❌ | ❌ |
| Action plan — view | ✅ | ✅ | ⚠ Own actions | ✅ | ⚠ Own actions |
| Action plan — update status | ❌ | ✅ | ✅ Own actions | ❌ | ✅ Own actions |

<!-- ✅ = Full access, ❌ = No access, ⚠ = Conditional (ghi chú điều kiện) -->
