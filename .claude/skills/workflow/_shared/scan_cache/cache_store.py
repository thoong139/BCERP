#!/usr/bin/env python3
"""cache_store.py — Write/prune cache entry.

Vai trò:
    - `set_entry()` — lưu signals vào entry JSON; enforce ADR-22 rule 6 (QD3 never cached).
    - `clear_older_than()` — prune entries cũ hơn --older-than.
    - Atomic write (tmp + rename) để tránh partial state.

Registry role: NONE.

Tham chiếu:
    - ADR-19: scan cache
    - ADR-22 rule 6: QD3 never cached — enforce BOTH ở schema và runtime
    - README.md §2, §5
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

DEFAULT_TTL_DAYS: int = 14
QD3_FORBIDDEN: str = "QD3"
SCHEMA_ID: str = "cache-entry-v1"


# ──────────────────────────────────────────────────────────────────────
# Helper: atomic write
# ──────────────────────────────────────────────────────────────────────


def _atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    """Atomic write: ghi tmp file trong cùng directory rồi rename vào path.

    Cần cùng directory để rename atomic trên POSIX. Dùng os.replace để
    cross-platform (Windows cũng atomic).
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    # NamedTemporaryFile + delete=False để có thể rename sau khi close
    tmp_fd, tmp_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as fh:
            # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
            json.dump(data, fh, indent=2, ensure_ascii=False, sort_keys=True)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_name, path)
    except Exception:
        # Dọn tmp nếu chưa rename
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


# ──────────────────────────────────────────────────────────────────────
# 1. Set entry
# ──────────────────────────────────────────────────────────────────────


def set_entry(
    cache_root: Path,
    fingerprint: str,
    probe_id: str,
    probe_version: str,
    file_path: str,
    file_content_sha: str,
    signals: list[dict[str, Any]],
    metadata: dict[str, Any] | None = None,
    ttl_days: int = DEFAULT_TTL_DAYS,
    config_hash: str = "",
) -> Path:
    """Write cache entry.

    ADR-22 rule 6 (runtime guard): nếu ANY signal có dimension_id="QD3"
    → raise ValueError, KHÔNG ghi file. Schema cũng không enum QD3 → defense-in-depth.

    Args:
        cache_root: thư mục cache (sẽ tạo nếu chưa có).
        fingerprint: cache key 64 hex (xem fingerprint.py).
        probe_id: P-QDx-<slug>.
        probe_version: semver.
        file_path: relative path của file đã scan.
        file_content_sha: sha256 của file bytes tại thời điểm scan.
        signals: list Signal v2 emit bởi probe này.
        metadata: optional extras (elapsed_ms, probe_exit_code).
        ttl_days: TTL (default 14).
        config_hash: sha256 chain của config files (optional).

    Returns:
        Path tới entry file đã ghi.

    Raises:
        ValueError: nếu ADR-22 rule 6 bị vi phạm (QD3 trong signals).
    """
    # ── ADR-22 rule 6 (runtime guard) — CHẠY ĐẦU TIÊN, trước mọi I/O ──
    # Defense-in-depth: check cả `dimension_id` (canonical) lẫn `dimension_hint`
    # (legacy schema trước rename) để bắt entry cũ trên đĩa hoặc input từ
    # producer chưa migrate. Stale entry với `dimension_hint=QD3` vẫn bị reject.
    for idx, s in enumerate(signals):
        dim_value = s.get("dimension_id") or s.get("dimension_hint")
        if dim_value == QD3_FORBIDDEN:
            key_name = "dimension_id" if s.get("dimension_id") else "dimension_hint"
            raise ValueError(
                "ADR-22 rule 6: QD3 (Security) không bao giờ được cache "
                f"— signal[{idx}] có {key_name}='{QD3_FORBIDDEN}'"
            )

    now = datetime.now(timezone.utc)
    entry: dict[str, Any] = {
        "$schema": SCHEMA_ID,
        "fingerprint": fingerprint,
        "probe_id": probe_id,
        "probe_version": probe_version,
        "file_path": file_path,
        "file_content_sha": file_content_sha,
        "config_hash": config_hash,
        "cached_at": now.isoformat(),
        "ttl_expires_at": (now + timedelta(days=ttl_days)).isoformat(),
        "signals_emitted": signals,
        "metadata": metadata or {},
    }

    entry_path = cache_root / f"{fingerprint}.json"
    _atomic_write_json(entry_path, entry)
    return entry_path


# ──────────────────────────────────────────────────────────────────────
# 2. Clear (prune)
# ──────────────────────────────────────────────────────────────────────


def clear_older_than(cache_root: Path, older_than_days: int) -> int:
    """Xóa entries có cached_at < now - older_than_days.

    Args:
        cache_root: thư mục cache.
        older_than_days: số ngày, >= 0.

    Returns:
        Số entry đã xóa.
    """
    if older_than_days < 0:
        raise ValueError(
            f"clear_older_than: older_than_days phải >= 0, nhận {older_than_days}"
        )
    if not cache_root.exists():
        return 0

    cutoff = datetime.now(timezone.utc) - timedelta(days=older_than_days)
    deleted = 0
    for entry_path in cache_root.glob("*.json"):
        try:
            data = json.loads(entry_path.read_text(encoding="utf-8"))
            cached_at_raw = data.get("cached_at")
            if not cached_at_raw:
                # Entry không có cached_at → coi là corrupt, xóa
                entry_path.unlink()
                deleted += 1
                continue
            cached_at = datetime.fromisoformat(cached_at_raw)
            if cached_at < cutoff:
                entry_path.unlink()
                deleted += 1
        except (json.JSONDecodeError, OSError, ValueError):
            # Corrupt entry → xóa để tránh pollute cache
            try:
                entry_path.unlink()
                deleted += 1
            except OSError:
                pass
    return deleted


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


# ──────────────────────────────────────────────────────────────────────
# 3. Migrate legacy signals (dimension_hint → dimension_id)
# ──────────────────────────────────────────────────────────────────────


def migrate_legacy_signals(cache_root: Path) -> tuple[int, int]:
    """Migrate entries có signal[*].dimension_hint thành dimension_id.

    Walk cache_root; với mỗi entry:
        - Nếu signal có dimension_hint='QD3' → DELETE entry (ADR-22 rule 6
          forbid cache QD3 — không thể migrate, chỉ xóa).
        - Nếu signal có dimension_hint khác QD3 → rename key thành
          dimension_id, atomic rewrite.

    Args:
        cache_root: thư mục cache.

    Returns:
        (migrated_count, deleted_count) — số entry đã rewrite + số đã xóa.
    """
    if not cache_root.exists():
        return (0, 0)

    migrated = 0
    deleted = 0
    for entry_path in cache_root.glob("*.json"):
        try:
            data = json.loads(entry_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue

        sigs = data.get("signals_emitted", [])
        if not isinstance(sigs, list):
            continue

        # Check QD3 violation trước (defense-in-depth)
        if any(
            isinstance(s, dict) and s.get("dimension_hint") == QD3_FORBIDDEN
            for s in sigs
        ):
            try:
                entry_path.unlink()
                deleted += 1
            except OSError:
                pass
            continue

        # Rewrite signals: dimension_hint → dimension_id (nếu cần)
        changed = False
        for s in sigs:
            if isinstance(s, dict) and "dimension_hint" in s and "dimension_id" not in s:
                s["dimension_id"] = s.pop("dimension_hint")
                changed = True

        if changed:
            try:
                _atomic_write_json(entry_path, data)
                migrated += 1
            except OSError:
                pass

    return (migrated, deleted)


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def _cmd_set(args: argparse.Namespace) -> int:
    """cache_store.py set ..."""
    signals_data = json.loads(args.signals_file.read_text(encoding="utf-8"))
    if not isinstance(signals_data, list):
        print("[cache_store ERROR] signals-file phải là JSON array", file=sys.stderr)
        return 1

    # Tính fingerprint từ các input nếu không có sẵn
    from .fingerprint import compute_fingerprint, hash_file_content

    file_sha = hash_file_content(args.file)
    fp = compute_fingerprint(
        probe_id=args.probe_id,
        probe_version=args.probe_version,
        file_path=str(args.file),
        file_content_sha=file_sha,
    )
    try:
        entry_path = set_entry(
            cache_root=args.cache_root,
            fingerprint=fp,
            probe_id=args.probe_id,
            probe_version=args.probe_version,
            file_path=str(args.file),
            file_content_sha=file_sha,
            signals=signals_data,
        )
        print(str(entry_path))
        return 0
    except ValueError as exc:
        print(f"[cache_store REJECT] {exc}", file=sys.stderr)
        return 2


def _cmd_clear(args: argparse.Namespace) -> int:
    """cache_store.py clear --older-than=<n>d."""
    count = clear_older_than(args.cache_root, args.older_than)
    print(f"Đã xóa {count} entry", file=sys.stderr)
    return 0


def _cmd_migrate(args: argparse.Namespace) -> int:
    """cache_store.py migrate — rename legacy dimension_hint key."""
    migrated, deleted = migrate_legacy_signals(args.cache_root)
    print(
        f"Migrated {migrated} entry (dimension_hint → dimension_id), "
        f"deleted {deleted} entry vi phạm ADR-22 rule 6 (QD3)",
        file=sys.stderr,
    )
    return 0


def _parse_duration(s: str) -> int:
    """Parse '14d' → 14 (days)."""
    if s.endswith("d"):
        try:
            n = int(s[:-1])
            if n < 0:
                raise argparse.ArgumentTypeError(f"Duration phải >= 0, nhận {n}")
            return n
        except ValueError:
            raise argparse.ArgumentTypeError(f"Invalid duration: {s}") from None
    raise argparse.ArgumentTypeError(f"Expected <n>d, got {s}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Scan cache store")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_set = sub.add_parser("set", help="Store signals into cache")
    p_set.add_argument("--cache-root", required=True, type=Path)
    p_set.add_argument("--probe-id", required=True)
    p_set.add_argument("--probe-version", required=True)
    p_set.add_argument("--file", required=True, type=Path)
    p_set.add_argument("--signals-file", required=True, type=Path)
    p_set.set_defaults(func=_cmd_set)

    p_clear = sub.add_parser("clear", help="Prune old entries")
    p_clear.add_argument("--cache-root", required=True, type=Path)
    p_clear.add_argument("--older-than", required=True, type=_parse_duration)
    p_clear.set_defaults(func=_cmd_clear)

    p_migrate = sub.add_parser(
        "migrate", help="Rename legacy dimension_hint → dimension_id"
    )
    p_migrate.add_argument("--cache-root", required=True, type=Path)
    p_migrate.set_defaults(func=_cmd_migrate)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
