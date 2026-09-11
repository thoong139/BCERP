"""test_signal_aggregator_xf08.py — XF-08 (Sprint 6) coverage uplift.

Verify signal_aggregator helpers:
- AggregationStats dataclass (warnings field new Sprint 6)
- _read_signals_from_file: parse/struct/format errors
- _read_signals_from_source: subdirectory hit/miss
- _read_signals_from_legacy: warning notice + reject when missing
- _legacy_signals_exists: file existence check
- _load_probe_failures: JSONL parse, malformed lines
- _normalize_probe_signal: full normalization paths (location, evidence as list,
  registry_refs symbol fallback, lane derivation)
- aggregate_lane_signals: end-to-end với edge cases
- CLI main()
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from signal_aggregator import (
    AggregationStats,
    _legacy_signals_exists,
    _load_probe_failures,
    _normalize_probe_signal,
    _read_signals_from_file,
    _read_signals_from_legacy,
    _read_signals_from_source,
    aggregate_lane_signals,
    main,
)


# ──────────────────────────────────────────────────────────────────────
# AggregationStats
# ──────────────────────────────────────────────────────────────────────


class TestAggregationStats:
    def test_default_factory(self) -> None:
        stats = AggregationStats(total_signals=0, total_issues=0)
        assert stats.errors == []
        assert stats.warnings == []  # Sprint 6 new field
        assert stats.by_dimension == {}
        assert stats.probe_failures == []
        assert stats.probe_failures_count == 0


# ──────────────────────────────────────────────────────────────────────
# _read_signals_from_file
# ──────────────────────────────────────────────────────────────────────


class TestReadSignalsFromFile:
    def test_valid_signals(self, tmp_path: Path) -> None:
        path = tmp_path / "signals.json"
        path.write_text(json.dumps({"signals": [{"probe_id": "x"}]}), encoding="utf-8")
        stats = AggregationStats(total_signals=0, total_issues=0)
        result = _read_signals_from_file(path, "label", stats)
        assert len(result) == 1

    def test_corrupt_json_appends_error(self, tmp_path: Path) -> None:
        path = tmp_path / "bad.json"
        path.write_text("not json", encoding="utf-8")
        stats = AggregationStats(total_signals=0, total_issues=0)
        result = _read_signals_from_file(path, "label", stats)
        assert result == []
        assert len(stats.errors) == 1
        assert "parse fail" in stats.errors[0]

    def test_root_not_object_appends_error(self, tmp_path: Path) -> None:
        path = tmp_path / "arr.json"
        path.write_text("[]", encoding="utf-8")
        stats = AggregationStats(total_signals=0, total_issues=0)
        result = _read_signals_from_file(path, "label", stats)
        assert result == []
        assert "root không phải object" in stats.errors[0]

    def test_signals_not_array(self, tmp_path: Path) -> None:
        path = tmp_path / "x.json"
        path.write_text(json.dumps({"signals": "not array"}), encoding="utf-8")
        stats = AggregationStats(total_signals=0, total_issues=0)
        result = _read_signals_from_file(path, "label", stats)
        assert result == []
        assert "không phải array" in stats.errors[0]


# ──────────────────────────────────────────────────────────────────────
# _read_signals_from_source / _read_signals_from_legacy
# ──────────────────────────────────────────────────────────────────────


class TestReadSignalsFromSource:
    def test_missing_source_returns_empty(self, tmp_path: Path) -> None:
        stats = AggregationStats(total_signals=0, total_issues=0)
        result = _read_signals_from_source(tmp_path, "QD1", "static-scan", stats)
        assert result == []

    def test_present_source_reads(self, tmp_path: Path) -> None:
        source = tmp_path / "lanes" / "QD1" / "static-scan"
        source.mkdir(parents=True)
        (source / "signals.json").write_text(
            json.dumps({"signals": [{"probe_id": "P-QD1-a"}]}),
            encoding="utf-8",
        )
        stats = AggregationStats(total_signals=0, total_issues=0)
        result = _read_signals_from_source(tmp_path, "QD1", "static-scan", stats)
        assert len(result) == 1


class TestReadSignalsFromLegacy:
    def test_missing_legacy(self, tmp_path: Path) -> None:
        stats = AggregationStats(total_signals=0, total_issues=0)
        result = _read_signals_from_legacy(tmp_path, "QD1", stats)
        assert result == []
        assert stats.warnings == []  # No warning khi file không tồn tại

    def test_present_legacy_warning(self, tmp_path: Path) -> None:
        """Sprint 6: legacy fallback → warning (not error)."""
        lane = tmp_path / "lanes" / "QD1"
        lane.mkdir(parents=True)
        (lane / "signals.json").write_text(
            json.dumps({"signals": [{"probe_id": "P-QD1-a"}]}),
            encoding="utf-8",
        )
        stats = AggregationStats(total_signals=0, total_issues=0)
        result = _read_signals_from_legacy(tmp_path, "QD1", stats)
        assert len(result) == 1
        assert len(stats.warnings) == 1
        assert "legacy fallback" in stats.warnings[0]
        assert stats.errors == []


class TestLegacySignalsExists:
    def test_missing(self, tmp_path: Path) -> None:
        assert _legacy_signals_exists(tmp_path, "QD1") is False

    def test_present(self, tmp_path: Path) -> None:
        lane = tmp_path / "lanes" / "QD1"
        lane.mkdir(parents=True)
        (lane / "signals.json").write_text("{}", encoding="utf-8")
        assert _legacy_signals_exists(tmp_path, "QD1") is True


# ──────────────────────────────────────────────────────────────────────
# _load_probe_failures
# ──────────────────────────────────────────────────────────────────────


class TestLoadProbeFailures:
    def test_missing_file(self, tmp_path: Path) -> None:
        assert _load_probe_failures(tmp_path) == []

    def test_valid_jsonl(self, tmp_path: Path) -> None:
        log = tmp_path / "probe-failures.log"
        log.write_text(
            '{"probe_id": "P-QD1-x", "reason": "timeout"}\n'
            '{"probe_id": "P-QD3-y", "reason": "exit"}\n',
            encoding="utf-8",
        )
        result = _load_probe_failures(tmp_path)
        assert len(result) == 2

    def test_skips_malformed_lines(self, tmp_path: Path) -> None:
        log = tmp_path / "probe-failures.log"
        log.write_text(
            '{"valid": 1}\n'
            'invalid json line\n'
            '\n'  # Empty line
            '{"another": 2}\n',
            encoding="utf-8",
        )
        result = _load_probe_failures(tmp_path)
        assert len(result) == 2

    def test_non_dict_skipped(self, tmp_path: Path) -> None:
        log = tmp_path / "probe-failures.log"
        log.write_text('"string-not-dict"\n[1,2]\n', encoding="utf-8")
        result = _load_probe_failures(tmp_path)
        assert result == []


# ──────────────────────────────────────────────────────────────────────
# _normalize_probe_signal
# ──────────────────────────────────────────────────────────────────────


class TestNormalizeProbeSignal:
    def test_not_dict_passthrough(self) -> None:
        result = _normalize_probe_signal("not a dict")  # type: ignore
        assert result == "not a dict"

    def test_detected_at_to_emitted_at(self) -> None:
        result = _normalize_probe_signal({
            "detected_at": "2026-05-15",
            "dimension_id": "QD1",
        })
        assert result["emitted_at"] == "2026-05-15"

    def test_lane_derived_from_dimension(self) -> None:
        """F06.005: dùng DIMENSION_REGISTRY thay vì hardcoded dict."""
        for dim, expected_lane in [
            ("QD1", "wf-fix-functional"),
            ("QD3", "wf-fix-security"),
            ("QD11", "wf-fix-business-completeness"),
        ]:
            result = _normalize_probe_signal({"dimension_id": dim})
            assert result["lane"] == expected_lane

    def test_target_from_location(self) -> None:
        result = _normalize_probe_signal({
            "location": {"file": "src/x.ts", "line": 10},
            "dimension_id": "QD1",
        })
        assert result["target"]["file_path"] == "src/x.ts"
        assert result["target"]["kind"] == "code"
        assert result["target"]["line"] == 10

    def test_target_symbol_from_registry_refs(self) -> None:
        result = _normalize_probe_signal({
            "registry_refs": {"feat_ids": ["FEAT-X"]},
            "dimension_id": "QD1",
        })
        assert result["target"]["symbol"] == "FEAT-X"

    def test_target_kind_logical_no_file(self) -> None:
        """Không có file_path → kind=logical."""
        result = _normalize_probe_signal({
            "location": {"file": "N/A"},
            "dimension_id": "QD1",
        })
        assert result["target"]["kind"] == "logical"
        assert result["target"]["file_path"] is None

    def test_evidence_array_to_dict(self) -> None:
        result = _normalize_probe_signal({
            "evidence": [
                {"type": "code", "path": "x.ts", "description": "bug found here"},
                {"type": "log", "path": "y.log", "description": "error logged at"},
            ],
            "dimension_id": "QD1",
        })
        assert isinstance(result["evidence"], dict)
        assert "code_snippet" in result["evidence"]

    def test_evidence_short_padded(self) -> None:
        """Evidence < 10 chars → pad với title."""
        result = _normalize_probe_signal({
            "evidence": [{"description": "x"}],
            "title": "Long title text here",
            "dimension_id": "QD1",
        })
        assert len(result["evidence"]["code_snippet"]) >= 10

    def test_invalid_dim_lane_fallback(self) -> None:
        result = _normalize_probe_signal({"dimension_id": "QD99"})
        # Invalid dim → fallback wf-fix-functional
        assert result["lane"] == "wf-fix-functional"


# ──────────────────────────────────────────────────────────────────────
# aggregate_lane_signals
# ──────────────────────────────────────────────────────────────────────


def _create_lane_signals(session: Path, dim: str, signals: list[dict]) -> None:
    """Helper write legacy lanes/{dim}/signals.json."""
    lane = session / "lanes" / dim
    lane.mkdir(parents=True, exist_ok=True)
    (lane / "signals.json").write_text(
        json.dumps({"$schema": "lane-signals-v1", "dimension": dim, "signals": signals}),
        encoding="utf-8",
    )


class TestAggregateLaneSignals:
    def test_warnings_not_errors_for_legacy(self, tmp_path: Path) -> None:
        """Sprint 6: legacy fallback notice → warnings, không errors."""
        _create_lane_signals(tmp_path, "QD1", [])
        _, stats = aggregate_lane_signals(tmp_path, ["QD1"])
        assert stats.errors == []  # No fatal errors
        assert len(stats.warnings) == 1  # Legacy fallback notice

    def test_missing_lane_appends_error(self, tmp_path: Path) -> None:
        """Lane hoàn toàn missing → error (not warning)."""
        _, stats = aggregate_lane_signals(tmp_path, ["QD1"])
        assert any("không tồn tại" in e for e in stats.errors)


# ──────────────────────────────────────────────────────────────────────
# CLI main()
# ──────────────────────────────────────────────────────────────────────


class TestCLI:
    def test_main_empty_session(self, capsys, tmp_path: Path) -> None:
        """Empty session: missing lane → exit 1 (errors)."""
        rc = main(["--session-dir", str(tmp_path), "--dims", "QD1"])
        captured = capsys.readouterr()
        # Returns 1 vì stats.errors non-empty (lane missing)
        assert rc == 1
        assert "errors" in captured.out
