"""isg — Interactive Selection Gate cho wf-fix-bugs orchestrator.

Khi user gõ `/wf-fix-bugs` không kèm `--dims`, ISG phân tích signals (git
diff, preflight, registry domain), hiển thị bảng tick 7 Quality Dimension,
nhận selection từ user → emit `dim-selection.json`. Enforce safety floor
ADR-22 rule 1 (QD1+QD2+QD5 cho profile ≥ standard) + CDG (CORE-027) cho các
lựa chọn "nguy hiểm" như bỏ QD1/QD3.

ADR refs: ADR-14 (ISG), ADR-22 rule 1 (safety floor).
CORE refs: CORE-027 (Critical Decision Gate).

Public API:
    - DimRecommendation, Signals (data classes)
    - collect_signals, analyze, render_checklist, parse_user_response
    - enforce_safety_floor, check_cdg, emit_selection
    - Constants: DIMENSIONS, DIM_NAMES, DEFAULT_PROFILE_DIMS,
      SAFETY_FLOOR_DIMS, SAFETY_FLOOR_PROFILES, VALID_PROFILES,
      CDG_TOKEN_OVERRIDE_QD1, CDG_TOKEN_SKIP_QD3
"""

from .isg_recommender import (
    CDG_TOKEN_OVERRIDE_QD1,
    CDG_TOKEN_SKIP_QD3,
    DEFAULT_PROFILE_DIMS,
    DIM_NAMES,
    DIMENSIONS,
    SAFETY_FLOOR_DIMS,
    SAFETY_FLOOR_PROFILES,
    VALID_PROFILES,
    DimRecommendation,
    Signals,
    analyze,
    check_cdg,
    collect_signals,
    emit_selection,
    enforce_safety_floor,
    parse_user_response,
    render_checklist,
)

__version__ = "0.2.0-b2"

__all__ = [
    # Data classes
    "DimRecommendation",
    "Signals",
    # Core functions
    "collect_signals",
    "analyze",
    "render_checklist",
    "parse_user_response",
    "enforce_safety_floor",
    "check_cdg",
    "emit_selection",
    # Constants
    "DIMENSIONS",
    "DIM_NAMES",
    "DEFAULT_PROFILE_DIMS",
    "VALID_PROFILES",
    "SAFETY_FLOOR_DIMS",
    "SAFETY_FLOOR_PROFILES",
    "CDG_TOKEN_OVERRIDE_QD1",
    "CDG_TOKEN_SKIP_QD3",
]
