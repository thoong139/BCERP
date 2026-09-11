# Playbook: Review Pull Request

> **Type**: Agent Skill Playbook
> **Agent**: code-reviewer
> **Triggered by**: /wf-implement-feature khi có PR cần review, hoặc gọi trực tiếp
> **Output**: PR review comments với severity labels tại path do skill cung cấp

---

## Khi nào dùng playbook này

- Khi developer tạo PR và cần review trước khi merge
- Khi cần đánh giá mức độ sẵn sàng merge của một changeset
- Khi cần peer review code thay đổi có phạm vi giới hạn (1 concern/feature)

---

## Procedure

### Bước 1: Thu thập ngữ cảnh PR

```
INPUT: PR description, link diff, hoặc danh sách files thay đổi do skill cung cấp
FALLBACK: tra .claude/references/path-registry.md → PHASE3, PHASE2

Cần xác định:
□ PR description có mô tả rõ "tại sao" và "cái gì" thay đổi không?
□ REQ-ID hoặc FEAT-ID nào PR này đang implement?
□ PR có linked ticket/issue không?
□ Base branch và target branch là gì?
```

Sau khi xác định context:
```
READ: .claude/references/team-expert/testing/code-review-patterns.md
```

### Bước 2: Kiểm tra PR scope (PR hygiene)

```
Đánh giá:
□ PR có quá lớn không? (> 400 dòng changed → cần tách)
□ PR giải quyết đúng 1 concern không? (không mix feature + refactor + bug fix)
□ PR title có mô tả chính xác nội dung không?
□ PR description có context đủ để reviewer hiểu mà không cần hỏi thêm không?
□ Có migration script đi kèm nếu thay đổi database schema không?

Nếu PR scope không rõ hoặc quá lớn:
  → Ghi nhận vào phần "PR Hygiene Findings"
  → Vẫn tiếp tục review nhưng note đây là vấn đề process
```

### Bước 3: Kiểm tra Code Style & Conventions

```
Đọc qua toàn bộ diff:
□ Naming conventions nhất quán với codebase (variables, functions, classes)?
□ File structure tuân theo project conventions?
□ Import order/grouping theo quy ước?
□ Không có dead code, commented-out code vô dụng?
□ Magic numbers/strings được extract thành constants?
□ Code formatting nhất quán (indent, line endings, trailing whitespace)?

Phân loại: Minor / Nit (không block merge)
```

### Bước 4: Logic Correctness

```
Phân tích logic từng file thay đổi:
□ Thuật toán implement đúng yêu cầu business không?
□ Điều kiện if/else/switch cover đủ cases không?
□ Off-by-one errors trong vòng lặp?
□ Null/undefined checks ở những nơi cần thiết?
□ State mutations có side effects không mong muốn?
□ Async/await xử lý đúng (không bỏ sót await, không race condition)?
□ Edge cases: empty input, max value, zero, negative number?

Nếu phát hiện logic sai → BLOCKER
```

### Bước 5: Error Handling

```
Kiểm tra:
□ Happy path và sad path đều được handle?
□ Errors được propagate đúng cách (không nuốt exception im lặng)?
□ Error messages có meaningful context để debug không?
□ HTTP status codes trả về đúng semantics (400 vs 422 vs 500)?
□ External service calls có timeout và retry logic?
□ Database errors có rollback nếu cần?
□ User-facing error messages không expose internal stack traces?

Lỗ hổng error handling trong critical path → BLOCKER
Thiếu ở non-critical path → Major
```

### Bước 6: Test Coverage

```
READ: .claude/references/team-expert/testing/test-strategy-patterns.md

Kiểm tra:
□ Unit tests cover happy path và sad path chính?
□ Edge cases được test (empty input, boundary values)?
□ Test names mô tả rõ scenario (KHÔNG dùng "should work", "test case 1")?
□ Test data không hardcode production values?
□ Mocking được dùng hợp lý (không over-mock)?
□ Tests độc lập (không phụ thuộc vào order chạy)?
□ Code coverage cho new code có đạt > 80% không?

Thiếu test cho critical business logic → BLOCKER
Coverage < 80% → Major
```

### Bước 7: Security Issues

```
Kiểm tra theo OWASP Top 10:
□ Input validation đủ trên mọi public-facing input?
□ SQL queries dùng parameterized statements / ORM (không raw string concat)?
□ XSS risks (output encoding nếu render HTML)?
□ Authentication được enforce đúng chỗ?
□ Authorization check: user chỉ access được data của mình?
□ Secrets/API keys có bị hardcode hoặc lộ trong log không?
□ Sensitive data (password, token) không được log?
□ File upload có validate type và size không?

Lỗ hổng bảo mật → BLOCKER, escalate sang security agent
```

### Bước 8: Performance Concerns

```
Đánh giá:
□ N+1 query patterns trong vòng lặp DB calls?
□ Queries có index phù hợp không? (xem table schema)
□ Allocations lớn hoặc không cần thiết trong hot paths?
□ Caching được dùng hợp lý cho expensive operations?
□ Không có synchronous blocking calls trong async context?
□ Pagination cho list endpoints (không return unbounded results)?

N+1 hoặc unbounded query → Major
Optimization concern không critical → Minor
```

### Bước 9: REQ-ID Coverage

```
Kiểm tra traceability:
□ Mọi business logic file có REQ-ID comment ở đầu file?
□ REQ-ID tham chiếu đến đúng requirement trong req-registry.json?
□ Nếu PR implement nhiều requirements → tất cả đều được reference?
□ Không có logic nằm ngoài scope của bất kỳ REQ-ID nào?

Format chuẩn:
  // REQ-ID: REQ-[DEPT]-[NNN]
  // FEAT-ID: FEAT-[SYS]-[NNN]

Thiếu REQ-ID trong business logic file → Major
```

### Bước 10: Documentation

```
Kiểm tra:
□ Public APIs / exported functions có JSDoc/docstring không?
□ Complex business logic có comment giải thích WHY (không chỉ WHAT)?
□ README được cập nhật nếu có thay đổi setup/config?
□ CHANGELOG hoặc migration guide nếu có breaking change?
□ Type definitions rõ ràng (không dùng `any` hoặc quá nhiều type casting)?

Thiếu doc → Minor / Nit tùy mức độ
```

### Bước 11: Quyết định Approve/Request Changes

```
Dựa trên kết quả các bước trên:

APPROVE nếu:
  → Không có BLOCKER
  → Không có Major chưa giải quyết
  → Minor/Nit chỉ là gợi ý, không bắt buộc

REQUEST CHANGES nếu:
  → Có ít nhất 1 BLOCKER
  → Có nhiều Major cần xử lý trước khi merge

NEEDS DISCUSSION nếu:
  → Có architecture concern cần thảo luận trước
  → Không chắc chắn về intent của code (đặt câu hỏi trước khi phán xét)
```

---

## Format Output: PR Review Report

```markdown
## PR Review: [PR Title]

**Reviewer**: code-reviewer
**Ngày review**: [date]
**Quyết định**: [APPROVE / REQUEST CHANGES / NEEDS DISCUSSION]

---

### Tổng quan
[2-3 câu về ấn tượng chung, điểm mạnh nổi bật, lo ngại chính]

### Điểm tốt
- [Ghi nhận ít nhất 1 điểm tốt cụ thể với file:dòng]

---

### Phát hiện

#### BLOCKER (phải sửa trước khi merge)
- **[file.ts:dòng]** — [Mô tả vấn đề]
  - **Lý do**: [Tại sao đây là vấn đề]
  - **Gợi ý**: [Hướng sửa]

#### Major (nên sửa, ảnh hưởng chất lượng)
- **[file.ts:dòng]** — [Mô tả]
  - **Lý do**: [...]
  - **Gợi ý**: [...]

#### Minor (cân nhắc sửa)
- **[file.ts:dòng]** — [Mô tả]

#### Nit (tùy chọn, chỉ là preference)
- **[file.ts:dòng]** — [Mô tả]

---

### PR Hygiene
[Nhận xét về scope, description, size nếu có vấn đề]

### REQ-ID Coverage
[Danh sách REQ-ID được cover, thiếu sót nếu có]

### Câu hỏi cần làm rõ
- [Câu hỏi 1 nếu có intent không rõ]
```

---

## Checklist trước khi submit review

```
□ Đã đọc toàn bộ diff (không chỉ đọc lướt)
□ Mỗi BLOCKER có giải thích LÝ DO rõ ràng
□ Ghi nhận ít nhất 1 điểm tốt
□ Không block vì style preference cá nhân
□ REQ-ID traceability đã kiểm tra
□ Security checklist đã đi qua
□ Quyết định cuối cùng rõ ràng với lý do
```
