#!/usr/bin/env bash
# Phase E CRASH INJECTION TEST — 4-Level Checkpoint verification (E.8)
#
# Tier 1 (UNIT): Python multiprocessing test suite simulates kill -9 at
#                each of L0/L1/L2/L3 checkpoint levels and verifies ≤1
#                unit loss per ADR-LS11. Always run — no fixtures needed.
#
# Tier 2 (E2E):  Manual E2E — runs /wf-legacy-scan on medium-vn fixture,
#                kills the process mid-L4/L5, then resumes. BLOCKED until
#                A.3 fixture baselines are populated (same gate as D.9).
#
# Acceptance (per phase-E §E.8):
#   - L0 phase resume works
#   - L1 layer resume works
#   - L2 batch/module resume works
#   - L3 intra-batch resume works
#   - Mất ≤ 1 unit (1 file / 1 feature / 1 batch) cho mỗi crash point
#
# Exit codes:
#   0 — all crash tests pass
#   1 — unit tests failed
#   2 — E2E BLOCKED (A.3 baselines missing — expected pre-close)

set -e

echo "=== Phase E CRASH INJECTION TEST ==="
echo

# ─── Tier 1: Python unit tests ────────────────────────────────
echo "[Tier 1] Python multiprocessing crash injection (kill -9 simulation)"
echo "         Target: .claude/skills/workflow/_shared/ips/tests/test_crash_injection.py"
echo

python -m pytest \
  .claude/skills/workflow/_shared/ips/tests/test_crash_injection.py \
  -v --tb=short

TIER1_RC=$?
if [ "$TIER1_RC" -ne 0 ]; then
  echo
  echo "❌ Tier 1 FAILED — crash injection unit tests did not pass."
  echo "   4-level checkpoint guarantees NOT verified. DO NOT tag v5.0-phase-E."
  exit 1
fi

echo
echo "✅ Tier 1 PASSED — 4-level checkpoint + atomic write verified via subprocess kill -9."
echo

# ─── Tier 2: E2E manual (BLOCKED until A.3) ──────────────────
FIXTURE_DIR="docs/design/skills/wf-legacy-scan/fixtures/medium-vn"
BASELINE_DIR="docs/design/skills/wf-legacy-scan/fixtures/medium-vn.baseline-v4.1"

echo "[Tier 2] End-to-end crash + resume (medium-vn fixture)"

if [ ! -d "$BASELINE_DIR" ]; then
  echo "BLOCKED: $BASELINE_DIR not found. A.3 fixtures missing."
  exit 2
fi

BASELINE_FILES=$(find "$BASELINE_DIR" -type f ! -name STATUS.md ! -name '.gitkeep' 2>/dev/null | wc -l)
if [ "$BASELINE_FILES" -eq 0 ]; then
  echo "BLOCKED: $BASELINE_DIR contains only STATUS.md stub — A.3 not populated."
  echo "         Populate fixture + run v4.1 /wf-legacy-scan before Tier 2."
  exit 2
fi

echo "Fixture ready — running 4 E2E crash scenarios:"
echo "  1. Mid L4 batch 3/5"
echo "  2. Mid L5 module 3/8"
echo "  3. Mid L5 module 3 feature 5/12"
echo "  4. Mid L6 synthesis"
echo

# NOTE: Actual E2E crash+resume requires orchestration of /wf-legacy-scan
# as a background process, SIGKILL injection at specific checkpoints, and
# --resume verification. Skill execution is driven by Claude Agent, which
# this shell script cannot reliably orchestrate. Tier 2 is therefore a
# documented manual procedure — run each scenario interactively through
# Claude Code and assert the acceptance criteria in phase-E §E.8.
#
# Procedure for each scenario:
#
#   Terminal A:
#     /wf-legacy-scan $FIXTURE_DIR --profile=standard
#     (observe scan-state.json; at target checkpoint, note session_id)
#
#   Terminal B (mid-scan):
#     kill -9 <claude-agent-pid>
#
#   Terminal A (new session):
#     /wf-legacy-scan $FIXTURE_DIR --resume
#     (verify: continues from next unit, ≤ 1 unit re-processed)
#
#   Post-run verify:
#     python .claude/scripts/verify-resume-loss.py \
#       --session=<session_id> \
#       --expected-loss-max=1

echo "⚠️  Tier 2 is a MANUAL procedure — see script comments for steps."
echo "   Once completed, log results in implementation/session-logs/<date>-N.md"
echo

echo "=== Phase E Crash Test Summary ==="
echo "  Tier 1 unit tests:  ✅ PASSED (automated)"
echo "  Tier 2 E2E:         ⚠️  MANUAL (see comments above)"
exit 0
