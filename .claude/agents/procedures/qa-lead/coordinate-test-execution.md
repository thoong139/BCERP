# Playbook: Điều phối Test Execution

> **Type**: Agent Skill Playbook
> **Agent**: qa-lead
> **Triggered by**: Sprint testing phase — cần điều phối testing team và track progress
> **Output**: `.mc-data/work/wf-implement-feature/sprint-test-summary.md`

---

## Khi nào dùng playbook này

- Được gọi khi sprint bước vào testing phase
- Khi `/wf-implement-feature` cần coordinate testing cho multiple features
- Khi cần track testing progress và escalate blocking issues
- Khi cần tổng hợp kết quả từ nhiều QA agents để báo cáo

---

## Procedure

### Bước 1: Load Sprint Test Scope

```
INPUT: Sprint info do skill cung cấp qua prompt
FALLBACK: tra .mc-data/docs/phase5-implementation/ → P5-00-implementation-roadmap.md

Cần xác định:
□ Sprint number và timeline
□ Features trong scope của sprint này
□ REQ-IDs cần verify trong sprint
□ Test cases đã được viết (từ write-test-cases.md output)
□ Test strategy hiện tại (từ plan-test-strategy.md output)

Nếu test cases chưa có:
→ Invoke write-test-cases.md trước khi bắt đầu coordinate
```

Load knowledge cần thiết:
```
READ: .claude/references/team-expert/testing/qa-templates.md (Section 1, 3)
READ: .claude/references/team-expert/testing/test-strategy-patterns.md (Section 6)
```

### Bước 2: Phân công Test Areas cho QA Agents

Dựa trên đặc tính của từng area, assign đúng agent:

```
PHÂN CÔNG THEO CHUYÊN MÔN:

code-reviewer:
□ Code quality review trước khi QA testing
□ Static analysis, code smells, SOLID violations
□ Technical debt assessment

api-tester:
□ API endpoints testing (REST/GraphQL)
□ Request/response schema validation
□ Authentication & authorization scenarios
□ Rate limiting và error handling
□ Contract testing

accessibility-auditor (khi có UI):
□ WCAG 2.1 AA compliance
□ Screen reader compatibility
□ Keyboard navigation
□ Color contrast

performance-benchmarker (khi có performance SLAs):
□ Load testing theo scenarios trong load-testing-examples.md
□ Response time measurement
□ Throughput benchmarking
□ Bottleneck identification

qa-lead (giữ lại):
□ Functional test cases (positive, negative, boundary)
□ Integration test scenarios phức tạp
□ Business logic validation
□ E2E critical paths
□ Coordination và synthesis

WHY: Phân công theo chuyên môn không phải để "phân chia công việc"
mà để đảm bảo mỗi area được đánh giá đúng bởi người có
deep knowledge — api-tester biết contract testing tốt hơn
qa-lead có thể thực hiện manually.
```

### Bước 3: Thiết lập Test Execution Tracking

```
Tạo tracking board cho sprint:

| TC-ID | Feature | Type | Assigned | Status | Result | Bug IDs |
|-------|---------|------|----------|--------|--------|---------|
| TC-001 | [Feat] | Unit | developer | Done | Pass | - |
| TC-002 | [Feat] | API | api-tester | In Progress | - | - |
| TC-003 | [Feat] | E2E | qa-lead | Todo | - | - |

Status values:
- Todo: Chưa bắt đầu
- In Progress: Đang thực hiện
- Blocked: Bị chặn bởi issue khác
- Done: Hoàn thành
- Skipped: Bỏ qua có lý do

Update tracking sau mỗi execution session.
```

### Bước 4: Huy động agents và monitor progress

```
Spawn agents với context đầy đủ:

Khi invoke code-reviewer:
  → Cung cấp: file paths cần review, REQ-IDs, coding standards
  → Expect output: code review findings với severity

Khi invoke api-tester:
  → Cung cấp: API spec path, endpoint list, auth config
  → Expect output: API test results với pass/fail per endpoint

Khi invoke accessibility-auditor:
  → Cung cấp: UI component paths, target WCAG level
  → Expect output: A11y issues list với severity

Khi invoke performance-benchmarker:
  → Cung cấp: SLA targets, load profile, test environment URL
  → Expect output: Benchmark results vs targets

Monitoring checkpoints (trong sprint):
□ 25% sprint: Mọi P0/P1 tests đã start chưa?
□ 50% sprint: Kết quả từ agents đầu tiên về chưa?
□ 75% sprint: Tất cả P0/P1 đã done, P0 bugs có fix plan chưa?
□ End of sprint: Toàn bộ TC done hoặc skipped với lý do
```

### Bước 5: Daily Defect Triage

Thực hiện mỗi ngày trong sprint testing phase:

```
□ Review mọi bug mới được report từ hôm qua
□ Verify severity/priority assignment
□ Assign đến đúng developer
□ Check SLA compliance:
  - P0: Phải start fix trong 4h từ lúc report
  - P1: Phải start fix trong 1 ngày
  - P2/P3: Đưa vào sprint backlog
□ Remove duplicate bugs (merge với existing)
□ Verify environment (bug có reproduce được trên staging không?)

Triage output:
- Updated bug list với assignments
- SLA violation warnings (nếu có)
- Escalation items (nếu P0 chưa được fix đúng SLA)
```

### Bước 6: Escalation Decisions

```
Khi nào escalate lên Tech Lead:
□ P0 bug open > 4h không có update
□ Bug không reproduce được (cần developer pair)
□ Architecture-level issue phát hiện qua testing
□ Defect density tăng >20% so với sprint trước
□ Test coverage không đạt 70% sau 75% sprint

Khi nào escalate lên PM/Product:
□ Business requirement ambiguous → test case không viết được
□ Acceptance criteria mâu thuẫn nhau
□ Scope change phát sinh trong sprint
□ P2 bug có business impact đáng kể

Khi nào block merge:
□ Bất kỳ P0/P1 bug chưa fix
□ Unit test coverage < 60% (hard block, không ngoại lệ)
□ Security scan có Critical/High finding
□ Flaky test rate > 5% trong test run cuối

Escalation format:
[ESCALATION] Sprint [N] - [Issue Type]
- Issue: [Mô tả ngắn]
- Impact: [Ảnh hưởng gì]
- Data: [Metrics/evidence]
- Request: [Cần gì từ người được escalate]
- Deadline: [Khi nào cần phản hồi]
```

### Bước 7: Retest Verification

```
Khi developer report bug đã fix:

□ Verify fix trên đúng environment (staging, không phải local)
□ Run test case gốc gây ra bug
□ Run regression tests quanh area bị fix (5-10 related TCs)
□ Kiểm tra fix không introduce regression

Retest pass criteria:
- Original bug không còn reproduce
- Không có mới regression
- Code coverage không giảm

Retest fail criteria:
- Bug vẫn còn → reopen với updated description
- Regression tìm thấy → mở bug mới với link đến original
- Partial fix → note rõ phần nào còn lại
```

### Bước 8: Blocking Issue Management

```
Blocked test case là TC không thể thực hiện vì:
- Environment không available
- Dependency feature chưa implement
- Test data không thể tạo
- Build bị broken

Với mỗi blocked TC:
□ Document lý do blocked và ngày blocked
□ Assign blocking issue cho owner (Dev/DevOps/PM)
□ Set follow-up date
□ Assess impact lên sprint timeline

Unblock process:
□ Notify qa-lead ngay khi block được resolve
□ Prioritize blocked TCs ngay sau unblock
□ Update sprint timeline estimate nếu cần

Khi không thể unblock trong sprint:
□ Mark TC là "Skipped - Environment Issue" hoặc "Deferred"
□ Document trong sprint summary
□ Carry forward sang sprint sau
```

### Bước 9: Sprint Quality Dashboard Update

```
Cập nhật dashboard metrics mỗi ngày hoặc sau mỗi execution session:

SPRINT QUALITY DASHBOARD - Sprint [N]
Date: [Ngày cập nhật]

Test Execution:
□ Total TCs: [N]
□ Done: [N] ([%])
□ Passing: [N] ([%])
□ Failing: [N] ([%])
□ Blocked: [N] ([%])
□ Skipped: [N] ([%])

Defect Status:
□ New this session: [N]
□ Open P0: [N] ← CRITICAL nếu > 0
□ Open P1: [N]
□ Open P2: [N]
□ Fixed/Closed: [N]

Coverage (từ CI):
□ Statement: [%] / target [%]
□ Branch: [%] / target [%]

Velocity vs Plan:
□ TCs planned today: [N]
□ TCs actual: [N]
□ Sprint completion: [%]
□ On track for exit criteria: [Yes/No]

Risks:
□ [Risk 1 nếu có]
□ [Risk 2 nếu có]
```

### Bước 10: Tổng hợp Sprint Test Summary

Thực hiện cuối sprint, sau khi tất cả TC đã run hoặc được dispositioned:

```
Thu thập từ tất cả agents:
□ code-reviewer → code quality findings
□ api-tester → API test results
□ accessibility-auditor → a11y findings (nếu có UI)
□ performance-benchmarker → benchmark results (nếu có)

Tổng hợp:
□ Tổng số TC executed
□ Final pass rate
□ Bug summary (per severity)
□ Coverage final
□ Blocked/deferred TCs với lý do
□ Lessons learned cho sprint sau

Đưa ra assessment:
□ Các features đã meet acceptance criteria chưa?
□ Ready for release readiness assessment chưa?
□ Issues cần carry forward sang sprint sau?
```

### Bước 11: Ghi output

```
Ghi vào: .mc-data/work/wf-implement-feature/sprint-test-summary.md

Cấu trúc report:
1. Sprint Overview (số, timeline, features in scope)
2. Test Execution Summary (table với tất cả metrics)
3. Defect Summary (per severity, open vs closed)
4. Coverage Report
5. Agent Reports Summary (code-reviewer, api-tester, etc.)
6. Blocked/Deferred Items
7. Known Issues (P2/P3 accepted)
8. Sprint Assessment (features ready / not ready)
9. Carry-forward Items cho sprint sau
10. Lessons Learned

Nếu ready cho release:
→ Trigger assess-release-readiness.md
```

---

## Checklist trước khi submit Sprint Summary

```
□ Mọi TC được dispositioned (Pass / Fail / Blocked / Skipped với lý do)
□ Mọi P0/P1 bug đã closed hoặc có escalation record
□ Kết quả từ tất cả agents đã được thu thập và tổng hợp
□ Coverage metrics có số cụ thể từ CI (không ước tính)
□ Carry-forward items được link sang sprint backlog
□ Lessons learned thực tế, actionable (không phải "cần cải thiện")
□ Assessment rõ ràng: features nào ready, features nào không
```
