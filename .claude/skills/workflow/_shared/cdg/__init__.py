"""cdg — CDG (Critical Decision Gate) handoff protocol cho linear skills.

Cung cấp token management cho Critical Decision Gate — đảm bảo
hành động không undo được phải có user confirmation.

Registry role: NONE.

Public API:
    - create_cdg_token: tạo token cho CDG decision
    - load_cdg_tokens: đọc tokens từ session
    - check_anti_loop: kiểm tra anti-loop guard
    - append_token: ghi token vào session (atomic)
"""
from __future__ import annotations

from .cdg_handler import (
    append_token,
    check_anti_loop,
    create_cdg_token,
    load_cdg_tokens,
)

__version__ = "0.1.0"

__all__ = [
    "create_cdg_token",
    "load_cdg_tokens",
    "check_anti_loop",
    "append_token",
]
