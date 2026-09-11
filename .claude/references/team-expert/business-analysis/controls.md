# Business Analysis - Controls & Access Management

> **Domain**: Business Analysis / Phân tích nghiệp vụ
> **Last Updated**: 2026-03-22
> **Nguồn**: IIBA BABOK v3, PMI Governance Framework, industry practice

---

## 1. Approval Matrix

### Requirements Sign-off by Priority Level

| Priority Level (MoSCoW) | BA Senior | Product Owner | Domain SME | Project Sponsor |
|-------------------------|:---------:|:-------------:|:----------:|:---------------:|
| Must Have | ⚠ Draft only | ✅ Approve | ✅ Domain validate | ⚠ Major scope only |
| Should Have | ⚠ Draft only | ✅ Approve | ⚠ If domain-specific | ❌ |
| Could Have | ⚠ Draft only | ✅ Approve | ❌ | ❌ |
| Won't Have (this release) | ⚠ Document | ✅ Confirm | ❌ | ❌ |

### Requirements Sign-off by Scope Impact

| Scope Impact | BA Senior | Product Owner | Project Manager | Steering Committee |
|--------------|:---------:|:-------------:|:---------------:|:-----------------:|
| Minor: 1–2 stories, không cross-system | ✅ | ✅ | ❌ | ❌ |
| Medium: 1 feature, single system | ⚠ Recommend | ✅ | ⚠ Inform | ❌ |
| Large: 1+ features, multi-system | ⚠ Recommend | ✅ | ✅ | ❌ |
| Major: new module hoặc phase change | ⚠ Recommend | ✅ | ✅ | ✅ |

### Change Request Approval Thresholds

| CR Impact | BA | Product Owner | Project Manager | Project Sponsor | Steering Committee |
|-----------|:--:|:-------------:|:---------------:|:---------------:|:-----------------:|
| Timeline delay ≤3 ngày | ❌ | ✅ | ✅ | ❌ | ❌ |
| Timeline delay 4–14 ngày | ❌ | ⚠ Recommend | ✅ | ⚠ Inform | ❌ |
| Timeline delay >14 ngày | ❌ | ⚠ Recommend | ⚠ Recommend | ✅ | ❌ |
| Scope tăng ≤5% effort | ❌ | ✅ | ✅ | ❌ | ❌ |
| Scope tăng 6–20% effort | ❌ | ⚠ Recommend | ✅ | ✅ | ❌ |
| Scope tăng >20% effort | ❌ | ⚠ Recommend | ⚠ Recommend | ⚠ Recommend | ✅ |
| Budget impact >10% project budget | ❌ | ❌ | ⚠ Recommend | ✅ | ✅ |

---

## 2. Access Control

### Requirements Document Access Matrix

| Resource | BA Senior | Product Owner | Project Manager | Domain SME | Developer | QA |
|----------|:---------:|:-------------:|:---------------:|:----------:|:---------:|:--:|
| Create requirement | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Edit draft requirement | ✅ | ✅ | ❌ | ⚠ Comment only | ❌ | ❌ |
| Edit approved requirement | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| View all requirements | ✅ | ✅ | ✅ | ⚠ Domain scope | ✅ Assigned | ✅ |
| Approve requirement | ❌ | ✅ | ❌ | ⚠ Domain scope | ❌ | ❌ |
| Archive / delete requirement | ❌ | ✅ | ⚠ PM approve | ❌ | ❌ | ❌ |
| View change history | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Export requirements | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |

### Backlog & Sprint Access Matrix

| Resource | BA Senior | Product Owner | Project Manager | Scrum Master | Developer |
|----------|:---------:|:-------------:|:---------------:|:------------:|:---------:|
| Create user story | ✅ | ✅ | ❌ | ❌ | ❌ |
| Edit story in backlog | ✅ | ✅ | ❌ | ❌ | ❌ |
| Set story priority | ❌ | ✅ | ❌ | ❌ | ❌ |
| Move story to sprint | ❌ | ✅ | ❌ | ⚠ Phối hợp PO | ❌ |
| Estimate story points | ❌ | ⚠ Final call | ❌ | ⚠ Facilitate | ✅ |
| Mark story done | ❌ | ✅ | ❌ | ❌ | ⚠ Done criteria |

### Ownership Rules

| Scenario | Rule | Override Authority |
|----------|------|--------------------|
| BA rời dự án giữa chừng | Requirements chuyển sang BA mới được chỉ định | BA Lead / PM |
| Conflicting domain ownership giữa 2 SME | SME thuộc business unit trực tiếp có priority | Department Head |
| PO unavailable >3 ngày liên tiếp | PM có thể tạm thời approve scope nhỏ | Project Sponsor |
| Requirement không rõ owner | PM assign dựa trên domain category | PM |
| Stakeholder sign-off bị từ chối mà không có lý do | Escalate đến Steering Committee | Project Sponsor |

---

## 3. Workflow Controls

### Requirement State Transitions (Vòng đời requirement)

```
[Draft] → [In Review] → [Approved] → [Baselined]
                ↓                          ↓
        [Revision Required]       [Change Requested]
                ↑                          ↓
           (BA fix)              [Approved (Updated)]
                                           ↓
                                    [Implemented]
                                           ↓
                                      [Verified]
```

| From State | To State | Entry Criteria | Validation |
|------------|----------|----------------|------------|
| Draft | In Review | BA hoàn thành writing, acceptance criteria có | Không còn placeholder text |
| In Review | Revision Required | Reviewer có comments cần giải quyết | Ít nhất 1 unresolved critical comment |
| Revision Required | In Review | BA address all comments | All comments marked resolved |
| In Review | Approved | PO + Domain SME confirm | Không có open critical comment |
| Approved | Baselined | PM lock version tại phase gate | Version number gán chính thức |
| Baselined | Change Requested | Change request formal form submitted | CR-ID gán chính thức |
| Change Requested | Approved (Updated) | CR approved theo approval matrix | Impact assessment documented |
| Approved | Implemented | Dev confirm code complete, tests pass | REQ-ID present trong code |
| Implemented | Verified | QA + business validation pass | UAT sign-off có chữ ký/timestamp |

### Hygiene Controls

| Control | Frequency | Enforcement |
|---------|-----------|-------------|
| Orphan requirement check (không có REQ-ID link) | Weekly | Automated scan, report to BA |
| Stale draft (>7 ngày không update) | Weekly | Notification đến BA owner |
| Requirements không có acceptance criteria | Before sprint planning | Blocked từ backlog grooming |
| Approved requirements không có test case | Before UAT start | QA gate: không vào UAT |
| REQ-ID referenced trong code nhưng không trong registry | Per commit | CI hook warning |
| Baselined requirement bị edit trực tiếp | Real-time | System block + alert PM |

### Baseline Lock Rules

| Trigger | Action | Responsible |
|---------|--------|-------------|
| Phase gate review hoàn thành | Lock tất cả Approved requirements vào baseline | PM |
| Sprint start | Lock sprint stories khỏi scope changes trong sprint | Scrum Master |
| UAT start | Lock requirements version — chỉ critical bugs được fix | PM + PO |
| Go-live | Archive baseline hiện tại, tạo production baseline | BA Lead |

---

## 4. Audit Trail Requirements

### Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Requirement created | Creator, timestamp, initial content, REQ-ID | Project lifetime + 2 năm |
| Requirement edited | Editor, timestamp, field changed, old value, new value | Project lifetime + 2 năm |
| Requirement status changed | Changer, timestamp, from state, to state, comment | Project lifetime + 2 năm |
| Requirement approved | Approver, timestamp, approval scope, version number | Project lifetime + 5 năm |
| Requirement baselined | PM, timestamp, version number, danh sách REQ-IDs | Project lifetime + 5 năm |
| Change request created | Requestor, timestamp, CR-ID, linked REQ-IDs, justification | Project lifetime + 3 năm |
| Change request approved/rejected | Approver, timestamp, decision, rationale | Project lifetime + 3 năm |
| Stakeholder sign-off | Stakeholder name, timestamp, requirement set version | Project lifetime + 5 năm |
| Requirement deleted/archived | Deleter, timestamp, reason, linked CR-ID nếu có | Project lifetime + 3 năm |

### Sensitive Data Access Log

| Data Accessed | Who Can Access | Purpose |
|---------------|----------------|---------|
| Full change history của requirement | BA Lead, PM, Auditor | Audit, dispute resolution |
| Stakeholder sign-off records | PM, PMO, Auditor | Compliance, legal reference |
| CR approval trail | PM, Steering Committee, Auditor | Governance reporting |
| Salary/compensation data trong HR requirements | HR BA, HR Manager only | Privacy restriction |
| Patient data trong healthcare requirements | Healthcare BA + Compliance Officer | Regulatory compliance |
| Financial thresholds và budget trong requirements | Finance BA, CFO, Auditor | Financial governance |

### Version Tracking Rules

| Artifact | Versioning Scheme | Who Triggers New Version |
|----------|-------------------|--------------------------|
| Individual requirement | Auto-increment (1.0, 1.1, 2.0) | Any edit sau khi approved |
| Requirements document (BRD) | Manual major.minor (1.0, 1.1, 2.0) | PM tại phase gates |
| Baseline snapshot | Date-stamped (YYYY-MM-DD) | PM khi lock baseline |
| Change request record | Sequential (CR-001, CR-002) | BA khi log CR |

---

## Quick Reference: Approval Checklist

### Trước khi Submit Requirement cho Review

- [ ] REQ-ID đã được gán từ registry chính thức
- [ ] Acceptance criteria viết dạng Given/When/Then hoặc tương đương
- [ ] Priority MoSCoW đã gán kèm rationale ngắn
- [ ] Domain SME đã được tag vào requirement
- [ ] Không còn TBD, TODO, placeholder trong body
- [ ] Linked business rule hoặc regulation nếu applicable

### Trước khi Approve Change Request

- [ ] CR-ID đã được gán chính thức
- [ ] Impact assessment bao gồm: timeline, cost, quality, dependencies
- [ ] Affected stakeholders đã được thông báo
- [ ] Approval level xác định dựa trên threshold matrix
- [ ] Baseline update plan đã có sau approval

### Trước khi Go-live

- [ ] Tất cả Must Have requirements: status = Verified
- [ ] Không có open critical change request chưa resolved
- [ ] UAT sign-off có đủ chữ ký stakeholder chủ chốt
- [ ] Production baseline đã được tạo và archived
- [ ] Audit trail export hoàn chỉnh cho compliance record
