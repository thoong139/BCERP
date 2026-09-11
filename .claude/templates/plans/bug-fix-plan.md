# Bug Fix Plan: [BUG-ID] [Short Description]

> Developer-internal planning template for bug fixes.
> Fill before starting. Tách biệt khỏi `doc-framework/`.

---

## 1. Bug Context

| Field | Value |
|-------|-------|
| **BUG-ID** | `[BUG-ID]` |
| **REQ-ID affected** | `[REQ-DEPT-NNN]` |
| **Severity** | Critical / High / Medium / Low |
| **Phase** | [where discovered: phase5 / cross-phase / post-deploy] |
| **Skill** | wf-fix-bugs |
| **Date** | [YYYY-MM-DD] |
| **Reporter** | [agent/user] |

---

## 2. Bug Description

### Symptom
[What is happening — observable behavior]

### Expected Behavior
[What should happen per spec / REQ-ID]

### Reproduction Steps
```
1.
2.
3.
```

### Environment
- [ ] All environments
- [ ] Dev only
- [ ] Staging only
- [ ] Production only

---

## 3. Root Cause Analysis

### Hypothesis
[Initial theory about cause]

### Investigation Files
```
[file.ts]:[line] — [why suspicious]
[file2.ts]:[line] — [why suspicious]
```

### Root Cause (confirmed)
[Fill after investigation]

### Why It Wasn't Caught
- [ ] No test coverage for this path
- [ ] Test existed but didn't catch edge case
- [ ] Regression from [change]
- [ ] Other: ___________

---

## 4. Fix Plan

### Approach
[One-paragraph description of the fix strategy]

### Files to Modify
```
[file.ts]   — [what changes]
```

### Test Plan
- [ ] Reproduce bug with failing test FIRST (TDD)
- [ ] Apply fix
- [ ] Confirm test passes
- [ ] Run full regression suite
- [ ] Check no new failures introduced

---

## 5. REQ-ID Traceability

Fix must reference REQ-ID in commit message:
```
fix: [short description] (REQ-[DEPT]-[NNN])
```

---

## 6. Done Criteria

- [ ] Root cause identified and documented
- [ ] Failing test written first (TDD)
- [ ] Fix applied
- [ ] All tests pass
- [ ] No regression in related areas
- [ ] Registry updated nếu cần
- [ ] Preflight report updated: `wf-preflight` passes

---

## 7. Status

`[ ] DONE` `[ ] DONE_WITH_CONCERNS` `[ ] BLOCKED` `[ ] NEEDS_CONTEXT`

Concerns (nếu có): _____________
