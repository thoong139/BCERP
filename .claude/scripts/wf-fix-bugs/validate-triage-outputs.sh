#!/usr/bin/env bash
# =============================================================================
# validate-triage-outputs.sh — Phase 5 Step 5.8 (POST-GATE T1-T4 — v10.7)
# =============================================================================
# Tiered validation cho triage agent outputs (CORE-012):
#   T1 — File Existence: bug-triage.md, fix-plan.md, fix-log.json, issue-registry.json
#   T2 — Structure Validation: JSON shape + markdown section markers
#   T3 — Content Depth: bug-triage.md ≥10 lines, fix-plan.md ≥15 lines
#   T4 — Cross-Reference: registry issue count vs bug-triage row count (best-effort)
#
# Required env vars:
#   SESSION_DIR
#
# Exit codes:
#   0 — Tất cả T1-T4 PASS (FAILS = 0)
#   1 — Required env var missing
#   4 — Có FAIL (orchestrator re-spawn x1 hoặc ESCALATE E054)
#
# Output JSON (stdout):
#   {
#     "t1_pass": <int>, "t1_fail": <int>,
#     "t2_pass": <int>, "t2_fail": <int>,
#     "t3_pass": <int>, "t3_fail": <int>,
#     "t4_pass": <int>, "t4_fail": <int>,
#     "total_fails": <int>,
#     "registry_count": <int>,
#     "status": "ok|fail"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

if [ -z "${SESSION_DIR:-}" ]; then
  echo "ERROR: Required env var \$SESSION_DIR is empty" >&2
  exit 1
fi

SG_DIR="$SESSION_DIR/phase5-triage"
T1_PASS=0; T1_FAIL=0
T2_PASS=0; T2_FAIL=0
T3_PASS=0; T3_FAIL=0
T4_PASS=0; T4_FAIL=0

# ── T1: File Existence ───────────────────────────────────────────────────────
for f in bug-triage.md fix-plan.md fix-log.json issue-registry.json; do
  if [ -s "$SG_DIR/$f" ]; then
    T1_PASS=$((T1_PASS + 1))
  else
    echo "T1 FAIL: $f missing or empty" >&2
    T1_FAIL=$((T1_FAIL + 1))
  fi
done

# ── T2: Structure Validation ─────────────────────────────────────────────────
# issue-registry: must have .issues array + .total_issues
if jq -e '.issues and (.total_issues != null)' "$SG_DIR/issue-registry.json" >/dev/null 2>&1; then
  T2_PASS=$((T2_PASS + 1))
else
  echo "T2 FAIL: issue-registry.json structure (need .issues + .total_issues)" >&2
  T2_FAIL=$((T2_FAIL + 1))
fi

# fix-log: must have .entries array
if jq -e '.entries' "$SG_DIR/fix-log.json" >/dev/null 2>&1; then
  T2_PASS=$((T2_PASS + 1))
else
  echo "T2 FAIL: fix-log.json structure (need .entries)" >&2
  T2_FAIL=$((T2_FAIL + 1))
fi

# bug-triage: must contain Triage/Bug/Severity keyword
if grep -qiE "triage|bug|severity" "$SG_DIR/bug-triage.md" 2>/dev/null; then
  T2_PASS=$((T2_PASS + 1))
else
  echo "T2 FAIL: bug-triage.md missing triage/severity headers" >&2
  T2_FAIL=$((T2_FAIL + 1))
fi

# fix-plan: must contain Execution Plan section
if grep -qE "Execution Plan|Kế Hoạch|Plan|## " "$SG_DIR/fix-plan.md" 2>/dev/null; then
  T2_PASS=$((T2_PASS + 1))
else
  echo "T2 FAIL: fix-plan.md missing Execution Plan section" >&2
  T2_FAIL=$((T2_FAIL + 1))
fi

# ── T3: Content Depth ────────────────────────────────────────────────────────
BUG_LINES=$(wc -l < "$SG_DIR/bug-triage.md" 2>/dev/null | tr -d ' ')
BUG_LINES=${BUG_LINES:-0}
if [ "$BUG_LINES" -ge 10 ]; then
  T3_PASS=$((T3_PASS + 1))
else
  echo "T3 FAIL: bug-triage.md too short ($BUG_LINES lines, need ≥10)" >&2
  T3_FAIL=$((T3_FAIL + 1))
fi

PLAN_LINES=$(wc -l < "$SG_DIR/fix-plan.md" 2>/dev/null | tr -d ' ')
PLAN_LINES=${PLAN_LINES:-0}
if [ "$PLAN_LINES" -ge 15 ]; then
  T3_PASS=$((T3_PASS + 1))
else
  echo "T3 FAIL: fix-plan.md too short ($PLAN_LINES lines, need ≥15)" >&2
  T3_FAIL=$((T3_FAIL + 1))
fi

# ── T4: Cross-Reference — registry issue count ───────────────────────────────
REG_COUNT=$(jq '.total_issues // 0' "$SG_DIR/issue-registry.json" 2>/dev/null || echo 0)
# Best-effort: bug-triage có mention số issues khớp registry?
# Soft check — warn không fail
if [ "$REG_COUNT" -gt 0 ]; then
  T4_PASS=$((T4_PASS + 1))
else
  echo "T4 WARN: registry count = 0" >&2
  T4_FAIL=$((T4_FAIL + 1))
fi

TOTAL_FAILS=$((T1_FAIL + T2_FAIL + T3_FAIL + T4_FAIL))

STATUS="ok"
EXIT_CODE=0
if [ "$TOTAL_FAILS" -gt 0 ]; then
  STATUS="fail"
  EXIT_CODE=4
fi

jq -n \
  --argjson t1p "$T1_PASS" --argjson t1f "$T1_FAIL" \
  --argjson t2p "$T2_PASS" --argjson t2f "$T2_FAIL" \
  --argjson t3p "$T3_PASS" --argjson t3f "$T3_FAIL" \
  --argjson t4p "$T4_PASS" --argjson t4f "$T4_FAIL" \
  --argjson tf "$TOTAL_FAILS" \
  --argjson rc "$REG_COUNT" \
  --arg st "$STATUS" \
  '{
    t1_pass: $t1p, t1_fail: $t1f,
    t2_pass: $t2p, t2_fail: $t2f,
    t3_pass: $t3p, t3_fail: $t3f,
    t4_pass: $t4p, t4_fail: $t4f,
    total_fails: $tf,
    registry_count: $rc,
    status: $st
  }'

exit "$EXIT_CODE"
