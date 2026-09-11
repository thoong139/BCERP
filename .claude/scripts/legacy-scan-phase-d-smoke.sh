#!/usr/bin/env bash
# Phase D integration smoke test.
# Exercises standalone sub-skill fallback scenarios (D.8):
#   Case 1: helper auto-migrates v4.1 ledger.json → scan-state session
#   Case 2: resume from active session
#   Case 3: no prior scan → RuntimeError
#
# Plus verifies the new API functions from D.1 work end-to-end on a
# synthetic fixture (no AI spawn — purely Python helper round-trip).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SHARED_DIR="$REPO_ROOT/.claude/skills/workflow/_shared"

echo "=== Phase D Smoke Test ==="
echo "Repo: $REPO_ROOT"
echo "Shared: $SHARED_DIR"
echo

cd "$SHARED_DIR"

# Use PYTHONIOENCODING to avoid cp1252 issues on Windows.
export PYTHONIOENCODING=utf-8

python - <<'PY'
import sys, tempfile, json
from pathlib import Path

sys.path.insert(0, ".")
from ips import scan_state_reader as ssr

PASS = 0
FAIL = 0

def check(cond, msg):
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"  [OK] {msg}")
    else:
        FAIL += 1
        print(f"  [FAIL] {msg}")


# ─── Case 1: migration from v4.1 ledger.json ────────────────
print("Case 1: Standalone after v4.1 scan (migrate from ledger.json)")
with tempfile.TemporaryDirectory() as tmp:
    work_dir = Path(tmp) / ".mc-data" / "work" / "legacy-scan"
    work_dir.mkdir(parents=True)
    ssr.WORK_DIR = work_dir

    ledger = {
        "project": {"name": "smoke-test", "path": "/test"},
        "strategy": {"id": "S2"},
        "maturity": {"maturity_level": "CODE_ONLY"},
        "stages": {
            "inventory": {"status": "completed"},
            "classify": {"status": "completed"},
            "extract": {"status": "not_started"},
            "synthesize": {"status": "not_started"},
        },
    }
    (work_dir / "ledger.json").write_text(
        json.dumps(ledger), encoding="utf-8"
    )

    sid = ssr.init_or_load_session(Path("/test"))
    check(bool(sid), f"Session created: {sid}")

    state = ssr.read_scan_state(sid)
    check(
        state["layers"]["L4"]["status"] == "completed",
        "L4 migrated as completed (classify was done)",
    )
    check(
        state["layers"]["L5"]["status"] == "not_started",
        "L5 migrated as not_started (extract pending)",
    )
    check(
        state["session"].get("migrated_from_legacy") is True,
        "session.migrated_from_legacy flag set",
    )

    # Sub-skill can now transition L5
    ssr.update_layer_status("L5", "in_progress")
    ssr.append_layer_output("L5", "extracted/billing.json")
    ssr.update_module_progress("L5", "billing", "completed")
    ssr.update_layer_status("L5", "completed")

    state2 = ssr.read_scan_state(sid)
    check(
        state2["layers"]["L5"]["status"] == "completed",
        "L5 completed via helper",
    )
    check(
        "extracted/billing.json" in state2["layers"]["L5"]["outputs"],
        "append_layer_output persisted",
    )
    check(
        "billing" in state2["layers"]["L5"]["module_progress"]["completed"],
        "update_module_progress persisted",
    )

# ─── Case 2: resume from active session ─────────────────────
print()
print("Case 2: Resume from active session")
with tempfile.TemporaryDirectory() as tmp:
    work_dir = Path(tmp) / ".mc-data" / "work" / "legacy-scan"
    (work_dir / "sessions" / "existing-sid").mkdir(parents=True)
    ssr.WORK_DIR = work_dir

    # Pre-seed an active session with scan-state.json
    state = {
        "$schema": "scan-state-v1",
        "session": {"id": "existing-sid", "project_path": "/test"},
        "layers": {
            f"L{i}": {"status": "not_started", "outputs": []}
            for i in range(1, 7)
        },
        "status": "in_progress",
        "depth_map": {
            "L1": "full", "L2": "full", "L3": "full",
            "L4": "deep", "L5": "deep", "L6": "full",
        },
        "ips": {"phase_a": {"recommended_profile": "deep"}, "phase_b": None},
        "error_log": [],
    }
    (work_dir / "sessions" / "existing-sid" / "scan-state.json").write_text(
        json.dumps(state), encoding="utf-8"
    )

    sid = ssr.init_or_load_session(Path("/test"))
    check(sid == "existing-sid", f"Active session returned as-is: {sid}")

    depth = ssr.read_depth_map()
    check(depth["L5"] == "deep", f"read_depth_map returns deep for L5")

    phase_a = ssr.read_ips_phase_a()
    check(
        phase_a.get("recommended_profile") == "deep",
        "read_ips_phase_a returns populated data",
    )

# ─── Case 3: no prior scan → RuntimeError ──────────────────
print()
print("Case 3: No prior scan (fresh project)")
with tempfile.TemporaryDirectory() as tmp:
    work_dir = Path(tmp) / ".mc-data" / "work" / "legacy-scan"
    ssr.WORK_DIR = work_dir

    try:
        ssr.init_or_load_session(Path("/test"))
        check(False, "Expected RuntimeError but got none")
    except RuntimeError as e:
        check("No prior scan" in str(e), "RuntimeError raised with expected message")

# ─── Case 4: domain expert confidence threshold ─────────────
print()
print("Case 4: get_domain_expert_for_module threshold enforcement")
with tempfile.TemporaryDirectory() as tmp:
    work_dir = Path(tmp) / ".mc-data" / "work" / "legacy-scan"
    (work_dir / "sessions" / "exp-sid").mkdir(parents=True)
    ssr.WORK_DIR = work_dir

    state = {
        "$schema": "scan-state-v1",
        "session": {"id": "exp-sid", "project_path": "/test"},
        "layers": {
            f"L{i}": {"status": "not_started", "outputs": []}
            for i in range(1, 7)
        },
        "status": "in_progress",
        "ips": {
            "phase_a": None,
            "phase_b": {
                "module_routing": {
                    "strong_mod": {
                        "expert": "finance-expert",
                        "confidence": 0.85,
                    },
                    "weak_mod": {
                        "expert": "operations-expert",
                        "confidence": 0.45,
                    },
                },
            },
        },
        "error_log": [],
    }
    (work_dir / "sessions" / "exp-sid" / "scan-state.json").write_text(
        json.dumps(state), encoding="utf-8"
    )

    strong = ssr.get_domain_expert_for_module("strong_mod")
    check(strong == "finance-expert", f"Strong module (0.85) → {strong}")

    weak = ssr.get_domain_expert_for_module("weak_mod")
    check(weak is None, f"Weak module (0.45) → None (below threshold)")

    missing = ssr.get_domain_expert_for_module("nonexistent")
    check(missing is None, "Missing module → None")


print()
print(f"=== SUMMARY ===")
print(f"Passed: {PASS}")
print(f"Failed: {FAIL}")
sys.exit(0 if FAIL == 0 else 1)
PY

RC=$?
echo
if [ $RC -eq 0 ]; then
  echo "Phase D smoke test: PASS"
else
  echo "Phase D smoke test: FAIL (rc=$RC)"
fi
exit $RC
