#!/usr/bin/env python3
"""dimension_registry.py — Central registry ánh xạ dimension → lane directory + agents + cache policy.

Vai trò:
    Cung cấp lookup nhanh từ dimension ID (QD1-QD11) → lane path, agents,
    cache policy. Dùng bởi lane_dispatch.py, workload_estimator, ISG recommender.

Registry role: NONE. Chỉ cung cấp lookup, không ghi.

Tham chiếu:
    - ADR-02: utility module
    - ADR-22 rule 6: QD3 KHÔNG BAO GIỜ cache
    - Stage E2 spec: docs/design/skills/wf-fix-bugs/prompts/stage-E-prompt.md
"""
from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class DimensionConfig:
    """Cấu hình cho 1 dimension lane."""

    dim: str
    lane: str
    agents: list[str]
    cache_allowed: bool


# ──────────────────────────────────────────────────────────────────────
# Registry — ADR-22 rule 6: QD3 cache_allowed=False
# ──────────────────────────────────────────────────────────────────────

DIMENSION_REGISTRY: dict[str, DimensionConfig] = {
    "QD1": DimensionConfig(
        dim="QD1",
        lane="wf-fix-functional",
        agents=[],
        cache_allowed=True,
    ),
    "QD2": DimensionConfig(
        dim="QD2",
        lane="wf-fix-business",
        agents=["business-analyst"],
        cache_allowed=True,
    ),
    "QD3": DimensionConfig(
        dim="QD3",
        lane="wf-fix-security",
        agents=["security"],
        cache_allowed=False,  # ADR-22 Rule 6
    ),
    "QD4": DimensionConfig(
        dim="QD4",
        lane="wf-fix-performance",
        agents=["performance-benchmarker"],
        cache_allowed=True,
    ),
    "QD5": DimensionConfig(
        dim="QD5",
        lane="wf-fix-ux-a11y",
        agents=["ux-researcher", "accessibility-auditor"],
        cache_allowed=True,
    ),
    "QD6": DimensionConfig(
        dim="QD6",
        lane="wf-fix-data",
        agents=["dba", "data-engineer"],
        cache_allowed=True,
    ),
    "QD7": DimensionConfig(
        dim="QD7",
        lane="wf-fix-compat",
        agents=["frontend-developer", "mobile-developer"],
        cache_allowed=True,
    ),
    "QD8": DimensionConfig(
        dim="QD8",
        lane="wf-fix-observability",
        agents=["sre", "devops"],
        cache_allowed=True,
    ),
    # v9.0: QD9 Runtime Health Verification (browser-based probes)
    "QD9": DimensionConfig(
        dim="QD9",
        lane="wf-fix-runtime-health",
        agents=["qa-lead", "frontend-developer"],
        cache_allowed=False,  # Runtime probes: always re-run (browser state changes)
    ),
    # v9.0: QD10 Cross-Module Integration (static + runtime)
    "QD10": DimensionConfig(
        dim="QD10",
        lane="wf-fix-integration",
        agents=["architect", "data-engineer"],
        cache_allowed=True,
    ),
    # v9.1: QD11 Business Completeness & Enhancement (LLM-only, 3-pass)
    "QD11": DimensionConfig(
        dim="QD11",
        lane="wf-fix-business-completeness",
        agents=["business-analyst", "architect"],
        cache_allowed=False,  # LLM probes: always re-run for fresh analysis
    ),
}

_VALID_DIMS = frozenset(DIMENSION_REGISTRY.keys())


# ──────────────────────────────────────────────────────────────────────
# Public functions
# ──────────────────────────────────────────────────────────────────────


def get_lane_path(dim: str, workflow_root: Path) -> Path:
    """Trả về đường dẫn tuyệt đối đến lane directory.

    Args:
        dim: Dimension ID (vd: "QD3").
        workflow_root: Root của workflow skills (vd: .claude/skills/workflow/).

    Returns:
        Absolute path đến lane directory.

    Raises:
        ValueError: dim không hợp lệ.
    """
    config = _get_config(dim)
    return workflow_root / config.lane


# F06.005 (Sprint 6 v10.3): Canonical lookup dim→lane name.
# Replaces hardcoded dicts trong signal_aggregator._normalize_probe_signal +
# các call sites khác. Dùng làm SSOT để tránh drift khi thêm/đổi dimensions.
_DEFAULT_LANE_FALLBACK = "wf-fix-functional"


def get_lane_name(dim: str | None, default: str | None = None) -> str:
    """Trả về lane skill name (vd: 'wf-fix-functional') cho dim ID.

    Khác `get_lane_path` (cần workflow_root), hàm này chỉ trả về tên lane
    để dùng trong signal payload / log / non-filesystem context.

    Args:
        dim: Dimension ID (vd: "QD3"). None hoặc invalid → trả default.
        default: Fallback nếu dim không hợp lệ. Mặc định "wf-fix-functional".

    Returns:
        Lane skill name (canonical từ DIMENSION_REGISTRY).
    """
    if not dim:
        return default if default is not None else _DEFAULT_LANE_FALLBACK
    config = DIMENSION_REGISTRY.get(dim)
    if config is None:
        return default if default is not None else _DEFAULT_LANE_FALLBACK
    return config.lane


def get_all_dimensions() -> list[str]:
    """Trả về ['QD1', 'QD2', ..., 'QD11'] theo thứ tự."""
    return sorted(_VALID_DIMS)


def validate_lane_exists(dim: str, workflow_root: Path) -> bool:
    """Check lane directory + dimension.json tồn tại.

    Args:
        dim: Dimension ID.
        workflow_root: Root của workflow skills.

    Returns:
        True nếu lane dir + dimension.json đều tồn tại.

    Raises:
        ValueError: dim không hợp lệ.
    """
    config = _get_config(dim)
    lane_path = workflow_root / config.lane
    if not lane_path.is_dir():
        return False
    dim_json = lane_path / "dimension.json"
    return dim_json.is_file()


def get_cache_policy(dim: str) -> bool:
    """Trả về True nếu dimension cho phép cache, False nếu không.

    ADR-22 Rule 6: QD3 luôn trả về False.

    Args:
        dim: Dimension ID.

    Returns:
        True nếu cache_allowed, False nếu không.

    Raises:
        ValueError: dim không hợp lệ.
    """
    config = _get_config(dim)
    return config.cache_allowed


def get_agents(dim: str) -> list[str]:
    """Trả về danh sách agents cho dimension.

    Args:
        dim: Dimension ID.

    Returns:
        List of agent type strings.

    Raises:
        ValueError: dim không hợp lệ.
    """
    config = _get_config(dim)
    return list(config.agents)


def _get_config(dim: str) -> DimensionConfig:
    """Lookup dimension config, raise ValueError nếu không hợp lệ."""
    config = DIMENSION_REGISTRY.get(dim)
    if config is None:
        raise ValueError(
            f"dimension_registry: dim='{dim}' không hợp lệ "
            f"(cho phép: {sorted(_VALID_DIMS)})"
        )
    return config


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: query dimension registry."""
    import argparse

    parser = argparse.ArgumentParser(description="Dimension Registry query")
    parser.add_argument("--dim", required=True, help="Dimension ID (QD1-QD11)")
    parser.add_argument(
        "--workflow-root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Root của workflow skills",
    )
    sub = parser.add_mutually_exclusive_group(required=True)
    sub.add_argument("--lane-path", action="store_true", help="Print lane path")
    sub.add_argument("--cache-policy", action="store_true", help="Print cache policy")
    sub.add_argument(
        "--validate", action="store_true", help="Validate lane exists"
    )
    sub.add_argument("--agents", action="store_true", help="Print agents")
    args = parser.parse_args(argv)

    try:
        if args.lane_path:
            print(get_lane_path(args.dim, args.workflow_root))
        elif args.cache_policy:
            print(get_cache_policy(args.dim))
        elif args.validate:
            print(validate_lane_exists(args.dim, args.workflow_root))
        elif args.agents:
            print(", ".join(get_agents(args.dim)))
        return 0
    except ValueError as exc:
        print(f"[dimension_registry ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
