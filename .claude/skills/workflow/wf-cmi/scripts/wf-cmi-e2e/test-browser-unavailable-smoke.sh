#!/usr/bin/env bash
# test-browser-unavailable-smoke.sh — G8.6 Browser Unavailable Smoke Test
#
# Mục đích: Validate Phase 9 PRE-GATE behavior khi Playwright MCP không khả dụng (E150 graceful degradation).
# Theo CORE-033 graceful degradation: Playwright DOWN → SKIP Phase 9-10 với E150 WARN, integrity-report.md ship bình thường.
#
# Deterministic simulator: KHÔNG cần Playwright thật. Mock các precondition kiểm tra qua functions.
#
# Usage: bash test-browser-unavailable-smoke.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
ASSERTIONS=()

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        ASSERTIONS+=("✓ $name: PASS (expected=$expected, actual=$actual)")
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        ASSERTIONS+=("✗ $name: FAIL (expected=$expected, actual=$actual)")
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Simulator: Phase 9 PRE-GATE T1-T4 check
# Input: exec_scenarios (true|false), playwright_available (true|false),
#        scenarios_manifest_exists (true|false), fe_running (true|false),
#        browser_lock_acquirable (true|false)
# Output: phase9_status (ACTIVE|SKIPPED) | error_code | warn_code | phase10_status
# ─────────────────────────────────────────────────────────────────────────────
phase9_pregate() {
    local exec_scenarios="$1"
    local playwright="$2"
    local manifest="$3"
    local fe="$4"
    local lock="$5"

    if [ "$exec_scenarios" != "true" ]; then
        echo "phase9_status=SKIPPED|error=|warn=|phase10_status=SKIPPED|integrity_report=SHIP_NORMAL|reason=no_exec_scenarios"
        return 0
    fi

    if [ "$playwright" != "true" ]; then
        echo "phase9_status=SKIPPED|error=|warn=E150|phase10_status=SKIPPED|integrity_report=SHIP_NORMAL|reason=playwright_unavailable"
        return 0
    fi

    if [ "$manifest" != "true" ]; then
        echo "phase9_status=SKIPPED|error=|warn=E150b|phase10_status=SKIPPED|integrity_report=SHIP_NORMAL|reason=no_scenarios_from_cd41"
        return 0
    fi

    if [ "$fe" != "true" ]; then
        echo "phase9_status=FAILED|error=E151|warn=|phase10_status=SKIPPED|integrity_report=SHIP_PARTIAL|reason=fe_not_running"
        return 0
    fi

    if [ "$lock" != "true" ]; then
        echo "phase9_status=BLOCKED|error=E152|warn=|phase10_status=SKIPPED|integrity_report=SHIP_PARTIAL|reason=browser_lock_held"
        return 0
    fi

    echo "phase9_status=ACTIVE|error=|warn=|phase10_status=PENDING|integrity_report=PENDING|reason=all_checks_pass"
}

# Helper: Extract field từ output string
extract() {
    local output="$1" field="$2"
    echo "$output" | tr '|' '\n' | grep "^${field}=" | head -1 | cut -d= -f2-
}

echo "=== G8.6 Browser Unavailable Smoke Test — Phase 9 PRE-GATE E150 Graceful Degradation ==="
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S1: Playwright MCP DOWN, --exec-scenarios=true, manifest exists, FE running, lock OK
# Expected: SKIP Phase 9-10 với E150 WARN, integrity-report ship bình thường
# ─────────────────────────────────────────────────────────────────────────────
echo "── S1: Playwright MCP DOWN (E150 graceful skip) ──"
S1=$(phase9_pregate true false true true true)
assert_eq "S1.phase9_status_skipped" "SKIPPED" "$(extract "$S1" phase9_status)"
assert_eq "S1.warn_code_e150" "E150" "$(extract "$S1" warn)"
assert_eq "S1.phase10_skipped" "SKIPPED" "$(extract "$S1" phase10_status)"
assert_eq "S1.integrity_report_ship_normal" "SHIP_NORMAL" "$(extract "$S1" integrity_report)"
assert_eq "S1.no_error_code" "" "$(extract "$S1" error)"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S2: --exec-scenarios=false (no flag set) — Phase 9-10 SKIP by design, KHÔNG warn E150
# Expected: SKIPPED with reason=no_exec_scenarios, NO E150 warn
# ─────────────────────────────────────────────────────────────────────────────
echo "── S2: --exec-scenarios=false (silent skip by design) ──"
S2=$(phase9_pregate false true true true true)
assert_eq "S2.phase9_status_skipped" "SKIPPED" "$(extract "$S2" phase9_status)"
assert_eq "S2.no_warn_e150" "" "$(extract "$S2" warn)"
assert_eq "S2.phase10_skipped" "SKIPPED" "$(extract "$S2" phase10_status)"
assert_eq "S2.integrity_report_normal" "SHIP_NORMAL" "$(extract "$S2" integrity_report)"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S3: --exec-scenarios=true + Playwright ON + scenarios-manifest EMPTY (CD41 SKIP profile=quick)
# Expected: SKIP Phase 9-10 với E150b "no scenarios from CD41"
# ─────────────────────────────────────────────────────────────────────────────
echo "── S3: scenarios-manifest empty (CD41 SKIP profile=quick) ──"
S3=$(phase9_pregate true true false true true)
assert_eq "S3.phase9_status_skipped" "SKIPPED" "$(extract "$S3" phase9_status)"
assert_eq "S3.warn_code_e150b" "E150b" "$(extract "$S3" warn)"
assert_eq "S3.phase10_skipped" "SKIPPED" "$(extract "$S3" phase10_status)"
assert_eq "S3.integrity_report_normal" "SHIP_NORMAL" "$(extract "$S3" integrity_report)"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S4: --exec-scenarios=true + Playwright ON + manifest OK + FE NOT running
# Expected: FAIL E151 (NOT graceful, blocks Phase 9), Phase 10 SKIP
# ─────────────────────────────────────────────────────────────────────────────
echo "── S4: FE not running (E151 error, not graceful) ──"
S4=$(phase9_pregate true true true false true)
assert_eq "S4.phase9_status_failed" "FAILED" "$(extract "$S4" phase9_status)"
assert_eq "S4.error_code_e151" "E151" "$(extract "$S4" error)"
assert_eq "S4.phase10_skipped" "SKIPPED" "$(extract "$S4" phase10_status)"
assert_eq "S4.integrity_report_partial" "SHIP_PARTIAL" "$(extract "$S4" integrity_report)"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S5: All preconditions PASS (positive control)
# Expected: Phase 9 ACTIVE, Phase 10 PENDING
# ─────────────────────────────────────────────────────────────────────────────
echo "── S5: All preconditions PASS (positive control) ──"
S5=$(phase9_pregate true true true true true)
assert_eq "S5.phase9_status_active" "ACTIVE" "$(extract "$S5" phase9_status)"
assert_eq "S5.no_error" "" "$(extract "$S5" error)"
assert_eq "S5.no_warn" "" "$(extract "$S5" warn)"
assert_eq "S5.phase10_pending" "PENDING" "$(extract "$S5" phase10_status)"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "=========================================="
echo "Results: $PASS_COUNT/$TOTAL PASS, $FAIL_COUNT/$TOTAL FAIL"
echo "=========================================="
echo ""
for ASSERT in "${ASSERTIONS[@]}"; do
    echo "  $ASSERT"
done

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
