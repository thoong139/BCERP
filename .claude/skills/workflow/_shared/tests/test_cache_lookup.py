"""test_cache_lookup.py — Tests cho scan_cache.cache_lookup.

Phạm vi chính:
    - lookup HIT: file tồn tại, chưa expired, file_content_sha khớp.
    - lookup MISS: entry không tồn tại.
    - lookup STALE: file_content_sha đổi → xóa + trả None.
    - lookup TTL-expired: ttl_expires_at < now → xóa + trả None.
    - CacheEntry.from_json reject nếu thiếu required field.
    - is_expired với timestamp corrupt → True (safe).
    - Schema-conform: entry tạo bởi set_entry → lookup đọc thành công.
"""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import pytest

from scan_cache.cache_lookup import CacheEntry, is_expired, lookup
from scan_cache.cache_store import set_entry

FINGERPRINT = "a" * 64
FILE_SHA = "b" * 64


# ──────────────────────────────────────────────────────────────────────
# Happy path — HIT
# ──────────────────────────────────────────────────────────────────────


class TestLookupHit:
    def test_hit_returns_cache_entry(
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
        result = lookup(
            cache_root=tmp_cache_root,
            fingerprint=FINGERPRINT,
            current_file_sha=FILE_SHA,
        )
        assert result is not None
        assert isinstance(result, CacheEntry)
        assert result.fingerprint == FINGERPRINT
        assert result.file_content_sha == FILE_SHA
        assert len(result.signals_emitted) == 1


# ──────────────────────────────────────────────────────────────────────
# MISS scenarios
# ──────────────────────────────────────────────────────────────────────


class TestLookupMiss:
    def test_missing_entry_returns_none(self, tmp_cache_root: Path) -> None:
        assert lookup(tmp_cache_root, FINGERPRINT, FILE_SHA) is None

    def test_stale_content_sha_deletes_entry_and_returns_none(
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
        assert (tmp_cache_root / f"{FINGERPRINT}.json").exists()

        # File đã đổi — sha mới
        new_sha = "c" * 64
        result = lookup(tmp_cache_root, FINGERPRINT, new_sha)
        assert result is None
        # Entry cũ đã bị xóa (không pollute cache)
        assert not (tmp_cache_root / f"{FINGERPRINT}.json").exists()

    def test_expired_entry_returns_none_and_deletes(self, tmp_cache_root: Path) -> None:
        """Entry có ttl_expires_at < now → MISS + delete."""
        expired_time = datetime.now(timezone.utc) - timedelta(days=1)
        payload = {
            "$schema": "cache-entry-v1",
            "fingerprint": FINGERPRINT,
            "probe_id": "P-QD1-demo",
            "probe_version": "0.1.0",
            "file_path": "src/a.ts",
            "file_content_sha": FILE_SHA,
            "config_hash": "",
            "cached_at": (expired_time - timedelta(days=14)).isoformat(),
            "ttl_expires_at": expired_time.isoformat(),
            "signals_emitted": [],
            "metadata": {},
        }
        entry_path = tmp_cache_root / f"{FINGERPRINT}.json"
        entry_path.write_text(json.dumps(payload), encoding="utf-8")

        result = lookup(tmp_cache_root, FINGERPRINT, FILE_SHA)
        assert result is None
        assert not entry_path.exists()

    def test_corrupt_json_returns_none_and_deletes(self, tmp_cache_root: Path) -> None:
        entry_path = tmp_cache_root / f"{FINGERPRINT}.json"
        entry_path.write_text("{ not valid json", encoding="utf-8")
        assert lookup(tmp_cache_root, FINGERPRINT, FILE_SHA) is None
        assert not entry_path.exists()


# ──────────────────────────────────────────────────────────────────────
# CacheEntry.from_json validation
# ──────────────────────────────────────────────────────────────────────


class TestCacheEntryFromJson:
    def test_missing_required_field_raises(self) -> None:
        with pytest.raises(ValueError, match="thiếu required field"):
            CacheEntry.from_json({"fingerprint": "x"})

    def test_signals_emitted_not_list_raises(self) -> None:
        payload = {
            "fingerprint": "x",
            "probe_id": "P-QD1-x",
            "probe_version": "0.1",
            "file_path": "a",
            "file_content_sha": "s",
            "cached_at": "2026-01-01T00:00:00+00:00",
            "ttl_expires_at": "2026-01-15T00:00:00+00:00",
            "signals_emitted": "not-a-list",
        }
        with pytest.raises(ValueError, match="phải là list"):
            CacheEntry.from_json(payload)


# ──────────────────────────────────────────────────────────────────────
# is_expired edge cases
# ──────────────────────────────────────────────────────────────────────


class TestIsExpired:
    def _make_entry(self, ttl: str) -> CacheEntry:
        return CacheEntry(
            fingerprint="x",
            probe_id="P-QD1-x",
            probe_version="0.1.0",
            file_path="src/x.ts",
            file_content_sha="a" * 64,
            cached_at="2026-04-20T00:00:00+00:00",
            ttl_expires_at=ttl,
            signals_emitted=[],
        )

    def test_expires_in_past_returns_true(self) -> None:
        entry = self._make_entry("2020-01-01T00:00:00+00:00")
        assert is_expired(entry) is True

    def test_expires_in_future_returns_false(self) -> None:
        future = datetime.now(timezone.utc) + timedelta(days=365)
        entry = self._make_entry(future.isoformat())
        assert is_expired(entry) is False

    def test_corrupt_timestamp_returns_true(self) -> None:
        entry = self._make_entry("not-a-date")
        assert is_expired(entry) is True
