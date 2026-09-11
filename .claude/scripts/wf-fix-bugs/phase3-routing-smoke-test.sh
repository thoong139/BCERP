#!/usr/bin/env bash
# =============================================================================
# phase3-routing-smoke-test.sh — Verify Phase 3 lazy-load routing chain
# =============================================================================
# Mục đích (v10.16.0):
#   Smoke test giả lập AI orchestrator đọc tuần tự qua 7 sub-files Phase 3.
#   Verify:
#     1. Index file (phase3-plan.md) exists + đủ 7 group references
#     2. Mỗi group file exists + có "Next Group" pointer đúng
#     3. Routing chain unbroken: A → B → C → D → E → F → POST-GATE
#     4. Mỗi group file có Input/Output contract section
#     5. Helper scripts exist + executable
#
# Exit codes:
#   0 — All checks PASS
#   1 — Critical check failed (missing file, broken routing)
#   2 — Warning level fail (missing optional section)
#
# Usage:
#   bash .claude/scripts/wf-fix-bugs/phase3-routing-smoke-test.sh
#
# Compatibility: Pure bash + grep. Run từ repo root.
# =============================================================================

set -u

INDEX_FILE=".claude/skills/workflow/wf-fix-bugs/procedures/phase3-plan.md"
GROUP_DIR=".claude/skills/workflow/wf-fix-bugs/procedures/phase3-plan"
SCRIPTS_DIR=".claude/scripts/wf-fix-bugs"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo "  ✓ $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  ✗ FAIL: $1" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { echo "  ! WARN: $1" >&2; WARN_COUNT=$((WARN_COUNT + 1)); }

echo "=============================================="
echo "Phase 3 Routing Smoke Test (v10.16.0)"
echo "=============================================="
echo ""

# ── Check 1: Index file exists + references all 7 group files ───────────────
echo "[1/5] Index file integrity"

if [ ! -f "$INDEX_FILE" ]; then
  fail "Index file missing: $INDEX_FILE"
  exit 1
fi
pass "Index file exists: $INDEX_FILE ($(wc -l < "$INDEX_FILE") lines)"

# Index should be lean — warn if too large
INDEX_LINES=$(wc -l < "$INDEX_FILE")
if [ "$INDEX_LINES" -gt 150 ]; then
  warn "Index file ${INDEX_LINES} lines (target ≤150 for lazy-load efficiency)"
else
  pass "Index file lean (${INDEX_LINES} lines)"
fi

# Verify index references all 7 group files
for grp in A-pregate-trace B-isg-partition C-workload-gate D-route-write E-report F-finalize POST-GATE; do
  if grep -q "phase3-plan/$grp.md" "$INDEX_FILE"; then
    pass "Index references phase3-plan/$grp.md"
  else
    fail "Index missing reference: phase3-plan/$grp.md"
  fi
done

echo ""

# ── Check 2: All 7 group files exist ────────────────────────────────────────
echo "[2/5] Group files existence"

GROUP_FILES=(A-pregate-trace B-isg-partition C-workload-gate D-route-write E-report F-finalize POST-GATE)
for grp in "${GROUP_FILES[@]}"; do
  f="$GROUP_DIR/$grp.md"
  if [ -f "$f" ]; then
    pass "$grp.md exists ($(wc -l < "$f") lines)"
  else
    fail "$grp.md missing: $f"
  fi
done

echo ""

# ── Check 3: Routing chain — each group points to next ──────────────────────
echo "[3/5] Routing chain integrity"

declare -A NEXT_OF=(
  [A-pregate-trace]="B-isg-partition"
  [B-isg-partition]="C-workload-gate"
  [C-workload-gate]="D-route-write"
  [D-route-write]="E-report"
  [E-report]="F-finalize"
  [F-finalize]="POST-GATE"
)

for grp in "${!NEXT_OF[@]}"; do
  expected_next="${NEXT_OF[$grp]}"
  f="$GROUP_DIR/$grp.md"
  if [ ! -f "$f" ]; then continue; fi
  if grep -q "$expected_next.md" "$f"; then
    pass "$grp.md routes to $expected_next.md"
  else
    fail "$grp.md missing route to $expected_next.md"
  fi
done

# POST-GATE.md should reference Phase 4
if [ -f "$GROUP_DIR/POST-GATE.md" ]; then
  if grep -qiE "phase4-find-bugs\.md|Phase 4" "$GROUP_DIR/POST-GATE.md"; then
    pass "POST-GATE.md routes to Phase 4"
  else
    fail "POST-GATE.md missing route to Phase 4"
  fi
fi

echo ""

# ── Check 4: Each group has Input/Output contract sections ──────────────────
echo "[4/5] Group file structure (Input/Output contracts)"

for grp in "${GROUP_FILES[@]}"; do
  f="$GROUP_DIR/$grp.md"
  if [ ! -f "$f" ]; then continue; fi
  if [ "$grp" = "POST-GATE" ]; then
    # POST-GATE has different structure (T1-T4 checks)
    if grep -qE "POST-GATE|T1.*T4|## On Failure" "$f"; then
      pass "$grp.md has POST-GATE structure"
    else
      warn "$grp.md missing POST-GATE structure markers"
    fi
    continue
  fi
  HAS_INPUT=$(grep -cE "Input contract|## Input" "$f" || echo 0)
  HAS_OUTPUT=$(grep -cE "Output contract|## Output" "$f" || echo 0)
  if [ "$HAS_INPUT" -ge 1 ] && [ "$HAS_OUTPUT" -ge 1 ]; then
    pass "$grp.md has Input + Output contract sections"
  else
    warn "$grp.md missing contract sections (Input=$HAS_INPUT, Output=$HAS_OUTPUT)"
  fi
done

echo ""

# ── Check 5: Helper scripts exist + executable ──────────────────────────────
echo "[5/5] Helper scripts existence + executable"

SCRIPTS=(plan-isg-partition.sh route-and-write.sh generate-phase3-report.sh phase-trace-start.sh phase-finalize.sh)

for s in "${SCRIPTS[@]}"; do
  f="$SCRIPTS_DIR/$s"
  if [ ! -f "$f" ]; then
    fail "Script missing: $f"
  elif [ ! -x "$f" ]; then
    warn "Script not executable: $f"
  else
    pass "Script ready: $s"
  fi
done

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo "=============================================="
echo "Summary:"
echo "  PASS: $PASS_COUNT"
echo "  WARN: $WARN_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "=============================================="

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "❌ SMOKE TEST FAILED — fix above before commit"
  exit 1
elif [ "$WARN_COUNT" -gt 0 ]; then
  echo "⚠ SMOKE TEST PASSED WITH WARNINGS"
  exit 0
else
  echo "✅ SMOKE TEST PASSED"
  exit 0
fi
