#!/usr/bin/env python3
"""integration-test.py — CLI harness cho Phase 5 integration tests.

Commands:
    run [--scenario A|B|...|ALL]  — chay pytest scenarios
    validate [--dir DIR]         — validate existing .mc-data/ outputs
    report [--format md|json]    — generate test report
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

_TOOLS_ROOT = Path(__file__).resolve().parent
_MCV3_ROOT = _TOOLS_ROOT.parent

SCENARIO_MAP = {
    "A": "scenarios/test_a_new_project.py",
    "B": "scenarios/test_b_legacy_project.py",
    "C": "scenarios/test_c_feature_add.py",
    "D": "scenarios/test_d_resume.py",
    "E": "scenarios/test_e_workload_cdg.py",
    "F": "scenarios/test_f_api_only.py",
    "G": "scenarios/test_g_session_cleanup.py",
    "H": "scenarios/test_h_concurrent.py",
}


def cmd_run(args: argparse.Namespace) -> int:
    """Chay pytest voi scenario filter."""
    if args.scenario == "ALL":
        target = "scenarios/"
    else:
        path = SCENARIO_MAP.get(args.scenario.upper())
        if path is None:
            print(f"Unknown scenario: {args.scenario}. Valid: {', '.join(SCENARIO_MAP)}")
            return 1
        target = path

    cmd = [sys.executable, "-m", "pytest", target, "-v", "--tb=short"]
    if args.markers:
        cmd.extend(["-m", args.markers])

    result = subprocess.run(cmd, cwd=str(_TOOLS_ROOT))
    return result.returncode


def cmd_validate(args: argparse.Namespace) -> int:
    """Validate existing .mc-data/ directory."""
    sys.path.insert(0, str(_TOOLS_ROOT))

    mc_dir = Path(args.dir) if args.dir else _MCV3_ROOT / ".mc-data"
    if not mc_dir.exists():
        print(f"Directory not found: {mc_dir}")
        return 1

    from validators.schema_validator import validate_all_meta_files
    from validators.path_contract import validate_all_contracts
    from validators.registry_validator import validate_registry_schema, validate_impl_statuses

    errors_found = 0

    # Schema validation
    print("=== Schema Validation ===")
    meta_results = validate_all_meta_files(mc_dir)
    for name, (ok, errs) in sorted(meta_results.items()):
        status = "PASS" if ok else "FAIL"
        print(f"  {status} {name}")
        if not ok:
            for e in errs:
                print(f"    - {e}")
            errors_found += 1

    # Registry
    print("\n=== Registry Validation ===")
    reg = mc_dir / "docs" / "_meta" / "req-registry.json"
    if reg.exists():
        ok, errs = validate_registry_schema(reg)
        print(f"  {'PASS' if ok else 'FAIL'} schema")
        if not ok:
            for e in errs:
                print(f"    - {e}")
            errors_found += 1

        ok, errs = validate_impl_statuses(reg)
        print(f"  {'PASS' if ok else 'FAIL'} impl_statuses")
        if not ok:
            for e in errs:
                print(f"    - {e}")
            errors_found += 1
    else:
        print("  SKIP req-registry.json not found")

    # Path contracts
    print("\n=== Path Contract Validation ===")
    contracts = validate_all_contracts(mc_dir)
    for c in contracts:
        status = c["status"]
        print(f"  {status} {c['message']}")
        if status == "FAIL":
            errors_found += 1

    print(f"\n{'PASS' if errors_found == 0 else 'FAIL'} — {errors_found} error(s)")
    return 1 if errors_found > 0 else 0


def cmd_report(args: argparse.Namespace) -> int:
    """Generate test report tu pytest output."""
    report_dir = _TOOLS_ROOT / "report"
    report_dir.mkdir(parents=True, exist_ok=True)

    result = subprocess.run(
        [sys.executable, "-m", "pytest", "scenarios/", "-v", "--tb=line", "-q"],
        capture_output=True, text=True, cwd=str(_TOOLS_ROOT),
    )

    fmt = args.format or "md"
    if fmt == "json":
        report = {
            "timestamp": __import__("datetime").datetime.now().isoformat(),
            "exit_code": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
        out_path = report_dir / "report.json"
        out_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    else:
        out_path = report_dir / "report.md"
        out_path.write_text(
            f"# Phase 5 Integration Test Report\n\n"
            f"**Generated:** {__import__('datetime').datetime.now().isoformat()}\n"
            f"**Exit code:** {result.returncode}\n\n"
            f"## Output\n\n```\n{result.stdout}\n```\n\n"
            f"## Errors\n\n```\n{result.stderr}\n```\n",
            encoding="utf-8",
        )

    print(f"Report written to: {out_path}")
    return result.returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Phase 5 Integration Tests")
    sub = parser.add_subparsers(dest="command")

    run_p = sub.add_parser("run", help="Run integration test scenarios")
    run_p.add_argument("--scenario", default="ALL", help="Scenario ID (A-H) or ALL")
    run_p.add_argument("--markers", default=None, help="pytest markers filter")

    val_p = sub.add_parser("validate", help="Validate existing .mc-data/ outputs")
    val_p.add_argument("--dir", default=None, help="Path to .mc-data/ directory")

    rep_p = sub.add_parser("report", help="Generate test report")
    rep_p.add_argument("--format", choices=["md", "json"], default="md")

    args = parser.parse_args(argv)

    if args.command == "run":
        return cmd_run(args)
    elif args.command == "validate":
        return cmd_validate(args)
    elif args.command == "report":
        return cmd_report(args)
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
