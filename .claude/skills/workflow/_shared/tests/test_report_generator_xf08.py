"""test_report_generator_xf08.py — XF-08 (Sprint 6) coverage uplift.

Verify report_generator.py CORE-031 template-driven generation:
- _populate_template: simple {{KEY}} replacement, multiple keys
- generate_lane_report: READ template → POPULATE → WRITE
- generate_coverage_report: similar logic, coverage_pct formatting
- Missing template raises FileNotFoundError
- CLI main() — lane + coverage subcommands

Tests dùng tmp_path để tránh ghi vào project tree.
"""
from __future__ import annotations

from pathlib import Path

import pytest

from report_generator import (
    _populate_template,
    generate_coverage_report,
    generate_lane_report,
    main,
)


LANE_TEMPLATE = """# Lane Report — {{DIMENSION_ID}}

Profile: {{PROFILE}}
Session: {{SESSION_DIR}}
Probes total: {{PROBES_TOTAL}} (available: {{PROBES_AVAILABLE}})
Signals: {{SIGNALS_COUNT}}, Issues: {{ISSUES_COUNT}}

Started: {{STARTED_AT}}
Completed: {{COMPLETED_AT}}

## Probes
{{PROBE_TABLE_ROWS}}

## Issues
{{ISSUES_DETAIL}}

## Recommendations
{{RECOMMENDATIONS}}
"""


COVERAGE_TEMPLATE = """# Coverage Report

Profile: {{PROFILE}}
Dimensions: {{DIMENSIONS_LIST}} (skipped: {{SKIPPED_DIMENSIONS}})
Session: {{SESSION_DIR}}

| Dim | Signals | Issues |
{{DIMENSION_TABLE_ROWS}}

Total signals: {{TOTAL_SIGNALS}}
Total issues: {{TOTAL_ISSUES}}
Dimensions with issues: {{DIMENSIONS_WITH_ISSUES}}/{{DIMENSIONS_RUN}}
Coverage: {{COVERAGE_PCT}}%

## Severity
{{SEVERITY_TABLE_ROWS}}

## Recommendations
{{RECOMMENDATIONS}}

Started: {{STARTED_AT}}
Completed: {{COMPLETED_AT}}
"""


# ──────────────────────────────────────────────────────────────────────
# _populate_template
# ──────────────────────────────────────────────────────────────────────


class TestPopulateTemplate:
    def test_single_replacement(self) -> None:
        result = _populate_template("Hello {{NAME}}", {"NAME": "World"})
        assert result == "Hello World"

    def test_multiple_replacements(self) -> None:
        result = _populate_template(
            "{{A}}-{{B}}-{{A}}",
            {"A": "x", "B": "y"},
        )
        assert result == "x-y-x"

    def test_missing_placeholder_unchanged(self) -> None:
        """Placeholder không có trong replacements → giữ nguyên."""
        result = _populate_template("{{UNMATCHED}}", {"OTHER": "v"})
        assert result == "{{UNMATCHED}}"

    def test_value_stringified(self) -> None:
        """Non-string values phải được str()."""
        result = _populate_template("count={{N}}", {"N": 42})
        assert result == "count=42"


# ──────────────────────────────────────────────────────────────────────
# generate_lane_report
# ──────────────────────────────────────────────────────────────────────


class TestGenerateLaneReport:
    def test_writes_populated_file(self, tmp_path: Path) -> None:
        template = tmp_path / "lane-template.md"
        template.write_text(LANE_TEMPLATE, encoding="utf-8")
        output = tmp_path / "subdir" / "QD1-report.md"

        result = generate_lane_report(
            template_path=template,
            output_path=output,
            dimension_id="QD1",
            dimension_name="Functional Correctness",
            profile="standard",
            session_dir="/tmp/session",
            probes_total=7,
            probes_available=7,
            signals_count=3,
            issues_count=2,
            probe_rows="| P-QD1-x | OK |",
            issues_detail="### Bug X",
            recommendations="Fix X",
            started_at="2026-05-15T08:00:00Z",
            completed_at="2026-05-15T08:05:00Z",
        )

        assert result == output
        content = output.read_text(encoding="utf-8")
        assert "QD1" in content
        assert "standard" in content
        assert "Signals: 3, Issues: 2" in content
        assert "Probes total: 7 (available: 7)" in content
        assert "Fix X" in content

    def test_missing_template_raises(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError, match="Lane report template"):
            generate_lane_report(
                template_path=tmp_path / "missing.md",
                output_path=tmp_path / "out.md",
                dimension_id="QD1",
                dimension_name="x",
                profile="quick",
                session_dir="/tmp",
                probes_total=0,
                probes_available=0,
                signals_count=0,
                issues_count=0,
                probe_rows="",
                issues_detail="",
                recommendations="",
                started_at="t",
                completed_at="t",
            )


# ──────────────────────────────────────────────────────────────────────
# generate_coverage_report
# ──────────────────────────────────────────────────────────────────────


class TestGenerateCoverageReport:
    def test_writes_with_pct_formatting(self, tmp_path: Path) -> None:
        template = tmp_path / "cov-template.md"
        template.write_text(COVERAGE_TEMPLATE, encoding="utf-8")
        output = tmp_path / "coverage-report.md"

        result = generate_coverage_report(
            template_path=template,
            output_path=output,
            profile="deep",
            dimensions_list="QD1,QD3,QD5",
            skipped_dimensions="",
            session_dir="/tmp/session",
            dimension_rows="| QD1 | 3 | 2 |",
            total_signals=10,
            total_issues=7,
            dimensions_with_issues=3,
            dimensions_run=3,
            coverage_pct=100.0,
            severity_rows="| CRITICAL | 2 |",
            recommendations="",
            started_at="t1",
            completed_at="t2",
        )

        assert result == output
        content = output.read_text(encoding="utf-8")
        # Coverage_pct phải format với 1 decimal place
        assert "Coverage: 100.0%" in content
        assert "Total signals: 10" in content
        assert "QD1,QD3,QD5" in content

    def test_pct_decimal_truncation(self, tmp_path: Path) -> None:
        """Coverage_pct truncate về 1 decimal."""
        template = tmp_path / "tpl.md"
        template.write_text("{{COVERAGE_PCT}}", encoding="utf-8")
        output = tmp_path / "out.md"

        generate_coverage_report(
            template_path=template,
            output_path=output,
            profile="standard",
            dimensions_list="QD1",
            skipped_dimensions="",
            session_dir="/tmp",
            dimension_rows="",
            total_signals=0,
            total_issues=0,
            dimensions_with_issues=0,
            dimensions_run=1,
            coverage_pct=66.6666666,
            severity_rows="",
            recommendations="",
            started_at="t",
            completed_at="t",
        )
        assert output.read_text(encoding="utf-8") == "66.7"

    def test_missing_template_raises(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError, match="Coverage report template"):
            generate_coverage_report(
                template_path=tmp_path / "missing.md",
                output_path=tmp_path / "out.md",
                profile="x",
                dimensions_list="",
                skipped_dimensions="",
                session_dir="/tmp",
                dimension_rows="",
                total_signals=0,
                total_issues=0,
                dimensions_with_issues=0,
                dimensions_run=0,
                coverage_pct=0.0,
                severity_rows="",
                recommendations="",
                started_at="t",
                completed_at="t",
            )


# ──────────────────────────────────────────────────────────────────────
# CLI main()
# ──────────────────────────────────────────────────────────────────────


class TestCLI:
    def test_lane_subcommand(self, tmp_path: Path) -> None:
        template = tmp_path / "lane.md"
        template.write_text(LANE_TEMPLATE, encoding="utf-8")
        output = tmp_path / "lane-report.md"

        rc = main([
            "lane",
            "--template", str(template),
            "--output", str(output),
            "--dimension-id", "QD3",
            "--dimension-name", "Security",
            "--profile", "deep",
            "--session-dir", "/tmp/s",
            "--probes-total", "5",
            "--probes-available", "7",
            "--signals-count", "2",
            "--issues-count", "1",
            "--started-at", "2026-05-15T00:00:00Z",
            "--completed-at", "2026-05-15T00:05:00Z",
        ])
        assert rc == 0
        content = output.read_text(encoding="utf-8")
        assert "QD3" in content
        assert "deep" in content

    def test_coverage_subcommand(self, tmp_path: Path) -> None:
        template = tmp_path / "cov.md"
        template.write_text(COVERAGE_TEMPLATE, encoding="utf-8")
        output = tmp_path / "cov-report.md"

        rc = main([
            "coverage",
            "--template", str(template),
            "--output", str(output),
            "--profile", "standard",
            "--dimensions-list", "QD1,QD3",
            "--skipped-dimensions", "QD11",
            "--session-dir", "/tmp/s",
            "--total-signals", "5",
            "--total-issues", "3",
            "--dimensions-with-issues", "2",
            "--dimensions-run", "2",
            "--coverage-pct", "100.0",
            "--started-at", "t1",
            "--completed-at", "t2",
        ])
        assert rc == 0
        content = output.read_text(encoding="utf-8")
        assert "QD1,QD3" in content
        assert "100.0" in content
