# Phase 3: Screen Groups — Lane Dispatch (ADR-OPT-01)

> Tạo screen group specs cho từng module có UI — mỗi UI module là 1 lane.
> **[ADR-OPT-01]** Lane Dispatch: `dispatch_lanes()` với `max_parallel = $LPM_PARAMS.max_parallel_agents`.
> Lane key format: `{module-slug}-screens`. Write-scope isolation: mỗi lane ghi vào `phase4-ux/{sys}/{mod}/` riêng.

**PRE-GATE:**
- [ ] Phase 2 (`phase2-navigation.md`) POST-GATE PASS
- [ ] `ls .mc-data/docs/phase4-ux/*/Navigation-*.md` có ít nhất 1 file

**INPUT:**
- `.mc-data/docs/phase4-ux/*/Navigation-*.md`
- `.mc-data/docs/phase4-ux/design-system.md`
- `.mc-data/docs/phase2-features/**/*.md`
- `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md`
- `.mc-data/docs/phase3-architecture/technical-specs/integration-map.md` (v4.1 — cross-module data needs)
- `$SCREEN_INVENTORY` + `$WORKFLOW_MAP` (từ Phase 2 Step 2.0 — v4.1)

**OUTPUT:** `.mc-data/docs/phase4-ux/[sys]/[mod]/screens-[group].md` (một file per screen group)

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates → P3 (ux-designer)
- `_shared.md` §_shared Module Imports (ADR-OPT Integration)
- `_shared.md` §LEGACY Context Injection (nếu LEGACY_MODE)
- `_shared.md` §Large Project Mode (max_parallel_agents, checkpoint_strategy)
- `_shared.md` §Token Limit Prevention
- `_shared.md` §Checkpoint Protocol

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 3.1 | Extract danh sách UI modules từ Navigation specs (filter `has_ui == true` hoặc interface không phải api-only). Loại bỏ `$DEPRECATED_MODULES`. Group theo system. | UI modules list per system |
| 3.2 | Per system: `mkdir -p .mc-data/docs/phase4-ux/[sys]/[mod]/` + **[SCAFFOLD-FIRST]** — xem §Scaffold Screen Groups | Directory + scaffold files exist |
| 3.3 | **Lane Dispatch (ADR-OPT-01):** Import `_shared/lane/dispatcher.py`. Build `LaneConfig` list — mỗi UI module tạo 1 lane:<br>`LaneConfig(key="{module-slug}-screens", agent_type="ux-designer", prompt=_shared.md §P3, output_path=$SESSION_DIR/lanes/{module-slug}-screens/signals.json, context={module features, design system tokens từ Phase 1, navigation từ Phase 2, legacy UI analysis nếu LEGACY})`.<br>Filter UI modules: `has_ui == true` (cross-check từ module feature specs + interface flag). Modules thuộc `$DEPRECATED_MODULES` → SKIP.<br>`dispatch_lanes(lanes, max_parallel=$LPM_PARAMS.max_parallel_agents, timeout_sec=300)`. | Lanes dispatched |
| 3.4 | Wait ALL lane agents complete → Verify mỗi lane: `test -s $SESSION_DIR/lanes/{mod}-screens/signals.json` + screen group files non-empty | `test -s lanes/{mod}-screens/signals.json` |
| 3.5 | **LOG AGENTS** — append `ux-designer` (per lane) vào `$SESSION_DIR/design-ux-status.json` → `metrics.agents_spawned[]` | Agents logged |
| 3.6 | **SAVE CHECKPOINT** — Standard: per batch, LPM: per system. POPULATE `$SESSION_DIR/checkpoint.json` với position, lane_states, modules_state, files_state, next_action | Checkpoint saved |

---

## Scaffold Screen Groups (Step 3.2)

```
PER SYSTEM [sys]:
  PER MODULE [mod] trong system:
    mkdir -p .mc-data/docs/phase4-ux/[sys]/[mod]/
    
    FOR EACH screen group trong Navigation-[sys].md (Danh Sách Screen Groups):
      screen_file = .mc-data/docs/phase4-ux/[sys]/[mod]/screens-[group-slug].md
      
      IF NOT test -f screen_file:
        READ $PHASE4_CONTRACT["screen-group"].required_sections + optional_sections
        Pre-tạo screen_file với:
          # [Screen Group Name]
          
          Implements: [FEAT-IDs từ Navigation]
          
          ## 1. Main Page Layout
          <!-- TODO: fill content -->
          
          ## 2. Tabs
          <!-- TODO: fill content hoặc N/A -->
          
          ... (required sections)
          
          <!-- Optional sections (xóa nếu không có):
          ## Dialogs/Popups
          ## Sheets/Drawers
          ## View Modes
          -->
          
          ## 6. API Endpoints Used
          <!-- TODO: fill content -->
          
          ## 7. UI-ID Registry
          <!-- TODO: fill content -->
```

---

## Lane Output Schema

```json
// $SESSION_DIR/lanes/{module-slug}-screens/signals.json
// Schema: ../_shared/templates/lane-signal.json
{
  "lane_type": "screen-group",
  "lane_key": "{module-slug}-screens",
  "module_slug": "{module-slug}",
  "system_id": "SYS-XXX",
  "items": [
    {
      "screen_id": "UI-SYS-MOD-SCREEN-001",
      "module_slug": "{module-slug}",
      "screen_name": "...",
      "screen_type": "list|detail|form|dashboard",
      "feat_ids": ["FEAT-XXX-001"],
      "file_path": ".mc-data/docs/phase4-ux/{sys}/{mod}/screens-{group}.md",
      "status": "created|skipped|error"
    }
  ],
  "agent_type": "ux-designer",
  "completed_at": "[ISO 8601]",
  "errors": []
}
```

**Write-scope isolation:** Mỗi module lane ghi vào `phase4-ux/{sys}/{mod}/` riêng — KHÔNG có shared write path.
**Dedup key:** `screen_id` (SCREEN-ID). Reuse component cross-module KHÔNG phải conflict — aggregate vào shared design system (Phase 1 revision nếu cần).

---

## Parallel Execution Pattern (Step 3.3 — Lane Dispatch)

```
# Build LaneConfig per UI module
ui_modules = filter_ui_modules(navigation_specs, deprecated=$DEPRECATED_MODULES)
lanes = []
FOR each module IN ui_modules:
  # SKIP-IF-EXISTS check per module
  existing_signals = test -f $SESSION_DIR/lanes/{module.slug}-screens/signals.json
  IF existing_signals AND all screen files exist:
    log "Lane {module.slug}-screens đã hoàn thành — skip"
    CONTINUE
  
  lanes.append(LaneConfig(
    key = f"{module.slug}-screens",
    agent_type = "ux-designer",
    prompt = _shared.md §P3 (populate với module context),
    output_path = $SESSION_DIR/lanes/{module.slug}-screens/signals.json,
    context = {
      module_features: feature specs của module,
      design_system: design-system.md tokens (key sections only),
      navigation: Navigation-{sys}.md (module section),
      workflow_context: { $WORKFLOW_MAP slice cho module, $SCREEN_INVENTORY entries của module } (v4.1),
      integration_map: cross-module dependencies của module (v4.1),
      legacy_ui: $UI_CONTEXT_SUMMARY nếu LEGACY_MODE
    }
  ))

# Dispatch lanes
dispatch_lanes(lanes, max_parallel=$LPM_PARAMS.max_parallel_agents, timeout_sec=300)
# Standard max_parallel: 5 — LPM: 3

# Wait và validate
FOR each lane IN dispatched_lanes:
  wait_lane_complete(lane)
  verify: test -s $SESSION_DIR/lanes/{lane.key}/signals.json
  
  IF $LARGE_PROJECT:
    SAVE CHECKPOINT per lane (LPM)

IF NOT $LARGE_PROJECT:
  SAVE CHECKPOINT per batch (Standard)

# Context threshold check
IF $CONTEXT_PERCENT >= 65%:
  finish current lane, KHÔNG start lanes mới
  IF $CONTEXT_PERCENT >= 80%:
    FORCE SAVE CHECKPOINT, STOP session, prompt --resume
```

**Agent prompt:** Xem `_shared.md §Agent Prompt Templates → P3`.

**INJECT LEGACY BLOCK** nếu `$LEGACY_MODE = true`. Modules thuộc `$DEPRECATED_MODULES` → KHÔNG tạo lane (skip hoàn toàn).

---

## Token Limit Strategy

> Phase 3 là phase nặng nhất — context dễ vượt ngưỡng.

| Điều kiện | Strategy |
|-----------|----------|
| 5+ systems có UI | Chia batch theo system (Standard: 5/batch, LPM: 3/batch) |
| Context >= 65% sau 1 batch | Finish current batch, không start batch mới, chuẩn bị checkpoint |
| Context >= 80% | FORCE SAVE CHECKPOINT ngay, resume session mới với `--resume` |
| Agent timeout | Retry 1 lần; nếu vẫn fail → mark system pending, continue batch, escalate sau batch |

---

## POST-GATE

- [ ] `ls $SESSION_DIR/lanes/*/signals.json` trả về ít nhất 1 file (lane outputs)
- [ ] Mỗi `signals.json` non-empty và có `items[]` array (`jq -e '.items | length > 0'`)
- [ ] `ls .mc-data/docs/phase4-ux/*/*/screens-*.md` trả về ít nhất 1 file
- [ ] Mỗi screen group file non-empty (`test -s`)
- [ ] **[Protocol 10 — T3]** Verify mỗi file >= 200 từ:
  ```bash
  for f in .mc-data/docs/phase4-ux/*/*/screens-*.md; do
    wc -w "$f" | awk '$1 < 200 {print "FAIL: " $2}'
  done
  ```
  Nếu FAIL → re-run ux-designer cho screen group đó (max 3 retries)
- [ ] Mỗi screen group có header "Implements: FEAT-XXX" (FEAT-ID traceability)
- [ ] **(v4.1 — R7 Tab Completeness)** Không có placeholder tab trong sections TABS:
  ```bash
  grep -in 'tương tự\|same pattern\|<!-- TODO' .mc-data/docs/phase4-ux/*/*/screens-*.md \
    | grep -i 'tab' || echo "PASS: no placeholder tabs"
  ```
  Nếu FAIL → re-run ux-designer cho screen group đó với instruction thiết kế đầy đủ từng tab (max 3 retries)
- [ ] **(v4.1 — R6 Data Grid)** Screen kiểu List phải đề cập search + filter + pagination:
  ```bash
  for f in .mc-data/docs/phase4-ux/*/*/screens-*.md; do
    if grep -qi 'Loại.*List\|Danh Sách' "$f"; then
      grep -qi 'pagination\|Phân trang' "$f" || echo "FAIL (missing pagination): $f"
      grep -qi 'filter\|Bộ lọc\|Lọc' "$f" || echo "FAIL (missing filter): $f"
    fi
  done
  ```
- [ ] **(v4.1 — R4/R5)** Screen detail của business object có trong `$WORKFLOW_MAP` phải reference owner/status (grep "owner\|phụ trách\|trạng thái\|status")
- [ ] UI-IDs unique across tất cả screen groups (cross-validation Phase 4 sẽ kiểm tra chi tiết)
- [ ] Checkpoint đã save (per batch hoặc per lane tùy LPM)

**Next phase:** `phase4-crossval.md`

---

## Auto-Correction

- File rỗng → re-run ux-designer
- Missing section → re-run với instruction bổ sung missing sections
- Missing FEAT-ID → auto-inject từ Navigation spec
- Word count < 200 → re-run với instruction tăng detail (layout description, component breakdown)
- **(v4.1)** Placeholder tab → re-run với instruction thiết kế đầy đủ từng tab theo R7
- **(v4.1)** List screen thiếu filter/pagination → re-run bổ sung theo R6
- **(v4.1)** Detail screen thiếu owner/status/progress → re-run với $WORKFLOW_MAP + integration-map context
- Max 3 retries per screen group, sau đó escalate
