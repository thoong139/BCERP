# Playbook: Thiết kế LMS / E-learning Platform

> **Type**: Agent Procedure
> **Agent**: education-expert
> **Triggered by**: /wf-design khi cần thiết kế LMS, e-learning, online course platform
> **Output**: `.mc-data/docs/phase3-architecture/education/lms.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design`
- Khi dự án cần thiết kế: LMS, e-learning platform, online course system, corporate training platform
- Khi segment là: Online Platform, Corporate L&D, Language Center with online component

---

## Procedure

### Bước 1: Course Structure Data Model

```
Xác định entities và relationships:

Course
  - id, title, slug, instructor_id, category_id, level (beginner/intermediate/advanced)
  - duration_hours, language, status (draft/published/archived)
  - thumbnail, description, prerequisites[], tags[]
  - passing_grade (configurable), max_attempts

Module (Section trong Course)
  - id, course_id, title, order, description, is_required

Lesson (Content item trong Module)
  - id, module_id, title, type (video/document/quiz/assignment/live/scorm)
  - content_url, duration_minutes, order, is_required
  - completion_criteria: watched_pct (video), score_pct (quiz), submitted (assignment)

Enrollment
  - id, student_id, course_id, enrolled_date, status (active/completed/dropped/expired)
  - progress_pct, started_date, completed_date, certificate_issued

Grade (per assessment item)
  - id, enrollment_id, lesson_id (quiz/assignment), score, max_score
  - submitted_at, graded_at, graded_by, feedback, attempt_number

Course Completion
  - Trigger: all required lessons completed + grade >= passing_grade
  - Auto-calculate from Enrollment + Grade records
```

### Bước 2: Content Delivery Engine

```
Video delivery:
  - Adaptive bitrate streaming (HLS) cho mobile/slow connection
  - Resume from last position (per student per lesson)
  - Playback speed control (0.75x, 1x, 1.25x, 1.5x, 2x)
  - Subtitle support (SRT/VTT upload, multiple languages)
  - Completion: video watched >= configurable % (default 80%)
  - Download control: configurable per course (allow/deny)

SCORM:
  - Launch in iframe with SCORM API bridge
  - Support SCORM 1.2 và 2004
  - Track: completion status, score, time spent
  - Pass completion/score back to gradebook

Live Session:
  - Zoom/Google Meet webhook → auto-create meeting link
  - Pre-session reminder (email/notification, 30 min trước)
  - Attendance: auto-pulled from Zoom/Meet report via API
  - Recording: auto-store link sau khi session kết thúc

Document:
  - PDF viewer in-browser (không force download)
  - Version control (instructor upload new version → notify enrolled students)
  - Completion: opened = completed (configurable)

Progress Tracking Logic:
  Lesson completion → recalculate Module progress → recalculate Course progress
  Course progress = (completed required lessons / total required lessons) × 100
```

### Bước 3: Assessment Engine

```
Quiz Builder:
  - Question types: Multiple choice (single/multiple answer), True/False, Fill-blank, Short answer
  - Question bank: pool of questions per topic → random selection per attempt
  - Settings: time limit, attempt limit, randomize questions, randomize answers
  - Auto-grading: MC, T/F, Fill-blank (exact/fuzzy match)
  - Manual grading: Short answer, Essay → instructor interface với rubric

Anti-cheat:
  - Timer countdown, auto-submit when time expires
  - Tab-switch detection → warning + log
  - Browser focus monitoring
  - Optional: webcam proctoring integration (for high-stakes exams)

Manual Grading Interface (assignments):
  - Rubric builder (criteria + levels + points)
  - Side-by-side: submission view + rubric scoring
  - Inline comments on submission
  - Grade override: instructor can adjust auto-grade with reason

Gradebook:
  - Weighted average per course grading policy
  - Override capability: instructor override final grade (with reason log)
  - Grade visibility: publish on specific date hoặc immediately after grading
  - Export: Excel/CSV cho offline analysis

READ: .claude/references/team-expert/education/controls.md
→ Grade entry authority, plagiarism detection, retake policy
```

### Bước 4: Certificate Generation

```
Trigger:
  - Course completion = 100% required lessons + final grade >= passing_grade
  - Manual override: instructor/admin can grant certificate exception

Certificate Template:
  - Customizable per institution (logo, color, layout)
  - Auto-populate: student name, course name, completion date, instructor name
  - QR code verification: encode unique certificate_id → verification URL

Digital delivery:
  - PDF download (watermarked with student name + cert ID)
  - Shareable link: public URL for verification
  - LinkedIn integration: "Add to Profile" button (optional)

Physical / Print:
  - Print-ready PDF (A4, 300dpi)
  - Batch print: admin prints all certificates for a cohort

Certificate Registry:
  - certificate_id (UUID), student_id, course_id, issued_date, issued_by
  - Verification endpoint: GET /verify/{certificate_id} → public JSON
```

### Bước 5: Analytics & Reporting

```
Student Dashboard (self-view):
  - Courses enrolled, in-progress, completed
  - Progress per course (% completion)
  - Recent activity, next lesson
  - Certificates earned

Instructor View (class-level):
  - Enrollment count, active learners, completion rate
  - Class average score per assessment
  - Struggling students alert (grade < threshold OR inactive > N days)
  - Assignment submission rate + grading queue

Admin View (institution-level):
  - Course enrollment trends (by time, by category)
  - Completion rates across courses
  - Revenue (if paid courses): enrollment × price
  - Instructor performance: avg student rating, completion rate by instructor

L&D Manager View (corporate):
  - Employee completion rate: mandatory vs elective
  - Compliance training status: % completed before deadline
  - Skill coverage: courses completed per department/role
  - Certificate expiry tracking: who needs renewal
```

---

## Checklist Design Review

```
□ Course/Module/Lesson data model covers all content types needed
□ SCORM 1.2 và 2004 both supported (if needed)
□ Video completion threshold configurable (default 80%)
□ Quiz anti-cheat: timer, tab-switch, question randomization
□ Certificate QR code links to verification endpoint
□ Grade authority: teacher enters → director approves → lock after publish
□ Analytics covers all 4 audience views (student, instructor, admin, L&D)
□ Mobile-responsive: student can access content on phone
□ Offline capability defined (if needed for mobile app)
```
