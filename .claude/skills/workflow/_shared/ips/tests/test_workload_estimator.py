"""Tests for workload_estimator.py — Phase C implementation.

Pure utility wrapper around ips_recommender._estimate_workload.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import workload_estimator as we  # noqa: E402


class TestEstimateWorkloadPrecomputed:
    """Shape 1 — caller already has total_files + module_count."""

    def test_standard_500_files(self) -> None:
        w = we.estimate_workload(
            {"total_files": 500, "module_count": 10}, profile="standard"
        )
        assert w["total_features_est"] == 40
        assert w["est_time_min"] == 60
        assert w["exceeds_cap"] is True

    def test_surface_no_extraction(self) -> None:
        w = we.estimate_workload(
            {"total_files": 100, "module_count": 3}, profile="surface"
        )
        assert w["total_features_est"] == 0
        assert w["est_time_min"] == 0


class TestEstimateWorkloadFromRawInventory:
    """Shape 2 — caller passes raw inventory source-files list."""

    def test_derive_from_source_files(self) -> None:
        inv = {
            "source-files": {
                "files": [
                    {"path": f"src/m{i}/a.ts"} for i in range(300)
                ]
            },
            "modules": ["m1", "m2", "m3"],
        }
        w = we.estimate_workload(inv, profile="deep")
        # 0.12 × 300 = 36 features × 2.5 = 90 min
        assert w["total_features_est"] == 36
        assert w["est_time_min"] == 90
        assert w["module_count"] == 3


class TestReExportConstants:
    def test_reexports(self) -> None:
        assert "standard" in we.PROFILE_BUDGET_MIN
        assert we.FEATURE_DENSITY_PER_FILE["standard"] == pytest.approx(0.08)
        assert we.TIME_PER_FEATURE_MIN["deep"] == pytest.approx(2.5)
