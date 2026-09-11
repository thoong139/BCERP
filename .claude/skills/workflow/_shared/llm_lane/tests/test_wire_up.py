"""Tests cho Phase C v8 wire-up modules: emit_invocations, emit_signals, merge_signals."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from llm_lane.emit_invocations import emit_invocations
from llm_lane.emit_signals import emit_signals
from llm_lane.merge_signals import merge_lane


def _make_session(tmp_path: Path, *, llm_scan: bool = True, profile: str = "deep") -> Path:
    """Tao 1 session_dir gia voi fix-status.json."""
    sd = tmp_path / "session"
    sd.mkdir()
    fix_status = {
        "fix_id": "test-01",
        "flags": {"llm_scan": llm_scan},
        "profile_used": profile,
    }
    (sd / "fix-status.json").write_text(json.dumps(fix_status), encoding="utf-8")
    return sd


# ────────────────────────────────────────────────────────────
# emit_invocations
# ────────────────────────────────────────────────────────────


class TestEmitInvocations:
    def test_skip_when_llm_scan_disabled(self, tmp_path: Path):
        sd = _make_session(tmp_path, llm_scan=False)
        result = emit_invocations(session_dir=sd, profile="deep", repo_root=tmp_path)
        assert result == []

    def test_skip_when_profile_quick(self, tmp_path: Path):
        sd = _make_session(tmp_path, llm_scan=True)
        result = emit_invocations(session_dir=sd, profile="quick", repo_root=tmp_path)
        assert result == []

    def test_skip_when_profile_standard(self, tmp_path: Path):
        sd = _make_session(tmp_path, llm_scan=True)
        result = emit_invocations(session_dir=sd, profile="standard", repo_root=tmp_path)
        assert result == []

    def test_emits_invocations_when_enabled(self, tmp_path: Path):
        sd = _make_session(tmp_path, llm_scan=True)
        result = emit_invocations(session_dir=sd, profile="deep", repo_root=tmp_path)
        assert len(result) > 0
        for inv in result:
            assert "probe_id" in inv
            assert "dimension" in inv
            assert "prompt_template" in inv
            assert "output_signals_path" in inv
            assert "is_cross_cutting" in inv

    def test_dims_filter(self, tmp_path: Path):
        sd = _make_session(tmp_path, llm_scan=True)
        result = emit_invocations(
            session_dir=sd, profile="deep",
            dims_filter=["QD2", "QD3"], repo_root=tmp_path,
        )
        for inv in result:
            dims = inv["dimensions"]
            assert any(d in ["QD2", "QD3"] for d in dims), f"Unexpected dims: {dims}"

    def test_cross_cutting_routes_to_cross_dir(self, tmp_path: Path):
        sd = _make_session(tmp_path, llm_scan=True)
        result = emit_invocations(session_dir=sd, profile="deep", repo_root=tmp_path)
        cross_invs = [i for i in result if i["is_cross_cutting"]]
        for inv in cross_invs:
            assert inv["dimension"] == "cross"
            assert "/cross/" in inv["output_signals_path"]
            assert inv["lane"] == "cross-cutting"

    def test_dedup_per_probe_id(self, tmp_path: Path):
        sd = _make_session(tmp_path, llm_scan=True)
        result = emit_invocations(session_dir=sd, profile="deep", repo_root=tmp_path)
        probe_ids = [i["probe_id"] for i in result]
        assert len(probe_ids) == len(set(probe_ids)), "Duplicate probe_ids in invocations"


# ────────────────────────────────────────────────────────────
# emit_signals
# ────────────────────────────────────────────────────────────


class TestEmitSignals:
    def test_writes_envelope_with_signals(self, tmp_path: Path):
        sd = _make_session(tmp_path)
        (tmp_path / "test.py").write_text("# line\n" * 20, encoding="utf-8")
        long_desc = "X" * 60
        raw_path = tmp_path / "raw.txt"
        raw_path.write_text(json.dumps({
            "signals": [{
                "title": "Test bug",
                "description": long_desc,
                "severity": "high",
                "location": {"file": "test.py", "line": 5},
            }]
        }), encoding="utf-8")
        out_path = sd / "lanes" / "QD1" / "llm-signals.json"

        count, meta = emit_signals(
            session_dir=sd,
            probe_id="P-QD1-llm-test",
            dimension="QD1",
            lane="wf-fix-functional",
            raw_output_path=raw_path,
            output_signals_path=out_path,
            profile="deep",
            source_dir=tmp_path,
        )
        assert count == 1
        envelope = json.loads(out_path.read_text(encoding="utf-8"))
        assert envelope["$schema"] == "lane-signals-v1"
        assert envelope["dimension"] == "QD1"
        assert envelope["probe_id"] == "P-QD1-llm-test"
        assert envelope["source"] == "llm_probe"
        assert len(envelope["signals"]) == 1

    def test_no_json_in_raw_returns_zero(self, tmp_path: Path):
        sd = _make_session(tmp_path)
        raw_path = tmp_path / "raw.txt"
        raw_path.write_text("Just plain text no JSON", encoding="utf-8")
        out_path = sd / "lanes" / "QD2" / "llm-signals.json"

        count, meta = emit_signals(
            session_dir=sd, probe_id="P", dimension="QD2", lane="L",
            raw_output_path=raw_path, output_signals_path=out_path,
            source_dir=tmp_path,
        )
        assert count == 0
        assert meta.get("dropped_no_json", 0) >= 1

    def test_missing_raw_raises(self, tmp_path: Path):
        sd = _make_session(tmp_path)
        with pytest.raises(FileNotFoundError):
            emit_signals(
                session_dir=sd, probe_id="P", dimension="QD1", lane="L",
                raw_output_path=tmp_path / "missing.txt",
                output_signals_path=sd / "out.json",
                source_dir=tmp_path,
            )


# ────────────────────────────────────────────────────────────
# merge_signals
# ────────────────────────────────────────────────────────────


class TestMergeSignals:
    def _write_static(self, sd: Path, dim: str, signals: list[dict]) -> Path:
        path = sd / "lanes" / dim / "signals.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        envelope = {
            "$schema": "lane-signals-v2",
            "dimension": dim,
            "profile": "deep",
            "signals": signals,
        }
        path.write_text(json.dumps(envelope), encoding="utf-8")
        return path

    def _write_llm(self, sd: Path, dim: str, signals: list[dict]) -> Path:
        path = sd / "lanes" / dim / "llm-signals.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        envelope = {
            "$schema": "lane-signals-v1",
            "dimension": dim,
            "signals": signals,
        }
        path.write_text(json.dumps(envelope), encoding="utf-8")
        return path

    def test_merges_static_plus_llm(self, tmp_path: Path):
        sd = _make_session(tmp_path)
        self._write_static(sd, "QD1", [
            {"title": "Static A", "fingerprint": "sha256:s1"},
        ])
        self._write_llm(sd, "QD1", [
            {"title": "LLM B", "fingerprint": "sha256:l1"},
        ])
        stats = merge_lane(sd, "QD1")
        assert stats["static_count"] == 1
        assert stats["llm_count"] == 1
        assert stats["dedup_dropped"] == 0
        assert stats["final_count"] == 2

    def test_dedup_by_fingerprint(self, tmp_path: Path):
        sd = _make_session(tmp_path)
        self._write_static(sd, "QD2", [
            {"title": "Static", "fingerprint": "sha256:dup1"},
        ])
        self._write_llm(sd, "QD2", [
            {"title": "LLM dup", "fingerprint": "sha256:dup1"},
            {"title": "LLM new", "fingerprint": "sha256:l2"},
        ])
        stats = merge_lane(sd, "QD2")
        assert stats["dedup_dropped"] == 1
        assert stats["final_count"] == 2

    def test_skips_when_no_llm(self, tmp_path: Path):
        sd = _make_session(tmp_path)
        self._write_static(sd, "QD3", [{"title": "Only static", "fingerprint": "sha256:o1"}])
        stats = merge_lane(sd, "QD3")
        assert stats["llm_count"] == 0
        assert stats["final_count"] == 1

    def test_cross_signals_dispatched_by_dim(self, tmp_path: Path):
        sd = _make_session(tmp_path)
        self._write_static(sd, "QD1", [{"title": "Static QD1", "fingerprint": "sha256:s1"}])
        cross_path = sd / "lanes" / "cross" / "P-LLM-integration" / "llm-signals.json"
        cross_path.parent.mkdir(parents=True, exist_ok=True)
        cross_path.write_text(json.dumps({
            "$schema": "lane-signals-v1",
            "signals": [
                {"title": "Cross QD1", "dimension_id": "QD1", "fingerprint": "sha256:c1"},
                {"title": "Cross QD2", "dimension_id": "QD2", "fingerprint": "sha256:c2"},
            ],
        }), encoding="utf-8")

        stats = merge_lane(sd, "QD1")
        assert stats["cross_count"] == 1
        merged = json.loads((sd / "lanes" / "QD1" / "signals.json").read_text(encoding="utf-8"))
        titles = [s["title"] for s in merged["signals"]]
        assert "Cross QD1" in titles
        assert "Cross QD2" not in titles

    def test_raises_when_static_missing(self, tmp_path: Path):
        sd = _make_session(tmp_path)
        with pytest.raises(FileNotFoundError):
            merge_lane(sd, "QD7")
