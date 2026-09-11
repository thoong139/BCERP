# Playbook: Review Feature Implementation

> **Type**: Agent Skill Playbook
> **Agent**: code-reviewer
> **Triggered by**: /wf-implement-feature sau khi feature được implement hoàn chỉnh
> **Output**: Feature Review Report tại path do skill cung cấp

---

## Khi nào dùng playbook này

- Khi một feature mới đã implement xong và cần deep review toàn bộ
- Khi cần đánh giá compliance của implementation với feature spec
- Khi cần sign-off trước khi feature được merge vào main branch
- Khác với review-pr.md: playbook này review TOÀN BỘ feature (nhiều files, nhiều PRs), không phải từng PR đơn lẻ

---

## Procedure

### Bước 1: Đọc Feature Specification

```
INPUT: Feature name, REQ-IDs liên quan, paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2, PHASE3, PHASE5

Cần thu thập:
□ Feature spec tại .mc-data/docs/phase2-features/[sys]/[mod]/[feat].md
□ Implementation task tại .mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md
□ API contract tại .mc-data/docs/phase3-architecture/ (nếu có)
□ REQ-IDs liên quan từ req-registry.json

Đọc knowledge base:
READ: .claude/references/team-expert/testing/code-review-patterns.md
READ: .claude/references/team-expert/testing/test-strategy-patterns.md
```

### Bước 2: File-by-file Architecture Review

```
Với mỗi file trong feature implementation:
□ File có đúng responsibility không? (Single Responsibility Principle)
□ File đặt đúng vị trí trong project structure không?
□ Dependencies hợp lý (không có circular dependency)?
□ Abstraction layers được tôn trọng (Controller không gọi thẳng Repository)?
□ Dependency Injection được dùng đúng cách?
□ Không có god class hoặc spaghetti function?

Với mỗi class/module:
□ Tên class/module phản ánh đúng responsibility?
□ Public interface tối thiểu (Law of Demeter)?
□ Extension points hợp lý (Open/Closed Principle)?
```

### Bước 3: Business Logic Correctness

```
Đối chiếu code với Feature Spec:
□ Mọi Acceptance Criteria trong spec đều được implement?
□ Business rules được encode chính xác?
□ Tính toán/formula đúng với yêu cầu nghiệp vụ?
□ Workflow/state machine đúng với flow diagram?
□ Validation rules khớp với business constraints?
□ Edge cases trong spec được xử lý?

Kiểm tra boundary conditions:
□ Minimum/Maximum values?
□ Empty state (không có data)?
□ Concurrent operations (race conditions)?
□ Idempotency cho operations quan trọng?
```

### Bước 4: Data Layer Review

```
Kiểm tra queries và transactions:
□ ORM queries đúng không? Không raw string concatenation?
□ N+1 query patterns? (vòng lặp có DB call bên trong)
□ Eager loading được dùng khi cần?
□ Indexes phù hợp cho các query thường dùng?
□ Transactions bao đúng phạm vi (không quá rộng, không quá hẹp)?
□ Optimistic/pessimistic locking khi cần tránh race condition?
□ Soft delete được implement nếu spec yêu cầu?
□ Audit trail / updated_at được cập nhật?
□ Migration scripts đúng và reversible?

Đặc biệt chú ý:
□ Query không return unbounded result set (phải có LIMIT)?
□ Sensitive data được encrypt trước khi lưu?
```

### Bước 5: API Contract Compliance

```
Đối chiếu implementation với API spec (nếu có):
□ Endpoint paths khớp với spec?
□ HTTP methods đúng semantics (GET read-only, POST create, PUT/PATCH update, DELETE)?
□ Request body schema đúng (required fields, types, format)?
□ Response schema khớp (field names, data types, null handling)?
□ HTTP status codes đúng (200/201/204/400/401/403/404/422/500)?
□ Error response format nhất quán?
□ Pagination (nếu có) implement đúng (cursor vs offset)?
□ Authentication/Authorization middleware được apply đúng?
□ Rate limiting headers trả về không?
```

### Bước 6: Test Suite Adequacy

```
READ: .claude/references/team-expert/testing/test-strategy-patterns.md

Đánh giá test coverage:
□ Unit tests cho business logic functions?
□ Integration tests cho API endpoints?
□ Happy path, sad path, và edge cases?
□ Error scenarios được test (network failure, DB error)?
□ Test data factories/fixtures đúng cách (không hardcode)?
□ Mocking strategies hợp lý?

Chất lượng tests:
□ Test names mô tả scenario rõ ràng (Given-When-Then)?
□ Assertions cụ thể (không chỉ assert không có exception)?
□ Tests độc lập với nhau (không shared state)?
□ Flaky tests? (test khi pass khi fail không nhất quán)
□ Code coverage đạt > 80% cho business logic?
```

### Bước 7: Security Checklist

```
Input validation:
□ Mọi user-provided input được validate và sanitize?
□ File upload: validate type, size, content?
□ Query parameters được validate (type, range, allowed values)?

Authentication & Authorization:
□ Endpoints yêu cầu auth được protect đúng?
□ Authorization check: user chỉ access data của họ?
□ Admin-only endpoints được restrict đúng?
□ Token validation đúng (expiry, signature)?

Data protection:
□ Passwords được hash với bcrypt/argon2 (không MD5, SHA1)?
□ Sensitive data không được log?
□ PII được encrypt khi lưu trữ?
□ SQL injection protection (parameterized queries)?
□ CSRF protection cho mutation endpoints?

Phát hiện lỗ hổng nghiêm trọng → escalate sang security agent
```

### Bước 8: Performance Profiling

```
Nhận diện potential bottlenecks:
□ API endpoints có thể bị chậm dưới tải cao?
□ Expensive computations trong request path?
□ External service calls được cache hợp lý?
□ Database queries được optimize?
□ Background jobs được dùng cho operations không cần synchronous?

Đánh giá resource usage:
□ Memory leaks tiềm năng (event listeners không được remove)?
□ Connection pools được dùng đúng?
□ Large objects không được hold in memory lâu hơn cần?

Nếu cần benchmark cụ thể → huy động performance-benchmarker
```

### Bước 9: Code Coverage Check

```
Đánh giá coverage tổng thể:
□ Coverage report (nếu có) đạt ngưỡng yêu cầu (> 80%)?
□ Uncovered paths có phải là critical business logic không?
□ Dead code paths (code không bao giờ được chạy)?
□ Test coverage cho error handling paths?
□ Coverage không bị inflate bởi trivial getter/setter tests?

Action:
  Coverage < 80% cho critical paths → request thêm tests (Major)
  Coverage thiếu ở utility/helper → Minor
```

### Bước 10: REQ-ID Completeness

```
Kiểm tra traceability toàn feature:
□ Mọi business logic file có REQ-ID comment?
□ Mọi REQ-ID trong feature spec đều có code implement?
□ Không có code thừa không liên quan đến bất kỳ REQ-ID nào?
□ FEAT-ID được reference khi cần (phase2 features)?

Đọc req-registry.json để verify:
  REQ-IDs trong code ↔ REQ-IDs trong registry phải khớp
  Không tự tạo REQ-ID mới ngoài registry

Thiếu REQ-ID trong business logic → Major
```

### Bước 11: Integration Points

```
Kiểm tra tích hợp với các module khác:
□ Events/messages được publish đúng format?
□ External service clients có error handling và retry?
□ Shared types/interfaces được import từ packages/ (không duplicate)?
□ Breaking changes với consumers hiện tại?
□ Webhooks/callbacks được verify signature?
□ Cache invalidation strategy khi data thay đổi?
□ Feature flags được implement nếu spec yêu cầu?
```

---

## Format Output: Feature Review Report

```markdown
## Feature Review Report: [Feature Name]

**Agent**: code-reviewer
**Ngày review**: [date]
**REQ-IDs covered**: [REQ-001, REQ-002, ...]
**Kết luận**: [PASS / FAIL / CONDITIONAL PASS]

---

### Tổng quan
[3-5 câu: feature có implement đúng spec không, điểm mạnh, lo ngại chính]

### Điểm tốt
- [Ghi nhận cụ thể với file:dòng]

---

### Phát hiện

#### BLOCKER (phải sửa trước khi merge)
| # | File:Dòng | Vấn đề | Lý do | Gợi ý |
|---|-----------|--------|-------|-------|
| 1 | ... | ... | ... | ... |

#### Major (ảnh hưởng chất lượng, cần sửa)
| # | File:Dòng | Vấn đề | Lý do | Gợi ý |
|---|-----------|--------|-------|-------|

#### Minor (cân nhắc cải thiện)
- [file:dòng] — [mô tả]

#### Nit (optional improvements)
- [file:dòng] — [mô tả]

---

### Compliance với Feature Spec
| Acceptance Criteria | Trạng thái | Ghi chú |
|--------------------|-----------|---------|
| [AC-1] | PASS / FAIL | ... |

### Security Checklist Summary
| Hạng mục | Trạng thái |
|----------|-----------|
| Input validation | PASS / FAIL / N/A |
| Auth/Authorization | PASS / FAIL / N/A |
| Data protection | PASS / FAIL / N/A |
| SQL injection | PASS / FAIL / N/A |

### REQ-ID Traceability
| REQ-ID | Files implement | Trạng thái |
|--------|----------------|-----------|
| REQ-XXX-001 | [files] | Covered / Missing |

### Test Coverage Summary
- Tổng coverage: [X]%
- Critical paths: [X]%
- Thiếu tests: [danh sách nếu có]

---

### Khuyến nghị
[Action items cụ thể nếu FAIL hoặc CONDITIONAL PASS]
```

---

## Checklist trước khi submit

```
□ Đọc feature spec và đối chiếu từng Acceptance Criteria
□ Kiểm tra toàn bộ files liên quan (không bỏ sót file nào)
□ Security checklist đi qua đầy đủ
□ REQ-ID traceability verified với req-registry.json
□ Mỗi BLOCKER/Major có lý do và gợi ý cụ thể
□ Ghi nhận ít nhất 1 điểm tốt
□ Kết luận PASS/FAIL rõ ràng
```
