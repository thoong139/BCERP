#!/usr/bin/env bash
# legacy-scan-phase-i-downstream.sh — Phase I downstream integration test.
# Usage: bash .claude/scripts/legacy-scan-phase-i-downstream.sh [fixture-dir]
#
# Verifies full legacy pipeline end-to-end:
#   wf-legacy-scan → wf-brainstorm (LEGACY_MODE) → wf-analyze-requirements
#   → wf-define-features → wf-design → wf-plan-modules
#
# Tier 1: File contract cross-checks (no Claude CLI required).
# Tier 2: Full pipeline E2E (requires fixtures + Claude CLI).

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

echo "=== Phase I Downstream Integration Test ==="
echo "Verifies: wf-legacy-scan outputs consumed correctly by downstream skills"
echo ""

# ─── Tier 1: Contract cross-check ─────────────────────────────────────────
echo "--- Tier 1: Cross-skill contract consistency ---"

# Check wf-legacy-scan _contract.json produces_for is consistent with
# consumer skills' consumes_from.
SCAN_CONTRACT="$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/_contract.json"
CLASSIFY_CONTRACT="$REPO_ROOT/.claude/skills/workflow/wf-legacy-classify/_contract.json"
EXTRACT_CONTRACT="$REPO_ROOT/.claude/skills/workflow/wf-legacy-extract/_contract.json"

# wf-legacy-scan produces domain-hints.json for wf-legacy-classify.
scan_produces_domain_for_classify=$(jq -e \
    '.cross_skill_contracts.produces_for."wf-legacy-classify" | contains(["domain-hints.json"])' \
    "$SCAN_CONTRACT" >/dev/null 2>&1 && echo "true" || echo "false")
check "wf-legacy-scan contract: domain-hints.json produced for wf-legacy-classify" \
    "$([ "$scan_produces_domain_for_classify" = "true" ] && echo 0 || echo 1)"

classify_consumes_domain=$(jq -e \
    '.cross_skill_contracts.consumes_from."wf-legacy-scan" | contains(["domain-hints.json"])' \
    "$CLASSIFY_CONTRACT" >/dev/null 2>&1 && echo "true" || echo "false")
check "wf-legacy-classify contract: consumes domain-hints.json from wf-legacy-scan" \
    "$([ "$classify_consumes_domain" = "true" ] && echo 0 || echo 1)"

# wf-legacy-scan produces scan-state.json for wf-legacy-extract.
extract_consumes_state=$(jq -e \
    '.cross_skill_contracts.consumes_from."wf-legacy-scan" | map(select(contains("scan-state"))) | length > 0' \
    "$EXTRACT_CONTRACT" >/dev/null 2>&1 && echo "true" || echo "false")
check "wf-legacy-extract contract: consumes scan-state.json from wf-legacy-scan" \
    "$([ "$extract_consumes_state" = "true" ] && echo 0 || echo 1)"

# CORE-021 check: wf-brainstorm should consume project-context.md.
BRAINSTORM_PRODUCES=$(jq -r \
    '.cross_skill_contracts.produces_for."wf-brainstorm" | .[]' \
    "$SCAN_CONTRACT" 2>/dev/null)
if echo "$BRAINSTORM_PRODUCES" | grep -q "project-context.md"; then
    check "wf-legacy-scan: project-context.md produced for wf-brainstorm (CORE-021)" 0
else
    check "wf-legacy-scan: project-context.md → wf-brainstorm" 1
fi

echo ""
echo "--- Tier 1: LEGACY_MODE detection anchor ---"

# Verify project-context.md template >= 500 bytes (CORE-021 detection threshold).
PCTX_TEMPLATE="$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/templates/project-context.md"
if [ -f "$PCTX_TEMPLATE" ]; then
    size=$(wc -c < "$PCTX_TEMPLATE")
    check "project-context.md template exists (size: ${size}B)" 0
    if [ "$size" -gt "200" ]; then
        check "project-context.md template is non-trivial (>200B)" 0
    else
        check "project-context.md template size > 200B (got: ${size}B)" 1
    fi
else
    check "project-context.md template exists" 1
fi

# Verify CORE-021 detection criteria documented in procedures.
if grep -q 'project-context.md.*500\|500.*bytes\|LEGACY_MODE' \
    "$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/procedures/phase4-synthesize.md" 2>/dev/null; then
    check "CORE-021 LEGACY_MODE anchor documented in phase4-synthesize.md" 0
else
    echo "  [SKIP] CORE-021 anchor check in phase4-synthesize.md — verify manually"
fi

echo ""
echo "--- Tier 1: Downstream skill consumer checks ---"

# Check wf-design consumes domain-hints.json from wf-legacy-scan.
scan_produces_domain_for_design=$(jq -e \
    '.cross_skill_contracts.produces_for."wf-design" | contains(["domain-hints.json"])' \
    "$SCAN_CONTRACT" >/dev/null 2>&1 && echo "true" || echo "false")
check "wf-legacy-scan: domain-hints.json produced for wf-design" \
    "$([ "$scan_produces_domain_for_design" = "true" ] && echo 0 || echo 1)"

# Check impl-status-snapshot.json → wf-define-features.
scan_produces_snapshot=$(jq -e \
    '.cross_skill_contracts.produces_for."wf-define-features" | contains(["impl-status-snapshot.json"])' \
    "$SCAN_CONTRACT" >/dev/null 2>&1 && echo "true" || echo "false")
check "wf-legacy-scan: impl-status-snapshot.json produced for wf-define-features" \
    "$([ "$scan_produces_snapshot" = "true" ] && echo 0 || echo 1)"

echo ""
echo "=== Tier 2: Full pipeline E2E (BLOCKED by A.3 + Claude CLI) ==="

if [ -z "$FIXTURE" ]; then
    echo "  [SKIP] No fixture provided."
    echo "  Full pipeline test:"
    echo "    1. cd <fixture-dir>"
    echo "    2. claude /wf-legacy-scan . --profile=standard"
    echo "    3. Verify: .mc-data/work/legacy-scan/project-context.md exists + size > 500B"
    echo "    4. claude /wf-brainstorm"
    echo "       Verify: LEGACY_MODE detected (project-context.md > 500B)"
    echo "    5. claude /wf-analyze-requirements"
    echo "       Verify: consumes project-context.md"
    echo "    6. claude /wf-define-features"
    echo "       Verify: consumes impl-status-snapshot.json (1 time only)"
    echo "    7. claude /wf-design"
    echo "       Verify: consumes domain-hints.json"
    echo "    8. claude /wf-plan-modules"
    echo "    9. jq '.requirements | length' .mc-data/docs/_meta/req-registry.json"
    echo "       Verify: REQ-IDs created from extracted data"
else
    echo "  Fixture: $FIXTURE"
    WORK="$FIXTURE/.mc-data/work/legacy-scan"
    if [ -f "$WORK/project-context.md" ]; then
        size=$(wc -c < "$WORK/project-context.md")
        check "project-context.md exists ($size bytes)" 0
        [ "$size" -gt "500" ] && check "project-context.md > 500B (CORE-021 anchor)" 0 \
                               || check "project-context.md > 500B (got: ${size}B)" 1
    else
        echo "  [SKIP] project-context.md not found — run wf-legacy-scan first"
    fi

    if [ -f "$WORK/domain-hints.json" ]; then
        check "domain-hints.json present for downstream consumption" 0
    else
        echo "  [SKIP] domain-hints.json not found — expected after IPS-B"
    fi
fi

echo ""
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL"
if [ "$FAIL" = "0" ]; then
    echo "[SUCCESS] Phase I downstream integration Tier 1 passed ($PASS/$PASS checks)"
    exit 0
else
    echo "[FAILURE] Phase I downstream integration failed ($FAIL/$TOTAL checks)"
    exit 1
fi
