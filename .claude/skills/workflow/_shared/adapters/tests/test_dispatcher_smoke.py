"""test_dispatcher_smoke.py — Smoke tests cho IMP-000 adapter framework scaffolding.

Phạm vi B0:
    - Verify dispatcher invokable + exit codes đúng.
    - Verify đủ 16 adapters đăng ký (5 stack + 5 PM + 6 ORM).
    - Verify mỗi adapter có detect()/scan() callable (không kiểm tra logic chi tiết).
    - Verify detect() trên empty dir → return 1; trên node-project → return 0.
    - Verify exit code 2 khi project path không tồn tại.

Out of scope (Stage 3 IMP-001/003/010):
    - Chính xác của detection per adapter (sẽ test bằng fixtures riêng).
    - Output schema của scan() (skeleton chỉ in stub message).

Tuân thủ CORE-005: docstring tiếng Việt; test code English.
"""
from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

# ──────────────────────────────────────────────────────────────────────
# Constants (đặt cạnh test để static analyzer không cần resolve conftest)
# ──────────────────────────────────────────────────────────────────────

ADAPTERS_ROOT = Path(__file__).resolve().parent.parent
DISPATCHER = ADAPTERS_ROOT / "_dispatcher.sh"

EXPECTED_STACKS = ["dotnet", "go", "java", "node", "python"]
EXPECTED_PMS = ["go-mod", "maven", "npm", "nuget", "pip"]
EXPECTED_ORMS = ["ef-core", "hibernate", "prisma", "sequelize", "sqlalchemy", "typeorm"]


def _to_bash_path(p: str | Path) -> str:
    """Convert Windows path → bash-compatible form.

    Detect runner bash: if subprocess bash là WSL (uname → Linux), convert `D:/...` → `/mnt/d/...`.
    Nếu là MSYS/MinGW (uname → MINGW*/MSYS*), giữ POSIX form `D:/...`.
    Cache kết quả ở module level để tránh spawn nhiều subprocess.
    """
    posix = Path(p).as_posix()
    if _IS_WSL_BASH and len(posix) >= 2 and posix[1] == ":":
        # D:/Working/... → /mnt/d/Working/...
        drive = posix[0].lower()
        return f"/mnt/{drive}{posix[2:]}"
    return posix


def _detect_wsl_bash() -> bool:
    """Probe runner bash 1 lần — True nếu WSL (cần convert path)."""
    try:
        result = subprocess.run(
            ["bash", "-c", "uname -s"],
            capture_output=True,
            text=True,
            check=False,
            timeout=5,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False
    return result.stdout.strip() == "Linux"


_IS_WSL_BASH: bool = _detect_wsl_bash()


def _run_dispatcher(*args: str) -> subprocess.CompletedProcess[str]:
    """Helper: invoke _dispatcher.sh qua bash, capture stdout/stderr/return code.

    Convert mọi arg dạng path sang form bash hiểu (POSIX hoặc /mnt/<drive>/ cho WSL).
    """
    posix_args = [_to_bash_path(a) if Path(a).exists() or "/" in a or "\\" in a else a for a in args]
    return subprocess.run(
        ["bash", _to_bash_path(DISPATCHER), *posix_args],
        capture_output=True,
        text=True,
        check=False,
    )


# ──────────────────────────────────────────────────────────────────────
# Dispatcher CLI
# ──────────────────────────────────────────────────────────────────────


class TestDispatcherCLI:
    def test_dispatcher_file_exists(self) -> None:
        assert DISPATCHER.is_file(), f"Missing dispatcher at {DISPATCHER}"

    def test_help_exits_zero(self) -> None:
        result = _run_dispatcher("--help")
        assert result.returncode == 0
        assert "Adapter Framework Dispatcher" in result.stdout

    def test_no_args_exits_one(self) -> None:
        result = _run_dispatcher()
        assert result.returncode == 1

    def test_unknown_flag_exits_one(self) -> None:
        result = _run_dispatcher("--bogus")
        assert result.returncode == 1


# ──────────────────────────────────────────────────────────────────────
# --list-adapters
# ──────────────────────────────────────────────────────────────────────


class TestListAdapters:
    def test_list_exits_zero(self) -> None:
        result = _run_dispatcher("--list-adapters")
        assert result.returncode == 0, f"stderr: {result.stderr}"

    def test_list_count_is_sixteen(self) -> None:
        """Expected total: 5 stack + 5 PM + 6 ORM = 16."""
        result = _run_dispatcher("--list-adapters")
        lines = [ln for ln in result.stdout.strip().splitlines() if ln]
        assert len(lines) == 16, f"Expected 16 adapters, got {len(lines)}: {lines}"

    @pytest.mark.parametrize("adapter", [f"stack/{name}" for name in EXPECTED_STACKS])
    def test_stack_adapter_listed(self, adapter: str) -> None:
        result = _run_dispatcher("--list-adapters")
        assert adapter in result.stdout

    @pytest.mark.parametrize("adapter", [f"package-manager/{name}" for name in EXPECTED_PMS])
    def test_pm_adapter_listed(self, adapter: str) -> None:
        result = _run_dispatcher("--list-adapters")
        assert adapter in result.stdout

    @pytest.mark.parametrize("adapter", [f"orm/{name}" for name in EXPECTED_ORMS])
    def test_orm_adapter_listed(self, adapter: str) -> None:
        result = _run_dispatcher("--list-adapters")
        assert adapter in result.stdout


# ──────────────────────────────────────────────────────────────────────
# Adapter file structure
# ──────────────────────────────────────────────────────────────────────


class TestAdapterFiles:
    def test_total_adapter_files_count(self, all_adapter_files) -> None:
        files = list(all_adapter_files)
        assert len(files) == 16, f"Expected 16 .sh adapter files, got {len(files)}"

    def test_each_adapter_has_detect_function(self) -> None:
        """Mỗi adapter phải define detect()."""
        for category in ("stack", "package-manager", "orm"):
            for sh in (ADAPTERS_ROOT / category).glob("*.sh"):
                content = sh.read_text(encoding="utf-8")
                assert "detect()" in content, f"Missing detect() in {sh}"

    def test_each_adapter_has_scan_function(self) -> None:
        """Mỗi adapter phải define scan()."""
        for category in ("stack", "package-manager", "orm"):
            for sh in (ADAPTERS_ROOT / category).glob("*.sh"):
                content = sh.read_text(encoding="utf-8")
                assert "scan()" in content, f"Missing scan() in {sh}"

    def test_each_adapter_has_imp000_header(self) -> None:
        """Mỗi adapter phải có comment header IMP-000 Stage 0."""
        for category in ("stack", "package-manager", "orm"):
            for sh in (ADAPTERS_ROOT / category).glob("*.sh"):
                content = sh.read_text(encoding="utf-8")
                assert "IMP-000" in content, f"Missing IMP-000 reference in {sh}"


# ──────────────────────────────────────────────────────────────────────
# --detect behavior
# ──────────────────────────────────────────────────────────────────────


class TestDetect:
    def test_detect_missing_arg_exits_one(self) -> None:
        result = _run_dispatcher("--detect")
        assert result.returncode == 1

    def test_detect_nonexistent_path_exits_two(self, tmp_path: Path) -> None:
        ghost = tmp_path / "does-not-exist"
        result = _run_dispatcher("--detect", str(ghost))
        assert result.returncode == 2

    def test_detect_empty_project_exits_three(self, empty_project: Path) -> None:
        """Empty dir → không adapter match → exit 3."""
        result = _run_dispatcher("--detect", str(empty_project))
        assert result.returncode == 3, f"stdout: {result.stdout}"

    def test_detect_node_project_matches_node_and_npm(self, node_project: Path) -> None:
        result = _run_dispatcher("--detect", str(node_project))
        assert result.returncode == 0, f"stderr: {result.stderr}"
        assert "stack/node" in result.stdout
        assert "package-manager/npm" in result.stdout

    def test_detect_dotnet_project_matches_dotnet_and_efcore(self, dotnet_project: Path) -> None:
        result = _run_dispatcher("--detect", str(dotnet_project))
        assert result.returncode == 0, f"stderr: {result.stderr}"
        assert "stack/dotnet" in result.stdout
        assert "package-manager/nuget" in result.stdout
        assert "orm/ef-core" in result.stdout


# ──────────────────────────────────────────────────────────────────────
# Scan stub
# ──────────────────────────────────────────────────────────────────────


class TestScanStub:
    @pytest.mark.parametrize(
        "adapter_id",
        [
            *(f"stack/{n}" for n in EXPECTED_STACKS),
            *(f"package-manager/{n}" for n in EXPECTED_PMS),
            *(f"orm/{n}" for n in EXPECTED_ORMS),
        ],
    )
    def test_scan_callable_exits_zero(self, adapter_id: str, tmp_path: Path) -> None:
        """Source adapter + invoke scan() → exit 0 + stub message chứa adapter id."""
        adapter_file = ADAPTERS_ROOT / f"{adapter_id}.sh"
        bash_adapter = _to_bash_path(adapter_file)
        bash_tmp = _to_bash_path(tmp_path)
        result = subprocess.run(
            ["bash", "-c", f"source '{bash_adapter}' && scan '{bash_tmp}'"],
            capture_output=True,
            text=True,
            check=False,
        )
        # Smoke test: scan() phải exit 0 trên empty tmp dir (no project files detected).
        # Stub adapters in lịch sử output `[stub] adapter_id ...`; real adapters (orm/prisma,
        # stack/node, package-manager/npm) chỉ output khi tìm thấy project files — empty stdout
        # là valid behavior. Chỉ fail khi exit non-zero (crash).
        assert result.returncode == 0, (
            f"adapter {adapter_id} crashed (exit {result.returncode}): stderr={result.stderr[:300]}"
        )
