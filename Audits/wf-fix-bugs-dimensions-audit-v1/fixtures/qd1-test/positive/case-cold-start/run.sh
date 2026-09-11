#!/usr/bin/env bash
# IMP-007 acceptance test: Retry logic for infra-preflight
#
# Tests that wf-fix-probe-static-infra-preflight.sh:
#   1. Without --health-url: emits SPEC-ONLY-PROBE-SKIP with retry config in description
#   2. Retry defaults load from profiles.json (IMP-004 integration)
#   3. With --threshold-overrides: retry count/interval changes
#   4. With unreachable URL: emits CRITICAL (not premature abort after first failure)
#   5. Configurable: --infra-retry-count 1 reduces retries
#
# PASS criteria:
#   - No-health-url: SPEC-ONLY-PROBE-SKIP with "count=3" in description (standard profile)
#   - threshold-overrides count=1: SPEC-ONLY-PROBE-SKIP with "count=1" in description
#   - Unreachable URL (port 19999): CRITICAL signal emitted (not medium/high)
#   - Explicit --infra-retry-count 1: probe exits in < 30s (not blocked by 3×5s retries)
#
# USAGE: bash run.sh [--dry-run]

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${1:-}"

echo "[run.sh] IMP-007 — Infra preflight retry logic fixture"
echo "[run.sh] FIXTURE_DIR=$FIXTURE_DIR"

# Locate probe script
PROBE_SCRIPT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/scripts/wf-fix-probe-static-infra-preflight.sh" ]; then
  PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-infra-preflight.sh"
fi
for candidate in \
  "../../../../../.claude/scripts/wf-fix-probe-static-infra-preflight.sh" \
  "../../../../../../.claude/scripts/wf-fix-probe-static-infra-preflight.sh"; do
  if [ -z "$PROBE_SCRIPT" ] && [ -f "$FIXTURE_DIR/$candidate" ]; then
    PROBE_SCRIPT="$(cd "$FIXTURE_DIR/$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    break
  fi
done

if [ -z "$PROBE_SCRIPT" ] || [ ! -f "$PROBE_SCRIPT" ]; then
  echo "ERROR: cannot locate wf-fix-probe-static-infra-preflight.sh" >&2; exit 1
fi
echo "[run.sh] PROBE_SCRIPT=$PROBE_SCRIPT"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "[run.sh] --dry-run: preflight PASS"
  exit 0
fi

SESSION_DIR="$(mktemp -d -t imp007-fixture-XXXXXX)"
trap 'rm -rf "$SESSION_DIR"' EXIT

PASS=true

# ============================================================
# Test 1: no --health-url → SPEC-ONLY-PROBE-SKIP
#         description must mention retry config from profiles.json (IMP-004)
# ============================================================
echo ""
echo "[run.sh] Test 1: no --health-url → SPEC-ONLY-PROBE-SKIP with retry config"
OUT1="$FIXTURE_DIR/.actual-skip.json"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-infra-preflight" \
  --profile "standard" \
  > "$OUT1"

SKIP1=$(jq '[.signals[] | select(.title | contains("SPEC-ONLY-PROBE-SKIP"))] | length' "$OUT1")
HAS_COUNT=$(jq -r '[.signals[] | select(.title | contains("SPEC-ONLY-PROBE-SKIP")) | .description] | any(contains("count=3"))' "$OUT1" 2>/dev/null || echo "false")
echo "[run.sh]   SPEC-ONLY-PROBE-SKIP: $SKIP1, has 'count=3': $HAS_COUNT"

if [ "$SKIP1" -lt 1 ]; then
  echo "  FAIL: expected SPEC-ONLY-PROBE-SKIP signal (no health-url)" >&2; PASS=false
else
  echo "  PASS: SPEC-ONLY-PROBE-SKIP emitted"
fi
if [ "$HAS_COUNT" != "true" ]; then
  echo "  FAIL: SPEC-ONLY-PROBE-SKIP description should mention retry count=3 (from profiles.json)" >&2; PASS=false
else
  echo "  PASS: retry config in signal description (IMP-004 integration)"
fi

# ============================================================
# Test 2: --threshold-overrides count=1 → description shows count=1
# ============================================================
echo ""
echo "[run.sh] Test 2: --threshold-overrides '{\"infra_retry_count\":1}' → count=1 in description"
OUT2="$FIXTURE_DIR/.actual-override.json"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-infra-preflight" \
  --profile "standard" \
  --threshold-overrides '{"infra_retry_count":1}' \
  > "$OUT2"

HAS_COUNT1=$(jq -r '[.signals[] | select(.title | contains("SPEC-ONLY-PROBE-SKIP")) | .description] | any(contains("count=1"))' "$OUT2" 2>/dev/null || echo "false")
echo "[run.sh]   description mentions 'count=1': $HAS_COUNT1"

if [ "$HAS_COUNT1" != "true" ]; then
  echo "  FAIL: threshold-overrides infra_retry_count=1 not reflected in description" >&2; PASS=false
else
  echo "  PASS: threshold-overrides applied to retry count"
fi

# ============================================================
# Test 3: unreachable URL + --infra-retry-count 1 → CRITICAL in ≤15s
#         (port 19999 is almost certainly unused; probe should fail fast with count=1)
# ============================================================
echo ""
echo "[run.sh] Test 3: unreachable URL + --infra-retry-count 1 → CRITICAL signal"
OUT3="$FIXTURE_DIR/.actual-unreachable.json"
START_TS=$SECONDS
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-functional" \
  --probe "P-QD1-infra-preflight" \
  --profile "standard" \
  --health-url "http://127.0.0.1:19999/health" \
  --infra-retry-count 1 \
  --infra-retry-interval 1 \
  --timeout-sec 3 \
  > "$OUT3"
ELAPSED=$(( SECONDS - START_TS ))

CRIT_COUNT=$(jq '[.signals[] | select(.severity == "critical")] | length' "$OUT3")
echo "[run.sh]   CRITICAL signals: $CRIT_COUNT, elapsed: ${ELAPSED}s"

if [ "$CRIT_COUNT" -lt 1 ]; then
  echo "  FAIL: expected CRITICAL signal for unreachable URL" >&2; PASS=false
else
  echo "  PASS: CRITICAL signal emitted for unreachable URL"
fi
if [ "$ELAPSED" -gt 20 ]; then
  echo "  FAIL: probe took ${ELAPSED}s (> 20s) with retry-count=1, interval=1s — retry not respected" >&2; PASS=false
else
  echo "  PASS: probe completed in ${ELAPSED}s (fast fail with retry-count=1)"
fi

echo ""
if $PASS; then
  echo "  VERDICT: PASS — IMP-007 acceptance criteria met (infra-preflight retry logic)"
  exit 0
else
  echo "  VERDICT: FAIL — one or more checks failed"
  exit 1
fi
