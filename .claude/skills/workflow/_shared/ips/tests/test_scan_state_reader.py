"""Tests for scan_state_reader.py — Phase B implementation.

Coverage:
- is_valid_transition: state machine edge cases.
- read_layer_status: in-memory accessor.
- get_active_session_dir: session auto-discovery.
- read_scan_state: file read với session auto-discovery.
- update_layer_status: state machine enforcement + atomic write.
- update_batch_progress, update_module_progress.
- append_error.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import scan_state_reader as ssr  # noqa: E402


# ─── Fixtures ────────────────────────────────────────────────


def _make_state(
    session_id: str = "2026-04-22T10-00-00",
    status: str = "in_progress",
    layer_overrides: dict | None = None,
) -> dict:
    """Build a minimal valid scan-state dict cho testing."""
    layers = {
        "L1": {"status": "completed", "started": None, "completed": None},
        "L2": {"status": "completed", "started": None, "completed": None},
        "L3": {"status": "completed", "started": None, "completed": None},
        "L4": {
            "status": "not_started",
            "started": None,
            "completed": None,
            "batch_progress": None,
        },
        "L5": {
            "status": "not_started",
            "started": None,
            "completed": None,
            "module_progress": None,
        },
        "L6": {"status": "not_started", "started": None, "completed": None},
    }
    if layer_overrides:
        for lid, overrides in layer_overrides.items():
            layers[lid].update(overrides)

    return {
        "$schema": "scan-state-v1",
        "session": {"id": session_id, "project_path": "/test"},
        "layers": layers,
        "status": status,
        "error_log": [],
    }


@pytest.fixture
def session_env(tmp_path, monkeypatch):
    """Setup mock work dir + active session.

    Returns tuple (work_dir, session_dir, session_id).
    """
    work_dir = tmp_path / ".mc-data" / "work" / "legacy-scan"
    session_id = "2026-04-22T10-00-00"
    session_dir = work_dir / "sessions" / session_id
    session_dir.mkdir(parents=True)

    state = _make_state(session_id=session_id)
    (session_dir / "scan-state.json").write_text(
        json.dumps(state), encoding="utf-8"
    )

    monkeypatch.setattr(ssr, "WORK_DIR", work_dir)
    return work_dir, session_dir, session_id


# ─── State Machine Tests (Phase A.7 baseline — still valid) ──


class TestIsValidTransition:
    @pytest.mark.parametrize(
        "from_state,to_state,expected",
        [
            ("not_started", "in_progress", True),
            ("not_started", "skipped_by_profile", True),
            ("not_started", "completed", False),
            ("in_progress", "completed", True),
            ("in_progress", "failed", True),
            ("in_progress", "not_started", False),
            ("completed", "in_progress", False),
            ("failed", "in_progress", True),
            ("skipped_by_profile", "in_progress", False),
            ("invalid_state", "in_progress", False),
        ],
    )
    def test_transitions(
        self, from_state: str, to_state: str, expected: bool
    ) -> None:
        assert ssr.is_valid_transition(from_state, to_state) is expected


class TestReadLayerStatus:
    def test_basic(self) -> None:
        state = {
            "layers": {
                "L1": {"status": "completed"},
                "L4": {"status": "in_progress"},
            }
        }
        assert ssr.read_layer_status(state, "L1") == "completed"
        assert ssr.read_layer_status(state, "L4") == "in_progress"


# ─── Session Discovery ───────────────────────────────────────


class TestGetActiveSessionDir:
    def test_no_sessions_returns_none(self, tmp_path, monkeypatch):
        work_dir = tmp_path / ".mc-data" / "work" / "legacy-scan"
        monkeypatch.setattr(ssr, "WORK_DIR", work_dir)
        assert ssr.get_active_session_dir() is None

    def test_active_session_found(self, session_env):
        _, session_dir, _ = session_env
        assert ssr.get_active_session_dir() == session_dir

    def test_completed_session_ignored(self, tmp_path, monkeypatch):
        work_dir = tmp_path / ".mc-data" / "work" / "legacy-scan"
        session = work_dir / "sessions" / "old-completed"
        session.mkdir(parents=True)
        state = _make_state(status="completed")
        (session / "scan-state.json").write_text(
            json.dumps(state), encoding="utf-8"
        )
        monkeypatch.setattr(ssr, "WORK_DIR", work_dir)
        assert ssr.get_active_session_dir() is None


# ─── Read ────────────────────────────────────────────────────


class TestReadScanState:
    def test_auto_discover(self, session_env):
        _, _, session_id = session_env
        state = ssr.read_scan_state()
        assert state["session"]["id"] == session_id

    def test_explicit_session_id(self, session_env):
        _, _, session_id = session_env
        state = ssr.read_scan_state(session_id)
        assert state["session"]["id"] == session_id

    def test_missing_session_raises(self, tmp_path, monkeypatch):
        work_dir = tmp_path / ".mc-data" / "work" / "legacy-scan"
        monkeypatch.setattr(ssr, "WORK_DIR", work_dir)
        with pytest.raises(FileNotFoundError):
            ssr.read_scan_state()

    def test_explicit_invalid_session_raises(self, session_env):
        with pytest.raises(FileNotFoundError):
            ssr.read_scan_state("nonexistent-session")


# ─── State Machine Enforcement on update_layer_status ────────


class TestUpdateLayerStatus:
    def test_valid_transition_persists(self, session_env):
        ssr.update_layer_status("L4", "in_progress")
        state = ssr.read_scan_state()
        assert state["layers"]["L4"]["status"] == "in_progress"
        assert state["layers"]["L4"]["started"] is not None

    def test_valid_completion_persists_timestamp(self, session_env):
        ssr.update_layer_status("L4", "in_progress")
        ssr.update_layer_status("L4", "completed")
        state = ssr.read_scan_state()
        assert state["layers"]["L4"]["status"] == "completed"
        assert state["layers"]["L4"]["completed"] is not None

    def test_invalid_transition_raises(self, session_env):
        # L1 is completed (terminal) — cannot go back to in_progress.
        with pytest.raises(ValueError, match="Invalid transition"):
            ssr.update_layer_status("L1", "in_progress")

    def test_unknown_status_raises(self, session_env):
        with pytest.raises(ValueError, match="Unknown layer status"):
            ssr.update_layer_status("L4", "bogus-state")

    def test_skip_by_profile_from_not_started(self, session_env):
        ssr.update_layer_status("L4", "skipped_by_profile")
        state = ssr.read_scan_state()
        assert state["layers"]["L4"]["status"] == "skipped_by_profile"

    def test_retry_failed_layer(self, session_env):
        ssr.update_layer_status("L4", "in_progress")
        ssr.update_layer_status("L4", "failed")
        # Retry: failed → in_progress is allowed.
        ssr.update_layer_status("L4", "in_progress")
        state = ssr.read_scan_state()
        assert state["layers"]["L4"]["status"] == "in_progress"


# ─── Batch / Module Progress ─────────────────────────────────


class TestUpdateBatchProgress:
    def test_l4_batch_progress_persists(self, session_env):
        progress = {"current": 3, "total": 10, "completed_batches": [0, 1, 2]}
        ssr.update_batch_progress("L4", progress)
        state = ssr.read_scan_state()
        assert state["layers"]["L4"]["batch_progress"] == progress

    def test_l5_batch_progress_persists(self, session_env):
        progress = {"current": 1, "total": 5}
        ssr.update_batch_progress("L5", progress)
        state = ssr.read_scan_state()
        assert state["layers"]["L5"]["batch_progress"] == progress

    def test_invalid_layer_raises(self, session_env):
        with pytest.raises(ValueError, match="L4/L5"):
            ssr.update_batch_progress("L1", {"current": 0, "total": 0})


class TestUpdateModuleProgress:
    def test_append_completed_module(self, session_env):
        ssr.update_module_progress("L5", "billing", "completed")
        ssr.update_module_progress("L5", "invoice", "completed")
        state = ssr.read_scan_state()
        completed = state["layers"]["L5"]["module_progress"]["completed"]
        assert "billing" in completed
        assert "invoice" in completed

    def test_dedup_completed_module(self, session_env):
        ssr.update_module_progress("L5", "billing", "completed")
        ssr.update_module_progress("L5", "billing", "completed")
        state = ssr.read_scan_state()
        completed = state["layers"]["L5"]["module_progress"]["completed"]
        assert completed.count("billing") == 1

    def test_non_completed_status_not_appended(self, session_env):
        ssr.update_module_progress("L5", "billing", "in_progress")
        state = ssr.read_scan_state()
        completed = state["layers"]["L5"]["module_progress"]["completed"]
        assert "billing" not in completed


# ─── Error Log Append ────────────────────────────────────────


class TestAppendError:
    def test_basic_append(self, session_env):
        ssr.append_error("L4", {"code": "E-01", "message": "test error"})
        state = ssr.read_scan_state()
        assert len(state["error_log"]) == 1
        entry = state["error_log"][0]
        assert entry["code"] == "E-01"
        assert entry["layer"] == "L4"
        assert "timestamp" in entry

    def test_multiple_errors_preserve_order(self, session_env):
        ssr.append_error("L4", {"code": "E-01", "message": "first"})
        ssr.append_error("L5", {"code": "E-02", "message": "second"})
        state = ssr.read_scan_state()
        assert [e["code"] for e in state["error_log"]] == ["E-01", "E-02"]


# ─── Phase D: Full API Tests ─────────────────────────────────


def _enrich_state_with_ips(
    state: dict,
    *,
    depth_map: dict | None = None,
    phase_a: dict | None = None,
    phase_b: dict | None = None,
) -> dict:
    """Enrich _make_state output với depth_map + ips fields cho Phase D tests."""
    if depth_map is not None:
        state["depth_map"] = depth_map
    else:
        state.setdefault(
            "depth_map",
            {"L1": "full", "L2": "full", "L3": "full",
             "L4": "standard", "L5": "standard", "L6": "full"},
        )
    state.setdefault("ips", {"phase_a": None, "phase_b": None})
    if phase_a is not None:
        state["ips"]["phase_a"] = phase_a
    if phase_b is not None:
        state["ips"]["phase_b"] = phase_b
    return state


@pytest.fixture
def ips_session(tmp_path, monkeypatch):
    """Session with enriched depth_map + ips fields populated."""
    work_dir = tmp_path / ".mc-data" / "work" / "legacy-scan"
    session_id = "2026-04-22T12-00-00"
    session_dir = work_dir / "sessions" / session_id
    session_dir.mkdir(parents=True)

    phase_a = {
        "recommended_profile": "standard",
        "profile_reasoning": "Healthy project",
        "detected_domains": [
            {"domain": "finance", "confidence": 0.85, "recommended_expert": "finance-expert"},
        ],
        "warnings": [],
    }
    phase_b = {
        "module_routing": {
            "billing": {
                "domain": "finance",
                "expert": "finance-expert",
                "confidence": 0.85,
                "source": "en",
            },
            "invoice": {
                "domain": "finance",
                "expert": "finance-expert",
                "confidence": 0.65,
                "source": "en",
            },
            "low_conf_mod": {
                "domain": "operations",
                "expert": "operations-expert",
                "confidence": 0.45,
                "source": "en",
            },
            "no_expert_entry": {
                "domain": "unknown",
                "expert": "",
                "confidence": 0.9,
                "source": "en",
            },
        },
        "complexity_hotspots": [{"module": "billing", "files": 42, "coupling": 7}],
    }

    depth_map = {
        "L1": "full", "L2": "full", "L3": "full",
        "L4": "deep", "L5": "deep", "L6": "full",
    }
    state = _make_state(session_id=session_id)
    state = _enrich_state_with_ips(
        state, depth_map=depth_map, phase_a=phase_a, phase_b=phase_b
    )
    (session_dir / "scan-state.json").write_text(
        json.dumps(state), encoding="utf-8"
    )

    monkeypatch.setattr(ssr, "WORK_DIR", work_dir)
    return work_dir, session_dir, session_id


class TestReadLayerOutputs:
    def test_empty_by_default(self, session_env):
        outputs = ssr.read_layer_outputs("L4")
        assert outputs == []

    def test_returns_appended_paths(self, session_env):
        ssr.append_layer_output("L4", "classified/batch-1.json")
        ssr.append_layer_output("L4", "classified/batch-2.json")
        outputs = ssr.read_layer_outputs("L4")
        assert outputs == [
            "classified/batch-1.json",
            "classified/batch-2.json",
        ]

    def test_returns_empty_if_outputs_missing_key(self, session_env):
        # Manually set outputs=None to test defensive behavior.
        state = ssr.read_scan_state()
        state["layers"]["L4"]["outputs"] = None
        _, session_dir, _ = session_env
        (session_dir / "scan-state.json").write_text(
            json.dumps(state), encoding="utf-8"
        )
        assert ssr.read_layer_outputs("L4") == []


class TestAppendLayerOutput:
    def test_dedup_idempotent(self, session_env):
        ssr.append_layer_output("L5", "extracted/billing.json")
        ssr.append_layer_output("L5", "extracted/billing.json")
        outputs = ssr.read_layer_outputs("L5")
        assert outputs == ["extracted/billing.json"]

    def test_preserve_order(self, session_env):
        ssr.append_layer_output("L5", "extracted/a.json")
        ssr.append_layer_output("L5", "extracted/b.json")
        ssr.append_layer_output("L5", "extracted/c.json")
        outputs = ssr.read_layer_outputs("L5")
        assert outputs == [
            "extracted/a.json",
            "extracted/b.json",
            "extracted/c.json",
        ]


class TestReadDepthMap:
    def test_returns_full_map(self, ips_session):
        depth = ssr.read_depth_map()
        assert depth["L4"] == "deep"
        assert depth["L5"] == "deep"
        assert depth["L1"] == "full"

    def test_missing_depth_map_returns_empty(self, session_env):
        # session_env fixture không set depth_map key
        state = ssr.read_scan_state()
        state.pop("depth_map", None)
        _, session_dir, _ = session_env
        (session_dir / "scan-state.json").write_text(
            json.dumps(state), encoding="utf-8"
        )
        assert ssr.read_depth_map() == {}


class TestReadIPSPhaseA:
    def test_returns_phase_a_dict(self, ips_session):
        phase_a = ssr.read_ips_phase_a()
        assert phase_a["recommended_profile"] == "standard"
        assert len(phase_a["detected_domains"]) == 1

    def test_returns_empty_when_missing(self, session_env):
        assert ssr.read_ips_phase_a() == {}


class TestReadIPSPhaseB:
    def test_returns_phase_b_dict(self, ips_session):
        phase_b = ssr.read_ips_phase_b()
        assert "billing" in phase_b["module_routing"]
        assert phase_b["complexity_hotspots"][0]["module"] == "billing"

    def test_returns_empty_when_missing(self, session_env):
        assert ssr.read_ips_phase_b() == {}


class TestGetDomainExpertForModule:
    def test_strong_confidence_returns_expert(self, ips_session):
        expert = ssr.get_domain_expert_for_module("billing")
        assert expert == "finance-expert"

    def test_moderate_confidence_above_threshold(self, ips_session):
        # invoice has 0.65 ≥ 0.6 threshold
        expert = ssr.get_domain_expert_for_module("invoice")
        assert expert == "finance-expert"

    def test_low_confidence_returns_none(self, ips_session):
        # low_conf_mod has 0.45 < 0.6 threshold
        expert = ssr.get_domain_expert_for_module("low_conf_mod")
        assert expert is None

    def test_missing_module_returns_none(self, ips_session):
        expert = ssr.get_domain_expert_for_module("nonexistent_module")
        assert expert is None

    def test_empty_expert_string_returns_none(self, ips_session):
        # no_expert_entry has confidence 0.9 but expert=""
        expert = ssr.get_domain_expert_for_module("no_expert_entry")
        assert expert is None

    def test_no_phase_b_returns_none(self, session_env):
        expert = ssr.get_domain_expert_for_module("anything")
        assert expert is None


class TestInitOrLoadSession:
    def test_returns_active_session_id(self, session_env):
        _, _, session_id = session_env
        result = ssr.init_or_load_session(Path("/test"))
        assert result == session_id

    def test_migrates_from_legacy_ledger(self, tmp_path, monkeypatch):
        work_dir = tmp_path / ".mc-data" / "work" / "legacy-scan"
        work_dir.mkdir(parents=True)

        # Write legacy v4.1 ledger.json
        ledger_data = {
            "project": {"name": "test-proj", "path": "/test"},
            "strategy": {"id": "S2"},
            "maturity": {"maturity_level": "CODE_ONLY"},
            "stages": {
                "detection": {"status": "completed"},
                "inventory": {"status": "completed"},
                "classify": {"status": "completed"},
                "extract": {"status": "in_progress"},
                "synthesize": {"status": "not_started"},
            },
            "generated_at": "2026-04-22T00:00:00Z",
        }
        (work_dir / "ledger.json").write_text(
            json.dumps(ledger_data), encoding="utf-8"
        )

        monkeypatch.setattr(ssr, "WORK_DIR", work_dir)

        session_id = ssr.init_or_load_session(Path("/test"))
        assert session_id  # non-empty string

        # Verify session dir + scan-state created
        session_dir = work_dir / "sessions" / session_id
        assert session_dir.exists()
        state_file = session_dir / "scan-state.json"
        assert state_file.exists()

        # Verify migration preserves layer states
        state = json.loads(state_file.read_text(encoding="utf-8"))
        assert state["session"]["migrated_from_legacy"] is True
        assert state["layers"]["L3"]["status"] == "completed"  # inventory
        assert state["layers"]["L4"]["status"] == "completed"  # classify
        assert state["layers"]["L5"]["status"] == "in_progress"  # extract

    def test_no_prior_scan_raises(self, tmp_path, monkeypatch):
        work_dir = tmp_path / ".mc-data" / "work" / "legacy-scan"
        # Không tạo sessions/ hoặc ledger.json
        monkeypatch.setattr(ssr, "WORK_DIR", work_dir)
        with pytest.raises(RuntimeError, match="No prior scan"):
            ssr.init_or_load_session(Path("/test"))

    def test_corrupt_ledger_raises(self, tmp_path, monkeypatch):
        work_dir = tmp_path / ".mc-data" / "work" / "legacy-scan"
        work_dir.mkdir(parents=True)
        (work_dir / "ledger.json").write_text(
            "{ not valid json", encoding="utf-8"
        )
        monkeypatch.setattr(ssr, "WORK_DIR", work_dir)
        with pytest.raises(RuntimeError, match="corrupted"):
            ssr.init_or_load_session(Path("/test"))

    def test_skipped_maturity_maps_to_skipped_by_profile(self, tmp_path, monkeypatch):
        work_dir = tmp_path / ".mc-data" / "work" / "legacy-scan"
        work_dir.mkdir(parents=True)
        ledger_data = {
            "stages": {
                "inventory": {"status": "completed"},
                "classify": {"status": "skipped_maturity"},
                "extract": {"status": "skipped"},
                "synthesize": {"status": "not_started"},
            },
        }
        (work_dir / "ledger.json").write_text(
            json.dumps(ledger_data), encoding="utf-8"
        )
        monkeypatch.setattr(ssr, "WORK_DIR", work_dir)

        session_id = ssr.init_or_load_session(Path("/test"))
        state = ssr.read_scan_state(session_id)
        assert state["layers"]["L4"]["status"] == "skipped_by_profile"
        assert state["layers"]["L5"]["status"] == "skipped_by_profile"


# ─── Phase E: L3 Intra-Batch Partial Tests ───────────────────


class TestLayerPartial:
    def test_write_read_roundtrip_l4(self, session_env):
        _, _, session_id = session_env
        ssr._reset_throttle_state()
        ssr.write_layer_partial(
            "L4",
            {
                "batch_id": "batch-003",
                "completed_items": ["src/a.ts", "src/b.ts"],
                "current_item": "src/c.ts",
            },
            session_id=session_id,
        )
        result = ssr.read_layer_partial("L4", session_id=session_id)
        assert result is not None
        assert result["layer"] == "L4"
        assert result["batch_id"] == "batch-003"
        assert result["completed_items"] == ["src/a.ts", "src/b.ts"]
        assert result["current_item"] == "src/c.ts"
        assert "updated" in result
        assert "started" in result
        assert result["$schema"] == "layer-partial-v1"

    def test_write_read_roundtrip_l5(self, session_env):
        _, _, session_id = session_env
        ssr._reset_throttle_state()
        ssr.write_layer_partial(
            "L5",
            {
                "module": "billing",
                "completed_items": ["feat-001", "feat-002"],
                "current_item": "feat-003",
            },
            session_id=session_id,
        )
        result = ssr.read_layer_partial("L5", session_id=session_id)
        assert result["module"] == "billing"
        assert result["completed_items"] == ["feat-001", "feat-002"]

    def test_invalid_layer_raises(self, session_env):
        _, _, session_id = session_env
        with pytest.raises(ValueError, match="L4/L5"):
            ssr.write_layer_partial(
                "L3", {"batch_id": "x"}, session_id=session_id
            )
        with pytest.raises(ValueError, match="L4/L5"):
            ssr.read_layer_partial("L6", session_id=session_id)
        with pytest.raises(ValueError, match="L4/L5"):
            ssr.clear_layer_partial("L1", session_id=session_id)

    def test_read_missing_partial_returns_none(self, session_env):
        _, _, session_id = session_env
        assert ssr.read_layer_partial("L4", session_id=session_id) is None
        assert ssr.read_layer_partial("L5", session_id=session_id) is None

    def test_clear_partial_idempotent(self, session_env):
        _, _, session_id = session_env
        ssr._reset_throttle_state()
        ssr.write_layer_partial(
            "L4",
            {"batch_id": "batch-001", "completed_items": []},
            session_id=session_id,
        )
        ssr.clear_layer_partial("L4", session_id=session_id)
        assert ssr.read_layer_partial("L4", session_id=session_id) is None
        # Idempotent — second clear không raise.
        ssr.clear_layer_partial("L4", session_id=session_id)

    def test_partial_file_atomic_and_isolated(self, session_env):
        """Partial file sống dưới layers/<L>/ tách biệt scan-state.json."""
        _, session_dir, session_id = session_env
        ssr._reset_throttle_state()
        ssr.write_layer_partial(
            "L4",
            {"batch_id": "batch-007", "completed_items": ["x.ts"]},
            session_id=session_id,
        )
        partial_path = session_dir / "layers" / "L4" / "partial.json"
        assert partial_path.exists()
        assert partial_path.parent.parent.name == "layers"

    def test_write_updates_scan_state_partial_ref(self, session_env):
        _, _, session_id = session_env
        ssr._reset_throttle_state()
        ssr.write_layer_partial(
            "L4",
            {"batch_id": "batch-001", "completed_items": []},
            session_id=session_id,
        )
        # Force flush pending so disk reflects update.
        ssr.flush_pending_writes(session_id=session_id)
        state = ssr.read_scan_state(session_id)
        assert state["layers"]["L4"]["partial"] == "layers/L4/partial.json"

    def test_clear_resets_scan_state_partial_ref(self, session_env):
        _, _, session_id = session_env
        ssr._reset_throttle_state()
        ssr.write_layer_partial(
            "L4",
            {"batch_id": "batch-001", "completed_items": []},
            session_id=session_id,
        )
        ssr.clear_layer_partial("L4", session_id=session_id)
        ssr.flush_pending_writes(session_id=session_id)
        state = ssr.read_scan_state(session_id)
        assert state["layers"]["L4"]["partial"] is None


# ─── Phase E: L0 last_completed Tests ────────────────────────


class TestUpdateLastCompleted:
    def test_basic_update(self, session_env):
        _, _, session_id = session_env
        ssr._reset_throttle_state()
        ssr.update_last_completed("L3", session_id=session_id)
        state = ssr.read_scan_state(session_id)
        assert state["last_completed"] == "L3"

    def test_sequential_updates_overwrite(self, session_env):
        _, _, session_id = session_env
        ssr._reset_throttle_state()
        ssr.update_last_completed("L1", session_id=session_id)
        ssr.update_last_completed("L2", session_id=session_id)
        ssr.update_last_completed("L3", session_id=session_id)
        state = ssr.read_scan_state(session_id)
        assert state["last_completed"] == "L3"

    def test_force_write_bypasses_throttle(self, session_env):
        """L0 checkpoint luôn flush disk ngay cả khi throttle active."""
        _, session_dir, session_id = session_env
        ssr._reset_throttle_state()
        # Prime last_write_time để trigger throttle path.
        ssr.update_layer_status("L4", "in_progress", session_id=session_id)
        # update_last_completed is force=True → must flush.
        ssr.update_last_completed("L3", session_id=session_id)
        # Read DISK directly (not pending).
        disk = json.loads(
            (session_dir / "scan-state.json").read_text(encoding="utf-8")
        )
        assert disk["last_completed"] == "L3"


# ─── Phase E: Write Throttle Tests ───────────────────────────


class TestWriteThrottle:
    def setup_method(self) -> None:
        ssr._reset_throttle_state()

    def teardown_method(self) -> None:
        ssr._reset_throttle_state()

    def test_rapid_non_critical_writes_throttled(
        self, session_env, monkeypatch
    ):
        """10 rapid batch_progress updates → ≤ 3 disk writes.

        Criteria from phase-E spec §E.2: "10 rapid calls → ≤ 3 writes".
        """
        _, session_dir, session_id = session_env
        state_path = session_dir / "scan-state.json"

        # Shrink throttle for deterministic timing nhưng vẫn > 0.
        monkeypatch.setattr(ssr, "_WRITE_THROTTLE_SEC", 5.0)

        write_count = 0

        def counting_do_write(_sd, st):
            nonlocal write_count
            write_count += 1
            # Actually write để subsequent reads work.
            state_path.write_text(
                json.dumps(st, ensure_ascii=False), encoding="utf-8"
            )

        monkeypatch.setattr(ssr, "_do_atomic_write", counting_do_write)

        # 10 rapid batch progress updates — batch_progress không phải critical.
        for i in range(10):
            ssr.update_batch_progress(
                "L4",
                {"current": i, "total": 10, "completed_batches": []},
                session_id=session_id,
            )

        # First write always goes through (last_write=0). Subsequent deferred.
        # Expect ≤ 3 writes (actually 1 here since no 5s elapsed).
        assert write_count <= 3
        assert write_count >= 1

    def test_critical_writes_bypass_throttle(self, session_env, monkeypatch):
        """update_layer_status (force=True) ignores throttle."""
        _, session_dir, session_id = session_env
        state_path = session_dir / "scan-state.json"

        write_count = 0

        def counting_do_write(_sd, st):
            nonlocal write_count
            write_count += 1
            state_path.write_text(
                json.dumps(st, ensure_ascii=False), encoding="utf-8"
            )

        monkeypatch.setattr(ssr, "_do_atomic_write", counting_do_write)

        # L4 not_started → in_progress → completed (transition chains).
        ssr.update_layer_status("L4", "in_progress", session_id=session_id)
        ssr.update_layer_status("L4", "completed", session_id=session_id)
        # 2 critical transitions → 2 actual writes.
        assert write_count == 2

    def test_deferred_write_flushed_on_next_critical(
        self, session_env, monkeypatch
    ):
        """Pending state từ throttled write được flush khi next critical fires."""
        _, session_dir, session_id = session_env
        state_path = session_dir / "scan-state.json"

        # Prime throttle — first write sets last_write_time.
        ssr.update_batch_progress(
            "L4",
            {"current": 1, "total": 10, "completed_batches": []},
            session_id=session_id,
        )

        # Second batch progress — should defer (< 5s elapsed).
        ssr.update_batch_progress(
            "L4",
            {"current": 2, "total": 10, "completed_batches": ["b1"]},
            session_id=session_id,
        )

        disk = json.loads(state_path.read_text(encoding="utf-8"))
        # Disk reflects first write, not second.
        assert disk["layers"]["L4"]["batch_progress"]["current"] == 1

        # Critical write flushes pending first (clears it) then force-writes.
        ssr.update_layer_status("L4", "in_progress", session_id=session_id)

        disk = json.loads(state_path.read_text(encoding="utf-8"))
        # Critical write's state had the pending modifications → current=2.
        assert disk["layers"]["L4"]["status"] == "in_progress"
        # Pending was superseded by critical write — layer has batch_progress
        # current=2 because the critical's read_scan_state picked up pending.
        assert disk["layers"]["L4"]["batch_progress"]["current"] == 2

    def test_read_returns_pending_state(self, session_env):
        """read_scan_state prefers pending (newer) over disk."""
        _, _, session_id = session_env

        # Prime throttle with first write.
        ssr.update_batch_progress(
            "L4",
            {"current": 1, "total": 10, "completed_batches": []},
            session_id=session_id,
        )

        # Second update deferred — stored in pending only.
        ssr.update_batch_progress(
            "L4",
            {"current": 5, "total": 10, "completed_batches": ["b1", "b2"]},
            session_id=session_id,
        )

        # read_scan_state should see pending value (5), not disk (1).
        state = ssr.read_scan_state(session_id)
        assert state["layers"]["L4"]["batch_progress"]["current"] == 5

    def test_flush_pending_writes_persists_to_disk(
        self, session_env
    ):
        """flush_pending_writes writes pending to disk."""
        _, session_dir, session_id = session_env
        state_path = session_dir / "scan-state.json"

        # Prime + defer.
        ssr.update_batch_progress(
            "L4",
            {"current": 1, "total": 10, "completed_batches": []},
            session_id=session_id,
        )
        ssr.update_batch_progress(
            "L4",
            {"current": 9, "total": 10, "completed_batches": ["a"] * 9},
            session_id=session_id,
        )

        disk = json.loads(state_path.read_text(encoding="utf-8"))
        assert disk["layers"]["L4"]["batch_progress"]["current"] == 1

        ssr.flush_pending_writes(session_id=session_id)

        disk = json.loads(state_path.read_text(encoding="utf-8"))
        assert disk["layers"]["L4"]["batch_progress"]["current"] == 9

    def test_flush_pending_all_sessions(self, session_env):
        """flush_pending_writes(None) flushes all pending sessions."""
        _, session_dir, session_id = session_env
        state_path = session_dir / "scan-state.json"

        ssr.update_batch_progress(
            "L4",
            {"current": 1, "total": 5, "completed_batches": []},
            session_id=session_id,
        )
        ssr.update_batch_progress(
            "L4",
            {"current": 3, "total": 5, "completed_batches": ["a", "b"]},
            session_id=session_id,
        )

        # Flush all — no session_id.
        ssr.flush_pending_writes()

        disk = json.loads(state_path.read_text(encoding="utf-8"))
        assert disk["layers"]["L4"]["batch_progress"]["current"] == 3

    def test_throttle_independent_per_session(self, tmp_path, monkeypatch):
        """Throttle bucket tính riêng per session — không cross-contaminate."""
        work_dir = tmp_path / ".mc-data" / "work" / "legacy-scan"
        monkeypatch.setattr(ssr, "WORK_DIR", work_dir)

        # Create 2 sessions.
        for sid in ("S-A", "S-B"):
            sd = work_dir / "sessions" / sid
            sd.mkdir(parents=True)
            state = _make_state(session_id=sid)
            (sd / "scan-state.json").write_text(
                json.dumps(state), encoding="utf-8"
            )

        # First write to A primes its last_write_time.
        ssr.update_batch_progress(
            "L4",
            {"current": 1, "total": 5, "completed_batches": []},
            session_id="S-A",
        )
        # First write to B — should NOT be throttled (separate session).
        ssr.update_batch_progress(
            "L4",
            {"current": 1, "total": 5, "completed_batches": []},
            session_id="S-B",
        )

        disk_a = json.loads(
            (work_dir / "sessions" / "S-A" / "scan-state.json").read_text(
                encoding="utf-8"
            )
        )
        disk_b = json.loads(
            (work_dir / "sessions" / "S-B" / "scan-state.json").read_text(
                encoding="utf-8"
            )
        )
        # Both writes reached disk (neither deferred).
        assert disk_a["layers"]["L4"]["batch_progress"]["current"] == 1
        assert disk_b["layers"]["L4"]["batch_progress"]["current"] == 1
