# Testing - Test Strategy & Planning Patterns

> **Domain**: Testing / Strategy & Planning
> **Last Updated**: 2026-03-15
> **Nguồn**: Industry best practices — ISTQB, Google Testing Blog, Kent Beck's Test Pyramid

---

## 1. Test Pyramid

Phân bổ test theo tầng để đạt balance giữa tốc độ, độ tin cậy và chi phí bảo trì.

```
           /‾‾‾‾‾‾‾‾‾‾‾‾\
          /  E2E Tests    \        5–10%   | Chậm, brittle, tốn kém
         /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
        /  Integration Tests \    20–30%  | Trung bình, kiểm tra biên giới
       /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
      /     Unit Tests          \  60–70% | Nhanh, isolated, chi phí thấp
     /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
```

**Anti-pattern cần tránh:** Ice cream cone (nhiều E2E, ít Unit) — dẫn đến test suite chậm, flaky, khó debug.

---

## 2. Định nghĩa & Phạm vi Từng Loại Test

| Loại Test | Scope | Tốc độ | Isolation | Khi nào dùng |
|-----------|-------|--------|-----------|--------------|
| Unit | Hàm / class đơn lẻ | < 10ms | Hoàn toàn (mock dependencies) | Logic thuần, business rules, calculations |
| Integration | 2+ modules ghép lại | 100ms–2s | Một phần (real DB/service) | Service + repository, API + middleware |
| Contract | Schema giữa producer/consumer | 50ms–1s | Mock service | Microservices, API boundaries |
| E2E | Full user journey | 5s–60s | Không (production-like env) | Critical happy paths, release gates |
| Smoke | Subset E2E tối thiểu | < 5 phút | Không | Sau mỗi deployment, sanity check |
| Regression | Toàn bộ tính năng đã có | Varies | Varies | Trước release, sau hotfix |
| Exploratory | Unscripted, tester-driven | N/A | Không | Sprint end, new features |
| Performance | Throughput, latency, stability | Phút–giờ | Không | Trước launch, sau infra change |
| Security | Vulnerabilities, auth, injection | Phút–giờ | Staging | Trước release, sau code security change |

---

## 3. Kỹ Thuật Thiết Kế Test Case

### 3a. Equivalence Partitioning
Chia input thành các nhóm có hành vi tương đương, test 1 đại diện mỗi nhóm.

```
Ví dụ: Trường tuổi (0–120)
  Hợp lệ:   18–65 → test với 30
  Không hợp lệ: < 0, > 120 → test với -1, 150
  Biên giới:  0, 18, 65, 120
```

### 3b. Boundary Value Analysis
Test tại và quanh ranh giới của các partition — nơi lỗi hay xảy ra nhất.

```
Giá trị ranh giới cho range [1, 100]:
  Dưới: 0 (invalid), 1 (min valid)
  Trên: 100 (max valid), 101 (invalid)
```

### 3c. Decision Table Testing
Dùng khi có nhiều điều kiện kết hợp ảnh hưởng đến output.

```
Điều kiện        | TC1 | TC2 | TC3 | TC4
─────────────────┼─────┼─────┼─────┼─────
User logged in   |  Y  |  Y  |  N  |  N
Has permission   |  Y  |  N  |  Y  |  N
─────────────────┼─────┼─────┼─────┼─────
Expected: Access |  Y  |  N  |  N  |  N
```

### 3d. State Transition Testing
Dùng cho workflow, FSM (Finite State Machine) — kiểm tra transitions hợp lệ và invalid.

```
Draft ──[submit]──► Pending ──[approve]──► Active
  ↑                    │                      │
  └────[reject]────────┘          [deactivate]┘
```

### 3e. Pairwise / Combinatorial Testing
Khi có N tham số với M giá trị mỗi tham số → thay vì test toàn bộ tổ hợp (M^N), test mọi cặp đôi (pair) — giảm 60–80% số test case mà vẫn bắt được phần lớn lỗi.

---

## 4. Risk-Based Testing Prioritization

Ma trận ưu tiên dựa trên Probability × Impact.

```
         │  Impact thấp  │  Impact trung  │  Impact cao
─────────┼───────────────┼────────────────┼─────────────
Prob cao │  MEDIUM (P2)  │   HIGH (P1)    │  CRITICAL (P0)
Prob TBình│  LOW (P3)     │  MEDIUM (P2)   │  HIGH (P1)
Prob thấp│  LOW (P3)     │   LOW (P3)     │  MEDIUM (P2)
```

**Áp dụng:**
- P0 CRITICAL: Test đầu tiên, block release nếu fail
- P1 HIGH: Test trong sprint, cần pass trước merge
- P2 MEDIUM: Test trước release, có thể defer nếu low-risk
- P3 LOW: Test khi có thời gian, document nếu skip

---

## 5. Test Coverage Strategy

| Loại Coverage | Mô tả | Mục tiêu | Công cụ |
|---------------|-------|----------|---------|
| Statement | Mỗi dòng code chạy ít nhất 1 lần | > 80% | Istanbul, JaCoCo |
| Branch | Mỗi nhánh if/else/switch được test | > 75% | Istanbul, Cobertura |
| Path | Mọi đường đi có thể qua code | > 60% | Niche tools |
| Mutation | Test cases bắt được khi code bị thay đổi nhỏ | > 70% mutation score | Stryker, PITest |

**Lưu ý:** Coverage cao không đồng nghĩa chất lượng test tốt. Tập trung vào meaningful assertions, không chỉ chạy code để tăng số %.

---

## 6. Definition of Done — QA Checklist

Trước khi feature được coi là Done:

- [ ] Unit test coverage >= 80% cho code mới
- [ ] Integration test cho mọi API endpoint
- [ ] E2E test cho critical user journey
- [ ] Không có P0/P1 bug mở
- [ ] Performance test pass (nếu feature ảnh hưởng throughput)
- [ ] Security scan không có critical/high vulnerability
- [ ] Accessibility check pass (WCAG 2.1 AA nếu có UI)
- [ ] Test report được tạo và review
- [ ] REQ-ID được trace đến test case

---

## 7. Bug Report Template

```
BUG-ID:      [BUG-XXX]
Title:       [Mô tả ngắn gọn, cụ thể]
Severity:    [Critical / High / Medium / Low]
Priority:    [P0 / P1 / P2 / P3]
Environment: [OS, Browser/App version, API version, Test env]
REQ-ID:      [REQ-XXX liên quan]

Steps to Reproduce:
  1.
  2.
  3.

Expected Result:
  [Hành vi mong đợi theo spec]

Actual Result:
  [Hành vi thực tế quan sát được]

Evidence:
  - Screenshot / video:
  - Log snippet:
  - Network response:

Workaround:  [Nếu có]
Assignee:    [Developer]
```

### Severity vs Priority Matrix

| | Priority cao | Priority thấp |
|--|-------------|---------------|
| **Severity cao** | Fix ngay (P0 blocker) | Fix trong sprint (kỹ thuật nghiêm trọng nhưng ít user bị ảnh hưởng) |
| **Severity thấp** | Fix sớm (UX quan trọng) | Backlog / nice-to-have |

---

## 8. Quality Metrics Dashboard

| Metric | Công thức | Target | Ngưỡng cảnh báo |
|--------|-----------|--------|-----------------|
| Defect Density | Bugs / KLOC | < 5 bugs/KLOC | > 10 bugs/KLOC |
| Test Pass Rate | (Pass / Total) × 100% | > 95% | < 90% |
| Code Coverage | Lines covered / Total lines | > 80% | < 70% |
| Escaped Defects | Bugs found in production / Total bugs | < 5% | > 15% |
| MTTR | Avg thời gian fix bug từ lúc report | < 4h (P0), < 2 ngày (P1) | > 8h (P0) |
| Flaky Test Rate | Flaky tests / Total tests | < 2% | > 5% |
| Test Execution Time | Tổng thời gian chạy CI test suite | < 10 phút | > 20 phút |
| Defect Removal Efficiency | Bugs found pre-prod / Total bugs | > 95% | < 85% |
