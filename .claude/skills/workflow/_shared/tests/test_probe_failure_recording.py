"""Test (HIGH-6 v9.0.3): probe-failures.log recording mechanism — static checks.

Bug class: v9.0.0 fantasy pattern — orchestrator-dispatched probes (QD9 runtime,
QD10 cross-module, QD2 domain expert) khi fail KHONG ghi vao probe-failures.log
→ probe_failures_count = 0 → POST-GATE T5 + E005 healthy gate silent pass.

Note: Subprocess-based behavior tests duoc viet o bash format trong
`wf-fix-bugs/evals/regression-tests/test-probe-failure-recording.sh`
(Python subprocess.run + bash args khong hoat dong dang tin tren Windows Git Bash).
Test Python o day chi check static structural invariants.
"""
from __future__ import annotations

from pathlib import Path

# tests/test_X.py → _shared → workflow → skills → .claude → REPO_ROOT
REPO_ROOT = Path(__file__).resolve().parents[5]
HELPER_SCRIPT = REPO_ROOT / ".claude" / "scripts" / "wf-fix-record-probe-failure.sh"


class TestProbeFailureRecordingStatic:
    """Static structural checks — chay tren moi platform."""

    def test_helper_script_exists(self) -> None:
        """wf-fix-record-probe-failure.sh PHAI ton tai (CRIT-2 fix anchor)."""
        assert HELPER_SCRIPT.is_file(), f"Helper script missing: {HELPER_SCRIPT}"

    def test_helper_script_documents_required_args(self) -> None:
        """Helper script PHAI document required args trong header comment."""
        content = HELPER_SCRIPT.read_text(encoding="utf-8")
        for arg in ["--session-dir", "--lane", "--probe-id", "--reason"]:
            assert arg in content, f"Helper script missing doc for {arg}"

    def test_helper_script_writes_to_probe_failures_log(self) -> None:
        """Helper PHAI ghi vao probe-failures.log (khop schema lane_dispatch._log_probe_failure)."""
        content = HELPER_SCRIPT.read_text(encoding="utf-8")
        assert "probe-failures.log" in content, \
            "Helper must write to probe-failures.log (compatible voi _load_probe_failures aggregator)"
        # Schema khop _log_probe_failure: timestamp, lane, probe_id, reason, returncode, stderr_snippet
        for field in ["timestamp", "lane", "probe_id", "reason", "returncode", "stderr_snippet"]:
            assert field in content, f"Helper must record field {field} (matching lane_dispatch schema)"

    def test_helper_marks_orchestrator_source(self) -> None:
        """Record PHAI co source='orchestrator_agent_dispatch' (distinguish vs lane_dispatch)."""
        content = HELPER_SCRIPT.read_text(encoding="utf-8")
        assert "orchestrator_agent_dispatch" in content, \
            "Helper must mark records voi source='orchestrator_agent_dispatch' de phan biet"

    def test_phase1_engine_documents_helper_usage(self) -> None:
        """v10.0: probe failure recording documented trong _shared.md + phase4-find-bugs.md."""
        shared_md = (
            REPO_ROOT
            / ".claude" / "skills" / "workflow" / "wf-fix-bugs"
            / "procedures" / "_shared.md"
        )
        phase4_md = (
            REPO_ROOT
            / ".claude" / "skills" / "workflow" / "wf-fix-bugs"
            / "procedures" / "phase4-find-bugs.md"
        )
        shared_content = shared_md.read_text(encoding="utf-8")
        phase4_content = phase4_md.read_text(encoding="utf-8")
        combined = shared_content + phase4_content
        assert "probe-failures.log" in combined, \
            "v10.0 must reference probe-failures.log (anti-fantasy anchor)"
        assert "E041" in combined and "E042" in combined, \
            "v10.0 must document probe failure error codes E041/E042"
        # Document standard failure handling
        assert "probe" in combined.lower(), \
            "v10.0 must document probe failure handling"

    def test_aggregator_loads_probe_failures(self) -> None:
        """signal_aggregator._load_probe_failures() ton tai va doc dung schema."""
        import sys
        sys.path.insert(0, str(REPO_ROOT / ".claude" / "skills" / "workflow" / "_shared"))
        from signal_aggregator import _load_probe_failures
        # Function ton tai → import success
        assert callable(_load_probe_failures)
        # Empty session_dir → return [] (no error)
        import tempfile
        with tempfile.TemporaryDirectory() as td:
            failures = _load_probe_failures(Path(td))
            assert failures == [], "Empty session_dir should return [] (graceful fallback)"
