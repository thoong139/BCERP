"""test_cdg_handler.py — Unit tests cho cdg module."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from cdg.cdg_handler import (
    append_token,
    check_anti_loop,
    create_cdg_token,
    load_cdg_tokens,
)


class TestCreateCdgToken:
    """Test create_cdg_token."""

    def test_basic_creation(self):
        """Tạo token cơ bản."""
        token = create_cdg_token(
            "cdg-workload-override-001",
            "Workload 120 phút vượt threshold 60 phút",
            Path("/tmp/session"),
        )
        assert token["cdg_id"] == "cdg-workload-override-001"
        assert token["decision"] == "pending"
        assert token["context"] != ""
        assert "created_at" in token

    def test_with_cdg_point(self):
        """Token có CDG point."""
        token = create_cdg_token(
            "cdg-001",
            "Context",
            Path("/tmp"),
            cdg_point="CDG-1",
        )
        assert token["cdg_point"] == "CDG-1"

    def test_invalid_decision_raises(self):
        """Decision không hợp lệ → ValueError."""
        with pytest.raises(ValueError, match="không hợp lệ"):
            create_cdg_token("cdg-001", "ctx", Path("/tmp"), decision="maybe")

    def test_accept_decision(self):
        """Accept decision hợp lệ."""
        token = create_cdg_token(
            "cdg-001", "ctx", Path("/tmp"), decision="accept"
        )
        assert token["decision"] == "accept"


class TestLoadCdgTokens:
    """Test load_cdg_tokens."""

    def test_nonexistent_returns_empty(self, tmp_path):
        """File không tồn tại → empty list."""
        tokens = load_cdg_tokens(tmp_path)
        assert tokens == []

    def test_load_existing(self, tmp_path):
        """Load tokens từ file."""
        tokens_file = tmp_path / "cdg-tokens.json"
        tokens_file.write_text(
            json.dumps({
                "$schema": "cdg-tokens-v1",
                "tokens": [{"cdg_id": "cdg-001", "decision": "accept"}],
            }),
            encoding="utf-8",
        )
        tokens = load_cdg_tokens(tmp_path)
        assert len(tokens) == 1
        assert tokens[0]["cdg_id"] == "cdg-001"

    def test_invalid_json_returns_empty(self, tmp_path):
        """JSON lỗi → empty list."""
        tokens_file = tmp_path / "cdg-tokens.json"
        tokens_file.write_text("not json", encoding="utf-8")
        tokens = load_cdg_tokens(tmp_path)
        assert tokens == []


class TestAntiLoop:
    """Test check_anti_loop."""

    def test_no_rejects_returns_ask(self):
        """Không có reject → ask."""
        tokens = [
            {"cdg_id": "cdg-workload-override-001", "decision": "accept"},
        ]
        result = check_anti_loop("cdg-workload-override-002", tokens)
        assert result == "ask"

    def test_one_reject_returns_ask(self):
        """1 reject (< max) → ask."""
        tokens = [
            {"cdg_id": "cdg-workload-override-001", "decision": "reject"},
        ]
        result = check_anti_loop("cdg-workload-override-002", tokens, max_rejects=2)
        assert result == "ask"

    def test_max_rejects_returns_escalate(self):
        """>= max_rejects → escalate."""
        tokens = [
            {"cdg_id": "cdg-workload-override-001", "decision": "reject"},
            {"cdg_id": "cdg-workload-override-002", "decision": "reject"},
        ]
        result = check_anti_loop("cdg-workload-override-003", tokens, max_rejects=2)
        assert result == "escalate"

    def test_different_cdg_prefix_not_counted(self):
        """CDG khác prefix không tính vào anti-loop."""
        tokens = [
            {"cdg_id": "cdg-workload-override-001", "decision": "reject"},
            {"cdg_id": "cdg-safety-floor-001", "decision": "reject"},
        ]
        result = check_anti_loop("cdg-workload-override-002", tokens, max_rejects=2)
        assert result == "ask"  # chỉ 1 reject cùng prefix


class TestAppendToken:
    """Test append_token (atomic write)."""

    def test_creates_file(self, tmp_path):
        """Append tạo file nếu chưa có."""
        token = create_cdg_token("cdg-001", "Test context", tmp_path)
        path = append_token(token, tmp_path)
        assert path.exists()
        tokens = load_cdg_tokens(tmp_path)
        assert len(tokens) == 1

    def test_appends_to_existing(self, tmp_path):
        """Append thêm vào file đã có."""
        token1 = create_cdg_token("cdg-001", "First", tmp_path)
        append_token(token1, tmp_path)

        token2 = create_cdg_token("cdg-002", "Second", tmp_path)
        append_token(token2, tmp_path)

        tokens = load_cdg_tokens(tmp_path)
        assert len(tokens) == 2
