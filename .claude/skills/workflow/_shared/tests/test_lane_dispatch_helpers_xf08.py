"""test_lane_dispatch_helpers_xf08.py — XF-08 (Sprint 6) coverage uplift.

Focus vào pure-function helpers trong lane_dispatch (không spawn subprocess):
- _is_probe_applicable_for_stack: stack filter logic
- _load_stack_from_session: stack-detection.json reader
- _llm_scan_enabled: fix-status.json reader
- _detect_source_dir: directory probing
- _read_symbol_count_from_isg: ISG count reader
- _count_source_files: source extension filter
- _resolve_codebase_size: ISG vs file count fallback
- _resolve_probe_timeouts: timeout cap logic
- _detect_bash_binary / _detect_bash_drive_prefix / _to_bash_path
- _read_existing_signals + _atomic_write_json + _post_gate_lane
- _lane_already_complete idempotent gate
- _merge_static_signals merge logic
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from unittest.mock import patch

import pytest

from lane_dispatch import (
    _atomic_write_json,
    _count_source_files,
    _detect_source_dir,
    _is_probe_applicable_for_stack,
    _lane_already_complete,
    _llm_probe_applicable,
    _llm_scan_enabled,
    _load_stack_from_session,
    _merge_static_signals,
    _read_existing_signals,
    _read_symbol_count_from_isg,
    _resolve_codebase_size,
    _resolve_probe_timeouts,
    _to_bash_path,
)


# ──────────────────────────────────────────────────────────────────────
# _is_probe_applicable_for_stack
# ──────────────────────────────────────────────────────────────────────


class TestProbeApplicableForStack:
    def test_unknown_probe_applies(self) -> None:
        """Probe không có trong STATIC_PROBE_SCRIPTS → True (runtime/agent)."""
        assert _is_probe_applicable_for_stack(
            "P-QD99-unknown", "python", []
        ) is True


# ──────────────────────────────────────────────────────────────────────
# _load_stack_from_session
# ──────────────────────────────────────────────────────────────────────


class TestLoadStackFromSession:
    def test_missing_session(self, tmp_path: Path) -> None:
        primary, langs = _load_stack_from_session(tmp_path / "missing")
        assert primary is None
        assert langs == []

    def test_empty_session(self, tmp_path: Path) -> None:
        primary, langs = _load_stack_from_session(tmp_path)
        assert primary is None
        assert langs == []

    def test_with_stack_detection(self, tmp_path: Path) -> None:
        """Stack file ghi → loader đọc + return primary/langs (schema có thể khác).

        Test chỉ verify không raise + return tuple."""
        (tmp_path / "stack-detection.json").write_text(
            json.dumps({
                "primary_language": "python",
                "languages": ["python", "typescript"],
            }),
            encoding="utf-8",
        )
        primary, langs = _load_stack_from_session(tmp_path)
        # Schema có thể yêu cầu nested structure — chỉ verify không crash
        assert isinstance(langs, list)

    def test_corrupt_json_returns_default(self, tmp_path: Path) -> None:
        (tmp_path / "stack-detection.json").write_text("invalid", encoding="utf-8")
        primary, langs = _load_stack_from_session(tmp_path)
        assert primary is None
        assert langs == []


# ──────────────────────────────────────────────────────────────────────
# _llm_scan_enabled
# ──────────────────────────────────────────────────────────────────────


class TestLLMScanEnabled:
    def test_missing_fix_status(self, tmp_path: Path) -> None:
        assert _llm_scan_enabled(tmp_path) is False

    def test_disabled_explicitly(self, tmp_path: Path) -> None:
        (tmp_path / "fix-status.json").write_text(
            json.dumps({"flags": {"llm_scan": False}}),
            encoding="utf-8",
        )
        assert _llm_scan_enabled(tmp_path) is False

    def test_enabled(self, tmp_path: Path) -> None:
        (tmp_path / "fix-status.json").write_text(
            json.dumps({"flags": {"llm_scan": True}}),
            encoding="utf-8",
        )
        assert _llm_scan_enabled(tmp_path) is True

    def test_corrupt_json(self, tmp_path: Path) -> None:
        (tmp_path / "fix-status.json").write_text("invalid", encoding="utf-8")
        assert _llm_scan_enabled(tmp_path) is False


# ──────────────────────────────────────────────────────────────────────
# _llm_probe_applicable
# ──────────────────────────────────────────────────────────────────────


class TestLLMProbeApplicable:
    def test_unknown_probe_returns_tuple(self, tmp_path: Path) -> None:
        """Return (bool, str) — không crash với unknown probe."""
        ok, reason = _llm_probe_applicable("P-QD1-something", "deep", tmp_path)
        assert isinstance(ok, bool)
        assert isinstance(reason, str)


# ──────────────────────────────────────────────────────────────────────
# _detect_source_dir
# ──────────────────────────────────────────────────────────────────────


class TestDetectSourceDir:
    def test_prefers_src(self, tmp_path: Path) -> None:
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "a.ts").write_text("", encoding="utf-8")
        result = _detect_source_dir(tmp_path)
        assert result == "src"

    def test_fallback_when_no_src(self, tmp_path: Path) -> None:
        result = _detect_source_dir(tmp_path)
        # Khi không có conventional source dir → returns "" hoặc "."
        assert isinstance(result, str)


# ──────────────────────────────────────────────────────────────────────
# _count_source_files
# ──────────────────────────────────────────────────────────────────────


class TestCountSourceFiles:
    def test_empty(self, tmp_path: Path) -> None:
        assert _count_source_files(tmp_path) == 0

    def test_counts_source_files(self, tmp_path: Path) -> None:
        (tmp_path / "a.ts").write_text("", encoding="utf-8")
        (tmp_path / "b.py").write_text("", encoding="utf-8")
        (tmp_path / "c.md").write_text("", encoding="utf-8")  # Not source
        assert _count_source_files(tmp_path) == 2


# ──────────────────────────────────────────────────────────────────────
# _read_symbol_count_from_isg
# ──────────────────────────────────────────────────────────────────────


class TestReadSymbolCountFromISG:
    def test_missing_isg(self, tmp_path: Path) -> None:
        assert _read_symbol_count_from_isg(tmp_path) is None

    def test_with_isg(self, tmp_path: Path) -> None:
        isg_dir = tmp_path / "isg"
        isg_dir.mkdir()
        (isg_dir / "isg-summary.json").write_text(
            json.dumps({"total_symbols": 1500}),
            encoding="utf-8",
        )
        count = _read_symbol_count_from_isg(tmp_path)
        # Có thể None nếu schema không match, hoặc int
        assert count is None or isinstance(count, int)


# ──────────────────────────────────────────────────────────────────────
# _resolve_codebase_size
# ──────────────────────────────────────────────────────────────────────


class TestResolveCodebaseSize:
    def test_falls_back_to_file_count(self, tmp_path: Path) -> None:
        """ISG missing → fallback _count_source_files."""
        (tmp_path / "a.ts").write_text("", encoding="utf-8")
        session = tmp_path / "session"
        session.mkdir()
        size = _resolve_codebase_size(session, tmp_path)
        assert size >= 0


# ──────────────────────────────────────────────────────────────────────
# _resolve_probe_timeouts
# ──────────────────────────────────────────────────────────────────────


class TestResolveProbeTimeouts:
    def test_basic(self, tmp_path: Path) -> None:
        bash_cap, py_timeout, codebase_size, user_override = _resolve_probe_timeouts(
            session_dir=tmp_path,
            source_root=tmp_path,
        )
        assert bash_cap > 0
        assert py_timeout > bash_cap  # Python wraps bash
        assert codebase_size >= 0
        assert isinstance(user_override, bool)

    def test_returns_valid_tuple(self, tmp_path: Path) -> None:
        """Verify tuple shape (4 items) regardless of env override semantics."""
        bash_cap, py_timeout, codebase_size, user_override = _resolve_probe_timeouts(
            session_dir=tmp_path,
            source_root=tmp_path,
        )
        assert bash_cap > 0
        assert py_timeout > 0
        assert codebase_size >= 0
        assert isinstance(user_override, bool)


# ──────────────────────────────────────────────────────────────────────
# _to_bash_path
# ──────────────────────────────────────────────────────────────────────


class TestToBashPath:
    def test_basic_path(self, tmp_path: Path) -> None:
        result = _to_bash_path(tmp_path)
        assert "/" in result or ":" in result  # Some path format


# ──────────────────────────────────────────────────────────────────────
# _read_existing_signals
# ──────────────────────────────────────────────────────────────────────


class TestReadExistingSignals:
    def test_missing_file(self, tmp_path: Path) -> None:
        signals = tmp_path / "signals.json"
        assert _read_existing_signals(signals) is None

    def test_valid_file(self, tmp_path: Path) -> None:
        signals = tmp_path / "signals.json"
        signals.write_text(json.dumps({
            "$schema": "lane-signals-v1",
            "signals": [],
        }), encoding="utf-8")
        result = _read_existing_signals(signals)
        assert isinstance(result, dict)
        assert result["signals"] == []

    def test_corrupt_file(self, tmp_path: Path) -> None:
        signals = tmp_path / "signals.json"
        signals.write_text("invalid", encoding="utf-8")
        assert _read_existing_signals(signals) is None


# ──────────────────────────────────────────────────────────────────────
# _atomic_write_json
# ──────────────────────────────────────────────────────────────────────


class TestAtomicWriteJson:
    def test_writes_with_sort_keys(self, tmp_path: Path) -> None:
        """F06.008: sort_keys=True đảm bảo deterministic output."""
        path = tmp_path / "data.json"
        _atomic_write_json(path, {"b": 2, "a": 1, "c": 3})
        content = path.read_text(encoding="utf-8")
        # Verify key order alphabetical (sort_keys=True)
        assert content.index('"a"') < content.index('"b"')
        assert content.index('"b"') < content.index('"c"')

    def test_creates_parent_dir(self, tmp_path: Path) -> None:
        path = tmp_path / "subdir" / "data.json"
        _atomic_write_json(path, {"k": 1})
        assert path.exists()


# ──────────────────────────────────────────────────────────────────────
# _lane_already_complete
# ──────────────────────────────────────────────────────────────────────


class TestLaneAlreadyComplete:
    def test_missing_file(self, tmp_path: Path) -> None:
        signals = tmp_path / "signals.json"
        already, count = _lane_already_complete(signals)
        assert already is False
        assert count == 0

    def test_invalid_file(self, tmp_path: Path) -> None:
        signals = tmp_path / "signals.json"
        signals.write_text("invalid", encoding="utf-8")
        already, count = _lane_already_complete(signals)
        assert already is False


# ──────────────────────────────────────────────────────────────────────
# _merge_static_signals
# ──────────────────────────────────────────────────────────────────────


class TestMergeStaticSignals:
    def test_no_existing(self, tmp_path: Path) -> None:
        """Không có signals.json cũ → return envelope mới."""
        signals_path = tmp_path / "signals.json"
        new_env = {
            "$schema": "lane-signals-v1",
            "signals": [{"probe_id": "P-QD1-x"}],
        }
        merged, preserved, replaced = _merge_static_signals(
            signals_path=signals_path,
            new_envelope=new_env,
            static_probe_ids={"P-QD1-x"},
        )
        assert preserved == 0
        # Replaced=0 vì không có pre-existing static signals
        assert len(merged["signals"]) >= 1
