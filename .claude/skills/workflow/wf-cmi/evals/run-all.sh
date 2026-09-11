#!/usr/bin/env bash
# run-all.sh — Chạy tất cả 18 test cases TC-cmi-001 → TC-cmi-018
#   v1 (5): TC-001..005 — Pipeline core, profiles, error handling, resume, concurrency
#   v2 (8): TC-006..013 — Wave dispatch, SSOT, 26-lane deep, logistics, compliance, status query
#   v3 (5): TC-014..018 — E2E Scenario Engine (backward-compat, CD41 synth, Phase 9-10, loop-back, stable-registry)
#
# Usage:
#   bash run-all.sh                                   # chạy tuần tự cả 18
#   bash run-all.sh --type=smoke                      # filter theo loại
#   bash run-all.sh --type=cd41-synth,phase9-execute  # v3 only
#   bash run-all.sh --skip=TC-cmi-016                 # bỏ qua test cụ thể
#   bash run-all.sh --dry-run                         # in plan, không thực thi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
HARNESS="$REPO_ROOT/.claude/scripts/audit/run-skill-evals.sh"
EVALS_JSON="$SCRIPT_DIR/evals.json"
RESULTS_DIR="$SCRIPT_DIR/results"

mkdir -p "$RESULTS_DIR"

# Parse args
TYPE_FILTER=""
SKIP_FILTER=""
DRY_RUN="false"
for arg in "$@"; do
    case "$arg" in
        --type=*) TYPE_FILTER="${arg#--type=}" ;;
        --skip=*) SKIP_FILTER="${arg#--skip=}" ;;
        --dry-run) DRY_RUN="true" ;;
        *) echo "Unknown arg: $arg" ; exit 2 ;;
    esac
done

# Resolve test cases (strip CR cho Windows Git Bash compatibility)
ALL_IDS=$(jq -r '.evals[].id' "$EVALS_JSON" | tr -d '\r')

# Filter by type (parse từ prompt vì schema không có field type ở top level — dùng heuristic)
get_test_type() {
    local id="$1"
    case "$id" in
        # v1 (pipeline core)
        TC-cmi-001) echo "smoke" ;;
        TC-cmi-002) echo "integration" ;;
        TC-cmi-003) echo "edge" ;;
        TC-cmi-004) echo "resume" ;;
        TC-cmi-005) echo "concurrent" ;;
        # v2 (Wave dispatch + new lanes)
        TC-cmi-006) echo "wave-subset" ;;
        TC-cmi-007) echo "ssot-missing" ;;
        TC-cmi-008) echo "full-26-lanes" ;;
        TC-cmi-009) echo "logistics-critical" ;;
        TC-cmi-010) echo "compliance" ;;
        TC-cmi-011) echo "new-additions" ;;
        TC-cmi-012) echo "backward-compat" ;;
        TC-cmi-013) echo "status-query" ;;
        # v3 (E2E Scenario Engine)
        TC-cmi-014) echo "backward-compat-v3" ;;
        TC-cmi-015) echo "cd41-synth" ;;
        TC-cmi-016) echo "phase9-execute" ;;
        TC-cmi-017) echo "phase10-loopback" ;;
        TC-cmi-018) echo "stable-registry" ;;
        *) echo "unknown" ;;
    esac
}

# Run
echo "==============================================="
echo "wf-cmi Evals — run-all.sh"
echo "Evals JSON: $EVALS_JSON"
echo "Results: $RESULTS_DIR"
echo "Filter: type=${TYPE_FILTER:-all} skip=${SKIP_FILTER:-none}"
echo "==============================================="

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

for TC_ID in $ALL_IDS; do
    TYPE=$(get_test_type "$TC_ID")

    # Filter
    if [ -n "$TYPE_FILTER" ] && [[ ",$TYPE_FILTER," != *",$TYPE,"* ]]; then
        echo "[SKIP-FILTER] $TC_ID ($TYPE)"
        continue
    fi
    if [ -n "$SKIP_FILTER" ] && [[ ",$SKIP_FILTER," == *",$TC_ID,"* ]]; then
        echo "[SKIP-USER] $TC_ID"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    echo ""
    echo "--- Running $TC_ID ($TYPE) ---"

    if [ "$DRY_RUN" = "true" ]; then
        echo "  [DRY-RUN] sẽ chạy: $HARNESS wf-cmi --test-id=$TC_ID"
        continue
    fi

    if [ ! -f "$HARNESS" ]; then
        echo "  ⚠ Harness $HARNESS chưa tồn tại — skip (sẽ implement Step 10)"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    if bash "$HARNESS" wf-cmi --test-id="$TC_ID"; then
        echo "  ✓ PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ✗ FAIL (exit $?)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
echo "==============================================="
echo "Summary: PASS=$PASS_COUNT FAIL=$FAIL_COUNT SKIP=$SKIP_COUNT"
echo "==============================================="

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
