#!/usr/bin/env bash
# Stage 7 Smoke Test — 7 scenarios from v3.0-e2e-integration-plan.md §7.2
# Mục đích: Validate args parsing + mutual exclusion + CDG E195b decision logic
# Test deterministic — KHÔNG cần Playwright thực tế, KHÔNG cần spawn agents
#
# Usage: bash test-stage7-smoke.sh

set -e

PASS=0
FAIL=0
RESULTS=""

assert_eq() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS+1))
    RESULTS="${RESULTS}\n  ✓ ${name}: PASS"
  else
    FAIL=$((FAIL+1))
    RESULTS="${RESULTS}\n  ✗ ${name}: FAIL — expected='$expected', actual='$actual'"
  fi
}

echo "=== Stage 7 Smoke Test — 7 scenarios §7.2 ==="
echo ""

# ─────────────────────────────────────────────────────────────────
# Simulate phase1-init.md Step 1.1.7b validate_v3_args logic
# ─────────────────────────────────────────────────────────────────
validate_v3_args() {
  local exec="$1" so="$2" se="$3" sb="$4" mb="$5" np="$6" afs="$7" sid="$8" resume="$9" ci="${10}"
  local stop_code=""
  local warn_codes=""

  # Pre-set adjusted values (echoed at end)
  local adj_se="$se"
  local adj_sb="$sb"
  local adj_mb="$mb"
  local adj_np="$np"
  local adj_afs="$afs"

  # --scenarios-only requires --session-id
  if [ "$so" = "true" ]; then
    [ -z "$sid" ] && { stop_code="E016b-no-session-id"; echo "$stop_code|"; return; }
    [ "$resume" = "true" ] && { stop_code="E016b-scenarios-only-resume-conflict"; echo "$stop_code|"; return; }
  fi

  # --strict-evidence requires --exec-scenarios
  if [ "$se" = "true" ] && [ "$exec" != "true" ]; then
    warn_codes="${warn_codes}E101-strict-evidence-no-exec,"
    adj_se="false"
  fi

  # --show-browser / --mobile only with --exec-scenarios
  if [ "$exec" != "true" ]; then
    if [ "$sb" = "true" ] || [ "$mb" = "true" ]; then
      warn_codes="${warn_codes}E101-browser-mobile-no-exec,"
      adj_sb="false"
      adj_mb="false"
    fi
  fi

  # --no-prompt + --auto-fix-source: CI auto-confirm
  if [ "$np" = "true" ] && [ "$afs" = "true" ]; then
    warn_codes="${warn_codes}E101-no-prompt-auto-fix,"
  fi

  # --auto-fix-source without --exec-scenarios is no-op
  if [ "$afs" = "true" ] && [ "$exec" != "true" ]; then
    warn_codes="${warn_codes}E101-auto-fix-no-exec,"
  fi

  # --ci + --exec-scenarios → auto-set --no-prompt
  if [ "$ci" = "true" ] && [ "$exec" = "true" ] && [ "$np" != "true" ]; then
    warn_codes="${warn_codes}E100-ci-auto-no-prompt,"
    adj_np="true"
  fi

  echo "|${warn_codes}|exec=$exec,so=$so,se=$adj_se,sb=$adj_sb,mb=$adj_mb,np=$adj_np,afs=$adj_afs"
}

# ─────────────────────────────────────────────────────────────────
# Simulate phase1-init.md Step 1.14b CDG E195b decision logic
# ─────────────────────────────────────────────────────────────────
compute_e195b() {
  local exec="$1" profile="$2" np="$3" so="$4" user_choice="${5:-}"
  local decision="not_triggered"
  local cd41_force="false"
  local cd41_sev=""

  if [ "$exec" = "true" ] \
     && { [ "$profile" = "quick" ] || [ "$profile" = "standard" ]; } \
     && [ "$np" != "true" ] \
     && [ "$so" != "true" ]; then
    # AskUserQuestion would fire — simulate via $user_choice
    decision="${user_choice:-execute_must_only}"  # Default if no choice = MUST-only
    case "$decision" in
      execute_all)        cd41_force="true"; cd41_sev="MUST,HIGH" ;;
      execute_must_only)  cd41_force="true"; cd41_sev="MUST" ;;
      cancel)             cd41_force="false"; cd41_sev=""; ;;
    esac
  elif [ "$exec" = "true" ] \
       && { [ "$profile" = "quick" ] || [ "$profile" = "standard" ]; } \
       && [ "$np" = "true" ]; then
    # CI mode silent default
    decision="execute_must_only"
    cd41_force="true"
    cd41_sev="MUST"
  fi

  echo "decision=$decision,cd41_force=$cd41_force,cd41_sev=$cd41_sev"
}

# ─────────────────────────────────────────────────────────────────
# G7.2 Scenario 1: v2 backward-compat (no exec flag)
# Expected: All v3 flags = false, no CDG E195b trigger, phase 1-8 only
# ─────────────────────────────────────────────────────────────────
echo "── G7.2.1: v2 backward-compat (/wf-cmi --profile=standard) ──"
RESULT=$(validate_v3_args "false" "false" "false" "false" "false" "false" "false" "" "false" "false")
STOP=$(echo "$RESULT" | cut -d'|' -f1)
WARN=$(echo "$RESULT" | cut -d'|' -f2)
ADJ=$(echo "$RESULT" | cut -d'|' -f3)
assert_eq "S1.validate.no_stop" "" "$STOP"
assert_eq "S1.validate.no_warn" "" "$WARN"
E195B=$(compute_e195b "false" "standard" "false" "false")
assert_eq "S1.e195b.not_triggered" "decision=not_triggered,cd41_force=false,cd41_sev=" "$E195B"

# ─────────────────────────────────────────────────────────────────
# G7.2 Scenario 2: CD41 synth only (deep no exec)
# Expected: All v3 flags = false, no CDG E195b trigger
# ─────────────────────────────────────────────────────────────────
echo ""
echo "── G7.2.2: CD41 synth only (/wf-cmi --profile=deep — no exec) ──"
RESULT=$(validate_v3_args "false" "false" "false" "false" "false" "false" "false" "" "false" "false")
STOP=$(echo "$RESULT" | cut -d'|' -f1)
assert_eq "S2.validate.no_stop" "" "$STOP"
E195B=$(compute_e195b "false" "deep" "false" "false")
assert_eq "S2.e195b.not_triggered" "decision=not_triggered,cd41_force=false,cd41_sev=" "$E195B"

# ─────────────────────────────────────────────────────────────────
# G7.2 Scenario 3: Full exec deep
# Expected: All v3 flags as set, no CDG E195b (deep auto-run)
# ─────────────────────────────────────────────────────────────────
echo ""
echo "── G7.2.3: Full exec deep (/wf-cmi --profile=deep --exec-scenarios) ──"
RESULT=$(validate_v3_args "true" "false" "false" "false" "false" "false" "false" "" "false" "false")
STOP=$(echo "$RESULT" | cut -d'|' -f1)
WARN=$(echo "$RESULT" | cut -d'|' -f2)
assert_eq "S3.validate.no_stop" "" "$STOP"
assert_eq "S3.validate.no_warn" "" "$WARN"
E195B=$(compute_e195b "true" "deep" "false" "false")
assert_eq "S3.e195b.not_triggered_deep" "decision=not_triggered,cd41_force=false,cd41_sev=" "$E195B"

# ─────────────────────────────────────────────────────────────────
# G7.2 Scenario 4: Subset exec quick (--exec-scenarios + profile=quick)
# Expected: CDG E195b trigger, default MUST-only
# ─────────────────────────────────────────────────────────────────
echo ""
echo "── G7.2.4: Subset exec quick (/wf-cmi --profile=quick --exec-scenarios) ──"
RESULT=$(validate_v3_args "true" "false" "false" "false" "false" "false" "false" "" "false" "false")
STOP=$(echo "$RESULT" | cut -d'|' -f1)
assert_eq "S4.validate.no_stop" "" "$STOP"
# G7.3 part 1: AskUserQuestion would fire — simulate user_choice=execute_must_only (default)
E195B=$(compute_e195b "true" "quick" "false" "false" "execute_must_only")
assert_eq "S4.e195b.must_only" "decision=execute_must_only,cd41_force=true,cd41_sev=MUST" "$E195B"
# G7.3 part 2: User chooses Cancel
E195B_CANCEL=$(compute_e195b "true" "quick" "false" "false" "cancel")
assert_eq "S4.e195b.cancel" "decision=cancel,cd41_force=false,cd41_sev=" "$E195B_CANCEL"
# G7.3 part 3: User chooses Execute all
E195B_ALL=$(compute_e195b "true" "quick" "false" "false" "execute_all")
assert_eq "S4.e195b.execute_all" "decision=execute_all,cd41_force=true,cd41_sev=MUST,HIGH" "$E195B_ALL"

# ─────────────────────────────────────────────────────────────────
# G7.2 Scenario 5: Scenarios-only resume
# Expected: requires --session-id, mutex with --resume
# ─────────────────────────────────────────────────────────────────
echo ""
echo "── G7.2.5: Scenarios-only resume (/wf-cmi --scenarios-only --session-id=<id>) ──"
# Test 5a: --scenarios-only without --session-id → E016b STOP
RESULT=$(validate_v3_args "false" "true" "false" "false" "false" "false" "false" "" "false" "false")
STOP=$(echo "$RESULT" | cut -d'|' -f1)
assert_eq "S5a.scenarios_only_no_session_id.stop" "E016b-no-session-id" "$STOP"
# Test 5b: --scenarios-only + --resume → E016b STOP
RESULT=$(validate_v3_args "false" "true" "false" "false" "false" "false" "false" "session-id-foo" "true" "false")
STOP=$(echo "$RESULT" | cut -d'|' -f1)
assert_eq "S5b.scenarios_only_resume_mutex.stop" "E016b-scenarios-only-resume-conflict" "$STOP"
# Test 5c: --scenarios-only + --session-id valid → no stop
RESULT=$(validate_v3_args "false" "true" "false" "false" "false" "false" "false" "session-id-foo" "false" "false")
STOP=$(echo "$RESULT" | cut -d'|' -f1)
assert_eq "S5c.scenarios_only_session_ok" "" "$STOP"

# ─────────────────────────────────────────────────────────────────
# G7.2 Scenario 6: Browser unavailable
# (simulated — would be Phase 9 PRE-GATE T2 not Phase 1)
# ─────────────────────────────────────────────────────────────────
echo ""
echo "── G7.2.6: Browser unavailable (Phase 9 PRE-GATE — E150 graceful) ──"
# This is a Phase 9 logic — Stage 7 only verifies Phase 1 args pass through
RESULT=$(validate_v3_args "true" "false" "false" "false" "false" "false" "false" "" "false" "false")
STOP=$(echo "$RESULT" | cut -d'|' -f1)
assert_eq "S6.phase1_args_pass" "" "$STOP"
# Phase 9 would emit E150 SKIP — Stage 7 does not test Phase 9 execution

# ─────────────────────────────────────────────────────────────────
# G7.2 Scenario 7: Strict evidence
# Expected: --strict-evidence + --exec-scenarios works; --strict-evidence alone → WARN E101
# ─────────────────────────────────────────────────────────────────
echo ""
echo "── G7.2.7: Strict evidence (/wf-cmi --profile=deep --exec-scenarios --strict-evidence) ──"
RESULT=$(validate_v3_args "true" "false" "true" "false" "false" "false" "false" "" "false" "false")
ADJ=$(echo "$RESULT" | cut -d'|' -f3)
assert_eq "S7.strict_evidence_with_exec" "exec=true,so=false,se=true,sb=false,mb=false,np=false,afs=false" "$ADJ"
# Test 7b: --strict-evidence WITHOUT --exec-scenarios → WARN + ignore flag
RESULT_B=$(validate_v3_args "false" "false" "true" "false" "false" "false" "false" "" "false" "false")
WARN_B=$(echo "$RESULT_B" | cut -d'|' -f2)
ADJ_B=$(echo "$RESULT_B" | cut -d'|' -f3)
[[ "$WARN_B" == *"E101-strict-evidence-no-exec"* ]] && assert_eq "S7b.strict_evidence_no_exec.warn" "found" "found" \
                                                    || assert_eq "S7b.strict_evidence_no_exec.warn" "found" "missing"
assert_eq "S7b.strict_evidence_no_exec.adj_se_off" "exec=false,so=false,se=false,sb=false,mb=false,np=false,afs=false" "$ADJ_B"

# ─────────────────────────────────────────────────────────────────
# G7.4: --no-prompt bypass test (CI mode)
# Expected: --no-prompt + profile=quick + --exec-scenarios → silent default execute_must_only
# ─────────────────────────────────────────────────────────────────
echo ""
echo "── G7.4: --no-prompt bypass (CI mode, no AskUserQuestion) ──"
E195B_CI=$(compute_e195b "true" "quick" "true" "false")
assert_eq "G7.4.no_prompt_silent_default" "decision=execute_must_only,cd41_force=true,cd41_sev=MUST" "$E195B_CI"
# Also verify CI mode flag auto-set --no-prompt when --ci + --exec-scenarios
RESULT_CI=$(validate_v3_args "true" "false" "false" "false" "false" "false" "false" "" "false" "true")
WARN_CI=$(echo "$RESULT_CI" | cut -d'|' -f2)
ADJ_CI=$(echo "$RESULT_CI" | cut -d'|' -f3)
[[ "$WARN_CI" == *"E100-ci-auto-no-prompt"* ]] && assert_eq "G7.4.ci_auto_no_prompt.warn" "found" "found" \
                                              || assert_eq "G7.4.ci_auto_no_prompt.warn" "found" "missing"
[[ "$ADJ_CI" == *"np=true"* ]] && assert_eq "G7.4.ci_auto_no_prompt.adj_np_true" "found" "found" \
                              || assert_eq "G7.4.ci_auto_no_prompt.adj_np_true" "found" "missing"

# ─────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo ""
echo "=========================================="
echo "Results: $PASS/$TOTAL PASS, $FAIL/$TOTAL FAIL"
echo "=========================================="
echo -e "$RESULTS"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
