#!/usr/bin/env python3
"""report_generator.py — Generate lane report + coverage report từ templates (CORE-031).

Vai trò:
    Đọc template markdown → populate placeholders → ghi output.
    Dùng bởi wf-fix-bugs v6 engine để tạo lane-report.md + coverage-report.md.

Registry role: NONE. Chỉ đọc templates và ghi output reports.

Tham chiếu:
    - CORE-031: Template Usage Rule
    - ADR-21: Profile locked defaults
    - Stage I2 spec: docs/design/skills/wf-fix-bugs/prompts/stage-I-prompt.md
"""
from __future__ import annotations

from pathlib import Path


# ──────────────────────────────────────────────────────────────────────
# Helper
# ──────────────────────────────────────────────────────────────────────


def _populate_template(template_content: str, replacements: dict[str, str]) -> str:
    """Replace {{KEY}} placeholders in template content."""
    result = template_content
    for key, value in replacements.items():
        result = result.replace(f"{{{{{key}}}}}", str(value))
    return result


# ──────────────────────────────────────────────────────────────────────
# Lane Report
# ──────────────────────────────────────────────────────────────────────


def generate_lane_report(
    template_path: Path,
    output_path: Path,
    dimension_id: str,
    dimension_name: str,
    profile: str,
    session_dir: str,
    probes_total: int,
    probes_available: int,
    signals_count: int,
    issues_count: int,
    probe_rows: str,
    issues_detail: str,
    recommendations: str,
    started_at: str,
    completed_at: str,
) -> Path:
    """READ template → POPULATE data → WRITE output (CORE-031).

    Args:
        template_path: Path đến lane-report.md template.
        output_path: Path đến output file sẽ ghi.
        dimension_id: VD: "QD1".
        dimension_name: VD: "Functional Correctness".
        profile: VD: "standard".
        session_dir: Session directory path.
        probes_total: Số probes đã chạy.
        probes_available: Tổng probes available.
        signals_count: Số signals phát hiện.
        issues_count: Số issues (sau dedup).
        probe_rows: Markdown table rows cho probe chi tiết.
        issues_detail: Markdown content cho issues section.
        recommendations: Markdown content cho recommendations.
        started_at: ISO timestamp.
        completed_at: ISO timestamp.

    Returns:
        Path đến output file đã ghi.
    """
    if not template_path.exists():
        raise FileNotFoundError(f"Lane report template not found: {template_path}")
    template_content = template_path.read_text(encoding="utf-8")

    populated = _populate_template(template_content, {
        "DIMENSION_ID": dimension_id,
        "DIMENSION_NAME": dimension_name,
        "PROFILE": profile,
        "SESSION_DIR": session_dir,
        "PROBES_TOTAL": str(probes_total),
        "PROBES_AVAILABLE": str(probes_available),
        "SIGNALS_COUNT": str(signals_count),
        "ISSUES_COUNT": str(issues_count),
        "PROBE_TABLE_ROWS": probe_rows,
        "ISSUES_DETAIL": issues_detail,
        "RECOMMENDATIONS": recommendations,
        "STARTED_AT": started_at,
        "COMPLETED_AT": completed_at,
    })

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(populated, encoding="utf-8")
    return output_path


# ──────────────────────────────────────────────────────────────────────
# Coverage Report
# ──────────────────────────────────────────────────────────────────────


def generate_coverage_report(
    template_path: Path,
    output_path: Path,
    profile: str,
    dimensions_list: str,
    skipped_dimensions: str,
    session_dir: str,
    dimension_rows: str,
    total_signals: int,
    total_issues: int,
    dimensions_with_issues: int,
    dimensions_run: int,
    coverage_pct: float,
    severity_rows: str,
    recommendations: str,
    started_at: str,
    completed_at: str,
) -> Path:
    """READ template → POPULATE data → WRITE output (CORE-031).

    Args:
        template_path: Path đến coverage-report.md template.
        output_path: Path đến output file sẽ ghi.
        profile: VD: "standard".
        dimensions_list: Comma-separated dimension IDs.
        skipped_dimensions: Comma-separated skipped dimensions.
        session_dir: Session directory path.
        dimension_rows: Markdown table rows cho dimension coverage.
        total_signals: Tổng signals (trước dedup).
        total_issues: Tổng issues (sau dedup).
        dimensions_with_issues: Số dimensions có issues.
        dimensions_run: Tổng dimensions chạy.
        coverage_pct: Coverage percentage.
        severity_rows: Markdown table rows cho severity breakdown.
        recommendations: Markdown content cho recommendations.
        started_at: ISO timestamp.
        completed_at: ISO timestamp.

    Returns:
        Path đến output file đã ghi.
    """
    if not template_path.exists():
        raise FileNotFoundError(f"Coverage report template not found: {template_path}")
    template_content = template_path.read_text(encoding="utf-8")

    populated = _populate_template(template_content, {
        "PROFILE": profile,
        "DIMENSIONS_LIST": dimensions_list,
        "SKIPPED_DIMENSIONS": skipped_dimensions,
        "SESSION_DIR": session_dir,
        "DIMENSION_TABLE_ROWS": dimension_rows,
        "TOTAL_SIGNALS": str(total_signals),
        "TOTAL_ISSUES": str(total_issues),
        "DIMENSIONS_WITH_ISSUES": str(dimensions_with_issues),
        "DIMENSIONS_RUN": str(dimensions_run),
        "COVERAGE_PCT": f"{coverage_pct:.1f}",
        "SEVERITY_TABLE_ROWS": severity_rows,
        "RECOMMENDATIONS": recommendations,
        "STARTED_AT": started_at,
        "COMPLETED_AT": completed_at,
    })

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(populated, encoding="utf-8")
    return output_path


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: generate lane-report.md hoặc coverage-report.md từ templates.

    Usage (chạy từ CWD=`_shared/`):
        cd .claude/skills/workflow/_shared && python -m report_generator lane \\
            --template templates/lane-report.md \\
            --output $SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/QD1-functional-report.md \\
            --dimension-id QD1 --dimension-name "Functional Correctness" \\
            --profile standard --session-dir $SESSION_DIR \\
            --probes-total 7 --probes-available 7 \\
            --signals-count 3 --issues-count 2 \\
            --probe-rows "" --issues-detail "" --recommendations "" \\
            --started-at 2026-04-21T08:00:00Z --completed-at 2026-04-21T08:05:00Z

        cd .claude/skills/workflow/_shared && python -m report_generator coverage \\
            --template templates/coverage-report.md \\
            --output $SESSION_DIR/phase4-find-bugs/coverage-report.md \\
            --profile standard --dimensions-list "QD1,QD3,QD5" \\
            --skipped-dimensions "" --session-dir $SESSION_DIR \\
            --dimension-rows "" --total-signals 10 --total-issues 7 \\
            --dimensions-with-issues 3 --dimensions-run 3 \\
            --coverage-pct 100.0 --severity-rows "" --recommendations "" \\
            --started-at 2026-04-21T08:00:00Z --completed-at 2026-04-21T08:10:00Z
    """
    import argparse
    import json
    import sys

    # Windows cp1252 → force UTF-8 cho stdout/stderr
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Report Generator (CORE-031)")
    subparsers = parser.add_subparsers(dest="mode", required=True)

    # Lane report subcommand
    lane = subparsers.add_parser("lane", help="Generate per-lane report")
    lane.add_argument("--template", required=True, type=Path)
    lane.add_argument("--output", required=True, type=Path)
    lane.add_argument("--dimension-id", required=True)
    lane.add_argument("--dimension-name", required=True)
    lane.add_argument("--profile", required=True)
    lane.add_argument("--session-dir", required=True)
    lane.add_argument("--probes-total", type=int, required=True)
    lane.add_argument("--probes-available", type=int, required=True)
    lane.add_argument("--signals-count", type=int, required=True)
    lane.add_argument("--issues-count", type=int, required=True)
    lane.add_argument("--probe-rows", default="")
    lane.add_argument("--issues-detail", default="")
    lane.add_argument("--recommendations", default="")
    lane.add_argument("--started-at", required=True)
    lane.add_argument("--completed-at", required=True)

    # Coverage report subcommand
    cov = subparsers.add_parser("coverage", help="Generate coverage report")
    cov.add_argument("--template", required=True, type=Path)
    cov.add_argument("--output", required=True, type=Path)
    cov.add_argument("--profile", required=True)
    cov.add_argument("--dimensions-list", required=True)
    cov.add_argument("--skipped-dimensions", default="")
    cov.add_argument("--session-dir", required=True)
    cov.add_argument("--dimension-rows", default="")
    cov.add_argument("--total-signals", type=int, required=True)
    cov.add_argument("--total-issues", type=int, required=True)
    cov.add_argument("--dimensions-with-issues", type=int, required=True)
    cov.add_argument("--dimensions-run", type=int, required=True)
    cov.add_argument("--coverage-pct", type=float, required=True)
    cov.add_argument("--severity-rows", default="")
    cov.add_argument("--recommendations", default="")
    cov.add_argument("--started-at", required=True)
    cov.add_argument("--completed-at", required=True)

    args = parser.parse_args(argv)

    try:
        if args.mode == "lane":
            out = generate_lane_report(
                template_path=args.template, output_path=args.output,
                dimension_id=args.dimension_id, dimension_name=args.dimension_name,
                profile=args.profile, session_dir=args.session_dir,
                probes_total=args.probes_total, probes_available=args.probes_available,
                signals_count=args.signals_count, issues_count=args.issues_count,
                probe_rows=args.probe_rows, issues_detail=args.issues_detail,
                recommendations=args.recommendations,
                started_at=args.started_at, completed_at=args.completed_at,
            )
        else:  # coverage
            out = generate_coverage_report(
                template_path=args.template, output_path=args.output,
                profile=args.profile, dimensions_list=args.dimensions_list,
                skipped_dimensions=args.skipped_dimensions, session_dir=args.session_dir,
                dimension_rows=args.dimension_rows,
                total_signals=args.total_signals, total_issues=args.total_issues,
                dimensions_with_issues=args.dimensions_with_issues,
                dimensions_run=args.dimensions_run,
                coverage_pct=args.coverage_pct,
                severity_rows=args.severity_rows, recommendations=args.recommendations,
                started_at=args.started_at, completed_at=args.completed_at,
            )
    except (OSError, FileNotFoundError, ValueError) as exc:
        print(f"[report_generator ERROR] {exc}", file=sys.stderr)
        return 1

    print(json.dumps({"output": str(out), "mode": args.mode}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
