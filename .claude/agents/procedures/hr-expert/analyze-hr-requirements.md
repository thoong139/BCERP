# Playbook: Phân tích HR Requirements

> **Type**: Agent Skill Playbook
> **Agent**: hr-expert
> **Triggered by**: /wf-analyze-requirements khi có HR/HRM modules
> **Output**: Requirements docs tại phase1-business/

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: HR, nhân sự, tuyển dụng, payroll, lương, chấm công, performance, đào tạo, onboarding
- Khi cần xác định HR requirements từ business idea hoặc legacy system

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại doanh nghiệp (Startup, SMB, Enterprise, Group/Holding)
□ Quy mô nhân sự (< 50 / 50-500 / > 500 người)
□ Cơ cấu tổ chức (đơn vị, phòng ban, chi nhánh?)
□ Địa bàn hoạt động (VN only / Multi-country?)
□ Đã có HRIS/HRM chưa? Đang dùng gì?
□ Loại hợp đồng lao động chủ yếu (toàn thời gian / bán thời gian / CTV?)
```

### Bước 2: Xác định HR modules cần có

Dựa trên quy mô và loại business, map ra modules cần build:

| Quy mô / Loại | Modules ưu tiên |
|---------------|-----------------|
| Startup < 50 người | Onboarding, Leave Management, Payroll đơn giản |
| SMB 50-500 người | Recruitment (ATS), Onboarding, Leave, Payroll đầy đủ, Performance |
| Enterprise > 500 | Tất cả + Training/LMS, Analytics, Multi-entity payroll |
| Nhiều chi nhánh/entity | Multi-entity payroll, Consolidated reporting |

Sau khi xác định modules → load knowledge files tương ứng:

```
Personas → READ: personas.md (luôn load)
Quy trình tuyển dụng → READ: operations.md (Process 1)
Quản lý nghỉ phép → READ: operations.md (Process 2)
Payroll → READ: operations.md (Process 4) + controls.md (Section 7)
Performance → READ: operations.md (Process 3)
Data access / PII → READ: controls.md (Section 1 + 2)
Approval workflows → READ: controls.md (Section 3)
```

### Bước 3: Xác định HR scope theo 6 sub-domains

Với mỗi sub-domain, confirm xem dự án có cần không:

```
□ RECRUITMENT   — ATS, job posting, interview, offer
□ ONBOARDING    — orientation, setup tasks, equipment, compliance
□ PAYROLL       — lương, BHXH/BHYT/BHTN, PIT, ngân hàng
□ PERFORMANCE   — OKRs/KPIs, review cycle, feedback
□ TRAINING      — khóa học, LMS, tracking completion
□ OFFBOARDING   — exit process, knowledge transfer, tài sản
```

### Bước 4: Map HR personas

```
READ: personas.md

Với mỗi persona xác định:
□ HR Admin      → daily ops, data entry, báo cáo
□ HR Manager    → approval, compliance, analytics
□ Recruiter     → tuyển dụng pipeline
□ Employee      → self-service (xin nghỉ, xem lương, cập nhật thông tin)
□ Manager       → approve team leave, performance review, headcount request

Với mỗi persona: ghi nhận pain points và must-have features
```

### Bước 5: Phân tích yêu cầu tuân thủ pháp luật lao động VN

```
READ: controls.md (Section 7 — Compliance Requirements)

Checklist bắt buộc cho dự án VN:
□ Giờ làm việc tối đa 48h/tuần + overtime tracking
□ Nghỉ phép năm tối thiểu 12 ngày (tăng theo thâm niên)
□ BHXH 8% + BHYT 1.5% + BHTN 1% (người lao động)
□ BHXH 17.5% + BHYT 3% + BHTN 1% (doanh nghiệp)
□ Thuế TNCN theo biểu lũy tiến 7 bậc (sau giảm trừ gia cảnh)
□ Thời gian thử việc: tối đa 60 ngày (công việc chuyên môn cao)
□ Báo cáo BHXH định kỳ (tháng/quý)
□ Lưu trữ hồ sơ nhân sự đủ thời hạn pháp định
```

### Bước 6: Phân tích độ phức tạp payroll

```
Xác định các yếu tố ảnh hưởng đến độ phức tạp tính lương:

PHỨC TẠP THẤP (lương tháng cố định):
- Lương cơ bản + phụ cấp cố định
- Chấm công đơn giản (đi/vắng)
- 1 loại hợp đồng

PHỨC TẠP TRUNG BÌNH (cần parameterize):
- Lương theo ngày công thực tế
- Overtime theo hệ số (1.5x ngày thường, 2x cuối tuần, 3x ngày lễ)
- Nhiều loại phụ cấp (xăng xe, điện thoại, trách nhiệm)
- Hoa hồng, thưởng KPI

PHỨC TẠP CAO (cần tư vấn finance-expert):
- Lương net → gross quy đổi
- Nhiều entity/công ty
- Expatriate: thuế khác, BHXH đặc thù
- Sales commission nhiều tier
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-HR-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần — impact gì]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format:**

```
REQ-HR-REC-001   → Recruitment / Tuyển dụng
REQ-HR-ONB-001   → Onboarding
REQ-HR-PAY-001   → Payroll / Lương
REQ-HR-PER-001   → Performance Management
REQ-HR-TRN-001   → Training / L&D
REQ-HR-OFF-001   → Offboarding
REQ-HR-LEA-001   → Leave Management / Nghỉ phép
REQ-HR-ANA-001   → HR Analytics
REQ-HR-ADM-001   → HRIS Admin / Core
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/hr-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về HR scope)
2. HR Modules cần build (list có đánh dấu in-scope / out-of-scope)
3. Personas affected (summary bảng)
4. Compliance requirements bắt buộc (labor law checklist)
5. Requirements (theo module, có REQ-ID)
6. Integration requirements với Finance, IT, Accounting
7. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-HR-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng
□ BHXH/BHYT/BHTN calculations đã covered
□ PIT withholding requirements đã noted
□ PII / data access requirements đã included (controls.md)
□ Approval workflows đã defined (ai approve gì)
□ Integration với Finance/Accounting đã noted
□ Open questions được list ra để stakeholders review
```
