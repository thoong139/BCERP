"""test_e2e_stage_i.py — E2E smoke tests cho Stage I.

Test cases:
    1. resolve_dimensions: profiles.json → quick → [QD1, QD5]
    2. resolve_dimensions: standard + skip=[QD2] → [QD1, QD5]
    3. resolve_dimensions: standard + skip=[QD1,QD2,QD5] → ValueError (safety floor)
    4. resolve_dimensions: standard + dims_override=[QD3,QD7] → [QD3, QD7]
    5. generate_lane_report from template → output có đúng placeholders
    6. generate_coverage_report from template → output có đúng placeholders
    7. Full E2E v6 smoke: dispatch → aggregate → reports → valid outputs
    8. fix-status.json template has engine_version field

Tham chiếu:
    - Stage I spec: docs/design/skills/wf-fix-bugs/prompts/stage-I-prompt.md
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from lane_dispatch import dispatch_lanes
from profile_resolver import resolve_dimensions
from report_generator import generate_coverage_report, generate_lane_report
from signal_aggregator import aggregate_lane_signals


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def workflow_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


@pytest.fixture
def shared_root() -> Path:
    return Path(__file__).resolve().parent.parent


@pytest.fixture
def tmp_session_dir(tmp_path: Path) -> Path:
    session = tmp_path / "session"
    session.mkdir(parents=True, exist_ok=True)
    return session


@pytest.fixture
def profiles_path(shared_root: Path) -> Path:
    return shared_root / "profiles.json"


# ──────────────────────────────────────────────────────────────────────
# I1: resolve_dimensions
# ──────────────────────────────────────────────────────────────────────


class TestResolveDimensions:
    """resolve_dimensions() loads profiles.json và resolves đúng dims per profile."""

    def test_resolve_dimensions_quick(self, profiles_path: Path) -> None:
        result = resolve_dimensions(profiles_path, "quick")
        assert result == ["QD1", "QD5"]

    def test_resolve_dimensions_standard(self, profiles_path: Path) -> None:
        result = resolve_dimensions(profiles_path, "standard")
        assert result == ["QD1", "QD2", "QD5", "QD9", "QD10"]

    def test_resolve_dimensions_deep(self, profiles_path: Path) -> None:
        result = resolve_dimensions(profiles_path, "deep")
        assert set(result) == {"QD1", "QD2", "QD5", "QD6", "QD3", "QD9", "QD10", "QD11"}

    def test_resolve_dimensions_exhaustive(self, profiles_path: Path) -> None:
        result = resolve_dimensions(profiles_path, "exhaustive")
        assert set(result) == {"QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"}


class TestResolveDimensionsOverrides:
    """resolve_dimensions() respects override parameters."""

    def test_standard_skip_qd2(self, profiles_path: Path) -> None:
        result = resolve_dimensions(profiles_path, "standard", skip=["QD2"])
        assert result == ["QD1", "QD5", "QD9", "QD10"]

    def test_standard_only_qd1(self, profiles_path: Path) -> None:
        result = resolve_dimensions(profiles_path, "standard", only=["QD1"])
        assert result == ["QD1"]

    def test_dims_override_respects_safety_floor(self, profiles_path: Path) -> None:
        # ADR-22 rule 1: dims_override KHÔNG bypass safety floor cho profile standard
        with pytest.raises(ValueError, match="safety floor"):
            resolve_dimensions(
                profiles_path, "standard", dims_override=["QD3", "QD7"]
            )

    def test_dims_override_passes_when_core_included(self, profiles_path: Path) -> None:
        # Safety floor pass khi dims_override chứa ít nhất 1 core dim (QD1/QD2/QD5)
        result = resolve_dimensions(
            profiles_path, "standard", dims_override=["QD1", "QD3", "QD7"]
        )
        assert result == ["QD1", "QD3", "QD7"]


class TestResolveDimensionsSafetyFloor:
    """Safety floor enforcement: standard + skip all core → ValueError."""

    def test_standard_skip_all_core_rejected(self, profiles_path: Path) -> None:
        with pytest.raises(ValueError, match="safety floor"):
            resolve_dimensions(
                profiles_path, "standard", skip=["QD1", "QD2", "QD5"]
            )

    def test_deep_skip_all_core_rejected(self, profiles_path: Path) -> None:
        with pytest.raises(ValueError, match="safety floor"):
            resolve_dimensions(
                profiles_path, "deep", skip=["QD1", "QD2", "QD5", "QD3", "QD6"]
            )

    def test_quick_no_safety_floor(self, profiles_path: Path) -> None:
        result = resolve_dimensions(profiles_path, "quick", skip=["QD1"])
        assert result == ["QD5"]

    def test_invalid_profile_rejected(self, profiles_path: Path) -> None:
        with pytest.raises(ValueError, match="không hợp lệ"):
            resolve_dimensions(profiles_path, "invalid_profile")

    def test_missing_profiles_json(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError):
            resolve_dimensions(tmp_path / "nonexistent.json", "quick")


# ──────────────────────────────────────────────────────────────────────
# I2: Report generation
# ──────────────────────────────────────────────────────────────────────


class TestLaneReportGeneration:
    """generate_lane_report từ template → output có đúng placeholders."""

    def test_lane_report_generated(
        self, shared_root: Path, tmp_session_dir: Path
    ) -> None:
        template = shared_root / "templates" / "lane-report.md"
        assert template.exists(), "lane-report.md template must exist"

        output = tmp_session_dir / "lanes" / "QD1" / "lane-report.md"
        result = generate_lane_report(
            template_path=template,
            output_path=output,
            dimension_id="QD1",
            dimension_name="Functional Correctness",
            profile="standard",
            session_dir=str(tmp_session_dir),
            probes_total=5,
            probes_available=7,
            signals_count=12,
            issues_count=3,
            probe_rows="| P-QD1-001 | PASS | 2 |\n",
            issues_detail="3 issues found",
            recommendations="Review error handling",
            started_at="2026-04-21T10:00:00Z",
            completed_at="2026-04-21T10:05:00Z",
        )

        assert result == output
        assert output.exists()
        content = output.read_text(encoding="utf-8")
        assert "QD1" in content
        assert "Functional Correctness" in content
        assert "standard" in content
        assert "5" in content
        assert "12" in content
        assert "3" in content
        # Placeholders must be replaced
        assert "{{DIMENSION_ID}}" not in content
        assert "{{PROFILE}}" not in content


class TestCoverageReportGeneration:
    """generate_coverage_report từ template → output có đúng placeholders."""

    def test_coverage_report_generated(
        self, shared_root: Path, tmp_session_dir: Path
    ) -> None:
        template = shared_root / "templates" / "coverage-report.md"
        assert template.exists(), "coverage-report.md template must exist"

        output = tmp_session_dir / "coverage-report.md"
        result = generate_coverage_report(
            template_path=template,
            output_path=output,
            profile="standard",
            dimensions_list="QD1, QD2, QD5",
            skipped_dimensions="QD3, QD4, QD6, QD7",
            session_dir=str(tmp_session_dir),
            dimension_rows="| QD1 | Functional | 7 | 12 | 3 | 5m |\n",
            total_signals=35,
            total_issues=8,
            dimensions_with_issues=2,
            dimensions_run=3,
            coverage_pct=66.7,
            severity_rows="| HIGH | 3 |\n",
            recommendations="Focus on QD1 issues first",
            started_at="2026-04-21T10:00:00Z",
            completed_at="2026-04-21T10:15:00Z",
        )

        assert result == output
        assert output.exists()
        content = output.read_text(encoding="utf-8")
        assert "standard" in content
        assert "QD1, QD2, QD5" in content
        assert "35" in content
        assert "8" in content
        assert "66.7" in content
        # Placeholders must be replaced
        assert "{{PROFILE}}" not in content
        assert "{{TOTAL_SIGNALS}}" not in content


# ──────────────────────────────────────────────────────────────────────
# I6: Full E2E v6 smoke
# ──────────────────────────────────────────────────────────────────────


class TestFullE2EV6Smoke:
    """Full E2E: dispatch → aggregate → reports → valid outputs."""

    def test_full_e2e_v6_smoke(
        self, tmp_session_dir: Path, workflow_root: Path, shared_root: Path
    ) -> None:
        dims = ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8"]

        # Step 1: Dispatch all 8 dimensions
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=dims,
            profile="exhaustive",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )

        # Step 2: Aggregate signals
        registry_path, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=dims,
        )

        assert registry_path.exists()
        registry_data = json.loads(registry_path.read_text(encoding="utf-8"))
        assert "issues" in registry_data

        # Step 3: Generate lane report for QD1
        lane_template = shared_root / "templates" / "lane-report.md"
        lanes_dir = tmp_session_dir / "lanes"
        if lanes_dir.exists() and (lanes_dir / "QD1").exists():
            lane_output = lanes_dir / "QD1" / "lane-report.md"
            generate_lane_report(
                template_path=lane_template,
                output_path=lane_output,
                dimension_id="QD1",
                dimension_name="Functional",
                profile="exhaustive",
                session_dir=str(tmp_session_dir),
                probes_total=3,
                probes_available=7,
                signals_count=stats.total_signals,
                issues_count=len(registry_data.get("issues", [])),
                probe_rows="",
                issues_detail="See issue-registry.json",
                recommendations="Review found issues",
                started_at="2026-04-21T10:00:00Z",
                completed_at="2026-04-21T10:05:00Z",
            )
            assert lane_output.exists()

        # Step 4: Generate coverage report
        coverage_template = shared_root / "templates" / "coverage-report.md"
        coverage_output = tmp_session_dir / "coverage-report.md"
        generate_coverage_report(
            template_path=coverage_template,
            output_path=coverage_output,
            profile="exhaustive",
            dimensions_list=", ".join(dims),
            skipped_dimensions="",
            session_dir=str(tmp_session_dir),
            dimension_rows="",
            total_signals=stats.total_signals,
            total_issues=len(registry_data.get("issues", [])),
            dimensions_with_issues=0,
            dimensions_run=7,
            coverage_pct=100.0,
            severity_rows="",
            recommendations="Full scan complete",
            started_at="2026-04-21T10:00:00Z",
            completed_at="2026-04-21T10:10:00Z",
        )
        assert coverage_output.exists()

        # Step 5: Validate issue-registry.json is valid JSON
        assert json.loads(registry_path.read_text(encoding="utf-8"))


# ──────────────────────────────────────────────────────────────────────
# I5: fix-status.json v6 fields
# ──────────────────────────────────────────────────────────────────────


class TestV6FixStatusFields:
    """fix-status.json template has v6 fields (template: _shared/templates/fix-status.json)."""

    def test_fix_status_has_v6_fields(self, shared_root: Path) -> None:
        template = shared_root / "templates" / "fix-status.json"
        assert template.exists(), "fix-status.json template must exist at _shared/templates/fix-status.json"

        data = json.loads(template.read_text(encoding="utf-8"))
        assert "engine_version" in data
        # v8.2.0: template default bumped from "v6" → "v8" để tránh mislead khi engine đã v8.x.
        # Runtime scripts (wf-fix-init-status.sh) overwrite field này — chỉ là default placeholder.
        assert data["engine_version"] == "v8"
        assert "dimensions_resolved" in data
        assert "profile_used" in data
        assert "dimension_overrides" in data

    def test_fix_status_v6_defaults(self, shared_root: Path) -> None:
        """v8 session defaults: engine_version=v8, nullable runtime fields, base status fields."""
        template = shared_root / "templates" / "fix-status.json"
        data = json.loads(template.read_text(encoding="utf-8"))
        assert data["engine_version"] == "v8"
        assert data["dimensions_resolved"] is None
        assert data["profile_used"] is None
        assert data["dimension_overrides"] is None
        assert data["fix_id"] == "{{FIX_ID}}"  # Mustache placeholder, substituted by wf-fix-init-status.sh
        assert data["status"] == "not_started"
        assert data["active_skill"] == "wf-fix-bugs"
