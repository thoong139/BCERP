"""Scan Cache — content-addressable 2-tier cache cho wf-legacy-scan v5.0.

Reference: docs/design/skills/wf-legacy-scan/08-tradeoffs-adr.md ADR-LS10
+ 04-data-model.md §7 (Scan Cache Schema).

Fingerprint:
    SHA256(probe_id || probe_version || depth_level || config_hash ||
           input_file_hashes || dep_closure_hash)

Tiers:
- Session cache: `sessions/<id>/cache/` — ephemeral, gitignored.
- Project cache: `.mc-data/cache/wf-legacy-scan/` — opt-in commit via
  `--cache-publish`.

Invalidation rules (§7.4):
- File hash change → fingerprint mismatch (automatic).
- Dep closure change → fingerprint mismatch (automatic).
- Probe version bump → fingerprint mismatch (automatic).
- Config change → fingerprint mismatch (automatic).
- TTL expire (`produced_at + ttl_days < now`) → explicit invalidate_expired().
- User force `--no-cache` → caller short-circuits lookup.
- User pattern `--invalidate-cache=<pattern>` → invalidate_pattern().

Privacy (ADR-LS10 §privacy): entries với privacy_scope in {"secret", "pii"}
KHÔNG bao giờ được cache (write is no-op).
"""

from __future__ import annotations

import fnmatch
import hashlib
import json
import os
import re
import time
from pathlib import Path
from typing import Any

# ─── Constants ───────────────────────────────────────────────

DEFAULT_TTL_DAYS = 14
SESSION_CACHE_DIRNAME = "cache"
PROJECT_CACHE_RELATIVE = Path(".mc-data/cache/wf-legacy-scan")

# Privacy scopes that MUST NOT be cached (ADR-LS10 privacy guard).
_FORBIDDEN_PRIVACY_SCOPES = frozenset({"secret", "pii"})

# Patterns nghi ngờ chứa secrets (simple regex, case-insensitive).
_SECRET_KEY_PATTERNS = [
    re.compile(r"\bpassword\b", re.IGNORECASE),
    re.compile(r"\btoken\b", re.IGNORECASE),
    re.compile(r"\bapi[_-]?key\b", re.IGNORECASE),
    re.compile(r"\bsecret\b", re.IGNORECASE),
    re.compile(r"\bprivate[_-]?key\b", re.IGNORECASE),
]


# ─── Fingerprint Helpers ─────────────────────────────────────


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str | None:
    """Return sha256 hex of a file, or None nếu file không tồn tại."""
    if not path.exists() or not path.is_file():
        return None
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_files(paths: list[Path] | list[str]) -> str:
    """Return sha256 hex của danh sách files (sorted + concatenated digests)."""
    digests: list[str] = []
    for p in sorted(str(pp) for pp in paths):
        d = sha256_file(Path(p))
        # Non-existent files contribute "missing:<path>" để fingerprint stable
        # và đổi nếu file xuất hiện sau.
        digests.append(d if d is not None else f"missing:{p}")
    joined = "\n".join(digests).encode("utf-8")
    return _sha256_bytes(joined)


def sha256_config(config: dict[str, Any]) -> str:
    """Stable sha256 of config dict (sorted keys)."""
    canonical = json.dumps(config, sort_keys=True, ensure_ascii=False)
    return _sha256_bytes(canonical.encode("utf-8"))


def compute_fingerprint(
    probe_id: str,
    probe_version: str,
    depth: str,
    config: dict[str, Any],
    input_files: list[str],
    dep_closure_files: list[str] | None = None,
) -> str:
    """Compute canonical fingerprint theo 04-data-model.md §7.2.

    Args:
        probe_id: Stable probe identifier (e.g., "L3.inventory.screens").
        probe_version: Probe version string (bump on logic change).
        depth: Depth level (full/surface/standard/deep/exhaustive).
        config: Relevant config dict (batch_size, caps, etc.).
        input_files: List of input file paths.
        dep_closure_files: Transitive dependency files (optional).

    Returns:
        Fingerprint string prefixed `sha256:`.
    """
    parts = [
        f"probe_id={probe_id}",
        f"probe_version={probe_version}",
        f"depth={depth}",
        f"config_hash={sha256_config(config)}",
        f"input_hash={sha256_files(input_files)}",
        f"dep_closure_hash={sha256_files(dep_closure_files or [])}",
    ]
    joined = "\n".join(parts).encode("utf-8")
    return f"sha256:{_sha256_bytes(joined)}"


# ─── Privacy Guard ───────────────────────────────────────────


def is_cacheable(
    privacy_scope: str | None,
    output: dict[str, Any] | None = None,
) -> bool:
    """Return False nếu entry chứa secrets / privacy-restricted data.

    Cả 2 điều kiện → forbidden:
    1. `privacy_scope` in {"secret", "pii"}.
    2. `output` chứa key match _SECRET_KEY_PATTERNS (shallow scan).
    """
    if privacy_scope and privacy_scope.lower() in _FORBIDDEN_PRIVACY_SCOPES:
        return False
    if output is None:
        return True
    return _scan_for_secrets(output) is None


def _scan_for_secrets(obj: Any, _depth: int = 0) -> str | None:
    """Shallow scan cho secret keys trong dict/list (max depth 3).

    Returns: first matching key path hoặc None.
    """
    if _depth > 3:
        return None
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(k, str):
                for pattern in _SECRET_KEY_PATTERNS:
                    if pattern.search(k):
                        return str(k)
            nested = _scan_for_secrets(v, _depth + 1)
            if nested is not None:
                return nested
    elif isinstance(obj, list):
        for item in obj:
            nested = _scan_for_secrets(item, _depth + 1)
            if nested is not None:
                return nested
    return None


# ─── Cache Backend ───────────────────────────────────────────


class CacheBackend:
    """File-system backed cache — single tier (session OR project).

    Layout: `<root>/<fp_prefix>/<fingerprint>.json` (prefix = first 2 hex
    chars after `sha256:` để giảm dir size).
    """

    def __init__(self, root: Path) -> None:
        self.root = Path(root)

    def _entry_path(self, fingerprint: str) -> Path:
        # Strip algorithm prefix `sha256:`.
        hex_part = fingerprint.split(":", 1)[-1]
        prefix = hex_part[:2] if len(hex_part) >= 2 else "00"
        return self.root / prefix / f"{hex_part}.json"

    def has(self, fingerprint: str) -> bool:
        path = self._entry_path(fingerprint)
        return path.exists() and path.stat().st_size > 0

    def get(self, fingerprint: str) -> dict[str, Any] | None:
        path = self._entry_path(fingerprint)
        if not path.exists():
            return None
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return None

    def set(self, fingerprint: str, entry: dict[str, Any]) -> None:
        """Atomic write: tmp → fsync → rename."""
        path = self._entry_path(fingerprint)
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(f".json.tmp.{os.getpid()}")
        # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
        tmp.write_text(
            json.dumps(entry, indent=2, ensure_ascii=False, sort_keys=True), encoding="utf-8"
        )
        try:
            with tmp.open("rb") as f:
                os.fsync(f.fileno())
        except (OSError, AttributeError):
            pass
        tmp.replace(path)

    def delete(self, fingerprint: str) -> bool:
        """Delete entry. Returns True if actually deleted."""
        path = self._entry_path(fingerprint)
        if path.exists():
            try:
                path.unlink()
                return True
            except OSError:
                pass
        return False

    def iter_entries(self):
        """Yield (fingerprint, entry_dict) for every cache entry."""
        if not self.root.exists():
            return
        for prefix_dir in self.root.iterdir():
            if not prefix_dir.is_dir():
                continue
            for entry_path in prefix_dir.glob("*.json"):
                try:
                    entry = json.loads(entry_path.read_text(encoding="utf-8"))
                except (json.JSONDecodeError, OSError):
                    continue
                fingerprint = entry.get("fingerprint") or (
                    f"sha256:{entry_path.stem}"
                )
                yield fingerprint, entry


# ─── 2-Tier Scan Cache ───────────────────────────────────────


class ScanCache:
    """2-tier scan cache: session (ephemeral) + project (opt-in).

    Lookup order:
      1. Session cache (fastest).
      2. Project cache (nếu enabled), promote hit to session cache.
      3. Miss → caller runs probe + `set()`.

    TTL enforced at lookup — expired entries deleted on access.
    """

    def __init__(
        self,
        session_root: Path,
        project_root: Path | None = None,
        ttl_days: int = DEFAULT_TTL_DAYS,
        no_cache: bool = False,
    ) -> None:
        self.session = CacheBackend(session_root)
        self.project: CacheBackend | None = (
            CacheBackend(project_root) if project_root is not None else None
        )
        self.ttl_days = ttl_days
        self.no_cache = no_cache

    # ─── Core API ─────────────────────────────────────────

    def get(self, fingerprint: str) -> dict[str, Any] | None:
        """Lookup entry. Returns dict if found & valid, else None.

        Honors:
        - `no_cache` flag (always miss).
        - TTL (expired entries deleted on access).
        """
        if self.no_cache:
            return None

        # Tier 1: session.
        entry = self.session.get(fingerprint)
        if entry is not None:
            if self._is_expired(entry):
                self.session.delete(fingerprint)
            else:
                return entry

        # Tier 2: project.
        if self.project is not None:
            entry = self.project.get(fingerprint)
            if entry is not None:
                if self._is_expired(entry):
                    self.project.delete(fingerprint)
                else:
                    # Promote to session tier.
                    try:
                        self.session.set(fingerprint, entry)
                    except OSError:
                        pass
                    return entry

        return None

    def set(
        self,
        fingerprint: str,
        entry: dict[str, Any],
        publish_to_project: bool = False,
    ) -> bool:
        """Write entry to session tier (+ project tier nếu publish).

        Privacy guard: nếu entry chứa secrets/PII → no-op, return False.

        Args:
            fingerprint: Cache key.
            entry: Entry dict theo §7.1 schema.
            publish_to_project: Nếu True + project tier enabled → write cả 2.

        Returns:
            True nếu written to at least 1 tier.
        """
        if self.no_cache:
            return False

        privacy = entry.get("privacy_scope")
        output = entry.get("output", {})
        if not is_cacheable(privacy, output):
            return False

        # Enrich metadata.
        enriched = {
            "$schema": "scan-cache-entry-v1",
            "fingerprint": fingerprint,
            "ttl_days": entry.get("ttl_days", self.ttl_days),
            **entry,
        }
        enriched.setdefault("produced_at", _now_iso())

        written = False
        try:
            self.session.set(fingerprint, enriched)
            written = True
        except OSError:
            pass

        if publish_to_project and self.project is not None:
            try:
                self.project.set(fingerprint, enriched)
                written = True
            except OSError:
                pass
        return written

    # ─── Invalidation ─────────────────────────────────────

    def invalidate(self, fingerprint: str) -> int:
        """Delete entry từ cả 2 tiers. Returns số entries xoá được."""
        deleted = 0
        if self.session.delete(fingerprint):
            deleted += 1
        if self.project is not None and self.project.delete(fingerprint):
            deleted += 1
        return deleted

    def invalidate_pattern(self, pattern: str) -> int:
        """Invalidate entries matching probe_id pattern (glob, e.g. `L3.*`).

        Scans cache entries và xoá entry.probe_id matches.
        """
        deleted = 0
        for backend in self._backends():
            for fingerprint, entry in list(backend.iter_entries()):
                probe_id = entry.get("probe_id", "")
                if fnmatch.fnmatchcase(probe_id, pattern):
                    if backend.delete(fingerprint):
                        deleted += 1
        return deleted

    def invalidate_expired(self, now: float | None = None) -> int:
        """Scan all entries and delete expired. Returns count deleted."""
        deleted = 0
        for backend in self._backends():
            for fingerprint, entry in list(backend.iter_entries()):
                if self._is_expired(entry, now=now):
                    if backend.delete(fingerprint):
                        deleted += 1
        return deleted

    def invalidate_by_probe_version(
        self, probe_id: str, minimum_version: str
    ) -> int:
        """Invalidate entries with probe_id match và version < minimum.

        String comparison — caller đảm bảo version format sortable.
        """
        deleted = 0
        for backend in self._backends():
            for fingerprint, entry in list(backend.iter_entries()):
                if entry.get("probe_id") != probe_id:
                    continue
                v = entry.get("probe_version", "")
                if v < minimum_version:
                    if backend.delete(fingerprint):
                        deleted += 1
        return deleted

    # ─── Internals ────────────────────────────────────────

    def _backends(self) -> list[CacheBackend]:
        if self.project is None:
            return [self.session]
        return [self.session, self.project]

    def _is_expired(
        self, entry: dict[str, Any], now: float | None = None
    ) -> bool:
        produced_at = entry.get("produced_at")
        if not produced_at:
            return False
        ttl_days = entry.get("ttl_days", self.ttl_days)
        try:
            produced_ts = _iso_to_epoch(produced_at)
        except ValueError:
            return False
        expires_at = produced_ts + ttl_days * 86400
        reference = now if now is not None else time.time()
        return reference >= expires_at


# ─── Time Helpers ────────────────────────────────────────────


def _now_iso() -> str:
    """UTC ISO 8601 timestamp (seconds precision)."""
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _iso_to_epoch(ts: str) -> float:
    """Parse ISO 8601 (with trailing Z) → epoch seconds."""
    clean = ts.replace("Z", "+00:00") if ts.endswith("Z") else ts
    # Python 3.11+ fromisoformat handles offset; fallback to strptime.
    from datetime import datetime

    try:
        dt = datetime.fromisoformat(clean)
    except ValueError as exc:
        raise ValueError(f"invalid ISO timestamp: {ts!r}") from exc
    return dt.timestamp()


# ─── Factory Helper ──────────────────────────────────────────


def build_scan_cache(
    session_dir: Path,
    project_cache_enabled: bool = False,
    project_root: Path | None = None,
    ttl_days: int = DEFAULT_TTL_DAYS,
    no_cache: bool = False,
) -> ScanCache:
    """Construct ScanCache với project tier optional.

    Args:
        session_dir: Active session directory (`sessions/<id>/`).
        project_cache_enabled: Enable project-shared tier.
        project_root: Root project path; defaults to cwd.
        ttl_days: TTL.
        no_cache: Global bypass switch.
    """
    session_root = Path(session_dir) / SESSION_CACHE_DIRNAME
    project_path: Path | None = None
    if project_cache_enabled:
        base = Path(project_root) if project_root is not None else Path.cwd()
        project_path = base / PROJECT_CACHE_RELATIVE
    return ScanCache(
        session_root=session_root,
        project_root=project_path,
        ttl_days=ttl_days,
        no_cache=no_cache,
    )
