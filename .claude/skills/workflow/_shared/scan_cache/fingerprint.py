#!/usr/bin/env python3
"""fingerprint.py — Compute cache key cho scan-cache.

Vai trò:
    Sha256 chaining theo spec README.md §2.
    Fingerprint = sha256(probe_id|probe_version|file_path|file_content_sha|config_hash)

Registry role: NONE.

Tham chiếu:
    - ADR-19: scan cache design
    - README.md §2 Fingerprint
    - ADR-22 rule 3: no-override defaults (áp dụng ở cache_store, không phải fingerprint)
"""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path


# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

CHUNK_SIZE: int = 64 * 1024  # 64 KiB — cân bằng memory vs overhead


# ──────────────────────────────────────────────────────────────────────
# 1. Hash file content
# ──────────────────────────────────────────────────────────────────────


def hash_file_content(file_path: Path) -> str:
    """Sha256 của toàn bộ file bytes (streaming, constant memory).

    Args:
        file_path: Path tới file cần hash. Binary-safe (dùng mode "rb").

    Returns:
        Hex digest 64 ký tự (sha256).

    Raises:
        FileNotFoundError: file không tồn tại.
        IsADirectoryError: path trỏ tới directory.
    """
    if not file_path.exists():
        raise FileNotFoundError(f"hash_file_content: file không tồn tại → {file_path}")
    if file_path.is_dir():
        raise IsADirectoryError(f"hash_file_content: path là directory → {file_path}")

    hasher = hashlib.sha256()
    with file_path.open("rb") as fh:
        while True:
            chunk = fh.read(CHUNK_SIZE)
            if not chunk:
                break
            hasher.update(chunk)
    return hasher.hexdigest()


# ──────────────────────────────────────────────────────────────────────
# 2. Hash config (optional)
# ──────────────────────────────────────────────────────────────────────


def hash_config(config_files: list[Path]) -> str:
    """Sha256 chain của các config file, sort theo path để deterministic.

    Args:
        config_files: List path config (ví dụ: .eslintrc, tsconfig.json).

    Returns:
        Hex digest; hoặc empty string nếu list rỗng.
    """
    if not config_files:
        return ""

    # Sort theo absolute path string để deterministic bất chấp thứ tự input
    sorted_paths = sorted(config_files, key=lambda p: str(p.resolve()))

    hasher = hashlib.sha256()
    for p in sorted_paths:
        # Thêm marker path để 2 file khác nhau có cùng content vẫn cho hash khác
        hasher.update(str(p).encode("utf-8"))
        hasher.update(b"|")
        hasher.update(hash_file_content(p).encode("ascii"))
        hasher.update(b"|")
    return hasher.hexdigest()


# ──────────────────────────────────────────────────────────────────────
# 3. Compute full fingerprint
# ──────────────────────────────────────────────────────────────────────


def compute_fingerprint(
    probe_id: str,
    probe_version: str,
    file_path: str,
    file_content_sha: str,
    config_hash: str = "",
) -> str:
    """Chain hash 5 thành phần theo spec.

    Format: sha256(probe_id|probe_version|file_path|file_content_sha|config_hash)

    Args:
        probe_id: P-QDx-<slug>.
        probe_version: semver (VD: "1.0.0").
        file_path: path tương đối project.
        file_content_sha: sha256 đã tính trước của file content.
        config_hash: sha256 chain các config; dùng empty string nếu không có.

    Returns:
        Hex digest 64 ký tự (sha256).

    Raises:
        ValueError: field bắt buộc rỗng.
    """
    if not probe_id:
        raise ValueError("compute_fingerprint: probe_id không được rỗng")
    if not probe_version:
        raise ValueError("compute_fingerprint: probe_version không được rỗng")
    if not file_path:
        raise ValueError("compute_fingerprint: file_path không được rỗng")
    if not file_content_sha:
        raise ValueError("compute_fingerprint: file_content_sha không được rỗng")

    message = "|".join(
        [probe_id, probe_version, file_path, file_content_sha, config_hash]
    )
    return hashlib.sha256(message.encode("utf-8")).hexdigest()


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Compute scan-cache fingerprint")
    parser.add_argument("--probe-id", required=True)
    parser.add_argument("--probe-version", required=True)
    parser.add_argument("--file", required=True, type=Path)
    parser.add_argument("--config", nargs="*", default=[], type=Path)

    args = parser.parse_args(argv)

    try:
        file_sha = hash_file_content(args.file)
        config_sha = hash_config(args.config) if args.config else ""
        fp = compute_fingerprint(
            probe_id=args.probe_id,
            probe_version=args.probe_version,
            file_path=str(args.file),
            file_content_sha=file_sha,
            config_hash=config_sha,
        )
        print(fp)
        return 0
    except (FileNotFoundError, IsADirectoryError, ValueError) as exc:
        print(f"[fingerprint ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
