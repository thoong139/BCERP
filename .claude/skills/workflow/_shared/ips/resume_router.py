"""Resume Router — 4-Level state-aware routing cho /wf-legacy-scan --resume.

Mục đích:
- Đọc scan-state.json của latest active session (hoặc session cụ thể qua
  `--session=ID`), decide finest-granularity resumption point theo 4 cấp
  checkpoint (L0 phase, L1 layer, L2 batch/module, L3 intra-batch).
- Trả về action payload JSON (stdout) để bash caller switch và route
  vào đúng phase procedure.

Routing table (reference: 03-architecture.md §2.2):

| last_completed | layer status | progress | partial | action_type |
|----------------|--------------|----------|---------|-------------|
| init           | —            | —        | —       | start_L1 |
| L1             | —            | —        | —       | start_L2 (re-run IPS-A) |
| L2             | —            | —        | —       | start_L3 |
| L3             | —            | —        | —       | start_L4 (re-run IPS-B if missing) |
| L4             | in_progress  | batch=N  | none    | resume_L4_batch |
| L4             | in_progress  | batch=N  | file=M  | resume_L4_intra_batch |
| L4             | completed    | —        | —       | start_L5 |
| L5             | in_progress  | module=X | none    | resume_L5_module |
| L5             | in_progress  | module=X | feat=Y  | resume_L5_intra_module |
| L5             | completed    | —        | —       | start_L6 |
| L6             | in_progress  | —        | —       | resume_L6_regenerate |
| completed      | —            | —        | —       | session_already_completed |

Edge cases:
- Không có session → no_resumable_session (suggest fresh start).
- `last_completed == "migrated"` → delegate_legacy_subskill (v4.1 ledger import).
- scan-state.json corrupted / schema invalid → fallback_legacy_ledger.

Reference:
- docs/design/skills/wf-legacy-scan/03-architecture.md §2.2 (routing table)
- docs/design/skills/wf-legacy-scan/04-data-model.md §1.1 (scan-state schema)
- Phase H plan: phases/phase-H-resume-routing.md

Lifecycle:
- Phase H (v5.0): initial implementation + CLI + tests.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Any

from . import scan_state_reader as ssr

# ─── Constants ───────────────────────────────────────────────

# Action type enum (stable contract cho bash caller switch).
ACTION_START_L1 = "start_L1"
ACTION_START_L2 = "start_L2_rerun_ips_a"
ACTION_START_L3 = "start_L3"
ACTION_START_L4 = "start_L4_rerun_ips_b_if_missing"
ACTION_RESUME_L4_BATCH = "resume_L4_batch"
ACTION_RESUME_L4_INTRA_BATCH = "resume_L4_intra_batch"
ACTION_START_L5 = "start_L5"
ACTION_RESUME_L5_MODULE = "resume_L5_module"
ACTION_RESUME_L5_INTRA_MODULE = "resume_L5_intra_module"
ACTION_START_L6 = "start_L6"
ACTION_RESUME_L6 = "resume_L6_regenerate"
ACTION_SESSION_COMPLETED = "session_already_completed"
ACTION_NO_RESUMABLE = "no_resumable_session"
ACTION_DELEGATE_LEGACY = "delegate_legacy_subskill"
ACTION_FALLBACK_LEDGER = "fallback_legacy_ledger"
ACTION_SESSION_INVALID = "session_invalid"

# Layers ordered by pipeline position.
_LAYER_ORDER: list[str] = ["L1", "L2", "L3", "L4", "L5", "L6"]


def is_lock_stale(lock_path: str | Path, max_age_seconds: int = 3600) -> bool:
    """Kiểm tra xem session lock file có bị stale không (mtime > max_age_seconds).

    Args:
        lock_path: Đường dẫn đến lock file (`.session.lock`).
        max_age_seconds: Ngưỡng stale tính bằng giây (default 3600 = 1 giờ).

    Returns:
        True nếu lock tồn tại và mtime cũ hơn max_age_seconds. False nếu lock
        không tồn tại hoặc còn mới.
    """
    p = Path(lock_path)
    if not p.exists():
        return False
    age = time.time() - p.stat().st_mtime
    return age > max_age_seconds


# ─── Public API ──────────────────────────────────────────────


def find_latest_active_session() -> Path | None:
    """Thin wrapper around `scan_state_reader.get_active_session_dir()`.

    Re-exported tại module level để bash caller có 1 điểm vào duy nhất
    cho resume routing (thay vì import chéo nhiều module).
    """
    return ssr.get_active_session_dir()


def decide_resume_action(state: dict[str, Any]) -> dict[str, Any]:
    """Decide resume action dict từ scan-state (pure function, no I/O).

    Inspect `state.last_completed` + per-layer status/progress/partial và
    trả về action payload mô tả:
    - `action_type` (categorical — stable enum cho bash switch).
    - `next_layer` — layer cần resume/start tiếp theo.
    - `resume_unit` — finest-granularity unit (batch / module / partial item).
    - `notes[]` — chuỗi hint dành cho orchestrator và user.

    Args:
        state: Parsed scan-state dict (đã validate có `last_completed`,
            `layers`, `status`).

    Returns:
        Action payload dict — xem module docstring for schema.

    Raises:
        ValueError: `state` thiếu required keys hoặc có giá trị không
            hợp lệ (schema validation fail).
    """
    # ── 1. Schema validation ──────────────────────────────────
    if not isinstance(state, dict):
        raise ValueError("state must be a dict")

    if "last_completed" not in state:
        raise ValueError("state missing 'last_completed' field")

    if "layers" not in state or not isinstance(state["layers"], dict):
        raise ValueError("state missing 'layers' dict")

    last = state["last_completed"]
    session_status = state.get("status", "in_progress")
    layers = state["layers"]

    # ── 2. Terminal states ────────────────────────────────────
    if session_status == "completed" or last == "completed":
        return _build_action(
            action_type=ACTION_SESSION_COMPLETED,
            next_layer=None,
            resume_unit=None,
            notes=[
                "Session đã hoàn thành tất cả 6 layers.",
                "Dùng `--status` để xem kết quả hoặc `--re-vision` để re-scan.",
            ],
            state=state,
        )

    if last == "migrated":
        # init_or_load_session() đã migrate v4.1 ledger — delegate resume
        # cho sub-skill đang chạy (classify/extract).
        return _build_action(
            action_type=ACTION_DELEGATE_LEGACY,
            next_layer=None,
            resume_unit=None,
            notes=[
                "Session migrated từ v4.1 ledger.json.",
                "Dùng `/wf-legacy-classify --resume` hoặc `/wf-legacy-extract --resume` để tiếp tục sub-skill.",
            ],
            state=state,
        )

    # ── 3. Status-aware override ──────────────────────────────
    # Nếu L4 hoặc L5 đang in_progress, bất kể last_completed giá trị gì,
    # ưu tiên resume layer in_progress đó. Crash xảy ra giữa layer work
    # thường đóng băng last_completed ở layer TRƯỚC (vd: last_completed=L3
    # nhưng L4 đã in_progress). Router phải detect trạng thái này.
    l4_status = layers.get("L4", {}).get("status", "not_started")
    l5_status = layers.get("L5", {}).get("status", "not_started")
    l6_status = layers.get("L6", {}).get("status", "not_started")

    if l5_status == "in_progress":
        return _decide_l5_resume(state, layers)

    if l4_status == "in_progress":
        return _decide_l4_resume(state, layers)

    if l6_status == "in_progress":
        return _build_action(
            action_type=ACTION_RESUME_L6,
            next_layer="L6",
            resume_unit=None,
            notes=[
                "L6 Synthesis đang in_progress — regenerate project-context.md từ L1-L5 outputs.",
            ],
            state=state,
        )

    # ── 4. Layer-by-layer routing via last_completed ─────────
    if last == "init":
        return _build_action(
            action_type=ACTION_START_L1,
            next_layer="L1",
            resume_unit=None,
            notes=["Chưa có layer nào hoàn thành — start L1 Discovery từ đầu."],
            state=state,
        )

    if last == "L1":
        return _build_action(
            action_type=ACTION_START_L2,
            next_layer="L2",
            resume_unit=None,
            notes=[
                "L1 Discovery đã xong.",
                "Start L2 Assessment — re-run IPS Phase A (domain hints) vì signal sau L1 đã đủ.",
            ],
            state=state,
        )

    if last == "L2":
        return _build_action(
            action_type=ACTION_START_L3,
            next_layer="L3",
            resume_unit=None,
            notes=["L2 Assessment đã xong — start L3 Inventory."],
            state=state,
        )

    if last == "L3":
        ips_b_present = bool(state.get("ips", {}).get("phase_b"))
        hint = "Start L4 Classification."
        if not ips_b_present:
            hint += " IPS Phase B chưa có — sẽ re-run để enrich domain confidence."
        return _build_action(
            action_type=ACTION_START_L4,
            next_layer="L4",
            resume_unit=None,
            notes=[hint],
            state=state,
        )

    if last == "L4":
        # last_completed=L4 + L4.status=completed → L5 sắp bắt đầu.
        # L4.status=in_progress đã được xử lý ở status-aware override ở trên.
        return _decide_l4_resume(state, layers)

    if last == "L5":
        return _decide_l5_resume(state, layers)

    if last == "L6":
        # L6 layer có thể in_progress (crash khi regenerate) hoặc completed.
        l6_status = layers.get("L6", {}).get("status", "not_started")
        if l6_status == "completed":
            return _build_action(
                action_type=ACTION_SESSION_COMPLETED,
                next_layer=None,
                resume_unit=None,
                notes=["L6 Synthesis đã xong — session complete."],
                state=state,
            )
        return _build_action(
            action_type=ACTION_RESUME_L6,
            next_layer="L6",
            resume_unit=None,
            notes=[
                "L6 Synthesis dở dang — regenerate project-context.md từ L1-L5 outputs.",
            ],
            state=state,
        )

    # ── 4. Unknown last_completed value ───────────────────────
    raise ValueError(
        f"Unknown last_completed value: {last!r}. "
        "Expected one of: init, L1..L6, completed, migrated."
    )


def route_resume(session_id: str | None = None) -> dict[str, Any]:
    """Full resume router — discover session, read state, decide action.

    Bash caller invoke qua CLI (`python -m ips.resume_router`) và nhận
    action payload JSON trên stdout.

    Args:
        session_id: Optional session identifier. Nếu None → auto-discover
            latest active session.

    Returns:
        Action payload dict với `action_type`, `session_id`, `session_dir`,
        etc. (xem `_build_action`). Nếu không có session → `ACTION_NO_RESUMABLE`.
    """
    # ── 1. Session discovery / resolution ─────────────────────
    try:
        if session_id:
            session_dir = ssr.WORK_DIR / "sessions" / session_id
            if not session_dir.exists():
                return {
                    "action_type": ACTION_NO_RESUMABLE,
                    "session_id": session_id,
                    "session_dir": None,
                    "last_completed": None,
                    "next_layer": None,
                    "resume_unit": None,
                    "notes": [
                        f"Session '{session_id}' not found.",
                        "Kiểm tra lại session ID hoặc chạy `/wf-legacy-scan [project-path]` để bắt đầu mới.",
                    ],
                    "depth_map": None,
                    "strategy": None,
                    "ips_phase_a_available": False,
                    "ips_phase_b_available": False,
                }
        else:
            session_dir = find_latest_active_session()
            if session_dir is None:
                return {
                    "action_type": ACTION_NO_RESUMABLE,
                    "session_id": None,
                    "session_dir": None,
                    "last_completed": None,
                    "next_layer": None,
                    "resume_unit": None,
                    "notes": [
                        "Không tìm thấy active session nào.",
                        "Chạy `/wf-legacy-scan [project-path]` để bắt đầu mới.",
                    ],
                    "depth_map": None,
                    "strategy": None,
                    "ips_phase_a_available": False,
                    "ips_phase_b_available": False,
                }
    except OSError as exc:
        return {
            "action_type": ACTION_SESSION_INVALID,
            "session_id": session_id,
            "session_dir": None,
            "last_completed": None,
            "next_layer": None,
            "resume_unit": None,
            "notes": [f"IO error khi resolve session: {exc}"],
            "depth_map": None,
            "strategy": None,
            "ips_phase_a_available": False,
            "ips_phase_b_available": False,
        }

    # ── 2. Read scan-state.json ───────────────────────────────
    state_path = session_dir / "scan-state.json"
    if not state_path.exists():
        return _fallback_action(
            session_dir,
            reason=f"scan-state.json not found at {state_path}",
        )

    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return _fallback_action(
            session_dir,
            reason=f"scan-state.json corrupted: {exc}",
        )

    # ── 3. Decide action ──────────────────────────────────────
    try:
        action = decide_resume_action(state)
    except ValueError as exc:
        return _fallback_action(
            session_dir,
            reason=f"scan-state.json schema invalid: {exc}",
        )

    # ── 4. Enrich với session metadata ────────────────────────
    action["session_id"] = state.get("session", {}).get("id") or session_dir.name
    action["session_dir"] = str(session_dir)
    return action


# ─── Internal helpers ────────────────────────────────────────


def _build_action(
    action_type: str,
    next_layer: str | None,
    resume_unit: dict[str, Any] | None,
    notes: list[str],
    state: dict[str, Any],
) -> dict[str, Any]:
    """Build action payload với metadata từ state (depth_map, strategy, IPS)."""
    session = state.get("session", {})
    ips = state.get("ips", {})
    return {
        "action_type": action_type,
        "session_id": session.get("id"),
        "session_dir": None,  # filled by route_resume()
        "last_completed": state.get("last_completed"),
        "next_layer": next_layer,
        "resume_unit": resume_unit,
        "notes": notes,
        "depth_map": state.get("depth_map"),
        "strategy": session.get("strategy"),
        "profile": session.get("profile"),
        "ips_phase_a_available": ips.get("phase_a") is not None,
        "ips_phase_b_available": ips.get("phase_b") is not None,
    }


def _decide_l4_resume(
    state: dict[str, Any],
    layers: dict[str, Any],
) -> dict[str, Any]:
    """Decide action when last_completed == 'L4'."""
    l4 = layers.get("L4", {})
    l4_status = l4.get("status", "not_started")

    if l4_status == "completed":
        return _build_action(
            action_type=ACTION_START_L5,
            next_layer="L5",
            resume_unit=None,
            notes=["L4 Classification đã xong — start L5 Extraction."],
            state=state,
        )

    # L4 in_progress hoặc failed → resume từ batch_progress / partial.
    batch_progress = l4.get("batch_progress") or {}
    current_batch = batch_progress.get("current")
    total_batches = batch_progress.get("total")
    completed_batches = batch_progress.get("completed_batches") or []
    partial = l4.get("partial")

    resume_unit: dict[str, Any] = {
        "layer": "L4",
        "current_batch": current_batch,
        "total_batches": total_batches,
        "completed_batches": completed_batches,
    }

    # Partial intra-batch (L3 checkpoint) — load partial.json cho detail.
    if partial:
        partial_data = _load_partial(state, "L4")
        if partial_data is not None:
            resume_unit["partial"] = partial
            resume_unit["completed_items"] = partial_data.get(
                "completed_items", []
            )
            resume_unit["in_flight_item"] = partial_data.get("current_item")
            return _build_action(
                action_type=ACTION_RESUME_L4_INTRA_BATCH,
                next_layer="L4",
                resume_unit=resume_unit,
                notes=[
                    f"L4 batch {current_batch or '?'} dở dang ở intra-batch.",
                    "Resume từ file tiếp theo sau `in_flight_item` — crash mất tối đa 1 unit.",
                ],
                state=state,
            )

    # Batch-level checkpoint — resume từ batch hiện tại.
    return _build_action(
        action_type=ACTION_RESUME_L4_BATCH,
        next_layer="L4",
        resume_unit=resume_unit,
        notes=[
            f"L4 dở dang tại batch {current_batch or '?'}/{total_batches or '?'}.",
            "Resume từ đầu batch này (đã complete các batches trước).",
        ],
        state=state,
    )


def _decide_l5_resume(
    state: dict[str, Any],
    layers: dict[str, Any],
) -> dict[str, Any]:
    """Decide action when last_completed == 'L5'."""
    l5 = layers.get("L5", {})
    l5_status = l5.get("status", "not_started")

    if l5_status == "completed":
        return _build_action(
            action_type=ACTION_START_L6,
            next_layer="L6",
            resume_unit=None,
            notes=["L5 Extraction đã xong — start L6 Synthesis."],
            state=state,
        )

    module_progress = l5.get("module_progress") or {}
    current_module = module_progress.get("current")
    total_modules = module_progress.get("total")
    completed_modules = module_progress.get("completed_modules") or []
    partial = l5.get("partial")

    resume_unit: dict[str, Any] = {
        "layer": "L5",
        "current_module": current_module,
        "total_modules": total_modules,
        "completed_modules": completed_modules,
    }

    if partial:
        partial_data = _load_partial(state, "L5")
        if partial_data is not None:
            resume_unit["partial"] = partial
            resume_unit["completed_items"] = partial_data.get(
                "completed_items", []
            )
            resume_unit["in_flight_item"] = partial_data.get("current_item")
            return _build_action(
                action_type=ACTION_RESUME_L5_INTRA_MODULE,
                next_layer="L5",
                resume_unit=resume_unit,
                notes=[
                    f"L5 module '{current_module or '?'}' dở dang ở intra-module.",
                    "Resume từ feature tiếp theo sau `in_flight_item` — crash mất tối đa 1 unit.",
                ],
                state=state,
            )

    return _build_action(
        action_type=ACTION_RESUME_L5_MODULE,
        next_layer="L5",
        resume_unit=resume_unit,
        notes=[
            f"L5 dở dang tại module '{current_module or '?'}' ({len(completed_modules)}/{total_modules or '?'} completed).",
            "Resume từ đầu module này (đã complete các modules trước).",
        ],
        state=state,
    )


def _load_partial(
    state: dict[str, Any], layer_id: str
) -> dict[str, Any] | None:
    """Load partial.json cho layer — trả về None nếu file missing/corrupt."""
    session_id = state.get("session", {}).get("id")
    if not session_id:
        return None
    try:
        return ssr.read_layer_partial(layer_id, session_id=session_id)
    except (ValueError, FileNotFoundError, OSError):
        return None


def _fallback_action(session_dir: Path, reason: str) -> dict[str, Any]:
    """Fallback action khi scan-state.json missing/corrupt.

    Kiểm tra xem có legacy v4.1 ledger.json không — nếu có, suggest
    dùng ledger fallback path; nếu không, báo session invalid.
    """
    ledger_path = ssr.WORK_DIR / "ledger.json"
    if ledger_path.exists() and ledger_path.stat().st_size > 0:
        return {
            "action_type": ACTION_FALLBACK_LEDGER,
            "session_id": session_dir.name if session_dir else None,
            "session_dir": str(session_dir) if session_dir else None,
            "last_completed": None,
            "next_layer": None,
            "resume_unit": None,
            "notes": [
                f"scan-state.json không dùng được ({reason}).",
                "Phát hiện v4.1 ledger.json — fallback qua init_or_load_session() để migrate.",
            ],
            "depth_map": None,
            "strategy": None,
            "profile": None,
            "ips_phase_a_available": False,
            "ips_phase_b_available": False,
        }

    return {
        "action_type": ACTION_SESSION_INVALID,
        "session_id": session_dir.name if session_dir else None,
        "session_dir": str(session_dir) if session_dir else None,
        "last_completed": None,
        "next_layer": None,
        "resume_unit": None,
        "notes": [
            f"Session không resume được: {reason}.",
            "Xem `--status` để chẩn đoán hoặc chạy `/wf-legacy-scan` mới.",
        ],
        "depth_map": None,
        "strategy": None,
        "profile": None,
        "ips_phase_a_available": False,
        "ips_phase_b_available": False,
    }


# ─── CLI entry ───────────────────────────────────────────────


def _cli(argv: list[str] | None = None) -> int:
    """CLI entry cho bash caller.

    Usage:
        python -m ips.resume_router [--session=ID]

    Emits action payload JSON to stdout. Exit code:
    - 0: action resolved (including no_resumable_session / session_completed).
    - 2: session ID explicitly provided nhưng không tồn tại (distinct from
         natural no_resumable — giúp bash caller phân biệt user error).
    """
    # Force UTF-8 stdout để tránh UnicodeEncodeError trên Windows cmd (cp1252).
    # JSON output + Vietnamese notes đều cần UTF-8.
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
        except (AttributeError, OSError):
            pass

    parser = argparse.ArgumentParser(
        prog="ips.resume_router",
        description=(
            "4-Level Resume Router for /wf-legacy-scan --resume. "
            "Discovers active session, reads scan-state.json, and decides "
            "finest-granularity resumption action."
        ),
    )
    parser.add_argument(
        "--session",
        dest="session_id",
        default=None,
        help="Explicit session ID (default: auto-discover latest active).",
    )
    parser.add_argument(
        "--work-dir",
        dest="work_dir",
        default=None,
        help="Override WORK_DIR for scan-state lookup (test/dev only).",
    )
    args = parser.parse_args(argv)

    if args.work_dir:
        ssr.WORK_DIR = Path(args.work_dir)

    action = route_resume(session_id=args.session_id)
    sys.stdout.write(json.dumps(action, indent=2, ensure_ascii=False))
    sys.stdout.write("\n")

    # Distinguish user-provided session ID không tồn tại khỏi no-session-at-all.
    if (
        action["action_type"] == ACTION_NO_RESUMABLE
        and args.session_id is not None
    ):
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(_cli())
