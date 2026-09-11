"""test_lane_dispatch_xf08.py — XF-08 (Sprint 7) coverage uplift cho lane_dispatch.

Sprint 7 mục tiêu: nâng `lane_dispatch.py` từ 59.02% → ≥80%.

Focus uncovered zones (Sprint 6 baseline) — pure-logic + I/O, KHÔNG async:
- `_atomic_write_json`: exception cleanup (1202-1208)
- `_atomic_write_signals_locked`: lock+write+release (1221-1226)
- `_read_existing_signals`: invalid root + invalid signals (1243, 1245)
- `_merge_static_signals`: A1 anti-overwrite logic (1282-1304)
- `_sync_lane_status_totals`: file IO + severity counting (1330-1360)
- `_post_gate_lane`: T1/T2 error branches (1373, 1375, 1385-1389)
- `_lane_already_complete`: probes_executed parse path (1415-1420)
- `dispatch_lanes` sync: empty dimensions ValueError (1623-1624)
- `main` CLI: argparse + dispatch + exit codes (1693-1720)

Async paths (_run_lane_async, dispatch_lanes_async) defer Sprint 8 (BHV-002 —
KHÔNG inflate, focus highest-ROI tests trước).

Tham chiếu:
- BHV-002 Simplicity First (focus tests dễ-cover-nhiều-stmts)
- CORE-035 Atomic Write Pattern
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from lane_dispatch import (
    SIGNALS_SCHEMA_ID,
    _atomic_write_json,
    _atomic_write_signals_locked,
    _lane_already_complete,
    _merge_static_signals,
    _post_gate_lane,
    _read_existing_signals,
    _sync_lane_status_totals,
    dispatch_lanes,
    main,
)


# ──────────────────────────────────────────────────────────────────────
# _atomic_write_json
# ──────────────────────────────────────────────────────────────────────


class TestAtomicWriteJson:
    def test_writes_data_and_creates_parent(self, tmp_path: Path) -> None:
        """Happy path: tạo parent dir, ghi atomic JSON."""
        out = tmp_path / "subdir" / "out.json"
        data = {"x": 1, "y": [2, 3]}
        _atomic_write_json(out, data)
        assert out.is_file()
        loaded = json.loads(out.read_text(encoding="utf-8"))
        assert loaded == data

    def test_cleanup_on_replace_failure(self, tmp_path: Path, monkeypatch) -> None:
        """os.replace raise → tmp file bị unlink."""
        out = tmp_path / "out.json"

        def boom(*args, **kwargs):
            raise OSError("simulated replace fail")

        monkeypatch.setattr("os.replace", boom)
        with pytest.raises(OSError, match="simulated replace fail"):
            _atomic_write_json(out, {"x": 1})
        # No leftover .out.json.*.tmp
        leftover = list(tmp_path.glob(".out.json.*.tmp"))
        assert leftover == []


# ──────────────────────────────────────────────────────────────────────
# _atomic_write_signals_locked
# ──────────────────────────────────────────────────────────────────────


class TestAtomicWriteSignalsLocked:
    def test_writes_with_lock(self, tmp_path: Path) -> None:
        """Happy path: lock → write → release; file ghi đúng."""
        signals_path = tmp_path / "lanes" / "QD1" / "signals.json"
        data = {"$schema": SIGNALS_SCHEMA_ID, "signals": []}
        _atomic_write_signals_locked(signals_path, data)
        assert signals_path.is_file()
        loaded = json.loads(signals_path.read_text(encoding="utf-8"))
        assert loaded == data
        # Lock dir bị release → không còn
        lock_dir = signals_path.parent / ".signals.json.lock"
        assert not lock_dir.exists()


# ──────────────────────────────────────────────────────────────────────
# _read_existing_signals
# ──────────────────────────────────────────────────────────────────────


class TestReadExistingSignals:
    def test_missing_file_returns_none(self, tmp_path: Path) -> None:
        result = _read_existing_signals(tmp_path / "missing.json")
        assert result is None

    def test_empty_file_returns_none(self, tmp_path: Path) -> None:
        f = tmp_path / "empty.json"
        f.write_text("")
        result = _read_existing_signals(f)
        assert result is None

    def test_invalid_json_returns_none(self, tmp_path: Path) -> None:
        f = tmp_path / "bad.json"
        f.write_text("{ not json")
        result = _read_existing_signals(f)
        assert result is None

    def test_non_dict_root_returns_none(self, tmp_path: Path) -> None:
        """Root là array thay vì dict → None."""
        f = tmp_path / "list.json"
        f.write_text("[1,2,3]")
        result = _read_existing_signals(f)
        assert result is None

    def test_signals_not_list_returns_none(self, tmp_path: Path) -> None:
        """signals field là str thay vì list → None."""
        f = tmp_path / "wrong.json"
        f.write_text(json.dumps({"signals": "not a list"}))
        result = _read_existing_signals(f)
        assert result is None

    def test_valid_returns_dict(self, tmp_path: Path) -> None:
        f = tmp_path / "ok.json"
        f.write_text(json.dumps({"$schema": SIGNALS_SCHEMA_ID, "signals": []}))
        result = _read_existing_signals(f)
        assert isinstance(result, dict)
        assert result["signals"] == []


# ──────────────────────────────────────────────────────────────────────
# _merge_static_signals — A1 anti-overwrite logic
# ──────────────────────────────────────────────────────────────────────


class TestMergeStaticSignals:
    def test_no_existing_returns_new_envelope(self, tmp_path: Path) -> None:
        """File mới → trả new_envelope nguyên (preserved=0, replaced=0)."""
        new = {"$schema": SIGNALS_SCHEMA_ID, "signals": [{"probe_id": "P-X"}]}
        merged, preserved, replaced = _merge_static_signals(
            signals_path=tmp_path / "missing.json",
            new_envelope=new,
            static_probe_ids={"P-X"},
        )
        assert merged == new
        assert preserved == 0
        assert replaced == 0

    def test_preserves_non_static_signals(self, tmp_path: Path) -> None:
        """Existing signals có 1 non-static (LLM) + 1 static cũ → preserve LLM, thay static."""
        signals_path = tmp_path / "signals.json"
        existing = {
            "$schema": SIGNALS_SCHEMA_ID,
            "signals": [
                {"probe_id": "P-LLM-1", "severity": "high"},  # non-static, preserve
                {"probe_id": "P-OLD-STATIC", "severity": "low"},  # static, replace
            ],
        }
        signals_path.write_text(json.dumps(existing))

        new = {
            "$schema": SIGNALS_SCHEMA_ID,
            "signals": [{"probe_id": "P-OLD-STATIC", "severity": "critical"}],
        }
        merged, preserved, replaced = _merge_static_signals(
            signals_path=signals_path,
            new_envelope=new,
            static_probe_ids={"P-OLD-STATIC"},
        )
        # 1 LLM signal preserved, 1 static signal replaced
        assert preserved == 1
        assert replaced == 1
        # Merged signals = 1 preserved + 1 new = 2
        assert len(merged["signals"]) == 2
        # P-LLM-1 vẫn còn
        probe_ids = [s["probe_id"] for s in merged["signals"]]
        assert "P-LLM-1" in probe_ids

    def test_skips_non_dict_signals(self, tmp_path: Path) -> None:
        """Existing signals có entry không phải dict → skip (không crash)."""
        signals_path = tmp_path / "signals.json"
        existing = {
            "$schema": SIGNALS_SCHEMA_ID,
            "signals": [
                "not a dict",
                {"probe_id": "P-OK"},
            ],
        }
        signals_path.write_text(json.dumps(existing))

        new = {"$schema": SIGNALS_SCHEMA_ID, "signals": []}
        merged, preserved, replaced = _merge_static_signals(
            signals_path=signals_path,
            new_envelope=new,
            static_probe_ids=set(),
        )
        # P-OK preserved (non-static), str entry skipped
        assert preserved == 1
        assert replaced == 0

    def test_preserves_envelope_metadata_fields(self, tmp_path: Path) -> None:
        """Existing có lane/session_id/llm_merged → merged giữ lại."""
        signals_path = tmp_path / "signals.json"
        existing = {
            "$schema": SIGNALS_SCHEMA_ID,
            "signals": [],
            "lane": "wf-fix-business",
            "session_id": "S-001",
            "llm_merged": True,
            "llm_merged_at": "2026-05-15T00:00:00Z",
        }
        signals_path.write_text(json.dumps(existing))

        new = {"$schema": SIGNALS_SCHEMA_ID, "signals": []}
        merged, _, _ = _merge_static_signals(
            signals_path=signals_path,
            new_envelope=new,
            static_probe_ids=set(),
        )
        # PRESERVE_FIELDS được copy từ existing sang merged
        assert merged.get("lane") == "wf-fix-business"
        assert merged.get("session_id") == "S-001"
        assert merged.get("llm_merged") is True


# ──────────────────────────────────────────────────────────────────────
# _sync_lane_status_totals
# ──────────────────────────────────────────────────────────────────────


class TestSyncLaneStatusTotals:
    def test_no_lane_status_file_noop(self, tmp_path: Path) -> None:
        """lane-status.json missing → noop, không raise."""
        # Should silently return
        _sync_lane_status_totals(
            lane_dir=tmp_path,
            signals=[{"severity": "high"}],
            probes_executed=1,
        )
        # Không tạo file mới
        assert not (tmp_path / "lane-status.json").exists()

    def test_corrupt_lane_status_returns_silently(self, tmp_path: Path) -> None:
        """lane-status.json corrupt → return silently."""
        f = tmp_path / "lane-status.json"
        f.write_text("not json")
        _sync_lane_status_totals(
            lane_dir=tmp_path,
            signals=[],
            probes_executed=0,
        )
        # File không bị ghi đè
        assert f.read_text() == "not json"

    def test_root_not_dict_returns_silently(self, tmp_path: Path) -> None:
        """lane-status.json root là array → noop."""
        f = tmp_path / "lane-status.json"
        f.write_text("[]")
        _sync_lane_status_totals(
            lane_dir=tmp_path, signals=[], probes_executed=0
        )
        assert f.read_text() == "[]"

    def test_updates_severity_counts(self, tmp_path: Path) -> None:
        """Existing lane-status có totals → update signals_emitted + by_severity."""
        f = tmp_path / "lane-status.json"
        f.write_text(json.dumps({"totals": {"probes_run": 1}}))
        signals = [
            {"severity": "critical"},
            {"severity": "critical"},
            {"severity": "high"},
            {"severity": "info"},
            {"severity": "weird"},  # ignored
            "not a dict",  # ignored
        ]
        _sync_lane_status_totals(
            lane_dir=tmp_path, signals=signals, probes_executed=2
        )
        loaded = json.loads(f.read_text(encoding="utf-8"))
        assert loaded["totals"]["signals_emitted"] == 6
        assert loaded["totals"]["signals_by_severity"]["critical"] == 2
        assert loaded["totals"]["signals_by_severity"]["high"] == 1
        assert loaded["totals"]["signals_by_severity"]["info"] == 1
        # probes_run = max(1 prev, 2 incoming) = 2
        assert loaded["totals"]["probes_run"] == 2

    def test_creates_totals_if_missing(self, tmp_path: Path) -> None:
        """lane-status không có 'totals' field → tạo mới."""
        f = tmp_path / "lane-status.json"
        f.write_text(json.dumps({"lane": "QD1"}))
        _sync_lane_status_totals(
            lane_dir=tmp_path, signals=[{"severity": "low"}], probes_executed=1
        )
        loaded = json.loads(f.read_text(encoding="utf-8"))
        assert "totals" in loaded
        assert loaded["totals"]["signals_emitted"] == 1
        assert loaded["totals"]["signals_by_severity"]["low"] == 1


# ──────────────────────────────────────────────────────────────────────
# _post_gate_lane — POST-GATE T1/T2
# ──────────────────────────────────────────────────────────────────────


class TestPostGateLane:
    def test_missing_file_fails_t1(self, tmp_path: Path) -> None:
        ok, errors = _post_gate_lane(tmp_path / "missing.json")
        assert ok is False
        assert any("không tồn tại" in e for e in errors)

    def test_empty_file_fails_t1(self, tmp_path: Path) -> None:
        f = tmp_path / "empty.json"
        f.write_text("")
        ok, errors = _post_gate_lane(f)
        assert ok is False
        assert any("rỗng" in e for e in errors)

    def test_invalid_json_fails_t2(self, tmp_path: Path) -> None:
        f = tmp_path / "bad.json"
        f.write_text("{ not json")
        ok, errors = _post_gate_lane(f)
        assert ok is False
        assert any("JSON parse fail" in e for e in errors)

    def test_root_not_object_fails(self, tmp_path: Path) -> None:
        f = tmp_path / "list.json"
        f.write_text("[1,2,3]")
        ok, errors = _post_gate_lane(f)
        assert ok is False
        assert any("phải là object" in e for e in errors)

    def test_wrong_schema_fails(self, tmp_path: Path) -> None:
        f = tmp_path / "wrong.json"
        f.write_text(json.dumps({"$schema": "wrong-v999", "signals": []}))
        ok, errors = _post_gate_lane(f)
        assert ok is False
        assert any("$schema" in e for e in errors)

    def test_signals_not_list_fails(self, tmp_path: Path) -> None:
        f = tmp_path / "bad-signals.json"
        f.write_text(
            json.dumps({"$schema": SIGNALS_SCHEMA_ID, "signals": "not list"})
        )
        ok, errors = _post_gate_lane(f)
        assert ok is False
        assert any("signals phải là array" in e for e in errors)

    def test_valid_passes(self, tmp_path: Path) -> None:
        f = tmp_path / "ok.json"
        f.write_text(
            json.dumps({"$schema": SIGNALS_SCHEMA_ID, "signals": []})
        )
        ok, errors = _post_gate_lane(f)
        assert ok is True
        assert errors == []


# ──────────────────────────────────────────────────────────────────────
# _lane_already_complete
# ──────────────────────────────────────────────────────────────────────


class TestLaneAlreadyComplete:
    def test_missing_file(self, tmp_path: Path) -> None:
        already, n = _lane_already_complete(tmp_path / "missing.json")
        assert already is False
        assert n == 0

    def test_invalid_post_gate(self, tmp_path: Path) -> None:
        f = tmp_path / "bad.json"
        f.write_text("not json")
        already, n = _lane_already_complete(f)
        assert already is False
        assert n == 0

    def test_valid_with_probes_executed(self, tmp_path: Path) -> None:
        f = tmp_path / "ok.json"
        f.write_text(json.dumps({
            "$schema": SIGNALS_SCHEMA_ID,
            "signals": [],
            "probes_executed": 5,
        }))
        already, n = _lane_already_complete(f)
        assert already is True
        assert n == 5

    def test_valid_without_probes_executed_field(self, tmp_path: Path) -> None:
        """File pass POST-GATE nhưng không có probes_executed → n=0 (default)."""
        f = tmp_path / "ok2.json"
        f.write_text(json.dumps({
            "$schema": SIGNALS_SCHEMA_ID,
            "signals": [],
        }))
        already, n = _lane_already_complete(f)
        assert already is True
        assert n == 0

    def test_invalid_probes_executed_value(self, tmp_path: Path) -> None:
        """probes_executed là str non-numeric → n=0 (ValueError caught)."""
        f = tmp_path / "ok3.json"
        f.write_text(json.dumps({
            "$schema": SIGNALS_SCHEMA_ID,
            "signals": [],
            "probes_executed": "not_an_int",
        }))
        already, n = _lane_already_complete(f)
        assert already is True
        assert n == 0


# ──────────────────────────────────────────────────────────────────────
# dispatch_lanes sync wrapper — partial coverage
# ──────────────────────────────────────────────────────────────────────


class TestDispatchLanesSyncSurface:
    def test_empty_dimensions_raises(self, tmp_path: Path) -> None:
        """dispatch_lanes([]) → ValueError."""
        with pytest.raises(ValueError, match="dimensions không được rỗng"):
            dispatch_lanes(
                session_dir=tmp_path,
                dimensions=[],
                profile="standard",
                workflow_root=tmp_path,
            )


# ──────────────────────────────────────────────────────────────────────
# main() CLI
# ──────────────────────────────────────────────────────────────────────


class TestMainCLI:
    def test_main_no_dimensions_returns_1(self, tmp_path: Path, capsys) -> None:
        """main không có --dims → argparse SystemExit (required arg)."""
        with pytest.raises(SystemExit):
            main(["--session-dir", str(tmp_path)])

    def test_main_invokes_dispatch_lanes(
        self, tmp_path: Path, monkeypatch, capsys
    ) -> None:
        """main([...]) gọi dispatch_lanes + print result."""
        # Mock dispatch_lanes để tránh thực thi probes
        called = {}

        def fake_dispatch(**kwargs):
            called.update(kwargs)
            return {"QD1": tmp_path / "lanes" / "QD1" / "signals.json"}

        monkeypatch.setattr(
            "lane_dispatch.dispatch_lanes", fake_dispatch
        )
        rc = main([
            "--session-dir", str(tmp_path),
            "--dims", "QD1",
            "--profile", "standard",
            "--max-parallel", "1",
        ])
        assert rc == 0
        # Kết quả printed ra stdout
        out = capsys.readouterr().out
        assert "QD1" in out

    def test_main_unknown_args_warning(
        self, tmp_path: Path, monkeypatch, capsys
    ) -> None:
        """Unknown args → print warning đến stderr nhưng vẫn dispatch."""
        monkeypatch.setattr(
            "lane_dispatch.dispatch_lanes",
            lambda **kw: {},
        )
        rc = main([
            "--session-dir", str(tmp_path),
            "--dims", "QD1",
            "--unknown-flag", "value",
        ])
        assert rc == 0
        err = capsys.readouterr().err
        assert "WARNING" in err or "Unknown" in err

    def test_main_dispatch_raises_value_error_returns_1(
        self, tmp_path: Path, monkeypatch, capsys
    ) -> None:
        """dispatch_lanes raise ValueError → main return 1, log error."""

        def boom(**kwargs):
            raise ValueError("simulated dispatch error")

        monkeypatch.setattr("lane_dispatch.dispatch_lanes", boom)
        rc = main([
            "--session-dir", str(tmp_path),
            "--dims", "QD1",
        ])
        assert rc == 1
        err = capsys.readouterr().err
        assert "ERROR" in err

    def test_main_dispatch_raises_runtime_error_returns_1(
        self, tmp_path: Path, monkeypatch, capsys
    ) -> None:
        """dispatch_lanes raise RuntimeError → main return 1."""

        def boom(**kwargs):
            raise RuntimeError("rt boom")

        monkeypatch.setattr("lane_dispatch.dispatch_lanes", boom)
        rc = main([
            "--session-dir", str(tmp_path),
            "--dims", "QD1",
        ])
        assert rc == 1
