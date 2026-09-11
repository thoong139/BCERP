# Playbook: Viết Test Cases

> **Type**: Agent Skill Playbook
> **Agent**: qa-lead
> **Triggered by**: Khi cần viết test cases cho feature/module cụ thể
> **Output**: Test cases document tại `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-test-cases.md`

---

## Khi nào dùng playbook này

- Được gọi sau khi feature spec đã hoàn chỉnh (Phase 2)
- Khi developer yêu cầu test cases trước khi implement (TDD approach)
- Khi cần document lại test coverage cho một module hiện có
- Khi `/wf-implement-feature` spawns qa-lead để chuẩn bị test plan cho feature

---

## Procedure

### Bước 1: Đọc Feature Spec và Acceptance Criteria

```
INPUT: Feature path do skill cung cấp qua prompt (thường là phase2-features/[sys]/[mod]/[feat].md)
FALLBACK: tra .claude/references/path-registry.md → PHASE2

Cần xác định:
□ REQ-ID(s) liên quan đến feature này
□ Acceptance criteria (đây là nguồn test case chính)
□ User personas sẽ dùng feature
□ Dependencies với modules/features khác
□ Business rules cần validate
□ Input/output data types và constraints
```

Load knowledge cần thiết:
```
READ: .claude/references/team-expert/testing/test-strategy-patterns.md (Section 3, 4)
READ: .claude/references/team-expert/testing/qa-templates.md (Section 5)
```

### Bước 2: Phân tích và phân loại Test Scenarios

Trước khi viết test case, map ra các scenarios theo nhóm:

```
FUNCTIONAL SCENARIOS:
□ Happy path (user thực hiện đúng flow)
□ Alternative paths (user chọn các option khác nhau)
□ Validation paths (user nhập sai, hệ thống phải báo lỗi)

BOUNDARY SCENARIOS:
□ Min/max values cho mọi số field
□ Empty / null / whitespace inputs
□ String length boundaries

NEGATIVE SCENARIOS:
□ Unauthorized access
□ Invalid input types
□ Missing required fields
□ Concurrent actions (race conditions nếu có)

NON-FUNCTIONAL SCENARIOS:
□ Performance: response time với data volume lớn
□ Security: injection attempts, auth bypass
□ Accessibility: keyboard navigation, screen reader (nếu có UI)
```

### Bước 3: Áp dụng kỹ thuật thiết kế test case

Sử dụng các kỹ thuật từ test-strategy-patterns.md Section 3:

**3a. Equivalence Partitioning:**
```
Với mỗi input field, chia thành partitions:
- Partition hợp lệ: test 1-2 đại diện
- Partition không hợp lệ: test từng loại lỗi

Ví dụ field "email":
  Hợp lệ:       user@domain.com
  Không hợp lệ: thiếu @, thiếu domain, chuỗi rỗng
```

**3b. Boundary Value Analysis:**
```
Với mọi range/limit:
  - Giá trị min hợp lệ
  - Giá trị min - 1 (không hợp lệ)
  - Giá trị max hợp lệ
  - Giá trị max + 1 (không hợp lệ)
```

**3c. Decision Table (khi có nhiều điều kiện):**
```
Liệt kê tất cả combinations của conditions → Expected outcome
Ưu tiên dùng khi: pricing rules, permission matrix, workflow branching
```

**3d. State Transition (khi có workflow):**
```
Map tất cả states và transitions:
  - Valid transitions (theo flow)
  - Invalid transitions (bypass attempt)
  - State persistence (data không bị mất khi chuyển state)
```

### Bước 4: Viết Positive Test Cases

Format chuẩn cho mỗi test case:

```markdown
### TC-[REQ-ID]-[NNN]: [Tên mô tả hành động người dùng]

**REQ-ID**: [REQ-XXX] — traceability bắt buộc
**Priority**: [P0 / P1 / P2 / P3]
**Test Type**: [Unit / Integration / E2E]
**Precondition**: [Trạng thái hệ thống trước khi test]

**Test Data**:
- Input 1: [giá trị cụ thể]
- Input 2: [giá trị cụ thể]

**Steps**:
1. [Hành động 1]
2. [Hành động 2]
3. [Hành động 3]

**Expected Result**:
- [Kết quả mong đợi cụ thể, đo lường được]
- [Trạng thái hệ thống sau khi action]

**Post-condition**: [Cleanup nếu cần]
```

Positive test cases PHẢI cover:
```
□ Toàn bộ acceptance criteria (1 AC → ít nhất 1 TC)
□ Mọi user role có quyền thực hiện action
□ Các valid input variations quan trọng
```

### Bước 5: Viết Negative Test Cases

```
Với mỗi negative scenario, test case cần verify:
□ Hệ thống từ chối input/action sai
□ Error message rõ ràng, không leak thông tin nhạy cảm
□ Hệ thống không rơi vào inconsistent state
□ Dữ liệu không bị corrupt khi operation fail

Ưu tiên negative cases cho:
- Authentication / Authorization
- Financial calculations
- Data persistence operations
- External service integrations
```

### Bước 6: Viết Boundary / Edge Cases

```
Edge cases thường bị bỏ sót:
□ Đúng tại ngưỡng (min valid, max valid)
□ Vượt ngưỡng 1 đơn vị (min-1, max+1)
□ Empty collection (list có 0 items)
□ Single item collection (list có 1 item)
□ Rất nhiều items (performance edge case)
□ Concurrent requests (cùng lúc 2 user thực hiện)
□ Network timeout / service unavailable
□ Timezone và locale differences (nếu có date/time)
□ Unicode và special characters trong text fields
```

### Bước 7: Viết Non-Functional Test Cases

**Performance test cases:**
```
TC-PERF-[NNN]: [Feature] phải respond trong X ms với Y records
- Tool: Ghi chú dùng k6 / JMeter / Locust
- Threshold: Theo Performance SLA trong test-strategy.md
- READ: .claude/references/team-expert/testing/load-testing-examples.md (Section 4)
```

**Security test cases:**
```
TC-SEC-[NNN]: [Feature] phải block [attack vector]
Checklist:
□ SQL injection trong text inputs
□ XSS trong display fields
□ Unauthorized access với invalid token
□ Mass assignment / parameter pollution
□ Sensitive data exposure trong responses/logs
```

**Accessibility test cases (nếu có UI):**
```
TC-A11Y-[NNN]: [Component] phải accessible theo WCAG 2.1 AA
Checklist:
□ Keyboard navigation (Tab order)
□ Screen reader labels (aria-label, alt text)
□ Color contrast ratio >= 4.5:1
□ Focus visible
```

### Bước 8: Xác định Test Data Requirements

```
Với mỗi test case group, document rõ:

□ Test accounts cần có (roles, permissions)
□ Seed data cần có (records, relationships)
□ External service mocks cần setup
□ Environment variables cần config

Format:
| Test Data Item | Value / Config | Scope |
|----------------|----------------|-------|
| Admin account  | admin@test.com | E2E   |
| Product seed   | 100 records    | Integ |
| Payment mock   | Stripe sandbox | Integ |
```

### Bước 9: Tạo REQ-ID Traceability Matrix

```
Document ánh xạ REQ-ID → Test Cases để verify coverage:

| REQ-ID | Requirement | Test Cases | Coverage |
|--------|-------------|------------|----------|
| REQ-XXX-001 | [Tên] | TC-001, TC-002, TC-007 | Unit + Integration |
| REQ-XXX-002 | [Tên] | TC-003, TC-008 | Integration + E2E |

Checklist coverage:
□ Mỗi REQ-ID có ít nhất 1 positive test case
□ REQ-ID có critical/complex logic → có negative + boundary cases
□ Không có TC nào không map được về REQ-ID
```

### Bước 10: Peer Review Checklist

Trước khi submit test cases để review:

```
□ Mỗi TC có ID duy nhất, không trùng lặp
□ Steps đủ cụ thể để người khác reproduce được
□ Expected result là observable, measurable — không dùng "hoạt động tốt"
□ Priority được gán theo Risk Matrix (P0/P1/P2/P3)
□ Test Type rõ ràng (Unit / Integration / E2E)
□ REQ-ID traceability 100% (không TC nào thiếu REQ-ID)
□ Test data requirements được document
□ Negative cases cover mọi error path trong acceptance criteria
□ Boundary cases cover mọi numeric/string field có giới hạn
□ Non-functional cases có threshold cụ thể
```

### Bước 11: Ghi output

```
Ghi vào: .mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-test-cases.md

Cấu trúc document:
1. Overview (feature name, REQ-IDs, scope)
2. Test Data Requirements
3. Positive Test Cases (nhóm theo user flow)
4. Negative Test Cases (nhóm theo error type)
5. Boundary / Edge Cases
6. Non-Functional Test Cases (performance, security, a11y)
7. REQ-ID Traceability Matrix
8. Test Execution Notes (environment, tools, special setup)
```

---

## Checklist trước khi submit

```
□ 100% acceptance criteria được map về ít nhất 1 test case
□ Mọi TC có REQ-ID reference
□ Có ít nhất 1 negative case cho mỗi input validation rule
□ Boundary values được test cho mọi numeric/length constraint
□ Non-functional thresholds cụ thể (không dùng "đủ nhanh")
□ Test data không dùng production data thật
□ Peer review checklist đã pass
```
