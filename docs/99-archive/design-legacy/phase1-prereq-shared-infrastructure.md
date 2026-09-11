# Phase 1 Prompt — Xây dựng hạ tầng `_shared/` cho Linear Workflow Skills

> **ADR reference:** `docs/design/skills/ADR-downstream-skills-optimization.md` §P0-PREREQ
> **Ngày:** 2026-04-23
> **Mục tiêu:** Bổ sung `_shared/` để 5 linear skills (brainstorm, analyze-req, define-features, design, design-ux) có thể import hạ tầng dùng chung.

---

## Context

`.claude/skills/workflow/_shared/` hiện có **121 files** phục vụ wf-fix-bugs v6:
- `isg/` — ISG recommender (signal analysis)
- `signal_bus/` — SignalBus dedup
- `concurrency/` — token bucket + backpressure
- `scan_cache/` — content-addressable cache (TTL 14d)
- `workload_estimator/` — workload estimation
- `ips/` — IPS 2-phase recommender cho wf-legacy-scan
- `impact_graph/` — impact graph builder
- Files loose: `lane_dispatch.py`, `signal_aggregator.py`, `profile_resolver.py`, `partition_planner.py`, `probe_executor.py`, `report_generator.py`
- `templates/` — 4 templates (coverage-report, fix-status, issue-registry-v2, lane-report)
- `tests/` — test suite
- `profiles.json` — 4 profiles cho wf-fix-bugs (QD-based)

**Vấn đề:** Các module hiện tại hardcode cho wf-fix-bugs (QD1-QD7 dimensions, fix-bugs specific schemas). Linear skills cần:
1. **Lane dispatch generic** (lanes theo department/system/feature, không phải QD)
2. **Profile system 3 cấp** cho linear authoring (quick/standard/deep, không phải QD-based)
3. **Partition planner generic** (group by arbitrary keys, không phải dimensions)
4. **Workload gate procedure** cho linear skills
5. **Signal aggregator generic** (dedup by arbitrary composite key, không phải file+line+dim)
6. **CDG handoff protocol** cho linear skills
7. **Cache adapter** cho content-hash based caching (dùng lại scan_cache nhưng adapt interface)
8. **Templates mới** (phase-summary.md, session-state.json, workload-report.md, lane-signal.json)
9. **_shared.md** protocol (template stripping + atomic write)

---

## Tasks

### Task 1: Tạo `profiles/` sub-package — Profile System cho Linear Skills

**Vị trí:** `.claude/skills/workflow/_shared/profiles/`

**Tạo files:**

1. `__init__.py` — exports `resolve_profile`, `validate_safety_floor`
2. `profiles.json` — 3 profiles cho linear skills:
```json
{
  "$schema": "linear-profiles-v1",
  "profiles": {
    "quick": {
      "description": "Overview nhanh — stubs/summary only",
      "depth_map": {
        "requirements": "summary",
        "features": "stub",
        "design": "outline",
        "ux": "wireframe"
      },
      "estimated_time_minutes": 15,
      "lanes_max_parallel": 2
    },
    "standard": {
      "description": "Đầy đủ — default, backward-compat với behavior hiện tại",
      "depth_map": {
        "requirements": "full",
        "features": "full",
        "design": "full",
        "ux": "full"
      },
      "estimated_time_minutes": 45,
      "lanes_max_parallel": 3
    },
    "deep": {
      "description": "Chi tiết — edge cases, compliance, a11y, animations",
      "depth_map": {
        "requirements": "deep",
        "features": "deep",
        "design": "deep",
        "ux": "deep"
      },
      "estimated_time_minutes": 90,
      "lanes_max_parallel": 3
    }
  },
  "safety_floor": {
    "rule": "production-bound projects PHẢI dùng standard hoặc deep",
    "applies_to": ["standard", "deep"]
  }
}
```
3. `profile_resolver.py` — Functions:
   - `resolve_profile(skill_name: str, cli_profile: str | None, recommendation: dict | None) -> str` — resolve final profile
   - `get_depth_for_phase(profile: str, skill_name: str, phase_key: str) -> str` — get depth map value
   - `validate_safety_floor(profile: str, is_production: bool) -> bool` — enforce safety floor
   - `estimate_time(profile: str) -> int` — return estimated minutes
4. `_contract.json` — version, exports, dependencies
5. `tests/test_profile_resolver.py` — unit tests

**Import từ:** Adapt logic từ `_shared/profile_resolver.py` hiện tại (QD-based) sang generic (skill-based).

### Task 2: Tạo `lane/` sub-package — Generic Lane Dispatch

**Vị trí:** `.claude/skills/workflow/_shared/lane/`

**Tạo files:**

1. `__init__.py` — exports `dispatch_lanes`, `LaneResult`
2. `dispatcher.py` — Generic lane dispatch:
   - `dispatch_lanes(lanes: list[LaneConfig], max_parallel: int = 3, timeout_sec: int = 300) -> list[LaneResult]`
   - `LaneConfig(key: str, agent_type: str, prompt: str, output_path: Path, context: dict)`
   - `LaneResult(key: str, status: str, output_path: Path, duration_ms: int, error: str | None)`
   - Dùng `asyncio.Semaphore(max_parallel)` cho concurrency control
   - Import `concurrency/token_bucket.py` cho backpressure
3. `schemas/lane-signal.schema.json` — JSON schema cho lane output:
```json
{
  "$schema": "lane-signal-v1",
  "type": "object",
  "required": ["lane_key", "lane_type", "items", "metadata"],
  "properties": {
    "lane_key": { "type": "string" },
    "lane_type": { "type": "string", "enum": ["department", "system", "feature-group", "spec-type", "role"] },
    "items": { "type": "array" },
    "metadata": {
      "type": "object",
      "properties": {
        "agent_type": { "type": "string" },
        "duration_ms": { "type": "integer" },
        "profile": { "type": "string" }
      }
    }
  }
}
```
4. `templates/lane-signal.json` — Template cho lane output
5. `_contract.json`
6. `tests/test_dispatcher.py` — unit tests

**Import từ:** Refactor logic từ `_shared/lane_dispatch.py` hiện tại (QD-specific) sang generic.

### Task 3: Tạo `partition/` sub-package — Generic Partition + Workload Gate

**Vị trí:** `.claude/skills/workflow/_shared/partition/`

**Tạo files:**

1. `__init__.py` — exports `plan_partitions`, `check_workload_gate`
2. `planner.py` — Generic partition planner:
   - `plan_partitions(items: list[dict], group_key: str, max_per_partition: int = 5) -> list[Partition]`
   - `estimate_workload(partitions: list[Partition], est_minutes_per_item: float = 3.0) -> WorkloadEstimate`
   - `Partition(items: list[dict], group_key: str, estimated_minutes: float)`
   - `WorkloadEstimate(total_minutes: float, partition_count: int, items_count: int, partitions: list[Partition])`
3. `workload_gate.py` — Gate logic:
   - `check_workload_gate(estimate: WorkloadEstimate, threshold_minutes: float) -> GateResult`
   - `GateResult(status: str, ratio: float, plan_a_options: list[str], plan_b_partitions: list[Partition] | None)`
   - Status: `"dead_zone"` (< 0.8), `"warn"` (0.8-1.5), `"block"` (> 1.5)
4. `workload-gate-procedure.md` — Markdown procedure cho SKILL.md reference:
   - Cách hiển thị estimate cho user
   - Plan A options: narrow scope / lower profile / override + CDG
   - Plan B: partition into sequential workloads
   - AskUserQuestion format
5. `schemas/workload-estimate.schema.json`
6. `templates/workload-estimate.json`
7. `_contract.json`
8. `tests/test_planner.py`, `tests/test_workload_gate.py`

**Import từ:** Adapt logic từ `_shared/partition_planner.py` + `_shared/workload_estimator/`.

### Task 4: Tạo `aggregate/` sub-package — Generic Signal Aggregator

**Vị trí:** `.claude/skills/workflow/_shared/aggregate/`

**Tạo files:**

1. `__init__.py` — exports `aggregate_lane_signals`, `dedup_key_fn`
2. `aggregator.py` — Generic aggregation:
   - `aggregate_lane_signals(lane_outputs: list[Path], dedup_key_fn: Callable) -> AggregationResult`
   - `dedup_key_fn(item: dict) -> str` — configurable dedup key function
   - Preset key functions: `dedup_by_id(id_field: str)`, `dedup_by_composite(fields: list[str])`
   - `AggregationResult(total_input: int, total_output: int, duplicates: int, conflicts: list[Conflict], items: list[dict])`
   - `Conflict(key: str, sources: list[str], items: list[dict])` — items trùng key từ nhiều lanes
3. `schemas/aggregation-result.schema.json`
4. `templates/aggregation-result.json`
5. `_contract.json`
6. `tests/test_aggregator.py`

**Import từ:** Refactor logic từ `_shared/signal_bus/signal_bus.py` (fix-bugs specific) sang generic.

### Task 5: Tạo `cdg/` sub-package — CDG Handoff Protocol

**Vị trí:** `.claude/skills/workflow/_shared/cdg/`

**Tạo files:**

1. `__init__.py` — exports `create_cdg_token`, `load_cdg_tokens`, `check_anti_loop`
2. `cdg_handler.py` — CDG token management:
   - `create_cdg_token(cdg_id: str, context: str, session_dir: Path) -> dict`
   - `load_cdg_tokens(session_dir: Path) -> list[dict]`
   - `check_anti_loop(cdg_id: str, tokens: list[dict], max_rejects: int = 2) -> str` — returns "ask" | "escalate"
   - `append_token(token: dict, session_dir: Path) -> None` — atomic append to cdg-tokens.json
3. `cdg-handoff-procedure.md` — Procedure cho SKILL.md reference:
   - Khi nào trigger CDG (per-skill CDG points)
   - AskUserQuestion format
   - Accept/reject handling
   - Anti-loop guard
4. `schemas/cdg-token.schema.json`
5. `templates/cdg-tokens.json`
6. `_contract.json`
7. `tests/test_cdg_handler.py`

### Task 6: Tạo `cache/` sub-package — Cache Adapter cho Linear Skills

**Vị trí:** `.claude/skills/workflow/_shared/cache/`

**Tạo files:**

1. `__init__.py` — exports `get_cached`, `set_cached`, `invalidate_cache`
2. `cache_adapter.py` — Adapter wrapping existing `scan_cache/`:
   - `get_cached(skill_name: str, content_hash: str, output_key: str) -> dict | None`
   - `set_cached(skill_name: str, content_hash: str, output_key: str, data: dict, ttl_days: int = 14) -> None`
   - `invalidate_cache(skill_name: str, content_hash: str | None = None) -> int` — returns count invalidated
   - `compute_content_hash(*file_paths: Path) -> str` — sha256 of concatenated file contents
3. `cache-types.md` — Document 2-tier: session (in-memory) + project (disk)
4. `_contract.json`
5. `tests/test_cache_adapter.py`

**Import từ:** Wrap `scan_cache/cache_lookup.py` + `scan_cache/cache_store.py` + `scan_cache/fingerprint.py`.

### Task 7: Tạo templates mới

**Vị trí:** `.claude/skills/workflow/_shared/templates/`

**Thêm files:**

1. `phase-summary.md` — CORE-028 template:
```markdown
# Phase Summary — {skill_name}

## Tổng quan
- Thời gian thực thi: {duration}
- Profile: {profile_used}
- Session: {session_id}
- Ngày: {timestamp}

{phase_sections}
```

2. `session-state.json` — Session isolation state schema:
```json
{
  "$schema": "session-state-v1",
  "session_id": "",
  "skill_name": "",
  "created_at": "",
  "updated_at": "",
  "status": "in_progress",
  "profile_used": "standard",
  "next_action": "",
  "phases": {},
  "cdg_decisions": [],
  "digests_produced": [],
  "lanes_completed": [],
  "errors": []
}
```

3. `workload-report.md` — Workload gate report template
4. `lane-signal.json` — Lane output template (cho linear skills)
5. `aggregation-result.json` — Aggregation result template

### Task 8: Tạo `_shared.md` — Protocol: Template Stripping + Atomic Write

**Vị trí:** `.claude/skills/workflow/_shared/_shared.md`

**Nội dung:**

```markdown
# Shared Protocol — Template Strip + Atomic Write

## 1. Template Metadata Stripping

Trước khi ghi digest/output file, xoá metadata fields:

\`\`\`bash
jq 'del(._template_notes, ._comments, ._examples, ._placeholder, ._description)' input.json > output.json
\`\`\`

Applied cho: mọi digest file trong Cross-Skill Output Path Contract (§4b CORE rules).

## 2. Atomic Write Pattern

\`\`\`bash
# Write to temp, validate, then atomic rename
jq '.' data.json > data.json.tmp && mv data.json.tmp data.json
\`\`\`

- tmp file trên cùng filesystem → `mv` atomic (POSIX)
- Nếu jq fail → tmp không move → data cũ nguyên vẹn
- Downstream đọc data.json → luôn thấy state consistent

## 3. Import Convention

Linear skills import _shared modules:
\`\`\`bash
SHARED_DIR="$(cd "$(dirname "$0")/../../workflow/_shared" && pwd)"
python3 "$SHARED_DIR/profiles/profile_resolver.py" --skill=wf-analyze-requirements --profile=standard
\`\`\`
```

### Task 9: Cập nhật `_shared/README.md`

**Vị trí:** `.claude/skills/workflow/_shared/README.md`

**Cập nhật:** Bổ sung §4+ cho linear skill modules:

```markdown
## 4. Linear Skill Modules (Phase 1 Addition — 2026-04-23)

| Module | Mục đích | ADR refs | Used by |
|--------|---------|---------|---------|
| `profiles/` | Profile system 3 cấp (quick/standard/deep) cho linear authoring | ADR-OPT-06 | analyze-req, define-features, design-ux |
| `lane/` | Generic lane dispatch (department/system/feature lanes) | ADR-OPT-01 | 5 skills |
| `partition/` | Generic partition planner + workload gate | ADR-OPT-03 | 4 skills (trừ brainstorm) |
| `aggregate/` | Generic signal aggregator + dedup | ADR-OPT-04 | 4 skills (trừ brainstorm) |
| `cdg/` | CDG handoff tokens + anti-loop | ADR-OPT-08 | 5 skills |
| `cache/` | Content-hash cache adapter | ADR-OPT-09 | 4 skills (trừ brainstorm) |

## 5. Dual-Audience

_shared/ phục vụ 2 nhóm skills:
- **wf-fix-* skills** (QD-based): dùng isg/, signal_bus/, scan_cache/ trực tiếp
- **wf-* linear skills** (department/system-based): dùng profiles/, lane/, partition/, aggregate/, cdg/, cache/ adapter

Không module nào xung đột — mỗi nhóm dùng sub-package riêng.
```

### Task 10: Cập nhật `pyproject.toml`

**Vị trí:** `.claude/skills/workflow/_shared/pyproject.toml`

**Cập nhật:** Bổ sung entry points cho CLI của new modules:
- `linear-profile-resolver` → `profiles.profile_resolver:main`
- `linear-lane-dispatcher` → `lane.dispatcher:main`
- `linear-partition-planner` → `partition.planner:main`
- `linear-aggregator` → `aggregate.aggregator:main`
- `linear-cdg-handler` → `cdg.cdg_handler:main`
- `linear-cache-adapter` → `cache.cache_adapter:main`

### Task 11: Chạy test suite hiện tại + mới

1. `cd .claude/skills/workflow/_shared && bash run-tests.sh` — verify không break existing tests
2. Chạy new tests cho 6 sub-packages mới
3. Verify import paths hoạt động: `python3 -c "from profiles.profile_resolver import resolve_profile"`

---

## Constraints

1. **KHÔNG sửa existing modules** (isg/, signal_bus/, concurrency/, scan_cache/, workload_estimator/, ips/, impact_graph/) — chỉ tạo mới hoặc thêm vào
2. **Python files dùng snake_case** (PEP 8) — JSON/MD/bash dùng kebab-case (CORE-016/017)
3. **Mọi Python module phải có _contract.json** — schema version, exports, dependencies
4. **Mọi template phải strip `_template_notes`** trước output — theo `_shared.md` protocol
5. **Tiếng Việt cho docs/comments, English cho code/names** (CORE-005)
6. **Registry role: NONE** cho toàn bộ _shared/ — không bao giờ ghi req-registry.json
7. **Unit tests bắt buộc** cho mỗi public function trong new modules

---

## Verify Checklist (POST-GATE)

| # | Check | Tier | Command |
|---|-------|------|---------|
| T1 | 6 new sub-packages tồn tại với `__init__.py` | Existence | `ls profiles/__init__.py lane/__init__.py ...` |
| T2 | Mỗi module có `_contract.json` với `"$schema"` | Structure | `jq '."$schema"' profiles/_contract.json` |
| T3 | Mỗi module có ít nhất 1 test file với ≥3 test cases | Content | `pytest tests/test_profile_resolver.py -v` |
| T4 | Existing test suite vẫn pass | Cross-ref | `bash run-tests.sh` |
| T5 | Import paths hoạt động từ outside _shared/ | Cross-ref | `python3 -c "import sys; sys.path.insert(0,'.'); from profiles.profile_resolver import resolve_profile"` |
| T6 | Templates không chứa `_template_notes` trong output sample | Content | `jq '.' templates/session-state.json \| jq 'has("_template_notes")'` → false |
| T7 | README.md updated với §4+§5 | Structure | `grep "ADR-OPT-06" README.md` |

---

## Success Criteria

- [ ] 6 sub-packages mới tạo: profiles/, lane/, partition/, aggregate/, cdg/, cache/
- [ ] 5 templates mới: phase-summary.md, session-state.json, workload-report.md, lane-signal.json, aggregation-result.json
- [ ] _shared.md protocol file tạo
- [ ] README.md updated
- [ ] pyproject.toml updated
- [ ] Existing tests pass (0 regression)
- [ ] New tests pass (≥18 test cases total, ≥3 per module)
- [ ] POST-GATE T1-T7 all pass
