"""Tests for scan_cache.py — Phase E Tasks E.5 / E.6 / E.7.

Coverage:
- Fingerprint determinism + sensitivity (file change, config change, probe
  version bump).
- 2-tier lookup (session → project promote).
- Privacy guard: secret/pii blocked, key pattern scan blocked.
- Invalidation: manual, pattern, TTL expire, probe version bump.
- `--no-cache` mode.
- Factory helper.
"""

from __future__ import annotations

import json
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import scan_cache as sc  # noqa: E402


# ─── Fingerprint ─────────────────────────────────────────────


class TestFingerprint:
    def test_deterministic(self, tmp_path):
        f = tmp_path / "a.ts"
        f.write_text("content", encoding="utf-8")
        fp1 = sc.compute_fingerprint(
            probe_id="L3.inventory",
            probe_version="1.0",
            depth="standard",
            config={"batch_size": 100},
            input_files=[str(f)],
        )
        fp2 = sc.compute_fingerprint(
            probe_id="L3.inventory",
            probe_version="1.0",
            depth="standard",
            config={"batch_size": 100},
            input_files=[str(f)],
        )
        assert fp1 == fp2
        assert fp1.startswith("sha256:")

    def test_file_change_invalidates(self, tmp_path):
        f = tmp_path / "a.ts"
        f.write_text("content-a", encoding="utf-8")
        fp1 = sc.compute_fingerprint(
            probe_id="p", probe_version="1",
            depth="standard", config={}, input_files=[str(f)],
        )
        f.write_text("content-b", encoding="utf-8")
        fp2 = sc.compute_fingerprint(
            probe_id="p", probe_version="1",
            depth="standard", config={}, input_files=[str(f)],
        )
        assert fp1 != fp2

    def test_config_change_invalidates(self, tmp_path):
        f = tmp_path / "a.ts"
        f.write_text("x", encoding="utf-8")
        fp1 = sc.compute_fingerprint(
            probe_id="p", probe_version="1",
            depth="standard",
            config={"batch_size": 100},
            input_files=[str(f)],
        )
        fp2 = sc.compute_fingerprint(
            probe_id="p", probe_version="1",
            depth="standard",
            config={"batch_size": 200},
            input_files=[str(f)],
        )
        assert fp1 != fp2

    def test_probe_version_bump_invalidates(self, tmp_path):
        f = tmp_path / "a.ts"
        f.write_text("x", encoding="utf-8")
        fp1 = sc.compute_fingerprint(
            probe_id="p", probe_version="1.0",
            depth="standard", config={}, input_files=[str(f)],
        )
        fp2 = sc.compute_fingerprint(
            probe_id="p", probe_version="2.0",
            depth="standard", config={}, input_files=[str(f)],
        )
        assert fp1 != fp2

    def test_depth_change_invalidates(self, tmp_path):
        f = tmp_path / "a.ts"
        f.write_text("x", encoding="utf-8")
        fp1 = sc.compute_fingerprint(
            probe_id="p", probe_version="1",
            depth="standard", config={}, input_files=[str(f)],
        )
        fp2 = sc.compute_fingerprint(
            probe_id="p", probe_version="1",
            depth="deep", config={}, input_files=[str(f)],
        )
        assert fp1 != fp2

    def test_dep_closure_change_invalidates(self, tmp_path):
        a = tmp_path / "a.ts"
        b = tmp_path / "b.ts"
        a.write_text("main", encoding="utf-8")
        b.write_text("dep1", encoding="utf-8")
        fp1 = sc.compute_fingerprint(
            probe_id="p", probe_version="1", depth="standard",
            config={}, input_files=[str(a)],
            dep_closure_files=[str(b)],
        )
        b.write_text("dep2", encoding="utf-8")
        fp2 = sc.compute_fingerprint(
            probe_id="p", probe_version="1", depth="standard",
            config={}, input_files=[str(a)],
            dep_closure_files=[str(b)],
        )
        assert fp1 != fp2

    def test_missing_file_contributes_stable_marker(self, tmp_path):
        nonexistent = tmp_path / "ghost.ts"
        fp1 = sc.compute_fingerprint(
            probe_id="p", probe_version="1", depth="standard",
            config={}, input_files=[str(nonexistent)],
        )
        # File appears later → fingerprint should differ.
        nonexistent.write_text("x", encoding="utf-8")
        fp2 = sc.compute_fingerprint(
            probe_id="p", probe_version="1", depth="standard",
            config={}, input_files=[str(nonexistent)],
        )
        assert fp1 != fp2


# ─── Privacy Guard ───────────────────────────────────────────


class TestPrivacyGuard:
    def test_secret_scope_not_cacheable(self):
        assert sc.is_cacheable("secret") is False
        assert sc.is_cacheable("SECRET") is False
        assert sc.is_cacheable("pii") is False

    def test_internal_scope_cacheable(self):
        assert sc.is_cacheable("internal") is True
        assert sc.is_cacheable(None) is True
        assert sc.is_cacheable("") is True

    def test_output_with_password_key_blocked(self):
        assert sc.is_cacheable(
            "internal", {"user": "a", "password": "p"}
        ) is False

    def test_output_with_api_key_blocked(self):
        assert sc.is_cacheable(
            "internal", {"config": {"api_key": "abc"}}
        ) is False
        assert sc.is_cacheable(
            "internal", {"config": {"apiKey": "abc"}}
        ) is False

    def test_output_with_token_blocked(self):
        assert sc.is_cacheable(
            "internal", {"auth": {"token": "t"}}
        ) is False

    def test_output_with_private_key_blocked(self):
        assert sc.is_cacheable(
            "internal", {"ssh": {"private_key": "k"}}
        ) is False

    def test_clean_output_cacheable(self):
        assert sc.is_cacheable(
            "internal",
            {"items": [{"name": "x"}], "count": 1},
        ) is True


# ─── CacheBackend ────────────────────────────────────────────


class TestCacheBackend:
    def test_set_get_roundtrip(self, tmp_path):
        backend = sc.CacheBackend(tmp_path / "cache")
        backend.set(
            "sha256:abcd1234",
            {"fingerprint": "sha256:abcd1234", "probe_id": "p", "data": 1},
        )
        got = backend.get("sha256:abcd1234")
        assert got is not None
        assert got["data"] == 1

    def test_has_and_get_missing(self, tmp_path):
        backend = sc.CacheBackend(tmp_path / "cache")
        assert backend.has("sha256:zzzz") is False
        assert backend.get("sha256:zzzz") is None

    def test_sharding_by_prefix(self, tmp_path):
        backend = sc.CacheBackend(tmp_path / "cache")
        backend.set("sha256:aa1234", {"data": 1})
        backend.set("sha256:bb5678", {"data": 2})
        # Prefix "aa" and "bb" directories exist.
        assert (tmp_path / "cache" / "aa").is_dir()
        assert (tmp_path / "cache" / "bb").is_dir()

    def test_delete(self, tmp_path):
        backend = sc.CacheBackend(tmp_path / "cache")
        backend.set("sha256:x", {"data": 1})
        assert backend.delete("sha256:x") is True
        assert backend.get("sha256:x") is None
        assert backend.delete("sha256:x") is False  # second delete

    def test_iter_entries(self, tmp_path):
        backend = sc.CacheBackend(tmp_path / "cache")
        backend.set(
            "sha256:aa1",
            {"fingerprint": "sha256:aa1", "probe_id": "L3.x"},
        )
        backend.set(
            "sha256:bb2",
            {"fingerprint": "sha256:bb2", "probe_id": "L4.y"},
        )
        entries = list(backend.iter_entries())
        probes = {e[1]["probe_id"] for e in entries}
        assert probes == {"L3.x", "L4.y"}


# ─── 2-Tier ScanCache ────────────────────────────────────────


class TestScanCacheTiers:
    def test_session_only_roundtrip(self, tmp_path):
        cache = sc.ScanCache(session_root=tmp_path / "s")
        fp = "sha256:aa"
        assert cache.get(fp) is None
        cache.set(fp, {"probe_id": "p", "output": {"data": 1}})
        got = cache.get(fp)
        assert got is not None
        assert got["output"]["data"] == 1

    def test_project_hit_promotes_to_session(self, tmp_path):
        session = tmp_path / "session"
        project = tmp_path / "project"
        cache = sc.ScanCache(session_root=session, project_root=project)
        fp = "sha256:aa"

        # Seed project tier only.
        project_backend = sc.CacheBackend(project)
        project_backend.set(
            fp,
            {
                "$schema": "scan-cache-entry-v1",
                "fingerprint": fp,
                "probe_id": "p",
                "produced_at": sc._now_iso(),
                "ttl_days": 14,
                "output": {"data": 42},
                "privacy_scope": "internal",
            },
        )

        # Session miss → project hit → promote.
        got = cache.get(fp)
        assert got is not None
        assert got["output"]["data"] == 42
        # Now session tier has it.
        assert cache.session.has(fp) is True

    def test_set_publish_writes_both_tiers(self, tmp_path):
        session = tmp_path / "s"
        project = tmp_path / "p"
        cache = sc.ScanCache(session_root=session, project_root=project)
        fp = "sha256:bb"
        written = cache.set(
            fp,
            {"probe_id": "p", "output": {"data": 1}},
            publish_to_project=True,
        )
        assert written is True
        assert cache.session.has(fp) is True
        assert cache.project.has(fp) is True

    def test_set_no_publish_session_only(self, tmp_path):
        session = tmp_path / "s"
        project = tmp_path / "p"
        cache = sc.ScanCache(session_root=session, project_root=project)
        fp = "sha256:cc"
        cache.set(fp, {"probe_id": "p", "output": {"data": 1}})
        assert cache.session.has(fp) is True
        assert cache.project.has(fp) is False


# ─── Privacy Enforcement trong ScanCache ─────────────────────


class TestScanCachePrivacy:
    def test_secret_scope_not_stored(self, tmp_path):
        cache = sc.ScanCache(session_root=tmp_path / "s")
        written = cache.set(
            "sha256:aa",
            {
                "probe_id": "p",
                "privacy_scope": "secret",
                "output": {"data": 1},
            },
        )
        assert written is False
        assert cache.get("sha256:aa") is None

    def test_pii_scope_not_stored(self, tmp_path):
        cache = sc.ScanCache(session_root=tmp_path / "s")
        written = cache.set(
            "sha256:aa",
            {
                "probe_id": "p",
                "privacy_scope": "pii",
                "output": {"data": 1},
            },
        )
        assert written is False

    def test_output_with_password_not_stored(self, tmp_path):
        cache = sc.ScanCache(session_root=tmp_path / "s")
        written = cache.set(
            "sha256:aa",
            {
                "probe_id": "p",
                "privacy_scope": "internal",
                "output": {"user": "u", "password": "x"},
            },
        )
        assert written is False


# ─── Invalidation ────────────────────────────────────────────


class TestInvalidation:
    def test_manual_invalidate_both_tiers(self, tmp_path):
        cache = sc.ScanCache(
            session_root=tmp_path / "s", project_root=tmp_path / "p"
        )
        fp = "sha256:x"
        cache.set(fp, {"probe_id": "p", "output": {}}, publish_to_project=True)
        deleted = cache.invalidate(fp)
        assert deleted == 2
        assert cache.get(fp) is None

    def test_pattern_invalidate(self, tmp_path):
        cache = sc.ScanCache(session_root=tmp_path / "s")
        cache.set("sha256:a", {"probe_id": "L3.inventory.a", "output": {}})
        cache.set("sha256:b", {"probe_id": "L3.inventory.b", "output": {}})
        cache.set("sha256:c", {"probe_id": "L4.classify", "output": {}})

        deleted = cache.invalidate_pattern("L3.inventory.*")
        assert deleted == 2
        assert cache.get("sha256:c") is not None  # L4 preserved

    def test_ttl_expire_on_access(self, tmp_path):
        cache = sc.ScanCache(session_root=tmp_path / "s", ttl_days=1)
        fp = "sha256:x"

        # Write with backdated produced_at.
        past = (datetime.now(timezone.utc) - timedelta(days=3)).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
        cache.session.set(
            fp,
            {
                "$schema": "scan-cache-entry-v1",
                "fingerprint": fp,
                "probe_id": "p",
                "produced_at": past,
                "ttl_days": 1,
                "output": {"data": 1},
                "privacy_scope": "internal",
            },
        )
        # Expired → get returns None + deletes entry.
        assert cache.get(fp) is None
        assert cache.session.has(fp) is False

    def test_invalidate_expired_batch(self, tmp_path):
        cache = sc.ScanCache(session_root=tmp_path / "s", ttl_days=1)
        past = (datetime.now(timezone.utc) - timedelta(days=3)).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

        cache.session.set(
            "sha256:old",
            {"fingerprint": "sha256:old", "probe_id": "p",
             "produced_at": past, "ttl_days": 1, "output": {}},
        )
        cache.session.set(
            "sha256:new",
            {"fingerprint": "sha256:new", "probe_id": "p",
             "produced_at": now, "ttl_days": 1, "output": {}},
        )
        deleted = cache.invalidate_expired()
        assert deleted == 1
        assert cache.session.has("sha256:old") is False
        assert cache.session.has("sha256:new") is True

    def test_invalidate_by_probe_version(self, tmp_path):
        cache = sc.ScanCache(session_root=tmp_path / "s")
        cache.session.set(
            "sha256:a",
            {
                "fingerprint": "sha256:a",
                "probe_id": "L3.inv",
                "probe_version": "1.0",
                "produced_at": sc._now_iso(),
                "output": {},
            },
        )
        cache.session.set(
            "sha256:b",
            {
                "fingerprint": "sha256:b",
                "probe_id": "L3.inv",
                "probe_version": "2.0",
                "produced_at": sc._now_iso(),
                "output": {},
            },
        )
        deleted = cache.invalidate_by_probe_version("L3.inv", "2.0")
        assert deleted == 1
        assert cache.session.has("sha256:a") is False
        assert cache.session.has("sha256:b") is True


# ─── --no-cache Flag ─────────────────────────────────────────


class TestNoCache:
    def test_no_cache_disables_get(self, tmp_path):
        cache = sc.ScanCache(session_root=tmp_path / "s")
        cache.set("sha256:a", {"probe_id": "p", "output": {"x": 1}})

        cache.no_cache = True
        assert cache.get("sha256:a") is None

    def test_no_cache_disables_set(self, tmp_path):
        cache = sc.ScanCache(session_root=tmp_path / "s", no_cache=True)
        written = cache.set("sha256:a", {"probe_id": "p", "output": {}})
        assert written is False
        # Disable flag — entry still not present.
        cache.no_cache = False
        assert cache.get("sha256:a") is None


# ─── Factory ─────────────────────────────────────────────────


class TestBuildScanCache:
    def test_session_only_default(self, tmp_path):
        cache = sc.build_scan_cache(
            session_dir=tmp_path / "session-001",
            project_cache_enabled=False,
        )
        assert cache.project is None
        assert cache.session.root == tmp_path / "session-001" / "cache"

    def test_with_project_tier(self, tmp_path):
        cache = sc.build_scan_cache(
            session_dir=tmp_path / "session-001",
            project_cache_enabled=True,
            project_root=tmp_path,
        )
        assert cache.project is not None
        assert cache.project.root == (
            tmp_path / ".mc-data" / "cache" / "wf-legacy-scan"
        )

    def test_no_cache_flag_propagates(self, tmp_path):
        cache = sc.build_scan_cache(
            session_dir=tmp_path / "s", no_cache=True
        )
        assert cache.no_cache is True
