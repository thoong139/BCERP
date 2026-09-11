# QD11 Implementation Plan — Business Completeness & Enhancement

**Created:** 2026-05-11
**Status:** Waiting for implementation in next session

## Summary
QD11 is a NEW dimension lane for `wf-fix-bugs` that detects MISSING business logic (not just broken logic) via 3-pass LLM analysis:
1. Cross-Module Pattern Comparison (auto, HIGH confidence)
2. Domain Heuristic Analysis (auto, MEDIUM confidence)
3. Business Rule Gap Detection (registry-based, HIGHEST confidence)

## Architecture Decision
**Approach B (new QD11 lane)** chosen over Approach A (expand QD2) because:
- Fundamentally different questions (correctness vs completeness)
- Different severity models and CDG gates
- Zero regression risk to existing QD1-QD10

## Implementation Plan
**Location:** `plans/wf-fix-bugs-qd11-implementation/qd11-implementation-plan.md`
**Estimate:** 8-12 hours, 6 sprints
**11 new files to CREATE, 10 existing files to MODIFY**

## Audit Checklist
- audit-checklist.md updated: C1.10 (10 new checkpoints), P1: 64→74, Total: 87→97
- audit-prompt.md updated: A.14 (QD11 static audit, 7 sub-checks), C.10-C.12 (3 runtime scenarios)
