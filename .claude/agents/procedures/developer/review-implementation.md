# Playbook: Review Implementation

> **Type**: Agent Skill Playbook
> **Agent**: developer
> **Triggered by**: Self-review trước khi merge (mọi feature), hoặc peer review khi được yêu cầu
> **Output**: Code review report với danh sách findings phân loại theo severity

---

## Khi nào dùng playbook này

- **Self-review**: Developer tự review code của mình trước khi tạo PR — bắt buộc mọi feature
- **Peer review**: Khi được chỉ định review code của người khác
- **Pre-merge review**: Khi lead/architect yêu cầu trước khi merge vào main

---

## Procedure

### Bước 1: Xác định scope review

```
INPUT: File paths hoặc PR diff cần review

Xác định:
□ Module nào? REQ-ID nào được implement?
□ Scope: feature mới / bug fix / refactoring?
□ Có breaking changes không? (thay đổi API, schema, interface)
□ Có files nào là critical path (payment, auth, data migration) không?
   → Critical path cần review kỹ hơn

Đọc task spec trước khi review code:
→ .mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md
→ Không có spec → không thể biết intent → hỏi người implement
```

### Bước 2: Kiểm tra code style và conventions

```
□ Naming conventions nhất quán với codebase:
   - Classes: PascalCase
   - Functions/variables: camelCase
   - Constants: SCREAMING_SNAKE_CASE
   - Files: kebab-case hoặc theo convention của project
□ Không có abbreviated names khó hiểu: usr, ord, tmp
□ Boolean variables/functions mô tả state: isOrderCancellable, hasActiveSubscription
□ Async functions rõ ràng: fetchUserById() tốt hơn getUser()
□ Không mix languages trong naming (Anh + Việt)
□ Magic numbers được đặt tên: MAX_RETRY_ATTEMPTS thay vì 3
□ File length reasonable: nếu > 300 lines → xem xét tách
```

### Bước 3: Verify REQ-ID coverage

```
BẮT BUỘC — theo CORE-003:

□ Mỗi file code có ít nhất 1 REQ-ID comment
□ Format đúng: // REQ-ID: REQ-[DEPT]-[NNN] hoặc REQ-[SYSTEM]-[MODULE]-[NNN]
□ REQ-ID tồn tại trong .mc-data/docs/_meta/req-registry.json
□ Feature code map đúng REQ-ID — không reference sai module

Nếu thiếu REQ-ID → BLOCKER (phải fix trước khi merge)
```

### Bước 4: Kiểm tra logic correctness

```
□ Business logic match với acceptance criteria trong task spec
   → Đọc spec, đọc code, so sánh từng criterion
□ Calculation đúng: không off-by-one, không precision loss
□ Conditional logic đầy đủ:
   - Xử lý null/undefined
   - Xử lý empty collection
   - Xử lý edge cases đã documented trong spec
□ State transitions hợp lệ: không cho phép transition invalid
□ Idempotency: nếu API cần idempotent → verify implementation
□ Ordering: sort/filter có đúng không?
□ Pagination: offset/limit/cursor implement đúng không?
```

### Bước 5: Kiểm tra error handling

```
□ Không "swallow" exceptions (catch block rỗng hoặc chỉ log)
□ Error types cụ thể — không throw new Error('something went wrong')
□ Error messages hữu ích cho debugging, nhưng không leak internals
□ Controller/Handler map domain errors → HTTP status codes đúng:
   - NotFoundError → 404
   - ValidationError → 400
   - AuthorizationError → 403
   - ConflictError → 409
   - Unexpected errors → 500 (không expose details)
□ External service failures có graceful degradation không?
□ Timeout xử lý đúng: không để request treo vô thời hạn
□ Retry logic: có exponential backoff không? (nếu applicable)
```

### Bước 6: Kiểm tra security issues

```
READ: .claude/references/team-expert/engineering/security-checklist.md

Checklist bắt buộc:

INJECTION PREVENTION (OWASP A03):
□ SQL: dùng parameterized queries hoặc ORM — không string concatenation
□ NoSQL: không inject user input vào query operators ($where, $regex)
□ Command injection: không exec(userInput), không shell interpolation

ACCESS CONTROL (OWASP A01):
□ Mọi endpoint kiểm tra authentication (token/session valid)
□ Mọi resource access kiểm tra authorization (user có quyền với resource đó không)
□ Không dựa vào security through obscurity (giấu URL không thay thế auth check)

SENSITIVE DATA:
□ Không log password, token, credit card số, PII
□ Không trả về sensitive fields trong response không cần thiết
□ Password phải hashed (bcrypt/argon2) — không MD5/SHA1

SECRETS MANAGEMENT:
□ Không hardcode API keys, DB credentials trong code
□ Không commit .env files
□ Config đọc từ environment variables

INPUT VALIDATION:
□ Validate tất cả input trước khi xử lý (không chỉ validate ở frontend)
□ Validate type, format, length, range

Findings phân loại:
→ Critical: SQL injection, hardcoded secrets, auth bypass → phải fix ngay
→ High: missing auth check, logging sensitive data
→ Medium: input validation thiếu, error message leak internal info
```

### Bước 7: Kiểm tra performance concerns

```
READ: .claude/references/team-expert/engineering/database-patterns.md (Section N+1)

N+1 QUERIES:
□ Vòng lặp có query database bên trong không?
   → Nếu có: dùng JOIN hoặc batch loading (dataloader pattern)
□ Có eager loading khi không cần thiết không?
   → Chỉ load relations thực sự cần dùng

UNNECESSARY COMPUTATION:
□ Có tính toán nặng trong mọi request thay vì cache kết quả không?
□ Có load toàn bộ dataset vào memory thay vì paginate không?
□ String concatenation trong vòng lặp lớn → dùng array.join()

CACHING:
□ Response phù hợp cho caching có Cache-Control header không?
□ Cache invalidation đúng khi data thay đổi không?

Nếu phát hiện performance issue nghiêm trọng:
→ Ghi vào report với estimate impact
→ Không fix trong cùng PR nếu scope lớn (tạo tech debt note)
```

### Bước 8: Kiểm tra test quality

```
□ Test coverage ≥ 80% cho business logic (Service layer)
□ Test names mô tả rõ: "should throw OrderNotFoundError when orderId does not exist"
□ Tests không phụ thuộc nhau (test isolation)
□ Không mock internal modules — chỉ mock external deps
□ Không test implementation details — test behavior/output
□ Assert đủ: không chỉ assert "không throw" mà còn assert giá trị trả về
□ Edge cases có test không? (empty, null, max value)
□ Không có hardcoded test data có thể gây false positive theo thời gian
   (ví dụ: so sánh với current date mà không mock Date)
```

### Bước 9: Kiểm tra documentation

```
□ REQ-ID comments đúng format và đúng requirement
□ Complex business logic có comment giải thích WHY (không WHAT)
□ Public API có JSDoc/docstring đầy đủ nếu project yêu cầu
□ Workaround/hack phải có comment:
   // TECH-DEBT: Workaround cho [vấn đề]. Cần refactor khi [điều kiện].
   // REQ-ID: [ID liên quan nếu có]
□ TODO chỉ acceptable nếu có ticket/issue reference:
   // TODO: [ticket-123] Remove after migration hoàn tất
```

### Bước 10: Tổng hợp và viết review report

```
Phân loại findings theo severity:

BLOCKER (phải fix trước khi merge):
- Security vulnerabilities (injection, auth bypass, hardcoded secrets)
- Missing REQ-ID (vi phạm CORE-003)
- Tests fail
- Logic sai so với acceptance criteria

CRITICAL (cần fix trong sprint này):
- N+1 queries ảnh hưởng performance
- Missing error handling trên critical paths
- Sensitive data leak trong logs/response

MAJOR (fix trong sprint sau, tạo tech debt note):
- Code smells ảnh hưởng maintainability
- Test coverage thấp (<60%)
- Documentation thiếu

MINOR (suggestion, optional):
- Naming improvement
- Style inconsistency nhỏ
- Performance optimization nhỏ

Format report:

---
## Code Review Report
**Module**: [tên module]
**REQ-ID**: [REQ-ID được review]
**Reviewer**: developer (self-review / peer review)
**Date**: [ngày]

### BLOCKER
- [ ] [File:Line] [Mô tả vấn đề] — [Đề xuất fix]

### CRITICAL
- [ ] [File:Line] [Mô tả vấn đề] — [Đề xuất fix]

### MAJOR
- [ ] [File:Line] [Mô tả vấn đề] — [Đề xuất fix]

### MINOR
- [ ] [File:Line] [Gợi ý cải thiện]

### Kết luận
[ ] APPROVE — không có blocker/critical
[ ] REQUEST CHANGES — có blocker/critical cần fix
---

Ghi report vào path do skill cung cấp.
Fallback: .mc-data/work/wf-implement-feature/[feat]-review.md
```

---

## Checklist trước khi submit review

```
□ Đã đọc task spec trước khi review code
□ Mọi BLOCKER findings được document rõ ràng với đề xuất fix
□ Security checklist đã đi qua đầy đủ (không skip)
□ REQ-ID coverage đã verify
□ Performance concerns được note nếu có
□ Kết luận rõ ràng: APPROVE hoặc REQUEST CHANGES
□ Tone của feedback constructive — ghi findings, không ghi judgment về người code
```
