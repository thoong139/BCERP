# Feature Implementation Plan: [FEAT-ID] [Feature Name]

> Developer-internal planning template. Tách biệt khỏi `doc-framework/` (user-facing).
> Điền vào trước khi bắt đầu implement.

---

## 1. Feature Context

| Field | Value |
|-------|-------|
| **REQ-ID** | `[REQ-DEPT-NNN]` |
| **FEAT-ID** | `[FEAT-ID]` |
| **Phase** | phase5-implementation |
| **Skill** | wf-implement-feature |
| **Date** | [YYYY-MM-DD] |
| **Developer** | [agent/developer] |

---

## 2. Spec References

- Feature spec: `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md`
- Implementation task: `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
- Architecture ref: `.mc-data/docs/phase3-architecture/P3-01-architecture.md`
- Registry: `.mc-data/docs/_meta/req-registry.json`

---

## 3. Scope

### Files to Create
```
src/[module]/[file].ts
src/[module]/[file].test.ts
```

### Files to Modify
```
src/[module]/[existing-file].ts   — [what changes]
```

### Files NOT touched
```
[list files explicitly out of scope]
```

---

## 4. Dependencies

| Dependency | Type | Status |
|------------|------|--------|
| [FEAT-X] | prerequisite | ✅ done / ⏳ pending |
| [Service Y] | external | ✅ available |

---

## 5. Implementation Steps

### Step 1: [Name]
- [ ] [Subtask 1]
- [ ] [Subtask 2]

### Step 2: [Name]
- [ ] [Subtask 1]

### Step 3: Tests
- [ ] Unit tests for [component]
- [ ] Integration test for [flow]
- [ ] Coverage ≥ 80% for new code

---

## 6. REQ-ID Traceability

Every code file must include REQ-ID comment:
```typescript
// REQ-[DEPT]-[NNN]: [Brief description of requirement]
```

---

## 7. Done Criteria

- [ ] All implementation steps complete
- [ ] Tests pass (unit + integration)
- [ ] Coverage ≥ 80% cho code mới
- [ ] REQ-ID comments present in all files
- [ ] Registry updated: `impl_status = "done"` for [FEAT-ID]
- [ ] No `TODO` / `FIXME` / placeholder left in code
- [ ] POST-GATE: `wf-preflight` passes

---

## 8. Status

`[ ] DONE` `[ ] DONE_WITH_CONCERNS` `[ ] BLOCKED` `[ ] NEEDS_CONTEXT`

Concerns (nếu có): _____________
