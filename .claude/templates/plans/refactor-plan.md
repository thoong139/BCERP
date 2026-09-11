# Refactor Plan: [Short Description]

> Developer-internal planning template for refactoring.
> Fill before starting. Tách biệt khỏi `doc-framework/`.
> Rule: Refactor KHÔNG thay đổi observable behavior — chỉ cải thiện internal structure.

---

## 1. Refactor Context

| Field | Value |
|-------|-------|
| **Scope** | [module/file/component being refactored] |
| **REQ-ID affected** | `[REQ-DEPT-NNN]` (nếu có) |
| **Motivation** | Technical debt / Performance / Readability / Modularity |
| **Phase** | [current phase] |
| **Date** | [YYYY-MM-DD] |
| **Developer** | [agent/developer] |

---

## 2. Current State

### Problem
[What is wrong with current implementation — specific, not vague]

### Evidence
```
[file.ts]:[line] — [specific problem: e.g., "function 350 lines, 4 responsibilities"]
[file2.ts]:[line] — [specific problem]
```

### Impact
- [ ] Performance bottleneck
- [ ] Difficult to test
- [ ] High coupling
- [ ] Code duplication (N occurrences)
- [ ] Exceeds 200-line modularization threshold
- [ ] Other: ___________

---

## 3. Target State

### Design
[Describe desired end state — module structure, responsibilities, interfaces]

```
Before:                          After:
[old-file.ts]  (350 lines)  →   [new-file-a.ts] (80 lines)
                                 [new-file-b.ts] (90 lines)
                                 [new-file-c.ts] (70 lines)
```

### Constraints
- Observable behavior PHẢI giữ nguyên
- Public API/interfaces: `[ ] unchanged` `[ ] must change (requires coordination)`
- Database schema: `[ ] unchanged` `[ ] changes (migration required)`

---

## 4. Migration Steps

### Step 1: Test coverage TRƯỚC khi refactor
- [ ] Current test coverage: ____%
- [ ] Target coverage before refactor: ≥ 80%
- [ ] Add tests for uncovered paths

### Step 2: Refactor
- [ ] [Specific step]
- [ ] [Specific step]

### Step 3: Verify
- [ ] All existing tests still pass
- [ ] No new test failures
- [ ] Performance benchmarks unchanged (nếu có)

---

## 5. Rollback Plan

If refactor introduces regression:
```bash
git revert [commit-sha]
# OR
git checkout [pre-refactor-branch] -- [files]
```

---

## 6. Done Criteria

- [ ] Test coverage ≥ 80% before AND after
- [ ] All existing tests pass
- [ ] No observable behavior change
- [ ] Code size/complexity reduced as planned
- [ ] REQ-ID comments preserved in refactored code
- [ ] No new `TODO` / `FIXME` introduced

---

## 7. Status

`[ ] DONE` `[ ] DONE_WITH_CONCERNS` `[ ] BLOCKED` `[ ] NEEDS_CONTEXT`

Concerns (nếu có): _____________
