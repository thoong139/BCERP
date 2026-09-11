# Playbook: Thiết kế Recruitment Module

> **Type**: Agent Skill Playbook
> **Agent**: hr-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần thiết kế module tuyển dụng
> **Output**: Feature spec recruitment module tại phase2-features/

---

## Khi nào dùng playbook này

- Dự án có requirement về tuyển dụng / ATS (Applicant Tracking System)
- Cần thiết kế workflow từ job requisition đến onboarding
- Được invoke trong Phase 2 (Features) hoặc Phase 3 (Architecture)

---

## Procedure

### Bước 1: Đọc context và requirements

```
INPUT: Paths do skill cung cấp qua prompt
Đọc: REQ-HR-REC-* từ phase1-business/hr-requirements.md (nếu có)

Xác định scope tuyển dụng:
□ Internal only / External (career site) / Cả hai
□ Có integration với job boards (LinkedIn, VietnamWorks, TopCV...) không?
□ Số lượng vị trí tuyển trung bình/tháng
□ Quy trình phỏng vấn: bao nhiêu vòng, ai tham gia?
□ Cần candidate portal (ứng viên tự track) không?
```

### Bước 2: Thiết kế Job Requisition Workflow

```
READ: operations.md (Process 1 — Recruitment End-to-End)
READ: controls.md (Section 3 — Recruitment Approvals)

Job Requisition cần capture:
□ Thông tin vị trí: Job title, Department, Level, Job type
□ Số lượng cần tuyển và lý do (replacement / new headcount)
□ Budget range (salary band)
□ Kỹ năng bắt buộc vs. mong muốn
□ Ngày cần nhận việc (deadline)
□ Approver: Manager → HR Manager → Finance (nếu headcount mới)

Approval chain:
Hiring Manager tạo → HR Manager review → Finance confirm budget → Publish
```

### Bước 3: Thiết kế Job Posting

```
Job Posting features:
□ Internal posting (employee referral, notice board nội bộ)
□ External posting lên career page
□ Integration API với job boards nếu yêu cầu
□ Job description template library (tiết kiệm thời gian)
□ Visibility settings (public / private / internal only)
□ Expiry date tự động

Với mỗi posting:
- Sync từ Job Requisition (không nhập lại)
- Trạng thái: Draft → Active → Paused → Closed
- Analytics: số lượt xem, số ứng tuyển theo nguồn
```

### Bước 4: Thiết kế Application Tracking Pipeline (ATS)

```
Pipeline stages chuẩn (có thể customize theo dự án):

[Mới ứng tuyển] → [Sàng lọc CV] → [Phỏng vấn HR] → [Phỏng vấn chuyên môn] → [Phỏng vấn cuối] → [Offer] → [Đã nhận / Từ chối]

Với mỗi stage:
□ Ai có quyền move candidate sang stage tiếp theo
□ Required actions trước khi move (vd: điền feedback trước khi chuyển bước)
□ Automated notifications cho candidate và interviewer
□ Bulk actions (reject nhiều candidate cùng lúc)
□ Disqualification reasons (track lý do từ chối)

Candidate card phải có:
- Thông tin cá nhân + CV attachment
- Application source (self-apply / referral / headhunter)
- Tags và notes nội bộ
- Interview history
- Activity log (ai đã xem, ai đã liên hệ)
```

### Bước 5: Thiết kế Interview Scheduling

```
Interview scheduling features:
□ Tích hợp calendar (Google Calendar / Outlook)
□ Interviewer availability check
□ Slot proposal → Candidate chọn (tránh email qua lại)
□ Meeting link tự động (Zoom / Teams / Google Meet)
□ Reminder email/SMS trước phỏng vấn
□ Reschedule / Cancel workflow

Evaluation Scorecard:
□ Per-stage scorecard template (HR phone screen khác Technical)
□ Rating scale thống nhất (1-5 hoặc Strong No / No / Yes / Strong Yes)
□ Mandatory fields trước khi submit
□ Blind review option (ẩn tên candidate để giảm bias)
□ Aggregated score so sánh các ứng viên
```

### Bước 6: Thiết kế Offer Management

```
Offer workflow:
□ Generate offer letter từ template (có merge fields)
□ Salary negotiation history (ghi lại các mốc offer)
□ Digital signature (e-sign) hoặc export PDF
□ Approval: nếu offer > standard band → cần HR Director

Offer letter template cần:
- Vị trí, department, start date
- Gross salary + allowances
- Benefits package (BHXH, BHYT, ngày phép...)
- Probation terms
- Offer expiry date

Candidate response tracking:
□ Accepted → trigger Onboarding workflow
□ Declined → mark reason → remain in talent pool
□ No response → reminder sau X ngày → auto-expire
```

### Bước 7: Thiết kế Candidate Portal

```
Nếu yêu cầu có candidate-facing portal:
□ Track application status realtime
□ Upload thêm documents khi được yêu cầu
□ Chọn interview slot
□ Sign offer letter online
□ Privacy: chỉ thấy data của chính mình

Nếu không cần portal → dùng email notifications thay thế
```

### Bước 8: Viết Feature Specs

Format output mỗi feature:

```markdown
### FEAT-HR-REC-[NNN]: [Tên feature]

**REQ-ID**: REQ-HR-REC-[NNN]
**Module**: Recruitment
**Priority**: Must-have / Should-have / Nice-to-have

**Mô tả**: [Chi tiết feature]

**User Stories**:
- Là [persona], tôi muốn [action] để [benefit]

**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]

**Technical Notes**:
- [Database entities cần có]
- [API endpoints chính]
- [Integration points]

**Dependencies**: [FEAT khác cần có trước]
```

### Bước 9: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase2-features/hr/recruitment/[feature-name].md

Cấu trúc output:
1. Module Overview — mô tả ngắn recruitment module
2. Feature List (có mapping REQ-ID)
3. Core Workflow Diagram (text-based)
4. Feature Specs chi tiết
5. Data Model sơ bộ (entities: Job, Candidate, Application, Interview, Offer)
6. Integration Points
7. Open Items / Decisions Needed
```

---

## Checklist trước khi submit

```
□ Mỗi feature map được về REQ-HR-REC-* tương ứng
□ Approval workflow đã define đầy đủ (ai approve gì)
□ Candidate data privacy đã addressed (PII, không leak nội bộ)
□ Candidate source tracking có (để tính cost per hire)
□ Audit trail cho offer letter changes đã noted
□ Integration với Onboarding module được trigger khi offer accepted
□ Mobile-friendly requirements nếu có (recruiter cần mobile)
```
