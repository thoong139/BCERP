"""lane — Generic lane dispatch cho linear workflow skills.

Cung cấp generic lane dispatch cho 5 linear skills, thay thế QD-specific
lane_dispatch.py. Lanes có thể group theo department, system, feature-group,
spec-type, hoặc role — không fix cứng theo QD dimension.

Registry role: NONE.

Public API:
    - LaneConfig: cấu hình 1 lane
    - LaneResult: kết quả 1 lane
    - dispatch_lanes: chạy nhiều lanes song song với backpressure
"""
from __future__ import annotations

from .dispatcher import LaneConfig, LaneResult, dispatch_lanes

__version__ = "0.1.0"

__all__ = [
    "LaneConfig",
    "LaneResult",
    "dispatch_lanes",
]
