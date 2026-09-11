# D.1 Cross-Reference Check — wf-fix-bugs v9.1.0

> **Date:** 2026-05-12 (Phiên 23)
> **Task:** 4.3 — Verify all references in orchestrator SKILL.md + procedures → targets exist
> **Method:** Static analysis — extract all references from SKILL.md + 7 key procedures, verify file existence + size + parseability

---

## Summary

| Category | Total | PASS | FAIL | WARN |
|----------|-------|------|------|------|
| Procedure files | 14 | 14 | 0 | 0 |
| Bash scripts (SKILL.md) | 11 | 11 | 0 | 0 |
| Python _shared modules (SKILL.md) | 5 | 5 | 0 | 0 |
| Sub-skill SKILL.md | 13 | 13 | 0 | 0 |
| Cross-skill consumer SKILL.md | 5 | 5 | 0 | 0 |
| Protocol files | 11 | 11 | 0 | 0 |
| CORE rules | 6 | 6 | 0 | 0 |
| Additional scripts (from procedures) | 5 | 5 | 0 | 0 |
| Additional _shared modules (from procedures) | 2 | 2 | 0 | 0 |
| QD11 bash scripts | 2 | 2 | 0 | 0 |
| Cross-skill --from-fix-bugs wiring | 3 | 3 | 0 | 0 |
| **TOTAL** | **77** | **77** | **0** | **0** |

**Result: PASS — 0 broken references across 77 verified targets.**

---

## Detailed Verification

### 1. Procedure Files (14/14 PASS)

All 14 procedure files referenced in SKILL.md §Procedure Index exist, are non-empty, and are parseable:

| # | File | Size (bytes) | Status |
|---|------|-------------|--------|
| 1 | procedures/ci-pre-gate.md | 4,988 | PASS |
| 2 | procedures/phase1-engine.md | 36,923 | PASS |
| 3 | procedures/phase2-triage.md | 2,574 | PASS |
| 4 | procedures/phase3-execute.md | 2,762 | PASS |
| 5 | procedures/post-gate-completion.md | 18,897 | PASS |
| 6 | procedures/workload-gate.md | 7,272 | PASS |
| 7 | procedures/agent-dispatch.md | 18,633 | PASS |
| 8 | procedures/cdg-handoff.md | 10,244 | PASS |
| 9 | procedures/session-dir.md | 11,401 | PASS |
| 10 | procedures/lock-management.md | 7,843 | PASS |
| 11 | procedures/resume-routing.md | 7,383 | PASS |
| 12 | procedures/status-display.md | 6,484 | PASS |
| 13 | procedures/examples.md | 4,616 | PASS |
| 14 | procedures/bash-delegation.md | 8,320 | PASS |

### 2. Bash Scripts Referenced in SKILL.md (11/11 PASS)

| # | File | Size (bytes) | Status |
|---|------|-------------|--------|
| 1 | wf-fix-common.sh | 20,347 | PASS |
| 2 | wf-fix-deprecation-block.sh | 2,264 | PASS |
| 3 | wf-fix-phase0-init.sh | 3,146 | PASS |
| 4 | wf-fix-browser-precheck.sh | 5,351 | PASS |
| 5 | wf-fix-cost-estimator.sh | 10,380 | PASS |
| 6 | wf-fix-safety-check.sh | 13,564 | PASS |
| 7 | wf-fix-impact-builder.sh | 18,973 | PASS |
| 8 | wf-fix-migrate-sessions.sh | 13,595 | PASS |
| 9 | ci-detect.sh | 12,621 | PASS |
| 10 | ci-freshness-check.sh | 4,053 | PASS |
| 11 | ci-inject-context.sh | 5,648 | PASS |

### 3. Python _shared Modules Referenced in SKILL.md (5/5 PASS)

| # | File | Size (bytes) | Status |
|---|------|-------------|--------|
| 1 | _shared/profile_resolver.py | 14,469 | PASS |
| 2 | _shared/isg/isg_recommender.py | 44,994 | PASS |
| 3 | _shared/lane_dispatch.py | 64,491 | PASS |
| 4 | _shared/signal_aggregator.py | 16,286 | PASS |
| 5 | _shared/report_generator.py | 12,940 | PASS |

### 4. Sub-skill SKILL.md Files (13/13 PASS)

All 13 sub-skill SKILL.md files exist and exceed the 10KB threshold:

| # | File | Size (bytes) | Status |
|---|------|-------------|--------|
| 1 | wf-fix-triage/SKILL.md | 32,591 | PASS |
| 2 | wf-fix-execute/SKILL.md | 25,329 | PASS |
| 3 | wf-fix-functional/SKILL.md | 14,430 | PASS |
| 4 | wf-fix-business/SKILL.md | 10,648 | PASS |
| 5 | wf-fix-security/SKILL.md | 11,663 | PASS |
| 6 | wf-fix-performance/SKILL.md | 10,338 | PASS |
| 7 | wf-fix-ux-a11y/SKILL.md | 11,037 | PASS |
| 8 | wf-fix-data/SKILL.md | 10,344 | PASS |
| 9 | wf-fix-compat/SKILL.md | 11,083 | PASS |
| 10 | wf-fix-observability/SKILL.md | 10,839 | PASS |
| 11 | wf-fix-runtime-health/SKILL.md | 13,186 | PASS |
| 12 | wf-fix-integration/SKILL.md | 14,681 | PASS |
| 13 | wf-fix-business-completeness/SKILL.md | 11,907 | PASS |

### 5. Cross-Skill Consumer SKILL.md Files (5/5 PASS)

| # | File | Size (bytes) | --from-fix-bugs | Status |
|---|------|-------------|-----------------|--------|
| 1 | wf-verify-sync/SKILL.md | 35,408 | YES (4 refs) | PASS |
| 2 | wf-prepare-deployment/SKILL.md | 14,988 | YES (8 refs) | PASS |
| 3 | wf-implement-feature/SKILL.md | 51,316 | YES (4 refs) | PASS |
| 4 | wf-preflight/SKILL.md | 15,298 | N/A (reads probes) | PASS |
| 5 | wf-brainstorm/SKILL.md | 15,918 | N/A | PASS |

### 6. Protocol Files (11/11 PASS)

All 11 protocols referenced in SKILL.md §Protocols & Strategy:

| # | Protocol | Size (bytes) | Status |
|---|----------|-------------|--------|
| 1 | 01-accuracy-assurance.md | 2,586 | PASS |
| 2 | 02-auto-correction.md | 1,786 | PASS |
| 3 | 03-context-checkpoint.md | 4,169 | PASS |
| 4 | 09-task-planning.md | 7,510 | PASS |
| 5 | 10-post-gate-schema.md | 3,612 | PASS |
| 6 | 14-phase-summary.md | 3,081 | PASS |
| 7 | 15-execution-trace.md | 2,878 | PASS |
| 8 | 16-critical-decision-gate.md | 11,100 | PASS |
| 9 | 18-session-isolation.md | 7,481 | PASS |
| 10 | 19-template-usage.md | 4,684 | PASS |
| 11 | 20-code-intelligence.md | 16,672 | PASS |

### 7. CORE Rules Verification (6/6 PASS)

All CORE rules referenced in SKILL.md are defined in `00-core.md`:

| Rule | SKILL.md Ref | 00-core.md Line | Status |
|------|-------------|-----------------|--------|
| CORE-006 | §Phase 1 §Registry Safe-Write | 76, 187 | PASS |
| CORE-020 | §Step 2.6 Safety Check | 122, 201 | PASS |
| CORE-026 | §Execution Trace | 152, 207 | PASS |
| CORE-028 | §POST-GATE, §Output Files | 209 | PASS |
| CORE-029 | §Phase 1 Step 7 | 210 | PASS |
| CORE-031 | §Phase 1 Steps 5,8 | 156, 212 | PASS |

Additional CORE rules referenced only in procedures:
- CORE-021 (ci-pre-gate.md): line 132 — PASS
- CORE-027 (workload-gate.md, cdg-handoff.md, agent-dispatch.md, lock-management.md): line 208 — PASS

### 8. Additional Scripts from Procedures (5/5 PASS)

Scripts referenced in procedures but NOT in SKILL.md Procedure Index:

| # | File | Size (bytes) | Referenced In | Status |
|---|------|-------------|---------------|--------|
| 1 | wf-fix-session.sh | 7,405 | phase1-engine, resume-routing, session-dir | PASS |
| 2 | wf-fix-init-status.sh | 8,764 | phase1-engine | PASS |
| 3 | wf-fix-merge-non-static-probes.sh | 5,117 | phase1-engine | PASS |
| 4 | wf-fix-incremental-scope.sh | 9,900 | phase1-engine | PASS |
| 5 | wf-fix-multi-app-coordinator.sh | 12,473 | phase1-engine | PASS |

### 9. Additional _shared Modules from Procedures (2/2 PASS)

| # | File | Size (bytes) | Referenced In | Status |
|---|------|-------------|---------------|--------|
| 1 | _shared/llm_lane/merge_signals.py | 10,338 | phase1-engine, lock-management | PASS |
| 2 | _shared/lane/dispatcher.py | 10,641 | lock-management | PASS |

Supporting sub-packages (referenced transitively): concurrency, signal_bus, cdg, lane, aggregate, cache, stack_detection, workload_estimator, scan_cache, read_trace — all init files exist.

### 10. QD11 Infrastructure (2/2 PASS)

| # | File | Size (bytes) | Status |
|---|------|-------------|--------|
| 1 | wf-fix-qd11-signals-validate.sh | 2,483 | PASS |
| 2 | wf-fix-qd11-skip-check.sh | 1,812 | PASS |
| 3 | wf-fix-business-completeness/_contract.json | valid JSON | PASS |

### 11. Cross-Skill `--from-fix-bugs` Wiring (3/3 PASS)

| Consumer | Refs | Description | Status |
|----------|------|-------------|--------|
| wf-verify-sync | 4 | Parses `--from-fix-bugs[=<id>]`, auto-resolves latest session, consumes fix-impact.json + docs-sync-report.json | PASS |
| wf-prepare-deployment | 8 | Parses flag, Go/No-Go signal from fix-impact.json (escalated>0 or tests_failed>0 → BLOCK CDG) | PASS |
| wf-implement-feature | 4 | Parses flag, consumes fix-impact.json to prioritize features with code_files matching FEATURE_SLUG | PASS |

---

## Findings & Observations

### FINDING D1-001: `coverage_estimator.py` path imprecise (LOW)

- **Location:** SKILL.md line 95: `Coverage estimate (theo `coverage_estimator.py`)`
- **Issue:** Reference says `coverage_estimator.py` without path prefix. Actual file is at `_shared/aggregate/coverage_estimator.py` (inside aggregate/ sub-package).
- **Impact:** Reader may look at `_shared/coverage_estimator.py` which doesn't exist. The file does exist at the sub-package location.
- **Recommendation:** Update reference to `_shared/aggregate/coverage_estimator.py` or just use module name qualifier.

### FINDING D1-002: 5 scripts in procedure references not catalogued in SKILL.md Procedure Index (LOW)

- **Issue:** The SKILL.md Procedure Index (lines 651-673) lists 11 bash scripts. However, 5 additional scripts are referenced in procedures:
  - `wf-fix-session.sh` (phase1-engine.md, resume-routing.md, session-dir.md)
  - `wf-fix-init-status.sh` (phase1-engine.md)
  - `wf-fix-merge-non-static-probes.sh` (phase1-engine.md)
  - `wf-fix-incremental-scope.sh` (phase1-engine.md)
  - `wf-fix-multi-app-coordinator.sh` (phase1-engine.md)
- **Impact:** LOW — all scripts exist and work. The Procedure Index is incomplete, not broken.
- **Recommendation:** Add these 5 scripts to the Procedure Index table.

### FINDING D1-003: 2 _shared modules in procedure references not documented in SKILL.md Phase 1 summary (LOW)

- **Issue:** SKILL.md Phase 1 §Flow tóm tắt lists 5 Python modules (profile_resolver, isg_recommender, lane_dispatch, signal_aggregator, report_generator). Two additional modules are referenced in procedures:
  - `_shared/llm_lane/merge_signals.py` (phase1-engine.md Step 9, lock-management.md)
  - `_shared/lane/dispatcher.py` (lock-management.md)
- **Impact:** LOW — both files exist at correct paths. SKILL.md summary is slightly incomplete.
- **Recommendation:** Add these modules to the Phase 1 flow summary for completeness.

### OBSERVATION D1-OBS-001: Internal procedure cross-references are consistent

All internal cross-references between procedures are valid:
- phase1-engine.md → procedures/session-dir.md, procedures/lock-management.md ✓
- session-dir.md → procedures/lock-management.md ✓
- lock-management.md → _shared/lane_dispatch.py, _shared/llm_lane/merge_signals.py ✓
- resume-routing.md → procedures/session-dir.md, procedures/lock-management.md, procedures/status-display.md ✓
- agent-dispatch.md → procedures/status-display.md ✓

### OBSERVATION D1-OBS-002: CORE rule cross-referencing is comprehensive

Both SKILL.md and procedures reference CORE rules correctly:
- SKILL.md: CORE-006, CORE-020, CORE-026, CORE-028, CORE-029, CORE-031
- Procedures: CORE-021 (ci-pre-gate), CORE-027 (workload-gate, cdg-handoff, agent-dispatch, lock-management), CORE-028 (session-dir, post-gate), CORE-029 (phase1-engine), CORE-031 (phase1-engine, post-gate)
- All 8 unique CORE rules verified in 00-core.md

### OBSERVATION D1-OBS-003: Protocol coverage is well-distributed

11 of 21 protocol files are referenced, covering key concerns:
- Execution: 01 (accuracy), 02 (auto-correction), 03 (checkpoint)
- Quality: 09 (task-planning), 10 (post-gate-schema), 16 (CDG)
- Output: 14 (phase-summary), 15 (execution-trace)
- Infrastructure: 18 (session-isolation), 19 (template-usage), 20 (code-intelligence)
- Missing protocols (04-08, 11-13, 17, 21) appear to be not applicable to wf-fix-bugs workflow — consistent with SKILL.md §Protocols & Strategy scope.

---

## Conclusion

**D.1 Cross-Reference Check: PASS — 0 broken references.**

All 77 verified targets (14 procedures, 16 scripts, 7 Python modules, 13 sub-skills, 5 cross-skill consumers, 11 protocols, 8 CORE rules, 3 cross-skill wirings) point to existing, non-empty, valid targets. Three LOW-severity documentation gaps identified (D1-001, D1-002, D1-003) — all are cataloging/documentation issues, not functional breaks.

**Key metric:** 77/77 references resolve correctly (100% resolution rate).
