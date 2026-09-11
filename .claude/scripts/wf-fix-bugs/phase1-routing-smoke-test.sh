#!/usr/bin/env bash
# =============================================================================
# phase1-routing-smoke-test.sh — Verify Phase 1 lazy-load routing chain
# =============================================================================
# Mục đích (v10.14.0):
#   Smoke test giả lập AI orchestrator đọc tuần tự qua 8 sub-files Phase 1.
#   Verify:
#     1. Index file (phase1-init.md) exists + đủ 8 group references
#     2. Mỗi group file exists + có "Next Group" pointer đúng
#     3. Routing chain unbroken: A → B → C → D → E → F → G → POST-GATE
#     4. Mỗi group file có Input/Output contract section
#     5. 4 helper scripts mới exist + executable
#
# Exit codes:
#   0 — All checks PASS
#   1 — Critical check failed (missing file, broken routing)
#   2 — Warning level fail (missing optional section)
#
# Usage:
#   bash .claude/scripts/wf-fix-bugs/phase1-routing-smoke-test.sh
#
# Compatibility: Pure bash + grep. Run từ repo root.
# =============================================================================

set -u

INDEX_FILE=".claude/skills/workflow/wf-fix-bugs/procedures/phase1-init.md"
GROUP_DIR=".claude/skills/workflow/wf-fix-bugs/procedures/phase1-init"
SCRIPTS_DIR=".claude/scripts/wf-fix-bugs"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo "  ✓ $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  ✗ FAIL: $1" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { echo "  ! WARN: $1" >&2; WARN_COUNT=$((WARN_COUNT + 1)); }

echo "=============================================="
echo "Phase 1 Routing Smoke Test (v10.14.0)"
echo "=============================================="
echo ""

# ── Check 1: Index file exists + references all 8 group files ───────────────
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

# Verify index references all 8 group files
for grp in A-bootstrap B-wave1 C-decision D-session-setup E-isg F-wave4 G-finalize POST-GATE; do
  if grep -q "phase1-init/$grp.md" "$INDEX_FILE"; then
    pass "Index references phase1-init/$grp.md"
  else
    fail "Index missing reference: phase1-init/$grp.md"
  fi
done

echo ""

# ── Check 2: All 8 group files exist ────────────────────────────────────────
echo "[2/5] Group files existence"

GROUP_FILES=(A-bootstrap B-wave1 C-decision D-session-setup E-isg F-wave4 G-finalize POST-GATE)
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
  [A-bootstrap]="B-wave1"
  [B-wave1]="C-decision"
  [C-decision]="D-session-setup"
  [D-session-setup]="E-isg"
  [E-isg]="F-wave4"
  [F-wave4]="G-finalize"
  [G-finalize]="POST-GATE"
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

# POST-GATE.md should reference Phase 2
if [ -f "$GROUP_DIR/POST-GATE.md" ]; then
  if grep -qiE "phase2-scan\.md|Phase 2" "$GROUP_DIR/POST-GATE.md"; then
    pass "POST-GATE.md routes to Phase 2"
  else
    fail "POST-GATE.md missing route to Phase 2"
  fi
fi

echo ""

# ── Check 4: Each group has Input/Output contract sections ──────────────────
echo "[4/5] Group file structure (Input/Output contracts)"

for grp in "${GROUP_FILES[@]}"; do
  f="$GROUP_DIR/$grp.md"
  if [ ! -f "$f" ]; then continue; fi
  if [ "$grp" = "POST-GATE" ]; then
    # POST-GATE has different structure (T1-T5 checks)
    if grep -qE "POST-GATE|T1.*T5|## On Failure" "$f"; then
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

# ── Check 5: New helper scripts exist + executable ──────────────────────────
echo "[5/5] Helper scripts existence + executable"

NEW_SCRIPTS=(phase1-parse-flags.sh phase1-auto-resolve.sh phase1-create-session.sh phase1-trace-start.sh)
EXISTING_SCRIPTS=(phase1-wave1-dispatch.sh phase1-validate-paths.sh phase1-isg-fastpath.sh phase1-init-bundle.sh)

for s in "${NEW_SCRIPTS[@]}" "${EXISTING_SCRIPTS[@]}"; do
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
