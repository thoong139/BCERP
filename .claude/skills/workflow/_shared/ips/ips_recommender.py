"""IPS Recommender — 2-phase domain detection + profile recommendation.

Phase A (after L2 Assessment) — recommend profile + initial domain hints.
Phase B (after L3 Inventory) — refine module routing + complexity hotspots.

Pattern reference: wf-fix-bugs v6 ISG Recommender.
Reference: docs/design/skills/wf-legacy-scan/05-profiles-ips.md §3.2-3.3.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import time
from collections import defaultdict
from pathlib import Path
from typing import Any

from .domain_scorer import find_unresolved_patterns, score_domains
from .vietnamese_keywords import load_pool


# ─── Utilities ───────────────────────────────────────────────


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    """Atomic write: write to .tmp then rename."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + f".tmp.{os.getpid()}")
    # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
    tmp.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True), encoding="utf-8"
    )
    try:
        with tmp.open("rb") as f:
            os.fsync(f.fileno())
    except (OSError, AttributeError):
        pass
    tmp.replace(path)


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


# ─── Phase A ─────────────────────────────────────────────────


# Detection threshold cho high-confidence domain (05-profiles-ips §3.2).
STRONG_DOMAIN_THRESHOLD = 0.75
# File count threshold for 'deep' recommendation.
LARGE_PROJECT_FILES = 1000
# Multiple-domain threshold (count of domains above moderate threshold).
MULTI_DOMAIN_COUNT = 2


def _classify_warnings(
    profile: dict[str, Any],
    detected: list[dict[str, Any]],
) -> list[dict[str, str]]:
    """Build warning list per 05-profiles-ips §3.6."""
    warnings: list[dict[str, str]] = []
    file_count = profile.get("file_counts", {}).get("total", 0)
    if not detected:
        warnings.append(
            {
                "code": "W_IPSA_NO_DOMAIN",
                "message": (
                    "No strong domain detected — will fall back to "
                    "business-analyst only at L5 (below 0.6 threshold)."
                ),
            }
        )
    if file_count > LARGE_PROJECT_FILES and detected and detected[0]["confidence"] < 0.4:
        warnings.append(
            {
                "code": "W_IPSA_LARGE_NO_DOMAIN",
                "message": (
                    f"Large project ({file_count} files) but weak domain "
                    "signal — manual review recommended."
                ),
            }
        )
    return warnings


def _recommend_profile(
    project_profile: dict[str, Any],
    assessment: dict[str, Any],
    detected: list[dict[str, Any]],
) -> tuple[str, str]:
    """Decide profile per 05-profiles-ips §3.2 rubric.

    Returns (profile, reasoning).
    """
    maturity = (
        assessment.get("maturity_level")
        or project_profile.get("doc_maturity", {}).get("level")
        or "UNKNOWN"
    )
    file_count = project_profile.get("file_counts", {}).get("total", 0)

    # Assessment scores may be nested differently; tolerate both shapes.
    scores = assessment.get("scores") or assessment.get("assessment", {})
    if isinstance(scores, dict):
        code_q = (
            scores.get("code_quality", {}).get("score")
            if isinstance(scores.get("code_quality"), dict)
            else scores.get("code_quality")
        )
        doc_q = (
            scores.get("doc_quality", {}).get("score")
            if isinstance(scores.get("doc_quality"), dict)
            else scores.get("doc_quality")
        )
    else:
        code_q = doc_q = None

    code_q = float(code_q) if isinstance(code_q, (int, float)) else 0.0
    doc_q = float(doc_q) if isinstance(doc_q, (int, float)) else 0.0

    strong = [d for d in detected if d["confidence"] >= STRONG_DOMAIN_THRESHOLD]
    moderate = [d for d in detected if d["confidence"] >= 0.6]

    # Maturity-driven fast tracks.
    if maturity == "NEAR_COMPLETE":
        return (
            "surface",
            "Project near-complete per assessment — overview sufficient.",
        )

    # Large or multi-domain → deep.
    if file_count > LARGE_PROJECT_FILES:
        if len(moderate) >= MULTI_DOMAIN_COUNT:
            return (
                "deep",
                f"Large project ({file_count} files) across "
                f"{len(moderate)} moderate+ domains — deep profile "
                "recommended for coverage.",
            )
        return (
            "deep",
            f"Large project ({file_count} files) — deep profile "
            "recommended to handle scale.",
        )

    if len(moderate) >= MULTI_DOMAIN_COUNT:
        names = ", ".join(d["domain"] for d in moderate[:3])
        return (
            "deep",
            f"Multiple domains detected ({names}) — deep profile spans "
            "domain experts.",
        )

    if strong:
        top = strong[0]
        return (
            "deep",
            f"Strong domain signal: {top['domain']} "
            f"(confidence {top['confidence']:.2f}) — deep profile "
            "unlocks domain expert enrichment.",
        )

    if code_q >= 70 and doc_q >= 50:
        return (
            "standard",
            f"Healthy project (code={code_q:.0f}, doc={doc_q:.0f}) — "
            "standard onboarding sufficient.",
        )

    return (
        "standard",
        "Default profile — no strong signals favoring surface/deep.",
    )


def run_phase_a(
    project_profile_path: Path,
    assessment_path: Path,
    output_path: Path,
) -> dict[str, Any]:
    """IPS Phase A — run after L2 Assessment.

    Reads project-profile.json + assessment-report.json, scores domains,
    recommends profile. Writes ips-phase-a.json + returns the dict.
    """
    profile = _read_json(project_profile_path)
    assessment = _read_json(assessment_path)

    pool = load_pool()

    # Domain scoring (EN + VN)
    detected_all = score_domains(profile, inventory=None, pool=pool)
    # top 5 for Phase A
    detected_top = detected_all[:5]

    rec_profile, reasoning = _recommend_profile(profile, assessment, detected_all)

    unresolved = find_unresolved_patterns(profile)
    warnings = _classify_warnings(profile, detected_all)

    result: dict[str, Any] = {
        "$schema": "domain-hints-v1",
        "run_at": _now_iso(),
        "recommended_profile": rec_profile,
        "profile_reasoning": reasoning,
        "detected_domains": detected_top,
        "unresolved_patterns": unresolved,
        "warnings": warnings,
        "user_overrode_profile": False,
    }
    _atomic_write_json(output_path, result)
    return result


# ─── Phase B ─────────────────────────────────────────────────


# Workload profile budgets (minutes) — 05-profiles-ips §1.1 midpoints.
PROFILE_BUDGET_MIN: dict[str, int] = {
    "surface": 10,
    "standard": 35,
    "deep": 75,
    "exhaustive": 150,
}

# Feature density per file (average) per profile depth.
# Used for workload estimate — feature = unit of extraction for business-analyst.
FEATURE_DENSITY_PER_FILE: dict[str, float] = {
    "surface": 0.0,  # no extraction
    "standard": 0.08,
    "deep": 0.12,
    "exhaustive": 0.15,
}

# Time per feature (minutes) per profile.
TIME_PER_FEATURE_MIN: dict[str, float] = {
    "surface": 0.0,
    "standard": 1.5,
    "deep": 2.5,
    "exhaustive": 3.5,
}

# Hotspot coupling percentile cutoff (top 20%).
HOTSPOT_PERCENTILE = 0.80


def _read_inventory_files(inventory_dir: Path) -> dict[str, Any]:
    """Load *.json files from inventory dir into {basename_without_ext: content}."""
    result: dict[str, Any] = {}
    if not inventory_dir.exists():
        return result
    for f in inventory_dir.glob("*.json"):
        try:
            result[f.stem] = _read_json(f)
        except (json.JSONDecodeError, OSError):
            continue
    return result


def _extract_source_file_paths(inventory: dict[str, Any]) -> list[str]:
    src = inventory.get("source-files", {})
    if isinstance(src, dict):
        files = src.get("files", [])
    elif isinstance(src, list):
        files = src
    else:
        files = []
    paths: list[str] = []
    for f in files:
        if isinstance(f, dict):
            p = f.get("path") or f.get("file")
        else:
            p = f
        if isinstance(p, str):
            paths.append(p.replace("\\", "/"))
    return paths


def _cluster_files_by_module(
    file_paths: list[str],
) -> dict[str, list[str]]:
    """Cluster files by their first non-generic directory segment.

    Example: 'src/billing/invoice.ts' → module='billing' (skip 'src').
    """
    GENERIC = {
        "src", "app", "apps", "packages", "lib", "tests", "test",
        "scripts", "public", "dist", "build", "node_modules",
    }
    modules: dict[str, list[str]] = defaultdict(list)
    for p in file_paths:
        parts = p.strip("/").split("/")
        module = None
        for part in parts[:-1]:  # exclude filename
            lower = part.lower()
            if lower and lower not in GENERIC:
                module = lower
                break
        if module is None:
            module = "_root"
        modules[module].append(p)
    return modules


def _compute_coupling(
    module_files: dict[str, list[str]],
    dependency_graph: dict[str, Any] | None,
) -> dict[str, int]:
    """Compute coupling count per module from dependency graph edges.

    Edge types assumed: {"from": "path", "to": "path"} or {"source": ..., "target": ...}.
    Coupling = number of edges crossing module boundary.
    """
    coupling: dict[str, int] = defaultdict(int)
    if not dependency_graph:
        return coupling

    edges = (
        dependency_graph.get("edges")
        or dependency_graph.get("dependencies")
        or []
    )
    if not isinstance(edges, list):
        return coupling

    # Build reverse map: file → module.
    file_to_module: dict[str, str] = {}
    for mod, files in module_files.items():
        for f in files:
            file_to_module[f] = mod

    for e in edges:
        if not isinstance(e, dict):
            continue
        src = e.get("from") or e.get("source") or e.get("src")
        dst = e.get("to") or e.get("target") or e.get("dst")
        if not (isinstance(src, str) and isinstance(dst, str)):
            continue
        src_mod = file_to_module.get(src.replace("\\", "/"))
        dst_mod = file_to_module.get(dst.replace("\\", "/"))
        if src_mod and dst_mod and src_mod != dst_mod:
            coupling[src_mod] += 1
            coupling[dst_mod] += 1
    return coupling


def _find_hotspots(
    module_files: dict[str, list[str]],
    coupling: dict[str, int],
    *,
    percentile: float = HOTSPOT_PERCENTILE,
) -> list[dict[str, Any]]:
    """Hotspot = top N% modules by (file_count, coupling)."""
    modules = list(module_files.keys())
    if not modules:
        return []

    # Compute composite score per module: sum of rank(files) + rank(coupling).
    by_files = sorted(modules, key=lambda m: len(module_files[m]))
    by_coupling = sorted(modules, key=lambda m: coupling.get(m, 0))
    rank_files = {m: i for i, m in enumerate(by_files)}
    rank_coupling = {m: i for i, m in enumerate(by_coupling)}
    composite = {
        m: rank_files[m] + rank_coupling.get(m, 0) for m in modules
    }

    cutoff_rank = math.ceil(len(modules) * percentile)
    sorted_modules = sorted(modules, key=lambda m: composite[m], reverse=True)
    hotspot_names = sorted_modules[: max(1, len(modules) - cutoff_rank) if cutoff_rank < len(modules) else len(modules)]
    # Reliable cutoff: pick top 20% (at least 1).
    top_count = max(1, round(len(modules) * (1 - percentile)))
    hotspot_names = sorted_modules[:top_count]

    return [
        {
            "module": m,
            "files": len(module_files[m]),
            "coupling": coupling.get(m, 0),
        }
        for m in hotspot_names
    ]


ROUTING_MIN_CONFIDENCE = 0.3  # matches VN core keyword base weight


def _route_modules_to_domains(
    module_files: dict[str, list[str]],
    ips_a: dict[str, Any],
    pool: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    """Route each module to its best-match domain via VN/EN keyword scoring.

    For each module, run detect_modules_vn([module_name]) + EN rule matching on
    module name alone. Pick top domain with confidence >= ROUTING_MIN_CONFIDENCE.

    Confidence interpretation (downstream L5 uses these):
    - >= 0.75 strong match → domain-expert spawned with high confidence
    - >= 0.6 moderate → domain-expert spawned
    - >= 0.3 weak → routing info recorded, but L5 may fallback to business-analyst only
    """
    from .domain_scorer import EN_RULES
    from .vietnamese_keywords import detect_modules_vn

    # Expert name lookup.
    expert_map: dict[str, str] = {}
    for dom, data in pool["domains"].items():
        expert_map[dom] = data.get("expert_agent", f"{dom}-expert")

    # Also fill from ips_a detected_domains (catch domains not in VN pool).
    for d in ips_a.get("detected_domains", []):
        expert_map.setdefault(d["domain"], d.get("recommended_expert", f"{d['domain']}-expert"))

    routing: dict[str, dict[str, Any]] = {}
    for module in module_files:
        best: tuple[str, float, str] | None = None  # (domain, confidence, source)

        # VN matching via detect_modules_vn
        vn_sigs = detect_modules_vn([module], pool=pool)
        for s in vn_sigs:
            if best is None or s.confidence > best[1]:
                best = (s.domain, s.confidence, "vn")

        # EN rule matching on module name
        for domain, rules in EN_RULES.items():
            for keyword, weight, _kind in rules:
                kw = keyword.lower()
                if module == kw or (len(kw) >= 3 and kw in module):
                    w = weight if module == kw else weight * 0.7
                    if best is None or w > best[1]:
                        best = (domain, w, "en")

        if best and best[1] >= ROUTING_MIN_CONFIDENCE:
            domain, conf, src = best
            routing[module] = {
                "domain": domain,
                "expert": expert_map.get(domain, f"{domain}-expert"),
                "confidence": round(conf, 4),
                "source": src,
            }

    return routing


def _estimate_workload(
    profile_name: str,
    total_files: int,
    module_count: int,
) -> dict[str, Any]:
    """Estimate features + time per 05-profiles-ips §4."""
    density = FEATURE_DENSITY_PER_FILE.get(profile_name, 0.08)
    time_per = TIME_PER_FEATURE_MIN.get(profile_name, 1.5)
    budget = PROFILE_BUDGET_MIN.get(profile_name, 35)

    features = int(round(total_files * density))
    est_time = int(round(features * time_per))
    soft_cap = int(budget * 1.5)
    ratio = (est_time / budget) if budget else 0.0

    return {
        "total_features_est": features,
        "est_time_min": est_time,
        "soft_cap_min": soft_cap,
        "budget_min": budget,
        "exceeds_cap": est_time > soft_cap,
        "ratio": round(ratio, 2),
        "module_count": module_count,
    }


def _check_workload_gate(
    workload: dict[str, Any],
    module_files: dict[str, list[str]],
    routing: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    """Check workload gate conditions (05-profiles-ips §4.1).

    Returns {triggered, reasons[], plan_required}.
    """
    largest_module = max(
        (len(files) for files in module_files.values()), default=0
    )
    reasons: list[str] = []

    if workload["exceeds_cap"]:
        reasons.append(
            f"est_time ({workload['est_time_min']} min) > "
            f"soft_cap ({workload['soft_cap_min']} min)"
        )
    if workload["total_features_est"] > 100:
        reasons.append(
            f"total_features ({workload['total_features_est']}) > 100"
        )
    if largest_module > 50:
        reasons.append(f"largest_module_files ({largest_module}) > 50")
    if workload["module_count"] > 30:
        reasons.append(f"modules_count ({workload['module_count']}) > 30")

    return {
        "triggered": bool(reasons),
        "reasons": reasons,
        "plan_required": bool(reasons),
        "routing_count": len(routing),
    }


def run_phase_b(
    inventory_dir: Path,
    ips_a_path: Path,
    output_path: Path,
) -> dict[str, Any]:
    """IPS Phase B — run after L3 Inventory.

    Reads inventory/*.json + ips-phase-a.json. Clusters modules, computes
    coupling, identifies hotspots, routes modules → domains, estimates workload.
    """
    inventory = _read_inventory_files(inventory_dir)
    ips_a = _read_json(ips_a_path)

    pool = load_pool()

    file_paths = _extract_source_file_paths(inventory)
    module_files = _cluster_files_by_module(file_paths)
    dep_graph = inventory.get("dependency-graph", {})
    coupling = _compute_coupling(module_files, dep_graph)
    hotspots = _find_hotspots(module_files, coupling)
    routing = _route_modules_to_domains(module_files, ips_a, pool)

    total_files = sum(len(files) for files in module_files.values())
    profile_name = ips_a.get("recommended_profile", "standard")
    workload = _estimate_workload(profile_name, total_files, len(module_files))
    gate = _check_workload_gate(workload, module_files, routing)

    result: dict[str, Any] = {
        "$schema": "ips-phase-b-v1",
        "run_at": _now_iso(),
        "profile_used": profile_name,
        "module_routing": routing,
        "module_count": len(module_files),
        "complexity_hotspots": hotspots,
        "workload_estimate": workload,
        "workload_gate": gate,
    }
    _atomic_write_json(output_path, result)
    return result


# ─── CLI ─────────────────────────────────────────────────────


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ips_recommender",
        description="IPS Recommender 2-phase CLI",
    )
    subparsers = parser.add_subparsers(dest="phase", required=True)

    p_a = subparsers.add_parser("phase_a", help="Run IPS Phase A (after L2 Assessment)")
    p_a.add_argument("--project-profile", required=True, type=Path)
    p_a.add_argument("--assessment", required=True, type=Path)
    p_a.add_argument("--output", required=True, type=Path)

    p_b = subparsers.add_parser("phase_b", help="Run IPS Phase B (after L3 Inventory)")
    p_b.add_argument("--inventory", required=True, type=Path)
    p_b.add_argument("--ips-a", required=True, type=Path)
    p_b.add_argument("--output", required=True, type=Path)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.phase == "phase_a":
        run_phase_a(args.project_profile, args.assessment, args.output)
    elif args.phase == "phase_b":
        run_phase_b(args.inventory, args.ips_a, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
