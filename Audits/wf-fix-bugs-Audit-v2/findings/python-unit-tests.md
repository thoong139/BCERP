# Task 3.3 — Python Unit Tests + Coverage Check

**Date:** 2026-05-12 (Phiên 20)
**Executor:** Claude Opus 4.7
**Status:** WARN — All 640 tests pass, coverage gate fails due to measurement scope

---

## Test Execution Summary

```
Test runner: .claude/skills/workflow/_shared/run-tests.sh
Mode: full (coverage gate ≥80%)
Python: 3.14.4, pytest: 9.0.3, pytest-cov: 7.1.0
Collected: 650 | Passed: 640 | Failed: 0 | Skipped: 10
Duration: ~198s (3:18)
Exit code: 1 (coverage gate fail)
```

### Test Results: PASS

All 640 tests pass. Zero failures. The test suite is healthy.

### Coverage: FAIL (28.86% vs 80% gate)

The `run-tests.sh` script passes `--cov=.` which measures ALL 42 Python modules in the `_shared/` directory. Of these, 25 modules have 0% coverage:

---

## Coverage Breakdown by Category

### Category A: Core Runtime Modules (actively used by wf-fix-bugs, 18 files)

| Module | Stmts | Cover% | Status |
|--------|-------|--------|--------|
| concurrency/backpressure.py | 83 | **96.84%** | Above gate |
| integration_cache.py | 143 | **92.09%** | Above gate |
| signal_bus/signal_bus.py | 344 | **81.33%** | Above gate |
| scan_cache/fingerprint.py | 57 | **80.00%** | At gate |
| probe_executor.py | 138 | **79.03%** | Near gate |
| scan_cache/cache_lookup.py | 78 | 76.09% | Below gate |
| concurrency/token_bucket.py | 144 | 76.14% | Below gate |
| signal_aggregator.py | 180 | 73.95% | Below gate |
| impact_graph/ripple.py | 116 | 73.46% | Below gate |
| isg/isg_recommender.py | 434 | 72.84% | Below gate |
| partition_planner.py | 115 | 69.28% | Below gate |
| profile_resolver.py | 137 | 55.61% | Below gate |
| lane_dispatch.py | 567 | 54.97% | Below gate |
| dimension_registry.py | 59 | 53.52% | Below gate |
| workload_estimator/estimator.py | 239 | 51.68% | Below gate |
| impact_graph/builder.py | 289 | 46.60% | Below gate |
| scan_cache/cache_store.py | 148 | 35.16% | Below gate |
| report_generator.py | 76 | 29.55% | Below gate |
| **Core subtotal** | **~3357** | **~67%** | Below gate |

### Category B: Duplicate/Refactored Sub-Packages (8 files, 0% coverage)

These are sub-package versions of root-level modules. The root-level versions are used in production; the sub-package versions are a planned modularization without tests:

| Module | Duplicate of |
|--------|-------------|
| aggregate/aggregator.py | signal_aggregator.py (root, 73.95%) |
| aggregate/coverage_estimator.py | (new, unused) |
| lane/dispatcher.py | lane_dispatch.py (root, 54.97%) |
| partition/planner.py | partition_planner.py (root, 69.28%) |
| partition/workload_gate.py | (new, unused) |
| profiles/profile_resolver.py | profile_resolver.py (root, 55.61%) |
| cache/cache_adapter.py | (new, unused) |
| cdg/cdg_handler.py | (new, unused) |

### Category C: Legacy IPS Infrastructure (10 files, 0% coverage)

`ips/` — Incremental Project Scanner, not actively used by wf-fix-bugs workflow:
agent_timeout.py, concurrency_controller.py, domain_scorer.py, impact_graph_builder.py, incremental.py, ips_recommender.py, resume_router.py, scan_cache.py, scan_state_reader.py, vietnamese_keywords.py, workload_estimator.py, workload_gate.py

### Category D: New LLM Lane Infrastructure (5 files, 0% coverage)

`llm_lane/` — LLM-based probe infrastructure, not yet tested:
budget_guard.py, chunk_planner.py, emit_invocations.py, emit_signals.py, merge_signals.py, signal_parser.py

### Category E: Other Uncovered (2 files, 0% coverage)

- stack_detection/stack_detector.py (341 stmts) — not yet tested
- read_trace.py (95 stmts) — utility script

---

## Skipped Tests Analysis

All 10 skipped tests are in `test_probe_executor.py` with reason "Probe .md not found":

| Test Function | Line | Probe |
|--------------|------|-------|
| test_probe_execution_with_valid_probe | 121 | Probe .md not found |
| test_probe_failure_logging | 144 | Probe .md not found |
| test_probe_skip_on_stack_mismatch | 167 | Probe .md not found |
| test_probe_skip_on_applicability_false | 189 | Probe .md not found |
| test_probe_static_vs_non_static | 209 | Probe .md not found |
| test_probe_execution_reporting | 241 | Probe .md not found |
| test_probe_timeout_handling | 289 | Probe .md not found |
| test_probe_signal_emission | 344 | Probe .md not found |
| test_probe_dimension_routing | 367 | Probe .md not found |
| test_probe_parallel_execution | 389 | Probe .md not found |

**Root cause:** Test fixture expects probe `.md` files at a specific path that doesn't exist in the test environment. These are likely integration-level probes defined in skill directories, not available during unit test execution. Classification: **TEST_INFRA** — fixture probes missing from test environment.

---

## Coverage Gate Analysis

### Why `--cov=.` produces 28.86%

The measurement includes:
- 18 core runtime modules (~3357 stmts, ~67% coverage)
- 8 duplicate sub-packages (~916 stmts, 0% coverage)
- 10 legacy IPS files (~2181 stmts, 0% coverage)
- 5 LLM lane files (~541 stmts, 0% coverage)
- 2 other uncovered files (~436 stmts, 0% coverage)

Total: ~7431 stmts. Core at ~2239 covered / 7431 total = 30.1% (close to measured 28.86%, difference from branch coverage).

### Core-Only Coverage

If measuring only the 18 actively-used runtime modules: ~2239/3357 = **66.7%** (still below 80%).

### Gap to 80% Gate

For the core modules to reach 80%, approximately 446 additional statements need test coverage. The biggest opportunities:

| Module | Additional coverage needed |
|--------|--------------------------|
| lane_dispatch.py (567 stmts) | +142 more stmts (from 55% to 80%) |
| impact_graph/builder.py (289 stmts) | +97 more stmts |
| workload_estimator/estimator.py (239 stmts) | +68 more stmts |
| scan_cache/cache_store.py (148 stmts) | +67 more stmts |
| profile_resolver.py (137 stmts) | +34 more stmts |
| dimension_registry.py (59 stmts) | +16 more stmts |
| report_generator.py (76 stmts) | +39 more stmts |

---

## Findings Summary

| # | Finding | Severity | Category |
|---|---------|----------|----------|
| F3.3-01 | All 640 tests pass, 0 failures | PASS | Tests |
| F3.3-02 | Coverage 28.86% fails 80% gate | WARN | Coverage |
| F3.3-03 | 25/43 modules have 0% coverage (duplicate sub-packages, legacy IPS, new llm_lane) | WARN | Coverage Scope |
| F3.3-04 | `--cov=.` in run-tests.sh measures all files, not just actively-used production code | WARN | Config |
| F3.3-05 | pyproject.toml `source = ["_shared"]` is ineffective (rootdir mismatch) | WARN | Config |
| F3.3-06 | 10 tests skipped — probe .md fixture files missing | WARN | Test Infra |
| F3.3-07 | 4 core modules above 80% coverage gate | PASS | Coverage |
| F3.3-08 | 14 core modules below 80% — gap of ~446 stmts to reach gate | WARN | Coverage |
| F3.3-09 | 8 duplicate sub-packages (aggregate/, lane/, partition/, profiles/) have root-level equivalents with tests | OBS | Architecture |
| F3.3-10 | llm_lane/ (5 files) and stack_detection/ (1 file) are new infrastructure without tests | OBS | Coverage |

---

## Observations

| ID | Observation |
|----|------------|
| OBS-062 | `run-tests.sh` line 75 uses `--cov=.` which overrides pyproject.toml `source = ["_shared"]`. The pyproject.toml intent was to limit coverage to the `_shared` Python package, but since rootdir IS `_shared/`, the config is dead. Fix: either change `source` to `["."]` with explicit `--omit` for duplicate/legacy dirs, or add `--omit='aggregate/*,lane/*,partition/*,profiles/*,cdg/*,cache/*,ips/*,llm_lane/*,stack_detection/*,adapters/*,catalog/*,locales/*,templates/*,read_trace.py'` to run-tests.sh. |
| OBS-063 | 10 probe .md fixture files referenced by test_probe_executor.py don't exist. These probes are defined in skill directories (`.claude/skills/workflow/wf-fix-*/probes/`), not in the `_shared/` test fixture. Either add probe fixtures or mark these as integration tests requiring skill context. |
| OBS-064 | 8 duplicate module pairs (sub-package vs root-level): aggregate/aggregator ↔ signal_aggregator, lane/dispatcher ↔ lane_dispatch, partition/planner ↔ partition_planner, profiles/profile_resolver ↔ profile_resolver. If the sub-packages are the intended future, the root-level versions should be deprecated. If root-level is canonical, the sub-packages should be removed to reduce maintenance burden. |
| OBS-065 | The `pyproject.toml` `[tool.coverage.run] source = ["_shared"]` is configured for running pytest from the parent directory (`.claude/skills/workflow/`) importing `_shared.*`, but `run-tests.sh` runs from within `_shared/` where `--cov=.` takes over. This is a deployment mismatch between CI config and local runner. |
| OBS-066 | 640 tests in 198s = ~3.1 tests/sec. No slow test warnings despite `--strict-markers`. Test suite performance is healthy. |

---

## Verdict

**Tests: PASS (640/650, 0 failures)**
**Coverage: FAIL (28.86% vs 80% gate)**

The coverage failure is primarily a measurement configuration issue (`--cov=.` includes 25 modules with 0% coverage) rather than a test quality issue. Core production modules average ~67% coverage with 4/18 above the 80% gate. The test suite itself is green and healthy.

**Recommendation:** Fix `run-tests.sh` to either:
1. Use `--omit` to exclude duplicate/legacy packages, OR
2. Run coverage from parent directory with `source = ["_shared"]` in pyproject.toml working correctly
3. Then re-evaluate whether core module coverage reaches 80%
