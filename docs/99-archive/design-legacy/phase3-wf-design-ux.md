# Phase 3 — ADR-OPT Rollout: `wf-design-ux` (Skill 3/4)

> **Tạo:** 2026-04-23
> **Mục đích:** Prompt-ready checklist cho phiên rollout — bump `wf-design-ux` lên v4.0.0 với 5 ADR-OPT techniques.
> **Prerequisite:** `phase3-wf-design.md` DONE + V1-V10 PASS + đọc `phase3-rollout-design-principles.md` (Variable Map §3.3).
> **Output của phiên này:** SKILL.md v4.0.0 + _contract.json v4.0.0 + 6-7 procedure files updated/created.

---

## Context (đọc trước khi bắt đầu)

`wf-design-ux` là skill **conditional** — toàn skill skip nếu `interface_type == "api-only"`. Phase 3 rollout PHẢI tôn trọng điều kiện này:
- Phase 0.5 workload gate **phải check conditional trước khi estimate**.
- Nếu skip → ghi `phases.P0_5.skipped = true, reason = "api-only interface"` vào session-state, **không spawn** AskUserQuestion.

**Current state (từ `_contract.json` + `procedures/` listing — 2026-04-23):**
- SKILL.md: v3.0.0
- _contract.json: v3.0.0
- Procedures (10 files + _shared.md):
  - `_shared.md`
  - `phase0-context.md`
  - `phase0-5-legacy-ui.md` (LEGACY only — existing UI analysis; lưu ý đặt tên dùng `-` thay vì `.`)
  - `phase1-design-system.md` (design tokens, colors, typography)
  - `phase2-navigation.md` (navigation specs per system)
  - `phase3-screen-groups.md` (primary lane phase — screens per module)
  - `phase4-crossval.md` (auto-correction)
  - `phase5-review.md` (stakeholder review)
  - `phase6-registry.md` (update ux_design_status)
  - `phase7-digest-summary.md` (Phiên 6 — digest + phase summary)

**⚠️ Naming conflict:** `phase0-5-legacy-ui.md` đã tồn tại (LEGACY only). Không conflict trực tiếp với `phase0.5-workload-gate.md` (dot vs dash), nhưng có thể gây confusion. Khuyến nghị:
- **Option A:** Giữ `phase0-5-legacy-ui.md` đúng như cũ (existing naming) + tạo mới `phase0.5-workload-gate.md` (theo pattern các skill khác).
- **Option B:** Rename `phase0-5-legacy-ui.md` → `phase0.5-legacy-ui-analysis.md` để consistent dot-naming.
- **Quyết định:** Chọn **Option B** — consistent với các skill khác trong Phase 3 rollout. Rename atomic cùng rollout.

**Target state:** v4.0.0 với 5 ADR-OPT + conditional skip logic bảo toàn. `registry_scope.fields_owned` UNCHANGED = `["ux_design_status"]`.

**Key references:**
- Design principles: `docs/design/skills/phase3-rollout-design-principles.md` §3.3
- ADR đầy đủ: `docs/design/skills/ADR-downstream-skills-optimization.md`
- Conditional contract: `.claude/rules/00-core.md §4b` (IF api-only → skip)
- _shared protocol: `.claude/skills/workflow/_shared/_shared.md`

---

## Decision Log — Skill: `wf-design-ux`

| Field | Value | Rationale |
|-------|-------|-----------|
| Current version | 3.0.0 | Từ `_contract.json` |
| Target version | **4.0.0** | SemVer MAJOR — thêm Phase 0.5 + Lane Dispatch (breaking) |
| Lane type | **screen-lane per module (non-api)** | Mỗi module có UI là đơn vị thiết kế screen group; skip modules api-only |
| Lane key format | `{module-slug}-screens` | Suffix `-screens` để phân biệt với potential component lanes tương lai |
| Partition grouping | `group_key="module"`, `max_per_partition = 5` | UI module nhẹ hơn design system module |
| Workload `est_minutes_per_item` | **4.0** | Screen group spec ngắn hơn feature spec (tập trung layout + wireframe, không logic) |
| Workload factor | 1.0 normal, 1.5 LEGACY, 1.5 nếu avg `>3 screen groups/module` | LEGACY cần cross-check existing UI |
| Dedup key | `screen_id` (SCREEN-ID) | Conflict khi 2 module cùng reuse screen (rare) |
| Aggregation conflict | Reuse component cross-module → aggregate vào shared design system (Phase 1), KHÔNG flag | Component sharing là tính năng mong muốn, không phải conflict |
| Conditional phases (skip triggers) | **TOÀN SKILL** skip nếu `interface_type == "api-only"` | Xem §0.5.0 bên dưới — special logic trong Phase 0.5 |
| Expert dispatch phase file | `phase3-screen-groups.md` | Primary lane phase — screens per module |
| Consolidate phase file | `phase4-crossval.md` | Signal Aggregation cho SCREEN-ID |
| Handoff phase file | `phase7-digest-summary.md` | Template Strip + Atomic Write cho `ux-input-digest.json` |
| Breaking change risk | **LOW** | Downstream chỉ `wf-plan-modules` (conditional); schema UNCHANGED |

---

## Tasks (thực hiện theo thứ tự)

### Task 1: Rename `phase0-5-legacy-ui.md` → `phase0.5-legacy-ui-analysis.md` + Tạo mới `phase0.5-workload-gate.md`

**Vị trí:**
- Rename: `.claude/skills/workflow/wf-design-ux/procedures/phase0-5-legacy-ui.md` → `phase0.5-legacy-ui-analysis.md`
- Tạo mới: `.claude/skills/workflow/wf-design-ux/procedures/phase0.5-workload-gate.md`

**Nội dung `phase0.5-workload-gate.md`:**

```
PRE-GATE: Phase 0 POST-GATE PASS
INPUT: $REGISTRY_DATA (systems, modules, interface_type), LEGACY_MODE flag, design-input-digest.json từ wf-design
OUTPUT: sessions/{id}/workload-report.md

Steps:
| Step | Action | Verify |
|------|--------|--------|
| 0.5.0 | CONDITIONAL CHECK: Đọc interface_type từ req-registry.json. IF "api-only" → Update session-state.json: phases.P0_5.status = "skipped", phases.P0_5.reason = "api-only interface". EXIT toàn skill (return success với 0 outputs). | IF api-only → skill exit before estimate |
| 0.5.1 | Import _shared/partition/planner.py → identify UI modules (filter modules where has_ui == true OR interface_type là web/mobile/hybrid). plan_partitions(items=$UI_MODULES, group_key="module", max_per_partition=5) | Partitions generated |
| 0.5.2 | Import _shared/partition/workload_gate.py → estimate_workload(partitions, est_minutes_per_item=4.0). Factor: ×1.0 normal, ×1.5 LEGACY_MODE, ×1.5 nếu avg screen_groups_per_module > 3 | WorkloadEstimate calculated |
| 0.5.3 | check_workload_gate(estimate, threshold_minutes=45). Ratio = estimated/45 | GateResult obtained |
| 0.5.4 | IF dead_zone (<0.8) → silent continue. IF warn (0.8-1.5) → AskUserQuestion. IF block (>1.5) → Plan A/B menu (narrow scope / override+CDG-A02 / partition sequential) | User decision recorded |
| 0.5.5 | WRITE workload-report.md từ template _shared/templates/workload-report.md | test -s workload-report.md |
| 0.5.6 | Update session-state.json: phases.P0_5.status, next_action = "phase0.5-legacy-ui-analysis" (IF LEGACY_MODE) else "phase1-design-system" | State persisted |

POST-GATE: Workload estimate recorded (OR skipped với reason="api-only"), user acknowledged (if WARN/BLOCK).
Next phase: phase0.5-legacy-ui-analysis.md (IF LEGACY_MODE) → phase1-design-system.md
```

**Lưu ý đặc thù:**
- Step 0.5.0 là **conditional exit gate** — KHÔNG skill nào khác có step này. Phải implement cẩn thận để skill return success (không fail) khi api-only.
- Skip skill không vi phạm workflow ordering — `wf-plan-modules` PRE-GATE đã handle trường hợp thiếu UX digest (xem `.claude/rules/00-core.md §4b` IF branch api-only).

**Sau khi rename `phase0.5-legacy-ui-analysis.md`:**
- Update tất cả references trong SKILL.md + _contract.json + phase files khác.

---

### Task 2: Cập nhật `procedures/_shared.md`

**Vị trí:** `.claude/skills/workflow/wf-design-ux/procedures/_shared.md`

**Thay đổi cần thực hiện:**

1. **Thêm 4 state variables** (pattern giống các skill khác): `$SESSION_DIR`, `$SESSION_ID`, `$WORKLOAD_ESTIMATE`, `$GATE_RESULT`.

2. **Thêm variable đặc thù:**
   - `$SKILL_SKIPPED` — Set by Phase 0.5.0, Read by exit handler — bool indicating api-only skip (để skill exit gracefully).

3. **Cập nhật Phase→File Mapping:**
   - `| Phase 0.5 workload | phase0.5-workload-gate.md | Workload gate + api-only conditional skip (ADR-OPT-03) |`
   - `| Phase 0.5 legacy-ui | phase0.5-legacy-ui-analysis.md | Existing UI analysis (LEGACY only, renamed từ phase0-5-legacy-ui.md) |`

4. **Cập nhật Phase Ordering:**
   - Nếu api-only: `0 → 0.5 (skip-exit)`
   - Nếu LEGACY: `0 → 0.5-workload → 0.5-legacy-ui → 1 → 2 → 3 → 4 → 5 → 6 → 7`
   - Nếu new: `0 → 0.5-workload → 1 → 2 → 3 → 4 → 5 → 6 → 7`

5. **Thêm section `## Session Isolation Protocol (ADR-OPT-02)`:**
   ```
   sessions/{YYYYMMDD-HHMMSS}-{hash4}/
   ├── session-state.json
   ├── design-ux-status.json
   ├── checkpoint.json
   ├── lanes/
   │   ├── {module-slug}-screens/
   │   │   └── signals.json
   │   └── ...
   ├── workload-report.md
   ├── aggregation-result.json
   ├── ux-input-digest.json          ← Working copy (post-strip → _meta/)
   └── phase-summary.md

   latest pointer: .mc-data/work/wf-design-ux/latest
   Cleanup: giữ 5 sessions
   ```

6. **Thêm section `## _shared Module Imports (ADR-OPT Integration)`** — giống các skill khác.

7. **Thêm section `## Conditional Skip Handling (api-only)`:**
   ```
   Nếu interface_type == "api-only" (đọc từ req-registry.json):
   1. Session vẫn được tạo (audit trail) — cleanup sau 5 sessions như bình thường.
   2. Phase 0.5.0 exit gate: ghi skipped status, return success với 0 canonical outputs.
   3. KHÔNG tạo ux-input-digest.json canonical — wf-plan-modules PRE-GATE handle thiếu digest theo §4b.
   4. phase-summary.md vẫn viết: "Skill skipped — project is api-only."
   ```

---

### Task 3: Cập nhật `procedures/phase0-context.md`

**Vị trí:** `.claude/skills/workflow/wf-design-ux/procedures/phase0-context.md`

**Thay đổi cần thực hiện:**

1. **Step 0.2b** session creation (pattern chuẩn).

2. **Cập nhật Step 0.3** — `design-ux-status.json` vào `$SESSION_DIR/`.

3. **`--resume` handler** đọc `$SESSION_DIR/session-state.json`.

4. **Cập nhật Next phase:** thêm `phase0.5-workload-gate.md` (phase 0.5.0 sẽ handle api-only skip).

5. **KHÔNG thêm api-only check ở Phase 0** — để Phase 0.5.0 handle (consistent exit point).

---

### Task 4: Cập nhật `procedures/phase3-screen-groups.md`

**Vị trí:** `.claude/skills/workflow/wf-design-ux/procedures/phase3-screen-groups.md`

**Thay đổi cần thực hiện:**

1. **Cập nhật Step 3.X (screen group dispatch)** — Lane Dispatch:
   ```
   | 3.X | Lane Dispatch (ADR-OPT-01): Import _shared/lane/dispatcher.py.
        Build LaneConfig list: mỗi UI module → LaneConfig(
          key="{module-slug}-screens",
          agent_type="ui-designer" (hoặc "ux-designer" tùy module requirements),
          prompt=UI designer Phase 3 template từ _shared.md,
          output_path=$SESSION_DIR/lanes/{module-slug}-screens/signals.json,
          context={module features, design system tokens từ Phase 1, navigation từ Phase 2, legacy UI analysis nếu LEGACY}
        ).
        dispatch_lanes(lanes, max_parallel=$LPM_PARAMS.max_parallel_agents, timeout_sec=300).
        Filter UI modules: has_ui == true (check từ module feature specs hoặc interface flag). | Lanes dispatched |
   ```

2. **Verify lane outputs:**
   ```
   | 3.Y | Mỗi lane: verify signals.json + phase4-ux/{sys}/{mod}/screens-{group}.md non-empty | test -s lanes/{mod}-screens/signals.json |
   ```

3. **Checkpoint update:** session-state.json phases.P3.batches[{mod}-screens].status.

4. **Thêm note:**
   ```
   Lane output schema: _shared/templates/lane-signal.json
     lane_type="screen-group", items[]=[{screen_id, module_slug, screen_name, screen_type, ...}]
   Write-scope isolation: mỗi module lane ghi vào phase4-ux/{sys}/{mod}/ riêng.
   ```

---

### Task 5: Cập nhật `procedures/phase4-crossval.md`

**Vị trí:** `.claude/skills/workflow/wf-design-ux/procedures/phase4-crossval.md`

**Thay đổi cần thực hiện:**

1. **Thêm step signal aggregation đầu phase:**
   ```
   | 4.0 | Signal Aggregation (ADR-OPT-04): Import _shared/aggregate/aggregator.py.
          aggregate_lane_signals(lane_outputs=$SESSION_DIR/lanes/*/signals.json, dedup_key_fn=dedup_by_id("screen_id")).
          Output: $SESSION_DIR/aggregation-result.json.
          Special handling: reuse cross-module → KHÔNG flag conflict, thay vào merge vào shared design system (Phase 1 revision nếu cần). | aggregation-result.json written |
   ```

2. **Auto-correction logic** vẫn giữ nguyên (max 3 iterations), chỉ thêm input từ aggregation-result conflicts.

---

### Task 6: Cập nhật `procedures/phase7-digest-summary.md`

**Vị trí:** `.claude/skills/workflow/wf-design-ux/procedures/phase7-digest-summary.md`

**Thay đổi cần thực hiện:**

1. **Cập nhật step tạo `ux-input-digest.json`** — template strip + atomic write:
   ```
   | 7.X | Tạo $SESSION_DIR/ux-input-digest.json từ template `_digests/ux-input-digest.template.json` → **Template Strip (ADR-OPT-05)**:
          jq 'del(._template_notes, ._comments, ._examples, ._placeholder, ._description)' digest.json > digest-stripped.json.
          **Atomic Write**: write to $SESSION_DIR/ux-input-digest.json.tmp → jq validate → mv to final. | Digest hợp lệ JSON, không chứa _template_notes |
   ```

2. **Sync canonical:**
   ```
   | 7.X+1 | SYNC sang canonical _meta/ path:
          cp $SESSION_DIR/ux-input-digest.json .mc-data/docs/_meta/ux-input-digest.json
          | canonical file exists |
   ```

3. **POST-GATE check:**
   ```bash
   jq -e 'has("_template_notes")' .mc-data/docs/_meta/ux-input-digest.json → false
   ```

4. **Conditional exit handling (api-only):** Nếu skill skipped ở Phase 0.5.0, KHÔNG chạy Phase 7 — đã exit trước đó. phase-summary.md đã được tạo với skipped reason.

---

### Task 7: Cập nhật `procedures/phase0.5-legacy-ui-analysis.md` (renamed)

**Vị trí:** `.claude/skills/workflow/wf-design-ux/procedures/phase0.5-legacy-ui-analysis.md`

**Thay đổi cần thực hiện:**

1. **Chỉ rename file** — KHÔNG lane-ify nội dung.
2. **Update internal references** từ `phase0-5-legacy-ui` → `phase0.5-legacy-ui-analysis` trong phase file.
3. **Giữ nguyên output path** `.mc-data/docs/phase4-ux/existing-ui-analysis.md`.

---

## Constraints (BẮT BUỘC)

1. **KHÔNG thay đổi `registry_scope.fields_owned`** — vẫn là `["ux_design_status"]`.
2. **Conditional skip logic api-only PHẢI ở Phase 0.5.0** — consistent exit point.
3. **KHÔNG lane-ify Phase 1 (design system)** — single-owner, shared across modules (sequential OK).
4. **KHÔNG lane-ify Phase 2 (navigation)** — per-system, thường ít system → sequential OK.
5. **Rename atomic** — `phase0-5-legacy-ui.md` → `phase0.5-legacy-ui-analysis.md` phải cùng commit với references updates.
6. **Tiếng Việt cho docs/comments, English cho code/names** (CORE-005).
7. **Template Usage Rule (CORE-031)**.
8. **Surgical changes only (BHV-003)**.
9. **Session vẫn tạo khi api-only** — audit trail, cleanup policy vẫn áp dụng.
10. **`ux-input-digest.json` schema UNCHANGED** — backward compat với wf-plan-modules.

---

## Verify Checklist (sau khi hoàn tất)

| # | Check | Command |
|---|-------|---------|
| V1 | `phase0.5-workload-gate.md` tồn tại, có Step 0.5.0 api-only exit | `test -f .claude/skills/workflow/wf-design-ux/procedures/phase0.5-workload-gate.md && grep -q "api-only" .claude/skills/workflow/wf-design-ux/procedures/phase0.5-workload-gate.md` |
| V2 | `phase0.5-legacy-ui-analysis.md` tồn tại, không còn `phase0-5-legacy-ui.md` | `test -f .claude/skills/workflow/wf-design-ux/procedures/phase0.5-legacy-ui-analysis.md && ! test -e .claude/skills/workflow/wf-design-ux/procedures/phase0-5-legacy-ui.md` |
| V3 | `_shared.md` có Session Isolation + Conditional Skip Handling sections | `grep -q "Session Isolation\|Conditional Skip" .claude/skills/workflow/wf-design-ux/procedures/_shared.md` |
| V4 | `phase0-context.md` có Step 0.2b | `grep -q "0.2b" .claude/skills/workflow/wf-design-ux/procedures/phase0-context.md` |
| V5 | `phase3-screen-groups.md` có Lane Dispatch reference | `grep -q "Lane Dispatch" .claude/skills/workflow/wf-design-ux/procedures/phase3-screen-groups.md` |
| V6 | `phase4-crossval.md` có Signal Aggregation (screen_id) | `grep -q "Signal Aggregation" .claude/skills/workflow/wf-design-ux/procedures/phase4-crossval.md && grep -q "screen_id" .claude/skills/workflow/wf-design-ux/procedures/phase4-crossval.md` |
| V7 | `phase7-digest-summary.md` có template strip + atomic write | `grep -qE "_template_notes\|Atomic Write" .claude/skills/workflow/wf-design-ux/procedures/phase7-digest-summary.md` |
| V8 | `_contract.json` JSON valid + version = 4.0.0 | `node -e "const c=JSON.parse(require('fs').readFileSync('.claude/skills/workflow/wf-design-ux/_contract.json')); console.log(c.version)"` → `4.0.0` |
| V9 | `registry_scope.fields_owned` không thay đổi | `node -e "const c=JSON.parse(require('fs').readFileSync('.claude/skills/workflow/wf-design-ux/_contract.json')); console.log(JSON.stringify(c.registry_scope.fields_owned))"` → `["ux_design_status"]` |
| V10 | Phase 1 (design-system) + Phase 2 (navigation) KHÔNG có Lane Dispatch | `! grep -q "Lane Dispatch" .claude/skills/workflow/wf-design-ux/procedures/phase1-design-system.md && ! grep -q "Lane Dispatch" .claude/skills/workflow/wf-design-ux/procedures/phase2-navigation.md` |

---

## Post-Rollout Validation

Sau khi V1-V10 PASS:
1. `./.claude/scripts/skill-compliance-audit.sh wf-design-ux`
2. `./.claude/scripts/validate-schema-sync.sh wf-design-ux`
3. Evals thêm ≥3 test cases:
   - `api-only-skip` — interface_type="api-only" → skill exit ở Phase 0.5.0, không tạo ux-input-digest.json canonical
   - `session-isolation-multi-run`, `workload-gate-dead-zone`, `lane-dispatch-parallel`, `template-strip-no-leak`
4. `/audit-devkit-scan` + `/audit-devkit-verify --skill=wf-design-ux` + `/audit-devkit-fix`
5. `/audit-skill-output wf-design-ux`
6. Integration test 2 scenarios:
   - **Scenario A (non-api-only):** `/wf-design` → `/wf-design-ux` → verify full pipeline tạo digest
   - **Scenario B (api-only):** `/wf-design` (với interface_type="api-only") → `/wf-design-ux` → verify skip + exit success + `/wf-plan-modules` PRE-GATE bypass ux digest OK
7. Update sign-off doc.
