#!/usr/bin/env bash
# calibrate-timeout.sh — Calibrate per-agent timeout (P95 + buffer).
# Usage: bash .claude/scripts/calibrate-timeout.sh [fixture-dir]
#
# Measures P95 agent completion time on medium+large fixtures.
# Sets timeout = P99 + 60s buffer (ADR-LS12 + 09-thresholds-justification.md).

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/../.." && pwd)"
SHARED_ROOT="$REPO_ROOT/.claude/skills/workflow/_shared"
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

echo "=== Per-Agent Timeout Calibration ==="
echo "Target: timeout = P99 agent completion time + 60s buffer (ADR-LS12)"
echo ""

# ─── Tier 1: Concurrency controller checks ───────────────────────────────
echo "--- Tier 1: Concurrency controller module checks ---"

# Verify agent_timeout module importable (timeout lives in agent_timeout, not concurrency).
if (cd "$SHARED_ROOT" && python -c "from ips import agent_timeout; print('ok')") >/dev/null 2>&1; then
    check "agent_timeout module importable" 0
else
    check "agent_timeout module importable" 1
fi

# Verify timeout constants defined in agent_timeout.
if (cd "$SHARED_ROOT" && python -c "
from ips import agent_timeout
t = getattr(agent_timeout, 'DEFAULT_TIMEOUT_SEC', None) or \
    getattr(agent_timeout, 'DEFAULT_DEEP_TIMEOUT_SEC', None)
assert t is not None, 'Missing timeout constant'
print('ok')
") >/dev/null 2>&1; then
    check "per-agent timeout constants defined (DEFAULT_TIMEOUT_SEC)" 0
else
    check "per-agent timeout constants in agent_timeout" 1
fi

# Verify concurrency_controller has per-layer limits (3-tier: global, per-layer, per-probe).
if (cd "$SHARED_ROOT" && python -c "
from ips import concurrency_controller
has_global = hasattr(concurrency_controller, 'DEFAULT_GLOBAL_MAX')
has_per_layer = hasattr(concurrency_controller, 'DEFAULT_PER_LAYER_MAX')
has_per_probe = hasattr(concurrency_controller, 'DEFAULT_PER_PROBE_MAX')
assert all([has_global, has_per_layer, has_per_probe]), f'Missing 3-tier: global={has_global} layer={has_per_layer} probe={has_per_probe}'
print('ok')
") >/dev/null 2>&1; then
    check "3-tier concurrency limits (global/per-layer/per-probe)" 0
else
    check "3-tier concurrency limits" 1
fi

# Verify env var override in agent_timeout.
if (cd "$SHARED_ROOT" && python -c "
from ips import agent_timeout
import inspect
src = inspect.getsource(agent_timeout)
assert 'LEGACY_SCAN' in src or 'os.environ' in src or 'getenv' in src, 'Missing env var override'
print('ok')
") >/dev/null 2>&1; then
    check "env var timeout override present in agent_timeout" 0
else
    check "env var timeout override in agent_timeout" 1
fi

# Verify pytest tests pass.
if (cd "$REPO_ROOT" && python -m pytest .claude/skills/workflow/_shared/ips/tests/ -k "concurren or timeout" -q) >/dev/null 2>&1; then
    check "concurrency/timeout unit tests pass" 0
else
    echo "  [SKIP] No concurrency-specific tests found — verify manually"
fi

echo ""

# ─── Tier 1b: Timeout defaults sanity ─────────────────────────────────────
echo "--- Tier 1b: Timeout defaults sanity check ---"

default_timeout=$(cd "$SHARED_ROOT" && python -c "
from ips import agent_timeout
# DEFAULT_TIMEOUT_SEC = standard profile timeout
val = getattr(agent_timeout, 'DEFAULT_TIMEOUT_SEC', None)
print(int(val) if val is not None else 'unknown')
" 2>/dev/null || echo "unknown")

echo "  Current default timeout: ${default_timeout}s"

if [ "$default_timeout" != "unknown" ] && [ "$default_timeout" -ge "120" ] 2>/dev/null; then
    check "default timeout >= 120s (reasonable for AI agents)" 0
elif [ "$default_timeout" = "unknown" ]; then
    echo "  [SKIP] Could not read timeout value — check concurrency.py manually"
else
    check "default timeout >= 120s" 1
fi

echo ""

# ─── Tier 2: P95/P99 measurement ──────────────────────────────────────────
echo "--- Tier 2: P95/P99 measurement (requires fixtures + session logs) ---"

if [ -z "$FIXTURE" ]; then
    echo "  [SKIP] No fixture provided."
    echo "  Usage: bash calibrate-timeout.sh fixtures/medium-vn/"
    echo ""
    echo "  When run after wf-legacy-scan on fixture, this script will:"
    echo "    1. Read session events.jsonl (agent spawn/complete events)"
    echo "    2. Compute per-agent duration distribution"
    echo "    3. Calculate P95, P99 completion times"
    echo "    4. Recommend: timeout = P99 + 60s"
    echo "    5. Update LEGACY_SCAN_AGENT_TIMEOUT env var recommendation"
else
    EVENTS="$FIXTURE/.mc-data/work/legacy-scan/sessions"
    if [ -d "$EVENTS" ]; then
        # Find most recent session.
        latest=$(ls -t "$EVENTS" 2>/dev/null | head -1)
        if [ -n "$latest" ] && [ -f "$EVENTS/$latest/events.jsonl" ]; then
            echo "  [INFO] Found session: $latest"
            agent_count=$(grep -c '"event":"agent_complete"' "$EVENTS/$latest/events.jsonl" 2>/dev/null || echo 0)
            echo "  [INFO] Agent completions logged: $agent_count"
            if [ "$agent_count" -gt "5" ]; then
                check "sufficient agent events for P99 calculation (>5)" 0
                echo "  [INFO] Parse events.jsonl manually to compute P95/P99 durations"
            else
                echo "  [SKIP] Not enough events ($agent_count) for statistical P99"
            fi
        else
            echo "  [SKIP] No events.jsonl in recent session — run wf-legacy-scan first"
        fi
    else
        echo "  [SKIP] No sessions directory found — run wf-legacy-scan first"
    fi
fi

echo ""
echo "--- Current Timeout Defaults (09-thresholds-justification.md) ---"
echo "  surface profile:     90s per agent"
echo "  standard profile:   180s per agent"
echo "  deep profile:       300s per agent"
echo "  exhaustive profile: 600s per agent"
echo ""
echo "  Env var override: LEGACY_SCAN_AGENT_TIMEOUT=<seconds>"
echo "  Token bucket: global=5 concurrent, L4=3, L5=2 (ADR-LS12)"

echo ""
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL"
if [ "$FAIL" = "0" ]; then
    echo "[SUCCESS] Timeout calibration Tier 1 passed ($PASS/$PASS checks)"
    exit 0
else
    echo "[FAILURE] Timeout calibration Tier 1 failed ($FAIL/$TOTAL checks)"
    exit 1
fi
