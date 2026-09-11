# Phase 6 — Output Report + Phase Summary + Execution Trace

> **Self-contained phase file.** Finalization — gộp Phase 6 (Output Report) + Phase 7 (Phase Summary + Trace).
> Protocol 14 (Phase Summary — CORE-028) + Protocol 15 (Execution Trace — CORE-026).
> Chạy BẤT KỂ kết quả Phase 4 (apply / dry-run stop / user cancel / E006 warning).

---

## PRE-GATE

Một trong các path sau:
- Phase 4 POST-GATE PASS (apply thành công)
- Phase 3 STOP (`--dry-run`) — report dry-run
- Phase 3 cancellation (user denied) — report cancellation
- Phase 1/2 WARNING E006 (nothing to do) — report no-op

---

## 📥 INPUT

- `$SESSION_DIR/add-scope-status.json`
- `$SESSION_DIR/scope-spec.json`
- `$BACKUP_PATH` (nếu Phase 4 chạy)

---

## 📤 OUTPUT

| File | Template |
|---|---|
| Terminal report | — (inline display) |
| `$SESSION_DIR/scope-impact.json` | `templates/scope-impact.json` (via `as-scope-impact-build.sh`) |
| `$SESSION_DIR/add-scope-plan.md` | `templates/add-scope-plan.md` (update checkboxes) |
| `$SESSION_DIR/phase-summary.md` | `doc-framework/_meta/phase-summary.template.md` |
| `.mc-data/work/_trace/session-log.json` | (APPEND COMPLETE entry) |

---

## Steps

### Step 6.1 — Build scope-impact.json (delegate)

```bash
bash .claude/scripts/wf-add-scope/as-scope-impact-build.sh "$SESSION_DIR"
# Output saved to $SESSION_DIR/scope-impact.json
```

**Graceful:** Nếu Phase 4 không chạy (dry-run / cancelled) → builder tạo scope-impact.json với `modules_added:[]` và `features_added:[]`.

---

### Step 6.2 — In terminal report

**Format đầy đủ (khi Phase 4 PASS):**

```markdown
## Add-Scope Hoàn Tất — $SYSTEM_ID

### Summary

- Modules added: $MODULES_ADDED_COUNT (MOD-..., MOD-..., ...)
- Features added: $FEATURES_ADDED
- Phase 2 stubs created: $STUBS_CREATED files trong `phase2-features/[sys-slug]/**`
- Skipped (already exist OR deprecated): $SKIPPED_COUNT

### Registry State

- Systems: $SYSTEMS_COUNT (unchanged)
- Modules: $MODULES_BEFORE → $MODULES_AFTER (+$MODULES_ADDED_COUNT)
- Features: $FEATURES_BEFORE → $FEATURES_AFTER (+$FEATURES_ADDED)
- Backup: `$BACKUP_PATH`

### scope-impact.json

Tạo tại `$SESSION_DIR/scope-impact.json` — consumers: `/wf-define-features`, `/wf-plan-modules`, `/wf-preflight`.

### Next Steps

1. **Review stubs:** `ls .mc-data/docs/phase2-features/[sys-slug]/**/*.md`
2. **(Optional) Flesh-out features:** `/wf-define-features $SYSTEM_ID`
3. **Re-run plan:** `/wf-plan-modules`
4. **(LEGACY only)** `/wf-annotate-code --module=[MOD-ID]` cho mỗi module mới

### Rollback Instructions (nếu cần)

cp $BACKUP_PATH .mc-data/docs/_meta/req-registry.json
```

**Format khi `--dry-run`:**

```markdown
## Add-Scope Dry-Run Complete — $SYSTEM_ID

Changes preview tại: `$SESSION_DIR/dry-run-diff.md`

Để apply: /wf-add-scope --system=$SYSTEM_ID [flags-without--dry-run]
```

**Format khi user cancelled OR E006:**

```markdown
## Add-Scope Cancelled — $SYSTEM_ID

Registry KHÔNG modified. Lý do: [user cancelled | all modules đã tồn tại]

Để re-run: /wf-add-scope --system=$SYSTEM_ID [...flags]
```

---

### Step 6.3 — Update `$SESSION_DIR/add-scope-status.json`

```
UPDATE add-scope-status.json:
  status                       = "completed" | "cancelled" | "dry-run-only"
  timestamps.completed_at      = now() (ISO format)
  phase_6.scope_impact_built   = true (nếu as-scope-impact-build.sh PASS)
  # Phase 6+7 merged — mark phase_7 completed together
  phases.phase_7.status        = "completed"
  phases.phase_7.phase_summary_created = true
  phases.phase_7.execution_trace_appended = true
```

---

### Step 6.4 — Update `$SESSION_DIR/add-scope-plan.md`

Mark tất cả steps completed với status indicators (checkboxes `[x]`).

---

### Step 6.5 — Phase Summary (CORE-028, Protocol 14)

**📋 Áp dụng Template Usage Rule:**

```
READ .claude/doc-framework/_meta/phase-summary.template.md

POPULATE bằng tiếng Việt, non-specialist audience:
  - Skill name: /wf-add-scope
  - Kết quả:
    * [N] modules mới đã thêm vào registry cho system [SYS-ID]
    * [N] features mới đã thêm (LEGACY_MODE only)
    * [N] Phase 2 doc stubs đã tạo
    * [N] modules bị skip (đã tồn tại OR deprecated)
  - Trạng thái registry:
    * Modules: [before] → [after]
    * Features: [before] → [after]
  - Bước tiếp theo:
    1. Review Phase 2 stubs (nếu có)
    2. Chạy `/wf-define-features` để flesh-out
    3. Chạy `/wf-plan-modules` để regenerate planning
  - Backup:
    * File: `req-registry.json.pre-addscope-<timestamp>`
    * Restore: `cp [backup] req-registry.json`

WRITE $SESSION_DIR/phase-summary.md
```

**Verify:** File tồn tại, non-empty, tiếng Việt.

---

### Step 6.6 — Append JSONL Index (status: completed)

```bash
ENTRY=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg sys "$SYSTEM_ID" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson mods "${MODULES_ADDED_COUNT:-0}" \
  --argjson feats "${FEATURES_ADDED:-0}" \
  '{session_id:$sid, target_system:$sys, status:"completed",
    completed_at:$ts, modules_added:$mods, features_added:$feats}')
bash .claude/scripts/wf-add-scope/as-index-append.sh "$ENTRY"
```

---

### Step 6.7 — Execution Trace COMPLETE entry (CORE-026)

Xem `_shared.md §10` cho pattern đầy đủ.

```bash
DETAILS=$(jq -n \
  --arg sys "$SYSTEM_ID" --arg mode "$MODE" --arg legacy "$LEGACY_MODE" \
  --argjson mods "${MODULES_ADDED_COUNT:-0}" \
  --argjson feats "${FEATURES_ADDED:-0}" \
  --argjson stubs "${STUBS_CREATED:-0}" \
  --arg dry "$DRY_RUN" \
  '{target_system:$sys, mode:$mode, legacy_mode:$legacy,
    modules_added:$mods, features_added:$feats, stubs_created:$stubs, dry_run:$dry}')
# Append COMPLETE entry → .mc-data/work/_trace/session-log.json (pattern ở _shared.md §10)
```

---

### Step 6.8 — Release locks + kill heartbeat

```bash
# Safety net: release registry lock if still held (error path may have missed it)
bash .claude/scripts/wf-add-scope/as-release-lock.sh registry "$SESSION_DIR" 2>/dev/null || true
# Release session lock
bash .claude/scripts/wf-add-scope/as-release-lock.sh session "$SESSION_DIR"
kill "$HEARTBEAT_PID" 2>/dev/null || true
```

---

### Step 6.9 — POST-GATE T1→T4 (delegate)

```bash
bash .claude/scripts/wf-add-scope/as-postgate-check.sh "$SESSION_DIR/scope-impact.json" json
bash .claude/scripts/wf-add-scope/as-postgate-check.sh "$SESSION_DIR/phase-summary.md" md 100 "Kết quả" "Bước tiếp theo"
```

- FAIL bất kỳ → auto-fix retry 3 lần → nếu vẫn fail → STOP, ESCALATE

---

## POST-GATE

- Terminal report displayed (format tùy theo apply/dry-run/cancel)
- `$SESSION_DIR/scope-impact.json` tạo bởi `as-scope-impact-build.sh`
- `$SESSION_DIR/add-scope-status.json` updated với final state
- `$SESSION_DIR/add-scope-plan.md` marked all steps completed
- `$SESSION_DIR/phase-summary.md` tồn tại, non-empty, tiếng Việt, đủ sections
- JSONL index entry appended (status: completed)
- Execution trace COMPLETE entry appended
- Session lock released + heartbeat killed
- T1→T4 validation all pass

---

## Next Workflow Step (user-facing)

```
→ /wf-plan-modules (re-run với new modules)
  HOẶC
→ /wf-define-features $SYSTEM_ID (flesh-out feature stubs)
  HOẶC (LEGACY)
→ /wf-annotate-code --module=[MOD-ID] (cho mỗi module mới)
```
