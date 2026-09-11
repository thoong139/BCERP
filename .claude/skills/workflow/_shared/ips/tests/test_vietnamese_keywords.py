"""Tests for vietnamese_keywords.py.

Phase A.7: normalize_vn() + load_pool() tested.
Phase C: detect_domain_vn() + detect_modules_vn() + aggregate_signals_by_domain().
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import vietnamese_keywords as vk  # noqa: E402


class TestNormalizeVn:
    """normalize_vn() — deterministic Vietnamese text normalization."""

    @pytest.mark.parametrize(
        "text,expected",
        [
            ("Quản-Lý-Khách-Hàng", "quanlykhachhang"),
            ("Hóa_Đơn", "hoadon"),
            ("Nhập/Kho", "nhapkho"),
            ("qlkh", "qlkh"),
            ("CHAM-CONG", "chamcong"),
            ("Đào.tạo", "daotao"),
            ("Nhân Viên", "nhan vien"),  # space preserved
        ],
    )
    def test_normalize(self, text: str, expected: str) -> None:
        assert vk.normalize_vn(text) == expected

    def test_idempotent(self) -> None:
        once = vk.normalize_vn("Quản-Lý-Khách-Hàng")
        twice = vk.normalize_vn(once)
        assert once == twice

    def test_empty_string(self) -> None:
        assert vk.normalize_vn("") == ""


class TestLoadPool:
    def test_default_pool_loads(self) -> None:
        pool = vk.load_pool()
        assert pool["$schema"] == "vn-keywords-v1"
        assert "domains" in pool
        assert len(pool["domains"]) == 14  # Core 7 + Optional 7

    def test_pool_is_valid_json(self) -> None:
        data = json.loads(vk._POOL_PATH.read_text(encoding="utf-8"))
        assert isinstance(data, dict)

    def test_core_7_has_min_6_keywords(self) -> None:
        """Core 7 domains PHAI co >=6 keywords (exclude abbreviations)."""
        pool = vk.load_pool()
        core_7 = {
            "finance",
            "hr",
            "sales",
            "procurement",
            "ecommerce",
            "operations",
            "compliance",
        }
        for dom in core_7:
            kws = pool["domains"][dom]["keywords"]
            assert len(kws) >= 6, f"{dom} has only {len(kws)} keywords (need ≥6)"


class TestDetectDomainVnBasic:
    def test_exact_match_qlkh_sales(self) -> None:
        signals = vk.detect_domain_vn("qlkh")
        assert any(s.domain == "sales" for s in signals)

    def test_exact_match_hoadon_finance(self) -> None:
        signals = vk.detect_domain_vn("hoadon")
        assert any(s.domain == "finance" for s in signals)

    def test_diacritic_variant_matches(self) -> None:
        # After normalization, "Hóa-Đơn" → "hoadon"
        signals = vk.detect_domain_vn("Hóa-Đơn")
        assert any(s.domain == "finance" for s in signals)

    def test_no_match_returns_empty(self) -> None:
        signals = vk.detect_domain_vn("xyznonsense")
        assert signals == []

    def test_empty_returns_empty(self) -> None:
        assert vk.detect_domain_vn("") == []

    def test_bhyt_matches_healthcare(self) -> None:
        signals = vk.detect_domain_vn("bhyt")
        assert any(s.domain == "healthcare" for s in signals)


class TestSubstringMatching:
    def test_substring_matched_with_discount(self) -> None:
        """Khi substring match → weight x 0.7 (not x 1.0)."""
        pool = vk.load_pool()
        # hoadon keyword weight 0.3 → substring match x 0.7 = 0.21
        signals = vk._match_single_token(
            "chuyenhoadon", pool, vk._build_keyword_domain_map(pool)
        )
        finance_sigs = [s for s in signals if s.domain == "finance"]
        # At least one finance signal with substring match
        assert any(
            s.signals[0]["match_type"] == "substring" for s in finance_sigs
        ), "Expected substring match signals"
        # Weight < 0.3 (original) after 0.7 multiplier.
        hoadon_subs = [
            s for s in finance_sigs
            if s.signals[0]["keyword"] == "hoadon"
            and s.signals[0]["match_type"] == "substring"
        ]
        assert hoadon_subs, "hoadon substring match missing"
        assert hoadon_subs[0].confidence < 0.3

    def test_exact_only_abbreviation_no_substring(self) -> None:
        """Viet tat 2-3 char (exact_only=True) khong bi substring match."""
        # 'kh' (sales abbreviation, exact_only=True) shouldn't match 'khachhang'
        pool = vk.load_pool()
        signals = vk._match_single_token(
            "khachhang", pool, vk._build_keyword_domain_map(pool)
        )
        matched_keywords = {s.signals[0]["keyword"] for s in signals}
        # 'khachhang' (keyword, exact_only=false) should match
        assert "khachhang" in matched_keywords
        # 'kh' (abbreviation, exact_only=true) should NOT substring-match
        assert "kh" not in matched_keywords


class TestCrossDomainPenalty:
    def test_cross_domain_hopdong_penalty(self) -> None:
        """'hopdong' xuat hien trong ca sales va legal -> 0.6x penalty."""
        pool = vk.load_pool()
        signals = vk._match_single_token(
            "hopdong", pool, vk._build_keyword_domain_map(pool)
        )
        # Both sales and legal pick up hopdong.
        domains = {s.domain for s in signals}
        assert "sales" in domains
        assert "legal" in domains
        # Confidence penalized: base 0.25 * 0.6 = 0.15
        for s in signals:
            if s.domain in ("sales", "legal"):
                assert s.confidence == pytest.approx(0.15, abs=1e-3)


class TestMultiSignalBoost:
    def test_hr_three_signals_boost(self) -> None:
        """3 modules HR keyword → +0.15 boost cho tat ca HR signals."""
        # qlns + chamcong + bangluong = 3 distinct HR keywords
        signals = vk.detect_modules_vn(["qlns", "chamcong", "bangluong"])
        hr_sigs = [s for s in signals if s.domain == "hr"]
        assert len(hr_sigs) == 3
        # Each original weight:
        #   qlns: abbreviation keyword, weight 0.4
        #   chamcong: 0.4
        #   bangluong: 0.4
        # After boost +0.15 (all unique keywords in HR), each → 0.55 (capped at 1.0)
        for s in hr_sigs:
            assert s.confidence == pytest.approx(0.55, abs=1e-3)
        # Signals also carry boost marker
        for s in hr_sigs:
            assert s.signals[0]["multi_signal_boost_applied"] is True

    def test_single_signal_no_boost(self) -> None:
        signals = vk.detect_modules_vn(["qlkh"])
        sales_sigs = [s for s in signals if s.domain == "sales"]
        # Only 1 keyword → no boost
        for s in sales_sigs:
            assert "multi_signal_boost_applied" not in s.signals[0]


class TestAggregateSignalsByDomain:
    def test_aggregate_sums_confidence_capped(self) -> None:
        sigs = [
            vk.DomainSignal(
                domain="sales",
                confidence=0.4,
                signals=[
                    {
                        "keyword": "qlkh",
                        "match_type": "exact",
                        "value": "qlkh",
                    }
                ],
            ),
            vk.DomainSignal(
                domain="sales",
                confidence=0.35,
                signals=[
                    {
                        "keyword": "banhang",
                        "match_type": "exact",
                        "value": "banhang",
                    }
                ],
            ),
            vk.DomainSignal(
                domain="finance",
                confidence=0.3,
                signals=[
                    {
                        "keyword": "hoadon",
                        "match_type": "exact",
                        "value": "hoadon",
                    }
                ],
            ),
        ]
        result = vk.aggregate_signals_by_domain(sigs)
        # Sales aggregated = 0.75, finance = 0.3 → sales first
        assert result[0]["domain"] == "sales"
        assert result[0]["confidence"] == pytest.approx(0.75, abs=1e-3)
        assert result[1]["domain"] == "finance"
        assert result[1]["confidence"] == pytest.approx(0.3, abs=1e-3)

    def test_aggregate_capped_at_1(self) -> None:
        sigs = [
            vk.DomainSignal(
                domain="hr",
                confidence=0.8,
                signals=[{"keyword": "a", "match_type": "exact", "value": "a"}],
            ),
            vk.DomainSignal(
                domain="hr",
                confidence=0.5,
                signals=[{"keyword": "b", "match_type": "exact", "value": "b"}],
            ),
        ]
        result = vk.aggregate_signals_by_domain(sigs)
        assert result[0]["confidence"] == pytest.approx(1.0, abs=1e-3)

    def test_aggregate_recommended_expert(self) -> None:
        sigs = vk.detect_domain_vn("qlkh")
        agg = vk.aggregate_signals_by_domain(sigs)
        sales = next((r for r in agg if r["domain"] == "sales"), None)
        assert sales is not None
        assert sales["recommended_expert"] == "sales-expert"
        assert sales["language"] == "vn"

    def test_aggregate_dedup_signals(self) -> None:
        # Same keyword appearing multiple times (duplicate modules)
        signals = vk.detect_modules_vn(["qlkh", "qlkh", "qlkh"])
        agg = vk.aggregate_signals_by_domain(signals)
        sales = next((r for r in agg if r["domain"] == "sales"), None)
        assert sales is not None
        # Dedup — should have just 1 signal entry for qlkh value
        keywords_in_signals = [
            (s["keyword"], s["value"]) for s in sales["signals"]
        ]
        # All same value 'qlkh' and keyword 'qlkh' → only 1 entry
        assert len(set(keywords_in_signals)) == len(keywords_in_signals)


class TestIntegrationFixtureModules:
    """Simulates fixture-style batched detection (matches 05-profiles-ips expected)."""

    def test_medium_vn_fixture_modules(self) -> None:
        """medium-vn fixture modules → detect finance + hr + sales + operations."""
        modules = [
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
        ]
        signals = vk.detect_modules_vn(modules)
        agg = vk.aggregate_signals_by_domain(signals)

        domains_detected = {r["domain"] for r in agg}
        # Must detect at minimum these 4 (per medium-vn/README.md)
        for expected in ("sales", "hr", "finance", "operations"):
            assert expected in domains_detected, (
                f"Expected {expected} in detected domains; got {domains_detected}"
            )

        # HR should have highest confidence (3 distinct keywords → boost)
        top = agg[0]
        assert top["domain"] == "hr"

    def test_diacritic_fixture_modules(self) -> None:
        """Du an-vn fixture (with diacritics) → detect same as normalized."""
        modules = ["Quản_Lý_Khách_Hàng", "Hóa_Đơn", "Nhập_Kho"]
        signals = vk.detect_modules_vn(modules)
        agg = vk.aggregate_signals_by_domain(signals)
        domains_detected = {r["domain"] for r in agg}
        assert "sales" in domains_detected
        assert "finance" in domains_detected
        assert "operations" in domains_detected
