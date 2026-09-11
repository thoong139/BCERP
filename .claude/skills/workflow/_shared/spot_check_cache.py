#!/usr/bin/env python3
"""spot_check_cache.py — LRU cache cho Agent Output Spot-Check schema patterns.

Vai trò:
    Cache pattern recognition cho schema check trong CORE-029 Spot-Check Protocol.
    Khi agent output có cùng (agent_type, signal_type, severity) → schema pattern
    đã được validate trước đó có thể reuse → SKIP full schema re-validation.

    LƯU Ý: Chỉ cache SCHEMA CHECK. 3/4 checks còn lại (file existence, scope,
    content sanity) LUÔN CHẠY fresh vì chúng phụ thuộc output cụ thể của agent.

Đặc tả:
    - LRU eviction strategy, max 50 entries (W3.3 plan).
    - Key: (agent_type, signal_type, severity) tuple.
    - Value: dict {schema_pattern_validated: bool, validated_at: ISO timestamp,
                   result: <cached check result>}.
    - Escape hatch: MCV3_FIX_SPOTCHECK_CACHE_DISABLED=1 → pattern_seen() luôn
      trả về None (force fresh validation).

Guard rails (W3.3 — plans/wf-fix-bugs-v10-speedup):
    - CORE-029 Protocol 17: 3/4 checks luôn chạy.
    - Cache size ≤ 50 (LRU eviction).
    - Backward compat: missing import → caller fallback fresh validation.

Registry role: NONE.

Tham chiếu:
    - plans/wf-fix-bugs-v10-speedup/00-master-plan.md §W3.3
    - plans/wf-fix-bugs-v10-speedup/01-guard-rails.md §W3.3
    - .claude/skills/workflow/wf-fix-execute/procedures/_shared.md
      §Agent Output Spot-Check Protocol
"""
from __future__ import annotations

import os
from collections import OrderedDict
from datetime import datetime, timezone
from typing import Any, Optional

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

MAX_SIZE: int = 50
ESCAPE_HATCH_ENV: str = "MCV3_FIX_SPOTCHECK_CACHE_DISABLED"


# ──────────────────────────────────────────────────────────────────────
# LRU Cache class
# ──────────────────────────────────────────────────────────────────────


class SpotCheckCache:
    """LRU cache cho schema pattern recognition trong Spot-Check.

    Key tuple: (agent_type, signal_type, severity).
    Value dict: {schema_pattern_validated: bool, validated_at: str, result: Any}.

    Behaviour:
        - pattern_seen() → trả cached entry và move-to-end (LRU touch). None nếu miss.
        - remember() → insert mới hoặc cập nhật entry hiện hữu, evict oldest nếu vượt MAX_SIZE.
        - clear() → reset toàn bộ cache.
        - inspector_size() → trả số entry hiện tại (dùng cho test/assertion).

    Escape hatch:
        Nếu env MCV3_FIX_SPOTCHECK_CACHE_DISABLED=1 → pattern_seen() trả None
        bất chấp nội dung cache (force fresh check mỗi lần). remember() vẫn ghi
        bình thường để giữ trạng thái có thể inspect/debug, KHÔNG ảnh hưởng hành vi.
    """

    def __init__(self, max_size: int = MAX_SIZE) -> None:
        if max_size <= 0:
            raise ValueError(f"max_size phải > 0, nhận {max_size}")
        self._max_size: int = max_size
        self._cache: "OrderedDict[tuple[str, str, str], dict[str, Any]]" = OrderedDict()

    # ───── Public API ────────────────────────────────────────────────

    def pattern_seen(
        self,
        agent_type: str,
        signal_type: str,
        severity: str,
    ) -> Optional[dict[str, Any]]:
        """Lookup pattern đã validate trước đó.

        Returns:
            dict entry nếu hit (đã move-to-end). None nếu miss hoặc escape hatch bật.
        """
        if _escape_hatch_enabled():
            return None
        key = _make_key(agent_type, signal_type, severity)
        entry = self._cache.get(key)
        if entry is None:
            return None
        # LRU touch
        self._cache.move_to_end(key)
        return entry

    def remember(
        self,
        agent_type: str,
        signal_type: str,
        severity: str,
        result: Any,
    ) -> None:
        """Lưu kết quả schema check vào cache.

        Args:
            result: Kết quả schema check (thường là dict đặc tả pass/fail + chi tiết).
        """
        key = _make_key(agent_type, signal_type, severity)
        entry = {
            "schema_pattern_validated": True,
            "validated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "result": result,
        }
        # Cập nhật entry hiện hữu → move-to-end để giữ "vừa dùng".
        if key in self._cache:
            self._cache[key] = entry
            self._cache.move_to_end(key)
            return
        # Insert mới → evict oldest nếu vượt giới hạn.
        self._cache[key] = entry
        while len(self._cache) > self._max_size:
            self._cache.popitem(last=False)

    def clear(self) -> None:
        """Reset cache về rỗng."""
        self._cache.clear()

    def inspector_size(self) -> int:
        """Trả về số entry hiện tại (dùng cho test/assertion)."""
        return len(self._cache)


# ──────────────────────────────────────────────────────────────────────
# Internal helpers
# ──────────────────────────────────────────────────────────────────────


def _make_key(agent_type: str, signal_type: str, severity: str) -> tuple[str, str, str]:
    """Chuẩn hóa key — tránh case-mismatch giữa các agent output."""
    return (
        str(agent_type or "").strip().lower(),
        str(signal_type or "").strip().lower(),
        str(severity or "").strip().upper(),
    )


def _escape_hatch_enabled() -> bool:
    """Kiểm tra escape hatch MCV3_FIX_SPOTCHECK_CACHE_DISABLED."""
    return os.environ.get(ESCAPE_HATCH_ENV, "0") == "1"


__all__ = ["SpotCheckCache", "MAX_SIZE", "ESCAPE_HATCH_ENV"]
