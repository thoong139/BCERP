# Business Analysis - Operational Analysis Framework

> **Domain**: Business Analysis / Phân tích Nghiệp vụ
> **Last Updated**: 2026-03-19

---

## 1. Core Processes

### Process 1: Requirements Elicitation (Thu thập Yêu cầu)

```
Identify      Plan         Conduct       Document      Validate
Stakeholders → Sessions  → Elicitation → Requirements → & Confirm
     │             │            │              │              │
     ▼             ▼            ▼              ▼              ▼
  RACI map     Interview    Interviews     User stories   Stakeholder
  Power grid   guide prep   Workshops      Use cases      sign-off
  SME list     Agenda set   Surveys        BRD draft      Feedback loop
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Identify stakeholders | BA | Tạo stakeholder register | Đủ representative từ mỗi nhóm |
| Plan sessions | BA | Lên lịch meetings, chuẩn bị template | Calendar confirmed, attendees confirmed |
| Conduct elicitation | BA + SME | Ghi chú, record (nếu được phép) | Notes captured trong 24h |
| Document requirements | BA | Viết vào system, gán REQ-ID | Format đúng template |
| Validate | PO + SME | Review cycle, comment | Sign-off chính thức |

### Process 2: Requirements Analysis & Documentation

```
Raw Input → Classify → Analyze → Prioritize → Write Spec → Review → Baseline
    │            │         │          │             │          │          │
    ▼            ▼         ▼          ▼             ▼          ▼          ▼
 Interview    Functional  Gap       MoSCoW        User       BA+PO     Locked
 notes        Non-func    Analysis  Ranking       stories    walkthrough version
 Workshops    Constraint  BPMN      Kano model    Use cases  Feedback   REQ-ID set
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Classify inputs | BA | Tag functional/non-functional/constraint | Mọi item đều có category |
| Gap analysis | BA | So sánh current vs. desired state | Gap table có root cause |
| Prioritize | PO + BA | Apply MoSCoW hoặc Kano | Priority có rationale documented |
| Write spec | BA | Tạo document theo template | Acceptance criteria rõ ràng |
| Review | PO + SME | Comment round, revision | No open critical comments |
| Baseline | PM | Lock version trong system | Version số và ngày chốt ghi nhận |

### Process 3: Stakeholder Management

```
Identify → Analyze → Engage Plan → Communicate → Monitor → Adjust
    │           │          │             │             │         │
    ▼           ▼          ▼             ▼             ▼         ▼
 Register    Power/     Frequency    Status         Engagement  Plan
 RACI        Interest   Channel      updates        level       revision
 map         matrix     per group    Workshops      tracking    Action items
```

| Step | Owner | Output | Frequency |
|------|-------|--------|-----------|
| Identify | BA / PM | Stakeholder register | Project kickoff |
| Analyze | BA / PM | Power/Interest matrix | Kickoff + major changes |
| Engagement plan | PM | Communication plan | Per phase |
| Execute communication | PM + BA | Meeting minutes, status reports | Per plan |
| Monitor engagement | PM | Engagement health score | Weekly |

### Process 4: Change Request Management

```
Request → Log → Impact → Decision → Update → Communicate
    │        │     │          │          │           │
    ▼        ▼     ▼          ▼          ▼           ▼
 Any       CR-ID  Timeline   Approve/   Baseline    All
 stakeholder  Date  Cost      Defer/     updated    stakeholders
 formal form  Priority Quality Reject   Docs updated notified
```

| Step | Owner | System Actions | SLA |
|------|-------|----------------|-----|
| Log request | BA | Tạo CR record với ID | Ngay khi nhận |
| Impact analysis | BA + Tech Lead | Timeline, cost, quality impact | 2-3 business days |
| Decision | PO + PM + Sponsor | Approval/rejection ghi nhận | 5 business days |
| Update baseline | BA | Revise requirements, update registry | 1 business day sau approval |
| Communicate | PM | Notify all affected stakeholders | Ngay sau baseline updated |

---

## 2. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Trả lời câu hỏi từ dev/design team | BA | 1-2 giờ | Interruptions phá vỡ deep work |
| Update requirement status trong system | BA | 30 phút | Hệ thống chậm, duplicate entry |
| Review comments từ stakeholders | PO + BA | 30 phút | Volume lớn, thiếu prioritization |
| Check open blockers và escalate | PM | 30 phút | Thông tin scattered nhiều tool |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Sprint planning / backlog grooming | PO + BA | 2-3 giờ | Stories chưa đủ detail để estimate |
| Stakeholder status update meeting | PM | 1-2 giờ | Chuẩn bị slide mất nhiều thời gian |
| Requirements review session | BA + SME | 1-2 giờ | SME availability thấp |
| Traceability check (REQ → Feature → Test) | BA | 1 giờ | Manual, dễ bỏ sót |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Requirements baseline review | PO + PM + BA | 2-3 giờ | Scope creep khó phát hiện |
| Change request log review | PM | 1 giờ | CR impact chưa được đánh giá đồng nhất |
| Stakeholder satisfaction pulse check | PM | 1 giờ | Phản hồi không đại diện đủ nhóm |
| Lessons learned capture | BA + PM | 1-2 giờ | Bị bỏ qua khi project gấp |

### Quarterly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Portfolio-level requirements review | PMO + PO | 3-4 giờ | Thiếu cross-project dependency map |
| Process improvement review | BA Lead | 2 giờ | Không có benchmark để compare |
| Stakeholder RACI re-assessment | PM | 1-2 giờ | Org changes chưa được cập nhật |
| Template và standard update | BA Lead | 2-3 giờ | Adoption thấp sau khi update |

---

## 3. Decision Support Requirements

### Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| Requirements Health | BA Lead, PO, PM | % requirements approved, open comments, change requests pending |
| Project Status | PM, Sponsors | RAG status, milestone progress, budget burn, risk count |
| Backlog Health | PO, Scrum Master | Story points ungroomed, stories without acceptance criteria, priority breakdown |
| Stakeholder Engagement | PM | Last contact date per stakeholder, engagement score, open action items |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Requirements Status Report | Weekly | Tracking tiến độ review và approval | PM, Sponsors |
| Change Request Log | Weekly | Visibility vào scope changes và decisions | PO, PM, Steering |
| Traceability Matrix | Per milestone | Đảm bảo coverage từ REQ đến test | QA Lead, BA |
| Stakeholder Communication Log | Monthly | Audit trail communication | PM, PMO |
| Sprint Velocity Report | Per sprint | Tốc độ delivery actual vs. planned | PO, Scrum Master |
| Phase Gate Report | Per phase | Go/No-go decision support | Steering Committee |

---

## 4. Integration Touchpoints

### PM Tools

| System | Data Flow | Purpose |
|--------|-----------|---------|
| Jira / Azure DevOps | Requirements → Epics/Stories | Chuyển BRD thành backlog items |
| MS Project / Smartsheet | Milestones ↔ Timeline | Sync project plan với requirements milestones |
| Confluence / Notion | Requirements docs → Team wiki | Share specs với development team |

### Design Tools

| System | Data Flow | Purpose |
|--------|-----------|---------|
| Figma / Miro | Requirements → Wireframes | UX team nhận context từ user stories |
| BPMN tools (draw.io, Lucidchart) | Process maps → Requirements | Process diagrams dẫn đến functional specs |

### Dev Tools

| System | Data Flow | Purpose |
|--------|-----------|---------|
| GitHub / GitLab | REQ-ID → Code comments | Traceability từ requirement đến implementation |
| CI/CD Pipeline | Acceptance criteria → Test automation | Test cases từ specs dẫn đến automated tests |

### Testing Tools

| System | Data Flow | Purpose |
|--------|-----------|---------|
| TestRail / Zephyr | Requirements → Test cases | Map mỗi requirement với test case tương ứng |
| UAT Platform | Approved specs → UAT scripts | Business stakeholders validate theo spec |

---

## 5. KPIs & Metrics

### Requirements Quality Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Requirements Approval Rate | (Approved REQs / Total REQs) × 100% | ≥90% trong 2 tuần từ draft |
| First-Pass Approval Rate | (Approved without revision / Total) × 100% | ≥70% |
| Requirements Defect Rate | (Requirements changed post-baseline / Total) × 100% | <15% per phase |
| Requirements Coverage | (REQs linked to test cases / Total REQs) × 100% | 100% trước UAT |

### Stakeholder Satisfaction Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Stakeholder Satisfaction Score | Pulse survey 1-5 scale | ≥4.0 average |
| Meeting Effectiveness Score | Post-meeting survey | ≥3.5 average |
| Communication Timeliness | % updates delivered on schedule | ≥95% |

### Change Request Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| CR Turnaround Time | Ngày từ CR log đến decision | ≤5 business days |
| Scope Creep Rate | (CRs approved post-baseline / Total REQs) × 100% | <20% per phase |
| CR Acceptance Rate | (CRs approved / CRs submitted) × 100% | N/A — track for patterns |
| Impact per CR | Effort days added per approved CR | Track trend |
