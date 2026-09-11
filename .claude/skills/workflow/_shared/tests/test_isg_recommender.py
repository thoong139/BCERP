"""test_isg_recommender.py — Unit tests cho _shared/isg/isg_recommender.py.

Vai trò B2:
    Kiểm tra 7 nhóm chức năng của ISG (Interactive Selection Gate):
        1. Constants sanity (DIMENSIONS, DIM_NAMES, DEFAULT_PROFILE_DIMS,
           SAFETY_FLOOR, CDG tokens).
        2. `_merge_strength` priority: strong > weak > none.
        3. `analyze()` — git diff heuristics + preflight + domain + interface_type
           + profile defaults.
        4. `render_checklist()` — markdown markers Việt + mention ADR-22 rule 1.
        5. `parse_user_response()` — default/all/recommend/CSV/invalid.
        6. `enforce_safety_floor()` — ADR-22 rule 1 cho standard/deep/exhaustive.
        7. `check_cdg()` — CORE-027: override-qd1 + confirm-skip-qd3.
        8. `emit_selection()` — atomic write + schema fields.
        9. `collect_signals()` — registry reading + graceful git failure.

ADR refs: ADR-14 (ISG), ADR-22 rule 1 (safety floor).
CORE refs: CORE-005 (Vietnamese docs), CORE-027 (CDG), CORE-031 (templates).
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from isg.isg_recommender import (
    CDG_TOKEN_OVERRIDE_QD1,
    CDG_TOKEN_SKIP_QD3,
    DEFAULT_PROFILE_DIMS,
    DIFF_MANY_FILES_THRESHOLD,
    DIM_NAMES,
    DIMENSIONS,
    DOMAIN_DIM_HINTS,
    SAFETY_FLOOR_DIMS,
    SAFETY_FLOOR_PROFILES,
    VALID_PROFILES,
    DimRecommendation,
    Signals,
    _merge_strength,
    _strength_marker,
    analyze,
    check_cdg,
    collect_signals,
    emit_selection,
    enforce_safety_floor,
    parse_user_response,
    render_checklist,
)


# ──────────────────────────────────────────────────────────────────────
# 1. Constants sanity
# ──────────────────────────────────────────────────────────────────────


class TestConstants:
    """Đảm bảo các constants không bị sửa nhầm (regression guard)."""

    def test_dimensions_has_ten_qds(self) -> None:
        # v9.1.0: mở rộng từ 10 → 11 dimensions (kèm QD11 Business Completeness)
        assert DIMENSIONS == (
            "QD1", "QD2", "QD3", "QD4", "QD5",
            "QD6", "QD7", "QD8", "QD9", "QD10", "QD11",
        )

    def test_dim_names_covers_all_dimensions(self) -> None:
        assert set(DIM_NAMES.keys()) == set(DIMENSIONS)
        # Tên tiếng Việt phải non-empty
        for dim, name in DIM_NAMES.items():
            assert len(name) > 0, f"{dim} thiếu tên tiếng Việt"

    def test_default_profile_dims_valid_subset(self) -> None:
        assert set(DEFAULT_PROFILE_DIMS.keys()) == {
            "quick",
            "standard",
            "deep",
            "exhaustive",
        }
        for profile, dims in DEFAULT_PROFILE_DIMS.items():
            for d in dims:
                assert d in DIMENSIONS, f"profile {profile} chứa dim lạ {d}"
        # Exhaustive phải là full 7
        assert set(DEFAULT_PROFILE_DIMS["exhaustive"]) == set(DIMENSIONS)
        # Quick phải nhỏ hơn standard
        assert set(DEFAULT_PROFILE_DIMS["quick"]).issubset(set(DIMENSIONS))
        assert len(DEFAULT_PROFILE_DIMS["quick"]) < len(DEFAULT_PROFILE_DIMS["standard"])

    def test_valid_profiles_matches_default_profile_dims(self) -> None:
        assert VALID_PROFILES == frozenset(DEFAULT_PROFILE_DIMS.keys())

    def test_safety_floor_dims_is_qd1_qd2_qd5(self) -> None:
        # ADR-22 rule 1 — cố định không đổi
        assert SAFETY_FLOOR_DIMS == frozenset({"QD1", "QD2", "QD5"})

    def test_safety_floor_profiles_skips_quick(self) -> None:
        assert SAFETY_FLOOR_PROFILES == frozenset({"standard", "deep", "exhaustive"})
        assert "quick" not in SAFETY_FLOOR_PROFILES

    def test_cdg_tokens_match_core_027(self) -> None:
        # CORE-027: token user phải gõ chính xác — không được đổi
        assert CDG_TOKEN_OVERRIDE_QD1 == "override-qd1"
        assert CDG_TOKEN_SKIP_QD3 == "confirm-skip-qd3"

    def test_domain_dim_hints_covers_core_domains(self) -> None:
        # 06-domain.md yêu cầu finance/healthcare/logistics
        assert "finance" in DOMAIN_DIM_HINTS
        assert "healthcare" in DOMAIN_DIM_HINTS
        assert "logistics" in DOMAIN_DIM_HINTS
        # Mỗi domain trỏ về QD hợp lệ
        for domain, dims in DOMAIN_DIM_HINTS.items():
            for d in dims:
                assert d in DIMENSIONS, f"domain {domain} trỏ về dim lạ {d}"

    def test_diff_many_files_threshold_positive(self) -> None:
        assert DIFF_MANY_FILES_THRESHOLD > 0


# ──────────────────────────────────────────────────────────────────────
# 2. _merge_strength priority
# ──────────────────────────────────────────────────────────────────────


class TestMergeStrength:
    """Quy tắc: strong > weak > none. Incoming mạnh hơn mới override."""

    @pytest.mark.parametrize(
        "current,incoming,expected",
        [
            ("none", "none", "none"),
            ("none", "weak", "weak"),
            ("none", "strong", "strong"),
            ("weak", "none", "weak"),  # incoming yếu hơn → giữ current
            ("weak", "weak", "weak"),
            ("weak", "strong", "strong"),
            ("strong", "none", "strong"),  # incoming yếu hơn → giữ current
            ("strong", "weak", "strong"),
            ("strong", "strong", "strong"),
        ],
    )
    def test_priority_order(self, current: str, incoming: str, expected: str) -> None:
        assert _merge_strength(current, incoming) == expected

    def test_unknown_strength_treated_as_zero(self) -> None:
        # Không raise; unknown được treat như "none"
        assert _merge_strength("strong", "garbage") == "strong"
        assert _merge_strength("garbage", "weak") == "weak"


# ──────────────────────────────────────────────────────────────────────
# 3. _strength_marker output
# ──────────────────────────────────────────────────────────────────────


class TestStrengthMarker:
    def test_strong_has_star(self) -> None:
        marker = _strength_marker("strong")
        assert "★" in marker
        assert "strong" in marker

    def test_weak_has_middot(self) -> None:
        marker = _strength_marker("weak")
        assert "·" in marker or "weak" in marker

    def test_none_returns_whitespace(self) -> None:
        marker = _strength_marker("none")
        assert marker.strip() == ""


# ──────────────────────────────────────────────────────────────────────
# 4. analyze() — signal-based recommendations
# ──────────────────────────────────────────────────────────────────────


class TestAnalyzeInvalidProfile:
    def test_invalid_profile_raises(self) -> None:
        signals = Signals()
        with pytest.raises(ValueError, match="profile"):
            analyze(signals, "super-deep")


class TestAnalyzeReturnsAllRecommendations:
    def test_returns_one_rec_per_dimension(self) -> None:
        # v9.0.2: analyze() trả về 1 recommendation cho mỗi dim trong DIMENSIONS (10 dims).
        signals = Signals()
        recs = analyze(signals, "standard")
        assert len(recs) == len(DIMENSIONS)
        dims = [r.dim for r in recs]
        assert set(dims) == set(DIMENSIONS)

    def test_each_recommendation_has_reason_at_least_10_chars(self) -> None:
        signals = Signals()
        recs = analyze(signals, "standard")
        for rec in recs:
            assert len(rec.reason) >= 10, (
                f"{rec.dim} reason quá ngắn: {rec.reason!r}"
            )

    def test_strength_is_enum(self) -> None:
        signals = Signals()
        recs = analyze(signals, "quick")
        for rec in recs:
            assert rec.strength in {"strong", "weak", "none"}


class TestAnalyzeGitDiffHeuristics:
    """Git diff path patterns → QD strong/weak."""

    def test_service_file_triggers_qd1_and_qd6_strong(self) -> None:
        signals = Signals(git_diff_files=["src/sales/customer.service.ts"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD1"].strength == "strong"
        assert recs["QD6"].strength == "strong"

    def test_controller_triggers_qd1_strong(self) -> None:
        signals = Signals(git_diff_files=["src/api/order.controller.ts"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD1"].strength == "strong"

    def test_auth_path_triggers_qd3_strong(self) -> None:
        signals = Signals(git_diff_files=["src/auth/login-handler.ts"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD3"].strength == "strong"

    def test_ui_component_triggers_qd5_strong(self) -> None:
        signals = Signals(git_diff_files=["src/views/dashboard.component.tsx"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD5"].strength == "strong"

    def test_migrations_trigger_qd6_strong(self) -> None:
        signals = Signals(git_diff_files=["db/migrations/20260420_add_users.sql"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD6"].strength == "strong"

    def test_repository_triggers_qd6_strong(self) -> None:
        signals = Signals(git_diff_files=["src/data/user.repository.ts"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD6"].strength == "strong"

    def test_perf_folder_triggers_qd4_weak(self) -> None:
        signals = Signals(git_diff_files=["src/performance/cache-layer.ts"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD4"].strength in {"weak", "strong"}

    def test_config_file_triggers_qd7_weak(self) -> None:
        signals = Signals(git_diff_files=["package.json"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        # QD7 phải có ít nhất weak (không bị downgrade)
        assert recs["QD7"].strength in {"weak", "strong"}

    def test_many_files_triggers_qd7_weak(self) -> None:
        many_files = [f"src/feature_{i}/file.ts" for i in range(DIFF_MANY_FILES_THRESHOLD + 5)]
        signals = Signals(git_diff_files=many_files)
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD7"].strength in {"weak", "strong"}

    def test_reason_mentions_git_diff_when_files_matched(self) -> None:
        signals = Signals(git_diff_files=["src/sales/order.service.ts"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        # QD1 reason phải mention diff
        assert "git diff" in recs["QD1"].reason.lower() or "diff" in recs["QD1"].reason.lower()


class TestAnalyzePreflightSignals:
    def test_preflight_critical_triggers_qd1_strong(self) -> None:
        signals = Signals(
            preflight_available=True,
            preflight_critical_count=3,
        )
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD1"].strength == "strong"
        assert "critical" in recs["QD1"].reason.lower() or "CRITICAL" in recs["QD1"].reason

    def test_preflight_security_warn_triggers_qd3_strong(self) -> None:
        signals = Signals(
            preflight_available=True,
            preflight_security_warn=True,
        )
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD3"].strength == "strong"

    def test_preflight_perf_warn_triggers_qd4_weak(self) -> None:
        signals = Signals(
            preflight_available=True,
            preflight_perf_warn=True,
        )
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD4"].strength in {"weak", "strong"}

    def test_preflight_unavailable_no_effect(self) -> None:
        signals = Signals(
            preflight_available=False,
            preflight_critical_count=10,  # bị ignore vì available=False
            preflight_security_warn=True,
        )
        recs = {r.dim: r for r in analyze(signals, "quick")}
        # Không có signal → QD1/QD3 chỉ được bơm bởi profile default
        # Quick default là [QD1, QD5] → QD1 sẽ weak (từ profile default)
        # QD3 không có trong quick default → phải none
        assert recs["QD3"].strength == "none"


class TestAnalyzeDomainHints:
    def test_finance_domain_triggers_qd2_strong(self) -> None:
        signals = Signals(domain="finance", departments=["finance"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD2"].strength == "strong"
        assert "finance" in recs["QD2"].reason.lower()

    def test_healthcare_domain_triggers_qd2_qd3_qd6(self) -> None:
        signals = Signals(domain="healthcare", departments=["healthcare"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD2"].strength == "strong"
        assert recs["QD3"].strength == "strong"
        assert recs["QD6"].strength == "strong"

    def test_logistics_domain_triggers_qd2_qd6(self) -> None:
        signals = Signals(domain="logistics", departments=["logistics"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        assert recs["QD2"].strength == "strong"
        assert recs["QD6"].strength == "strong"

    def test_unknown_domain_no_effect(self) -> None:
        signals = Signals(domain="gaming", departments=["gaming"])
        recs = {r.dim: r for r in analyze(signals, "quick")}
        # Không có domain hint nào match → QD2 chỉ nhận signal từ profile default
        # Quick default không bao gồm QD2 → strength = none
        assert recs["QD2"].strength == "none"


class TestAnalyzeInterfaceType:
    def test_api_only_downgrades_qd5_when_strong(self) -> None:
        # Signal git diff chạm UI → QD5 strong
        signals = Signals(
            git_diff_files=["src/ui/dashboard.component.tsx"],
            interface_type="api-only",
        )
        recs = {r.dim: r for r in analyze(signals, "quick")}
        # api-only force QD5 strong → weak
        assert recs["QD5"].strength == "weak"
        assert "api-only" in recs["QD5"].reason.lower()

    def test_web_interface_no_downgrade(self) -> None:
        signals = Signals(
            git_diff_files=["src/ui/dashboard.component.tsx"],
            interface_type="web",
        )
        recs = {r.dim: r for r in analyze(signals, "quick")}
        # Web → giữ QD5 strong
        assert recs["QD5"].strength == "strong"


class TestAnalyzeProfileDefaults:
    def test_profile_default_injects_weak_if_none(self) -> None:
        signals = Signals()
        recs = {r.dim: r for r in analyze(signals, "standard")}
        # Standard default = [QD1, QD2, QD5]
        for dim in DEFAULT_PROFILE_DIMS["standard"]:
            assert recs[dim].strength in {"weak", "strong"}, (
                f"{dim} phải có ít nhất weak vì là profile default của standard"
            )

    def test_profile_default_does_not_overwrite_strong(self) -> None:
        # Nếu domain đã bơm QD2 strong thì profile default KHÔNG downgrade
        signals = Signals(domain="finance", departments=["finance"])
        recs = {r.dim: r for r in analyze(signals, "standard")}
        assert recs["QD2"].strength == "strong"

    def test_exhaustive_profile_injects_all_eight(self) -> None:
        signals = Signals()
        recs = {r.dim: r for r in analyze(signals, "exhaustive")}
        # All 7 phải có strength != "none"
        for dim in DIMENSIONS:
            assert recs[dim].strength != "none", (
                f"{dim} phải được inject bởi profile exhaustive default"
            )


# ──────────────────────────────────────────────────────────────────────
# 5. render_checklist()
# ──────────────────────────────────────────────────────────────────────


class TestRenderChecklist:
    @pytest.fixture
    def basic_recommendations(self) -> list[DimRecommendation]:
        signals = Signals(git_diff_files=["src/api/order.service.ts"])
        return analyze(signals, "standard")

    def test_renders_markdown_table_header(
        self, basic_recommendations: list[DimRecommendation]
    ) -> None:
        md = render_checklist(basic_recommendations, "standard")
        assert "| Tick |" in md
        assert "| QD |" in md
        assert "| Tên |" in md

    def test_profile_name_appears_in_title(
        self, basic_recommendations: list[DimRecommendation]
    ) -> None:
        md = render_checklist(basic_recommendations, "standard")
        assert "standard" in md

    def test_default_dims_marked_tick(
        self, basic_recommendations: list[DimRecommendation]
    ) -> None:
        md = render_checklist(basic_recommendations, "standard")
        # Standard default = [QD1, QD2, QD5]
        lines = md.split("\n")
        for dim in DEFAULT_PROFILE_DIMS["standard"]:
            matched = [ln for ln in lines if f"| {dim} |" in ln]
            assert matched, f"Row cho {dim} không tồn tại"
            # Phải có [x]
            assert "[x]" in matched[0], f"{dim} phải được tick [x] trong profile standard"

    def test_non_default_dims_marked_empty(
        self, basic_recommendations: list[DimRecommendation]
    ) -> None:
        md = render_checklist(basic_recommendations, "quick")
        # Quick default = [QD1, QD5]; các QD khác phải [ ]
        lines = md.split("\n")
        non_defaults = [d for d in DIMENSIONS if d not in DEFAULT_PROFILE_DIMS["quick"]]
        for dim in non_defaults:
            matched = [ln for ln in lines if f"| {dim} |" in ln]
            assert matched
            assert "[ ]" in matched[0], f"{dim} không phải default của quick, phải là [ ]"

    def test_strong_marker_appears(
        self, basic_recommendations: list[DimRecommendation]
    ) -> None:
        md = render_checklist(basic_recommendations, "standard")
        # Ít nhất 1 dim phải có ★ (QD1 strong từ service file)
        assert "★" in md

    def test_safety_floor_warning_for_standard(
        self, basic_recommendations: list[DimRecommendation]
    ) -> None:
        md = render_checklist(basic_recommendations, "standard")
        assert "ADR-22" in md or "safety" in md.lower() or "floor" in md.lower()

    def test_safety_floor_warning_skipped_for_quick(
        self, basic_recommendations: list[DimRecommendation]
    ) -> None:
        md = render_checklist(basic_recommendations, "quick")
        # Quick không có safety floor → không mention
        assert "ADR-22 rule 1" not in md

    def test_reason_with_pipe_escaped(self) -> None:
        # Defensive: nếu reason chứa pipe, phải escape để không phá table
        recs = [
            DimRecommendation(dim="QD1", strength="strong", reason="Lỗi | với pipe bên trong"),
        ]
        # Cần thêm đủ 7 dims cho render
        for dim in DIMENSIONS[1:]:
            recs.append(DimRecommendation(dim=dim, strength="none", reason="Không có signal"))
        md = render_checklist(recs, "standard")
        # Phải có backslash escape
        assert "\\|" in md

    def test_invalid_profile_raises(
        self, basic_recommendations: list[DimRecommendation]
    ) -> None:
        with pytest.raises(ValueError, match="profile"):
            render_checklist(basic_recommendations, "super-exhaustive")


# ──────────────────────────────────────────────────────────────────────
# 6. parse_user_response()
# ──────────────────────────────────────────────────────────────────────


class TestParseUserResponse:
    @pytest.fixture
    def recommendations_with_signals(self) -> list[DimRecommendation]:
        signals = Signals(
            git_diff_files=["src/sales/order.service.ts"],  # QD1+QD6 strong
            domain="finance",  # QD2 strong
            departments=["finance"],
        )
        return analyze(signals, "standard")

    def test_empty_returns_profile_default(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        result = parse_user_response("", recommendations_with_signals, "standard")
        assert result == set(DEFAULT_PROFILE_DIMS["standard"])

    def test_default_keyword_returns_profile_default(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        result = parse_user_response("default", recommendations_with_signals, "standard")
        assert result == set(DEFAULT_PROFILE_DIMS["standard"])

    def test_all_returns_eight_dims(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        result = parse_user_response("all", recommendations_with_signals, "standard")
        assert result == set(DIMENSIONS)

    def test_all_case_insensitive(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        assert parse_user_response("ALL", recommendations_with_signals, "standard") == set(DIMENSIONS)
        assert parse_user_response("All", recommendations_with_signals, "standard") == set(DIMENSIONS)

    def test_recommend_picks_strong_and_weak(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        result = parse_user_response("recommend", recommendations_with_signals, "standard")
        # Recommendations phải bao gồm QD1/QD2/QD6 (strong) + QD5 (standard profile default = weak)
        assert "QD1" in result  # strong (service file)
        assert "QD2" in result  # strong (finance)
        assert "QD6" in result  # strong (service file)
        assert "QD5" in result  # weak từ profile default

    def test_csv_parses_individual_dims(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        result = parse_user_response("QD1,QD2,QD5", recommendations_with_signals, "standard")
        assert result == {"QD1", "QD2", "QD5"}

    def test_csv_whitespace_tolerated(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        result = parse_user_response(
            "  QD1 , QD3 , QD7  ", recommendations_with_signals, "standard"
        )
        assert result == {"QD1", "QD3", "QD7"}

    def test_csv_case_insensitive(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        result = parse_user_response("qd1,qd3", recommendations_with_signals, "standard")
        assert result == {"QD1", "QD3"}

    def test_space_separated_tokens(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        result = parse_user_response("QD1 QD2 QD5", recommendations_with_signals, "standard")
        assert result == {"QD1", "QD2", "QD5"}

    def test_invalid_token_raises(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        with pytest.raises(ValueError, match="không hợp lệ"):
            parse_user_response("QD1,QD99", recommendations_with_signals, "standard")

    def test_non_qd_prefix_raises(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        with pytest.raises(ValueError, match="không hợp lệ"):
            parse_user_response("Q1,Q2", recommendations_with_signals, "standard")

    def test_invalid_profile_raises(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        with pytest.raises(ValueError, match="profile"):
            parse_user_response("default", recommendations_with_signals, "super-deep")

    def test_whitespace_only_response_returns_default(
        self, recommendations_with_signals: list[DimRecommendation]
    ) -> None:
        # Response chỉ có khoảng trắng → coi như empty → profile default
        result = parse_user_response("   ", recommendations_with_signals, "deep")
        assert result == set(DEFAULT_PROFILE_DIMS["deep"])


# ──────────────────────────────────────────────────────────────────────
# 7. enforce_safety_floor() — ADR-22 rule 1
# ──────────────────────────────────────────────────────────────────────


class TestEnforceSafetyFloor:
    def test_quick_profile_never_violates(self) -> None:
        # Quick không có safety floor — bất kỳ selection nào cũng OK
        ok, msg = enforce_safety_floor({"QD4"}, "quick")
        assert ok is True
        assert msg is None

    def test_quick_with_single_qd7_also_ok(self) -> None:
        ok, msg = enforce_safety_floor({"QD7"}, "quick")
        assert ok is True
        assert msg is None

    def test_standard_with_qd1_passes(self) -> None:
        ok, msg = enforce_safety_floor({"QD1", "QD4"}, "standard")
        assert ok is True
        assert msg is None

    def test_standard_with_qd2_passes(self) -> None:
        ok, msg = enforce_safety_floor({"QD2", "QD7"}, "standard")
        assert ok is True

    def test_standard_with_qd5_passes(self) -> None:
        ok, msg = enforce_safety_floor({"QD5", "QD3"}, "standard")
        assert ok is True

    def test_standard_without_floor_fails(self) -> None:
        # Bỏ toàn bộ QD1, QD2, QD5 — vi phạm ADR-22 rule 1
        ok, msg = enforce_safety_floor({"QD3", "QD4", "QD6", "QD7"}, "standard")
        assert ok is False
        assert msg is not None
        assert "QD1" in msg and "QD2" in msg and "QD5" in msg

    def test_deep_without_floor_fails(self) -> None:
        ok, msg = enforce_safety_floor({"QD3", "QD4"}, "deep")
        assert ok is False
        assert msg is not None

    def test_deep_with_only_qd1_passes(self) -> None:
        # Chỉ cần 1 trong floor
        ok, msg = enforce_safety_floor({"QD1", "QD4"}, "deep")
        assert ok is True

    def test_exhaustive_requires_all_eight(self) -> None:
        # Thiếu QD8 → fail
        ok, msg = enforce_safety_floor(set(DIMENSIONS) - {"QD8"}, "exhaustive")
        assert ok is False
        assert msg is not None and "QD8" in msg

    def test_exhaustive_with_all_eight_passes(self) -> None:
        ok, msg = enforce_safety_floor(set(DIMENSIONS), "exhaustive")
        assert ok is True
        assert msg is None

    def test_empty_selected_raises(self) -> None:
        with pytest.raises(ValueError, match="rỗng"):
            enforce_safety_floor(set(), "standard")

    def test_invalid_profile_raises(self) -> None:
        with pytest.raises(ValueError, match="profile"):
            enforce_safety_floor({"QD1"}, "super-exhaustive")

    def test_invalid_dim_in_selected_raises(self) -> None:
        with pytest.raises(ValueError, match="không hợp lệ"):
            enforce_safety_floor({"QD1", "QD99"}, "standard")

    def test_violation_message_mentions_safety_floor(self) -> None:
        ok, msg = enforce_safety_floor({"QD3"}, "standard")
        assert ok is False
        assert msg is not None
        # Must contain Vietnamese hint về floor + suggest quick
        assert "quick" in msg.lower() or "profile" in msg.lower()


# ──────────────────────────────────────────────────────────────────────
# 8. check_cdg() — CORE-027
# ──────────────────────────────────────────────────────────────────────


class TestCheckCdg:
    def test_quick_profile_no_cdg(self) -> None:
        # Quick không trigger CDG dù bỏ bất cứ QD nào
        assert check_cdg({"QD7"}, "quick") == []

    def test_exhaustive_no_cdg(self) -> None:
        # Exhaustive mặc định full 7, không cần CDG token
        assert check_cdg(set(DIMENSIONS), "exhaustive") == []

    def test_standard_missing_qd1_requires_override(self) -> None:
        tokens = check_cdg({"QD2", "QD5"}, "standard")
        assert CDG_TOKEN_OVERRIDE_QD1 in tokens

    def test_standard_with_qd1_no_cdg(self) -> None:
        tokens = check_cdg({"QD1", "QD5"}, "standard")
        assert CDG_TOKEN_OVERRIDE_QD1 not in tokens

    def test_deep_missing_qd3_requires_confirm_skip(self) -> None:
        # Deep profile bao gồm QD3; nếu user bỏ → confirm-skip-qd3
        tokens = check_cdg({"QD1", "QD2", "QD5", "QD6"}, "deep")
        assert CDG_TOKEN_SKIP_QD3 in tokens

    def test_deep_missing_qd1_requires_override(self) -> None:
        tokens = check_cdg({"QD2", "QD3", "QD5", "QD6"}, "deep")
        assert CDG_TOKEN_OVERRIDE_QD1 in tokens

    def test_deep_missing_both_qd1_and_qd3_returns_both_tokens(self) -> None:
        tokens = check_cdg({"QD2", "QD5", "QD6"}, "deep")
        assert CDG_TOKEN_OVERRIDE_QD1 in tokens
        assert CDG_TOKEN_SKIP_QD3 in tokens

    def test_deep_full_selection_no_cdg(self) -> None:
        assert check_cdg({"QD1", "QD2", "QD3", "QD5", "QD6"}, "deep") == []

    def test_duplicate_tokens_not_returned(self) -> None:
        # Defensive: mỗi token chỉ xuất hiện 1 lần
        tokens = check_cdg({"QD2", "QD5", "QD6"}, "deep")
        assert len(tokens) == len(set(tokens))

    def test_invalid_profile_raises(self) -> None:
        with pytest.raises(ValueError, match="profile"):
            check_cdg({"QD1"}, "custom")


# ──────────────────────────────────────────────────────────────────────
# 9. emit_selection() — ghi dim-selection.json
# ──────────────────────────────────────────────────────────────────────


class TestEmitSelection:
    @pytest.fixture
    def basic_setup(self, tmp_session_dir: Path) -> dict[str, object]:
        signals = Signals(
            git_diff_files=["src/sales/order.service.ts"],
            interface_type="web",
            domain="finance",
            departments=["finance"],
        )
        recs = analyze(signals, "standard")
        return {
            "signals": signals,
            "recs": recs,
            "output": tmp_session_dir / "dim-selection.json",
        }

    def test_writes_file_with_correct_schema(self, basic_setup: dict[str, object]) -> None:
        path = emit_selection(
            selected={"QD1", "QD2", "QD5"},
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="standard",
            scope={"type": "all"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=basic_setup["output"],  # type: ignore[arg-type]
        )
        assert path.exists()
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["$schema"] == "dim-selection-v1"

    def test_selected_sorted_in_output(self, basic_setup: dict[str, object]) -> None:
        path = emit_selection(
            selected={"QD5", "QD1", "QD2"},  # bất kỳ thứ tự
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="standard",
            scope={"type": "all"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=basic_setup["output"],  # type: ignore[arg-type]
        )
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["selected"] == ["QD1", "QD2", "QD5"]

    def test_skipped_lists_missing_dims(self, basic_setup: dict[str, object]) -> None:
        path = emit_selection(
            selected={"QD1", "QD2", "QD5"},
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="standard",
            scope={"type": "all"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=basic_setup["output"],  # type: ignore[arg-type]
        )
        data = json.loads(path.read_text(encoding="utf-8"))
        # v9.1.0: DIMENSIONS mở rộng QD11 → skipped string-sort: QD10, QD11 đứng trước QD3
        assert data["skipped"] == ["QD10", "QD11", "QD3", "QD4", "QD6", "QD7", "QD8", "QD9"]

    def test_safety_floor_enforced_true_when_selected_intersects(
        self, basic_setup: dict[str, object]
    ) -> None:
        path = emit_selection(
            selected={"QD1", "QD3"},  # QD1 ∈ floor
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="standard",
            scope={"type": "all"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=basic_setup["output"],  # type: ignore[arg-type]
        )
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["safety_floor_enforced"] is True

    def test_safety_floor_enforced_false_when_quick(
        self, basic_setup: dict[str, object]
    ) -> None:
        path = emit_selection(
            selected={"QD4"},
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="quick",
            scope={"type": "all"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=basic_setup["output"],  # type: ignore[arg-type]
        )
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["safety_floor_enforced"] is False

    def test_scope_with_name_preserved(self, basic_setup: dict[str, object]) -> None:
        path = emit_selection(
            selected={"QD1"},
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="quick",
            scope={"type": "system", "name": "sales"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=basic_setup["output"],  # type: ignore[arg-type]
        )
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["scope"]["type"] == "system"
        assert data["scope"]["name"] == "sales"

    def test_cdg_confirmations_written_when_provided(
        self, basic_setup: dict[str, object]
    ) -> None:
        path = emit_selection(
            selected={"QD2", "QD5"},  # Bỏ QD1 trong standard → cần CDG
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="standard",
            scope={"type": "all"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=basic_setup["output"],  # type: ignore[arg-type]
            cdg_confirmations=[CDG_TOKEN_OVERRIDE_QD1],
        )
        data = json.loads(path.read_text(encoding="utf-8"))
        assert CDG_TOKEN_OVERRIDE_QD1 in data["cdg_confirmations"]

    def test_skipped_rationale_auto_generated(
        self, basic_setup: dict[str, object]
    ) -> None:
        path = emit_selection(
            selected={"QD1", "QD2", "QD5"},
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="standard",
            scope={"type": "all"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=basic_setup["output"],  # type: ignore[arg-type]
        )
        data = json.loads(path.read_text(encoding="utf-8"))
        # Có dims bị skip → rationale phải có
        assert "skipped_rationale" in data
        assert len(data["skipped_rationale"]) > 0

    def test_skipped_rationale_override(self, basic_setup: dict[str, object]) -> None:
        custom = "User chọn quick vì PR nhỏ."
        path = emit_selection(
            selected={"QD1", "QD2", "QD5"},
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="standard",
            scope={"type": "all"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=basic_setup["output"],  # type: ignore[arg-type]
            skipped_rationale=custom,
        )
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["skipped_rationale"] == custom

    def test_source_signals_present(self, basic_setup: dict[str, object]) -> None:
        path = emit_selection(
            selected={"QD1", "QD2", "QD5"},
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="standard",
            scope={"type": "all"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=basic_setup["output"],  # type: ignore[arg-type]
        )
        data = json.loads(path.read_text(encoding="utf-8"))
        src = data["source_signals"]
        assert src["git_diff_files"] == 1
        assert src["interface_type"] == "web"
        assert src["domain"] == "finance"

    def test_recommendations_serialized(self, basic_setup: dict[str, object]) -> None:
        path = emit_selection(
            selected={"QD1"},
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="quick",
            scope={"type": "all"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=basic_setup["output"],  # type: ignore[arg-type]
        )
        data = json.loads(path.read_text(encoding="utf-8"))
        # Mỗi recommendation phải có 3 field dim/strength/reason — 1 entry mỗi dimension (v9.0.2: 10 dims)
        assert len(data["recommendations"]) == len(DIMENSIONS)
        for r in data["recommendations"]:
            assert "dim" in r and "strength" in r and "reason" in r

    def test_empty_selected_raises(self, basic_setup: dict[str, object]) -> None:
        with pytest.raises(ValueError, match="rỗng"):
            emit_selection(
                selected=set(),
                recommendations=basic_setup["recs"],  # type: ignore[arg-type]
                profile="quick",
                scope={"type": "all"},
                signals=basic_setup["signals"],  # type: ignore[arg-type]
                output_path=basic_setup["output"],  # type: ignore[arg-type]
            )

    def test_invalid_profile_raises(self, basic_setup: dict[str, object]) -> None:
        with pytest.raises(ValueError, match="profile"):
            emit_selection(
                selected={"QD1"},
                recommendations=basic_setup["recs"],  # type: ignore[arg-type]
                profile="super-exhaustive",
                scope={"type": "all"},
                signals=basic_setup["signals"],  # type: ignore[arg-type]
                output_path=basic_setup["output"],  # type: ignore[arg-type]
            )

    def test_invalid_scope_type_raises(self, basic_setup: dict[str, object]) -> None:
        with pytest.raises(ValueError, match="scope.type"):
            emit_selection(
                selected={"QD1"},
                recommendations=basic_setup["recs"],  # type: ignore[arg-type]
                profile="quick",
                scope={"type": "hacker"},
                signals=basic_setup["signals"],  # type: ignore[arg-type]
                output_path=basic_setup["output"],  # type: ignore[arg-type]
            )

    def test_scope_missing_type_raises(self, basic_setup: dict[str, object]) -> None:
        with pytest.raises(ValueError, match="type"):
            emit_selection(
                selected={"QD1"},
                recommendations=basic_setup["recs"],  # type: ignore[arg-type]
                profile="quick",
                scope={"name": "sales"},  # type: ignore[arg-type]
                signals=basic_setup["signals"],  # type: ignore[arg-type]
                output_path=basic_setup["output"],  # type: ignore[arg-type]
            )

    def test_invalid_dim_in_selected_raises(self, basic_setup: dict[str, object]) -> None:
        with pytest.raises(ValueError, match="không hợp lệ"):
            emit_selection(
                selected={"QD1", "QD99"},
                recommendations=basic_setup["recs"],  # type: ignore[arg-type]
                profile="quick",
                scope={"type": "all"},
                signals=basic_setup["signals"],  # type: ignore[arg-type]
                output_path=basic_setup["output"],  # type: ignore[arg-type]
            )

    def test_unknown_interface_type_falls_back_to_null(
        self, tmp_session_dir: Path
    ) -> None:
        # Signal có interface_type lạ → schema enum không chấp → fallback None
        signals = Signals(interface_type="minigame")
        recs = analyze(signals, "quick")
        output = tmp_session_dir / "dim-selection.json"
        path = emit_selection(
            selected={"QD1"},
            recommendations=recs,
            profile="quick",
            scope={"type": "all"},
            signals=signals,
            output_path=output,
        )
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["source_signals"]["interface_type"] is None

    def test_atomic_write_leaves_no_tmp_file(
        self, basic_setup: dict[str, object]
    ) -> None:
        output: Path = basic_setup["output"]  # type: ignore[assignment]
        emit_selection(
            selected={"QD1", "QD2", "QD5"},
            recommendations=basic_setup["recs"],  # type: ignore[arg-type]
            profile="standard",
            scope={"type": "all"},
            signals=basic_setup["signals"],  # type: ignore[arg-type]
            output_path=output,
        )
        # Sau khi hoàn tất, không còn tempfile .tmp nào trong cùng dir
        tmp_files = list(output.parent.glob("*.tmp"))
        assert tmp_files == [], f"Còn tempfile rò rỉ: {tmp_files}"


# ──────────────────────────────────────────────────────────────────────
# 10. collect_signals() — registry + graceful git failure
# ──────────────────────────────────────────────────────────────────────


class TestCollectSignals:
    def test_reads_departments_from_registry(self, tmp_registry: Path) -> None:
        # tmp_registry nằm tại tmp_path/.mc-data/docs/_meta/
        # Project root = tmp_path (chứa .mc-data/)
        project_root = tmp_registry.parent.parent.parent.parent
        # session_dir = project_root/session
        session = project_root / "session"
        session.mkdir(parents=True, exist_ok=True)

        signals = collect_signals(session_dir=session, scope="all")

        assert "finance" in signals.departments
        assert "logistics" in signals.departments
        assert signals.interface_type == "web"
        # Domain được derive từ dept đầu tiên match
        assert signals.domain in {"finance", "logistics"}

    def test_missing_registry_graceful(self, tmp_session_dir: Path) -> None:
        # Không có .mc-data/ trong path → empty signals
        signals = collect_signals(session_dir=tmp_session_dir, scope="all")
        # Không raise; các field default
        assert signals.departments == []
        assert signals.interface_type is None
        assert signals.domain is None

    def test_invalid_json_registry_graceful(self, tmp_path: Path) -> None:
        # Registry tồn tại nhưng parse fail → signals trống
        registry_dir = tmp_path / ".mc-data" / "docs" / "_meta"
        registry_dir.mkdir(parents=True, exist_ok=True)
        registry_path = registry_dir / "req-registry.json"
        registry_path.write_text("{ this is not valid JSON", encoding="utf-8")

        session = tmp_path / "session"
        session.mkdir(parents=True, exist_ok=True)

        signals = collect_signals(session_dir=session, scope="all")
        assert signals.departments == []
        assert signals.interface_type is None

    def test_departments_as_dict_normalized_to_string(self, tmp_path: Path) -> None:
        # Registry có departments dạng [{"id": "finance"}] → phải trích tên
        registry_dir = tmp_path / ".mc-data" / "docs" / "_meta"
        registry_dir.mkdir(parents=True, exist_ok=True)
        registry_path = registry_dir / "req-registry.json"
        registry_data = {
            "project": {"name": "test"},
            "departments": [{"id": "finance"}, {"name": "healthcare"}],
            "interface_type": "api-only",
        }
        registry_path.write_text(
            json.dumps(registry_data, ensure_ascii=False),
            encoding="utf-8",
        )

        session = tmp_path / "session"
        session.mkdir(parents=True, exist_ok=True)

        signals = collect_signals(session_dir=session, scope="all")
        assert "finance" in signals.departments
        assert "healthcare" in signals.departments
        assert signals.interface_type == "api-only"


# ──────────────────────────────────────────────────────────────────────
# 11. DimRecommendation.to_dict()
# ──────────────────────────────────────────────────────────────────────


class TestDimRecommendationToDict:
    def test_to_dict_has_all_three_fields(self) -> None:
        rec = DimRecommendation(dim="QD1", strength="strong", reason="Lý do test đủ 10 ký tự")
        d = rec.to_dict()
        assert d == {
            "dim": "QD1",
            "strength": "strong",
            "reason": "Lý do test đủ 10 ký tự",
        }

    def test_to_dict_is_json_serializable(self) -> None:
        rec = DimRecommendation(dim="QD2", strength="weak", reason="Gợi ý yếu cho QD2")
        # Không raise
        assert json.dumps(rec.to_dict(), ensure_ascii=False)


# ──────────────────────────────────────────────────────────────────────
# 12. Integration: full flow (analyze → render → parse → enforce → emit)
# ──────────────────────────────────────────────────────────────────────


class TestFullFlowIntegration:
    """Happy-path end-to-end cho flow ISG, mô phỏng orchestrator."""

    def test_happy_path_standard_profile(self, tmp_session_dir: Path) -> None:
        # 1. Collect + analyze
        signals = Signals(
            git_diff_files=["src/sales/order.service.ts"],
            interface_type="web",
            domain="finance",
            departments=["finance"],
        )
        recs = analyze(signals, "standard")

        # 2. Render (không raise, có markdown)
        md = render_checklist(recs, "standard")
        assert len(md) > 0

        # 3. Parse user "default"
        selected = parse_user_response("default", recs, "standard")
        assert selected == set(DEFAULT_PROFILE_DIMS["standard"])

        # 4. Enforce safety
        ok, msg = enforce_safety_floor(selected, "standard")
        assert ok is True and msg is None

        # 5. Check CDG (default bao gồm QD1+QD2+QD5 → không cần CDG)
        cdg_tokens = check_cdg(selected, "standard")
        assert cdg_tokens == []

        # 6. Emit
        output = tmp_session_dir / "dim-selection.json"
        emit_selection(
            selected=selected,
            recommendations=recs,
            profile="standard",
            scope={"type": "all"},
            signals=signals,
            output_path=output,
        )
        data = json.loads(output.read_text(encoding="utf-8"))
        assert data["$schema"] == "dim-selection-v1"
        assert data["safety_floor_enforced"] is True

    def test_override_path_deep_profile_skips_qd1_and_qd3(
        self, tmp_session_dir: Path
    ) -> None:
        # User cố tình bỏ QD1 + QD3 trong profile deep → cần 2 CDG tokens
        signals = Signals(
            git_diff_files=["src/api/order.service.ts"],
            domain="finance",
            departments=["finance"],
        )
        recs = analyze(signals, "deep")

        # User chọn QD2, QD5, QD6 → bỏ QD1+QD3
        selected = parse_user_response("QD2,QD5,QD6", recs, "deep")
        assert selected == {"QD2", "QD5", "QD6"}

        # Safety floor pass (QD2+QD5 ∈ floor)
        ok, _ = enforce_safety_floor(selected, "deep")
        assert ok is True

        # CDG phải yêu cầu cả 2 tokens
        cdg_tokens = check_cdg(selected, "deep")
        assert set(cdg_tokens) == {CDG_TOKEN_OVERRIDE_QD1, CDG_TOKEN_SKIP_QD3}

        # Emit với cdg_confirmations
        output = tmp_session_dir / "dim-selection.json"
        emit_selection(
            selected=selected,
            recommendations=recs,
            profile="deep",
            scope={"type": "all"},
            signals=signals,
            output_path=output,
            cdg_confirmations=cdg_tokens,
        )
        data = json.loads(output.read_text(encoding="utf-8"))
        assert set(data["cdg_confirmations"]) == {
            CDG_TOKEN_OVERRIDE_QD1,
            CDG_TOKEN_SKIP_QD3,
        }

    def test_safety_floor_violation_blocks_emit(
        self, tmp_session_dir: Path
    ) -> None:
        signals = Signals()
        recs = analyze(signals, "standard")

        # User bỏ toàn bộ floor
        selected = {"QD3", "QD4", "QD7"}
        ok, msg = enforce_safety_floor(selected, "standard")
        assert ok is False
        # Orchestrator phải dừng trước khi emit → không test emit ở đây
        assert msg is not None


# ──────────────────────────────────────────────────────────────────────
# Module-level smoke test
# ──────────────────────────────────────────────────────────────────────


def test_module_exports_populated() -> None:
    """Import smoke test — đảm bảo public API không bị rỗng sau refactor."""
    from isg import (  # noqa: F401
        DimRecommendation,
        Signals,
        analyze,
        check_cdg,
        collect_signals,
        emit_selection,
        enforce_safety_floor,
        parse_user_response,
        render_checklist,
    )
