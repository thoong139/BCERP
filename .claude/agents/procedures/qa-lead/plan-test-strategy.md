# Playbook: Lập Test Strategy

> **Type**: Agent Skill Playbook
> **Agent**: qa-lead
> **Triggered by**: Đầu project hoặc major release — khi cần thiết kế chiến lược kiểm thử toàn diện
> **Output**: `.mc-data/docs/phase5-implementation/test-strategy.md`

---

## Khi nào dùng playbook này

- Được gọi ở đầu project, trước khi bắt đầu sprint testing đầu tiên
- Khi có major release yêu cầu review lại strategy
- Khi team thay đổi tech stack hoặc kiến trúc hệ thống đáng kể
- Khi qa-lead được spawn bởi `/wf-plan-modules` hoặc `/wf-implement-feature`

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2, PHASE3

Cần xác định:
□ Loại hệ thống (web app / API-only / mobile / microservices / monolith)
□ Tech stack: ngôn ngữ, framework, database
□ Giai đoạn dự án (greenfield / legacy / major release)
□ Team size và cơ cấu QA (manual / automation / hybrid)
□ CI/CD pipeline hiện có chưa?
□ Requirements đã có REQ-ID chưa?
```

Sau khi xác định loại hệ thống:
```
READ: .claude/references/team-expert/testing/test-strategy-patterns.md (Section 1, 4, 5)
READ: .claude/references/team-expert/testing/qa-templates.md (Section 1, 4, 7)
```

### Bước 2: Xác định Quality Goals

Dựa trên business context, thiết lập mục tiêu chất lượng cụ thể:

```
□ Pass rate target: [mặc định >95%]
□ Code coverage target: [mặc định >80% statement, >75% branch]
□ Defect density target: [mặc định <5 bugs/KLOC]
□ Escaped defect rate: [mặc định <5% ra production]
□ Performance SLA: [p95 response time, error rate]
□ Security baseline: [OWASP Top 10, không có Critical/High vuln]
□ Accessibility standard: [WCAG 2.1 AA nếu có UI]

WHY: Quality goals phải được đặt trước khi thiết kế test cases —
chúng là "definition of done" cho toàn bộ testing effort.
```

### Bước 3: Xác định Test Scope

```
In Scope (PHẢI test):
□ Đọc req-registry.json → liệt kê tất cả REQ-IDs và features
□ Mọi critical path của user journey
□ Tất cả API endpoints (nếu có)
□ Business logic phức tạp (tính toán, workflow, state machine)
□ Security boundaries (auth, authorization, input validation)
□ Integration points giữa services/modules

Out of Scope (KHÔNG test hoặc defer):
□ Third-party libraries (chỉ test adapter/wrapper của ta)
□ Infrastructure-level (thuộc DevOps)
□ [Các features explicitly defer sang phase sau]

WHY: Scope rõ ràng ngăn scope creep và giúp estimate effort chính xác.
```

### Bước 4: Thiết kế Test Pyramid

Áp dụng tỉ lệ 70/20/10 theo test-strategy-patterns.md:

```
Unit Tests (70%):
- Scope: Hàm / class đơn lẻ, isolated hoàn toàn (mock dependencies)
- Target: Mọi business logic, calculations, validations
- Framework gợi ý: Jest (JS/TS), pytest (Python), JUnit (Java)
- Thời gian chạy: < 10ms/test, toàn bộ suite < 2 phút

Integration Tests (20%):
- Scope: 2+ modules tích hợp, real DB/service trong test env
- Target: Service + Repository, API handlers + middleware, message queue
- Framework gợi ý: Supertest (API), TestContainers (DB)
- Thời gian chạy: < 2s/test

E2E Tests (10%):
- Scope: Full user journey, production-like environment
- Target: Critical happy paths và top 3 failure scenarios
- Framework gợi ý: Playwright, Cypress
- Thời gian chạy: < 60s/test, toàn bộ suite < 30 phút

ANTI-PATTERN cần tránh: Ice cream cone (nhiều E2E, ít Unit)
→ dẫn đến test suite chậm, flaky, khó debug, chi phí bảo trì cao
```

### Bước 5: Risk-Based Prioritization

Sử dụng ma trận Probability × Impact từ test-strategy-patterns.md:

```
Với mỗi module/feature trong scope:

1. Đánh giá Probability of Failure:
   - Cao: Logic phức tạp, nhiều dependencies, code mới hoàn toàn
   - Trung: Moderate complexity, có một phần code hiện có
   - Thấp: Simple CRUD, code đã stable lâu

2. Đánh giá Business Impact nếu fail:
   - Cao: Payment, auth, data integrity, core workflow
   - Trung: Reporting, notifications, secondary features
   - Thấp: UI cosmetics, non-critical helpers

3. Phân loại:
   P0 CRITICAL → Test đầu tiên, block release nếu fail
   P1 HIGH     → Test trong sprint, cần pass trước merge
   P2 MEDIUM   → Test trước release, có thể defer nếu low-risk
   P3 LOW      → Test khi có thời gian, document nếu skip
```

### Bước 6: Test Environment Strategy

```
□ Environments cần có:
  - development: Dev local + shared dev server
  - staging: Mirror production (cùng infrastructure, dữ liệu ẩn danh)
  - production: Smoke test sau deployment

□ Isolation rules:
  - Unit test: không cần external services (mock all)
  - Integration test: database riêng, reset sau mỗi test suite
  - E2E: staging environment, không dùng production data

□ Environment parity checklist:
  - Cùng OS, runtime version với production
  - Cùng environment variables (không hardcode)
  - Feature flags phản ánh đúng production config

WHY: Environment inconsistency là nguyên nhân hàng đầu của "works on my machine" bugs.
```

### Bước 7: Test Data Strategy

```
□ Data generation:
  - Unit test: Fixtures/factories inline trong test file
  - Integration test: Seeded database, reset sau mỗi suite
  - E2E: Dedicated test accounts, synthetic data

□ Data sensitivity:
  - KHÔNG dùng production data thật
  - PII phải được anonymize/fake (Faker.js, Factory Boy)
  - Dữ liệu tài chính phải dùng số giả

□ Data cleanup:
  - Mỗi test phải dọn dẹp data sau khi chạy
  - Không để test phụ thuộc vào order (test isolation)
```

### Bước 8: Automation Strategy

```
□ Automation tiers:
  - PHẢI automate: Unit tests (100%), Integration tests (90%), Smoke tests (100%)
  - NÊN automate: E2E critical paths, Regression suite
  - Manual exploratory: Edge cases mới, UX assessment, domain logic phức tạp

□ CI/CD integration:
  - Pre-commit: Unit tests (< 30s)
  - Pull Request: Unit + Integration (< 10 phút)
  - Merge to main: Full suite bao gồm E2E (< 30 phút)
  - Nightly: Regression + Performance (không giới hạn thời gian)

□ Flaky test policy:
  - Flaky test rate target: < 2%
  - Nếu test flaky > 3 lần → quarantine và fix trong 1 sprint
  - Không merge khi test flaky chưa được resolve

WHY: Automation strategy phải khả thi với team size hiện tại —
đừng promise 100% automation khi team chỉ có 1 QA.
```

### Bước 9: Defect Management Process

```
□ Defect lifecycle:
  New → Assigned → In Progress → Fixed → Retest → Closed

□ SLA theo severity:
  Critical (P0): Report ngay, fix trong 4h, retest trong 2h
  High (P1):     Fix trong 1 ngày, retest trong 4h
  Medium (P2):   Fix trong sprint hiện tại
  Low (P3):      Backlog, fix khi có capacity

□ Escalation rules:
  - P0 bug mở quá 4h → escalate đến Tech Lead + PM
  - Defect density tăng >20% qua 3 sprint → báo cáo architect review
  - Escaped defect rate >5% → trigger retrospective ngay

□ Bug report format: Theo template trong test-strategy-patterns.md (Section 7)
```

### Bước 10: Entry / Exit Criteria

```
ENTRY CRITERIA (điều kiện bắt đầu test):
□ Code complete cho tất cả features trong scope
□ Unit tests đã pass 100% trên CI
□ Test environment sẵn sàng và verified
□ Test data được chuẩn bị
□ REQ-ID traceability matrix được tạo

EXIT CRITERIA (điều kiện hoàn thành testing):
□ Test pass rate >= target (mặc định 95%)
□ Code coverage >= target (mặc định 80%)
□ Không có P0 và P1 bug mở
□ Performance SLA passed
□ Security scan: không có Critical/High vulnerabilities
□ Test summary report được approve bởi stakeholders
```

### Bước 11: KPIs và Reporting

```
Metrics phải track theo sprint:
□ Test Pass Rate: (Pass / Total) × 100% — target >95%
□ Code Coverage: Lines/Branch/Mutation coverage — target >80%
□ Defect Density: Bugs / KLOC — target <5 bugs/KLOC
□ Escaped Defect Rate: Prod bugs / Total bugs — target <5%
□ MTTR (P0): Thời gian fix P0 bug — target <4h
□ Flaky Test Rate: Flaky / Total — target <2%
□ Test Execution Time: CI suite time — target <10 phút

Reporting cadence:
- Daily: Defect triage status (trong sprint)
- Per Sprint: Sprint quality dashboard
- Per Release: Release readiness report
```

### Bước 12: Ghi output

```
Ghi vào: .mc-data/docs/phase5-implementation/test-strategy.md

Cấu trúc document:
1. Executive Summary (scope + quality goals)
2. Test Scope (in/out)
3. Test Pyramid allocation (số lượng ước tính mỗi tầng)
4. Risk Matrix (P0/P1/P2/P3 per module)
5. Environment Strategy
6. Test Data Strategy
7. Automation Roadmap
8. Defect Management Process
9. Entry / Exit Criteria
10. KPI Targets & Dashboard
11. Team Assignments (qa-lead + agents được huy động)
```

---

## Checklist trước khi submit

```
□ Quality goals có số liệu cụ thể (không dùng "cao" hay "tốt")
□ Risk matrix cover tất cả modules trong req-registry.json
□ Test pyramid tỉ lệ 70/20/10 được maintain
□ Entry/exit criteria rõ ràng, đo lường được
□ Automation strategy khả thi với team size thực tế
□ Defect SLA được xác định cho từng severity level
□ KPI targets đồng bộ với qa-templates.md Section 7
```
