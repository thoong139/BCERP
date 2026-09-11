#!/usr/bin/env bash
# =============================================================================
# phase1-wave1-dispatch.sh — Phase 1 Wave 1 Parallel Discovery
# =============================================================================
# Mục đích (v10.11.0 — Phase 1 optimization):
#   Chạy SONG SONG 3 sub-steps độc lập của Phase 1:
#     1. Step 1.5 CI PRE-GATE         (slow if cache miss: 200ms-10s)
#     2. Step 1.6 Registry+Source+LEGACY (fast: 50-150ms)
#     3. Step 1.9 Sub-skill paths validation (cached: 10-100ms)
#
# Trước (v10.10): 3 bash invocations tuần tự ~300-500ms (cache hit case)
# Sau  (v10.11): 1 bash invocation, internal parallel ~150-200ms (giảm ~50%)
#
# Output: env-style stdout (eval-friendly) — orchestrator chỉ cần `eval "$(...)"`:
#   GITNEXUS_AVAILABLE=true
#   SERENA_AVAILABLE=true
#   FRESHNESS_STATUS=ok
#   CI_ROUTE=primary
#   CI_CONTEXT_FILE=/path/to/ci-context.txt
#   REGISTRY_VALID=true
#   SOURCE_VALID=true
#   SOURCE_DIR=src
#   LEGACY_MODE=false
#   INTERFACE_TYPE=web
#   PATHS_OK=13
#   PATHS_MISSING_COUNT=0
#   WAVE1_DURATION_MS=180
#
# Exit codes:
#   0 — Tất cả 3 sub-steps PASS (orchestrator vẫn phải check REGISTRY_VALID, SOURCE_VALID)
#   3 — Registry hoặc source code missing (E003)
#   4 — Sub-skill paths missing (E004)
#   14 — CI PRE-GATE script fail (E014 — graceful fallback)
#   Mã exit cao nhất nếu nhiều fail
#
# Compatibility: Git Bash + WSL + macOS/Linux. Pure bash + jq.
# =============================================================================

set -u   # KHÔNG dùng -e — manual exit code aggregation

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
T0=$(date +%s%3N 2>/dev/null || date +%s)

# ── Temp dir để collect parallel outputs ─────────────────────────────────────
WAVE1_TMP="${TMPDIR:-/tmp}/mcv3-wave1-$$"
mkdir -p "$WAVE1_TMP"

# Cleanup on exit (parent's trap KHÔNG affect — script process độc lập)
trap "rm -rf '$WAVE1_TMP'" EXIT INT TERM

# ── Worker 1: CI PRE-GATE ────────────────────────────────────────────────────
(
  if bash "$SCRIPT_DIR/ci-pregate.sh" --eval > "$WAVE1_TMP/ci.env" 2>"$WAVE1_TMP/ci.err"; then
    echo "CI_EXIT=0" >> "$WAVE1_TMP/ci.env"
  else
    echo "CI_EXIT=14" >> "$WAVE1_TMP/ci.env"
  fi
) &
PID_CI=$!

# ── Worker 2: Registry + Source + LEGACY_MODE ────────────────────────────────
(
  REGISTRY_VALID=false
  REQ_COUNT=0
  if [ -f .mc-data/docs/_meta/req-registry.json ]; then
    REQ_COUNT=$(jq '.requirements | length' .mc-data/docs/_meta/req-registry.json 2>/dev/null || echo 0)
    [ "$REQ_COUNT" -gt 0 ] && REGISTRY_VALID=true
  fi

  # Source code check
  SOURCE_DIR=""
  SOURCE_VALID=false
  if [ -d "src" ] && [ "$(find src -maxdepth 3 -type f 2>/dev/null | head -1)" != "" ]; then
    SOURCE_DIR="src"; SOURCE_VALID=true
  elif [ -d "apps" ] && [ "$(find apps -maxdepth 3 -type f 2>/dev/null | head -1)" != "" ]; then
    SOURCE_DIR="apps"; SOURCE_VALID=true
  fi

  # LEGACY_MODE detect (CORE-021) — portable size check
  LEGACY_MODE=false
  PC_FILE=".mc-data/work/legacy-scan/project-context.md"
  if [ -f "$PC_FILE" ]; then
    PC_SIZE=$(stat -c '%s' "$PC_FILE" 2>/dev/null \
              || stat -f '%z' "$PC_FILE" 2>/dev/null \
              || wc -c < "$PC_FILE" 2>/dev/null | tr -d ' ' \
              || echo 0)
    [ "${PC_SIZE:-0}" -gt 500 ] && LEGACY_MODE=true
  fi

  # Output env vars
  {
    echo "REGISTRY_VALID=$REGISTRY_VALID"
    echo "REQ_COUNT=$REQ_COUNT"
    echo "SOURCE_VALID=$SOURCE_VALID"
    echo "SOURCE_DIR='$SOURCE_DIR'"
    echo "LEGACY_MODE=$LEGACY_MODE"
    echo "INTERFACE_TYPE=web"   # default; orchestrator có thể override
  } > "$WAVE1_TMP/validation.env"

  # Exit code
  if [ "$REGISTRY_VALID" = "true" ] && [ "$SOURCE_VALID" = "true" ]; then
    echo "VALIDATION_EXIT=0" >> "$WAVE1_TMP/validation.env"
  else
    echo "VALIDATION_EXIT=3" >> "$WAVE1_TMP/validation.env"
  fi
) &
PID_VAL=$!

# ── Worker 3: Sub-skill paths validation (cached) ────────────────────────────
(
  if bash "$SCRIPT_DIR/phase1-validate-paths.sh" > "$WAVE1_TMP/paths.json" 2>"$WAVE1_TMP/paths.err"; then
    PATHS_EXIT=0
  else
    PATHS_EXIT=4
  fi
  PATHS_OK=$(jq -r '.paths_ok // 0' "$WAVE1_TMP/paths.json" 2>/dev/null || echo 0)
  PATHS_MISSING=$(jq -r '.missing_count // 0' "$WAVE1_TMP/paths.json" 2>/dev/null || echo 0)
  PATHS_CACHED=$(jq -r '.cached // false' "$WAVE1_TMP/paths.json" 2>/dev/null || echo false)
  {
    echo "PATHS_OK=$PATHS_OK"
    echo "PATHS_MISSING_COUNT=$PATHS_MISSING"
    echo "PATHS_CACHED=$PATHS_CACHED"
    echo "PATHS_EXIT=$PATHS_EXIT"
  } > "$WAVE1_TMP/paths.env"
) &
PID_PATHS=$!

# ── Wait cho cả 3 workers ────────────────────────────────────────────────────
wait "$PID_CI"
wait "$PID_VAL"
wait "$PID_PATHS"

# ── Aggregate outputs (echo ra stdout cho orchestrator eval) ─────────────────
cat "$WAVE1_TMP/ci.env" 2>/dev/null
cat "$WAVE1_TMP/validation.env" 2>/dev/null
cat "$WAVE1_TMP/paths.env" 2>/dev/null

# Read exit codes
CI_EXIT=$(grep '^CI_EXIT=' "$WAVE1_TMP/ci.env" 2>/dev/null | cut -d= -f2 || echo 14)
VAL_EXIT=$(grep '^VALIDATION_EXIT=' "$WAVE1_TMP/validation.env" 2>/dev/null | cut -d= -f2 || echo 3)
PATHS_EXIT=$(grep '^PATHS_EXIT=' "$WAVE1_TMP/paths.env" 2>/dev/null | cut -d= -f2 || echo 4)

# Compute total duration
T1=$(date +%s%3N 2>/dev/null || date +%s)
DURATION=$((T1 - T0))
echo "WAVE1_DURATION_MS=$DURATION"

# Echo errors ra stderr (debug)
[ -s "$WAVE1_TMP/ci.err" ] && { echo "[wave1] CI errors:" >&2; cat "$WAVE1_TMP/ci.err" >&2; }
[ -s "$WAVE1_TMP/paths.err" ] && { echo "[wave1] Paths errors:" >&2; cat "$WAVE1_TMP/paths.err" >&2; }

# Final exit: highest priority error wins (E003 > E004 > E014)
if [ "$VAL_EXIT" -ne 0 ]; then
  exit "$VAL_EXIT"      # E003 — registry/source missing (BLOCKING)
elif [ "$PATHS_EXIT" -ne 0 ]; then
  exit "$PATHS_EXIT"    # E004 — paths missing (BLOCKING)
elif [ "$CI_EXIT" -ne 0 ]; then
  exit "$CI_EXIT"       # E014 — CI fail (NON-BLOCKING, fallback)
fi
exit 0
