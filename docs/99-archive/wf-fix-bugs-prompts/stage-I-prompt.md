# Stage I Prompt — E2E Validation + Profile Coverage Verification + Fix-Triage-Execute v6 Wiring

## Context

Stage H hoàn tất (PASS). SKILL.md integration + profile wiring + contract update đã build thành công:
- **profiles.json** tạo tại `_shared/profiles.json` — 4 profiles (quick/standard/deep/exhaustive) + safety_floor config
- **wf-fix-bugs SKILL.md** thêm v6 engine flow section (PRE-GATE → EXECUTE → POST-GATE)
- **wf-fix-bugs _contract.json** thêm 4 v6 output fields vào `outputs.working[]`
- **wf-fix-discover SKILL.md** thêm v6 mode detection + dimension lane dispatch integration
- **3 templates** tạo tại `_shared/templates/` (lane-report.md, coverage-report.md, issue-registry-v2.json)
- **CORE-007 path contract** updated với 5 v6 entries trong `00-core.md` §4b
- **21 new tests** trong `test_e2e_stage_h.py`, tất cả pass
- **463 tests total**, 0 failures, 0 regression

### Trạng thái kiến trúc sau Stage H

```
_shared/                           ✅ COMPLETE — shared services layer + config
├── signal_bus/                    ✅ Signal Bus (emit, validate, dedup)
├── scan_cache/                    ✅ Scan Cache (fingerprint, TTL, QD3 never cached)
├── probe_executor.py              ✅ Probe execution (grep/agent/runtime → Signal v2)
├── lane_dispatch.py               ✅ Lane dispatch (cache integration, parallel)
├── signal_aggregator.py           ✅ Aggregation (lanes → issue-registry.json)
├── dimension_registry.py          ✅ Dimension registry (metadata, cache policy)
├── profile_resolver.py            ✅ Profile → dimensions mapping (reads dimension.json)
├── read_trace.py                  ✅ Code tracing
├── isg/                           ✅ ISG recommender
├── impact_graph/                  ✅ Impact graph builder
├── workload_estimator/            ✅ Workload estimation
├── concurrency/                   ✅ Backpressure + token bucket
├── profiles.json                  ✅ Profile config (ADR-21 locked defaults)
├── templates/                     ✅ 3 v6 output templates (CORE-031)
└── tests/                         ✅ 463 tests (442 base + 21 Stage H)

wf-fix-functional/                 ✅ QD1 — dimension.json + 7 probe .md files
wf-fix-business/                   ✅ QD2 — dimension.json + 5 probe .md files
wf-fix-security/                   ✅ QD3 — dimension.json + 7 probe .md files
wf-fix-performance/                ✅ QD4 — dimension.json + 6 probe .md files
wf-fix-ux-a11y/                    ✅ QD5 — dimension.json + 7 probe .md files
wf-fix-data/                       ✅ QD6 — dimension.json + 6 probe .md files
wf-fix-compat/                     ✅ QD7 — dimension.json + 5 probe .md files

wf-fix-bugs/                       ✅ Orchestrator v6 flow documented in SKILL.md
wf-fix-discover/                   ✅ v6 mode detection documented in SKILL.md
```

### What's Missing (Gap Analysis)

Stage H wired engine config into skill execution layer. Stage I validates the full E2E chain
and wires the remaining downstream skills (triage + execute) for v6 mode:

```
GAPS:
1. wf-fix-triage SKILL.md chưa có v6 mode — cần đọc issue-registry.json v2 schema
2. wf-fix-execute SKILL.md chưa có v6 mode — cần respect engine_version cho verify
3. profile_resolver.py chỉ đọc từ dimension.json — cần hàm load profiles.json để resolve dimension list per profile
4. Golden-v6 fixture chưa được validate full E2E qua dispatch → aggregate → triage → execute chain
5. fix-status.json template chưa có engine_version field
6. Coverage report generation chưa được implement (chỉ template)
7. Lane report generation chưa được implement (chỉ template)
8. E2E smoke test: chạy full pipeline --engine=v6 trên golden-v6 fixture chưa có
```

---

## Stage I: E2E Validation + Downstream v6 Wiring + Report Generation

### Mục tiêu

Validate toàn bộ v6 pipeline end-to-end và wire downstream skills:
1. `profile_resolver.py` thêm `resolve_dimensions()` function load từ profiles.json
2. Implement report generation functions (lane report + coverage report từ templates)
3. Wire wf-fix-triage + wf-fix-execute SKILL.md cho v6 mode
4. Update fix-status.json template với engine_version field
5. Full E2E smoke test trên golden-v6 fixture

### Key Constraints

1. **Backward compatibility**: `--engine=v5` remains default, v5 flow unchanged
2. **CORE-006**: Safe-Write Protocol — skill chỉ update đúng fields được phân công
3. **CORE-007**: Path contract — outputs phải khớp với cross-skill contract table (Stage H đã update)
4. **CORE-028**: Phase Summary — mọi skill phase phải tạo phase-summary.md
5. **CORE-031**: Template Usage Rule — reports tạo từ templates (READ → POPULATE → WRITE)
6. **ADR-21**: Default profile locked: quick=[QD1,QD5], standard=[QD1,QD2,QD5], deep=[QD1,QD2,QD5,QD6,QD3], exhaustive=QD1-7
7. **ADR-22**: QD3 never cached
8. **Không regression**: 463 existing tests phải vẫn pass

---

## Tasks

### I1: Add resolve_dimensions() to profile_resolver.py (CRITICAL)

File: `.claude/skills/workflow/_shared/profile_resolver.py`

Thêm function mới `resolve_dimensions()` đọc từ profiles.json:

```python
def resolve_dimensions(
    profiles_json_path: Path,
    profile: str,
    dims_override: list[str] | None = None,
    only: list[str] | None = None,
    skip: list[str] | None = None,
) -> list[str]:
    """Load profiles.json, resolve dimensions theo profile + overrides.

    Logic:
        1. Read profiles.json
        2. Get base dimensions from profiles[profile].dimensions
        3. Apply overrides: dims_override (replace all), only (filter), skip (remove)
        4. Safety floor check: profile >= standard phải giữ >= 1 của QD1,QD2,QD5
        5. Return final dimension list
    """
```

Verify: Unit tests cho function mới + existing `resolve_probes()` vẫn hoạt động.

### I2: Implement Report Generation Functions (HIGH)

File: `.claude/skills/workflow/_shared/report_generator.py` (NEW)

Tạo module report generation:

```python
def generate_lane_report(
    template_path: Path,
    output_path: Path,
    dimension_id: str,
    dimension_name: str,
    profile: str,
    session_dir: Path,
    probes_total: int,
    probes_available: int,
    signals_count: int,
    issues_count: int,
    probe_rows: list[dict],
    issues_detail: str,
    recommendations: str,
    started_at: str,
    completed_at: str,
) -> Path:
    """READ template → POPULATE data → WRITE output (CORE-031)."""


def generate_coverage_report(
    template_path: Path,
    output_path: Path,
    profile: str,
    dimensions_list: list[str],
    skipped_dimensions: list[str],
    session_dir: Path,
    dimension_rows: list[dict],
    total_signals: int,
    total_issues: int,
    severity_rows: list[dict],
    recommendations: str,
    started_at: str,
    completed_at: str,
) -> Path:
    """READ template → POPULATE data → WRITE output (CORE-031)."""
```

### I3: Update wf-fix-triage SKILL.md — v6 Mode (HIGH)

File: `.claude/skills/workflow/wf-fix-triage/SKILL.md`

Khi v6 mode (detected qua fix-status.json.engine_version == "v6"):

1. Đọc issue-registry.json — hỗ trợ cả v1 (v5) và v2 (v6) schema
2. v2 schema có thêm fields: `dimensions_run[]`, `engine_version`, `coverage{}`, `dedup_stats{}`
3. Triage logic giữ nguyên — chỉ thêm dimension-aware severity hints
4. Tạo coverage-aware triage summary (hiển thị dimensions nào có issues)

### I4: Update wf-fix-execute SKILL.md — v6 Mode (MEDIUM)

File: `.claude/skills/workflow/wf-fix-execute/SKILL.md`

Khi v6 mode:

1. Phase 5 (Verify): nếu engine_version == "v6" → read impact-graph.json cho ripple verification
2. Phase 6 (Report): include coverage-report.md reference trong fix-report.md
3. fix-log.json entries thêm `dimension` field khi v6 mode

### I5: Update fix-status.json Template (MEDIUM)

File: `.claude/skills/workflow/wf-fix-discover/templates/fix-status.json`

Thêm v6 fields vào template (backward-compat — fields default null cho v5):

```json
{
  "engine_version": null,
  "dimensions_resolved": null,
  "profile_used": null,
  "dimension_overrides": null
}
```

### I6: Full E2E Smoke Test (CRITICAL)

File: `.claude/skills/workflow/_shared/tests/test_e2e_stage_i.py`

Test cases:

1. **test_resolve_dimensions_quick**: profiles.json → quick → [QD1, QD5]
2. **test_resolve_dimensions_standard_skip_qd2**: standard + skip=[QD2] → [QD1, QD5]
3. **test_resolve_dimensions_safety_floor_reject**: standard + skip=[QD1,QD2,QD5] → ValueError
4. **test_resolve_dimensions_dims_override**: standard + dims_override=[QD3,QD7] → [QD3, QD7] (dims override bypasses safety floor)
5. **test_lane_report_generation**: generate_lane_report từ template → output có đúng placeholders
6. **test_coverage_report_generation**: generate_coverage_report từ template → output có đúng placeholders
7. **test_full_e2e_v6_smoke**: golden-v6 → dispatch_lanes(7 dims) → aggregate → reports generated → issue-registry.json valid
8. **test_v6_fix_status_fields**: fix-status.json template có engine_version field

**Target:** 463 existing + 8 new = 471 tests, 0 failures.

### I7: Final Regression (CRITICAL)

```bash
cd "z:/Working/MCV3/.claude/skills/workflow/_shared"
python -m pytest tests/ --tb=short
```

**Target:** 471+ tests, 0 failures, 0 regression.
Verify: no circular imports after new report_generator module.

---

## File Summary

### Files to CREATE

| File | Mục đích |
|------|----------|
| `_shared/report_generator.py` | Lane report + coverage report generation từ templates (CORE-031) |
| `_shared/tests/test_e2e_stage_i.py` | E2E smoke tests cho Stage I |

### Files to MODIFY

| File | Thay đổi |
|------|----------|
| `_shared/profile_resolver.py` | Thêm `resolve_dimensions()` function |
| `wf-fix-triage/SKILL.md` | Thêm v6 mode detection + v2 schema support |
| `wf-fix-execute/SKILL.md` | Thêm v6 mode cho Phase 5 verify + Phase 6 report |
| `wf-fix-discover/templates/fix-status.json` | Thêm engine_version + dimensions fields |

### Files KHÔNG thay đổi

| File | Lý do |
|------|-------|
| `_shared/profiles.json` | Stage H created, stable |
| `_shared/templates/*` | Stage H created, templates stable |
| `_shared/lane_dispatch.py` | Stage F complete, stable |
| `_shared/signal_aggregator.py` | Stage F complete, stable |
| `_shared/signal_bus/` | Stage E complete, stable |
| `_shared/scan_cache/` | Stage E complete, stable |
| `wf-fix-bugs/SKILL.md` | Stage H updated, stable |
| `wf-fix-bugs/_contract.json` | Stage H updated, stable |
| `wf-fix-*/dimension.json` (7 files) | Stage G complete, stable |

---

## Success Criteria

1. ✅ `resolve_dimensions()` load profiles.json và resolves đúng dims per profile + overrides
2. ✅ Safety floor enforcement in code: standard + skip all core → ValueError
3. ✅ Lane report + coverage report generated từ templates (CORE-031)
4. ✅ wf-fix-triage supports v2 issue-registry schema
5. ✅ wf-fix-execute respects v6 mode for verify + report
6. ✅ fix-status.json template has engine_version field
7. ✅ Full E2E smoke: dispatch → aggregate → reports → valid outputs
8. ✅ 471+ tests pass, 0 failures, 0 regression
9. ✅ No circular imports
