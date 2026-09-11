"""__main__.py — CLI entry point cho scan_cache module.

Cho phep chay:
    python -m _shared.scan_cache.cache_store clear --cache-root=<path> --older-than=14d
    python -m _shared.scan_cache.cache_store set --cache-root=<path> --probe-id=P1-01 ...

Tham chieu: B4-2 — Scan Cache prune CLI.
"""
from _shared.scan_cache.cache_store import main
import sys

sys.exit(main())
