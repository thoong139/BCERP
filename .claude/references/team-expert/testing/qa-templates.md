# Testing - QA Templates & Frameworks

> **Domain**: Testing / Kiểm thử phần mềm
> **Last Updated**: 2026-03-15

---

## 1. Test Plan Template

```markdown
# Test Plan: [Feature/System]

## Overview
- System Under Test: [Name]
- Test Period: [Start - End]
- Test Lead: [Name]

## Scope
### In Scope
- Feature 1
- Feature 2

### Out of Scope
- Feature X

## Test Strategy
| Test Type | Approach | Coverage |
|-----------|----------|----------|
| Unit | Automated | 80% |
| Integration | Automated | 60% |
| E2E | Manual/Automated | Critical flows |
| Performance | Automated | Load testing |
| Security | Manual | OWASP Top 10 |

## Test Cases
| ID | Description | Priority | Status |
|----|-------------|----------|--------|
| TC-001 | | | |

## Entry Criteria
- [ ] Code complete
- [ ] Unit tests passing
- [ ] Environment ready

## Exit Criteria
- [ ] All P0/P1 cases passed
- [ ] No critical bugs open
- [ ] Performance benchmarks met
```

---

## 2. Bug Report Template

```markdown
# Bug Report

## Summary
[Brief description]

## Details
- **Severity**: Critical/High/Medium/Low
- **Priority**: P0/P1/P2/P3
- **Environment**: Dev/Staging/Prod
- **REQ-ID**: [Related requirement]

## Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

## Expected Result
[What should happen]

## Actual Result
[What actually happened]

## Evidence
- Screenshot:
- Logs:

## Impact
[Business impact]
```

---

## 3. Test Summary Report Template

```markdown
# Test Summary Report

## Executive Summary
[Brief overview of testing results]

## Test Execution
| Metric | Value |
|--------|-------|
| Total Test Cases | |
| Passed | |
| Failed | |
| Blocked | |
| Not Run | |
| Pass Rate | |

## Bug Summary
| Severity | Count | Open | Fixed |
|----------|-------|------|-------|
| Critical | | | |
| High | | | |
| Medium | | | |
| Low | | | |

## Risk Assessment
| Risk | Impact | Mitigation |
|------|--------|------------|
| | | |

## Recommendation
- [ ] Go/No-Go decision
- [ ] Conditions for release
```

---

## 4. Test Pyramid — Tỉ lệ khuyến nghị

| Tầng | Tỉ lệ | Tốc độ | Chi phí |
|------|--------|--------|---------|
| Unit tests | 70% | Nhanh nhất | Thấp nhất |
| Integration tests | 20% | Trung bình | Trung bình |
| E2E tests | 10% | Chậm nhất | Cao nhất |

---

## 5. Test Types Checklist

### Functional Testing
- [ ] Positive test cases
- [ ] Negative test cases
- [ ] Edge cases
- [ ] Boundary testing

### Non-Functional Testing
- [ ] Performance testing
- [ ] Load testing
- [ ] Security testing
- [ ] Usability testing

### Regression Testing
- [ ] Smoke tests
- [ ] Critical path tests
- [ ] Integration tests

---

## 6. Quality Metrics — Targets

| Metric | Formula | Target |
|--------|---------|--------|
| Defect Density | Bugs / KLOC | <1 per KLOC |
| Test Coverage | Lines covered / Total lines | >80% |
| Test Pass Rate | Passed / Total | >95% |
| Bug Reopen Rate | Reopened / Total fixed | <5% |
| Bug Escape Rate | Prod bugs / Total bugs | <5% |

---

## 7. Release Readiness Scoring

| Component | Weight | Threshold |
|-----------|--------|-----------|
| Pass rate | 30% | ≥95% |
| Coverage | 25% | ≥80% |
| Defect density | 20% | <1/KLOC |
| Performance SLA | 15% | 100% met |
| Security compliance | 10% | 0 critical |
| **GO threshold** | | **≥80/100** |

---

## 8. Quality Cost Multiplier

| Giai đoạn phát hiện bug | Chi phí tương đối |
|--------------------------|-------------------|
| Unit test | 1x |
| Integration test | 5x |
| QA testing | 10x |
| Production | 50-100x |
