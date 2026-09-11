#!/usr/bin/env bash
# wf-fix-trace-rotate.sh — Rotate session-log.json khi vượt threshold (v7.0 S11)
#
# Rotate `.mc-data/work/_trace/session-log.json` qua gzip khi size > threshold.
# Idempotent: gọi nhiều lần OK — không rotate file nhỏ hơn threshold.
#
# Usage:
#   wf-fix-trace-rotate.sh                   # rotate nếu cần (default 10MB)
#   wf-fix-trace-rotate.sh --check           # chỉ check, KHÔNG rotate (exit 0 nếu < threshold, exit 2 nếu cần rotate)
#   wf-fix-trace-rotate.sh --force           # rotate kể cả khi < threshold
#   wf-fix-trace-rotate.sh --trace-path PATH # custom path (default: .mc-data/work/_trace/session-log.json)
#
# Threshold:
#   Default 10MB. Override qua env: MCV3_TRACE_ROTATE_THRESHOLD_MB
#
# Output rotated file:
#   <trace-path-dir>/session-log.YYYY-MM-DD-HHMMSS.json.gz
#
# Exit codes:
#   0 — success (rotated hoặc no-op vì < threshold)
#   1 — invalid args / trace file not found
#   2 — --check mode + file >= threshold (signal cần rotate)
#   3 — gzip/atomic write failure
#
# Cross-platform: GNU/Linux, macOS (BSD), Git Bash (MINGW), WSL.

set -euo pipefail

# Source common helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$SCRIPT_DIR/../.." && pwd; })"

# ============================================================
# ARG PARSING
# ============================================================
TRACE_PATH="$REPO_ROOT/.mc-data/work/_trace/session-log.json"
MODE="rotate"  # rotate | check | force

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      MODE="check"
      shift
      ;;
    --force)
      MODE="force"
      shift
      ;;
    --trace-path)
      TRACE_PATH="$2"
      shift 2
      ;;
    --trace-path=*)
      TRACE_PATH="${1#--trace-path=}"
      shift
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg '$1'" >&2
      exit 1
      ;;
  esac
done

# ============================================================
# THRESHOLD RESOLUTION
# ============================================================
THRESHOLD_MB="${MCV3_TRACE_ROTATE_THRESHOLD_MB:-10}"

# Validate threshold is positive integer
if ! [[ "$THRESHOLD_MB" =~ ^[0-9]+$ ]] || [[ "$THRESHOLD_MB" -le 0 ]]; then
  echo "ERROR: MCV3_TRACE_ROTATE_THRESHOLD_MB must be positive integer (got: $THRESHOLD_MB)" >&2
  exit 1
fi

THRESHOLD_BYTES=$((THRESHOLD_MB * 1024 * 1024))

# ============================================================
# FILE CHECK
# ============================================================
if [[ ! -f "$TRACE_PATH" ]]; then
  if [[ "$MODE" == "check" ]]; then
    # No file = nothing to rotate
    echo "Trace file not found: $TRACE_PATH (nothing to rotate)" >&2
    exit 0
  else
    echo "ERROR: trace file not found: $TRACE_PATH" >&2
    exit 1
  fi
fi

# Get file size cross-platform (BSD stat -f%z, GNU stat -c%s)
file_size_bytes() {
  local f="$1"
  if stat -c '%s' "$f" >/dev/null 2>&1; then
    stat -c '%s' "$f"
  else
    stat -f '%z' "$f"
  fi
}

CURRENT_BYTES=$(file_size_bytes "$TRACE_PATH")
CURRENT_MB=$(awk "BEGIN { printf \"%.2f\", $CURRENT_BYTES / 1024 / 1024 }")

# ============================================================
# DECISION LOGIC
# ============================================================
NEEDS_ROTATE=false
if [[ "$CURRENT_BYTES" -ge "$THRESHOLD_BYTES" ]]; then
  NEEDS_ROTATE=true
fi

if [[ "$MODE" == "check" ]]; then
  echo "Trace file: $TRACE_PATH"
  echo "  Size: ${CURRENT_MB} MB (${CURRENT_BYTES} bytes)"
  echo "  Threshold: ${THRESHOLD_MB} MB (${THRESHOLD_BYTES} bytes)"
  if [[ "$NEEDS_ROTATE" == "true" ]]; then
    echo "  Status: NEEDS ROTATION"
    exit 2
  else
    echo "  Status: OK (within threshold)"
    exit 0
  fi
fi

if [[ "$MODE" == "rotate" && "$NEEDS_ROTATE" == "false" ]]; then
  # No-op: under threshold + not forced
  echo "Trace file size ${CURRENT_MB} MB < threshold ${THRESHOLD_MB} MB — no rotation needed."
  exit 0
fi

# ============================================================
# ROTATE
# ============================================================
TRACE_DIR="$(dirname "$TRACE_PATH")"
TRACE_BASE="$(basename "$TRACE_PATH" .json)"
TIMESTAMP="$(date -u +%Y-%m-%d-%H%M%S)"
ROTATED_PATH="${TRACE_DIR}/${TRACE_BASE}.${TIMESTAMP}.json.gz"

echo "Rotating: $TRACE_PATH (${CURRENT_MB} MB) → $ROTATED_PATH"

# Step 1: gzip → temp file (preserve original until success)
TEMP_GZ="${ROTATED_PATH}.tmp"
if ! gzip -c "$TRACE_PATH" > "$TEMP_GZ"; then
  rm -f "$TEMP_GZ"
  echo "ERROR: gzip failed" >&2
  exit 3
fi

# Step 2: verify gzip is valid
if ! gzip -t "$TEMP_GZ" 2>/dev/null; then
  rm -f "$TEMP_GZ"
  echo "ERROR: rotated file failed gzip integrity check" >&2
  exit 3
fi

# Step 3: atomic move temp → final rotated path
if ! mv "$TEMP_GZ" "$ROTATED_PATH"; then
  rm -f "$TEMP_GZ"
  echo "ERROR: failed to move rotated file to final path" >&2
  exit 3
fi

# Step 4: truncate original to empty (preserve file for ongoing appends)
# Use atomic_write via temp + mv to avoid concurrent write race
TEMP_EMPTY="${TRACE_PATH}.tmp"
: > "$TEMP_EMPTY"
if ! mv "$TEMP_EMPTY" "$TRACE_PATH"; then
  rm -f "$TEMP_EMPTY"
  echo "ERROR: failed to truncate original trace file" >&2
  exit 3
fi

# Step 5: report success
ROTATED_BYTES=$(file_size_bytes "$ROTATED_PATH")
ROTATED_MB=$(awk "BEGIN { printf \"%.2f\", $ROTATED_BYTES / 1024 / 1024 }")
echo "Rotated successfully:"
echo "  Original: ${CURRENT_MB} MB"
echo "  Compressed: ${ROTATED_MB} MB"
echo "  New empty file: $TRACE_PATH"
exit 0
