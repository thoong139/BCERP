#!/usr/bin/env bash
# check-gate.sh — Gate Verification Script
# Audit: wf-fix-bugs-Audit-v2
# Checks gate criteria for G0→G5
# Exit 0 = Gate PASS, Exit 1 = Gate FAIL

set -uo pipefail

AUDIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
GATE="${1:-all}"

ok()  { echo "  PASS $1"; PASS=$((PASS + 1)); }
fail(){ echo "  FAIL $1"; FAIL=$((FAIL + 1)); }
h()   { echo ""; echo "=== $1 ==="; }

check_g0() {
  h "G0 — Infrastructure"
  for dir in reports findings logs scripts; do
    if [[ -d "$AUDIT_DIR/$dir" ]]; then
      ok "Directory $dir/ exists"
    else
      fail "Directory $dir/ missing"
    fi
  done
  [[ -f "$AUDIT_DIR/reports/README.md" ]] && ok "reports/README.md exists" || fail "reports/README.md missing"
  [[ -f "$AUDIT_DIR/reports/file-inventory.md" ]] && ok "reports/file-inventory.md exists" || fail "reports/file-inventory.md missing"
  [[ -f "$AUDIT_DIR/reports/schema-validation.md" ]] && ok "reports/schema-validation.md exists" || fail "reports/schema-validation.md missing"
}

check_g1() {
  h "G1 — P1 Correctness (74 CP)"
  local expected=(
    "c1.1-phase-execution" "c1.2-gates-part1" "c1.2-gates-part2"
    "c1.3-status-accuracy" "c1.4-signal-completeness" "c1.5-fix-correctness"
    "c1.6-resume-reliability" "c1.7-c1.8-isolation-degradation"
    "c1.9-deep-scan-part1" "c1.9-deep-scan-part2"
    "c1.10-qd11-part1" "c1.10-qd11-part2" "c1.10-qd11-infra"
  )
  for f in "${expected[@]}"; do
    if [[ -f "$AUDIT_DIR/findings/$f.md" ]]; then
      ok "findings/$f.md exists"
    else
      fail "findings/$f.md MISSING"
    fi
  done
}

check_g2() {
  h "G2 — P2 Performance + P3 Efficiency (23 CP)"
  for f in "p2-performance" "p3-efficiency"; do
    if [[ -f "$AUDIT_DIR/findings/$f.md" ]]; then
      ok "findings/$f.md exists"
    else
      fail "findings/$f.md MISSING"
    fi
  done
}

check_g3() {
  h "G3 — Regression Tests"
  # Check if tests were run (look for test result files or log entries)
  if grep -q "3.1.*done\|3.2.*done\|3.3.*done" "$AUDIT_DIR/progress.md" 2>/dev/null; then
    ok "Regression test results documented in progress.md"
  else
    fail "Regression test results not found in progress.md"
  fi
}

check_g4() {
  h "G4 — Runtime Scenarios + Reference Check"
  local expected=("runtime-scenarios-part1" "runtime-scenarios-part2" "d1-cross-reference" "d2-consumer-contract")
  for f in "${expected[@]}"; do
    if [[ -f "$AUDIT_DIR/findings/$f.md" ]]; then
      ok "findings/$f.md exists"
    else
      fail "findings/$f.md MISSING"
    fi
  done
}

check_g5() {
  h "G5 — Final Report"
  if ls "$AUDIT_DIR/reports/audit-report-"*.md 2>/dev/null | head -1 | grep -q .; then
    ok "Final audit report exists"
  else
    fail "Final audit report NOT FOUND"
  fi
  # Check all previous gates
  if [[ "$FAIL" -eq 0 ]]; then
    ok "All gates G0-G5 PASS — ready for DONE tag"
  fi
}

case "$GATE" in
  g0|G0) check_g0 ;;
  g1|G1) check_g1 ;;
  g2|G2) check_g2 ;;
  g3|G3) check_g3 ;;
  g4|G4) check_g4 ;;
  g5|G5) check_g5 ;;
  all)
    check_g0
    check_g1
    check_g2
    check_g3
    check_g4
    check_g5
    ;;
  *)
    echo "Usage: $0 [g0|g1|g2|g3|g4|g5|all]"
    exit 2
    ;;
esac

echo ""
echo "=============================="
echo "GATE RESULT: $GATE"
echo "PASS: $PASS | FAIL: $FAIL"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "GATE PASS"
  exit 0
else
  echo "GATE FAIL — Fix $FAIL criteria"
  exit 1
fi
