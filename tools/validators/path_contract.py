"""Cross-skill path contract validator theo 00-core.md section 4b.

Kiem tra cac output paths giua cac skills phai ton tai va nhat quan.
Du lieu duoc hardcode tu bang Cross-Skill Output Path Contract.

Su dung:
    from validators.path_contract import validate_all_contracts, ContractEntry
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class ContractEntry:
    """Mot entry trong cross-skill output path contract.

    Attributes:
        producer: Skill tao ra output (VD: ``/wf-brainstorm``).
        output_path: Duong dan tuong doi tu ``.mc-data/``.
        consumer: Skill tiep theo su dung output.
        conditional: Dieu kien bat buoc (VD: ``interface_type != "api-only"``).
    """

    producer: str
    output_path: str
    consumer: str
    conditional: str | None = None


# ──────────────────────────────────────────────────────────────────────
# Hardcoded path contracts tu 00-core.md section 4b
# ──────────────────────────────────────────────────────────────────────

PATH_CONTRACTS: list[ContractEntry] = [
    # Brainstorm → downstream
    ContractEntry(
        producer="/wf-brainstorm",
        output_path="docs/_meta/project-digest.json",
        consumer="/wf-analyze-requirements",
    ),
    ContractEntry(
        producer="/wf-analyze-requirements",
        output_path="docs/_meta/dept-digests.json",
        consumer="/wf-define-features",
    ),
    ContractEntry(
        producer="/wf-analyze-requirements",
        output_path="docs/_meta/phase1-handoff.json",
        consumer="/wf-define-features",
    ),
    ContractEntry(
        producer="/wf-analyze-requirements",
        output_path="docs/phase1-business/stakeholder-review.md",
        consumer="/wf-define-features",
    ),
    ContractEntry(
        producer="/wf-define-features",
        output_path="docs/_meta/feature-briefs.json",
        consumer="/wf-design",
    ),
    ContractEntry(
        producer="/wf-define-features",
        output_path="docs/_meta/req-registry.json",
        consumer="/wf-design",
    ),
    ContractEntry(
        producer="/wf-design",
        output_path="docs/_meta/design-input-digest.json",
        consumer="/wf-design-ux",
    ),
    ContractEntry(
        producer="/wf-design",
        output_path="docs/_meta/design-input-digest.json",
        consumer="/wf-plan-modules",
    ),
    ContractEntry(
        producer="/wf-design",
        output_path="docs/phase3-architecture/stakeholder-review.md",
        consumer="/wf-design-ux",
    ),
    ContractEntry(
        producer="/wf-design-ux",
        output_path="docs/_meta/ux-input-digest.json",
        consumer="/wf-plan-modules",
        conditional="interface_type != 'api-only'",
    ),
    ContractEntry(
        producer="/wf-design-ux",
        output_path="docs/phase4-ux/design-system.md",
        consumer="/wf-plan-modules",
        conditional="interface_type != 'api-only'",
    ),
    ContractEntry(
        producer="/wf-plan-modules",
        output_path="docs/phase5-implementation/module-plan.md",
        consumer="/wf-implement-feature",
    ),
    ContractEntry(
        producer="/wf-plan-modules",
        output_path="docs/phase5-implementation/dependency-graph.md",
        consumer="/wf-implement-feature",
    ),
    ContractEntry(
        producer="/wf-plan-modules",
        output_path="docs/phase5-implementation/P5-00-implementation-roadmap.md",
        consumer="/wf-implement-feature",
    ),
    ContractEntry(
        producer="/wf-plan-modules",
        output_path="docs/phase5-implementation/stakeholder-review.md",
        consumer="/wf-implement-feature",
    ),
    ContractEntry(
        producer="/wf-implement-feature",
        output_path="docs/_meta/req-registry.json",
        consumer="/wf-preflight",
    ),
    ContractEntry(
        producer="/wf-preflight",
        output_path="work/wf-preflight/preflight-report.md",
        consumer="/wf-fix-bugs",
    ),
    ContractEntry(
        producer="/wf-verify-sync",
        output_path="docs/_meta/verify-sync.md",
        consumer="/wf-prepare-deployment",
    ),
    ContractEntry(
        producer="/wf-brainstorm",
        output_path="work/wf-brainstorm/legacy-decisions.json",
        consumer="/wf-analyze-requirements",
        conditional="LEGACY_MODE",
    ),
    ContractEntry(
        producer="/wf-legacy-scan",
        output_path="work/legacy-scan/project-context.md",
        consumer="/wf-brainstorm",
        conditional="LEGACY_MODE",
    ),
    ContractEntry(
        producer="/wf-legacy-scan",
        output_path="work/legacy-scan/module-code-mapping.json",
        consumer="/wf-annotate-code",
        conditional="LEGACY_MODE",
    ),
    ContractEntry(
        producer="/wf-define-features",
        output_path="work/wf-define-features/deferred-findings.md",
        consumer="/wf-design",
    ),
    ContractEntry(
        producer="/wf-design",
        output_path="work/wf-design/deferred-findings.md",
        consumer="/wf-plan-modules",
    ),
]


# ──────────────────────────────────────────────────────────────────────
# Internal helpers
# ──────────────────────────────────────────────────────────────────────


def _resolve_condition(
    condition: str | None,
    mc_data: Path,
) -> bool:
    """Kiem tra dieu kien cua contract.

    Hien ho tro:
        - ``interface_type != 'api-only'`` — doc tu req-registry.json.
        - ``LEGACY_MODE`` — kiem tra project-context.md ton tai va > 500 bytes.

    Args:
        condition: Chuoi dieu kien tu contract.
        mc_data: Duong dan ``.mc-data/``.

    Returns:
        True neu dieu kien thoa man hoac khong co dieu kien.
    """
    if condition is None:
        return True

    if condition == "LEGACY_MODE":
        ctx = mc_data / "work" / "legacy-scan" / "project-context.md"
        return ctx.exists() and ctx.stat().st_size > 500

    if "interface_type" in condition and "api-only" in condition:
        registry_path = mc_data / "docs" / "_meta" / "req-registry.json"
        if not registry_path.exists():
            return False
        try:
            data = json.loads(registry_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return False
        iface_type = data.get("interface_type", "")
        return iface_type != "api-only"

    # Dieu kien khong nhan dien — mac dinh la True
    return True


# ──────────────────────────────────────────────────────────────────────
# Public API
# ──────────────────────────────────────────────────────────────────────


def validate_contract(
    mc_data: Path,
    contract: ContractEntry,
) -> tuple[bool, str]:
    """Kiem tra mot contract entry: dieu kien va ton tai cua output path.

    Args:
        mc_data: Duong dan den thu muc ``.mc-data/``.
        contract: Contract entry can kiem tra.

    Returns:
        Tuple (exists, message).
        - ``(True, "...")`` — file ton tai.
        - ``(False, "...")`` — file khong ton tai hoac loi.
    """
    if not _resolve_condition(contract.conditional, mc_data):
        return True, f"SKIP: Dieu kien khong thoa ({contract.conditional})"

    full_path = mc_data / contract.output_path
    if full_path.exists():
        return True, f"OK: {contract.output_path}"

    return False, f"THIEU: {contract.output_path} (tu {contract.producer} → {contract.consumer})"


def validate_all_contracts(
    mc_data: Path,
) -> list[dict]:
    """Validate tat ca path contracts.

    Args:
        mc_data: Duong dan den thu muc ``.mc-data/``.

    Returns:
        Danh sach dicts voi keys: ``contract``, ``exists``, ``message``, ``status``.
        ``status`` la ``PASS``, ``FAIL``, hoac ``SKIP``.
    """
    results: list[dict] = []

    for contract in PATH_CONTRACTS:
        exists, message = validate_contract(mc_data, contract)

        if "SKIP" in message:
            status = "SKIP"
        elif exists:
            status = "PASS"
        else:
            status = "FAIL"

        results.append({
            "contract": contract,
            "exists": exists,
            "message": message,
            "status": status,
        })

    return results


def check_latest_pointer(
    sessions_dir: Path,
) -> tuple[bool, str]:
    """Kiem tra thu muc sessions co mtime ordering xac dinh.

    Khong co file ``latest`` that — chi verify rang session moi nhat
    (theo mtime) la xac dinh va khong bi ambiguous.

    Args:
        sessions_dir: Duong dan den thu muc ``sessions/``.

    Returns:
        Tuple (is_deterministic, message).
    """
    if not sessions_dir.exists():
        return False, f"Thu muc sessions khong ton tai: {sessions_dir}"

    session_dirs = [d for d in sessions_dir.iterdir() if d.is_dir()]
    if len(session_dirs) == 0:
        return True, "Khong co sessions — khong can kiem tra"

    # Sap xep theo mtime va kiem tra khong co ambiguitiet
    sorted_by_mtime = sorted(session_dirs, key=lambda d: d.stat().st_mtime)

    newest = sorted_by_mtime[-1]
    if len(sorted_by_mtime) >= 2:
        second_newest = sorted_by_mtime[-2]
        if newest.stat().st_mtime == second_newest.stat().st_mtime:
            return (
                False,
                f"Ambiguous mtime: {newest.name} va {second_newest.name} "
                f"co cung mtime — khong xac dinh duoc session moi nhat",
            )

    return True, f"Session moi nhat: {newest.name} (mtime deterministic)"
