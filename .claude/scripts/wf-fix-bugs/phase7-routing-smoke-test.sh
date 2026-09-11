#!/usr/bin/env bash
# =============================================================================
# phase7-routing-smoke-test.sh — Verify Phase 7 lazy-load routing chain
# =============================================================================
# Mục đích (v10.17.0):
#   Smoke test giả lập AI orchestrator đọc tuần tự qua 8 sub-files Phase 7.
#   Verify:
#     1. Index file (phase7-verify.md) exists + đủ 8 group references
#     2. Mỗi group file exists + có "Next Group" pointer đúng
#     3. Routing chain unbroken: A → B → C → D → E → F → G → POST-GATE
#        + E005 healthy branching: A → D (skip B + C)
#     4. Mỗi group file có Input/Output contract section
#     5. Helper scripts exist + executable
#     6. POST-GATE reference fix-impact.json schema check (CORE-036)
#
# Exit codes:
#   0 — All checks PASS
#   1 — Critical check failed (missing file, broken routing)
#   2 — Warning level fail (missing optional section)
#
# Usage:
#   bash .claude/scripts/wf-fix-bugs/phase7-routing-smoke-test.sh
#
# Compatibility: Pure bash + grep. Run từ repo root.
# =============================================================================

set -u

INDEX_FILE=".claude/skills/workflow/wf-fix-bugs/procedures/phase7-verify.md"
GROUP_DIR=".claude/skills/workflow/wf-fix-bugs/procedures/phase7-verify"
SCRIPTS_DIR=".claude/scripts/wf-fix-bugs"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo "  ✓ $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  ✗ FAIL: $1" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { echo "  ! WARN: $1" >&2; WARN_COUNT=$((WARN_COUNT + 1)); }

echo "=============================================="
echo "Phase 7 Routing Smoke Test (v10.17.0)"
echo "=============================================="
echo ""

# ── Check 1: Index file exists + references all 8 group files ───────────────
echo "[1/6] Index file integrity"

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
for grp in A-setup B-cqg1 C-cqg2-cdg D-mobile-dashboard E-reports F-finalize G-todowrite-display POST-GATE; do
  if grep -q "phase7-verify/$grp.md" "$INDEX_FILE"; then
    pass "Index references phase7-verify/$grp.md"
  else
    fail "Index missing reference: phase7-verify/$grp.md"
  fi
done

echo ""

# ── Check 2: All 8 group files exist ────────────────────────────────────────
echo "[2/6] Group files existence"

GROUP_FILES=(A-setup B-cqg1 C-cqg2-cdg D-mobile-dashboard E-reports F-finalize G-todowrite-display POST-GATE)
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
echo "[3/6] Routing chain integrity"

declare -A NEXT_OF=(
  [A-setup]="B-cqg1"
  [B-cqg1]="C-cqg2-cdg"
  [C-cqg2-cdg]="D-mobile-dashboard"
  [D-mobile-dashboard]="E-reports"
  [E-reports]="F-finalize"
  [F-finalize]="G-todowrite-display"
  [G-todowrite-display]="POST-GATE"
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

# A-setup.md should also reference D-mobile-dashboard.md (E005 branching skip B+C)
if [ -f "$GROUP_DIR/A-setup.md" ]; then
  if grep -q "D-mobile-dashboard.md" "$GROUP_DIR/A-setup.md"; then
    pass "A-setup.md has E005 healthy branch route to D-mobile-dashboard.md"
  else
    warn "A-setup.md missing E005 healthy branch route to D-mobile-dashboard.md"
  fi
fi

# POST-GATE.md should mention END / cross-skill (Phase 7 là phase cuối)
if [ -f "$GROUP_DIR/POST-GATE.md" ]; then
  if grep -qiE "END|wf-verify-sync|--from-fix-bugs|cross-skill" "$GROUP_DIR/POST-GATE.md"; then
    pass "POST-GATE.md references END / cross-skill consumer"
  else
    fail "POST-GATE.md missing END / cross-skill reference"
  fi
fi

echo ""

# ── Check 4: Each group has Input/Output contract sections ──────────────────
echo "[4/6] Group file structure (Input/Output contracts)"

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

# ── Check 5: Helper scripts exist + executable ──────────────────────────────
echo "[5/6] Helper scripts existence + executable"

# Phase 7 dùng finalize-phase7.sh (special case — KHÔNG migrate sang phase-finalize.sh
# do pre-finalize pipeline_status=DONE + dual-write global trace)
SCRIPTS=(setup-verify.sh cqg1-numeric.sh finalize-dashboard.sh generate-phase7-reports.sh finalize-phase7.sh)

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

# ── Check 6: POST-GATE references fix-impact.json schema check (CORE-036) ───
echo "[6/6] Cross-skill artifact contract (CORE-036)"

POST_GATE="$GROUP_DIR/POST-GATE.md"
if [ -f "$POST_GATE" ]; then
  if grep -qE 'fix-impact-v1|fix-impact\.json' "$POST_GATE"; then
    pass "POST-GATE.md references fix-impact.json schema (CORE-036)"
  else
    fail "POST-GATE.md missing fix-impact.json schema check"
  fi
  if grep -qE 'audit_chain|checksum_sha256|checksum.*64' "$POST_GATE"; then
    pass "POST-GATE.md references audit_chain checksum (CORE-036 integrity)"
  else
    warn "POST-GATE.md missing audit_chain checksum check"
  fi
  if grep -qE '_phase7_trace_fail|trace_fail' "$POST_GATE"; then
    pass "POST-GATE.md references _phase7_trace_fail standard pattern"
  else
    warn "POST-GATE.md missing _phase7_trace_fail reference"
  fi
fi

# E-reports.md should reference fix-impact.json + audit_chain
E_REPORTS="$GROUP_DIR/E-reports.md"
if [ -f "$E_REPORTS" ]; then
  if grep -qE 'fix-impact-v1|audit_chain' "$E_REPORTS"; then
    pass "E-reports.md references fix-impact.json schema + audit_chain"
  else
    warn "E-reports.md missing fix-impact.json + audit_chain reference"
  fi
fi

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
