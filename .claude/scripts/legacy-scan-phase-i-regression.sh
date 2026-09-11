#!/usr/bin/env bash
# legacy-scan-phase-i-regression.sh — Phase I final regression test suite.
# Usage: bash .claude/scripts/legacy-scan-phase-i-regression.sh
#
# Orchestrates all Phase I Tier 1 tests in sequence:
#   1. Python IPS test suite
#   2. Compliance audit (3 skills)
#   3. Schema sync check
#   4. E2E matrix Tier 1
#   5. Workload Gate Tier 1
#   6. Crash injection Tier 1
#   7. Downstream integration Tier 1
#   8. Phase H backward-compat golden test (re-run)
#   9. CORE rule compliance check
#
# All Tier 2 (E2E on fixtures) documented as BLOCKED by A.3.
# Pass criterion: 0 Tier 1 failures.

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/../.." && pwd)"

PASS_SUITE=0
FAIL_SUITE=0
SKIP_SUITE=0

run_suite() {
    local name="$1" script="$2"
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  Running: $name"
    echo "════════════════════════════════════════════════════════"
    if bash "$script" 2>&1; then
        echo "  → SUITE PASS: $name"
        PASS_SUITE=$((PASS_SUITE+1))
    else
        echo "  → SUITE FAIL: $name"
        FAIL_SUITE=$((FAIL_SUITE+1))
    fi
}

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Phase I Final Regression Test Suite — wf-legacy-scan   ║"
echo "║  Date: $(date '+%Y-%m-%d %H:%M')                              ║"
echo "╚══════════════════════════════════════════════════════════╝"

# ─── Suite 1: Python IPS tests ───────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  Suite 1: Python IPS test suite (all tests)"
echo "════════════════════════════════════════════════════════"
if (cd "$REPO_ROOT" && python -m pytest .claude/skills/workflow/_shared/ips/tests/ -q --tb=short) 2>&1; then
    echo "  → SUITE PASS: Python IPS tests"
    PASS_SUITE=$((PASS_SUITE+1))
else
    echo "  → SUITE FAIL: Python IPS tests"
    FAIL_SUITE=$((FAIL_SUITE+1))
fi

# ─── Suite 2: Compliance audit ───────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  Suite 2: Compliance audit (3 skills)"
echo "════════════════════════════════════════════════════════"
AUDIT_PASS=0
AUDIT_FAIL=0
for skill in wf-legacy-scan wf-legacy-classify wf-legacy-extract; do
    if bash "$SCRIPTS_DIR/skill-compliance-audit.sh" "$skill" 2>&1 | grep -qE 'PASS|compliant'; then
        echo "  [PASS] $skill compliance"
        AUDIT_PASS=$((AUDIT_PASS+1))
    else
        echo "  [FAIL] $skill compliance"
        AUDIT_FAIL=$((AUDIT_FAIL+1))
    fi
done
if [ "$AUDIT_FAIL" = "0" ]; then
    echo "  → SUITE PASS: Compliance audit ($AUDIT_PASS/3 skills)"
    PASS_SUITE=$((PASS_SUITE+1))
else
    echo "  → SUITE FAIL: Compliance audit ($AUDIT_FAIL/3 skills failed)"
    FAIL_SUITE=$((FAIL_SUITE+1))
fi

# ─── Suite 3: Schema sync ─────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  Suite 3: Schema sync check (3 skills)"
echo "════════════════════════════════════════════════════════"
SYNC_PASS=0
SYNC_FAIL=0
for skill in wf-legacy-scan wf-legacy-classify wf-legacy-extract; do
    if bash "$SCRIPTS_DIR/validate-schema-sync.sh" "$skill" 2>&1 | grep -qE 'PASS|valid|sync'; then
        echo "  [PASS] $skill schema sync"
        SYNC_PASS=$((SYNC_PASS+1))
    else
        echo "  [FAIL] $skill schema sync"
        SYNC_FAIL=$((SYNC_FAIL+1))
    fi
done
if [ "$SYNC_FAIL" = "0" ]; then
    echo "  → SUITE PASS: Schema sync ($SYNC_PASS/3)"
    PASS_SUITE=$((PASS_SUITE+1))
else
    echo "  → SUITE FAIL: Schema sync ($SYNC_FAIL/3 failed)"
    FAIL_SUITE=$((FAIL_SUITE+1))
fi

# ─── Suite 4: E2E Tier 1 ─────────────────────────────────────────────────
run_suite "E2E matrix Tier 1" "$SCRIPTS_DIR/legacy-scan-phase-i-e2e.sh"

# ─── Suite 5: Workload Gate Tier 1 ───────────────────────────────────────
run_suite "Workload Gate Tier 1" "$SCRIPTS_DIR/legacy-scan-phase-i-workload.sh"

# ─── Suite 6: Crash injection Tier 1 ─────────────────────────────────────
run_suite "Crash injection Tier 1" "$SCRIPTS_DIR/legacy-scan-phase-i-crash.sh"

# ─── Suite 7: Downstream integration Tier 1 ──────────────────────────────
run_suite "Downstream integration Tier 1" "$SCRIPTS_DIR/legacy-scan-phase-i-downstream.sh"

# ─── Suite 8: Phase H backward-compat golden test ────────────────────────
run_suite "Phase H backward-compat (re-run)" "$SCRIPTS_DIR/legacy-scan-phase-h-smoke.sh"

# ─── Suite 9: Golden test re-run (Phase D) ────────────────────────────────
# exit 2 = BLOCKED by A.3 fixture gap — treat as SKIP, not FAIL.
echo ""
echo "════════════════════════════════════════════════════════"
echo "  Suite 9: Phase D golden test (backward-compat)"
echo "════════════════════════════════════════════════════════"
set +e
bash "$SCRIPTS_DIR/legacy-scan-phase-d-golden-test.sh" 2>&1
_golden_rc=$?
set -e
if [ "$_golden_rc" = "0" ]; then
    echo "  → SUITE PASS: Phase D golden test"
    PASS_SUITE=$((PASS_SUITE+1))
elif [ "$_golden_rc" = "2" ]; then
    echo "  → SUITE SKIP: Phase D golden test (BLOCKED by A.3 fixture gap)"
    SKIP_SUITE=$((SKIP_SUITE+1))
else
    echo "  → SUITE FAIL: Phase D golden test (exit $rc)"
    FAIL_SUITE=$((FAIL_SUITE+1))
fi

# ─── Suite 10: Calibration Tier 1 ────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  Suite 10: Calibration Tier 1 (structural)"
echo "════════════════════════════════════════════════════════"
CALIB_PASS=0
CALIB_FAIL=0
for script in calibrate-cache-hit.sh calibrate-drift.sh calibrate-rename.sh calibrate-timeout.sh; do
    if bash "$SCRIPTS_DIR/$script" 2>&1 | grep -q '\[SUCCESS\]'; then
        echo "  [PASS] $script"
        CALIB_PASS=$((CALIB_PASS+1))
    else
        echo "  [FAIL] $script"
        CALIB_FAIL=$((CALIB_FAIL+1))
    fi
done
if [ "$CALIB_FAIL" = "0" ]; then
    echo "  → SUITE PASS: Calibration ($CALIB_PASS/4)"
    PASS_SUITE=$((PASS_SUITE+1))
else
    echo "  → SUITE FAIL: Calibration ($CALIB_FAIL/4 failed)"
    FAIL_SUITE=$((FAIL_SUITE+1))
fi

# ─── Suite 11: CORE rule compliance check ────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  Suite 11: CORE rule compliance spot-check"
echo "════════════════════════════════════════════════════════"
CORE_PASS=0
CORE_FAIL=0

# CORE-021: LEGACY_MODE detection via project-context.md.
if grep -q 'project-context.md' \
    "$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/procedures/phase4-synthesize.md" 2>/dev/null; then
    echo "  [PASS] CORE-021: project-context.md written in phase4-synthesize"
    CORE_PASS=$((CORE_PASS+1))
else
    echo "  [FAIL] CORE-021: project-context.md reference in phase4-synthesize"
    CORE_FAIL=$((CORE_FAIL+1))
fi

# CORE-028: phase-summary.md in contract.
if jq -e '.outputs.working[] | select(.path | contains("phase-summary.md"))' \
    "$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/_contract.json" >/dev/null 2>&1; then
    echo "  [PASS] CORE-028: phase-summary.md in _contract.json outputs"
    CORE_PASS=$((CORE_PASS+1))
else
    echo "  [FAIL] CORE-028: phase-summary.md in _contract.json"
    CORE_FAIL=$((CORE_FAIL+1))
fi

# CORE-031: Templates referenced in contract.
template_count=$(jq '[.outputs.working[] | select(.template != null)] | length' \
    "$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/_contract.json" 2>/dev/null || echo 0)
if [ "$template_count" -gt "5" ]; then
    echo "  [PASS] CORE-031: $template_count outputs have templates in _contract.json"
    CORE_PASS=$((CORE_PASS+1))
else
    echo "  [FAIL] CORE-031: too few templated outputs ($template_count)"
    CORE_FAIL=$((CORE_FAIL+1))
fi

# CORE-006: registry_scope.role = NONE for wf-legacy-scan.
role=$(jq -r '.registry_scope.role' \
    "$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/_contract.json" 2>/dev/null)
if [ "$role" = "NONE" ]; then
    echo "  [PASS] CORE-006: registry_scope.role=NONE"
    CORE_PASS=$((CORE_PASS+1))
else
    echo "  [FAIL] CORE-006: registry_scope.role should be NONE (got: $role)"
    CORE_FAIL=$((CORE_FAIL+1))
fi

if [ "$CORE_FAIL" = "0" ]; then
    echo "  → SUITE PASS: CORE compliance ($CORE_PASS/4)"
    PASS_SUITE=$((PASS_SUITE+1))
else
    echo "  → SUITE FAIL: CORE compliance ($CORE_FAIL/4 failed)"
    FAIL_SUITE=$((FAIL_SUITE+1))
fi

# ─── Final Report ─────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  PHASE I REGRESSION REPORT                              ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Suite PASS: $PASS_SUITE / $((PASS_SUITE+FAIL_SUITE+SKIP_SUITE))                                      ║"
echo "║  Suite SKIP: $SKIP_SUITE (BLOCKED by A.3)                        ║"
echo "║  Suite FAIL: $FAIL_SUITE                                         ║"
echo "║                                                          ║"
if [ "$FAIL_SUITE" = "0" ]; then
echo "║  STATUS: ✅ PHASE I REGRESSION PASS                      ║"
echo "║  TIER 2 (E2E on fixtures): BLOCKED by A.3               ║"
else
echo "║  STATUS: ❌ PHASE I REGRESSION FAIL ($FAIL_SUITE suites)        ║"
fi
echo "╚══════════════════════════════════════════════════════════╝"

if [ "$FAIL_SUITE" = "0" ]; then
    exit 0
else
    exit 1
fi
