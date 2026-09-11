#!/usr/bin/env bash
# =============================================================================
# phase-finalize.sh — Generic Phase TRACE COMPLETE + fix-status update
# =============================================================================
# Mục đích (v10.15.0 — reusable across Phases 2-7):
#   1 atomic call thay cho TRACE COMPLETE + atomic fix-status.phases.phaseN update.
#   Replaces ~20 dòng inline bash trong mỗi phase file.
#
# Required env vars:
#   SESSION_DIR        — Session root
#   PHASE_NUM          — 2|3|4|5|6|7
#
# Optional env vars (extra fields to write into fix-status.phases.phaseN):
#   PHASE_EXTRA_FIELDS — JSON object string, vd: '{"interface_type":"web"}'
#                        Merged vào .phases.phase{N} qua jq.
#   PHASE_TOP_FIELDS   — JSON object string, vd: '{"interface_type":"web"}'
#                        Merged vào TOP-LEVEL fix-status.json
#
# Output: (silent on success)
#
# Exit codes:
#   0 — Success
#   1 — Required env var missing
#   35 — Atomic write fail (E035)
#
# Compatibility: jq atomic write + dual-write trace pattern.
# =============================================================================

set -u

# ── Validate env vars ────────────────────────────────────────────────────────
for var in SESSION_DIR PHASE_NUM; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: \$$var required" >&2
    exit 1
  fi
done

if ! echo "$PHASE_NUM" | grep -qE '^[2-7]$'; then
  echo "ERROR: PHASE_NUM must be 2-7, got '$PHASE_NUM'" >&2
  exit 1
fi

PHASE_KEY="phase$PHASE_NUM"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── 1. TRACE COMPLETE event (session-log.json) ──────────────────────────────
SL="$SESSION_DIR/session-log.json"
if [ -s "$SL" ]; then
  TMP_SL="$SL.tmp.$$"
  if jq --arg ts "$NOW" --arg phase "$PHASE_KEY" \
       '.events += [{phase: $phase, event: "COMPLETE", timestamp: $ts}]' \
       "$SL" > "$TMP_SL" 2>/dev/null \
     && jq '.' "$TMP_SL" >/dev/null 2>&1 \
     && mv "$TMP_SL" "$SL"; then
    : # success
  else
    rm -f "$TMP_SL"
    echo "WARN: session-log COMPLETE event lost" >&2
  fi
else
  echo "WARN: session-log.json missing — TRACE COMPLETE skipped" >&2
fi

# ── 2. Global trace dual-write (CORE-026) ────────────────────────────────────
GLOBAL_TRACE=".mc-data/work/_trace/session-log.json"
mkdir -p "$(dirname "$GLOBAL_TRACE")"
SESSION_ID=$(jq -r '.session_id // empty' "$SESSION_DIR/fix-status.json" 2>/dev/null || echo "unknown")
echo "{\"session_id\":\"$SESSION_ID\",\"phase\":$PHASE_NUM,\"event\":\"COMPLETE\",\"timestamp\":\"$NOW\"}" \
  >> "$GLOBAL_TRACE" 2>/dev/null || echo "WARN: global trace append fail" >&2

# ── 3. fix-status.json atomic update ─────────────────────────────────────────
FS="$SESSION_DIR/fix-status.json"
if [ ! -s "$FS" ]; then
  echo "E035: fix-status.json missing" >&2
  exit 35
fi

TMP_FS="$FS.tmp.$$"

# Build jq filter dynamically based on extra fields
JQ_FILTER='.phases.'"$PHASE_KEY"' = {"status":"completed","completed_at":$ts}'

# Merge phase-specific extra fields (vd: interface_type)
if [ -n "${PHASE_EXTRA_FIELDS:-}" ]; then
  JQ_FILTER="$JQ_FILTER"' * {phases: {'"$PHASE_KEY"': '"$PHASE_EXTRA_FIELDS"'}}'
fi

# Merge top-level extra fields
if [ -n "${PHASE_TOP_FIELDS:-}" ]; then
  JQ_FILTER="$JQ_FILTER"' * '"$PHASE_TOP_FIELDS"
fi

# Always update .updated_at
JQ_FILTER="$JQ_FILTER"' | .updated_at = $ts'

if jq --arg ts "$NOW" "$JQ_FILTER" "$FS" > "$TMP_FS" 2>/dev/null \
   && jq '.' "$TMP_FS" >/dev/null 2>&1 \
   && mv "$TMP_FS" "$FS"; then
  : # success
else
  rm -f "$TMP_FS"
  echo "E035: fix-status.json atomic update fail" >&2
  exit 35
fi

exit 0
