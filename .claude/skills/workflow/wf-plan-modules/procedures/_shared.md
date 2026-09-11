# Shared Protocols — wf-plan-modules

> Cross-cutting protocols, state variables glossary, fix rules và reference data
> được sử dụng bởi nhiều Phase trong wf-plan-modules.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Fix Rules đặc thù](#fix-rules-đặc-thù)
- [Error Tracking](#error-tracking)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Registry Safe-Write](#registry-safe-write)
- [Token Limit Prevention](#token-limit-prevention)
- [Implementation Order Schema](#implementation-order-schema)
- [LEGACY_MODE Detection](#legacy_mode-detection)
- [Session Isolation Protocol (ADR-OPT-02)](#session-isolation-protocol-adr-opt-02)
- [_shared Module Imports (ADR-OPT Integration)](#_shared-module-imports-adr-opt-integration)
- [Phase→File Mapping](#phasefile-mapping)
- [Topological Lane Dispatch](#topological-lane-dispatch)

---

## State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt skill execution. AI cần nhớ phase nào set, phase nào read.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$SESSION_DIR` | Phase 0 (step 0.2b) | Tất cả phases | Đường dẫn đến session directory: `.mc-data/work/wf-plan-modules/sessions/{id}/` |
| `$SESSION_ID` | Phase 0 (step 0.2b) | 0, 0.5, 7a, 7c | Session ID dạng `{YYYYMMDD-HHMMSS}-{hash4}` |
| `$WORKLOAD_ESTIMATE` | Phase 0.5 | 0.5 POST-GATE | Estimated workload (phút) từ `workload_gate.py` |
| `$GATE_RESULT` | Phase 0.5 | 0.5 POST-GATE, SKILL.md route | `pass` / `warn` / `block` — quyết định của workload gate |
| `$LEGACY_MODE` | Phase 0 | 0, 1.5, 2, 4, 7.5 | Boolean — true nếu `project-context.md > 500 bytes` (CORE-021) |
| `$LEGACY_CONTEXT` | Phase 0 | 1.5, 4, 7 | Nội dung `project-context.md` (LEGACY) |
| `$LEGACY_GAP_CONTEXT` | Phase 0 | 4, 7 | Nội dung `gap-report.md` + `action-items.json` (LEGACY) |
| `$LEGACY_DECISIONS` | Phase 0 | 7.5 | Nội dung `legacy-decisions.json` (LEGACY) |
| `$DEPRECATED_MODULES` | Phase 0 | 7.5, 7a | Array module IDs có `action="DEPRECATE"` từ legacy-decisions |
| `$ARCH_DIGEST` | Phase 0.5 | 1, 7 | Architecture digest (design-input-digest.json) |
| `$UX_DIGEST` | Phase 0.5 | 7 | UX digest (ux-input-digest.json) — chỉ khi `interface_type != "api-only"` |
| `$MODULE_COUNT` | Phase 1 | 2, 4, mode select | Số modules trong registry |
| `$MODE` | Phase 1 | 2, 7 | `Simple` (1) / `Lite` (2) / `Full` (3+) |
| `$SYSTEM_COVERAGE_MAP` | Phase 1.7 | 7, 7.5.0, 7a | Array mỗi system có `{sys_id, name, modules_count, features_count, status}` |
| `$COVERAGE_STRATEGY` | Phase 1.7 | 7, 7.5.0, 7a | `full` / `placeholders` / `thin_clients` |
| `$USER_COVERAGE_DECISION` | Phase 1.7 | 7 | Quyết định user khi có orphan |
| `$FEATURE_IMPL_MAP` | Phase 1.5 | 7.5 | Array mỗi feature có `{feat_id, strategy, existing_code_refs, gaps_identified, effort_estimate}` (LEGACY) |
| `$DEP_MATRIX` | Phase 2 | 3, 4 | Map module → list of dependencies |
| `$HAS_CYCLE` | Phase 3 | 4 | Boolean — true nếu phát hiện circular dependency |
| `$LAYERS` | Phase 4 | 7, 7.5 | Array layers với `{layer, phase, modules[], parallel, sprint}` |
| `$TOPOLOGICAL_LEVELS` | Phase 4 | 7.5 | List các topological levels, mỗi level là list module slugs có thể parallel trong level đó — dùng cho Topological Lane Dispatch (ADR-OPT-01) |
| `$ASSIGNED` / `$TOTAL` | Phase 4 | 4 POST-GATE | Count modules đã assigned vs tổng |
| `$HAS_MVP_FLAG` | Phase 0 (parse args) | 5 | Boolean — true nếu `--mvp` |
| `$HAS_SKIP_SPRINTS_FLAG` | Phase 0 step 0.3 (parse args) | 7 (steps 7.6–7.7) | Boolean — true nếu `--skip-sprints`. Khi true, Phase 7 SKIP steps 7.6 và 7.7 (không tạo sprint files). Phase 7a check 7a.4 cũng SKIP khi flag này true. |
| `$MVP_SIZE` | Phase 5 | 5 POST-GATE | Số modules trong MVP scope |
| `$IMPACT_MODULE` | Phase 0 (parse args) | 6 | Module ID từ `--impact=<module>` |
| `$IMPACT_REPORT` | Phase 6 | 6 POST-GATE | Impact analysis report (in-memory) |
| `$PROJECT_TYPE` | Phase 0 | (display only) | `LEGACY` hoặc `STANDARD` |
| `error_log[]` | All phases | 7a | Array errors collected — dùng cho Auto-Correction Loop |

---

## Fix Rules đặc thù

| Loại lỗi | Auto-Fix | Escalate nếu |
|-----------|----------|---------------|
| File không tồn tại | Tạo file từ template/context | Không đủ context để tạo |
| File rỗng (size 0) | Re-run step tạo file | Vẫn rỗng sau retry |
| Module ID không tồn tại | Kiểm tra registry, fix ID | Module thực sự không có |
| Circular dependency | Break cycle theo priority | Ambiguous priority |
| JSON invalid | Fix syntax error | Structure corruption |
| Orphan reference | Remove orphan hoặc add missing module | Cannot determine intent |

> **Retry:** Mỗi step retry tối đa 3 lần. Nếu vẫn fail → escalate với thông báo đầy đủ.

---

## Error Tracking

`error_log[]` được duy trì xuyên suốt skill — append mỗi khi có error/warning. Phase 7a đọc và ghi vào `module-plan.md` report:

```json
{
  "phase": "7",
  "step": "7.5",
  "severity": "WARNING",
  "code": "E_MODULE_REF",
  "message": "Module MOD-XXX referenced trong sprint S02 không tồn tại trong registry",
  "auto_fix_applied": "Removed reference",
  "timestamp": "2026-04-19T10:30:00Z"
}
```

---

## Cross-Phase Data Flow

```
Phase 0 (init)         → $LEGACY_MODE, $LEGACY_*, $DEPRECATED_MODULES, $SESSION_DIR, $SESSION_ID
Phase 0.5 (workload-gate) → $WORKLOAD_ESTIMATE, $GATE_RESULT
Phase 0.5 (digest)     → $ARCH_DIGEST, $UX_DIGEST
Phase 1 (validate)     → $MODULE_COUNT, $MODE
Phase 1.7 (coverage)   → $SYSTEM_COVERAGE_MAP, $COVERAGE_STRATEGY
Phase 1.5 (legacy)     → $FEATURE_IMPL_MAP        [CHỈ LEGACY]
Phase 2 (deps)         → $DEP_MATRIX
Phase 3 (cycles)       → $HAS_CYCLE
Phase 4 (topo)         → $LAYERS, $TOPOLOGICAL_LEVELS
Phase 5 (mvp)          → $MVP_SCOPE               [CHỈ --mvp]
Phase 6 (impact)       → $IMPACT_REPORT           [CHỈ --impact]
Phase 7 (outputs)      → file outputs + registry update
Phase 7.5.0 (orphan)   → _NO-FEATURES.md          [CHỈ orphan]
Phase 7.5 (tasks)      → task files + A6-EXT + A7-EXT
Phase 7a (verify)      → fixes / error_log
Phase 7b (review)      → stakeholder-review.md
Phase 7c (summary)     → phase-summary.md + session log
```

**Quy tắc:** Mỗi phase chỉ READ variables đã được SET ở phase trước. KHÔNG được SET lại variables của phase khác.

**`$LAYERS` Re-hydration sau context reset (BẮT BUỘC — resume safety):**

Khi resume và `$LAYERS` không còn trong context (LLM context reset), Phase 7 và 7.5 PHẢI re-hydrate trước khi dùng:

```bash
# Re-hydrate $LAYERS từ file persist (Phase 4 step 4.4b)
IF test -s "$SESSION_DIR/topo-layers.json":
  LAYERS=$(jq -c '.layers' "$SESSION_DIR/topo-layers.json")
  Log: "Re-hydrated $LAYERS từ $SESSION_DIR/topo-layers.json ([N] layers)"
ELIF test -s ".mc-data/work/wf-plan-modules/topo-layers-fallback.json":
  LAYERS=$(jq -c '.layers' ".mc-data/work/wf-plan-modules/topo-layers-fallback.json")
  Log: "Re-hydrated $LAYERS từ fallback file"
ELSE:
  STOP: "Không tìm thấy $LAYERS — Phase 4 chưa hoàn tất. Chạy lại từ Phase 4."
```

Tương tự, `$DEP_MATRIX` (Phase 2) và `$TOPOLOGICAL_LEVELS` (Phase 4) nên được re-derive từ `topo-layers.json` hoặc re-run Phase 2-4 khi resume về Phase trước đó.

---

## Checkpoint Flush Rule

> Mọi phase PHẢI flush checkpoint xuống disk TRƯỚC khi return về SKILL.md để route sang phase tiếp (CORE-003, H4).

```
QUY TẮC:
1. Mỗi phase POST-GATE → update checkpoint.position.current_phase = "[next_phase]"
2. Write checkpoint.json (atomic: tmp + mv)
3. SAU ĐÓ mới return / route sang phase tiếp
4. Nếu checkpoint write fail → log warning → tiếp tục (không block execution)

Exception:
- Phase 0 (init) tạo checkpoint lần đầu — flush trong step 0.7
- Phase 7c (summary) flush final checkpoint — step 7c.3
```

---

## Registry Safe-Write

> **Protocol 5 — chi tiết:** xem `.claude/skills/protocols/` §5.

`/wf-plan-modules` CHỈ được update 2 fields trong `req-registry.json`:
- `implementation_order` (Phase 7) — full overwrite với canonical schema
- `impl_status` per REQ-ID (Phase 0/7.5) — **CHỈ set `"skipped"` cho features thuộc `$DEPRECATED_MODULES`**

```
QUY TẮC SAFE-WRITE:
1. ĐỌC registry NGAY TRƯỚC KHI GHI — không cache từ đầu session
2. CHỈ MODIFY 2 fields trên — giữ nguyên mọi fields khác
3. GHI ATOMIC — single write operation cho toàn bộ JSON
4. VALIDATE sau ghi — `jq '.' registry.json` phải pass
5. KHÔNG downgrade impl_status từ "done" → giá trị khác
   EXCEPTION: DEPRECATED modules → "skipped" được phép ghi đè mọi status
   (CORE-022 — explicit user decision từ wf-brainstorm Phase 0.5)
6. **[v3.2 — Cross-Process Mutex BẮT BUỘC]** ACQUIRE registry lock trước khi đọc-ghi
   để safe khi user có sessions wf-implement-feature/wf-verify-sync chạy song song.
```

### Cross-Process Mutex (BẮT BUỘC — Phase 7 Step 7.4)

> **Pattern shared với wf-implement-feature** — xem định nghĩa canonical tại
> `.claude/skills/workflow/wf-implement-feature/procedures/_shared.md §Cross-Process Mutex`.

```bash
# Phase 7 Step 7.4 (registry update) PHẢI bao bọc:
acquire_registry_lock() {
  local LOCK=".mc-data/docs/_meta/.registry.lock"
  local MY_PID=$$
  local TIMEOUT=30
  local STALE=300
  local START=$(date +%s)
  while true; do
    if ( set -C; echo "$MY_PID:$(date +%s)" > "$LOCK" ) 2>/dev/null; then return 0; fi
    if [ -f "$LOCK" ]; then
      local LOCK_INFO=$(cat "$LOCK" 2>/dev/null)
      local LOCK_PID=$(echo "$LOCK_INFO" | cut -d: -f1)
      local LOCK_TS=$(echo "$LOCK_INFO" | cut -d: -f2)
      local AGE=$(($(date +%s) - LOCK_TS))
      if [ "$AGE" -gt "$STALE" ] || ! kill -0 "$LOCK_PID" 2>/dev/null; then
        rm -f "$LOCK"; continue
      fi
    fi
    if [ $(($(date +%s) - START)) -gt "$TIMEOUT" ]; then
      echo "ERROR: Registry lock timeout. Holder: $LOCK_INFO" >&2; return 1
    fi
    sleep 0.5
  done
}
release_registry_lock() { rm -f ".mc-data/docs/_meta/.registry.lock"; }

# Usage trong Phase 7 Step 7.4:
acquire_registry_lock || exit 1
trap release_registry_lock EXIT
# ... read + jq narrow update + atomic mv ...
release_registry_lock
trap - EXIT
```

**QUY TẮC bổ sung:**
- Lock TIMEOUT = 30s. Nếu vượt → fail E_REGISTRY_LOCK_TIMEOUT, log holder PID
- Stale lock (>5min hoặc PID dead) → auto cleanup
- KHÔNG giữ lock qua agent spawn / I/O không cần thiết — release ngay sau atomic mv

---

## Token Limit Prevention

> **Protocol 6 — chi tiết:** xem `.claude/skills/protocols/` §6.

Áp dụng riêng cho wf-plan-modules:

| Phase | Tình huống | Strategy |
|-------|------------|----------|
| Phase 2 | Tổng feature files > 5 | Grep dependency keywords thay vì Read full files (Protocol 6.2) |
| Phase 7 | Registry update | Write trực tiếp — KHÔNG spawn agent (Protocol 6.1) |
| Phase 7.5 | Spawn architect/feature | Output size targets per agent context |
| Phase 7b | Spawn architect + qa-lead | Output size targets ~1500-2500 từ (architect), ~1000-1500 từ (qa-lead) |

**Context thresholds:**
- < 65% → tiếp tục
- 65-80% → chuẩn bị checkpoint
- 80-90% → SAVE checkpoint NGAY
- > 90% → FORCE STOP, prompt `--resume`

---

## Implementation Order Schema

LUÔN dùng format này khi ghi `implementation_order` vào registry:

```json
{
  "implementation_order": {
    "layers": [
      {
        "layer": 0,
        "phase": "Foundation",
        "modules": ["MOD-AUTH"],
        "parallel": false,
        "sprint": "S01"
      },
      {
        "layer": 1,
        "phase": "Core",
        "modules": ["MOD-CRM", "MOD-HR"],
        "parallel": true,
        "sprint": "S02"
      }
    ],
    "critical_path": ["MOD-AUTH", "MOD-CRM", "MOD-ORDERS"],
    "total_sprints": 3,
    "total_layers": 2
  }
}
```

**Required fields:**
- Mỗi `layer` object: `layer` (int), `phase` (string), `modules` (array), `parallel` (bool), `sprint` (string)
- Top-level: `layers`, `critical_path`, `total_sprints`, `total_layers`

---

## LEGACY_MODE Detection

Theo CORE-021 (BẮT BUỘC):

```bash
LEGACY_MODE=$(test -f .mc-data/work/legacy-scan/project-context.md \
  && test $(wc -c < .mc-data/work/legacy-scan/project-context.md) -gt 500 \
  && echo "true" || echo "false")
```

**KHÔNG** detect bằng `ledger.json` (false positive — tồn tại từ Stage 0.5).
**KHÔNG** detect bằng check khác giữa các skills.

Khi `LEGACY_MODE = true`:
- Phase 0 đọc thêm: `project-context.md`, `gap-report.md`, `action-items.json`, `legacy-decisions.json`
- Phase 1.5 chạy (Feature-Level Code Status)
- Phase 7.5 inject Implementation Strategy section vào mỗi task file
- Phase 7.5 KHÔNG tạo task file cho features thuộc `$DEPRECATED_MODULES`

Graceful degradation (CORE-022): nếu `legacy-decisions.json` không tồn tại → `$DEPRECATED_MODULES = []`, tiếp tục bình thường.

---

## Session Isolation Protocol (ADR-OPT-02)

Mỗi lần chạy `wf-plan-modules` tạo một session directory riêng biệt — tránh ghi đè dữ liệu giữa các lần chạy.

### Session Directory Structure

```
.mc-data/work/wf-plan-modules/sessions/{YYYYMMDD-HHMMSS}-{hash4}/
├── session-state.json           ← Trạng thái toàn session (phases, next_action)
├── planmod-status.json          ← Status file (mirror of root-level)
├── checkpoint.json              ← Checkpoint 3-level
├── workload-report.md           ← Phase 0.5 output
├── aggregation-result.json      ← Phase 7a aggregated signals
├── feature-impl-map.json        ← LEGACY only: $FEATURE_IMPL_MAP persist
└── lanes/
    ├── L0/                      ← Topological level 0 (leaf modules, no deps)
    │   ├── {module-slug}/
    │   │   └── signals.json     ← Lane output per module
    │   └── ...
    ├── L1/                      ← Level 1 (modules depend on L0)
    │   └── ...
    └── ...
phase-summary.md                 ← Phase summary (root-level, CORE-028)
```

**Latest pointer:** `.mc-data/work/wf-plan-modules/latest` → symlink/file ghi path của session hiện tại.

**Cleanup rule:** Giữ tối đa 5 sessions gần nhất — xóa session cũ khi tạo session mới nếu vượt 5.

### 3-Level Checkpoint Schema

```json
{
  "session_id": "20260423-143000-a1b2",
  "phases": {
    "P0":   { "status": "completed" },
    "P0_5": { "status": "completed", "gate_result": "pass", "estimated_minutes": 32 },
    "P1":   { "status": "completed" },
    "P7_5": {
      "status": "in_progress",
      "batches": {
        "L0-auth":     { "status": "completed", "items": { "FEAT-AUTH-001": "completed" } },
        "L1-crm":      { "status": "in_progress", "items": { "FEAT-CRM-001": "pending" } }
      }
    }
  },
  "next_action": "phase7.5",
  "position": { "current_phase": "phase_7.5", "topological_level": 1 }
}
```

**Checkpoint levels:**
- **L1 Phase:** `phases.P{N}.status` — trạng thái toàn phase
- **L2 Batch:** `phases.P{N}.batches[{level}-{module}].status` — trạng thái per module lane
- **L3 Item:** `phases.P{N}.batches[{level}-{module}].items[{task}].status` — trạng thái per task

---

## _shared Module Imports (ADR-OPT Integration)

Các module Python trong `.claude/skills/workflow/_shared/` được import theo phase:

| Module | Phase sử dụng | Chức năng |
|--------|--------------|-----------|
| `_shared/partition/planner.py` | Phase 0.5 | `plan_partitions()` — chia modules thành partitions |
| `_shared/partition/workload_gate.py` | Phase 0.5 | `estimate_workload()`, `check_workload_gate()` |
| `_shared/lane/dispatcher.py` | Phase 7.5 | `dispatch_lanes()` — Topological Lane Dispatch |
| `_shared/aggregate/aggregator.py` | Phase 7a | `aggregate_lane_signals()` — dedup + merge signals |
| `_shared/cache/cache.py` | Phase 0.5 | Cache DAG preview results |
| `_shared/cdg/cdg.py` | Phase 0.5 (block zone) + Phase 7a (downgrade) | CDG acknowledgement flow |

**Template files (_shared/templates/):**
- `_shared/templates/session-state.json` — session state schema
- `_shared/templates/workload-report.md` — workload gate report
- `_shared/templates/lane-signal.json` — per-lane output schema
- `_shared/templates/aggregation-result.json` — aggregated signals schema

---

## Phase→File Mapping

| Phase | File | Mô tả |
|-------|------|-------|
| Phase 0 | `phase0-init.md` | Context loading + session init + resume check |
| Phase 0.5 | `phase0.5-workload-gate.md` | Workload gate (ADR-OPT-03) |
| Phase 1 | `phase1-validate.md` | Registry validation |
| Phase 1.5 | `phase1.5-legacy-impl.md` | LEGACY only — CORE-019 feature-level code verification |
| Phase 2 | `phase2-deps.md` | Dependency analysis |
| Phase 3 | `phase3-cycles.md` | Circular dependency detection |
| Phase 4 | `phase4-topo.md` | Topological sort → $LAYERS, $TOPOLOGICAL_LEVELS. Step 4.4b persist $LAYERS → `$SESSION_DIR/topo-layers.json` |
| Phase 5 | `phase5-mvp.md` | MVP scope identification |
| Phase 6 | `phase6-impact.md` | Impact analysis |
| Phase 7 | `phase7-outputs.md` | Generate module-plan + dependency-graph + roadmap + sprints |
| Phase 7.5.0 | `phase7.5.0-orphan.md` | Orphan systems placeholder |
| Phase 7.5 | `phase7.5-tasks.md` | Task generation per feature (primary lane phase) |
| Phase 7a | `phase7a-verify.md` | Signal Aggregation + verify + auto-correction loop |
| Phase 7b | `phase7b-review.md` | Stakeholder review |
| Phase 7c | `phase7c-summary.md` | Phase summary + session close |

**Phase Ordering (Standard):** `0 → 0.5 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 7.5.0 → 7.5 → 7a → 7b → 7c`

**Phase Ordering (LEGACY):** `0 → 0.5 → 1 → 1.5 → 2 → 3 → 4 → 5 → 6 → 7 → 7.5.0 → 7.5 → 7a → 7b → 7c`

---

## Topological Lane Dispatch

Phase 7.5 dispatch lanes theo **topological order** từ `$TOPOLOGICAL_LEVELS` (set bởi Phase 4):

```
1. Đọc $TOPOLOGICAL_LEVELS từ Phase 4 output.
   Format: [[mod-auth, mod-config], [mod-crm, mod-hr], [mod-orders]]
   (mỗi inner list = 1 level, các modules trong cùng level có thể parallel)

2. For each level L (L0, L1, L2, ...):
   a. Build LaneConfig list cho tất cả modules trong level L:
      LaneConfig(
        key       = "{module-slug}",
        agent_type = "architect",
        prompt    = task generation template (từ _shared.md §Task Generation Template),
        output_path = $SESSION_DIR/lanes/L{L}/{module-slug}/signals.json,
        context   = {
          module_features: features thuộc module này,
          dependencies: dep list từ Phase 4,
          FEATURE_IMPL_MAP: $FEATURE_IMPL_MAP[module] (chỉ LEGACY),
          sprint_allocation: sprint assignment từ Phase 5
        }
      )

   b. dispatch_lanes(lanes, max_parallel=$LPM_PARAMS.max_parallel_agents, timeout_sec=600)

   c. WAIT for ALL lanes in level L to complete
      (enforce topological invariant: L+1 KHÔNG bắt đầu trước L hoàn tất)

   d. Per-level partial aggregation: merge signals từ level L vào running total
      (phòng ngừa context overflow ở dự án lớn có nhiều levels)

3. Final aggregation sau khi all levels done → Phase 7a signal aggregator.
```

**Rationale:** Module ở level L+1 có thể cần task output của level L làm context (do có dependency). Sequential giữa levels đảm bảo context chính xác.

**Write-scope isolation:** Mỗi module lane ghi output riêng vào `$SESSION_DIR/lanes/L{level}/{module-slug}/` — không conflict.
