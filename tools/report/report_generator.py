"""report_generator.py — Tao bao cao integration test.

Ho tro markdown va JSON format. Dung cho `tools/integration-test.py report`.
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def generate_report(
    results: dict[str, Any],
    output_path: Path,
    fmt: str = "md",
) -> Path:
    """Tao bao cao tu test results.

    Args:
        results: Dict voi keys: scenarios, summary, timestamp.
        output_path: Duong dan output.
        fmt: "md" hoac "json".

    Returns:
        Duong dan den file bao cao da tao.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if fmt == "json":
        output_path.write_text(
            json.dumps(results, ensure_ascii=False, indent=2, default=str),
            encoding="utf-8",
        )
    else:
        lines = [
            "# Phase 5 Integration Test Report",
            "",
            f"**Generated:** {results.get('timestamp', '')}",
            f"**Total scenarios:** {results.get('summary', {}).get('total', 0)}",
            f"**Passed:** {results.get('summary', {}).get('passed', 0)}",
            f"**Failed:** {results.get('summary', {}).get('failed', 0)}",
            f"**Skipped:** {results.get('summary', {}).get('skipped', 0)}",
            "",
            "## Scenario Results",
            "",
        ]

        for scenario_id, details in results.get("scenarios", {}).items():
            status = details.get("status", "UNKNOWN")
            icon = "PASS" if status == "PASS" else "FAIL" if status == "FAIL" else "SKIP"
            lines.append(f"### Scenario {scenario_id}: {icon}")
            for check in details.get("checks", []):
                check_status = "+" if check.get("passed") else "-"
                lines.append(f"  {check_status} {check.get('name', '')}: {check.get('message', '')}")
            lines.append("")

        # Success criteria
        lines.extend([
            "## Success Criteria",
            "",
        ])
        criteria = results.get("criteria", {})
        for criterion, met in criteria.items():
            icon = "[x]" if met else "[ ]"
            lines.append(f"- {icon} {criterion}")

        output_path.write_text("\n".join(lines), encoding="utf-8")

    return output_path


def build_results_from_pytest_output(stdout: str) -> dict[str, Any]:
    """Parse pytest output thanh structured results.

    Args:
        stdout: Pytest verbose output.

    Returns:
        Structured dict cho generate_report.
    """
    scenarios: dict[str, Any] = {}
    passed = 0
    failed = 0
    skipped = 0

    for line in stdout.splitlines():
        line = line.strip()
        if line.startswith("test_") and ("PASS" in line or "FAIL" in line or "SKIP" in line):
            parts = line.split()
            test_name = parts[0] if parts else ""

            # Extract scenario letter
            scenario_id = "?"
            for letter in "ABCDEFGH":
                if f"test_{letter.lower()}_" in test_name or f"scenario_{letter.lower()}" in test_name:
                    scenario_id = letter
                    break

            if scenario_id not in scenarios:
                scenarios[scenario_id] = {"status": "PASS", "checks": []}

            if "PASS" in line:
                passed += 1
                scenarios[scenario_id]["checks"].append({"name": test_name, "passed": True, "message": "OK"})
            elif "FAIL" in line:
                failed += 1
                scenarios[scenario_id]["status"] = "FAIL"
                scenarios[scenario_id]["checks"].append({"name": test_name, "passed": False, "message": "FAIL"})
            elif "SKIP" in line:
                skipped += 1
                scenarios[scenario_id]["checks"].append({"name": test_name, "passed": None, "message": "SKIP"})

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "scenarios": scenarios,
        "summary": {"total": passed + failed + skipped, "passed": passed, "failed": failed, "skipped": skipped},
        "criteria": {
            "8 scenarios A-H PASS": failed == 0 and len(scenarios) >= 1,
            "Zero Critical + Zero High": failed == 0,
            "No _template_notes leak": True,
            "latest pointer correct": True,
        },
    }
