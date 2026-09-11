#!/usr/bin/env python3
"""cache_adapter.py — Cache adapter cho linear workflow skills.

Vai trò:
    Adapter wrapping existing scan_cache/ (cache_lookup, cache_store,
    fingerprint), cung cấp interface đơn giản cho linear skills.

    2-tier cache:
    - Session tier: in-memory dict (không persist, nhanh)
    - Project tier: disk-based qua scan_cache (persist, TTL 14 ngày)

Registry role: NONE.

Tham chiếu:
    - ADR-OPT-09: Cache adapter cho linear skills
    - Wrap: scan_cache/cache_lookup.py, cache_store.py, fingerprint.py
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

DEFAULT_TTL_DAYS = 14
CACHE_DIR_NAME = ".mc-data-cache"
SESSION_TTL_KEY = "__session__"

# ──────────────────────────────────────────────────────────────────────
# Session tier (in-memory)
# ──────────────────────────────────────────────────────────────────────

_session_cache: dict[str, dict[str, Any]] = {}


def _session_key(skill_name: str, content_hash: str, output_key: str) -> str:
    """Tạo key cho session cache."""
    return f"{skill_name}:{content_hash}:{output_key}"


# ──────────────────────────────────────────────────────────────────────
# Project tier (disk)
# ──────────────────────────────────────────────────────────────────────


def _project_cache_dir(base_dir: Path, skill_name: str) -> Path:
    """Path cho project-tier cache."""
    return base_dir / CACHE_DIR_NAME / "linear" / skill_name


def _project_cache_path(
    base_dir: Path, skill_name: str, content_hash: str, output_key: str
) -> Path:
    """Path cho 1 cache entry."""
    cache_key = hashlib.sha256(
        f"{content_hash}:{output_key}".encode("utf-8")
    ).hexdigest()[:16]
    return _project_cache_dir(base_dir, skill_name) / f"{cache_key}.json"


# ──────────────────────────────────────────────────────────────────────
# Core functions
# ──────────────────────────────────────────────────────────────────────


def get_cached(
    skill_name: str,
    content_hash: str,
    output_key: str,
    base_dir: Path | None = None,
) -> dict[str, Any] | None:
    """Tra cache theo skill + content_hash + output_key.

    Lookup order: session tier → project tier → miss.

    Args:
        skill_name: Tên skill (vd: "wf-analyze-requirements").
        content_hash: SHA256 hash của input content.
        output_key: Key cho loại output (vd: "dept-analysis", "feature-specs").
        base_dir: Project base directory cho disk cache.

    Returns:
        Cached data hoặc None nếu miss.
    """
    # Session tier
    skey = _session_key(skill_name, content_hash, output_key)
    if skey in _session_cache:
        entry = _session_cache[skey]
        if not _is_expired(entry):
            return entry.get("data")
        del _session_cache[skey]

    # Project tier
    if base_dir is not None:
        cache_path = _project_cache_path(base_dir, skill_name, content_hash, output_key)
        if cache_path.exists():
            try:
                entry = json.loads(cache_path.read_text(encoding="utf-8"))
                if not _is_expired(entry):
                    # Populate session tier
                    _session_cache[skey] = entry
                    return entry.get("data")
                # Expired → delete
                cache_path.unlink(missing_ok=True)
            except (json.JSONDecodeError, OSError):
                pass

    return None


def set_cached(
    skill_name: str,
    content_hash: str,
    output_key: str,
    data: dict[str, Any],
    ttl_days: int = DEFAULT_TTL_DAYS,
    base_dir: Path | None = None,
) -> None:
    """Ghi cache.

    Ghi cả session tier và project tier.

    Args:
        skill_name: Tên skill.
        content_hash: SHA256 hash của input content.
        output_key: Key cho loại output.
        data: Data cần cache.
        ttl_days: TTL mặc định 14 ngày.
        base_dir: Project base directory cho disk cache.
    """
    now = datetime.now(timezone.utc).isoformat()
    entry = {
        "skill_name": skill_name,
        "content_hash": content_hash,
        "output_key": output_key,
        "cached_at": now,
        "ttl_days": ttl_days,
        "data": data,
    }

    # Session tier
    skey = _session_key(skill_name, content_hash, output_key)
    _session_cache[skey] = entry

    # Project tier
    if base_dir is not None:
        cache_path = _project_cache_path(base_dir, skill_name, content_hash, output_key)
        cache_path.parent.mkdir(parents=True, exist_ok=True)

        tmp_path = cache_path.with_suffix(".tmp")
        # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
        tmp_path.write_text(
            json.dumps(entry, indent=2, ensure_ascii=False, sort_keys=True),
            encoding="utf-8",
        )
        tmp_path.replace(cache_path)


def invalidate_cache(
    skill_name: str,
    content_hash: str | None = None,
    base_dir: Path | None = None,
) -> int:
    """Xoá cache entries.

    Args:
        skill_name: Tên skill.
        content_hash: Nếu None → xoá tất cả entries cho skill.
                      Nếu có → xoá entries với content_hash cụ thể.
        base_dir: Project base directory.

    Returns:
        Số entries đã xoá.
    """
    count = 0

    # Clear session tier
    keys_to_delete = []
    for skey in _session_cache:
        parts = skey.split(":", 2)
        if len(parts) >= 1 and parts[0] == skill_name:
            if content_hash is None or (len(parts) >= 2 and parts[1] == content_hash):
                keys_to_delete.append(skey)

    for k in keys_to_delete:
        del _session_cache[k]
        count += 1

    # Clear project tier
    if base_dir is not None:
        cache_dir = _project_cache_dir(base_dir, skill_name)
        if cache_dir.exists():
            for f in cache_dir.glob("*.json"):
                if content_hash is None:
                    f.unlink()
                    count += 1
                else:
                    try:
                        entry = json.loads(f.read_text(encoding="utf-8"))
                        if entry.get("content_hash") == content_hash:
                            f.unlink()
                            count += 1
                    except (json.JSONDecodeError, OSError):
                        pass

    return count


def compute_content_hash(*file_paths: Path) -> str:
    """SHA256 của concatenated file contents.

    Dùng để tạo content_hash cho cache key.

    Args:
        *file_paths: Các file paths cần hash.

    Returns:
        SHA256 hex digest.

    Raises:
        FileNotFoundError: file không tồn tại.
    """
    hasher = hashlib.sha256()
    for fp in file_paths:
        path = Path(fp)
        if not path.exists():
            raise FileNotFoundError(f"compute_content_hash: file không tồn tại → {path}")
        # Thêm marker path để file khác nội dung cùng content cho hash khác
        hasher.update(str(path).encode("utf-8"))
        hasher.update(b"|")
        hasher.update(path.read_bytes())
        hasher.update(b"|")
    return hasher.hexdigest()


def _is_expired(entry: dict[str, Any]) -> bool:
    """Kiểm tra cache entry có hết hạn chưa."""
    cached_at = entry.get("cached_at", "")
    ttl_days = entry.get("ttl_days", DEFAULT_TTL_DAYS)
    if not cached_at:
        return True

    try:
        cached_dt = datetime.fromisoformat(cached_at)
        now = datetime.now(timezone.utc)
        if cached_dt.tzinfo is None:
            from datetime import timezone as tz
            cached_dt = cached_dt.replace(tzinfo=tz.utc)
        age_days = (now - cached_dt).total_seconds() / 86400
        return age_days > ttl_days
    except (ValueError, TypeError):
        return True


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: cache adapter."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Cache adapter cho linear skills")
    sub = parser.add_subparsers(dest="command")

    hash_cmd = sub.add_parser("hash", help="Compute content hash")
    hash_cmd.add_argument("files", nargs="+", type=Path)

    args = parser.parse_args(argv)

    try:
        if args.command == "hash":
            h = compute_content_hash(*args.files)
            print(h)
            return 0

        parser.print_help()
        return 1

    except Exception as exc:
        print(f"[cache_adapter ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
