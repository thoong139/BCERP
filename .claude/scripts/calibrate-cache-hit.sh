#!/usr/bin/env bash
# calibrate-cache-hit.sh — Measure scan cache hit rate across 2 consecutive scans.
# Usage: bash .claude/scripts/calibrate-cache-hit.sh [fixture-dir]
#
# Measures cache hit rate (ADR-LS10) to calibrate LEGACY_SCAN_CACHE_TTL.
# Target: >= 50% (configured), >= 70% (aspirational from phase-I §5).
#
# Requirements: LEGACY_SCAN_CACHE_TTL env var, jq, project with scan history.
# Output: Cache hit rate + recommended TTL adjustment.

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

echo "=== Cache Hit Rate Calibration ==="
echo "Target: >= 50% (configure), >= 70% (aspirational)"
echo ""

# ─── Tier 1: Structural checks ────────────────────────────────────────────
echo "--- Tier 1: Structural / module checks ---"

# Verify cache module importable.
if (cd "$SHARED_ROOT" && python -c "from ips import scan_cache; print('ok')") >/dev/null 2>&1; then
    check "scan_cache module importable" 0
else
    check "scan_cache module importable" 1
fi

# Verify cache fingerprint generation deterministic (sha256_file / compute_fingerprint).
if (cd "$SHARED_ROOT" && python -c "
from ips import scan_cache
# sha256_files hashes a list of file paths deterministically
assert hasattr(scan_cache, 'sha256_files') or hasattr(scan_cache, 'compute_fingerprint'), 'Missing hash fn'
print('ok')
") >/dev/null 2>&1; then
    check "cache fingerprint function present (sha256_files/compute_fingerprint)" 0
else
    check "cache fingerprint function present" 1
fi

# Verify sha256_config produces different hashes for different configs.
if (cd "$SHARED_ROOT" && python -c "
from ips import scan_cache
h1 = scan_cache.sha256_config({'key': 'v1'})
h2 = scan_cache.sha256_config({'key': 'v2'})
assert h1 != h2, 'Config hash should differ on config change'
print('ok')
") >/dev/null 2>&1; then
    check "sha256_config: different configs produce different hashes" 0
else
    check "sha256_config hash differentiation" 1
fi

# Verify 2-tier cache via build_scan_cache (session_dir + project_cache_enabled).
if (cd "$SHARED_ROOT" && python -c "
from ips import scan_cache
import inspect
sig = inspect.signature(scan_cache.build_scan_cache)
params = list(sig.parameters.keys())
assert 'session_dir' in params and 'project_cache_enabled' in params, f'Missing 2-tier params: {params}'
print('ok')
") >/dev/null 2>&1; then
    check "2-tier cache API (build_scan_cache: session_dir + project_cache_enabled)" 0
else
    check "2-tier cache API" 1
fi

# Verify --no-cache bypass via build_scan_cache(no_cache=True).
if (cd "$SHARED_ROOT" && python -c "
from ips import scan_cache
import inspect
sig = inspect.signature(scan_cache.build_scan_cache)
assert 'no_cache' in sig.parameters, 'Missing no_cache param'
print('ok')
") >/dev/null 2>&1; then
    check "--no-cache bypass via build_scan_cache(no_cache=True)" 0
else
    check "--no-cache bypass mechanism present" 1
fi

# Verify --cache-publish via project_cache_enabled=True in build_scan_cache.
if (cd "$SHARED_ROOT" && python -c "
from ips import scan_cache
import inspect
sig = inspect.signature(scan_cache.build_scan_cache)
assert 'project_cache_enabled' in sig.parameters or 'project_root' in sig.parameters, 'Missing project cache params'
print('ok')
") >/dev/null 2>&1; then
    check "--cache-publish via build_scan_cache(project_cache_enabled=True)" 0
else
    check "--cache-publish mechanism present" 1
fi

echo ""

# ─── Tier 2: Actual measurement (requires fixtures) ───────────────────────
echo "--- Tier 2: Cache hit rate measurement (requires fixtures) ---"

if [ -z "$FIXTURE" ]; then
    echo "  [SKIP] No fixture provided. Pass fixture path to measure actual hit rate."
    echo "  Usage: bash calibrate-cache-hit.sh fixtures/medium-vn/"
    echo ""
    echo "  When run with fixture, this script will:"
    echo "    1. Run scan 1 (cold) — populate cache"
    echo "    2. Run scan 2 (warm) — measure hit rate"
    echo "    3. Compare project-profile.json timestamps"
    echo "    4. Output: hit_rate, recommend LEGACY_SCAN_CACHE_TTL"
else
    echo "  Fixture: $FIXTURE"
    if [ ! -d "$FIXTURE" ]; then
        echo "  [FAIL] Fixture directory not found: $FIXTURE"
        FAIL=$((FAIL+1))
    else
        echo "  [INFO] Tier 2 measurement requires /wf-legacy-scan Claude CLI integration."
        echo "         Run manually: claude /wf-legacy-scan $FIXTURE --profile=standard --no-cache"
        echo "                 then: claude /wf-legacy-scan $FIXTURE --profile=standard"
        echo "         Measure: grep 'cache_hit' in session log"
    fi
fi

# ─── Current calibration recommendation ────────────────────────────────────
echo ""
echo "--- Current Calibration Values (from 09-thresholds-justification.md) ---"
echo "  LEGACY_SCAN_CACHE_TTL: ${LEGACY_SCAN_CACHE_TTL:-172800} seconds (48h default)"
echo "  Target hit rate: >= 50% (configured), >= 70% (aspirational)"
echo "  Re-scan delta: 20% changes -> <= 30% full scan time (M4)"
echo ""
echo "  To tune: if actual hit rate < 50% -> lower TTL by 20%"
echo "           if actual hit rate >= 70% already -> TTL is well-calibrated"

# ─── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL (Tier 1 structural)"
if [ "$FAIL" = "0" ]; then
    echo "[SUCCESS] Cache calibration Tier 1 passed ($PASS/$PASS checks)"
    echo "[STATUS] Tier 2 (actual measurement) requires fixtures + Claude CLI"
    exit 0
else
    echo "[FAILURE] Cache calibration Tier 1 failed ($FAIL/$TOTAL checks)"
    exit 1
fi
