"""test_signal_bus.py — Tests cho signal_bus.signal_bus.

Phạm vi chính:
    - Signal.from_dict happy-path + validation guards.
    - validate_evidence (ADR-09): ≥1 non-empty + đủ min length.
    - compute_dedup_key: deterministic, 64 hex, khác target → khác key.
    - detect_secrets_hint (ADR-22 rule 4): match các pattern secret.
    - normalize Signal→Issue: set triage_status="cdg_required" khi có secrets.
    - merge_or_append: dedup theo dedup_key, union probe_sources.
    - _escalate_triage: priority cdg_required > triaged > deferred > pending > closed.
    - post_gate_check T1-T4 (ADR-22 rule 5).
    - SignalBus ingest + flush round-trip.
"""
from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any

import pytest

from signal_bus.signal_bus import (
    DEDUP_KEY_PATTERN,
    ISSUE_ID_PATTERN,
    ISSUE_SCHEMA_ID,
    MIN_EVIDENCE_LENGTH,
    REGISTRY_SCHEMA_ID,
    SECRETS_HINT_PATTERNS,
    SIGNAL_SCHEMA_ID,
    VALID_DIMENSIONS,
    VALID_EVIDENCE_KINDS,
    Issue,
    Signal,
    SignalBus,
    _escalate_triage,
    compute_dedup_key,
    detect_secrets_hint,
    merge_or_append,
    normalize,
    post_gate_check,
    validate_evidence,
)


# ──────────────────────────────────────────────────────────────────────
# Constants sanity
# ──────────────────────────────────────────────────────────────────────


class TestConstants:
    def test_schema_ids(self) -> None:
        assert SIGNAL_SCHEMA_ID == "signal-v2"
        assert ISSUE_SCHEMA_ID == "issue-v2"
        assert REGISTRY_SCHEMA_ID == "issue-registry-v2"

    def test_valid_dimensions_cover_11(self) -> None:
        # v9.1.0: 11 dimensions (QD1-QD11 — thêm QD11 Business Completeness)
        assert VALID_DIMENSIONS == frozenset(
            {"QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"}
        )

    def test_min_evidence_length_required_kinds(self) -> None:
        assert MIN_EVIDENCE_LENGTH["code_snippet"] == 10
        assert MIN_EVIDENCE_LENGTH["log_excerpt"] == 20
        assert MIN_EVIDENCE_LENGTH["stacktrace"] == 50

    def test_secrets_hint_patterns_has_core_keywords(self) -> None:
        lowered = {p.lower() for p in SECRETS_HINT_PATTERNS}
        for needed in ("api_key", "apikey", "password", "secret"):
            assert needed in lowered


# ──────────────────────────────────────────────────────────────────────
# Signal.from_dict
# ──────────────────────────────────────────────────────────────────────


class TestSignalFromDict:
    def test_happy_path(self, sample_signal_dict: dict[str, Any]) -> None:
        s = Signal.from_dict(sample_signal_dict)
        assert s.probe_id == "P-QD1-sample-probe"
        assert s.dimension_id == "QD1"
        assert s.target["kind"] == "code"
        assert len(s.description) >= 10

    @pytest.mark.parametrize(
        "missing_field",
        [
            "probe_id",
            "probe_version",
            "emitted_at",
            "lane",
            "dimension_id",
            "target",
            "description",
            "evidence",
        ],
    )
    def test_missing_required_raises(
        self, sample_signal_dict: dict[str, Any], missing_field: str
    ) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        del bad[missing_field]
        with pytest.raises(ValueError, match="thiếu required field"):
            Signal.from_dict(bad)

    def test_invalid_dimension_raises(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        bad["dimension_id"] = "QD99"
        with pytest.raises(ValueError, match="dimension_id"):
            Signal.from_dict(bad)

    def test_invalid_probe_id_format_raises(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        bad["probe_id"] = "bad_probe_id"
        with pytest.raises(ValueError, match="probe_id"):
            Signal.from_dict(bad)

    def test_target_missing_kind_raises(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        del bad["target"]["kind"]
        with pytest.raises(ValueError, match="target.kind"):
            Signal.from_dict(bad)

    def test_evidence_not_dict_raises(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        bad["evidence"] = "not-a-dict"
        with pytest.raises(ValueError, match="evidence"):
            Signal.from_dict(bad)

    def test_description_too_short_raises(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        bad["description"] = "short"  # < 10 ký tự
        with pytest.raises(ValueError, match="description"):
            Signal.from_dict(bad)


# ──────────────────────────────────────────────────────────────────────
# validate_evidence (ADR-09)
# ──────────────────────────────────────────────────────────────────────


class TestValidateEvidence:
    def test_valid_code_snippet_passes(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        s = Signal.from_dict(sample_signal_dict)
        ok, reason = validate_evidence(s)
        assert ok is True
        assert reason is None

    def test_all_empty_fails(self, sample_signal_dict: dict[str, Any]) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        bad["evidence"] = {k: None for k in sample_signal_dict["evidence"]}
        s = Signal.from_dict(bad)
        ok, reason = validate_evidence(s)
        assert ok is False
        assert reason is not None
        assert "missing-evidence" in reason

    def test_short_code_snippet_fails(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        bad["evidence"]["code_snippet"] = "a"  # < 10 ký tự
        s = Signal.from_dict(bad)
        ok, _ = validate_evidence(s)
        assert ok is False

    def test_unknown_kind_ignored(self, sample_signal_dict: dict[str, Any]) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        bad["evidence"] = {
            "garbage_kind": "a" * 100,
            "code_snippet": None,
        }
        s = Signal.from_dict(bad)
        ok, _ = validate_evidence(s)
        assert ok is False


# ──────────────────────────────────────────────────────────────────────
# compute_dedup_key
# ──────────────────────────────────────────────────────────────────────


class TestComputeDedupKey:
    def test_returns_64_hex(self, sample_signal_dict: dict[str, Any]) -> None:
        s = Signal.from_dict(sample_signal_dict)
        key = compute_dedup_key(s)
        assert DEDUP_KEY_PATTERN.match(key)

    def test_deterministic(self, sample_signal_dict: dict[str, Any]) -> None:
        s1 = Signal.from_dict(sample_signal_dict)
        s2 = Signal.from_dict(sample_signal_dict)
        assert compute_dedup_key(s1) == compute_dedup_key(s2)

    def test_different_dimensions_different_keys(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        s1 = Signal.from_dict(sample_signal_dict)
        bad = copy.deepcopy(sample_signal_dict)
        bad["dimension_id"] = "QD2"
        s2 = Signal.from_dict(bad)
        assert compute_dedup_key(s1) != compute_dedup_key(s2)

    def test_different_file_path_different_keys(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        s1 = Signal.from_dict(sample_signal_dict)
        bad = copy.deepcopy(sample_signal_dict)
        bad["target"]["file_path"] = "src/another/path.ts"
        s2 = Signal.from_dict(bad)
        assert compute_dedup_key(s1) != compute_dedup_key(s2)

    def test_missing_line_range_uses_default(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        del bad["target"]["line_range"]
        s = Signal.from_dict(bad)
        # Vẫn sinh key, không raise
        assert DEDUP_KEY_PATTERN.match(compute_dedup_key(s))


# ──────────────────────────────────────────────────────────────────────
# detect_secrets_hint (ADR-22 rule 4)
# ──────────────────────────────────────────────────────────────────────


class TestDetectSecretsHint:
    def _inject(
        self, base: dict[str, Any], evidence_kind: str, content: str
    ) -> Signal:
        sig = copy.deepcopy(base)
        sig["evidence"][evidence_kind] = content
        return Signal.from_dict(sig)

    def test_clean_code_no_hint(self, sample_signal_dict: dict[str, Any]) -> None:
        s = Signal.from_dict(sample_signal_dict)
        assert detect_secrets_hint(s) is False

    @pytest.mark.parametrize(
        "snippet",
        [
            "const api_key = 'abc123';",
            "const apiKey = process.env.FOO;",
            "password = 'supersecret';",
            "Authorization: Bearer abc.def.ghi",
            "private_key = open('key.pem').read()",
            "-----BEGIN PRIVATE KEY-----",
            "credential: my-cred",
            "secret=xyz",
        ],
    )
    def test_code_snippet_triggers_hint(
        self, sample_signal_dict: dict[str, Any], snippet: str
    ) -> None:
        s = self._inject(sample_signal_dict, "code_snippet", snippet)
        assert detect_secrets_hint(s) is True

    def test_log_excerpt_triggers_hint(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        s = self._inject(
            sample_signal_dict,
            "log_excerpt",
            "Leaked token: Bearer abc.def + padding for min length >= 20 chars",
        )
        assert detect_secrets_hint(s) is True


# ──────────────────────────────────────────────────────────────────────
# normalize
# ──────────────────────────────────────────────────────────────────────


class TestNormalize:
    def test_happy_path(self, sample_signal_dict: dict[str, Any]) -> None:
        s = Signal.from_dict(sample_signal_dict)
        issue = normalize(s, "ISS-20260420-001")
        assert issue.issue_id == "ISS-20260420-001"
        assert issue.dimensions == ["QD1"]
        assert len(issue.evidence) >= 1
        assert DEDUP_KEY_PATTERN.match(issue.dedup_key)
        assert issue.triage_status == "pending"
        assert issue.probe_sources == [
            {"probe_id": s.probe_id, "probe_version": s.probe_version}
        ]

    def test_secrets_hint_sets_cdg_required(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        bad["evidence"]["code_snippet"] = "api_key = 'real-secret-value'"
        s = Signal.from_dict(bad)
        issue = normalize(s, "ISS-20260420-001")
        assert issue.triage_status == "cdg_required"

    def test_invalid_issue_id_raises(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        s = Signal.from_dict(sample_signal_dict)
        with pytest.raises(ValueError, match="issue_id"):
            normalize(s, "INVALID-ID")

    def test_to_dict_has_schema(self, sample_signal_dict: dict[str, Any]) -> None:
        s = Signal.from_dict(sample_signal_dict)
        issue = normalize(s, "ISS-20260420-001")
        d = issue.to_dict()
        assert d["$schema"] == ISSUE_SCHEMA_ID
        for key in (
            "issue_id",
            "dimensions",
            "target",
            "title",
            "description_md",
            "probe_sources",
            "evidence",
            "dedup_key",
            "triage_status",
        ):
            assert key in d


# ──────────────────────────────────────────────────────────────────────
# merge_or_append
# ──────────────────────────────────────────────────────────────────────


class TestMergeOrAppend:
    def test_different_key_appends(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        s1 = Signal.from_dict(sample_signal_dict)
        iss1 = normalize(s1, "ISS-20260420-001")

        other = copy.deepcopy(sample_signal_dict)
        other["target"]["file_path"] = "src/other.ts"
        s2 = Signal.from_dict(other)
        iss2 = normalize(s2, "ISS-20260420-002")

        merged, action = merge_or_append(iss2, [iss1])
        assert action == "appended"
        assert len(merged) == 2

    def test_same_key_merges_probe_sources_union(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        s1 = Signal.from_dict(sample_signal_dict)
        iss1 = normalize(s1, "ISS-20260420-001")

        dup = copy.deepcopy(sample_signal_dict)
        dup["probe_id"] = "P-QD1-other-probe"  # cùng target, khác probe
        dup["probe_version"] = "0.2.0"
        s2 = Signal.from_dict(dup)
        iss2 = normalize(s2, "ISS-20260420-002")

        merged, action = merge_or_append(iss2, [iss1])
        assert action == "merged"
        assert len(merged) == 1
        # Giữ issue_id ban đầu
        assert merged[0].issue_id == "ISS-20260420-001"
        probe_ids = {p["probe_id"] for p in merged[0].probe_sources}
        assert probe_ids == {"P-QD1-sample-probe", "P-QD1-other-probe"}

    def test_merge_escalates_cdg_required(
        self, sample_signal_dict: dict[str, Any]
    ) -> None:
        # iss1 pending, iss2 có secrets → merged phải là cdg_required
        s1 = Signal.from_dict(sample_signal_dict)
        iss1 = normalize(s1, "ISS-20260420-001")
        assert iss1.triage_status == "pending"

        dup = copy.deepcopy(sample_signal_dict)
        dup["probe_id"] = "P-QD1-other-probe"
        dup["evidence"]["code_snippet"] = "password = 'leaked-creds'"
        s2 = Signal.from_dict(dup)
        iss2 = normalize(s2, "ISS-20260420-002")
        assert iss2.triage_status == "cdg_required"

        merged, action = merge_or_append(iss2, [iss1])
        assert action == "merged"
        assert merged[0].triage_status == "cdg_required"


# ──────────────────────────────────────────────────────────────────────
# _escalate_triage
# ──────────────────────────────────────────────────────────────────────


class TestEscalateTriage:
    @pytest.mark.parametrize(
        "existing,new,expected",
        [
            ("pending", "cdg_required", "cdg_required"),
            ("pending", "triaged", "triaged"),
            ("triaged", "pending", "triaged"),
            ("cdg_required", "triaged", "cdg_required"),
            ("deferred", "pending", "deferred"),
            ("closed", "pending", "pending"),
            ("pending", "pending", "pending"),
        ],
    )
    def test_priority_order(self, existing: str, new: str, expected: str) -> None:
        assert _escalate_triage(existing, new) == expected


# ──────────────────────────────────────────────────────────────────────
# post_gate_check (ADR-22 rule 5)
# ──────────────────────────────────────────────────────────────────────


class TestPostGateCheck:
    def _write(self, path: Path, data: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data), encoding="utf-8")

    def test_missing_file_fails_t1(self, tmp_path: Path) -> None:
        ok, errors = post_gate_check(tmp_path / "no-file.json")
        assert ok is False
        assert any("T1" in e for e in errors)

    def test_empty_file_fails_t1(self, tmp_path: Path) -> None:
        p = tmp_path / "empty.json"
        p.write_text("", encoding="utf-8")
        ok, errors = post_gate_check(p)
        assert ok is False
        assert any("T1" in e for e in errors)

    def test_bad_json_fails_t2(self, tmp_path: Path) -> None:
        p = tmp_path / "bad.json"
        p.write_text("{ not valid json", encoding="utf-8")
        ok, errors = post_gate_check(p)
        assert ok is False
        assert any("T2" in e for e in errors)

    def test_missing_schema_fails_t2(self, tmp_path: Path) -> None:
        p = tmp_path / "reg.json"
        self._write(p, {"issues": []})
        ok, errors = post_gate_check(p)
        # $schema sai → error, nhưng issues=[] OK → T3/T4 không thêm errors
        assert ok is False
        assert any("$schema" in e for e in errors)

    def test_issues_not_array_fails_t2(self, tmp_path: Path) -> None:
        p = tmp_path / "reg.json"
        self._write(p, {"$schema": REGISTRY_SCHEMA_ID, "issues": "not-array"})
        ok, errors = post_gate_check(p)
        assert ok is False
        assert any("issues" in e for e in errors)

    def test_happy_path_with_valid_issue(
        self, tmp_path: Path, sample_signal_dict: dict[str, Any]
    ) -> None:
        s = Signal.from_dict(sample_signal_dict)
        issue = normalize(s, "ISS-20260420-001")
        p = tmp_path / "reg.json"
        self._write(
            p,
            {
                "$schema": REGISTRY_SCHEMA_ID,
                "generated_at": "2026-04-20T00:00:00+00:00",
                "issues": [issue.to_dict()],
            },
        )
        ok, errors = post_gate_check(p)
        assert ok is True, f"Expected PASS, got errors: {errors}"

    def test_invalid_issue_id_format_fails_t3(
        self, tmp_path: Path, sample_signal_dict: dict[str, Any]
    ) -> None:
        s = Signal.from_dict(sample_signal_dict)
        issue = normalize(s, "ISS-20260420-001")
        bad_dict = issue.to_dict()
        bad_dict["issue_id"] = "BAD-ID"
        p = tmp_path / "reg.json"
        self._write(p, {"$schema": REGISTRY_SCHEMA_ID, "issues": [bad_dict]})
        ok, errors = post_gate_check(p)
        assert ok is False
        assert any("T3" in e and "issue_id" in e for e in errors)

    def test_invalid_dimension_fails_t4(
        self, tmp_path: Path, sample_signal_dict: dict[str, Any]
    ) -> None:
        s = Signal.from_dict(sample_signal_dict)
        issue = normalize(s, "ISS-20260420-001")
        bad_dict = issue.to_dict()
        bad_dict["dimensions"] = ["QD99"]
        p = tmp_path / "reg.json"
        self._write(p, {"$schema": REGISTRY_SCHEMA_ID, "issues": [bad_dict]})
        ok, errors = post_gate_check(p)
        assert ok is False
        assert any("T4" in e and "QD99" in e for e in errors)


# ──────────────────────────────────────────────────────────────────────
# SignalBus round-trip
# ──────────────────────────────────────────────────────────────────────


class TestSignalBusRoundTrip:
    def test_ingest_and_flush(
        self, tmp_session_dir: Path, sample_signal_dict: dict[str, Any]
    ) -> None:
        bus = SignalBus(tmp_session_dir)
        bus.load_existing()
        issue = bus.ingest(sample_signal_dict)
        assert ISSUE_ID_PATTERN.match(issue.issue_id)

        path = bus.flush()
        assert path.exists()
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["$schema"] == REGISTRY_SCHEMA_ID
        assert len(data["issues"]) == 1

    def test_ingest_dedup_same_target(
        self, tmp_session_dir: Path, sample_signal_dict: dict[str, Any]
    ) -> None:
        """2 signal cùng target → 1 issue trong registry."""
        bus = SignalBus(tmp_session_dir)
        bus.ingest(sample_signal_dict)

        other = copy.deepcopy(sample_signal_dict)
        other["probe_id"] = "P-QD1-another"
        bus.ingest(other)

        bus.flush()
        data = json.loads(bus.registry_path.read_text(encoding="utf-8"))
        assert len(data["issues"]) == 1
        probe_ids = {p["probe_id"] for p in data["issues"][0]["probe_sources"]}
        assert probe_ids == {"P-QD1-sample-probe", "P-QD1-another"}

    def test_ingest_rejects_bad_evidence(
        self, tmp_session_dir: Path, sample_signal_dict: dict[str, Any]
    ) -> None:
        bad = copy.deepcopy(sample_signal_dict)
        bad["evidence"] = {"code_snippet": None}
        bus = SignalBus(tmp_session_dir)
        with pytest.raises(ValueError, match="missing-evidence"):
            bus.ingest(bad)
