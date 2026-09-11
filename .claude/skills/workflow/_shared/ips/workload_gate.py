"""Workload Gate — Phase F Task F.5.

Detect conditions khi workload qua lon va tra ve WARN + 3 options:
- continue-as-is
- downgrade-profile
- abort

**v5.0 scope (v2.1):** Detect + WARN only. KHONG sinh fix-workload.json —
Partition Planner defer v5.1.

Thresholds theo `09-thresholds-justification.md §2.5`:
| Trigger | v2.1 value | Env var |
|---------|-----------|---------|
| estimated_time > X × profile.budget | 1.5 | LEGACY_SCAN_WORKLOAD_TIME_RATIO |
| total_features_est > N | 100 | — |
| largest_module_files > N | 40 (v2.1 lowered) | LEGACY_SCAN_WORKLOAD_LARGEST_MOD |
| modules_count > N | 30 | — |
| total_files > N AND profile ∈ {deep, exhaustive} | 1,000 | — |

Reference:
- docs/design/skills/wf-legacy-scan/05-profiles-ips.md §4
- docs/design/skills/wf-legacy-scan/09-thresholds-justification.md §2.5
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Any


# ---------------------------------------------------------------------------
# Constants + env override
# ---------------------------------------------------------------------------

DEFAULT_TIME_RATIO_TRIGGER = 1.5
DEFAULT_FEATURES_TRIGGER = 100
DEFAULT_LARGEST_MODULE_FILES = 40
DEFAULT_MODULES_COUNT_TRIGGER = 30
DEFAULT_TOTAL_FILES_TRIGGER = 1_000

# Profile downgrade map — 3 options plan
PROFILE_DOWNGRADE_MAP: dict[str, str] = {
    "exhaustive": "deep",
    "deep": "standard",
    "standard": "surface",
    "surface": "surface",  # no further downgrade
}

# Valid user choices
OPTION_CONTINUE = "continue-as-is"
OPTION_DOWNGRADE = "downgrade-profile"
OPTION_ABORT = "abort"
VALID_OPTIONS: tuple[str, ...] = (OPTION_CONTINUE, OPTION_DOWNGRADE, OPTION_ABORT)


def _read_env_float(name: str, default: float) -> float:
    raw = os.environ.get(name)
    if not raw:
        return default
    try:
        v = float(raw)
        if v > 0:
            return v
    except (TypeError, ValueError):
        pass
    return default


def _read_env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if not raw:
        return default
    try:
        v = int(raw)
        if v > 0:
            return v
    except (TypeError, ValueError):
        pass
    return default


def time_ratio_trigger() -> float:
    return _read_env_float("LEGACY_SCAN_WORKLOAD_TIME_RATIO", DEFAULT_TIME_RATIO_TRIGGER)


def largest_module_trigger() -> int:
    return _read_env_int("LEGACY_SCAN_WORKLOAD_LARGEST_MOD", DEFAULT_LARGEST_MODULE_FILES)


# ---------------------------------------------------------------------------
# Data class
# ---------------------------------------------------------------------------


@dataclass
class GateResult:
    """Ket qua cua Workload Gate check."""

    triggered: bool
    profile: str
    triggers: list[str] = field(default_factory=list)
    time_ratio: float = 0.0
    estimated_time_min: int = 0
    profile_budget_min: int = 0
    total_features_est: int = 0
    modules_count: int = 0
    largest_module_files: int = 0
    total_files: int = 0
    recommended_downgrade: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "triggered": self.triggered,
            "profile": self.profile,
            "triggers": list(self.triggers),
            "time_ratio": round(self.time_ratio, 2),
            "estimated_time_min": self.estimated_time_min,
            "profile_budget_min": self.profile_budget_min,
            "total_features_est": self.total_features_est,
            "modules_count": self.modules_count,
            "largest_module_files": self.largest_module_files,
            "total_files": self.total_files,
            "recommended_downgrade": self.recommended_downgrade,
        }


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def check_workload_gate(
    workload_estimate: dict[str, Any],
    *,
    profile: str,
    modules_count: int | None = None,
    largest_module_files: int | None = None,
    total_files: int | None = None,
    time_ratio_override: float | None = None,
    largest_module_override: int | None = None,
) -> GateResult:
    """Check xem co can trigger Workload Gate khong.

    Args:
        workload_estimate: Output cua `workload_estimator.estimate_workload()`:
            { total_features_est, est_time_min, budget_min, exceeds_cap, ratio,
              module_count }.
        profile: Profile hien tai (surface / standard / deep / exhaustive).
        modules_count: So modules — neu None, doc tu workload_estimate.module_count.
        largest_module_files: So file lon nhat trong 1 module (tu inventory).
        total_files: Tong so file (tu inventory).

    Returns:
        GateResult — neu `.triggered == True`, orchestrator phai show UI +
        AskUserQuestion CDG.
    """
    if not isinstance(workload_estimate, dict):
        raise TypeError("workload_estimate phai la dict")

    time_ratio_th = time_ratio_override if time_ratio_override is not None else time_ratio_trigger()
    largest_mod_th = largest_module_override if largest_module_override is not None else largest_module_trigger()

    est_time = int(workload_estimate.get("est_time_min") or 0)
    budget = int(workload_estimate.get("budget_min") or 0)
    features_est = int(workload_estimate.get("total_features_est") or 0)
    actual_modules = int(
        modules_count if modules_count is not None else (workload_estimate.get("module_count") or 0)
    )
    largest = int(largest_module_files or 0)
    total_f = int(total_files or 0)

    time_ratio = (est_time / budget) if budget > 0 else 0.0

    triggers: list[str] = []

    # Trigger 1: estimated_time > ratio × budget
    if budget > 0 and time_ratio > time_ratio_th:
        triggers.append(
            f"Time estimate {est_time} min vuot {time_ratio_th}x budget {budget} min "
            f"(ratio={time_ratio:.2f}x)"
        )

    # Trigger 2: total_features_est > 100
    if features_est > DEFAULT_FEATURES_TRIGGER:
        triggers.append(
            f"{features_est} features dự kiến (> {DEFAULT_FEATURES_TRIGGER})"
        )

    # Trigger 3: largest_module_files > 40
    if largest > largest_mod_th:
        triggers.append(
            f"Module lớn nhất {largest} files (> {largest_mod_th}) — co the bao hoa agent context"
        )

    # Trigger 4: modules_count > 30
    if actual_modules > DEFAULT_MODULES_COUNT_TRIGGER:
        triggers.append(
            f"{actual_modules} modules (> {DEFAULT_MODULES_COUNT_TRIGGER})"
        )

    # Trigger 5: total_files > 1000 AND profile in {deep, exhaustive}
    if total_f > DEFAULT_TOTAL_FILES_TRIGGER and profile in ("deep", "exhaustive"):
        triggers.append(
            f"{total_f} files tong (> {DEFAULT_TOTAL_FILES_TRIGGER}) voi profile={profile}"
        )

    triggered = bool(triggers)
    downgrade = PROFILE_DOWNGRADE_MAP.get(profile) if triggered else None

    return GateResult(
        triggered=triggered,
        profile=profile,
        triggers=triggers,
        time_ratio=time_ratio,
        estimated_time_min=est_time,
        profile_budget_min=budget,
        total_features_est=features_est,
        modules_count=actual_modules,
        largest_module_files=largest,
        total_files=total_f,
        recommended_downgrade=downgrade,
    )


def format_warn_message(result: GateResult) -> str:
    """Format WARN message text — consumed by SKILL.md display hook.

    Khong tao AskUserQuestion — orchestrator lam via Claude tool. Chi format
    text se hien.
    """
    if not result.triggered:
        return "Workload within expected budget — no gate triggered."

    lines = [
        "⚠️  Workload lớn phát hiện (Phase 1 inventory + IPS-B)",
        "",
    ]
    if result.estimated_time_min and result.profile_budget_min:
        lines.append(
            f"Ước tính: {result.estimated_time_min} phút × profile={result.profile} "
            f"(budget {result.profile_budget_min} phút — ratio {result.time_ratio:.2f}x)"
        )
    lines.append(f"Features dự kiến: {result.total_features_est}")
    lines.append(f"Modules: {result.modules_count}")
    if result.largest_module_files:
        lines.append(f"Module lớn nhất: {result.largest_module_files} files")
    lines.append("")
    lines.append("Điều kiện vượt threshold:")
    for t in result.triggers:
        lines.append(f"  - {t}")
    lines.append("")
    lines.append("Chọn:")
    lines.append(f"  [A] {OPTION_CONTINUE} — Ghi WARN vào log, giữ profile={result.profile}, tiếp tục")
    if result.recommended_downgrade and result.recommended_downgrade != result.profile:
        lines.append(
            f"  [B] {OPTION_DOWNGRADE} — Đổi profile {result.profile} → {result.recommended_downgrade} (giảm time/features)"
        )
    else:
        lines.append(
            f"  [B] {OPTION_DOWNGRADE} — (không thể downgrade tu {result.profile}) — A hoặc C only"
        )
    lines.append(f"  [C] {OPTION_ABORT} — STOP scan, user thu hẹp phạm vi rồi chạy lại")
    return "\n".join(lines)


def apply_user_choice(choice: str, result: GateResult) -> dict[str, Any]:
    """Ap dung lua chon cua user — tra ve action instruction.

    Returns:
        {
          "action": "continue" | "downgrade" | "abort",
          "new_profile": str | None,
          "log_level": "warn" | "info",
          "message": str,
        }
    """
    if choice not in VALID_OPTIONS:
        raise ValueError(f"choice must be one of {VALID_OPTIONS}, got {choice!r}")

    if choice == OPTION_CONTINUE:
        return {
            "action": "continue",
            "new_profile": result.profile,
            "log_level": "warn",
            "message": f"User chose continue-as-is. Scanning với profile={result.profile} despite workload warning.",
        }

    if choice == OPTION_DOWNGRADE:
        target = result.recommended_downgrade or result.profile
        if target == result.profile:
            return {
                "action": "continue",
                "new_profile": result.profile,
                "log_level": "warn",
                "message": (
                    f"Khong the downgrade tu '{result.profile}' — keeping current profile. "
                    "User co the abort + retry voi profile nho hon."
                ),
            }
        return {
            "action": "downgrade",
            "new_profile": target,
            "log_level": "info",
            "message": (
                f"User chose downgrade-profile: {result.profile} → {target}. "
                "Re-building depth_map + synthesis_mode."
            ),
        }

    # abort
    return {
        "action": "abort",
        "new_profile": None,
        "log_level": "warn",
        "message": (
            "User chose abort. Scan STOPPED. "
            "Suggest: narrow --layers, filter project path, or explicit smaller --profile."
        ),
    }


__all__ = [
    "DEFAULT_TIME_RATIO_TRIGGER",
    "DEFAULT_FEATURES_TRIGGER",
    "DEFAULT_LARGEST_MODULE_FILES",
    "DEFAULT_MODULES_COUNT_TRIGGER",
    "DEFAULT_TOTAL_FILES_TRIGGER",
    "PROFILE_DOWNGRADE_MAP",
    "OPTION_CONTINUE",
    "OPTION_DOWNGRADE",
    "OPTION_ABORT",
    "VALID_OPTIONS",
    "GateResult",
    "check_workload_gate",
    "format_warn_message",
    "apply_user_choice",
    "time_ratio_trigger",
    "largest_module_trigger",
]
