#!/usr/bin/env bash
# sync-audit-to-evals.sh — Verify audit findings synced to evals.json per lane skill
# Stage 2 Task 4 (DEC-006): Check >= 3 TC-audit-* cases per wf-fix-{dim}/evals/evals.json
#
# Usage:
#   bash plans/wf-fix-bugs-dimensions-audit-v1/scripts/sync-audit-to-evals.sh
#   bash plans/wf-fix-bugs-dimensions-audit-v1/scripts/sync-audit-to-evals.sh --list
#
# Exit codes:
#   0 — All 7 dims PASS (>= 3 TC-audit-* cases each)
#   1 — One or more dims FAIL or MISSING

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.claude/skills/workflow"
LIST_MODE="${1:-}"

# QD→skill mapping (7 lane skills)
DIMS=(
  "QD1:wf-fix-functional:11"
  "QD2:wf-fix-business:14"
  "QD3:wf-fix-security:12"
  "QD4:wf-fix-performance:12"
  "QD5:wf-fix-ux-a11y:16"
  "QD6:wf-fix-data:15"
  "QD7:wf-fix-compat:14"
)

MIN_AUDIT_CASES=3

PASS=0
FAIL=0
MISSING=0

echo "========================================================"
echo " sync-audit-to-evals.sh — Stage 2 Task 4 (DEC-006)"
echo " Verify: >= $MIN_AUDIT_CASES TC-audit-* per lane skill"
echo "========================================================"
echo ""

for entry in "${DIMS[@]}"; do
  DIM="${entry%%:*}"
  REST="${entry#*:}"
  SKILL="${REST%%:*}"
  IMP_COUNT="${REST##*:}"
  EVALS="$SKILLS_DIR/$SKILL/evals/evals.json"

  if [ ! -f "$EVALS" ]; then
    printf "%-8s %-25s MISSING  (evals.json not found)\n" "$DIM" "$SKILL"
    MISSING=$((MISSING + 1))
    continue
  fi

  # Count TC-audit-* cases
  AUDIT_COUNT=$(jq '[.test_cases[] | select(.id | startswith("TC-audit-"))] | length' "$EVALS" 2>/dev/null || echo 0)
  TOTAL_COUNT=$(jq '.test_cases | length' "$EVALS" 2>/dev/null || echo 0)

  if [ "$AUDIT_COUNT" -ge "$MIN_AUDIT_CASES" ]; then
    printf "PASS     %-25s %d TC-audit-* cases (%d total) — %s IMPs covered\n" \
      "$SKILL" "$AUDIT_COUNT" "$TOTAL_COUNT" "$IMP_COUNT"
    PASS=$((PASS + 1))

    # --list mode: show which TC-audit cases
    if [ "$LIST_MODE" = "--list" ]; then
      jq -r '.test_cases[] | select(.id | startswith("TC-audit-")) | "           \(.id): \(.name[0:70])"' "$EVALS"
    fi
  else
    printf "FAIL     %-25s %d TC-audit-* cases (need >= %d, total %d)\n" \
      "$SKILL" "$AUDIT_COUNT" "$MIN_AUDIT_CASES" "$TOTAL_COUNT"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "--- Summary ---"
printf "PASS: %d / %d\n" "$PASS" "${#DIMS[@]}"
printf "FAIL: %d\n" "$FAIL"
printf "MISSING: %d\n" "$MISSING"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$MISSING" -eq 0 ]; then
  echo "STATUS: SYNC_COMPLETE — All 7 dims have >= $MIN_AUDIT_CASES audit-derived eval cases"
  echo "G2 gate criterion: evals sync ✅ PASS"
  exit 0
else
  echo "STATUS: SYNC_INCOMPLETE — Fix FAIL/MISSING dims before G2 sign-off"
  echo "G2 gate criterion: evals sync ❌ FAIL"
  exit 1
fi
