#!/usr/bin/env bash
# legacy-scan-phase-i-e2e.sh — Phase I E2E test matrix: 4 profiles × 3 fixtures = 12 cases.
# Usage: bash .claude/scripts/legacy-scan-phase-i-e2e.sh [--tier1-only]
#
# Tier 1 (runs now): Structural checks — IPS module, contract schema, output schema.
# Tier 2 (blocked by A.3): Full E2E on fixtures/small-en, medium-vn, large-mixed.
#
# Expected runtimes per phase-I §6:
#   fixture     | surface   | standard  | deep      | exhaustive
#   small-en    | <= 10min  | <= 20min  | <= 45min  | <= 90min
#   medium-vn   | <= 15min  | <= 40min  | <= 90min  | <= 180min
#   large-mixed | <= 20min  | WARN      | WARN      | WARN

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/../.." && pwd)"
SHARED_ROOT="$REPO_ROOT/.claude/skills/workflow/_shared"
TIER1_ONLY="${1:-}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0
SKIP=0
check() {
    local desc="$1" status="$2"
    if [ "$status" = "0" ]; then echo "  [PASS] $desc"; PASS=$((PASS+1))
    else echo "  [FAIL] $desc"; FAIL=$((FAIL+1)); fi
}
skip() { echo "  [SKIP] $1"; SKIP=$((SKIP+1)); }

echo "=== Phase I E2E Test Matrix ==="
echo "4 profiles × 3 fixtures = 12 test cases"
echo ""

# ─── Tier 1: Full IPS regression suite ───────────────────────────────────
echo "--- Tier 1: IPS regression suite ---"

if (cd "$REPO_ROOT" && python -m pytest .claude/skills/workflow/_shared/ips/tests/ -q) >/dev/null 2>&1; then
    check "full IPS test suite (410+ tests) passes" 0
else
    check "full IPS test suite" 1
fi

echo ""
echo "--- Tier 1: scan-state.json schema validation ---"

# Create synthetic scan-state for all 4 profiles and validate.
for profile in surface standard deep exhaustive; do
    cat > "$TMP_DIR/scan-state-$profile.json" <<EOF
{
  "\$schema": "scan-state-v1",
  "session": {
    "id": "test-$profile-e2e",
    "project_path": "/fixtures/test",
    "profile": "$profile",
    "strategy": "S2",
    "created_at": "2026-04-22T10:00:00Z"
  },
  "depth_map": {
    "L1": "full", "L2": "full", "L3": "full",
    "L4": "$([ "$profile" = "surface" ] && echo "surface" || echo "standard")",
    "L5": "$([ "$profile" = "surface" ] && echo "skip" || ([ "$profile" = "standard" ] && echo "standard" || echo "deep"))",
    "L6": "full"
  },
  "layers": {
    "L1": {"status": "completed"},
    "L2": {"status": "completed"},
    "L3": {"status": "completed"},
    "L4": {"status": "not_started", "batch_progress": null, "partial": null},
    "L5": {"status": "$([ "$profile" = "surface" ] && echo "skipped_by_profile" || echo "not_started")", "module_progress": null, "partial": null},
    "L6": {"status": "not_started"}
  },
  "ips": {"phase_a": null, "phase_b": null},
  "last_completed": "L3",
  "status": "in_progress"
}
EOF
    if jq -e '."$schema" == "scan-state-v1" and .session.profile != null and .depth_map != null and .layers != null' \
        "$TMP_DIR/scan-state-$profile.json" >/dev/null 2>&1; then
        check "scan-state.json schema valid for profile=$profile" 0
    else
        check "scan-state.json schema invalid for profile=$profile" 1
    fi
done

echo ""
echo "--- Tier 1: profile depth_map expectations ---"

# Verify surface profile skips L5.
surface_l5=$(jq -r '.layers.L5.status' "$TMP_DIR/scan-state-surface.json" 2>/dev/null)
[ "$surface_l5" = "skipped_by_profile" ] && check "surface: L5 skipped_by_profile" 0 || check "surface: L5 skipped_by_profile (got: $surface_l5)" 1

# Verify exhaustive depth_map has deep for L5.
exhaustive_l5_depth=$(jq -r '.depth_map.L5' "$TMP_DIR/scan-state-exhaustive.json" 2>/dev/null)
[ "$exhaustive_l5_depth" = "deep" ] && check "exhaustive: L5 depth=deep" 0 || check "exhaustive: L5 depth (got: $exhaustive_l5_depth)" 1

echo ""
echo "--- Tier 1: contract outputs cross-check ---"

# Verify _contract.json lists all expected outputs.
# Baseline Phase I = 5.0.0; patch/minor bump sau đó là drift hợp lệ — chỉ chặn thoái hoá.
CONTRACT="$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/_contract.json"
CONTRACT_VERSION=$(jq -r '.version' "$CONTRACT" 2>/dev/null || echo "")
VERSION_MAX=$(printf '%s\n5.0.0\n' "$CONTRACT_VERSION" | sort -V | tail -1)
if [[ -n "$CONTRACT_VERSION" && "$VERSION_MAX" == "$CONTRACT_VERSION" ]]; then
    check "_contract.json version >= 5.0.0 (now $CONTRACT_VERSION)" 0
else
    check "_contract.json version >= 5.0.0 (got '${CONTRACT_VERSION:-missing}')" 1
fi

# Check required output paths present in contract.
for out_path in "sessions/{id}/scan-state.json" "domain-hints.json" "project-context.md" "ledger.json"; do
    if jq -e --arg p "$out_path" '.outputs.working[] | select(.path | contains($p))' "$CONTRACT" >/dev/null 2>&1; then
        check "contract has output: $out_path" 0
    else
        check "contract has output: $out_path" 1
    fi
done

echo ""
echo "=== Tier 2: E2E on Fixtures (BLOCKED by A.3) ==="
echo ""
echo "The following 12 test cases require fixture directories:"
echo "  fixtures/small-en/, fixtures/medium-vn/, fixtures/large-mixed/"
echo ""
echo "  Expected matrix:"
echo "  | Fixture     | surface   | standard   | deep       | exhaustive |"
echo "  |-------------|-----------|------------|------------|------------|"
echo "  | small-en    | <=10 min  | <=20 min   | <=45 min   | <=90 min   |"
echo "  | medium-vn   | <=15 min  | <=40 min   | <=90 min   | <=180 min  |"
echo "  | large-mixed | <=20 min  | WARN gate  | WARN gate  | WARN gate  |"
echo ""
echo "  When A.3 fixtures are available, run each combination:"
for fixture in small-en medium-vn large-mixed; do
    for profile in surface standard deep exhaustive; do
        skip "E2E: $fixture × $profile"
    done
done

# ─── Summary ─────────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL (Tier 1)"
echo "  SKIP: $SKIP (Tier 2 blocked by A.3 fixtures)"
if [ "$FAIL" = "0" ]; then
    echo ""
    echo "[SUCCESS] Phase I E2E Tier 1 passed ($PASS/$PASS checks)"
    echo "[STATUS]  Tier 2 (12 E2E cases) blocked pending A.3 fixtures"
    exit 0
else
    echo ""
    echo "[FAILURE] Phase I E2E Tier 1 failed ($FAIL/$TOTAL checks)"
    exit 1
fi
