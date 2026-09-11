<!-- Template: impl-report.md — Báo cáo kết quả sau khi triển khai một feature -->
<!-- Ai viết: AI tự động generate khi hoàn thành Phase 6 của /wf-implement-feature -->

# Implementation Report: [Feature Name]

**Generated:** YYYY-MM-DD HH:mm:ss
**Implementation ID:** IMPL-YYYYMMDD-NNN
**REQ-ID:** REQ-XXX-NNN

---

## Executive Summary

| Mục | Giá trị |
|-----|---------|
| **Feature** | [Feature Name] |
| **Module** | [Module Name] |
| **Scenario** | NEW / EXTEND / MODIFY |
| **Complexity** | Simple / Medium / Complex |
| **Status** | ✅ COMPLETED / ❌ FAILED |
| **Sessions** | X sessions |
| **Duration** | Xm Ys |

---

## Progress Overview

```
Phase 0: Existing Code Analysis  [✅/⏭️ SKIP]  100%
Phase 1: Feature Context         [✅]           100%
Phase 2: Planning                [✅]           100%
Phase 3: TDD Implementation      [✅]           100%
  ├─ Batch 1: Entity + Repository [✅]
  ├─ Batch 2: Service             [✅]
  └─ Batch 3: Controller + API    [✅]
Phase 4: Parallel Reviews        [✅]           100%
Phase 5: Issue Resolution        [✅]           100%
Phase 6: Update Status           [✅]           100%
```

---

## Files Created/Modified

### Created Files

| File | Type | Lines | REQ-IDs |
|------|------|-------|---------|
| `src/modules/[module]/entities/[Entity].ts` | Entity | XX | REQ-XXX-NNN |
| `src/modules/[module]/repositories/[Repo].ts` | Repository | XX | REQ-XXX-NNN |
| `src/modules/[module]/services/[Service].ts` | Service | XX | REQ-XXX-NNN |
| `src/modules/[module]/controllers/[Controller].ts` | Controller | XX | REQ-XXX-NNN |
| `tests/modules/[module]/[Entity].test.ts` | Test | XX | REQ-XXX-NNN |

### Modified Files (EXTEND/MODIFY only)

| File | Changes | Lines ± |
|------|---------|---------|
| `path/to/modified/file.ts` | [Description] | +XX -YY |

---

## Quality Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| **Files Created** | X | — | ✅ |
| **Files Modified** | X | — | ✅ |
| **Tests Passing** | X/X | 100% | ✅ |
| **Test Coverage** | XX% | ≥80% | ✅/⚠️ |
| **Lines Added** | XXX | — | — |
| **Lines Removed** | XXX | — | — |

---

## Review Results

### Code Review

| Severity | Count | Resolved |
|----------|-------|----------|
| CRITICAL | 0 | ✅ |
| HIGH | 0 | ✅ |
| MEDIUM | 0 | ✅ |
| LOW | 0 | ✅ |

**Summary:** [Brief summary of code review findings]

### Security Review

| Severity | Count | Resolved |
|----------|-------|----------|
| CRITICAL | 0 | ✅ |
| HIGH | 0 | ✅ |
| MEDIUM | 0 | ✅ |
| LOW | 0 | ✅ |

**Security Checks:**
- [x] Input validation
- [x] Authentication/Authorization
- [x] SQL injection prevention
- [x] XSS prevention
- [x] No hardcoded secrets
- [x] Error handling

**Summary:** [Brief summary of security review findings]

---

## TDD Summary

| Batch | Entity/Service | Test Written | Test Pass | Refactored |
|-------|----------------|--------------|-----------|------------|
| 1 | [Entity Name] | ✅ | ✅ | ✅ |
| 2 | [Service Name] | ✅ | ✅ | ✅ |
| 3 | [Controller Name] | ✅ | ✅ | ✅ |

---

## Checkpoints History

| Session | Checkpoint | Phase | Context | Action |
|---------|------------|-------|---------|--------|
| 1 | CP-001 | 2 | 78% | Planning complete |
| 2 | CP-002 | 3.1 | 82% | Batch 1 complete |
| 2 | CP-003 | 3.2 | 85% | Batch 2 complete |

---

## Requirements Coverage

| REQ-ID | Description | Status | Files |
|--------|-------------|--------|-------|
| REQ-XXX-001 | [Description] | ✅ DONE | [file1.ts], [file2.ts] |
| REQ-XXX-002 | [Description] | ✅ DONE | [file3.ts] |

---

## Issues & Resolutions

| # | Phase | Issue | Resolution | Status |
|---|-------|-------|------------|--------|
| 1 | 3.1 | [Issue description] | [How resolved] | ✅ Resolved |
| 2 | 4 | [Issue description] | [How resolved] | ✅ Resolved |

---

## Existing Code Analysis (EXTEND/MODIFY only)

### Patterns Identified

| Pattern | Location | Applied |
|---------|----------|---------|
| [Pattern 1] | [File] | ✅ |
| [Pattern 2] | [File] | ✅ |

### Impact Analysis

| Affected File | Impact Type | Tested |
|---------------|-------------|--------|
| [File 1] | Modified | ✅ |
| [File 2] | Dependency | ✅ |

---

## Next Steps

1. ✅ Implementation complete
2. 👉 **Recommended:** Run `/wf-verify-sync` to verify full project sync
3. 👉 **Optional:** Run integration tests if applicable
4. 👉 **Optional:** Update API documentation if endpoints changed

---

## For Downstream Skills (v4.0 Sprint 3)

Implementation này produce machine-readable hints trong `impl-status.json.consumer_hints` (schema v2.0). Các consumer skills có thể đọc qua flag `--from-impl=[FEATURE_SLUG]` để skip re-scan và focus scope.

### `/wf-prepare-deployment --from-impl=[FEATURE_SLUG]`
- **Files for CHANGELOG:** xem `consumer_hints["wf-prepare-deployment"].files_for_changelog` (exclude test/spec files)
- **Breaking changes:** xem `consumer_hints["wf-prepare-deployment"].breaking_changes` (decision IDs)
- **Migrations required:** xem `consumer_hints["wf-prepare-deployment"].migrations_required` (boolean)
- **Feature summary (vi):** xem `consumer_hints["wf-prepare-deployment"].feature_summary_vi`

### `/wf-fix-bugs --from-impl=[FEATURE_SLUG]`
- **Scope:** giới hạn vào module(s) trong `consumer_hints["wf-fix-bugs"].scope_modules`
- **Test files added:** `consumer_hints["wf-fix-bugs"].test_files_added` (priority targets cho regression)
- **New decisions:** `consumer_hints["wf-fix-bugs"].decision_ids_new` — append vào `decision-registry.global.json`
- **Implementation strategy:** `consumer_hints["wf-fix-bugs"].implementation_strategy_used` (IMPLEMENT_NEW / COMPLETE_EXISTING / VERIFY_ONLY)

### `/wf-verify-sync --from-impl=[FEATURE_SLUG]`
- **REQ-IDs completed:** `consumer_hints["wf-verify-sync"].req_ids_completed`
- **Files with REQ-ID comment:** `consumer_hints["wf-verify-sync"].files_with_req_id` (count)
- **Session dir:** `consumer_hints["wf-verify-sync"].session_dir` (artifacts location)

> **Note (Q1 LOCKED v4.0):** 3 consumer skills này chưa modify trong v4.0. Output có sẵn — consumer skills sẽ tự đọc khi roadmap v5.0 add `--from-impl` flag.

### Architectural decisions (cross-feature)

Decisions có scope `project` hoặc `module:*` đã được APPEND vào `.mc-data/docs/_meta/decision-registry.global.json` qua Phase 3.5. Future implementations sẽ tự động consume các decisions này ở Phase 0.5b.

---

## Appendix: Error Log

```
[If any errors occurred during implementation]
```

---

*Report auto-generated by DEVKIT `/wf-implement-feature`*
