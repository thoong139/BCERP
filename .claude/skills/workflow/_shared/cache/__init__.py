"""cache — Cache adapter cho linear workflow skills.

Adapter wrapping existing scan_cache/, cung cấp content-hash based
caching interface đơn giản cho linear skills.

Registry role: NONE.

Public API:
    - get_cached: tra cache theo skill + content_hash + output_key
    - set_cached: ghi cache
    - invalidate_cache: xoá cache
    - compute_content_hash: sha256 của concatenated file contents
"""
from __future__ import annotations

from .cache_adapter import (
    compute_content_hash,
    get_cached,
    invalidate_cache,
    set_cached,
)

__version__ = "0.1.0"

__all__ = [
    "get_cached",
    "set_cached",
    "invalidate_cache",
    "compute_content_hash",
]
