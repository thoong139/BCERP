# Business Analysis - User Personas

> **Domain**: Business Analysis / Phân tích nghiệp vụ
> **Last Updated**: 2026-03-22
> **Nguồn**: IIBA BABOK v3, PMI-PBA Practice Guide, industry practice

---

## Persona 1: Business Analyst (Senior)

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Senior Business Analyst / Chuyên viên phân tích nghiệp vụ |
| **Experience** | 5–10 năm |
| **Report to** | BA Lead / Project Manager |
| **Focus** | Requirements elicitation, process analysis, spec writing |

### Daily Tasks

1. Thu thập yêu cầu từ stakeholders qua interviews và workshops
2. Phân tích và mô hình hóa quy trình nghiệp vụ (BPMN, flowchart)
3. Viết functional requirements và user stories với acceptance criteria
4. Làm rõ ambiguities giữa business và technical team
5. Review và validate requirements với product owner và domain experts

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Phân loại priority cho requirement (MoSCoW) | Recommend | Business impact, effort estimate |
| Xác định scope inclusion/exclusion | Recommend | Stakeholder input, project constraints |
| Chốt requirement wording cuối cùng | Execute | Stakeholder sign-off |
| Escalate conflicting requirements | Request | Conflict documentation, impact analysis |
| Gán REQ-ID mới vào registry | Execute | Approval từ PO hoặc PM |

### Pain Points

- Requirements thay đổi liên tục sau khi đã sign-off, gây rework lớn
- Stakeholders mô tả solution thay vì vấn đề thực tế — gap giữa "muốn" và "cần"
- Thiếu traceability từ requirement đến test case và code, khó audit
- Không có single source of truth — requirements rải rác email, chat, Excel

### Must-have Features

- ✅ Requirement versioning và change history tracking
- ✅ Traceability matrix: REQ → Feature → Test case → Code
- ✅ Template library cho user stories và functional specs
- ✅ Workflow sign-off có timestamped approval records

---

## Persona 2: Product Owner

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Product Owner / Chủ sản phẩm |
| **Experience** | 3–8 năm |
| **Report to** | Head of Product / CPO |
| **Focus** | Backlog management, feature prioritization, stakeholder communication |

### Daily Tasks

1. Prioritize và groom product backlog theo business value
2. Viết và review user stories với acceptance criteria rõ ràng
3. Làm việc với development team để clarify requirements trong sprint
4. Tham gia sprint reviews và collect feedback từ stakeholders
5. Communicate product roadmap và release plan với các bên liên quan

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Priority thứ tự features trong backlog | Approve | Business value, user demand, effort |
| Accept/reject sprint deliverables | Approve | Acceptance criteria, demo output |
| Defer feature sang release sau | Approve | Dependency analysis, business impact |
| Approve scope change trong sprint | Approve | Impact to sprint goal, team capacity |
| Authorize thêm requirement mới vào registry | Approve | Business justification, effort estimate |

### Pain Points

- Backlog không có đủ context để dev team estimate chính xác
- Conflict priority giữa các stakeholders internal — khó giữ trung lập
- Sprint velocity thực tế thường thấp hơn dự kiến, gây pressure rollout
- Stakeholders bypass PO để request trực tiếp với Developer

### Must-have Features

- ✅ Backlog board với drag-drop prioritization và story point estimation
- ✅ Sprint planning view liên kết backlog với team capacity
- ✅ Release notes generator từ completed user stories
- ✅ Dashboard ROI theo feature/epic để justify priorities

---

## Persona 3: Project Sponsor (Executive Sponsor)

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Executive Sponsor / Giám đốc bảo trợ dự án |
| **Experience** | 10+ năm quản lý cấp cao |
| **Report to** | CEO hoặc Board of Directors |
| **Focus** | Strategic alignment, budget authorization, risk oversight |

### Daily Tasks

1. Review executive dashboard về tiến độ và budget consumption (hàng tuần)
2. Quyết định escalated issues vượt thẩm quyền của PM/BA
3. Tham gia steering committee meetings (thường 1 lần/tháng)
4. Phê duyệt change requests có ảnh hưởng lớn đến scope hoặc budget
5. Communicate dự án với các stakeholder cấp Board

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Approve hoặc reject project business case | Approve | ROI projections, risk assessment, budget |
| Authorize budget vượt threshold | Approve | Budget utilization, variance explanation |
| Approve major scope changes (>20% effort) | Approve | Impact analysis: cost, timeline, risk |
| Resolve conflict giữa departments về priority | Approve | BA recommendation, each dept's justification |
| Quyết định tiếp tục hay dừng dự án | Approve | Project health report, escalation context |

### Pain Points

- Báo cáo tiến độ quá chi tiết về kỹ thuật, khó nắm bắt business impact
- Nhận escalation quá muộn khi vấn đề đã nghiêm trọng
- Không có full visibility về dependency giữa các dự án song song

### Must-have Features

- ✅ Executive summary dashboard: traffic light status, 1 trang
- ✅ Budget vs actuals với forecast to completion
- ✅ Risk register với early warning indicators
- ✅ Change request log với business impact tóm tắt cấp cao

---

## Persona 4: Domain SME (Subject Matter Expert)

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Subject Matter Expert / Chuyên gia nghiệp vụ chuyên sâu |
| **Experience** | 8–20 năm trong chuyên ngành (Finance, HR, Operations, v.v.) |
| **Report to** | Department Head (không report trực tiếp vào project) |
| **Focus** | Domain knowledge provision, requirement validation, process expertise |

### Daily Tasks

1. Trả lời câu hỏi từ BA team về quy trình và nghiệp vụ chuyên môn
2. Review requirements draft để xác nhận accuracy và completeness
3. Tham gia business process workshops với tư cách subject expert
4. Validate test scenarios và UAT test cases từ góc nhìn domain
5. Document edge cases và exception flows từ kinh nghiệm thực tiễn

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Xác nhận requirement phản ánh đúng thực tế nghiệp vụ | Approve | Requirement draft, process context |
| Chỉ ra exception cases quan trọng bị bỏ sót | Execute | Domain knowledge, historical data |
| Recommend data fields cần capture | Recommend | Business process, reporting needs |
| Validate UAT kết quả có đúng business logic | Approve | Test cases, system output |

### Pain Points

- Thời gian dành cho dự án bị tính ngoài KPI chính — thiếu ưu tiên
- Requirements không phản ánh được edge cases chỉ SME mới biết
- Thay đổi sau khi SME sign-off khiến domain knowledge không còn accurate
- Bị hỏi cùng câu hỏi nhiều lần do thiếu tài liệu ghi nhận quyết định

### Must-have Features

- ✅ Async review interface: comment trực tiếp vào requirement document
- ✅ Notification khi requirement trong domain của họ bị thay đổi
- ✅ Knowledge capture form để document exception flows và business rules
- ✅ Domain-specific filter để chỉ xem requirements liên quan

---

## Persona 5: Change Manager

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Change Manager / Quản lý thay đổi tổ chức |
| **Experience** | 5–12 năm |
| **Report to** | Project Sponsor hoặc HR Director |
| **Focus** | Organizational readiness, adoption, training, resistance management |

### Daily Tasks

1. Đánh giá impact của dự án đến từng nhóm người dùng (change impact assessment)
2. Thiết kế và triển khai training plan cho end users
3. Thu thập và phân tích feedback về adoption sau go-live
4. Theo dõi resistance indicators, escalate khi cần
5. Cập nhật stakeholder engagement plan theo tiến độ dự án

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Xác định nhóm người dùng cần training đặc biệt | Execute | Change impact assessment, org chart |
| Đánh giá go-live readiness của từng phòng ban | Recommend | Training completion rate, readiness survey |
| Thiết kế nội dung training | Execute | Feature list, process changes, user personas |
| Escalate resistance từ department cụ thể | Recommend | Survey data, meeting notes, attendance records |

### Pain Points

- Được đưa vào dự án quá trễ (sau khi system đã built) — không đủ thời gian chuẩn bị
- Không có visibility về feature list để lập training plan sớm
- Khó đo adoption rate sau go-live khi thiếu system usage data
- Thường bị xem là overhead thay vì core team member

### Must-have Features

- ✅ Change impact matrix: liên kết features với affected user groups
- ✅ Training completion tracker theo department
- ✅ User adoption dashboard: login frequency, feature usage heatmap
- ✅ Readiness checklist tích hợp vào go-live gate

---

## Quick Reference: Access Matrix

| Data / Function | BA Senior | Product Owner | Project Sponsor | Domain SME | Change Manager |
|-----------------|:---------:|:-------------:|:---------------:|:----------:|:--------------:|
| Tạo requirement mới | ✅ | ✅ | ❌ | ❌ | ❌ |
| Edit requirement draft | ✅ | ✅ | ❌ | ⚠ Comment only | ❌ |
| Edit approved requirement | ❌ | ✅ | ❌ | ❌ | ❌ |
| Approve requirement | ❌ | ✅ | ❌ | ⚠ Domain scope | ❌ |
| Xem toàn bộ requirements | ✅ | ✅ | ✅ | ⚠ Domain scope | ✅ View |
| Tạo change request | ✅ | ✅ | ✅ | ❌ | ❌ |
| Approve scope change (lớn) | ❌ | ⚠ Minor | ✅ | ❌ | ❌ |
| View project timeline | ✅ | ✅ | ✅ | ❌ | ✅ View |
| Edit project timeline | ❌ | ❌ | ❌ | ❌ | ❌ |
| Traceability matrix | ✅ | ✅ | ⚠ View | ❌ | ❌ |
| UAT sign-off | ❌ | ✅ | ⚠ Final escalation | ✅ Domain | ❌ |
| Go-live readiness decision | ⚠ Input | ✅ | ✅ Final | ⚠ Domain | ✅ Recommend |
| Training materials | ⚠ Contribute | ⚠ Contribute | ❌ | ⚠ Validate | ✅ Own |
| Budget data | ❌ | ⚠ High-level | ✅ | ❌ | ❌ |

<!-- ✅ = Full access, ❌ = No access, ⚠ = Conditional (xem mô tả persona cho chi tiết) -->
