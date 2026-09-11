#!/usr/bin/env bash
# =============================================================================
# phase4-routing-smoke-test.sh — Verify Phase 4 lazy-load routing chain
# =============================================================================
# Mục đích (v10.18.0):
#   Smoke test giả lập AI orchestrator đọc tuần tự qua 8 sub-files Phase 4.
#   Verify:
#     1. Index file (phase4-find-bugs.md) exists + đủ 8 group references
#     2. Mỗi group file exists + có "Next Group" pointer đúng
#     3. Routing chain unbroken: A → B → C → D → E → F → G → POST-GATE
#        + A skip-branch: A → C (khi PW_LANE_COUNT == 0)
#     4. Mỗi group file có Input/Output contract section
#     5. Helper scripts exist + executable (8 scripts)
#     6. POST-GATE reference phase4-summary.json schema + audit_chain (CORE-036)
#     7. EXTRA Phase 4-specific: PARALLEL Dispatch pattern preserved
#        (MANDATORY DISPATCH PROTOCOL, single-response, max 10, subagent_type="claude")
#
# Exit codes:
#   0 — All checks PASS (with optional WARN)
#   1 — Critical check failed (missing file, broken routing)
#
# Usage:
#   bash .claude/scripts/wf-fix-bugs/phase4-routing-smoke-test.sh
#
# Compatibility: Pure bash + grep. Run từ repo root.
# =============================================================================

set -u

INDEX_FILE=".claude/skills/workflow/wf-fix-bugs/procedures/phase4-find-bugs.md"
GROUP_DIR=".claude/skills/workflow/wf-fix-bugs/procedures/phase4-find-bugs"
SCRIPTS_DIR=".claude/scripts/wf-fix-bugs"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo "  ✓ $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  ✗ FAIL: $1" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { echo "  ! WARN: $1" >&2; WARN_COUNT=$((WARN_COUNT + 1)); }

echo "=============================================="
echo "Phase 4 Routing Smoke Test (v10.18.0)"
echo "=============================================="
echo ""

# ── Check 1: Index file exists + references all 8 group files ───────────────
echo "[1/7] Index file integrity"

if [ ! -f "$INDEX_FILE" ]; then
  fail "Index file missing: $INDEX_FILE"
  exit 1
fi
pass "Index file exists: $INDEX_FILE ($(wc -l < "$INDEX_FILE") lines)"

# Index should be lean — warn if too large (Phase 4 cho phép >150 do phức tạp nhất)
INDEX_LINES=$(wc -l < "$INDEX_FILE")
if [ "$INDEX_LINES" -gt 160 ]; then
  warn "Index file ${INDEX_LINES} lines (target ≤160 for Phase 4 — phức tạp nhất pipeline)"
else
  pass "Index file lean (${INDEX_LINES} lines)"
fi

# Verify index references all 8 group files
for grp in A-pregate-setup B-browser-cdg C-create-lanes D-render-verify E-dispatch F-monitor-validate G-report-finalize POST-GATE; do
  if grep -q "phase4-find-bugs/$grp.md" "$INDEX_FILE"; then
    pass "Index references phase4-find-bugs/$grp.md"
  else
    fail "Index missing reference: phase4-find-bugs/$grp.md"
  fi
done

echo ""

# ── Check 2: All 8 group files exist ────────────────────────────────────────
echo "[2/7] Group files existence"

GROUP_FILES=(A-pregate-setup B-browser-cdg C-create-lanes D-render-verify E-dispatch F-monitor-validate G-report-finalize POST-GATE)
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
echo "[3/7] Routing chain integrity"

declare -A NEXT_OF=(
  [A-pregate-setup]="B-browser-cdg"
  [B-browser-cdg]="C-create-lanes"
  [C-create-lanes]="D-render-verify"
  [D-render-verify]="E-dispatch"
  [E-dispatch]="F-monitor-validate"
  [F-monitor-validate]="G-report-finalize"
  [G-report-finalize]="POST-GATE"
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

# A-pregate-setup.md should also reference C-create-lanes.md (PW=0 skip branch)
if [ -f "$GROUP_DIR/A-pregate-setup.md" ]; then
  if grep -q "C-create-lanes.md" "$GROUP_DIR/A-pregate-setup.md"; then
    pass "A-pregate-setup.md has PW=0 skip branch route to C-create-lanes.md"
  else
    warn "A-pregate-setup.md missing PW=0 skip branch route to C-create-lanes.md"
  fi
fi

# POST-GATE.md should mention Phase 5 (next phase)
if [ -f "$GROUP_DIR/POST-GATE.md" ]; then
  if grep -qE "Phase 5|phase5-triage" "$GROUP_DIR/POST-GATE.md"; then
    pass "POST-GATE.md references Phase 5 next phase"
  else
    fail "POST-GATE.md missing Phase 5 reference"
  fi
fi

echo ""

# ── Check 4: Each group has Input/Output contract sections ──────────────────
echo "[4/7] Group file structure (Input/Output contracts)"

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
echo "[5/7] Helper scripts existence + executable"

# Phase 4 dùng 8 scripts:
# - setup-lanes.sh (Group A Step 4.2) — wf-fix-bugs/
# - wf-fix-baseurl-conflict-check.sh (Group B Step 4.3 E090b) — scripts/ ROOT level
# - create-lane-dirs.sh (Group C Step 4.4) — wf-fix-bugs/
# - verify-lane-prompt.sh (Group D Step 4.6) — wf-fix-bugs/
# - monitor-lanes.sh (Group F Step 4.7) — wf-fix-bugs/
# - validate-lane-outputs.sh (Group F Step 4.7) — wf-fix-bugs/
# - generate-phase4-report.sh (Group G Step 4.8) — wf-fix-bugs/
# - finalize-phase4.sh (Group G Step 4.9 — SPECIAL CASE) — wf-fix-bugs/

# Scripts trong wf-fix-bugs/ subfolder
SCRIPTS=(setup-lanes.sh create-lane-dirs.sh verify-lane-prompt.sh monitor-lanes.sh validate-lane-outputs.sh generate-phase4-report.sh finalize-phase4.sh)

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

# Script trong .claude/scripts/ ROOT level (đặc biệt)
ROOT_SCRIPT=".claude/scripts/wf-fix-baseurl-conflict-check.sh"
if [ ! -f "$ROOT_SCRIPT" ]; then
  fail "Script missing: $ROOT_SCRIPT"
elif [ ! -x "$ROOT_SCRIPT" ]; then
  warn "Script not executable: $ROOT_SCRIPT"
else
  pass "Script ready: wf-fix-baseurl-conflict-check.sh (root level)"
fi

echo ""

# ── Check 6: POST-GATE references phase4-summary.json schema (CORE-036) ─────
echo "[6/7] Cross-skill artifact contract (CORE-036)"

POST_GATE="$GROUP_DIR/POST-GATE.md"
if [ -f "$POST_GATE" ]; then
  if grep -qE 'phase4-summary-v1|phase4-summary\.json' "$POST_GATE"; then
    pass "POST-GATE.md references phase4-summary.json schema (CORE-036)"
  else
    fail "POST-GATE.md missing phase4-summary.json schema check"
  fi
  if grep -qE 'audit_chain|signals_sha256|lane_status_sha256' "$POST_GATE"; then
    pass "POST-GATE.md references audit_chain checksum (CORE-036 integrity)"
  else
    fail "POST-GATE.md missing audit_chain checksum check"
  fi
  if grep -qE 'length == 64|64-char|sha256 hex' "$POST_GATE"; then
    pass "POST-GATE.md verifies audit_chain checksum format (64-char sha256)"
  else
    warn "POST-GATE.md missing checksum format verification"
  fi
fi

# G-report-finalize.md should reference phase4-summary.json + audit_chain
G_REPORT="$GROUP_DIR/G-report-finalize.md"
if [ -f "$G_REPORT" ]; then
  if grep -qE 'phase4-summary-v1|audit_chain' "$G_REPORT"; then
    pass "G-report-finalize.md references phase4-summary.json schema + audit_chain"
  else
    warn "G-report-finalize.md missing phase4-summary.json + audit_chain reference"
  fi
fi

echo ""

# ── Check 7: EXTRA — PARALLEL Dispatch pattern preserved (Phase 4-specific) ─
echo "[7/7] PARALLEL Dispatch pattern verification (Phase 4-specific)"

E_DISPATCH="$GROUP_DIR/E-dispatch.md"
if [ -f "$E_DISPATCH" ]; then
  # CRITICAL: E-dispatch.md must preserve PARALLEL pattern
  if grep -qE 'MANDATORY DISPATCH PROTOCOL' "$E_DISPATCH"; then
    pass "E-dispatch.md preserves MANDATORY DISPATCH PROTOCOL banner"
  else
    fail "E-dispatch.md missing MANDATORY DISPATCH PROTOCOL banner (CORE-025)"
  fi

  if grep -qiE 'Single-Response|single response' "$E_DISPATCH"; then
    pass "E-dispatch.md references Single-Response Parallel Dispatch"
  else
    fail "E-dispatch.md missing Single-Response Parallel Dispatch requirement"
  fi

  if grep -qE 'max 10|Max 10|MAX_CONCURRENT.*10|max.*10' "$E_DISPATCH"; then
    pass "E-dispatch.md references max 10 concurrent limit (CORE-025)"
  else
    fail "E-dispatch.md missing max 10 concurrent limit"
  fi

  if grep -qE 'subagent_type.*"claude"|subagent_type=.claude.' "$E_DISPATCH"; then
    pass "E-dispatch.md enforces subagent_type=\"claude\" (CORE-037)"
  else
    fail "E-dispatch.md missing subagent_type=\"claude\" requirement"
  fi
else
  fail "E-dispatch.md missing — cannot verify PARALLEL dispatch pattern"
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
