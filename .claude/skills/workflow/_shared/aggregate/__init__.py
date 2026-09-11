"""aggregate — Generic signal aggregator + dedup + coverage estimator cho linear skills.

Cung cấp aggregation cho output từ nhiều lanes, với configurable dedup,
và coverage estimation cho honest framing trong fix-report.

Registry role: NONE.

Public API:
    - aggregate_lane_signals: gom lane outputs, dedup, detect conflicts
    - dedup_key_fn: configurable dedup key function
    - dedup_by_id: preset key function theo ID field
    - dedup_by_composite: preset key function theo composite fields
    - estimate_coverage: compute coverage estimate cho session
    - load_session_inputs: load fix-status.json + stack-info.json
"""
from __future__ import annotations

from .aggregator import (
    AggregationResult,
    Conflict,
    aggregate_lane_signals,
    dedup_by_composite,
    dedup_by_id,
)
from .coverage_estimator import estimate_coverage, load_session_inputs

__version__ = "0.2.0"

__all__ = [
    "aggregate_lane_signals",
    "dedup_by_id",
    "dedup_by_composite",
    "AggregationResult",
    "Conflict",
    "estimate_coverage",
    "load_session_inputs",
]
