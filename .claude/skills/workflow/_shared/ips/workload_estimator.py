"""Workload Estimator — estimate workload minutes cho profile planning.

Thin utility exposing workload estimate functions that the IPS Phase B and
orchestrator share. Actual estimate logic lives in ips_recommender._estimate_workload
to keep a single source of truth (numbers can drift otherwise).

Reference: docs/design/skills/wf-legacy-scan/05-profiles-ips.md §4
           (Workload Gate + soft cap thresholds).
"""

from __future__ import annotations

from typing import Any

from .ips_recommender import (
    FEATURE_DENSITY_PER_FILE,
    PROFILE_BUDGET_MIN,
    TIME_PER_FEATURE_MIN,
    _estimate_workload,
)


def estimate_workload(
    inventory: dict[str, Any],
    *,
    profile: str = "standard",
) -> dict[str, Any]:
    """Estimate workload cho mot scan session.

    Args:
        inventory: Parsed inventory summary. Accepts two shapes:
            1. {"total_files": int, "module_count": int}  (pre-computed)
            2. {"source-files": {"files": [...]}}          (raw inventory)
        profile: Profile level (surface / standard / deep / exhaustive).

    Returns:
        Dict with keys total_features_est, est_time_min, soft_cap_min,
        budget_min, exceeds_cap, ratio, module_count.
    """
    # Shape 1 — pre-computed.
    total_files = inventory.get("total_files")
    module_count = inventory.get("module_count")

    if total_files is None:
        # Shape 2 — derive from source-files list.
        src = inventory.get("source-files") or inventory.get("source_files") or {}
        files = (
            src.get("files", [])
            if isinstance(src, dict)
            else (src if isinstance(src, list) else [])
        )
        total_files = len(files)

    if module_count is None:
        # Heuristic: if inventory provides "modules" list, use its length.
        modules = inventory.get("modules") or []
        module_count = len(modules) if isinstance(modules, list) else 0

    return _estimate_workload(profile, int(total_files), int(module_count))


__all__ = [
    "FEATURE_DENSITY_PER_FILE",
    "PROFILE_BUDGET_MIN",
    "TIME_PER_FEATURE_MIN",
    "estimate_workload",
]
