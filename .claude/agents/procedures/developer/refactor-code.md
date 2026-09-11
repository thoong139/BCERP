# Playbook: Refactor Code

> **Type**: Agent Skill Playbook
> **Agent**: developer
> **Triggered by**: Khi cần refactor existing code — tech debt, performance, readability, hoặc theo yêu cầu sau audit
> **Output**: Code được cải thiện cấu trúc, cùng behavior, không regression

---

## Khi nào dùng playbook này

- Khi tech debt được ghi nhận trong Implementation Report và đến hạn refactor
- Khi code review (xem `review-implementation.md`) phát hiện code smells nghiêm trọng
- Khi cần improve performance sau profiling
- Khi cần cải thiện readability trước khi extend feature

---

## Procedure

### Bước 1: Đọc code hiện tại và xác định mục tiêu

```
INPUT: File paths cần refactor (do caller cung cấp hoặc từ tech debt notes)

Đọc và ghi chú:
□ Mục tiêu refactor là gì? (readability / performance / reduce duplication / testability)
□ Module này đang serve những REQ-ID nào? (xem comment trong file)
□ Ai là caller của module này? (grep để tìm imports)
□ Có integration với external systems không?

QUAN TRỌNG: Không thay đổi behavior bên ngoài — chỉ cải thiện cấu trúc bên trong.
Nếu cần thay đổi interface/API → đó là feature change, không phải refactor.
```

### Bước 2: Identify code smells

```
Kiểm tra theo danh sách code smells phổ biến:

DUPLICATION (DRY violations):
□ Copy-paste logic ở nhiều nơi → Extract common function/class
□ Cùng query pattern lặp lại ở nhiều repositories → Extract base repository
□ Validation logic lặp lại → Extract validator

LONG METHODS (> 30-40 lines):
□ Method làm quá nhiều việc → Extract private methods với tên rõ ràng
□ Mỗi method sau refactor nên chỉ làm 1 việc

DEEP NESTING (> 3 levels):
□ Nested if/else → Early return pattern
□ Nested loops → Extract inner loop thành separate method
□ Callback hell → Async/await, Promise chain

POOR NAMING:
□ Tên hàm mơ hồ: process(), handle(), doStuff() → đổi tên mô tả hành động
□ Tên biến quá ngắn: d, temp, x → đổi tên mô tả dữ liệu
□ Boolean flags: flag, isGood → đổi tên: isOrderCancellable, hasShippedItems

LARGE CLASS (God Object):
□ Class có quá nhiều responsibilities → Tách thành multiple focused classes
□ Áp dụng Single Responsibility Principle

MAGIC NUMBERS / MAGIC STRINGS:
□ if (status === 3) → đổi thành if (status === OrderStatus.SHIPPED)
□ timeout = 30000 → const DEFAULT_TIMEOUT_MS = 30_000

FEATURE ENVY:
□ Method A liên tục access data của object B → cân nhắc move method sang B
```

### Bước 3: Map test coverage hiện có

```
Trước khi thay đổi gì, xác định safety net:

□ Chạy test suite hiện tại — ghi nhận số tests pass, coverage %
□ Identify functions chưa có test → viết test cho chúng TRƯỚC KHI refactor
   (xem write-unit-tests.md)

LÝ DO: Nếu không có tests, không thể biết refactor có phá behavior không.
Quy tắc: Không refactor code không có tests.

Nếu coverage < 50% cho code cần refactor:
→ Dừng lại
→ Viết tests trước (dùng write-unit-tests.md)
→ Sau đó mới refactor
```

### Bước 4: Lập kế hoạch refactoring (nhỏ, incremental)

```
Chia refactoring thành các bước nhỏ, mỗi bước:
1. Thay đổi một điều duy nhất
2. Chạy tests → xác nhận pass
3. Commit (atomic)
4. Lặp lại

Thứ tự an toàn:
1. Rename (không thay đổi behavior)
2. Extract method (không thay đổi behavior)
3. Extract class (không thay đổi behavior)
4. Replace algorithm (có thể thay đổi internal, test kỹ)
5. Restructure data flow (cần test toàn diện)

KHÔNG làm nhiều thứ cùng lúc:
→ KHÔNG rename + extract + restructure trong 1 commit
→ KHÔNG fix bugs trong khi refactor (ghi nhận bug, fix sau)
```

### Bước 5: Thực hiện refactoring từng bước

```
Với mỗi bước refactor:

EARLY RETURN (thay deep nesting):
// BEFORE:
function processOrder(order) {
  if (order) {
    if (order.status === 'pending') {
      if (order.items.length > 0) {
        // ... logic
      }
    }
  }
}

// AFTER:
function processOrder(order) {
  if (!order) return;
  if (order.status !== 'pending') return;
  if (order.items.length === 0) return;
  // ... logic (không indent sâu)
}

EXTRACT METHOD (thay long method):
// BEFORE: method 80 lines làm nhiều việc
async createOrder(input) {
  // 20 lines validate input
  // 20 lines calculate pricing
  // 20 lines persist to DB
  // 20 lines send notifications
}

// AFTER:
async createOrder(input) {
  this.validateOrderInput(input);
  const pricing = await this.calculateOrderPricing(input.items);
  const order = await this.persistOrder(input, pricing);
  await this.notifyOrderCreated(order);
  return order;
}

REPLACE MAGIC NUMBERS:
// BEFORE: if (retryCount > 3)
// AFTER: const MAX_RETRY_ATTEMPTS = 3; if (retryCount > MAX_RETRY_ATTEMPTS)
```

### Bước 6: Verify tests pass sau mỗi bước

```
Sau MỖI bước refactor nhỏ:
□ Chạy toàn bộ test suite
□ Nếu tests fail → revert bước đó, tìm hiểu nguyên nhân
□ KHÔNG bỏ qua failing tests với lý do "sẽ fix sau"
□ KHÔNG sửa tests để match với code mới (trừ khi test sai)

Nếu test fail sau refactor:
→ Khả năng cao refactor đã thay đổi behavior vô tình
→ Revert và tìm chỗ khác để áp dụng refactoring nhỏ hơn
```

### Bước 7: Extract reusable utilities

```
Sau khi tách methods, xem xét có gì dùng chung nhiều nơi:

□ String/date formatting logic → utils/formatters.ts
□ Validation helpers → utils/validators.ts
□ Math calculations → utils/calculators.ts
□ Constants → constants/[domain].ts

Quy tắc tạo utility:
- Utility function phải pure (no side effects)
- Utility phải có unit test riêng
- Đặt trong package/module shared nếu dùng cross-module
```

### Bước 8: Cập nhật documentation và comments

```
Sau khi refactor:
□ Xóa comments giải thích WHAT (code tự giải thích rồi)
   Ví dụ: // Tăng counter lên 1 → xóa (counter++ đã rõ)
□ Giữ comments giải thích WHY (quyết định thiết kế)
   Ví dụ: // Dùng pessimistic locking vì conflict rate > 20% trong production
□ Cập nhật JSDoc/docstring nếu signature thay đổi
□ REQ-ID comments vẫn phải có sau refactor
□ Cập nhật README nếu module API thay đổi
```

### Bước 9: Verify no regression

```
Final verification trước khi tạo PR:

□ Full test suite pass
□ Coverage không giảm so với trước refactor
□ Không có any new lint warnings
□ Chạy integration tests nếu có
□ Thực hiện manual smoke test cho critical paths nếu thiếu test coverage

Commit message cuối:
refactor([module]): [mô tả ngắn điều đã cải thiện]

Ví dụ:
refactor(order-service): extract pricing calculation into dedicated PricingService
refactor(user-repository): replace magic numbers with named constants

KHÔNG commit message mơ hồ:
refactor: cleanup, refactor: minor improvements
```

---

## Checklist trước khi submit

```
□ Tests pass trước và sau refactor (không regression)
□ Coverage không giảm
□ Không có hành vi nào thay đổi (cùng input → cùng output)
□ Không có workaround mới được thêm vào
□ REQ-ID comments vẫn còn nguyên
□ Comments WHY được giữ lại; comments WHAT được xóa
□ Atomic commits — mỗi commit = 1 refactoring action
□ Tech debt đã xử lý được ghi nhận trong Implementation Report
```
