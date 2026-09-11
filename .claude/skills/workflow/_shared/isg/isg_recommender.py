#!/usr/bin/env python3
"""isg_recommender.py — Interactive Selection Gate — recommendation + enforcement.

Vai trò (B2 full implementation):
    Phân tích tín hiệu (git diff, preflight, registry, domain) → đề xuất QD nào
    nên được chọn. Render markdown checklist. Enforce safety floor ADR-22 rule 1.
    Emit dim-selection.json.

Registry role: NONE. Module này chỉ ĐỌC req-registry.json, không ghi.

Tham chiếu:
    - ADR-14: ISG design
    - ADR-22 rule 1: safety floor QD1+QD2+QD5 cho profile ≥ standard
    - CORE-027: Critical Decision Gate
    - docs/design/skills/wf-fix-bugs/08-user-scenarios-solutions.md §3
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# Reconfigure stdout/stderr to UTF-8 — required on Windows where default cp1252
# fails on Vietnamese diacritics in ensure_ascii=False JSON output.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, ValueError):
        pass

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

DIMENSIONS: tuple[str, ...] = (
    "QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11",
)

DIM_NAMES: dict[str, str] = {
    "QD1": "Functional Correctness (Đúng chức năng)",
    "QD2": "Business Correctness (Đúng nghiệp vụ)",
    "QD3": "Security & Privacy (An toàn & Riêng tư)",
    "QD4": "Performance & Efficiency (Hiệu năng)",
    "QD5": "Accessibility & UX (Khả dụng & Trải nghiệm)",
    "QD6": "Data Integrity & Resilience (Toàn vẹn dữ liệu)",
    "QD7": "Compatibility & Portability (Tương thích)",
    "QD8": "Observability & Reliability (Quan sát & Độ tin cậy)",
    "QD9": "Runtime Health (Sức khỏe runtime)",
    "QD10": "Cross-Module Integration (Tích hợp liên module)",
    "QD11": "Business Completeness & Enhancement (Đầy đủ nghiệp vụ & Nâng cao)",
}

DEFAULT_PROFILE_DIMS: dict[str, list[str]] = {
    "quick": ["QD1", "QD5"],
    "standard": ["QD1", "QD2", "QD5", "QD9", "QD10"],
    "deep": ["QD1", "QD2", "QD5", "QD6", "QD3", "QD9", "QD10", "QD11"],
    "exhaustive": list(DIMENSIONS),
}

VALID_PROFILES: frozenset[str] = frozenset(DEFAULT_PROFILE_DIMS.keys())

# ADR-22 rule 1: profile ≥ standard không được bỏ toàn bộ 3 chiều floor
SAFETY_FLOOR_DIMS: frozenset[str] = frozenset({"QD1", "QD2", "QD5"})
SAFETY_FLOOR_PROFILES: frozenset[str] = frozenset({"standard", "deep", "exhaustive"})

# Domain → QD strong hints (xem README §4.3)
DOMAIN_DIM_HINTS: dict[str, tuple[str, ...]] = {
    "finance": ("QD2",),
    "accounting": ("QD2",),
    "healthcare": ("QD2", "QD3", "QD6"),
    "medical": ("QD2", "QD3", "QD6"),
    "logistics": ("QD2", "QD6"),
    "shipping": ("QD2", "QD6"),
    "legal": ("QD2", "QD3"),
    "hr": ("QD2", "QD3"),
    "payroll": ("QD2", "QD3"),
    "ecommerce": ("QD2", "QD3", "QD6"),
    "retail": ("QD2", "QD6"),
    "procurement": ("QD2",),
    "manufacturing": ("QD2", "QD6"),
}

# Git diff path heuristics → QD strength
# Key: regex pattern (case-insensitive), Value: list[(dim, strength)]
DIFF_PATTERN_TO_DIMS: list[tuple[str, list[tuple[str, str]]]] = [
    # Services → Functional + Data integrity
    (r".*\.service\.(ts|tsx|js|jsx|py)$", [("QD1", "strong"), ("QD6", "strong")]),
    # Controllers → Functional correctness
    (r".*\.controller\.(ts|tsx|js|jsx|py)$", [("QD1", "strong")]),
    # Auth paths → Security + Observability (CDG-RELIABILITY-RISK on auth retry)
    (r".*(auth|authn|authz|login|session|jwt|token)[/\\.].*", [("QD3", "strong"), ("QD8", "weak")]),
    # Payment / billing / checkout → Security + Observability + Data integrity
    # Per CLAUDE.md: CDG-RELIABILITY-RISK trên payment/auth retry-without-CB → QD8 phải fire.
    (r".*(payment|billing|checkout|invoice|transaction|order|cart)[/\\.].*", [("QD3", "strong"), ("QD8", "strong"), ("QD6", "strong")]),
    # UI components → Accessibility
    (
        r".*\.(component|page|screen|view)\.(tsx|jsx|vue|svelte)$",
        [("QD5", "strong")],
    ),
    # Generic UI/components folder
    (r".*(components|pages|screens|ui)[/\\].*", [("QD5", "weak")]),
    # Migrations → Data integrity
    (r".*(migrations|migrate|schema)[/\\].*", [("QD6", "strong")]),
    # Repositories / DB ops
    (r".*\.(repository|entity|model|dao)\.(ts|js|py)$", [("QD6", "strong")]),
    # Performance / cache / worker
    (r".*(perf|performance|cache|worker|queue)[/\\].*", [("QD4", "weak")]),
    # Query builders
    (r".*(query|builder)\.(ts|js|py)$", [("QD4", "weak")]),
    # Config / compat surfaces
    (r".*(\.env|dockerfile|docker-compose|package\.json|requirements\.txt)$", [("QD7", "weak")]),
    # Observability / SRE — logs, metrics, traces, alerts, retry/circuit-breaker, health-check
    (r".*(logger|logging|tracer|tracing|metrics|prometheus|grafana|alert|alarm)[/\\.].*", [("QD8", "strong")]),
    (r".*(retry|circuit.?breaker|resilience|hystrix|polly|opossum)[/\\.].*", [("QD8", "strong")]),
    (r".*(health|healthz|readiness|liveness)[/\\.].*", [("QD8", "weak")]),
    # Deploy/infra config (k8s, terraform) thuong chua reliability config
    (r".*(\.k8s|kubernetes|helm|terraform|deployment\.ya?ml)[/\\.].*", [("QD8", "weak"), ("QD7", "weak")]),
    # Cross-module / shared code → QD11 completeness analysis
    (r".*(shared|common|core|utils|libs?|packages?)[/\\.].*", [("QD11", "weak")]),
    # Registry / dependencies config change → QD11 registry gap
    (r".*(req-registry\.json|package\.json|requirements\.txt|Cargo\.toml|go\.mod)[/\\.].*", [("QD11", "weak")]),
]

DIFF_MANY_FILES_THRESHOLD: int = 30  # > threshold → QD7 weak

# Preflight severity parsing
PREFLIGHT_CRITICAL_PATTERN = re.compile(r"(?i)^\s*(?:[-*]\s*)?(?:\*\*)?critical(?:\*\*)?", re.MULTILINE)
PREFLIGHT_WARN_PATTERN = re.compile(r"(?i)^\s*(?:[-*]\s*)?(?:\*\*)?warn(?:ing)?(?:\*\*)?", re.MULTILINE)
PREFLIGHT_SECURITY_SECTION = re.compile(r"(?i)##+\s*(security|bảo mật|an toàn)")
PREFLIGHT_PERF_SECTION = re.compile(r"(?i)##+\s*(performance|hiệu năng)")

# CDG tokens user phải gõ để override (CORE-027)
CDG_TOKEN_OVERRIDE_QD1: str = "override-qd1"
CDG_TOKEN_SKIP_QD3: str = "confirm-skip-qd3"

# Stage E4: Dimension scoring weights cho v6 engine
# Dùng để rank dimensions khi recommend — file type hints + project context boost
DIMENSION_SCORES: dict[str, dict[str, float]] = {
    "QD1": {"base_weight": 1.0, "security_boost": 0.0, "perf_boost": 0.0},
    "QD2": {"base_weight": 1.2, "security_boost": 0.0, "perf_boost": 0.0},
    "QD3": {"base_weight": 1.5, "security_boost": 2.0, "perf_boost": 0.0},
    "QD4": {"base_weight": 1.0, "security_boost": 0.0, "perf_boost": 1.5},
    "QD5": {"base_weight": 1.3, "security_boost": 0.0, "perf_boost": 0.0},
    "QD6": {"base_weight": 0.8, "security_boost": 0.0, "perf_boost": 0.0},
    "QD7": {"base_weight": 1.1, "security_boost": 0.0, "perf_boost": 0.5},
    "QD8": {"base_weight": 0.9, "security_boost": 0.5, "perf_boost": 1.0},
    "QD9": {"base_weight": 0.9, "security_boost": 0.0, "perf_boost": 0.5},
    "QD10": {"base_weight": 0.9, "security_boost": 0.0, "perf_boost": 0.0},
    "QD11": {"base_weight": 0.9, "security_boost": 0.0, "perf_boost": 0.0},
}

# File extension → dimension boost mapping
FILE_TYPE_DIM_HINTS: dict[str, list[tuple[str, float]]] = {
    ".sql": [("QD6", 1.5)],
    ".tsx": [("QD5", 1.0), ("QD7", 0.5)],
    ".jsx": [("QD5", 1.0), ("QD7", 0.5)],
    ".vue": [("QD5", 1.0), ("QD7", 0.5)],
    ".svelte": [("QD5", 1.0), ("QD7", 0.5)],
}


# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass
class DimRecommendation:
    """Một dòng recommend cho 1 chiều chất lượng."""

    dim: str
    strength: str  # "strong" | "weak" | "none"
    reason: str

    def to_dict(self) -> dict[str, str]:
        return {"dim": self.dim, "strength": self.strength, "reason": self.reason}


@dataclass
class Signals:
    """Tập hợp tín hiệu thu thập được từ môi trường."""

    git_diff_files: list[str] = field(default_factory=list)
    preflight_available: bool = False
    preflight_critical_count: int = 0
    preflight_warn_count: int = 0
    preflight_security_warn: bool = False
    preflight_perf_warn: bool = False
    domain: str | None = None
    departments: list[str] = field(default_factory=list)
    interface_type: str | None = None  # "api-only" | "web" | ...


# ──────────────────────────────────────────────────────────────────────
# Utility: atomic write JSON
# ──────────────────────────────────────────────────────────────────────


def _atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    """Ghi JSON atomic: tempfile trong cùng dir + fsync + os.replace.

    Bảo vệ chống corruption nếu process crash giữa chừng.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_fd, tmp_name = tempfile.mkstemp(
        prefix=f".{path.name}.",
        suffix=".tmp",
        dir=str(path.parent),
    )
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2, sort_keys=True)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_name, path)
    except Exception:
        # Cleanup tmp file nếu chưa replace
        try:
            if os.path.exists(tmp_name):
                os.unlink(tmp_name)
        except OSError:
            pass
        raise


# ──────────────────────────────────────────────────────────────────────
# 1. Signal collection
# ──────────────────────────────────────────────────────────────────────


def _run_git_diff(since_ref: str, cwd: Path) -> list[str]:
    """Chạy `git diff --name-only <since_ref>` trả về list file paths.

    Không raise — nếu git fail (không phải repo, ref invalid) → trả [].
    """
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", since_ref],
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if result.returncode != 0:
            return []
        files = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        return files
    except (OSError, subprocess.TimeoutExpired):
        return []


def _parse_preflight(preflight_path: Path) -> tuple[bool, int, int, bool, bool]:
    """Parse preflight-report.md → (available, critical, warn, security_warn, perf_warn).

    Không raise — nếu không đọc được → trả (False, 0, 0, False, False).
    """
    if not preflight_path.exists():
        return False, 0, 0, False, False

    try:
        content = preflight_path.read_text(encoding="utf-8")
    except OSError:
        return False, 0, 0, False, False

    critical_count = len(PREFLIGHT_CRITICAL_PATTERN.findall(content))
    warn_count = len(PREFLIGHT_WARN_PATTERN.findall(content))

    # Kiểm tra WARN trong section security/performance
    # Heuristic đơn giản: tìm section header + ≥1 WARN trong 2000 char sau đó
    security_warn = False
    perf_warn = False
    for match in PREFLIGHT_SECURITY_SECTION.finditer(content):
        section_text = content[match.end() : match.end() + 2000]
        if PREFLIGHT_WARN_PATTERN.search(section_text) or PREFLIGHT_CRITICAL_PATTERN.search(section_text):
            security_warn = True
            break
    for match in PREFLIGHT_PERF_SECTION.finditer(content):
        section_text = content[match.end() : match.end() + 2000]
        if PREFLIGHT_WARN_PATTERN.search(section_text) or PREFLIGHT_CRITICAL_PATTERN.search(section_text):
            perf_warn = True
            break

    return True, critical_count, warn_count, security_warn, perf_warn


def _load_registry_info(registry_path: Path) -> tuple[list[str], str | None]:
    """Đọc req-registry.json → (departments, interface_type).

    Không raise — nếu fail → ([], None).
    """
    if not registry_path.exists():
        return [], None

    try:
        raw = registry_path.read_text(encoding="utf-8")
        data = json.loads(raw)
    except (OSError, json.JSONDecodeError):
        return [], None

    departments_raw = data.get("departments", [])
    departments: list[str] = []
    if isinstance(departments_raw, list):
        for d in departments_raw:
            if isinstance(d, str):
                departments.append(d)
            elif isinstance(d, dict):
                name = d.get("id") or d.get("name") or d.get("slug")
                if isinstance(name, str):
                    departments.append(name)

    interface_type = data.get("interface_type")
    if not isinstance(interface_type, str):
        interface_type = None

    return departments, interface_type


def _detect_domain(departments: list[str]) -> str | None:
    """Ghép departments[] → domain keyword đầu tiên khớp DOMAIN_DIM_HINTS."""
    for dept in departments:
        key = dept.lower().strip()
        for keyword in DOMAIN_DIM_HINTS:
            if keyword in key:
                return keyword
    return None


def collect_signals(
    session_dir: Path,
    scope: str,
    scope_name: str | None = None,
    since_ref: str | None = None,
) -> Signals:
    """Đọc git diff + preflight report + registry để gom tín hiệu.

    Args:
        session_dir: thư mục session của fix run (để locate preflight/registry).
        scope: "all" | "system" | "module".
        scope_name: tên system/module khi scope != "all".
        since_ref: git ref để diff (default HEAD~1).

    Returns:
        Signals đã điền đầy đủ (trường nào không có → giữ default).
    """
    # Tìm project root (walk up từ session_dir để gặp .mc-data/)
    project_root = _find_project_root(session_dir)
    if project_root is None:
        # Fallback: session_dir chính là project root
        project_root = session_dir

    # Git diff
    ref = since_ref or "HEAD~1"
    git_files = _run_git_diff(ref, project_root)

    # Preflight
    preflight_path = project_root / ".mc-data" / "work" / "wf-preflight" / "preflight-report.md"
    p_available, p_crit, p_warn, p_sec, p_perf = _parse_preflight(preflight_path)

    # Registry
    registry_path = project_root / ".mc-data" / "docs" / "_meta" / "req-registry.json"
    departments, interface_type = _load_registry_info(registry_path)
    domain = _detect_domain(departments)

    return Signals(
        git_diff_files=git_files,
        preflight_available=p_available,
        preflight_critical_count=p_crit,
        preflight_warn_count=p_warn,
        preflight_security_warn=p_sec,
        preflight_perf_warn=p_perf,
        domain=domain,
        departments=departments,
        interface_type=interface_type,
    )


def _find_project_root(start: Path) -> Path | None:
    """Walk up từ start, tìm thư mục chứa .mc-data/ hoặc .git/."""
    try:
        current = start.resolve()
    except OSError:
        return None

    if current.is_file():
        current = current.parent

    # Depth 30 — hỗ trợ nested monorepo (vd: repo/apps/web/packages/*/...)
    # và các worktree sâu. Loop vẫn break khi đạt filesystem root.
    for _ in range(30):
        if (current / ".mc-data").is_dir() or (current / ".git").exists():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent

    return None


# ──────────────────────────────────────────────────────────────────────
# 2. Analysis → recommendations
# ──────────────────────────────────────────────────────────────────────


def _merge_strength(current: str, incoming: str) -> str:
    """Kết hợp 2 strength → chọn cái mạnh hơn. strong > weak > none."""
    order = {"none": 0, "weak": 1, "strong": 2}
    if order.get(incoming, 0) > order.get(current, 0):
        return incoming
    return current


def analyze(signals: Signals, profile: str) -> list[DimRecommendation]:
    """Từ signals → list recommendations cho 10 chiều QD.

    Heuristic xem README.md §4.

    Args:
        signals: Signals object từ collect_signals().
        profile: "quick" | "standard" | "deep" | "exhaustive".

    Returns:
        List 11 DimRecommendation — mỗi QD một dòng.

    Raises:
        ValueError: nếu profile không hợp lệ.
    """
    if profile not in VALID_PROFILES:
        raise ValueError(
            f"analyze: profile '{profile}' không hợp lệ — "
            f"phải thuộc {sorted(VALID_PROFILES)}"
        )

    # Khởi tạo: mỗi QD bắt đầu với strength="none", reason rỗng
    strengths: dict[str, str] = {d: "none" for d in DIMENSIONS}
    reasons: dict[str, list[str]] = {d: [] for d in DIMENSIONS}

    # 2.1. Git diff signals
    compiled_patterns = [(re.compile(p, re.IGNORECASE), dims) for p, dims in DIFF_PATTERN_TO_DIMS]
    diff_dim_counts: dict[str, int] = {d: 0 for d in DIMENSIONS}

    for file_path in signals.git_diff_files:
        for regex, dim_hints in compiled_patterns:
            if regex.search(file_path):
                for dim, strength in dim_hints:
                    strengths[dim] = _merge_strength(strengths[dim], strength)
                    diff_dim_counts[dim] += 1

    for dim, count in diff_dim_counts.items():
        if count > 0:
            reasons[dim].append(f"git diff chạm {count} file khớp pattern {dim}")

    if len(signals.git_diff_files) > DIFF_MANY_FILES_THRESHOLD:
        strengths["QD7"] = _merge_strength(strengths["QD7"], "weak")
        reasons["QD7"].append(
            f"Diff có {len(signals.git_diff_files)} file (> {DIFF_MANY_FILES_THRESHOLD}) — "
            "rủi ro compat tăng"
        )

    # 2.2. Preflight signals
    if signals.preflight_available:
        if signals.preflight_critical_count > 0:
            # CRITICAL bơm QD1 strong (fallback) — section-specific sẽ override
            strengths["QD1"] = _merge_strength(strengths["QD1"], "strong")
            reasons["QD1"].append(
                f"Preflight có {signals.preflight_critical_count} lỗi CRITICAL"
            )
        if signals.preflight_security_warn:
            strengths["QD3"] = _merge_strength(strengths["QD3"], "strong")
            reasons["QD3"].append("Preflight section security có WARN/CRITICAL")
        if signals.preflight_perf_warn:
            strengths["QD4"] = _merge_strength(strengths["QD4"], "weak")
            reasons["QD4"].append("Preflight section performance có WARN")

    # 2.3. Domain signals
    if signals.domain and signals.domain in DOMAIN_DIM_HINTS:
        for dim in DOMAIN_DIM_HINTS[signals.domain]:
            strengths[dim] = _merge_strength(strengths[dim], "strong")
            reasons[dim].append(f"Domain '{signals.domain}' yêu cầu {dim}")

    # 2.4. Interface type
    if signals.interface_type == "api-only":
        # QD5 ít liên quan với api-only
        if strengths["QD5"] == "strong":
            strengths["QD5"] = "weak"
        reasons["QD5"].append("interface_type=api-only — UI/accessibility ít liên quan")

    # 2.5. Profile default — auto-include với strength="weak" nếu chưa có signal
    profile_defaults = DEFAULT_PROFILE_DIMS[profile]
    for dim in profile_defaults:
        if strengths[dim] == "none":
            strengths[dim] = "weak"
            reasons[dim].append(f"Profile '{profile}' mặc định include {dim}")

    # 2.6. Build recommendations
    recommendations: list[DimRecommendation] = []
    for dim in DIMENSIONS:
        reason_text = "; ".join(reasons[dim]) if reasons[dim] else f"Không có signal cho {dim}"
        # Đảm bảo reason ≥ 10 ký tự (schema requirement)
        if len(reason_text) < 10:
            reason_text = reason_text.ljust(10, ".")
        recommendations.append(
            DimRecommendation(dim=dim, strength=strengths[dim], reason=reason_text)
        )

    return recommendations


# ──────────────────────────────────────────────────────────────────────
# 3. Render checklist
# ──────────────────────────────────────────────────────────────────────


def _strength_marker(strength: str) -> str:
    """Map strength → ký hiệu hiển thị."""
    if strength == "strong":
        return "★ strong"
    if strength == "weak":
        return "· weak  "
    return "       "


def render_checklist(recommendations: list[DimRecommendation], profile: str) -> str:
    """Trả về markdown table tick-box để in ra stdout.

    Format:
        | Tick | QD | Tên | Recommend | Lý do |

    Args:
        recommendations: list 7 DimRecommendation từ analyze().
        profile: "quick" | "standard" | "deep" | "exhaustive".

    Returns:
        Markdown string.

    Raises:
        ValueError: nếu profile không hợp lệ.
    """
    if profile not in VALID_PROFILES:
        raise ValueError(
            f"render_checklist: profile '{profile}' không hợp lệ — "
            f"phải thuộc {sorted(VALID_PROFILES)}"
        )

    defaults = DEFAULT_PROFILE_DIMS[profile]

    lines: list[str] = []
    lines.append(f"# ISG — Chọn chiều chất lượng để quét (profile = `{profile}`)")
    lines.append("")
    lines.append(f"**Default profile:** {', '.join(defaults)}")
    lines.append("")
    lines.append("| Tick | QD | Tên | Recommend | Lý do |")
    lines.append("|:----:|:---|:----|:----------|:------|")

    for rec in recommendations:
        tick = "[x]" if rec.dim in defaults else "[ ]"
        marker = _strength_marker(rec.strength)
        # Escape pipe trong reason để không phá table
        reason_safe = rec.reason.replace("|", "\\|")
        lines.append(
            f"| {tick} | {rec.dim} | {DIM_NAMES[rec.dim]} | {marker} | {reason_safe} |"
        )

    lines.append("")
    lines.append("## Hướng dẫn trả lời")
    lines.append("")
    lines.append("- Gõ `recommend` để lấy tất cả chiều có strength = strong hoặc weak.")
    lines.append("- Gõ `all` để chọn toàn bộ 11 chiều.")
    lines.append("- Gõ `default` (hoặc bỏ trống) để giữ default profile.")
    lines.append("- Gõ danh sách tùy ý, ví dụ `QD1,QD2,QD5`.")
    lines.append("")
    if profile in SAFETY_FLOOR_PROFILES:
        floor = ", ".join(sorted(SAFETY_FLOOR_DIMS))
        lines.append(
            f"> ⚠️  **ADR-22 rule 1:** Profile `{profile}` yêu cầu ít nhất 1 trong "
            f"[{floor}] phải được chọn."
        )
        lines.append("")

    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────
# 4. Parse user response
# ──────────────────────────────────────────────────────────────────────


_QD_TOKEN_PATTERN = re.compile(r"^QD(1[0-1]|[1-9])$", re.IGNORECASE)


def parse_user_response(
    response: str,
    recommendations: list[DimRecommendation],
    profile: str,
) -> set[str]:
    """Parse input user thành set[QD-id].

    Hỗ trợ:
        - "" hoặc "default" → DEFAULT_PROFILE_DIMS[profile]
        - "recommend" → tất cả dim có strength != "none"
        - "all" → toàn bộ 11 QD
        - "QD1,QD2,QD5" → custom subset

    Raises:
        ValueError: nếu profile sai, response rỗng sau khi strip nhưng không
            phải "" (edge case), hoặc danh sách chứa token sai format.
    """
    if profile not in VALID_PROFILES:
        raise ValueError(
            f"parse_user_response: profile '{profile}' không hợp lệ — "
            f"phải thuộc {sorted(VALID_PROFILES)}"
        )

    text = (response or "").strip()
    lowered = text.lower()

    # Empty hoặc "default"
    if lowered == "" or lowered == "default":
        return set(DEFAULT_PROFILE_DIMS[profile])

    if lowered == "all":
        return set(DIMENSIONS)

    if lowered == "recommend":
        return {r.dim for r in recommendations if r.strength != "none"}

    # Custom list: split theo "," hoặc whitespace
    tokens = [t.strip().upper() for t in re.split(r"[,\s]+", text) if t.strip()]
    if not tokens:
        # Edge case: response chỉ chứa delimiter
        return set(DEFAULT_PROFILE_DIMS[profile])

    selected: set[str] = set()
    invalid: list[str] = []
    for tok in tokens:
        if _QD_TOKEN_PATTERN.match(tok) and tok in DIMENSIONS:
            selected.add(tok)
        else:
            invalid.append(tok)

    if invalid:
        raise ValueError(
            f"parse_user_response: token không hợp lệ {invalid} — "
            f"phải có dạng QD1..QD11"
        )

    return selected


# ──────────────────────────────────────────────────────────────────────
# 5. Safety floor enforcement (ADR-22 rule 1) — CRITICAL
# ──────────────────────────────────────────────────────────────────────


def enforce_safety_floor(selected: set[str], profile: str) -> tuple[bool, str | None]:
    """ADR-22 rule 1: profile ≥ standard phải giữ ≥ 1 trong {QD1, QD2, QD5}.

    Args:
        selected: tập QD đã chọn.
        profile: "quick" | "standard" | "deep" | "exhaustive".

    Returns:
        (ok, violation_message):
            ok = True  → không vi phạm
            ok = False → violation_message mô tả lý do (tiếng Việt)

    Raises:
        ValueError: nếu profile không hợp lệ hoặc selected rỗng.
    """
    if profile not in VALID_PROFILES:
        raise ValueError(
            f"enforce_safety_floor: profile '{profile}' không hợp lệ — "
            f"phải thuộc {sorted(VALID_PROFILES)}"
        )
    if not selected:
        raise ValueError(
            "enforce_safety_floor: selected rỗng — phải chọn ít nhất 1 QD"
        )

    # Tất cả token trong selected phải hợp lệ
    invalid = [t for t in selected if t not in DIMENSIONS]
    if invalid:
        raise ValueError(
            f"enforce_safety_floor: selected chứa token không hợp lệ {sorted(invalid)}"
        )

    # Profile quick không có floor
    if profile not in SAFETY_FLOOR_PROFILES:
        return True, None

    # Profile exhaustive yêu cầu full 11
    if profile == "exhaustive":
        missing = sorted(set(DIMENSIONS) - selected)
        if missing:
            return False, (
                f"LỖI: Profile 'exhaustive' yêu cầu chọn đủ {len(DIMENSIONS)} QD. "
                f"Còn thiếu: {', '.join(missing)}."
            )
        return True, None

    # Standard + deep: phải có ít nhất 1 trong safety floor
    intersection = selected & SAFETY_FLOOR_DIMS
    if not intersection:
        floor_list = ", ".join(sorted(SAFETY_FLOOR_DIMS))
        return False, (
            f"LỖI: Profile '{profile}' yêu cầu ít nhất 1 trong [{floor_list}] "
            f"phải được chọn.\n"
            f"    Lý do: North Star của wf-fix-bugs là ưu tiên logic + nghiệp vụ + UI.\n"
            f"    Gợi ý: Dùng --profile=quick nếu bạn muốn bỏ cả 3."
        )

    return True, None


# ──────────────────────────────────────────────────────────────────────
# 6. CDG check (CORE-027) — confirm các lựa chọn "nguy hiểm"
# ──────────────────────────────────────────────────────────────────────


def check_cdg(selected: set[str], profile: str) -> list[str]:
    """Trả về list CDG token user phải gõ để xác nhận.

    Trigger (xem README.md §6):
        - Bỏ QD1 ở profile=standard → cần override-qd1
        - Bỏ QD3 ở profile=deep → cần confirm-skip-qd3

    Args:
        selected: tập QD đã chọn.
        profile: "quick" | "standard" | "deep" | "exhaustive".

    Returns:
        list token — rỗng nghĩa là không cần CDG.

    Raises:
        ValueError: nếu profile không hợp lệ.
    """
    if profile not in VALID_PROFILES:
        raise ValueError(
            f"check_cdg: profile '{profile}' không hợp lệ — "
            f"phải thuộc {sorted(VALID_PROFILES)}"
        )

    tokens: list[str] = []

    # Standard: bỏ QD1 → override
    if profile == "standard" and "QD1" not in selected:
        tokens.append(CDG_TOKEN_OVERRIDE_QD1)

    # Deep: bỏ QD3 → confirm-skip
    if profile == "deep" and "QD3" not in selected:
        tokens.append(CDG_TOKEN_SKIP_QD3)

    # Deep: bỏ QD1 cũng cần override (cùng rationale như standard)
    if profile == "deep" and "QD1" not in selected:
        if CDG_TOKEN_OVERRIDE_QD1 not in tokens:
            tokens.append(CDG_TOKEN_OVERRIDE_QD1)

    return tokens


# ──────────────────────────────────────────────────────────────────────
# 7. Emit dim-selection.json
# ──────────────────────────────────────────────────────────────────────


def emit_selection(
    selected: set[str],
    recommendations: list[DimRecommendation],
    profile: str,
    scope: dict[str, Any],
    signals: Signals,
    output_path: Path,
    cdg_confirmations: list[str] | None = None,
    skipped_rationale: str | None = None,
) -> Path:
    """Ghi dim-selection.json theo schema dim-selection-v1.

    Args:
        selected: tập QD đã chọn (phải đã pass enforce_safety_floor).
        recommendations: list 7 DimRecommendation.
        profile: "quick" | "standard" | "deep" | "exhaustive".
        scope: dict {"type": ..., "name": ...}.
        signals: Signals object.
        output_path: đường dẫn file output.
        cdg_confirmations: list CDG token user đã gõ.
        skipped_rationale: giải thích tiếng Việt vì sao các QD bị bỏ.

    Returns:
        output_path.

    Raises:
        ValueError: nếu profile/scope/selected không hợp lệ.
    """
    if profile not in VALID_PROFILES:
        raise ValueError(
            f"emit_selection: profile '{profile}' không hợp lệ — "
            f"phải thuộc {sorted(VALID_PROFILES)}"
        )
    if not selected:
        raise ValueError("emit_selection: selected rỗng — schema yêu cầu minItems=1")

    invalid = [t for t in selected if t not in DIMENSIONS]
    if invalid:
        raise ValueError(
            f"emit_selection: selected chứa token không hợp lệ {sorted(invalid)}"
        )

    # Validate scope
    if not isinstance(scope, dict) or "type" not in scope:
        raise ValueError("emit_selection: scope phải là dict có key 'type'")
    scope_type = scope.get("type")
    if scope_type not in ("all", "system", "module"):
        raise ValueError(
            f"emit_selection: scope.type '{scope_type}' không hợp lệ — "
            "phải là all|system|module"
        )

    # Build scope dict chuẩn
    scope_out: dict[str, Any] = {"type": scope_type}
    if scope_type != "all":
        name = scope.get("name")
        if isinstance(name, str) and name.strip():
            scope_out["name"] = name.strip()

    # Tính safety_floor_enforced
    safety_floor_enforced = (
        profile in SAFETY_FLOOR_PROFILES
        and bool(selected & SAFETY_FLOOR_DIMS)
    )

    # Tính skipped
    skipped = sorted(set(DIMENSIONS) - selected)

    # Chuẩn hóa interface_type cho schema enum
    interface_type_for_schema = signals.interface_type
    if interface_type_for_schema not in (None, "api-only", "web", "mobile", "hybrid"):
        # Schema chỉ accept các giá trị trên — fallback về null nếu lạ
        interface_type_for_schema = None

    data: dict[str, Any] = {
        "$schema": "dim-selection-v1",
        "selected_at": datetime.now(timezone.utc).isoformat(),
        "profile": profile,
        "scope": scope_out,
        "recommendations": [r.to_dict() for r in recommendations],
        "selected": sorted(selected),
        "skipped": skipped,
        "safety_floor_enforced": safety_floor_enforced,
        "source_signals": {
            "git_diff_files": len(signals.git_diff_files),
            "preflight_available": signals.preflight_available,
            "preflight_critical_count": signals.preflight_critical_count,
            "preflight_warn_count": signals.preflight_warn_count,
            "domain": signals.domain,
            "interface_type": interface_type_for_schema,
        },
    }

    if cdg_confirmations:
        data["cdg_confirmations"] = list(cdg_confirmations)

    if skipped_rationale:
        data["skipped_rationale"] = skipped_rationale
    elif skipped:
        data["skipped_rationale"] = (
            f"User chọn profile={profile}; các chiều bỏ qua: {', '.join(skipped)}."
        )

    _atomic_write_json(output_path, data)
    return output_path


# ──────────────────────────────────────────────────────────────────────
# 8. Dimension scoring (Stage E4 — v6 engine)
# ──────────────────────────────────────────────────────────────────────


def recommend_dimensions(
    file_paths: list[str] | None = None,
    interface_type: str | None = None,
    domain: str | None = None,
) -> list[tuple[str, float]]:
    """Rank dimensions theo file type hints + project context.

    Args:
        file_paths: Danh sách file paths để detect extension boosts.
        interface_type: "api-only" → skip QD5; "web" → boost QD5.
        domain: Domain keyword để boost từ DOMAIN_DIM_HINTS.

    Returns:
        Sorted list of (dim, score) tuples — highest score first.
    """
    scores: dict[str, float] = {}
    for dim, weights in DIMENSION_SCORES.items():
        scores[dim] = weights["base_weight"]

    # File type boosts
    if file_paths:
        for fp in file_paths:
            ext = ""
            for suffix in (".tsx", ".jsx", ".vue", ".svelte", ".sql"):
                if fp.lower().endswith(suffix):
                    ext = suffix
                    break
            if ext and ext in FILE_TYPE_DIM_HINTS:
                for dim, boost in FILE_TYPE_DIM_HINTS[ext]:
                    scores[dim] = scores.get(dim, 0.0) + boost

    # Domain boosts
    if domain and domain in DOMAIN_DIM_HINTS:
        for dim in DOMAIN_DIM_HINTS[domain]:
            if dim in ("QD3",):
                scores[dim] += DIMENSION_SCORES[dim]["security_boost"]
            elif dim in ("QD6",):
                scores[dim] += 0.5

    # Interface type adjustment
    if interface_type == "api-only":
        scores["QD5"] = 0.0  # Exclude UX/A11y cho api-only
    elif interface_type in ("web", "mobile", "hybrid"):
        scores["QD5"] += 0.5

    # Sort by score descending
    ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return ranked


# ──────────────────────────────────────────────────────────────────────
# CLI dispatch
# ──────────────────────────────────────────────────────────────────────


def _cmd_analyze(args: argparse.Namespace) -> int:
    """`isg_recommender.py analyze` subcommand — print recommendations JSON."""
    signals = collect_signals(
        session_dir=args.session_dir,
        scope=args.scope,
        scope_name=args.name,
        since_ref=args.since,
    )
    recs = analyze(signals, args.profile)
    out = {
        "profile": args.profile,
        "scope": {"type": args.scope, "name": args.name},
        "recommendations": [r.to_dict() for r in recs],
        "source_signals": {
            "git_diff_files": len(signals.git_diff_files),
            "preflight_available": signals.preflight_available,
            "preflight_critical_count": signals.preflight_critical_count,
            "preflight_warn_count": signals.preflight_warn_count,
            "domain": signals.domain,
            "interface_type": signals.interface_type,
        },
    }
    print(json.dumps(out, ensure_ascii=False, indent=2))
    return 0


def _cmd_render(args: argparse.Namespace) -> int:
    """`isg_recommender.py render` subcommand — print checklist markdown."""
    try:
        raw = args.recommendations.read_text(encoding="utf-8")
        data = json.loads(raw)
    except (OSError, json.JSONDecodeError) as e:
        print(f"LỖI: không đọc được {args.recommendations}: {e}", file=sys.stderr)
        return 2

    recs_raw = data.get("recommendations", [])
    recs = [
        DimRecommendation(
            dim=str(r["dim"]),
            strength=str(r["strength"]),
            reason=str(r["reason"]),
        )
        for r in recs_raw
    ]
    print(render_checklist(recs, args.profile))
    return 0


def _cmd_enforce(args: argparse.Namespace) -> int:
    """`isg_recommender.py enforce` subcommand — check safety + CDG."""
    try:
        selected = parse_user_response(args.selected, [], args.profile)
    except ValueError as e:
        print(f"LỖI: {e}", file=sys.stderr)
        return 2

    ok, msg = enforce_safety_floor(selected, args.profile)
    if not ok:
        print(msg, file=sys.stderr)
        return 3

    cdg = check_cdg(selected, args.profile)
    if cdg:
        print(
            f"CẦN CDG: phải gõ các token {cdg} để xác nhận override",
            file=sys.stderr,
        )
        return 4

    print(json.dumps({"selected": sorted(selected), "ok": True}, ensure_ascii=False))
    return 0


def _cmd_emit(args: argparse.Namespace) -> int:
    """`isg_recommender.py emit` subcommand — ghi dim-selection.json."""
    try:
        selected = parse_user_response(args.selected, [], args.profile)
    except ValueError as e:
        print(f"LỖI: {e}", file=sys.stderr)
        return 2

    ok, msg = enforce_safety_floor(selected, args.profile)
    if not ok:
        print(msg, file=sys.stderr)
        return 3

    scope_dict: dict[str, Any] = {"type": args.scope_type}
    if args.scope_name:
        scope_dict["name"] = args.scope_name

    # Minimal signals cho CLI — thực tế orchestrator gọi collect_signals trước
    signals = collect_signals(
        session_dir=args.session_dir if args.session_dir else Path.cwd(),
        scope=args.scope_type,
        scope_name=args.scope_name,
    )
    recs = analyze(signals, args.profile)

    out = emit_selection(
        selected=selected,
        recommendations=recs,
        profile=args.profile,
        scope=scope_dict,
        signals=signals,
        output_path=args.output,
    )
    print(str(out))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="ISG recommender — phân tích signals + render + emit dim-selection.json"
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_analyze = sub.add_parser("analyze", help="Phân tích signals → recommendations")
    p_analyze.add_argument("--session-dir", required=True, type=Path)
    p_analyze.add_argument("--profile", default="standard", choices=sorted(VALID_PROFILES))
    p_analyze.add_argument("--scope", default="all", choices=["all", "system", "module"])
    p_analyze.add_argument("--name", default=None)
    p_analyze.add_argument("--since", default=None)
    p_analyze.set_defaults(func=_cmd_analyze)

    p_render = sub.add_parser("render", help="Render checklist markdown")
    p_render.add_argument("--recommendations", required=True, type=Path)
    p_render.add_argument("--profile", default="standard", choices=sorted(VALID_PROFILES))
    p_render.set_defaults(func=_cmd_render)

    p_enforce = sub.add_parser("enforce", help="Enforce safety floor + CDG")
    p_enforce.add_argument("--selected", required=True)
    p_enforce.add_argument("--profile", default="standard", choices=sorted(VALID_PROFILES))
    p_enforce.set_defaults(func=_cmd_enforce)

    p_emit = sub.add_parser("emit", help="Emit dim-selection.json")
    p_emit.add_argument("--selected", required=True)
    p_emit.add_argument("--profile", default="standard", choices=sorted(VALID_PROFILES))
    p_emit.add_argument("--scope-type", default="all", choices=["all", "system", "module"])
    p_emit.add_argument("--scope-name", default=None)
    p_emit.add_argument("--session-dir", default=None, type=Path)
    p_emit.add_argument("--output", required=True, type=Path)
    p_emit.set_defaults(func=_cmd_emit)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
