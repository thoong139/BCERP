#!/usr/bin/env bash
# wave-coordinator.sh — Wave dispatch coordinator cho wf-cmi v2.0 Phase 4 (3-WAVE strategy)
# Part of Stage 5 Dispatcher refinement
#
# Subcommands:
#   init    <SESSION_DIR> <PROFILE>                            — Init wave-status.json từ template
#   start   <SESSION_DIR> <WAVE_ID> "<LANES_CSV_OR_SPACE>"     — Mark wave started, populate lanes_active
#   end     <SESSION_DIR> <WAVE_ID>                            — Aggregate lane outcomes + gate check
#   status  <SESSION_DIR>                                      — Print current wave state summary
#
# Exit codes (subcommand `end`):
#   0  — Wave PASS (all lanes completed hoặc skip count chấp nhận được)
#   1  — Wave FAIL_THRESHOLD (≥fail_threshold lanes failed/timeout → E120/E121/E122, STOP dispatch)
#   2  — Wave PARTIAL_FAIL (1+ fail nhưng dưới threshold → E123 WARN, continue next wave)
#
# Reads: $SESSION_DIR/phase4-coverage/lanes/<LANE>/lane-status.json (per-lane status updated by lane agents)
# Writes (atomic): $SESSION_DIR/wave-status.json
#
# Tham chiếu: phase4-coverage-dispatch.md Step 4.2 (init) + 4.5 (start/end) + §F error codes E120-E123.

set -euo pipefail

# ============================================================================
# Common helpers
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL_DEFAULT="$SCRIPT_DIR/../../skills/workflow/wf-cmi/templates/wave-status.json"
TPL="${MCV3_CMI_WAVE_STATUS_TPL:-$TPL_DEFAULT}"

log() {
  echo "[wave-coordinator] $*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

ts_now() {
  date -Iseconds
}

require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq is required (install: apt/brew install jq)"
}

# Atomic write helper: stdin → file.tmp.$$ → mv to file (POSIX atomic rename)
atomic_write() {
  local target="$1"
  local tmp="$target.tmp.$$"
  cat > "$tmp"
  # Validate JSON nếu target là .json
  case "$target" in
    *.json) jq -e '.' "$tmp" >/dev/null 2>&1 || { rm -f "$tmp"; die "Atomic write JSON invalid: $target"; } ;;
  esac
  mv "$tmp" "$target"
}

wave_status_path() {
  # Per CORE-035 (Phase Output Organization), wave-status sits trong phase4-coverage/ subdir
  echo "$1/phase4-coverage/wave-status.json"
}

# Map wave_id → array of canonical lane IDs (v2.0 26-lane layout)
wave_lanes_canonical() {
  case "$1" in
    1) echo "CD1 CD2 CD3 CD4 CD5 CD6 CD7 CD11 CD16 CD17" ;;
    2) echo "CD13 CD15 CD18 CD23 CD24 CD25 CD28 CD30 CD31 CD37" ;;
    3) echo "CD9 CD26 CD29 CD38 CD39 CD40" ;;
    *) die "Unknown wave_id: $1 (must be 1, 2, or 3)" ;;
  esac
}

# ============================================================================
# Helper: update overall_status + all_waves_complete after Wave 3 terminal
# Acceptable terminal: PASS | SKIPPED | PARTIAL_FAIL. Bad: FAIL_THRESHOLD.
# ============================================================================
update_overall_status() {
  local target="$1"
  local w1 w2 w3 overall
  w1="$(jq -r '.wave_1.gate_status' "$target")"
  w2="$(jq -r '.wave_2.gate_status' "$target")"
  w3="$(jq -r '.wave_3.gate_status' "$target")"

  _acceptable() {
    case "$1" in PASS|SKIPPED|PARTIAL_FAIL) return 0 ;; *) return 1 ;; esac
  }

  if _acceptable "$w1" && _acceptable "$w2" && _acceptable "$w3"; then
    overall="PASS"
  else
    overall="FAIL"
  fi

  jq --arg os "$overall" --argjson w 4 \
     '.overall_status = $os
      | .current_wave = $w
      | .all_waves_complete = true' "$target" | atomic_write "$target"
}

# ============================================================================
# Subcommand: init
# ============================================================================
# Strip template metadata + substitute placeholders → wave-status.json
cmd_init() {
  local session_dir="${1:?init requires SESSION_DIR}"
  local profile="${2:?init requires PROFILE}"

  [ -d "$session_dir" ] || die "SESSION_DIR not found: $session_dir"
  [ -f "$TPL" ] || die "Template not found: $TPL"

  local target
  target="$(wave_status_path "$session_dir")"
  mkdir -p "$(dirname "$target")"

  # Strip _template_notes + substitute placeholders
  jq --arg sid "$(basename "$session_dir")" \
     --arg prof "$profile" \
     'del(._template_notes)
      | .session_id = $sid
      | .profile = $prof' "$TPL" | atomic_write "$target"

  log "init OK → $target (profile=$profile)"
}

# ============================================================================
# Subcommand: start
# ============================================================================
# Mark wave started + populate lanes_active (filter by canonical wave lanes ∩ requested)
cmd_start() {
  local session_dir="${1:?start requires SESSION_DIR}"
  local wave_id="${2:?start requires WAVE_ID}"
  local requested_lanes="${3:-}"

  local target
  target="$(wave_status_path "$session_dir")"
  [ -f "$target" ] || die "wave-status.json not found at $target — run 'init' first"

  # Compute lanes_active = canonical wave lanes ∩ requested
  # Requested có thể là CSV (CD1,CD2) hoặc space-separated (CD1 CD2)
  local canonical
  canonical="$(wave_lanes_canonical "$wave_id")"

  local lanes_active=()
  if [ -z "$requested_lanes" ]; then
    # Empty requested → use full canonical (profile=deep all-26 case)
    for l in $canonical; do lanes_active+=("$l"); done
  else
    # Normalize: replace comma + dedup
    local req_normalized
    req_normalized="$(echo "$requested_lanes" | tr ',' ' ' | tr -s ' ')"
    for l in $canonical; do
      if echo " $req_normalized " | grep -q " $l "; then
        lanes_active+=("$l")
      fi
    done
  fi

  local lane_count="${#lanes_active[@]}"

  # Build JSON array of lanes_active
  local lanes_json
  lanes_json="$(printf '%s\n' "${lanes_active[@]}" | jq -R . | jq -s .)"

  local now
  now="$(ts_now)"

  # Atomic update (dùng jq dynamic field access để tránh bash var expansion conflict)
  jq --argjson w "$wave_id" \
     --argjson lanes "$lanes_json" \
     --argjson cnt "$lane_count" \
     --arg ts "$now" \
     '("wave_" + ($w | tostring)) as $wk
      | .[$wk].lanes_active = $lanes
      | .[$wk].lane_count = $cnt
      | .[$wk].started_at = $ts
      | .[$wk].gate_status = "RUNNING"
      | .current_wave = $w
      | .overall_status = "RUNNING"
      | .total_lanes_active = (.wave_1.lane_count + .wave_2.lane_count + .wave_3.lane_count)' "$target" | atomic_write "$target"

  log "start wave=$wave_id lanes=${lane_count} (${lanes_active[*]:-none})"
}

# ============================================================================
# Subcommand: end
# ============================================================================
# Aggregate per-lane lane-status.json → wave-status.json + gate check
cmd_end() {
  local session_dir="${1:?end requires SESSION_DIR}"
  local wave_id="${2:?end requires WAVE_ID}"

  local target
  target="$(wave_status_path "$session_dir")"
  [ -f "$target" ] || die "wave-status.json not found at $target"

  # Read lanes_active + fail_threshold cho wave này (qua jq dynamic field access)
  local lanes_active_json fail_threshold
  lanes_active_json="$(jq -c --argjson w "$wave_id" '.["wave_" + ($w | tostring)].lanes_active' "$target")"
  fail_threshold="$(jq -r --argjson w "$wave_id" '.["wave_" + ($w | tostring)].fail_threshold' "$target")"

  if [ "$lanes_active_json" = "null" ] || [ "$lanes_active_json" = "[]" ]; then
    log "WARN: wave_$wave_id has no lanes_active — marking SKIPPED"
    jq --argjson w "$wave_id" --arg ts "$(ts_now)" \
       '("wave_" + ($w | tostring)) as $wk
        | .[$wk].gate_status = "SKIPPED"
        | .[$wk].completed_at = $ts' "$target" | atomic_write "$target"
    # Wave 3 SKIPPED vẫn cần update overall_status
    [ "$wave_id" = "3" ] && update_overall_status "$target"
    return 0
  fi

  # Aggregate outcomes from per-lane lane-status.json
  local outcomes_obj="{}"
  local pass_count=0 fail_count=0 timeout_count=0 skip_count=0 missing_count=0

  # jq -r on Git Bash for Windows emits \r\n line endings — strip \r to avoid tokenization bugs
  for lane in $(echo "$lanes_active_json" | jq -r '.[]' | tr -d '\r'); do
    local lane_status_file="$session_dir/phase4-coverage/lanes/$lane/lane-status.json"
    local outcome="missing"

    if [ -f "$lane_status_file" ]; then
      # Read status field, normalize to lowercase, strip CR (Git Bash)
      local raw_status
      raw_status="$(jq -r '.status // "missing"' "$lane_status_file" 2>/dev/null | tr -d '\r' || echo "missing")"
      outcome="$(echo "$raw_status" | tr '[:upper:]' '[:lower:]')"
    fi

    # Map to canonical outcome buckets
    case "$outcome" in
      completed|done|pass) outcome="completed"; pass_count=$((pass_count+1)) ;;
      failed|fail|error) outcome="failed"; fail_count=$((fail_count+1)) ;;
      timeout|timed_out) outcome="timeout"; timeout_count=$((timeout_count+1)) ;;
      skipped|skip) outcome="skipped"; skip_count=$((skip_count+1)) ;;
      missing|pending|running|*)
        # Pending/running treated as missing/incomplete → counted as failed for gate purposes
        outcome="missing"
        missing_count=$((missing_count+1))
        fail_count=$((fail_count+1))
        ;;
    esac

    outcomes_obj="$(echo "$outcomes_obj" | jq --arg k "$lane" --arg v "$outcome" '. + {($k): $v}')"
  done

  # Combined fail = failed + timeout (for gate threshold check)
  local combined_fail=$((fail_count + timeout_count))

  # Determine gate_status + exit code
  local gate_status exit_code error_code error_message
  if [ "$combined_fail" -ge "$fail_threshold" ]; then
    gate_status="FAIL_THRESHOLD"
    exit_code=1
    case "$wave_id" in
      1) error_code="E120" ;;
      2) error_code="E121" ;;
      3) error_code="E122" ;;
    esac
    error_message="Wave $wave_id batch fail: $combined_fail/$(echo "$lanes_active_json" | jq 'length') lanes failed/timeout (threshold=$fail_threshold)"
  elif [ "$combined_fail" -ge 1 ]; then
    gate_status="PARTIAL_FAIL"
    exit_code=2
    error_code="E123"
    error_message="Wave $wave_id partial fail: $combined_fail lane(s) — continue with retry"
  else
    gate_status="PASS"
    exit_code=0
    error_code="null"
    error_message="null"
  fi

  local now started_at duration
  now="$(ts_now)"
  started_at="$(jq -r ".wave_$wave_id.started_at // \"$now\"" "$target")"
  # Compute duration if both timestamps available
  if [ "$started_at" != "null" ] && [ "$started_at" != "$now" ]; then
    duration=$(($(date -d "$now" +%s 2>/dev/null || echo 0) - $(date -d "$started_at" +%s 2>/dev/null || echo 0)))
  else
    duration=0
  fi

  # Atomic update wave-status.json (jq dynamic field access)
  jq --argjson w "$wave_id" \
     --argjson outcomes "$outcomes_obj" \
     --argjson pc "$pass_count" \
     --argjson fc "$fail_count" \
     --argjson tc "$timeout_count" \
     --argjson sc "$skip_count" \
     --argjson dur "$duration" \
     --arg gs "$gate_status" \
     --arg ts "$now" \
     --arg ec "$error_code" \
     --arg em "$error_message" \
     '("wave_" + ($w | tostring)) as $wk
      | .[$wk].lane_outcomes = $outcomes
      | .[$wk].pass_count = $pc
      | .[$wk].fail_count = $fc
      | .[$wk].timeout_count = $tc
      | .[$wk].skip_count = $sc
      | .[$wk].completed_at = $ts
      | .[$wk].duration_sec = $dur
      | .[$wk].gate_status = $gs
      | .[$wk].error_code = (if $ec == "null" then null else $ec end)
      | .[$wk].error_message = (if $em == "null" then null else $em end)
      | .total_lanes_completed = (.wave_1.pass_count + .wave_2.pass_count + .wave_3.pass_count)
      | .total_lanes_failed = (.wave_1.fail_count + .wave_1.timeout_count + .wave_2.fail_count + .wave_2.timeout_count + .wave_3.fail_count + .wave_3.timeout_count)' \
     "$target" | atomic_write "$target"

  # Update overall_status + all_waves_complete after Wave 3 (handled bởi helper)
  [ "$wave_id" = "3" ] && update_overall_status "$target"

  log "end wave=$wave_id gate_status=$gate_status pass=$pass_count fail=$fail_count timeout=$timeout_count skip=$skip_count"
  [ "$error_code" != "null" ] && log "  $error_code: $error_message"

  return "$exit_code"
}

# ============================================================================
# Subcommand: status
# ============================================================================
cmd_status() {
  local session_dir="${1:?status requires SESSION_DIR}"
  local target
  target="$(wave_status_path "$session_dir")"
  [ -f "$target" ] || die "wave-status.json not found at $target"

  jq -r '
    "Session: \(.session_id) | Profile: \(.profile) | Overall: \(.overall_status) | Current wave: \(.current_wave)/3",
    "Total lanes: active=\(.total_lanes_active), completed=\(.total_lanes_completed), failed=\(.total_lanes_failed)",
    "",
    "Wave 1 [\(.wave_1.gate_status)]: lanes=\(.wave_1.lane_count) pass=\(.wave_1.pass_count) fail=\(.wave_1.fail_count) timeout=\(.wave_1.timeout_count) skip=\(.wave_1.skip_count) duration=\(.wave_1.duration_sec)s",
    "Wave 2 [\(.wave_2.gate_status)]: lanes=\(.wave_2.lane_count) pass=\(.wave_2.pass_count) fail=\(.wave_2.fail_count) timeout=\(.wave_2.timeout_count) skip=\(.wave_2.skip_count) duration=\(.wave_2.duration_sec)s",
    "Wave 3 [\(.wave_3.gate_status)]: lanes=\(.wave_3.lane_count) pass=\(.wave_3.pass_count) fail=\(.wave_3.fail_count) timeout=\(.wave_3.timeout_count) skip=\(.wave_3.skip_count) duration=\(.wave_3.duration_sec)s"
  ' "$target"
}

# ============================================================================
# Subcommand: gate-check (read-only inspection)
# ============================================================================
# Returns exit 0/1/2 based on a previously-recorded gate_status (after `end`)
cmd_gate_check() {
  local session_dir="${1:?gate-check requires SESSION_DIR}"
  local wave_id="${2:?gate-check requires WAVE_ID}"
  local target
  target="$(wave_status_path "$session_dir")"
  [ -f "$target" ] || die "wave-status.json not found at $target"

  local gs
  gs="$(jq -r --argjson w "$wave_id" '.["wave_" + ($w | tostring)].gate_status' "$target")"
  case "$gs" in
    PASS|SKIPPED) echo "PASS"; return 0 ;;
    PARTIAL_FAIL) echo "PARTIAL_FAIL"; return 2 ;;
    FAIL_THRESHOLD) echo "FAIL_THRESHOLD"; return 1 ;;
    PENDING|RUNNING) echo "INCOMPLETE($gs)"; return 3 ;;
    *) die "Unknown gate_status for wave $wave_id: $gs" ;;
  esac
}

# ============================================================================
# Main dispatcher
# ============================================================================

require_jq

CMD="${1:-}"
shift || true

case "$CMD" in
  init)       cmd_init "$@" ;;
  start)      cmd_start "$@" ;;
  end)        cmd_end "$@" ;;
  status)     cmd_status "$@" ;;
  gate-check) cmd_gate_check "$@" ;;
  ""|-h|--help|help)
    cat <<'EOF'
Usage: wave-coordinator.sh <subcommand> [args...]

Subcommands:
  init    <SESSION_DIR> <PROFILE>                      Init wave-status.json from template
  start   <SESSION_DIR> <WAVE_ID> "<LANES_CSV>"        Mark wave started + populate lanes_active
                                                       (LANES_CSV empty = use canonical wave lanes)
  end     <SESSION_DIR> <WAVE_ID>                      Aggregate lane outcomes + gate check
                                                       Exit: 0=PASS, 1=FAIL_THRESHOLD, 2=PARTIAL_FAIL
  status  <SESSION_DIR>                                Print wave state summary
  gate-check <SESSION_DIR> <WAVE_ID>                   Read-only gate check (re-evaluate recorded state)

Env overrides:
  MCV3_CMI_WAVE_STATUS_TPL  — Override template path (default: skill templates/wave-status.json)
EOF
    [ -z "$CMD" ] && exit 0 || exit 0
    ;;
  *) die "Unknown subcommand: $CMD (try --help)" ;;
esac
