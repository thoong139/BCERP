"""test_cache_store_xf08.py — XF-08 (Sprint 6) coverage uplift.

Verify scan_cache.cache_store:
- set_entry: write cache entry + ADR-22 rule 6 QD3 reject (dimension_id + dimension_hint)
- clear_older_than: prune entries by age + corrupt entry cleanup
- migrate_legacy_signals: dimension_hint → dimension_id, QD3 delete
- CLI subcommands: set, clear, migrate, _parse_duration
"""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from scan_cache.cache_store import (
    DEFAULT_TTL_DAYS,
    QD3_FORBIDDEN,
    SCHEMA_ID,
    _atomic_write_json,
    _parse_duration,
    clear_older_than,
    main,
    migrate_legacy_signals,
    set_entry,
)


# ──────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────


def test_schema_id_versioned() -> None:
    assert SCHEMA_ID == "cache-entry-v1"


def test_qd3_forbidden() -> None:
    assert QD3_FORBIDDEN == "QD3"


def test_default_ttl_14_days() -> None:
    assert DEFAULT_TTL_DAYS == 14


# ──────────────────────────────────────────────────────────────────────
# set_entry
# ──────────────────────────────────────────────────────────────────────


class TestSetEntry:
    def test_writes_entry_file(self, tmp_path: Path) -> None:
        entry_path = set_entry(
            cache_root=tmp_path,
            fingerprint="a" * 64,
            probe_id="P-QD1-test",
            probe_version="1.0.0",
            file_path="src/x.ts",
            file_content_sha="b" * 64,
            signals=[{"dimension_id": "QD1", "evidence": "x"}],
        )
        assert entry_path.exists()
        data = json.loads(entry_path.read_text(encoding="utf-8"))
        assert data["$schema"] == SCHEMA_ID
        assert data["probe_id"] == "P-QD1-test"
        assert data["fingerprint"] == "a" * 64

    def test_qd3_dimension_id_rejected(self, tmp_path: Path) -> None:
        """ADR-22 rule 6: signal có dimension_id=QD3 → ValueError."""
        with pytest.raises(ValueError, match="ADR-22 rule 6"):
            set_entry(
                cache_root=tmp_path,
                fingerprint="a" * 64,
                probe_id="P-QD3-x",
                probe_version="1.0.0",
                file_path="src/x.ts",
                file_content_sha="b" * 64,
                signals=[{"dimension_id": "QD3"}],
            )

    def test_qd3_legacy_dimension_hint_rejected(self, tmp_path: Path) -> None:
        """Legacy dimension_hint=QD3 cũng phải reject (defense-in-depth)."""
        with pytest.raises(ValueError, match="ADR-22 rule 6"):
            set_entry(
                cache_root=tmp_path,
                fingerprint="a" * 64,
                probe_id="P-QD3-x",
                probe_version="1.0.0",
                file_path="src/x.ts",
                file_content_sha="b" * 64,
                signals=[{"dimension_hint": "QD3"}],
            )

    def test_ttl_applied(self, tmp_path: Path) -> None:
        entry_path = set_entry(
            cache_root=tmp_path,
            fingerprint="a" * 64,
            probe_id="P-QD1-test",
            probe_version="1.0.0",
            file_path="src/x.ts",
            file_content_sha="b" * 64,
            signals=[],
            ttl_days=7,
        )
        data = json.loads(entry_path.read_text(encoding="utf-8"))
        cached = datetime.fromisoformat(data["cached_at"])
        expires = datetime.fromisoformat(data["ttl_expires_at"])
        delta = expires - cached
        assert abs(delta.days - 7) <= 1


# ──────────────────────────────────────────────────────────────────────
# clear_older_than
# ──────────────────────────────────────────────────────────────────────


class TestClearOlderThan:
    def test_negative_raises(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match=">= 0"):
            clear_older_than(tmp_path, -1)

    def test_missing_root_returns_0(self, tmp_path: Path) -> None:
        assert clear_older_than(tmp_path / "missing", 7) == 0

    def test_deletes_old(self, tmp_path: Path) -> None:
        # Tạo 2 entries: 1 cũ (cached_at > 30 ngày), 1 mới
        old = tmp_path / "old.json"
        new = tmp_path / "new.json"
        old_dt = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
        new_dt = datetime.now(timezone.utc).isoformat()
        old.write_text(json.dumps({"cached_at": old_dt}), encoding="utf-8")
        new.write_text(json.dumps({"cached_at": new_dt}), encoding="utf-8")

        count = clear_older_than(tmp_path, 7)
        assert count == 1
        assert not old.exists()
        assert new.exists()

    def test_corrupt_entry_deleted(self, tmp_path: Path) -> None:
        """Entry corrupt JSON → delete để tránh pollute cache."""
        corrupt = tmp_path / "bad.json"
        corrupt.write_text("not valid json", encoding="utf-8")
        count = clear_older_than(tmp_path, 7)
        assert count == 1
        assert not corrupt.exists()

    def test_no_cached_at_deleted(self, tmp_path: Path) -> None:
        """Entry không có cached_at → corrupt, delete."""
        entry = tmp_path / "no-cached-at.json"
        entry.write_text(json.dumps({"x": 1}), encoding="utf-8")
        count = clear_older_than(tmp_path, 7)
        assert count == 1


# ──────────────────────────────────────────────────────────────────────
# migrate_legacy_signals
# ──────────────────────────────────────────────────────────────────────


class TestMigrateLegacySignals:
    def test_missing_root(self, tmp_path: Path) -> None:
        assert migrate_legacy_signals(tmp_path / "missing") == (0, 0)

    def test_rename_dimension_hint(self, tmp_path: Path) -> None:
        """Signal với dimension_hint != QD3 → rename → dimension_id."""
        entry = tmp_path / "e.json"
        entry.write_text(json.dumps({
            "signals_emitted": [{"dimension_hint": "QD1"}],
        }), encoding="utf-8")

        migrated, deleted = migrate_legacy_signals(tmp_path)
        assert migrated == 1
        assert deleted == 0
        data = json.loads(entry.read_text(encoding="utf-8"))
        assert data["signals_emitted"][0]["dimension_id"] == "QD1"
        assert "dimension_hint" not in data["signals_emitted"][0]

    def test_qd3_legacy_deleted(self, tmp_path: Path) -> None:
        """dimension_hint=QD3 → DELETE entry (ADR-22 rule 6)."""
        entry = tmp_path / "e.json"
        entry.write_text(json.dumps({
            "signals_emitted": [{"dimension_hint": "QD3"}],
        }), encoding="utf-8")

        migrated, deleted = migrate_legacy_signals(tmp_path)
        assert migrated == 0
        assert deleted == 1
        assert not entry.exists()

    def test_no_change_when_already_migrated(self, tmp_path: Path) -> None:
        """Signal đã có dimension_id → no-op."""
        entry = tmp_path / "e.json"
        entry.write_text(json.dumps({
            "signals_emitted": [{"dimension_id": "QD1"}],
        }), encoding="utf-8")

        migrated, deleted = migrate_legacy_signals(tmp_path)
        assert migrated == 0
        assert deleted == 0

    def test_skip_corrupt_entry(self, tmp_path: Path) -> None:
        """Corrupt JSON → continue (no count)."""
        entry = tmp_path / "bad.json"
        entry.write_text("not json", encoding="utf-8")
        result = migrate_legacy_signals(tmp_path)
        assert result == (0, 0)


# ──────────────────────────────────────────────────────────────────────
# _parse_duration
# ──────────────────────────────────────────────────────────────────────


class TestParseDuration:
    def test_valid_days(self) -> None:
        assert _parse_duration("14d") == 14

    def test_zero(self) -> None:
        assert _parse_duration("0d") == 0

    def test_negative_raises(self) -> None:
        import argparse
        with pytest.raises(argparse.ArgumentTypeError, match=">= 0"):
            _parse_duration("-1d")

    def test_no_d_suffix(self) -> None:
        import argparse
        with pytest.raises(argparse.ArgumentTypeError, match="Expected <n>d"):
            _parse_duration("14")

    def test_invalid_number(self) -> None:
        import argparse
        with pytest.raises(argparse.ArgumentTypeError, match="Invalid duration"):
            _parse_duration("abc d")


# ──────────────────────────────────────────────────────────────────────
# _atomic_write_json error handling
# ──────────────────────────────────────────────────────────────────────


class TestAtomicWriteJson:
    def test_write_and_read(self, tmp_path: Path) -> None:
        target = tmp_path / "x.json"
        _atomic_write_json(target, {"key": "value"})
        assert target.exists()
        assert json.loads(target.read_text(encoding="utf-8")) == {"key": "value"}

    def test_creates_parent_dir(self, tmp_path: Path) -> None:
        target = tmp_path / "subdir" / "x.json"
        _atomic_write_json(target, {"k": 1})
        assert target.exists()


# ──────────────────────────────────────────────────────────────────────
# CLI main()
# ──────────────────────────────────────────────────────────────────────


class TestCLI:
    def test_clear_subcommand(self, capsys, tmp_path: Path) -> None:
        rc = main(["clear", "--cache-root", str(tmp_path), "--older-than", "7d"])
        captured = capsys.readouterr()
        assert rc == 0
        assert "0 entry" in captured.err  # No entries to clear

    def test_migrate_subcommand(self, capsys, tmp_path: Path) -> None:
        rc = main(["migrate", "--cache-root", str(tmp_path)])
        captured = capsys.readouterr()
        assert rc == 0
        assert "Migrated 0 entry" in captured.err
