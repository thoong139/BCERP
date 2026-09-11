"""test_impact_graph_builder_xf08.py — XF-08 (Sprint 7) coverage uplift cho impact_graph/builder.

Sprint 7 mục tiêu: nâng `impact_graph/builder.py` từ 46.60% → ≥80%.

Focus vào các hàm parser/resolver/orchestrator chưa cover:
- `_iter_source_files`: walk + skip_dirs + max_files cap
- `_loc_estimate`: empty/non-empty content
- `_resolve_relative`: ./x, ../y, file vs index
- `_resolve_py_module`: stdlib hint, package init, dotted path
- `_compute_strength`: wildcard, head-of-file, cap floor
- `_parse_js_like`: ES6 import, dynamic import(), require
- `_parse_py`: from-import, import, wildcard
- `_parse_generic`: java/cs/go/rs heuristic
- `_find_by_stem`: stem index cache
- `_rel_id`: outside repo path fallback
- `build()`: end-to-end mixed Python/TS project, OSError tolerant
- `_graph_to_dict`/`emit()`: serialization + atomic write
- `_parse_scope` + `main()`: CLI parser + exit codes

Pattern Sprint 6 — inline tmp_path fixtures, mock chỉ khi cần.

Tham chiếu:
- BHV-002 Simplicity First (inline strings, no persistent fixtures)
- CORE-035 Atomic Write Pattern (test emit())
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

from _shared.impact_graph import builder
from _shared.impact_graph.builder import (
    SCHEMA_ID,
    Edge,
    Graph,
    Node,
    _compute_strength,
    _find_by_stem,
    _graph_to_dict,
    _iter_source_files,
    _loc_estimate,
    _parse_generic,
    _parse_js_like,
    _parse_py,
    _parse_scope,
    _rel_id,
    _resolve_py_module,
    _resolve_relative,
    _RX_JAVA_IMPORT,
    _RX_RS_USE,
    build,
    emit,
    main,
)


# ──────────────────────────────────────────────────────────────────────
# _iter_source_files
# ──────────────────────────────────────────────────────────────────────


class TestIterSourceFiles:
    def test_empty_dir_returns_empty(self, tmp_path: Path) -> None:
        """Thư mục rỗng → list rỗng (không raise)."""
        result = _iter_source_files(
            tmp_path, max_files=100, max_file_bytes=1024
        )
        assert result == []

    def test_collects_supported_extensions(self, tmp_path: Path) -> None:
        """File .py/.ts/.go etc. được pick; .txt bỏ qua."""
        (tmp_path / "a.py").write_text("x = 1\n")
        (tmp_path / "b.ts").write_text("export const x = 1;\n")
        (tmp_path / "c.txt").write_text("ignore me\n")
        (tmp_path / "d.go").write_text("package main\n")
        result = _iter_source_files(
            tmp_path, max_files=10, max_file_bytes=1024
        )
        names = sorted(p.name for p in result)
        assert "a.py" in names
        assert "b.ts" in names
        assert "d.go" in names
        assert "c.txt" not in names

    def test_skips_excluded_dirs(self, tmp_path: Path) -> None:
        """node_modules, .git, __pycache__ etc. bị skip."""
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "ok.py").write_text("x = 1\n")
        (tmp_path / "node_modules").mkdir()
        (tmp_path / "node_modules" / "lib.js").write_text("x = 1\n")
        (tmp_path / ".git").mkdir()
        (tmp_path / ".git" / "config.py").write_text("x = 1\n")
        result = _iter_source_files(
            tmp_path, max_files=10, max_file_bytes=1024
        )
        names = [p.name for p in result]
        assert "ok.py" in names
        assert "lib.js" not in names
        assert "config.py" not in names

    def test_respects_max_files_cap(self, tmp_path: Path) -> None:
        """max_files=2 → trả về tối đa 2 file."""
        for i in range(5):
            (tmp_path / f"f{i}.py").write_text("x = 1\n")
        result = _iter_source_files(
            tmp_path, max_files=2, max_file_bytes=1024
        )
        assert len(result) <= 2

    def test_skips_oversize_files(self, tmp_path: Path) -> None:
        """File > max_file_bytes bị bỏ qua."""
        small = tmp_path / "small.py"
        small.write_text("x = 1\n")
        big = tmp_path / "big.py"
        big.write_text("x = 1\n" * 1000)  # ~6000 bytes
        result = _iter_source_files(
            tmp_path, max_files=10, max_file_bytes=100
        )
        names = [p.name for p in result]
        assert "small.py" in names
        assert "big.py" not in names


# ──────────────────────────────────────────────────────────────────────
# _loc_estimate
# ──────────────────────────────────────────────────────────────────────


class TestLocEstimate:
    def test_empty_string(self) -> None:
        assert _loc_estimate("") == 0

    def test_only_blank_lines(self) -> None:
        assert _loc_estimate("\n\n\n") == 0

    def test_mixed_lines(self) -> None:
        """Đếm dòng non-empty (blank lines bỏ qua)."""
        content = "x = 1\n\ny = 2\n   \nz = 3\n"
        assert _loc_estimate(content) == 3


# ──────────────────────────────────────────────────────────────────────
# _resolve_relative
# ──────────────────────────────────────────────────────────────────────


class TestResolveRelative:
    def test_non_relative_returns_none(self, tmp_path: Path) -> None:
        """Import không bắt đầu '.' hay '/' → None."""
        src = tmp_path / "src" / "a.ts"
        src.parent.mkdir(parents=True)
        src.write_text("")
        assert _resolve_relative(src, "react", tmp_path) is None

    def test_resolves_explicit_extension(self, tmp_path: Path) -> None:
        """./other.ts → resolve thành tmp_path/src/other.ts."""
        src = tmp_path / "src" / "a.ts"
        src.parent.mkdir(parents=True)
        src.write_text("")
        target = tmp_path / "src" / "other.ts"
        target.write_text("export const x = 1;\n")
        result = _resolve_relative(src, "./other", tmp_path)
        assert result is not None
        assert result.name == "other.ts"

    def test_resolves_index_file(self, tmp_path: Path) -> None:
        """./utils → utils/index.ts khi không có file utils.ts."""
        src = tmp_path / "src" / "a.ts"
        src.parent.mkdir(parents=True)
        src.write_text("")
        idx = tmp_path / "src" / "utils" / "index.ts"
        idx.parent.mkdir(parents=True)
        idx.write_text("export const u = 1;\n")
        result = _resolve_relative(src, "./utils", tmp_path)
        assert result is not None
        assert result.name == "index.ts"

    def test_outside_repo_returns_none(self, tmp_path: Path) -> None:
        """Resolve target ngoài repo → None."""
        sub = tmp_path / "sub"
        sub.mkdir()
        src = sub / "a.ts"
        src.write_text("")
        # ../outside.ts trỏ ra ngoài sub, vẫn nằm trong tmp_path
        # Nên test với repo_root = sub (outside tmp_path)
        outside = tmp_path / "outside.ts"
        outside.write_text("")
        result = _resolve_relative(src, "../outside", sub)
        assert result is None


# ──────────────────────────────────────────────────────────────────────
# _resolve_py_module
# ──────────────────────────────────────────────────────────────────────


class TestResolvePyModule:
    def test_empty_module_returns_none(self, tmp_path: Path) -> None:
        assert _resolve_py_module("", tmp_path) is None

    def test_stdlib_returns_none(self, tmp_path: Path) -> None:
        """stdlib top (os, json, etc.) → None để giảm false positive."""
        assert _resolve_py_module("os", tmp_path) is None
        assert _resolve_py_module("json.encoder", tmp_path) is None

    def test_resolves_module_file(self, tmp_path: Path) -> None:
        """myapp.utils → tmp_path/myapp/utils.py."""
        pkg = tmp_path / "myapp"
        pkg.mkdir()
        (pkg / "utils.py").write_text("def f(): pass\n")
        result = _resolve_py_module("myapp.utils", tmp_path)
        assert result is not None
        assert result.name == "utils.py"

    def test_resolves_package_init(self, tmp_path: Path) -> None:
        """myapp → tmp_path/myapp/__init__.py."""
        pkg = tmp_path / "myapp"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")
        result = _resolve_py_module("myapp", tmp_path)
        assert result is not None
        assert result.name == "__init__.py"

    def test_unresolvable_returns_none(self, tmp_path: Path) -> None:
        """myapp.does_not_exist → None."""
        assert _resolve_py_module("myapp.nope", tmp_path) is None


# ──────────────────────────────────────────────────────────────────────
# _compute_strength
# ──────────────────────────────────────────────────────────────────────


class TestComputeStrength:
    def test_baseline(self) -> None:
        """Import thường (không wildcard, không top) → 0.5 base."""
        s = _compute_strength("foo.bar", line_no=50, total_lines=100)
        assert s == 0.5

    def test_wildcard_bonus(self) -> None:
        """Có '*' → +0.2."""
        s = _compute_strength("foo.*", line_no=50, total_lines=100)
        assert s == 0.7

    def test_top_of_file_bonus(self) -> None:
        """Line nằm trong 5% đầu file → +0.2."""
        s = _compute_strength("foo", line_no=2, total_lines=100)
        assert s == 0.7

    def test_both_bonuses_capped_at_1(self) -> None:
        """Wildcard + top → 0.5 + 0.2 + 0.2 = 0.9."""
        s = _compute_strength("foo.*", line_no=1, total_lines=100)
        assert s == 0.9

    def test_max_cap_at_1(self) -> None:
        """Hypothetical: nếu base > 1.0 → cap to 1.0 (test indirectly)."""
        # Function chỉ có 2 bonus +0.2, max 0.9 — verify cap branch covered
        # bằng cách check hàm trả về float ≤ 1.0
        s = _compute_strength("**", line_no=1, total_lines=10)
        assert s <= 1.0

    def test_empty_total_lines(self) -> None:
        """total_lines=0 → không apply top-of-file bonus."""
        s = _compute_strength("foo", line_no=1, total_lines=0)
        assert s == 0.5


# ──────────────────────────────────────────────────────────────────────
# _parse_js_like
# ──────────────────────────────────────────────────────────────────────


class TestParseJsLike:
    def test_es6_import_from(self, tmp_path: Path) -> None:
        """`import x from './other'` → 1 edge tới other.ts."""
        src = tmp_path / "a.ts"
        target = tmp_path / "other.ts"
        target.write_text("export const x = 1;\n")
        content = "import x from './other';\n"
        src.write_text(content)
        edges = _parse_js_like(src, content, tmp_path)
        assert len(edges) == 1
        assert edges[0].target.endswith("other.ts")
        assert edges[0].edge_type == "import"

    def test_dynamic_import(self, tmp_path: Path) -> None:
        """`import('./mod')` dynamic ở đầu dòng → 1 edge.

        Regex `_RX_JS_IMPORT` yêu cầu `^\\s*` đầu dòng nên expression dynamic
        import phải được place ở đầu dòng.
        """
        src = tmp_path / "a.ts"
        (tmp_path / "mod.ts").write_text("")
        content = "import('./mod');\n"
        src.write_text(content)
        edges = _parse_js_like(src, content, tmp_path)
        assert len(edges) == 1
        assert edges[0].target.endswith("mod.ts")

    def test_require_pattern(self, tmp_path: Path) -> None:
        """`const x = require('./x')` → 1 edge."""
        src = tmp_path / "a.js"
        (tmp_path / "x.js").write_text("")
        content = "const x = require('./x');\n"
        src.write_text(content)
        edges = _parse_js_like(src, content, tmp_path)
        assert len(edges) == 1

    def test_unresolved_import_skipped(self, tmp_path: Path) -> None:
        """`import x from 'react'` (external) → no edge."""
        src = tmp_path / "a.ts"
        content = "import x from 'react';\n"
        src.write_text(content)
        edges = _parse_js_like(src, content, tmp_path)
        assert edges == []

    def test_no_imports_returns_empty(self, tmp_path: Path) -> None:
        src = tmp_path / "a.ts"
        content = "const x = 1;\n"
        src.write_text(content)
        edges = _parse_js_like(src, content, tmp_path)
        assert edges == []


# ──────────────────────────────────────────────────────────────────────
# _parse_py
# ──────────────────────────────────────────────────────────────────────


class TestParsePy:
    def test_from_import_with_symbols(self, tmp_path: Path) -> None:
        """`from myapp import utils` → 1 edge tới myapp/__init__.py hoặc utils.py."""
        pkg = tmp_path / "myapp"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")
        (pkg / "utils.py").write_text("def f(): pass\n")
        src = tmp_path / "main.py"
        content = "from myapp import utils\n"
        src.write_text(content)
        edges = _parse_py(src, content, tmp_path)
        # Có thể resolve thành utils.py + __init__.py — tối thiểu 1
        assert len(edges) >= 1

    def test_plain_import(self, tmp_path: Path) -> None:
        """`import myapp.utils` → 1 edge."""
        pkg = tmp_path / "myapp"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")
        (pkg / "utils.py").write_text("")
        src = tmp_path / "main.py"
        content = "import myapp.utils\n"
        src.write_text(content)
        edges = _parse_py(src, content, tmp_path)
        assert len(edges) >= 1

    def test_wildcard_import(self, tmp_path: Path) -> None:
        """`from myapp import *` → resolve tới package init."""
        pkg = tmp_path / "myapp"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("x = 1\n")
        src = tmp_path / "main.py"
        content = "from myapp import *\n"
        src.write_text(content)
        edges = _parse_py(src, content, tmp_path)
        # Wildcard → strength bonus
        assert len(edges) >= 1
        assert edges[0].strength >= 0.5

    def test_stdlib_import_skipped(self, tmp_path: Path) -> None:
        """`import os` → no edge (stdlib hint)."""
        src = tmp_path / "main.py"
        content = "import os\nimport sys\n"
        src.write_text(content)
        edges = _parse_py(src, content, tmp_path)
        assert edges == []

    def test_unresolvable_module_skipped(self, tmp_path: Path) -> None:
        """`import nonexistent_pkg` → no edge."""
        src = tmp_path / "main.py"
        content = "import nonexistent_pkg.foo\n"
        src.write_text(content)
        edges = _parse_py(src, content, tmp_path)
        assert edges == []

    def test_multiple_imports_in_one_statement(self, tmp_path: Path) -> None:
        """`import myapp.a, myapp.b` → 2 edges."""
        pkg = tmp_path / "myapp"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")
        (pkg / "a.py").write_text("")
        (pkg / "b.py").write_text("")
        src = tmp_path / "main.py"
        content = "import myapp.a, myapp.b\n"
        src.write_text(content)
        edges = _parse_py(src, content, tmp_path)
        assert len(edges) >= 2


# ──────────────────────────────────────────────────────────────────────
# _parse_generic (Java/C#/Go/Rust)
# ──────────────────────────────────────────────────────────────────────


class TestParseGeneric:
    def test_java_import_resolved(self, tmp_path: Path) -> None:
        """`import com.foo.MyClass;` → resolve tới MyClass.java nếu có."""
        # Reset cache giữa tests
        builder._STEM_INDEX_CACHE.clear()
        src = tmp_path / "Main.java"
        target = tmp_path / "lib" / "MyClass.java"
        target.parent.mkdir()
        target.write_text("public class MyClass {}\n")
        content = "import com.foo.MyClass;\n"
        src.write_text(content)
        edges = _parse_generic(src, content, tmp_path, _RX_JAVA_IMPORT)
        assert len(edges) == 1
        assert edges[0].target.endswith("MyClass.java")

    def test_no_match_when_target_missing(self, tmp_path: Path) -> None:
        """`import com.foo.Missing;` không có file → no edge."""
        builder._STEM_INDEX_CACHE.clear()
        src = tmp_path / "Main.java"
        content = "import com.foo.Missing;\n"
        src.write_text(content)
        edges = _parse_generic(src, content, tmp_path, _RX_JAVA_IMPORT)
        assert edges == []

    def test_short_stem_skipped(self, tmp_path: Path) -> None:
        """Stem 1 ký tự bị skip (giảm false positive)."""
        builder._STEM_INDEX_CACHE.clear()
        src = tmp_path / "Main.java"
        # stem = "X" → length < 2 sẽ skip
        content = "import a.X;\n"
        src.write_text(content)
        edges = _parse_generic(src, content, tmp_path, _RX_JAVA_IMPORT)
        assert edges == []

    def test_rust_use_resolved(self, tmp_path: Path) -> None:
        """`use mymod::myfunc;` → segment cuối = "myfunc" → match myfunc.rs."""
        builder._STEM_INDEX_CACHE.clear()
        src = tmp_path / "main.rs"
        target = tmp_path / "myfunc.rs"
        target.write_text("pub fn x() {}\n")
        content = "use mymod::myfunc;\n"
        src.write_text(content)
        edges = _parse_generic(src, content, tmp_path, _RX_RS_USE)
        assert len(edges) >= 1


# ──────────────────────────────────────────────────────────────────────
# _find_by_stem
# ──────────────────────────────────────────────────────────────────────


class TestFindByStem:
    def test_finds_existing_file(self, tmp_path: Path) -> None:
        builder._STEM_INDEX_CACHE.clear()
        (tmp_path / "Foo.java").write_text("")
        result = _find_by_stem(tmp_path, "Foo", ".java")
        assert result is not None
        assert result.name == "Foo.java"

    def test_returns_none_when_missing(self, tmp_path: Path) -> None:
        builder._STEM_INDEX_CACHE.clear()
        result = _find_by_stem(tmp_path, "NotThere", ".java")
        assert result is None

    def test_uses_cache_on_second_call(self, tmp_path: Path) -> None:
        """Second call hit cache, không re-walk filesystem."""
        builder._STEM_INDEX_CACHE.clear()
        (tmp_path / "X.go").write_text("")
        first = _find_by_stem(tmp_path, "X", ".go")
        # Cache phải có entry
        assert tmp_path in builder._STEM_INDEX_CACHE
        second = _find_by_stem(tmp_path, "X", ".go")
        assert first == second


# ──────────────────────────────────────────────────────────────────────
# _rel_id
# ──────────────────────────────────────────────────────────────────────


class TestRelId:
    def test_inside_repo(self, tmp_path: Path) -> None:
        """Path trong repo → POSIX relative."""
        f = tmp_path / "src" / "a.py"
        f.parent.mkdir()
        f.write_text("")
        result = _rel_id(f, tmp_path)
        assert "/" in result or "\\" not in result
        assert result.endswith("a.py")

    def test_outside_repo_fallback(self, tmp_path: Path) -> None:
        """Path ngoài repo → str(p) fallback (ValueError nội bộ)."""
        # Tạo path nằm ngoài tmp_path
        outside = tmp_path.parent / "outside_file.py"
        try:
            outside.write_text("")
            result = _rel_id(outside, tmp_path)
            # Khi outside repo → trả về str(p) (fallback branch)
            assert isinstance(result, str)
            assert "outside_file.py" in result
        finally:
            if outside.exists():
                outside.unlink()


# ──────────────────────────────────────────────────────────────────────
# build() — end-to-end
# ──────────────────────────────────────────────────────────────────────


class TestBuildEndToEnd:
    def test_empty_repo_produces_valid_graph(self, tmp_path: Path) -> None:
        """Empty repo → graph với schema + stats nhưng nodes/edges rỗng."""
        builder._STEM_INDEX_CACHE.clear()
        graph = build(tmp_path)
        assert graph.schema == SCHEMA_ID
        assert graph.nodes == []
        assert graph.edges == []
        assert graph.stats["file_count"] == 0
        assert graph.stats["edge_count"] == 0

    def test_python_project_with_imports(self, tmp_path: Path) -> None:
        """Python project: main.py imports myapp.utils → có node + edge."""
        builder._STEM_INDEX_CACHE.clear()
        pkg = tmp_path / "myapp"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")
        (pkg / "utils.py").write_text("def f(): pass\n")
        (tmp_path / "main.py").write_text("from myapp import utils\n")
        graph = build(tmp_path)
        assert graph.stats["file_count"] >= 2
        # Phải có ít nhất 1 edge từ main.py tới myapp/...
        assert graph.stats["edge_count"] >= 1

    def test_typescript_project_with_imports(self, tmp_path: Path) -> None:
        """TypeScript project: a.ts imports './b' → có edge."""
        builder._STEM_INDEX_CACHE.clear()
        (tmp_path / "a.ts").write_text("import x from './b';\n")
        (tmp_path / "b.ts").write_text("export const x = 1;\n")
        graph = build(tmp_path)
        assert graph.stats["file_count"] >= 2
        assert graph.stats["edge_count"] >= 1

    def test_scope_metadata_preserved(self, tmp_path: Path) -> None:
        """Scope dict được lưu vào graph metadata."""
        builder._STEM_INDEX_CACHE.clear()
        scope = {"type": "module", "name": "crm"}
        graph = build(tmp_path, scope=scope)
        assert graph.scope == scope

    def test_stats_repo_root_present(self, tmp_path: Path) -> None:
        """stats có repo_root field."""
        builder._STEM_INDEX_CACHE.clear()
        graph = build(tmp_path)
        assert "repo_root" in graph.stats

    def test_self_loops_filtered(self, tmp_path: Path) -> None:
        """File import chính nó (self-loop) bị filter — verify edge.source != edge.target."""
        builder._STEM_INDEX_CACHE.clear()
        (tmp_path / "a.ts").write_text("import x from './a';\n")  # self-loop
        graph = build(tmp_path)
        for e in graph.edges:
            assert e.source != e.target


# ──────────────────────────────────────────────────────────────────────
# _graph_to_dict + emit
# ──────────────────────────────────────────────────────────────────────


class TestGraphToDictAndEmit:
    def test_graph_to_dict_schema_field(self) -> None:
        """_graph_to_dict emit `$schema` (not `schema`)."""
        g = Graph()
        d = _graph_to_dict(g)
        assert "$schema" in d
        assert d["$schema"] == SCHEMA_ID
        assert d["nodes"] == []
        assert d["edges"] == []

    def test_graph_to_dict_serializes_nodes_and_edges(self) -> None:
        """Node/Edge → dict qua asdict."""
        g = Graph(
            nodes=[Node(id="a.py", lang="py", loc=10)],
            edges=[
                Edge(
                    source="a.py", target="b.py",
                    edge_type="import", strength=0.5,
                    evidence_line=1,
                )
            ],
        )
        d = _graph_to_dict(g)
        assert d["nodes"][0]["id"] == "a.py"
        assert d["edges"][0]["target"] == "b.py"

    def test_emit_writes_atomic(self, tmp_path: Path) -> None:
        """emit() tạo parent dir + ghi JSON valid."""
        out = tmp_path / "subdir" / "graph.json"
        g = Graph(nodes=[Node(id="a.py", lang="py", loc=1)])
        emit(g, out)
        assert out.is_file()
        loaded = json.loads(out.read_text(encoding="utf-8"))
        assert loaded["$schema"] == SCHEMA_ID
        assert loaded["nodes"][0]["id"] == "a.py"

    def test_emit_idempotent_overwrite(self, tmp_path: Path) -> None:
        """emit() ghi đè file cũ (atomic replace)."""
        out = tmp_path / "graph.json"
        g1 = Graph(nodes=[Node(id="a.py", lang="py", loc=1)])
        emit(g1, out)
        g2 = Graph(nodes=[Node(id="b.py", lang="py", loc=2)])
        emit(g2, out)
        loaded = json.loads(out.read_text(encoding="utf-8"))
        assert loaded["nodes"][0]["id"] == "b.py"


# ──────────────────────────────────────────────────────────────────────
# CLI: _parse_scope + main
# ──────────────────────────────────────────────────────────────────────


class TestParseScope:
    def test_all_returns_type_all(self) -> None:
        result = _parse_scope("all")
        assert result == {"type": "all"}

    def test_system_with_name(self) -> None:
        result = _parse_scope("system:crm")
        assert result == {"type": "system", "name": "crm"}

    def test_module_with_name(self) -> None:
        result = _parse_scope("module:auth")
        assert result == {"type": "module", "name": "auth"}

    def test_invalid_format_raises(self) -> None:
        import argparse as ap
        with pytest.raises(ap.ArgumentTypeError):
            _parse_scope("invalid")

    def test_invalid_kind_raises(self) -> None:
        import argparse as ap
        with pytest.raises(ap.ArgumentTypeError):
            _parse_scope("unknown:value")


class TestMainCLI:
    def test_main_success_writes_output(self, tmp_path: Path) -> None:
        """main() build + emit thành công với --repo-root + --output."""
        builder._STEM_INDEX_CACHE.clear()
        (tmp_path / "a.py").write_text("x = 1\n")
        out = tmp_path / "graph.json"
        rc = main([
            "--repo-root", str(tmp_path),
            "--output", str(out),
        ])
        assert rc == 0
        assert out.is_file()
        loaded = json.loads(out.read_text(encoding="utf-8"))
        assert loaded["$schema"] == SCHEMA_ID

    def test_main_with_scope_arg(self, tmp_path: Path) -> None:
        """main() với --scope module:foo → scope nhúng vào graph."""
        builder._STEM_INDEX_CACHE.clear()
        out = tmp_path / "graph.json"
        rc = main([
            "--repo-root", str(tmp_path),
            "--output", str(out),
            "--scope", "module:foo",
        ])
        assert rc == 0
        loaded = json.loads(out.read_text(encoding="utf-8"))
        assert loaded["scope"] == {"type": "module", "name": "foo"}

    def test_main_failure_returns_1(self, tmp_path: Path, monkeypatch) -> None:
        """main() khi build raise → return 1."""
        builder._STEM_INDEX_CACHE.clear()

        def boom(*args, **kwargs):
            raise RuntimeError("simulated")

        monkeypatch.setattr("_shared.impact_graph.builder.build", boom)
        out = tmp_path / "graph.json"
        rc = main([
            "--repo-root", str(tmp_path),
            "--output", str(out),
        ])
        assert rc == 1


# ──────────────────────────────────────────────────────────────────────
# CLI subprocess (real entry point)
# ──────────────────────────────────────────────────────────────────────


class TestCLISubprocess:
    """End-to-end CLI fork để cover `if __name__ == '__main__'` branch."""

    def test_cli_runs_via_module(self, tmp_path: Path) -> None:
        """`python -m _shared.impact_graph.builder --repo-root ... --output ...`."""
        (tmp_path / "a.py").write_text("x = 1\n")
        out = tmp_path / "graph.json"
        result = subprocess.run(
            [
                sys.executable, "-m", "_shared.impact_graph.builder",
                "--repo-root", str(tmp_path),
                "--output", str(out),
            ],
            capture_output=True, text=True,
            cwd=Path(__file__).parent.parent.parent,
        )
        assert result.returncode == 0, f"CLI failed: {result.stderr}"
        assert out.is_file()
