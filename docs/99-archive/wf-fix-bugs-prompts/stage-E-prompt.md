# Stage E Prompt — Orchestrator Integration + Lane Dispatch

## Context

Stage D hoàn tất (PASS). Toàn bộ 7 dimension lanes đã build + test thành công:
- 71 files mới (5 lanes × ~14 files/lane + tests + fixtures + CI)
- 43/43 E2E tests pass cho QD3-QD7, 380 total tests (0 failures)
- QD3 (Security): 7 probes, ADR-22 Rule 6 enforced — KHÔNG cache
- QD4 (Performance): 6 probes, static cache allowed, runtime skip
- QD5 (UX/A11y): 7 probes, agents: ux-researcher, accessibility-auditor
- QD6 (Data): 6 probes, agents: dba, data-engineer
- QD7 (Compat): 5 probes, agents: frontend-developer, mobile-developer
- Golden fixture: 11 known issues across 4 files, 7 dimensions

Giờ kết nối orchestrator (wf-fix-bugs) với 7 dimension lanes, xây dựng profile-to-probe resolution, parallel dispatch, và Signal Bus aggregation.

---

## Stage E: Orchestrator Integration + Lane Dispatch

### Mục tiêu

Kết nối wf-fix-bugs orchestrator với 7 dimension lanes, thay thế discovery 5-Layer bằng dimension-based lane dispatch:

1. **Orchestrator update** — wf-fix-bugs SKILL.md thêm logic spawn lanes thay thế 5-Layer
2. **Profile-to-probe resolution** — Runtime logic đọc dimension.json → chọn probes theo profile
3. **Parallel lane dispatch** — Spawn lanes song song với token_bucket + backpressure
4. **Signal Bus aggregation** — Thu thập signals từ tất cả lanes → issue-registry.json
5. **Workload Estimator update** — Thêm QD3-QD7 dimensions vào estimator
6. **ISG Recommender update** — Thêm dimension weights cho QD3-QD7

### Key Constraints

1. **CORE-025**: Song song hóa chỉ khi write scope tách biệt — mỗi lane ghi `lanes/{DIM}/`
2. **ADR-22 Rule 6**: QD3 KHÔNG BAO GIỜ cache — orchestrator PHẢI enforce
3. **CORE-027**: CDG cho partition override — user confirmation bắt buộc
4. **CORE-028**: phase-summary.md ≤15 dòng
5. **CORE-030**: Session isolation — mỗi run có SESSION_DIR riêng
6. **CORE-031**: Mọi output từ template
7. **Backward compat**: `--engine=v5` vẫn hoạt động (migration plan Phase 5)

---

## E1: Profile-to-Probe Resolution Module

Tạo `_shared/profile_resolver.py` (~150 LOC).

### Logic

```python
def resolve_probes(dimension_json_path: Path, profile: str) -> list[str]:
    """Đọc dimension.json, trả về probe IDs cho profile.

    Profile exit_criteria.probes_required:
      - list of probe IDs → return list
      - "ALL" → return tất cả probes[].id
    """
```

### Behavior

1. Read dimension.json
2. Look up `exit_criteria[profile].probes_required`
3. If list → return as-is
4. If "ALL" → collect all `probes[].id`
5. Validate mỗi probe ID match `^P-QD[1-7]-[a-z0-9-]+$`
6. Return ordered list

### Test cases

- `resolve_probes(dimension_QD3, "quick")` → ["P-QD3-dependency-vuln-scan", "P-QD3-owasp-top-ten", "P-QD3-dangerous-deserialize"]
- `resolve_probes(dimension_QD3, "exhaustive")` → all 7 probes
- `resolve_probes(dimension_QD3, "invalid")` → raise ValueError
- `resolve_probes(missing_file, "quick")` → raise FileNotFoundError

---

## E2: Dimension Lane Registry

Tạo `_shared/dimension_registry.py` (~200 LOC).

### Purpose

Central registry ánh xạ dimension → lane directory, agents, probe count.

### Schema

```python
# _shared/dimension_registry.py

DIMENSION_REGISTRY = {
    "QD1": {
        "lane": "wf-fix-functional",
        "dimension_file": "dimension.json",
        "agents": [],
        "cache_allowed": True,
    },
    "QD2": {
        "lane": "wf-fix-business",
        "dimension_file": "dimension.json",
        "agents": ["business-analyst"],
        "cache_allowed": True,
    },
    "QD3": {
        "lane": "wf-fix-security",
        "dimension_file": "dimension.json",
        "agents": ["security"],
        "cache_allowed": False,  # ADR-22 Rule 6
    },
    "QD4": {
        "lane": "wf-fix-performance",
        "dimension_file": "dimension.json",
        "agents": ["performance-benchmarker"],
        "cache_allowed": True,
    },
    "QD5": {
        "lane": "wf-fix-ux-a11y",
        "dimension_file": "dimension.json",
        "agents": ["ux-researcher", "accessibility-auditor"],
        "cache_allowed": True,
    },
    "QD6": {
        "lane": "wf-fix-data",
        "dimension_file": "dimension.json",
        "agents": ["dba", "data-engineer"],
        "cache_allowed": True,
    },
    "QD7": {
        "lane": "wf-fix-compat",
        "dimension_file": "dimension.json",
        "agents": ["frontend-developer", "mobile-developer"],
        "cache_allowed": True,
    },
}
```

### Functions

```python
def get_lane_path(dim: str, workflow_root: Path) -> Path:
    """Trả về đường dẫn tuyệt đối đến lane directory."""

def get_all_dimensions() -> list[str]:
    """Trả về ['QD1', 'QD2', ..., 'QD7']."""

def validate_lane_exists(dim: str, workflow_root: Path) -> bool:
    """Check lane directory + dimension.json tồn tại."""

def get_cache_policy(dim: str) -> bool:
    """Trả về True nếu dimension cho phép cache, False nếu không (QD3)."""
```

### Test cases

- `get_lane_path("QD3", workflow_root)` → path ending with `wf-fix-security/`
- `get_cache_policy("QD3")` → False
- `get_cache_policy("QD4")` → True
- `validate_lane_exists("QD1", workflow_root)` → True
- `validate_lane_exists("QD99", workflow_root)` → False (invalid dimension)

---

## E3: Workload Estimator Update

Update `_shared/workload_estimator/estimator.py` thêm QD3-QD7.

### Changes

1. Add dimension weights cho QD3-QD7:

```python
DIMENSION_WEIGHTS = {
    "QD1": 1.0,   # Functional — baseline
    "QD2": 1.2,   # Business — needs agent
    "QD3": 1.5,   # Security — higher cost, no cache
    "QD4": 1.0,   # Performance — static + runtime
    "QD5": 1.3,   # UX/A11y — needs Playwright + agents
    "QD6": 0.8,   # Data — mostly static
    "QD7": 1.1,   # Compat — static + runtime
}
```

2. Update `estimate()` to read dimension.json probe `estimated_cost`:
   - Sum `time_seconds` + `tokens` for all probes in selected profile
   - Multiply by dimension weight
   - Aggregate across selected dimensions

3. Test cases:
   - `estimate(["QD3"], "quick")` → time based on 3 QD3 quick probes × 1.5 weight
   - `estimate(["QD1", "QD3", "QD5"], "standard")` → aggregated across 3 dimensions
   - `estimate([], "quick")` → raise ValueError

---

## E4: ISG Recommender Update

Update `_shared/isg/isg_recommender.py` thêm QD3-QD7 dimension scores.

### Changes

1. Add dimension scoring cho new dimensions:

```python
# Scoring heuristics per dimension
DIMENSION_SCORES = {
    "QD1": {"base_weight": 1.0, "security_boost": 0, "perf_boost": 0},
    "QD2": {"base_weight": 1.2, "security_boost": 0, "perf_boost": 0},
    "QD3": {"base_weight": 1.5, "security_boost": 2.0, "perf_boost": 0},
    "QD4": {"base_weight": 1.0, "security_boost": 0, "perf_boost": 1.5},
    "QD5": {"base_weight": 1.3, "security_boost": 0, "perf_boost": 0},
    "QD6": {"base_weight": 0.8, "security_boost": 0, "perf_boost": 0},
    "QD7": {"base_weight": 1.1, "security_boost": 0, "perf_boost": 0.5},
}
```

2. Update `recommend_dimensions()`:
   - Accept file type hints (e.g., `.sql` → boost QD6, `.tsx` → boost QD5+QD7)
   - Accept project context (api-only → skip QD5)
   - Return ranked dimension list with scores

3. Test cases:
   - `recommend_dimensions(["src/auth/login.ts"])` → QD3 ranked high (security)
   - `recommend_dimensions(["src/db/migration.sql"])` → QD6 ranked high (data)
   - `recommend_dimensions(interface_type="api-only")` → QD5 excluded

---

## E5: Lane Dispatch Protocol

Tạo `_shared/lane_dispatch.py` (~250 LOC).

### Purpose

Orchestrate parallel lane execution với token_bucket + backpressure.

### Core logic

```python
def dispatch_lanes(
    session_dir: Path,
    dimensions: list[str],
    profile: str,
    workflow_root: Path,
    max_parallel: int = 3,
) -> dict[str, Path]:
    """Dispatch lanes (parallel up to max_parallel), return signals paths.

    Per dimension:
      1. Resolve probes via profile_resolver
      2. Create lane dir: $SESSION_DIR/lanes/{DIM}/
      3. Check cache policy (QD3 → skip cache)
      4. Execute probes (call Agent tool with appropriate subagent_type)
      5. Collect signals → $SESSION_DIR/lanes/{DIM}/signals.json
      6. Run POST-GATE T1-T4 per lane

    Returns: {dimension: signals.json_path}
    """
```

### Implementation

1. Use `_shared/concurrency/token_bucket.py` for rate limiting
2. Use `_shared/concurrency/backpressure.py` for adaptive throttling
3. Per lane:
   - `mkdir -p $SESSION_DIR/lanes/{DIM}/`
   - For each probe in resolved list:
     - If cache_allowed AND `--use-cache` → check `_shared/scan_cache/`
     - Execute probe (read probe .md → follow SENSE→THINK→ACT→VERIFY)
     - Emit signal via `SignalBus.ingest()`
   - `SignalBus.flush()` → `lanes/{DIM}/signals.json`
4. POST-GATE T1-T4 per lane signals.json
5. Return dict of signals paths

### Test cases

- `dispatch_lanes(session, ["QD1", "QD3"], "quick", workflow)` → 2 signals.json created
- QD3 lane does NOT call cache_store/fingerprint
- QD1 lane DOES call cache when `--use-cache` provided
- POST-GATE fail → retry lane (max 3), then skip with error logged
- max_parallel=1 → sequential execution
- max_parallel=3 → up to 3 lanes concurrent

---

## E6: Signal Bus Aggregation Protocol

Tạo `_shared/signal_aggregator.py` (~150 LOC).

### Purpose

Aggregate signals từ tất cả lane-local signals.json → master issue-registry.json.

### Logic

```python
def aggregate_lane_signals(
    session_dir: Path,
    dimensions: list[str],
) -> tuple[Path, dict[str, int]]:
    """Read all lane signals.json, aggregate via SignalBus, return (registry_path, stats).

    Stats: {"total_signals": N, "total_issues": M, "by_dimension": {...}}
    """
```

### Implementation

1. For each dimension in `dimensions`:
   - Read `$SESSION_DIR/lanes/{DIM}/signals.json`
   - Extract `signals[]` array
2. Create `SignalBus(session_dir)`
3. Ingest all signals (dedup happens automatically via SignalBus)
4. `bus.flush()` → `$SESSION_DIR/issue-registry.json`
5. Return stats for reporting

### Test cases

- Aggregate QD1+QD3 signals → issue-registry with issues from both dimensions
- Same file+line in QD1+QD3 → 2 separate issues (different dedup_key)
- Same file+line+dimension → deduped to 1 issue
- 0 signals in all lanes → empty issue-registry.json (valid)

---

## E7: Orchestrator SKILL.md Update

Update `wf-fix-bugs/SKILL.md` thêm v6 lane dispatch path.

### Changes to wf-fix-bugs/SKILL.md

1. **Add `--engine` flag** (default: `v5`):
   ```
   --engine=v5|v6   Engine version (default: v5)
   ```

2. **Add `--dims` flag** (v6 only):
   ```
   --dims=QD1,QD3,QD5   Comma-separated dimensions to run (default: all applicable)
   ```

3. **Add `--profile` flag** (v6 only):
   ```
   --profile=quick|standard|deep|exhaustive   Profile depth (default: standard)
   ```

4. **Add v6 execution path** (after PRE-GATE):
   ```
   IF --engine=v6:
     E1. Parse --dims → if empty, use ISG Recommender to auto-select
     E2. Workload Estimator → check gate
     E3. Profile Resolver → resolve probes per dimension
     E4. Lane Dispatch → execute lanes (parallel up to max_parallel)
     E5. Signal Aggregation → collect all signals → issue-registry.json
     E6. Triage → wf-fix-triage (reuse existing)
     E7. Execute → wf-fix-execute (reuse existing)
     E8. Report → aggregate lane reports + phase-summary
   ELSE:
     [Existing v5 flow unchanged]
   ```

5. **Version bump** → `6.0.0-alpha` (indicate experimental status)

### Files to modify

| File | Change |
|------|--------|
| `wf-fix-bugs/SKILL.md` | Add --engine, --dims, --profile flags; add v6 execution path |
| `wf-fix-bugs/_contract.json` | Add new inputs: --engine, --dims, --profile |

---

## E8: Integration Tests

### Test file

`.claude/skills/workflow/_shared/tests/test_e2e_orchestrator.py` (~400 LOC)

### Test cases

1. **TestProfileResolver** (5 tests)
   - resolve QD1 quick → 3 probes
   - resolve QD3 standard → 6 probes
   - resolve QD3 exhaustive → ALL (7 probes)
   - resolve invalid profile → ValueError
   - resolve missing dimension.json → FileNotFoundError

2. **TestDimensionRegistry** (5 tests)
   - get_lane_path all 7 dimensions
   - get_cache_policy QD3=False, others=True
   - validate_lane_exists for valid/invalid
   - get_all_dimensions → 7 items

3. **TestWorkloadEstimatorV6** (4 tests)
   - estimate single dimension (QD3 quick)
   - estimate multiple dimensions
   - estimate with dimension weights applied
   - estimate empty → ValueError

4. **TestLaneDispatch** (5 tests)
   - dispatch 2 lanes sequential
   - dispatch QD3 → no cache calls
   - dispatch QD1 with --use-cache → cache lookup called
   - dispatch with POST-GATE failure → retry
   - dispatch with max_parallel → verify isolation

5. **TestSignalAggregation** (5 tests)
   - aggregate 2 lanes → merged issue-registry
   - cross-dimension dedup → separate issues
   - same-dimension dedup → merged issues
   - empty signals → valid empty registry
   - aggregation stats accuracy

6. **TestOrchestratorV6Flow** (3 tests)
   - Full flow: dispatch → aggregate → triage → report (golden fixture)
   - --engine=v5 → existing flow unchanged
   - --dims=QD3 only → single dimension dispatch

---

## E9: CI + Documentation

### CI Update

Verify `.github/workflows/wf-fix-bugs-ci.yml` covers all new test files.

### Documentation

1. Update `wf-fix-bugs/SKILL.md` version to `6.0.0-alpha`
2. Update `CLAUDE.md` — add note about --engine=v5|v6 coexistence
3. Write `docs/design/skills/wf-fix-bugs/reviews/E-review-20260421.md`

---

## Execution Order

```
E1 (profile_resolver.py)     ─┐
E2 (dimension_registry.py)   ─┤ independent modules
E3 (workload_estimator upd)  ─┤ → can parallel
E4 (isg_recommender upd)     ─┘
         ↓
E5 (lane_dispatch.py)         ← depends on E1+E2
         ↓
E6 (signal_aggregator.py)     ← depends on E5
         ↓
E7 (orchestrator SKILL.md)    ← depends on E1-E6
         ↓
E8 (integration tests)        ← depends on E7
         ↓
E9 (CI + review)
```

CORE-025: E1-E4 có isolated write scopes (separate files). E5-E6 có dependency chain. E7 touches orchestrator only.

---

## Acceptance Criteria

| # | Criteria | Target |
|---|----------|--------|
| 1 | Profile resolver cho tất cả 7 dimensions | 4 profiles × 7 dims = 28 resolution paths |
| 2 | Dimension registry chính xác | 7 dimensions, cache policy đúng cho QD3 |
| 3 | Workload estimator có QD3-QD7 weights | 7 dimensions weighted |
| 4 | ISG recommender recommend QD3 cho security files | File-type → dimension mapping |
| 5 | Lane dispatch isolation | Mỗi lane writes lanes/{DIM}/ riêng |
| 6 | Signal aggregation dedup đúng | Cross-dim separate, same-dim merged |
| 7 | --engine=v5 backward compat | Existing flow untouched |
| 8 | Full test suite pass | 380 existing + ~27 new = ~407 total |
| 9 | Coverage gate ≥80% | All tests pass |
| 10 | CORE-025 parallel safe | No write conflicts |
| 11 | CORE-028 phase summary | ≤15 lines |
| 12 | ADR-22 Rule 6 enforced | QD3 never cached in dispatch |

---

## Verification (End-to-End)

1. `python -c "from profile_resolver import resolve_probes; print(resolve_probes(...))"` — works for all 7 dims
2. `python -c "from dimension_registry import get_cache_policy; assert get_cache_policy('QD3') == False"`
3. `pytest _shared/tests/test_e2e_orchestrator.py -v` — all new tests pass
4. `pytest _shared/tests/ -v --tb=short` — 0 regression
5. `/wf-fix-bugs --engine=v6 --dims=QD3 --profile=quick --dry-run` — dispatches QD3 lane only
6. `/wf-fix-bugs --engine=v5` — existing flow works unchanged
