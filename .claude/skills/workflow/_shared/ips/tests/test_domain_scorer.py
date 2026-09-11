"""Tests for domain_scorer.py.

Phase C: detect_en() + score_domains() + score_signals() + find_unresolved_patterns().
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import domain_scorer as ds  # noqa: E402
from ips import vietnamese_keywords as vk  # noqa: E402


# ─── Fixtures ────────────────────────────────────────────────


@pytest.fixture
def small_en_profile() -> dict:
    """Small EN project (50 files, 3 modules — sales domain)."""
    return {
        "name": "small-en",
        "file_counts": {"total": 50},
        "structure": {"top_level_dirs": ["src"]},
        "top_level_dirs": ["src", "customer", "sales", "reporting"],
        "frameworks": ["React", "Vite"],
        "dependencies": {
            "production": ["react", "react-dom", "axios"],
            "development": ["typescript", "vite"],
        },
        "modules": ["customer", "sales", "reporting"],
    }


@pytest.fixture
def medium_vn_profile() -> dict:
    """Medium VN project (500 files, 10 modules — finance+hr+sales+operations)."""
    return {
        "name": "medium-vn",
        "file_counts": {"total": 500},
        "top_level_dirs": [
            "qlkh",
            "hoadon",
            "qlns",
            "chamcong",
            "bangluong",
            "nhapkho",
            "xuatkho",
            "baocao",
            "caidat",
            "dangnhap",
        ],
        "frameworks": ["ASP.NET Core", "React"],
        "dependencies": {
            "production": ["Microsoft.AspNetCore.App", "Newtonsoft.Json"],
        },
        "modules": [
            "qlkh",
            "hoadon",
            "qlns",
            "chamcong",
            "bangluong",
            "nhapkho",
            "xuatkho",
        ],
    }


@pytest.fixture
def large_mixed_profile() -> dict:
    """Large mixed EN+VN project (1500 files, finance+logistics dominant)."""
    return {
        "name": "large-mixed",
        "file_counts": {"total": 1500},
        "top_level_dirs": [
            "apps",
            "packages",
            "billing",
            "invoice",
            "payment",
            "tax",
            "shipping",
            "delivery",
            "customs",
            "warehouse",
            "hr",
            "payroll",
            "sales-crm",
            "quotes",
            "audit-log",
            "compliance",
            # VN-named
            "qlkh",
            "hoadon",
            "baogia",
            "vanchuyen",
            "haiquan",
            "khobai",
            "qlns",
            "chamcong",
            "bangluong",
            "tuanthu",
        ],
        "frameworks": ["Node.js", "Express", "React"],
        "dependencies": {
            "production": ["decimal.js", "money", "axios", "express"],
        },
    }


# ─── detect_en ───────────────────────────────────────────────


class TestDetectEn:
    def test_small_en_finds_sales(self, small_en_profile) -> None:
        signals = ds.detect_en(small_en_profile)
        domains = {s.domain for s in signals}
        assert "sales" in domains

    def test_package_dep_match(self) -> None:
        profile = {
            "dependencies": {"production": ["decimal.js"]},
            "top_level_dirs": [],
        }
        signals = ds.detect_en(profile)
        finance = [s for s in signals if s.domain == "finance"]
        assert finance
        assert finance[0].signals[0]["type"] == "package_dep"
        assert finance[0].signals[0]["lang"] == "en"

    def test_directory_match(self) -> None:
        profile = {
            "dependencies": {},
            "top_level_dirs": ["billing"],
        }
        signals = ds.detect_en(profile)
        finance_billing = [
            s
            for s in signals
            if s.domain == "finance" and s.signals[0]["value"] == "billing"
        ]
        assert finance_billing
        # Directory match exact → full weight 0.4
        assert finance_billing[0].confidence == pytest.approx(0.4, abs=1e-3)

    def test_substring_discount(self) -> None:
        profile = {
            "top_level_dirs": ["billing-legacy"],
            "dependencies": {},
        }
        signals = ds.detect_en(profile)
        matched = [
            s
            for s in signals
            if s.domain == "finance" and s.signals[0]["keyword"] == "billing"
        ]
        # Substring match → 0.4 * 0.7 = 0.28
        assert matched
        assert matched[0].confidence == pytest.approx(0.28, abs=1e-3)
        assert matched[0].signals[0]["match_type"] == "substring"

    def test_no_match_returns_empty(self) -> None:
        profile = {"top_level_dirs": ["random", "blob"], "dependencies": {}}
        signals = ds.detect_en(profile)
        # Nothing in rules matches 'random' or 'blob'
        assert signals == []


# ─── score_domains ────────────────────────────────────────────


class TestScoreDomains:
    def test_small_en_top_sales(self, small_en_profile) -> None:
        result = ds.score_domains(small_en_profile)
        assert result, "Expected non-empty result"
        top = result[0]
        assert top["domain"] == "sales"
        assert top["confidence"] > 0

    def test_medium_vn_detects_multiple_domains(self, medium_vn_profile) -> None:
        result = ds.score_domains(medium_vn_profile)
        domains = {r["domain"] for r in result}
        # Must detect at least sales, hr, finance, operations
        for expected in ("sales", "hr", "finance", "operations"):
            assert expected in domains, (
                f"Missing {expected} in {domains}"
            )

    def test_medium_vn_hr_top_due_to_boost(self, medium_vn_profile) -> None:
        """HR gets multi-signal boost (qlns + chamcong + bangluong = 3 distinct)."""
        result = ds.score_domains(medium_vn_profile)
        # HR must be in top 2 (likely top).
        top_2 = [r["domain"] for r in result[:2]]
        assert "hr" in top_2

    def test_large_mixed_detects_finance_logistics(
        self, large_mixed_profile
    ) -> None:
        result = ds.score_domains(large_mixed_profile)
        domains = {r["domain"] for r in result}
        assert "finance" in domains
        assert "logistics" in domains

    def test_sorted_desc(self, large_mixed_profile) -> None:
        result = ds.score_domains(large_mixed_profile)
        confidences = [r["confidence"] for r in result]
        assert confidences == sorted(confidences, reverse=True)

    def test_language_labeling_en(self, small_en_profile) -> None:
        result = ds.score_domains(small_en_profile)
        # Small EN project — sales has EN-only signals
        sales = next(r for r in result if r["domain"] == "sales")
        assert sales["language"] == "en"

    def test_language_labeling_vn(self, medium_vn_profile) -> None:
        result = ds.score_domains(medium_vn_profile)
        hr = next(r for r in result if r["domain"] == "hr")
        # HR detected only via VN keywords
        assert hr["language"] == "vn"

    def test_language_labeling_mixed(self, large_mixed_profile) -> None:
        result = ds.score_domains(large_mixed_profile)
        finance = next(r for r in result if r["domain"] == "finance")
        # finance has both EN (billing, invoice, decimal.js) + VN (hoadon)
        assert finance["language"] == "mixed"

    def test_confidence_capped_at_1(self, large_mixed_profile) -> None:
        result = ds.score_domains(large_mixed_profile)
        for r in result:
            assert r["confidence"] <= 1.0

    def test_recommended_expert_populated(self, medium_vn_profile) -> None:
        result = ds.score_domains(medium_vn_profile)
        for r in result:
            assert r["recommended_expert"].endswith("-expert")


# ─── score_signals (API compat) ──────────────────────────────


class TestScoreSignals:
    def test_accepts_domain_signal_instances(self) -> None:
        sigs = [
            vk.DomainSignal(
                domain="sales",
                confidence=0.5,
                signals=[
                    {"keyword": "qlkh", "match_type": "exact", "value": "qlkh"}
                ],
            )
        ]
        result = ds.score_signals(sigs)
        assert result[0]["domain"] == "sales"

    def test_accepts_raw_dicts(self) -> None:
        sigs = [
            {
                "domain": "finance",
                "confidence": 0.3,
                "signals": [
                    {
                        "keyword": "hoadon",
                        "match_type": "exact",
                        "value": "hoadon",
                    }
                ],
            }
        ]
        result = ds.score_signals(sigs)
        assert result[0]["domain"] == "finance"
        assert result[0]["confidence"] == pytest.approx(0.3, abs=1e-3)

    def test_empty_input(self) -> None:
        assert ds.score_signals([]) == []


# ─── find_unresolved_patterns ────────────────────────────────


class TestFindUnresolvedPatterns:
    def test_unknown_dir_is_unresolved(self) -> None:
        profile = {
            "top_level_dirs": ["xyzfoo", "billing"],
            "dependencies": {},
        }
        unresolved = ds.find_unresolved_patterns(profile)
        tokens = {u["token"] for u in unresolved}
        assert "xyzfoo" in tokens
        assert "billing" not in tokens  # matched by EN rule

    def test_generic_dirs_ignored(self) -> None:
        profile = {
            "top_level_dirs": ["src", "tests", "node_modules", "xyzfoo"],
            "dependencies": {},
        }
        unresolved = ds.find_unresolved_patterns(profile)
        tokens = {u["token"] for u in unresolved}
        assert "xyzfoo" in tokens
        # Generics ignored
        assert "src" not in tokens
        assert "tests" not in tokens
        assert "node_modules" not in tokens
