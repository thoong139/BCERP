#!/usr/bin/env bash
# IMP-006 acceptance test: Auth-aware api-smoke probe
#
# Tests that wf-fix-probe-static-api-smoke.sh:
#   1. Reads auth credentials from auth.json (bearer_token, api_key)
#   2. Without --base-url: emits SPEC-ONLY-PROBE-SKIP + route info signals
#   3. Detects API routes from source code (GET /api/users, POST /api/users, GET /api/profile)
#   4. Emits correct signal count (≥ routes detected)
#
# Note: Live server test not required in fixture (no running server).
#       The probe must correctly handle no-server case without crashing,
#       and must read and acknowledge auth config.
#
# PASS criteria:
#   - Probe exits 0 (no crash)
#   - ≥1 SPEC-ONLY-PROBE-SKIP signal present (no base-url mode)
#   - ≥1 route-detected signal present (api-routes.ts has GET /api/users etc.)
#   - Auth file read test: probe with --auth-file loads credentials
#
# USAGE: bash run.sh [--dry-run]

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${1:-}"

echo "[run.sh] IMP-006 — Auth-aware api-smoke fixture"
echo "[run.sh] FIXTURE_DIR=$FIXTURE_DIR"

# Locate probe script
PROBE_SCRIPT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/scripts/wf-fix-probe-static-api-smoke.sh" ]; then
  PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-api-smoke.sh"
fi
for candidate in \
  "../../../../../.claude/scripts/wf-fix-probe-static-api-smoke.sh" \
  "../../../../../../.claude/scripts/wf-fix-probe-static-api-smoke.sh"; do
  if [ -z "$PROBE_SCRIPT" ] && [ -f "$FIXTURE_DIR/$candidate" ]; then
    PROBE_SCRIPT="$(cd "$FIXTURE_DIR/$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    break
  fi
done

if [ -z "$PROBE_SCRIPT" ] || [ ! -f "$PROBE_SCRIPT" ]; then
  echo "ERROR: cannot locate wf-fix-probe-static-api-smoke.sh" >&2; exit 1
fi
echo "[run.sh] PROBE_SCRIPT=$PROBE_SCRIPT"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "[run.sh] --dry-run: preflight PASS"
  exit 0
fi

SESSION_DIR="$(mktemp -d -t imp006-fixture-XXXXXX)"
ACTUAL="$FIXTURE_DIR/.actual-api-smoke.json"
trap 'rm -rf "$SESSION_DIR"' EXIT

PASS=true

# ============================================================
# Test 1: No --base-url → SPEC-ONLY-PROBE-SKIP + route signals
# ============================================================
echo ""
echo "[run.sh] Test 1: no --base-url → SPEC-ONLY-PROBE-SKIP"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-api-smoke" \
  --profile "standard" \
  --source-dir "$FIXTURE_DIR" \
  --auth-file "$FIXTURE_DIR/auth.json" \
  > "$ACTUAL"

TOTAL_SIGNALS=$(jq '.signals | length' "$ACTUAL")
SKIP_COUNT=$(jq '[.signals[] | select(.title | contains("SPEC-ONLY-PROBE-SKIP"))] | length' "$ACTUAL")
ROUTE_SIGNALS=$(jq '[.signals[] | select(.title | contains("API route detected"))] | length' "$ACTUAL")

echo "[run.sh]   total signals: $TOTAL_SIGNALS, SPEC-ONLY-PROBE-SKIP: $SKIP_COUNT, route signals: $ROUTE_SIGNALS"
jq -r '.signals[] | "  [" + .severity + "] " + .title' "$ACTUAL" 2>/dev/null || true

if [ "$SKIP_COUNT" -lt 1 ]; then
  echo "  FAIL: expected SPEC-ONLY-PROBE-SKIP signal (no base-url mode)" >&2; PASS=false
else
  echo "  PASS: SPEC-ONLY-PROBE-SKIP emitted correctly"
fi

if [ "$ROUTE_SIGNALS" -lt 1 ]; then
  echo "  FAIL: expected ≥1 route-detected signal (api-routes.ts has GET /api/users)" >&2; PASS=false
else
  echo "  PASS: $ROUTE_SIGNALS route-detected signal(s) found"
fi

# ============================================================
# Test 2: Auth scheme validation — probe reads auth.json without crash
# ============================================================
echo ""
echo "[run.sh] Test 2: auth scheme bearer — reads credentials from --auth-file"
ACTUAL2="$FIXTURE_DIR/.actual-auth-bearer.json"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-api-smoke" \
  --profile "standard" \
  --source-dir "$FIXTURE_DIR" \
  --auth-scheme "bearer" \
  --auth-file "$FIXTURE_DIR/auth.json" \
  > "$ACTUAL2"

SKIP2=$(jq '[.signals[] | select(.title | contains("SPEC-ONLY-PROBE-SKIP"))] | length' "$ACTUAL2")
# SPEC-ONLY-PROBE-SKIP description should mention "credentials loaded"
CREDS_LOADED=$(jq -r '[.signals[] | select(.title | contains("SPEC-ONLY-PROBE-SKIP")) | .description] | any(contains("credentials loaded"))' "$ACTUAL2" 2>/dev/null || echo "false")

echo "[run.sh]   SPEC-ONLY-PROBE-SKIP: $SKIP2, description mentions 'credentials loaded': $CREDS_LOADED"

if [ "$SKIP2" -lt 1 ]; then
  echo "  FAIL: expected SPEC-ONLY-PROBE-SKIP with auth-file" >&2; PASS=false
else
  echo "  PASS: probe exits cleanly with bearer auth-file"
fi
if [ "$CREDS_LOADED" != "true" ]; then
  echo "  FAIL: SPEC-ONLY-PROBE-SKIP description should mention credentials loaded" >&2; PASS=false
else
  echo "  PASS: credentials loaded acknowledgement in signal description"
fi

# ============================================================
# Test 3: apikey scheme — reads api_key from auth.json
# ============================================================
echo ""
echo "[run.sh] Test 3: auth scheme apikey"
ACTUAL3="$FIXTURE_DIR/.actual-auth-apikey.json"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-api-smoke" \
  --profile "standard" \
  --source-dir "$FIXTURE_DIR" \
  --auth-scheme "apikey" \
  --auth-file "$FIXTURE_DIR/auth.json" \
  > "$ACTUAL3"

SKIP3=$(jq '[.signals[] | select(.title | contains("SPEC-ONLY-PROBE-SKIP"))] | length' "$ACTUAL3")
echo "[run.sh]   SPEC-ONLY-PROBE-SKIP: $SKIP3"
if [ "$SKIP3" -lt 1 ]; then
  echo "  FAIL: apikey scheme should also emit SPEC-ONLY-PROBE-SKIP without base-url" >&2; PASS=false
else
  echo "  PASS: apikey scheme probe exits cleanly"
fi

echo ""
if $PASS; then
  echo "  VERDICT: PASS — IMP-006 acceptance criteria met (auth-aware api-smoke)"
  exit 0
else
  echo "  VERDICT: FAIL — one or more checks failed"
  exit 1
fi
