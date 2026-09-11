# Stage J Prompt — ISG Recommender Integration + Workload Partition Planner + Engine v6 Orchestrator Wiring

## Context

Stage I hoàn tất (PASS). E2E validation + downstream v6 wiring + report generation thành công:
- **profile_resolver.py** thêm `resolve_dimensions()` — load profiles.json, resolve dims per profile + overrides, safety floor enforcement
- **report_generator.py** tạo mới — `generate_lane_report()` + `generate_coverage_report()` từ templates (CORE-031)
- **wf-fix-triage SKILL.md** thêm v6 mode detection (PRE-GATE step 2a), v2 issue-registry schema support, dimension-aware severity hints (Step 2.1b), coverage-aware triage summary (Step 2.3d)
- **wf-fix-execute SKILL.md** thêm v6 mode detection (PRE-GATE step 2a), Verify Ripple for v6 (Phase 5), coverage-report reference in fix-report (Phase 6), fix-log dimension field (Phase 3)
- **fix-status.json template** thêm 4 v6 fields (engine_version, dimensions_resolved, profile_used, dimension_overrides) — default null cho v5 compat
- **17 new tests** trong `test_e2e_stage_i.py`, tất cả pass
- **480 tests total**, 0 failures, 0 regression

### Trạng thái kiến trúc sau Stage I

```
_shared/                           ✅ COMPLETE — shared services layer + config
├── signal_bus/                    ✅ Signal Bus (emit, validate, dedup)
├── scan_cache/                    ✅ Scan Cache (fingerprint, TTL, QD3 never cached)
├── probe_executor.py              ✅ Probe execution (grep/agent/runtime → Signal v2)
├── lane_dispatch.py               ✅ Lane dispatch (cache integration, parallel)
├── signal_aggregator.py           ✅ Aggregation (lanes → issue-registry.json)
├── dimension_registry.py          ✅ Dimension registry (metadata, cache policy)
├── profile_resolver.py            ✅ Profile → probe + dimension resolver (resolve_probes + resolve_dimensions)
├── report_generator.py            ✅ Lane + coverage report generation từ templates
├── read_trace.py                  ✅ Code tracing
├── isg/                           ✅ ISG recommender (core logic)
├── impact_graph/                  ✅ Impact graph builder
├── workload_estimator/            ✅ Workload estimation (core logic)
├── concurrency/                   ✅ Backpressure + token bucket
├── profiles.json                  ✅ Profile config (ADR-21 locked defaults)
├── templates/                     ✅ 3 v6 output templates (CORE-031)
└── tests/                         ✅ 480 tests (463 base + 17 Stage I)

wf-fix-functional/                 ✅ QD1 — dimension.json + 7 probe .md files
wf-fix-business/                   ✅ QD2 — dimension.json + 5 probe .md files
wf-fix-security/                   ✅ QD3 — dimension.json + 7 probe .md files
wf-fix-performance/                ✅ QD4 — dimension.json + 6 probe .md files
wf-fix-ux-a11y/                    ✅ QD5 — dimension.json + 7 probe .md files
wf-fix-data/                       ✅ QD6 — dimension.json + 6 probe .md files
wf-fix-compat/                     ✅ QD7 — dimension.json + 5 probe .md files

wf-fix-bugs/                       ✅ Orchestrator v6 flow documented in SKILL.md
wf-fix-discover/                   ✅ v6 mode detection documented in SKILL.md
wf-fix-triage/                     ✅ v6 mode + v2 schema documented in SKILL.md
wf-fix-execute/                    ✅ v6 mode for verify + report documented in SKILL.md
```

### What's Missing (Gap Analysis)

Stage I validated E2E chain and wired downstream skills. Stage J integrates ISG recommender
into the v6 orchestrator flow and implements Workload Partition Planner:

```
GAPS:
1. wf-fix-bugs SKILL.md chưa call resolve_dimensions() — cần wire vào v6 PRE-GATE
2. wf-fix-bugs SKILL.md chưa call ISG recommender — cần wire cho Partition Planner
3. Partition Planner logic chưa implement trong _shared/ — cần hàm partition dimensions → workloads
   (workload_estimator/ đã có propose_partitions() cho workload-level splitting,
    nhưng chưa có dimension-level splitting → partition_planner.py sẽ bridge gap này)
4. wf-fix-discover SKILL.md v6 mode chưa generate coverage-report.md + lane reports
5. wf-fix-discover procedures chưa có v6 dispatch step-by-step instructions
6. Signal aggregator chưa populate v2 schema fields (dimensions_run, coverage, dedup_stats)
7. E2E test: v6 full flow với resolve_dimensions → partition → dispatch → aggregate → reports
```

---

## Stage J: ISG Integration + Partition Planner + Discover v6 Dispatch

### Mục tiêu

Wire ISG recommender + workload estimator + partition planner vào v6 orchestrator flow:
1. Implement partition_dimensions() trong _shared/ — split dimensions → workloads
2. Wire wf-fix-bugs v6 PRE-GATE: resolve_dimensions → ISG → partition → dispatch
3. Update signal_aggregator để populate v2 schema fields
4. Wire wf-fix-discover v6 mode để generate coverage-report + lane reports
5. Full E2E test: v6 flow from profiles.json → ISG → partition → dispatch → reports

### Key Constraints

1. **Backward compatibility**: `--engine=v5` remains default, v5 flow unchanged
2. **CORE-006**: Safe-Write Protocol — skill chỉ update đúng fields được phân công
3. **CORE-007**: Path contract — outputs phải khớp với cross-skill contract table
4. **CORE-028**: Phase Summary — mọi skill phase phải tạo phase-summary.md
5. **CORE-031**: Template Usage Rule — reports tạo từ templates (READ → POPULATE → WRITE)
6. **ADR-14**: ISG recommendation → workload sizing
7. **ADR-15**: Partition Planner — Plan A (single-run) vs Plan B (multi-run)
8. **ADR-18**: Impact Graph → Verify Ripple depth=1, strength ≥ 0.5
9. **ADR-19**: Scan Cache — TTL 14 ngày, QD3 never cached
10. **ADR-21**: Default profile locked
11. **ADR-22**: QD3 never cached + blast_radius from impact graph
12. **Không regression**: 480 existing tests phải vẫn pass

---

## Tasks

### J1: Implement partition_dimensions() in _shared/ (CRITICAL)

File: `.claude/skills/workflow/_shared/partition_planner.py` (NEW)

Tạo partition planner module:

```python
def partition_dimensions(
    dimensions: list[str],
    isg_recommendation: dict | None = None,
    max_workload_size: int = 7,
) -> list[dict]:
    """Partition dimensions thành 1+ workloads.

    Logic:
        1. If dimensions <= max_workload_size → single workload
        2. If ISG recommends split → follow ISG guidance
        3. Otherwise → split by priority: core dims (QD1,QD2,QD5) first, then rest
        4. Each workload: { id, dimensions[], estimated_probes, estimated_minutes }

    Returns:
        List of workload dicts. Each workload có:
        - id: "W01", "W02", ...
        - dimensions: list of dimension IDs
        - estimated_probes: tổng probes (sum across dimensions)
        - estimated_minutes: rough time estimate
    """
```

Verify: Unit tests cho single-workload, multi-workload, ISG-guided partition.

### J2: Wire resolve_dimensions into wf-fix-bugs v6 PRE-GATE (CRITICAL)

File: `.claude/skills/workflow/wf-fix-bugs/SKILL.md`

Trong v6 engine flow PRE-GATE section, thêm steps:
1. Load profiles.json
2. Call resolve_dimensions(profile, overrides) → get dimension list
3. Call ISG recommender → get recommendation
4. Call partition_dimensions → get workloads
5. Write workloads to `$SESSION_DIR/workloads/W01/fix-workload.json` etc.

### J3: Update signal_aggregator to populate v2 schema fields (HIGH)

File: `.claude/skills/workflow/_shared/signal_aggregator.py`

Khi aggregate, nếu dimension list provided → populate v2 fields:
- `dimensions_run`: list of dimensions that ran
- `coverage.dimensions_with_issues`: dimensions có issues
- `coverage.dimensions_without_issues`: dimensions không có issues
- `coverage.coverage_rate_pct`: percentage
- `dedup_stats`: signals ingested vs deduplicated vs final issues

### J4: Wire wf-fix-discover v6 mode for report generation (HIGH)

File: `.claude/skills/workflow/wf-fix-discover/SKILL.md`

Trong v6 POST-GATE section, thêm:
1. After dispatch + aggregate → generate lane reports per dimension
2. Generate coverage-report.md từ template
3. Write reports to `$SESSION_DIR/lanes/QD*/lane-report.md` + `$SESSION_DIR/coverage-report.md`

### J5: Update wf-fix-discover procedures for v6 dispatch (MEDIUM)

File: `.claude/skills/workflow/wf-fix-discover/procedures/phase0-init.md`

Thêm v6 mode dispatch instructions:
1. Read fix-workload.json nếu engine_version == "v6"
2. Dispatch lanes theo workload dimensions
3. Aggregate signals → v2 issue-registry.json
4. Generate reports từ templates

### J6: E2E Smoke Tests (CRITICAL)

File: `.claude/skills/workflow/_shared/tests/test_e2e_stage_j.py`

Test cases:

1. **test_partition_single_workload**: 3 dims → 1 workload
2. **test_partition_multi_workload**: 7 dims, max=3 → 3 workloads
3. **test_partition_isg_guided**: ISG recommends split → follow guidance
4. **test_aggregator_v2_fields**: aggregate with dims list → v2 fields populated
5. **test_v6_full_pipeline**: profiles.json → resolve → partition → dispatch → aggregate → reports
6. **test_workload_json_schema**: fix-workload.json matches expected schema
7. **test_isg_recommender_integration**: ISG returns recommendation → partition uses it
8. **test_coverage_report_from_aggregation**: coverage-report generated from actual aggregation stats

**Target:** 480 existing + 8 new = 488 tests, 0 failures.

### J7: Final Regression (CRITICAL)

```bash
cd "z:/Working/MCV3/.claude/skills/workflow/_shared"
python -m pytest tests/ --tb=short
```

**Target:** 488+ tests, 0 failures, 0 regression.
Verify: no circular imports after new partition_planner module.

---

## File Summary

### Files to CREATE

| File | Mục đích |
|------|----------|
| `_shared/partition_planner.py` | Partition dimensions → workloads (ADR-14, ADR-15) |
| `_shared/tests/test_e2e_stage_j.py` | E2E smoke tests cho Stage J |

### Files to MODIFY

| File | Thay đổi |
|------|----------|
| `wf-fix-bugs/SKILL.md` | Wire resolve_dimensions + ISG + partition vào v6 PRE-GATE |
| `wf-fix-discover/SKILL.md` | Thêm report generation cho v6 POST-GATE |
| `wf-fix-discover/procedures/phase0-init.md` | Thêm v6 dispatch step-by-step |
| `_shared/signal_aggregator.py` | Populate v2 schema fields khi dims provided |

### Files KHÔNG thay đổi

| File | Lý do |
|------|-------|
| `_shared/profile_resolver.py` | Stage I updated, stable |
| `_shared/report_generator.py` | Stage I created, stable |
| `_shared/profiles.json` | Stage H created, stable |
| `_shared/templates/*` | Stage H created, templates stable |
| `_shared/lane_dispatch.py` | Stage F complete, stable |
| `_shared/isg/` | Core logic stable, integrate only |
| `_shared/workload_estimator/` | Core logic stable, integrate only |
| `_shared/impact_graph/` | Stage E complete, stable |
| `wf-fix-triage/SKILL.md` | Stage I updated, stable |
| `wf-fix-execute/SKILL.md` | Stage I updated, stable |
| `wf-fix-discover/templates/fix-status.json` | Stage I updated, stable |

---

## Success Criteria

1. ✅ `partition_dimensions()` splits dims theo ISG guidance or default strategy
2. ✅ wf-fix-bugs v6 PRE-GATE calls resolve_dimensions → ISG → partition
3. ✅ signal_aggregator populates v2 fields (dimensions_run, coverage, dedup_stats)
4. ✅ wf-fix-discover v6 generates lane reports + coverage report
5. ✅ wf-fix-discover procedures có v6 dispatch instructions
6. ✅ Full E2E: profiles → ISG → partition → dispatch → aggregate → reports
7. ✅ fix-workload.json matches expected schema
8. ✅ 488+ tests pass, 0 failures, 0 regression
9. ✅ No circular imports
