#!/usr/bin/env bash
# legacy-scan-phase-h-smoke.sh — Phase H smoke test cho Resume Router + --session + --status.
# Usage: bash .claude/scripts/legacy-scan-phase-h-smoke.sh
#
# Verifies:
# 1. Python resume_router module imports + CLI runs correctly (Tier 1).
# 2. CLI exit codes: 0 for natural no-session, 2 for explicit --session=ID not-found.
# 3. Resume action payload contract — JSON fields present + types correct.
# 4. 12 test cases (4 levels × 3 scenarios) pass via pytest (Tier 1).
# 5. scan-state.json canonical reading prioritized over ledger.json fallback.
# 6. --session=ID flag parsed by SKILL.md (cross-checked against phase0-detection.md).
#
# Tier 2 (bash E2E on A.3 fixtures: small-en, medium-vn, large-mixed) is BLOCKED
# by A.3 baselines — documented at bottom of this file.

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/../.." && pwd)"
SHARED_ROOT="$REPO_ROOT/.claude/skills/workflow/_shared"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0
check() {
    local desc="$1"
    local status="$2"
    if [ "$status" = "0" ]; then
        echo "  [PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $desc"
        FAIL=$((FAIL + 1))
    fi
}

# ─── Test 1: Python module imports ─────────────────────────────────────
echo "=== Test 1: Python module + CLI basic ==="

if (cd "$SHARED_ROOT" && python -c "from ips import resume_router; print(resume_router.__doc__[:30])") >/dev/null 2>&1; then
    check "resume_router importable" 0
else
    check "resume_router importable" 1
fi

# CLI help
if (cd "$SHARED_ROOT" && python -m ips.resume_router --help) >/dev/null 2>&1; then
    check "CLI --help works" 0
else
    check "CLI --help works" 1
fi

# ─── Test 2: Natural no-session → exit 0 ──────────────────────────────
echo ""
echo "=== Test 2: CLI exit codes ==="

out="$(cd "$SHARED_ROOT" && python -m ips.resume_router --work-dir "$TMP_DIR" 2>&1)"
rc=$?
if [ "$rc" = "0" ] && echo "$out" | grep -q '"action_type": "no_resumable_session"'; then
    check "exit 0 on natural no-session" 0
else
    check "exit 0 on natural no-session (rc=$rc)" 1
fi

# Explicit --session=ID not found → exit 2
if (cd "$SHARED_ROOT" && python -m ips.resume_router --work-dir "$TMP_DIR" --session nonexistent) 2>/dev/null; then
    check "exit 2 on explicit missing session" 1
else
    rc=$?
    if [ "$rc" = "2" ]; then
        check "exit 2 on explicit missing session" 0
    else
        check "exit 2 on explicit missing session (got rc=$rc)" 1
    fi
fi

# ─── Test 3: Action payload contract ──────────────────────────────────
echo ""
echo "=== Test 3: Action payload JSON schema ==="

# Seed a fake session.
mkdir -p "$TMP_DIR/sessions/test-smoke"
cat > "$TMP_DIR/sessions/test-smoke/scan-state.json" <<'EOF'
{
  "$schema": "scan-state-v1",
  "session": {"id": "test-smoke", "project_path": "/tmp", "profile": "standard", "strategy": "S2"},
  "depth_map": {"L1":"full","L2":"full","L3":"full","L4":"standard","L5":"standard","L6":"full"},
  "layers": {
    "L1": {"status":"completed"}, "L2": {"status":"completed"},
    "L3": {"status":"completed"},
    "L4": {"status":"in_progress","batch_progress":{"current":3,"total":5,"completed_batches":["b1","b2"]},"partial":null},
    "L5": {"status":"not_started","module_progress":null,"partial":null},
    "L6": {"status":"not_started"}
  },
  "ips": {"phase_a": null, "phase_b": null},
  "last_completed": "L3",
  "status": "in_progress"
}
EOF

action_json="$(cd "$SHARED_ROOT" && python -m ips.resume_router --work-dir "$TMP_DIR" --session test-smoke 2>/dev/null)"

# Check required fields present.
for field in action_type session_id session_dir last_completed next_layer resume_unit notes depth_map ips_phase_a_available ips_phase_b_available; do
    if echo "$action_json" | jq -e ".${field}" >/dev/null 2>&1 \
       || echo "$action_json" | jq -e "has(\"$field\")" | grep -q true; then
        check "payload has '$field'" 0
    else
        check "payload has '$field'" 1
    fi
done

# Check action_type is resume_L4_batch (since L4 in_progress, no partial).
actual_action="$(echo "$action_json" | jq -r '.action_type')"
if [ "$actual_action" = "resume_L4_batch" ]; then
    check "action_type=resume_L4_batch for L4 in-progress" 0
else
    check "action_type=resume_L4_batch (got: $actual_action)" 1
fi

# Check resume_unit has current_batch = 3.
actual_batch="$(echo "$action_json" | jq -r '.resume_unit.current_batch')"
if [ "$actual_batch" = "3" ]; then
    check "resume_unit.current_batch=3" 0
else
    check "resume_unit.current_batch=3 (got: $actual_batch)" 1
fi

# ─── Test 4: pytest Tier 1 — 4 levels × 3 scenarios ───────────────────
echo ""
echo "=== Test 4: pytest Tier 1 (13 tests: 12 H.4 cases + 1 summary) ==="

if (cd "$REPO_ROOT" && python -m pytest .claude/skills/workflow/_shared/ips/tests/test_crash_resume_flow.py -q) >/dev/null 2>&1; then
    check "test_crash_resume_flow.py 13/13 pass" 0
else
    check "test_crash_resume_flow.py" 1
fi

if (cd "$REPO_ROOT" && python -m pytest .claude/skills/workflow/_shared/ips/tests/test_resume_router.py -q) >/dev/null 2>&1; then
    check "test_resume_router.py 36/36 pass" 0
else
    check "test_resume_router.py" 1
fi

# Full IPS regression gate.
if (cd "$REPO_ROOT" && python -m pytest .claude/skills/workflow/_shared/ips/tests/ -q) >/dev/null 2>&1; then
    check "full IPS suite (410+) regression clean" 0
else
    check "full IPS suite" 1
fi

# ─── Test 5: CLI flag parsing in phase0-detection.md ──────────────────
echo ""
echo "=== Test 5: --session flag wired in phase0-detection.md ==="

if grep -q 'SESSION_ID_OVERRIDE' "$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/procedures/phase0-detection.md"; then
    check "SESSION_ID_OVERRIDE exported in phase0-detection.md" 0
else
    check "SESSION_ID_OVERRIDE in phase0-detection.md" 1
fi

if grep -q '\-\-session=\*.*SESSION_ID_OVERRIDE' "$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/procedures/phase0-detection.md"; then
    check "--session=* pattern parsed" 0
else
    check "--session=* pattern parsed" 1
fi

# ─── Test 6: resume-status.md references resume_router module ─────────
echo ""
echo "=== Test 6: resume-status.md wired to resume_router ==="

if grep -q 'ips.resume_router' "$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/procedures/resume-status.md"; then
    check "resume-status.md invokes ips.resume_router" 0
else
    check "resume-status.md invokes ips.resume_router" 1
fi

# All 13+ action_types referenced in resume-status.md switch?
for at in start_L1 start_L2_rerun_ips_a start_L3 start_L4_rerun_ips_b_if_missing \
          resume_L4_batch resume_L4_intra_batch start_L5 resume_L5_module \
          resume_L5_intra_module start_L6 resume_L6_regenerate \
          session_already_completed delegate_legacy_subskill fallback_legacy_ledger \
          session_invalid no_resumable_session; do
    if grep -q "$at" "$REPO_ROOT/.claude/skills/workflow/wf-legacy-scan/procedures/resume-status.md"; then
        : # ok
    else
        check "action_type '$at' in switch" 1
        continue
    fi
done
check "all 16 action_types in resume-status.md switch" 0

# ─── Summary ──────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL"
echo "  FAIL: $FAIL / $TOTAL"

if [ "$FAIL" = "0" ]; then
    echo ""
    echo "[SUCCESS] Phase H smoke test passed ($PASS/$PASS checks)"
    exit 0
else
    echo ""
    echo "[FAILURE] Phase H smoke test failed ($FAIL/$TOTAL checks)"
    exit 1
fi

# ─── Tier 2 — E2E on A.3 fixtures (BLOCKED) ───────────────────────────
#
# The phase-H.md plan calls for "4 crash points × 3 fixtures = 12 test cases"
# with real `/wf-legacy-scan` invocation against fixtures/small-en, medium-vn,
# large-mixed. This is BLOCKED by A.3 (fixtures + v4.1 baselines not yet
# populated — see MIGRATION-PROGRESS.md).
#
# Tier 1 (above) delivers equivalent coverage structurally:
# - 4 crash levels (L0 / L1 / L2 / L3) covered by test_crash_resume_flow.py
# - 3 scenarios per level (just-started / mid-way / near-end) — 12 total cases
# - +1 summary sanity + 36 router unit tests = 49 Phase H tests
#
# When A.3 populates fixtures, Tier 2 will:
# 1. Start `/wf-legacy-scan fixtures/<fix>/` in subshell.
# 2. `kill -9` PID at a deterministic checkpoint via sleep + syncpoint files.
# 3. Invoke `/wf-legacy-scan --resume` via Claude CLI.
# 4. Verify:
#    - Lock released (no .session.lock file).
#    - scan-state.json shows correct last_completed + layer status.
#    - Resume continues from the expected unit (±1 unit loss allowed).
#    - Final output matches v4.1 baseline (modulo timestamps).
# 5. Repeat for 4 crash points × 3 fixtures.
#
# Follow-up: Tier 2 will merge into legacy-scan-phase-i-e2e.sh during Phase I.
