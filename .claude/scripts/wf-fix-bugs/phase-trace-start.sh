#!/usr/bin/env bash
# =============================================================================
# phase-trace-start.sh — Generic Phase TRACE START
# =============================================================================
# Mục đích (v10.15.0 — reusable across Phases 2-7):
#   Ghi START event vào session-log.json (atomic) cho phase N bất kỳ.
#   Replaces ~10 dòng inline bash trong mỗi phase file.
#
# Required env vars:
#   SESSION_DIR        — Session root
#   PHASE_NUM          — 2|3|4|5|6|7
#
# Optional env vars:
#   PHASE_METADATA     — JSON object string thêm vào event, vd: '{"profile":"deep"}'
#
# Output: (silent on success)
#
# Exit codes:
#   0 — Success
#   1 — Required env var missing
#   35 — Atomic write fail (E001)
#
# Compatibility: jq atomic write.
# =============================================================================

set -u

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
SL="$SESSION_DIR/session-log.json"

if [ ! -s "$SL" ]; then
  echo "E001: session-log.json missing" >&2
  exit 35
fi

TMP="$SL.tmp.$$"

# Build event object (optionally merge metadata)
EVENT_FILTER='{phase: $phase, event: "START", timestamp: $ts}'
if [ -n "${PHASE_METADATA:-}" ]; then
  EVENT_FILTER="$EVENT_FILTER"' * '"$PHASE_METADATA"
fi

if jq --arg ts "$NOW" --arg phase "$PHASE_KEY" \
     ".events += [$EVENT_FILTER]" \
     "$SL" > "$TMP" 2>/dev/null \
   && jq '.' "$TMP" >/dev/null 2>&1 \
   && mv "$TMP" "$SL"; then
  exit 0
else
  rm -f "$TMP"
  echo "E001: session-log START event fail" >&2
  exit 35
fi
