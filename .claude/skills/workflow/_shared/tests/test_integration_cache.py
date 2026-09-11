"""test_integration_cache.py — Unit tests cho integration_cache module.

Coverage targets:
- CacheType enum
- IntegrationCache: get / set / invalidate / is_stale / clear_all
- Mtime-based invalidation
- TTL expiry logic
- Atomic write (implicit via get/set)
- Module-level functional API
"""
from __future__ import annotations

import json
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from integration_cache import (
    CacheType,
    IntegrationCache,
    _entry_key,
    _is_ttl_expired,
    _current_mtime,
    clear_all,
    get,
    invalidate,
    is_stale,
    set as cache_set,
    _default_cache,
)
import integration_cache as ic_module


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture()
def cache(tmp_path):
    """IntegrationCache instance với tmp_path làm cache_dir."""
    return IntegrationCache(cache_dir=tmp_path)


@pytest.fixture()
def source_file(tmp_path):
    """Tạo một source file mẫu."""
    f = tmp_path / "req-registry.json"
    f.write_text('{"modules": []}', encoding="utf-8")
    return f


@pytest.fixture(autouse=True)
def reset_default_cache():
    """Reset default cache singleton giữa mỗi test."""
    ic_module._default_cache = None
    yield
    ic_module._default_cache = None


# ──────────────────────────────────────────────────────────────────────
# CacheType
# ──────────────────────────────────────────────────────────────────────


class TestCacheType:
    """Kiểm tra CacheType enum."""

    def test_all_values_defined(self):
        expected = {"cross_module_deps", "api_contract", "db_schema", "biz_rule"}
        actual = {ct.value for ct in CacheType}
        assert actual == expected

    def test_str_coercion(self):
        assert str(CacheType.CROSS_MODULE_DEPS) == "CacheType.CROSS_MODULE_DEPS"
        assert CacheType.CROSS_MODULE_DEPS.value == "cross_module_deps"

    def test_is_str_subclass(self):
        assert isinstance(CacheType.DB_SCHEMA, str)


# ──────────────────────────────────────────────────────────────────────
# Helper functions
# ──────────────────────────────────────────────────────────────────────


class TestHelpers:
    """Kiểm tra _entry_key, _is_ttl_expired, _current_mtime."""

    def test_entry_key_deterministic(self):
        k1 = _entry_key("/a/b.json", "cross_module_deps")
        k2 = _entry_key("/a/b.json", "cross_module_deps")
        assert k1 == k2

    def test_entry_key_different_type(self):
        k1 = _entry_key("/a/b.json", "cross_module_deps")
        k2 = _entry_key("/a/b.json", "api_contract")
        assert k1 != k2

    def test_entry_key_different_path(self):
        k1 = _entry_key("/a/b.json", "db_schema")
        k2 = _entry_key("/a/c.json", "db_schema")
        assert k1 != k2

    def test_ttl_not_expired(self):
        cached_at = datetime.now(timezone.utc).isoformat()
        assert not _is_ttl_expired(cached_at, ttl_hours=24)

    def test_ttl_expired(self):
        old = (datetime.now(timezone.utc) - timedelta(hours=25)).isoformat()
        assert _is_ttl_expired(old, ttl_hours=24)

    def test_ttl_empty_string_is_expired(self):
        assert _is_ttl_expired("", ttl_hours=24)

    def test_ttl_invalid_string_is_expired(self):
        assert _is_ttl_expired("not-a-date", ttl_hours=24)

    def test_current_mtime_existing_file(self, tmp_path):
        f = tmp_path / "test.json"
        f.write_text("{}", encoding="utf-8")
        mtime = _current_mtime(str(f))
        assert isinstance(mtime, float)
        assert mtime > 0

    def test_current_mtime_nonexistent(self):
        mtime = _current_mtime("/nonexistent/path/file.json")
        assert mtime is None


# ──────────────────────────────────────────────────────────────────────
# IntegrationCache — get / set
# ──────────────────────────────────────────────────────────────────────


class TestGetSet:
    """Kiểm tra get + set cơ bản."""

    def test_miss_returns_none(self, cache, source_file):
        result = cache.get(str(source_file), CacheType.CROSS_MODULE_DEPS)
        assert result is None

    def test_set_then_get_hit(self, cache, source_file):
        data = {"modules": ["MOD-CRM", "MOD-QUO"]}
        cache.set(str(source_file), CacheType.CROSS_MODULE_DEPS, data)
        result = cache.get(str(source_file), CacheType.CROSS_MODULE_DEPS)
        assert result == data

    def test_different_cache_types_independent(self, cache, source_file):
        cache.set(str(source_file), CacheType.CROSS_MODULE_DEPS, {"a": 1})
        cache.set(str(source_file), CacheType.DB_SCHEMA, {"b": 2})

        assert cache.get(str(source_file), CacheType.CROSS_MODULE_DEPS) == {"a": 1}
        assert cache.get(str(source_file), CacheType.DB_SCHEMA) == {"b": 2}

    def test_cache_type_string_works(self, cache, source_file):
        cache.set(str(source_file), "biz_rule", {"rule": "x"})
        result = cache.get(str(source_file), "biz_rule")
        assert result == {"rule": "x"}

    def test_set_creates_cache_file(self, cache, tmp_path, source_file):
        cache.set(str(source_file), CacheType.API_CONTRACT, {"spec": "v2"})
        cache_root = tmp_path / "integration"
        files = list(cache_root.glob("*.json"))
        assert len(files) == 1

    def test_set_stores_source_mtime(self, cache, source_file):
        cache.set(str(source_file), CacheType.DB_SCHEMA, {})
        entry_path = cache._entry_path(str(source_file), CacheType.DB_SCHEMA)
        entry = json.loads(entry_path.read_text(encoding="utf-8"))
        assert entry["source_mtime"] is not None
        assert isinstance(entry["source_mtime"], float)

    def test_set_nonexistent_source_has_none_mtime(self, cache):
        cache.set("/nonexistent.json", CacheType.BIZ_RULE, {"r": 1})
        entry_path = cache._entry_path("/nonexistent.json", CacheType.BIZ_RULE)
        entry = json.loads(entry_path.read_text(encoding="utf-8"))
        assert entry["source_mtime"] is None

    def test_set_respects_custom_ttl(self, cache, source_file):
        cache.set(str(source_file), CacheType.API_CONTRACT, {}, ttl_hours=1)
        entry_path = cache._entry_path(str(source_file), CacheType.API_CONTRACT)
        entry = json.loads(entry_path.read_text(encoding="utf-8"))
        assert entry["ttl_hours"] == 1

    def test_overwrite_existing_entry(self, cache, source_file):
        cache.set(str(source_file), CacheType.CROSS_MODULE_DEPS, {"v": 1})
        cache.set(str(source_file), CacheType.CROSS_MODULE_DEPS, {"v": 2})
        result = cache.get(str(source_file), CacheType.CROSS_MODULE_DEPS)
        assert result == {"v": 2}

    def test_corrupt_cache_file_returns_none(self, cache, source_file, tmp_path):
        # Ghi cache entry rồi corrupt file
        cache.set(str(source_file), CacheType.DB_SCHEMA, {"x": 1})
        entry_path = cache._entry_path(str(source_file), CacheType.DB_SCHEMA)
        entry_path.write_text("NOT JSON", encoding="utf-8")
        result = cache.get(str(source_file), CacheType.DB_SCHEMA)
        assert result is None


# ──────────────────────────────────────────────────────────────────────
# IntegrationCache — invalidate
# ──────────────────────────────────────────────────────────────────────


class TestInvalidate:
    """Kiểm tra invalidate."""

    def test_invalidate_specific_type(self, cache, source_file):
        cache.set(str(source_file), CacheType.CROSS_MODULE_DEPS, {"a": 1})
        cache.set(str(source_file), CacheType.API_CONTRACT, {"b": 2})

        count = cache.invalidate(str(source_file), CacheType.CROSS_MODULE_DEPS)
        assert count == 1
        assert cache.get(str(source_file), CacheType.CROSS_MODULE_DEPS) is None
        assert cache.get(str(source_file), CacheType.API_CONTRACT) == {"b": 2}

    def test_invalidate_all_types_for_source(self, cache, source_file):
        cache.set(str(source_file), CacheType.CROSS_MODULE_DEPS, {"a": 1})
        cache.set(str(source_file), CacheType.DB_SCHEMA, {"b": 2})
        cache.set(str(source_file), CacheType.BIZ_RULE, {"c": 3})

        count = cache.invalidate(str(source_file))
        assert count == 3
        assert cache.get(str(source_file), CacheType.CROSS_MODULE_DEPS) is None

    def test_invalidate_nonexistent_returns_zero(self, cache):
        count = cache.invalidate("/nonexistent.json")
        assert count == 0

    def test_invalidate_specific_type_nonexistent_returns_zero(self, cache, source_file):
        count = cache.invalidate(str(source_file), CacheType.API_CONTRACT)
        assert count == 0

    def test_invalidate_only_affects_target_source(self, cache, tmp_path):
        f1 = tmp_path / "file1.json"
        f2 = tmp_path / "file2.json"
        f1.write_text("{}", encoding="utf-8")
        f2.write_text("{}", encoding="utf-8")

        cache.set(str(f1), CacheType.CROSS_MODULE_DEPS, {"f1": 1})
        cache.set(str(f2), CacheType.CROSS_MODULE_DEPS, {"f2": 2})

        cache.invalidate(str(f1))
        assert cache.get(str(f1), CacheType.CROSS_MODULE_DEPS) is None
        assert cache.get(str(f2), CacheType.CROSS_MODULE_DEPS) == {"f2": 2}


# ──────────────────────────────────────────────────────────────────────
# IntegrationCache — is_stale
# ──────────────────────────────────────────────────────────────────────


class TestIsStale:
    """Kiểm tra is_stale."""

    def test_miss_is_stale(self, cache, source_file):
        assert cache.is_stale(str(source_file), CacheType.CROSS_MODULE_DEPS) is True

    def test_fresh_entry_not_stale(self, cache, source_file):
        cache.set(str(source_file), CacheType.CROSS_MODULE_DEPS, {})
        assert cache.is_stale(str(source_file), CacheType.CROSS_MODULE_DEPS) is False

    def test_expired_ttl_is_stale(self, cache, source_file, tmp_path):
        cache.set(str(source_file), CacheType.DB_SCHEMA, {})
        # Patch cached_at sang 25h trước
        entry_path = cache._entry_path(str(source_file), CacheType.DB_SCHEMA)
        entry = json.loads(entry_path.read_text(encoding="utf-8"))
        old_time = (datetime.now(timezone.utc) - timedelta(hours=25)).isoformat()
        entry["cached_at"] = old_time
        entry_path.write_text(json.dumps(entry), encoding="utf-8")

        assert cache.is_stale(str(source_file), CacheType.DB_SCHEMA) is True

    def test_mtime_change_makes_stale(self, cache, source_file):
        cache.set(str(source_file), CacheType.CROSS_MODULE_DEPS, {})
        assert not cache.is_stale(str(source_file), CacheType.CROSS_MODULE_DEPS)

        # Chờ 1 tick rồi modify file
        time.sleep(0.05)
        source_file.write_text('{"modules": ["NEW"]}', encoding="utf-8")

        assert cache.is_stale(str(source_file), CacheType.CROSS_MODULE_DEPS) is True

    def test_corrupt_entry_is_stale(self, cache, source_file):
        cache.set(str(source_file), CacheType.BIZ_RULE, {})
        entry_path = cache._entry_path(str(source_file), CacheType.BIZ_RULE)
        entry_path.write_text("BROKEN", encoding="utf-8")
        assert cache.is_stale(str(source_file), CacheType.BIZ_RULE) is True


# ──────────────────────────────────────────────────────────────────────
# IntegrationCache — clear_all
# ──────────────────────────────────────────────────────────────────────


class TestClearAll:
    """Kiểm tra clear_all."""

    def test_clear_all_empty_returns_zero(self, cache):
        assert cache.clear_all() == 0

    def test_clear_all_removes_all_entries(self, cache, tmp_path):
        f1 = tmp_path / "f1.json"
        f2 = tmp_path / "f2.json"
        f1.write_text("{}", encoding="utf-8")
        f2.write_text("{}", encoding="utf-8")

        cache.set(str(f1), CacheType.CROSS_MODULE_DEPS, {"a": 1})
        cache.set(str(f2), CacheType.API_CONTRACT, {"b": 2})
        cache.set(str(f1), CacheType.DB_SCHEMA, {"c": 3})

        count = cache.clear_all()
        assert count == 3
        assert cache.get(str(f1), CacheType.CROSS_MODULE_DEPS) is None
        assert cache.get(str(f2), CacheType.API_CONTRACT) is None

    def test_clear_all_root_not_exists(self, tmp_path):
        cache2 = IntegrationCache(cache_dir=tmp_path / "nonexistent")
        assert cache2.clear_all() == 0


# ──────────────────────────────────────────────────────────────────────
# Mtime edge cases
# ──────────────────────────────────────────────────────────────────────


class TestMtimeEdgeCases:
    """Kiểm tra edge cases của mtime logic."""

    def test_both_mtimes_none_not_stale(self, cache):
        # Source không tồn tại khi cache + vẫn không tồn tại khi check
        cache.set("/nonexistent.json", CacheType.BIZ_RULE, {"x": 1})
        # Vì cả stored_mtime lẫn current_mtime đều None → không stale
        assert cache.is_stale("/nonexistent.json", CacheType.BIZ_RULE) is False

    def test_source_deleted_after_cache_is_stale(self, cache, tmp_path):
        f = tmp_path / "temp.json"
        f.write_text("{}", encoding="utf-8")
        cache.set(str(f), CacheType.DB_SCHEMA, {})

        f.unlink()
        assert cache.is_stale(str(f), CacheType.DB_SCHEMA) is True

    def test_get_stale_entry_removes_file(self, cache, source_file, tmp_path):
        cache.set(str(source_file), CacheType.API_CONTRACT, {})
        entry_path = cache._entry_path(str(source_file), CacheType.API_CONTRACT)
        # Patch TTL expired
        entry = json.loads(entry_path.read_text(encoding="utf-8"))
        entry["cached_at"] = (datetime.now(timezone.utc) - timedelta(hours=25)).isoformat()
        entry_path.write_text(json.dumps(entry), encoding="utf-8")

        result = cache.get(str(source_file), CacheType.API_CONTRACT)
        assert result is None
        assert not entry_path.exists()


# ──────────────────────────────────────────────────────────────────────
# Functional API
# ──────────────────────────────────────────────────────────────────────


class TestFunctionalAPI:
    """Kiểm tra module-level functional API."""

    def test_set_and_get_functional(self, tmp_path, source_file):
        cache_set(
            str(source_file),
            CacheType.CROSS_MODULE_DEPS,
            {"deps": ["MOD-CRM"]},
            cache_dir=tmp_path,
        )
        result = get(str(source_file), CacheType.CROSS_MODULE_DEPS, cache_dir=tmp_path)
        assert result == {"deps": ["MOD-CRM"]}

    def test_is_stale_functional(self, tmp_path, source_file):
        assert is_stale(str(source_file), CacheType.DB_SCHEMA, cache_dir=tmp_path)
        cache_set(str(source_file), CacheType.DB_SCHEMA, {}, cache_dir=tmp_path)
        assert not is_stale(str(source_file), CacheType.DB_SCHEMA, cache_dir=tmp_path)

    def test_invalidate_functional(self, tmp_path, source_file):
        cache_set(str(source_file), CacheType.BIZ_RULE, {"x": 1}, cache_dir=tmp_path)
        count = invalidate(str(source_file), CacheType.BIZ_RULE, cache_dir=tmp_path)
        assert count == 1
        assert get(str(source_file), CacheType.BIZ_RULE, cache_dir=tmp_path) is None

    def test_clear_all_functional(self, tmp_path, source_file):
        cache_set(str(source_file), CacheType.API_CONTRACT, {}, cache_dir=tmp_path)
        count = clear_all(cache_dir=tmp_path)
        assert count == 1

    def test_default_instance_reused(self, tmp_path, source_file):
        cache_set(str(source_file), CacheType.CROSS_MODULE_DEPS, {"a": 1}, cache_dir=tmp_path)
        result = get(str(source_file), CacheType.CROSS_MODULE_DEPS, cache_dir=tmp_path)
        assert result == {"a": 1}
        # Default instance dùng lại vì cache_dir giống nhau
        assert ic_module._default_cache is not None
