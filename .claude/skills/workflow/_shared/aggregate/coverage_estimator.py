#!/usr/bin/env python3
"""coverage_estimator — Honest framing module cho wf-fix-bugs.

Phase A của Coverage Improvement Plan v8.

Compute coverage estimate dựa trên:
- Detected stack (TS/React, C#, Python, Go, Java, Vue, ...)
- Profile chosen (quick/standard/deep/exhaustive)
- Dimensions enabled
- Probe types invoked (static_only vs static+llm)

Output: coverage-estimate.json để report_generator.py populate fix-report.md.

Registry role: NONE — read-only consumer.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

__version__ = "1.1.0"

# Stack-aware base coverage matrix (cho static probes hiện tại).
# Phản ánh thực tế: skill thiết kế gốc cho C#, các stack khác cần stack-specific probes.
# Giá trị = % HIGH+MEDIUM bugs mà static probes có thể bắt trên stack đó.
STACK_STATIC_COVERAGE: Dict[str, int] = {
    "csharp-dotnet": 75,        # Skill design target — coverage cao nhất
    "typescript-react": 65,      # Sau patch v7.5.0 (react probe + i18n + TS business)
    "typescript-nextjs": 65,
    "javascript-react": 60,
    "vue": 35,                   # Chưa có Vue-specific probes
    "python-fastapi": 30,
    "python-django": 30,
    "go": 25,
    "java-spring": 30,
    "rust": 20,
    "unknown": 25,               # Fallback rất thận trọng
}

# Profile multiplier (probes chạy nhiều/ít).
PROFILE_MULTIPLIER: Dict[str, float] = {
    "quick": 0.40,
    "standard": 0.70,
    "deep": 1.00,
    "exhaustive": 1.15,    # Có thể vượt base nhờ probes opt-in
}

# Dimension weights cho 8 QDs (để biết mỗi dimension đóng góp coverage thế nào).
# Tổng = 1.0
DIMENSION_WEIGHTS: Dict[str, float] = {
    "QD1": 0.18,    # Functional Correctness
    "QD2": 0.16,    # Business Logic
    "QD3": 0.14,    # Security
    "QD4": 0.10,    # Performance
    "QD5": 0.14,    # UX/A11y
    "QD6": 0.12,    # Data Integrity
    "QD7": 0.08,    # Compatibility
    "QD8": 0.08,    # Observability & Reliability (added v8.2)
}

# LLM lane bonus — % cải thiện khi enable --llm-scan (ước tính).
LLM_BONUS_PCT: Dict[str, int] = {
    "deep": 15,        # +15% coverage trên integration/business edge cases
    "exhaustive": 20,  # +20% với coverage cao hơn
}

# QD9 Runtime Health (browser) bonus — % coverage từ browser probes theo profile.
# quick = 0% vì QD9 lane tự skip trong quick profile (no browser overhead).
QD9_RUNTIME_BONUS_PCT: Dict[str, int] = {
    "quick": 0,        # QD9 skips trong quick profile
    "standard": 5,     # 3 core probes: dev-server-bootstrap, console-network, auth-aware
    "deep": 8,         # +4 deep probes (Wave 1.5: feature-checklist, interactive, spa-route, form-validation)
    "exhaustive": 10,  # Tất cả QD9 probes bao gồm form-validation exhaustive
}

# Blind spots cố định mà static analysis KHÔNG thể bắt.
INHERENT_BLIND_SPOTS = [
    "Race conditions / concurrency bugs (cần runtime testing)",
    "Cross-component integration bugs (cần E2E test)",
    "Business-rule edge cases sâu (state machine inconsistencies)",
    "Subtle UX flow inconsistencies (cần manual review)",
    "Domain-specific compliance gaps (cần expert review)",
    "Performance regression dưới load (cần load test)",
]

# Confidence levels.
CONFIDENCE_HIGH = "high"
CONFIDENCE_MEDIUM = "medium"
CONFIDENCE_LOW = "low"


def _normalize_stack(stack: str | None) -> str:
    """Normalize stack identifier về key trong STACK_STATIC_COVERAGE."""
    if not stack:
        return "unknown"
    s = stack.lower().strip().replace("_", "-")
    # Aliases
    aliases = {
        "ts-react": "typescript-react",
        "ts-nextjs": "typescript-nextjs",
        "next": "typescript-nextjs",
        "nextjs": "typescript-nextjs",
        "csharp": "csharp-dotnet",
        "dotnet": "csharp-dotnet",
        ".net": "csharp-dotnet",
        "python": "python-fastapi",
        "fastapi": "python-fastapi",
        "django": "python-django",
        "java": "java-spring",
        "spring": "java-spring",
        "golang": "go",
    }
    return aliases.get(s, s if s in STACK_STATIC_COVERAGE else "unknown")


def _compute_dimension_coverage_pct(dimensions: List[str]) -> int:
    """Tính % weight được cover bởi dimensions enabled."""
    if not dimensions:
        return 0
    enabled_set = set(dimensions)
    weight_sum = sum(DIMENSION_WEIGHTS.get(d, 0) for d in enabled_set)
    return round(weight_sum * 100)


def _determine_confidence(stack: str, profile: str, llm_enabled: bool) -> str:
    """Confidence dựa trên stack-known + profile depth + LLM."""
    if stack == "unknown":
        return CONFIDENCE_LOW
    if profile == "quick":
        return CONFIDENCE_LOW
    if profile == "exhaustive" and llm_enabled:
        return CONFIDENCE_HIGH
    if profile in ("deep", "exhaustive"):
        return CONFIDENCE_MEDIUM if not llm_enabled else CONFIDENCE_HIGH
    return CONFIDENCE_MEDIUM


def _compute_runtime_pct(dimensions: List[str], profile: str) -> int:
    """Tính runtime coverage % từ QD9 browser probes.

    Trả về 0 nếu QD9 không trong dimensions (lane không chạy)
    hoặc profile=quick (QD9 tự skip trong quick mode).
    """
    if "QD9" not in dimensions:
        return 0
    return QD9_RUNTIME_BONUS_PCT.get(profile, 0)


def _build_recommendations(
    stack: str, profile: str, dimensions: List[str], llm_enabled: bool, current_pct: int
) -> List[str]:
    """Đề xuất cách tăng coverage."""
    recs: List[str] = []
    if profile != "exhaustive":
        next_profile = {"quick": "standard", "standard": "deep", "deep": "exhaustive"}[profile]
        recs.append(f"Chạy `--profile={next_profile}` để tăng độ sâu probe.")
    missing_dims = [d for d in DIMENSION_WEIGHTS if d not in dimensions]
    if missing_dims:
        recs.append(
            f"Thêm dimensions còn thiếu: {', '.join(missing_dims)} "
            f"(via `--dims=...`)."
        )
    if not llm_enabled and profile in ("deep", "exhaustive"):
        bonus = LLM_BONUS_PCT.get(profile, 15)
        recs.append(
            f"Bật `--llm-scan` để augment với LLM agents "
            f"(+~{bonus}% coverage trên integration/business edge cases, cost ~$0.50-1.50)."
        )
    if stack == "unknown":
        recs.append(
            "Stack không được detect — kết quả coverage có độ tin cậy THẤP. "
            "Kiểm tra package.json/requirements.txt/*.csproj để stack_detector hoạt động."
        )
    if current_pct < 50:
        recs.append(
            "Coverage hiện ở mức THẤP. KHÔNG nên tin tưởng \"fix xong là sạch\" — "
            "cần manual review + runtime testing."
        )
    return recs


def estimate_coverage(
    stack: str | None,
    profile: str,
    dimensions: List[str],
    llm_enabled: bool = False,
    *,
    interface_type: str | None = None,
    custom_blind_spots: List[str] | None = None,
) -> Dict[str, Any]:
    """Compute coverage estimate.

    Args:
        stack: Detected primary stack (e.g., "typescript-react", "csharp-dotnet").
        profile: One of "quick", "standard", "deep", "exhaustive".
        dimensions: List of QD codes enabled (e.g., ["QD1", "QD2", ...]).
        llm_enabled: Whether --llm-scan was opted in.
        interface_type: Registry interface_type ("api-only" | "web" | "mobile" | ...).
            Dùng để quyết định runtime_warn — khi None, warn chỉ khi QD9 explicitly skip.
        custom_blind_spots: Optional additional blind spots beyond inherent list.

    Returns:
        Dict with static_pct, runtime_pct, coverage_estimate_pct, runtime_warn,
        confidence, blind_spots, recommendations.
    """
    norm_stack = _normalize_stack(stack)
    base = STACK_STATIC_COVERAGE.get(norm_stack, STACK_STATIC_COVERAGE["unknown"])
    multiplier = PROFILE_MULTIPLIER.get(profile, 0.70)
    # dim_coverage chỉ tính QD1-QD8 (static dimensions) — QD9 không có trong DIMENSION_WEIGHTS
    dim_coverage = _compute_dimension_coverage_pct(dimensions)

    # Static probe coverage estimate (QD1-QD8 only)
    # base * multiplier * (dim_coverage / 100) — clamped to [0, 100]
    static_pct = round(base * multiplier * (dim_coverage / 100))

    # Runtime coverage bonus từ QD9 browser probes
    runtime_pct = _compute_runtime_pct(dimensions, profile)

    # LLM bonus
    llm_bonus = 0
    if llm_enabled:
        llm_bonus = LLM_BONUS_PCT.get(profile, 0)

    # Total: static + runtime + llm, capped at 95% — không bao giờ tuyên bố 100%
    final_pct = min(static_pct + runtime_pct + llm_bonus, 95)

    # runtime_warn: True khi runtime_pct=0 trên UI project (không phải api-only)
    # Giúp orchestrator-summary hiển thị WARN nếu QD9 bị skip trên UI project.
    runtime_warn = runtime_pct == 0 and interface_type not in (None, "api-only")

    blind_spots = list(INHERENT_BLIND_SPOTS)
    if custom_blind_spots:
        blind_spots.extend(custom_blind_spots)
    if norm_stack == "unknown":
        blind_spots.insert(0, "Stack không xác định — probes phù hợp không được dispatch")

    confidence = _determine_confidence(norm_stack, profile, llm_enabled)
    recommendations = _build_recommendations(
        norm_stack, profile, dimensions, llm_enabled, final_pct
    )
    if runtime_warn:
        recommendations.insert(
            0,
            "⚠️ Runtime coverage = 0% — QD9 skip hoặc BASE_URL không có. "
            "Chạy không có `--no-browser` để bật browser probes và tăng coverage.",
        )

    return {
        "schema": "coverage-estimate-v1",
        "stack": norm_stack,
        "profile": profile,
        "dimensions_enabled": list(dimensions),
        "dimensions_count": len(dimensions),
        "llm_scan_enabled": llm_enabled,
        "components": {
            "stack_base_pct": base,
            "profile_multiplier": multiplier,
            "dimension_coverage_pct": dim_coverage,
            "static_estimate_pct": static_pct,
            "runtime_bonus_pct": runtime_pct,
            "llm_bonus_pct": llm_bonus,
        },
        "static_pct": static_pct,
        "runtime_pct": runtime_pct,
        "runtime_warn": runtime_warn,
        "coverage_estimate_pct": final_pct,
        "confidence": confidence,
        "blind_spots": blind_spots,
        "recommendations": recommendations,
        "disclaimer": (
            "Đây là ƯỚC TÍNH — KHÔNG đảm bảo. Static analysis có giới hạn lý thuyết. "
            "Coverage thật phụ thuộc bug nature, code quality, và domain complexity."
        ),
        "version": __version__,
    }


def load_session_inputs(session_dir: Path) -> Tuple[str | None, str, List[str], bool]:
    """Đọc fix-status.json + (optional) stack-info.json từ session để feed estimator.

    Returns: (stack, profile, dimensions, llm_enabled).
    """
    fix_status_path = session_dir / "fix-status.json"
    if not fix_status_path.exists():
        raise FileNotFoundError(f"fix-status.json không tồn tại: {fix_status_path}")
    with fix_status_path.open("r", encoding="utf-8") as f:
        fix_status = json.load(f)

    profile = fix_status.get("profile_used", "standard")
    dimensions = fix_status.get("dimensions_resolved", [])
    flags = fix_status.get("flags", {}) or {}
    llm_enabled = bool(flags.get("llm_scan", False))

    # Optional stack-info.json (tạo bởi stack_detector ở Phase B)
    stack_info_path = session_dir / "stack-info.json"
    stack: str | None = None
    if stack_info_path.exists():
        try:
            with stack_info_path.open("r", encoding="utf-8") as f:
                stack_info = json.load(f)
            stack = stack_info.get("primary_stack")
        except (json.JSONDecodeError, OSError):
            stack = None

    return stack, profile, dimensions, llm_enabled


def load_session_interface_type(session_dir: Path) -> str | None:
    """Đọc interface_type từ fix-status.json của session.

    Returns None nếu không có hoặc không đọc được.
    """
    fix_status_path = session_dir / "fix-status.json"
    if not fix_status_path.exists():
        return None
    try:
        with fix_status_path.open("r", encoding="utf-8") as f:
            fix_status = json.load(f)
        return fix_status.get("interface_type") or None
    except (json.JSONDecodeError, OSError):
        return None


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Compute coverage estimate cho wf-fix-bugs session."
    )
    parser.add_argument("--session", required=True, help="Đường dẫn session directory.")
    parser.add_argument("--output", help="Output file path (default: $session/coverage-estimate.json).")
    parser.add_argument("--stack", help="Override detected stack.")
    parser.add_argument("--profile", help="Override profile.")
    parser.add_argument("--dims", help="Override dimensions (comma-separated).")
    parser.add_argument("--llm-scan", action="store_true", help="Mark LLM scan as enabled.")
    parser.add_argument("--interface-type", help="Override interface_type (api-only|web|mobile|...).")
    parser.add_argument("--print", action="store_true", help="Print result to stdout.")
    args = parser.parse_args(argv)

    session_dir = Path(args.session)
    if not session_dir.is_dir():
        print(f"ERROR: session directory không tồn tại: {session_dir}", file=sys.stderr)
        return 2

    try:
        s_stack, s_profile, s_dims, s_llm = load_session_inputs(session_dir)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 3

    stack = args.stack or s_stack
    profile = args.profile or s_profile
    dimensions = args.dims.split(",") if args.dims else s_dims
    llm_enabled = args.llm_scan or s_llm
    interface_type = getattr(args, "interface_type", None) or load_session_interface_type(session_dir)

    estimate = estimate_coverage(
        stack=stack,
        profile=profile,
        dimensions=[d.strip() for d in dimensions],
        llm_enabled=llm_enabled,
        interface_type=interface_type,
    )

    output_path = Path(args.output) if args.output else session_dir / "coverage-estimate.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
        json.dump(estimate, f, indent=2, ensure_ascii=False, sort_keys=True)

    if args.print:
        # Use ensure_ascii=True for stdout safety on Windows (cp1252 codec).
        # JSON file output above retains UTF-8 with ensure_ascii=False.
        try:
            sys.stdout.reconfigure(encoding="utf-8")
        except (AttributeError, OSError):
            pass
        try:
            print(json.dumps(estimate, indent=2, ensure_ascii=False))
        except UnicodeEncodeError:
            print(json.dumps(estimate, indent=2, ensure_ascii=True))
    else:
        print(f"Coverage estimate: {estimate['coverage_estimate_pct']}% "
              f"({estimate['confidence']} confidence) -> {output_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
