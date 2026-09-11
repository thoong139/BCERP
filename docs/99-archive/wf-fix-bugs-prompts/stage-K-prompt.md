# Stage K Prompt — Contract Sync: _contract.json v6 Outputs + 00-core.md Path Contract Update

## Context

Stage J hoàn tất (PASS). ISG Recommender Integration + Workload Partition Planner + Engine v6 Orchestrator Wiring thành công:
- **partition_planner.py** tạo mới tại `_shared/partition_planner.py` — `partition_dimensions()` chia dims → workloads theo ISG guidance hoặc default priority strategy
- **signal_aggregator.py** cập nhật v2 schema fields — `dimensions_run`, `dimensions_with_issues`, `dimensions_without_issues`, `coverage_rate_pct`, `dedup_ingested`, `dedup_deduplicated`
- **wf-fix-bugs SKILL.md** cập nhật v6 PRE-GATE — thêm resolve_dimensions → ISG → partition → dispatch wiring
- **wf-fix-discover SKILL.md** cập nhật v6 POST-GATE — thêm report generation (lane reports + coverage report)
- **wf-fix-discover procedures/phase0-init.md** cập nhật — thêm v6 Engine Dispatch block (Steps V6.1-V6.7)
- **12 new tests** trong `test_e2e_stage_j.py`, tất cả pass
- **492 tests total**, 0 failures, 0 regression

### Trạng thái kiến trúc sau Stage J

```
_shared/                           ✅ COMPLETE — shared services layer + config
├── signal_bus/                    ✅ Signal Bus (emit, validate, dedup)
├── scan_cache/                    ✅ Scan Cache (fingerprint, TTL, QD3 never cached)
├── probe_executor.py              ✅ Probe execution (grep/agent/runtime → Signal v2)
├── lane_dispatch.py               ✅ Lane dispatch (cache integration, parallel)
├── signal_aggregator.py           ✅ Aggregation v2 (lanes → issue-registry.json + v2 schema fields)
├── dimension_registry.py          ✅ Dimension registry (metadata, cache policy)
├── profile_resolver.py            ✅ Profile → probe + dimension resolver
├── report_generator.py            ✅ Lane + coverage report generation từ templates
├── partition_planner.py           ✅ Partition dimensions → workloads (ISG-guided + priority-based)
├── read_trace.py                  ✅ Code tracing
├── isg/                           ✅ ISG recommender (core logic)
├── impact_graph/                  ✅ Impact graph builder
├── workload_estimator/            ✅ Workload estimation (core logic)
├── concurrency/                   ✅ Backpressure + token bucket
├── profiles.json                  ✅ Profile config (ADR-21 locked defaults)
├── templates/                     ✅ 3 v6 output templates (CORE-031)
└── tests/                         ✅ 492 tests (463 base + 17 Stage I + 12 Stage J)

wf-fix-functional/                 ✅ QD1 — dimension.json + 7 probe .md files
wf-fix-business/                   ✅ QD2 — dimension.json + 5 probe .md files
wf-fix-security/                   ✅ QD3 — dimension.json + 7 probe .md files
wf-fix-performance/                ✅ QD4 — dimension.json + 6 probe .md files
wf-fix-ux-a11y/                    ✅ QD5 — dimension.json + 7 probe .md files
wf-fix-data/                       ✅ QD6 — dimension.json + 6 probe .md files
wf-fix-compat/                     ✅ QD7 — dimension.json + 5 probe .md files

wf-fix-bugs/                       ✅ Orchestrator v6 flow (resolve → ISG → partition → dispatch)
wf-fix-discover/                   ✅ v6 mode dispatch + report generation
wf-fix-triage/                     ✅ v6 mode + v2 schema documented
wf-fix-execute/                    ✅ v6 mode for verify + report documented
```

### What's Missing (Gap Analysis)

Stage J wired ISG + partition planner + v6 dispatch. Stage K ensures **contract consistency** —
all _contract.json files reflect v6 outputs, and `00-core.md §4b` path contract is complete:

```
GAPS:
1. wf-fix-discover/_contract.json chưa có v6 output entries:
   - $SESSION_DIR/lanes/QD*/signals.json (v6 dispatch output)
   - $SESSION_DIR/coverage-report.md (v6 report generation)
   - $SESSION_DIR/lanes/QD*/lane-report.md (v6 per-dimension report)
   - $SESSION_DIR/issue-registry.json v2 schema note
2. wf-fix-discover/_contract.json chưa có v6 cross-skill produces_for entries cho wf-fix-bugs v6 mode
3. 00-core.md §4b chưa có path entries cho:
   - wf-fix-discover v6 → coverage-report.md
   - wf-fix-discover v6 → lanes/QD*/lane-report.md
   - partition_planner → workloads/$WORKLOAD_ID/fix-workload.json (Stage J tạo partition_planner nhưng path contract chưa update)
4. wf-fix-bugs/_contract.json outputs.working[] đã có v6 entries (Stage H) — cần verify chỉ redirect đúng
5. wf-fix-triage/_contract.json + wf-fix-execute/_contract.json — cần check v6 fields present
```

---

## Stage K: Contract Sync + Path Contract Update

### Mục tiêu

Đồng bộ hóa tất cả `_contract.json` files với Stage J changes và update `00-core.md §4b` path contract:

1. Update `wf-fix-discover/_contract.json` — thêm v6 output entries + cross-skill refs
2. Verify `wf-fix-bugs/_contract.json` — confirm v6 outputs present và consistent
3. Verify `wf-fix-triage/_contract.json` + `wf-fix-execute/_contract.json` — v6 fields
4. Update `00-core.md §4b` — thêm path entries cho v6 dispatch outputs
5. Validate tất cả contracts via `validate-schema-sync.sh`

### Key Constraints

1. **Chỉ update contracts + path docs** — KHÔNG thay đổi code logic hay test files
2. **CORE-007**: Path contract — outputs phải khớp với cross-skill contract table
3. **CORE-031**: Template Usage Rule — _contract.json outputs.working[].template phải trỏ đúng template path
4. **Không regression**: KHÔNG sửa .py files, chỉ .json + .md contracts
5. **Backward compat**: v5 entries không được xóa hay modify, chỉ thêm v6 entries
6. **Schema validation**: Mỗi _contract.json phải pass `$schema: "skill-contract-v1"` validation

---

## Tasks

### K1: Update wf-fix-discover/_contract.json — v6 outputs (CRITICAL)

File: `.claude/skills/workflow/wf-fix-discover/_contract.json`

Thêm vào `outputs.working[]`:

```json
{
  "path": "$SESSION_DIR/lanes/QD*/signals.json",
  "required": false,
  "template": null,
  "condition": "engine_version == 'v6' in fix-status.json",
  "notes": "v6 only — Per-dimension signal output, dynamically created per resolved profile. Created by v6 dispatch (lane_dispatch.py)."
},
{
  "path": "$SESSION_DIR/coverage-report.md",
  "required": false,
  "template": "../../_shared/templates/coverage-report.md",
  "condition": "engine_version == 'v6' in fix-status.json",
  "notes": "v6 only — Dimension coverage summary. READ template → POPULATE stats → WRITE. CORE-031 compliance."
},
{
  "path": "$SESSION_DIR/lanes/QD*/lane-report.md",
  "required": false,
  "template": "../../_shared/templates/lane-report.md",
  "condition": "engine_version == 'v6' in fix-status.json",
  "notes": "v6 only — Per-dimension lane report. READ template → POPULATE dimension data → WRITE. CORE-031 compliance."
}
```

Thêm vào `cross_skill_contracts.produces_for.wf-fix-bugs[]`:
- `$SESSION_DIR/lanes/QD*/signals.json (v6 mode dispatch output)`
- `$SESSION_DIR/coverage-report.md (v6 mode coverage report)`
- `$SESSION_DIR/lanes/QD*/lane-report.md (v6 mode per-dimension report)`

Cập nhật `cross_skill_contracts.returns_to.provides[]` — thêm v6 outputs khi engine_version == "v6".

Cập nhật `version` từ `"2.5.1"` → `"2.6.0"` (minor version bump cho v6 output additions).

### K2: Verify wf-fix-bugs/_contract.json v6 consistency (HIGH)

File: `.claude/skills/workflow/wf-fix-bugs/_contract.json`

Kiểm tra (READ-ONLY, chỉ verify):
- `outputs.working[]` đã có 4 v6 entries: lanes/QD*/signals.json, issue-registry.json v2, coverage-report.md, lanes/QD*/lane-report.md ✅ (Stage H thêm)
- `inputs[]` đã có --engine, --dims, --profile ✅ (Stage H thêm)
- `cross_skill_contracts.consumes_from.wf-fix-discover[]` phải match wf-fix-discover v6 produces

Nếu consumes_from entries thiếu v6 paths → thêm. Nhưng Stage J verified SKILL.md đã wire đúng,
nên task này chủ yếu là confirm.

### K3: Verify wf-fix-triage/_contract.json + wf-fix-execute/_contract.json (MEDIUM)

Files:
- `.claude/skills/workflow/wf-fix-triage/_contract.json`
- `.claude/skills/workflow/wf-fix-execute/_contract.json`

Kiểm tra (READ-ONLY, chỉ verify):
- wf-fix-triage: `inputs[]` có cần thêm v6 fields? (engine_version detection flag, dims list?)
  - Nếu triage cần biết v6 mode → thêm input hoặc note
- wf-fix-execute: tương tự — verify v6 mode detection documented trong contract

Nếu cần update → update. Nếu đã ổn → chỉ ghi nhận trong output.

### K4: Update 00-core.md §4b path contract (CRITICAL)

File: `.claude/rules/00-core.md`

Trong bảng `### 4b. Cross-Skill Output Path Contract`, thêm các entries:

```
| `/wf-fix-discover` v6 Engine Dispatch | `$SESSION_DIR/lanes/QD*/signals.json` | `/wf-fix-bugs` Phase 2 aggregation (signal sources) |
| `/wf-fix-discover` v6 Report Generation | `$SESSION_DIR/coverage-report.md` | User, `/wf-verify-sync` |
| `/wf-fix-discover` v6 Report Generation | `$SESSION_DIR/lanes/QD*/lane-report.md` | User |
| `/wf-fix-discover` v6 Dispatch (via partition_planner) | `$SESSION_DIR/issue-registry.json` (v2 schema — dimensions_run, coverage, dedup_stats fields) | `/wf-fix-triage` (v6 mode), `/wf-fix-execute` (v6 mode) |
```

QUAN TRỌNG: 00-core.md đã có sẵn một số v6 path entries từ Stage H (xem trong bảng hiện tại).
Kiểm tra trùng lặp TRƯỚC khi thêm — chỉ thêm entries thực sự mới.

### K5: Validate contracts via schema sync (CRITICAL)

```bash
cd "z:/Working/MCV3"
./.claude/scripts/validate-schema-sync.sh wf-fix-discover
./.claude/scripts/validate-schema-sync.sh wf-fix-bugs
./.claude/scripts/validate-schema-sync.sh wf-fix-triage
./.claude/scripts/validate-schema-sync.sh wf-fix-execute
```

Nếu script báo lỗi → fix cho đến khi PASS.

Verify tất cả _contract.json files là valid JSON:
```bash
cd "z:/Working/MCV3/.claude/skills/workflow"
jq '.' wf-fix-discover/_contract.json > /dev/null && echo "discover: OK"
jq '.' wf-fix-bugs/_contract.json > /dev/null && echo "bugs: OK"
jq '.' wf-fix-triage/_contract.json > /dev/null && echo "triage: OK"
jq '.' wf-fix-execute/_contract.json > /dev/null && echo "execute: OK"
```

---

## File Summary

### Files to MODIFY

| File | Thay đổi |
|------|----------|
| `wf-fix-discover/_contract.json` | Thêm 3 v6 output entries + cross-skill refs, bump version → 2.6.0 |
| `00-core.md` §4b | Thêm v6 path contract entries (kiểm tra trùng trước khi thêm) |

### Files to VERIFY (read-only)

| File | Mục đích |
|------|----------|
| `wf-fix-bugs/_contract.json` | Confirm v6 outputs already present |
| `wf-fix-triage/_contract.json` | Check v6 mode fields |
| `wf-fix-execute/_contract.json` | Check v6 mode fields |

### Files KHÔNG thay đổi

| File | Lý do |
|------|-------|
| Tất cả `.py` files | Stage K chỉ update contracts |
| `_shared/tests/` | Không thêm/sửa tests |
| `wf-fix-*/SKILL.md` | Stage J đã update |
| `wf-fix-*/procedures/` | Stage J đã update |

---

## Success Criteria

1. ✅ `wf-fix-discover/_contract.json` có v6 output entries (signals, coverage-report, lane-report)
2. ✅ `wf-fix-bugs/_contract.json` v6 outputs verified consistent với discover contract
3. ✅ `wf-fix-triage/_contract.json` + `wf-fix-execute/_contract.json` v6 fields verified
4. ✅ `00-core.md §4b` có path entries cho tất cả v6 dispatch outputs (không trùng lặp)
5. ✅ Tất cả 4 _contract.json pass `jq '.'` validation
6. ✅ `validate-schema-sync.sh` PASS cho cả 4 skills
7. ✅ Không có code file nào bị thay đổi
