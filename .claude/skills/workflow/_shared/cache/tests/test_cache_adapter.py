"""test_cache_adapter.py — Unit tests cho cache module."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from cache.cache_adapter import (
    compute_content_hash,
    get_cached,
    invalidate_cache,
    set_cached,
    _session_cache,
)


@pytest.fixture(autouse=True)
def clear_session_cache():
    """Xoá session cache trước mỗi test."""
    _session_cache.clear()
    yield
    _session_cache.clear()


class TestContentHash:
    """Test compute_content_hash."""

    def test_single_file(self, tmp_path):
        """Hash 1 file."""
        f = tmp_path / "test.json"
        f.write_text('{"key": "value"}', encoding="utf-8")
        h = compute_content_hash(f)
        assert len(h) == 64  # SHA256 hex digest

    def test_multiple_files(self, tmp_path):
        """Hash nhiều files."""
        f1 = tmp_path / "a.json"
        f2 = tmp_path / "b.json"
        f1.write_text("a", encoding="utf-8")
        f2.write_text("b", encoding="utf-8")
        h = compute_content_hash(f1, f2)
        assert len(h) == 64

    def test_same_content_different_path(self, tmp_path):
        """Cùng nội dung nhưng path khác → hash khác (path marker)."""
        f1 = tmp_path / "file1.txt"
        f2 = tmp_path / "file2.txt"
        f1.write_text("same content", encoding="utf-8")
        f2.write_text("same content", encoding="utf-8")
        assert compute_content_hash(f1) != compute_content_hash(f2)

    def test_nonexistent_file_raises(self, tmp_path):
        """File không tồn tại → FileNotFoundError."""
        with pytest.raises(FileNotFoundError):
            compute_content_hash(tmp_path / "nonexistent.txt")


class TestCacheGetSet:
    """Test get_cached / set_cached."""

    def test_session_tier_hit(self, tmp_path):
        """Set → Get hit ở session tier (không cần base_dir)."""
        set_cached("wf-test", "hash123", "output1", {"result": "data"})
        result = get_cached("wf-test", "hash123", "output1")
        assert result == {"result": "data"}

    def test_session_tier_miss(self):
        """Get chưa set → None."""
        result = get_cached("wf-test", "hash123", "output1")
        assert result is None

    def test_project_tier_hit(self, tmp_path):
        """Set với base_dir → Get từ project tier."""
        set_cached(
            "wf-test", "hash456", "output2",
            {"result": "disk"},
            base_dir=tmp_path,
        )
        # Clear session tier
        _session_cache.clear()

        # Get từ project tier
        result = get_cached("wf-test", "hash456", "output2", base_dir=tmp_path)
        assert result == {"result": "disk"}

    def test_different_key_miss(self):
        """Key khác → miss."""
        set_cached("wf-test", "hash123", "output1", {"data": 1})
        result = get_cached("wf-test", "hash123", "output2")
        assert result is None


class TestInvalidate:
    """Test invalidate_cache."""

    def test_invalidate_all_for_skill(self, tmp_path):
        """Invalidate tất cả entries cho 1 skill."""
        set_cached("wf-test", "h1", "k1", {"a": 1})
        set_cached("wf-test", "h2", "k2", {"b": 2})
        set_cached("wf-other", "h3", "k3", {"c": 3})

        count = invalidate_cache("wf-test")
        assert count == 2

        assert get_cached("wf-test", "h1", "k1") is None
        assert get_cached("wf-other", "h3", "k3") is not None

    def test_invalidate_specific_hash(self):
        """Invalidate entries với content_hash cụ thể."""
        set_cached("wf-test", "h1", "k1", {"a": 1})
        set_cached("wf-test", "h1", "k2", {"b": 2})
        set_cached("wf-test", "h2", "k3", {"c": 3})

        count = invalidate_cache("wf-test", content_hash="h1")
        assert count == 2

        assert get_cached("wf-test", "h1", "k1") is None
        assert get_cached("wf-test", "h2", "k3") is not None

    def test_invalidate_nonexistent_returns_zero(self):
        """Invalidate skill không có entries → 0."""
        count = invalidate_cache("nonexistent")
        assert count == 0
