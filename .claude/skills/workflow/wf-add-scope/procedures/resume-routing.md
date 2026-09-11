# Procedure: Resume Routing

> **Purpose:** Khi `--resume` flag set, route AI tới đúng phase file dựa trên `add-scope-status.json`.
> **Caller:** `procedures/phase0-context.md` Step 0.2.

---

## Step RR.1 — Discover sessions

```bash
tail -n 50 .mc-data/work/wf-add-scope/_index/sessions.jsonl 2>/dev/null | \
  jq -s 'group_by(.session_id) | map(max_by(.created_at)) | map(select(.status == "in_progress"))'
```

---

## Step RR.2 — Display sessions

```
IF count == 0:
  → STOP "Không có session in_progress để resume.
           Chạy /wf-add-scope --system=<id> để tạo session mới."
IF count == 1:
  → Auto-select → continue RR.3
IF count > 1:
  → AskUserQuestion: "Có [N] sessions in_progress. Chọn session_id để resume:" [list all]
```

---

## Step RR.3 — Re-bind state variables

```
$SESSION_ID  = (chosen session_id)
$SESSION_DIR = .mc-data/work/wf-add-scope/sessions/$SESSION_ID
$STATUS_FILE = $SESSION_DIR/add-scope-status.json
```

READ `$STATUS_FILE`:
```
$SYSTEM_ID     = .target_system
$MODE          = .mode
$LEGACY_MODE   = .legacy_mode
$DRY_RUN       = .arguments.dry_run
$NO_DOCS       = .arguments.no_docs
$CURRENT_PHASE = .current_phase
```

---

## Step RR.4 — Re-acquire session lock

```bash
RESULT=$(bash .claude/scripts/wf-add-scope/as-acquire-lock.sh session "$SESSION_DIR" 30)
LOCK_STATUS=$(echo "$RESULT" | jq -r '.status // .error')
```

- `status="acquired"` → continue RR.5
- `error="lock_held_alive"` → STOP E010 (session đang chạy elsewhere — PID/host shown)
- `error="lock_held_cross_host"` → STOP E011 (cross-host lock — manual resolve needed)
- `error="lock_acquire_failed"` → STOP E012 (filesystem error)

---

## Step RR.5 — Restart heartbeat daemon

```bash
nohup bash .claude/scripts/wf-add-scope/as-heartbeat.sh "$SESSION_DIR/.session.lock" 30 \
  > /dev/null 2>&1 &
echo $! > "$SESSION_DIR/.heartbeat.pid"
HEARTBEAT_PID=$!
```

---

## Step RR.6 — Route to phase file

| `current_phase` | `phase_N.status` | Action |
|-----------------|------------------|--------|
| 0 | `pending` / `in_progress` | Continue Phase 0 từ Step 0.3 (session vars đã re-bound) |
| 1 | `in_progress` | Read `phase1-scope.md` |
| 2 | `in_progress` | Read `phase2-stubs.md` |
| 2 | `skipped` | Phase 2 skipped (NEW project) → route to `phase3-dryrun.md` |
| 3 | `in_progress` | Read `phase3-dryrun.md` |
| 4 | `in_progress` | **CRITICAL:** Check `audit_chain.checksum_post` — nếu set → Phase 4 đã ghi → skip Phase 4, jump Phase 5 |
| 5 | `in_progress` | Read `phase5-docs.md` |
| 5 | `skipped` | Phase 5 skipped → route to `phase6-report.md` |
| 6 | `in_progress` | Read `phase6-report.md` |
| any | `completed` | AskUserQuestion: "Session đã hoàn thành. Tạo session mới hay cần review kết quả?" |
| any | `skipped` | Route to next non-skipped phase (N+1) |

---

## Step RR.7 — Append trace event

```bash
echo "{\"event\":\"RESUME\",\"session_id\":\"$SESSION_ID\",\"resumed_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"from_phase\":$CURRENT_PHASE}" \
  >> .mc-data/work/_trace/session-log.json
```
