# Stage L Prompt — Integration Validation: Multi-Workload Scenarios + Fix-Workload Fixtures

## Context

Stage J hoàn tất (PASS). ISG + Partition Planner + v6 Orchestrator Wiring thành công (492 tests, 0 failures).
Stage K hoàn tất (PASS). Tất cả _contract.json files đồng bộ với v6 outputs + `00-core.md §4b` path contract cập nhật.

### Trạng thái kiến trúc sau Stage K

```
_shared/                           ✅ COMPLETE — shared services layer + config
├── signal_bus/                    ✅ Signal Bus (emit, validate, dedup)
├── scan_cache/                    ✅ Scan Cache (fingerprint, TTL, QD3 never cached)
├── probe_executor.py              ✅ Probe execution (grep/agent/runtime → Signal v2)
├── lane_dispatch.py               ✅ Lane dispatch (cache integration, parallel)
├── signal_aggregator.py           ✅ Aggregation v2 (v2 schema fields populated)
├── dimension_registry.py          ✅ Dimension registry (metadata, cache policy)
├── profile_resolver.py            ✅ Profile → probe + dimension resolver
├── report_generator.py            ✅ Lane + coverage report generation từ templates
├── partition_planner.py           ✅ Partition dimensions → workloads
├── read_trace.py                  ✅ Code tracing
├── isg/                           ✅ ISG recommender (core logic)
├── impact_graph/                  ✅ Impact graph builder
├── workload_estimator/            ✅ Workload estimation (core logic)
├── concurrency/                   ✅ Backpressure + token bucket
├── profiles.json                  ✅ Profile config (ADR-21 locked defaults)
├── templates/                     ✅ 3 v6 output templates (CORE-031)
└── tests/                         ✅ 492 tests (463 base + 17 Stage I + 12 Stage J)

Contracts:
├── wf-fix-bugs/_contract.json     ✅ v6 outputs + cross-skill refs (Stage K verified)
├── wf-fix-discover/_contract.json ✅ v6 outputs added (Stage K)
├── wf-fix-triage/_contract.json   ✅ v6 fields verified (Stage K)
├── wf-fix-execute/_contract.json  ✅ v6 fields verified (Stage K)
├── 00-core.md §4b                 ✅ Path contract updated (Stage K)
```

### What's Missing (Gap Analysis)

Stage J tested individual components (partition, aggregator v2, ISG integration).
Stage K synced contracts. Stage L validates **multi-workload integration** end-to-end:

```
GAPS:
1. Chưa có test cho multi-workload scenario (7 dims → 3 workloads → sequential dispatch)
2. Chưa có test cho fix-workload.json fixture generation (partition_planner output → workload JSON)
3. Chưa có test cho v6 dispatch với ISG-recommended dimensions (không chỉ default)
4. Chưa có test verify coverage-report populated từ multi-workload aggregation stats
5. Chưa validate rằng v2 issue-registry schema fields populated đúng khi multiple workloads aggregate
6. Edge case: empty signals in some dimensions (coverage_rate reflects correctly)
7. Edge case: dedup across dimensions (same file+line in QD1+QD3 → should be separate issues)
```

---

## Stage L: Integration Testing — Multi-Workload Scenarios

### Mục tiêu

Tạo comprehensive integration tests cho multi-workload v6 pipeline:

1. Multi-workload dispatch → aggregate → reports chain
2. fix-workload.json fixture generation from partition_planner output
3. ISG-recommended dimension selection → partition → dispatch
4. Coverage report populated from real multi-workload aggregation stats
5. v2 schema field correctness across multi-workload scenarios
6. Edge cases: empty signals, cross-dimension dedup

### Key Constraints

1. **Chỉ thêm tests** — KHÔNG thay đổi source code (.py files)
2. **CORE-007**: Tests phải validate paths match cross-skill contract
3. **CORE-031**: Tests phải verify reports created from templates (no ad-hoc generation)
4. **Không regression**: 492 existing tests phải vẫn pass
5. **ADR-15**: Tests phải cover Plan A (single-run) vs Plan B (multi-run partition)
6. **ADR-19**: QD3 never cached — tests respect this rule

---

## Tasks

### L1: Create test_e2e_stage_l.py — Multi-Workload Integration Tests (CRITICAL)

File: `.claude/skills/workflow/_shared/tests/test_e2e_stage_l.py`

Test classes:

#### TestMultiWorkloadDispatch
- `test_seven_dims_three_workloads_dispatch`: 7 dims, max=3 → 3 workloads → dispatch each → aggregate all → verify
  - Partition: `["QD1","QD2","QD3","QD4","QD5","QD6","QD7"]` with `max_workload_size=3`
  - Assert ≥3 workloads, all dims covered
  - Dispatch each workload separately using `lane_dispatch.dispatch_lanes()`
  - Aggregate using `aggregate_lane_signals()` with full dims list
  - Verify: `stats.dimensions_run == ["QD1","QD2","QD3","QD4","QD5","QD6","QD7"]`
  - Verify: `stats.total_signals >= 0` (may be 0 in test env, that's OK)
  - Verify: `stats.coverage_rate_pct >= 0.0`

- `test_multi_workload_fixtures`: Generate fix-workload.json from partition output
  - Partition dims → workloads
  - For each workload, write `fix-workload.json` to temp session dir
  - Verify each fixture has correct schema: `{ id, dimensions, estimated_probes, estimated_minutes }`

#### TestISGRecommendedDimensions
- `test_isg_recommended_then_dispatch`: ISG recommends dims → resolve → partition → dispatch
  - Use `isg_recommender.recommend_dimensions()` with realistic file paths
  - Take top-N dims based on profile (e.g., standard = top 3)
  - Partition those dims
  - Dispatch → aggregate
  - Verify stats populated correctly

- `test_isg_vs_default_coverage`: Compare ISG-selected vs default-selected dims
  - Standard profile default: `["QD1", "QD2", "QD5"]`
  - ISG recommendation for auth-heavy project: might include QD3
  - Both should dispatch + aggregate without errors

#### TestMultiWorkloadReports
- `test_multi_workload_coverage_report`: 3 workloads → aggregate → coverage report
  - Partition 7 dims into workloads
  - Dispatch + aggregate
  - Generate coverage report using `report_generator.generate_coverage_report()`
  - Verify report exists, no `{{PLACEHOLDER}}` residuals
  - Verify `stats.total_signals` value appears in report

- `test_per_dimension_lane_reports`: Each dimension gets lane report
  - Dispatch dims
  - For each dim, generate lane report
  - Verify each report file exists at `$SESSION_DIR/lanes/QD*/lane-report.md`
  - Verify reports have correct dimension_id populated

#### TestV2SchemaFields
- `test_v2_dimensions_run_matches_input`: After aggregation, `dimensions_run` matches input dims exactly

- `test_v2_coverage_calculation`: Coverage rate calculated correctly
  - If all dims have 0 signals → `coverage_rate_pct == 0.0`
  - If some dims have signals → `coverage_rate_pct > 0.0`
  - Formula: `len(dimensions_with_issues) / len(dimensions_run) * 100`

- `test_v2_dedup_stats`: Dedup stats populated correctly
  - `dedup_ingested == total_signals` (before dedup)
  - `dedup_deduplicated == total_signals - total_issues` (after dedup)

#### TestEdgeCases
- `test_empty_signals_in_some_dims`: Some dims have 0 signals
  - Dispatch 3 dims, but only create signals.json for 2 of them
  - Aggregate → verify `dimensions_without_issues` contains the empty dim
  - Verify `coverage_rate_pct < 100.0`

- `test_single_dim_workload`: 1 dim → 1 workload → dispatch → aggregate
  - Edge case: minimum viable workload
  - Verify stats populated correctly

### L2: Verify multi-workload dispatch creates correct directory structure (HIGH)

Trong test `test_seven_dims_three_workloads_dispatch`:
- Verify `$SESSION_DIR/lanes/QD1/` through `QD7` directories exist after dispatch
- Verify `$SESSION_DIR/lanes/QD*/signals.json` files exist for all dispatched dims
- Verify `$SESSION_DIR/issue-registry.json` exists after aggregation

### L3: Verify fix-workload.json schema matches ADR-14/15 (MEDIUM)

Trong test `test_multi_workload_fixtures`:
- Each `fix-workload.json` must have:
  ```json
  {
    "id": "W01",
    "dimensions": ["QD1", "QD2", "QD5"],
    "estimated_probes": 8,
    "estimated_minutes": 12.0
  }
  ```
- Verify `estimated_probes` = sum of `PROBES_PER_DIM` for included dimensions
- Verify `estimated_minutes` = `estimated_probes * 1.5` (rounded to 1 decimal)

### L4: Final Regression (CRITICAL)

```bash
cd "z:/Working/MCV3/.claude/skills/workflow/_shared"
python -m pytest tests/ --tb=short
```

**Target:** 492 existing + ~15 new = ~507 tests, 0 failures, 0 regression.

---

## File Summary

### Files to CREATE

| File | Mục đích |
|------|----------|
| `_shared/tests/test_e2e_stage_l.py` | Multi-workload integration tests |

### Files KHÔNG thay đổi

| File | Lý do |
|------|-------|
| Tất cả `.py` source files | Stage L chỉ thêm tests |
| `_contract.json` files | Stage K đã sync |
| `00-core.md` | Stage K đã update |
| `SKILL.md` files | Stage J đã update |
| `procedures/` files | Stage J đã update |
| `_shared/templates/` | Stage H tạo, stable |
| `test_e2e_stage_j.py` | Stage J tạo, stable |

---

## Success Criteria

1. ✅ Multi-workload dispatch → aggregate → reports chain passes E2E
2. ✅ fix-workload.json fixtures generated correctly from partition_planner output
3. ✅ ISG-recommended dimensions → partition → dispatch validates
4. ✅ Coverage report populated from real multi-workload aggregation stats
5. ✅ v2 schema fields (`dimensions_run`, `coverage_rate_pct`, `dedup_stats`) correct
6. ✅ Edge cases: empty signals, single dim, cross-dim dedup
7. ✅ ~507 tests total, 0 failures, 0 regression
8. ✅ No source code changes (tests only)
