# Phase 0: Context Loading

> Khởi tạo session, load registry + brainstorm context, tạo `analyze-status.json`.
> Entry point cho cả flow mới và `--resume`.

**PRE-GATE:**

```bash
test -f .mc-data/docs/_meta/req-registry.json        # E000 nếu FAIL
test -f .mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md  # E016 nếu FAIL (00-core Rule 2)
jq -e '.project and .departments and .interface_type' .mc-data/docs/_meta/req-registry.json  # E008 nếu FAIL — validate SEED fields only (CORE-011: wf-brainstorm seeds project/departments/interface_type)
```

> **Forensic validation (Protocol 10.4):** `P0-01-brainstorm.md`: >= 3 headings, >= 200 words. Nếu FAIL → "P0-01-brainstorm.md không đạt yêu cầu nội dung. Chạy `/wf-brainstorm` để tạo/hoàn thiện."

> **(CORE-026)** Append START entry vào `.mc-data/work/_trace/session-log.json` (xem `_shared.md §Execution Trace Protocol`). Include `$SESSION_ID` trong trace metadata (set ở Step 0.2b).

**INPUT:** Registry + brainstorm + `legacy-decisions.json` (nếu LEGACY) + checkpoint (nếu `--resume`)

**OUTPUT:**
- `.mc-data/work/wf-analyze-requirements/analyze-status.json`
- `$SESSION_DIR/session-state.json` (ADR-OPT-02)
- `.mc-data/work/wf-analyze-requirements/latest` (pointer)

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 0.1  | Check `--status`, `--resume` flags | Args validated |
| 0.2  | `mkdir -p .mc-data/work/wf-analyze-requirements/` | `test -d .mc-data/work/wf-analyze-requirements/` |
| 0.2b | **Session Isolation (ADR-OPT-02 + CORE-030):**<br>1. `$SESSION_ID = $(date -u +%Y%m%d-%H%M%S)-$(openssl rand -hex 2)` (fallback: `$(uuidgen \| cut -c1-4)`)<br>2. `$SESSION_DIR = .mc-data/work/wf-analyze-requirements/sessions/$SESSION_ID`<br>3. `mkdir -p $SESSION_DIR/lanes`<br>4. **Tạo session-state.json** (Template Usage Rule CORE-031): READ `.claude/skills/workflow/_shared/templates/session-state.json` → FILL `session_id`, `skill_name="wf-analyze-requirements"`, `created_at`, `updated_at`, `status="in_progress"`, `profile_used`, `next_action="phase0.5-workload-gate"`, `phases.P0 = {status: "in_progress"}` → **Template Strip** (`jq 'del(._template_notes)'`) → **Atomic Write** (tmp → validate → mv) → `$SESSION_DIR/session-state.json`<br>5. **Tạo latest pointer:** `echo "$SESSION_DIR" > .mc-data/work/wf-analyze-requirements/latest`<br>6. **Cleanup (Sign-off #3):** `ls -1d .mc-data/work/wf-analyze-requirements/sessions/*/ \| sort \| head -n -5 \| xargs -r rm -rf` | `test -d $SESSION_DIR && test -f $SESSION_DIR/session-state.json && test -f .mc-data/work/wf-analyze-requirements/latest` |
| 0.3  | Tạo `analyze-status.json` từ `.claude/skills/workflow/wf-analyze-requirements/templates/analyze-status.json` (Template Usage Rule). Ghi vào `$SESSION_DIR/analyze-status.json` VÀ copy về `.mc-data/work/wf-analyze-requirements/analyze-status.json` (dual-write — backward-compat cho `--status` handler cũ) | `test -f $SESSION_DIR/analyze-status.json && test -f .mc-data/work/wf-analyze-requirements/analyze-status.json` |
| 0.4  | Đọc `req-registry.json` → `$REGISTRY_DATA`. Validate SEED fields từ wf-brainstorm (`project`, `departments[]`, `interface_type`, `systems[]`). Extract `$BRAINSTORM_SYSTEMS = .systems[]` (seeded by brainstorm Phase 5.3 với `user_roles[]`, `touchpoints[]`, `related_departments[]`, `phase`). `modules[]`, `requirements[]` được populate bởi skill này (PRIMARY role) — không validate ở PRE-GATE. `systems[].module_ids[]` sẽ được enrich ở Phase 8 (không ghi đè fields đã seed). | Content loaded + SEED fields valid + `$BRAINSTORM_SYSTEMS` length > 0 |
| 0.4b | **Forensic validation systems[] (CORE-011):** `jq -e '(.systems \| length > 0) and all(.systems[]; (.user_roles // [] \| length > 0) and (.touchpoints // [] \| length > 0) and (.related_departments // [] \| length > 0))' req-registry.json`. Nếu FAIL → ERROR E008-SYS: "systems[] thiếu fields seed từ wf-brainstorm. Chạy lại /wf-brainstorm Phase 5.3 để seed đủ scope matrix (user_roles + touchpoints + related_departments)." STOP. | systems[] validation pass |
| 0.5  | Đọc `P0-01-brainstorm.md` → `$BRAINSTORM_CONTEXT` (extract project context) | Brainstorm loaded |
| 0.6  | Detect `$LEGACY_MODE` (CORE-021): `test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes`. Nếu true → load `$LEGACY_CONTEXT` | `$LEGACY_MODE` set |
| 0.6b | Nếu `$LEGACY_MODE = true` → đọc `.mc-data/work/wf-brainstorm/legacy-decisions.json` → `$LEGACY_DECISIONS`. Extract `$DEPRECATED_MODULES` = array module IDs có `action=DEPRECATE`. **GRACEFUL DEGRADATION (CORE-022):** Nếu file không tồn tại → LOG WARNING: "⚠️ legacy-decisions.json not found — user decisions từ wf-brainstorm chưa được propagate. Khuyến nghị chạy lại /wf-brainstorm Phase 0.5." Set `$DEPRECATED_MODULES = []`, tiếp tục không enforce scope exclusion. Ghi `flags.legacy_mode`, `flags.deprecated_modules_count` vào `analyze-status.json` | `$DEPRECATED_MODULES` loaded |
| 0.7  | **(RESUME RECONCILIATION — chỉ khi `--resume`)** Xem section "Argument Handling → `--resume` handler" bên dưới. | Checkpoint đã reconcile |

> **(CORE-022 enforcement downstream)** Tất cả phase sau (Phase 1-8) PHẢI reference `$DEPRECATED_MODULES` khi build expert agent prompts: "KHÔNG tạo requirements cho modules thuộc danh sách DEPRECATE: [$DEPRECATED_MODULES]". Mọi module trong `$DEPRECATED_MODULES` bị loại khỏi scope analysis, cross-validation, và handoff output.

## Argument Handling

### `--status` handler

```
IF test -f .mc-data/work/wf-analyze-requirements/checkpoint.json:
  checkpoint = đọc checkpoint.json
  actual_dept_files = find .mc-data/docs/phase1-business/departments/ -name "*.md" | wc -l
  → Hiển thị trạng thái theo project_type (legacy hoặc new):
    - Bao gồm dòng: "Files dept trên disk: [actual_dept_files]"
    - Nếu actual_dept_files != checkpoint.depts_completed → "(checkpoint chưa đồng bộ — chạy --resume để cập nhật)"
  → STOP
ELSE IF test -f analyze-status.json:
  → Hiển thị trạng thái từ analyze-status.json
  → STOP
ELSE:
  → "Chưa có analyze-requirements session nào."
  → STOP
```

### `--resume` handler

```
# Primary: đọc latest pointer → session-state.json (ADR-OPT-02)
IF test -f .mc-data/work/wf-analyze-requirements/latest:
  $SESSION_DIR = cat latest
  IF test -f $SESSION_DIR/session-state.json:
    state = đọc session-state.json
    → Tiếp tục Phase 0 (LEGACY_MODE tự detect từ project-context.md — CORE-021)
    → Dispatch theo state.next_action (vd: "phase0.5-workload-gate", "phase4-experts-partb")
    → **Reconciliation:** `find .mc-data/docs/phase1-business/departments/ -name "*.md"` → đếm dept files thực tế.
      Nếu `actual_depts_done != state.phases.P4.batches completed count` → cập nhật
      session-state.json phases.P4.batches, log: "Reconciled: [N] dept files on disk"
    → STOP (dispatch tiếp theo)

# Fallback: legacy checkpoint.json (backward-compat)
ELSE IF test -f .mc-data/work/wf-analyze-requirements/checkpoint.json:
  checkpoint = đọc checkpoint.json
  LOG WARNING: "session-state.json not found — fallback legacy checkpoint. Khuyến nghị chạy lại từ đầu để enable ADR-OPT-02."
  → Tiếp tục Phase 0 (LEGACY_MODE tự detect từ project-context.md)
  → Jump tới phase trong checkpoint.position.current_phase
ELSE:
  → STOP: "Không tìm thấy checkpoint. Chạy `/wf-analyze-requirements` từ đầu."
```

**POST-GATE:**

```bash
test -f .mc-data/work/wf-analyze-requirements/analyze-status.json
test -d $SESSION_DIR
test -f $SESSION_DIR/session-state.json
test -f .mc-data/work/wf-analyze-requirements/latest
jq -e '.phases.P0.status' $SESSION_DIR/session-state.json  # P0 started
```

> **(Protocol 6.6 — LPM-05)** Nếu `$LARGE_PROJECT = true` (xác định sau Phase 2): **SAVE CHECKPOINT** sau Phase 0. Ở Standard mode, checkpoint Phase 0 là optional.

**Status update:**
- `analyze-status.json` → `phase_0.status = "completed"`, `phase_0.completed_at = <ISO timestamp>`, `flags.legacy_mode`, `flags.deprecated_modules_count`, `session.id = $SESSION_ID`, `session.dir = $SESSION_DIR`.
- `$SESSION_DIR/session-state.json` → `phases.P0 = {status: "completed", completed_at: <ISO>}`, `next_action = "phase0.5-workload-gate"` (atomic write).

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id=0, status, items_processed (registry loaded, brainstorm loaded, legacy context), key_findings ($LEGACY_MODE, $DEPRECATED_MODULES count), next_action (Phase 1 scope)
3. WRITE: `.mc-data/work/wf-analyze-requirements/phase-summary.md`

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json`.

**Next phase:** `phase0.5-workload-gate.md`
