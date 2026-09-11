#!/usr/bin/env python3
"""cdg_handler.py — CDG token management cho linear skills.

Vai trò:
    Quản lý Critical Decision Gate tokens — ghi nhận user decisions
    cho các hành động không thể undo (CORE-027). Bao gồm anti-loop
    guard để tránh lặp vô hạn khi user reject liên tục.

    7 CDG points (CORE-027 / protocols/16-critical-decision-gate.md §16.1):
    - CDG-1: Workload override (block zone)
    - CDG-2: Profile downgrade cho production
    - CDG-3: Skip phase trong workflow
    - CDG-4: DEPRECATE module
    - CDG-5: Override safety floor
    - CDG-6: Registry write outside owned fields
    - CDG-7: Force-complete impl_status

Registry role: NONE.

Tham chiếu:
    - ADR-OPT-08: CDG handoff tokens
    - CORE-027: Critical Decision Gate
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

CDG_TOKENS_FILE = "cdg-tokens.json"
MAX_REJECTS_DEFAULT = 2

VALID_DECISIONS = frozenset({"accept", "reject"})


# ──────────────────────────────────────────────────────────────────────
# Core functions
# ──────────────────────────────────────────────────────────────────────


def create_cdg_token(
    cdg_id: str,
    context: str,
    session_dir: Path,
    decision: str = "pending",
    cdg_point: str = "",
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Tạo CDG token cho 1 decision.

    Args:
        cdg_id: Định danh CDG (vd: "cdg-workload-override-001").
        context: Mô tả context cho user.
        session_dir: Session directory chứa cdg-tokens.json.
        decision: "pending" | "accept" | "reject".
        cdg_point: CDG point ID (CDG-1 đến CDG-7).
        metadata: Metadata tùy chọn.

    Returns:
        CDG token dict.
    """
    if decision not in VALID_DECISIONS and decision != "pending":
        raise ValueError(
            f"create_cdg_token: decision='{decision}' không hợp lệ "
            f"(cho phép: pending, accept, reject)"
        )

    token = {
        "cdg_id": cdg_id,
        "cdg_point": cdg_point,
        "context": context,
        "decision": decision,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "resolved_at": None,
        "metadata": metadata or {},
    }

    return token


def load_cdg_tokens(session_dir: Path) -> list[dict[str, Any]]:
    """Đọc CDG tokens từ session.

    Args:
        session_dir: Session directory.

    Returns:
        Danh sách tokens, hoặc [] nếu file không tồn tại.
    """
    tokens_path = session_dir / CDG_TOKENS_FILE
    if not tokens_path.exists():
        return []

    try:
        data = json.loads(tokens_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return []

    if isinstance(data, dict) and "tokens" in data:
        return data["tokens"]
    if isinstance(data, list):
        return data
    return []


def check_anti_loop(
    cdg_id: str,
    tokens: list[dict[str, Any]],
    max_rejects: int = MAX_REJECTS_DEFAULT,
) -> str:
    """Kiểm tra anti-loop guard cho CDG.

    Args:
        cdg_id: CDG ID đang check.
        tokens: Danh sách existing tokens.
        max_rejects: Số reject tối đa trước khi escalate.

    Returns:
        "ask" — còn room để hỏi user.
        "escalate" — đã reject quá nhiều lần, cần escalate.

    Logic:
        Đếm số reject tokens cho cùng cdg_id prefix.
        Nếu >= max_rejects → escalate.
    """
    # Tìm prefix của cdg_id (ví dụ: "cdg-workload-override" từ "cdg-workload-override-001")
    parts = cdg_id.rsplit("-", 1)
    prefix = parts[0] if len(parts) > 1 else cdg_id

    reject_count = 0
    for token in tokens:
        if not isinstance(token, dict):
            continue
        token_id = token.get("cdg_id", "")
        token_prefix = token_id.rsplit("-", 1)[0] if "-" in token_id else token_id
        if token_prefix == prefix and token.get("decision") == "reject":
            reject_count += 1

    if reject_count >= max_rejects:
        return "escalate"

    return "ask"


def append_token(
    token: dict[str, Any],
    session_dir: Path,
) -> Path:
    """Ghi thêm token vào cdg-tokens.json (atomic append).

    Args:
        token: CDG token dict.
        session_dir: Session directory.

    Returns:
        Path đến cdg-tokens.json.

    Raises:
        OSError: không ghi được file.
    """
    tokens_path = session_dir / CDG_TOKENS_FILE
    session_dir.mkdir(parents=True, exist_ok=True)

    # Load existing
    existing = load_cdg_tokens(session_dir)

    # Append
    existing.append(token)

    # Atomic write
    data = {
        "$schema": "cdg-tokens-v1",
        "tokens": existing,
    }

    tmp_fd, tmp_name = tempfile.mkstemp(
        prefix=f".{CDG_TOKENS_FILE}.",
        suffix=".tmp",
        dir=str(session_dir),
    )
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as fh:
            # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
            json.dump(data, fh, indent=2, ensure_ascii=False, sort_keys=True)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_name, tokens_path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise

    return tokens_path


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: CDG token management."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="CDG token handler")
    sub = parser.add_subparsers(dest="command")

    check_cmd = sub.add_parser("check", help="Check anti-loop guard")
    check_cmd.add_argument("--cdg-id", required=True)
    check_cmd.add_argument("--session-dir", required=True, type=Path)
    check_cmd.add_argument("--max-rejects", type=int, default=MAX_REJECTS_DEFAULT)

    args = parser.parse_args(argv)

    try:
        if args.command == "check":
            tokens = load_cdg_tokens(args.session_dir)
            result = check_anti_loop(args.cdg_id, tokens, args.max_rejects)
            print(result)
            return 0

        parser.print_help()
        return 1

    except Exception as exc:
        print(f"[cdg_handler ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
