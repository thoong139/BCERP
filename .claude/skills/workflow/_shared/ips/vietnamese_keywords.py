"""Vietnamese Keyword Pool — domain detection cho du an Viet Nam.

Phase A.7: normalize_vn() + load_pool() (da xong).
Phase C: detect_domain_vn() + helpers. Matching rules theo
10-vietnamese-keywords.md §3.2:

1. Exact match (normalized) → weight giu nguyen.
2. Substring match → weight x 0.7 (chi ap dung khi exact_only=False).
3. Multi-signal boost: >=3 keyword cung domain xuat hien trong 1 scan → +0.15
   (dua tren count DISTINCT keyword dua ra signal cho domain do).
4. Cross-domain penalty: keyword xuat hien trong >=2 domain → weight x 0.6.
5. Abbreviations (exact_only=True) chi match exact, khong substring.

Reference: docs/design/skills/wf-legacy-scan/10-vietnamese-keywords.md §3.
"""

from __future__ import annotations

import json
import re
import unicodedata
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

_POOL_PATH = Path(__file__).parent / "vietnamese-keywords.json"
_SEPARATOR_RE = re.compile(r"[-_/.]")


@dataclass
class DomainSignal:
    """Signal cho mot domain match — one keyword per signal."""

    domain: str
    confidence: float
    signals: list[dict[str, Any]] = field(default_factory=list)
    source: str = "vn"


# ─── Normalization ───────────────────────────────────────────


def normalize_vn(text: str) -> str:
    """Normalize Vietnamese text: strip diacritics, lowercase, remove separators.

    Steps:
    1. lowercase
    2. Unicode NFD decompose + strip combining marks (remove diacritics)
    3. đ/Đ -> d
    4. strip separators: - _ / .
    """
    text = text.lower()
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = text.replace("đ", "d")
    text = _SEPARATOR_RE.sub("", text)
    return text


def load_pool(pool_path: Path | None = None) -> dict[str, Any]:
    """Load VN keyword pool from JSON."""
    path = pool_path or _POOL_PATH
    with path.open(encoding="utf-8") as f:
        return json.load(f)


# ─── Core Detection ──────────────────────────────────────────


def _iter_entries(domain_data: dict[str, Any]):
    """Yield (entry_dict, kind) pairs cho keywords + abbreviations."""
    for kw in domain_data.get("keywords", []):
        yield kw, "keyword"
    for kw in domain_data.get("abbreviations", []):
        yield kw, "abbreviation"


def _build_keyword_domain_map(pool: dict[str, Any]) -> dict[str, set[str]]:
    """Map normalized_keyword -> set of domains it appears in.

    Dung de detect cross-domain keywords cho penalty (rule 4).
    """
    out: dict[str, set[str]] = defaultdict(set)
    for domain, data in pool["domains"].items():
        for entry, _kind in _iter_entries(data):
            norm_kw = normalize_vn(entry["keyword"])
            out[norm_kw].add(domain)
    return out


def _match_single_token(
    token: str,
    pool: dict[str, Any],
    keyword_domains: dict[str, set[str]],
) -> list[DomainSignal]:
    """Match 1 normalized token against pool → list DomainSignal (one per match).

    Rules 1, 2, 4, 5 applied here. Rule 3 (multi-signal boost) la global
    aggregation step, apply sau cung trong detect_domain_vn.
    """
    rules = pool.get("matching_rules", {})
    substring_mul = rules.get("substring_weight_multiplier", 0.7)
    cross_penalty = rules.get("cross_domain_penalty", 0.6)

    signals: list[DomainSignal] = []

    for domain, data in pool["domains"].items():
        for entry, kind in _iter_entries(data):
            norm_kw = normalize_vn(entry["keyword"])
            weight = float(entry["weight"])
            exact_only = bool(entry.get("exact_only", False))

            if not norm_kw:
                continue

            match_type: str | None = None
            if norm_kw == token:
                match_type = "exact"
            elif not exact_only and len(norm_kw) >= 3 and norm_kw in token:
                # Substring match — restrict keyword ≥3 chars de tranh noise
                match_type = "substring"
                weight *= substring_mul

            if match_type is None:
                continue

            # Rule 4 — cross-domain penalty
            if len(keyword_domains.get(norm_kw, set())) >= 2:
                weight *= cross_penalty

            signals.append(
                DomainSignal(
                    domain=domain,
                    confidence=weight,
                    signals=[
                        {
                            "type": "directory_name",
                            "value": token,
                            "keyword": entry["keyword"],
                            "kind": kind,
                            "match_type": match_type,
                            "weight": round(weight, 4),
                            "lang": "vn",
                        }
                    ],
                )
            )

    return signals


def _apply_multi_signal_boost(
    signals: list[DomainSignal],
    pool: dict[str, Any],
) -> list[DomainSignal]:
    """Rule 3: if >=N DISTINCT keywords cho cung 1 domain -> +boost.

    N = matching_rules.multi_signal_min_keywords (default 3).
    boost = matching_rules.multi_signal_boost (default 0.15).
    Boost apply cho TAT CA signals cua domain do (cap at 1.0).
    """
    rules = pool.get("matching_rules", {})
    min_kw = rules.get("multi_signal_min_keywords", 3)
    boost = rules.get("multi_signal_boost", 0.15)

    # Count distinct keyword per domain.
    per_domain_kw: dict[str, set[str]] = defaultdict(set)
    for sig in signals:
        for s in sig.signals:
            per_domain_kw[sig.domain].add(s["keyword"])

    boosted_domains = {
        dom for dom, kws in per_domain_kw.items() if len(kws) >= min_kw
    }

    for sig in signals:
        if sig.domain in boosted_domains:
            sig.confidence = min(sig.confidence + boost, 1.0)
            for s in sig.signals:
                s["multi_signal_boost_applied"] = True

    return signals


def detect_domain_vn(
    module_name: str,
    pool: dict[str, Any] | None = None,
) -> list[DomainSignal]:
    """Detect VN domain signals from a single module name.

    Matching run tren 1 token (normalized module name). Multi-signal
    boost yeu cau DISTINCT keyword, con detect_modules_vn() xu ly N tokens
    de duoc full multi-signal context.

    Returns:
        List of DomainSignal (one per keyword match). May be empty.
    """
    if pool is None:
        pool = load_pool()

    normalized = normalize_vn(module_name)
    if not normalized:
        return []

    keyword_domains = _build_keyword_domain_map(pool)
    signals = _match_single_token(normalized, pool, keyword_domains)
    signals = _apply_multi_signal_boost(signals, pool)
    return signals


def detect_modules_vn(
    module_names: list[str],
    pool: dict[str, Any] | None = None,
) -> list[DomainSignal]:
    """Detect VN domain signals across nhieu module names.

    Multi-signal boost applies *globally* — neu 3 modules match 3 keyword
    khac nhau cua cung domain, tat ca signals cua domain do duoc boost.
    """
    if pool is None:
        pool = load_pool()
    keyword_domains = _build_keyword_domain_map(pool)

    all_signals: list[DomainSignal] = []
    for mod in module_names:
        normalized = normalize_vn(mod)
        if not normalized:
            continue
        all_signals.extend(_match_single_token(normalized, pool, keyword_domains))

    return _apply_multi_signal_boost(all_signals, pool)


# ─── Aggregation Helpers ─────────────────────────────────────


def aggregate_signals_by_domain(
    signals: list[DomainSignal],
    pool: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Aggregate raw signals into per-domain records suitable for domain-hints.json.

    Strategy:
    - Group signals by domain.
    - Confidence = sum of per-signal weights, capped at 1.0.
      (Summing captures multi-signal evidence; single strong match vs multiple
      weak matches both produce reasonable scores.)
    - Dedup signals by (keyword, match_type) khi append into aggregated list.

    Args:
        signals: Raw DomainSignal list (from detect_modules_vn).
        pool: Optional pool để lay recommended expert.

    Returns:
        Sorted list desc by confidence: [
          {domain, confidence, language, signals[], recommended_expert}, ...
        ]
    """
    if pool is None:
        pool = load_pool()

    by_domain: dict[str, list[DomainSignal]] = defaultdict(list)
    for sig in signals:
        by_domain[sig.domain].append(sig)

    result: list[dict[str, Any]] = []
    for domain, sigs in by_domain.items():
        # Sum weights, capped.
        total = min(sum(s.confidence for s in sigs), 1.0)

        # Dedup per-signal details by (keyword, match_type, value).
        seen: set[tuple[str, str, str]] = set()
        flat: list[dict[str, Any]] = []
        for s in sigs:
            for entry in s.signals:
                key = (entry["keyword"], entry["match_type"], entry["value"])
                if key in seen:
                    continue
                seen.add(key)
                flat.append(entry)

        expert = (
            pool["domains"].get(domain, {}).get("expert_agent")
            or f"{domain}-expert"
        )

        result.append(
            {
                "domain": domain,
                "confidence": round(total, 4),
                "language": "vn",
                "signals": flat,
                "recommended_expert": expert,
            }
        )

    result.sort(key=lambda r: r["confidence"], reverse=True)
    return result
