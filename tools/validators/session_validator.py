"""Session isolation validator theo CORE-030 / Protocol 18.

Kiem tra:
    - session-state.json hop le (schema, required fields, status values)
    - Session isolation (khong trung session_id, khong co leak files)
    - Cleanup sessions cu
    - History append-only (sorted by timestamp)

Su dung:
    from validators.session_validator import validate_session_dir, validate_session_isolation
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path

_VALID_SESSION_STATUSES: frozenset[str] = frozenset({
    "in_progress",
    "completed",
    "failed",
    "paused",
})

_REQUIRED_SESSION_FIELDS: frozenset[str] = frozenset({
    "session_id",
    "skill_name",
    "created_at",
    "status",
})

# Cac file thuoc ve session — neu gap ngoai session dir thi la leak
_SESSION_FILES: frozenset[str] = frozenset({
    "session-state.json",
    "phase-summary.md",
    "session-log.json",
    "error-ledger.json",
    "events.jsonl",
    "scan-state.json",
    "scan-plan.md",
    "fix-status.json",
    "issue-registry.json",
    "fix-log.json",
    "fix-report.md",
    "coverage-report.md",
    "lane-report.md",
})


def _load_json(path: Path) -> tuple[dict | None, str]:
    """Doc va parse JSON file. Tra ve (data, error_message)."""
    if not path.exists():
        return None, f"File khong ton tai: {path}"

    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        return None, f"Khong doc duoc file {path}: {exc}"

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        return None, f"JSON khong hop le tai {path}: {exc}"

    if not isinstance(data, dict):
        return None, f"Phai la JSON object, thay {type(data).__name__}"

    return data, ""


def _check_no_template_notes(data: dict) -> list[str]:
    """Kiem tra khong co _template_notes trong data."""
    violations: list[str] = []

    def _walk(obj: dict | list, path: str = "") -> None:
        if isinstance(obj, dict):
            for key, value in obj.items():
                child = f"{path}.{key}" if path else key
                if key == "_template_notes":
                    violations.append(child)
                _walk(value, child)
        elif isinstance(obj, list):
            for idx, item in enumerate(obj):
                _walk(item, f"{path}[{idx}]")

    _walk(data)
    return violations


# ──────────────────────────────────────────────────────────────────────
# Public API
# ──────────────────────────────────────────────────────────────────────


def validate_session_dir(
    session_dir: Path,
) -> tuple[bool, list[str]]:
    """Validate mot session directory.

    Kiem tra:
        1. session-state.json ton tai va la JSON hop le.
        2. Co ``$schema: "session-state-v1"``.
        3. Co required fields: session_id, skill_name, created_at, status.
        4. status la gia tri hop le (in_progress/completed/failed/paused).
        5. Khong co ``_template_notes``.

    Args:
        session_dir: Duong dan den thu muc session.

    Returns:
        Tuple (is_valid, errors).
    """
    errors: list[str] = []

    state_path = session_dir / "session-state.json"
    data, load_error = _load_json(state_path)
    if data is None:
        return False, [load_error]

    # Rule 2: $schema
    schema = data.get("$schema", "")
    if schema != "session-state-v1":
        errors.append(
            f"$schema phai la 'session-state-v1', thay: {schema!r}"
        )

    # Rule 3: required fields
    for field_name in _REQUIRED_SESSION_FIELDS:
        if field_name not in data:
            errors.append(f"Thieu required field: {field_name}")
        elif not data[field_name]:
            errors.append(f"Required field rong: {field_name}")

    # Rule 4: status hop le
    status = data.get("status", "")
    if status and status not in _VALID_SESSION_STATUSES:
        errors.append(
            f"Status khong hop le: {status!r} "
            f"(cho: {sorted(_VALID_SESSION_STATUSES)})"
        )

    # Rule 5: khong _template_notes
    template_violations = _check_no_template_notes(data)
    for v in template_violations:
        errors.append(f"Tim thay _template_notes tai: {v}")

    return len(errors) == 0, errors


def validate_session_isolation(
    sessions_root: Path,
) -> tuple[bool, list[str]]:
    """Kiem tra session isolation cho tat ca sessions.

    Kiem tra:
        1. Moi session co session-state.json hop le.
        2. Khong co hai sessions cung session_id.
        3. Khong co session files nam ngoai session dirs (root leak).

    Args:
        sessions_root: Duong dan den thu muc ``sessions/``.

    Returns:
        Tuple (is_clean, errors).
    """
    errors: list[str] = []

    if not sessions_root.exists():
        return False, [f"Thu muc sessions khong ton tai: {sessions_root}"]

    session_dirs = sorted(
        [d for d in sessions_root.iterdir() if d.is_dir()]
    )

    if not session_dirs:
        return True, []

    # Rule 1 + 2: moi session hop le va khong trung session_id
    seen_ids: dict[str, Path] = {}
    for sdir in session_dirs:
        is_valid, session_errors = validate_session_dir(sdir)
        if not is_valid:
            for err in session_errors:
                errors.append(f"{sdir.name}: {err}")

        # Kiem tra session_id unique
        state_path = sdir / "session-state.json"
        if state_path.exists():
            try:
                state = json.loads(state_path.read_text(encoding="utf-8"))
                sid = state.get("session_id", "")
                if sid:
                    if sid in seen_ids:
                        errors.append(
                            f"Trung session_id '{sid}' giua "
                            f"{seen_ids[sid].name} va {sdir.name}"
                        )
                    else:
                        seen_ids[sid] = sdir
            except (json.JSONDecodeError, OSError):
                pass  # Da bao loi o validate_session_dir

    # Rule 3: khong co session files nam ngoai session dirs
    for item in sessions_root.iterdir():
        if item.is_file() and item.name in _SESSION_FILES:
            errors.append(
                f"Session file leak: {item.name} nam ngoai session dir "
                f"(nen nam trong sessions/<id>/)"
            )

    return len(errors) == 0, errors


def cleanup_old_sessions(
    sessions_root: Path,
    keep: int = 5,
) -> list[Path]:
    """Giu lai ``keep`` sessions moi nhat (theo mtime), xoa phan con lai.

    Args:
        sessions_root: Duong dan den thu muc ``sessions/``.
        keep: So luong sessions can giu lai.

    Returns:
        Danh sach cac duong dan da bi xoa.
    """
    if not sessions_root.exists():
        return []

    session_dirs = sorted(
        [d for d in sessions_root.iterdir() if d.is_dir()],
        key=lambda d: d.stat().st_mtime,
        reverse=True,
    )

    to_keep = session_dirs[:keep]
    to_delete = session_dirs[keep:]

    deleted: list[Path] = []
    for sdir in to_delete:
        shutil.rmtree(sdir)
        deleted.append(sdir)

    return deleted


def find_latest_session(
    sessions_root: Path,
) -> Path | None:
    """Tim session moi nhat theo mtime.

    Args:
        sessions_root: Duong dan den thu muc ``sessions/``.

    Returns:
        Duong dan den session moi nhat, hoac ``None`` neu khong co.
    """
    if not sessions_root.exists():
        return None

    session_dirs = [d for d in sessions_root.iterdir() if d.is_dir()]
    if not session_dirs:
        return None

    return max(session_dirs, key=lambda d: d.stat().st_mtime)


def validate_history_append(
    history_path: Path,
) -> tuple[bool, list[str]]:
    """Validate _shared/history.json: JSON array va entries sorted by timestamp.

    Args:
        history_path: Duong dan den history.json.

    Returns:
        Tuple (is_valid, errors).
    """
    errors: list[str] = []

    if not history_path.exists():
        return True, []  # History file khong bat buoc

    try:
        raw = history_path.read_text(encoding="utf-8")
    except OSError as exc:
        return False, [f"Khong doc duoc history: {exc}"]

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        return False, [f"History JSON khong hop le: {exc}"]

    if not isinstance(data, list):
        return False, [f"History phai la JSON array, thay {type(data).__name__}"]

    # Kiem tra moi entry co timestamp va sorted
    timestamps: list[str] = []
    for idx, entry in enumerate(data):
        if not isinstance(entry, dict):
            errors.append(f"Entry [{idx}] khong phai dict")
            continue
        ts = entry.get("timestamp")
        if ts is None:
            errors.append(f"Entry [{idx}] thieu 'timestamp'")
        else:
            timestamps.append(str(ts))

    # Kiem tra sorted
    if timestamps and timestamps != sorted(timestamps):
        errors.append("History entries khong duoc sap xep theo timestamp")

    return len(errors) == 0, errors
