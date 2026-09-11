# Playbook: Đánh giá Release Readiness

> **Type**: Agent Skill Playbook
> **Agent**: qa-lead
> **Triggered by**: Trước mỗi release — cần đưa ra Go/No-Go decision dựa trên data
> **Output**: `.mc-data/work/wf-implement-feature/release-readiness-[version].md`

---

## Khi nào dùng playbook này

- Được gọi trước mỗi production release (major, minor, hotfix)
- Khi skill `/wf-prepare-deployment` yêu cầu QA sign-off
- Khi PM/Tech Lead yêu cầu release readiness assessment
- Khi sprint testing phase kết thúc và cần quyết định deploy

---

## Procedure

### Bước 1: Thu thập thông tin release

```
INPUT: Version/release info do skill cung cấp qua prompt
FALLBACK: tra .mc-data/work/wf-implement-feature/ → sprint summary gần nhất

Cần xác định:
□ Version/tag release (ví dụ: v1.2.0)
□ Features included trong release này (từ sprint scope)
□ REQ-IDs được implement trong release
□ Hotfix hay planned release? (ảnh hưởng đến risk tolerance)
□ Target deployment environment
□ Rollback plan có chưa?
```

Load knowledge cần thiết:
```
READ: .claude/references/team-expert/testing/qa-templates.md (Section 3, 7)
READ: .claude/references/team-expert/testing/test-strategy-patterns.md (Section 8)
```

### Bước 2: Tổng hợp Test Execution Results

```
Thu thập kết quả từ tất cả QA agents đã chạy trong sprint:

Từ code-reviewer:
□ Code quality score
□ Security findings
□ Technical debt items

Từ api-tester:
□ API test pass rate
□ Contract violations
□ Schema issues

Từ accessibility-auditor (nếu có UI):
□ WCAG 2.1 AA compliance
□ Critical a11y issues

Từ performance-benchmarker:
□ Load test results
□ Response time vs SLA
□ Throughput vs target

Tổng hợp vào bảng:
| Test Type | Total TCs | Passed | Failed | Blocked | Pass Rate |
|-----------|-----------|--------|--------|---------|-----------|
| Unit      | [N]       | [N]    | [N]    | [N]     | [%]       |
| Integration| [N]      | [N]    | [N]    | [N]     | [%]       |
| E2E       | [N]       | [N]    | [N]    | [N]     | [%]       |
| API       | [N]       | [N]    | [N]    | [N]     | [%]       |
| TOTAL     | [N]       | [N]    | [N]    | [N]     | [%]       |
```

### Bước 3: Phân loại và Triage Defects

Với mọi bug đang open:

```
CRITICAL (P0) — Block release:
□ Data corruption hoặc data loss
□ Security vulnerabilities (Critical/High theo CVSS)
□ Payment/financial calculation sai
□ System crash / availability issue
□ Authentication bypass

HIGH (P1) — Cần plan rõ ràng trước release:
□ Core workflow bị broken
□ Feature không hoạt động theo spec
□ Performance không đạt SLA
□ Data inconsistency

MEDIUM (P2) — Có thể release với known issues:
□ Edge case failures không ảnh hưởng majority users
□ Non-critical feature degraded (workaround có)
□ Performance sub-optimal nhưng acceptable

LOW (P3) — Release OK, fix next sprint:
□ UI/cosmetic issues
□ Nice-to-have improvements
□ Non-blocking UX friction

Decision rule:
- Có BẤT KỲ P0 nào mở → NO-GO bắt buộc
- Có P1 chưa có fix plan → NO-GO hoặc yêu cầu plan
- P2 mở → GO với known issues documented
- P3 mở → GO, log vào backlog
```

### Bước 4: Kiểm tra Test Coverage vs Targets

```
So sánh actual vs target từ test-strategy.md:

| Metric               | Target  | Actual | Status |
|----------------------|---------|--------|--------|
| Statement Coverage   | >80%    | [%]    | [Pass/Fail] |
| Branch Coverage      | >75%    | [%]    | [Pass/Fail] |
| Overall Pass Rate    | >95%    | [%]    | [Pass/Fail] |
| Defect Density       | <5/KLOC | [N]    | [Pass/Fail] |

Nếu coverage dưới target:
□ Identify uncovered modules
□ Assess risk của uncovered code
□ Quyết định: defer release hay accept risk với documentation
```

### Bước 5: Kiểm tra Performance Benchmarks

```
READ: .claude/references/team-expert/testing/load-testing-examples.md (Section 4)

So sánh với Performance SLA defaults:

| Metric          | Target    | Actual | Status |
|-----------------|-----------|--------|--------|
| p95 Response    | <200ms    | [N]ms  | [Pass/Fail] |
| p99 Response    | <500ms    | [N]ms  | [Pass/Fail] |
| Error Rate      | <0.1%     | [%]    | [Pass/Fail] |
| Throughput      | ≥[N] req/s| [N]    | [Pass/Fail] |

Nếu performance fail:
□ Identify bottleneck layer (DB query, application, network)
□ Đánh giá: critical path bị ảnh hưởng không?
□ Hotfix có khả thi không trước release?
```

### Bước 6: Kiểm tra Security Scan Results

```
Security checklist:
□ SAST (Static Analysis): Không có Critical/High findings
□ Dependency scan: Không có known CVE Critical/High trong dependencies
□ Auth/Authorization: Access control tests pass 100%
□ Input validation: Injection tests pass 100%
□ Sensitive data: Không có secrets trong code/logs
□ HTTPS/TLS config đúng (nếu có network layer)

Nếu có security finding:
- Critical/High → NO-GO bắt buộc, KHÔNG release
- Medium → Assess exploitability, document nếu accept risk
- Low → Document và plan fix trong next sprint
```

### Bước 7: Kiểm tra Regression Suite Status

```
□ Regression suite chạy đủ chưa? (phải chạy trên staging)
□ Có test nào fail trong regression không?
□ Có test flaky nào ảnh hưởng đến kết quả không?
□ Features từ sprint trước còn hoạt động đúng không?

Flaky test handling:
- Nếu fail rate của flaky test < 20% → chấp nhận, document
- Nếu fail rate >= 20% → coi như real failure, investigate trước release
```

### Bước 8: Tổng hợp Known Issues & Workarounds

```
Với mỗi P2/P3 bug chấp nhận release cùng:

| Bug ID | Severity | Description | Workaround | Fix Target |
|--------|----------|-------------|------------|------------|
| BUG-XXX | Medium | [Mô tả] | [Workaround nếu có] | Sprint [N] |

Document phải được:
□ Thông báo đến Product Manager
□ Thêm vào release notes
□ Tạo ticket tracking cho fix
```

### Bước 9: Risk Assessment tổng thể

```
Tổng hợp risk profile của release này:

OVERALL RISK LEVEL:
□ LOW: Tất cả metrics pass, không có P0/P1, stable regression
□ MEDIUM: Một số P2 open, coverage slightly below target, performance borderline
□ HIGH: P1 open với workaround, coverage significantly below target
□ CRITICAL: Bất kỳ P0 open → NO-GO

Risk factors cần xem xét:
□ Đây là hotfix? (lower tolerance, higher urgency)
□ Có thay đổi database schema không? (rollback khó hơn)
□ Có integration với third-party mới không?
□ Thời điểm release (peak traffic, business-critical period)
```

### Bước 10: Release Readiness Scoring

```
Áp dụng scoring từ qa-templates.md Section 7:

| Component         | Weight | Score (0-100) | Weighted |
|-------------------|--------|---------------|---------|
| Pass Rate         | 30%    | [N]           | [N×0.3] |
| Coverage          | 25%    | [N]           | [N×0.25]|
| Defect Density    | 20%    | [N]           | [N×0.2] |
| Performance SLA   | 15%    | [N]           | [N×0.15]|
| Security          | 10%    | [N]           | [N×0.1] |
| **TOTAL SCORE**   |        |               | **[N]** |

GO threshold: >= 80/100
- Score >= 80 → GO (nếu không có P0 blocking)
- Score 70-79 → Conditional GO (phải document conditions)
- Score < 70 → NO-GO

WHY: Scoring system ngăn việc release theo cảm tính — mọi quyết định
phải có data support. Kể cả khi score >= 80, P0 bug là hard block.
```

### Bước 11: Stakeholder Sign-off Checklist

```
Trước khi finalize Go/No-Go:

□ Tech Lead đã review và acknowledge risk assessment
□ Product Manager đã approve known issues list
□ DevOps đã confirm rollback procedure sẵn sàng
□ Security team sign-off (nếu có security changes)
□ Documentation/Release notes đã chuẩn bị
□ On-call engineer đã được notify về release window
□ Monitoring alerts đã configured cho production deployment
```

### Bước 12: Go/No-Go Recommendation

```
Cấu trúc quyết định:

RECOMMENDATION: [GO / CONDITIONAL GO / NO-GO]

Lý do:
- [Data point 1 support quyết định]
- [Data point 2]
- [Data point 3]

Conditions (nếu CONDITIONAL GO):
- [Condition 1 phải đáp ứng trước deploy]
- [Condition 2]

Blocking items (nếu NO-GO):
- [BUG-XXX]: [Mô tả ngắn] — phải fix trước release
- [BUG-YYY]: [Mô tả ngắn] — phải fix trước release

Recommended next steps:
- [Hành động 1]
- [Hành động 2]

Expected re-assessment date: [Date nếu NO-GO]

WHY qa-lead KHÔNG claim "zero issues":
Lần implement đầu luôn có issues. Mục tiêu là "known risk được document,
managed, và không có surprises" — không phải "hoàn hảo".
```

### Bước 13: Ghi output

```
Ghi vào: .mc-data/work/wf-implement-feature/release-readiness-[version].md

Cấu trúc report:
1. Executive Summary (version, date, overall: GO/NO-GO)
2. Test Execution Summary (table)
3. Defect Summary (P0/P1/P2/P3 counts)
4. Coverage vs Targets (table)
5. Performance Benchmarks (table)
6. Security Assessment
7. Known Issues & Workarounds
8. Risk Assessment (LOW/MEDIUM/HIGH/CRITICAL)
9. Release Readiness Score ([N]/100)
10. Stakeholder Sign-offs
11. Go/No-Go Recommendation với lý do
```

---

## Checklist trước khi submit

```
□ Mọi metric có số liệu cụ thể (không phỏng đoán)
□ Mọi P0/P1 bug được liệt kê đầy đủ
□ Known issues có workaround hoặc fix target date
□ Release readiness score được tính theo formula
□ Go/No-Go recommendation có data support rõ ràng
□ Stakeholder sign-offs đã được track
□ Rollback plan được xác nhận là sẵn sàng
```
