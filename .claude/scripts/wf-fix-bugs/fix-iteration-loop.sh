#!/usr/bin/env bash
# =============================================================================
# fix-iteration-loop.sh — Wave 2 G2 (v11.0.0)
# =============================================================================
# Orchestrator-side helper: đọc state hiện tại, decide tiếp tục loop, escalate
# CDG, hay finalize Phase 6. Init fix-iterations.json nếu chưa có.
#
# Required env vars:
#   SESSION_DIR
#
# Optional env vars:
#   MCV3_FIX_LOOP_MAX_ITER          (default: 3)
#   MCV3_FIX_LOOP_AUTO_ESCALATE     (default: true)
#   MCV3_FIX_LOOP_DISABLE           (default: false — set true để skip toàn bộ loop, behavior v10.x)
#
# Inputs (read):
#   $SESSION_DIR/phase6-execute/unsanctioned-defers.json (từ verify-defer-reasons.sh)
#   $SESSION_DIR/phase6-execute/fix-iterations.json (state — init nếu thiếu)
#
# Outputs (write):
#   $SESSION_DIR/phase6-execute/fix-iterations.json (update với decision + iteration entry)
#   stdout: decision JSON
#
# Exit codes:
#   0 — Decision emitted (kể cả continue/escalate/done)
#   1 — Required input missing
#   3 — Atomic write fail
#
# Output JSON (stdout):
#   {
#     "decision": "continue_loop|escalate_cdg|done|disabled",
#     "current_iteration": <int>,
#     "max_iterations": <int>,
#     "unsanctioned_count": <int>,
#     "actual_fixed": <int>,
#     "next_action": "spawn_execute_with_unsanctioned|ask_user_question|finalize_phase6|finalize_phase6_legacy"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

[ -n "${SESSION_DIR:-}" ] || { echo "ERROR: SESSION_DIR required" >&2; exit 1; }

UNSANCT_FILE="$SESSION_DIR/phase6-execute/unsanctioned-defers.json"
ITER_FILE="$SESSION_DIR/phase6-execute/fix-iterations.json"
ITER_TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase6-execute/fix-iterations.json"

MAX_ITER="${MCV3_FIX_LOOP_MAX_ITER:-3}"
AUTO_ESCALATE="${MCV3_FIX_LOOP_AUTO_ESCALATE:-true}"
LOOP_DISABLE="${MCV3_FIX_LOOP_DISABLE:-false}"

# ── Disable check (backward-compat v10.x behavior) ──────────────────────────
if [ "$LOOP_DISABLE" = "true" ]; then
  jq -n --argjson m "$MAX_ITER" '{
    decision: "disabled",
    current_iteration: 0,
    max_iterations: $m,
    unsanctioned_count: 0,
    actual_fixed: 0,
    next_action: "finalize_phase6_legacy",
    note: "MCV3_FIX_LOOP_DISABLE=true — skip loop (v10.x compat)"
  }'
  exit 0
fi

# ── Verify input ─────────────────────────────────────────────────────────────
[ -s "$UNSANCT_FILE" ] || { echo "ERROR: unsanctioned-defers.json missing — chạy verify-defer-reasons.sh trước" >&2; exit 1; }

UNSANCT_COUNT=$(jq -r '.summary.unsanctioned_count // 0' "$UNSANCT_FILE" 2>/dev/null || echo 0)
ACTUAL_FIXED=$(jq -r '.summary.actually_fixed_count // 0' "$UNSANCT_FILE" 2>/dev/null || echo 0)
ACTUAL_DEFERRED=$(jq -r '.summary.actually_deferred_count // 0' "$UNSANCT_FILE" 2>/dev/null || echo 0)
SHOULD_FIX=$(jq -r '.summary.should_fix_count // 0' "$UNSANCT_FILE" 2>/dev/null || echo 0)

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SESSION_ID=$(basename "$SESSION_DIR")

# ── Init fix-iterations.json nếu chưa có ────────────────────────────────────
if [ ! -s "$ITER_FILE" ]; then
  mkdir -p "$(dirname "$ITER_FILE")"
  if [ -f "$ITER_TPL" ]; then
    TMP="$ITER_FILE.tmp.init.$$"
    jq --arg sid "$SESSION_ID" --arg ts "$NOW" \
       --argjson maxi "$MAX_ITER" \
       --argjson init_sf "$SHOULD_FIX" \
       --argjson init_af "$ACTUAL_FIXED" \
       --argjson init_uc "$UNSANCT_COUNT" \
       '.session_id = $sid
        | .max_iterations = $maxi
        | .started_at = $ts
        | .updated_at = $ts
        | .summary.initial_should_fix = $init_sf
        | .summary.initial_actually_fixed = $init_af
        | .summary.initial_unsanctioned = $init_uc
        | del(._template_notes, ._schema_notes)' \
       "$ITER_TPL" > "$TMP" \
       && jq '.' "$TMP" >/dev/null \
       && mv "$TMP" "$ITER_FILE" \
       || { rm -f "$TMP"; echo "ERROR: init fix-iterations.json fail" >&2; exit 3; }
  else
    # Fallback inline init
    jq -n --arg sid "$SESSION_ID" --arg ts "$NOW" --argjson maxi "$MAX_ITER" \
       --argjson init_sf "$SHOULD_FIX" --argjson init_af "$ACTUAL_FIXED" --argjson init_uc "$UNSANCT_COUNT" \
       '{
         "$schema": "fix-iterations-v1",
         session_id: $sid,
         max_iterations: $maxi,
         current_iteration: 0,
         started_at: $ts,
         updated_at: $ts,
         iterations: [],
         final_decision: null,
         cdg_token: null,
         summary: {
           initial_should_fix: $init_sf,
           initial_actually_fixed: $init_af,
           initial_unsanctioned: $init_uc,
           final_fixed_total: $init_af,
           final_unsanctioned_remaining: $init_uc,
           net_improvement: 0
         }
       }' > "$ITER_FILE"
  fi
fi

# Đọc state hiện tại
CURRENT_ITER=$(jq -r '.current_iteration // 0' "$ITER_FILE")

# ── Decision logic (v11.0.1 — thêm no-progress guard, v11.0.2 — fix PRIOR semantics) ───────
DECISION=""
NEXT_ACTION=""

# No-progress guard: nếu CURRENT_ITER >= 1 và actual_fixed KHÔNG tăng so với
# state TRƯỚC iteration hiện tại → force escalate (tránh infinite spin trên items không fixable)
#
# v11.0.2 fix: PRIOR_FIXED phải là input_actually_fixed của iter hiện tại
# (= state BEFORE iter ran), KHÔNG phải after_fix_count (= state AFTER iter ran,
# = ACTUAL_FIXED → luôn ≤ ACTUAL_FIXED → false-fire NO_PROGRESS sau MỌI iter).
# input_actually_fixed được snapshot tại continue_loop case khi iter được bump.
NO_PROGRESS=false
if [ "$CURRENT_ITER" -ge 1 ]; then
  PRIOR_FIXED=$(jq -r "(.iterations[$((CURRENT_ITER - 1))].input_actually_fixed // 0)" "$ITER_FILE" 2>/dev/null || echo 0)
  if [ "$ACTUAL_FIXED" -le "$PRIOR_FIXED" ]; then
    NO_PROGRESS=true
    echo "WARN(v11): No-progress detected (iter $CURRENT_ITER: $ACTUAL_FIXED vs prior $PRIOR_FIXED) — force escalate CDG" >&2
  fi
fi

if [ "$UNSANCT_COUNT" -eq 0 ]; then
  # Tất cả OK — không có unsanctioned defers
  DECISION="done"
  NEXT_ACTION="finalize_phase6"
elif [ "$NO_PROGRESS" = "true" ]; then
  # No-progress → skip remaining budget, force CDG escalation
  if [ "$AUTO_ESCALATE" = "true" ]; then
    DECISION="escalate_cdg"
    NEXT_ACTION="ask_user_question"
  else
    DECISION="done"
    NEXT_ACTION="finalize_phase6"
  fi
elif [ "$CURRENT_ITER" -lt "$MAX_ITER" ]; then
  # Còn budget + có progress — tiếp tục loop
  DECISION="continue_loop"
  NEXT_ACTION="spawn_execute_with_unsanctioned"
else
  # Hết budget
  if [ "$AUTO_ESCALATE" = "true" ]; then
    DECISION="escalate_cdg"
    NEXT_ACTION="ask_user_question"
  else
    # Skip CDG, chấp nhận state hiện tại
    DECISION="done"
    NEXT_ACTION="finalize_phase6"
  fi
fi

# ── Update fix-iterations.json: bump iteration counter nếu continue ─────────
# (Iteration ENTRY chính sẽ được append bởi orchestrator sau khi execute xong.
#  Ở đây chỉ update updated_at + final_decision nếu done/escalate)
TMP="$ITER_FILE.tmp.upd.$$"
case "$DECISION" in
  continue_loop)
    NEW_ITER=$((CURRENT_ITER + 1))
    jq --arg ts "$NOW" --argjson ni "$NEW_ITER" \
       --argjson uc "$UNSANCT_COUNT" --argjson af "$ACTUAL_FIXED" \
       '.current_iteration = $ni
        | .updated_at = $ts
        | .iterations += [{
            iteration: $ni,
            started_at: $ts,
            completed_at: null,
            input_unsanctioned_count: $uc,
            input_actually_fixed: $af,
            after_fix_count: null,
            after_deferred_count: null,
            agent_decisions: []
          }]' "$ITER_FILE" > "$TMP"
    ;;
  done)
    jq --arg ts "$NOW" --arg fd "completed" \
       --argjson af "$ACTUAL_FIXED" --argjson uc "$UNSANCT_COUNT" \
       --argjson init_af "$(jq -r '.summary.initial_actually_fixed' "$ITER_FILE")" \
       '.completed_at = $ts
        | .updated_at = $ts
        | .final_decision = $fd
        | .summary.final_fixed_total = $af
        | .summary.final_unsanctioned_remaining = $uc
        | .summary.net_improvement = ($af - $init_af)' "$ITER_FILE" > "$TMP"
    ;;
  escalate_cdg)
    jq --arg ts "$NOW" --arg fd "cdg_escalated" \
       --argjson af "$ACTUAL_FIXED" --argjson uc "$UNSANCT_COUNT" \
       --argjson init_af "$(jq -r '.summary.initial_actually_fixed' "$ITER_FILE")" \
       '.updated_at = $ts
        | .final_decision = $fd
        | .summary.final_fixed_total = $af
        | .summary.final_unsanctioned_remaining = $uc
        | .summary.net_improvement = ($af - $init_af)' "$ITER_FILE" > "$TMP"
    ;;
esac
[ -s "$TMP" ] && jq '.' "$TMP" >/dev/null && mv "$TMP" "$ITER_FILE" || { rm -f "$TMP"; echo "WARN: fix-iterations update fail" >&2; }

# ── Emit decision JSON ──────────────────────────────────────────────────────
jq -n \
  --arg dec "$DECISION" \
  --argjson ci "$CURRENT_ITER" \
  --argjson mi "$MAX_ITER" \
  --argjson uc "$UNSANCT_COUNT" \
  --argjson af "$ACTUAL_FIXED" \
  --arg na "$NEXT_ACTION" \
  '{
    decision: $dec,
    current_iteration: $ci,
    max_iterations: $mi,
    unsanctioned_count: $uc,
    actual_fixed: $af,
    next_action: $na
  }'

echo "INFO(v11): loop decision=$DECISION, iter=$CURRENT_ITER/$MAX_ITER, unsanct=$UNSANCT_COUNT" >&2
exit 0
