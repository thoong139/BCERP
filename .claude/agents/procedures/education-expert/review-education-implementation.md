# Playbook: Review Education Implementation

> **Type**: Agent Procedure
> **Agent**: education-expert
> **Triggered by**: /wf-implement-feature review pass cho education modules
> **Output**: Review report (inline hoặc `.mc-data/work/wf-implement-feature/review-education-[date].md`)

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-implement-feature` sau khi code education modules đã viết
- Khi cần review chất lượng implementation: student management, LMS, attendance, grading, parent portal
- Đặc biệt quan trọng: modules liên quan đến dữ liệu học sinh < 18 tuổi

---

## Review Checklist

### 1. Data Privacy & Child Protection

```
Nghị định 13/2023 — Dữ liệu học sinh < 18 tuổi:

□ Parental consent flow hoạt động đúng
  - Khi tạo student account < 18: yêu cầu parent consent form
  - Consent stored với timestamp và method (digital signature / OTP)
  - Enrollment không thể complete nếu chưa có consent

□ Dữ liệu trẻ em không accessible cho third-party services
  - Kiểm tra: API endpoints có trả về student data không khi gọi từ external?
  - Analytics SDKs (Google Analytics, etc.) không nhận student PII
  - Third-party integrations (Zoom, payment) không lưu student data dài hạn

□ Photo/video của học sinh không xuất hiện trong marketing features
  - Marketing components không pull từ student photo storage
  - Public-facing pages không hiển thị student photos

□ Parent access scope đúng: chỉ thấy data của con mình
  - API: GET /parent/children/{id}/grades → chỉ return nếu parent_id khớp
  - Không thể access student data của học sinh khác qua IDOR
  - Session token của parent không thể dùng để query student API directly
```

### 2. Academic Integrity

```
Grade authority chain:

□ Grade entry chỉ teacher mới được nhập (student role: read-only)
  - API: POST /grades → kiểm tra role = teacher hoặc instructor
  - Student role không có permission PATCH/POST /grades
  - Test: student token → grade endpoint → expect 403 Forbidden

□ Grade lock sau publish: chỉ Academic Director có thể unlock
  - Sau khi director approve: grade.status = "published", grade.locked = true
  - PUT /grades/{id} khi locked = true → reject (không phải director role)
  - Unlock flow: director request → audit log ghi nhận

□ Quiz anti-cheat: timer, attempt limit, question randomization
  - Timer: server-side countdown (không trust client time)
  - Attempt limit: enforced server-side (count attempts in DB trước khi allow)
  - Randomization: question order và answer order khác nhau mỗi attempt
  - Tab-switch: detection event → log với timestamp, warning count

□ Plagiarism detection integration active (nếu có assignment submission)
  - Submission hook triggers plagiarism check async
  - Cross-student comparison result stored (similarity %)
  - Instructor notified khi similarity > threshold (configurable, default 30%)
```

### 3. LMS Content & Progress

```
□ Lesson completion tracked correctly
  - Video: completion = watched >= threshold% (default 80%, configurable)
  - Document: completion = opened (configurable to require full scroll)
  - Quiz: completion = submitted (regardless of score)
  - Assignment: completion = submitted
  - SCORM: completion = scorm_status = "completed" (1.2) hoặc "completed" (2004)

□ SCORM completion/score communicated back correctly
  - LMSSetValue("cmi.core.lesson_status", ...) → stored in DB
  - LMSSetValue("cmi.core.score.raw", ...) → stored as grade
  - PostMessageAPI hoặc iframe communication verified

□ Course completion trigger = all required lessons completed + grade >= passing
  - Trigger fires on: grade saved, lesson marked complete
  - Check: all Lesson where is_required=true for this Enrollment are completed
  - AND: final grade (weighted avg) >= course.passing_grade
  - Race condition: use transaction / optimistic lock

□ Certificate generates automatically on trigger (correct data)
  - Verify: student full name (not username)
  - Verify: course title (not slug)
  - Verify: completion date (not enrollment date, not today if already completed)
  - Verify: QR code → verification endpoint returns correct data
  - Verify: certificate_id unique (UUID v4)
```

### 4. Attendance & Academic Records

```
□ Attendance threshold alert triggers correctly
  - Default threshold: 70% (configurable per course/institution)
  - Alert fires when: current_attendance% <= threshold + 2 sessions buffer
  - Alert recipients: student + parent (if K-12) + teacher + admin
  - Exam block: student cannot register for exam if attendance < 70%

□ GPA calculation correct per grading policy
  - Formula: sum(grade × credit_hours) / sum(credit_hours) per semester
  - Cumulative GPA: same formula across all completed semesters
  - Edge case: withdrawn courses (W grade) excluded from GPA calculation
  - Edge case: grade of 0 counted (not excluded)

□ Transcript shows correct data and is print-ready
  - Official transcript: institution logo, seal/signature placeholder
  - All semesters listed chronologically
  - Current academic standing visible
  - GPA per semester + cumulative GPA at bottom
  - PDF: A4, printable fonts, no dynamic JS rendering

□ Academic standing updates automatically when GPA changes
  - Trigger: on grade save / grade appeal approve
  - History: append to standing_history[], not overwrite
  - Notification sent on standing downgrade (Good → Warning, Warning → Probation)
```

### 5. Financial Controls

```
□ Tuition payment reconciles with enrollment status
  - Unpaid balance > threshold → enrollment status = "pending_payment"
  - Grade release hold: grades not visible if payment overdue (configurable)
  - Transcript request: blocked if balance > 0 (configurable)

□ Scholarship disbursement goes to school account, not student
  - Scholarship adjustment: applied as credit against student's fee balance
  - No direct bank transfer to student's personal account from scholarship
  - Disbursement record: amount, date, applied_to (fee period)

□ Refund policy enforced correctly by withdrawal date
  - withdrawal_date compared against course.start_date
  - Refund tiers: 100% / 50% / 0% by configurable date windows
  - Refund request: manual approval by finance admin
  - Refund: credit to original payment method or credit note

□ Receipt auto-generated after payment confirmed
  - Trigger: payment_status changes to "confirmed" (webhook from payment gateway)
  - Receipt: sequential receipt_number, amount, date, payment method, items paid
  - PDF: emailed to parent/student automatically
  - Stored: accessible in portal for 10 years (Luật Kế toán)
```

---

## Severity Classification

| Severity | Mô tả | Action |
|----------|-------|--------|
| CRITICAL | Data privacy breach, grade can be edited by student, financial fraud | Block release |
| HIGH | GPA calculation wrong, certificate missing data, attendance threshold not enforced | Fix before release |
| MEDIUM | Missing notification, report data mismatch | Fix in next sprint |
| LOW | UI inconsistency, minor UX | Log as tech debt |

---

## Output Format

```markdown
## Education Implementation Review — [Date] — [Module Name]

### Summary
- Total checks: N
- CRITICAL: N | HIGH: N | MEDIUM: N | LOW: N
- Recommendation: ✅ PASS / ⚠️ PASS WITH CONDITIONS / ❌ BLOCK

### Findings

#### CRITICAL
- [ ] [Finding description + file:line + fix recommendation]

#### HIGH
- [ ] [Finding description + fix recommendation]

#### MEDIUM / LOW
- [ ] [Brief description]

### Approved by
education-expert agent review — [timestamp]
```
