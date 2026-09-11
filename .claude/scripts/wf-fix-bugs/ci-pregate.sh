#!/usr/bin/env bash
# =============================================================================
# ci-pregate.sh — CI PRE-GATE wrapper (Protocol 20 §20.8 — gộp Na/Nb/Nc)
# =============================================================================
# Gộp 3 CI PRE-GATE sub-steps thành 1 call duy nhất cho Phase 1 orchestrator:
#   Na. Load CI Capabilities      → ci-detect.sh
#   Nb. Index Freshness Check     → ci-freshness-check.sh
#   Nc. Agent Context Injection   → ci-inject-context.sh
#
# Output: JSON 1 dòng (stdout) cho orchestrator parse:
#   {
#     "gitnexus_available": true|false,
#     "serena_available": true|false,
#     "freshness_status": "ok|light|strong|severe|skipped",
#     "ci_context_file": "<path>",     # null nếu không có CI
#     "ci_route": "primary|fallback"   # primary = có CI, fallback = Grep/Glob
#   }
#
# Exit codes:
#   0 — Success (luôn 0 — graceful degradation, không block pipeline)
#   1 — Internal error (script crash)
#
# Usage (Phase 1 orchestrator):
#   eval "$(bash .claude/scripts/wf-fix-bugs/ci-pregate.sh --eval)"
#   # Sets: $GITNEXUS_AVAILABLE, $SERENA_AVAILABLE, $FRESHNESS_STATUS,
#   #       $CI_CONTEXT_FILE, $CI_ROUTE, $CI_CONTEXT (file content)
#
# Compatibility: Git Bash on Windows + WSL. Pure bash.
# =============================================================================

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CI_DETECT="$SCRIPT_DIR/ci-detect.sh"
CI_FRESHNESS="$SCRIPT_DIR/ci-freshness-check.sh"
CI_INJECT="$SCRIPT_DIR/ci-inject-context.sh"

EVAL_MODE=false
[ "${1:-}" = "--eval" ] && EVAL_MODE=true

# ── Na: Load CI Capabilities ─────────────────────────────────────────────────
set +e
bash "$CI_DETECT" >/dev/null 2>&1
DETECT_EXIT=$?
set -e

CACHE_FILE=".mc-data/work/_meta/code-intelligence.json"
if [ -f "$CACHE_FILE" ]; then
  GITNEXUS_AVAILABLE=$(jq -r '.gitnexus.available // false' "$CACHE_FILE" 2>/dev/null || echo "false")
  SERENA_AVAILABLE=$(jq -r '.serena.available // false' "$CACHE_FILE" 2>/dev/null || echo "false")
else
  GITNEXUS_AVAILABLE="false"
  SERENA_AVAILABLE="false"
fi

# Lock held → graceful fallback
if [ "$DETECT_EXIT" -eq 2 ]; then
  GITNEXUS_AVAILABLE="false"
  SERENA_AVAILABLE="false"
fi

# ── Nb: Index Freshness Check ────────────────────────────────────────────────
set +e
FRESHNESS_JSON=$(bash "$CI_FRESHNESS" 2>/dev/null)
set -e

if [ -n "$FRESHNESS_JSON" ]; then
  FRESHNESS_STATUS=$(echo "$FRESHNESS_JSON" | jq -r '.status // "skipped"' 2>/dev/null || echo "skipped")
else
  FRESHNESS_STATUS="skipped"
fi

# ── Nc: Agent Context Injection ──────────────────────────────────────────────
CI_CONTEXT_FILE=""
CI_CONTEXT=""
if [ "$GITNEXUS_AVAILABLE" = "true" ] || [ "$SERENA_AVAILABLE" = "true" ]; then
  CI_CONTEXT_FILE=".mc-data/work/_meta/ci-context.snippet.md"
  mkdir -p "$(dirname "$CI_CONTEXT_FILE")"
  set +e
  bash "$CI_INJECT" > "$CI_CONTEXT_FILE" 2>/dev/null
  INJECT_EXIT=$?
  set -e
  if [ "$INJECT_EXIT" -ne 0 ] || [ ! -s "$CI_CONTEXT_FILE" ]; then
    CI_CONTEXT_FILE=""
  else
    CI_CONTEXT=$(cat "$CI_CONTEXT_FILE")
  fi
fi

# ── Route decision ───────────────────────────────────────────────────────────
if [ "$GITNEXUS_AVAILABLE" = "true" ] || [ "$SERENA_AVAILABLE" = "true" ]; then
  CI_ROUTE="primary"
else
  CI_ROUTE="fallback"
fi

# ── Output ───────────────────────────────────────────────────────────────────
if [ "$EVAL_MODE" = "true" ]; then
  # Eval-friendly output for `eval "$(... --eval)"`
  cat <<EOF
export GITNEXUS_AVAILABLE="$GITNEXUS_AVAILABLE"
export SERENA_AVAILABLE="$SERENA_AVAILABLE"
export FRESHNESS_STATUS="$FRESHNESS_STATUS"
export CI_CONTEXT_FILE="$CI_CONTEXT_FILE"
export CI_ROUTE="$CI_ROUTE"
EOF
  # CI_CONTEXT có thể multi-line → đọc từ file khi cần (không export inline)
else
  # JSON output for jq parsing
  jq -n \
    --arg gn "$GITNEXUS_AVAILABLE" \
    --arg sn "$SERENA_AVAILABLE" \
    --arg fs "$FRESHNESS_STATUS" \
    --arg cf "$CI_CONTEXT_FILE" \
    --arg cr "$CI_ROUTE" \
    '{
      gitnexus_available: ($gn == "true"),
      serena_available: ($sn == "true"),
      freshness_status: $fs,
      ci_context_file: (if $cf == "" then null else $cf end),
      ci_route: $cr
    }'
fi

exit 0
