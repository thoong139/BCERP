"""Tests for resume_router.py — Phase H implementation.

Coverage:
- decide_resume_action: pure state → action mapping cho mọi routing
  table row (12 cases) + schema validation.
- route_resume: full discover → read → decide loop.
- CLI entry: JSON output + exit codes.
- Edge cases: no session, corrupt scan-state, legacy ledger fallback,
  partial.json loss.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import resume_router as rr  # noqa: E402
from ips import scan_state_reader as ssr  # noqa: E402


# ─── Fixtures ────────────────────────────────────────────────


def _base_state(
    last_completed: str = "init",
    session_status: str = "in_progress",
) -> dict:
    """Minimal valid scan-state dict."""
    return {
        "$schema": "scan-state-v1",
        "session": {
            "id": "2026-04-22T10-00-00",
            "project_path": "/test",
            "profile": "standard",
            "strategy": "S2",
        },
        "depth_map": {
            "L1": "full",
            "L2": "full",
            "L3": "full",
            "L4": "standard",
            "L5": "standard",
            "L6": "full",
        },
        "layers": {
            "L1": {"name": "discovery", "status": "not_started"},
            "L2": {"name": "assessment", "status": "not_started"},
            "L3": {"name": "inventory", "status": "not_started"},
            "L4": {
                "name": "classification",
                "status": "not_started",
                "batch_progress": None,
                "partial": None,
            },
            "L5": {
                "name": "extraction",
                "status": "not_started",
                "module_progress": None,
                "partial": None,
            },
            "L6": {"name": "synthesis", "status": "not_started"},
        },
        "ips": {"phase_a": None, "phase_b": None},
        "last_completed": last_completed,
        "status": session_status,
    }


@pytest.fixture
def work_dir(tmp_path, monkeypatch):
    """Setup mock work dir + reset throttle state."""
    wd = tmp_path / ".mc-data" / "work" / "legacy-scan"
    wd.mkdir(parents=True)
    monkeypatch.setattr(ssr, "WORK_DIR", wd)
    ssr._reset_throttle_state()  # type: ignore[attr-defined]
    return wd


def _write_session(work_dir: Path, session_id: str, state: dict) -> Path:
    session_dir = work_dir / "sessions" / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    (session_dir / "scan-state.json").write_text(
        json.dumps(state, indent=2), encoding="utf-8"
    )
    return session_dir


# ─── decide_resume_action — pure routing table ──────────────


class TestDecideResumeActionTerminals:
    def test_session_completed(self) -> None:
        state = _base_state(
            last_completed="L6", session_status="completed"
        )
        state["layers"]["L6"]["status"] = "completed"
        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_SESSION_COMPLETED
        assert action["next_layer"] is None

    def test_last_completed_completed(self) -> None:
        state = _base_state(last_completed="completed")
        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_SESSION_COMPLETED

    def test_migrated_delegates_legacy(self) -> None:
        state = _base_state(last_completed="migrated")
        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_DELEGATE_LEGACY
        assert any(
            "classify" in n or "extract" in n for n in action["notes"]
        )


class TestDecideResumeActionLayerStart:
    def test_init_starts_L1(self) -> None:
        action = rr.decide_resume_action(_base_state(last_completed="init"))
        assert action["action_type"] == rr.ACTION_START_L1
        assert action["next_layer"] == "L1"

    def test_L1_done_starts_L2_with_ips_rerun(self) -> None:
        action = rr.decide_resume_action(_base_state(last_completed="L1"))
        assert action["action_type"] == rr.ACTION_START_L2
        assert action["next_layer"] == "L2"
        assert any("IPS Phase A" in n for n in action["notes"])

    def test_L2_done_starts_L3(self) -> None:
        action = rr.decide_resume_action(_base_state(last_completed="L2"))
        assert action["action_type"] == rr.ACTION_START_L3
        assert action["next_layer"] == "L3"

    def test_L3_done_starts_L4_ips_b_missing(self) -> None:
        action = rr.decide_resume_action(_base_state(last_completed="L3"))
        assert action["action_type"] == rr.ACTION_START_L4
        assert action["next_layer"] == "L4"
        assert any("IPS Phase B" in n for n in action["notes"])

    def test_L3_done_starts_L4_ips_b_present(self) -> None:
        state = _base_state(last_completed="L3")
        state["ips"]["phase_b"] = {"domains": {"finance": 0.8}}
        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_START_L4
        # Shouldn't mention re-run when phase_b already present
        assert not any("re-run" in n for n in action["notes"])


class TestDecideResumeActionL4:
    def test_L4_completed_starts_L5(self) -> None:
        state = _base_state(last_completed="L4")
        state["layers"]["L4"]["status"] = "completed"
        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_START_L5
        assert action["next_layer"] == "L5"

    def test_L4_in_progress_batch_only(self) -> None:
        state = _base_state(last_completed="L4")
        state["layers"]["L4"]["status"] = "in_progress"
        state["layers"]["L4"]["batch_progress"] = {
            "current": "batch-003",
            "total": 5,
            "completed_batches": ["batch-001", "batch-002"],
        }
        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_RESUME_L4_BATCH
        assert action["resume_unit"]["current_batch"] == "batch-003"
        assert action["resume_unit"]["completed_batches"] == [
            "batch-001",
            "batch-002",
        ]

    def test_L4_in_progress_intra_batch(self, work_dir):
        """L4 với partial.json → intra-batch resume."""
        session_id = "2026-04-22T10-00-00"
        state = _base_state(last_completed="L4")
        state["layers"]["L4"]["status"] = "in_progress"
        state["layers"]["L4"]["batch_progress"] = {
            "current": "batch-003",
            "total": 5,
            "completed_batches": [],
        }
        state["layers"]["L4"]["partial"] = "layers/L4/partial.json"

        session_dir = _write_session(work_dir, session_id, state)
        # Write partial.json.
        partial_dir = session_dir / "layers" / "L4"
        partial_dir.mkdir(parents=True)
        (partial_dir / "partial.json").write_text(
            json.dumps(
                {
                    "$schema": "layer-partial-v1",
                    "layer": "L4",
                    "batch_id": "batch-003",
                    "completed_items": ["src/a.ts", "src/b.ts"],
                    "current_item": "src/c.ts",
                    "started": "2026-04-22T10:12:05Z",
                    "updated": "2026-04-22T10:12:40Z",
                },
                indent=2,
            ),
            encoding="utf-8",
        )

        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_RESUME_L4_INTRA_BATCH
        assert action["resume_unit"]["completed_items"] == [
            "src/a.ts",
            "src/b.ts",
        ]
        assert action["resume_unit"]["in_flight_item"] == "src/c.ts"

    def test_L4_partial_missing_file_falls_back_to_batch(
        self, work_dir
    ) -> None:
        """partial flag set nhưng partial.json không tồn tại → batch-level resume."""
        session_id = "2026-04-22T10-00-00"
        state = _base_state(last_completed="L4")
        state["layers"]["L4"]["status"] = "in_progress"
        state["layers"]["L4"]["batch_progress"] = {
            "current": "batch-004",
            "total": 5,
            "completed_batches": [],
        }
        state["layers"]["L4"]["partial"] = "layers/L4/partial.json"
        _write_session(work_dir, session_id, state)
        # Không ghi partial.json → _load_partial → None.

        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_RESUME_L4_BATCH


class TestDecideResumeActionL5:
    def test_L5_completed_starts_L6(self) -> None:
        state = _base_state(last_completed="L5")
        state["layers"]["L5"]["status"] = "completed"
        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_START_L6

    def test_L5_in_progress_module_only(self) -> None:
        state = _base_state(last_completed="L5")
        state["layers"]["L5"]["status"] = "in_progress"
        state["layers"]["L5"]["module_progress"] = {
            "current": "billing",
            "total": 8,
            "completed_modules": ["auth", "users"],
        }
        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_RESUME_L5_MODULE
        assert action["resume_unit"]["current_module"] == "billing"
        assert action["resume_unit"]["completed_modules"] == [
            "auth",
            "users",
        ]

    def test_L5_in_progress_intra_module(self, work_dir):
        session_id = "2026-04-22T10-00-00"
        state = _base_state(last_completed="L5")
        state["layers"]["L5"]["status"] = "in_progress"
        state["layers"]["L5"]["module_progress"] = {
            "current": "billing",
            "total": 8,
            "completed_modules": ["auth", "users"],
        }
        state["layers"]["L5"]["partial"] = "layers/L5/partial.json"

        session_dir = _write_session(work_dir, session_id, state)
        partial_dir = session_dir / "layers" / "L5"
        partial_dir.mkdir(parents=True)
        (partial_dir / "partial.json").write_text(
            json.dumps(
                {
                    "$schema": "layer-partial-v1",
                    "layer": "L5",
                    "module": "billing",
                    "completed_items": ["feature-1", "feature-2"],
                    "current_item": "feature-3",
                    "started": "2026-04-22T11:00:00Z",
                    "updated": "2026-04-22T11:05:00Z",
                },
                indent=2,
            ),
            encoding="utf-8",
        )

        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_RESUME_L5_INTRA_MODULE
        assert action["resume_unit"]["in_flight_item"] == "feature-3"
        assert len(action["resume_unit"]["completed_items"]) == 2


class TestDecideResumeActionL6:
    def test_L6_in_progress_regenerate(self) -> None:
        state = _base_state(last_completed="L6")
        state["layers"]["L6"]["status"] = "in_progress"
        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_RESUME_L6

    def test_L6_completed_session_done(self) -> None:
        state = _base_state(last_completed="L6")
        state["layers"]["L6"]["status"] = "completed"
        action = rr.decide_resume_action(state)
        assert action["action_type"] == rr.ACTION_SESSION_COMPLETED


class TestDecideResumeActionSchema:
    def test_missing_last_completed_raises(self) -> None:
        state = {"layers": {}, "status": "in_progress"}
        with pytest.raises(ValueError, match="last_completed"):
            rr.decide_resume_action(state)

    def test_missing_layers_raises(self) -> None:
        state = {"last_completed": "init", "status": "in_progress"}
        with pytest.raises(ValueError, match="layers"):
            rr.decide_resume_action(state)

    def test_non_dict_raises(self) -> None:
        with pytest.raises(ValueError, match="dict"):
            rr.decide_resume_action("not a dict")  # type: ignore[arg-type]

    def test_unknown_last_completed_raises(self) -> None:
        state = _base_state(last_completed="L99")
        with pytest.raises(ValueError, match="Unknown last_completed"):
            rr.decide_resume_action(state)


# ─── route_resume — full flow ────────────────────────────────


class TestRouteResumeDiscovery:
    def test_no_session_returns_no_resumable(self, work_dir) -> None:
        action = rr.route_resume()
        assert action["action_type"] == rr.ACTION_NO_RESUMABLE
        assert action["session_id"] is None

    def test_completed_session_not_auto_discovered(
        self, work_dir
    ) -> None:
        state = _base_state(last_completed="L6", session_status="completed")
        state["layers"]["L6"]["status"] = "completed"
        _write_session(work_dir, "old-complete", state)
        # get_active_session_dir filters out completed — no_resumable.
        action = rr.route_resume()
        assert action["action_type"] == rr.ACTION_NO_RESUMABLE

    def test_explicit_session_id(self, work_dir) -> None:
        state = _base_state(last_completed="L2")
        _write_session(work_dir, "2026-04-22T10-00-00", state)
        action = rr.route_resume(session_id="2026-04-22T10-00-00")
        assert action["action_type"] == rr.ACTION_START_L3
        assert action["session_id"] == "2026-04-22T10-00-00"

    def test_explicit_session_id_not_found(self, work_dir) -> None:
        action = rr.route_resume(session_id="nonexistent")
        assert action["action_type"] == rr.ACTION_NO_RESUMABLE
        assert action["session_id"] == "nonexistent"

    def test_latest_active_picked_over_old_in_progress(
        self, work_dir
    ) -> None:
        import time

        old_state = _base_state(last_completed="L1")
        old_state["session"]["id"] = "old-session"
        old_dir = _write_session(work_dir, "old-session", old_state)
        # Ensure mtime differentiation.
        time.sleep(0.01)
        new_state = _base_state(last_completed="L4")
        new_state["session"]["id"] = "new-session"
        new_state["layers"]["L4"]["status"] = "in_progress"
        new_state["layers"]["L4"]["batch_progress"] = {
            "current": "batch-002",
            "total": 3,
            "completed_batches": ["batch-001"],
        }
        new_dir = _write_session(work_dir, "new-session", new_state)
        # Force mtime update to ensure ordering.
        import os

        os.utime(new_dir, None)

        action = rr.route_resume()
        assert action["session_id"] == "new-session"
        assert action["action_type"] == rr.ACTION_RESUME_L4_BATCH
        assert old_dir.name != action["session_id"]


class TestRouteResumeCorruption:
    def test_missing_scan_state_no_ledger(self, work_dir) -> None:
        # Session dir exists but no scan-state.json + no ledger.
        session_dir = work_dir / "sessions" / "broken-session"
        session_dir.mkdir(parents=True)
        # get_active_session_dir ignores dirs without scan-state.json
        # → route via explicit session_id.
        action = rr.route_resume(session_id="broken-session")
        assert action["action_type"] == rr.ACTION_SESSION_INVALID
        assert any("not found" in n.lower() for n in action["notes"])

    def test_missing_scan_state_with_ledger_fallback(
        self, work_dir
    ) -> None:
        session_dir = work_dir / "sessions" / "migrate-me"
        session_dir.mkdir(parents=True)
        # Write legacy ledger.json at WORK_DIR root.
        (work_dir / "ledger.json").write_text(
            json.dumps({"generated_at": "2026-04-10", "stages": {}}),
            encoding="utf-8",
        )
        action = rr.route_resume(session_id="migrate-me")
        assert action["action_type"] == rr.ACTION_FALLBACK_LEDGER

    def test_corrupted_scan_state_json(self, work_dir) -> None:
        session_dir = work_dir / "sessions" / "corrupt"
        session_dir.mkdir(parents=True)
        (session_dir / "scan-state.json").write_text(
            "{ invalid json [[", encoding="utf-8"
        )
        action = rr.route_resume(session_id="corrupt")
        assert action["action_type"] in (
            rr.ACTION_SESSION_INVALID,
            rr.ACTION_FALLBACK_LEDGER,
        )

    def test_scan_state_schema_invalid(self, work_dir) -> None:
        # Valid JSON, invalid schema (missing last_completed).
        session_dir = work_dir / "sessions" / "no-schema"
        session_dir.mkdir(parents=True)
        (session_dir / "scan-state.json").write_text(
            json.dumps({"session": {"id": "no-schema"}, "layers": {}}),
            encoding="utf-8",
        )
        action = rr.route_resume(session_id="no-schema")
        assert action["action_type"] in (
            rr.ACTION_SESSION_INVALID,
            rr.ACTION_FALLBACK_LEDGER,
        )


# ─── Enrichment ──────────────────────────────────────────────


class TestActionEnrichment:
    def test_depth_map_included(self, work_dir) -> None:
        state = _base_state(last_completed="L1")
        state["depth_map"]["L4"] = "deep"
        _write_session(work_dir, "enrich-test", state)
        action = rr.route_resume(session_id="enrich-test")
        assert action["depth_map"]["L4"] == "deep"

    def test_ips_flags_reflect_state(self, work_dir) -> None:
        state = _base_state(last_completed="L3")
        state["ips"]["phase_a"] = {"domains": {}}
        state["ips"]["phase_b"] = None
        _write_session(work_dir, "ips-test", state)
        action = rr.route_resume(session_id="ips-test")
        assert action["ips_phase_a_available"] is True
        assert action["ips_phase_b_available"] is False

    def test_profile_and_strategy_surfaced(self, work_dir) -> None:
        state = _base_state(last_completed="init")
        state["session"]["profile"] = "deep"
        state["session"]["strategy"] = "S4"
        _write_session(work_dir, "meta-test", state)
        action = rr.route_resume(session_id="meta-test")
        assert action["profile"] == "deep"
        assert action["strategy"] == "S4"


# ─── CLI ─────────────────────────────────────────────────────


class TestCLI:
    def test_cli_json_output(self, work_dir, capsys) -> None:
        state = _base_state(last_completed="L2")
        state["session"]["id"] = "cli-test"
        _write_session(work_dir, "cli-test", state)
        exit_code = rr._cli(
            ["--session", "cli-test", "--work-dir", str(work_dir)]
        )
        captured = capsys.readouterr()
        payload = json.loads(captured.out)
        assert exit_code == 0
        assert payload["action_type"] == rr.ACTION_START_L3
        assert payload["session_id"] == "cli-test"

    def test_cli_exit_2_on_missing_session_id(
        self, work_dir, capsys
    ) -> None:
        exit_code = rr._cli(
            ["--session", "nonexistent", "--work-dir", str(work_dir)]
        )
        captured = capsys.readouterr()
        payload = json.loads(captured.out)
        assert exit_code == 2
        assert payload["action_type"] == rr.ACTION_NO_RESUMABLE

    def test_cli_exit_0_on_natural_no_resumable(
        self, work_dir, capsys
    ) -> None:
        exit_code = rr._cli(["--work-dir", str(work_dir)])
        captured = capsys.readouterr()
        payload = json.loads(captured.out)
        # No session provided → natural no-session → exit 0.
        assert exit_code == 0
        assert payload["action_type"] == rr.ACTION_NO_RESUMABLE
