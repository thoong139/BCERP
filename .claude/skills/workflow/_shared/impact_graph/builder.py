#!/usr/bin/env python3
"""builder.py — Probe P0.XREF cho Impact Graph (ADR-18).

Vai trò:
    Quét source code trong scope + sinh đồ thị phụ thuộc giữa các file. Output
    là ``$SESSION_DIR/impact-graph.json`` được tiêu thụ bởi ``ripple.verify_ripple``
    ở Phase 5 của ``/wf-fix-execute`` (ADR-22 rule 2: Verify Ripple depth=1,
    strength >= 0.5).

Ngôn ngữ hỗ trợ (detect theo phần mở rộng):
    - ``ts``, ``tsx``, ``js``, ``jsx`` — parse ``import ... from '...'``,
      ``require('...')``, ``import('...')``
    - ``py`` — parse ``from x.y import z``, ``import x``
    - ``java``, ``cs``, ``go``, ``rs`` — detect bằng regex nhẹ (best-effort, không
      resolve classpath); chỉ dùng tên module để match theo file name.

Edge strength heuristic:
    - base = 0.5 cho mỗi import quan hệ (ngang hàng)
    - + 0.2 nếu là ``import * from`` hoặc wildcard
    - + 0.2 nếu target file được import ở top-of-file (eager)
    - cap ở 1.0, floor 0.1

Edge type:
    - ``import`` — module/file import trực tiếp
    - ``call`` — dùng symbol qua import (heuristic: symbol xuất hiện trong code)
    - ``data`` — dùng interface/type (heuristic trên TS)
    Trong B3 minimal build chỉ emit ``import`` (conservative).

Registry role: NONE. Không ghi vào ``req-registry.json``.

Tham chiếu:
    - ADR-18 (Impact Graph)
    - ADR-22 rule 2 (Verify Ripple)
    - 00-core.md §4b Cross-Skill Output Path Contract:
      ``$SESSION_DIR/impact-graph.json``
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCHEMA_ID: str = "impact-graph.v1"
SUPPORTED_LANGS: tuple[str, ...] = (
    "ts",
    "tsx",
    "js",
    "jsx",
    "py",
    "java",
    "cs",
    "go",
    "rs",
)

# Extension → "language bucket" cho heuristic
_EXT_LANG: dict[str, str] = {
    ".ts": "ts",
    ".tsx": "tsx",
    ".js": "js",
    ".jsx": "jsx",
    ".py": "py",
    ".java": "java",
    ".cs": "cs",
    ".go": "go",
    ".rs": "rs",
}

# Thư mục bỏ qua khi enumerate source
_SKIP_DIRS: frozenset[str] = frozenset(
    {
        "node_modules",
        ".git",
        ".venv",
        "venv",
        "env",
        "__pycache__",
        "dist",
        "build",
        ".next",
        ".nuxt",
        "out",
        "target",
        "bin",
        "obj",
        ".mc-data",
        ".cache",
        "coverage",
        ".pytest_cache",
        ".mypy_cache",
    }
)

# Giới hạn phòng thủ — tránh quét cả monorepo khổng lồ vô thời hạn.
MAX_FILES_DEFAULT: int = 5000
MAX_FILE_BYTES_DEFAULT: int = 1024 * 1024  # 1 MiB/file — bỏ qua file lớn hơn


# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class Node:
    """Một file source trong graph."""

    id: str  # relative path từ project root (POSIX style)
    lang: str
    loc: int  # ước lượng số dòng (để rank)


@dataclass(frozen=True)
class Edge:
    """Cạnh import giữa 2 file."""

    source: str  # node.id import target
    target: str  # node.id bị import
    edge_type: str  # "import" | "call" | "data"
    strength: float  # [0.0, 1.0]
    evidence_line: int  # line number trong source (1-based); 0 nếu không xác định


@dataclass
class Graph:
    """Impact Graph — collection of nodes + edges."""

    schema: str = SCHEMA_ID
    built_at: str = ""
    scope: dict[str, Any] = field(default_factory=dict)
    nodes: list[Node] = field(default_factory=list)
    edges: list[Edge] = field(default_factory=list)
    stats: dict[str, Any] = field(default_factory=dict)


# ──────────────────────────────────────────────────────────────────────
# Regex — import detection per language
# ──────────────────────────────────────────────────────────────────────

# TS/JS: import x from 'y';  import * as n from 'y';  import('y');  require('y')
_RX_JS_IMPORT = re.compile(
    r"""
    ^\s*                                      # đầu dòng
    (?:
       import\s+ (?: \*\s+as\s+\w+ | [^'"\n]+ ) \s+ from \s+ ['"]([^'"\n]+)['"]
     | import\s+ ['"]([^'"\n]+)['"]
     | (?: const | let | var )\s+ [^=;\n]+? = \s*
           require \s* \( \s* ['"]([^'"\n]+)['"] \s* \)
     | import\s*\(\s* ['"]([^'"\n]+)['"] \s*\)
    )
    """,
    re.MULTILINE | re.VERBOSE,
)

# Python: import x.y | from x.y import z | from . import ...
# Group 1: from module (e.g., "pkg")
# Group 2: from symbols list raw (e.g., "c" | "a, b, c" | "c as cc" | "*")
# Group 3: plain import list (e.g., "os, sys")
_RX_PY_IMPORT = re.compile(
    r"""
    ^[ \t]*
    (?:
       from \s+ ([\w\.]+) \s+ import \s+ ([\w\*\,\s\(\)]+?) (?=\n|\#|$)
     | import \s+ ([\w\.]+(?:\s*,\s*[\w\.]+)*)
    )
    """,
    re.MULTILINE | re.VERBOSE,
)

# Java / C# / Go / Rust — minimal heuristic (chỉ capture module path)
_RX_JAVA_IMPORT = re.compile(r"^\s*import\s+(?:static\s+)?([\w\.]+)\s*;", re.MULTILINE)
_RX_CS_USING = re.compile(r"^\s*using\s+(?:static\s+)?([\w\.]+)\s*;", re.MULTILINE)
_RX_GO_IMPORT = re.compile(r"""^\s*(?:import)?\s*(?:\(|\s)\s*['"]([^'"\n]+)['"]""", re.MULTILINE)
_RX_RS_USE = re.compile(r"^\s*use\s+([\w:]+)\s*(?:as\s+\w+)?\s*;", re.MULTILINE)


# ──────────────────────────────────────────────────────────────────────
# Enumerate source files
# ──────────────────────────────────────────────────────────────────────


def _iter_source_files(
    root: Path,
    max_files: int,
    max_file_bytes: int,
) -> list[Path]:
    """Walk ``root``, trả về danh sách file trong ``SUPPORTED_LANGS`` ≤ max_files."""
    result: list[Path] = []
    root = root.resolve()
    for dirpath, dirnames, filenames in os.walk(root):
        # In-place prune SKIP_DIRS
        dirnames[:] = [d for d in dirnames if d not in _SKIP_DIRS]
        for fname in filenames:
            if len(result) >= max_files:
                return result
            p = Path(dirpath) / fname
            ext = p.suffix.lower()
            if ext not in _EXT_LANG:
                continue
            try:
                if p.stat().st_size > max_file_bytes:
                    continue
            except OSError:
                continue
            result.append(p)
    return result


def _loc_estimate(content: str) -> int:
    """Ước lượng LOC — đếm dòng non-empty."""
    if not content:
        return 0
    return sum(1 for ln in content.splitlines() if ln.strip())


# ──────────────────────────────────────────────────────────────────────
# Resolve import spec → file path within repo
# ──────────────────────────────────────────────────────────────────────


def _resolve_relative(
    source_path: Path,
    raw_import: str,
    repo_root: Path,
) -> Path | None:
    """Resolve import spec tương đối (./x, ../y). Trả về Path đã resolve hoặc None."""
    if not raw_import.startswith((".", "/")):
        return None
    base = source_path.parent
    # Chấp nhận import không có ext: thử thêm các ext JS/TS phổ biến.
    candidates: list[Path] = []
    raw_path = (base / raw_import).resolve()
    candidates.append(raw_path)
    for ext in (".ts", ".tsx", ".js", ".jsx"):
        candidates.append(raw_path.with_suffix(ext))
    for ext in (".ts", ".tsx", ".js", ".jsx"):
        candidates.append(raw_path / f"index{ext}")
    for c in candidates:
        try:
            if c.is_file() and c.resolve().is_relative_to(repo_root):
                return c.resolve()
        except (OSError, ValueError):
            continue
    return None


def _resolve_py_module(
    raw_module: str,
    repo_root: Path,
) -> Path | None:
    """Resolve Python module ``a.b.c`` thành ``repo_root/a/b/c.py`` hoặc ``.../__init__.py``."""
    if not raw_module:
        return None
    # Bỏ qua stdlib chuyên dùng để tránh false positive
    top = raw_module.split(".", 1)[0]
    if top in _PY_STDLIB_HINT:
        return None
    rel = raw_module.replace(".", os.sep)
    for suffix in (".py", os.sep + "__init__.py"):
        cand = (repo_root / (rel + suffix)).resolve()
        try:
            if cand.is_file() and cand.is_relative_to(repo_root):
                return cand
        except (OSError, ValueError):
            continue
    return None


# Tập nhỏ các top-level modules thường-là-stdlib — best-effort prune.
_PY_STDLIB_HINT: frozenset[str] = frozenset(
    {
        "os",
        "sys",
        "json",
        "re",
        "io",
        "pathlib",
        "typing",
        "datetime",
        "argparse",
        "subprocess",
        "itertools",
        "functools",
        "collections",
        "dataclasses",
        "hashlib",
        "tempfile",
        "logging",
        "time",
        "math",
        "abc",
        "enum",
        "asyncio",
    }
)


# ──────────────────────────────────────────────────────────────────────
# Strength heuristic
# ──────────────────────────────────────────────────────────────────────


def _compute_strength(raw_import: str, line_no: int, total_lines: int) -> float:
    """Tính strength ∈ [0.1, 1.0] — heuristic nhẹ."""
    base = 0.5
    if "*" in raw_import:
        base += 0.2
    # Eager-top-of-file (line_no <= 5% total) → +0.2
    if total_lines > 0 and line_no <= max(3, int(total_lines * 0.05)):
        base += 0.2
    if base > 1.0:
        base = 1.0
    if base < 0.1:
        base = 0.1
    # Round tránh float noise trong JSON
    return round(base, 2)


# ──────────────────────────────────────────────────────────────────────
# Core: parse 1 file → edges
# ──────────────────────────────────────────────────────────────────────


def _parse_js_like(
    source_path: Path,
    content: str,
    repo_root: Path,
) -> list[Edge]:
    edges: list[Edge] = []
    total_lines = content.count("\n") + 1
    for m in _RX_JS_IMPORT.finditer(content):
        raw = next((g for g in m.groups() if g), None)
        if not raw:
            continue
        target = _resolve_relative(source_path, raw, repo_root)
        if target is None:
            continue
        line_no = content.count("\n", 0, m.start()) + 1
        strength = _compute_strength(raw, line_no, total_lines)
        edges.append(
            Edge(
                source=_rel_id(source_path, repo_root),
                target=_rel_id(target, repo_root),
                edge_type="import",
                strength=strength,
                evidence_line=line_no,
            )
        )
    return edges


def _parse_py(
    source_path: Path,
    content: str,
    repo_root: Path,
) -> list[Edge]:
    edges: list[Edge] = []
    total_lines = content.count("\n") + 1
    source_id = _rel_id(source_path, repo_root)

    for m in _RX_PY_IMPORT.finditer(content):
        raw_from = m.group(1)
        raw_from_syms = m.group(2)
        raw_import = m.group(3)
        line_no = content.count("\n", 0, m.start()) + 1

        # Case 1: `from X import a, b as bb, *`
        if raw_from:
            resolved_any = False
            if raw_from_syms:
                # Tách symbol list: bỏ paren, "as X" aliases, wildcard
                cleaned = raw_from_syms.replace("(", " ").replace(")", " ")
                for tok in cleaned.split(","):
                    sym = tok.strip().split()[0] if tok.strip() else ""
                    if not sym or sym == "*":
                        continue
                    # Thử resolve X.sym như submodule trước
                    candidate = f"{raw_from}.{sym}"
                    target = _resolve_py_module(candidate, repo_root)
                    if target is not None:
                        strength = _compute_strength(candidate, line_no, total_lines)
                        edges.append(
                            Edge(
                                source=source_id,
                                target=_rel_id(target, repo_root),
                                edge_type="import",
                                strength=strength,
                                evidence_line=line_no,
                            )
                        )
                        resolved_any = True
            # Fall back: resolve X tự thân (package __init__.py hoặc X.py)
            # Cũng emit khi symbols đã resolve (vì package __init__ vẫn bị import)
            target_pkg = _resolve_py_module(raw_from, repo_root)
            if target_pkg is not None:
                pkg_id = _rel_id(target_pkg, repo_root)
                # Tránh dup nếu đã có edge tới pkg (trường hợp X là module không phải package)
                if not any(
                    e.target == pkg_id and e.evidence_line == line_no for e in edges
                ):
                    # Wildcard "*" → tăng strength
                    spec = raw_from_syms or raw_from
                    strength = _compute_strength(spec, line_no, total_lines)
                    edges.append(
                        Edge(
                            source=source_id,
                            target=pkg_id,
                            edge_type="import",
                            strength=strength,
                            evidence_line=line_no,
                        )
                    )
                    resolved_any = True
            _ = resolved_any  # silence unused warning — dùng cho future debug

        # Case 2: `import X, Y.Z`
        if raw_import:
            for mod in [s.strip() for s in raw_import.split(",") if s.strip()]:
                target = _resolve_py_module(mod, repo_root)
                if target is None:
                    continue
                strength = _compute_strength(mod, line_no, total_lines)
                edges.append(
                    Edge(
                        source=source_id,
                        target=_rel_id(target, repo_root),
                        edge_type="import",
                        strength=strength,
                        evidence_line=line_no,
                    )
                )
    return edges


def _parse_generic(
    source_path: Path,
    content: str,
    repo_root: Path,
    regex: re.Pattern[str],
) -> list[Edge]:
    """Java/C#/Go/Rust — best-effort: chỉ emit nếu target resolve được qua name match."""
    edges: list[Edge] = []
    total_lines = content.count("\n") + 1
    source_id = _rel_id(source_path, repo_root)
    for m in regex.finditer(content):
        raw = m.group(1)
        if not raw:
            continue
        # Match theo file stem (last segment) để tránh quét full classpath
        segments = re.split(r"[\./:]", raw)
        stem = segments[-1] if segments else raw
        if not stem or len(stem) < 2:
            continue
        # Tìm file có stem khớp trong cùng repo
        target = _find_by_stem(repo_root, stem, source_path.suffix)
        if target is None:
            continue
        line_no = content.count("\n", 0, m.start()) + 1
        strength = _compute_strength(raw, line_no, total_lines)
        edges.append(
            Edge(
                source=source_id,
                target=_rel_id(target, repo_root),
                edge_type="import",
                strength=strength,
                evidence_line=line_no,
            )
        )
    return edges


_STEM_INDEX_CACHE: dict[Path, dict[str, Path]] = {}


def _find_by_stem(repo_root: Path, stem: str, ext_hint: str) -> Path | None:
    """Tìm file trong repo có basename == stem + phần mở rộng tương tự."""
    idx = _STEM_INDEX_CACHE.get(repo_root)
    if idx is None:
        idx = {}
        for dirpath, dirnames, filenames in os.walk(repo_root):
            dirnames[:] = [d for d in dirnames if d not in _SKIP_DIRS]
            for fname in filenames:
                ext = Path(fname).suffix.lower()
                if ext not in _EXT_LANG:
                    continue
                key = Path(fname).stem + "|" + ext
                idx.setdefault(key, Path(dirpath) / fname)
        _STEM_INDEX_CACHE[repo_root] = idx
    key = stem + "|" + ext_hint.lower()
    return idx.get(key)


def _rel_id(p: Path, repo_root: Path) -> str:
    """Convert Path → POSIX relative path string so graph is portable."""
    try:
        rel = p.resolve().relative_to(repo_root)
    except ValueError:
        return str(p)
    return rel.as_posix()


# ──────────────────────────────────────────────────────────────────────
# Public API
# ──────────────────────────────────────────────────────────────────────


def build(
    repo_root: Path,
    scope: dict[str, Any] | None = None,
    max_files: int = MAX_FILES_DEFAULT,
    max_file_bytes: int = MAX_FILE_BYTES_DEFAULT,
) -> Graph:
    """Xây Impact Graph từ ``repo_root``.

    Args:
        repo_root: thư mục gốc của project.
        scope: optional, lưu vào metadata (vd ``{"type": "module", "name": "crm"}``).
        max_files: giới hạn số file quét (phòng thủ).
        max_file_bytes: bỏ qua file lớn hơn ngưỡng này.

    Returns:
        ``Graph`` đã populate ``nodes``, ``edges``, ``stats``.
    """
    repo_root = repo_root.resolve()
    files = _iter_source_files(repo_root, max_files=max_files, max_file_bytes=max_file_bytes)

    nodes: list[Node] = []
    edges: list[Edge] = []
    seen_edge_keys: set[tuple[str, str, int]] = set()
    skipped = 0

    for fp in files:
        try:
            content = fp.read_text(encoding="utf-8", errors="replace")
        except OSError:
            skipped += 1
            continue
        lang = _EXT_LANG.get(fp.suffix.lower(), "unknown")
        nodes.append(
            Node(
                id=_rel_id(fp, repo_root),
                lang=lang,
                loc=_loc_estimate(content),
            )
        )
        try:
            if lang in ("ts", "tsx", "js", "jsx"):
                new_edges = _parse_js_like(fp, content, repo_root)
            elif lang == "py":
                new_edges = _parse_py(fp, content, repo_root)
            elif lang == "java":
                new_edges = _parse_generic(fp, content, repo_root, _RX_JAVA_IMPORT)
            elif lang == "cs":
                new_edges = _parse_generic(fp, content, repo_root, _RX_CS_USING)
            elif lang == "go":
                new_edges = _parse_generic(fp, content, repo_root, _RX_GO_IMPORT)
            elif lang == "rs":
                new_edges = _parse_generic(fp, content, repo_root, _RX_RS_USE)
            else:
                new_edges = []
        except Exception:  # noqa: BLE001 — resilient per file
            skipped += 1
            continue
        for e in new_edges:
            key = (e.source, e.target, e.evidence_line)
            if key in seen_edge_keys:
                continue
            seen_edge_keys.add(key)
            # Loại self-loop
            if e.source == e.target:
                continue
            edges.append(e)

    # Reset stem index cache để không rò memory giữa nhiều lần gọi
    _STEM_INDEX_CACHE.pop(repo_root, None)

    graph = Graph(
        schema=SCHEMA_ID,
        built_at=datetime.now(timezone.utc).isoformat(timespec="seconds"),
        scope=dict(scope or {}),
        nodes=nodes,
        edges=edges,
        stats={
            "file_count": len(nodes),
            "edge_count": len(edges),
            "files_skipped": skipped,
            "repo_root": _rel_id(repo_root, repo_root) or ".",
        },
    )
    return graph


def _graph_to_dict(g: Graph) -> dict[str, Any]:
    return {
        "$schema": g.schema,
        "built_at": g.built_at,
        "scope": g.scope,
        "stats": g.stats,
        "nodes": [asdict(n) for n in g.nodes],
        "edges": [asdict(e) for e in g.edges],
    }


def emit(graph: Graph, out_path: Path) -> None:
    """Atomic write graph → ``out_path`` (tạo parent nếu chưa có)."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_fd, tmp_name = tempfile.mkstemp(
        prefix=f".{out_path.name}.",
        suffix=".tmp",
        dir=str(out_path.parent),
    )
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as fh:
            # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
            json.dump(_graph_to_dict(graph), fh, indent=2, ensure_ascii=False, sort_keys=True)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_name, out_path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def _parse_scope(s: str) -> dict[str, Any]:
    if s == "all":
        return {"type": "all"}
    if ":" in s:
        kind, name = s.split(":", 1)
        if kind in ("system", "module") and name:
            return {"type": kind, "name": name}
    raise argparse.ArgumentTypeError(f"Invalid scope: {s}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Impact Graph Builder (probe P0.XREF)"
    )
    parser.add_argument("--repo-root", type=Path, required=True, help="Project root")
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help="Output path (e.g. $SESSION_DIR/impact-graph.json)",
    )
    parser.add_argument(
        "--scope",
        type=_parse_scope,
        default={"type": "all"},
        help="Scope filter: all | system:<name> | module:<name>",
    )
    parser.add_argument("--max-files", type=int, default=MAX_FILES_DEFAULT)
    parser.add_argument("--max-file-bytes", type=int, default=MAX_FILE_BYTES_DEFAULT)

    args = parser.parse_args(argv)
    try:
        graph = build(
            repo_root=args.repo_root,
            scope=args.scope,
            max_files=args.max_files,
            max_file_bytes=args.max_file_bytes,
        )
        emit(graph, args.output)
    except Exception as exc:  # noqa: BLE001 — thin CLI surface
        print(f"[impact_graph.builder ERROR] {exc}", file=sys.stderr)
        return 1
    print(
        f"[impact_graph.builder] nodes={len(graph.nodes)} "
        f"edges={len(graph.edges)} out={args.output}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
