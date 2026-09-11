# Stage F Prompt — Probe Execution Integration + Agent Wiring

## Context

Stage E hoàn tất (PASS). Orchestrator integration + lane dispatch đã build thành công:
- 4 modules mới: profile_resolver, dimension_registry, lane_dispatch, signal_aggregator
- 2 modules update: workload_estimator (DIMENSION_WEIGHTS), isg_recommender (recommend_dimensions)
- wf-fix-bugs SKILL.md bumped → v6.0.0-alpha với --engine, --dims, --profile flags
- 33/33 E2E tests pass, 413/413 total tests (0 regression)
- CI đã cover tất cả files mới

Giờ wire Agent tool vào lane_dispatch để probes thực sự chạy SENSE→THINK→ACT→VERIFY, kết nối scan_cache cho cache-hitting, và chạy full E2E với golden fixture.

---

## Stage F: Probe Execution Integration + Agent Wiring

### Mục tiêu

Biến lane_dispatch từ "framework code" thành "production-ready probe execution engine":

1. **Probe executor** — Đọc probe .md → gọi Agent tool với đúng subagent_type
2. **Cache integration** — Wire scan_cache vào lane_dispatch cho non-QD3 probes
3. **Signal emission** — Probe executor emit Signal v2 qua SignalBus
4. **Golden fixture E2E** — Chạy full v6 flow với 11 known issues across 7 dimensions
5. **--engine=v6 dry-run** — Verify full orchestrator flow end-to-end

### Key Constraints

1. **ADR-22 Rule 6**: QD3 probes KHÔNG BAO GIỜ gọi cache_store/fingerprint
2. **ADR-09**: Mỗi Signal phải có ≥1 evidence field non-empty
3. **CORE-025**: Mỗi lane writes lanes/{DIM}/ riêng — không write conflict
4. **CORE-027**: CDG probes (cdg=true trong dimension.json) cần user confirmation
5. **CORE-029**: Agent output spot-check trước khi ghi signals

---

## F1: Probe Executor Module

Tạo `_shared/probe_executor.py` (~300 LOC).

### Purpose

Đọc probe .md file → extract SENSE/THINK/ACT/VERIFY steps → emit Signal v2.

### Logic

```python
def execute_probe(
    probe_config_path: Path,
    dimension: str,
    lane: str,
    session_dir: Path,
    workflow_root: Path,
    project_root: Path,
) -> dict[str, Any]:
    """Đọc probe .md → execute → return Signal v2 dict.

    Returns:
        Signal v2 dict (để ingest vào SignalBus).

    Raises:
        FileNotFoundError: probe config không tồn tại.
        ValueError: probe output không pass validation.
    """
```

### Behavior

1. Read probe .md file
2. Extract metadata: probe_id, probe_version, tool kind, depth
3. Determine execution path by tool.kind:
   - "grep+jq" → run grep/glob/search tools → parse output → build signal
   - "bash+jq" → run bash command → parse output → build signal
   - "bash+curl" → run HTTP request → parse response → build signal
   - "agent" → delegate to Agent tool with correct subagent_type
4. Build Signal v2 dict with evidence (ADR-09)
5. Return signal dict

### Test cases

- execute_probe cho grep+jq probe → signal with code_snippet evidence
- execute_probe cho agent probe → calls Agent with correct subagent_type
- execute_probe cho missing probe → raises FileNotFoundError
- execute_probe output passes Signal.from_dict validation

---

## F2: Cache Integration in Lane Dispatch

Update `_shared/lane_dispatch.py` để wire scan_cache.

### Changes

1. Import `scan_cache.fingerprint` + `scan_cache.cache_lookup` + `scan_cache.cache_store`
2. In `_execute_lane_sequential`, before each probe:
   - If `cache_allowed AND use_cache`:
     - Compute fingerprint via `fingerprint.compute()`
     - Lookup via `cache_lookup.lookup()`
     - If cache hit → skip probe, use cached signals
     - If cache miss → execute probe, store result via `cache_store.store()`
   - If NOT cache_allowed (QD3) → skip all cache calls

### Test cases

- QD3 lane with use_cache=True → NO cache_store/fingerprint calls
- QD1 lane with use_cache=True → cache_lookup called, cache_store called on miss
- QD1 lane with use_cache=False → no cache calls
- Cache hit → probe skipped, cached signals returned

---

## F3: Signal Emission in Probe Executor

Ensure mỗi probe executor emit valid Signal v2.

### Validation

1. Every signal has `probe_id` matching `^P-QD[1-7]-[a-z0-9-]+$`
2. Every signal has `dimension_hint` matching valid dimensions
3. Every signal has ≥1 evidence field non-empty (ADR-09)
4. Every signal has `description` ≥10 chars
5. CDG probes emit signal with `cdg_required` flag

### Test cases

- Signal emission passes `Signal.from_dict()` validation
- Signal emission passes `validate_evidence()` check
- CDG probe (e.g., P-QD3-secret-detection) → signal flagged for CDG

---

## F4: Golden Fixture Full E2E

Create `_shared/tests/fixtures/golden-v6/` with test data.

### Fixture

```
tests/fixtures/golden-v6/
├── src/
│   ├── auth.ts          # Security issues (QD3)
│   ├── orders.ts        # Business logic issues (QD2)
│   ├── dashboard.tsx    # UX/A11y issues (QD5)
│   └── db-migration.sql # Data issues (QD6)
└── expected-signals.json  # 11 expected signals
```

### Test cases

1. `test_golden_fixture_dispatch` — dispatch all 7 dims → 7 signals.json created
2. `test_golden_fixture_aggregation` — aggregate → issue-registry with expected issues
3. `test_golden_fixture_qd3_cache_never` — QD3 never cached
4. `test_golden_fixture_cdg_flags` — CDG probes flagged correctly
5. `test_golden_fixture_backward_compat` — --engine=v5 still works

---

## F5: v6 Dry-Run End-to-End

### Test scenario

```
/wf-fix-bugs --engine=v6 --dims=QD1,QD3 --profile=quick --dry-run --scope=module --name=AUTH
```

### Expected flow

1. PRE-GATE pass (registry exists)
2. E1: Parse dims → [QD1, QD3]
3. E2: Workload Estimator → gate not triggered
4. E3: Profile Resolver → QD1: 3 probes, QD3: 3 probes
5. E4: Lane Dispatch → 2 lanes executed (dry-run: probes emit preview signals)
6. E5: Signal Aggregation → issue-registry.json
7. Triage → preview triage
8. Execute → dry-run Phase 6 preview
9. Report → fix-report.md with PREVIEW status

### Test cases

- Dry-run flag propagates correctly through v6 path
- No code changes made during dry-run
- Preview report generated with all expected sections

---

## Execution Order

```
F1 (probe_executor.py)       ← independent
F2 (cache integration)       ← depends on F1
F3 (signal emission)         ← depends on F1
F4 (golden fixture E2E)      ← depends on F1-F3
F5 (v6 dry-run E2E)          ← depends on F4
```

---

## Acceptance Criteria

| # | Criteria | Target |
|---|----------|--------|
| 1 | Probe executor chạy grep+jq probes | ≥3 probe types supported |
| 2 | Cache integration cho non-QD3 | QD3 never cached, others cached when --use-cache |
| 3 | All signals pass Signal.from_dict() validation | 100% valid signals |
| 4 | Golden fixture E2E pass | 11 issues detected across ≥4 dimensions |
| 5 | --engine=v5 backward compat | Existing 380 tests still pass |
| 6 | --engine=v6 --dry-run | Preview report generated, no code changes |
| 7 | CDG probes flagged | P-QD3-secret-detection → cdg_required |
| 8 | Full test suite pass | 413 existing + ~25 new = ~438 total |
| 9 | ADR-22 Rule 6 enforced | QD3 cache_policy=never in all test paths |
