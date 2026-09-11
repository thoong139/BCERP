#!/usr/bin/env python3
"""estimator.py — Phase 0 Workload Estimation.

Vai trò:
    Ước lượng workload dựa trên file count + profile + selected dims.
    Trigger Workload Gate (ADR-14) nếu vượt ngưỡng. Đề xuất Partition Plan A/B
    (ADR-15).

Registry role: NONE. Chỉ ĐỌC req-registry.json, không ghi.

Tham chiếu:
    - ADR-02: utility module
    - ADR-14: Workload Gate (default 45 min = 2700s)
    - ADR-15: Partition Planner (Plan A by_scope, Plan B by_dim)
    - ADR-22 rule 1: safety floor — không tự drop QD1/QD2/QD5
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# ──────────────────────────────────────────────────────────────────────
# Hằng số — heuristic bảng (tune qua B4)
# ──────────────────────────────────────────────────────────────────────

PROBES_PER_DIM: dict[str, int] = {
    "QD1": 3,
    "QD2": 2,
    "QD3": 2,
    "QD4": 2,
    "QD5": 3,
    "QD6": 2,
    "QD7": 1,
    "QD8": 2,  # Observability & Reliability — retry/CB + timeout in quick; up to 7 in exhaustive
    "QD9": 7,  # Runtime Health — 3 core Wave 1 + 4 deep Wave 1.5 (browser-based probes)
    "QD10": 5,  # Cross-Module Integration — 3 static Wave 1 + 2 runtime Wave 1.5
    "QD11": 3,  # Business Completeness — 3 LLM probes (cross-module + domain heuristic + registry gap)
}

# Stage E3: Dimension weights cho v6 engine — multiplier cho estimated_sec
DIMENSION_WEIGHTS: dict[str, float] = {
    "QD1": 1.0,   # Functional — baseline
    "QD2": 1.2,   # Business — needs agent
    "QD3": 1.5,   # Security — higher cost, no cache (ADR-22 Rule 6)
    "QD4": 1.0,   # Performance — static + runtime
    "QD5": 1.3,   # UX/A11y — needs Playwright + agents
    "QD6": 0.8,   # Data — mostly static
    "QD7": 1.1,   # Compat — static + runtime
    "QD8": 1.0,   # Observability — mostly static + 1 runtime health-check
    "QD9": 1.3,   # Runtime Health — browser-based, Playwright heavy
    "QD10": 1.2,  # Cross-Module Integration — static + runtime, multi-module
    "QD11": 1.5,  # Business Completeness — 100% LLM, expensive tokens
}

AVG_TIME_PER_FILE_SEC: dict[str, float] = {
    "QD1": 1.5,
    "QD2": 2.0,
    "QD3": 3.5,
    "QD4": 2.5,
    "QD5": 2.0,
    "QD6": 2.5,
    "QD7": 1.5,
    "QD8": 2.0,  # log/metrics scan grep-based, runtime health-check = curl
    "QD9": 3.0,  # browser runtime probes — each takes significant Playwright time
    "QD10": 2.5, # cross-module integration — static + runtime multi-module analysis
    "QD11": 3.5, # LLM analysis — token-heavy, not strictly per-file but conservative estimate
}

PROFILE_MULTIPLIER: dict[str, float] = {
    "quick": 0.5,
    "standard": 1.0,
    "deep": 1.5,
    "exhaustive": 2.5,
}

GATE_THRESHOLD_SEC_DEFAULT: int = 45 * 60  # 2700s = 45 phút (ADR-14)

SCHEMA_ID: str = "fix-workload-v1"

# Source extensions hợp lệ khi count files
SOURCE_EXTENSIONS: frozenset[str] = frozenset(
    {
        ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
        ".py", ".rb", ".go", ".rs", ".java", ".kt", ".swift",
        ".cs", ".php", ".vue", ".svelte",
        ".sql", ".sh", ".html", ".css", ".scss",
    }
)

# Directory exclude khi scan toàn bộ
EXCLUDED_DIRS: frozenset[str] = frozenset(
    {
        "node_modules", ".git", ".venv", "venv", "__pycache__",
        "dist", "build", ".next", ".turbo", ".cache",
        "coverage", ".mc-data", ".pytest_cache", "target",
    }
)


# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass
class LaneEstimate:
    """Estimate cho 1 QD lane."""

    dim: str
    probes_count: int
    files_covered: int
    estimated_sec: float


@dataclass
class PartitionPlan:
    """Plan A (by scope) hoặc Plan B (by dim)."""

    kind: str  # "by_scope" | "by_dim"
    batches: list[dict[str, Any]]
    estimated_sec_per_batch: float


@dataclass
class Workload:
    """Output của estimator."""

    workload_id: str
    estimated_at: str
    profile: str
    scope: dict[str, Any]
    file_count: int
    selected_dims: list[str]
    lanes: list[LaneEstimate]
    total_estimated_sec: float
    gate_threshold_sec: int
    gate_triggered: bool
    partition_plans: list[PartitionPlan] = field(default_factory=list)


# ──────────────────────────────────────────────────────────────────────
# 1. Count files in scope
# ──────────────────────────────────────────────────────────────────────


def _find_project_root(start: Path) -> Path:
    """Đi lên tìm project root (chứa .mc-data/ hoặc .git/).

    Fallback về start nếu không tìm thấy.
    """
    current = start.resolve()
    for parent in [current, *current.parents]:
        if (parent / ".mc-data").is_dir() or (parent / ".git").is_dir():
            return parent
    return current


def _count_source_files(root: Path) -> int:
    """Đếm source file trong root, exclude EXCLUDED_DIRS."""
    if not root.exists():
        return 0
    count = 0
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        # Exclude bất kỳ parent nào nằm trong EXCLUDED_DIRS
        if any(part in EXCLUDED_DIRS for part in path.parts):
            continue
        if path.suffix in SOURCE_EXTENSIONS:
            count += 1
    return count


def _load_registry(root: Path) -> dict[str, Any] | None:
    """Đọc req-registry.json nếu tồn tại + valid JSON."""
    registry_path = root / ".mc-data" / "docs" / "_meta" / "req-registry.json"
    if not registry_path.exists():
        return None
    try:
        return json.loads(registry_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def count_files_in_scope(session_dir: Path, scope: dict[str, Any]) -> int:
    """Đếm file thuộc scope.

    Args:
        session_dir: $SESSION_DIR (dùng để resolve project root).
        scope: {"type": "all"} hoặc {"type": "system"|"module", "name": "<id>"}.

    Returns:
        File count >= 0.

    Logic:
        - scope.type == "all" → đếm toàn bộ source file trong project root.
        - scope.type == "system" → đọc registry, lấy modules thuộc system, đếm files.
          Fallback: đếm toàn bộ nếu không match được.
        - scope.type == "module" → tương tự system.
    """
    project_root = _find_project_root(session_dir)
    scope_type = scope.get("type", "all")

    if scope_type == "all":
        return _count_source_files(project_root)

    # system / module → cần registry để xác định files
    registry = _load_registry(project_root)
    scope_name = scope.get("name")
    if registry is None or not scope_name:
        # Không có registry → fallback đếm all để có estimate (vẫn an toàn)
        return _count_source_files(project_root)

    # Thử tìm folder theo convention phase2-features/[system]/[module]/
    phase2_root = project_root / ".mc-data" / "docs" / "phase2-features"
    if scope_type == "system":
        candidate = phase2_root / scope_name
    else:  # module
        # Module có thể nằm trong bất kỳ system nào — quét qua các system folder
        candidate = phase2_root
        matched = False
        if phase2_root.exists():
            for sys_dir in phase2_root.iterdir():
                if sys_dir.is_dir() and (sys_dir / scope_name).is_dir():
                    candidate = sys_dir / scope_name
                    matched = True
                    break
        if not matched:
            return _count_source_files(project_root)

    # Candidate là docs folder, không phải code; dùng như heuristic count via feature specs
    # Vì chưa có module-code-mapping bắt buộc, fallback về toàn bộ source dưới project
    # và scale theo tỉ lệ feature count (conservative heuristic).
    if candidate.exists():
        feature_count = sum(1 for _ in candidate.rglob("*.md"))
        total = _count_source_files(project_root)
        if feature_count == 0 or total == 0:
            return total
        # Ước lượng: trung bình ~5 file code per feature
        estimated = min(total, max(1, feature_count * 5))
        return estimated

    return _count_source_files(project_root)


# ──────────────────────────────────────────────────────────────────────
# 2. Estimate per lane
# ──────────────────────────────────────────────────────────────────────


def estimate_lane(dim: str, file_count: int, profile: str, *, use_weights: bool = False) -> LaneEstimate:
    """estimated_sec = file_count * probes_per_dim * avg_time * profile_multiplier [* weight].

    Args:
        use_weights: Nếu True, nhân thêm DIMENSION_WEIGHTS[dim] (v6 engine).

    Raises:
        ValueError: dim không hợp lệ hoặc profile không hợp lệ.
    """
    if dim not in PROBES_PER_DIM:
        raise ValueError(
            f"estimate_lane: dim='{dim}' không hợp lệ "
            f"(cho phép: {sorted(PROBES_PER_DIM.keys())})"
        )
    if profile not in PROFILE_MULTIPLIER:
        raise ValueError(
            f"estimate_lane: profile='{profile}' không hợp lệ "
            f"(cho phép: {sorted(PROFILE_MULTIPLIER.keys())})"
        )
    if file_count < 0:
        raise ValueError(f"estimate_lane: file_count phải >= 0, nhận {file_count}")

    probes = PROBES_PER_DIM[dim]
    avg = AVG_TIME_PER_FILE_SEC[dim]
    mul = PROFILE_MULTIPLIER[profile]
    estimated_sec = file_count * probes * avg * mul

    if use_weights:
        weight = DIMENSION_WEIGHTS.get(dim, 1.0)
        estimated_sec *= weight

    return LaneEstimate(
        dim=dim,
        probes_count=probes,
        files_covered=file_count,
        estimated_sec=round(estimated_sec, 2),
    )


# ──────────────────────────────────────────────────────────────────────
# 3. Check Workload Gate
# ──────────────────────────────────────────────────────────────────────


def check_gate(total_sec: float, threshold_sec: int) -> bool:
    """Trả True nếu gate triggered (total > threshold)."""
    return total_sec > threshold_sec


def _get_threshold_sec() -> int:
    """Đọc env WF_FIX_BUGS_WORKLOAD_THRESHOLD_MIN (phút), fallback default."""
    env_val = os.environ.get("WF_FIX_BUGS_WORKLOAD_THRESHOLD_MIN")
    if env_val is None:
        return GATE_THRESHOLD_SEC_DEFAULT
    try:
        minutes = int(env_val)
        if minutes <= 0:
            return GATE_THRESHOLD_SEC_DEFAULT
        return minutes * 60
    except ValueError:
        return GATE_THRESHOLD_SEC_DEFAULT


# ──────────────────────────────────────────────────────────────────────
# 4. Propose partition plans (ADR-15)
# ──────────────────────────────────────────────────────────────────────


def propose_partitions(
    workload: Workload, session_dir: Path
) -> list[PartitionPlan]:
    """Đề xuất Plan A (by_scope) + Plan B (by_dim) khi gate_triggered.

    Plan A: chia theo module/system từ registry, mỗi batch ≈ threshold/2.
    Plan B: 1 batch per QD, chạy tuần tự.
    """
    plans: list[PartitionPlan] = []
    half_threshold = workload.gate_threshold_sec / 2.0

    # ── Plan A: by_scope ──────────────────────────────────────────
    project_root = _find_project_root(session_dir)
    registry = _load_registry(project_root)
    modules: list[dict[str, str]] = []
    if registry is not None:
        raw_modules = registry.get("modules", [])
        if isinstance(raw_modules, list):
            for m in raw_modules:
                if isinstance(m, dict):
                    mid = m.get("id") or m.get("module_id") or m.get("name")
                    sid = m.get("system_id") or m.get("system") or ""
                    if mid:
                        modules.append({"module_id": str(mid), "system_id": str(sid)})

    # Ước lượng files per module (equal split conservative)
    per_module_files = (
        max(1, workload.file_count // max(1, len(modules))) if modules else workload.file_count
    )
    plan_a_batches: list[dict[str, Any]] = []
    if modules:
        current_batch: list[dict[str, str]] = []
        current_sec = 0.0
        per_module_sec = sum(
            estimate_lane(dim, per_module_files, workload.profile).estimated_sec
            for dim in workload.selected_dims
        )
        for m in modules:
            if current_sec + per_module_sec > half_threshold and current_batch:
                plan_a_batches.append(
                    {"modules": current_batch, "estimated_sec": round(current_sec, 2)}
                )
                current_batch = []
                current_sec = 0.0
            current_batch.append(m)
            current_sec += per_module_sec
        if current_batch:
            plan_a_batches.append(
                {"modules": current_batch, "estimated_sec": round(current_sec, 2)}
            )
    else:
        # Không có module → 1 batch duy nhất (degenerate case)
        plan_a_batches.append(
            {"modules": [], "estimated_sec": workload.total_estimated_sec}
        )

    plan_a_sec = (
        max((b["estimated_sec"] for b in plan_a_batches), default=0.0)
        if plan_a_batches
        else 0.0
    )
    plans.append(
        PartitionPlan(
            kind="by_scope",
            batches=plan_a_batches,
            estimated_sec_per_batch=round(plan_a_sec, 2),
        )
    )

    # ── Plan B: by_dim ────────────────────────────────────────────
    plan_b_batches: list[dict[str, Any]] = []
    for lane in workload.lanes:
        plan_b_batches.append(
            {
                "dim": lane.dim,
                "files_covered": lane.files_covered,
                "estimated_sec": lane.estimated_sec,
            }
        )
    plan_b_sec = (
        max((b["estimated_sec"] for b in plan_b_batches), default=0.0)
        if plan_b_batches
        else 0.0
    )
    plans.append(
        PartitionPlan(
            kind="by_dim",
            batches=plan_b_batches,
            estimated_sec_per_batch=round(plan_b_sec, 2),
        )
    )

    return plans


# ──────────────────────────────────────────────────────────────────────
# 5. Main estimate function
# ──────────────────────────────────────────────────────────────────────


def _next_workload_id(session_dir: Path) -> str:
    """Format: WL-YYYYMMDD-NNN, NNN tăng dần theo file tồn tại cùng ngày."""
    today = datetime.now(timezone.utc).strftime("%Y%m%d")
    workloads_root = session_dir.parent if session_dir.name.startswith("WL-") else session_dir
    # Đếm existing workload cùng ngày
    count = 0
    if workloads_root.exists():
        for p in workloads_root.iterdir():
            if p.is_dir() and p.name.startswith(f"WL-{today}-"):
                count += 1
    return f"WL-{today}-{count + 1:03d}"


def estimate(
    session_dir: Path,
    profile: str,
    scope: dict[str, Any],
    selected_dims: list[str],
) -> Workload:
    """Full pipeline: count files → per-lane estimate → gate → partition plans."""
    if profile not in PROFILE_MULTIPLIER:
        raise ValueError(
            f"estimate: profile='{profile}' không hợp lệ "
            f"(cho phép: {sorted(PROFILE_MULTIPLIER.keys())})"
        )
    if not selected_dims:
        raise ValueError("estimate: selected_dims không được rỗng")
    for d in selected_dims:
        if d not in PROBES_PER_DIM:
            raise ValueError(f"estimate: dim='{d}' không hợp lệ")

    file_count = count_files_in_scope(session_dir, scope)
    lanes = [estimate_lane(dim, file_count, profile) for dim in selected_dims]
    total_sec = sum(l.estimated_sec for l in lanes)
    threshold = _get_threshold_sec()
    gate = check_gate(total_sec, threshold)

    workload = Workload(
        workload_id=_next_workload_id(session_dir),
        estimated_at=datetime.now(timezone.utc).isoformat(),
        profile=profile,
        scope=scope,
        file_count=file_count,
        selected_dims=list(selected_dims),
        lanes=lanes,
        total_estimated_sec=round(total_sec, 2),
        gate_threshold_sec=threshold,
        gate_triggered=gate,
    )

    if gate:
        workload.partition_plans = propose_partitions(workload, session_dir)

    return workload


# ──────────────────────────────────────────────────────────────────────
# 6. Emit workload JSON
# ──────────────────────────────────────────────────────────────────────


def _workload_to_dict(w: Workload) -> dict[str, Any]:
    return {
        "$schema": SCHEMA_ID,
        "workload_id": w.workload_id,
        "estimated_at": w.estimated_at,
        "profile": w.profile,
        "scope": w.scope,
        "file_count": w.file_count,
        "selected_dims": w.selected_dims,
        "lanes": [asdict(l) for l in w.lanes],
        "total_estimated_sec": w.total_estimated_sec,
        "gate_threshold_sec": w.gate_threshold_sec,
        "gate_triggered": w.gate_triggered,
        "partition_plans": [asdict(p) for p in w.partition_plans],
    }


def emit(workload: Workload, out_path: Path) -> None:
    """Atomic write fix-workload.json."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    data = _workload_to_dict(workload)
    tmp_fd, tmp_name = tempfile.mkstemp(
        prefix=f".{out_path.name}.", suffix=".tmp", dir=str(out_path.parent)
    )
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as fh:
            # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
            json.dump(data, fh, indent=2, ensure_ascii=False, sort_keys=True)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_name, out_path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def _cmd_analyze(args: argparse.Namespace) -> int:
    """estimator.py analyze ..."""
    try:
        workload = estimate(
            session_dir=args.session_dir,
            profile=args.profile,
            scope=args.scope,
            selected_dims=args.selected_dims,
        )
        emit(workload, args.output)
        print(
            f"[estimator] workload_id={workload.workload_id} "
            f"total={workload.total_estimated_sec}s "
            f"gate_triggered={workload.gate_triggered}",
            file=sys.stderr,
        )
        return 0
    except ValueError as exc:
        print(f"[estimator ERROR] {exc}", file=sys.stderr)
        return 1


def _parse_scope(s: str) -> dict[str, Any]:
    """Parse 'all' | 'system:<name>' | 'module:<name>' → dict."""
    if s == "all":
        return {"type": "all"}
    if ":" in s:
        kind, name = s.split(":", 1)
        if kind in ("system", "module") and name:
            return {"type": kind, "name": name}
    raise argparse.ArgumentTypeError(f"Invalid scope: {s}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Workload Estimator")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_analyze = sub.add_parser("analyze", help="Estimate workload + emit JSON")
    p_analyze.add_argument("--session-dir", required=True, type=Path)
    p_analyze.add_argument(
        "--profile", choices=list(PROFILE_MULTIPLIER.keys()), default="standard"
    )
    p_analyze.add_argument("--scope", type=_parse_scope, default={"type": "all"})
    p_analyze.add_argument(
        "--selected-dims", nargs="+", default=["QD1", "QD2", "QD5"]
    )
    p_analyze.add_argument("--output", type=Path, required=True)
    p_analyze.set_defaults(func=_cmd_analyze)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
