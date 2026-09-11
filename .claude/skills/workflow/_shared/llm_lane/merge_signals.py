"""merge_signals — Merge static signals.json + LLM signals (per-dim).

Phase C v8 wire-up part 3: Sau khi orchestrator drive Agent calls va emit_signals
da viet llm-signals.json, script nay merge vao signals.json (static) cho tung dim.

Cross-cutting probes (lanes/cross/{probe_id}/llm-signals.json) duoc dispatch theo
`signal.dimension_id` cua tung signal — vd signal voi dimension_id="QD2" se duoc
merge vao phase4-find-bugs/lanes/QD2-business/signals.json.

Dedup theo fingerprint — neu LLM signal trung fingerprint voi static → drop LLM
(static co priority vi co code citation tu probe deterministic).

Usage:
    python -m llm_lane.merge_signals --session-dir <path> --dim QD1 [--dim QD2 ...]
    python -m llm_lane.merge_signals --session-dir <path> --all

Atomic write: signals.json moi se replace ban cu, llm-signals.json giu nguyen
lam audit trail.

Exit codes:
    0 — success (merge completed cho tat ca dims)
    1 — invalid args / session dir not found
    2 — partial merge (1+ dim fail)
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# CRIT-4 fix v9.0.3: mo rong QD1-QD10 (v9.0.0/v9.0.1 chua cap nhat cho QD9/QD10).
# v9.1.0: mo rong QD1-QD11 — them QD11 Business Completeness.
# Tat ca LLM signals tu QD9 runtime-health, QD10 cross-module integration, QD11 business completeness giờ duoc merge dung.
ALL_DIMS = ("QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11")


# ────────────────────────────────────────────────────────────
# B1 (v8.2.2) — File-level lock for signals.json
# ────────────────────────────────────────────────────────────
# Convention: <signals_path>.lock/ directory (mkdir POSIX atomic).
# Compatible với lane_dispatch._signals_lock_acquire + bash
# acquire_signals_lock — cùng path nên 3 writer chia sẻ được.

def _signals_lock_acquire(
    signals_path: Path,
    timeout_sec: int = 30,
    stale_sec: int = 300,
) -> bool:
    lock_dir = signals_path.with_suffix(signals_path.suffix + ".lock")
    waited = 0
    while waited < timeout_sec:
        if lock_dir.exists():
            try:
                age = time.time() - lock_dir.stat().st_mtime
            except OSError:
                age = 0
            if age > stale_sec:
                print(
                    f"[merge_signals WARNING] stale signals lock "
                    f"(age={int(age)}s > {stale_sec}s), taking over: {lock_dir}",
                    file=sys.stderr, flush=True,
                )
                try:
                    lock_dir.rmdir()
                except OSError:
                    pass

        try:
            lock_dir.parent.mkdir(parents=True, exist_ok=True)
            lock_dir.mkdir()
            return True
        except FileExistsError:
            time.sleep(1)
            waited += 1
        except OSError as exc:
            print(
                f"[merge_signals ERROR] signals lock OS error: {exc} ({lock_dir})",
                file=sys.stderr, flush=True,
            )
            return False

    print(
        f"[merge_signals ERROR] signals lock timeout ({timeout_sec}s) "
        f"for {signals_path}",
        file=sys.stderr, flush=True,
    )
    return False


def _signals_lock_release(signals_path: Path) -> None:
    lock_dir = signals_path.with_suffix(signals_path.suffix + ".lock")
    try:
        lock_dir.rmdir()
    except (FileNotFoundError, OSError):
        pass


def _read_json(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def _atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + f".tmp.{id(data)}")
    # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True), encoding="utf-8")
    tmp.replace(path)


def _load_cross_signals_for_dim(session_dir: Path, dim: str) -> list[dict[str, Any]]:
    """Load cross-cutting LLM signals matching given dim.

    Reads $SESSION_DIR/lanes/cross/{probe_id}/llm-signals.json,
    filters signals where signal.dimension_id == dim.
    """
    cross_dir = session_dir / "lanes" / "cross"
    if not cross_dir.is_dir():
        return []

    matched: list[dict[str, Any]] = []
    for probe_subdir in sorted(cross_dir.iterdir()):
        if not probe_subdir.is_dir():
            continue
        llm_signals_file = probe_subdir / "llm-signals.json"
        envelope = _read_json(llm_signals_file)
        if not envelope or not isinstance(envelope.get("signals"), list):
            continue
        for sig in envelope["signals"]:
            if isinstance(sig, dict) and sig.get("dimension_id") == dim:
                matched.append(sig)
    return matched


def merge_lane(session_dir: Path, dim: str) -> dict[str, Any]:
    """Merge static signals.json + LLM signals cho 1 dim.

    Returns:
        Stats dict: {static_count, llm_count, cross_count, dedup_dropped, final_count}.
        Raises FileNotFoundError neu signals.json (static) khong ton tai.
    """
    lane_dir = session_dir / "lanes" / dim
    static_path = lane_dir / "signals.json"
    llm_path = lane_dir / "llm-signals.json"

    # B1 (v8.2.2) — Lock bao quanh toàn bộ Read-Modify-Write
    # để chống race với lane_dispatch.py + signal-emit.md.
    locked = _signals_lock_acquire(static_path)
    try:
        static_envelope = _read_json(static_path)
        if static_envelope is None:
            raise FileNotFoundError(f"static signals.json not found: {static_path}")

        static_signals = static_envelope.get("signals", []) or []
        if not isinstance(static_signals, list):
            static_signals = []

        llm_signals: list[dict[str, Any]] = []
        llm_envelope = _read_json(llm_path)
        if llm_envelope is not None and isinstance(llm_envelope.get("signals"), list):
            llm_signals.extend(llm_envelope["signals"])

        cross_signals = _load_cross_signals_for_dim(session_dir, dim)
        llm_signals.extend(cross_signals)

        # Dedup by fingerprint. Static priority — keep static, drop LLM duplicates.
        seen_fps: set[str] = set()
        merged: list[dict[str, Any]] = []
        for sig in static_signals:
            fp = sig.get("fingerprint", "") if isinstance(sig, dict) else ""
            if fp:
                seen_fps.add(fp)
            merged.append(sig)

        dedup_dropped = 0
        for sig in llm_signals:
            if not isinstance(sig, dict):
                continue
            fp = sig.get("fingerprint", "")
            if fp and fp in seen_fps:
                dedup_dropped += 1
                continue
            if fp:
                seen_fps.add(fp)
            merged.append(sig)

        # Update envelope
        static_envelope["signals"] = merged
        static_envelope["llm_merged"] = True
        static_envelope["llm_merged_at"] = datetime.now(timezone.utc).isoformat()
        static_envelope["llm_signals_count"] = len(llm_envelope["signals"]) if llm_envelope else 0
        static_envelope["cross_signals_count"] = len(cross_signals)
        static_envelope["llm_dedup_dropped"] = dedup_dropped

        _atomic_write_json(static_path, static_envelope)

        return {
            "static_count": len(static_signals),
            "llm_count": len(llm_envelope["signals"]) if llm_envelope else 0,
            "cross_count": len(cross_signals),
            "dedup_dropped": dedup_dropped,
            "final_count": len(merged),
        }
    finally:
        if locked:
            _signals_lock_release(static_path)


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Merge static + LLM signals per dim")
    parser.add_argument("--session-dir", required=True, type=Path)
    parser.add_argument("--dim", action="append", default=[],
                        help="Dimension to merge. Repeat for multiple. Or use --all.")
    parser.add_argument("--all", action="store_true",
                        help="Merge all 7 dimensions QD1-QD7")
    args = parser.parse_args(argv)

    if not args.session_dir.is_dir():
        print(f"[merge_signals ERROR] session-dir not found: {args.session_dir}", file=sys.stderr)
        return 1

    target_dims: list[str]
    if args.all:
        target_dims = list(ALL_DIMS)
    elif args.dim:
        target_dims = list(args.dim)
    else:
        print("[merge_signals ERROR] --dim or --all required", file=sys.stderr)
        return 1

    overall_status = 0
    summary: dict[str, Any] = {}
    for dim in target_dims:
        try:
            stats = merge_lane(args.session_dir, dim)
            summary[dim] = stats
            print(
                f"[{dim}] OK: static={stats['static_count']} + llm={stats['llm_count']} "
                f"+ cross={stats['cross_count']} - dedup={stats['dedup_dropped']} "
                f"= final={stats['final_count']}"
            )
        except FileNotFoundError as exc:
            # Lane chua chay → skip, KHONG fail
            print(f"[{dim}] SKIP: {exc}", file=sys.stderr)
            summary[dim] = {"skipped": True, "reason": str(exc)}
        except Exception as exc:  # noqa: BLE001
            print(f"[{dim}] ERROR: {exc}", file=sys.stderr)
            summary[dim] = {"error": str(exc)}
            overall_status = 2

    return overall_status


if __name__ == "__main__":
    sys.exit(main())
