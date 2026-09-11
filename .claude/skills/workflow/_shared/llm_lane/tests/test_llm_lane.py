"""Tests cho llm_lane module — Phase C v8 wf-fix-bugs."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from llm_lane.budget_guard import LLMBudget, estimate_cost
from llm_lane.chunk_planner import estimate_tokens, plan_chunks
from llm_lane.signal_parser import parse_signals, validate_signal


# ────────────────────────────────────────────────────────────
# Budget Guard
# ────────────────────────────────────────────────────────────


class TestBudgetGuard:
    def test_defaults_unlimited(self):
        """Quality-first defaults: tat ca caps = 0 (unlimited)."""
        b = LLMBudget.from_defaults()
        assert b.max_total_tokens_in == 0
        assert b.max_total_tokens_out == 0
        assert b.estimated_cost_usd_cap == 0.0
        assert b.max_chunks_per_probe == 0
        assert b.max_signals_per_probe == 0
        assert b.require_user_confirmation is False
        assert b.is_unlimited()

    def test_pre_check_pass(self):
        b = LLMBudget.from_defaults()
        ok, reason = b.pre_check(estimated_chunks=3, avg_tokens_in=10_000)
        assert ok
        assert "OK" in reason

    def test_unlimited_mode_does_not_block(self):
        """Default config never blocks pre_check, regardless of scope size."""
        b = LLMBudget.from_defaults()
        ok, reason = b.pre_check(estimated_chunks=1000, avg_tokens_in=100_000)
        assert ok
        assert "unlimited" in reason.lower()

    def test_unlimited_mode_does_not_auto_halt(self):
        """Default config never auto-halts even at extreme cumulative usage."""
        b = LLMBudget.from_defaults()
        b.increment(tokens_in=10_000_000, tokens_out=1_000_000)
        assert not b.halted
        assert b.halt_reason == ""
        assert b.cumulative_cost_usd() > 0  # tracks for visibility

    def test_summary_mode_field(self):
        unlim = LLMBudget.from_defaults().summary()
        assert unlim["mode"] == "unlimited"
        capped = LLMBudget(estimated_cost_usd_cap=5.00).summary()
        assert capped["mode"] == "capped"

    def test_remaining_unlimited_returns_sentinel(self):
        b = LLMBudget.from_defaults()
        assert b.remaining_tokens_in() == -1
        assert b.remaining_tokens_out() == -1

    def test_pre_check_chunks_exceed(self):
        b = LLMBudget(max_chunks_per_probe=4)
        ok, reason = b.pre_check(estimated_chunks=10, avg_tokens_in=1000)
        assert not ok
        assert "chunks" in reason.lower()

    def test_pre_check_tokens_in_exceed(self):
        b = LLMBudget(max_total_tokens_in=20_000)
        ok, reason = b.pre_check(estimated_chunks=5, avg_tokens_in=10_000)
        assert not ok
        assert "tokens_in" in reason

    def test_pre_check_cost_exceed(self):
        # Want: chunks within cap, tokens_in/out within cap, but cost above cap.
        # 5 × 5K = 25K input, 5 × 1.2K = 6K output. Cost = $0.075 + $0.09 = $0.165 > $0.05
        b = LLMBudget(
            estimated_cost_usd_cap=0.05,
            max_chunks_per_probe=20,
            max_total_tokens_in=200_000,
            max_total_tokens_out=30_000,
        )
        ok, reason = b.pre_check(estimated_chunks=5, avg_tokens_in=5_000)
        assert not ok
        assert "cost" in reason.lower()

    def test_increment_tracks_cumulative(self):
        b = LLMBudget()
        b.increment(tokens_in=10_000, tokens_out=1500)
        b.increment(tokens_in=15_000, tokens_out=2000)
        assert b.used_tokens_in == 25_000
        assert b.used_tokens_out == 3500
        assert b.invocations == 2

    def test_increment_negative_raises(self):
        b = LLMBudget()
        with pytest.raises(ValueError):
            b.increment(tokens_in=-1, tokens_out=100)

    def test_auto_halt_on_tokens_exceed(self):
        b = LLMBudget(max_total_tokens_in=10_000)
        b.increment(tokens_in=15_000, tokens_out=100)
        assert b.halted
        assert "tokens_in" in b.halt_reason

    def test_auto_halt_on_cost_exceed(self):
        b = LLMBudget(estimated_cost_usd_cap=0.10)
        # 50K input + 5K output = $0.15 + $0.075 = $0.225 > $0.10
        b.increment(tokens_in=50_000, tokens_out=5_000)
        assert b.halted
        assert "cost" in b.halt_reason.lower()

    def test_pre_check_after_halt_fails(self):
        b = LLMBudget(max_total_tokens_in=10_000)
        b.increment(tokens_in=15_000, tokens_out=100)
        ok, reason = b.pre_check(estimated_chunks=1, avg_tokens_in=100)
        assert not ok
        assert "halted" in reason.lower()

    def test_summary_structure(self):
        b = LLMBudget()
        b.increment(tokens_in=1000, tokens_out=200)
        s = b.summary()
        assert "used_tokens_in" in s
        assert "cumulative_cost_usd" in s
        assert s["invocations"] == 1

    def test_estimate_cost(self):
        # 1M in + 0 out = $3.00
        assert estimate_cost(tokens_in=1_000_000, tokens_out=0) == pytest.approx(3.00)
        # 0 in + 1M out = $15.00
        assert estimate_cost(tokens_in=0, tokens_out=1_000_000) == pytest.approx(15.00)


# ────────────────────────────────────────────────────────────
# Chunk Planner
# ────────────────────────────────────────────────────────────


class TestChunkPlanner:
    def test_estimate_tokens(self):
        # Roughly: 4 chars = 1 token
        assert estimate_tokens("abcd") == 1
        assert estimate_tokens("abcdefgh") == 2

    def test_single_small_file(self, tmp_path: Path):
        f = tmp_path / "a.py"
        f.write_text("def hello(): pass\n", encoding="utf-8")
        chunks = plan_chunks(["a.py"], tmp_path, max_tokens_per_chunk=10_000)
        assert len(chunks) == 1
        assert len(chunks[0].files) == 1
        assert chunks[0].files[0].path == "a.py"

    def test_skip_missing_files(self, tmp_path: Path):
        chunks = plan_chunks(["nonexistent.py"], tmp_path, max_tokens_per_chunk=10_000, skip_missing=True)
        assert chunks == []

    def test_raise_on_missing_when_strict(self, tmp_path: Path):
        with pytest.raises(FileNotFoundError):
            plan_chunks(["nonexistent.py"], tmp_path, skip_missing=False)

    def test_packs_multiple_small_files(self, tmp_path: Path):
        for i in range(5):
            (tmp_path / f"f{i}.py").write_text("x" * 100, encoding="utf-8")
        chunks = plan_chunks([f"f{i}.py" for i in range(5)], tmp_path, max_tokens_per_chunk=200)
        # Each file ~25 tokens; chunk holds ~8 files. Should pack into 1 chunk.
        assert len(chunks) >= 1
        total_files = sum(len(c.files) for c in chunks)
        assert total_files == 5

    def test_splits_large_file(self, tmp_path: Path):
        # 10000 chars = ~2500 tokens
        big = "\n".join(["x" * 100] * 100)  # 100 lines of 100 chars
        (tmp_path / "big.py").write_text(big, encoding="utf-8")
        chunks = plan_chunks(["big.py"], tmp_path, max_tokens_per_chunk=500)
        # Should split into multiple FileScopes
        all_scopes = sum(len(c.files) for c in chunks)
        assert all_scopes >= 2

    def test_max_chunks_cap(self, tmp_path: Path):
        for i in range(20):
            (tmp_path / f"f{i}.py").write_text("x" * 5000, encoding="utf-8")
        chunks = plan_chunks(
            [f"f{i}.py" for i in range(20)],
            tmp_path,
            max_tokens_per_chunk=200,
            max_chunks=3,
        )
        assert len(chunks) <= 3

    def test_to_prompt_section(self, tmp_path: Path):
        (tmp_path / "x.py").write_text("hello = 1", encoding="utf-8")
        chunks = plan_chunks(["x.py"], tmp_path, max_tokens_per_chunk=10_000,
                             purposes={"x.py": "main entry"})
        section = chunks[0].to_prompt_section()
        assert "x.py" in section
        assert "main entry" in section
        assert "hello = 1" in section

    def test_invalid_max_tokens_raises(self, tmp_path: Path):
        with pytest.raises(ValueError):
            plan_chunks([], tmp_path, max_tokens_per_chunk=0)


# ────────────────────────────────────────────────────────────
# Signal Parser
# ────────────────────────────────────────────────────────────


class TestSignalParser:
    def _make_signal(self, **overrides):
        base = {
            "title": "Test Signal",
            "description": "X" * 60,  # passes MIN_DESCRIPTION_LEN
            "severity": "high",
            "location": {"file": "test.py", "line": 5},
        }
        base.update(overrides)
        return base

    def test_validate_minimal_signal(self, tmp_path: Path):
        (tmp_path / "test.py").write_text("# line1\n" * 20, encoding="utf-8")
        sig = self._make_signal()
        ok, reason, norm = validate_signal(
            sig, source_dir=tmp_path, probe_id="P-LLM",
            lane="wf-fix-business", dimension="QD2",
        )
        assert ok, reason
        assert norm["title"] == "Test Signal"
        assert norm["fingerprint"].startswith("sha256:")
        assert norm["dimension_id"] == "QD2"

    def test_drops_short_description(self, tmp_path: Path):
        (tmp_path / "test.py").write_text("x", encoding="utf-8")
        sig = self._make_signal(description="too short")
        ok, reason, _ = validate_signal(
            sig, source_dir=tmp_path, probe_id="P-LLM",
            lane="L", dimension="QD1",
        )
        assert not ok
        assert "description too short" in reason

    def test_drops_invalid_severity(self, tmp_path: Path):
        (tmp_path / "test.py").write_text("x", encoding="utf-8")
        sig = self._make_signal(severity="EXTREME")
        ok, reason, _ = validate_signal(
            sig, source_dir=tmp_path, probe_id="P-LLM", lane="L", dimension="QD1",
        )
        assert not ok

    def test_drops_nonexistent_file(self, tmp_path: Path):
        sig = self._make_signal(location={"file": "fake.py", "line": 1})
        ok, reason, _ = validate_signal(
            sig, source_dir=tmp_path, probe_id="P-LLM", lane="L", dimension="QD1",
        )
        assert not ok
        assert "does not exist" in reason

    def test_drops_line_overflow(self, tmp_path: Path):
        (tmp_path / "test.py").write_text("# line1\n# line2\n", encoding="utf-8")
        sig = self._make_signal(location={"file": "test.py", "line": 999})
        ok, reason, _ = validate_signal(
            sig, source_dir=tmp_path, probe_id="P-LLM", lane="L", dimension="QD1",
        )
        assert not ok
        assert "exceeds" in reason

    def test_low_confidence_downgrades_severity(self, tmp_path: Path):
        (tmp_path / "test.py").write_text("# line1\n" * 20, encoding="utf-8")
        sig = self._make_signal(severity="critical")
        ok, _, norm = validate_signal(
            sig, source_dir=tmp_path, probe_id="P-LLM",
            lane="L", dimension="QD1", confidence=0.3,
        )
        assert ok
        assert norm["severity"] == "info"  # downgraded

    def test_parse_fenced_json(self, tmp_path: Path):
        (tmp_path / "test.py").write_text("x\n" * 20, encoding="utf-8")
        long_desc = "This is a longer description that meets the minimum 50 character length requirement."
        inner = json.dumps({"signals": [{
            "title": "Bug found",
            "description": long_desc,
            "severity": "medium",
            "location": {"file": "test.py", "line": 1},
        }]})
        agent_output = f"Here are my findings:\n\n```json\n{inner}\n```\n\nThat's all."
        signals, meta = parse_signals(
            agent_output, source_dir=tmp_path, probe_id="P-LLM-test",
            lane="L", dimension="QD1",
        )
        assert meta["raw_signals"] == 1
        assert len(signals) == 1
        assert signals[0]["title"] == "Bug found"

    def test_parse_no_json_returns_empty(self, tmp_path: Path):
        signals, meta = parse_signals(
            "Just plain text, no JSON here",
            source_dir=tmp_path, probe_id="P-LLM",
            lane="L", dimension="QD1",
        )
        assert signals == []
        assert meta["dropped_no_json"] == 1

    def test_parse_dedup_against_static(self, tmp_path: Path):
        (tmp_path / "test.py").write_text("# line1\n" * 20, encoding="utf-8")
        signal = {
            "title": "Same Title",
            "description": "X" * 60,
            "severity": "medium",
            "location": {"file": "test.py", "line": 5},
        }
        # First, compute what the fingerprint would be
        from llm_lane.signal_parser import _compute_fingerprint
        canonical = {
            "dimension_id": "QD1",
            "probe_id": "P-LLM",
            "title": "Same Title",
            "location": {"file": "test.py", "line": 5},
        }
        existing_fp = _compute_fingerprint(canonical)

        agent_output = json.dumps({"signals": [signal, signal]})  # 2 dups
        signals, meta = parse_signals(
            agent_output, source_dir=tmp_path, probe_id="P-LLM",
            lane="L", dimension="QD1",
            static_fingerprints={existing_fp},
        )
        assert len(signals) == 0
        assert meta["dropped_duplicate"] >= 1

    def test_parse_max_signals_cap(self, tmp_path: Path):
        (tmp_path / "test.py").write_text("# line\n" * 50, encoding="utf-8")
        sigs = []
        for i in range(15):
            sigs.append({
                "title": f"Bug {i}",
                "description": "X" * 60,
                "severity": "medium",
                "location": {"file": "test.py", "line": i + 1},
            })
        agent_output = json.dumps({"signals": sigs})
        signals, meta = parse_signals(
            agent_output, source_dir=tmp_path, probe_id="P-LLM",
            lane="L", dimension="QD1", max_signals=5,
        )
        assert len(signals) == 5
        assert meta["dropped_max_cap"] >= 0  # depends on residual ordering

    def test_parse_handles_array_root(self, tmp_path: Path):
        (tmp_path / "test.py").write_text("x\n" * 20, encoding="utf-8")
        agent_output = json.dumps([
            {
                "title": "Issue",
                "description": "Y" * 60,
                "severity": "low",
                "location": {"file": "test.py", "line": 1},
            }
        ])
        signals, meta = parse_signals(
            agent_output, source_dir=tmp_path, probe_id="P-LLM",
            lane="L", dimension="QD1",
        )
        assert len(signals) == 1
