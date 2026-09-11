"""test_cache_store.py — Tests cho scan_cache.cache_store.

Phạm vi chính:
    - set_entry happy-path: ghi JSON đúng schema cache-entry-v1.
    - ADR-22 rule 6: signal có dimension_id=QD3 → raise ValueError, KHÔNG ghi file.
    - Atomic write: không còn tmp file nằm lại sau success.
    - clear_older_than: xóa đúng entries cũ, giữ entries mới.
    - Schema-conform: output khớp schema file (top-level fields).
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import pytest

from scan_cache.cache_store import (
    DEFAULT_TTL_DAYS,
    QD3_FORBIDDEN,
    SCHEMA_ID,
    clear_older_than,
    set_entry,
)


FINGERPRINT = "a" * 64
FILE_SHA = "b" * 64


def _read_entry(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


# ──────────────────────────────────────────────────────────────────────
# Happy path
# ──────────────────────────────────────────────────────────────────────


class TestSetEntryHappyPath:
    def test_writes_json_with_required_fields(
        self, tmp_cache_root: Path, sample_signal_dict: dict[str, Any]
    ) -> None:
        out = set_entry(
            cache_root=tmp_cache_root,
            fingerprint=FINGERPRINT,
            probe_id="P-QD1-demo",
            probe_version="0.1.0",
            file_path="src/a.ts",
            file_content_sha=FILE_SHA,
            signals=[sample_signal_dict],
        )
        assert out.exists()
        assert out.name == f"{FINGERPRINT}.json"

        data = _read_entry(out)
        assert data["$schema"] == SCHEMA_ID
        for key in (
            "fingerprint",
            "probe_id",
            "probe_version",
            "file_path",
            "file_content_sha",
            "cached_at",
            "ttl_expires_at",
            "signals_emitted",
            "metadata",
        ):
            assert key in data

    def test_ttl_expires_at_is_cached_plus_ttl_days(
        self, tmp_cache_root: Path, sample_signal_dict: dict[str, Any]
    ) -> None:
        out = set_entry(
            cache_root=tmp_cache_root,
            fingerprint=FINGERPRINT,
            probe_id="P-QD1-demo",
            probe_version="0.1.0",
            file_path="src/a.ts",
            file_content_sha=FILE_SHA,
            signals=[sample_signal_dict],
            ttl_days=DEFAULT_TTL_DAYS,
        )
        data = _read_entry(out)
        cached = datetime.fromisoformat(data["cached_at"])
        expires = datetime.fromisoformat(data["ttl_expires_at"])
        delta = expires - cached
        # Cho phép sai lệch vài giây do tính timestamp riêng
        assert abs(delta.total_seconds() - DEFAULT_TTL_DAYS * 86400) < 5

    def test_atomic_write_no_tmp_leftover(
        self, tmp_cache_root: Path, sample_signal_dict: dict[str, Any]
    ) -> None:
        set_entry(
            cache_root=tmp_cache_root,
            fingerprint=FINGERPRINT,
            probe_id="P-QD1-demo",
            probe_version="0.1.0",
            file_path="src/a.ts",
            file_content_sha=FILE_SHA,
            signals=[sample_signal_dict],
        )
        leftover = [p for p in tmp_cache_root.iterdir() if p.name.endswith(".tmp")]
        assert leftover == []


# ──────────────────────────────────────────────────────────────────────
# ADR-22 rule 6 — QD3 never cached
# ──────────────────────────────────────────────────────────────────────


class TestADR22Rule6QD3Forbidden:
    def test_qd3_signal_raises_value_error(
        self, tmp_cache_root: Path, qd3_signal_dict: dict[str, Any]
    ) -> None:
        with pytest.raises(ValueError, match="ADR-22 rule 6"):
            set_entry(
                cache_root=tmp_cache_root,
                fingerprint=FINGERPRINT,
                probe_id="P-QD3-sec",
                probe_version="0.1.0",
                file_path="src/auth.ts",
                file_content_sha=FILE_SHA,
                signals=[qd3_signal_dict],
            )

    def test_qd3_raise_does_not_write_file(
        self, tmp_cache_root: Path, qd3_signal_dict: dict[str, Any]
    ) -> None:
        with pytest.raises(ValueError):
            set_entry(
                cache_root=tmp_cache_root,
                fingerprint=FINGERPRINT,
                probe_id="P-QD3-sec",
                probe_version="0.1.0",
                file_path="src/auth.ts",
                file_content_sha=FILE_SHA,
                signals=[qd3_signal_dict],
            )
        # KHÔNG được có file với fingerprint này + không có tmp file rác
        entries = list(tmp_cache_root.iterdir())
        assert entries == [], f"QD3 reject phải không tạo file, thấy: {entries}"

    def test_qd3_hidden_in_mixed_list_still_raises(
        self,
        tmp_cache_root: Path,
        sample_signal_dict: dict[str, Any],
        qd3_signal_dict: dict[str, Any],
    ) -> None:
        """Signal QD3 ẩn ở index > 0 vẫn phải bị reject."""
        signals = [sample_signal_dict, qd3_signal_dict]
        with pytest.raises(ValueError, match="signal\\[1\\]"):
            set_entry(
                cache_root=tmp_cache_root,
                fingerprint=FINGERPRINT,
                probe_id="P-QD1-mixed",
                probe_version="0.1.0",
                file_path="src/a.ts",
                file_content_sha=FILE_SHA,
                signals=signals,
            )

    def test_qd3_constant_is_uppercase(self) -> None:
        assert QD3_FORBIDDEN == "QD3"


# ──────────────────────────────────────────────────────────────────────
# clear_older_than
# ──────────────────────────────────────────────────────────────────────


class TestClearOlderThan:
    def _create_entry_with_cached_at(
        self, cache_root: Path, fingerprint: str, cached_at: datetime
    ) -> Path:
        payload = {
            "$schema": SCHEMA_ID,
            "fingerprint": fingerprint,
            "probe_id": "P-QD1-x",
            "probe_version": "0.1.0",
            "file_path": "src/x.ts",
            "file_content_sha": "f" * 64,
            "config_hash": "",
            "cached_at": cached_at.isoformat(),
            "ttl_expires_at": (cached_at + timedelta(days=14)).isoformat(),
            "signals_emitted": [],
            "metadata": {},
        }
        p = cache_root / f"{fingerprint}.json"
        p.write_text(json.dumps(payload), encoding="utf-8")
        return p

    def test_removes_old_keeps_new(self, tmp_cache_root: Path) -> None:
        now = datetime.now(timezone.utc)
        old = self._create_entry_with_cached_at(
            tmp_cache_root, "c" * 64, now - timedelta(days=30)
        )
        fresh = self._create_entry_with_cached_at(
            tmp_cache_root, "d" * 64, now - timedelta(days=1)
        )

        removed = clear_older_than(tmp_cache_root, older_than_days=14)

        assert removed == 1
        assert not old.exists()
        assert fresh.exists()

    def test_clear_older_than_zero_days_removes_all(self, tmp_cache_root: Path) -> None:
        now = datetime.now(timezone.utc)
        self._create_entry_with_cached_at(
            tmp_cache_root, "e" * 64, now - timedelta(hours=1)
        )
        removed = clear_older_than(tmp_cache_root, older_than_days=0)
        assert removed >= 1
