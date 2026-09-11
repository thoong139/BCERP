#!/usr/bin/env python3
"""lane_dispatch.py — Orchestrate parallel lane execution với token_bucket + backpressure.

Vai trò:
    Dispatch dimension lanes (QD1-QD11) cho wf-fix-bugs v6+ engine. Mỗi lane
    chạy probes theo profile, ghi signals.json riêng vào lanes/{DIM}/.
    Hỗ trợ parallel execution (max_parallel) với CORE-025 isolation.

Registry role: NONE. Chỉ ghi vào $SESSION_DIR/lanes/{DIM}/.

Tham chiếu:
    - ADR-02: utility module
    - ADR-17: concurrency model
    - ADR-22 rule 6: QD3 KHÔNG BAO GIỜ cache
    - CORE-025: song song an toàn (write scope tách biệt)
    - Stage E5 spec: docs/design/skills/wf-fix-bugs/prompts/stage-E-prompt.md
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import subprocess
import sys
import tempfile
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# F06.007 (Sprint 6 v10.3): Standard logging thay print(file=sys.stderr) cho
# status/progress logs. Level configurable via env LANE_DISPATCH_LOG_LEVEL
# (default INFO). Output đi qua stderr handler — backward-compat với existing
# CI capture của stderr; nhưng giờ filterable theo level.
_logger = logging.getLogger(__name__)
if not _logger.handlers:
    _handler = logging.StreamHandler(sys.stderr)
    _handler.setFormatter(logging.Formatter("%(message)s"))
    _logger.addHandler(_handler)
    _level_name = os.environ.get("LANE_DISPATCH_LOG_LEVEL", "INFO").upper()
    _logger.setLevel(getattr(logging, _level_name, logging.INFO))
    _logger.propagate = False

from dimension_registry import (
    get_cache_policy,
    get_lane_path,
    validate_lane_exists,
)
from profile_resolver import resolve_probes
from scan_cache.cache_lookup import lookup as cache_lookup_fn
from scan_cache.cache_store import set_entry as cache_store_fn
from scan_cache.fingerprint import compute_fingerprint, hash_file_content

# Concurrency (optional — graceful degrade neu import fail)
try:
    from concurrency.token_bucket import TokenBucket3Tier  # noqa: F401
    _TB_AVAILABLE = True
except ImportError:
    _TB_AVAILABLE = False
    TokenBucket3Tier = None  # type: ignore

try:
    from concurrency.backpressure import AdaptiveBackpressure  # noqa: F401
    _BP_AVAILABLE = True
except ImportError:
    _BP_AVAILABLE = False
    AdaptiveBackpressure = None  # type: ignore

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

MAX_RETRIES_PER_LANE: int = 3
SIGNALS_SCHEMA_ID: str = "lane-signals-v1"

# Task 2 — Auto-scale probe timeout theo codebase size.
#
# Trên Windows Git Bash, subprocess.run(timeout=...) gọi proc.kill() chỉ
# TerminateProcess() process bash chính, không kill child tree (grep/find).
# Defense-in-depth: probe scripts gọi `with_runtime_cap "$@"` (xem
# .claude/scripts/wf-fix-common.sh) — bash re-exec dưới GNU `timeout` →
# SIGTERM toàn bộ tree → exit 143. Cap được pass qua env
# `WF_FIX_PROBE_MAX_RUNTIME_SEC` (set bởi Python ngay trước subprocess.run).
#
# Tier (codebase symbol_count → bash inner cap seconds):
#   <10k   → 300s  (small project)
#   10k-50k  → 600s  (legacy default)
#   50k-100k → 1200s (medium monorepo)
#   >100k   → 1800s (large monorepo, vd EUREKA-2026 ~127k+ symbols)
# Hard absolute max 7200s (2h) để tránh hang vĩnh viễn trên codebase cực lớn.
# Python outer cap = bash cap + 60s buffer (Python phải lớn hơn để bash timeout fire trước).
#
# User override: WF_FIX_PROBE_MAX_RUNTIME_SEC từ env luôn thắng auto-scale
# (clip về ABSOLUTE_MAX_PROBE_CAP_SEC để không vượt 2h).
ABSOLUTE_MAX_PROBE_CAP_SEC: int = 7200
PYTHON_TIMEOUT_BUFFER_SEC: int = 60
# Tier table: (max_symbol_count_inclusive, bash_cap_seconds). Sentinel cuối = +∞.
_PROBE_CAP_TIERS: tuple[tuple[int, int], ...] = (
    (10_000, 600),
    (50_000, 1200),
    (100_000, 2400),
    (sys.maxsize, 3600),
)
# Backward compat: external readers còn refer PROBE_TIMEOUT_SEC.
# Giữ alias = max possible Python outer cap (3660s) — chỉ dùng làm fallback nếu
# resolve_probe_timeouts() crash (defensive). Auto-scale bypass biến này.
PROBE_TIMEOUT_SEC: int = ABSOLUTE_MAX_PROBE_CAP_SEC + PYTHON_TIMEOUT_BUFFER_SEC

# Phase B (v8 Coverage Improvement) — Stack-Aware Probe Registry.
# Mỗi probe có applicable_stacks list. Probe không match stack target → no-op.
# "any" = applicable cho mọi stack (cross-stack probes như xref, secret-detection).
@dataclass(frozen=True)
class ProbeSpec:
    """Spec cho 1 static probe."""
    script: str
    applicable_stacks: tuple[str, ...]  # frozen tuple cho immutability
    dimensions: tuple[str, ...]
    profile_min: str = "standard"  # quick/standard/deep/exhaustive — minimum profile to run


# Stack identifiers must match stack_detector.KNOWN_STACKS.
# "any" is sentinel meaning "applicable to any detected stack".
PROBE_REGISTRY: dict[str, ProbeSpec] = {
    # QD1 Functional
    "P-QD1-req-registry-xref": ProbeSpec(
        script="wf-fix-probe-static-xref.sh",
        applicable_stacks=("any",),  # cross-stack — chỉ check REQ-ID comments
        dimensions=("QD1",),
    ),
    "P-QD1-react-contract-check": ProbeSpec(
        script="wf-fix-probe-static-react.sh",
        applicable_stacks=("typescript-react", "typescript-nextjs", "javascript-react"),
        dimensions=("QD1",),
    ),
    # QD2 Business Logic
    # Fix #6: P-QD2-business-logic-audit removed — phantom entry không có trong dimension.json
    # và probe script reject ID này. Valid IDs: P-QD2-calculation-check, P-QD2-hardcoded-value-detect.
    "P-QD2-hardcoded-value-detect": ProbeSpec(
        script="wf-fix-probe-static-business.sh",
        applicable_stacks=("any",),
        dimensions=("QD2",),
    ),
    "P-QD2-calculation-check": ProbeSpec(
        script="wf-fix-probe-static-business.sh",
        applicable_stacks=("any",),
        dimensions=("QD2",),
    ),
    # QD3 Security
    "P-QD3-secret-detection": ProbeSpec(
        script="wf-fix-probe-static-secret.sh",
        applicable_stacks=("any",),  # secret patterns are stack-agnostic
        dimensions=("QD3",),
    ),
    # QD4 Performance
    "P-QD4-bundle-size-audit": ProbeSpec(
        script="wf-fix-probe-static-perf.sh",
        applicable_stacks=("typescript-react", "typescript-nextjs", "javascript-react", "vue"),
        dimensions=("QD4",),
    ),
    # QD5 UX/A11y
    "P-QD5-aria-attribute-scan": ProbeSpec(
        script="wf-fix-probe-static-a11y.sh",
        applicable_stacks=("typescript-react", "typescript-nextjs", "javascript-react", "vue"),
        dimensions=("QD5",),
    ),
    # QD6 Data Integrity
    "P-QD6-data-integrity-audit": ProbeSpec(
        script="wf-fix-probe-static-data.sh",
        applicable_stacks=("any",),
        dimensions=("QD6",),
    ),
    # QD7 Compatibility
    "P-QD7-deprecated-api-usage": ProbeSpec(
        script="wf-fix-probe-static-deprecated.sh",
        applicable_stacks=("any",),
        dimensions=("QD7",),
    ),
    "P-QD7-i18n-key-audit": ProbeSpec(
        script="wf-fix-probe-static-deprecated.sh",  # i18n logic embedded in deprecated script
        applicable_stacks=("typescript-react", "typescript-nextjs", "javascript-react", "vue"),
        dimensions=("QD7",),
    ),
    # B.3 — New stack-specific probes
    "P-QD1-python-endpoint-check": ProbeSpec(
        script="wf-fix-probe-static-python.sh",
        applicable_stacks=("python-fastapi", "python-django"),
        dimensions=("QD1",),
    ),
    "P-QD2-python-orm-nplus1": ProbeSpec(
        script="wf-fix-probe-static-python.sh",
        applicable_stacks=("python-fastapi", "python-django"),
        dimensions=("QD2",),
    ),
    "P-QD1-vue-composition-check": ProbeSpec(
        script="wf-fix-probe-static-vue.sh",
        applicable_stacks=("vue",),
        dimensions=("QD1",),
    ),
    "P-QD7-vue-i18n-key-audit": ProbeSpec(
        script="wf-fix-probe-static-vue.sh",
        applicable_stacks=("vue",),
        dimensions=("QD7",),
    ),
    "P-QD1-go-error-wrap-check": ProbeSpec(
        script="wf-fix-probe-static-go.sh",
        applicable_stacks=("go",),
        dimensions=("QD1",),
    ),
    "P-QD3-go-sql-injection": ProbeSpec(
        script="wf-fix-probe-static-go.sh",
        applicable_stacks=("go",),
        dimensions=("QD3",),
    ),
    # MAJOR-10 fix v9.0.3: dong cac orphan probe scripts (truoc do co script
    # nhung khong co PROBE_REGISTRY entry → write-ownership contract khong
    # bao ve duoc signals khoi merge overwrite).
    "P-QD1-infra-preflight": ProbeSpec(
        script="wf-fix-probe-static-infra-preflight.sh",
        applicable_stacks=("any",),
        dimensions=("QD1",),
    ),
    "P-QD1-route-config-parse": ProbeSpec(
        script="wf-fix-probe-static-route.sh",
        applicable_stacks=("any",),
        dimensions=("QD1",),
    ),
    "P-QD3-sast-scan": ProbeSpec(
        script="wf-fix-probe-static-sast.sh",
        applicable_stacks=("any",),
        dimensions=("QD3",),
    ),
    "P-QD3-dependency-vuln-scan": ProbeSpec(
        script="wf-fix-probe-static-depvuln.sh",
        applicable_stacks=("any",),
        dimensions=("QD3",),
    ),
    "P-QD6-orm-model-sync": ProbeSpec(
        script="wf-fix-probe-static-orm.sh",
        applicable_stacks=("any",),
        dimensions=("QD6",),
    ),
    "P-QD6-schema-drift-detect": ProbeSpec(
        script="wf-fix-probe-static-schema-drift.sh",
        applicable_stacks=("any",),
        dimensions=("QD6",),
    ),
}


# Backward-compat: derive STATIC_PROBE_SCRIPTS from PROBE_REGISTRY.
# Probes NOT in this map are runtime/agent type — orchestrator (Claude) phải
# spawn agent để execute (xem phase1-engine.md §"Probe Execution by Agent").
STATIC_PROBE_SCRIPTS: dict[str, str] = {
    pid: spec.script for pid, spec in PROBE_REGISTRY.items()
}


def _is_probe_applicable_for_stack(probe_id: str, primary_stack: str | None,
                                    secondary_stacks: list[str] | None = None) -> bool:
    """Check if probe applies to detected stack(s).

    Returns:
        True if probe.applicable_stacks contains "any" or matches detected stack(s).
        True (default) if probe_id not in registry (legacy/runtime probe).
        True if no stack info available (stack=None) — fail open, run probe anyway.
    """
    spec = PROBE_REGISTRY.get(probe_id)
    if spec is None:
        return True  # Legacy/runtime probe — let orchestrator handle
    if "any" in spec.applicable_stacks:
        return True
    if primary_stack is None:
        return True  # No detection — fail open, don't silently skip
    if primary_stack in spec.applicable_stacks:
        return True
    if secondary_stacks:
        for s in secondary_stacks:
            if s in spec.applicable_stacks:
                return True
    return False


def _load_stack_from_session(session_dir: Path) -> tuple[str | None, list[str]]:
    """Load primary + secondary stacks từ $SESSION_DIR/stack-info.json.

    Returns:
        (primary_stack, secondary_stacks). (None, []) if missing/invalid.
    """
    stack_info_path = session_dir / "stack-info.json"
    if not stack_info_path.is_file():
        return None, []
    try:
        with stack_info_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        primary = data.get("primary_stack")
        if primary == "unknown":
            primary = None
        secondary = data.get("secondary_stacks", [])
        if not isinstance(secondary, list):
            secondary = []
        return primary, secondary
    except (json.JSONDecodeError, OSError):
        return None, []


# ──────────────────────────────────────────────────────────────────────
# Phase C v8 — LLM-Augmented Scan Lane (opt-in via --llm-scan)
# ──────────────────────────────────────────────────────────────────────
@dataclass(frozen=True)
class LLMProbeSpec:
    """Spec cho 1 LLM probe."""
    prompt_file: str          # relative to lane_skill/prompts/
    applicable_stacks: tuple[str, ...]
    dimensions: tuple[str, ...]
    lane_skill: str = "wf-fix-bugs"  # sub-skill folder chứa prompts/ (default: orchestrator)
    profile_min: str = "deep"  # quick/standard/deep/exhaustive — chỉ run từ deep+
    description: str = ""


# Catalog of LLM probes — invoke khi --llm-scan + profile in {deep, exhaustive}.
LLM_PROBE_AGENTS: dict[str, LLMProbeSpec] = {
    "P-QD1-llm-functional-audit": LLMProbeSpec(
        prompt_file="llm-probe-qd1-functional.md",
        lane_skill="wf-fix-functional",
        applicable_stacks=("any",),
        dimensions=("QD1",),
        description="Null deref, off-by-one, edge cases, race conditions, state mutation",
    ),
    "P-QD2-llm-business-rules": LLMProbeSpec(
        prompt_file="llm-probe-qd2-business.md",
        lane_skill="wf-fix-business",
        applicable_stacks=("any",),
        dimensions=("QD2",),
        description="Business rule consistency, state machine, calculations, cross-entity (most important)",
    ),
    "P-QD3-llm-security-review": LLMProbeSpec(
        prompt_file="llm-probe-qd3-security.md",
        lane_skill="wf-fix-security",
        applicable_stacks=("any",),
        dimensions=("QD3",),
        description="Auth bypass, IDOR, mass assignment, deserialization, sensitive logging",
    ),
    "P-QD4-llm-performance-audit": LLMProbeSpec(
        prompt_file="llm-probe-qd4-performance.md",
        lane_skill="wf-fix-performance",
        applicable_stacks=("any",),
        dimensions=("QD4",),
        description="N+1, memory leaks, blocking I/O, inefficient algorithms, re-renders",
    ),
    "P-QD5-llm-ux-review": LLMProbeSpec(
        prompt_file="llm-probe-qd5-ux-a11y.md",
        lane_skill="wf-fix-ux-a11y",
        applicable_stacks=("typescript-react", "typescript-nextjs", "javascript-react", "vue"),
        dimensions=("QD5",),
        description="Loading/error/empty states, UX flow, keyboard nav, copy clarity",
    ),
    "P-QD6-llm-data-integrity": LLMProbeSpec(
        prompt_file="llm-probe-qd6-data-integrity.md",
        lane_skill="wf-fix-data",
        applicable_stacks=("any",),
        dimensions=("QD6",),
        description="Transaction boundaries, FK constraints, race conditions, optimistic locking",
    ),
    "P-QD7-llm-compatibility": LLMProbeSpec(
        prompt_file="llm-probe-qd7-compatibility.md",
        lane_skill="wf-fix-compat",
        applicable_stacks=("any",),
        dimensions=("QD7",),
        description="Browser compat, polyfill, i18n, locale-specific, SSR mismatch, deprecated API",
    ),
    "P-QD8-llm-observability": LLMProbeSpec(
        prompt_file="llm-probe-qd8-observability.md",
        lane_skill="wf-fix-observability",
        applicable_stacks=("any",),
        dimensions=("QD8",),
        description="Reliability gaps (CB, retry, timeout, graceful degradation), observability (logs/metrics/traces/alerts), health-check, graceful shutdown (v8.2 → v2.0)",
    ),
    "P-QD9-llm-runtime-health": LLMProbeSpec(
        prompt_file="llm-probe-qd9-runtime-health.md",
        lane_skill="wf-fix-runtime-health",
        applicable_stacks=("typescript-react", "typescript-nextjs", "javascript-react", "vue"),
        dimensions=("QD9",),
        description="Error boundaries, unhandled rejections, route guards, CTA double-submit, browser API feature detection, form client-side validation, SPA navigation (v1.0)",
    ),
    "P-QD10-llm-integration": LLMProbeSpec(
        prompt_file="llm-probe-qd10-integration.md",
        lane_skill="wf-fix-integration",
        applicable_stacks=("any",),
        dimensions=("QD10",),
        description="Cross-module reference drift, API contract violations, event handler coverage, orphan FK references, multi-platform entity sync, state machine cross-module, auth matrix violations (v1.0)",
    ),
    "P-QD11-cross-module-comparison": LLMProbeSpec(
        prompt_file="llm-probe-qd11-cross-module.md",
        lane_skill="wf-fix-business-completeness",
        applicable_stacks=("any",),
        dimensions=("QD11",),
        description="Pass 1: Cross-module pattern comparison — entity forms, lists, workflows, actions (v1.0)",
    ),
    "P-QD11-domain-heuristic": LLMProbeSpec(
        prompt_file="llm-probe-qd11-domain-heuristic.md",
        lane_skill="wf-fix-business-completeness",
        applicable_stacks=("any",),
        dimensions=("QD11",),
        description="Pass 2: Domain heuristic analysis — mandatory fields, compliance checks, audit trail, business rules (deep+ only, v1.0)",
    ),
    "P-QD11-registry-gap": LLMProbeSpec(
        prompt_file="llm-probe-qd11-registry-gap.md",
        lane_skill="wf-fix-business-completeness",
        applicable_stacks=("any",),
        dimensions=("QD11",),
        description="Pass 3: Registry gap detection — unimplemented reqs, orphan REQ-IDs, missing FEAT-ID mappings (v1.0)",
    ),
    # v8.1 — Cross-cutting probes (multi-dim / post-fix).
    # CRIT-4 fix v9.0.3: dimensions mo rong sang QD1-QD10 (truoc do hardcode QD1-QD8 lo cho QD9/QD10
    # — la tan du cua v9.0.0 fantasy completion bug). QD10 cross-module integration la dimension
    # noi tai cho integration-bugs probe; QD9 runtime health la candidate cho regression-verify.
    "P-LLM-integration-bugs": LLMProbeSpec(
        prompt_file="llm-probe-integration.md",
        applicable_stacks=("any",),
        dimensions=("QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"),
        description="Cross-dimension integration bugs span >=2 dims/modules (race FE+BE+DB, auth+cache+replica combo, multi-tenant leak, cross-module entity sync)",
    ),
    "P-LLM-regression-verify": LLMProbeSpec(
        prompt_file="llm-probe-regression.md",
        applicable_stacks=("any",),
        dimensions=("QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"),
        profile_min="deep",
        description="Post-fix regression verification — phat hien fix scope creep, side effects, band-aid, symptom suppression",
    ),
}


def _llm_scan_enabled(session_dir: Path) -> bool:
    """Check if --llm-scan opt-in từ fix-status.json.flags.llm_scan."""
    fix_status_path = session_dir / "fix-status.json"
    if not fix_status_path.is_file():
        return False
    try:
        with fix_status_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        flags = data.get("flags", {}) or {}
        return bool(flags.get("llm_scan", False))
    except (json.JSONDecodeError, OSError):
        return False


def _llm_probe_applicable(probe_id: str, profile: str, session_dir: Path) -> tuple[bool, str]:
    """Check if LLM probe should run.

    Returns:
        (should_run, reason). reason="" if yes, else explanation for skip.
    """
    spec = LLM_PROBE_AGENTS.get(probe_id)
    if spec is None:
        return False, f"probe {probe_id} not in LLM_PROBE_AGENTS registry"

    # Profile gating: chỉ deep/exhaustive
    if profile not in ("deep", "exhaustive"):
        return False, f"LLM probes require profile=deep|exhaustive (current: {profile})"

    # Opt-in flag check
    if not _llm_scan_enabled(session_dir):
        return False, "--llm-scan flag not enabled"

    # Stack filter
    primary, secondary = _load_stack_from_session(session_dir)
    if not _is_probe_applicable_for_stack(probe_id, primary, secondary):
        # Stack-aware filter applies to LLM probes via shared logic — cần bổ sung registry mapping.
        # For LLM probes, fall back to direct check on LLM_PROBE_AGENTS spec.
        if "any" not in spec.applicable_stacks:
            if primary is not None and primary not in spec.applicable_stacks:
                if not any(s in spec.applicable_stacks for s in secondary):
                    return False, f"stack {primary} not in applicable_stacks {spec.applicable_stacks}"

    return True, ""


# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass
class LaneResult:
    """Kết quả thực thi 1 lane."""

    dim: str
    status: str  # "completed" | "failed" | "skipped"
    probes_executed: int
    signals_path: Path | None
    error: str | None = None


@dataclass
class DispatchResult:
    """Kết quả tổng hợp của toàn bộ dispatch."""

    lanes: list[LaneResult]
    completed: int
    failed: int
    signals_paths: dict[str, Path]


# ──────────────────────────────────────────────────────────────────────
# Lane execution (single dimension)
# ──────────────────────────────────────────────────────────────────────


def _execute_lane_sequential(
    dim: str,
    session_dir: Path,
    profile: str,
    workflow_root: Path,
    use_cache: bool = False,
) -> LaneResult:
    """Thực thi 1 lane: resolve probes → execute → collect signals.

    Logic:
        1. Resolve probes via profile_resolver
        2. Create lane dir: $SESSION_DIR/lanes/{DIM}/
        3. Check cache policy (QD3 → skip cache)
        4. For each probe: execute (read .md, run SENSE→THINK→ACT→VERIFY)
        5. Collect signals → $SESSION_DIR/lanes/{DIM}/signals.json
        6. POST-GATE T1-T4

    Returns:
        LaneResult với status + signals_path.
    """
    lane_dir = session_dir / "lanes" / dim
    lane_dir.mkdir(parents=True, exist_ok=True)
    signals_path = lane_dir / "signals.json"

    # 1. Resolve probes
    dim_config = get_lane_path(dim, workflow_root)
    dimension_json = dim_config / "dimension.json"

    if not dimension_json.exists():
        return LaneResult(
            dim=dim, status="failed", probes_executed=0,
            signals_path=None, error=f"dimension.json not found: {dimension_json}",
        )

    try:
        probe_ids = resolve_probes(dimension_json, profile)
    except (FileNotFoundError, ValueError) as exc:
        return LaneResult(
            dim=dim, status="failed", probes_executed=0,
            signals_path=None, error=str(exc),
        )

    # 2. Cache policy check (ADR-22 Rule 6)
    cache_allowed = get_cache_policy(dim)
    cache_root = session_dir / "cache" / "probes"

    # 3. Execute probes — trong thực tế Agent tool sẽ gọi probes
    signals: list[dict[str, Any]] = []
    probes_executed = 0

    for probe_id in probe_ids:
        cache_hit = False
        cached_signals: list[dict[str, Any]] = []
        probe_fp: str | None = None
        probe_dim_sha: str | None = None

        if cache_allowed and use_cache:
            # Fingerprint based on dimension.json — cache is per (probe, config)
            dim_config_path = dim_config / "dimension.json"
            if dim_config_path.exists():
                probe_dim_sha = hash_file_content(dim_config_path)
                probe_fp = compute_fingerprint(
                    probe_id=probe_id,
                    probe_version="1.0.0",
                    file_path=str(dim_config_path),
                    file_content_sha=probe_dim_sha,
                )
                entry = cache_lookup_fn(cache_root, probe_fp, probe_dim_sha)
                if entry is not None:
                    cached_signals = entry.signals_emitted
                    cache_hit = True

        if cache_hit:
            signals.extend(cached_signals)
            probes_executed += 1
            continue

        # Static probe execution: nếu probe_id có script tương ứng trong
        # STATIC_PROBE_SCRIPTS → invoke trực tiếp. Runtime/agent probes vẫn cần
        # orchestrator (Claude) gọi qua Agent tool ngoài lane_dispatch.
        probe_signals: list[dict[str, Any]] = _execute_static_probe(
            probe_id=probe_id,
            session_dir=session_dir,
            workflow_root=workflow_root,
            profile=profile,
            lane_name=dim_config.name,
        )
        signals.extend(probe_signals)
        probes_executed += 1

        # Cache store — luôn store kể cả empty (negative cache)
        if cache_allowed and use_cache and probe_fp is not None:
            try:
                cache_store_fn(
                    cache_root=cache_root,
                    fingerprint=probe_fp,
                    probe_id=probe_id,
                    probe_version="1.0.0",
                    file_path=str(dim_config_path),
                    file_content_sha=probe_dim_sha,
                    signals=probe_signals,
                )
            except ValueError:
                pass  # ADR-22 rule 6 defense-in-depth

    # 4. Write signals.json — A1 MERGE-PRESERVE (không OVERWRITE):
    # Chỉ thay thế signals của static probes (đã chạy trong run này),
    # GIỮ NGUYÊN signals của non-static / LLM probes đã APPEND trước đó
    # (qua signal-emit.md helper hoặc merge_signals.py). Bảo vệ data loss
    # khi --resume hoặc retry POST-GATE.
    # B2 (v8.2.2) — Schema unification: bổ sung lane, session_id, session_dir
    # đầy đủ để khớp với template signals.json + POST-GATE T2.2 enforce.
    new_envelope: dict[str, Any] = {
        "$schema": SIGNALS_SCHEMA_ID,
        "lane": dim_config.name,
        "dimension": dim,
        "session_id": session_dir.name,
        "session_dir": str(session_dir),
        "profile": profile,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "probes_executed": probes_executed,
        "cache_policy": "allowed" if cache_allowed else "never",
        "signals": signals,
    }
    static_probe_ids = set(STATIC_PROBE_SCRIPTS.keys())
    # B1 (v8.2.2) — File-level lock bao quanh toàn bộ Read-Modify-Write
    # để tránh race với signal-emit.md và merge_signals.py concurrent writers.
    locked = _signals_lock_acquire(signals_path)
    try:
        merged_envelope, preserved_count, replaced_count = _merge_static_signals(
            signals_path=signals_path,
            new_envelope=new_envelope,
            static_probe_ids=static_probe_ids,
        )
        if preserved_count > 0 or replaced_count > 0:
            _logger.info(
                "[lane_dispatch] %s merge: preserved=%d non-static, "
                "replaced=%d static, new_static=%d → total=%d",
                dim, preserved_count, replaced_count,
                len(signals), len(merged_envelope.get('signals', [])),
            )
        _atomic_write_json(signals_path, merged_envelope)
    finally:
        if locked:
            _signals_lock_release(signals_path)

    # B3 (2026-05-09) — Đồng bộ lane-status.json.totals.signals_emitted với
    # số signals THỰC TẾ trong file (bao gồm cả non-static signals đã append).
    # Tránh POST-GATE T3.3 fail giả khi `signal-emit.md` không phải nguồn duy
    # nhất viết signals (lane_dispatch + non-static probes cùng góp).
    _sync_lane_status_totals(
        lane_dir=signals_path.parent,
        signals=merged_envelope.get("signals", []),
        probes_executed=probes_executed,
    )

    # 5. POST-GATE T1-T2
    ok, errors = _post_gate_lane(signals_path)
    if not ok:
        return LaneResult(
            dim=dim, status="failed", probes_executed=probes_executed,
            signals_path=None, error="; ".join(errors),
        )

    return LaneResult(
        dim=dim, status="completed", probes_executed=probes_executed,
        signals_path=signals_path,
    )


def _detect_source_dir(repo_root: Path) -> str:
    """Auto-detect project source root để pass cho static probe scripts.

    Default fallback "src/" hợp với project layout phổ biến nhưng không hợp
    với monorepo (có "apps/"). Detect theo thứ tự: apps/ → src/ → .
    """
    if (repo_root / "apps").is_dir():
        return "apps"
    if (repo_root / "src").is_dir():
        return "src"
    return "."


# ──────────────────────────────────────────────────────────────────────
# Task 2 — Auto-scale probe timeout: codebase size resolver + tier mapper
# ──────────────────────────────────────────────────────────────────────

# Source file extensions để fallback count khi ISG snapshot missing.
# Liệt kê đầy đủ stack hỗ trợ + một số stack phụ phổ biến trong monorepo.
_SOURCE_EXTENSIONS: frozenset[str] = frozenset({
    ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
    ".cs", ".cshtml", ".razor",
    ".py",
    ".go",
    ".vue",
    ".java", ".kt",
    ".rs", ".rb", ".php",
})

# Skip dirs khi walk source tree (vendored / build artifacts / VCS / IDE).
_SKIP_DIRS: frozenset[str] = frozenset({
    "node_modules", "bin", "obj", ".next", ".nuxt", "dist", "build",
    "__pycache__", ".git", "vendor", "target", ".venv", "venv",
    ".idea", ".vs", "coverage", "out",
})

# Cap-cứng để fallback walk không treo trên codebase pathological.
_MAX_FILE_COUNT_SAFETY_LIMIT: int = 500_000

# Avg symbols per source file — convert file_count → symbol_count estimate
# khi fallback (ISG snapshot missing). Calibrated for typical monorepo
# (TypeScript/C#/Python ~20-30 symbols/file). EUREKA-2026 verified:
# 6290 files in apps/ × 20 = 125k ≈ GitNexus 176k symbols (đặt ở tier >100k).
# Conservative lean toward higher tier vì cost của under-scaling (timeout
# silent fail) >> over-scaling (probe finish nhanh hơn).
_FALLBACK_SYMBOLS_PER_FILE: int = 20

# Cache module-level: tránh re-walk cây source mỗi lần spawn probe.
# Key: (session_dir_str, source_root_str). Value: estimated symbol_count (int).
_CODEBASE_SIZE_CACHE: dict[tuple[str, str], int] = {}


def _read_symbol_count_from_isg(session_dir: Path) -> int | None:
    """Đọc symbol_count từ $SESSION_DIR/_meta/isg-snapshot.json nếu có.

    Returns:
        int >=0 nếu file tồn tại + parse OK + có field symbol_count.
        None nếu file missing / invalid / field thiếu (caller fallback file count).
    """
    snapshot = session_dir / "_meta" / "isg-snapshot.json"
    if not snapshot.is_file():
        return None
    try:
        with snapshot.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
        sc = data.get("symbol_count") if isinstance(data, dict) else None
        if isinstance(sc, int) and sc >= 0:
            return sc
    except (json.JSONDecodeError, OSError):
        pass
    return None


def _count_source_files(source_root: Path) -> int:
    """Đếm source files trong source_root (skip vendored/build dirs).

    Fallback khi isg-snapshot.json missing. Walk 1 lần, in-place prune
    skip-dirs để giảm IO. Cap _MAX_FILE_COUNT_SAFETY_LIMIT để không treo
    trên codebase pathological.
    """
    if not source_root.is_dir():
        return 0
    count = 0
    for root, dirs, files in os.walk(source_root):
        # In-place prune: bỏ skip-dirs + dot-dirs (.git, .venv, .vs, ...)
        dirs[:] = [d for d in dirs if d not in _SKIP_DIRS and not d.startswith(".")]
        for fname in files:
            ext = os.path.splitext(fname)[1].lower()
            if ext in _SOURCE_EXTENSIONS:
                count += 1
                if count >= _MAX_FILE_COUNT_SAFETY_LIMIT:
                    return count
    return count


def _resolve_codebase_size(session_dir: Path, source_root: Path) -> int:
    """Resolve estimated symbol_count. Cached.

    1. ISG snapshot present + valid → return raw symbol_count.
    2. Fallback: file_count × _FALLBACK_SYMBOLS_PER_FILE (estimate).

    Tier table luôn so sánh trên symbol-scale → multiplier ép fallback
    về cùng đơn vị để tier mapping nhất quán.
    """
    key = (str(session_dir), str(source_root))
    cached = _CODEBASE_SIZE_CACHE.get(key)
    if cached is not None:
        return cached
    size = _read_symbol_count_from_isg(session_dir)
    if size is None:
        size = _count_source_files(source_root) * _FALLBACK_SYMBOLS_PER_FILE
    _CODEBASE_SIZE_CACHE[key] = size
    return size


def _resolve_probe_timeouts(
    session_dir: Path,
    source_root: Path,
) -> tuple[int, int, int, bool]:
    """Tính timeouts cho 1 probe call dựa trên codebase size + user override.

    Order:
      1. Nếu env WF_FIX_PROBE_MAX_RUNTIME_SEC set + parse OK → user override
         thắng. Clip về ABSOLUTE_MAX_PROBE_CAP_SEC để không vượt 1h.
      2. Auto-scale theo tier table _PROBE_CAP_TIERS dựa trên codebase size.

    Returns:
        (bash_cap_sec, python_timeout_sec, codebase_size, is_user_override).
        codebase_size = -1 nếu user override (skip resolve để tiết kiệm IO).
    """
    user_override_raw = os.environ.get("WF_FIX_PROBE_MAX_RUNTIME_SEC")
    if user_override_raw:
        try:
            user_cap = int(user_override_raw.strip())
            if user_cap > 0:
                bash_cap = min(user_cap, ABSOLUTE_MAX_PROBE_CAP_SEC)
                python_timeout = bash_cap + PYTHON_TIMEOUT_BUFFER_SEC
                return bash_cap, python_timeout, -1, True
        except ValueError:
            pass  # invalid override → fall through to auto-scale

    size = _resolve_codebase_size(session_dir, source_root)
    bash_cap = _PROBE_CAP_TIERS[-1][1]  # default last tier
    for threshold, tier_cap in _PROBE_CAP_TIERS:
        if size < threshold:
            bash_cap = tier_cap
            break
    bash_cap = min(bash_cap, ABSOLUTE_MAX_PROBE_CAP_SEC)
    python_timeout = bash_cap + PYTHON_TIMEOUT_BUFFER_SEC
    return bash_cap, python_timeout, size, False


_BASH_BIN_CACHE: str | None = None
_BASH_PATH_PREFIX_CACHE: str | None = None


def _detect_bash_binary() -> str:
    """Chọn bash binary tốt nhất cho subprocess (cache module-level).

    Trên Windows, Python `subprocess.run(["bash", ...])` thường spawn WSL2 bash
    (Linux mount: /mnt/d/, không có jq nếu chưa cài). Chuyển sang Git Bash MINGW
    (đi kèm jq, sha256sum, etc.) cho đúng môi trường mà các probe scripts kỳ vọng.

    Order ưu tiên:
        1. $WF_FIX_BASH_PATH (user override, dạng absolute path)
        2. C:/Program Files/Git/bin/bash.exe (Git Bash wrapper)
        3. C:/Program Files/Git/usr/bin/bash.exe (Git Bash msys binary)
        4. "bash" (PATH lookup fallback — có thể là WSL2 hoặc Linux native)
    """
    global _BASH_BIN_CACHE
    if _BASH_BIN_CACHE is not None:
        return _BASH_BIN_CACHE
    override = os.environ.get("WF_FIX_BASH_PATH")
    candidates = []
    if override:
        candidates.append(override)
    candidates.extend([
        r"C:\Program Files\Git\bin\bash.exe",
        r"C:\Program Files\Git\usr\bin\bash.exe",
    ])
    for cand in candidates:
        if Path(cand).exists():
            _BASH_BIN_CACHE = cand
            return _BASH_BIN_CACHE
    _BASH_BIN_CACHE = "bash"
    return _BASH_BIN_CACHE


def _detect_bash_drive_prefix() -> str:
    """Hỏi chính bash binary đã chọn để biết drive prefix đúng.

    WSL2 mount Windows drive ở /mnt/<letter>; Git Bash MINGW ở /<letter>.
    Trả về "/mnt/" hoặc "/" — cache module-level để không probe nhiều lần.
    """
    global _BASH_PATH_PREFIX_CACHE
    if _BASH_PATH_PREFIX_CACHE is not None:
        return _BASH_PATH_PREFIX_CACHE
    bash_bin = _detect_bash_binary()
    try:
        proc = subprocess.run(
            [bash_bin, "-c", "[ -d /mnt/c ] && echo /mnt/ || echo /"],
            capture_output=True, text=True, timeout=10, encoding="utf-8", errors="replace",
        )
        out = (proc.stdout or "").strip()
        _BASH_PATH_PREFIX_CACHE = out if out in ("/mnt/", "/") else "/"
    except (OSError, subprocess.TimeoutExpired):
        _BASH_PATH_PREFIX_CACHE = "/"
    return _BASH_PATH_PREFIX_CACHE


def _to_bash_path(p: Path) -> str:
    """Convert Windows path → POSIX path mà bash subprocess hiểu được.

    Path("D:/foo/bar") → "/d/foo/bar" (Git Bash MINGW) hoặc "/mnt/d/foo/bar" (WSL2).
    Drive prefix dựa trên bash binary được chọn (xem _detect_bash_binary).
    Trên Linux/macOS không có drive letter → trả về as_posix() trực tiếp.
    """
    posix = p.as_posix()
    if len(posix) >= 2 and posix[1] == ":":
        drive = posix[0].lower()
        return _detect_bash_drive_prefix() + drive + posix[2:]
    return posix


def _execute_static_probe(
    *,
    probe_id: str,
    session_dir: Path,
    workflow_root: Path,
    profile: str,
    lane_name: str,
) -> list[dict[str, Any]]:
    """Execute a static probe script và parse JSON output.

    Returns:
        signals[] from probe stdout. Empty list nếu probe không phải static
        hoặc execution fail. Failures được LOG ra stderr + ghi vào
        $SESSION_DIR/lanes/{DIM}/probe-failures.log để aggregator/POST-GATE
        có thể detect (fix #3 — chống silent false-positive khi probe timeout).
    """
    script_name = STATIC_PROBE_SCRIPTS.get(probe_id)
    if not script_name:
        return []

    # Phase B v8 — Stack-Aware Filter.
    # Skip probe nếu detected stack không match applicable_stacks.
    # Fail-open: nếu stack-info.json missing → vẫn run probe (avoid silent skip).
    primary_stack, secondary_stacks = _load_stack_from_session(session_dir)
    if not _is_probe_applicable_for_stack(probe_id, primary_stack, secondary_stacks):
        return []

    # workflow_root = .claude/skills/workflow → repo_root = workflow_root.parent.parent.parent
    # Scripts ở repo_root / .claude / scripts /
    repo_root = workflow_root.parent.parent.parent
    script_path = repo_root / ".claude" / "scripts" / script_name
    if not script_path.exists():
        return []

    source_dir = os.environ.get("WF_FIX_SOURCE_DIR") or _detect_source_dir(repo_root)

    # Task 2 — auto-scale probe timeout theo codebase size.
    # User override env (WF_FIX_PROBE_MAX_RUNTIME_SEC) thắng. Pass cap qua env
    # để bash `with_runtime_cap` re-exec dưới `timeout $cap`. Python outer
    # timeout = bash cap + buffer (đảm bảo bash fire trước Python).
    bash_cap, python_timeout, codebase_size, is_user_override = _resolve_probe_timeouts(
        session_dir=session_dir,
        source_root=repo_root / source_dir,
    )
    if is_user_override:
        size_label = "user_override"
    else:
        size_label = f"codebase_size={codebase_size}"
    _logger.info(
        "[lane_dispatch] probe=%s timeout_cap=%ds python_timeout=%ds %s",
        probe_id, bash_cap, python_timeout, size_label,
    )
    probe_env = {**os.environ, "WF_FIX_PROBE_MAX_RUNTIME_SEC": str(bash_cap)}

    # Dùng Git Bash binary trên Windows (đi kèm jq) thay vì WSL2 bash từ PATH.
    # Path style POSIX phải khớp với bash đã chọn (Git Bash: "/d/...", WSL2: "/mnt/d/...").
    cmd = [
        _detect_bash_binary(), _to_bash_path(script_path),
        "--session-dir", _to_bash_path(session_dir),
        "--lane", lane_name,
        "--probe", probe_id,
        "--profile", profile,
        "--source-dir", source_dir,
    ]

    failure_reason: str | None = None
    proc_returncode: int | None = None
    proc_stderr: str = ""

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=python_timeout,
            cwd=str(repo_root),
            env=probe_env,
        )
        proc_returncode = proc.returncode
        proc_stderr = (proc.stderr or "")[:1000]
    except subprocess.TimeoutExpired:
        failure_reason = f"python_timeout (cap={python_timeout}s, bash_cap={bash_cap}s)"
        _log_probe_failure(session_dir, lane_name, probe_id, failure_reason, "", -1)
        return []
    except OSError as exc:
        failure_reason = f"os_error: {exc}"
        _log_probe_failure(session_dir, lane_name, probe_id, failure_reason, "", -1)
        return []

    # Detect timeout via bash `timeout` wrapper: exit 124 (default) or 143 (SIGTERM)
    # or 137 (SIGKILL) or 141 (SIGPIPE). All indicate non-success.
    if proc_returncode != 0:
        # Tag known timeout exit codes for clearer diagnosis.
        if proc_returncode in (124, 137, 141, 143):
            failure_reason = f"bash_timeout (exit={proc_returncode}, cap={bash_cap}s hit)"
        else:
            failure_reason = f"non_zero_exit (exit={proc_returncode})"
        _log_probe_failure(session_dir, lane_name, probe_id, failure_reason, proc_stderr, proc_returncode)
        return []

    if not proc.stdout or not proc.stdout.strip():
        failure_reason = "empty_stdout"
        _log_probe_failure(session_dir, lane_name, probe_id, failure_reason, proc_stderr, proc_returncode or 0)
        return []
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        failure_reason = f"json_decode_error: {exc}"
        _log_probe_failure(session_dir, lane_name, probe_id, failure_reason, proc_stderr, proc_returncode or 0)
        return []
    if not isinstance(data, dict):
        failure_reason = f"invalid_json_type (expected dict, got {type(data).__name__})"
        _log_probe_failure(session_dir, lane_name, probe_id, failure_reason, proc_stderr, proc_returncode or 0)
        return []
    out_signals = data.get("signals", [])
    if not isinstance(out_signals, list):
        failure_reason = "signals_not_list"
        _log_probe_failure(session_dir, lane_name, probe_id, failure_reason, proc_stderr, proc_returncode or 0)
        return []
    # Defense: keep only dict-typed signals
    return [s for s in out_signals if isinstance(s, dict)]


def _log_probe_failure(
    session_dir: Path,
    lane_name: str,
    probe_id: str,
    reason: str,
    stderr_snippet: str,
    returncode: int,
) -> None:
    """Log probe failure ra stderr + persist to disk (fix #3).

    Ghi 1 dòng JSON Lines vào $SESSION_DIR/probe-failures.log để aggregator
    detect được "no signals" KHÔNG phải vì healthy mà vì probe broken.
    """
    import sys
    _logger.error(
        "[lane_dispatch] PROBE_FAILURE lane=%s probe=%s reason=%s exit=%d",
        lane_name, probe_id, reason, returncode,
    )
    if stderr_snippet:
        _logger.error("  stderr: %s", stderr_snippet[:500])

    try:
        log_path = session_dir / "probe-failures.log"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        record = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "lane": lane_name,
            "probe_id": probe_id,
            "reason": reason,
            "returncode": returncode,
            "stderr_snippet": stderr_snippet[:500],
        }
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")
    except Exception:
        pass  # never fail caller


# F06.004 (Sprint 6 v10.3): Lock TTL tuning + heartbeat.
#   - SIGNALS_LOCK_STALE_SEC giảm 300→60. Probe write < 5s typical;
#     5-phút stale window quá lớn so với session 30s, dẫn đến writer
#     crash → lock giữ 5 phút → block consecutive lanes.
#   - HEARTBEAT_INTERVAL_SEC refresh mtime mỗi 20s khi giữ lock dài (rare
#     case probe trung bình > 1 phút) để tránh false-positive stale takeover.
#   - Configurable qua env LANE_DISPATCH_LOCK_STALE_SEC + LANE_DISPATCH_LOCK_HEARTBEAT_SEC.
import threading

SIGNALS_LOCK_STALE_SEC: int = int(os.environ.get("LANE_DISPATCH_LOCK_STALE_SEC", "60"))
LOCK_HEARTBEAT_INTERVAL_SEC: int = int(os.environ.get("LANE_DISPATCH_LOCK_HEARTBEAT_SEC", "20"))

# Heartbeat threads per signals_path (keyed by lock_dir str).
_lock_heartbeats: dict[str, threading.Timer] = {}


def _heartbeat_touch(lock_dir: Path) -> None:
    """Refresh lock_dir mtime để tránh false-positive stale takeover.

    Schedule next touch via Timer (recursive). Cancel khi release.
    """
    if not lock_dir.exists():
        return
    try:
        os.utime(lock_dir, None)
    except OSError:
        pass
    # Re-schedule
    timer = threading.Timer(
        LOCK_HEARTBEAT_INTERVAL_SEC, _heartbeat_touch, args=(lock_dir,)
    )
    timer.daemon = True  # KHÔNG block process exit
    _lock_heartbeats[str(lock_dir)] = timer
    timer.start()


def _signals_lock_acquire(
    signals_path: Path,
    timeout_sec: int = 30,
    stale_sec: int | None = None,
) -> bool:
    """B1 (v8.2.2) + F06.004 — Acquire file-level lock for signals.json.

    Convention: ``<signals_path>.lock/`` directory (mkdir-based POSIX atomic).
    Compatible với bash helper ``acquire_signals_lock`` ở wf-fix-common.sh —
    cùng path convention nên 2 process khác ngôn ngữ chia sẻ được.

    Stale takeover: nếu ``.lock/`` directory mtime > ``stale_sec`` →
    rmdir + retry (writer crash). Default stale_sec=60 (Sprint 6, giảm
    từ 300s gốc — aligned với typical probe write duration <5s).

    Heartbeat: sau acquire thành công, background thread refresh lock_dir
    mtime mỗi LOCK_HEARTBEAT_INTERVAL_SEC giây — tránh false-positive
    stale khi probe dài > stale_sec.

    Returns:
        True nếu acquire thành công trong timeout, False nếu timeout.
    """
    if stale_sec is None:
        stale_sec = SIGNALS_LOCK_STALE_SEC
    lock_dir = signals_path.with_suffix(signals_path.suffix + ".lock")
    waited = 0
    while waited < timeout_sec:
        # Stale takeover
        if lock_dir.exists():
            try:
                age = time.time() - lock_dir.stat().st_mtime
            except OSError:
                age = 0
            if age > stale_sec:
                _logger.warning(
                    "[lane_dispatch] stale signals lock (age=%ds > %ds), "
                    "taking over: %s",
                    int(age), stale_sec, lock_dir,
                )
                try:
                    lock_dir.rmdir()
                except OSError:
                    # Re-mkdir failure dưới — best effort
                    pass

        try:
            lock_dir.parent.mkdir(parents=True, exist_ok=True)
            lock_dir.mkdir()
            # F06.004: Start heartbeat refresher khi acquire thành công.
            timer = threading.Timer(
                LOCK_HEARTBEAT_INTERVAL_SEC, _heartbeat_touch, args=(lock_dir,)
            )
            timer.daemon = True
            _lock_heartbeats[str(lock_dir)] = timer
            timer.start()
            return True
        except FileExistsError:
            time.sleep(1)
            waited += 1
        except OSError as exc:
            _logger.error(
                "[lane_dispatch] signals lock OS error: %s (%s)", exc, lock_dir,
            )
            return False

    _logger.error(
        "[lane_dispatch] signals lock timeout (%ds) for %s",
        timeout_sec, signals_path,
    )
    return False


def _signals_lock_release(signals_path: Path) -> None:
    """Release signals lock (idempotent). Cancel heartbeat timer nếu có."""
    lock_dir = signals_path.with_suffix(signals_path.suffix + ".lock")
    # F06.004: Cancel heartbeat thread trước khi rmdir (tránh race với touch).
    timer = _lock_heartbeats.pop(str(lock_dir), None)
    if timer is not None:
        timer.cancel()
    try:
        lock_dir.rmdir()
    except (FileNotFoundError, OSError):
        pass


def _atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    """Ghi JSON atomic: tempfile + fsync + os.replace."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_fd, tmp_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent),
    )
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as fh:
            # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
            json.dump(data, fh, indent=2, ensure_ascii=False, sort_keys=True)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_name, path)
    except Exception:
        try:
            if os.path.exists(tmp_name):
                os.unlink(tmp_name)
        except OSError:
            pass
        raise


def _atomic_write_signals_locked(signals_path: Path, data: dict[str, Any]) -> None:
    """B1 (v8.2.2) — Atomic write signals.json with file-level lock.

    Wrapper combine ``_signals_lock_acquire`` + ``_atomic_write_json`` +
    ``_signals_lock_release``. Dùng cho mọi write site cho signals.json
    trong lane_dispatch.py + merge_signals.py.

    Lock failure → fallback to non-locked atomic write + WARNING (best-effort,
    không break pipeline; race vẫn có thể xảy ra nhưng đã có A1 merge defense).
    """
    locked = _signals_lock_acquire(signals_path)
    try:
        _atomic_write_json(signals_path, data)
    finally:
        if locked:
            _signals_lock_release(signals_path)


def _read_existing_signals(signals_path: Path) -> dict[str, Any] | None:
    """Đọc signals.json hiện hữu nếu valid. Trả None nếu missing/parse-fail.

    Dùng để A1 MERGE-PRESERVE: lane_dispatch chỉ thay thế signals của static
    probe (probe_id ∈ STATIC_PROBE_SCRIPTS), GIỮ NGUYÊN signals của non-static
    probe đã được APPEND qua signal-emit.md trước đó (tránh data loss khi
    --resume hoặc retry).
    """
    if not signals_path.exists() or signals_path.stat().st_size == 0:
        return None
    try:
        raw = signals_path.read_text(encoding="utf-8")
        data = json.loads(raw)
        if not isinstance(data, dict):
            return None
        if not isinstance(data.get("signals"), list):
            return None
        return data
    except (json.JSONDecodeError, OSError):
        return None


def _merge_static_signals(
    *,
    signals_path: Path,
    new_envelope: dict[str, Any],
    static_probe_ids: set[str],
) -> tuple[dict[str, Any], int, int]:
    """Merge static signals mới với non-static signals hiện hữu.

    Logic A1 (chống overwrite):
      1. Đọc signals.json hiện hữu (nếu có).
      2. Tách existing.signals[] thành 2 nhóm theo probe_id:
         - static_existing (probe_id ∈ static_probe_ids): SẼ BỊ THAY bằng new
         - preserved (non-static + LLM): GIỮ NGUYÊN
      3. Concat preserved + new_envelope.signals → final signals[]
      4. Preserve các fields từ existing (lane, session_id, session_dir,
         llm_merged*, cross_signals_count) nếu có.

    Returns:
        (merged_envelope, preserved_count, replaced_count)
        preserved_count = số signals non-static được giữ
        replaced_count = số signals static cũ bị thay
    """
    existing = _read_existing_signals(signals_path)
    if existing is None:
        # File mới hoặc invalid → trả new_envelope như cũ
        return new_envelope, 0, 0

    existing_signals = existing.get("signals", []) or []
    preserved: list[dict[str, Any]] = []
    replaced_count = 0
    for sig in existing_signals:
        if not isinstance(sig, dict):
            continue
        probe_id = sig.get("probe_id", "")
        if probe_id in static_probe_ids:
            replaced_count += 1
        else:
            preserved.append(sig)

    # Concat: preserved (non-static) + new (static)
    merged_signals = preserved + (new_envelope.get("signals", []) or [])

    # Merge envelope: ưu tiên fields từ new_envelope (probes_executed mới),
    # nhưng preserve các fields chỉ có trong existing (lane, session_id,
    # session_dir, llm_merged*, cross_signals_count).
    PRESERVE_FIELDS = (
        "lane", "session_id", "session_dir",
        "llm_merged", "llm_merged_at", "llm_signals_count",
        "cross_signals_count", "llm_dedup_dropped",
    )
    merged_envelope = dict(new_envelope)
    for field in PRESERVE_FIELDS:
        if field in existing and field not in merged_envelope:
            merged_envelope[field] = existing[field]

    merged_envelope["signals"] = merged_signals
    return merged_envelope, len(preserved), replaced_count


def _sync_lane_status_totals(
    *,
    lane_dir: Path,
    signals: list[dict[str, Any]],
    probes_executed: int,
) -> None:
    """B3 (2026-05-09) — Cập nhật lane-status.json.totals.signals_emitted +
    signals_by_severity từ signals THỰC TẾ trong file (không chỉ static).

    Lý do: lane_dispatch + non-static probe agents + LLM merge cùng góp
    signals vào signals.json. Trước B3 chỉ `signal-emit.md` increment
    counter → POST-GATE T3.3 fail giả vì counter không khớp signals.length.

    Idempotent: gọi nhiều lần đều cho cùng giá trị (totals dựa vào file).
    Best-effort: lỗi đọc/ghi không fail caller (caller có flow riêng).
    """
    lane_status_path = lane_dir / "lane-status.json"
    if not lane_status_path.exists():
        return  # PRE-GATE chưa khởi tạo (khi lane_dispatch chạy độc lập)

    try:
        existing = json.loads(lane_status_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return  # corrupt — để POST-GATE T2 báo lỗi rõ ràng

    if not isinstance(existing, dict):
        return

    sev_counts: dict[str, int] = {
        "critical": 0, "high": 0, "medium": 0, "low": 0, "info": 0,
    }
    for sig in signals:
        if not isinstance(sig, dict):
            continue
        sev = str(sig.get("severity", "")).lower()
        if sev in sev_counts:
            sev_counts[sev] += 1

    totals = existing.get("totals") or {}
    if not isinstance(totals, dict):
        totals = {}
    totals["signals_emitted"] = len(signals)
    totals["signals_by_severity"] = sev_counts
    prev_probes_run = int(totals.get("probes_run", 0) or 0)
    totals["probes_run"] = max(prev_probes_run, int(probes_executed))
    existing["totals"] = totals

    try:
        _atomic_write_json(lane_status_path, existing)
    except OSError:
        return  # best-effort


def _post_gate_lane(signals_path: Path) -> tuple[bool, list[str]]:
    """POST-GATE T1-T2 cho lane signals.json.

    T1: file exists + non-empty
    T2: JSON parse OK + has $schema + signals[] (array)
    """
    errors: list[str] = []

    # T1
    if not signals_path.exists():
        return False, [f"T1: {signals_path} không tồn tại"]
    if signals_path.stat().st_size == 0:
        return False, [f"T1: {signals_path} rỗng"]

    # T2
    try:
        raw = signals_path.read_text(encoding="utf-8")
        data = json.loads(raw)
    except (json.JSONDecodeError, OSError) as exc:
        return False, [f"T2: JSON parse fail: {exc}"]

    if not isinstance(data, dict):
        return False, ["T2: root phải là object"]
    if data.get("$schema") != SIGNALS_SCHEMA_ID:
        errors.append(f"T2: $schema phải là '{SIGNALS_SCHEMA_ID}'")
    if not isinstance(data.get("signals"), list):
        errors.append("T2: signals phải là array")

    return len(errors) == 0, errors


# ──────────────────────────────────────────────────────────────────────
# Async dispatch — parallel lanes
# ──────────────────────────────────────────────────────────────────────


def _lane_already_complete(signals_path: Path) -> tuple[bool, int]:
    """C2 (v8.2.2) — Check signals.json đã pass POST-GATE chưa.

    Module-level helper dùng bởi cả ``_run_lane_async`` (A3 retry guard) và
    ``dispatch_lanes_async`` (C2 module-level skip — không submit task khi
    lane đã đầy đủ signals, tiết kiệm semaphore slot + spawn cost).

    Returns:
        (already_complete, probes_executed)
        already_complete=True nghĩa là file tồn tại + POST-GATE T1-T2 pass.
    """
    if not signals_path.exists():
        return False, 0
    ok, _errors = _post_gate_lane(signals_path)
    if not ok:
        return False, 0
    try:
        existing_data = json.loads(signals_path.read_text(encoding="utf-8"))
        probes_executed = int(existing_data.get("probes_executed", 0))
    except (json.JSONDecodeError, OSError, ValueError):
        probes_executed = 0
    return True, probes_executed


async def _run_lane_async(
    dim: str,
    session_dir: Path,
    profile: str,
    workflow_root: Path,
    use_cache: bool,
    semaphore: asyncio.Semaphore,
    token_bucket: "TokenBucket3Tier | None" = None,
    backpressure: "AdaptiveBackpressure | None" = None,
) -> LaneResult:
    """Run 1 lane trong semaphore slot. Retry max 3 lần.

    A3 (2026-05-09): Idempotent guard — trước mỗi attempt, kiểm tra
    signals.json hiện hữu đã pass POST-GATE chưa. Nếu rồi → skip retry,
    trả completed luôn (tránh re-execute probes làm overwrite signals
    đã có và tốn token cho non-static probes phải re-spawn).
    """
    signals_path = session_dir / "lanes" / dim / "signals.json"

    for attempt in range(1, MAX_RETRIES_PER_LANE + 1):
        # A3 — Pre-attempt idempotent check (delegated to _lane_already_complete)
        already, probes_executed = _lane_already_complete(signals_path)
        if already:
            _logger.info(
                "[lane_dispatch] %s idempotent skip — signals.json valid "
                "(attempt=%d, probes_executed=%d)",
                dim, attempt, probes_executed,
            )
            return LaneResult(
                dim=dim, status="completed", probes_executed=probes_executed,
                signals_path=signals_path,
            )

        # Acquire token bucket trước khi vào semaphore slot
        tb_ctx = None
        if token_bucket is not None:
            try:
                tb_ctx = token_bucket.acquire(
                    lane_id=dim,
                    probe_id=dim,
                    timeout_ms=15_000,
                )
                await tb_ctx.__aenter__()
            except Exception:
                tb_ctx = None  # Graceful degrade

        try:
            if backpressure is not None:
                try:
                    await backpressure.pre_wait()
                    backpressure.start()
                except Exception:
                    pass  # Graceful degrade

            async with semaphore:
                result = _execute_lane_sequential(
                    dim=dim,
                    session_dir=session_dir,
                    profile=profile,
                    workflow_root=workflow_root,
                    use_cache=use_cache,
                )
        finally:
            if backpressure is not None:
                try:
                    backpressure.end()
                except Exception:
                    pass
            if tb_ctx is not None:
                try:
                    await tb_ctx.__aexit__(None, None, None)
                except Exception:
                    pass

        if result.status == "completed":
            return result
        if attempt < MAX_RETRIES_PER_LANE:
            await asyncio.sleep(0.1 * attempt)  # Simple backoff

    return result  # Return last failure


async def dispatch_lanes_async(
    session_dir: Path,
    dimensions: list[str],
    profile: str,
    workflow_root: Path,
    max_parallel: int = 3,
    use_cache: bool = False,
    enable_concurrency: bool = False,
) -> DispatchResult:
    """Dispatch lanes song song (async), trả về aggregated result.

    Per dimension:
      1. Resolve probes via profile_resolver
      2. Create lane dir: $SESSION_DIR/lanes/{DIM}/
      3. Check cache policy (QD3 → skip cache)
      4. Execute probes
      5. Collect signals → $SESSION_DIR/lanes/{DIM}/signals.json
      6. POST-GATE T1-T2 per lane

    Returns:
        DispatchResult với lanes + signals_paths.
    """
    # C2 (v8.2.2) — Module-level skip: pre-filter lanes đã hoàn thành để
    # KHÔNG submit task vào semaphore. Tiết kiệm spawn cost + giải phóng
    # slot cho lanes thực sự chưa chạy. Khác A3 (retry-loop guard ở per-lane
    # level) — đây là gate trước cả khi gather().
    pre_completed: list[LaneResult] = []
    pending_dims: list[str] = []
    for dim in dimensions:
        signals_path = session_dir / "lanes" / dim / "signals.json"
        already, probes_executed = _lane_already_complete(signals_path)
        if already:
            _logger.info(
                "[lane_dispatch] %s module-level skip — signals.json valid "
                "(probes_executed=%d)",
                dim, probes_executed,
            )
            pre_completed.append(LaneResult(
                dim=dim, status="completed", probes_executed=probes_executed,
                signals_path=signals_path,
            ))
        else:
            pending_dims.append(dim)

    semaphore = asyncio.Semaphore(max_parallel)

    # Concurrency primitives (wired defensively — graceful degrade on failure)
    token_bucket = None
    backpressure = None
    if enable_concurrency and _TB_AVAILABLE:
        try:
            token_bucket = TokenBucket3Tier()
        except Exception:
            pass
    if enable_concurrency and _BP_AVAILABLE:
        try:
            backpressure = AdaptiveBackpressure(
                registry_path=session_dir / "issue-registry.json"
            )
        except Exception:
            pass

    tasks = [
        _run_lane_async(dim, session_dir, profile, workflow_root, use_cache,
                        semaphore, token_bucket, backpressure)
        for dim in pending_dims
    ]
    spawned_results = await asyncio.gather(*tasks) if tasks else []
    lane_results = pre_completed + list(spawned_results)

    signals_paths: dict[str, Path] = {}
    completed = 0
    failed = 0
    for r in lane_results:
        if r.status == "completed":
            completed += 1
            if r.signals_path is not None:
                signals_paths[r.dim] = r.signals_path
        else:
            failed += 1

    return DispatchResult(
        lanes=list(lane_results),
        completed=completed,
        failed=failed,
        signals_paths=signals_paths,
    )


# ──────────────────────────────────────────────────────────────────────
# Sync wrapper — dùng từ non-async code (CLI, SKILL.md orchestration)
# ──────────────────────────────────────────────────────────────────────


def dispatch_lanes(
    session_dir: Path,
    dimensions: list[str],
    profile: str,
    workflow_root: Path,
    max_parallel: int = 3,
    use_cache: bool = False,
) -> dict[str, Path]:
    """Sync wrapper: dispatch lanes, trả về {dimension: signals.json_path}.

    Per dimension:
      1. Resolve probes via profile_resolver
      2. Create lane dir: $SESSION_DIR/lanes/{DIM}/
      3. Check cache policy (QD3 → skip cache)
      4. Execute probes
      5. Collect signals → $SESSION_DIR/lanes/{DIM}/signals.json
      6. POST-GATE T1-T2 per lane

    Returns:
        Dict ánh xạ dimension → signals.json path.

    Raises:
        ValueError: dimensions rỗng hoặc profile không hợp lệ.
    """
    if not dimensions:
        raise ValueError("dispatch_lanes: dimensions không được rỗng")

    # Normalize session_dir to absolute path early.
    # Callers cd into _shared/ before invoking us, so relative session_dir
    # paths resolve from the wrong cwd. repo_root = workflow_root/../../..
    if not session_dir.is_absolute():
        repo_root = workflow_root.parent.parent.parent
        session_dir = (repo_root / session_dir).resolve()
    else:
        session_dir = session_dir.resolve()

    # Nếu max_parallel <= 1 hoặc chỉ 1 dimension → chạy sequential
    if max_parallel <= 1 or len(dimensions) == 1:
        results: dict[str, Path] = {}
        for dim in dimensions:
            result = _execute_lane_sequential(
                dim=dim,
                session_dir=session_dir,
                profile=profile,
                workflow_root=workflow_root,
                use_cache=use_cache,
            )
            if result.status == "completed" and result.signals_path:
                results[dim] = result.signals_path
        return results

    # Parallel: chạy async event loop.
    # Windows ProactorEventLoop guard: kiểm tra xem đang trong async context không
    # để tránh RuntimeError("asyncio.run() cannot be called from a running event loop").
    try:
        asyncio.get_running_loop()
        # Đã trong async context → không thể asyncio.run() → fallback về sequential
        # (caller nên dùng dispatch_lanes_async trực tiếp trong async context)
        results_seq: dict[str, Path] = {}
        for dim in dimensions:
            result = _execute_lane_sequential(
                dim=dim,
                session_dir=session_dir,
                profile=profile,
                workflow_root=workflow_root,
                use_cache=use_cache,
            )
            if result.status == "completed" and result.signals_path:
                results_seq[dim] = result.signals_path
        return results_seq
    except RuntimeError:
        # Không có running loop → an toàn để asyncio.run()
        pass

    dispatch_result = asyncio.run(
        dispatch_lanes_async(
            session_dir=session_dir,
            dimensions=dimensions,
            profile=profile,
            workflow_root=workflow_root,
            max_parallel=max_parallel,
            use_cache=use_cache,
        )
    )
    return dispatch_result.signals_paths


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: dispatch lanes cho dimensions."""
    import argparse

    parser = argparse.ArgumentParser(description="Lane Dispatch")
    parser.add_argument("--session-dir", required=True, type=Path)
    parser.add_argument("--dims", required=True, nargs="+", help="Dimensions (QD1 QD3 ...)")
    parser.add_argument("--profile", default="standard", choices=["quick", "standard", "deep", "exhaustive"])
    parser.add_argument("--workflow-root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--max-parallel", type=int, default=3)
    parser.add_argument("--use-cache", action="store_true")
    args, unknown = parser.parse_known_args(argv)
    if unknown:
        print(f"[lane_dispatch WARNING] Unknown arguments ignored: {unknown}", file=sys.stderr)

    try:
        result = dispatch_lanes(
            session_dir=args.session_dir,
            dimensions=args.dims,
            profile=args.profile,
            workflow_root=args.workflow_root,
            max_parallel=args.max_parallel,
            use_cache=args.use_cache,
        )
        for dim, path in sorted(result.items()):
            print(f"{dim}: {path}")
        return 0
    except (ValueError, RuntimeError) as exc:
        print(f"[lane_dispatch ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
