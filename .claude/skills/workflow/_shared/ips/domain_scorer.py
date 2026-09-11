"""Domain Scorer — unify EN + VN domain signals into scored output.

Reference:
- docs/design/skills/wf-legacy-scan/05-profiles-ips.md §3.2-3.3 (IPS algorithm)
- docs/design/skills/wf-legacy-scan/05-profiles-ips.md §3.4 (Detection rules table)
- docs/design/skills/wf-legacy-scan/10-vietnamese-keywords.md §3 (VN rules)

Public API:
- EN_RULES: Table cua English signal rules (domain, signal, weight).
- detect_en(profile, inventory) -> list[DomainSignal VN-shape]
- score_domains(profile, inventory?) -> list[dict]  (merged EN + VN, aggregated)
- score_signals(signals, ...) -> list[dict]  (pure aggregation utility)
"""

from __future__ import annotations

from collections import defaultdict
from typing import Any

from .vietnamese_keywords import (
    DomainSignal,
    aggregate_signals_by_domain,
    detect_modules_vn,
    load_pool,
)


# ─── English Signal Rules (tu 05-profiles-ips.md §3.4) ───────


# Keyed by domain. Each entry is (keyword, weight, signal_type).
# signal_type: "package_dep" | "directory" | "framework".
EN_RULES: dict[str, list[tuple[str, float, str]]] = {
    "finance": [
        ("decimal.js", 0.3, "package_dep"),
        ("money.js", 0.3, "package_dep"),
        ("currency.js", 0.3, "package_dep"),
        ("billing", 0.4, "directory"),
        ("invoice", 0.4, "directory"),
        ("payment", 0.4, "directory"),
        ("tax", 0.4, "directory"),
        ("ledger", 0.35, "directory"),
        ("accounting", 0.35, "directory"),
    ],
    "procurement": [
        ("procurement", 0.4, "directory"),
        ("sourcing", 0.4, "directory"),
        ("vendor", 0.4, "directory"),
        ("supplier", 0.35, "directory"),
        ("rfq", 0.3, "directory"),
    ],
    "sales": [
        ("sales", 0.4, "directory"),
        ("crm", 0.4, "directory"),
        ("pipeline", 0.4, "directory"),
        ("lead", 0.35, "directory"),
        ("opportunity", 0.3, "directory"),
        ("customer", 0.35, "directory"),
        ("quote", 0.3, "directory"),
    ],
    "hr": [
        ("hr", 0.4, "directory"),
        ("payroll", 0.4, "directory"),
        ("leave", 0.4, "directory"),
        ("benefits", 0.35, "directory"),
        ("employee", 0.3, "directory"),
        ("recruitment", 0.3, "directory"),
    ],
    "ecommerce": [
        ("cart", 0.4, "directory"),
        ("checkout", 0.4, "directory"),
        ("catalog", 0.4, "directory"),
        ("storefront", 0.35, "directory"),
        ("shopify", 0.3, "package_dep"),
    ],
    "operations": [
        ("inventory", 0.4, "directory"),
        ("warehouse", 0.4, "directory"),
        ("stock", 0.4, "directory"),
    ],
    "compliance": [
        ("audit", 0.4, "directory"),
        ("compliance", 0.4, "directory"),
        ("regulatory", 0.4, "directory"),
        ("governance", 0.3, "directory"),
    ],
    "healthcare": [
        ("fhir", 0.7, "package_dep"),
        ("hl7", 0.7, "package_dep"),
        ("openemr", 0.6, "package_dep"),
        ("patient", 0.4, "directory"),
        ("clinical", 0.4, "directory"),
        ("prescription", 0.4, "directory"),
        ("bhyt", 0.4, "directory"),
    ],
    "logistics": [
        ("shipping", 0.4, "directory"),
        ("customs", 0.4, "directory"),
        ("tms", 0.4, "directory"),
        ("wms", 0.4, "directory"),
        ("delivery", 0.35, "directory"),
        ("freight", 0.3, "directory"),
    ],
    "manufacturing": [
        ("bom", 0.4, "directory"),
        ("production", 0.4, "directory"),
        ("mrp", 0.4, "directory"),
        ("mes", 0.35, "directory"),
    ],
    "retail": [
        ("pos", 0.4, "directory"),
        ("store", 0.4, "directory"),
        ("cashier", 0.4, "directory"),
        ("loyalty", 0.3, "directory"),
    ],
    "legal": [
        ("contract", 0.4, "directory"),
        ("legal", 0.4, "directory"),
        ("nda", 0.3, "directory"),
    ],
    "insurance": [
        ("policy", 0.4, "directory"),
        ("claim", 0.4, "directory"),
        ("underwriting", 0.4, "directory"),
        ("premium", 0.35, "directory"),
    ],
    "education": [
        ("course", 0.4, "directory"),
        ("student", 0.4, "directory"),
        ("lms", 0.4, "directory"),
        ("classroom", 0.3, "directory"),
    ],
}


# ─── Helpers ─────────────────────────────────────────────────


def _collect_en_tokens(
    project_profile: dict[str, Any],
    inventory: dict[str, Any] | None,
) -> tuple[set[str], set[str]]:
    """Extract (directory_tokens, package_tokens) tu project profile + inventory.

    Tokens duoc lowercase + basename cho easy matching.
    """
    dir_tokens: set[str] = set()
    pkg_tokens: set[str] = set()

    # Directories: top_level_dirs OR structure.top_level_dirs
    for key in ("top_level_dirs", "structure"):
        val = project_profile.get(key)
        if isinstance(val, list):
            for d in val:
                if isinstance(d, str):
                    dir_tokens.add(d.strip("/").lower())
        elif isinstance(val, dict):
            for d in val.get("top_level_dirs", []) or []:
                if isinstance(d, str):
                    dir_tokens.add(d.strip("/").lower())

    # Dependencies
    deps = project_profile.get("dependencies", {})
    if isinstance(deps, dict):
        for dep_key in ("production", "development", "all"):
            for d in deps.get(dep_key, []) or []:
                if isinstance(d, str):
                    pkg_tokens.add(d.lower())
    elif isinstance(deps, list):
        for d in deps:
            if isinstance(d, str):
                pkg_tokens.add(d.lower())

    # Frameworks
    for f in project_profile.get("frameworks", []) or []:
        if isinstance(f, str):
            pkg_tokens.add(f.lower())

    # Source files (from inventory) — get immediate parent dir
    if inventory:
        src = inventory.get("source-files", {})
        files = (
            src.get("files", [])
            if isinstance(src, dict)
            else (src if isinstance(src, list) else [])
        )
        for f in files:
            path = f.get("path") if isinstance(f, dict) else f
            if not isinstance(path, str):
                continue
            parts = path.replace("\\", "/").strip("/").split("/")
            for part in parts[:-1]:
                if part:
                    dir_tokens.add(part.lower())

    return dir_tokens, pkg_tokens


def _match_en_rule(token: str, keyword: str) -> str | None:
    """Return match_type or None."""
    kw = keyword.lower()
    if token == kw:
        return "exact"
    # Substring only when keyword is at least 3 chars to reduce noise.
    if len(kw) >= 3 and (token.startswith(kw) or kw in token):
        return "substring"
    return None


def detect_en(
    project_profile: dict[str, Any],
    inventory: dict[str, Any] | None = None,
) -> list[DomainSignal]:
    """Detect English domain signals tu project profile + inventory.

    Returns DomainSignal list (source='en'). Apply substring x0.7 multiplier
    (alligned with VN rule 2). Multi-signal boost DOESN'T apply here — that
    happens after EN+VN merge in score_domains().
    """
    dir_tokens, pkg_tokens = _collect_en_tokens(project_profile, inventory)

    signals: list[DomainSignal] = []
    for domain, rules in EN_RULES.items():
        for keyword, weight, signal_type in rules:
            haystack = (
                pkg_tokens if signal_type in ("package_dep", "framework") else dir_tokens
            )
            for tok in haystack:
                mt = _match_en_rule(tok, keyword)
                if mt is None:
                    continue
                w = weight * (0.7 if mt == "substring" else 1.0)
                signals.append(
                    DomainSignal(
                        domain=domain,
                        confidence=w,
                        signals=[
                            {
                                "type": signal_type,
                                "value": tok,
                                "keyword": keyword,
                                "match_type": mt,
                                "weight": round(w, 4),
                                "lang": "en",
                            }
                        ],
                        source="en",
                    )
                )
    return signals


def _collect_module_names(
    project_profile: dict[str, Any],
    inventory: dict[str, Any] | None,
) -> list[str]:
    """Module names = directory names across profile + inventory (dedup)."""
    dir_tokens, _ = _collect_en_tokens(project_profile, inventory)
    # Also explicit module list if provided.
    modules = project_profile.get("modules", []) or []
    if isinstance(modules, list):
        for m in modules:
            if isinstance(m, str):
                dir_tokens.add(m.lower())
            elif isinstance(m, dict) and "name" in m:
                dir_tokens.add(str(m["name"]).lower())
    return sorted(dir_tokens)


def score_domains(
    project_profile: dict[str, Any],
    inventory: dict[str, Any] | None = None,
    *,
    pool: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Score domains across EN + VN signals.

    Args:
        project_profile: Parsed project-profile.json.
        inventory: Optional parsed inventory (for IPS-B deeper scoring).
        pool: Optional pre-loaded VN pool.

    Returns:
        List of {domain, confidence, language, signals[], recommended_expert}
        sorted desc by confidence. Capped at 1.0 per domain.
    """
    if pool is None:
        pool = load_pool()

    # 1. EN signals
    en_signals = detect_en(project_profile, inventory)

    # 2. VN signals (on directory names — same tokens)
    module_names = _collect_module_names(project_profile, inventory)
    vn_signals = detect_modules_vn(module_names, pool=pool)

    # 3. Merge + aggregate via reuse of VN aggregator (handles dedup + cap).
    # Need to annotate EN signals với language='en' so aggregated output
    # distinguishes. However, aggregate_signals_by_domain uses 'vn' hardcoded
    # — we override afterwards with per-domain majority language.
    merged = en_signals + vn_signals
    aggregated = aggregate_signals_by_domain(merged, pool=pool)

    # Re-label language per domain based on majority signal source.
    for record in aggregated:
        en_count = sum(1 for s in record["signals"] if s.get("lang") == "en")
        vn_count = sum(1 for s in record["signals"] if s.get("lang") == "vn")
        if en_count and vn_count:
            record["language"] = "mixed"
        elif en_count:
            record["language"] = "en"
        else:
            record["language"] = "vn"

    return aggregated


# ─── Pure Aggregation API (backward-compat shape) ────────────


def score_signals(
    signals: list[dict[str, Any]] | list[DomainSignal],
    *,
    cross_domain_penalty: float = 0.6,  # noqa: ARG001  (kept for API compat)
    multi_signal_boost: float = 0.15,  # noqa: ARG001
    multi_signal_min_keywords: int = 3,  # noqa: ARG001
    pool: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Aggregate raw signals into per-domain scored records.

    Accepts either list of DomainSignal OR list of raw dicts. For dicts,
    each must contain: domain (str), confidence (float), signals (list).

    Cross-domain / boost params are accepted for API compat but not used —
    raw signals should already have those applied upstream (in detect_*).
    """
    coerced: list[DomainSignal] = []
    for s in signals:
        if isinstance(s, DomainSignal):
            coerced.append(s)
        elif isinstance(s, dict):
            coerced.append(
                DomainSignal(
                    domain=s["domain"],
                    confidence=float(s["confidence"]),
                    signals=list(s.get("signals", [])),
                    source=s.get("source", "unknown"),
                )
            )
    return aggregate_signals_by_domain(coerced, pool=pool)


# ─── Utility: find unresolved signals ────────────────────────


def find_unresolved_patterns(
    project_profile: dict[str, Any],
    inventory: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Return directory tokens not matched by any EN/VN rule — for warnings.

    Used cho IPS-A `unresolved_patterns` field.
    """
    dir_tokens, _ = _collect_en_tokens(project_profile, inventory)

    en_matched_tokens: set[str] = set()
    for sig in detect_en(project_profile, inventory):
        for entry in sig.signals:
            en_matched_tokens.add(entry["value"])

    vn_matched_tokens: set[str] = set()
    for sig in detect_modules_vn(sorted(dir_tokens)):
        for entry in sig.signals:
            vn_matched_tokens.add(entry["value"])

    # Also normalize VN side — VN aggregator stores normalized token.
    matched = en_matched_tokens | vn_matched_tokens

    # Unresolved are dir_tokens not in matched set AND not generic helpers.
    GENERIC = {
        "src", "app", "apps", "packages", "node_modules", "dist", "build",
        "public", "assets", "static", "tests", "test", "scripts", "docs",
        "doc", "config", "lib", "utils", "common", "shared", "types",
    }
    unresolved = [
        {"token": t, "source": "directory"}
        for t in sorted(dir_tokens)
        if t not in matched and t not in GENERIC
    ]
    return unresolved


_ = defaultdict  # re-export markers silenced
