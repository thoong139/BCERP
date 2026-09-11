#!/usr/bin/env bash
# pf-generate-session-id.sh — Generate session ID for wf-preflight
# Format: {YYYY-MM-DD}-{scope-slug}-{NN}  (D1: NN counter)
# Usage: pf-generate-session-id.sh <all|system|module|feature> [SCOPE_NAME]
# Output: JSON {session_id, status, action, session_dir}
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/pf-common.sh"

SCOPE_TYPE="${1:?Usage: pf-generate-session-id.sh <all|system|module|feature> [SCOPE_NAME]}"
SCOPE_NAME="${2:-}"

DATE=$(date +%Y-%m-%d)

# Slug generation per D1 rules
case "$SCOPE_TYPE" in
  "all")
    SCOPE_SLUG="all"
    ;;
  "system")
    if [[ -z "$SCOPE_NAME" ]]; then
      echo '{"error":"scope_name_required_for_system"}'; exit 1
    fi
    SCOPE_SLUG="sys-$(echo "$SCOPE_NAME" | tr '[:upper:]' '[:lower:]' | \
      sed 's/[^a-z0-9-]/-/g' | sed 's/^sys-//' | sed 's/--*/-/g' | sed 's/-$//')"
    ;;
  "module")
    if [[ -z "$SCOPE_NAME" ]]; then
      echo '{"error":"scope_name_required_for_module"}'; exit 1
    fi
    SCOPE_SLUG="mod-$(echo "$SCOPE_NAME" | tr '[:upper:]' '[:lower:]' | \
      sed 's/[^a-z0-9-]/-/g' | sed 's/^mod-//' | sed 's/--*/-/g' | sed 's/-$//')"
    ;;
  "feature")
    if [[ -z "$SCOPE_NAME" ]]; then
      echo '{"error":"scope_name_required_for_feature"}'; exit 1
    fi
    SCOPE_SLUG="feat-$(echo "$SCOPE_NAME" | tr '[:upper:]' '[:lower:]' | \
      sed 's/[^a-z0-9-]/-/g' | sed 's/^feat-//' | sed 's/--*/-/g' | sed 's/-$//')"
    ;;
  *)
    echo "{\"error\":\"invalid_scope_type\",\"got\":\"$SCOPE_TYPE\",\"valid\":[\"all\",\"system\",\"module\",\"feature\"]}"
    exit 1
    ;;
esac

ensure_dirs

# NN counter: count existing sessions with same date+slug prefix
PREFIX="${DATE}-${SCOPE_SLUG}-"
EXISTING=0
if [[ -d "$SESSIONS_DIR" ]]; then
  EXISTING=$(ls "$SESSIONS_DIR" 2>/dev/null | grep -c "^${PREFIX}" || true)
fi
NN=$(printf "%02d" $((EXISTING + 1)))
SESSION_ID="${DATE}-${SCOPE_SLUG}-${NN}"
SESSION_DIR="$SESSIONS_DIR/$SESSION_ID"

# Paranoia check: collision should not happen with NN counter
if [[ -d "$SESSION_DIR" ]]; then
  echo "{\"error\":\"session_id_collision\",\"session_id\":\"$SESSION_ID\",\"hint\":\"concurrent_run_detected\"}"
  exit 1
fi

echo "{\"session_id\":\"$SESSION_ID\",\"status\":\"new\",\"action\":\"create\",\"session_dir\":\"$SESSION_DIR\",\"scope_slug\":\"$SCOPE_SLUG\"}"
