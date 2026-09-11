# wf-e2e-verify Orchestrator — Shared Protocols

## State Variables

```
$FEAT_ID = argument 1
$SESSION_DIR = .mc-data/work/wf-e2e-verify/sessions/${FEAT_ID}-${YYYYMMDD-HHmm}/
$E2E_STATUS = $SESSION_DIR/e2e-status.json
$ORCH_SUMMARY = $SESSION_DIR/orchestrator-summary.md
$SESSION_LOG = $SESSION_DIR/session-log.json
$ERROR_LEDGER = $SESSION_DIR/error-ledger.json
$LOCK = $SESSION_DIR/.lock
$PROMPT_CONTEXT = $SESSION_DIR/prompt-context.md
```

## Init Session

```bash
init_session() {
  ISO_SHORT=$(date -u +%Y%m%d-%H%M)
  SESSION_ID="${FEAT_ID}-${ISO_SHORT}"
  SESSION_DIR=".mc-data/work/wf-e2e-verify/sessions/${SESSION_ID}"
  
  mkdir -p "$SESSION_DIR"/{F1-test,F2-browser,F3-unblock,F4-implement,F5-retest,F6-fix,F7-scenario,F8-demo,findings,outputs,screenshots,_locks}
  
  # Init e2e-status.json from template
  jq --arg sid "$SESSION_ID" --arg fid "$FEAT_ID" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    del(._template_notes) | del(._schema_notes) |
    .session_id = $sid | .feat_id = $fid | .created_at = $now
  ' .claude/skills/workflow/wf-e2e-verify/templates/e2e-status.template.json > "$E2E_STATUS"
  
  # Init session-log + error-ledger
  echo '{"$schema":"session-log-v1","events":[]}' > "$SESSION_LOG"
  echo '{"$schema":"error-ledger-v1","errors":[]}' > "$ERROR_LEDGER"
  
  echo "# Prompt Context\n\nCommand: /wf-e2e-verify $ARGUMENTS" > "$PROMPT_CONTEXT"
  
  acquire_lock
}
```

## Lock Strategy

```bash
acquire_lock() {
  if [ -f "$LOCK" ]; then
    AGE=$(($(date +%s) - $(stat -c %Y "$LOCK")))
    if [ "$AGE" -gt 1800 ]; then
      log_error "E008" "init" "Stale lock auto-released"
      rm "$LOCK"
    else
      log_error "E007" "init" "Active lock"
      exit 1
    fi
  fi
  echo "$$:$(date +%s):wf-e2e-verify-orchestrator" > "$LOCK"
  trap "rm -f $LOCK" EXIT
}
```

## Session Resolution (--resume / --session=)

```bash
resolve_session() {
  if [ -n "${SESSION_ARG:-}" ]; then
    SESSION_DIR=".mc-data/work/wf-e2e-verify/sessions/${SESSION_ARG}"
    test -d "$SESSION_DIR" || { log_error "E001" "init" "Session not found"; exit 1; }
  elif [ "${RESUME:-false}" = "true" ]; then
    SESSION_DIR=$(ls -td ".mc-data/work/wf-e2e-verify/sessions/${FEAT_ID}-"* 2>/dev/null | head -1)
    [ -z "$SESSION_DIR" ] && { log_error "E001" "init" "No session to resume"; exit 1; }
  else
    init_session
  fi
}
```

## e2e-status.json Atomic Update

```bash
update_step_status() {
  local STEP="$1"  # F1..F8
  local STATUS="$2"  # pending|running|completed|failed|skipped
  local FIELD="$3"  # optional
  local VALUE="$4"
  
  ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  if [ -z "$FIELD" ]; then
    jq --arg s "$STEP" --arg st "$STATUS" --arg now "$ISO" '
      (.steps[$s] | .status) = $st |
      (.steps[$s] | .last_updated) = $now |
      (if $st == "running" then (.steps[$s] | .started_at) = $now
       elif $st == "completed" then (.steps[$s] | .completed_at) = $now
       else . end)
    ' "$E2E_STATUS" > "$E2E_STATUS.tmp"
  else
    jq --arg s "$STEP" --arg st "$STATUS" --arg f "$FIELD" --arg v "$VALUE" --arg now "$ISO" '
      (.steps[$s] | .status) = $st |
      (.steps[$s] | .[$f]) = $v |
      (.steps[$s] | .last_updated) = $now
    ' "$E2E_STATUS" > "$E2E_STATUS.tmp"
  fi
  
  jq '.' "$E2E_STATUS.tmp" > /dev/null || { rm "$E2E_STATUS.tmp"; exit 1; }
  mv "$E2E_STATUS.tmp" "$E2E_STATUS"
}
```

## Sub-Skill Spawn Pattern

```bash
spawn_subskill() {
  local STEP="$1"
  local SKILL_NAME="$2"
  local EXTRA_FLAGS="$3"
  
  echo "Spawning $SKILL_NAME for step $STEP..."
  update_step_status "$STEP" "running"
  
  PROMPT="
Bạn là delegate agent cho wf-e2e-verify orchestrator.

Task: Run /${SKILL_NAME} ${FEAT_ID} --session=${SESSION_ID} ${EXTRA_FLAGS}

Context:
- Parent orchestrator session: ${SESSION_ID}
- Shared session dir: ${SESSION_DIR}
- Current step: ${STEP}

Instructions:
1. Read .claude/skills/workflow/${SKILL_NAME}/SKILL.md
2. Execute skill workflow đầy đủ
3. Tuân thủ POST-GATE validation
4. Return summary với status, outputs, counts.
  "
  
  # Use Agent tool — subagent_type=general-purpose
  # Agent --subagent_type=general-purpose --description=\"${STEP} ${SKILL_NAME}\" --prompt=\"$PROMPT\"
  
  # POST-VERIFY
  if verify_step_outputs "$STEP"; then
    update_step_status "$STEP" "completed"
    return 0
  else
    update_step_status "$STEP" "failed"
    return 1
  fi
}
```

## POST-VERIFY (per step)

```bash
verify_step_outputs() {
  local STEP="$1"
  case "$STEP" in
    "F1")
      test -d "$SESSION_DIR/findings" || return 1
      test -f "$SESSION_DIR/outputs/test-scenario.md" || return 1
      test -f "$SESSION_DIR/outputs/user-guide.md" || return 1
      test -f "$SESSION_DIR/issues.json" || return 1
      test -f "$SESSION_DIR/block-test.json" || return 1
      test -f "$SESSION_DIR/implement-required.json" || return 1
      test -f "$SESSION_DIR/manual.json" || return 1
      ;;
    "F2") test -f "$SESSION_DIR/F2-browser/browser-test-report.md" || return 1 ;;
    "F3") test -f "$SESSION_DIR/F3-unblock/unblock-report.md" || return 1 ;;
    "F4") test -f "$SESSION_DIR/F4-implement/impl-log.json" || return 1 ;;
    "F5") test -f "$SESSION_DIR/F5-retest/retest-log.md" || return 1 ;;
    "F6") test -f "$SESSION_DIR/F6-fix/fix-log.json" || return 1 ;;
    "F7") test -f "$SESSION_DIR/F7-scenario/scenario-test-report.md" || return 1 ;;
    "F8") test -f "$SESSION_DIR/F8-demo/demo-report.md" || return 1 ;;
  esac
  return 0
}
```

## Atomic Write (CORE-035)

```bash
atomic_write_json() {
  local FILE="$1"
  local CONTENT="$2"
  echo "$CONTENT" > "$FILE.tmp"
  jq '.' "$FILE.tmp" > /dev/null || { rm "$FILE.tmp"; return 1; }
  mv "$FILE.tmp" "$FILE"
}
```

## Session Log (CORE-026, APPEND-only)

```bash
log_event() {
  local TYPE="$1"  # START | COMPLETE | FAIL | SKIP | RESUME
  local STEP="$2"
  local NOTE="$3"
  
  ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  jq --arg t "$TYPE" --arg s "$STEP" --arg n "$NOTE" --arg now "$ISO" '
    .events += [{"timestamp":$now,"type":$t,"step":$s,"note":$n}]
  ' "$SESSION_LOG" > "$SESSION_LOG.tmp"
  mv "$SESSION_LOG.tmp" "$SESSION_LOG"
}
```

## Error Ledger (CORE-034)

```bash
log_error() {
  local CODE="$1"
  local PHASE="$2"
  local MSG="$3"
  
  ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  jq --arg c "$CODE" --arg p "$PHASE" --arg m "$MSG" --arg now "$ISO" '
    .errors += [{"timestamp":$now,"code":$c,"phase":$p,"message":$m,"retry_count":0}]
  ' "$ERROR_LEDGER" > "$ERROR_LEDGER.tmp"
  mv "$ERROR_LEDGER.tmp" "$ERROR_LEDGER"
}
```

## CI Detection (CORE-033)

> CI tools auto-detect, khong hoi user. Lock held -> fallback Grep/Glob.

```bash
GITNEXUS_AVAILABLE=false
SERENA_AVAILABLE=false
CI_CONTEXT=""

ci_detect() {
  # Na: Load CI capabilities
  if bash .claude/scripts/ci-detect.sh 2>/dev/null; then
    GITNEXUS_AVAILABLE=true
    SERENA_AVAILABLE=true
  fi

  # Nb: Index freshness check
  FRESHNESS=$(bash .claude/scripts/ci-freshness-check.sh 2>/dev/null || echo "unknown")
  case "$FRESHNESS" in
    severe|strong) echo "WARN: CI index $FRESHNESS, fallback Grep/Glob" ;;
  esac

  # Nc: Agent context injection
  CI_CONTEXT=$(bash .claude/scripts/ci-inject-context.sh 2>/dev/null || echo "")
  export GITNEXUS_AVAILABLE SERENA_AVAILABLE CI_CONTEXT
}
```

## Context & Checkpoint (CORE-038)

| Context Usage | Hanh dong |
|---------------|-----------|
| < 65% | Tiep tuc binh thuong |
| 65-80% | Chuan bi checkpoint (luu e2e-status.json + session-log.json) |
| 80-90% | Luu checkpoint, STOP sau step hien tai -> huong dan --resume |
| > 90% | FORCE STOP (E009) — checkpoint bat buoc, khong advance |

Resume flow chi tiet -> `procedures/resume-status.md`.

## Cleanup

```bash
cleanup() {
  rm -f "$LOCK"
  
  # Release shared locks held by orchestrator
  for L in "$SESSION_DIR/_locks"/*.lock; do
    [ -f "$L" ] && grep -q "wf-e2e-verify-orchestrator" "$L" 2>/dev/null && rm "$L"
  done
  
  log_event "ORCHESTRATOR_EXIT" "finalize" "Cleanup complete"
}
trap cleanup EXIT
```

## verify_expert_decision() — Expert Accuracy Tracking (G3)

WHY: Expert agents đôi khi predict risk sai (đánh giá "low" cho bug HIGH, hoặc ngược lại gây over-block). Rolling accuracy tracking giúp phát hiện expert nào đang degraded để escalate calibration. Threshold 80% dựa trên trade-off giữa false positive và false negative cho E2E verification.

```bash
verify_expert_decision() {
  local DECISION_ID="$1"
  local EXPERT_TYPE="$2"      # qa-lead | frontend-developer | architect | ...
  local CHOSEN_OPTION="$3"    # option 1|2|3 đã chọn
  local PREDICTED_RISK="$4"   # low | medium | high | critical
  local ACTUAL_OUTCOME="$5"   # pass | fail | partial

  local HISTORY_FILE=".mc-data/work/_decisions/expert-accuracy-history.jsonl"
  local ACCURACY_FILE=".mc-data/work/_decisions/expert-accuracy-stats.json"

  mkdir -p ".mc-data/work/_decisions"

  # Append entry (APPEND-only per CORE-026)
  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "{\"decision_id\":\"$DECISION_ID\",\"expert\":\"$EXPERT_TYPE\",\"chosen\":\"$CHOSEN_OPTION\",\"predicted_risk\":\"$PREDICTED_RISK\",\"actual_outcome\":\"$ACTUAL_OUTCOME\",\"timestamp\":\"$ISO\"}" \
    >> "$HISTORY_FILE"

  # Rolling accuracy check trên 20 decisions gần nhất
  # WHY 20 entries: đủ để thống kê có ý nghĩa, không quá dài để outlier làm méo
  if [ -f "$HISTORY_FILE" ]; then
    python3 - <<'PYEOF' 2>/dev/null || true
import sys, json, collections

with open(".mc-data/work/_decisions/expert-accuracy-history.jsonl") as f:
    lines = [l.strip() for l in f if l.strip()]

last20 = [json.loads(l) for l in lines[-20:]]
expert_stats = collections.defaultdict(lambda: {"total": 0, "correct": 0})

for d in last20:
    e = d["expert"]
    expert_stats[e]["total"] += 1
    outcome = d.get("actual_outcome", "")
    risk = d.get("predicted_risk", "")
    # Correct = (outcome pass AND predicted low/medium) OR (outcome fail AND predicted high/critical)
    if outcome == "pass" and risk in ("low", "medium"):
        expert_stats[e]["correct"] += 1
    elif outcome == "fail" and risk in ("high", "critical"):
        expert_stats[e]["correct"] += 1

alerts = []
stats_out = {}
for e, s in expert_stats.items():
    acc = s["correct"] / s["total"] * 100 if s["total"] > 0 else 100
    stats_out[e] = {"total": s["total"], "correct": s["correct"], "accuracy_pct": round(acc, 1)}
    if acc < 80 and s["total"] >= 5:
        alerts.append(f"WARN: Expert '{e}' accuracy={acc:.0f}% ({s['correct']}/{s['total']}) < 80% — calibration needed")

for a in alerts:
    print(a, file=sys.stderr)

with open(".mc-data/work/_decisions/expert-accuracy-stats.json", "w") as f:
    json.dump({"updated_at": sys.argv[1] if len(sys.argv) > 1 else "", "stats": stats_out}, f, indent=2)
PYEOF
  fi
}
```

Gọi `verify_expert_decision` sau mỗi lần expert CDG decision được resolve và outcome đã biết (sau F5 retest hoặc F6 fix completion).

---

## append_decision_queue() — DECISION-REQUIRED Queue (B2)

Dùng khi một CDG point cần user quyết định nhưng đang ở `--auto` mode hoặc user chưa response.

```bash
append_decision_queue() {
  local DECISION_ID="$1"       # e.g. "DECISION-0042"
  local DECISION_TYPE="$2"     # "non_destructive" | "destructive"
  local FEAT_ID="$3"
  local DESCRIPTION="$4"
  local OPTIONS="$5"           # JSON array string: '["option_a","option_b"]'
  local EXPIRES_AT="$6"        # ISO-8601 + 24h từ now
  local QUEUE_FILE=".mc-data/work/_decisions/pending-queue.json"

  # Atomic append to pending queue
  TMPFILE="${QUEUE_FILE}.tmp.$$"
  python3 - <<PYEOF
import json, sys, os, datetime

queue_file = "$QUEUE_FILE"
os.makedirs(os.path.dirname(queue_file), exist_ok=True)

# Read existing queue
if os.path.exists(queue_file):
    with open(queue_file) as f:
        queue = json.load(f)
else:
    queue = {"schema": "decision-queue-v1", "decisions": []}

# Check duplicate
existing_ids = [d["decision_id"] for d in queue["decisions"]]
if "$DECISION_ID" in existing_ids:
    print(f"WARN: $DECISION_ID already in queue — skipping duplicate", file=sys.stderr)
    sys.exit(0)

# Append new decision
new_entry = {
    "decision_id": "$DECISION_ID",
    "decision_type": "$DECISION_TYPE",
    "feat_id": "$FEAT_ID",
    "description": "$DESCRIPTION",
    "options": json.loads('$OPTIONS') if '$OPTIONS' else [],
    "status": "pending",
    "created_at": datetime.datetime.utcnow().isoformat() + "Z",
    "expires_at": "$EXPIRES_AT",
    "resolved_at": None,
    "chosen_option": None,
    "resolved_by": None
}
queue["decisions"].append(new_entry)
queue["total_pending"] = len([d for d in queue["decisions"] if d["status"] == "pending"])

# Atomic write
tmp = queue_file + ".tmp"
with open(tmp, "w") as f:
    json.dump(queue, f, indent=2)
os.replace(tmp, queue_file)
print(f"OK: appended $DECISION_ID to pending queue (total_pending={queue['total_pending']})")
PYEOF
}
```

**Khi nào gọi:** Khi CDG cần quyết định nhưng không thể hỏi user ngay (batch mode, --auto). Flow:
1. Gọi `append_decision_queue()` → ghi vào `pending-queue.json`
2. Tạo file `DECISION-NNNN.md` từ template `decision-required.template.md`
3. Set step status = `decision_required` (KHÔNG phải `blocked` hay `completed`)
4. Tiếp tục các FEATs không phụ thuộc vào decision này
5. Khi user chạy `/status` → hiển thị Pending Decisions section

---

## dispatch_expert_for_decision() — Auto Expert Dispatch (T4.4)

Dùng trong `--auto` mode cho non-destructive CDG points: spawn chuyên gia phù hợp để ra quyết định thay user.

```bash
dispatch_expert_for_decision() {
  local DECISION_ID="$1"
  local DECISION_TYPE="$2"   # "non_destructive" only — destructive → handle_destructive_cdg()
  local CONTEXT_FILE="$3"    # Path to context markdown for expert
  local FEAT_ID="$4"
  local DOMAIN="$5"          # e.g. "finance", "healthcare", "general"

  if [ "$DECISION_TYPE" = "destructive" ]; then
    handle_destructive_cdg "$DECISION_ID" "$CONTEXT_FILE" "$FEAT_ID"
    return $?
  fi

  # Map domain → subagent_type
  local EXPERT_TYPE
  case "$DOMAIN" in
    finance|banking)      EXPERT_TYPE="finance-expert" ;;
    healthcare|medical)   EXPERT_TYPE="healthcare-expert" ;;
    security|auth)        EXPERT_TYPE="security" ;;
    architecture|design)  EXPERT_TYPE="architect" ;;
    qa|testing)           EXPERT_TYPE="qa-lead" ;;
    *)                    EXPERT_TYPE="architect" ;;  # default fallback
  esac

  # Write dispatch log entry
  local DISPATCH_LOG=".mc-data/work/_decisions/dispatch-log.jsonl"
  python3 - <<PYEOF
import json, datetime, os
os.makedirs(os.path.dirname("$DISPATCH_LOG"), exist_ok=True)
entry = {
    "decision_id": "$DECISION_ID",
    "expert_type": "$EXPERT_TYPE",
    "feat_id": "$FEAT_ID",
    "domain": "$DOMAIN",
    "dispatched_at": datetime.datetime.utcnow().isoformat() + "Z",
    "context_file": "$CONTEXT_FILE",
    "status": "dispatched"
}
with open("$DISPATCH_LOG", "a") as f:
    f.write(json.dumps(entry) + "\n")
print(f"DISPATCH: {\"$DECISION_ID\"} → {\"$EXPERT_TYPE\"}")
PYEOF

  # Spawn expert agent (non-blocking — appends result to decision queue)
  echo "AUTO-DISPATCH: Spawning $EXPERT_TYPE for $DECISION_ID..."
  # NOTE: Actual Agent spawn handled by orchestrator via sub-skill pattern (CORE-037)
  # orchestrator reads DISPATCH_LOG và spawn expert agents theo batch
  return 0
}
```

**Policy:** Non-destructive CDG trong `--auto` mode:
- Domain expert = nguồn đáng tin cậy thứ nhất (accuracy ≥80% rolling)
- Nếu expert accuracy < 80% → fallback `append_decision_queue()` → chờ user
- Kết quả expert được ghi vào `expert-accuracy-log.jsonl` → `verify_expert_decision()` theo dõi

---

## handle_destructive_cdg() — 2-Expert Destructive Gate (T4.4)

Dùng cho CDG destructive actions: cần 2 expert đồng thuận + snapshot + 24h rollback window.

```bash
handle_destructive_cdg() {
  local DECISION_ID="$1"
  local CONTEXT_FILE="$2"
  local FEAT_ID="$3"
  local SNAPSHOT_DIR=".mc-data/work/_decisions/snapshots/$DECISION_ID"

  echo "CDG-DESTRUCTIVE: $DECISION_ID requires 2-expert consensus + snapshot"

  # Step 1: Create pre-action snapshot
  mkdir -p "$SNAPSHOT_DIR"
  local SNAPSHOT_FILE="$SNAPSHOT_DIR/pre-action-snapshot.json"
  python3 - <<PYEOF
import json, datetime, os, subprocess

snapshot = {
    "decision_id": "$DECISION_ID",
    "snapshot_type": "pre_destructive_action",
    "created_at": datetime.datetime.utcnow().isoformat() + "Z",
    "feat_id": "$FEAT_ID",
    "context_file": "$CONTEXT_FILE",
    "rollback_window_hours": 24,
    "rollback_expires_at": (datetime.datetime.utcnow() + datetime.timedelta(hours=24)).isoformat() + "Z",
    "git_sha": subprocess.getoutput("git rev-parse HEAD 2>/dev/null || echo 'no-git'"),
    "status": "pending_consensus"
}
with open("$SNAPSHOT_FILE", "w") as f:
    json.dump(snapshot, f, indent=2)
print(f"SNAPSHOT: created at $SNAPSHOT_FILE")
PYEOF

  # Step 2: Queue for 2-expert review (security + architect both must approve)
  append_decision_queue \
    "$DECISION_ID" \
    "destructive" \
    "$FEAT_ID" \
    "DESTRUCTIVE action requires 2-expert consensus (security + architect). Context: $CONTEXT_FILE" \
    '["approve","reject","defer_24h"]' \
    "$(python3 -c "import datetime; print((datetime.datetime.utcnow() + datetime.timedelta(hours=24)).isoformat() + 'Z')")"

  # Step 3: Post-hoc notification entry (async — user sees this in /status)
  local NOTIFY_FILE=".mc-data/work/_decisions/post-hoc-notifications.jsonl"
  python3 - <<PYEOF
import json, datetime, os
os.makedirs(os.path.dirname("$NOTIFY_FILE"), exist_ok=True)
entry = {
    "decision_id": "$DECISION_ID",
    "type": "destructive_cdg_initiated",
    "message": "Destructive CDG '$DECISION_ID' initiated for FEAT $FEAT_ID. Requires security + architect consensus. Snapshot created. 24h rollback window open.",
    "snapshot_path": "$SNAPSHOT_DIR/pre-action-snapshot.json",
    "created_at": datetime.datetime.utcnow().isoformat() + "Z",
    "acknowledged": False
}
with open("$NOTIFY_FILE", "a") as f:
    f.write(json.dumps(entry) + "\n")
PYEOF

  echo "CDG-DESTRUCTIVE: $DECISION_ID queued. Snapshot at $SNAPSHOT_DIR. 24h rollback window started."
  return 0
}
```

**2-Expert consensus rules:**
1. `security` agent + `architect` agent đều phải `approve` → action proceeds
2. Bất kỳ 1 expert `reject` → action BLOCKED, ghi lý do vào decision record
3. `defer_24h` từ bất kỳ expert → re-queue sau 24h với user notification
4. Nếu không resolve trong 24h → auto-REJECT + notify user

---

## Migration Notes (from v6.5.0)

State machine cũ (current_phase 0-7 + sub_state) đã được REMOVE khỏi orchestrator. Sub-skill F1 wf-e2e-test giữ state machine 6 phase nội bộ. Các state cũ map sang:

| Old state | New equivalent |
|-----------|----------------|
| `current_phase=0` (SETUP) | F1 phase0-setup |
| `current_phase=1-6` (BUSINESS-OUTPUT) | F1 phase1-6 |
| `current_phase=7` (BROWSER) | F2 + F7 + F8 |
| `sub_state=FIND/ASSESS/...` | F1 internal state |
| `bo_sung_count` | F1 internal |
| `verify_attempts` | F1 internal |

Orchestrator chỉ track top-level 8-step state qua `e2e-status.json`.
