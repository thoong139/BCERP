#!/usr/bin/env bash
# check-roadmap-locked.sh — G2 Gate Verify Script
# Plan: wf-fix-bugs-dimensions-audit-v1
# Checks all G2 criteria from 11-stages-and-gates.md
# Exit 0 = G2 PASS, Exit 1 = G2 FAIL

set -uo pipefail

PLAN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$PLAN_DIR/../../.claude/skills/workflow"
PASS=0
FAIL=0

ok()  { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail(){ echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
h()   { echo ""; echo "=== $1 ==="; }

echo "G2 GATE VERIFY — Plan: wf-fix-bugs-dimensions-audit-v1"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"

# ---------------------------------------------------------------
# Criterion 1: 10-improvement-roadmap.md has LOCKED status
# ---------------------------------------------------------------
h "C1: Roadmap LOCKED"
ROADMAP="$PLAN_DIR/10-improvement-roadmap.md"
if [[ ! -f "$ROADMAP" ]]; then
  fail "10-improvement-roadmap.md not found"
else
  if grep -q "LOCKED" "$ROADMAP"; then
    ok "10-improvement-roadmap.md header contains LOCKED"
  else
    fail "10-improvement-roadmap.md does NOT contain LOCKED"
  fi
fi

# ---------------------------------------------------------------
# Criterion 2: No tentative evidence_status remaining
# ---------------------------------------------------------------
h "C2: No tentative IMPs"
if [[ ! -f "$ROADMAP" ]]; then
  fail "Roadmap missing — skipping tentative check"
else
  TENTATIVE=$(grep "evidence_status: tentative" "$ROADMAP" 2>/dev/null | wc -l | tr -d ' ')
  VERIFIED=$(grep "evidence_status: verified" "$ROADMAP" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$TENTATIVE" -eq 0 ]]; then
    ok "0 tentative; $VERIFIED verified IMPs found"
  else
    fail "$TENTATIVE tentative IMP(s) still remain — must promote or drop"
  fi
fi

# ---------------------------------------------------------------
# Criterion 3: All verified IMPs have acceptance_test path (not placeholder)
# Only the YAML template doc (line <40) should have <path>
# ---------------------------------------------------------------
h "C3: Acceptance test paths"
if [[ ! -f "$ROADMAP" ]]; then
  fail "Roadmap missing — skipping acceptance_test check"
else
  # Count <path> placeholders BELOW line 40 (below template doc section)
  MISSING_PATH=$(awk 'NR>40 && /acceptance_test: <path>/' "$ROADMAP" | wc -l | tr -d ' ')
  TOTAL_AT=$(grep "acceptance_test:" "$ROADMAP" | grep -v "<path>" | wc -l | tr -d ' ')
  if [[ "$MISSING_PATH" -eq 0 ]]; then
    ok "All $TOTAL_AT real IMPs have acceptance_test paths (0 placeholders below template section)"
  else
    fail "$MISSING_PATH IMP(s) still have placeholder <path> in acceptance_test (excluding template doc)"
  fi
fi

# ---------------------------------------------------------------
# Criterion 4: IMP-002 cross-skill impact analysis exists
# ---------------------------------------------------------------
h "C4: IMP-002 cross-skill impact analysis"
IMPACT_FILE="$PLAN_DIR/reports/imp-002-cross-skill-impact.md"
DECISIONS="$PLAN_DIR/12-decisions-log.md"
if [[ -f "$IMPACT_FILE" ]]; then
  ok "reports/imp-002-cross-skill-impact.md exists"
elif grep -q "DEC-008" "$DECISIONS" 2>/dev/null; then
  ok "IMP-002 cross-skill impact documented in 12-decisions-log.md (DEC-008)"
else
  fail "IMP-002 cross-skill impact analysis not found in reports/ or DEC-008 in decisions log"
fi

# ---------------------------------------------------------------
# Criterion 5: All 7 evals.json have ≥3 TC-audit-* cases
# QD1=wf-fix-functional QD2=wf-fix-business QD3=wf-fix-security
# QD4=wf-fix-performance QD5=wf-fix-ux-a11y QD6=wf-fix-data QD7=wf-fix-compat
# ---------------------------------------------------------------
h "C5: evals.json sync (7/7 dims)"
declare -A DIM_MAP
DIM_MAP=( ["QD1"]="wf-fix-functional" ["QD2"]="wf-fix-business" ["QD3"]="wf-fix-security"
          ["QD4"]="wf-fix-performance" ["QD5"]="wf-fix-ux-a11y" ["QD6"]="wf-fix-data"
          ["QD7"]="wf-fix-compat" )
EVAL_FAIL_COUNT=0
for DIM in QD1 QD2 QD3 QD4 QD5 QD6 QD7; do
  SKILL="${DIM_MAP[$DIM]}"
  EVALS_FILE="$SKILLS_DIR/$SKILL/evals/evals.json"
  if [[ ! -f "$EVALS_FILE" ]]; then
    echo "  ❌ $DIM ($SKILL): evals.json NOT FOUND"
    EVAL_FAIL_COUNT=$((EVAL_FAIL_COUNT + 1))
  else
    # Count TC-audit-* cases (use jq — path-safe on Windows/Git Bash)
    COUNT=$(jq '[.test_cases[] | select(.id | startswith("TC-audit-"))] | length' "$EVALS_FILE" 2>/dev/null || echo "0")
    if [[ "$COUNT" -ge 3 ]]; then
      echo "  ✅ $DIM ($SKILL): $COUNT TC-audit-* cases"
    else
      echo "  ❌ $DIM ($SKILL): only $COUNT TC-audit-* cases (need ≥3)"
      EVAL_FAIL_COUNT=$((EVAL_FAIL_COUNT + 1))
    fi
  fi
done
if [[ "$EVAL_FAIL_COUNT" -eq 0 ]]; then
  ok "7/7 dims have ≥3 TC-audit-* cases"
else
  fail "$EVAL_FAIL_COUNT dim(s) failing TC-audit-* check"
fi

# ---------------------------------------------------------------
# Criterion 6: 09-cross-cutting-findings.md has ≥7 themes
# ---------------------------------------------------------------
h "C6: Cross-cutting findings ≥7 themes"
CCF="$PLAN_DIR/09-cross-cutting-findings.md"
if [[ ! -f "$CCF" ]]; then
  fail "09-cross-cutting-findings.md not found"
else
  THEME_COUNT=$(grep "^## Theme [0-9]" "$CCF" | wc -l | tr -d ' ')
  if [[ "$THEME_COUNT" -ge 7 ]]; then
    ok "$THEME_COUNT themes found in 09-cross-cutting-findings.md (≥7 required)"
  else
    fail "Only $THEME_COUNT themes found (need ≥7)"
  fi
fi

# ---------------------------------------------------------------
# Criterion 7: 12-decisions-log.md has ≥4 decisions
# ---------------------------------------------------------------
h "C7: Decisions log ≥4 entries"
DECLOG="$PLAN_DIR/12-decisions-log.md"
if [[ ! -f "$DECLOG" ]]; then
  fail "12-decisions-log.md not found"
else
  DEC_COUNT=$(grep "^### DEC-[0-9]" "$DECLOG" | wc -l | tr -d ' ')
  if [[ "$DEC_COUNT" -ge 4 ]]; then
    ok "$DEC_COUNT decisions documented (≥4 required)"
  else
    fail "Only $DEC_COUNT decisions (need ≥4)"
  fi
fi

# ---------------------------------------------------------------
# Criterion 8: reports/sprint-4-report.md exists
# ---------------------------------------------------------------
h "C8: Sprint 4 report exists"
SPRINT4="$PLAN_DIR/reports/sprint-4-report.md"
if [[ -f "$SPRINT4" ]]; then
  ok "reports/sprint-4-report.md exists"
else
  fail "reports/sprint-4-report.md NOT FOUND — create before G2 sign-off"
fi

# ---------------------------------------------------------------
# Final verdict
# ---------------------------------------------------------------
echo ""
echo "=============================="
echo "G2 GATE RESULT"
echo "=============================="
echo "PASS: $PASS criteria"
echo "FAIL: $FAIL criteria"
echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "✅ G2 GATE PASS — Stage 3 UNLOCKED"
  exit 0
else
  echo "❌ G2 GATE FAIL — Fix $FAIL criteria before sign-off"
  exit 1
fi
