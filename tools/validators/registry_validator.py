"""Registry validator theo CORE-006/CORE-008/CORE-010.

Kiem tra:
    - Schema req-registry.json hop le ($schema, required keys)
    - impl_status chi nhan 4 gia tri: not_started, in_progress, done, skipped
    - Khong downgrade trang thai tu done sang gia tri khac (CORE-008)
    - Append-only cho sections (CORE-006 — wf-add-scope)

Su dung:
    from validators.registry_validator import validate_registry_schema, check_no_downgrade
"""
from __future__ import annotations

import json
from pathlib import Path

VALID_IMPL_STATUSES: frozenset[str] = frozenset({
    "not_started",
    "in_progress",
    "done",
    "skipped",
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
        return None, f"Registry phai la JSON object, thay {type(data).__name__}"

    return data, ""


# ──────────────────────────────────────────────────────────────────────
# Public API
# ──────────────────────────────────────────────────────────────────────


def validate_registry_schema(
    path: Path,
) -> tuple[bool, list[str]]:
    """Validate schema cua req-registry.json.

    Kiem tra:
        1. File la JSON hop le.
        2. Co ``$schema`` bat dau bang ``"req-registry-v"``.
        3. Co cac required keys: ``systems``, ``modules``, ``requirements``, ``features``.

    Args:
        path: Duong dan den req-registry.json.

    Returns:
        Tuple (is_valid, errors).
    """
    errors: list[str] = []

    data, load_error = _load_json(path)
    if data is None:
        return False, [load_error]

    # Rule 2: $schema
    schema = data.get("$schema", "")
    if not isinstance(schema, str) or not schema.startswith("req-registry-v"):
        errors.append(
            f"$schema phai bat dau bang 'req-registry-v', thay: {schema!r}"
        )

    # Rule 3: required keys
    required_keys = ("systems", "modules", "requirements", "features")
    for key in required_keys:
        if key not in data:
            errors.append(f"Thieu required key: {key}")
        elif not isinstance(data[key], list):
            errors.append(f"Key '{key}' phai la list, thay {type(data[key]).__name__}")

    return len(errors) == 0, errors


def validate_impl_statuses(
    path: Path,
) -> tuple[bool, list[str]]:
    """Kiem tra tat ca impl_status trong requirements va features la hop le.

    CORE-010: impl_status chi nhan 4 gia tri chinh thuc.

    Args:
        path: Duong dan den req-registry.json.

    Returns:
        Tuple (is_valid, errors).
    """
    errors: list[str] = []

    data, load_error = _load_json(path)
    if data is None:
        return False, [load_error]

    # Kiem tra requirements
    for req in data.get("requirements", []):
        req_id = req.get("id", "<unknown>")
        status = req.get("impl_status", "")
        if status not in VALID_IMPL_STATUSES:
            errors.append(
                f"Requirement {req_id}: impl_status={status!r} khong hop le "
                f"(cho: {sorted(VALID_IMPL_STATUSES)})"
            )

    # Kiem tra features
    for feat in data.get("features", []):
        feat_id = feat.get("id", "<unknown>")
        status = feat.get("impl_status", "")
        if status not in VALID_IMPL_STATUSES:
            errors.append(
                f"Feature {feat_id}: impl_status={status!r} khong hop le "
                f"(cho: {sorted(VALID_IMPL_STATUSES)})"
            )

    return len(errors) == 0, errors


def check_no_downgrade(
    before: Path,
    after: Path,
) -> tuple[bool, list[str]]:
    """So sanh hai registries, kiem tra khong co downgrade tu done.

    CORE-008: Khong downgrade impl_status tu ``done`` sang gia tri khac.

    Args:
        before: Duong dan den registry truoc khi thay doi.
        after: Duong dan den registry sau khi thay doi.

    Returns:
        Tuple (is_clean, violations).
    """
    violations: list[str] = []

    data_before, err_b = _load_json(before)
    data_after, err_a = _load_json(after)

    if data_before is None:
        return False, [f"Before: {err_b}"]
    if data_after is None:
        return False, [f"After: {err_a}"]

    # Map ID -> impl_status cho before
    before_map: dict[str, str] = {}
    for req in data_before.get("requirements", []):
        rid = req.get("id", "")
        if rid:
            before_map[rid] = req.get("impl_status", "not_started")

    for feat in data_before.get("features", []):
        fid = feat.get("id", "")
        if fid:
            before_map[f"[feat] {fid}"] = feat.get("impl_status", "not_started")

    # Map ID -> impl_status cho after
    after_map: dict[str, str] = {}
    for req in data_after.get("requirements", []):
        rid = req.get("id", "")
        if rid:
            after_map[rid] = req.get("impl_status", "not_started")

    for feat in data_after.get("features", []):
        fid = feat.get("id", "")
        if fid:
            after_map[f"[feat] {fid}"] = feat.get("impl_status", "not_started")

    # Kiem tra downgrade
    for item_id, before_status in before_map.items():
        if before_status == "done":
            after_status = after_map.get(item_id)
            if after_status is not None and after_status != "done":
                violations.append(
                    f"DOWNGRADE: {item_id} tu 'done' → '{after_status}'"
                )

    return len(violations) == 0, violations


def validate_append_only(
    before: Path,
    after: Path,
    section: str = "features",
) -> tuple[bool, list[str]]:
    """Kiem tra append-only: items trong before van ton tai trong after.

    CORE-006 (wf-add-scope role): Chi duoc them entries moi, khong modify/delete.

    Args:
        before: Duong dan den registry truoc khi thay doi.
        after: Duong dan den registry sau khi thay doi.
        section: Ten section can kiem tra (VD: ``"features"``, ``"modules"``).

    Returns:
        Tuple (is_clean, violations).
    """
    violations: list[str] = []

    data_before, err_b = _load_json(before)
    data_after, err_a = _load_json(after)

    if data_before is None:
        return False, [f"Before: {err_b}"]
    if data_after is None:
        return False, [f"After: {err_a}"]

    before_section = data_before.get(section, [])
    after_section = data_after.get(section, [])

    if not isinstance(before_section, list):
        return False, [f"Before.{section} khong phai list"]
    if not isinstance(after_section, list):
        return False, [f"After.{section} khong phai list"]

    # Map ID -> item cho after (de tim nhanh)
    after_by_id: dict[str, dict] = {}
    for item in after_section:
        if isinstance(item, dict) and "id" in item:
            after_by_id[item["id"]] = item

    for item in before_section:
        if not isinstance(item, dict):
            continue
        item_id = item.get("id")
        if item_id is None:
            continue

        # Kiem tra van ton tai
        if item_id not in after_by_id:
            violations.append(
                f"DELETED: {section}/{item_id} bi xoa trong after"
            )
            continue

        # Kiem tra noi dung khong doi (ngoai impl_status cho phep safe-update)
        after_item = after_by_id[item_id]
        for key, before_value in item.items():
            after_value = after_item.get(key)
            if key == "impl_status":
                # Cho phep upgrade nhung khong downgrade (da kiem tra rieng)
                continue
            if before_value != after_value:
                violations.append(
                    f"MODIFIED: {section}/{item_id}.{key} "
                    f"tu {before_value!r} → {after_value!r}"
                )

    return len(violations) == 0, violations
