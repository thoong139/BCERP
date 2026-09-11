# Playbook: Viết Unit Tests

> **Type**: Agent Skill Playbook
> **Agent**: developer
> **Triggered by**: Khi cần viết test suite cho một module, hoặc được gọi từ `implement-feature.md` Bước 5
> **Output**: Test suite files với coverage ≥ 80% cho business logic

---

## Khi nào dùng playbook này

- Khi implement feature mới và cần viết tests song song hoặc sau code
- Khi module hiện tại thiếu tests và cần bổ sung
- Khi TDD workflow: viết tests trước, implement sau

---

## Procedure

### Bước 1: Phân tích module cần test

```
INPUT: Source files của module cần test

Đọc và xác định:
□ Public interface: các hàm/method mà caller bên ngoài sẽ dùng
□ Dependencies: những gì module này phụ thuộc vào (DB, external APIs, other services)
□ Business rules: logic nào cần validate (validation, calculation, state transitions)
□ Error conditions: những trường hợp nào nên throw error

Phân tầng test scope:
- Service layer: test business logic — đây là nơi cần coverage cao nhất
- Controller layer: test request parsing + response mapping
- Repository layer: test query logic (nếu phức tạp) — thường dùng in-memory DB
```

### Bước 2: Identify boundary cases

```
Với mỗi public function, liệt kê test cases theo loại:

VALID INPUTS (Happy path):
□ Input đầy đủ, hợp lệ → output đúng
□ Input optional fields bỏ trống → default behavior đúng
□ Input ở giá trị boundary hợp lệ (min, max)

INVALID INPUTS (Validation):
□ Thiếu required fields → ValidationError
□ Sai format (email không hợp lệ, số âm khi cần dương) → ValidationError
□ Vượt giá trị max/min cho phép

BUSINESS RULE VIOLATIONS:
□ Vi phạm domain rules (ví dụ: đặt hàng vượt tồn kho) → domain-specific error
□ State machine violations (ví dụ: cancel một order đã shipped)
□ Authorization violations (resource thuộc về user khác)

NOT FOUND / EMPTY:
□ Entity không tồn tại → NotFoundError
□ Empty collection → trả về array rỗng, không throw
□ Null dependency → xử lý gracefully

CONCURRENCY / EDGE CASES (chỉ khi relevant):
□ Duplicate creation → ConflictError
□ Concurrent update → optimistic locking behavior
```

### Bước 3: Cấu trúc test file

```
Dùng pattern Arrange / Act / Assert (AAA) nhất quán:

describe('[ClassName hoặc function name]', () => {
  // Setup chung cho toàn group
  let service: OrderService;
  let mockRepository: jest.Mocked<OrderRepository>;

  beforeEach(() => {
    // ARRANGE: khởi tạo mocks và subject under test
    mockRepository = createMockRepository();
    service = new OrderService(mockRepository);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('[method name]', () => {
    it('should [expected behavior] when [condition]', async () => {
      // ARRANGE
      const input = buildValidOrderInput();
      mockRepository.findById.mockResolvedValue(existingOrder);

      // ACT
      const result = await service.createOrder(input);

      // ASSERT
      expect(result).toMatchObject({ status: 'pending' });
      expect(mockRepository.save).toHaveBeenCalledWith(
        expect.objectContaining({ customerId: input.customerId })
      );
    });
  });
});

QUY TẮC đặt tên test:
- Format: "should [expected outcome] when [condition]"
- Ví dụ đúng: "should throw OrderNotFoundError when orderId does not exist"
- Tránh: "test case 1", "works correctly", "should work"
```

### Bước 4: Viết Happy Path tests

```
Đây là test quan trọng nhất — xác nhận feature hoạt động đúng trong điều kiện bình thường:

□ Test output value: expect(result.status).toBe('pending')
□ Test side effects: expect(repository.save).toHaveBeenCalledOnce()
□ Test return type: expect(result).toBeInstanceOf(OrderDto)
□ Test không throw: await expect(service.createOrder(input)).resolves.not.toThrow()

Tip: Dùng builder/factory functions để tạo test data — tránh lặp code:
function buildValidOrderInput(overrides?: Partial<CreateOrderInput>): CreateOrderInput {
  return {
    customerId: 'customer-123',
    items: [{ productId: 'prod-001', quantity: 2 }],
    ...overrides,
  };
}
```

### Bước 5: Viết Error Case tests

```
Validation errors:
□ Test từng required field bị thiếu
□ Test từng field sai format
□ Dùng it.each() khi có nhiều invalid inputs cùng loại:

it.each([
  [null, 'customerId is required'],
  ['', 'customerId cannot be empty'],
  ['not-a-uuid', 'customerId must be a valid UUID'],
])('should throw ValidationError when customerId is %s', async (customerId, expectedMessage) => {
  await expect(service.createOrder({ customerId }))
    .rejects.toThrow(new ValidationError(expectedMessage));
});

Domain errors:
□ Mock dependencies để simulate domain failure
□ Verify error type và message — không chỉ check "throws"
```

### Bước 6: Viết Edge Case tests

```
Empty / null handling:
□ findAll với không có data → expect([]).toEqual([])
□ Optional fields không có → verify default value được dùng

Numeric boundary:
□ Quantity = 0, quantity = MAX_INT
□ Price = 0, price âm (nếu không hợp lệ → expect error)

State transitions:
□ Order ở state A → action → state B (happy path)
□ Order ở state A → action không hợp lệ ở state này → StateTransitionError
```

### Bước 7: Mock strategy

```
QUY TẮC MOCK:
□ Chỉ mock external dependencies — database, external APIs, file system, time
□ KHÔNG mock internal modules trong cùng service — đó là implementation detail
□ KHÔNG mock the subject under test (class bạn đang test)

Mock database (Repository layer):
→ Dùng in-memory implementation hoặc jest.fn() mocks
→ KHÔNG mock ORM internals (TypeORM, Prisma) — quá brittle

Mock external APIs:
→ Dùng jest.fn() hoặc MSW (Mock Service Worker) cho HTTP
→ Test cả success case và network failure case

Mock thời gian:
→ Dùng jest.useFakeTimers() nếu code phụ thuộc vào Date.now()
→ Reset sau mỗi test: afterEach(() => jest.useRealTimers())

Mock example:
const mockPaymentService = {
  charge: jest.fn().mockResolvedValue({ transactionId: 'txn-001' }),
} as jest.Mocked<PaymentService>;
```

### Bước 8: Code coverage target

```
Target coverage theo layer:
| Layer | Line Coverage | Branch Coverage |
|-------|--------------|-----------------|
| Service (business logic) | ≥ 80% | ≥ 70% |
| Controller | ≥ 70% | ≥ 60% |
| Repository | ≥ 60% | ≥ 50% |
| Utility/Helper | ≥ 90% | ≥ 80% |

Chạy kiểm tra coverage:
→ Jest: npx jest --coverage --collectCoverageFrom='src/**/*.ts'
→ pytest: pytest --cov=src --cov-report=term-missing

Nếu coverage thấp hơn target:
□ Identify uncovered branches trong report
□ Hỏi: nhánh đó có realistic user path không? Nếu có → thêm test case
□ Dead code → xem xét xóa thay vì thêm test giả tạo
```

### Bước 9: Test naming conventions

```
File naming:
- Jest/TypeScript: [module].service.spec.ts, [module].controller.spec.ts
- pytest: test_[module]_service.py, test_[module]_controller.py

Describe block: tên class hoặc function được test
it/test block: "should [outcome] when [condition]"

Tránh:
- "should work" — quá mơ hồ
- "test 1", "test case 2" — không readable
- "should not throw" — nên nói throw cái gì cụ thể

Ví dụ tốt:
describe('OrderService', () => {
  describe('cancelOrder', () => {
    it('should set order status to cancelled when order is in pending state')
    it('should throw OrderAlreadyShippedError when order has been shipped')
    it('should send cancellation notification email after successful cancellation')
  })
})
```

---

## Checklist trước khi submit

```
□ Coverage ≥ 80% cho business logic (Service layer)
□ Mọi public method có ít nhất 1 happy path test
□ Error cases được test với đúng error type (không chỉ "throws")
□ Mocks chỉ dùng cho external deps — không mock internal modules
□ Test names theo format "should [outcome] when [condition]"
□ Test data dùng builder/factory functions — không hard-code literals lặp lại
□ Tests pass locally trước khi commit
□ Không có test nào phụ thuộc thứ tự chạy (test isolation)
```
