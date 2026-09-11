#!/usr/bin/env python3
"""integration_cache.py — TTL 24h mtime-aware cache cho cross-module integration data.

Vai trò:
    Cache các parsed artifacts tốn computation trong cross-module probes:
    - cross_module_dependencies (parsed từ req-registry.json)
    - API contract diffs (so sánh OpenAPI specs giữa 2 modules)
    - DB schema snapshots (parsed từ migration files)
    - BIZ-RULE annotations (extracted từ phase2 feature docs)

    Invalidation logic:
    1. TTL expired (default 24h) — vô điều kiện
    2. Source file mtime thay đổi — ngay lập tức, ưu tiên hơn TTL

    Disk layout:
    <cache_dir>/integration/<sha256(source_path:cache_type)>.json

    Registry role: NONE (chỉ là runtime cache, không ghi registry).

Tham chiếu:
    - W5.3 wf-fix-bugs v9 — Cross-module dep resolver cache
    - ADR-OPT-09: Cache adapter cho linear skills (tương tự pattern)
"""
from __future__ import annotations

import hashlib
import json
import os
import tempfile
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

DEFAULT_TTL_HOURS: int = 24
CACHE_SUBDIR: str = "integration"
SCHEMA_ID: str = "integration-cache-v1"


# ──────────────────────────────────────────────────────────────────────
# Cache types
# ──────────────────────────────────────────────────────────────────────


class CacheType(str, Enum):
    """Loại dữ liệu được cache."""
    CROSS_MODULE_DEPS = "cross_module_deps"
    API_CONTRACT = "api_contract"
    DB_SCHEMA = "db_schema"
    BIZ_RULE = "biz_rule"


# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────


def _entry_key(source_path: str, cache_type: str) -> str:
    """SHA256 của source_path:cache_type — làm tên file cache entry."""
    raw = f"{source_path}:{cache_type}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _atomic_write(path: Path, data: dict[str, Any]) -> None:
    """Atomic write: ghi tmp trong cùng dir rồi os.replace."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
            json.dump(data, fh, indent=2, ensure_ascii=False, sort_keys=True)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_name, path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def _current_mtime(source_path: str) -> float | None:
    """Trả về os.path.getmtime của file, hoặc None nếu không tồn tại."""
    try:
        return os.path.getmtime(source_path)
    except OSError:
        return None


def _is_ttl_expired(cached_at: str, ttl_hours: int) -> bool:
    """Kiểm tra entry có hết hạn TTL chưa."""
    if not cached_at:
        return True
    try:
        dt = datetime.fromisoformat(cached_at)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        age_sec = (datetime.now(timezone.utc) - dt).total_seconds()
        return age_sec > (ttl_hours * 3600)
    except (ValueError, TypeError):
        return True


# ──────────────────────────────────────────────────────────────────────
# IntegrationCache
# ──────────────────────────────────────────────────────────────────────


class IntegrationCache:
    """TTL + mtime-aware disk cache cho integration artifacts.

    Sử dụng:
        cache = IntegrationCache(cache_dir=Path(".mc-data-cache"))
        data = cache.get("/path/to/req-registry.json", CacheType.CROSS_MODULE_DEPS)
        if data is None:
            data = expensive_parse(...)
            cache.set("/path/to/req-registry.json", CacheType.CROSS_MODULE_DEPS, data)
    """

    def __init__(
        self,
        cache_dir: Path | str,
        ttl_hours: int = DEFAULT_TTL_HOURS,
    ) -> None:
        """
        Args:
            cache_dir: Base cache directory (sẽ tạo <cache_dir>/integration/).
            ttl_hours: TTL mặc định cho mỗi entry (default 24h).
        """
        self._root = Path(cache_dir) / CACHE_SUBDIR
        self._ttl_hours = ttl_hours

    # ── Public API ─────────────────────────────────────────────────────

    def get(self, source_path: str, cache_type: str) -> Any | None:
        """Tra cache cho (source_path, cache_type).

        Trả về data nếu hit + còn valid, None nếu miss/stale.

        Args:
            source_path: Đường dẫn tuyệt đối tới file nguồn.
            cache_type: Loại cache (CacheType enum hoặc string).

        Returns:
            Cached data hoặc None.
        """
        entry_path = self._entry_path(source_path, str(cache_type))
        if not entry_path.exists():
            return None

        try:
            entry = json.loads(entry_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return None

        if self._is_entry_stale(entry, source_path):
            entry_path.unlink(missing_ok=True)
            return None

        return entry.get("data")

    def set(
        self,
        source_path: str,
        cache_type: str,
        data: Any,
        ttl_hours: int | None = None,
    ) -> None:
        """Ghi cache entry.

        Args:
            source_path: Đường dẫn tuyệt đối tới file nguồn.
            cache_type: Loại cache (CacheType enum hoặc string).
            data: Data cần cache (phải JSON-serializable).
            ttl_hours: Override TTL cho entry này. None = dùng instance default.
        """
        effective_ttl = ttl_hours if ttl_hours is not None else self._ttl_hours
        source_mtime = _current_mtime(source_path)

        entry: dict[str, Any] = {
            "$schema": SCHEMA_ID,
            "source_path": source_path,
            "cache_type": str(cache_type),
            "cached_at": datetime.now(timezone.utc).isoformat(),
            "ttl_hours": effective_ttl,
            "source_mtime": source_mtime,
            "data": data,
        }

        entry_path = self._entry_path(source_path, str(cache_type))
        _atomic_write(entry_path, entry)

    def invalidate(self, source_path: str, cache_type: str | None = None) -> int:
        """Xoá cache entry/entries cho source_path.

        Args:
            source_path: Đường dẫn tới file nguồn.
            cache_type: Nếu None → xoá tất cả cache types cho source_path.
                        Nếu có → chỉ xoá entry cho (source_path, cache_type).

        Returns:
            Số entry đã xoá.
        """
        if cache_type is not None:
            entry_path = self._entry_path(source_path, str(cache_type))
            if entry_path.exists():
                entry_path.unlink()
                return 1
            return 0

        # Xoá tất cả entries cho source_path
        count = 0
        if not self._root.exists():
            return 0
        for entry_path in self._root.glob("*.json"):
            try:
                entry = json.loads(entry_path.read_text(encoding="utf-8"))
                if entry.get("source_path") == source_path:
                    entry_path.unlink()
                    count += 1
            except (json.JSONDecodeError, OSError):
                pass
        return count

    def is_stale(self, source_path: str, cache_type: str) -> bool:
        """Kiểm tra cache entry có stale không (miss cũng là stale).

        Args:
            source_path: Đường dẫn tới file nguồn.
            cache_type: Loại cache.

        Returns:
            True nếu stale/miss, False nếu còn valid.
        """
        entry_path = self._entry_path(source_path, str(cache_type))
        if not entry_path.exists():
            return True

        try:
            entry = json.loads(entry_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return True

        return self._is_entry_stale(entry, source_path)

    def clear_all(self) -> int:
        """Xoá toàn bộ integration cache entries.

        Returns:
            Số entry đã xoá.
        """
        if not self._root.exists():
            return 0
        count = 0
        for entry_path in self._root.glob("*.json"):
            try:
                entry_path.unlink()
                count += 1
            except OSError:
                pass
        return count

    # ── Internals ──────────────────────────────────────────────────────

    def _entry_path(self, source_path: str, cache_type: str) -> Path:
        """Path cho 1 cache entry."""
        key = _entry_key(source_path, cache_type)
        return self._root / f"{key}.json"

    def _is_entry_stale(self, entry: dict[str, Any], source_path: str) -> bool:
        """Kiểm tra entry có stale không.

        Stale nếu:
        1. TTL expired, HOẶC
        2. source file mtime thay đổi so với lúc cache, HOẶC
        3. source file không còn tồn tại (mtime=None hiện tại nhưng entry có mtime)
        """
        # TTL check
        if _is_ttl_expired(entry.get("cached_at", ""), entry.get("ttl_hours", self._ttl_hours)):
            return True

        # Mtime check — ưu tiên hơn TTL
        stored_mtime = entry.get("source_mtime")
        current_mtime = _current_mtime(source_path)

        if stored_mtime is None and current_mtime is None:
            # Cả hai không có mtime (file không tồn tại khi cache, vẫn không tồn tại)
            return False
        if stored_mtime is None or current_mtime is None:
            # Một bên có mtime, một bên không → stale
            return True
        # So sánh với tolerance nhỏ để tránh floating point noise
        return abs(stored_mtime - current_mtime) > 0.001


# ──────────────────────────────────────────────────────────────────────
# Module-level default instance + functional API
# ──────────────────────────────────────────────────────────────────────

_default_cache: IntegrationCache | None = None


def _get_default(cache_dir: Path | str | None = None) -> IntegrationCache:
    """Trả về default cache instance.

    Tạo mới nếu chưa có hoặc cache_dir khác. Default cache_dir:
    `.mc-data-cache` trong current working directory.
    """
    global _default_cache
    if cache_dir is None:
        cache_dir = Path.cwd() / ".mc-data-cache"
    target_root = Path(cache_dir) / CACHE_SUBDIR
    if _default_cache is None or _default_cache._root != target_root:
        _default_cache = IntegrationCache(cache_dir=Path(cache_dir))
    return _default_cache


def get(
    source_path: str,
    cache_type: str,
    cache_dir: Path | str | None = None,
) -> Any | None:
    """Functional API — get từ default cache instance."""
    return _get_default(cache_dir).get(source_path, cache_type)


def set(
    source_path: str,
    cache_type: str,
    data: Any,
    ttl_hours: int | None = None,
    cache_dir: Path | str | None = None,
) -> None:
    """Functional API — set vào default cache instance."""
    _get_default(cache_dir).set(source_path, cache_type, data, ttl_hours=ttl_hours)


def invalidate(
    source_path: str,
    cache_type: str | None = None,
    cache_dir: Path | str | None = None,
) -> int:
    """Functional API — invalidate từ default cache instance."""
    return _get_default(cache_dir).invalidate(source_path, cache_type)


def is_stale(
    source_path: str,
    cache_type: str,
    cache_dir: Path | str | None = None,
) -> bool:
    """Functional API — is_stale từ default cache instance."""
    return _get_default(cache_dir).is_stale(source_path, cache_type)


def clear_all(cache_dir: Path | str | None = None) -> int:
    """Functional API — clear_all từ default cache instance."""
    return _get_default(cache_dir).clear_all()
