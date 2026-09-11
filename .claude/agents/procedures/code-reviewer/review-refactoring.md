# Playbook: Review Refactoring Changes

> **Type**: Agent Skill Playbook
> **Agent**: code-reviewer
> **Triggered by**: Khi có PR/commit refactoring code cần review
> **Output**: Refactoring Review Report tại path do skill cung cấp

---

## Khi nào dùng playbook này

- Khi developer submit refactoring changes (không phải feature mới hoặc bug fix)
- Khi cần verify behavior preservation sau khi restructure code
- Khi cần đánh giá xem refactoring có đúng mục tiêu không (reduce complexity, improve naming, extract duplication)
- Khi cần kiểm tra "chỉ refactor, không thêm feature" (no scope creep)

**Nguyên tắc cốt lõi của review này**: Code mới phải có CÙNG behavior với code cũ — cùng input cho cùng output, cùng side effects, cùng error behavior. Nếu behavior thay đổi → đây không còn là refactoring thuần túy.

---

## Procedure

### Bước 1: Đọc ngữ cảnh refactoring

```
INPUT: PR/diff và mô tả mục tiêu refactoring do skill cung cấp
FALLBACK: tra .claude/references/path-registry.md → PHASE3, PHASE5

Cần xác định:
□ Mục tiêu refactoring là gì? (improve naming, reduce complexity, extract duplication,
  improve testability, apply design pattern, performance optimization...)
□ Files nào bị thay đổi? Scope có hợp lý không?
□ REQ-IDs nào liên quan đến code được refactor?
□ Có test coverage trước khi refactor không?

READ: .claude/references/team-expert/testing/code-review-patterns.md
```

### Bước 2: Verify Behavior Preservation (Quan trọng nhất)

```
Đây là kiểm tra THEN CHỐT của review refactoring.
Mọi thay đổi phải đảm bảo: same input → same output, same side effects, same errors.

Phương pháp kiểm tra:
□ Tests hiện có có pass với code mới không?
□ Test cases đặc biệt cho edge cases có vẫn pass không?
□ Return types của public functions có thay đổi không?
□ Function signatures có thay đổi không? (thêm/bỏ/đổi params)
□ Side effects (DB writes, external calls, events) có thay đổi không?
□ Error types/messages được throw ra có thay đổi không?
□ Null/undefined handling có thay đổi không?

Phương pháp đọc diff để verify:
  1. Với mỗi function bị thay đổi: so sánh input → output logic
  2. Kiểm tra tất cả code paths (if/else, try/catch, loops)
  3. Tìm các điểm có thể silently change behavior:
     - Order của operations
     - Type coercions ẩn
     - Default parameter values
     - Exception handling thay đổi

Nếu phát hiện behavior thay đổi → BLOCKER ngay lập tức
```

### Bước 3: Test Coverage Before/After

```
So sánh test coverage:
□ Coverage % trước và sau refactoring (không được giảm)
□ Nếu code trước không có test → refactoring PHẢI thêm test (điều kiện để review)
□ Tests mới có test đúng behavior mới không?
□ Tests cũ có bị xóa không? Nếu có → lý do tại sao?

Kiểm tra chất lượng tests sau refactoring:
□ Test names vẫn mô tả đúng behavior?
□ Mocking strategy vẫn hợp lý?
□ Không có tests bị làm cho pass bằng cách hack (force mock để pass)?

Coverage giảm sau refactoring → Major (vi phạm mục tiêu refactoring)
Không có tests cho code được refactor → BLOCKER (không thể verify behavior)
```

### Bước 4: Kiểm tra không có thay đổi ngoài ý muốn

```
Đọc diff cẩn thận để tìm unintended changes:
□ Whitespace/formatting changes không liên quan đến logic?
□ Debug logs, console.log, print statements được thêm vào?
□ Environment-specific configurations bị thay đổi?
□ Comments có ý nghĩa bị xóa hoặc thay đổi?
□ TODO/FIXME comments bị xóa mà chưa được giải quyết?
□ Version numbers, build configs bị thay đổi không chủ ý?

Những thay đổi không liên quan → yêu cầu tách ra commit riêng (Minor/Major tùy mức độ)
```

### Bước 5: Performance Delta

```
Đánh giá tác động hiệu năng của refactoring:
□ Có thêm abstraction layers gây overhead không?
□ Loops được restructure có thay đổi complexity (O(n) → O(n²))?
□ Memory allocations tăng lên không?
□ Database query patterns thay đổi không?
□ Caching behavior bị thay đổi không?

Nếu mục tiêu refactoring là performance improvement:
□ Có benchmark chứng minh cải thiện không?
□ Cải thiện có significant hay chỉ micro-optimization vô nghĩa?

Performance regression → Major
```

### Bước 6: Complexity Reduction Verification

```
Verify refactoring đạt mục tiêu giảm complexity:
□ Cyclomatic complexity của functions đã giảm chưa?
□ Function length hợp lý hơn (< 50 dòng là target)?
□ Nesting levels giảm?
□ Conditional logic đơn giản hơn?
□ Magic numbers/strings đã được extract thành constants?
□ Duplication đã được remove (DRY principle)?
□ Design pattern áp dụng có phù hợp không? (không over-engineer)

Nếu complexity không giảm hoặc tăng → đặt câu hỏi về value của refactoring
```

### Bước 7: Dependency Changes

```
Kiểm tra tác động đến dependencies:
□ Import/dependency thay đổi có introduce circular deps không?
□ New dependencies được thêm vào (package.json/requirements.txt)?
  → New dependency có justified không?
  → Có thể dùng built-in thay vì external library?
□ Interface/API của module bị thay đổi không?
  → Nếu có → consumers có được update đồng bộ không?
□ Shared types/contracts bị thay đổi không?
  → Breaking change cho consumers?

Breaking dependency change không được đồng bộ → BLOCKER
```

### Bước 8: No Scope Creep Verification

```
Đây là kiểm tra quan trọng thứ 2 của review refactoring.
Refactoring KHÔNG được kèm theo:

□ Bug fixes ẩn trong refactoring?
  (OK nếu trivial + documented, nhưng cần tách commit nếu significant)
□ New features được thêm vào?
□ Performance optimizations không liên quan?
□ Configuration changes không liên quan?
□ API behavior changes?
□ Database schema changes?

Mọi thứ ngoài mục tiêu refactoring đã nêu → yêu cầu tách ra (Major)
Scope creep ẩn → phải flag ngay để không bị "sneak in" feature qua refactoring PR
```

### Bước 9: Documentation Accuracy

```
Kiểm tra documentation sau refactoring:
□ JSDoc/docstring vẫn còn chính xác sau khi thay đổi?
□ README/comments không bị outdated?
□ Type annotations vẫn đúng?
□ API documentation (nếu có endpoint thay đổi) được update?
□ Architecture diagrams (nếu có) cần update không?
□ Migration guide nếu có interface change?

Outdated documentation → Minor (nhưng quan trọng nếu public API)
```

---

## Format Output: Refactoring Review Report

```markdown
## Refactoring Review Report

**Agent**: code-reviewer
**Ngày review**: [date]
**Mục tiêu refactoring**: [Mục tiêu theo PR description]
**Kết luận**: [PASS / FAIL / CONDITIONAL PASS]

---

### Behavior Preservation: [VERIFIED / COMPROMISED]
[Mô tả kết quả kiểm tra: tests pass, edge cases preserved, no silent changes]

### Scope Compliance: [CLEAN / SCOPE CREEP DETECTED]
[Refactoring có đúng mục tiêu không? Có scope creep không?]

---

### Điểm tốt
- [Cải thiện cụ thể đạt được]

---

### Phát hiện

#### BLOCKER (behavior thay đổi hoặc tests không đủ)
- **[file:dòng]** — [Mô tả]
  - **Lý do**: [...]
  - **Gợi ý**: [...]

#### Major (scope creep, coverage giảm, performance regression)
- **[file:dòng]** — [Mô tả]
  - **Lý do**: [...]
  - **Gợi ý**: [...]

#### Minor (outdated docs, unintended whitespace changes)
- [file:dòng] — [mô tả]

#### Nit (optional improvements)
- [file:dòng] — [mô tả]

---

### Complexity Analysis
| Metric | Trước | Sau | Nhận xét |
|--------|-------|-----|---------|
| Max function length | [X] lines | [Y] lines | [tốt/xấu hơn] |
| Max nesting depth | [X] | [Y] | [...] |
| Duplicated blocks removed | — | [N] blocks | [...] |

### Test Coverage Delta
| Metric | Trước | Sau |
|--------|-------|-----|
| Coverage % | [X]% | [Y]% |
| Test count | [X] | [Y] |

### Scope Creep Check
| Thay đổi ngoài mục tiêu | Mức độ | Hành động |
|------------------------|--------|-----------|
| [Nếu có] | Minor/Major | Tách ra commit riêng |

---

### Kết luận
[Refactoring có đạt mục tiêu không? Tổng đánh giá]
```

---

## Checklist trước khi submit

```
□ Behavior preservation đã verify (tests pass + logic so sánh)
□ Không có scope creep ẩn
□ Coverage không giảm sau refactoring
□ Complexity metrics thực sự cải thiện
□ Dependencies không bị break
□ Documentation còn chính xác
□ Mỗi BLOCKER có lý do rõ ràng
□ Ghi nhận ít nhất 1 cải thiện cụ thể đạt được
```
