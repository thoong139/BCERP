# Compliance - Operational Analysis Framework

> **Domain**: Compliance / Tuân thủ & Kiểm soát Nội bộ
> **Last Updated**: 2026-03-19

---

## 1. Core Processes

### Process 1: Regulatory Monitoring (Theo dõi Pháp lý)

```
Monitor       Assess        Classify      Update         Communicate
Sources    → Impact      → Priority   → Policies &  → Stakeholders
    │             │             │        Controls          │
    ▼             ▼             ▼             ▼             ▼
 Gov websites  Gap          Critical/    Policy draft   All-hands
 Newsletters   analysis     High/Med/    Procedure      Department
 Legal counsel Business     Low          update         heads
 Regulators    impact map   timeline     Training       Audit trail
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Monitor sources | Compliance Analyst | Tạo regulatory alert record | Alert có source, date, summary |
| Assess impact | Compliance Officer | Link regulation đến affected processes | Impact documented với rationale |
| Classify priority | Compliance Officer | Gán deadline (Critical ≤30 ngày, High ≤90 ngày, Medium ≤180 ngày) | Deadline gắn với effective date |
| Update policies/controls | Compliance Officer + Process Owner | Version mới policy, thông báo affected staff | Approved version ghi nhận |
| Communicate | Compliance Analyst | Gửi notification, update training content | Acknowledgment tracking bắt đầu |

### Process 2: Compliance Assessment (Đánh giá Tuân thủ)

```
Scope        Plan         Assess        Score        Report       Remediate
Definition → Assessment → Controls   → Compliance → Findings  → Gaps
    │             │          Maturity        │            │           │
    ▼             ▼             │             ▼            ▼           ▼
 Regulation   Checklist    → Document   % rate       Dashboard  Action plan
 Business     Evidence       Review     RAG status   Executive  Owner assign
 process map  request list   Interview  by domain    summary    Deadline set
```

| Step | Owner | Output | Frequency |
|------|-------|--------|-----------|
| Scope definition | Compliance Officer | Assessment scope document | Per regulation / Annual |
| Plan assessment | Compliance Officer | Checklist, evidence request list | 2 tuần trước execution |
| Assess controls | Internal Auditor / Compliance Analyst | Work papers, evidence files | Per assessment plan |
| Score compliance | Internal Auditor | Compliance score by area (% compliant) | Khi assessment hoàn thành |
| Report findings | Compliance Officer | Executive summary + detailed findings | 5 ngày sau assessment |
| Remediate gaps | Process Owner + Compliance | Action plan, progress tracking | Liên tục đến closed |

### Process 3: Audit Execution (Thực hiện Kiểm toán)

```
Plan      Fieldwork     Findings     Draft        Management     Final
Audit  → Conduct     → Document   → Report    → Response     → Report
  │          │             │            │             │             │
  ▼          ▼             ▼            ▼             ▼             ▼
Scope     Evidence     Rating:       Initial      Agree/        Issued
Risk-based collection  Critical/    circulate    Disagree/     Findings
Sampling  Interviews   High/Med/Low Review       Action plan   logged
Criteria  Walkthroughs               round       deadline set  Remediation
```

| Step | Owner | SLA | Output |
|------|-------|-----|--------|
| Plan audit | Head of Internal Audit | 3 tuần trước fieldwork | Audit plan, scope, criteria |
| Conduct fieldwork | Internal Auditor | Per scope estimate | Work papers, evidence package |
| Document findings | Internal Auditor | Trong fieldwork | Finding sheets với rating |
| Draft report | Internal Auditor | 5 ngày sau fieldwork | Draft audit report |
| Management response | Process Owner | 7 ngày sau draft | Agreed action plans |
| Final report | Head of Internal Audit | 3 ngày sau response | Final report distributed |

### Process 4: Incident Response (Xử lý Sự cố Tuân thủ)

```
Detect → Log → Triage → Investigate → Remediate → Close → Review
   │       │      │           │             │          │       │
   ▼       ▼      ▼           ▼             ▼          ▼       ▼
Any     Incident Minor/     Root cause   Action      Verify  Lessons
channel  ID      Major/     Evidence     Owner       resolved learned
Hotline  stamp   Critical   Timeline     Deadline    Sign-off Process
System           Notify     Impact       Regulatory  Audit    update
alert            chain      report       notify?     trail
```

| Step | Owner | SLA | Notification |
|------|-------|-----|--------------|
| Log incident | Compliance Analyst | Ngay khi nhận | Tạo incident record với ID |
| Triage | Compliance Officer | 2 giờ | Notify Legal nếu Critical |
| Investigate | Compliance Officer + Legal | 24-48 giờ (Critical), 5 ngày (Major) | Update stakeholders |
| Regulatory notification | Compliance Officer + Legal | Theo quy định (GDPR: 72 giờ) | Regulator + Board |
| Remediate | Process Owner | Theo action plan | Progress update weekly |
| Close | Compliance Officer | Sau verify remediation | Incident record closed, lessons logged |

### Process 5: Policy Management (Quản lý Chính sách)

```
Draft → Review → Approve → Publish → Train → Acknowledge → Review
  │        │        │          │        │          │           │
  ▼        ▼        ▼          ▼        ▼          ▼           ▼
Policy   Legal   Compliance  Version  Training  Staff        Annual
writer   SME     Officer     control  content   completion   or trigger
         review  Board if    Archive  update    tracking     event
                 material    Old      quiz
                             versions
```

| Step | Owner | SLA | Validation |
|------|-------|-----|------------|
| Draft | Policy Owner / Compliance | Per need | Mapped to regulation |
| Legal review | Legal / Compliance | 5 business days | No unresolved legal issues |
| Approve | Compliance Officer / Board | 3 business days sau review | Approval recorded với date |
| Publish | Compliance Analyst | Ngay sau approval | Versioned, old version archived |
| Train | HR + Compliance | 30 ngày từ publish | Training content updated |
| Acknowledge | All affected staff | 30 ngày từ publish | 100% target; escalate nếu <90% |

---

## 2. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Monitor compliance alerts và system exceptions | Compliance Analyst | 1-2 giờ | Alert volume cao, nhiều false positives |
| Xử lý incoming incidents / hotline reports | Compliance Analyst | 30-60 phút | Không có structured intake form |
| Theo dõi data subject requests (DSR) SLA | DPO / Compliance Analyst | 30 phút | Requests đến từ nhiều kênh, thiếu tập trung |
| Update open finding và incident status | Compliance Analyst | 30 phút | Thủ công, dễ quên cập nhật |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Regulatory update review (newsletter, circular) | Compliance Officer | 1-2 giờ | Quá nhiều nguồn, thiếu aggregation tool |
| Policy training completion tracking | Compliance Analyst | 1 giờ | Dữ liệu LMS phân tán, không auto-remind |
| Open finding và remediation progress review | Compliance Officer | 1-2 giờ | Process owners chậm cập nhật |
| Internal compliance status meeting | Compliance Officer | 1 giờ | Chuẩn bị báo cáo mất nhiều thời gian |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Compliance metrics report cho Ban lãnh đạo | Compliance Officer | 3-4 giờ | Thu thập dữ liệu từ nhiều nguồn thủ công |
| Vendor compliance check | Compliance Analyst | 2-3 giờ | Thiếu centralized vendor compliance record |
| KRI review và risk register update | Risk Manager | 2-3 giờ | Risk data không real-time |
| Policy expiry và renewal review | Compliance Analyst | 1-2 giờ | Không có automated expiry tracking |

### Quarterly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Control testing (sample-based) | Internal Auditor | 5-10 ngày | Scheduling với process owners khó |
| Policy review cycle | Compliance Officer | 2-3 giờ/policy | Không có structured review workflow |
| Regulatory change impact assessment | Compliance Officer + Legal | 3-5 giờ | Thiếu gap analysis framework |
| Compliance training program review | Compliance Officer + HR | 2-3 giờ | Training effectiveness data hạn chế |

---

## 3. Decision Support Requirements

### Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| Compliance Health | Compliance Officer, CEO, Audit Committee | Overall compliance %, open findings count, policy acknowledgment rate, incident trend |
| Audit Status | Head of Internal Audit, CFO | Audit plan completion %, open findings by severity, remediation on-time % |
| Risk Overview | Risk Manager, C-suite | Risk heat map, KRI breach count, residual risk distribution |
| Privacy & Data Protection | DPO, Legal | Open DSR count, DPIA status, consent rate, breach incidents |
| Training Completion | Compliance Analyst, HR | % completion by department, overdue by deadline, quiz pass rate |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Compliance Status Report | Monthly | Overview tuân thủ theo từng regulation area | CEO, CFO, Audit Committee |
| Audit Findings Report | Per audit | Chi tiết findings, ratings, action plans | Board, Management, External Auditors |
| Incident Summary | Monthly | Tổng kết incidents: loại, severity, status | Compliance Officer, Management |
| Regulatory Update Briefing | Bi-weekly | Thay đổi pháp lý mới và action required | Compliance Officer, Legal, Management |
| Policy Acknowledgment Report | Monthly | Ai đã và chưa ký nhận chính sách | Compliance Analyst, Department Heads |
| Risk Register Report | Quarterly | Top risks, KRI status, mitigation progress | CRO, Board Risk Committee |
| Annual Compliance Report | Annually | Toàn diện tình trạng tuân thủ trong năm | Board, External Auditors |

---

## 4. Integration Touchpoints

### GRC Tools (Governance, Risk & Compliance)

| System | Data Flow | Purpose |
|--------|-----------|---------|
| GRC Platform (e.g., MetricStream, ServiceNow GRC) | Controls ↔ Findings ↔ Risks | Central repository cho risk, audit, compliance data |
| Policy Management System | Policies → Acknowledgment tracking | Distribute policies, collect employee sign-off |
| Audit Management System | Audit plans → Work papers → Reports | Manage audit lifecycle end-to-end |

### HR Systems

| System | Data Flow | Purpose |
|--------|-----------|---------|
| HRIS (HR Information System) | Employee data → Training assignment | Assign compliance training by role, track completion |
| LMS (Learning Management System) | Training content → Completion records | Deliver và track compliance training |
| Onboarding System | New hire list → Compliance tasks | Trigger compliance onboarding checklist |

### IT & Security Systems

| System | Data Flow | Purpose |
|--------|-----------|---------|
| SIEM (Security Information and Event Management) | Security events → Compliance alerts | Detect potential compliance violations |
| IAM (Identity & Access Management) | User access data → Access review | Quarterly access certification, SoD enforcement |
| DLP (Data Loss Prevention) | Data movement alerts → Incident log | Detect unauthorized data transfers |

### Document Management

| System | Data Flow | Purpose |
|--------|-----------|---------|
| Document Management System (e.g., SharePoint) | Policies ↔ Version control | Policy storage, version history, access control |
| Contract Management | Contracts → Compliance obligations | Track regulatory clauses và obligations |
| Ticketing System (e.g., Jira, ServiceNow) | Findings → Remediation tasks | Assign và track remediation action items |

---

## 5. KPIs & Metrics

### Compliance Rate Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Overall Compliance Rate | (Compliant controls / Total controls assessed) × 100% | ≥95% |
| Policy Acknowledgment Rate | (Staff acknowledged / Total required) × 100% | 100% trong 30 ngày từ publish |
| Training Completion Rate | (Staff completed / Total assigned) × 100% | ≥98% per quarter |
| Regulatory Filing On-Time | (Filings on time / Total filings) × 100% | 100% |

### Audit & Findings Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Audit Plan Completion | (Audits completed / Audits planned) × 100% | ≥90% per year |
| Findings Closure Time — Critical | Ngày từ finding issued đến closed | ≤30 ngày |
| Findings Closure Time — High | Ngày từ finding issued đến closed | ≤60 ngày |
| Findings Closure Time — Medium | Ngày từ finding issued đến closed | ≤90 ngày |
| Remediation On-Time Rate | (Actions closed by deadline / Total actions) × 100% | ≥85% |
| Repeat Finding Rate | (Repeat findings / Total findings) × 100% | <10% |

### Incident Response Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Incident Response Time (Critical) | Giờ từ incident detect đến triage complete | ≤2 giờ |
| Regulatory Notification Compliance | % notifications submitted trong thời hạn pháp lý | 100% |
| Incident Resolution Time | Ngày từ log đến close | ≤30 ngày (Major), ≤7 ngày (Critical) |
| Incident Recurrence Rate | (Repeat incident types / Total incidents) × 100% | <15% per year |

### Risk Management Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Risk Register Coverage | (Identified risks / Assessed business processes) × 100% | 100% của key processes |
| KRI Threshold Breaches | Số KRIs vượt ngưỡng cảnh báo | 0 Critical, <3 High per quarter |
| Risk Acceptance Waivers | Số waivers outstanding >90 ngày | <5 open |
| Policy Review Cycle Compliance | (Policies reviewed on time / Total policies due) × 100% | 100% |
