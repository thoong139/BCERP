# Business Analysis - Frameworks

> **Domain**: Business Analysis / Requirements & Analysis Methods
> **Last Updated**: 2026-03-15
> **Nguồn**: IIBA BABOK v3, PMI-PBA Practice Guide, Agile BA practices

---

## 1. Kỹ Thuật Elicitation Requirements

| Kỹ Thuật | Mô Tả | Phù Hợp Khi | Hạn Chế |
|----------|-------|------------|---------|
| **Phỏng vấn (Interview)** | 1-on-1 hoặc nhóm nhỏ, hỏi có cấu trúc | Cần hiểu sâu nghiệp vụ; stakeholder cấp cao | Tốn thời gian; phụ thuộc vào sự cởi mở |
| **Workshop** | Buổi làm việc có cấu trúc, nhiều stakeholder | Cần đồng thuận; requirements phức tạp, nhiều phòng ban | Khó tổ chức; cần facilitator giỏi |
| **Observation (Job Shadowing)** | Quan sát người dùng thực tế làm việc | Hiểu quy trình thực tế; phát hiện pain points ẩn | Mất thời gian; người dùng có thể thay đổi hành vi |
| **Prototyping** | Dùng mockup/prototype để validate | Requirements mơ hồ; cần user feedback nhanh | Có thể bị hiểu nhầm là sản phẩm thật |
| **Survey/Questionnaire** | Câu hỏi gửi đến nhiều người | Khảo sát ý kiến diện rộng; định lượng preferences | Câu trả lời nông; không đào sâu được |
| **Document Analysis** | Phân tích tài liệu hiện có (quy trình, hệ thống cũ) | Hệ thống legacy; quy trình đã được ghi chép | Tài liệu có thể lỗi thời hoặc không đầy đủ |
| **Brainstorming** | Tạo ý tưởng tự do trong nhóm | Giai đoạn đầu; tìm giải pháp sáng tạo | Không có cấu trúc; ý kiến ít kinh nghiệm át ý kiến tốt |

---

## 2. BPMN Notation Quick Reference

### Các Ký Hiệu Cơ Bản

```
EVENTS (Sự kiện):
  ○  — Start Event (Bắt đầu)
  ◎  — Intermediate Event (Trung gian)
  ●  — End Event (Kết thúc)
  ⊗  — Error Event (Lỗi)
  ⊙  — Timer Event (Hẹn giờ)

ACTIVITIES (Hoạt động):
  ┌──────┐
  │ Task │  — Task (Tác vụ đơn lẻ)
  └──────┘
  ┌──────┐
  │ Sub- │  — Sub-process (Quy trình con có thể mở rộng)
  │Proc. │
  └──────┘

GATEWAYS (Cổng quyết định):
  ◇  — Exclusive Gateway (XOR): Chỉ 1 nhánh được đi
  ◈  — Parallel Gateway (AND): Tất cả nhánh đều đi cùng lúc
  ◇+ — Inclusive Gateway (OR): 1 hoặc nhiều nhánh tùy điều kiện

FLOWS (Luồng):
  →  — Sequence Flow (Luồng tuần tự)
  -->  — Message Flow (Luồng thông điệp giữa pools)
  - - → — Association (Liên kết annotation)

CONTAINERS:
  ┌─ Pool ─────────────────────────┐
  │  ┌─ Lane (Swimlane) ─────────┐ │
  │  │                           │ │
  │  └───────────────────────────┘ │
  └────────────────────────────────┘
```

### Ví Dụ Quy Trình Phê Duyệt

```
[Start] → [Submit Request] → ◇ Approved? → YES → [Execute] → [End]
                                         → NO  → [Notify Rejection] → [End]
```

---

## 3. Use Case Template Structure

```
USE CASE: UC-[ID] — [Tên Use Case]
─────────────────────────────────────────
Actor(s):       [Primary Actor] / [Secondary Actor]
Goal:           [Mục tiêu của actor]
Preconditions:  [Điều kiện phải đúng trước khi bắt đầu]
Postconditions: [Trạng thái hệ thống sau khi hoàn thành]
─────────────────────────────────────────
Main Flow (Happy Path):
  1. Actor thực hiện hành động X
  2. Hệ thống phản hồi Y
  3. Actor thực hiện Z
  4. Hệ thống lưu và xác nhận

Alternative Flows:
  A1. [Nếu điều kiện A]: Hệ thống thực hiện A1a → Trở về bước 2
  A2. [Nếu actor cancel]: Use case kết thúc

Exception Flows:
  E1. [Lỗi hệ thống]: Hiển thị thông báo lỗi, log và notify admin

─────────────────────────────────────────
Linked REQ-ID: REQ-[DEPT]-[NNN]
```

---

## 4. Requirements Prioritization Methods

### MoSCoW

| Mức Độ | Ý Nghĩa | Thường Chiếm |
|--------|---------|-------------|
| **Must Have** | Bắt buộc; không có thì sản phẩm không hoạt động | 60% |
| **Should Have** | Quan trọng nhưng có workaround tạm thời | 20% |
| **Could Have** | Tốt nếu có; ảnh hưởng nhỏ nếu không có | 15% |
| **Won't Have** | Không làm lần này; có thể làm tương lai | 5% |

### WSJF (Weighted Shortest Job First — Agile/SAFe)

```
WSJF Score = Cost of Delay / Job Duration

Cost of Delay = Business Value + Time Criticality + Risk Reduction

→ Feature có WSJF cao nhất → làm trước
```

### Kano Model

| Loại Feature | Đặc Điểm | Ví Dụ |
|-------------|----------|-------|
| **Basic (Must-be)** | Người dùng coi là hiển nhiên; thiếu → rất bất mãn | Login, lưu dữ liệu |
| **Performance** | Càng tốt → càng hài lòng | Tốc độ tải trang |
| **Excitement (Delight)** | Người dùng không biết cần nhưng rất thích khi có | AI suggestions |
| **Indifferent** | Không ảnh hưởng đến satisfaction | UI màu sắc minor |
| **Reverse** | Một số thích, một số không | Tính năng quá phức tạp |

### Value vs Complexity Matrix

```
         HIGH VALUE
              │
    Quick Win │ Strategic
    (Do Now)  │ (Plan Carefully)
──────────────┼──────────────────
    Low Prio  │ Avoid / Reconsider
    (Defer)   │ (High effort, low value)
              │
         LOW VALUE
    LOW COMPLEXITY     HIGH COMPLEXITY
```

---

## 5. Gap Analysis Framework

```
┌─────────────────────────────────────────────────────┐
│                  GAP ANALYSIS FLOW                  │
├─────────────────────────────────────────────────────┤
│                                                     │
│  [1. Current State]                                 │
│     Mô tả quy trình/hệ thống hiện tại              │
│     Pain points, limitations, workarounds           │
│                                                     │
│  [2. Future State]                                  │
│     Mục tiêu sau khi implement                     │
│     Success criteria, KPIs mong muốn               │
│                                                     │
│  [3. Gap Identification]                            │
│     Delta giữa Current và Future                   │
│     Chia theo: Process / Technology / People        │
│                                                     │
│  [4. Action Plan]                                   │
│     Từng Gap → Giải pháp cụ thể                    │
│     Owner, Timeline, Resources needed               │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Gap Analysis Table Template

| Gap ID | Lĩnh Vực | Current State | Future State | Gap | Giải Pháp | Priority | Owner |
|--------|----------|---------------|-------------|-----|-----------|----------|-------|
| GAP-001 | Process | Manual approval email | Workflow tự động | Không có approval system | Implement workflow engine | High | BA |
| GAP-002 | Technology | Excel tracking | Real-time dashboard | Không có reporting tool | Mua/xây BI tool | Medium | IT |
| GAP-003 | People | Không có training | Staff biết dùng hệ thống | Skill gap | Training program | Medium | HR |

---

## 6. RACI Matrix Template

| Hoạt Động | Project Manager | Business Analyst | Developer | Tester | Stakeholder |
|-----------|----------------|-----------------|-----------|--------|-------------|
| Elicit requirements | I | R | C | I | A |
| Write functional spec | C | R | C | I | A |
| Design technical architecture | I | C | R | I | I |
| Development | I | C | R | I | I |
| UAT Testing | I | C | C | R | A |
| Deployment | A | I | R | C | I |
| Post-launch review | R | C | C | C | A |

**Legend:** R = Responsible, A = Accountable, C = Consulted, I = Informed

---

## 7. Decision Matrix Template

| Tiêu Chí | Trọng Số | Phương Án A | Phương Án B | Phương Án C |
|----------|----------|-------------|-------------|-------------|
| Chi phí triển khai | 30% | 7 (2.1) | 9 (2.7) | 5 (1.5) |
| Thời gian to-market | 25% | 8 (2.0) | 6 (1.5) | 9 (2.25) |
| Rủi ro kỹ thuật | 20% | 6 (1.2) | 8 (1.6) | 7 (1.4) |
| Khả năng mở rộng | 15% | 9 (1.35) | 7 (1.05) | 6 (0.9) |
| Phù hợp nghiệp vụ | 10% | 8 (0.8) | 9 (0.9) | 7 (0.7) |
| **Tổng điểm** | 100% | **7.45** | **7.75** | **6.75** |

Ghi chú: Điểm thô (1–10) × Trọng số = Điểm có trọng số; tổng điểm cao nhất → Phương án được chọn.
