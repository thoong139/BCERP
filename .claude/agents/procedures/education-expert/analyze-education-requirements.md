# Playbook: Phân tích Education Requirements

> **Type**: Agent Procedure
> **Agent**: education-expert
> **Triggered by**: /wf-analyze-requirements khi project có education/training modules
> **Output**: `.mc-data/docs/phase1-business/education-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: giáo dục, đào tạo, LMS, trường học, học viên, khóa học, e-learning, corporate training
- Khi cần xác định education requirements từ business idea hoặc legacy system

---

## Procedure

### Bước 1: Xác định segment và scope

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Xác định segment:
□ K-12         — Trường tiểu học, THCS, THPT → báo cáo Bộ GD&ĐT, dữ liệu học sinh nhạy cảm
□ Higher Edu   — Đại học, cao đẳng → academic credit system, research component
□ Vocational   — Trung cấp nghề, cao đẳng nghề → practical skills, apprenticeship
□ Language     — Trung tâm anh ngữ, ngoại ngữ → level testing, smaller class sizes
□ Corporate    — Training nội bộ → mandatory vs elective, compliance training
□ Online       — MOOC-style → nhiều instructors, global audience

Xác định quy mô:
□ # học viên / học sinh hiện tại và dự kiến
□ # khóa học / môn học cần quản lý
□ # giáo viên / instructor
□ # concurrent users (peak: enrollment period, exam day)
□ Delivery mode: offline / online / blended
```

### Bước 2: Map personas

```
READ: .claude/references/team-expert/education/personas.md

Theo segment, chọn personas ưu tiên:
□ K-12:      Student, Teacher, Parent (critical), Academic Admin
□ University: Student, Teacher, Academic Admin, Registrar
□ Corporate:  Employee-learner, L&D Manager, Instructor
□ Language:   Student, Teacher, Admin

Với mỗi persona: ghi nhận pain points hiện tại và must-have features
Chú ý: Parent là critical persona cho K-12 — riêng portal, riêng permissions
```

### Bước 3: Map academic process

```
READ: .claude/references/team-expert/education/operations.md

Xác định:
□ Academic calendar phù hợp với segment
□ Course lifecycle: từ design → certification
□ LMS content types cần support (video, SCORM, live session, quiz...)
□ Assessment types: auto-graded vs manual grading
□ Grading scale: 10-point / Letter grade / Pass-Fail
□ Current tools: Excel? Phần mềm gì? Quy trình thủ công nào?
□ Pain points hiện tại: manual steps, bottlenecks
```

### Bước 4: Xác định controls

```
READ: .claude/references/team-expert/education/controls.md

Grade authority:
□ Ai nhập điểm? (Teacher)
□ Ai review? (Department Head)
□ Ai approve/publish? (Academic Director)
□ Lock policy sau publish?

Academic integrity:
□ Online assessment cần anti-cheat không?
□ Plagiarism detection cần không?

Data privacy:
□ Có học sinh < 18 tuổi không? → mandatory: Nghị định 13/2023 controls
□ Parental consent flow cần thiết kế?
□ Third-party integrations nào cần data học sinh?

Attendance:
□ Có cần báo cáo Bộ GD&ĐT không? (trường chính thức)
□ Ngưỡng 70% bắt buộc không? (higher education)
```

### Bước 5: Cross-agent dependencies

```
HR: Teacher payroll, staff scheduling → tag hr-expert
Finance: Tuition fee, scholarship disbursement, financial reporting → tag finance-expert
Compliance: Bộ GD&ĐT reporting, child data privacy, licensing → tag compliance-expert
Customer: Student support portal, satisfaction tracking, helpdesk → tag customer-expert
```

### Bước 6: Phân loại và viết requirements

```
Phân loại mỗi requirement:
- REGULATORY  → bắt buộc theo Bộ GD&ĐT / pháp luật (không thể skip)
- OPERATIONAL → cần để vận hành bình thường
- NICE-TO-HAVE → cải thiện trải nghiệm, có thể defer

REQ-ID Format: REQ-EDU-[MODULE]-[NNN]
MODULE codes:
  STU   → Student Management (enrollment, records, attendance)
  LMS   → Learning Management (content, assessment, certification)
  ACAD  → Academic Operations (timetabling, curriculum, exam)
  TEACH → Teacher Management (schedule, workload, evaluation)
  COMP  → Compliance (Bộ GD&ĐT reporting, data privacy)

Output format mỗi requirement:
### REQ-EDU-[MODULE]-[NNN]: [Tên ngắn gọn]
**Mô tả**: [Diễn giải đầy đủ]
**Persona**: [Ai cần]
**Business Value**: [Impact nếu có / không có]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
**Regulatory**: [Có/Không — nếu có, cite nguồn]
```

### Bước 7: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/education-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng: segment, quy mô, delivery mode, scope chính)
2. Segment Profile (loại institution, compliance level)
3. Personas affected (bảng tóm tắt: persona → pain points → must-haves)
4. Modules in-scope vs out-of-scope
5. Compliance requirements bắt buộc (checklist: pháp luật giáo dục VN)
6. Requirements (theo module, có REQ-ID và priority)
7. Cross-agent dependencies (HR / Finance / Compliance / Customer)
8. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-EDU-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng
□ Học sinh < 18 tuổi: data privacy controls đã covered
□ Grade authority chain đã defined (Teacher → Dept Head → Director)
□ Attendance reporting requirements đã noted (nếu trường chính thức)
□ LMS content types đã confirmed với stakeholders
□ Cross-agent dependencies đã tag đúng (HR, Finance, Compliance)
□ Open questions được list ra để stakeholders review
```
