# Phase 0 — Context Loading & Validation

> **Self-contained phase file.** Tham chiếu `_shared.md` cho State Variables, Template Usage Rule, Fix Rules, Error Codes, LEGACY_MODE Detection.

---

## PRE-GATE

```bash
# Forensic registry validation (CORE-011 — content check, không chỉ existence)
jq -e '.systems | length > 0 and .modules != null' .mc-data/docs/_meta/req-registry.json
```

- **FAIL → STOP E004:** *"Registry JSON invalid. Fix manually trước khi chạy add-scope."*

---

## 📥 INPUT

| File | Đường dẫn | Điều kiện |
|------|-----------|-----------|
| Registry | `.mc-data/docs/_meta/req-registry.json` | BẮT BUỘC |
| Module-code mapping | `.mc-data/work/legacy-scan/module-code-mapping.json` | BẮT BUỘC nếu `--from-mapping` |
| Project context | `.mc-data/work/legacy-scan/project-context.md` | Optional (LEGACY_MODE detection) |
| Legacy decisions | `.mc-data/work/wf-brainstorm/legacy-decisions.json` | Optional |

---

## 📤 OUTPUT

| File | Template |
|------|----------|
| `$SESSION_DIR/add-scope-status.json` | `templates/add-scope-status.json` |
| `$SESSION_DIR/add-scope-plan.md` | `templates/add-scope-plan.md` |

---

## Steps

### Step 0.1 — Delegate to session-init.md

```
Read procedures/session-init.md → execute all steps SI.1–SI.7
Returns: $SESSION_ID, $SESSION_DIR, $LOCK_PATH, $HEARTBEAT_PID
```

---

### Step 0.2 — Handle `--status` / `--resume` flags

```
IF $ARGUMENTS chứa "--status":
  tail -n 100 .mc-data/work/wf-add-scope/_index/sessions.jsonl 2>/dev/null | \
    jq -s 'group_by(.session_id) | map(max_by(.created_at)) |
           .[] | {session_id, status, system:.target_system, created_at, completed_at}'
  DISPLAY sessions table → EXIT skill

IF $ARGUMENTS chứa "--resume":
  Read procedures/resume-routing.md → execute → route to phase file
  STOP (no further execution in Phase 0)
```

---

### Step 0.3 — Parse arguments

```
EXTRACT từ $ARGUMENTS:
  $SYSTEM_ID     = value của --system flag         (REQUIRED)
  $MODULES_LIST  = value của --modules flag (split by comma nếu có)
  $FROM_MAPPING  = --from-mapping flag present (bool)
  $FROM_SCAN     = value của --from-scan flag (session_id hoặc path)
  $INTERACTIVE   = --interactive flag present (bool)
  $DRY_RUN       = --dry-run flag present (bool)
  $NO_DOCS       = --no-docs flag present (bool)
```

**Verify:** `$SYSTEM_ID` non-empty. Nếu empty → STOP, hỏi user cung cấp `--system=<id>`.

#### Step 0.3b — Hint recent wf-scan-target session

Khi user KHÔNG pass `--from-scan` và KHÔNG pass `--from-mapping` → check recent scan session (< 7 ngày). Hint không block flow.

```bash
if [[ -z "$FROM_SCAN" && "$FROM_MAPPING" != "true" ]]; then
  scans_dir=".mc-data/work/wf-scan-target/sessions"
  if [[ -d "$scans_dir" ]]; then
    recent_scan=$(find "$scans_dir" -maxdepth 1 -type d -mtime -7 \
      ! -path "$scans_dir" 2>/dev/null | sort | tail -1)
    if [[ -n "$recent_scan" ]]; then
      recent_id=$(basename "$recent_scan")
      echo "💡 Tip: Có session scan-target gần đây ($recent_id). Dùng --from-scan=$recent_id để auto-seed modules."
    fi
  fi
fi
```

---

### Step 0.4 — Validate system exists

```bash
jq -e ".systems[] | select(.id == \"$SYSTEM_ID\")" .mc-data/docs/_meta/req-registry.json
```

- **FAIL → STOP E001:** *"System `$SYSTEM_ID` không tồn tại. Available: [list systems]. KHÔNG auto-create system."*

---

### Step 0.5 — LEGACY_MODE Detection (delegate — CORE-021)

```bash
RESULT=$(bash .claude/scripts/wf-add-scope/as-detect-legacy.sh)
LEGACY_MODE=$(echo "$RESULT" | jq -r '.legacy_mode')
DEPRECATED_MODULES=$(echo "$RESULT" | jq -c '.deprecated_modules')
```

**Gate combine với `$FROM_MAPPING`:**

```
IF $FROM_MAPPING == true AND $LEGACY_MODE == false:
  STOP E003: "--from-mapping yêu cầu LEGACY_MODE. Chạy /wf-legacy-scan trước hoặc dùng --interactive."
```

---

### Step 0.6 — Khởi tạo status files (Template Usage Rule — CORE-031)

```
## add-scope-status.json
READ templates/add-scope-status.json
POPULATE:
  - "$schema": "add-scope-status-v3.0"
  - schema_version: "add-scope-status-v3.0"
  - session_id: $SESSION_ID
  - project: từ registry.project
  - target_system: $SYSTEM_ID
  - mode: derive từ flags (from-mapping | from-scan | modules-list | interactive)
  - legacy_mode: $LEGACY_MODE
  - host: $(hostname)
  - user: $(whoami)
  - arguments.*: từ parsed flags
  - timestamps.started_at: now() (ISO format)
  - phases.phase_0.status: "in_progress"
WRITE $SESSION_DIR/add-scope-status.json

## add-scope-plan.md
READ templates/add-scope-plan.md
POPULATE:
  - {PROJECT_NAME}: từ registry.project
  - {SESSION_ID}: $SESSION_ID
  - {SESSION_DIR}: $SESSION_DIR
  - {SYSTEM_ID}: $SYSTEM_ID
  - {YYYY-MM-DD}: current date
  - {MODE}: $MODE
  - {HOSTNAME}: $(hostname)
  - {LEGACY_MODE}: $LEGACY_MODE
  - Flags: populate theo parsed arguments
WRITE $SESSION_DIR/add-scope-plan.md
```

---

### Step 0.7 — Execution Trace START entry (CORE-026)

Xem `_shared.md §10` cho pattern đầy đủ.

```bash
DETAILS=$(jq -n \
  --arg sys "$SYSTEM_ID" \
  --arg mode "$MODE" \
  --arg legacy "$LEGACY_MODE" \
  --arg session "$SESSION_ID" \
  '{target_system:$sys, mode:$mode, legacy_mode:$legacy, session_id:$session}')
# Append START entry → .mc-data/work/_trace/session-log.json (pattern ở _shared.md §10)
```

---

## POST-GATE

- PRE-GATE forensic PASS (registry valid)
- `$SESSION_ID`, `$SESSION_DIR`, `$LOCK_PATH`, `$HEARTBEAT_PID` set (từ session-init.md)
- System target validated (tồn tại trong registry)
- `$LEGACY_MODE` detected và set (via `as-detect-legacy.sh`)
- `$SESSION_DIR/add-scope-status.json` tồn tại và populated từ template
- `$SESSION_DIR/add-scope-plan.md` tồn tại
- `add-scope-status.json.phases.phase_0.status` = `"completed"`
- Execution trace START entry appended

---

## Next Phase

→ Load `phase1-scope.md` để build `$SESSION_DIR/scope-spec.json`.
