"""test_fingerprint.py — Tests cho scan_cache.fingerprint.

Phạm vi:
    - hash_file_content: happy-path, edge (empty file), error (missing).
    - hash_config: deterministic ordering, empty list.
    - compute_fingerprint: happy-path, determinism, error (empty field).

Coverage mục tiêu: ≥80% cho fingerprint.py.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

import pytest

from scan_cache.fingerprint import (
    CHUNK_SIZE,
    compute_fingerprint,
    hash_config,
    hash_file_content,
)


# ──────────────────────────────────────────────────────────────────────
# hash_file_content
# ──────────────────────────────────────────────────────────────────────


class TestHashFileContent:
    def test_happy_path_returns_64_hex(self, tmp_path: Path) -> None:
        f = tmp_path / "sample.txt"
        payload = "Nội dung mẫu tiếng Việt".encode("utf-8")
        f.write_bytes(payload)
        digest = hash_file_content(f)
        assert len(digest) == 64
        assert all(c in "0123456789abcdef" for c in digest)
        # Verify matches stdlib computation
        expected = hashlib.sha256(payload).hexdigest()
        assert digest == expected

    def test_empty_file_returns_sha256_of_empty(self, tmp_path: Path) -> None:
        f = tmp_path / "empty.bin"
        f.write_bytes(b"")
        assert hash_file_content(f) == hashlib.sha256(b"").hexdigest()

    def test_large_file_uses_streaming(self, tmp_path: Path) -> None:
        """File > CHUNK_SIZE vẫn hash đúng (streaming OK)."""
        f = tmp_path / "large.bin"
        payload = b"A" * (CHUNK_SIZE * 3 + 17)
        f.write_bytes(payload)
        assert hash_file_content(f) == hashlib.sha256(payload).hexdigest()

    def test_missing_file_raises(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError):
            hash_file_content(tmp_path / "nope.txt")

    def test_directory_raises(self, tmp_path: Path) -> None:
        with pytest.raises(IsADirectoryError):
            hash_file_content(tmp_path)


# ──────────────────────────────────────────────────────────────────────
# hash_config
# ──────────────────────────────────────────────────────────────────────


class TestHashConfig:
    def test_empty_list_returns_empty_string(self) -> None:
        assert hash_config([]) == ""

    def test_order_independent(self, tmp_path: Path) -> None:
        a = tmp_path / "a.cfg"
        b = tmp_path / "b.cfg"
        a.write_text("alpha")
        b.write_text("beta")
        h_ab = hash_config([a, b])
        h_ba = hash_config([b, a])
        assert h_ab == h_ba
        assert len(h_ab) == 64

    def test_path_marker_differentiates(self, tmp_path: Path) -> None:
        """File khác path nhưng cùng nội dung phải cho hash khác (path làm marker)."""
        a = tmp_path / "a.cfg"
        b = tmp_path / "b.cfg"
        a.write_text("same-content")
        b.write_text("same-content")
        assert hash_config([a]) != hash_config([b])


# ──────────────────────────────────────────────────────────────────────
# compute_fingerprint
# ──────────────────────────────────────────────────────────────────────


class TestComputeFingerprint:
    def test_happy_path_64_hex(self) -> None:
        fp = compute_fingerprint(
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path="src/a.ts",
            file_content_sha="a" * 64,
        )
        assert len(fp) == 64
        assert all(c in "0123456789abcdef" for c in fp)

    def test_deterministic_same_inputs_same_output(self) -> None:
        args = dict(
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path="src/a.ts",
            file_content_sha="b" * 64,
        )
        assert compute_fingerprint(**args) == compute_fingerprint(**args)

    def test_config_hash_changes_fingerprint(self) -> None:
        base = dict(
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path="src/a.ts",
            file_content_sha="c" * 64,
        )
        fp_no_cfg = compute_fingerprint(**base, config_hash="")
        fp_cfg = compute_fingerprint(**base, config_hash="d" * 64)
        assert fp_no_cfg != fp_cfg

    @pytest.mark.parametrize(
        "field,value",
        [
            ("probe_id", ""),
            ("probe_version", ""),
            ("file_path", ""),
            ("file_content_sha", ""),
        ],
    )
    def test_empty_required_field_raises(self, field: str, value: str) -> None:
        kwargs = dict(
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path="src/a.ts",
            file_content_sha="e" * 64,
        )
        kwargs[field] = value
        with pytest.raises(ValueError, match=field):
            compute_fingerprint(**kwargs)
