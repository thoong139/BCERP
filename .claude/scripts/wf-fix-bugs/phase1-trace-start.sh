#!/usr/bin/env bash
# =============================================================================
# phase1-trace-start.sh — Phase 1 Step 1.17 TRACE START (dual-write)
# =============================================================================
# Mục đích (v10.14.0 — extracted from phase1-init.md):
#   Ghi START event vào session-log.json + global trace log (CORE-026).
#   Tiết kiệm ~15 dòng inline bash trong procedure file.
#
# Required env vars: SESSION_DIR, SESSION_ID, PROFILE, SCOPE, DIMS_ARRAY
#
# Output: (no stdout output — silent on success)
#
# Exit codes:
#   0 — Success
#   35 — Append fail (E035 NON-BLOCKING per CORE-026 trace là output-only)
#
# Compatibility: jq atomic write + dual-write pattern.
# =============================================================================

set -u

# ── Validate env vars ────────────────────────────────────────────────────────
for var in SESSION_DIR SESSION_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: \$$var required" >&2
    exit 1
  fi
done

PROFILE="${PROFILE:-unknown}"
SCOPE="${SCOPE:-unknown}"
DIMS_ARRAY="${DIMS_ARRAY:-}"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── 1. Session-local trace (atomic append) ──────────────────────────────────
SESSION_TRACE="$SESSION_DIR/session-log.json"
EXIT_CODE=0

if [ -s "$SESSION_TRACE" ]; then
  TMP="${SESSION_TRACE}.tmp.$$"
  if jq --arg ts "$NOW" --arg p "$PROFILE" --arg s "$SCOPE" --arg d "$DIMS_ARRAY" \
       '.events += [{"phase": 1, "event": "START", "timestamp": $ts, "profile": $p, "scope": $s, "dims": $d}]' \
       "$SESSION_TRACE" > "$TMP" 2>/dev/null \
     && jq '.' "$TMP" > /dev/null 2>&1 \
     && mv "$TMP" "$SESSION_TRACE"; then
    : # success
  else
    rm -f "$TMP"
    echo "WARN E035: Session trace append fail (non-blocking)" >&2
    EXIT_CODE=35
  fi
else
  echo "WARN E035: Session trace file missing — TRACE START skipped" >&2
  EXIT_CODE=35
fi

# ── 2. Global trace (dual-write) ─────────────────────────────────────────────
GLOBAL_TRACE=".mc-data/work/_trace/session-log.json"
mkdir -p "$(dirname "$GLOBAL_TRACE")"

if ! echo "{\"session_id\":\"$SESSION_ID\",\"phase\":1,\"event\":\"START\",\"timestamp\":\"$NOW\"}" >> "$GLOBAL_TRACE" 2>/dev/null; then
  echo "WARN E035: Global trace append fail (non-blocking)" >&2
fi

# E035 trace fail là NON-BLOCKING — pipeline tiếp tục
exit $EXIT_CODE
