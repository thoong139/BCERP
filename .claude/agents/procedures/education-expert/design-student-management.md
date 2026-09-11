# Playbook: Thiết kế Student Management System

> **Type**: Agent Procedure
> **Agent**: education-expert
> **Triggered by**: /wf-design khi cần thiết kế student management, enrollment, academic records
> **Output**: `.mc-data/docs/phase3-architecture/education/student-management.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design`
- Khi dự án cần thiết kế: Student Information System (SIS), Enrollment Management, Academic Records
- Phù hợp cho: K-12, University, Language Center có quản lý học viên chính thức

---

## Procedure

### Bước 1: Student Record Data Model

```
Student (core profile):
  - id, student_code (auto-generated), full_name, dob, gender
  - photo (consent required for minors)
  - contact: email, phone, address
  - parent_info: name, relationship, phone, email (BẮT BUỘC nếu age < 18)
  - enrollment_status: active / on_leave / graduated / withdrawn / dismissed

Academic Record:
  - student_id, program_id (or course list for non-degree)
  - courses_enrolled[], grades{}, attendance_summary{}
  - gpa_semester{}, gpa_cumulative, academic_standing
  - transcript_requests[]

Enrollment:
  - id, student_id, program_id, cohort, intake_date
  - expected_graduation_date, actual_graduation_date
  - status: enrolled / on_leave / graduated / withdrawn
  - scholarship_id (FK nếu có)

Financial:
  - student_id, tuition_schedule_id
  - payments[]: {date, amount, method, reference}
  - balance (outstanding)
  - scholarship_discount_applied

READ: .claude/references/team-expert/education/controls.md
→ Section 3: Data Privacy for Minors — parent_info bắt buộc cho age < 18
→ Section 6: Access Control Matrix — ai thấy data gì
```

### Bước 2: Enrollment & Admission Workflow

```
Phase 1 — Application:
  Online form:
    - Personal information + documents upload (photo ID, certificates)
    - For minors: parent/guardian information + parental consent form
  Application fee payment → receipt auto-generated
  Application status tracking (student/parent portal)

Phase 2 — Screening:
  Academic requirement check (auto: score/GPA threshold)
  Entrance test scheduling (if required): auto-notify applicant
  Interview scheduling (if required): calendar integration
  Screening result → Accept / Conditional Accept / Reject

Phase 3 — Offer & Acceptance:
  Acceptance letter auto-generated (PDF with seal)
  Student portal: accept offer + upload remaining documents
  Initial tuition payment → enrollment confirmed

Phase 4 — Registration:
  Student profile created in system
  Student ID card generated (with photo, barcode/QR)
  LMS account provisioned (SSO preferred)
  Email/portal credentials sent

Phase 5 — Orientation:
  Timetable sent automatically
  Welcome package (policies, resources, contacts)
  Checklist: required actions before first class
```

### Bước 3: Attendance Tracking

```
Tracking Methods (choose based on institution type):

Manual (default):
  Teacher marks: Present / Absent / Late / Excused per student per session
  Mobile-friendly interface for teacher (in-class marking)

QR Code:
  System generates unique QR per class session (rotates every 5 min)
  Student scans on mobile → auto-timestamp presence
  Late threshold: configurable (e.g., scan after 10 min = Late)

RFID/NFC:
  Physical card tap at classroom terminal
  Auto-log presence with timestamp

Live Session (online):
  Zoom/Google Meet: auto-pull attendance report via API after session ends
  Min attendance time threshold: configurable (e.g., must attend ≥ 50% of session)

Reporting:
  Daily attendance summary per class → sent to teacher
  Weekly report to Academic Admin
  Monthly attendance report → Parents (K-12 mandatory)
  Alert: student approaching threshold (3 absences from limit) → notify teacher + parent
  Alert: student < 70% → exam eligibility warning → notify student + parent + admin

READ: .claude/references/team-expert/education/controls.md
→ Section 4: Attendance Override Authority
→ Section 7: 70% threshold requirement (VN Higher Education)
```

### Bước 4: Academic Performance Tracking

```
Grade Input:
  Teacher enters scores per assessment item in gradebook
  Auto-save drafts → publish when ready
  Grade entry window: configurable (e.g., open during exam period + 2 weeks)

GPA Calculation:
  Per semester: weighted average of all enrolled courses
  Cumulative: rolling average across all semesters
  Formula: configurable per institution (credit-weighted vs simple average)
  Recalculate triggered on: new grade entered, grade appeal approved

Academic Standing:
  Auto-update on GPA recalculation:
    GPA ≥ 3.0 → Good Standing
    GPA 2.0-2.99 → Academic Warning (notify student + advisor)
    GPA < 2.0 → Academic Probation (notify student + parent + dept head)
  Standing history: maintain log of each semester's standing

Transcript Generation:
  Unofficial: student self-service, instant PDF, watermarked "UNOFFICIAL"
  Official: request → verification → admin reviews → seal/signature → PDF or physical
  Content: course list, credits, grades, GPA per semester, cumulative GPA, status

Graduation Check:
  System auto-checks: all required courses passed + GPA threshold met + fees cleared
  Graduation clearance → flag for academic admin review
  Certificate/degree: generated after admin confirms clearance
```

### Bước 5: Parent Portal & Communication

```
Parent Portal (K-12 bắt buộc, university optional):

View permissions (read-only for own child):
  - Grades: current semester scores, grade history
  - Attendance: daily record, monthly summary, alerts
  - Schedule: timetable, upcoming exams, school calendar
  - Financial: fee balance, payment history, upcoming due dates
  - Announcements: school-wide, class-specific

Messaging:
  - Direct message to teacher/admin (threaded)
  - Moderated: messages visible to both teacher and admin
  - No direct student-to-parent messaging through school system
  - Read receipt for important announcements

Notifications (push + email):
  - Grade posted for child's course
  - Attendance alert (absent or late)
  - Fee payment due (7 days, 3 days, 1 day before)
  - School announcements, exam schedules
  - Academic standing change

Payment:
  - Online tuition payment: card, bank transfer, e-wallet
  - Installment plan: auto-debit schedule
  - Receipt auto-generated and stored
  - Late payment: auto-reminder sequence

Consent Forms (digital):
  - Field trip consent
  - Photo/video usage consent (Nghị định 13/2023 compliance)
  - Data sharing with third parties
  - Medical information for health emergencies
  - Digital signature (OTP confirmation)

READ: .claude/references/team-expert/education/controls.md
→ Section 3: Data Privacy for Minors — parent access rights, consent requirements
```

---

## Checklist Design Review

```
□ Parent info field bắt buộc cho student < 18 (data model)
□ Attendance tracking method phù hợp với infrastructure (manual/QR/RFID)
□ 70% attendance threshold alert tự động (nếu higher education VN)
□ Grade input window có lock date sau publish
□ GPA calculation formula đã confirm với institution
□ Unofficial vs Official transcript: khác biệt về format và access
□ Parent portal: read-only, chỉ thấy data của con mình
□ Consent forms: digital signature flow hoàn chỉnh
□ Graduation check: auto-check all requirements trước khi flag for review
□ Financial hold: unpaid tuition → hold on grade release / transcript
```
