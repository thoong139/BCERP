"""scan_cache — Content-addressable cache cho probe results.

Shared utility module cho `/wf-fix-discover` v6.0+ (opt-in `--use-cache`).
Fingerprint = sha256(probe_id + probe_version + file_sha256 + config). TTL
mặc định 14 ngày. QD3 (Security) không bao giờ cache (ADR-22 rule 6).

ADR refs: ADR-19 (Scan Cache), ADR-22 rule 6 (QD3 never cached).

Public API:
    - fingerprint: hash_file_content, hash_config, compute_fingerprint
    - cache_store: set_entry, clear_older_than, QD3_FORBIDDEN
    - cache_lookup: lookup, is_expired, CacheEntry
"""

from .cache_lookup import CacheEntry, is_expired, lookup
from .cache_store import QD3_FORBIDDEN, clear_older_than, set_entry
from .fingerprint import compute_fingerprint, hash_config, hash_file_content

__version__ = "0.2.0-b2"

__all__ = [
    # fingerprint
    "hash_file_content",
    "hash_config",
    "compute_fingerprint",
    # cache_store
    "set_entry",
    "clear_older_than",
    "QD3_FORBIDDEN",
    # cache_lookup
    "lookup",
    "is_expired",
    "CacheEntry",
]
