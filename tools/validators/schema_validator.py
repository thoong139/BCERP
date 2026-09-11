"""Schema validator cho cac JSON output files trong .mc-data/.

Kiem tra:
    - JSON hop le (parse thanh cong)
    - Khong ton tai ``_template_notes`` (CORE-031 — output phai clean, khong template artifacts)
    - Co ``$schema`` field (cho dict-level files)

Su dung:
    from validators.schema_validator import validate_json_file, validate_all_meta_files
"""
from __future__ import annotations

import json
from pathlib import Path


# ──────────────────────────────────────────────────────────────────────
# Internal helpers
# ──────────────────────────────────────────────────────────────────────


def _walk_and_find_template_notes(
    data: dict | list,
    path: str = "",
) -> list[str]:
    """Duyet de quy tim tat ca ``_template_notes`` keys.

    Args:
        data: Dict hoac list can duyet.
        path: Duong dan hien tai (dung cho thong bao loi).

    Returns:
        Danh sach duong dan (JSON pointer style) tim thay ``_template_notes``.
    """
    violations: list[str] = []

    if isinstance(data, dict):
        for key, value in data.items():
            child_path = f"{path}.{key}" if path else key
            if key == "_template_notes":
                violations.append(child_path)
            violations.extend(_walk_and_find_template_notes(value, child_path))
    elif isinstance(data, list):
        for idx, item in enumerate(data):
            child_path = f"{path}[{idx}]"
            violations.extend(_walk_and_find_template_notes(item, child_path))

    return violations


# ──────────────────────────────────────────────────────────────────────
# Public API
# ──────────────────────────────────────────────────────────────────────


def validate_no_template_notes(
    data: dict | list,
    path: str = "",
) -> list[str]:
    """Kiem tra de quy khong ton tai ``_template_notes`` trong bat ky dict nao.

    Args:
        data: Dict hoac list can kiem tra.
        path: Duong dan goc (dung cho thong bao loi).

    Returns:
        Danh sach duong dan tim thay ``_template_notes``. Rong = hop le.
    """
    return _walk_and_find_template_notes(data, path)


def validate_json_file(path: Path) -> tuple[bool, list[str]]:
    """Validate mot JSON file: (1) hop le, (2) khong _template_notes, (3) co $schema.

    Args:
        path: Duong dan den JSON file.

    Returns:
        Tuple (is_valid, errors). ``is_valid=True`` khi khong co loi nao.
    """
    errors: list[str] = []

    if not path.exists():
        return False, [f"File khong ton tai: {path}"]

    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        return False, [f"Khong doc duoc file {path}: {exc}"]

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        return False, [f"JSON khong hop le tai {path}: {exc}"]

    # Rule 2: khong _template_notes
    template_violations = validate_no_template_notes(data)
    for v in template_violations:
        errors.append(f"Tim thay _template_notes tai: {v}")

    # Rule 3: phai co $schema neu la dict
    if isinstance(data, dict) and "$schema" not in data:
        errors.append(f"Thieu $schema trong {path.name}")

    return len(errors) == 0, errors


def validate_digest_file(path: Path) -> tuple[bool, list[str]]:
    """Validate digest files: JSON hop le, khong _template_notes, co $schema.

    Giong ``validate_json_file`` nhung danh rieng cho digest artifacts,
    giup test suite phan biet loai file.

    Args:
        path: Duong dan den digest JSON file.

    Returns:
        Tuple (is_valid, errors).
    """
    errors: list[str] = []

    if not path.exists():
        return False, [f"Digest file khong ton tai: {path}"]

    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        return False, [f"Khong doc duoc digest {path}: {exc}"]

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        return False, [f"Digest JSON khong hop le tai {path}: {exc}"]

    template_violations = validate_no_template_notes(data)
    for v in template_violations:
        errors.append(f"Tim thay _template_notes tai: {v}")

    if not isinstance(data, dict):
        errors.append(f"Digest phai la JSON object, thay {type(data).__name__}")
    elif "$schema" not in data:
        errors.append(f"Thieu $schema trong digest {path.name}")

    return len(errors) == 0, errors


def validate_all_meta_files(
    mc_data: Path,
) -> dict[str, tuple[bool, list[str]]]:
    """Scan va validate tat ca JSON files trong ``.mc-data/docs/_meta/``.

    Args:
        mc_data: Duong dan den thu muc ``.mc-data/``.

    Returns:
        Dict ten file -> (is_valid, errors).
    """
    meta_dir = mc_data / "docs" / "_meta"
    results: dict[str, tuple[bool, list[str]]] = {}

    if not meta_dir.exists():
        return results

    for json_file in sorted(meta_dir.glob("*.json")):
        is_valid, errors = validate_json_file(json_file)
        results[json_file.name] = (is_valid, errors)

    return results
