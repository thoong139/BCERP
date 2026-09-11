#!/usr/bin/env python3
"""profile_resolver.py — Resolve profile cho linear workflow skills.

Vai trò:
    Xác định profile (quick/standard/deep) cho skill chạy, dựa trên:
    1. CLI flag (user chỉ định trực tiếp)
    2. Recommendation từ ISG hoặc previous skill
    3. Default: "standard"

    Sau đó tra depth_map để biết mức độ chi tiết cho từng phase.

Registry role: NONE.

Tham chiếu:
    - ADR-OPT-06: Profile system 3 cấp cho linear authoring
    - Adapt từ _shared/profile_resolver.py gốc (QD-based)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

LINEAR_VALID_PROFILES: frozenset[str] = frozenset({"quick", "standard", "deep"})

DEFAULT_PROFILE: str = "standard"

# Mapping skill_name → phase_key chính (dùng khi tra depth_map)
SKILL_PHASE_MAP: dict[str, str] = {
    "wf-analyze-requirements": "requirements",
    "wf-define-features": "features",
    "wf-design": "design",
    "wf-design-ux": "ux",
    "wf-brainstorm": "requirements",
    "wf-plan-modules": "design",
    "wf-implement-feature": "design",
}

# Fallback depth nếu phase_key không có trong depth_map
FALLBACK_DEPTH: str = "full"


# ──────────────────────────────────────────────────────────────────────
# Core functions
# ──────────────────────────────────────────────────────────────────────


def _load_profiles_data(
    profiles_json_path: Path | None = None,
) -> dict[str, Any]:
    """Đọc profiles.json, trả về parsed data.

    Args:
        profiles_json_path: Path đến profiles.json. Nếu None, dùng default
            cùng thư mục với file này.

    Raises:
        FileNotFoundError: file không tồn tại.
        ValueError: JSON parse fail hoặc schema sai.
    """
    if profiles_json_path is None:
        profiles_json_path = Path(__file__).parent / "profiles.json"

    if not profiles_json_path.exists():
        raise FileNotFoundError(
            f"profiles.json không tồn tại: {profiles_json_path}"
        )

    try:
        raw = profiles_json_path.read_text(encoding="utf-8")
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"profiles.json parse fail: {exc}"
        ) from exc

    if not isinstance(data, dict):
        raise ValueError("profiles.json root phải là object")

    if data.get("$schema") != "linear-profiles-v1":
        raise ValueError(
            f"profiles.json $schema phải là 'linear-profiles-v1', "
            f"nhận '{data.get('$schema')}'"
        )

    profiles = data.get("profiles")
    if not isinstance(profiles, dict) or not profiles:
        raise ValueError("profiles.json thiếu 'profiles' object hoặc rỗng")

    return data


def resolve_profile(
    skill_name: str,
    cli_profile: str | None = None,
    recommendation: dict[str, Any] | None = None,
    profiles_json_path: Path | None = None,
) -> str:
    """Xác định profile cuối cùng cho skill.

    Priority (cao → thấp):
        1. cli_profile: user chỉ định trực tiếp (--profile=deep)
        2. recommendation.profile: từ ISG hoặc previous skill
        3. DEFAULT_PROFILE ("standard")

    Sau resolve, validate profile hợp lệ.

    Args:
        skill_name: Tên skill đang chạy (vd: "wf-analyze-requirements").
        cli_profile: Profile từ CLI flag, None nếu không chỉ định.
        recommendation: Dict có thể chứa "profile" key từ upstream.
        profiles_json_path: Path đến profiles.json (None = default).

    Returns:
        Profile name đã xác định ("quick" | "standard" | "deep").

    Raises:
        ValueError: profile không hợp lệ.
    """
    # Ưu tiên CLI
    if cli_profile is not None:
        if cli_profile not in LINEAR_VALID_PROFILES:
            raise ValueError(
                f"resolve_profile: cli_profile='{cli_profile}' không hợp lệ "
                f"(cho phép: {sorted(LINEAR_VALID_PROFILES)})"
            )
        return cli_profile

    # Thử recommendation
    if recommendation is not None and isinstance(recommendation, dict):
        rec_profile = recommendation.get("profile")
        if isinstance(rec_profile, str) and rec_profile in LINEAR_VALID_PROFILES:
            return rec_profile

    # Default
    return DEFAULT_PROFILE


def get_depth_for_phase(
    profile: str,
    skill_name: str,
    phase_key: str | None = None,
    profiles_json_path: Path | None = None,
) -> str:
    """Tra depth_map cho profile + phase.

    Args:
        profile: "quick" | "standard" | "deep".
        skill_name: Tên skill (dùng để tra phase_key mặc định).
        phase_key: Key trong depth_map. None = tự detect từ skill_name.
        profiles_json_path: Path đến profiles.json (None = default).

    Returns:
        Depth value: "summary" | "stub" | "outline" | "wireframe" |
                     "full" | "deep"

    Raises:
        ValueError: profile không hợp lệ hoặc không tìm thấy trong profiles.json.
    """
    if profile not in LINEAR_VALID_PROFILES:
        raise ValueError(
            f"get_depth_for_phase: profile='{profile}' không hợp lệ "
            f"(cho phép: {sorted(LINEAR_VALID_PROFILES)})"
        )

    data = _load_profiles_data(profiles_json_path)
    profiles = data["profiles"]

    profile_config = profiles.get(profile)
    if not isinstance(profile_config, dict):
        raise ValueError(
            f"get_depth_for_phase: profile '{profile}' không có trong profiles.json"
        )

    depth_map = profile_config.get("depth_map", {})

    # Tự detect phase_key từ skill_name nếu không chỉ định
    if phase_key is None:
        phase_key = SKILL_PHASE_MAP.get(skill_name)
        if phase_key is None:
            return FALLBACK_DEPTH

    return depth_map.get(phase_key, FALLBACK_DEPTH)


def validate_safety_floor(
    profile: str,
    is_production: bool,
    profiles_json_path: Path | None = None,
) -> bool:
    """Enforce safety floor: production-bound PHẢI dùng standard hoặc deep.

    Args:
        profile: Profile đã resolve.
        is_production: True nếu dự án production-bound.
        profiles_json_path: Path đến profiles.json (None = default).

    Returns:
        True nếu pass safety floor.

    Raises:
        ValueError: safety floor violation — production dùng profile quá thấp.
    """
    if not is_production:
        return True

    data = _load_profiles_data(profiles_json_path)
    safety = data.get("safety_floor", {})
    applies_to = safety.get("applies_to", [])

    if profile in applies_to:
        return True

    raise ValueError(
        f"validate_safety_floor: dự án production-bound không được dùng "
        f"profile '{profile}'. Phải dùng một trong: {applies_to}. "
        f"Rule: {safety.get('rule', 'N/A')}"
    )


def estimate_time(
    profile: str,
    profiles_json_path: Path | None = None,
) -> int:
    """Ước lượng thời gian thực thi theo profile.

    Args:
        profile: "quick" | "standard" | "deep".
        profiles_json_path: Path đến profiles.json (None = default).

    Returns:
        Số phút ước lượng.

    Raises:
        ValueError: profile không hợp lệ.
    """
    if profile not in LINEAR_VALID_PROFILES:
        raise ValueError(
            f"estimate_time: profile='{profile}' không hợp lệ "
            f"(cho phép: {sorted(LINEAR_VALID_PROFILES)})"
        )

    data = _load_profiles_data(profiles_json_path)
    profiles = data["profiles"]

    profile_config = profiles.get(profile)
    if not isinstance(profile_config, dict):
        return 45  # fallback

    return profile_config.get("estimated_time_minutes", 45)


def get_max_parallel(
    profile: str,
    profiles_json_path: Path | None = None,
) -> int:
    """Lấy số lanes max parallel cho profile.

    Args:
        profile: "quick" | "standard" | "deep".
        profiles_json_path: Path đến profiles.json (None = default).

    Returns:
        Số lanes tối đa chạy song song.

    Raises:
        ValueError: profile không hợp lệ.
    """
    if profile not in LINEAR_VALID_PROFILES:
        raise ValueError(
            f"get_max_parallel: profile='{profile}' không hợp lệ "
            f"(cho phép: {sorted(LINEAR_VALID_PROFILES)})"
        )

    data = _load_profiles_data(profiles_json_path)
    profiles = data["profiles"]

    profile_config = profiles.get(profile)
    if not isinstance(profile_config, dict):
        return 3  # fallback

    return profile_config.get("lanes_max_parallel", 3)


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: resolve profile cho linear skill."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(
        description="Linear profile resolver — tra depth/time cho linear skills"
    )
    sub = parser.add_subparsers(dest="command")

    # resolve
    resolve_cmd = sub.add_parser("resolve", help="Resolve final profile")
    resolve_cmd.add_argument("--skill", required=True, help="Skill name")
    resolve_cmd.add_argument(
        "--profile",
        choices=sorted(LINEAR_VALID_PROFILES),
        default=None,
        help="CLI profile override",
    )
    resolve_cmd.add_argument(
        "--is-production",
        action="store_true",
        help="Enforce safety floor cho production projects",
    )

    # depth
    depth_cmd = sub.add_parser("depth", help="Get depth for phase")
    depth_cmd.add_argument("--skill", required=True, help="Skill name")
    depth_cmd.add_argument(
        "--profile",
        required=True,
        choices=sorted(LINEAR_VALID_PROFILES),
    )
    depth_cmd.add_argument("--phase-key", default=None, help="Phase key override")

    # time
    time_cmd = sub.add_parser("time", help="Estimate time")
    time_cmd.add_argument(
        "--profile",
        required=True,
        choices=sorted(LINEAR_VALID_PROFILES),
    )

    args = parser.parse_args(argv)

    try:
        if args.command == "resolve":
            profile = resolve_profile(args.skill, cli_profile=args.profile)
            validate_safety_floor(profile, args.is_production)
            print(profile)
            return 0

        if args.command == "depth":
            depth = get_depth_for_phase(args.profile, args.skill, args.phase_key)
            print(depth)
            return 0

        if args.command == "time":
            minutes = estimate_time(args.profile)
            print(minutes)
            return 0

        parser.print_help()
        return 1

    except (FileNotFoundError, ValueError) as exc:
        print(f"[profile_resolver ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
