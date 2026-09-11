# Template: Task Checklist

> **Purpose:** Template dùng khi tạo task-level checklist cho các tasks phức tạp.
> **Copy this file** → rename → populate.

---

## Task: {{TASK_ID}} — {{TASK_NAME}}

**Phase:** {{PHASE_LETTER}}
**Priority:** CRITICAL / HIGH / MEDIUM / LOW
**Duration estimate:** {{HOURS}}
**Status:** ⬜ Pending / 🟡 In Progress / ✅ Completed / ❌ Failed

---

## Context

- **Dependencies:** {{LIST}}
- **Blocks:** {{LIST}} (tasks depend on this)
- **Design ref:** [{{DOC}}]({{PATH}})

---

## Pre-Task

- [ ] Read task description trong phase plan
- [ ] Read design doc sections listed
- [ ] Verify prerequisites met
- [ ] Branch clean, working tree OK

---

## Actions

### Step 1: {{STEP_NAME}}

```bash
# command
```

**Expected output:**
```
...
```

**Issues to watch:**
- ...

### Step 2: {{STEP_NAME}}

...

---

## Verify

### Automated Checks

```bash
# Test 1
<command> && echo "✓ PASS" || echo "❌ FAIL"

# Test 2
<command>
```

### Manual Review

- [ ] {{CHECK_1}}
- [ ] {{CHECK_2}}

---

## Acceptance Criteria

- [ ] {{CRITERION_1}}
- [ ] {{CRITERION_2}}
- [ ] All verify checks PASS
- [ ] No regression vs previous baseline
- [ ] Session log updated

---

## Rollback (if fail)

```bash
# Revert changes
```

**Recovery steps:**
1. ...
2. ...

---

## Commit Message Template

```
Phase {{X}} {{TASK_ID}}: {{SHORT_DESC}}

- {{DETAIL_1}}
- {{DETAIL_2}}

Verify: {{COMMAND}} — PASS
Refs: {{ADR}}, {{DOC_SECTION}}
```

---

## Notes / Issues

{{ANY_NOTES}}
