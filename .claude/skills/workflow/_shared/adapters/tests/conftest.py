"""conftest.py — Shared fixtures cho adapter framework smoke tests.

Vai trò:
    - Cung cấp path constants tới dispatcher + adapter dirs.
    - Helper fixtures cho tmp project paths (empty, node, dotnet, ...).
    - Tuân thủ CORE-005: docstring tiếng Việt; test code English.

Phạm vi:
    Chỉ phục vụ smoke test B0 (test_dispatcher_smoke.py). Khi IMP-001/003/010 implement
    đầy đủ ở Stage 3, thêm fixtures riêng cho mỗi adapter family.
"""
from __future__ import annotations

from pathlib import Path

import pytest

# ──────────────────────────────────────────────────────────────────────
# Path constants
# ──────────────────────────────────────────────────────────────────────

# tests/ nằm ở adapters/tests/. Parent là adapters/.
# (Constants được duplicated trong test file để tránh phụ thuộc import từ conftest —
#  pytest tự load conftest fixtures nhưng IDE static analyzer không resolve được.)
ADAPTERS_ROOT = Path(__file__).resolve().parent.parent


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def adapters_root() -> Path:
    """Trả về path tuyệt đối tới adapters/ root."""
    return ADAPTERS_ROOT


@pytest.fixture
def empty_project(tmp_path: Path) -> Path:
    """Tạo project rỗng (không có lockfile/manifest nào). Mọi adapter detect() → 1."""
    project = tmp_path / "empty-project"
    project.mkdir()
    return project


@pytest.fixture
def node_project(tmp_path: Path) -> Path:
    """Tạo project Node tối thiểu (chỉ có package.json). Stack/node + PM/npm match."""
    project = tmp_path / "node-project"
    project.mkdir()
    (project / "package.json").write_text('{"name":"test","version":"0.0.0"}', encoding="utf-8")
    (project / "package-lock.json").write_text('{"lockfileVersion":3}', encoding="utf-8")
    return project


@pytest.fixture
def dotnet_project(tmp_path: Path) -> Path:
    """Tạo project .NET tối thiểu (.csproj). Stack/dotnet + PM/nuget match nếu có PackageReference."""
    project = tmp_path / "dotnet-project"
    project.mkdir()
    csproj = project / "Sample.csproj"
    csproj.write_text(
        """<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><TargetFramework>net9.0</TargetFramework></PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore" Version="9.0.0" />
  </ItemGroup>
</Project>
""",
        encoding="utf-8",
    )
    return project


@pytest.fixture(scope="session")
def all_adapter_files() -> list[Path]:
    """Trả về list mọi file adapter .sh (trừ _dispatcher.sh)."""
    files: list[Path] = []
    for category in ("stack", "package-manager", "orm"):
        cat_dir = ADAPTERS_ROOT / category
        if not cat_dir.is_dir():
            continue
        files.extend(sorted(cat_dir.glob("*.sh")))
    return files
