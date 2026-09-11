#!/usr/bin/env python3
"""signal_aggregator.py — Aggregate signals từ lane-local signals.json → master issue-registry.json.

Vai trò:
    Đọc tất cả lane signals.json (từ lanes/{DIM}/), aggregate qua SignalBus
    thành issue-registry.json tổng hợp. Dedup theo (dimension, file_path, line_range, symbol).

Registry role: NONE. Chỉ ghi vào $SESSION_DIR/issue-registry.json.

Tham chiếu:
    - ADR-02: utility module
    - CORE-025: song song an toàn
    - Stage E6 spec: docs/design/skills/wf-fix-bugs/prompts/stage-E-prompt.md
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from dimension_registry import get_lane_name
from signal_bus.signal_bus import SignalBus

# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass
class AggregationStats:
    """Thống kê sau khi aggregate."""

    total_signals: int
    total_issues: int
    by_dimension: dict[str, int] = field(default_factory=dict)
    errors: list[str] = field(default_factory=list)
    # Sprint 6 (v10.3): legacy fallback notices & non-fatal observations tách
    # khỏi `errors` (fatal) để consumer phân biệt rõ. Errors vẫn block POST-GATE,
    # warnings chỉ log để khuyến nghị migrate.
    warnings: list[str] = field(default_factory=list)
    # v2 schema fields (populated when dimensions list provided)
    dimensions_run: list[str] = field(default_factory=list)
    dimensions_with_issues: list[str] = field(default_factory=list)
    dimensions_without_issues: list[str] = field(default_factory=list)
    coverage_rate_pct: float = 0.0
    dedup_ingested: int = 0
    dedup_deduplicated: int = 0
    # Task 1: probe failure tracking — block E005 false-positive khi có probe broken.
    probe_failures: list[dict[str, Any]] = field(default_factory=list)
    probe_failures_count: int = 0


# ──────────────────────────────────────────────────────────────────────
# Core function
# ──────────────────────────────────────────────────────────────────────


# v9.2.0: Signal source subdirectories (anti-overwrite)
_SIGNAL_SOURCES = ["static-scan", "runtime", "llm-scan"]


def _read_signals_from_file(
    read_path: Path, source_label: str, stats: AggregationStats
) -> list[dict[str, Any]]:
    """Đọc + parse 1 file signals.json. Append errors khi parse/struct fail."""
    try:
        raw = read_path.read_text(encoding="utf-8")
        data = json.loads(raw)
    except (json.JSONDecodeError, OSError) as exc:
        stats.errors.append(f"{source_label} parse fail: {exc}")
        return []

    if not isinstance(data, dict):
        stats.errors.append(f"{source_label} root không phải object")
        return []

    signals = data.get("signals", [])
    if not isinstance(signals, list):
        stats.errors.append(f"{source_label} 'signals' không phải array")
        return []

    return signals


def _read_signals_from_source(
    session_dir: Path, dim: str, source: str, stats: AggregationStats
) -> list[dict[str, Any]]:
    """Đọc signals từ 1 source subdirectory cụ thể (v9.2.0 path).

    KHÔNG fallback ra legacy path ở đây — legacy chỉ đọc 1 lần (xem
    aggregate_lane_signals) để tránh triple-count khi cả 3 source iteration
    cùng fallback về 1 legacy file.
    """
    source_path = session_dir / "lanes" / dim / source / "signals.json"
    if not source_path.exists():
        return []
    return _read_signals_from_file(
        source_path, f"lanes/{dim}/{source}/signals.json", stats
    )


def _legacy_signals_exists(session_dir: Path, dim: str) -> bool:
    """True nếu legacy lanes/{dim}/signals.json tồn tại (regardless content)."""
    return (session_dir / "lanes" / dim / "signals.json").is_file()


def _read_signals_from_legacy(
    session_dir: Path, dim: str, stats: AggregationStats
) -> list[dict[str, Any]]:
    """Đọc legacy lanes/{dim}/signals.json (pre-v9.2.0 layout).

    Append warning để khuyến nghị migrate sang static-scan/runtime/llm-scan.
    Trả [] nếu file không tồn tại.
    """
    legacy_path = session_dir / "lanes" / dim / "signals.json"
    if not legacy_path.is_file():
        return []
    signals = _read_signals_from_file(
        legacy_path, f"lanes/{dim}/signals.json (legacy fallback)", stats
    )
    # Sprint 6: legacy fallback là WARNING (recommend migrate), KHÔNG fatal error.
    # Errors vẫn block POST-GATE, warnings chỉ informational.
    stats.warnings.append(
        f"lanes/{dim}/static-scan/signals.json không tồn tại — "
        f"dùng legacy fallback lanes/{dim}/signals.json. "
        f"Nên migrate sang cấu trúc v9.2.0 (static-scan/runtime/llm-scan)."
    )
    return signals


def aggregate_lane_signals(
    session_dir: Path,
    dimensions: list[str],
) -> tuple[Path, AggregationStats]:
    """Đọc tất cả lane signals từ 3 subdirectory, aggregate qua SignalBus → issue-registry.json.

    Logic v9.2.0:
        1. For each dimension in dimensions:
           - Read $SESSION_DIR/lanes/{DIM}/static-scan/signals.json
           - Read $SESSION_DIR/lanes/{DIM}/runtime/signals.json
           - Read $SESSION_DIR/lanes/{DIM}/llm-scan/signals.json
           - Fallback: nếu subdirectory thiếu → đọc lanes/{DIM}/signals.json cũ
           - Extract signals[] arrays
        2. Create SignalBus(session_dir)
        3. Ingest all signals (dedup happens automatically via SignalBus)
        4. bus.flush() → $SESSION_DIR/issue-registry.json
        5. Return stats for reporting

    Args:
        session_dir: $SESSION_DIR chứa lanes/ subdirectory.
        dimensions: List of dimension IDs đã chạy (vd: ["QD1", "QD3"]).

    Returns:
        Tuple of (registry_path, AggregationStats).

    Note:
        - Same file+line in QD1+QD3 → 2 separate issues (different dedup_key).
        - Same file+line+dimension → deduped to 1 issue (SignalBus dedup).
        - 0 signals in all lanes → empty issue-registry.json (valid).
        - Mỗi signal được tag với `source` (static-scan/runtime/llm-scan) để audit.
    """
    stats = AggregationStats(total_signals=0, total_issues=0)
    all_signals: list[dict[str, Any]] = []

    for dim in dimensions:
        dim_signals: list[dict[str, Any]] = []
        sources_found = False

        # Ưu tiên v9.2.0 subdirectories (static-scan/runtime/llm-scan)
        for source in _SIGNAL_SOURCES:
            source_signals = _read_signals_from_source(session_dir, dim, source, stats)
            if source_signals:
                sources_found = True
            # Tag source để audit (biết signal đến từ đâu)
            for s in source_signals:
                if isinstance(s, dict) and "source" not in s:
                    s["source"] = source
            dim_signals.extend(source_signals)

        # Legacy fallback CHỈ đọc 1 lần khi không có subdirectory nào hit.
        # Tránh triple-count bug khi cả 3 source iteration cùng fallback về legacy file.
        if not sources_found:
            legacy_exists = _legacy_signals_exists(session_dir, dim)
            legacy_signals = _read_signals_from_legacy(session_dir, dim, stats)
            for s in legacy_signals:
                if isinstance(s, dict) and "source" not in s:
                    s["source"] = "legacy"
            dim_signals.extend(legacy_signals)

            # Phân biệt 2 case:
            # (a) Legacy file tồn tại nhưng signals=[] → lane valid, signal count = 0 → silent.
            # (b) Legacy file KHÔNG tồn tại + 0 sources → lane missing → error rõ ràng.
            if not legacy_exists:
                stats.errors.append(
                    f"lanes/{dim}/ không tồn tại — không có signals.json ở "
                    f"static-scan/runtime/llm-scan ({_SIGNAL_SOURCES}) hoặc legacy fallback."
                )

        all_signals.extend(dim_signals)
        dim_count = len(dim_signals)
        stats.by_dimension[dim] = dim_count
        stats.total_signals += dim_count

    # Task 1: Load probe failures từ probe-failures.log (do lane_dispatch ghi khi probe timeout/fail).
    # Skill phải block E005 "healthy" early-exit khi có failures.
    failures = _load_probe_failures(session_dir)
    stats.probe_failures = failures
    stats.probe_failures_count = len(failures)

    # Track dedup: signals ingested vs final issues
    stats.dedup_ingested = len(all_signals)

    # Aggregate via SignalBus
    bus = SignalBus(session_dir)
    bus.load_existing()

    for signal_dict in all_signals:
        try:
            bus.ingest(_normalize_probe_signal(signal_dict))
        except ValueError as exc:
            stats.errors.append(f"Signal ingest rejected: {exc}")

    registry_path = bus.flush()
    stats.total_issues = len(bus.issues)

    # v2 schema: populate dimension-level coverage fields
    if dimensions:
        stats.dimensions_run = list(dimensions)
        stats.dimensions_with_issues = sorted(
            dim for dim, count in stats.by_dimension.items() if count > 0
        )
        stats.dimensions_without_issues = sorted(
            dim for dim in dimensions if stats.by_dimension.get(dim, 0) == 0
        )
        total = len(dimensions)
        with_issues = len(stats.dimensions_with_issues)
        stats.coverage_rate_pct = round(with_issues / total * 100, 1) if total > 0 else 0.0
        stats.dedup_deduplicated = stats.total_signals - stats.total_issues

    # Enrich registry với full v2 schema fields (template: issue-registry-v2.json).
    # signal_bus.flush() chỉ ghi minimal {$schema, generated_at, session_dir, issues};
    # POST-GATE T2/T4 downstream cần fix_id, dimensions_run, total_issues, dedup_stats, coverage.
    _enrich_registry_metadata(registry_path, stats, dimensions)

    return registry_path, stats


def _load_probe_failures(session_dir: Path) -> list[dict[str, Any]]:
    """Đọc $SESSION_DIR/probe-failures.log (JSONL) — record do lane_dispatch ghi
    khi probe timeout/non-zero exit/json decode error/etc.

    Returns:
        List of failure records, hoặc [] nếu file missing / không parse được.

    Schema record (từ lane_dispatch._log_probe_failure):
        {timestamp, lane, probe_id, reason, returncode, stderr_snippet}

    Task 1: aggregator báo cáo failures, POST-GATE/orchestrator block E005
    "healthy" early-exit khi có failures (chống false-positive).
    """
    failures_path = session_dir / "probe-failures.log"
    if not failures_path.is_file():
        return []
    out: list[dict[str, Any]] = []
    try:
        for line in failures_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(rec, dict):
                out.append(rec)
    except OSError:
        pass
    return out


def _normalize_probe_signal(s: dict[str, Any]) -> dict[str, Any]:
    """Normalize signal-v2 (probe output) → SignalBus Signal schema.

    Probe scripts emit `signal-v2` (dimension_id, location, detected_at, evidence as array)
    nhưng SignalBus.Signal yêu cầu `lane`, `target` (with .kind), `emitted_at`, `evidence`
    là dict. Hàm này map field names + reshape để bus có thể ingest.

    Field mapping:
        location ↔ target (location.file → target.file_path; thêm target.kind)
        detected_at ↔ emitted_at
        evidence (array) ↔ evidence (dict {items: [...]})
        lane: derive từ dimension_id (xem dimension_registry.LANE map) nếu thiếu
    """
    if not isinstance(s, dict):
        return s
    out = dict(s)
    if "emitted_at" not in out and "detected_at" in out:
        out["emitted_at"] = out["detected_at"]
    if "lane" not in out:
        # F06.005: Dùng DIMENSION_REGISTRY canonical (SSOT), không hardcode dict.
        # Tránh drift khi thêm/đổi dimensions.
        out["lane"] = get_lane_name(out.get("dimension_id"))
    if "target" not in out:
        loc = out.get("location") or {}
        # Probe có thể đặt "N/A" thay vì null → coi như không có file.
        loc_file = loc.get("file") if isinstance(loc, dict) else None
        if loc_file in (None, "", "N/A", "n/a"):
            loc_file = None
        # Fallback symbol: dùng FEAT-ID/REQ-ID từ registry_refs để dedup_key unique
        # cho signals như "Coverage gap: FEAT-X" — cùng dimension nhưng khác entity.
        symbol = None
        refs = out.get("registry_refs") or {}
        if isinstance(refs, dict):
            for key in ("feat_ids", "req_ids", "module_ids"):
                vals = refs.get(key)
                if isinstance(vals, list) and vals:
                    symbol = str(vals[0])
                    break
        out["target"] = {
            "kind": "code" if loc_file else "logical",
            "file_path": loc_file,
            "line": loc.get("line") if isinstance(loc, dict) else None,
            "url": loc.get("url") if isinstance(loc, dict) else None,
            "selector": loc.get("selector") if isinstance(loc, dict) else None,
            "symbol": symbol,
        }
    ev = out.get("evidence")
    if isinstance(ev, list):
        # Probe emits evidence as array of {type, path, description}; SignalBus
        # cần dict với key ∈ {code_snippet, screenshot_path, log_excerpt, ...}.
        # Map sang code_snippet — dùng description text (cần ≥10 chars per ADR-09).
        descriptions = []
        paths = []
        for item in ev:
            if not isinstance(item, dict):
                continue
            d = str(item.get("description", "")).strip()
            p = str(item.get("path", "")).strip()
            if d:
                descriptions.append(d)
            if p:
                paths.append(p)
        snippet_parts = []
        if paths:
            snippet_parts.append("paths: " + ", ".join(paths[:3]))
        if descriptions:
            snippet_parts.append(" | ".join(descriptions[:2]))
        snippet = "; ".join(snippet_parts) or out.get("description", "")
        if len(snippet) < 10:
            snippet = (snippet + " " + str(out.get("title", ""))).strip()
        out["evidence"] = {"code_snippet": snippet}
    return out


def _enrich_registry_metadata(
    registry_path: Path,
    stats: AggregationStats,
    dimensions: list[str] | None,
) -> None:
    """Merge aggregation metadata vào issue-registry.json (atomic re-write)."""
    try:
        data = json.loads(registry_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return  # POST-GATE đã pass trước đó; không tự gây lỗi nếu read fail
    if not isinstance(data, dict):
        return
    data["fix_id"] = registry_path.parent.name
    data.setdefault("engine_version", "v6")
    data["dimensions_run"] = list(dimensions) if dimensions else stats.dimensions_run
    data["total_issues"] = stats.total_issues
    data["dedup_stats"] = {
        "signals_ingested": stats.dedup_ingested,
        "signals_deduplicated": stats.dedup_deduplicated,
        "issues_after_dedup": stats.total_issues,
    }
    data["coverage"] = {
        "dimensions_with_issues": stats.dimensions_with_issues,
        "dimensions_without_issues": stats.dimensions_without_issues,
        "coverage_rate_pct": stats.coverage_rate_pct,
    }
    # Task 1: expose probe failures for POST-GATE / E005 gating.
    data["probe_failures_count"] = stats.probe_failures_count
    data["probe_failures"] = stats.probe_failures
    data["healthy"] = (
        stats.total_issues == 0 and stats.probe_failures_count == 0
    )
    tmp = registry_path.with_suffix(registry_path.suffix + f".tmp.{os.getpid()}")
    with tmp.open("w", encoding="utf-8") as fh:
        # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
        json.dump(data, fh, indent=2, ensure_ascii=False, sort_keys=True)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, registry_path)


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: aggregate lane signals into master issue-registry.json.

    Usage:
        python -m signal_aggregator --session-dir $SESSION_DIR --dims QD1 QD3 QD5
        (run from _shared/ directory)
    """
    import argparse
    import sys

    # Windows cp1252 → force UTF-8 cho stdout/stderr (Vietnamese chars)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(
        description="Signal Aggregator - merge lane signals.json into issue-registry.json"
    )
    parser.add_argument("--session-dir", required=True, type=Path,
                        help="Path to SESSION_DIR containing lanes/ subdir")
    parser.add_argument("--dims", required=True, nargs="+",
                        help="Dimension IDs da chay (vd: QD1 QD3 QD5)")
    args = parser.parse_args(argv)

    try:
        registry_path, stats = aggregate_lane_signals(
            session_dir=args.session_dir,
            dimensions=args.dims,
        )
    except (OSError, ValueError) as exc:
        print(f"[signal_aggregator ERROR] {exc}", file=sys.stderr)
        return 1

    # Emit JSON summary to stdout (machine-readable for orchestrator)
    summary = {
        "registry_path": str(registry_path),
        "total_signals": stats.total_signals,
        "total_issues": stats.total_issues,
        "by_dimension": stats.by_dimension,
        "dimensions_run": stats.dimensions_run,
        "dimensions_with_issues": stats.dimensions_with_issues,
        "dimensions_without_issues": stats.dimensions_without_issues,
        "coverage_rate_pct": stats.coverage_rate_pct,
        "dedup_ingested": stats.dedup_ingested,
        "dedup_deduplicated": stats.dedup_deduplicated,
        "errors": stats.errors,
        # Task 1: probe failure visibility cho POST-GATE / orchestrator E005 gating.
        "probe_failures_count": stats.probe_failures_count,
        "probe_failures": stats.probe_failures,
        "healthy": (stats.total_issues == 0 and stats.probe_failures_count == 0),
    }
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    # F06.002: exit 1 khi có errors để orchestrator phân biệt success vs success-with-errors
    return 1 if stats.errors else 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
