# Phase 3 — ADR-OPT Rollout: `wf-plan-modules` (Skill 4/4)

> **Tạo:** 2026-04-23
> **Mục đích:** Prompt-ready checklist cho phiên rollout — bump `wf-plan-modules` lên v3.0.0 với 5 ADR-OPT techniques.
> **Prerequisite:** `phase3-wf-design-ux.md` DONE + V1-V10 PASS + đọc `phase3-rollout-design-principles.md` (Variable Map §3.4).
> **Output của phiên này:** SKILL.md v3.0.0 + _contract.json v3.0.0 + 6-7 procedure files updated/created.

---

## Context (đọc trước khi bắt đầu)

`wf-plan-modules` là skill **cuối** trong 4 rollout — phụ thuộc kết quả của 3 skill trước. Skill này có **đặc thù**:
- Chạy theo **topological order** từ dependency DAG (không phải parallel per-system như `wf-design`).
- Có **14 procedure files** (nhiều nhất trong 5 linear skills).
- LEGACY mode có Phase 1.5 `CORE-019 feature-level code verification` — không lane-ify.
- Phase 7.5 task generation là primary lane phase — task breakdown per module.

**Current state (từ `_contract.json` + `procedures/` listing — 2026-04-23):**
- SKILL.md: v1.7.0
- _contract.json: v1.7.1
- Procedures (14 files + _shared.md):
  - `_shared.md`
  - `phase0-init.md`
  - `phase1-validate.md` (registry validation)
  - `phase1.5-legacy-impl.md` (LEGACY only — CORE-019 feature-level code verification)
  - `phase2-deps.md` (dependency analysis)
  - `phase3-cycles.md` (circular dependency detection)
  - `phase4-topo.md` (topological sort — tạo LAYERS)
  - `phase5-mvp.md` (MVP scope identification)
  - `phase6-impact.md` (impact analysis)
  - `phase7-outputs.md` (generate module-plan.md + dependency-graph.md + roadmap + sprints — output phase primary)
  - `phase7.5.0-orphan.md` (orphan systems placeholder)
  - `phase7.5-tasks.md` (task generation per feature — primary lane phase)
  - `phase7a-verify.md` (verify + registry update)
  - `phase7b-review.md` (stakeholder review)
  - `phase7c-summary.md` (phase summary + digest output Phiên 6)

**Target state:** v3.0.0 (skip 2.x theo plan gốc — major bump trực tiếp để align minor band). `registry_scope.fields_owned` UNCHANGED = `["implementation_order", "impl_status"]`.

**Key references:**
- Design principles: `docs/design/skills/phase3-rollout-design-principles.md` §3.4
- ADR đầy đủ: `docs/design/skills/ADR-downstream-skills-optimization.md`
- CORE-019 feature-level code verification: `.claude/rules/00-core.md §4c`
- CORE-020 Pre-Implementation Safety Gate: `.claude/rules/00-core.md §4d`
- _shared protocol: `.claude/skills/workflow/_shared/_shared.md`

---

## Decision Log — Skill: `wf-plan-modules`

| Field | Value | Rationale |
|-------|-------|-----------|
| Current version | 1.7.1 | Từ `_contract.json` (phase-per-file refactor 2026-04-19) |
| Target version | **3.0.0** | Skip 2.x theo plan gốc để align minor band với các linear skills; breaking phase structure change |
| Lane type | **module-lane theo topological DAG** | Chạy topological order — mỗi level trong DAG có thể parallel |
| Lane key format | `{module-slug}` | Module là đơn vị task generation |
| Partition grouping | `group_key="topological_level"`, `max_per_partition = 5` per level | Song song trong cùng level, sequential giữa levels |
| Workload `est_minutes_per_item` | **8.0** | Task breakdown + implementation_strategy + sprint allocation mỗi module |
| Workload factor | 1.0 normal, 1.5 LEGACY, 2.0 nếu cross-module dependencies phức tạp (>3 dep per module trung bình) | LEGACY cần Phase 1.5 code verification; cross-deps phức tạp → nhiều ripple |
| Dedup key | `task_id` (TASK-ID) | Conflict khi shared task across modules (rare, flag for review) |
| Aggregation conflict | Shared task → flag cho Phase 7a verify (dependency review) | Shared task có thể valid (shared infrastructure) hoặc bug (duplicate work) |
| Conditional phases (skip triggers) | Phase 1.5 legacy-impl chỉ LEGACY_MODE (giữ nguyên) | KHÔNG lane-ify Phase 1.5 — sequential code verification |
| Expert dispatch phase file | `phase7.5-tasks.md` | Primary lane phase — task generation per feature trong module |
| Consolidate phase file | `phase7a-verify.md` | Signal Aggregation + verify dependencies |
| Handoff phase file | `phase7-outputs.md` + `phase7c-summary.md` | Outputs phase tạo nhiều files; Phase 7c tạo digest summary |
| Breaking change risk | **HIGH** | Downstream `wf-implement-feature` đọc nhiều outputs (module-plan, dependency-graph, sprints, tasks) — schema UNCHANGED nhưng session path mới có thể break path resolution |

---

## Tasks (thực hiện theo thứ tự)

### Task 1: Tạo `procedures/phase0.5-workload-gate.md` (MỚI)

**Vị trí:** `.claude/skills/workflow/wf-plan-modules/procedures/phase0.5-workload-gate.md`

**Nội dung:**

```
PRE-GATE: Phase 0 POST-GATE PASS
INPUT: $REGISTRY_DATA (modules, features, dependencies từ feature-briefs + design-input-digest), LEGACY_MODE flag
OUTPUT: sessions/{id}/workload-report.md

Steps:
| Step | Action | Verify |
|------|--------|--------|
| 0.5.1 | Build initial DAG preview (chỉ counting dependencies, chưa full topological sort). Import _shared/partition/planner.py → plan_partitions(items=$ACTIVE_MODULES, group_key="module", max_per_partition=5) | Partitions generated |
| 0.5.2 | Import _shared/partition/workload_gate.py → estimate_workload(partitions, est_minutes_per_item=8.0). Factor: ×1.0 normal, ×1.5 LEGACY_MODE (cần Phase 1.5), ×2.0 nếu avg dependencies_per_module > 3 | WorkloadEstimate calculated |
| 0.5.3 | check_workload_gate(estimate, threshold_minutes=45). Ratio = estimated/45 | GateResult obtained |
| 0.5.4 | IF dead_zone (<0.8) → silent continue. IF warn (0.8-1.5) → AskUserQuestion. IF block (>1.5) → Plan A/B menu (narrow MVP scope / override+CDG-A02 / partition per topological level sequential) | User decision recorded |
| 0.5.5 | WRITE workload-report.md từ template _shared/templates/workload-report.md | test -s workload-report.md |
| 0.5.6 | Update session-state.json: phases.P0_5.status, next_action = "phase1-validate" | State persisted |

POST-GATE: Workload estimate recorded, user acknowledged (if WARN/BLOCK).
Next phase: phase1-validate.md
```

**Lưu ý đặc thù:**
- Workload estimate dùng **initial DAG preview**, không phải full topological sort (chưa có ở Phase 0.5). Đủ chính xác để gate.
- Full topological sort diễn ra ở Phase 4 — khi đó partitions được re-compute theo level.

---

### Task 2: Cập nhật `procedures/_shared.md`

**Vị trí:** `.claude/skills/workflow/wf-plan-modules/procedures/_shared.md`

**Thay đổi cần thực hiện:**

1. **Thêm 4 state variables** chuẩn: `$SESSION_DIR`, `$SESSION_ID`, `$WORKLOAD_ESTIMATE`, `$GATE_RESULT`.

2. **Thêm 2 state variables đặc thù:**
   - `$TOPOLOGICAL_LEVELS` — Set by Phase 4, Read by Phase 7.5 — list of levels, mỗi level là list modules có thể parallel.
   - `$FEATURE_IMPL_MAP` — Set by Phase 1.5 (LEGACY), Read by Phase 7.5 — map feature → {strategy, existing_code_refs, gaps}.

3. **Phase→File Mapping:**
   - `| Phase 0.5 | phase0.5-workload-gate.md | Workload gate (ADR-OPT-03) |`

4. **Phase Ordering:**
   - New: `0 → 0.5 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 7.5.0 → 7.5 → 7a → 7b → 7c`
   - Legacy: `0 → 0.5 → 1 → 1.5 → 2 → 3 → 4 → 5 → 6 → 7 → 7.5.0 → 7.5 → 7a → 7b → 7c`

5. **Thêm section `## Session Isolation Protocol (ADR-OPT-02)`:**
   ```
   sessions/{YYYYMMDD-HHMMSS}-{hash4}/
   ├── session-state.json
   ├── planmod-status.json
   ├── checkpoint.json
   ├── lanes/
   │   ├── L0/                      ← Topological level 0 (leaf modules)
   │   │   ├── {module-slug}/
   │   │   │   └── signals.json
   │   │   └── ...
   │   ├── L1/                      ← Level 1 (modules dep on L0)
   │   └── ...
   ├── workload-report.md
   ├── aggregation-result.json
   ├── feature-impl-map.json        ← A6-H1 fix (LEGACY only)
   └── phase-summary.md

   latest pointer: .mc-data/work/wf-plan-modules/latest

   3-level checkpoint:
   - L1 Phase: phases.P{N}.status
   - L2 Batch: phases.P{N}.batches[{level}-{module}].status
   - L3 Item: phases.P{N}.batches[{level}-{module}].items[{task}].status

   Cleanup: giữ 5 sessions
   ```

6. **Thêm section `## _shared Module Imports (ADR-OPT Integration)`:**
   - Module map: `lane` (Phase 7.5), `partition` (Phase 0.5), `aggregate` (Phase 7a), `cache` (Phase 0.5), `cdg` (Phase 0.5 + 7a nếu downgrade impl_status).

7. **Thêm section `## Topological Lane Dispatch`:**
   ```
   Phase 7.5 dispatch lanes theo topological order:
   1. Đọc $TOPOLOGICAL_LEVELS từ Phase 4 output.
   2. For each level (L0, L1, L2, ...):
      a. Build LaneConfig list cho modules trong level đó.
      b. dispatch_lanes(lanes, max_parallel=$LPM_PARAMS.max_parallel_agents).
      c. WAIT for level complete trước khi start level tiếp theo (enforce topological invariant).
      d. Aggregate signals per-level, merge vào aggregation-result.json running total.
   3. Final aggregation sau khi all levels done.

   Reasoning: Module L1 có thể cần task output của L0 làm context → sequential giữa levels.
   ```

---

### Task 3: Cập nhật `procedures/phase0-init.md`

**Vị trí:** `.claude/skills/workflow/wf-plan-modules/procedures/phase0-init.md`

**Thay đổi cần thực hiện:**

1. **Step 0.2b** session creation (pattern chuẩn).
2. **`--resume` handler** đọc `$SESSION_DIR/session-state.json`.
3. **Cập nhật Next phase:** thêm `phase0.5-workload-gate.md`.

---

### Task 4: Cập nhật `procedures/phase7.5-tasks.md`

**Vị trí:** `.claude/skills/workflow/wf-plan-modules/procedures/phase7.5-tasks.md`

**Thay đổi cần thực hiện:**

1. **Cập nhật primary dispatch logic** — Topological Lane Dispatch:
   ```
   | 7.5.X | Topological Lane Dispatch (ADR-OPT-01): Import _shared/lane/dispatcher.py.
          For each level L in $TOPOLOGICAL_LEVELS:
            Build LaneConfig list: mỗi module trong level L → LaneConfig(
              key="{module-slug}",
              agent_type="architect" (planning role),
              prompt=task generation template từ _shared.md,
              output_path=$SESSION_DIR/lanes/L{level}/{module-slug}/signals.json,
              context={module features, dependencies từ Phase 4, FEATURE_IMPL_MAP nếu LEGACY, sprint allocation từ Phase 5}
            ).
            dispatch_lanes(lanes, max_parallel=$LPM_PARAMS.max_parallel_agents, timeout_sec=600).
            WAIT level complete. | Lanes dispatched per level, topological order preserved |
   ```

2. **Verify lane outputs per-level:**
   ```
   | 7.5.Y | Mỗi lane: verify signals.json + tasks/{sys}/{mod}/{feat}-impl.md files non-empty | test -s lanes/L{level}/{mod}/signals.json |
   ```

3. **Checkpoint update:**
   ```
   | 7.5.Z | Sau MỖI lane complete: update session-state.json phases.P7_5.batches[L{level}-{mod}].status = "completed" (L2). | session-state.json updated |
   ```

4. **Thêm note:**
   ```
   Lane output schema: _shared/templates/lane-signal.json
     lane_type="module", items[]=[{task_id, feat_id, module_slug, implementation_strategy (VERIFY_ONLY/COMPLETE_EXISTING/IMPLEMENT_NEW), existing_code_refs[], estimated_hours}]
   Write-scope isolation: mỗi module lane ghi vào phase5-implementation/tasks/{sys}/{mod}/ riêng.
   Topological constraint: level L+1 phải WAIT tới khi tất cả level L lanes complete (enforce trong dispatcher).
   ```

---

### Task 5: Cập nhật `procedures/phase7a-verify.md`

**Vị trí:** `.claude/skills/workflow/wf-plan-modules/procedures/phase7a-verify.md`

**Thay đổi cần thực hiện:**

1. **Thêm step signal aggregation đầu phase:**
   ```
   | 7a.0 | Signal Aggregation (ADR-OPT-04): Import _shared/aggregate/aggregator.py.
          aggregate_lane_signals(lane_outputs=$SESSION_DIR/lanes/*/*/signals.json (glob all levels), dedup_key_fn=dedup_by_id("task_id")).
          Output: $SESSION_DIR/aggregation-result.json.
          IF conflicts[] non-empty (shared task across modules) → flag cho dependency review (không auto-resolve — user quyết định shared infrastructure vs duplicate work). | aggregation-result.json written |
   ```

2. **Verify dependencies** dựa trên aggregated tasks:
   ```
   | 7a.X | Cross-check: mỗi task_id phải có existing_code_refs nếu strategy != IMPLEMENT_NEW (CORE-019). | All tasks verified |
   ```

3. **Registry Safe-Write (impl_status):**
   - Giữ nguyên CORE-006 SAFE-UPDATE logic.
   - Thêm CDG token flow nếu downgrade done→skipped (legacy mode + deprecated modules).

---

### Task 6: Cập nhật `procedures/phase7-outputs.md` + `procedures/phase7c-summary.md`

**Vị trí:**
- `.claude/skills/workflow/wf-plan-modules/procedures/phase7-outputs.md` (module-plan + dependency-graph + roadmap + sprints)
- `.claude/skills/workflow/wf-plan-modules/procedures/phase7c-summary.md` (phase summary + Phiên 6 digest)

**Thay đổi — `phase7-outputs.md`:**

1. **Thêm atomic write cho mọi output:**
   ```
   | 7.X | Generate module-plan.md via atomic write: $SESSION_DIR/module-plan.md.tmp → validate → mv to phase5-implementation/module-plan.md | test -s phase5-implementation/module-plan.md |
   ```
   - Áp dụng cho: `module-plan.md`, `dependency-graph.md`, `P5-00-implementation-roadmap.md`, mỗi `sprints/S{NN}-*.md`.

2. **Thêm template strip** cho bất kỳ JSON output nào (hiện tại tất cả outputs là markdown, không cần strip — chỉ atomic write).

**Thay đổi — `phase7c-summary.md`:**

1. **Cập nhật step tạo phase-summary.md** — template strip + atomic write pattern chuẩn.

2. **Đảm bảo phase-summary.md (CORE-028) viết đúng format tiếng Việt, non-specialist, ≤15 dòng.**

3. **KHÔNG có digest output canonical** — `wf-plan-modules` không tạo `_meta/*.json` digest (skill cuối chuỗi, consumer là `wf-implement-feature` đọc directly từ docs).

---

## Constraints (BẮT BUỘC)

1. **KHÔNG thay đổi `registry_scope.fields_owned`** — vẫn là `["implementation_order", "impl_status"]`.
2. **KHÔNG lane-ify Phase 1.5 (CORE-019 code verification)** — sequential đảm bảo accuracy.
3. **Topological invariant**: level L+1 WAIT level L complete — enforce trong dispatcher, không skip.
4. **Shared task conflicts KHÔNG auto-resolve** — flag cho user review.
5. **CORE-019 implementation_strategy** — mỗi task PHẢI có strategy từ FEATURE_IMPL_MAP (LEGACY) hoặc IMPLEMENT_NEW (new project).
6. **CORE-020 Pre-Implementation Safety Gate** — task generation phải search existing code trước khi mark IMPLEMENT_NEW.
7. **Atomic write** cho mọi output file (markdown + JSON).
8. **Tiếng Việt cho docs/comments, English cho code/names** (CORE-005).
9. **Template Usage Rule (CORE-031)**.
10. **Surgical changes only (BHV-003)**.
11. **CDG trigger** khi downgrade impl_status done→skipped (LEGACY deprecated modules) — giữ Protocol 16 logic.

---

## Verify Checklist (sau khi hoàn tất)

| # | Check | Command |
|---|-------|---------|
| V1 | `phase0.5-workload-gate.md` tồn tại | `test -f .claude/skills/workflow/wf-plan-modules/procedures/phase0.5-workload-gate.md` |
| V2 | `_shared.md` có Session Isolation + Topological Lane Dispatch sections | `grep -q "Session Isolation\|Topological Lane Dispatch" .claude/skills/workflow/wf-plan-modules/procedures/_shared.md` |
| V3 | `_shared.md` Phase→File Mapping có Phase 0.5 | `grep -q "phase0.5-workload-gate" .claude/skills/workflow/wf-plan-modules/procedures/_shared.md` |
| V4 | `phase0-init.md` có Step 0.2b | `grep -q "0.2b" .claude/skills/workflow/wf-plan-modules/procedures/phase0-init.md` |
| V5 | `phase7.5-tasks.md` có Topological Lane Dispatch reference | `grep -qE "Topological Lane Dispatch\|for each level" .claude/skills/workflow/wf-plan-modules/procedures/phase7.5-tasks.md` |
| V6 | `phase7a-verify.md` có Signal Aggregation (task_id) | `grep -q "Signal Aggregation" .claude/skills/workflow/wf-plan-modules/procedures/phase7a-verify.md && grep -q "task_id" .claude/skills/workflow/wf-plan-modules/procedures/phase7a-verify.md` |
| V7 | `phase7-outputs.md` có atomic write pattern | `grep -qE "atomic write\|\\.tmp" .claude/skills/workflow/wf-plan-modules/procedures/phase7-outputs.md` |
| V8 | `_contract.json` JSON valid + version = 3.0.0 | `node -e "const c=JSON.parse(require('fs').readFileSync('.claude/skills/workflow/wf-plan-modules/_contract.json')); console.log(c.version)"` → `3.0.0` |
| V9 | `registry_scope.fields_owned` không thay đổi | `node -e "const c=JSON.parse(require('fs').readFileSync('.claude/skills/workflow/wf-plan-modules/_contract.json')); console.log(JSON.stringify(c.registry_scope.fields_owned))"` → `["implementation_order","impl_status"]` |
| V10 | Phase 1.5 (legacy-impl) KHÔNG có Lane Dispatch | `! grep -q "Lane Dispatch" .claude/skills/workflow/wf-plan-modules/procedures/phase1.5-legacy-impl.md` |

---

## Post-Rollout Validation

Sau khi V1-V10 PASS:
1. `./.claude/scripts/skill-compliance-audit.sh wf-plan-modules`
2. `./.claude/scripts/validate-schema-sync.sh wf-plan-modules`
3. Evals thêm ≥3 test cases:
   - `topological-lane-dispatch` — 3-level DAG (L0 → L1 → L2) → verify level L+1 WAITs L
   - `shared-task-conflict-flag` — 2 modules cùng produce TASK-ID → flag trong aggregation-result.json
   - `session-isolation`, `workload-gate-legacy-factor`, `atomic-write-outputs`
4. `/audit-devkit-scan` + `/audit-devkit-verify --skill=wf-plan-modules` + `/audit-devkit-fix`
5. `/audit-skill-output wf-plan-modules`
6. Integration test **critical**:
   - Full E2E: `/wf-plan-modules` → verify `wf-implement-feature` đọc được module-plan.md + dependency-graph.md + sprints/ + tasks/
   - Verify HIGH breaking change risk — path resolution cho tasks/, sprints/ phải UNCHANGED.
7. Update sign-off doc.

---

## Notes Cuối Phase 3

Sau khi skill này DONE, **toàn bộ 5 linear skills** (analyze-req + 4 skill rollout) đã có 5 ADR-OPT techniques. Phase 4 (documentation signoff) và Phase 5 (integration tests) sẽ chạy trên toàn chuỗi để xác nhận không skill nào break contract.
