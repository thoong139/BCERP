# F0a wf-e2e-finding — Shared Protocols

## State Variables

```
$FEAT_ID    = argument 1 (FEAT-EW-{MOD}-{NNN})
$SESSION_ID = {FEAT_ID}-{YYYYMMDD-HHmm}
$SESSION_DIR = .mc-data/work/wf-e2e-verify/sessions/$SESSION_ID/
$FINDINGS_DIR = $SESSION_DIR/findings/
$STATUS      = $SESSION_DIR/status.json
$SESSION_LOG = $SESSION_DIR/session-log.json
$ERROR_LEDGER = $SESSION_DIR/error-ledger.json
$LOCK        = $SESSION_DIR/.lock
$PROMPT_CONTEXT = $SESSION_DIR/prompt-context.md
```

---

## Session Init

```bash
init_session() {
  ISO_SHORT=$(date -u +%Y%m%d-%H%M)
  SESSION_ID="${FEAT_ID}-${ISO_SHORT}"
  SESSION_DIR=".mc-data/work/wf-e2e-verify/sessions/${SESSION_ID}"

  mkdir -p "$SESSION_DIR/findings"

  # Tạo status.json cho F0a
  cat > "$STATUS" <<EOF
{
  "\$schema": "f0a-status-v1",
  "session_id": "$SESSION_ID",
  "feat_id": "$FEAT_ID",
  "skill": "wf-e2e-finding",
  "version": "1.0.0",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "current_phase": 0,
  "overall_status": "in_progress",
  "phases": {
    "p0_setup":      { "status": "pending" },
    "p1_business":   { "status": "pending", "bo_sung_count": 0, "verify_attempts": 0 },
    "p2_db":         { "status": "pending", "bo_sung_count": 0 },
    "p3_api":        { "status": "pending", "bo_sung_count": 0 },
    "p4_ui":         { "status": "pending", "bo_sung_count": 0 },
    "p5_completion": { "status": "pending" }
  },
  "context_estimate_pct": 0,
  "next_action": "run P1 business analysis"
}
EOF

  # Session log + error ledger (CORE-026, CORE-034)
  echo '{"$schema":"session-log-v1","events":[]}' > "$SESSION_LOG"
  echo '{"$schema":"error-ledger-v1","errors":[]}' > "$ERROR_LEDGER"

  echo "# Prompt Context\n\nCommand: /wf-e2e-finding $ARGUMENTS\nTimestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PROMPT_CONTEXT"

  acquire_lock
}
```

---

## Lock Strategy

```bash
acquire_lock() {
  if [ -f "$LOCK" ]; then
    AGE=$(($(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || stat -f %m "$LOCK")))
    if [ "$AGE" -gt 1800 ]; then
      log_error "E008" "init" "Stale lock auto-released sau $AGE giây"
      rm "$LOCK"
    else
      log_error "E007" "init" "Lock đang active, process khác đang chạy"
      exit 1
    fi
  fi
  echo "$$:$(date +%s):wf-e2e-finding" > "$LOCK"
  trap "rm -f $LOCK" EXIT
}
```

---

## Session Resolution (--resume / --session=)

```bash
resolve_session() {
  if [ -n "${SESSION_ARG:-}" ]; then
    SESSION_DIR=".mc-data/work/wf-e2e-verify/sessions/${SESSION_ARG}"
    test -d "$SESSION_DIR" || { log_error "E029" "init" "Session $SESSION_ARG không tồn tại"; exit 1; }
    SESSION_ID="$SESSION_ARG"
  elif [ "${RESUME:-false}" = "true" ]; then
    SESSION_DIR=$(ls -td ".mc-data/work/wf-e2e-verify/sessions/${FEAT_ID}-"* 2>/dev/null | head -1)
    [ -z "$SESSION_DIR" ] && { log_error "E029" "init" "Không có session để resume cho $FEAT_ID"; exit 1; }
    SESSION_ID=$(basename "$SESSION_DIR")
  else
    init_session
  fi
  STATUS="$SESSION_DIR/status.json"
  FINDINGS_DIR="$SESSION_DIR/findings"
  SESSION_LOG="$SESSION_DIR/session-log.json"
  ERROR_LEDGER="$SESSION_DIR/error-ledger.json"
  LOCK="$SESSION_DIR/.lock"
}
```

---

## Atomic Write Pattern (CORE-035)

```bash
atomic_write_json() {
  local FILE="$1"
  local CONTENT="$2"
  echo "$CONTENT" > "${FILE}.tmp.$$"
  jq '.' "${FILE}.tmp.$$" > /dev/null || { rm -f "${FILE}.tmp.$$"; return 1; }
  mv "${FILE}.tmp.$$" "$FILE"
}

atomic_write_file() {
  local FILE="$1"
  local CONTENT="$2"
  echo "$CONTENT" > "${FILE}.tmp.$$"
  mv "${FILE}.tmp.$$" "$FILE"
}
```

---

## Status Update

```bash
update_phase_status() {
  local PHASE="$1"   # p0_setup | p1_business | p2_db | p3_api | p4_ui | p5_completion
  local STATUS="$2"  # pending | running | done | failed
  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  jq --arg p "$PHASE" --arg s "$STATUS" --arg now "$ISO" '
    .phases[$p].status = $s |
    .last_updated = $now
  ' "$STATUS" > "${STATUS}.tmp.$$"
  jq '.' "${STATUS}.tmp.$$" > /dev/null || { rm "${STATUS}.tmp.$$"; return 1; }
  mv "${STATUS}.tmp.$$" "$STATUS"
}

advance_phase() {
  local NEXT_PHASE="$1"
  local NEXT_ACTION="$2"

  jq --argjson n "$NEXT_PHASE" --arg a "$NEXT_ACTION" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    .current_phase = $n |
    .next_action = $a |
    .last_updated = $now
  ' "$STATUS" > "${STATUS}.tmp.$$"
  mv "${STATUS}.tmp.$$" "$STATUS"
}
```

---

## Error Ledger (CORE-034)

```bash
log_error() {
  local CODE="$1"
  local PHASE="$2"
  local MSG="$3"
  local RETRY="${4:-0}"
  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  jq --arg c "$CODE" --arg p "$PHASE" --arg m "$MSG" --argjson r "$RETRY" --arg now "$ISO" '
    .errors += [{"timestamp":$now,"code":$c,"phase":$p,"message":$m,"retry_count":$r}]
  ' "$ERROR_LEDGER" > "${ERROR_LEDGER}.tmp.$$"
  mv "${ERROR_LEDGER}.tmp.$$" "$ERROR_LEDGER"
}
```

---

## Session Log (CORE-026)

```bash
log_event() {
  local TYPE="$1"   # START | COMPLETE | FAIL | SKIP | RESUME | CHECKPOINT
  local PHASE="$2"
  local NOTE="$3"
  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  jq --arg t "$TYPE" --arg p "$PHASE" --arg n "$NOTE" --arg now "$ISO" '
    .events += [{"timestamp":$now,"type":$t,"phase":$p,"note":$n}]
  ' "$SESSION_LOG" > "${SESSION_LOG}.tmp.$$"
  mv "${SESSION_LOG}.tmp.$$" "$SESSION_LOG"
}
```

---

## CI Detection (CORE-033) — 3-Step PRE-GATE

```bash
ci_detect() {
  # Na: Load CI Capabilities
  GITNEXUS_AVAILABLE=false
  SERENA_AVAILABLE=false
  if bash .claude/scripts/ci-detect.sh 2>/dev/null; then
    GITNEXUS_AVAILABLE=true
    SERENA_AVAILABLE=true
  fi

  # Nb: Index freshness check
  FRESHNESS=$(bash .claude/scripts/ci-freshness-check.sh 2>/dev/null || echo "unknown")
  case "$FRESHNESS" in
    severe|strong)
      echo "WARN: CI index $FRESHNESS stale — fallback về Grep/Glob cho code scan"
      GITNEXUS_AVAILABLE=false
      ;;
  esac

  # Nc: Agent context injection
  CI_CONTEXT=$(bash .claude/scripts/ci-inject-context.sh 2>/dev/null || echo "")

  export GITNEXUS_AVAILABLE SERENA_AVAILABLE CI_CONTEXT
}
```

---

## Context Budget Check (CORE-038)

F0a dùng ngưỡng chặt hơn (50%/65%/80%) để bảo đảm còn context cho F1 sau đó.

```bash
check_context_budget() {
  local PCT="${CONTEXT_ESTIMATE_PCT:-0}"

  if [ "$PCT" -ge 80 ]; then
    log_error "E028" "context" "Context $PCT% — FORCE STOP"
    log_event "CHECKPOINT" "context" "Force checkpoint tại $PCT%"
    save_checkpoint
    echo "WARN: Context $PCT% (>80%). F0a dừng. Chạy /wf-e2e-finding $FEAT_ID --resume để tiếp tục."
    exit 0
  elif [ "$PCT" -ge 65 ]; then
    echo "WARN: Context $PCT% (>65%). Sau phase hiện tại sẽ dừng + hướng dẫn --resume."
    STOP_AFTER_PHASE=true
  elif [ "$PCT" -ge 50 ]; then
    echo "INFO: Context $PCT% (>50%). Chuẩn bị checkpoint sau phase này."
    save_checkpoint
  fi
}

save_checkpoint() {
  # status.json đã được update atomic sau mỗi phase — đây là checkpoint đủ để resume
  jq --argjson pct "${CONTEXT_ESTIMATE_PCT:-0}" '.context_estimate_pct = $pct' \
    "$STATUS" > "${STATUS}.tmp.$$"
  mv "${STATUS}.tmp.$$" "$STATUS"
  log_event "CHECKPOINT" "context" "Checkpoint lưu tại phase $(jq -r '.current_phase' "$STATUS")"
}
```

---

## PRE-GATE Validation (CORE-011 Forensic)

```bash
run_pregate() {
  local REG=".mc-data/docs/_meta/req-registry.json"

  # T1: File existence
  test -f "$REG" || { echo "E029: req-registry.json không tồn tại"; exit 1; }

  FEAT_ENTRY=$(jq -r --arg id "$FEAT_ID" '.features[] | select(.feat_id == $id or .id == $id)' "$REG" 2>/dev/null)
  if [ -z "$FEAT_ENTRY" ]; then
    log_error "E020" "pregate" "FEAT-ID $FEAT_ID không tồn tại trong registry"
    exit 1
  fi

  # T2: Schema validation
  jq -e '.requirements | length > 0' "$REG" > /dev/null || {
    log_error "E029" "pregate" "Registry thiếu requirements"
    exit 1
  }

  # T3: Feature spec file
  SPEC_FILE=$(echo "$FEAT_ENTRY" | jq -r '.file // empty')
  if [ -n "$SPEC_FILE" ] && [ -f "$SPEC_FILE" ]; then
    SPEC_SIZE=$(wc -c < "$SPEC_FILE")
    if [ "$SPEC_SIZE" -le 500 ]; then
      log_error "E020" "pregate" "Feature spec $SPEC_FILE < 500 bytes (stub trống)"
      exit 1
    fi
  else
    log_error "E020" "pregate" "Feature spec file không tìm thấy: $SPEC_FILE"
    exit 1
  fi

  # T4: Cross-reference req_ids
  REQ_IDS=$(echo "$FEAT_ENTRY" | jq -r '.req_ids[]?' 2>/dev/null)
  for RID in $REQ_IDS; do
    EXISTS=$(jq -r --arg r "$RID" '.requirements[] | select(.req_id == $r or .id == $r) | .req_id // .id' "$REG" 2>/dev/null)
    if [ -z "$EXISTS" ]; then
      echo "WARN: req_id $RID không tìm thấy trong registry (T4 cross-ref)"
    fi
  done

  log_event "COMPLETE" "pregate" "PRE-GATE T1-T4 passed"
}
```
