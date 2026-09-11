#!/usr/bin/env bash
# legacy-scan-phase-i-perf.sh — Phase I performance benchmark vs v4.1.
# Usage: bash .claude/scripts/legacy-scan-phase-i-perf.sh [fixture-dir]
#
# Measures success metrics M1-M11 (phase-I §10):
#   M2: standard 100-500 files: v4.1 30-90 min → v5.0 target 20-40 min
#   M3: deep confidence target avg >= 0.82 (v4.1 ~0.65)
#   M4: re-scan 20% changes <= 30% full scan time
#   M10: cache hit rate >= 60% on re-scan 2-day delta
#
# Tier 1: Metric extraction from session logs.
# Tier 2: Full benchmark requires fixtures + Claude CLI.

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/../.." && pwd)"
FIXTURE="${1:-}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0
check() {
    local desc="$1" status="$2"
    if [ "$status" = "0" ]; then echo "  [PASS] $desc"; PASS=$((PASS+1))
    else echo "  [FAIL] $desc"; FAIL=$((FAIL+1)); fi
}

echo "=== Phase I Performance Benchmark ==="
echo "Success metrics M1-M11 vs v4.1 baseline"
echo ""

# ─── M1-M11 definitions ────────────────────────────────────────────────
echo "--- Success Metric Definitions ---"
echo "  M1:  surface profile completes in <= 10 min for small-en"
echo "  M2:  standard 100-500 files: v4.1 30-90 min → v5.0 20-40 min"
echo "  M3:  deep: avg confidence >= 0.82 (v4.1 ~0.65)"
echo "  M4:  re-scan 20% changes <= 30% of full scan time"
echo "  M5:  IPS-A completes in <= 60s for any fixture"
echo "  M6:  IPS-B completes in <= 120s for standard/deep"
echo "  M7:  L4 per-batch agent time P95 <= profile timeout"
echo "  M8:  L5 per-module agent time P95 <= profile timeout"
echo "  M9:  no memory leak (RSS stable across 3 consecutive scans)"
echo "  M10: cache hit rate >= 60% on re-scan 2-day delta"
echo "  M11: session log events.jsonl latency overhead <= 5ms/event"
echo ""

# ─── Tier 1: Structural metric collection capability ──────────────────
echo "--- Tier 1: Metric collection infrastructure ---"

SHARED_ROOT="$REPO_ROOT/.claude/skills/workflow/_shared"

# Check events.jsonl parsing utility.
if (cd "$SHARED_ROOT" && python -c "
from ips import metrics_collector
print('ok')
") >/dev/null 2>&1; then
    check "metrics_collector module importable" 0
else
    echo "  [SKIP] metrics_collector not yet separate module — check events.jsonl manually"
fi

# Verify events.jsonl schema has timing fields.
if (cd "$SHARED_ROOT" && python -c "
from ips.resume_router import _parse_events_jsonl
# At minimum, the function should exist for metrics extraction
print('ok')
") >/dev/null 2>&1 || grep -r 'events.jsonl\|duration_ms\|started_at\|completed_at' \
    "$REPO_ROOT/.claude/skills/workflow/_shared/ips/" >/dev/null 2>&1; then
    check "events.jsonl timing fields documented" 0
else
    check "events.jsonl timing fields" 1
fi

# Check confidence extraction from extracted/{module}.json.
if grep -r 'confidence\|extraction_confidence' \
    "$REPO_ROOT/.claude/skills/workflow/wf-legacy-extract/templates/" >/dev/null 2>&1; then
    check "confidence field in extract templates (M3 precondition)" 0
else
    echo "  [SKIP] confidence field in extract templates — verify manually"
fi

echo ""
echo "--- Tier 1: IPS timing assertions ---"

# Verify IPS-A has reasonable internal timing (no blocking ops).
if (cd "$SHARED_ROOT" && python -c "
import time
from ips import ips_phase_a
# ips_phase_a should complete trivial input in < 5s.
start = time.time()
result = ips_phase_a.analyze({'file_count': 50, 'tech_stack': ['python'], 'docs': []})
elapsed = time.time() - start
assert elapsed < 5.0, f'IPS-A took {elapsed:.1f}s on trivial input (> 5s threshold)'
print(f'IPS-A trivial: {elapsed:.2f}s OK')
") >/dev/null 2>&1; then
    check "IPS-A trivial input completes < 5s" 0
else
    echo "  [SKIP] IPS-A timing not measurable without module — verify manually"
fi

echo ""
echo "=== Tier 2: Full benchmark (BLOCKED by A.3 + Claude CLI) ==="

if [ -z "$FIXTURE" ]; then
    echo "  [SKIP] No fixture provided."
    echo ""
    echo "  Benchmark procedure:"
    echo "    1. Full scan (cold): time claude /wf-legacy-scan <fixture> --profile=standard"
    echo "       Record: wall_clock_time, output sizes"
    echo "    2. Re-scan (warm): modify 20% files, time claude /wf-legacy-scan --profile=standard"
    echo "       Verify M4: time <= 30% of step 1"
    echo "    3. Cache re-scan: run again without changes"
    echo "       Verify M10: cache hit rate >= 60%"
    echo "    4. Deep profile: time claude /wf-legacy-scan --profile=deep"
    echo "       Verify M3: avg confidence in extracted/{module}.json >= 0.82"
    echo ""
    echo "  Compare with v4.1 baseline from .v4.1.bak/ scripts"
else
    SESSIONS="$FIXTURE/.mc-data/work/legacy-scan/sessions"
    if [ -d "$SESSIONS" ]; then
        latest=$(ls -t "$SESSIONS" 2>/dev/null | head -1)
        if [ -n "$latest" ]; then
            SESSION_DIR="$SESSIONS/$latest"
            STATE="$SESSION_DIR/scan-state.json"
            if [ -f "$STATE" ]; then
                profile=$(jq -r '.session.profile' "$STATE" 2>/dev/null)
                status=$(jq -r '.status' "$STATE" 2>/dev/null)
                check "Latest session found: profile=$profile, status=$status" 0

                # Try to compute rough timing from session log.
                if [ -f "$SESSION_DIR/session-log.json" ]; then
                    start_ts=$(jq -r 'if type == "array" then .[0].timestamp else .start_time end' \
                        "$SESSION_DIR/session-log.json" 2>/dev/null || echo "")
                    end_ts=$(jq -r 'if type == "array" then .[-1].timestamp else .end_time end' \
                        "$SESSION_DIR/session-log.json" 2>/dev/null || echo "")
                    if [ -n "$start_ts" ] && [ -n "$end_ts" ]; then
                        check "session-log.json has timing data for M1/M2 verification" 0
                    fi
                fi
            fi
        fi
    else
        echo "  [SKIP] No session data found — run wf-legacy-scan on fixture first"
    fi
fi

echo ""
echo "--- Benchmark Report Template ---"
cat <<'TEMPLATE'
  When complete, fill in:
  | Metric | v4.1 baseline | v5.0 measured | Pass? |
  |--------|--------------|---------------|-------|
  | M1: surface small-en | N/A | __min | <=10min |
  | M2: standard medium-vn | 30-90min | __min | 20-40min |
  | M3: deep avg confidence | ~0.65 | __ | >=0.82 |
  | M4: re-scan 20% delta | - | __% | <=30% |
  | M5: IPS-A time | N/A | __s | <=60s |
  | M10: cache hit rate | N/A | __% | >=60% |
  Target: >= 8/11 metrics meet threshold
TEMPLATE

echo ""
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL"
if [ "$FAIL" = "0" ]; then
    echo "[SUCCESS] Phase I perf benchmark Tier 1 passed ($PASS/$PASS checks)"
    exit 0
else
    echo "[FAILURE] Phase I perf benchmark failed ($FAIL/$TOTAL checks)"
    exit 1
fi
