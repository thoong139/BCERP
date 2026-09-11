"""profiles — Hệ thống profile 3 cấp cho linear workflow skills.

Cung cấp profile resolution (quick/standard/deep) cho 5 linear skills:
wf-brainstorm, wf-analyze-requirements, wf-define-features, wf-design, wf-design-ux.

Khác với profiles.json gốc (QD-based cho wf-fix-bugs), module này dùng
depth_map theo phase_key thay vì dimension (ADR-OPT-06).

Registry role: NONE.

Public API:
    - resolve_profile: chốt profile cuối cùng từ CLI + recommendation
    - validate_safety_floor: enforce production-bound ≥ standard
    - get_depth_for_phase: tra depth_map value
    - estimate_time: ước lượng thời gian theo profile
"""

from .profile_resolver import (
    LINEAR_VALID_PROFILES,
    estimate_time,
    get_depth_for_phase,
    resolve_profile,
    validate_safety_floor,
)

__version__ = "0.1.0"

__all__ = [
    "resolve_profile",
    "validate_safety_floor",
    "get_depth_for_phase",
    "estimate_time",
    "LINEAR_VALID_PROFILES",
]
