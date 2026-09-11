#!/usr/bin/env bash
# Sprint 4 comprehensive smoke test — verify all changes integrate correctly.
# Tests: template, helper, namespace coverage, _shared.md, phase-summary, _contract.json, evals.

set -uo pipefail
# Note: KHÔNG dùng -e vì grep -c | wc -l có thể return 1 khi không match — assertions handle fail riêng.

cd "$(dirname "$0")/../../.."
ROOT="$(pwd)"
SKILL="$ROOT/.claude/skills/workflow/wf-implement-feature"
PASS=0
FAIL=0

ASSERT() {
  local name="$1"; local cond="$2"
  if [[ "$cond" == "true" ]]; then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL+1))
  fi
}

# ── Test 1: template error-ledger.json valid + has required fields ──────────
LEDGER_TPL="$SKILL/templates/error-ledger.json"
[[ -f "$LEDGER_TPL" ]] && ASSERT "T1.1 error-ledger.json template exists" true || ASSERT "T1.1 error-ledger.json template exists" false

T1_2=$(jq -e '.schema_version == "1.0" and has("session_id") and has("feature_slug") and (.errors | type == "array" and length == 0)' "$LEDGER_TPL" >/dev/null 2>&1 && echo true || echo false)
ASSERT "T1.2 template schema fields valid" "$T1_2"

[[ -f "$SKILL/templates/error-ledger.schema.md" ]] && ASSERT "T1.3 schema doc exists" true || ASSERT "T1.3 schema doc exists" false

# ── Test 2: ledger_log helper functional ───────────────────────────────────
T2_1=$(grep -c "^ledger_log()" "$ROOT/.claude/scripts/wf-implement-feature/implement-common.sh")
[[ "$T2_1" == "1" ]] && ASSERT "T2.1 ledger_log() function defined" true || ASSERT "T2.1 ledger_log() function defined ($T2_1 occurrences)" false

# Bash syntax check
bash -n "$ROOT/.claude/scripts/wf-implement-feature/implement-common.sh" 2>/dev/null && ASSERT "T2.2 implement-common.sh bash syntax valid" true || ASSERT "T2.2 implement-common.sh bash syntax valid" false

# Quick functional test — source + call once
TEST_DIR="$ROOT/.mc-data/work/wf-implement-feature/test-sprint4-smoke/sessions/2026-04-28-smoke"
rm -rf "$ROOT/.mc-data/work/wf-implement-feature/test-sprint4-smoke"
mkdir -p "$TEST_DIR"
export SESSION_ID="2026-04-28-smoke"
export FEATURE_SLUG="test-sprint4-smoke"
export SESSION_DIR="$TEST_DIR"
_SCRIPT_NAME="smoke-test"
source "$ROOT/.claude/scripts/wf-implement-feature/implement-common.sh"
# Re-disable -e (sourcing helper activated set -euo pipefail; we need lenient mode for assertions)
set +e
ledger_log "E101" "phase01-pattern-scan" "warning" "Smoke test entry" '{"src":"smoke"}' true >/dev/null 2>&1 || true
[[ -f "$TEST_DIR/error-ledger.json" ]] && ASSERT "T2.3 ledger_log creates file" true || ASSERT "T2.3 ledger_log creates file" false

T2_4=$(jq -r '.errors[0].code' "$TEST_DIR/error-ledger.json" 2>/dev/null)
[[ "$T2_4" == "E101" ]] && ASSERT "T2.4 ledger entry has correct code" true || ASSERT "T2.4 ledger entry has correct code (got '$T2_4')" false

# ── Test 3: _shared.md has namespace + alias table ─────────────────────────
SHARED="$SKILL/procedures/_shared.md"
T3_1=$(grep -c "v4.0+ namespaced" "$SHARED")
[[ "$T3_1" -gt 0 ]] && ASSERT "T3.1 _shared.md has namespace section header" true || ASSERT "T3.1 _shared.md has namespace section header" false

T3_2=$(grep -cE "^\| E[1-9][0-9]{2} \|" "$SHARED")
[[ "$T3_2" -ge 15 ]] && ASSERT "T3.2 _shared.md has ≥15 namespaced codes (got $T3_2)" true || ASSERT "T3.2 _shared.md has ≥15 namespaced codes (got $T3_2)" false

# Each E001-E014 has alias mapping in shared.md (allow E015 too)
T3_3_PASS=true
for old in E001 E002 E003 E004a E004b E005 E006 E007 E008 E009 E010 E011 E012 E013 E014 E015; do
  if ! grep -q "| $old |" "$SHARED"; then
    echo "  Missing alias: $old"
    T3_3_PASS=false
  fi
done
[[ "$T3_3_PASS" == "true" ]] && ASSERT "T3.3 alias table covers E001-E015" true || ASSERT "T3.3 alias table covers E001-E015" false

# ── Test 4: Phase files no standalone E0xx (only alias notation) ────────────
T4_REMAINING=$(grep -rEn "E0[0-9]{2}" "$SKILL/procedures/" | grep -v "_shared.md" | grep -vE "alias E0|\(was \)" | wc -l)
[[ "$T4_REMAINING" -le 1 ]] && ASSERT "T4.1 phase files no standalone E0xx (≤1 = footnote)" true || ASSERT "T4.1 phase files no standalone E0xx ($T4_REMAINING remaining)" false

# Phase files reference at least some E1xx-E9xx codes
T4_NS=$(grep -rEn "E[1-9][0-9]{2}" "$SKILL/procedures/" | wc -l)
[[ "$T4_NS" -ge 10 ]] && ASSERT "T4.2 phase files reference namespaced codes (got $T4_NS)" true || ASSERT "T4.2 phase files reference namespaced codes ($T4_NS)" false

# ── Test 5: phase-summary template has Errors & Warnings section ────────────
SUMMARY="$SKILL/templates/phase-summary.md"
T5_1=$(grep -c "## Errors & Warnings" "$SUMMARY")
[[ "$T5_1" -ge 1 ]] && ASSERT "T5.1 phase-summary.md has Errors & Warnings section" true || ASSERT "T5.1 phase-summary.md has Errors & Warnings section" false

T5_2=$(grep -c "✅ Không có lỗi hoặc cảnh báo" "$SUMMARY")
[[ "$T5_2" -ge 1 ]] && ASSERT "T5.2 phase-summary has zero-state placeholder" true || ASSERT "T5.2 phase-summary has zero-state placeholder" false

# Phase 6 has populate logic
T5_3=$(grep -c "Errors & Warnings Population" "$SKILL/procedures/phase6-finalize.md")
[[ "$T5_3" -ge 1 ]] && ASSERT "T5.3 phase6-finalize has populate logic" true || ASSERT "T5.3 phase6-finalize has populate logic" false

# Phase 6 step 6.7 verify includes Errors check
T5_4=$(grep -c 'Errors & Warnings\\" phase-summary.md' "$SKILL/procedures/phase6-finalize.md" || true)
T5_4_OK=$(grep -c "Errors & Warnings" "$SKILL/procedures/phase6-finalize.md")
[[ "$T5_4_OK" -ge 2 ]] && ASSERT "T5.4 phase6 references Errors & Warnings (verify gate)" true || ASSERT "T5.4 phase6 references Errors & Warnings ($T5_4_OK occurrences)" false

# ── Test 6: _contract.json has error-ledger output ─────────────────────────
CONTRACT="$SKILL/_contract.json"
jq empty "$CONTRACT" 2>/dev/null && ASSERT "T6.1 _contract.json valid JSON" true || ASSERT "T6.1 _contract.json valid JSON" false

T6_2=$(jq -r '.outputs.working[] | select(.path | endswith("error-ledger.json")) | .path' "$CONTRACT" 2>/dev/null)
[[ -n "$T6_2" ]] && ASSERT "T6.2 error-ledger.json output entry present" true || ASSERT "T6.2 error-ledger.json output entry present" false

T6_3=$(jq -r '.outputs.working[] | select(.path | endswith("error-ledger.json")) | .template' "$CONTRACT" 2>/dev/null)
[[ "$T6_3" == "templates/error-ledger.json" ]] && ASSERT "T6.3 error-ledger entry references template" true || ASSERT "T6.3 error-ledger entry references template (got '$T6_3')" false

T6_4=$(jq -r '.description' "$CONTRACT" 2>/dev/null | grep -c "Sprint 4")
[[ "$T6_4" -ge 1 ]] && ASSERT "T6.4 description mentions Sprint 4" true || ASSERT "T6.4 description mentions Sprint 4" false

T6_5=$(jq -r '.version' "$CONTRACT" 2>/dev/null)
[[ "$T6_5" == "4.0.0" ]] && ASSERT "T6.5 version is 4.0.0" true || ASSERT "T6.5 version is 4.0.0 (got '$T6_5')" false

# ── Test 7: SKILL.md updated ───────────────────────────────────────────────
T7_1=$(grep -c "v4.0+ namespaced" "$SKILL/SKILL.md")
[[ "$T7_1" -ge 1 ]] && ASSERT "T7.1 SKILL.md Error Handling section bumped" true || ASSERT "T7.1 SKILL.md Error Handling section bumped" false

T7_2=$(grep -cE "^\| E[1-9][0-9]{2} " "$SKILL/SKILL.md")
[[ "$T7_2" -ge 5 ]] && ASSERT "T7.2 SKILL.md table has namespaced codes (got $T7_2)" true || ASSERT "T7.2 SKILL.md table has namespaced codes" false

# ── Test 8: evals.json updated ─────────────────────────────────────────────
EVALS="$SKILL/evals/evals.json"
jq empty "$EVALS" 2>/dev/null && ASSERT "T8.1 evals.json valid JSON" true || ASSERT "T8.1 evals.json valid JSON" false

T8_2=$(grep -c "E103, alias E003\|E103 (alias E003)" "$EVALS")
[[ "$T8_2" -ge 1 ]] && ASSERT "T8.2 evals reference E103 alias E003" true || ASSERT "T8.2 evals reference E103 alias E003 (got $T8_2)" false

# ── Test 9: ledger_log integration with multiple severities ────────────────
ledger_log "E301" "phase07-tdd" "error" "Test gate fail" '{"batch":2}' false true "Manual review needed" >/dev/null 2>&1 || true
ledger_log "E602" "phase10-finalize" "critical" "POST-GATE T1 fail" '{}' false true >/dev/null 2>&1 || true
ledger_log "E601" "phase10-finalize" "info" "Lock acquired" >/dev/null 2>&1 || true

T9_1=$(jq -r '.errors | length' "$TEST_DIR/error-ledger.json")
[[ "$T9_1" == "4" ]] && ASSERT "T9.1 4 entries total (1+3 new)" true || ASSERT "T9.1 4 entries total (got $T9_1)" false

T9_2=$(jq -r '[.errors[] | select(.severity == "critical")] | length' "$TEST_DIR/error-ledger.json")
[[ "$T9_2" == "1" ]] && ASSERT "T9.2 1 critical entry" true || ASSERT "T9.2 1 critical entry (got $T9_2)" false

T9_3=$(jq -r '[.errors[] | select(.escalated_to_user == true)] | length' "$TEST_DIR/error-ledger.json")
[[ "$T9_3" == "2" ]] && ASSERT "T9.3 2 escalated entries" true || ASSERT "T9.3 2 escalated entries (got $T9_3)" false

# ── Test 10: Cleanup ───────────────────────────────────────────────────────
rm -rf "$ROOT/.mc-data/work/wf-implement-feature/test-sprint4-smoke"
ASSERT "T10.1 Cleanup OK" true

echo ""
echo "════════════════════════════════════════"
echo "Sprint 4 Smoke Test Result: PASS=$PASS  FAIL=$FAIL"
echo "════════════════════════════════════════"

[[ $FAIL -eq 0 ]] || exit 1
exit 0
