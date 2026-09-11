# Phase 3 — ADR-OPT Rollout: `wf-design` (Skill 2/4)

> **Tạo:** 2026-04-23
> **Mục đích:** Prompt-ready checklist cho phiên rollout — bump `wf-design` lên v4.0.0 với 5 ADR-OPT techniques.
> **Prerequisite:** `phase3-wf-define-features.md` DONE + V1-V10 PASS + đọc `phase3-rollout-design-principles.md` (Variable Map §3.2 + Shared Constraints §4).
> **Output của phiên này:** SKILL.md v4.0.0 + _contract.json v4.0.0 + 6-7 procedure files updated/created.

---

## Context (đọc trước khi bắt đầu)

`wf-design` hiện đã ở v3.0.0 (refactor 9-phase-file, 2026-04-19) — nhưng **chưa có** 5 ADR-OPT. Phase 3 rollout bump lên **v4.0.0** (SemVer MAJOR) do thêm Phase 0.5 + Lane Dispatch + Session Isolation — thay đổi phase structure breaking.

**Current state (từ `_contract.json` + `procedures/` listing — 2026-04-23):**
- SKILL.md: v3.0.0
- _contract.json: v3.0.0
- Procedures (9 files + _shared.md):
  - `_shared.md`
  - `phase0-context.md`
  - `phase1-architecture.md` (primary architect dispatch)
  - `phase2-specs-parallel.md` (parallel: api-contract + database-design + infra-spec)
  - `phase3-integration.md`
  - `phase4-crossval.md` (auto-correction loop)
  - `phase5-review.md` (stakeholder review)
  - `phase6-finalize.md`
  - `phase7-gap.md` (LEGACY only — gap analysis)
  - `phase8-digest-summary.md` (Phiên 6 — digest + phase summary)

**Target state:** v4.0.0 với 5 ADR-OPT. `registry_scope.fields_owned` UNCHANGED = `["design_status"]` (legacy flow được phép write thêm systems/modules/..., giữ nguyên).

**Đặc thù skill này:**
- Heaviest skill trong 4 — mỗi system có 4-5 technical specs (architecture + API + DB + integration + infra).
- Phase 2 đã parallel sẵn (api-contract + database-design + infra-spec) — cần convert sang Lane Dispatch với write-scope isolation.
- LEGACY gap analysis (Phase 7) cần tích hợp với lane context (không phải lane-ify phase này).

**Key references:**
- Design principles: `docs/design/skills/phase3-rollout-design-principles.md` §3.2
- ADR đầy đủ: `docs/design/skills/ADR-downstream-skills-optimization.md`
- Phase 2 template (reference): `docs/design/skills/phase2-analyze-req-remaining-steps.md`
- _shared protocol: `.claude/skills/workflow/_shared/_shared.md`

---

## Decision Log — Skill: `wf-design`

| Field | Value | Rationale |
|-------|-------|-----------|
| Current version | 3.0.0 | Từ `_contract.json` (refactor 9-phase-file) |
| Target version | **4.0.0** | SemVer MAJOR — thêm Phase 0.5 + Lane Dispatch + Session Isolation (breaking) |
| Lane type | **system-lane per system** | Mỗi system có kiến trúc độc lập; multi-system project cần song song để tránh blocking |
| Lane key format | `{system-slug}` | Single-level slug — system là đơn vị thiết kế lớn nhất |
| Partition grouping | `group_key="system"`, `max_per_partition = 3` | System nặng hơn module/dept → giảm concurrency để tránh agent quá tải |
| Workload `est_minutes_per_item` | **15.0** | Design toàn diện: architect + API + DB + integration + infra ≈ 4-5 agents spawn / system |
| Workload factor | 1.0 normal, 1.5 LEGACY, 2.0 nếu multi-tier (microservices, event-driven) | Multi-tier → thêm integration-map phức tạp hơn |
| Dedup key | `component_id` (COMPONENT-ID) cho architecture phase, `api_id` cho API contract phase | 2 phases có dedup khác nhau — aggregator gọi 2 lần với key khác |
| Aggregation conflict | Cross-system dependency conflicts → flag, defer cho Phase 5 stakeholder review | Conflict giữa systems cần design-level decision, không auto-resolve |
| Conditional phases (skip triggers) | Phase 7 gap analysis — LEGACY_MODE only (giữ nguyên) | Không lane-ify — gap analysis là sequential aggregate |
| Expert dispatch phase file | `phase1-architecture.md` + `phase2-specs-parallel.md` | Primary lane phase — thay spawn logic hiện tại bằng Lane Dispatch |
| Consolidate phase file | `phase3-integration.md` + `phase4-crossval.md` | Signal Aggregation cho COMPONENT-ID/API-ID dedup |
| Handoff phase file | `phase6-finalize.md` + `phase8-digest-summary.md` | Template Strip + Atomic Write cho `design-input-digest.json` + `design-summary.json` |
| Breaking change risk | **MEDIUM** | Downstream (wf-design-ux, wf-plan-modules) đọc `design-input-digest.json` — schema UNCHANGED nhưng path qua session dir → cần verify session→canonical sync hoạt động |

---

## Tasks (thực hiện theo thứ tự)

### Task 1: Tạo `procedures/phase0.5-workload-gate.md` (MỚI)

**Vị trí:** `.claude/skills/workflow/wf-design/procedures/phase0.5-workload-gate.md`

**Nội dung:**

```
PRE-GATE: Phase 0 POST-GATE PASS
INPUT: $REGISTRY_DATA (systems, modules, features counts from feature-briefs.json), LEGACY_MODE flag, architecture_style (detect từ project-context.md nếu LEGACY)
OUTPUT: sessions/{id}/workload-report.md

Steps:
| Step | Action | Verify |
|------|--------|--------|
| 0.5.1 | Import _shared/partition/planner.py → plan_partitions(items=$ACTIVE_SYSTEMS, group_key="system", max_per_partition=3) | Partitions generated |
| 0.5.2 | Import _shared/partition/workload_gate.py → estimate_workload(partitions, est_minutes_per_item=15.0). Factor: ×1.0 normal, ×1.5 LEGACY_MODE, ×2.0 nếu architecture_style IN (microservices, event-driven) | WorkloadEstimate calculated |
| 0.5.3 | check_workload_gate(estimate, threshold_minutes=45). Ratio = estimated/45 | GateResult obtained |
| 0.5.4 | IF dead_zone (<0.8) → silent continue. IF warn (0.8-1.5) → AskUserQuestion: "Estimated {X} min for {N} systems. Continue?". IF block (>1.5) → Plan A/B menu (narrow to 1 system / override+CDG-A02 / partition sequential by system) | User decision recorded |
| 0.5.5 | WRITE workload-report.md từ template _shared/templates/workload-report.md | test -s workload-report.md |
| 0.5.6 | Update session-state.json: phases.P0_5.status, next_action = "phase1-architecture" | State persisted |

POST-GATE: Workload estimate recorded, user acknowledged (if WARN/BLOCK).
Next phase: phase1-architecture.md
```

**Lưu ý đặc thù wf-design:**
- `est_minutes_per_item = 15.0` cao nhất trong 4 skills — reflect đúng design complexity.
- `max_per_partition = 3` thấp hơn mặc định — system-lane heavy, tránh agent saturation.
- Multi-tier factor (×2.0) detect từ `project-context.md` legacy scan hoặc brainstorm decisions.

---

### Task 2: Cập nhật `procedures/_shared.md`

**Vị trí:** `.claude/skills/workflow/wf-design/procedures/_shared.md`

**Thay đổi cần thực hiện:**

1. **Thêm section mới** sau `## State Variables Glossary`:
   - `$SESSION_DIR` — `.mc-data/work/wf-design/sessions/{YYYYMMDD-HHMMSS}-{hash4}/`
   - `$SESSION_ID` — `YYYYMMDD-HHMMSS-hash4`
   - `$WORKLOAD_ESTIMATE`, `$GATE_RESULT` — từ Phase 0.5

2. **Cập nhật `## Phase → File Mapping`** — thêm:
   - `| Phase 0.5 | phase0.5-workload-gate.md | Workload estimation + gate evaluation (ADR-OPT-03) |`

3. **Cập nhật Phase Ordering** — thêm 0.5 vào ordering hiện tại:
   - `0 → 0.5 → 1 → 2 → 3 → 4 → 5 → 6 → [7 LEGACY] → 8`

4. **Thêm section mới** `## Session Isolation Protocol (ADR-OPT-02)`:
   ```
   sessions/{YYYYMMDD-HHMMSS}-{hash4}/
   ├── session-state.json
   ├── design-status.json
   ├── checkpoint.json
   ├── lanes/
   │   ├── {system-slug}/
   │   │   ├── signals.json             ← Lane 1: architecture
   │   │   └── specs-signals.json       ← Lane 2: specs (api/db/infra, conditional)
   │   └── ...
   ├── workload-report.md
   ├── aggregation-result.json          ← Components + APIs dedup
   ├── design-input-digest.json         ← Working copy (post-strip → _meta/)
   ├── design-summary.json              ← Per-module compressed spec
   └── phase-summary.md

   latest pointer: .mc-data/work/wf-design/latest

   3-level checkpoint:
   - L1 Phase: phases.P{N}.status
   - L2 Batch: phases.P{N}.batches[{system}].status
   - L3 Item: phases.P{N}.batches[{system}].items[{component/api}].status

   Cleanup: giữ 5 sessions
   ```

5. **Thêm section** `## _shared Module Imports (ADR-OPT Integration)`:
   - Module map: `lane` (Phase 1-2), `partition` (Phase 0.5), `aggregate` (Phase 3-4), `cache` (Phase 0.5), `cdg` (Phase 0.5)

6. **Cập nhật `## Checkpoint Protocol`** — session-state.json primary, checkpoint.json backward-compat.

---

### Task 3: Cập nhật `procedures/phase0-context.md`

**Vị trí:** `.claude/skills/workflow/wf-design/procedures/phase0-context.md`

**Thay đổi cần thực hiện:**

1. **Sau Step 0.2** — thêm Step 0.2b session creation (giống pattern `wf-analyze-requirements` / `wf-define-features`).

2. **Cập nhật Step 0.3** — `design-status.json` ghi vào `$SESSION_DIR/design-status.json`.

3. **Cập nhật `--resume` handler:**
   - Đọc `$SESSION_DIR/session-state.json` → `next_action` → dispatch phase.
   - Fallback checkpoint.json.

4. **Cập nhật Step 0.4 Sub-Phase 0.5 (feature digest compression):**
   - Feature digest output ghi vào `$SESSION_DIR/feature-digest.md` (thay vì `.mc-data/work/wf-design/feature-digest.md`).
   - Giữ backward-compat: symlink hoặc copy về root.

5. **Cập nhật Next phase:** thêm `phase0.5-workload-gate.md`.

---

### Task 4: Cập nhật `procedures/phase1-architecture.md` + `procedures/phase2-specs-parallel.md`

**Vị trí:**
- `.claude/skills/workflow/wf-design/procedures/phase1-architecture.md` (primary lane phase)
- `.claude/skills/workflow/wf-design/procedures/phase2-specs-parallel.md` (secondary lane — specs per system)

**Thay đổi — `phase1-architecture.md`:**

1. **Cập nhật Step 1.X** (architect dispatch) — formalize lane dispatch:
   ```
   | 1.X | Lane Dispatch (ADR-OPT-01): Import _shared/lane/dispatcher.py.
        Build LaneConfig list: mỗi system → LaneConfig(
          key="{system-slug}",
          agent_type="architect",
          prompt=architect Phase 1 template từ _shared.md,
          output_path=$SESSION_DIR/lanes/{system-slug}/signals.json,
          context={system features from registry, feature-briefs digest, legacy context nếu LEGACY}
        ).
        dispatch_lanes(lanes, max_parallel=$LPM_PARAMS.max_parallel_agents, timeout_sec=600).
        Conditional agents (ai-engineer / data-engineer / automation-architect) — spawn trong CÙNG lane (child process), KHÔNG tách lane riêng. | Lanes dispatched, max_parallel enforced |
   ```

2. **Cập nhật Step verify lane outputs:**
   ```
   | 1.Y | Mỗi lane: verify signals.json + P3-01-architecture.md section cho system đó | test -s lanes/{sys}/signals.json |
   ```

3. **Cập nhật checkpoint update** — session-state.json phases.P1.batches[{system}].status.

**Thay đổi — `phase2-specs-parallel.md`:**

1. **Cập nhật parallel spawn (api-contract + database-design + infra-spec)** — 2 cách:
   - **Option A (đơn giản):** Spawn 3 agents trong CÙNG lane của system đó (vì output path khác nhau: `api-contract.md`, `database-design.md`, `infra-spec.md` — không conflict write scope).
   - **Option B (fine-grained):** Tạo 3 sub-lanes per system: `{system}-api`, `{system}-db`, `{system}-infra`. Phức tạp hơn nhưng tracking rõ hơn.
   - **Quyết định:** Option A — giữ pattern "1 system = 1 lane", các specs là sub-tasks trong lane. Output aggregation vẫn per-system.

2. **Verify lane outputs** cho 3 spec files:
   ```
   | 2.X | verify api-contract.md + database-design.md + infra-spec.md tồn tại + non-empty cho mỗi system | test -s technical-specs/{api-contract,database-design,infra-spec}.md |
   ```

3. **Thêm note**:
   ```
   Lane output schema: _shared/templates/lane-signal.json
     lane_type="system", items[]=[{component_id, api_id, db_table_id, infra_resource_id, ...}]
   Write-scope isolation: mỗi system lane ghi vào `phase3-architecture/{system-slug}/` hoặc shared `technical-specs/` với file-level dedup trong aggregation.
   ```

---

### Task 5: Cập nhật `procedures/phase3-integration.md` + `procedures/phase4-crossval.md`

**Vị trí:**
- `.claude/skills/workflow/wf-design/procedures/phase3-integration.md`
- `.claude/skills/workflow/wf-design/procedures/phase4-crossval.md`

**Thay đổi — `phase3-integration.md`:**

1. **Thêm step đầu phase** — signal aggregation:
   ```
   | 3.0 | Signal Aggregation (ADR-OPT-04) — phase 1: Import _shared/aggregate/aggregator.py.
          aggregate_lane_signals(lane_outputs=$SESSION_DIR/lanes/*/signals.json, dedup_key_fn=dedup_by_id("component_id")).
          Output: $SESSION_DIR/aggregation-result.json (phần components).
          IF conflicts[] non-empty → flag cho Phase 4 cross-validation. | aggregation-result.json written (components) |
   | 3.0b | Signal Aggregation phase 2: aggregate_lane_signals(specs-signals, dedup_by_id("api_id")). Merge kết quả vào aggregation-result.json (phần apis). | APIs deduped |
   ```

2. **Integration map generation** — dựa trên aggregated components/APIs thay vì parse per-system files.

**Thay đổi — `phase4-crossval.md`:**

1. **Thêm step xử lý conflicts** từ aggregation:
   ```
   | 4.X | Đọc $SESSION_DIR/aggregation-result.json → conflicts[]. Mỗi conflict: auto-correction loop (max 3 iterations) cố gắng resolve. Nếu không resolve được → flag cho Phase 5 stakeholder review. | All conflicts resolved or flagged |
   ```

---

### Task 6: Cập nhật `procedures/phase6-finalize.md` + `procedures/phase8-digest-summary.md`

**Vị trí:**
- `.claude/skills/workflow/wf-design/procedures/phase6-finalize.md`
- `.claude/skills/workflow/wf-design/procedures/phase8-digest-summary.md`

**Thay đổi — `phase8-digest-summary.md` (primary handoff phase):**

1. **Cập nhật step tạo `design-input-digest.json`** — thêm template strip:
   ```
   | 8.X | Tạo $SESSION_DIR/design-input-digest.json từ template `_digests/design-input-digest.template.json` → **Template Strip (ADR-OPT-05)**:
          jq 'del(._template_notes, ._comments, ._examples, ._placeholder, ._description)' digest.json > digest-stripped.json.
          **Atomic Write**: write to $SESSION_DIR/design-input-digest.json.tmp → jq validate → mv to final.
          (xem _shared/_shared.md §1-2) | Digest hợp lệ JSON, không chứa _template_notes |
   ```

2. **Cập nhật step tạo `design-summary.json`** — cùng pattern template strip + atomic write.

3. **Thêm step sync canonical:**
   ```
   | 8.X+1 | SYNC sang canonical _meta/ path:
          cp $SESSION_DIR/design-input-digest.json .mc-data/docs/_meta/design-input-digest.json
          cp $SESSION_DIR/design-summary.json .mc-data/work/wf-design/design-summary.json (working path giữ nguyên)
          | canonical file exists |
   ```

4. **Thêm POST-GATE check mới:**
   ```bash
   jq -e 'has("_template_notes")' .mc-data/docs/_meta/design-input-digest.json → false
   jq -e '.components | length > 0' .mc-data/docs/_meta/design-input-digest.json → true
   jq -e '.apis | length >= 0' .mc-data/docs/_meta/design-input-digest.json → true
   ```

**Thay đổi — `phase6-finalize.md`:**

1. **Chỉ cập nhật checkpoint + status** — không có digest write ở phase này (digest ở Phase 8).
2. **Registry Safe-Write (design_status):** Giữ nguyên CORE-006 logic.

---

### Task 7: Cập nhật `procedures/phase7-gap.md` (LEGACY only — KHÔNG lane-ify)

**Vị trí:** `.claude/skills/workflow/wf-design/procedures/phase7-gap.md`

**Thay đổi cần thực hiện:**

1. **KHÔNG lane-ify** — gap analysis là aggregate sequential, không benefit từ parallel.
2. **Chỉ cập nhật output paths:**
   - `gap-report.md`, `gap-categories.json`, `action-items.json`, `final-report.md` — write vào `.mc-data/work/legacy-scan/` (giữ path canonical — downstream consumers đã quen).
3. **Thêm template strip cho `action-items.json`** (nếu chưa có):
   ```
   jq 'del(._template_notes, ._comments)' action-items.json.tmp > action-items.json
   ```

---

## Constraints (BẮT BUỘC)

1. **KHÔNG thay đổi `registry_scope.fields_owned`** — vẫn là `["design_status"]` + legacy flow extension.
2. **KHÔNG lane-ify Phase 7 (gap analysis)** — sequential aggregate, không benefit.
3. **Option A cho Phase 2 specs** — mỗi system = 1 lane, 3 specs là sub-tasks.
4. **Tiếng Việt cho docs/comments, English cho code/names** (CORE-005).
5. **Template Usage Rule (CORE-031)** — mọi output file phải READ template → POPULATE → WRITE.
6. **Surgical changes only (BHV-003)** — không refactor thêm.
7. **Import convention** theo `_shared/_shared.md §3-4`.
8. **KHÔNG viết Python code** — procedure files là Markdown instructions.
9. **Backward compatibility** — `design-input-digest.json` + `design-summary.json` schemas UNCHANGED.
10. **Dual dedup key** (component_id + api_id) — aggregator gọi 2 lần, merge kết quả.

---

## Verify Checklist (sau khi hoàn tất)

| # | Check | Command |
|---|-------|---------|
| V1 | `phase0.5-workload-gate.md` tồn tại | `test -f .claude/skills/workflow/wf-design/procedures/phase0.5-workload-gate.md` |
| V2 | `_shared.md` có Session Isolation Protocol section | `grep -q "Session Isolation" .claude/skills/workflow/wf-design/procedures/_shared.md` |
| V3 | `_shared.md` Phase→File Mapping có Phase 0.5 | `grep -q "phase0.5-workload-gate" .claude/skills/workflow/wf-design/procedures/_shared.md` |
| V4 | `phase0-context.md` có Step 0.2b session creation | `grep -q "0.2b" .claude/skills/workflow/wf-design/procedures/phase0-context.md` |
| V5 | `phase1-architecture.md` có Lane Dispatch reference | `grep -q "Lane Dispatch" .claude/skills/workflow/wf-design/procedures/phase1-architecture.md` |
| V6 | `phase3-integration.md` có Signal Aggregation (component + api) | `grep -qE "Signal Aggregation" .claude/skills/workflow/wf-design/procedures/phase3-integration.md && grep -q "component_id" .claude/skills/workflow/wf-design/procedures/phase3-integration.md && grep -q "api_id" .claude/skills/workflow/wf-design/procedures/phase3-integration.md` |
| V7 | `phase8-digest-summary.md` có template strip + atomic write | `grep -qE "_template_notes\|Atomic Write" .claude/skills/workflow/wf-design/procedures/phase8-digest-summary.md` |
| V8 | `_contract.json` JSON valid + version = 4.0.0 | `node -e "const c=JSON.parse(require('fs').readFileSync('.claude/skills/workflow/wf-design/_contract.json')); console.log(c.version)"` → `4.0.0` |
| V9 | `registry_scope.fields_owned` không thay đổi | `node -e "const c=JSON.parse(require('fs').readFileSync('.claude/skills/workflow/wf-design/_contract.json')); console.log(JSON.stringify(c.registry_scope.fields_owned))"` → `["design_status"]` |
| V10 | `phase7-gap.md` KHÔNG có Lane Dispatch (sequential vẫn giữ) | `! grep -q "Lane Dispatch" .claude/skills/workflow/wf-design/procedures/phase7-gap.md` |

---

## Post-Rollout Validation

Sau khi V1-V10 PASS, chạy pattern `phase2-validation-tests.md` với skill = `wf-design`:
1. `./.claude/scripts/skill-compliance-audit.sh wf-design`
2. `./.claude/scripts/validate-schema-sync.sh wf-design`
3. Update evals: ≥3 test cases mới (session-isolation, workload-gate, lane-dispatch-multi-system, aggregation-dual-dedup, template-strip)
4. `/audit-devkit-scan` + `/audit-devkit-verify --skill=wf-design` + `/audit-devkit-fix`
5. `/audit-skill-output wf-design` (1 project đã chạy xong v4.0.0)
6. Integration test: chạy `/wf-design` → verify downstream `/wf-design-ux` + `/wf-plan-modules` đọc được `design-input-digest.json` với schema UNCHANGED.
7. Update sign-off doc.
