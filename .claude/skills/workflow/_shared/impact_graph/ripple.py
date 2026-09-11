#!/usr/bin/env python3
"""ripple.py — Verify Ripple consumer (ADR-22 rule 2).

Vai trò:
    Consumer cho ``/wf-fix-execute`` Phase 5. Với mỗi issue sau khi đã fix,
    đọc ``$SESSION_DIR/impact-graph.json`` (sinh bởi ``builder``) và enumerate
    các file **phụ thuộc ngược** (upstream dependents — file IMPORT file vừa
    sửa). Các file này cần re-verify để đảm bảo fix không làm vỡ consumer.

Quy tắc ADR-22 rule 2:
    - ``depth <= 1`` (1 hop — chỉ direct dependents, không chuyển tiếp)
    - ``strength >= 0.5`` (bỏ cạnh yếu/noise import)

Registry role: NONE. Không ghi vào ``req-registry.json``.

Tham chiếu:
    - ADR-18 Impact Graph
    - ADR-22 rule 2 Verify Ripple
    - 00-core.md §4b Cross-Skill Output Path Contract
      (``$SESSION_DIR/impact-graph.json`` — Producer: wf-fix-discover Layer 0;
      Consumer: wf-fix-execute Phase 5)

Public API:
    - ``verify_ripple(issue, impact_graph_path, depth, strength_threshold)``
    - ``RippleTarget`` (dataclass)
    - ``DEFAULT_DEPTH``, ``DEFAULT_STRENGTH``
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict, deque
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Iterable

# ──────────────────────────────────────────────────────────────────────
# Constants — ADR-22 rule 2 defaults (KHÔNG đổi ngầm; override qua param)
# ──────────────────────────────────────────────────────────────────────

DEFAULT_DEPTH: int = 1
DEFAULT_STRENGTH: float = 0.5

# Schema id được builder phát hành — consumer kiểm tra để tránh đọc nhầm file
_EXPECTED_SCHEMA: str = "impact-graph.v1"


# ──────────────────────────────────────────────────────────────────────
# Data class
# ──────────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class RippleTarget:
    """Một file cần re-verify sau khi fix issue tại ``origin``.

    Attributes:
        file_path: Relative POSIX path từ project root (khớp node.id trong graph).
        reason: "direct-dependent" | "transitive-dependent" (khi depth>1).
        edge_strength: Strength của cạnh IMPORT nối với origin (hop 1).
        distance: Số hop từ origin (1 = direct).
        origin: File đã fix — gốc của ripple.
    """

    file_path: str
    reason: str
    edge_strength: float
    distance: int
    origin: str


# ──────────────────────────────────────────────────────────────────────
# Internal helpers
# ──────────────────────────────────────────────────────────────────────


def _load_graph(graph_path: Path) -> dict[str, Any]:
    """Đọc + parse impact-graph.json, validate schema header."""
    if not graph_path.is_file():
        raise FileNotFoundError(f"impact-graph.json not found: {graph_path}")
    with graph_path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    schema = data.get("$schema") or data.get("schema")
    if schema != _EXPECTED_SCHEMA:
        raise ValueError(
            f"Incompatible impact-graph schema: got={schema!r}, "
            f"expected={_EXPECTED_SCHEMA!r}"
        )
    if "edges" not in data or "nodes" not in data:
        raise ValueError("impact-graph.json missing required keys: nodes, edges")
    return data


def _build_reverse_index(edges: Iterable[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    """Index edges theo ``target`` → danh sách edges (để enumerate dependents).

    Ripple là "ai phụ thuộc vào tôi?" — tra theo target, lấy source.
    """
    idx: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for e in edges:
        target = e.get("target")
        if not target:
            continue
        idx[target].append(e)
    return idx


def _resolve_issue_file(issue: dict[str, Any]) -> str | None:
    """Trích xuất file path từ issue object (Signal v2 / Issue v2 compatible).

    Ưu tiên các field phổ biến: ``file_path``, ``target.file_path``,
    ``evidence[0].file_path``. Trả về POSIX relative path hoặc None nếu không có.
    """
    if not isinstance(issue, dict):
        return None
    fp = issue.get("file_path")
    if not fp:
        target = issue.get("target") or {}
        if isinstance(target, dict):
            fp = target.get("file_path")
    if not fp:
        ev_list = issue.get("evidence") or []
        if isinstance(ev_list, list) and ev_list:
            first = ev_list[0]
            if isinstance(first, dict):
                fp = first.get("file_path")
    if not fp:
        return None
    # Normalize về POSIX (tránh mismatch Windows path)
    return str(fp).replace(os.sep, "/").lstrip("./")


# ──────────────────────────────────────────────────────────────────────
# Public API — verify_ripple
# ──────────────────────────────────────────────────────────────────────


def verify_ripple(
    issue: dict[str, Any],
    impact_graph_path: str | Path,
    depth: int = DEFAULT_DEPTH,
    strength_threshold: float = DEFAULT_STRENGTH,
) -> list[RippleTarget]:
    """Tính danh sách file cần re-verify sau khi fix ``issue``.

    Thuật toán (ADR-22 rule 2):
        1. Xác định ``origin = issue.file_path``.
        2. Enumerate các edges có ``target == origin``, strength >= threshold.
        3. Mỗi ``edge.source`` là 1 dependent → thêm vào danh sách.
        4. Nếu depth > 1: BFS tiếp tục từ các dependents (hop 2, 3, ...).

    Args:
        issue: dict Issue v2 (hoặc Signal v2) với tối thiểu 1 trong các field
            ``file_path``, ``target.file_path``, ``evidence[].file_path``.
        impact_graph_path: path tới ``$SESSION_DIR/impact-graph.json``.
        depth: số hop tối đa (mặc định 1 per ADR-22; cho phép override khi debug).
        strength_threshold: edge strength tối thiểu để tính ripple
            (mặc định 0.5 per ADR-22).

    Returns:
        List ``RippleTarget`` đã dedup theo ``file_path``, giữ khoảng cách
        và strength nhỏ nhất (nghiêm ngặt nhất) cho mỗi dependent.

    Raises:
        ValueError: khi issue không có file_path xác định được hoặc graph
            schema không khớp.
        FileNotFoundError: khi ``impact_graph_path`` không tồn tại.
    """
    if depth < 1:
        raise ValueError(f"depth must be >= 1, got {depth}")
    if not 0.0 <= strength_threshold <= 1.0:
        raise ValueError(
            f"strength_threshold must be in [0.0, 1.0], got {strength_threshold}"
        )

    origin = _resolve_issue_file(issue)
    if not origin:
        raise ValueError(
            "Cannot resolve file_path from issue — require one of: "
            "file_path | target.file_path | evidence[0].file_path"
        )

    graph = _load_graph(Path(impact_graph_path))
    reverse_idx = _build_reverse_index(graph.get("edges", []))

    # BFS upstream (dependents-of-origin)
    visited: dict[str, RippleTarget] = {}
    queue: deque[tuple[str, int]] = deque()
    queue.append((origin, 0))

    while queue:
        current, dist = queue.popleft()
        if dist >= depth:
            continue
        for edge in reverse_idx.get(current, []):
            src = edge.get("source")
            if not src or src == origin:
                continue
            strength = float(edge.get("strength", 0.0))
            if strength < strength_threshold:
                continue
            new_dist = dist + 1
            existing = visited.get(src)
            # Giữ bản ghi với distance nhỏ nhất (direct ưu tiên transitive)
            if existing is not None and existing.distance <= new_dist:
                continue
            reason = "direct-dependent" if new_dist == 1 else "transitive-dependent"
            target = RippleTarget(
                file_path=src,
                reason=reason,
                edge_strength=round(strength, 2),
                distance=new_dist,
                origin=origin,
            )
            visited[src] = target
            if new_dist < depth:
                queue.append((src, new_dist))

    # Sort deterministic cho output ổn định (reproducible verify runs)
    return sorted(
        visited.values(),
        key=lambda t: (t.distance, -t.edge_strength, t.file_path),
    )


# ──────────────────────────────────────────────────────────────────────
# CLI — hỗ trợ wf-fix-execute gọi trực tiếp
# ──────────────────────────────────────────────────────────────────────


def _cmd_verify(args: argparse.Namespace) -> int:
    """Subcommand ``verify``: đọc 1 issue từ JSON file, in ripple targets."""
    issue_path = Path(args.issue)
    if not issue_path.is_file():
        print(f"[ripple ERROR] issue file not found: {issue_path}", file=sys.stderr)
        return 2
    with issue_path.open("r", encoding="utf-8") as fh:
        issue = json.load(fh)

    try:
        targets = verify_ripple(
            issue=issue,
            impact_graph_path=args.graph,
            depth=args.depth,
            strength_threshold=args.strength,
        )
    except (ValueError, FileNotFoundError) as exc:
        print(f"[ripple ERROR] {exc}", file=sys.stderr)
        return 1

    payload = {
        "origin": _resolve_issue_file(issue),
        "depth": args.depth,
        "strength_threshold": args.strength,
        "target_count": len(targets),
        "targets": [asdict(t) for t in targets],
    }
    json.dump(payload, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Verify Ripple consumer (ADR-22 rule 2) — enumerate downstream "
        "dependents cần re-verify sau fix."
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_verify = sub.add_parser("verify", help="Tính ripple targets cho 1 issue")
    p_verify.add_argument(
        "--issue",
        type=str,
        required=True,
        help="Path tới JSON file chứa issue (Issue v2 shape).",
    )
    p_verify.add_argument(
        "--graph",
        type=str,
        required=True,
        help="Path tới $SESSION_DIR/impact-graph.json",
    )
    p_verify.add_argument(
        "--depth",
        type=int,
        default=DEFAULT_DEPTH,
        help=f"Số hop tối đa (default={DEFAULT_DEPTH} per ADR-22 rule 2).",
    )
    p_verify.add_argument(
        "--strength",
        type=float,
        default=DEFAULT_STRENGTH,
        help=f"Edge strength tối thiểu (default={DEFAULT_STRENGTH} per ADR-22 rule 2).",
    )
    p_verify.set_defaults(func=_cmd_verify)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
