#!/usr/bin/env python3
"""profile_resolver.py — Resolve dimension.json → probe IDs theo profile.

Vai trò:
    Đọc dimension.json của 1 dimension, trả về danh sách probe IDs phù hợp
    với profile (quick/standard/deep/exhaustive). Dùng bởi lane_dispatch.py
    để biết probes nào cần chạy cho mỗi dimension.

Registry role: NONE. Chỉ đọc dimension.json, không ghi.

Tham chiếu:
    - ADR-02: utility module
    - Stage E1 spec: docs/design/skills/wf-fix-bugs/prompts/stage-E-prompt.md
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

VALID_PROFILES: frozenset[str] = frozenset({"quick", "standard", "deep", "exhaustive"})

# Hỗ trợ QD1-QD11 (QD9=Runtime Health, QD10=Cross-Module Integration, QD11=Business Completeness thêm ở v9.1)
PROBE_ID_PATTERN: re.Pattern[str] = re.compile(r"^P-QD(1[01]|[1-9])-[a-z0-9-]+$")


# ──────────────────────────────────────────────────────────────────────
# Core function
# ──────────────────────────────────────────────────────────────────────


def resolve_probes(dimension_json_path: Path, profile: str) -> list[str]:
    """Đọc dimension.json, trả về probe IDs cho profile.

    Logic:
        1. Read dimension.json
        2. Look up exit_criteria[profile].probes_required
        3. If list → return as-is (validate format)
        4. If "ALL" → collect all probes[].id
        5. Validate mỗi probe ID match pattern
        6. Return ordered list

    Args:
        dimension_json_path: Path đến dimension.json (vd: wf-fix-security/dimension.json).
        profile: "quick" | "standard" | "deep" | "exhaustive".

    Returns:
        Ordered list of probe IDs.

    Raises:
        FileNotFoundError: dimension_json_path không tồn tại.
        ValueError: profile không hợp lệ, JSON schema sai, hoặc probe ID format sai.
    """
    if profile not in VALID_PROFILES:
        raise ValueError(
            f"resolve_probes: profile='{profile}' không hợp lệ "
            f"(cho phép: {sorted(VALID_PROFILES)})"
        )

    if not dimension_json_path.exists():
        raise FileNotFoundError(
            f"resolve_probes: dimension.json không tồn tại: {dimension_json_path}"
        )

    try:
        raw = dimension_json_path.read_text(encoding="utf-8")
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"resolve_probes: JSON parse fail cho {dimension_json_path}: {exc}"
        ) from exc

    if not isinstance(data, dict):
        raise ValueError(
            f"resolve_probes: dimension.json root phải là object, nhận {type(data).__name__}"
        )

    # Lấy exit_criteria
    exit_criteria = data.get("exit_criteria")
    if not isinstance(exit_criteria, dict):
        raise ValueError(
            "resolve_probes: dimension.json thiếu exit_criteria hoặc không phải object"
        )

    profile_config = exit_criteria.get(profile)
    if profile_config is None:
        raise ValueError(
            f"resolve_probes: profile '{profile}' không có trong exit_criteria "
            f"(có: {sorted(exit_criteria.keys())})"
        )

    if not isinstance(profile_config, dict):
        raise ValueError(
            f"resolve_probes: exit_criteria['{profile}'] phải là object"
        )

    probes_required = profile_config.get("probes_required")
    if probes_required is None:
        raise ValueError(
            f"resolve_probes: exit_criteria['{profile}'] thiếu probes_required"
        )

    # Case 1: "ALL" → collect tất cả probes[].id
    if isinstance(probes_required, str) and probes_required == "ALL":
        all_probes = data.get("probes", [])
        if not isinstance(all_probes, list):
            raise ValueError("resolve_probes: probes phải là array")
        result = []
        for i, probe in enumerate(all_probes):
            if not isinstance(probe, dict):
                raise ValueError(f"resolve_probes: probes[{i}] không phải object")
            pid = probe.get("id")
            if not isinstance(pid, str):
                raise ValueError(f"resolve_probes: probes[{i}].id không phải string")
            _validate_probe_id(pid, i)
            result.append(pid)
        return result

    # Case 2: list of probe IDs (empty list = legitimate SKIP for this profile,
    # e.g. QD2 quick profile sets probes_required=[] to opt out — see dimension.json notes)
    if isinstance(probes_required, list):
        if not probes_required:
            return []
        for i, pid in enumerate(probes_required):
            if not isinstance(pid, str):
                raise ValueError(
                    f"resolve_probes: probes_required[{i}] không phải string"
                )
            _validate_probe_id(pid, i)
        return list(probes_required)

    raise ValueError(
        f"resolve_probes: probes_required phải là list hoặc 'ALL', "
        f"nhận {type(probes_required).__name__}"
    )


def _validate_probe_id(pid: str, index: int) -> None:
    """Validate probe ID format: P-QD<x>-<slug> (x ∈ {1..11}, v9.1.0)."""
    if not PROBE_ID_PATTERN.match(pid):
        raise ValueError(
            f"resolve_probes: probe ID tại index {index}='{pid}' "
            f"không match pattern P-QD<x>-<slug> (x ∈ {{1..11}})"
        )


# ──────────────────────────────────────────────────────────────────────
# Dimension-level resolution (profiles.json → dimension list)
# ──────────────────────────────────────────────────────────────────────

CORE_DIMS: frozenset[str] = frozenset({"QD1", "QD2", "QD5"})


def resolve_dimensions(
    profiles_json_path: Path,
    profile: str,
    dims_override: list[str] | None = None,
    only: list[str] | None = None,
    skip: list[str] | None = None,
) -> list[str]:
    """Load profiles.json, resolve dimensions theo profile + overrides.

    Logic:
        1. Read profiles.json
        2. Get base dimensions from profiles[profile].dimensions
        3. Apply overrides: dims_override (replace all), only (filter), skip (remove)
        4. Safety floor check: profile >= standard phải giữ >= 1 của QD1,QD2,QD5
        5. Return final dimension list

    Args:
        profiles_json_path: Path đến profiles.json.
        profile: "quick" | "standard" | "deep" | "exhaustive".
        dims_override: If provided, replaces entire dimension list. Safety floor
            vẫn được ENFORCE (ADR-22 rule 1) — user KHÔNG bypass được bằng --dims.
        only: If provided, filter base dims to only these.
        skip: If provided, remove these dims from result.

    Returns:
        Final ordered list of dimension IDs.

    Raises:
        FileNotFoundError: profiles_json_path không tồn tại.
        ValueError: profile không hợp lệ, JSON schema sai, hoặc safety floor violation.
    """
    if profile not in VALID_PROFILES:
        raise ValueError(
            f"resolve_dimensions: profile='{profile}' không hợp lệ "
            f"(cho phép: {sorted(VALID_PROFILES)})"
        )

    if not profiles_json_path.exists():
        raise FileNotFoundError(
            f"resolve_dimensions: profiles.json không tồn tại: {profiles_json_path}"
        )

    try:
        raw = profiles_json_path.read_text(encoding="utf-8")
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"resolve_dimensions: JSON parse fail cho {profiles_json_path}: {exc}"
        ) from exc

    if not isinstance(data, dict):
        raise ValueError(
            f"resolve_dimensions: profiles.json root phải là object, nhận {type(data).__name__}"
        )

    profiles = data.get("profiles")
    if not isinstance(profiles, dict):
        raise ValueError("resolve_dimensions: profiles.json thiếu 'profiles' object")

    profile_config = profiles.get(profile)
    if not isinstance(profile_config, dict):
        raise ValueError(
            f"resolve_dimensions: profile '{profile}' không có trong profiles "
            f"(có: {sorted(profiles.keys())})"
        )

    base_dims = profile_config.get("dimensions")
    if not isinstance(base_dims, list):
        raise ValueError(
            f"resolve_dimensions: profile '{profile}' thiếu dimensions list"
        )

    # Apply overrides
    if dims_override is not None:
        result = list(dims_override)
    else:
        result = list(base_dims)

        if only is not None:
            only_set = set(only)
            result = [d for d in result if d in only_set]

        if skip is not None:
            skip_set = set(skip)
            result = [d for d in result if d not in skip_set]

    # Safety floor: profile >= standard phải giữ >= 1 core dim
    # ADR-22 rule 1: ENFORCED cả khi dims_override được truyền — user
    # KHÔNG được bypass safety floor bằng cách pass --dims.
    safety = data.get("safety_floor", {})
    applies_to = safety.get("applies_to", [])
    if profile in applies_to and not (CORE_DIMS & set(result)):
        raise ValueError(
            f"resolve_dimensions: safety floor violation — profile '{profile}' "
            f"phải giữ ít nhất 1 dimension trong {sorted(CORE_DIMS)}. "
            f"Kết quả sau override: {result}"
        )

    return result


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: resolve probes hoac dimensions cho profile."""
    import argparse
    import sys as _sys

    # Windows cp1252 → force UTF-8 cho stdout/stderr (Vietnamese chars trong error messages)
    if hasattr(_sys.stdout, "reconfigure"):
        _sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(_sys.stderr, "reconfigure"):
        _sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Profile -> Probe/Dimension resolver")
    sub = parser.add_subparsers(dest="command")

    # Sub-command: probes (original)
    probes_cmd = sub.add_parser("probes", help="Resolve probes for dimension")
    probes_cmd.add_argument(
        "--dimension-json", required=True, type=Path, help="Path đến dimension.json"
    )
    probes_cmd.add_argument(
        "--profile", required=True, choices=sorted(VALID_PROFILES), help="Profile depth"
    )

    # Sub-command: dimensions (new)
    dims_cmd = sub.add_parser("dimensions", help="Resolve dimensions for profile")
    dims_cmd.add_argument(
        "--profiles-json", required=True, type=Path, help="Path đến profiles.json"
    )
    dims_cmd.add_argument(
        "--profile", required=True, choices=sorted(VALID_PROFILES), help="Profile depth"
    )
    dims_cmd.add_argument("--dims", nargs="+", help="Override dimension list")
    dims_cmd.add_argument(
        "--lane",
        help="(v9.0+) Single-lane shorthand: --lane=QD10 → chỉ chạy QD10. "
             "Bỏ qua safety floor. Nếu --dims đã set → --dims wins.",
    )
    dims_cmd.add_argument("--only", nargs="+", help="Only these dimensions")
    dims_cmd.add_argument("--skip", nargs="+", help="Skip these dimensions")

    # Backward compat: no subcommand → probes
    parser.add_argument("--dimension-json", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--profile", choices=sorted(VALID_PROFILES), help=argparse.SUPPRESS)

    args = parser.parse_args(argv)

    try:
        if args.command == "dimensions":
            # --lane shorthand: single-lane focus, bypass safety floor.
            # --dims wins if both provided (documented in SKILL.md §Arguments).
            lane = getattr(args, "lane", None)
            if lane is not None and args.dims is None:
                # Return single lane directly — no safety floor enforcement.
                print(lane)
                return 0
            dims = resolve_dimensions(
                args.profiles_json, args.profile,
                dims_override=args.dims, only=args.only, skip=args.skip,
            )
            for d in dims:
                print(d)
            return 0

        # Default: probes (backward compat)
        dim_json = getattr(args, "dimension_json", None) or args.dimension_json
        profile = args.profile
        if dim_json is None or profile is None:
            parser.print_help()
            return 1
        probes = resolve_probes(dim_json, profile)
        for pid in probes:
            print(pid)
        return 0
    except (FileNotFoundError, ValueError) as exc:
        print(f"[profile_resolver ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
