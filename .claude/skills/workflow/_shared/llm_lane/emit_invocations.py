"""emit_invocations — Emit LLM probe invocations cho orchestrator drive Agent calls.

Phase C v8 wire-up: lane_dispatch (subprocess) KHONG goi duoc Agent tool
(thuoc Claude main loop). Vay subprocess emit JSON list cua "invocations"
ra stdout, orchestrator (Claude) doc roi drive `Agent({subagent_type, prompt})`
calls va save raw output → emit_signals.py parse → lane signals.

Reads:
    - $SESSION_DIR/fix-status.json.flags.llm_scan (must be true)
    - LLM_PROBE_AGENTS catalog (from lane_dispatch)
    - $SESSION_DIR/_meta/stack.json (optional, for stack-aware filtering)

Outputs (stdout JSON array):
    [
      {
        "probe_id": "P-QD2-llm-business-rules",
        "dimension": "QD2",
        "lane": "wf-fix-business",
        "prompt_template": ".../prompts/llm-probe-qd2-business.md",
        "shared_template": ".../prompts/_shared.md",
        "scope": {
          "source_dir": "apps/ | src/ | .",
          "file_globs": ["**/*.ts", "**/*.tsx"],
          "max_files": 50,
          "purpose": "..."
        },
        "output_signals_path": ".../phase4-find-bugs/lanes/QD2-business/llm-signals.json",
        "output_raw_dir": ".../phase4-find-bugs/lanes/QD2-business/llm-raw/",
        "agent_subagent_type": "general-purpose",
        "estimated_cost_usd": 0.30
      },
      ...
    ]

Empty array khi:
    - flags.llm_scan = false
    - profile NOT IN {deep, exhaustive}
    - LLM_PROBE_AGENTS empty (config issue)

Registry role: NONE.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# Stack glob mapping for scope auto-discovery.
STACK_GLOB_MAP: dict[str, list[str]] = {
    "typescript-react":   ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"],
    "typescript-nextjs":  ["**/*.ts", "**/*.tsx"],
    "javascript-react":   ["**/*.js", "**/*.jsx"],
    "vue":                ["**/*.vue", "**/*.ts", "**/*.js"],
    "csharp-dotnet":      ["**/*.cs"],
    "python":             ["**/*.py"],
    "go":                 ["**/*.go"],
    "java":               ["**/*.java"],
    "any":                ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx",
                           "**/*.py", "**/*.go", "**/*.java", "**/*.cs"],
}

# Estimated cost per probe (USD, Sonnet 4.6, ~50K in + 8K out ≈ $0.27).
DEFAULT_COST_USD = 0.30
MAX_FILES_PER_PROBE = 50


def _read_llm_scan_flag(session_dir: Path) -> bool:
    """Doc fix-status.json.flags.llm_scan."""
    fix_status = session_dir / "fix-status.json"
    if not fix_status.is_file():
        return False
    try:
        data = json.loads(fix_status.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return False
    flags = data.get("flags", {}) or {}
    return bool(flags.get("llm_scan", False))


def _read_stack(session_dir: Path) -> tuple[str | None, list[str]]:
    """Doc primary + secondary stacks tu $SESSION_DIR/_meta/stack.json."""
    stack_path = session_dir / "_meta" / "stack.json"
    if not stack_path.is_file():
        return None, []
    try:
        data = json.loads(stack_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None, []
    primary = data.get("primary_stack") or data.get("primary")
    secondary = data.get("secondary_stacks") or data.get("secondary") or []
    if isinstance(primary, str) and isinstance(secondary, list):
        return primary, [s for s in secondary if isinstance(s, str)]
    return None, []


def _detect_source_dir(repo_root: Path) -> str:
    """Auto-detect project source root. Match lane_dispatch._detect_source_dir."""
    if (repo_root / "apps").is_dir():
        return "apps"
    if (repo_root / "src").is_dir():
        return "src"
    return "."


def _stack_glob(primary: str | None) -> list[str]:
    """Map primary stack → file globs."""
    if primary and primary in STACK_GLOB_MAP:
        return STACK_GLOB_MAP[primary]
    return STACK_GLOB_MAP["any"]


def _is_probe_applicable(
    *,
    applicable_stacks: tuple[str, ...],
    primary: str | None,
    secondary: list[str],
) -> bool:
    """Stack-aware filter — same logic as lane_dispatch._is_probe_applicable_for_stack."""
    if "any" in applicable_stacks:
        return True
    if primary is not None and primary in applicable_stacks:
        return True
    return any(s in applicable_stacks for s in secondary)


def _qd_to_lane(dim: str) -> str:
    """QD → lane folder mapping (matches wf-fix-merge-non-static-probes.sh)."""
    mapping = {
        "QD1": "wf-fix-functional",
        "QD2": "wf-fix-business",
        "QD3": "wf-fix-security",
        "QD4": "wf-fix-performance",
        "QD5": "wf-fix-ux-a11y",
        "QD6": "wf-fix-data",
        "QD7": "wf-fix-compat",
        "QD8": "wf-fix-observability",
        "QD9": "wf-fix-runtime-health",
        "QD10": "wf-fix-integration",
        "QD11": "wf-fix-business-completeness",
    }
    return mapping.get(dim, f"wf-fix-{dim.lower()}")


def emit_invocations(
    *,
    session_dir: Path,
    profile: str,
    dims_filter: list[str] | None = None,
    repo_root: Path | None = None,
) -> list[dict[str, Any]]:
    """Compute danh sach invocations.

    Empty list khi: llm_scan flag = false, profile not in {deep, exhaustive},
    hoac khong probe nao apply.
    """
    if profile not in ("deep", "exhaustive"):
        return []

    if not _read_llm_scan_flag(session_dir):
        return []

    repo_root = repo_root or Path.cwd()
    primary, secondary = _read_stack(session_dir)
    file_globs = _stack_glob(primary)
    source_dir_rel = _detect_source_dir(repo_root)

    # Lazy import — avoid pulling lane_dispatch dependencies at module load.
    # lane_dispatch.LLM_PROBE_AGENTS la single source of truth.
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    try:
        from lane_dispatch import LLM_PROBE_AGENTS, LLMProbeSpec  # noqa: F401
    except ImportError as exc:
        print(f"[emit_invocations] cannot import LLM_PROBE_AGENTS: {exc}", file=sys.stderr)
        return []

    skills_workflow_dir = Path(__file__).resolve().parent.parent.parent
    orchestrator_prompts = skills_workflow_dir / "wf-fix-bugs" / "prompts"
    shared_template = orchestrator_prompts / "_shared.md"

    invocations: list[dict[str, Any]] = []
    for probe_id, spec in LLM_PROBE_AGENTS.items():
        # Profile gating
        # spec.profile_min default "deep" → both deep + exhaustive pass.
        if spec.profile_min == "exhaustive" and profile != "exhaustive":
            continue

        # Stack filter
        if not _is_probe_applicable(
            applicable_stacks=spec.applicable_stacks,
            primary=primary,
            secondary=secondary,
        ):
            continue

        # Dimension filter (if user passed --dims)
        if dims_filter and not any(d in dims_filter for d in spec.dimensions):
            continue

        lane_prompts_dir = skills_workflow_dir / spec.lane_skill / "prompts"
        prompt_template = lane_prompts_dir / spec.prompt_file
        if not prompt_template.is_file():
            print(
                f"[emit_invocations] WARN: prompt missing for {probe_id}: {prompt_template}",
                file=sys.stderr,
            )
            continue

        # 1 invocation per unique probe_id.
        # Cross-cutting probes (>1 dim) → output ra lanes/cross/{probe_id}/.
        # Merge stage dispatch signals theo signal.dimension_id.
        is_cross_cutting = len(spec.dimensions) > 1
        if is_cross_cutting:
            output_dir = session_dir / "lanes" / "cross" / probe_id
            primary_dim = "cross"
            primary_lane = "cross-cutting"
        else:
            primary_dim = spec.dimensions[0]
            primary_lane = _qd_to_lane(primary_dim)
            output_dir = session_dir / "lanes" / primary_dim

        invocations.append({
            "probe_id": probe_id,
            "dimension": primary_dim,
            "dimensions": list(spec.dimensions),
            "lane": primary_lane,
            "is_cross_cutting": is_cross_cutting,
            "prompt_template": str(prompt_template).replace("\\", "/"),
            "shared_template": str(shared_template).replace("\\", "/"),
            "scope": {
                "source_dir": source_dir_rel,
                "file_globs": file_globs,
                "max_files": MAX_FILES_PER_PROBE,
                "purpose": spec.description,
            },
            "output_signals_path": str(output_dir / "llm-signals.json").replace("\\", "/"),
            "output_raw_dir": str(output_dir / "llm-raw").replace("\\", "/"),
            "agent_subagent_type": "general-purpose",
            "estimated_cost_usd": DEFAULT_COST_USD,
        })

    return invocations


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Emit LLM probe invocations for orchestrator")
    parser.add_argument("--session-dir", required=True, type=Path)
    parser.add_argument("--profile", required=True,
                        choices=("quick", "standard", "deep", "exhaustive"))
    parser.add_argument("--dims", help="Comma-separated dimensions filter (e.g., QD1,QD2)")
    parser.add_argument("--repo-root", type=Path, default=Path.cwd(),
                        help="Repo root for source dir detection")
    args = parser.parse_args(argv)

    if not args.session_dir.is_dir():
        print(f"[emit_invocations ERROR] session-dir not found: {args.session_dir}", file=sys.stderr)
        return 1

    dims_filter: list[str] | None = None
    if args.dims:
        dims_filter = [d.strip() for d in args.dims.split(",") if d.strip()]

    invocations = emit_invocations(
        session_dir=args.session_dir,
        profile=args.profile,
        dims_filter=dims_filter,
        repo_root=args.repo_root,
    )

    print(json.dumps(invocations, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
