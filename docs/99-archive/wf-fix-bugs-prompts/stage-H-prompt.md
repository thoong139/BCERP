# Stage H Prompt — SKILL.md Integration + Profile Wiring + Contract Update

## Context

Stage G hoàn tất (PASS). Dimension config completion + final integration đã build thành công:
- **43/43 probes** trong 7 dimension.json có `tool.kind` hợp lệ (trong SUPPORTED_TOOL_KINDS)
- **GREP_PATTERNS** cover tất cả 7 dimensions (QD1-QD7)
- **Golden-v6 fixture** trigger signals cho ≥6 dimensions (QD1, QD2, QD3, QD4, QD5, QD6, QD7)
- **442 tests pass**, 0 failures, 0 regression
- **No circular imports** verified
- **SUPPORTED_TOOL_KINDS** alignment verified: all dimension tool.kinds exist in supported set

### Trạng thái kiến trúc sau Stage G

```
_shared/                           ✅ COMPLETE — shared services layer
├── signal_bus/                    ✅ Signal Bus (emit, validate, dedup)
├── scan_cache/                    ✅ Scan Cache (fingerprint, TTL, QD3 never cached)
├── probe_executor.py              ✅ Probe execution (grep/agent/runtime → Signal v2)
├── lane_dispatch.py               ✅ Lane dispatch (cache integration, parallel)
├── signal_aggregator.py           ✅ Aggregation (lanes → issue-registry.json)
├── dimension_registry.py          ✅ Dimension registry (metadata, cache policy)
├── profile_resolver.py            ✅ Profile → dimensions mapping
├── read_trace.py                  ✅ Code tracing
├── isg/                           ✅ ISG recommender
├── impact_graph/                  ✅ Impact graph builder
├── workload_estimator/            ✅ Workload estimation
├── concurrency/                   ✅ Backpressure + token bucket
└── tests/                         ✅ 442 tests

wf-fix-functional/                 ✅ QD1 — dimension.json + 7 probe .md files
wf-fix-business/                   ✅ QD2 — dimension.json + 5 probe .md files (tool.kind fixed)
wf-fix-security/                   ✅ QD3 — dimension.json + 7 probe .md files
wf-fix-performance/                ✅ QD4 — dimension.json + 6 probe .md files (tool.kind added)
wf-fix-ux-a11y/                    ✅ QD5 — dimension.json + 7 probe .md files (tool.kind added)
wf-fix-data/                       ✅ QD6 — dimension.json + 6 probe .md files (tool.kind added)
wf-fix-compat/                     ✅ QD7 — dimension.json + 5 probe .md files (tool.kind added)
```

### What's Missing (Gap Analysis)

Stage G completed the **engine layer** (`_shared/`) and **dimension configs** (7 lane directories).
Stage H wires this engine into the **skill execution layer** so `/wf-fix-bugs --engine=v6` works end-to-end.

```
GAPS:
1. SKILL.md chưa có flag --engine=v6
2. SKILL.md chưa có flow để gọi _shared/ modules
3. _contract.json chưa reflect v6 outputs (lanes/, issue-registry v2 schema)
4. profiles.json chưa tồn tại — profile_resolver.py cần config file
5. wf-fix-discover SKILL.md chưa integrate dimension lanes (vẫn dùng 5-Layer)
6. CORE-007 path contract chưa có entries cho v6 lane outputs
7. Template files cho v6 outputs (lane-report, phase-summary) chưa tạo
```

---

## Stage H: SKILL.md Integration + Profile Wiring + Contract Update

### Mục tiêu

Wire the v6 engine into skill execution layer, enable `/wf-fix-bugs --engine=v6` to:
1. Dispatch dimension lanes via `_shared/lane_dispatch.py`
2. Aggregate signals via `_shared/signal_aggregator.py`
3. Generate v6-compatible outputs in `$SESSION_DIR/`
4. Maintain backward compatibility with `--engine=v5` (default)

### Key Constraints

1. **Backward compatibility**: `--engine=v5` remains default, v5 flow unchanged
2. **CORE-006**: Safe-Write Protocol — skill chỉ update đúng fields được phân công
3. **CORE-007**: Path contract — outputs phải khớp với cross-skill contract table
4. **CORE-028**: Phase Summary — mọi skill phase phải tạo phase-summary.md
5. **ADR-21**: Default profile locked: quick=[QD1,QD5], standard=[QD1,QD2,QD5], deep=[QD1,QD2,QD5,QD6,QD3], exhaustive=QD1-7
6. **ADR-22**: QD3 never cached
7. **Không regression**: 442 existing tests phải vẫn pass

---

## Tasks

### H1: Create profiles.json (CRITICAL)

File: `.claude/skills/workflow/_shared/profiles.json`

Profile resolver cần config file. Tạo theo ADR-21 locked defaults:

```json
{
  "$schema": "profiles-v1",
  "profiles": {
    "quick": {
      "dimensions": ["QD1", "QD5"],
      "description": "Fast scan — correctness + UX baseline",
      "estimated_time_minutes": 5
    },
    "standard": {
      "dimensions": ["QD1", "QD2", "QD5"],
      "description": "Balanced — correctness + business + UX",
      "estimated_time_minutes": 15
    },
    "deep": {
      "dimensions": ["QD1", "QD2", "QD5", "QD6", "QD3"],
      "description": "Thorough — thêm data integrity + security",
      "estimated_time_minutes": 30
    },
    "exhaustive": {
      "dimensions": ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7"],
      "description": "Full coverage — tất cả 7 dimensions",
      "estimated_time_minutes": 60
    }
  },
  "dimension_overrides": {
    "--only": "Replace profile dimensions với user-specified list",
    "--skip": "Remove specified dimensions từ profile",
    "--dims": "Explicit dimension list (override profile entirely)"
  },
  "safety_floor": {
    "rule": "Profile ≥ standard KHÔNG được bỏ toàn bộ QD1+QD2+QD5",
    "applies_to": ["standard", "deep", "exhaustive"]
  }
}
```

Verify: `profile_resolver.py` load được file này và resolve đúng dimensions per profile.

### H2: Update wf-fix-bugs SKILL.md — Add v6 Engine Flow (CRITICAL)

File: `.claude/skills/workflow/wf-fix-bugs/SKILL.md`

Thêm flag `--engine=v5|v6` (default: v5) và v6 execution flow:

1. **CLI flags mới**:
   - `--engine=v5|v6` — chọn engine (default v5, backward-compat)
   - `--dims=QD1,QD3,QD5` — explicit dimension list
   - `--only=QD3` — shorthand cho single dimension
   - `--skip=QD4,QD7` — skip dimensions từ profile
   - `--profile=quick|standard|deep|exhaustive` — override default profile
   - `--use-cache` — enable scan cache (ADR-22: QD3 never cached)

2. **V6 flow** (khi `--engine=v6`):
   ```
   PRE-GATE:
     - Verify project_root exists
     - Load profile → resolve dimensions (profile_resolver.py)
     - Create $SESSION_DIR/ structure

   EXECUTE:
     Phase 1: lane_dispatch.dispatch_lanes()
       → Dispatch probes cho resolved dimensions
       → Collect signals per lane in $SESSION_DIR/lanes/QD*/
     Phase 2: signal_aggregator.aggregate_lane_signals()
       → Merge + dedup signals → issue-registry.json
     Phase 3: Generate reports
       → lane-report.md per dimension
       → coverage-report.md (overall)
       → phase-summary.md (CORE-028)

   POST-GATE:
     - T1: issue-registry.json exists + non-empty
     - T2: Required sections present
     - T3: issue count > 0 (hoặc explicit --dry-run)
     - T4: Cross-reference with dimension exit_criteria
   ```

3. **Giữ nguyên v5 flow** khi không có `--engine=v6`:
   ```
   /wf-fix-bugs [mô-tả] [--scope] [--dry-run] [--resume]
   → delegate tuần tự wf-fix-discover → wf-fix-triage → wf-fix-execute
   (không thay đổi gì)
   ```

### H3: Update wf-fix-bugs _contract.json (HIGH)

File: `.claude/skills/workflow/wf-fix-bugs/_contract.json`

Thêm v6-specific output fields:

```json
{
  "outputs": {
    "working": [
      {
        "path": "$SESSION_DIR/lanes/QD*/signals.json",
        "template": null,
        "notes": "Per-dimension signal output — dynamically created per resolved profile"
      },
      {
        "path": "$SESSION_DIR/issue-registry.json",
        "template": null,
        "notes": "v2 schema — aggregated from all dimension lanes"
      },
      {
        "path": "$SESSION_DIR/coverage-report.md",
        "template": null,
        "notes": "Dimension coverage summary"
      }
    ]
  }
}
```

### H4: Update wf-fix-discover SKILL.md — v6 Mode Detection (HIGH)

File: `.claude/skills/workflow/wf-fix-discover/SKILL.md`

Khi `--engine=v6`, Phase 1 (Discovery) thay 5-Layer bằng dimension lane dispatch:

1. Detect engine mode từ session context (fix-status.json.engine_version)
2. Nếu v6: gọi `lane_dispatch.dispatch_lanes()` thay vì chạy 5-Layer manually
3. Nếu v5: giữ nguyên flow hiện tại
4. Phase 0 init tạo thêm `engine_version: "v6"` trong fix-status.json

### H5: Create v6 Output Templates (MEDIUM)

Files to create:
- `.claude/skills/workflow/_shared/templates/lane-report.md` — template cho per-dimension report
- `.claude/skills/workflow/_shared/templates/coverage-report.md` — template cho overall coverage
- `.claude/skills/workflow/_shared/templates/issue-registry-v2.json` — v2 issue schema template

Templates follow CORE-031 (Template Usage Rule): READ template → POPULATE data → WRITE output.

### H6: Update CORE-007 Path Contract (MEDIUM)

File: `.claude/rules/00-core.md` §4b

Thêm v6-specific path entries vào Cross-Skill Output Path Contract table:

| Producer | Output Path | Consumer |
|----------|-------------|----------|
| `/wf-fix-bugs` (--engine=v6) Phase 1 | `$SESSION_DIR/lanes/QD*/signals.json` | `/wf-fix-bugs` Phase 2 (aggregation) |
| `/wf-fix-bugs` (--engine=v6) Phase 2 | `$SESSION_DIR/issue-registry.json` (v2 schema) | `/wf-fix-triage` (v6 mode), `/wf-fix-execute` (v6 mode) |
| `/wf-fix-bugs` (--engine=v6) Phase 3 | `$SESSION_DIR/coverage-report.md` | User, `/wf-verify-sync` |
| `/wf-fix-bugs` (--engine=v6) Phase 0 | `$SESSION_DIR/fix-status.json` (engine_version: "v6") | `/wf-fix-triage` (detect mode), `/wf-fix-execute` (detect mode) |

### H7: Integration Tests (CRITICAL)

File: `.claude/skills/workflow/_shared/tests/test_e2e_stage_h.py`

Test cases:

1. **test_profile_resolver_loads**: `profile_resolver.py` load profiles.json → resolve đúng dims per profile
2. **test_v6_full_dispatch_7dims**: Dispatch all 7 dims on golden-v6 → issue-registry.json có entries cho ≥6 dims
3. **test_v6_profile_quick**: Profile quick → chỉ dispatch QD1+QD5, không dispatch QD2-QD4,QD6-QD7
4. **test_v6_safety_floor**: Profile standard + `--skip=QD1,QD2,QD5` → rejected (safety floor violation)
5. **test_v6_backward_compat**: `--engine=v5` → v5 flow không thay đổi, v6 modules không được load
6. **test_v6_cache_integration**: `--use-cache` → cache files cho non-QD3 dims, no cache for QD3
7. **test_v6_template_usage**: Coverage report + lane reports created từ templates (CORE-031)

**Target:** 442 existing + 7 new = 449 tests, 0 failures.

### H8: Final Regression (CRITICAL)

```bash
cd "z:/Working/MCV3/.claude/skills/workflow/_shared"
python -m pytest tests/ --tb=short
```

**Target:** 449+ tests, 0 failures, 0 regression.
Verify: no circular imports after new template/wiring code.

---

## File Summary

### Files to CREATE

| File | Mục đích |
|------|----------|
| `_shared/profiles.json` | Profile → dimensions mapping config (ADR-21) |
| `_shared/templates/lane-report.md` | Per-dimension report template |
| `_shared/templates/coverage-report.md` | Overall coverage report template |
| `_shared/templates/issue-registry-v2.json` | v2 issue schema template |
| `_shared/tests/test_e2e_stage_h.py` | Integration tests cho Stage H |

### Files to MODIFY

| File | Thay đổi |
|------|----------|
| `wf-fix-bugs/SKILL.md` | Thêm --engine=v5\|v6 flag, v6 execution flow |
| `wf-fix-bugs/_contract.json` | Thêm v6 output fields |
| `wf-fix-discover/SKILL.md` | Thêm v6 mode detection + lane dispatch integration |
| `../../rules/00-core.md` | Thêm v6 path entries vào §4b |

### Files KHÔNG thay đổi

| File | Lý do |
|------|-------|
| `_shared/probe_executor.py` | Stage G complete, stable |
| `_shared/lane_dispatch.py` | Stage F complete, stable |
| `_shared/signal_aggregator.py` | Stage F complete, stable |
| `_shared/signal_bus/` | Stage E complete, stable |
| `_shared/scan_cache/` | Stage E complete, stable |
| `wf-fix-*/dimension.json` (7 files) | Stage G complete, all 43 probes have tool.kind |

---

## Success Criteria

1. ✅ `/wf-fix-bugs --engine=v6` dispatches dimension lanes và generates issue-registry.json
2. ✅ Profile resolver loads profiles.json và resolves đúng dimensions per profile (ADR-21)
3. ✅ Safety floor enforcement: không được bỏ toàn bộ QD1+QD2+QD5 ở profile ≥ standard
4. ✅ `--engine=v5` flow hoàn toàn không thay đổi (backward compat)
5. ✅ Templates tạo đúng format outputs (CORE-031)
6. ✅ CORE-007 path contract updated với v6 entries
7. ✅ 449+ tests pass, 0 failures, 0 regression
8. ✅ No circular imports
