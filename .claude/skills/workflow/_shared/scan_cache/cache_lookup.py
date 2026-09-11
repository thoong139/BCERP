#!/usr/bin/env python3
"""cache_lookup.py — Read cache entry + validate.

Vai trò:
    Kiểm tra cache HIT/MISS theo 3 tầng:
    1. File entry tồn tại.
    2. TTL chưa expired (cached_at + 14 ngày > now).
    3. File content hash khớp (không stale).

Registry role: NONE.

Tham chiếu:
    - ADR-19: scan cache
    - README.md §2, §5
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


REQUIRED_FIELDS: tuple[str, ...] = (
    "fingerprint",
    "probe_id",
    "probe_version",
    "file_path",
    "file_content_sha",
    "cached_at",
    "ttl_expires_at",
    "signals_emitted",
)


@dataclass
class CacheEntry:
    """Cache entry loaded từ disk."""

    fingerprint: str
    probe_id: str
    probe_version: str
    file_path: str
    file_content_sha: str
    cached_at: str
    ttl_expires_at: str
    signals_emitted: list[dict[str, Any]]
    metadata: dict[str, Any] = field(default_factory=dict)
    config_hash: str = ""

    @classmethod
    def from_json(cls, data: dict[str, Any]) -> "CacheEntry":
        """Parse từ JSON dict, validate required fields.

        Raises:
            ValueError: nếu thiếu required field hoặc sai type.
        """
        missing = [k for k in REQUIRED_FIELDS if k not in data]
        if missing:
            raise ValueError(
                f"CacheEntry.from_json: thiếu required field(s): {missing}"
            )

        signals = data["signals_emitted"]
        if not isinstance(signals, list):
            raise ValueError(
                f"CacheEntry.from_json: signals_emitted phải là list, "
                f"nhận {type(signals).__name__}"
            )

        return cls(
            fingerprint=str(data["fingerprint"]),
            probe_id=str(data["probe_id"]),
            probe_version=str(data["probe_version"]),
            file_path=str(data["file_path"]),
            file_content_sha=str(data["file_content_sha"]),
            cached_at=str(data["cached_at"]),
            ttl_expires_at=str(data["ttl_expires_at"]),
            signals_emitted=list(signals),
            metadata=dict(data.get("metadata", {})),
            config_hash=str(data.get("config_hash", "")),
        )


# ──────────────────────────────────────────────────────────────────────
# 1. Lookup
# ──────────────────────────────────────────────────────────────────────


def is_expired(entry: CacheEntry) -> bool:
    """Check ttl_expires_at < now.

    Returns:
        True nếu entry đã hết hạn.
    """
    try:
        expires = datetime.fromisoformat(entry.ttl_expires_at)
    except ValueError:
        # Timestamp corrupt → coi là expired (loại bỏ an toàn)
        return True
    now = datetime.now(timezone.utc)
    # Nếu expires không có tzinfo, gán UTC để so sánh
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    return expires < now


def lookup(
    cache_root: Path,
    fingerprint: str,
    current_file_sha: str,
) -> CacheEntry | None:
    """Check cache hit.

    Logic:
        - Nếu file entry không tồn tại → None (MISS).
        - Nếu JSON corrupt → xóa file, return None.
        - Nếu entry expired → xóa file, return None.
        - Nếu entry.file_content_sha != current_file_sha → xóa file, return None (STALE).
        - Ngược lại → return CacheEntry (HIT).

    Args:
        cache_root: thư mục cache.
        fingerprint: cache key 64 hex.
        current_file_sha: sha256 của file content HIỆN TẠI — dùng để
            detect file đã thay đổi kể từ lúc cache.

    Returns:
        CacheEntry nếu HIT, None nếu MISS (mọi lý do).
    """
    entry_path = cache_root / f"{fingerprint}.json"
    if not entry_path.exists():
        return None

    try:
        raw = entry_path.read_text(encoding="utf-8")
        data = json.loads(raw)
        entry = CacheEntry.from_json(data)
    except (json.JSONDecodeError, ValueError, OSError):
        # Corrupt entry → xóa để tránh pollute
        try:
            entry_path.unlink()
        except OSError:
            pass
        return None

    if is_expired(entry):
        try:
            entry_path.unlink()
        except OSError:
            pass
        return None

    if entry.file_content_sha != current_file_sha:
        # File đã thay đổi kể từ lúc cache → stale
        try:
            entry_path.unlink()
        except OSError:
            pass
        return None

    return entry


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Lookup scan-cache entry")
    parser.add_argument("--cache-root", required=True, type=Path)
    parser.add_argument("--fingerprint", required=True)
    parser.add_argument("--current-file-sha", required=True)

    args = parser.parse_args(argv)

    entry = lookup(args.cache_root, args.fingerprint, args.current_file_sha)
    if entry is None:
        print("MISS", file=sys.stderr)
        return 1
    print("HIT", file=sys.stderr)
    print(json.dumps(entry.__dict__, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
