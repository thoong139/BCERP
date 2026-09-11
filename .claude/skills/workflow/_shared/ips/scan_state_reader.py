"""Scan State Reader — helper API for scan-state.json read/write.

Enforces:
- Session auto-discovery (latest active session).
- Atomic write pattern (tmp -> fsync -> rename).
- State machine validation cho layer status transitions.
- Error log append trong scan-state.error_log[].

Reference: docs/design/skills/wf-legacy-scan/04-data-model.md §1.2-1.3.

Lifecycle:
- Phase A.7: skeleton + `is_valid_transition()` + `read_layer_status()` chỉ.
- Phase B: đầy đủ read_scan_state + update_* + append_error (atomic, state-machine enforced).
- Phase D: full API cho sub-skill migration — read_layer_outputs, append_layer_output,
  read_depth_map, read_ips_phase_a/b, get_domain_expert_for_module,
  init_or_load_session (standalone fallback from legacy ledger.json).
- Phase E: 4-Level Checkpoint L3 intra-batch partial.json API + write throttle
  (5s min interval per session, deferred write, atexit flush).
"""

from __future__ import annotations

import atexit
import json
import os
import threading
import time
from pathlib import Path
from typing import Any

# Default work dir — skills/orchestrator can override via env var hoặc explicit session_id.
WORK_DIR = Path(".mc-data/work/legacy-scan")

# Valid layer statuses (state machine nodes).
_VALID_LAYER_STATES: frozenset[str] = frozenset(
    {
        "not_started",
        "in_progress",
        "completed",
        "failed",
        "skipped_by_profile",
    }
)

# State machine transitions: current → allowed next states.
_VALID_LAYER_TRANSITIONS: dict[str, frozenset[str]] = {
    "not_started": frozenset({"in_progress", "skipped_by_profile"}),
    "in_progress": frozenset({"completed", "failed"}),
    "completed": frozenset(),  # terminal
    "failed": frozenset({"in_progress"}),  # retry path
    "skipped_by_profile": frozenset(),  # terminal
}


# ─── Session Discovery ───────────────────────────────────────


def get_active_session_dir() -> Path | None:
    """Find latest session có status ∈ {in_progress, paused}.

    Returns None nếu không có active session.
    """
    sessions_dir = WORK_DIR / "sessions"
    if not sessions_dir.exists():
        return None

    # Sort by mtime desc để prefer session mới nhất.
    candidates = sorted(
        (p for p in sessions_dir.iterdir() if p.is_dir()),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )

    for session in candidates:
        state_path = session / "scan-state.json"
        if not state_path.exists():
            continue
        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        if state.get("status") in ("in_progress", "paused"):
            return session
    return None


def _resolve_session_dir(session_id: str | None) -> Path:
    """Resolve session directory path.

    Nếu session_id=None → auto-discover latest active session.
    Raises FileNotFoundError nếu không resolve được.
    """
    if session_id:
        session_dir = WORK_DIR / "sessions" / session_id
        if not session_dir.exists():
            raise FileNotFoundError(
                f"Session directory not found: {session_dir}"
            )
        return session_dir

    active = get_active_session_dir()
    if active is None:
        raise FileNotFoundError(
            "No active session found. Run /wf-legacy-scan to start."
        )
    return active


# ─── Read Helpers ────────────────────────────────────────────


def read_scan_state(session_id: str | None = None) -> dict[str, Any]:
    """Read scan-state.json for a session.

    Phase E: nếu có pending throttled write cho session này → trả về in-memory
    pending state (deep-copied) để keep view-of-truth consistent, KHÔNG đọc disk.

    Args:
        session_id: Session identifier. If None, resolve latest active session.

    Returns:
        Parsed scan-state dict.

    Raises:
        FileNotFoundError: No active session or invalid session_id.
        json.JSONDecodeError: scan-state.json corrupted.
    """
    session_dir = _resolve_session_dir(session_id)

    # Phase E — prefer pending state nếu có (newer than disk).
    with _THROTTLE_LOCK:
        pending = _PENDING_STATE.get(_session_key(session_dir))
        if pending is not None:
            _, state = pending
            # Deep-copy via JSON roundtrip để caller mutate không ảnh hưởng pending.
            return json.loads(json.dumps(state))

    state_path = session_dir / "scan-state.json"
    if not state_path.exists():
        raise FileNotFoundError(f"scan-state.json not found at {state_path}")
    return json.loads(state_path.read_text(encoding="utf-8"))


def read_layer_status(state: dict[str, Any], layer_id: str) -> str:
    """Read status of a specific layer from parsed scan-state dict.

    Thin accessor — không chạm file. Useful cho code đã có state in-memory.

    Args:
        state: Parsed scan-state dict.
        layer_id: Layer identifier (L1..L6).

    Returns:
        Layer status string.

    Raises:
        KeyError: layer_id không tồn tại.
    """
    return state["layers"][layer_id]["status"]


def is_valid_transition(from_status: str, to_status: str) -> bool:
    """Check if layer status transition is valid theo state machine.

    Args:
        from_status: Current status.
        to_status: Target status.

    Returns:
        True nếu transition allowed.
    """
    if from_status not in _VALID_LAYER_TRANSITIONS:
        return False
    return to_status in _VALID_LAYER_TRANSITIONS[from_status]


# ─── Write Helpers (atomic + throttle) ───────────────────────


# Phase E Task E.2 — Write Throttle state.
# Minimum interval (seconds) between disk writes per session. Updates coming
# in too fast are deferred in-memory; the next write that passes the gate
# (or atexit flush) persists the latest state.
_WRITE_THROTTLE_SEC = 5.0

# Per-session last-write timestamp (monotonic seconds).
_LAST_WRITE_TIME: dict[str, float] = {}

# Per-session pending state (session_key → (session_dir, state)).
# session_key = str(session_dir) — stable per session.
_PENDING_STATE: dict[str, tuple[Path, dict[str, Any]]] = {}

# Lock protecting the throttle bookkeeping above.
_THROTTLE_LOCK = threading.Lock()

# atexit flush guard — register only once.
_ATEXIT_REGISTERED = False


def _now_iso() -> str:
    """UTC ISO 8601 timestamp (seconds precision)."""
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _session_key(session_dir: Path) -> str:
    """Stable per-session key for throttle bookkeeping."""
    return str(session_dir)


def _do_atomic_write(session_dir: Path, state: dict[str, Any]) -> None:
    """Raw atomic write: tmp → fsync → rename.

    Internal — callers should go through `_atomic_write_state()` để tuân thủ throttle.
    """
    state_path = session_dir / "scan-state.json"
    tmp_path = state_path.with_suffix(f".json.tmp.{os.getpid()}")

    # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
    payload = json.dumps(state, indent=2, ensure_ascii=False, sort_keys=True)
    tmp_path.write_text(payload, encoding="utf-8")

    # fsync best-effort (không fail nếu platform không support).
    try:
        with tmp_path.open("rb") as f:
            os.fsync(f.fileno())
    except (OSError, AttributeError):
        pass

    tmp_path.replace(state_path)


def _flush_pending_locked(session_key: str) -> None:
    """Flush pending state for a session. Must hold _THROTTLE_LOCK."""
    pending = _PENDING_STATE.pop(session_key, None)
    if pending is None:
        return
    session_dir, state = pending
    _do_atomic_write(session_dir, state)
    _LAST_WRITE_TIME[session_key] = time.monotonic()


def _flush_all_pending() -> None:
    """Flush all pending states — called at process exit."""
    with _THROTTLE_LOCK:
        keys = list(_PENDING_STATE.keys())
        for key in keys:
            try:
                _flush_pending_locked(key)
            except OSError:
                # Best-effort — atexit must not raise.
                pass


def _register_atexit() -> None:
    """Register atexit flush handler (idempotent)."""
    global _ATEXIT_REGISTERED
    if _ATEXIT_REGISTERED:
        return
    atexit.register(_flush_all_pending)
    _ATEXIT_REGISTERED = True


def _atomic_write_state(
    session_dir: Path,
    state: dict[str, Any],
    force: bool = False,
) -> None:
    """Atomic write với 5-second throttle per session.

    Nếu last write cho session này < 5s → defer:
        - Lưu state vào `_PENDING_STATE[session_key]`
        - Return immediately, no disk I/O

    Ngược lại → write ngay:
        - Clear pending (nếu có — state đã superseded)
        - Atomic write tmp → fsync → rename
        - Update `_LAST_WRITE_TIME[session_key]`

    Args:
        session_dir: Session directory path.
        state: Full scan-state dict to persist.
        force: Bỏ qua throttle (dùng cho state machine transitions quan trọng).
    """
    key = _session_key(session_dir)
    with _THROTTLE_LOCK:
        _register_atexit()

        now = time.monotonic()
        last = _LAST_WRITE_TIME.get(key, 0.0)
        elapsed = now - last

        if not force and elapsed < _WRITE_THROTTLE_SEC and last > 0.0:
            # Defer — store newest state, skip disk I/O.
            _PENDING_STATE[key] = (session_dir, state)
            return

        # Gate passed (or forced) — write now + clear pending.
        _PENDING_STATE.pop(key, None)
        _do_atomic_write(session_dir, state)
        _LAST_WRITE_TIME[key] = now


def _reset_throttle_state() -> None:
    """Reset throttle bookkeeping — for test isolation only."""
    with _THROTTLE_LOCK:
        _LAST_WRITE_TIME.clear()
        _PENDING_STATE.clear()


def flush_pending_writes(session_id: str | None = None) -> None:
    """Force-flush pending throttled writes for a session (or all).

    Dùng khi caller muốn đảm bảo state đã persist trước khi tiếp tục
    (e.g., trước khi spawn agent, trước khi exit phase).

    Args:
        session_id: Nếu None → flush tất cả sessions.
    """
    with _THROTTLE_LOCK:
        if session_id is None:
            keys = list(_PENDING_STATE.keys())
            for key in keys:
                _flush_pending_locked(key)
            return

        try:
            session_dir = _resolve_session_dir(session_id)
        except FileNotFoundError:
            return
        _flush_pending_locked(_session_key(session_dir))


def update_layer_status(
    layer_id: str,
    new_status: str,
    session_id: str | None = None,
) -> None:
    """Atomically update layer status với state machine validation.

    Args:
        layer_id: Layer identifier (L1..L6).
        new_status: Target status (must be valid transition từ current).
        session_id: Optional session override (None → auto-discover).

    Raises:
        FileNotFoundError: No active session.
        ValueError: Invalid transition hoặc unknown new_status.
        KeyError: layer_id không tồn tại.
    """
    if new_status not in _VALID_LAYER_STATES:
        raise ValueError(
            f"Unknown layer status: {new_status!r}. "
            f"Valid: {sorted(_VALID_LAYER_STATES)}"
        )

    session_dir = _resolve_session_dir(session_id)
    state = read_scan_state(session_id)

    current = state["layers"][layer_id]["status"]
    if not is_valid_transition(current, new_status):
        raise ValueError(
            f"Invalid transition for layer {layer_id}: "
            f"{current!r} → {new_status!r}"
        )

    state["layers"][layer_id]["status"] = new_status
    if new_status == "in_progress":
        state["layers"][layer_id]["started"] = _now_iso()
    elif new_status in ("completed", "failed"):
        state["layers"][layer_id]["completed"] = _now_iso()

    # Layer status transitions là CRITICAL — force write, bypass throttle.
    _atomic_write_state(session_dir, state, force=True)


def update_batch_progress(
    layer_id: str,
    progress: dict[str, Any],
    session_id: str | None = None,
) -> None:
    """Update batch progress cho L4/L5 layers.

    Args:
        layer_id: Must be L4 (classification) hoặc L5 (extraction).
        progress: Dict với keys current, total, completed_batches, ...
        session_id: Optional session override.

    Raises:
        ValueError: layer_id không phải L4/L5.
    """
    if layer_id not in ("L4", "L5"):
        raise ValueError(
            f"batch_progress chỉ áp dụng cho L4/L5, not {layer_id!r}"
        )

    session_dir = _resolve_session_dir(session_id)
    state = read_scan_state(session_id)
    state["layers"][layer_id]["batch_progress"] = progress
    _atomic_write_state(session_dir, state)


def update_module_progress(
    layer_id: str,
    module: str,
    status: str,
    session_id: str | None = None,
) -> None:
    """Update per-module progress cho L5 extraction.

    Append module vào `completed[]` nếu status == "completed".
    Nếu list chưa tồn tại, khởi tạo {"completed": [], "total": 0}.

    Args:
        layer_id: Thường là L5.
        module: Module ID / name.
        status: Status của module (chủ yếu "completed" hoặc "failed").
        session_id: Optional session override.
    """
    session_dir = _resolve_session_dir(session_id)
    state = read_scan_state(session_id)

    layer = state["layers"][layer_id]
    mp = layer.get("module_progress") or {"completed": [], "total": 0}

    if status == "completed":
        completed_list = mp.setdefault("completed", [])
        if module not in completed_list:
            completed_list.append(module)

    layer["module_progress"] = mp
    _atomic_write_state(session_dir, state)


def append_error(
    layer_id: str,
    error: dict[str, Any],
    session_id: str | None = None,
) -> None:
    """Append error entry vào error_log[] (atomic).

    Enriches error với `layer` + `timestamp` nếu chưa có.

    Args:
        layer_id: Layer phát sinh error.
        error: Error dict (code, message, context, ...).
        session_id: Optional session override.
    """
    session_dir = _resolve_session_dir(session_id)
    state = read_scan_state(session_id)

    enriched = {**error}
    enriched.setdefault("layer", layer_id)
    enriched.setdefault("timestamp", _now_iso())

    state.setdefault("error_log", []).append(enriched)
    # Errors là CRITICAL cho diagnostics — force write.
    _atomic_write_state(session_dir, state, force=True)


# ─── Phase D: Sub-skill Migration API ────────────────────────


# Confidence threshold for domain-expert recommendation (ADR-LS06 §2.1).
DOMAIN_EXPERT_MIN_CONFIDENCE = 0.6


def read_layer_outputs(
    layer_id: str, session_id: str | None = None
) -> list[str]:
    """Read list of output file paths for a layer.

    Args:
        layer_id: Layer identifier (L1..L6).
        session_id: Optional session override.

    Returns:
        List of output paths (may be empty).

    Raises:
        KeyError: layer_id không tồn tại.
    """
    state = read_scan_state(session_id)
    layer = state["layers"][layer_id]
    outputs = layer.get("outputs") or []
    if not isinstance(outputs, list):
        return []
    return [str(p) for p in outputs if isinstance(p, str)]


def append_layer_output(
    layer_id: str,
    output_path: str,
    session_id: str | None = None,
) -> None:
    """Append output file path to layer.outputs[] (atomic, dedup).

    Nếu path đã tồn tại → no-op (idempotent).

    Args:
        layer_id: Layer identifier.
        output_path: Output path to append.
        session_id: Optional session override.
    """
    session_dir = _resolve_session_dir(session_id)
    state = read_scan_state(session_id)

    layer = state["layers"][layer_id]
    outputs = layer.get("outputs")
    if not isinstance(outputs, list):
        outputs = []
    if output_path not in outputs:
        outputs.append(output_path)
    layer["outputs"] = outputs

    _atomic_write_state(session_dir, state)


def read_depth_map(session_id: str | None = None) -> dict[str, str]:
    """Return depth_map dict (L1..L6 → depth level).

    Args:
        session_id: Optional session override.

    Returns:
        Dict map layer → depth (full/surface/standard/deep/skip).
    """
    state = read_scan_state(session_id)
    depth_map = state.get("depth_map") or {}
    if not isinstance(depth_map, dict):
        return {}
    return {str(k): str(v) for k, v in depth_map.items()}


def read_ips_phase_a(
    session_id: str | None = None,
) -> dict[str, Any]:
    """Return ips.phase_a content (domain hints, recommended_profile, ...).

    Args:
        session_id: Optional session override.

    Returns:
        Phase A dict. Empty dict nếu chưa có dữ liệu.
    """
    state = read_scan_state(session_id)
    ips = state.get("ips") or {}
    phase_a = ips.get("phase_a")
    if not isinstance(phase_a, dict):
        return {}
    return phase_a


def read_ips_phase_b(
    session_id: str | None = None,
) -> dict[str, Any]:
    """Return ips.phase_b content (module routing, hotspots, workload, ...).

    Args:
        session_id: Optional session override.

    Returns:
        Phase B dict. Empty dict nếu chưa có dữ liệu.
    """
    state = read_scan_state(session_id)
    ips = state.get("ips") or {}
    phase_b = ips.get("phase_b")
    if not isinstance(phase_b, dict):
        return {}
    return phase_b


def get_domain_expert_for_module(
    module: str,
    session_id: str | None = None,
) -> str | None:
    """Return recommended domain-expert cho module (from ips.phase_b.module_routing).

    Nếu confidence < DOMAIN_EXPERT_MIN_CONFIDENCE (0.6) → returns None
    (caller nên fallback business-analyst only).

    Args:
        module: Module name (normalized lowercase-kebab-case).
        session_id: Optional session override.

    Returns:
        Expert agent subagent_type string, hoặc None nếu không đủ confidence.
    """
    phase_b = read_ips_phase_b(session_id)
    routing = phase_b.get("module_routing") or {}
    if not isinstance(routing, dict):
        return None

    entry = routing.get(module)
    if not isinstance(entry, dict):
        return None

    confidence = entry.get("confidence", 0.0)
    try:
        confidence = float(confidence)
    except (TypeError, ValueError):
        return None

    if confidence < DOMAIN_EXPERT_MIN_CONFIDENCE:
        return None

    expert = entry.get("expert")
    if not isinstance(expert, str) or not expert:
        return None
    return expert


def _migrate_legacy_ledger(
    project_path: Path,
    ledger_path: Path,
) -> str:
    """Migrate v4.1 ledger.json → new scan-state.json session.

    Standalone fallback khi user chạy /wf-legacy-classify hoặc /wf-legacy-extract
    sau khi v4.1 scan đã complete (chỉ có ledger.json, chưa có scan-state.json).

    Tạo session với layers hydrated từ ledger.stages status map.
    """
    ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    stages = ledger.get("stages", {})

    def stage_status(stage_name: str) -> str:
        """Translate ledger stage status → layer state."""
        raw = stages.get(stage_name, {}).get("status", "not_started")
        if raw == "completed":
            return "completed"
        if raw == "in_progress":
            return "in_progress"
        if raw == "failed":
            return "failed"
        if raw == "skipped" or raw == "skipped_maturity":
            return "skipped_by_profile"
        return "not_started"

    # Map legacy stages → v5.0 layers.
    # detection/assessment → L2 (assessment); inventory → L3;
    # classify → L4; extract → L5; synthesize → L6.
    layer_states = {
        "L1": "completed" if stages else "not_started",  # discovery considered done
        "L2": stage_status("detection") if "detection" in stages else "completed",
        "L3": stage_status("inventory"),
        "L4": stage_status("classify"),
        "L5": stage_status("extract"),
        "L6": stage_status("synthesize"),
    }

    session_id = time.strftime("%Y-%m-%dT%H-%M-%S", time.gmtime())
    session_dir = WORK_DIR / "sessions" / session_id
    session_dir.mkdir(parents=True, exist_ok=True)

    state: dict[str, Any] = {
        "$schema": "scan-state-v1",
        "session": {
            "id": session_id,
            "created": _now_iso(),
            "project_path": str(project_path),
            "profile": "standard",
            "strategy": ledger.get("strategy", {}).get("id"),
            "maturity_level": ledger.get("maturity", {}).get("maturity_level"),
            "workload_id": None,
            "chunk_id": None,
            "migrated_from_legacy": True,
        },
        "depth_map": {
            "L1": "full",
            "L2": "full",
            "L3": "full",
            "L4": "standard",
            "L5": "standard",
            "L6": "full",
        },
        "synthesis_mode": "full",
        "config": {"batch_size": 100},
        "layers": {},
        "ips": {"phase_a": None, "phase_b": None},
        "workload": None,
        "last_completed": "migrated",
        "status": "in_progress",
        "error_log": [],
        "resume_hint": "Migrated from v4.1 ledger.json — continue current sub-skill.",
        "legacy_ledger": {
            "generated_at": ledger.get("generated_at"),
            "schema_version": "legacy-v4.1",
            "note": "Imported via _migrate_legacy_ledger().",
        },
    }

    layer_names = {
        "L1": "discovery",
        "L2": "assessment",
        "L3": "inventory",
        "L4": "classification",
        "L5": "extraction",
        "L6": "synthesis",
    }
    for lid, status in layer_states.items():
        layer: dict[str, Any] = {
            "name": layer_names[lid],
            "status": status,
            "started": None,
            "completed": _now_iso() if status == "completed" else None,
            "outputs": [],
        }
        if lid == "L4":
            layer.update({"depth": "standard", "batch_progress": None, "partial": None})
        elif lid == "L5":
            layer.update({"depth": "standard", "module_progress": None, "partial": None})
        elif lid == "L6":
            layer["synthesis_mode"] = "full"
        state["layers"][lid] = layer

    _atomic_write_state(session_dir, state)
    return session_id


def init_or_load_session(project_path: Path) -> str:
    """Standalone sub-skill fallback — init session nếu chưa có, hoặc load latest.

    Fallback strategy:
    1. Nếu có active session (in_progress/paused) → use nó
    2. Nếu có v4.1 legacy ledger.json → migrate to scan-state, init new session
    3. Else → raise RuntimeError (user phải chạy /wf-legacy-scan trước)

    Args:
        project_path: Absolute path của project.

    Returns:
        session_id (string).

    Raises:
        RuntimeError: Không có prior scan (cả scan-state.json và ledger.json đều missing).
    """
    # Priority 1: active session.
    active = get_active_session_dir()
    if active is not None:
        return active.name

    # Priority 2: legacy v4.1 ledger.
    ledger_path = WORK_DIR / "ledger.json"
    if ledger_path.exists() and ledger_path.stat().st_size > 0:
        try:
            return _migrate_legacy_ledger(project_path, ledger_path)
        except (json.JSONDecodeError, OSError) as exc:
            raise RuntimeError(
                f"Legacy ledger.json corrupted: {exc}. "
                "Chạy /wf-legacy-scan lại để tái tạo session."
            ) from exc

    # Priority 3: fail.
    raise RuntimeError(
        "No prior scan found. Chạy /wf-legacy-scan trước khi dùng sub-skill."
    )


# ─── Phase E: L3 Intra-Batch Partial Checkpoint ──────────────

# Partial state file lives under the layer subdirectory để không contend
# với scan-state.json write throttle. Mỗi layer tối đa 1 partial file tại
# một thời điểm — được clear khi batch/module complete.
#
# Schema (04-data-model.md §1.1 — layers.L*.partial):
# {
#   "$schema": "layer-partial-v1",
#   "layer": "L4",
#   "batch_id": "batch-003",               # L4 only
#   "module": "billing",                   # L5 only
#   "completed_items": ["src/a.ts", ...],  # items processed inside batch/module
#   "current_item": "src/b.ts",            # item in-flight (may be lost on crash)
#   "started": "2026-04-22T10:12:05Z",
#   "updated": "2026-04-22T10:12:40Z"
# }


def _partial_path(session_dir: Path, layer_id: str) -> Path:
    """Resolve partial.json path cho layer — `layers/<L>/partial.json`."""
    return session_dir / "layers" / layer_id / "partial.json"


def write_layer_partial(
    layer_id: str,
    partial: dict[str, Any],
    session_id: str | None = None,
) -> None:
    """Write intra-batch partial state cho L4/L5 layer.

    Được gọi sau mỗi file/feature processed trong batch/module để đảm bảo
    crash mất tối đa 1 unit (ADR-LS11 "never lose more than 1 unit").

    Args:
        layer_id: L4 hoặc L5.
        partial: Partial state dict (batch_id/module, completed_items, current_item, ...).
        session_id: Optional session override.

    Raises:
        ValueError: layer_id không phải L4/L5.
    """
    if layer_id not in ("L4", "L5"):
        raise ValueError(
            f"partial checkpoint chỉ áp dụng cho L4/L5, not {layer_id!r}"
        )

    session_dir = _resolve_session_dir(session_id)
    path = _partial_path(session_dir, layer_id)
    path.parent.mkdir(parents=True, exist_ok=True)

    # Enrich với metadata.
    enriched = {
        "$schema": "layer-partial-v1",
        "layer": layer_id,
        **partial,
        "updated": _now_iso(),
    }
    enriched.setdefault("started", enriched["updated"])

    # Atomic write — direct (không qua scan-state throttle).
    tmp_path = path.with_suffix(f".json.tmp.{os.getpid()}")
    # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
    tmp_path.write_text(
        json.dumps(enriched, indent=2, ensure_ascii=False, sort_keys=True), encoding="utf-8"
    )
    try:
        with tmp_path.open("rb") as f:
            os.fsync(f.fileno())
    except (OSError, AttributeError):
        pass
    tmp_path.replace(path)

    # Cũng update layer.partial field trong scan-state.json (throttled) để
    # resume router có thể tìm partial file.
    relative = f"layers/{layer_id}/partial.json"
    try:
        state = read_scan_state(session_id)
        layer = state["layers"].get(layer_id)
        if layer is not None and layer.get("partial") != relative:
            layer["partial"] = relative
            _atomic_write_state(session_dir, state)
    except (FileNotFoundError, KeyError):
        # scan-state update is best-effort — partial file itself is the
        # canonical L3 checkpoint record.
        pass


def read_layer_partial(
    layer_id: str,
    session_id: str | None = None,
) -> dict[str, Any] | None:
    """Read intra-batch partial state cho L4/L5 layer.

    Returns None nếu không có partial (batch/module chưa start hoặc đã complete).

    Args:
        layer_id: L4 hoặc L5.
        session_id: Optional session override.
    """
    if layer_id not in ("L4", "L5"):
        raise ValueError(
            f"partial checkpoint chỉ áp dụng cho L4/L5, not {layer_id!r}"
        )

    session_dir = _resolve_session_dir(session_id)
    path = _partial_path(session_dir, layer_id)
    if not path.exists() or path.stat().st_size == 0:
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def clear_layer_partial(
    layer_id: str,
    session_id: str | None = None,
) -> None:
    """Clear partial file sau khi batch/module hoàn thành.

    Idempotent — no-op nếu file không tồn tại.

    Args:
        layer_id: L4 hoặc L5.
        session_id: Optional session override.
    """
    if layer_id not in ("L4", "L5"):
        raise ValueError(
            f"partial checkpoint chỉ áp dụng cho L4/L5, not {layer_id!r}"
        )

    session_dir = _resolve_session_dir(session_id)
    path = _partial_path(session_dir, layer_id)
    if path.exists():
        try:
            path.unlink()
        except OSError:
            pass

    # Clear layer.partial field trong scan-state.json (throttled).
    try:
        state = read_scan_state(session_id)
        layer = state["layers"].get(layer_id)
        if layer is not None and layer.get("partial"):
            layer["partial"] = None
            _atomic_write_state(session_dir, state)
    except (FileNotFoundError, KeyError):
        pass


# ─── Phase E: L0 Phase Checkpoint Update ─────────────────────


def update_last_completed(
    layer_id: str,
    session_id: str | None = None,
) -> None:
    """Update session.last_completed (L0 phase checkpoint).

    Phải gọi SAU khi layer transition từ in_progress → completed để resume
    router biết tới đâu.

    Args:
        layer_id: Layer vừa hoàn thành (L1..L6).
        session_id: Optional session override.
    """
    session_dir = _resolve_session_dir(session_id)
    state = read_scan_state(session_id)
    state["last_completed"] = layer_id
    # L0 phase checkpoint là CRITICAL — force write.
    _atomic_write_state(session_dir, state, force=True)
