"""Tests cho incremental module — Phase F Task F.3.

Coverage:
- Threshold env resolution + defaults.
- ChangeSet percentages.
- mtime-based change detection.
- Rename detection (exact hash, Levenshtein, function signature overlap).
- classify_delta auto-upgrade rules (L4 > 25%, L5 > 25% or renames).
- apply_delta pure merge function.
- Git diff branch — guarded (chi test parse shape khi git khong available).
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path
from unittest.mock import patch

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import incremental as inc  # noqa: E402


# ---------------------------------------------------------------------------
# Thresholds + env
# ---------------------------------------------------------------------------


class TestThresholds:
    def test_default_reclassify(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("LEGACY_SCAN_DELTA_RECLASSIFY_PCT", None)
            assert inc.reclassify_threshold_pct() == 25

    def test_default_reextract(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("LEGACY_SCAN_DELTA_REEXTRACT_PCT", None)
            assert inc.reextract_threshold_pct() == 25

    def test_env_override(self) -> None:
        with patch.dict(os.environ, {"LEGACY_SCAN_DELTA_RECLASSIFY_PCT": "35"}):
            assert inc.reclassify_threshold_pct() == 35

    def test_env_invalid_falls_back(self) -> None:
        with patch.dict(os.environ, {"LEGACY_SCAN_DELTA_RECLASSIFY_PCT": "not-a-number"}):
            assert inc.reclassify_threshold_pct() == 25

    def test_env_out_of_range_falls_back(self) -> None:
        with patch.dict(os.environ, {"LEGACY_SCAN_DELTA_RECLASSIFY_PCT": "150"}):
            assert inc.reclassify_threshold_pct() == 25


# ---------------------------------------------------------------------------
# ChangeSet stats
# ---------------------------------------------------------------------------


class TestChangeSetStats:
    def test_affected_pct_basic(self) -> None:
        cs = inc.ChangeSet(
            method="mtime",
            unchanged=["a", "b", "c", "d"],
            modified=["e"],
            new=[],
            deleted=[],
        )
        # 1 modified / 5 total = 20%
        assert cs.affected_pct() == 20.0

    def test_affected_pct_with_renames(self) -> None:
        cs = inc.ChangeSet(
            method="mtime",
            unchanged=["a"],
            modified=[],
            new=[],
            deleted=[],
            renamed=[("old", "new")],
        )
        # 1 rename / 2 total = 50%
        assert cs.affected_pct() == 50.0

    def test_affected_pct_empty(self) -> None:
        cs = inc.ChangeSet(method="mtime")
        assert cs.affected_pct() == 0.0

    def test_to_dict_shape(self) -> None:
        cs = inc.ChangeSet(method="git_diff", since_ref="HEAD~5", modified=["a"], new=["b"])
        d = cs.to_dict()
        assert d["method"] == "git_diff"
        assert d["since_ref"] == "HEAD~5"
        assert d["modified_count"] == 1
        assert d["new_count"] == 1


# ---------------------------------------------------------------------------
# Levenshtein distance
# ---------------------------------------------------------------------------


class TestLevenshtein:
    def test_identical_strings(self) -> None:
        assert inc.levenshtein_distance("hello", "hello") == 0

    def test_single_edit(self) -> None:
        assert inc.levenshtein_distance("hello", "hallo") == 1

    def test_insert(self) -> None:
        assert inc.levenshtein_distance("abc", "abcd") == 1

    def test_delete(self) -> None:
        assert inc.levenshtein_distance("abcd", "abc") == 1

    def test_empty(self) -> None:
        assert inc.levenshtein_distance("", "abc") == 3
        assert inc.levenshtein_distance("abc", "") == 3
        assert inc.levenshtein_distance("", "") == 0

    def test_truncation_long_strings(self) -> None:
        a = "x" * 30000
        b = "y" * 30000
        # Truncated to 20000 per string, but still consistent
        d = inc.levenshtein_distance(a, b, max_len=5000)
        assert d > 0


# ---------------------------------------------------------------------------
# Function signature extraction
# ---------------------------------------------------------------------------


class TestSignatureExtraction:
    def test_typescript_exports(self, tmp_path: Path) -> None:
        f = tmp_path / "svc.ts"
        f.write_text(
            "export function getCustomer() {}\n"
            "export async function fetchOrders() {}\n"
            "export class CustomerService {}\n",
            encoding="utf-8",
        )
        sigs = inc.extract_function_signatures(f)
        assert set(sigs) == {"getCustomer", "fetchOrders", "CustomerService"}

    def test_python_defs(self, tmp_path: Path) -> None:
        f = tmp_path / "module.py"
        f.write_text(
            "def compute_total():\n    pass\n"
            "class Invoice:\n    pass\n",
            encoding="utf-8",
        )
        sigs = inc.extract_function_signatures(f)
        assert set(sigs) == {"compute_total", "Invoice"}

    def test_missing_file(self, tmp_path: Path) -> None:
        assert inc.extract_function_signatures(tmp_path / "nope.py") == []


# ---------------------------------------------------------------------------
# Rename detection private helper
# ---------------------------------------------------------------------------


class TestRenameDetection:
    def test_exact_hash_match(self, tmp_path: Path) -> None:
        content = "function foo() {}\n"
        a = tmp_path / "a.ts"
        b = tmp_path / "b.ts"
        a.write_text(content, encoding="utf-8")
        b.write_text(content, encoding="utf-8")
        assert inc._is_probable_rename(a, b) is True

    def test_levenshtein_within_tolerance(self, tmp_path: Path) -> None:
        a = tmp_path / "a.ts"
        b = tmp_path / "b.ts"
        base = "x" * 1000
        a.write_text(base, encoding="utf-8")
        b.write_text(base + "yy", encoding="utf-8")  # 2/1002 ~ 0.2% edits
        assert inc._is_probable_rename(a, b, leven_pct=10) is True

    def test_levenshtein_over_tolerance(self, tmp_path: Path) -> None:
        a = tmp_path / "a.ts"
        b = tmp_path / "b.ts"
        a.write_text("hello world " * 10, encoding="utf-8")
        b.write_text("xxxxxxxxx yyy " * 10, encoding="utf-8")
        # Force smaller thresholds to reject:
        assert (
            inc._is_probable_rename(a, b, leven_pct=1, signature_min=10) is False
        )

    def test_signature_overlap_match(self, tmp_path: Path) -> None:
        a = tmp_path / "a.ts"
        b = tmp_path / "b.ts"
        # Different wrapper text, same 3 functions → signature match trumps Leven distance
        a.write_text(
            "export function alpha() {} \nexport function beta(){}\nexport function gamma(){}\n"
            + "x" * 5000,
            encoding="utf-8",
        )
        b.write_text(
            "// refactor: moved\nexport function alpha(){}\nexport function beta(){}\nexport function gamma(){}\n"
            + "y" * 5000,
            encoding="utf-8",
        )
        assert inc._is_probable_rename(a, b, leven_pct=1, signature_min=3) is True

    def test_no_match(self, tmp_path: Path) -> None:
        a = tmp_path / "a.ts"
        b = tmp_path / "b.ts"
        a.write_text("function foo() {}", encoding="utf-8")
        b.write_text("def totally_different(): pass", encoding="utf-8")
        assert (
            inc._is_probable_rename(a, b, leven_pct=1, signature_min=3) is False
        )


# ---------------------------------------------------------------------------
# detect_changes — mtime path (default when no git)
# ---------------------------------------------------------------------------


class TestDetectChangesMtime:
    def _make_project(self, tmp_path: Path) -> Path:
        root = tmp_path / "proj"
        (root / "src").mkdir(parents=True)
        (root / "src" / "a.ts").write_text("export function a(){}", encoding="utf-8")
        (root / "src" / "b.ts").write_text("export function b(){}", encoding="utf-8")
        return root

    def test_no_previous_state_yields_all_new(self, tmp_path: Path) -> None:
        root = self._make_project(tmp_path)
        # Disable git detection so we stay on mtime path
        with patch.object(inc, "_is_git_repo", return_value=False):
            cs = inc.detect_changes(root, since_ref=None, previous_mtimes={})
        assert cs.method == "mtime"
        assert len(cs.new) == 2
        assert cs.modified == []

    def test_unchanged_files(self, tmp_path: Path) -> None:
        root = self._make_project(tmp_path)
        files = [root / "src" / "a.ts", root / "src" / "b.ts"]
        prev = {str(f): f.stat().st_mtime for f in files}
        with patch.object(inc, "_is_git_repo", return_value=False):
            cs = inc.detect_changes(root, previous_mtimes=prev)
        assert sorted(cs.unchanged) == sorted(str(f) for f in files)
        assert cs.modified == []
        assert cs.new == []

    def test_modified_detected(self, tmp_path: Path) -> None:
        root = self._make_project(tmp_path)
        files = [root / "src" / "a.ts", root / "src" / "b.ts"]
        prev = {str(f): f.stat().st_mtime - 100 for f in files}  # lien ke qua khu
        with patch.object(inc, "_is_git_repo", return_value=False):
            cs = inc.detect_changes(root, previous_mtimes=prev)
        assert len(cs.modified) == 2

    def test_new_file_detected(self, tmp_path: Path) -> None:
        root = self._make_project(tmp_path)
        old_a = root / "src" / "a.ts"
        prev = {str(old_a): old_a.stat().st_mtime}
        # Add new file
        (root / "src" / "c.ts").write_text("export function c(){}", encoding="utf-8")
        with patch.object(inc, "_is_git_repo", return_value=False):
            cs = inc.detect_changes(root, previous_mtimes=prev)
        new_files = [f for f in cs.new if f.endswith(("b.ts", "c.ts"))]
        assert len(new_files) == 2

    def test_deleted_file_detected(self, tmp_path: Path) -> None:
        root = self._make_project(tmp_path)
        files = [root / "src" / "a.ts", root / "src" / "b.ts"]
        prev = {str(f): f.stat().st_mtime for f in files}
        # Add phantom file vao prev (khong co trong actual)
        prev[str(root / "src" / "ghost.ts")] = time.time()
        with patch.object(inc, "_is_git_repo", return_value=False):
            cs = inc.detect_changes(root, previous_mtimes=prev)
        assert any(f.endswith("ghost.ts") for f in cs.deleted)

    def test_project_path_must_exist(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError):
            inc.detect_changes(tmp_path / "does-not-exist")

    def test_rename_detected_with_content_hashes(self, tmp_path: Path) -> None:
        """Mtime mode detect rename khi previous_content_hashes cung cap."""
        root = tmp_path / "proj"
        (root / "src").mkdir(parents=True)
        content = "export function renamed(){ return 42; }\n" + "x" * 200
        # Phase 1: a.ts exists — record mtime + hash
        old_path = root / "src" / "a.ts"
        old_path.write_text(content, encoding="utf-8")
        prev_mtimes = {str(old_path): old_path.stat().st_mtime}
        prev_hashes = {str(old_path): inc.content_hash(old_path)}
        # Phase 2: a.ts deleted, b.ts created with same content
        old_path.unlink()
        new_path = root / "src" / "b.ts"
        new_path.write_text(content, encoding="utf-8")
        with patch.object(inc, "_is_git_repo", return_value=False):
            cs = inc.detect_changes(
                root,
                previous_mtimes=prev_mtimes,
                previous_content_hashes=prev_hashes,
            )
        assert len(cs.renamed) == 1
        assert cs.renamed[0][0].endswith("a.ts")
        assert cs.renamed[0][1].endswith("b.ts")
        assert cs.new == []
        assert cs.deleted == []

    def test_rename_without_hashes_stays_as_delete_plus_add(self, tmp_path: Path) -> None:
        """Khong co previous_content_hashes → deleted va new tach rieng (by design)."""
        root = tmp_path / "proj"
        (root / "src").mkdir(parents=True)
        old_path = root / "src" / "a.ts"
        old_path.write_text("content", encoding="utf-8")
        prev_mtimes = {str(old_path): old_path.stat().st_mtime}
        old_path.unlink()
        (root / "src" / "b.ts").write_text("content", encoding="utf-8")
        with patch.object(inc, "_is_git_repo", return_value=False):
            cs = inc.detect_changes(root, previous_mtimes=prev_mtimes)
        assert cs.renamed == []
        assert len(cs.deleted) == 1
        assert len(cs.new) == 1


# ---------------------------------------------------------------------------
# detect_changes — git_diff path
# ---------------------------------------------------------------------------


class TestDetectChangesGit:
    def test_git_diff_parse(self, tmp_path: Path) -> None:
        root = tmp_path / "proj"
        root.mkdir()
        with patch.object(inc, "_is_git_repo", return_value=True), patch.object(
            inc,
            "_git_diff_name_status",
            return_value=[
                ("M", "src/a.ts", "src/a.ts"),
                ("A", "src/c.ts", "src/c.ts"),
                ("D", "src/x.ts", "src/x.ts"),
                ("R", "src/old.ts", "src/new.ts"),
            ],
        ):
            cs = inc.detect_changes(root, since_ref="HEAD~3")
        assert cs.method == "git_diff"
        assert cs.since_ref == "HEAD~3"
        assert "src/a.ts" in cs.modified
        assert "src/c.ts" in cs.new
        assert "src/x.ts" in cs.deleted
        assert ("src/old.ts", "src/new.ts") in cs.renamed

    def test_git_fallback_to_mtime(self, tmp_path: Path) -> None:
        root = tmp_path / "proj"
        (root / "src").mkdir(parents=True)
        (root / "src" / "a.ts").write_text("export{}", encoding="utf-8")
        with patch.object(inc, "_is_git_repo", return_value=True), patch.object(
            inc, "_git_diff_name_status", return_value=None
        ):
            cs = inc.detect_changes(root, since_ref="HEAD~3", previous_mtimes={})
        assert cs.method == "mtime"
        assert len(cs.new) >= 1


# ---------------------------------------------------------------------------
# classify_delta thresholds
# ---------------------------------------------------------------------------


class TestClassifyDelta:
    def test_no_changes(self) -> None:
        cs = inc.ChangeSet(method="mtime", unchanged=["a", "b"])
        plan = inc.classify_delta(cs)
        assert plan.auto_upgrade_to_full is False
        assert plan.l4_plan == "skip"
        assert plan.l5_plan == "skip"

    def test_small_change_below_threshold(self) -> None:
        cs = inc.ChangeSet(
            method="mtime",
            unchanged=["a"] * 90,
            modified=["b"] * 5,
            new=["c"] * 5,
        )
        # 10/100 = 10% ≤ 25%
        plan = inc.classify_delta(cs)
        assert plan.auto_upgrade_to_full is False
        assert plan.l4_plan == "delta"
        assert plan.l5_plan == "selective"

    def test_above_reclassify_threshold_triggers_full_l4(self) -> None:
        cs = inc.ChangeSet(
            method="mtime",
            unchanged=["a"] * 60,
            modified=["b"] * 30,
            new=["c"] * 10,
        )
        # 40/100 = 40% > 25%
        plan = inc.classify_delta(cs)
        assert plan.auto_upgrade_to_full is True
        assert plan.l4_plan == "full_reclassify"
        assert plan.l5_plan == "full_reextract"
        assert "40" in plan.reason or "threshold" in plan.reason

    def test_rename_triggers_l5_full_reextract(self) -> None:
        cs = inc.ChangeSet(
            method="mtime",
            unchanged=["a"] * 95,
            renamed=[("old", "new")] * 1,  # only 1% affected but has rename
        )
        plan = inc.classify_delta(cs)
        assert plan.l5_plan == "full_reextract"
        assert "rename" in plan.reason.lower()

    def test_custom_thresholds_override(self) -> None:
        cs = inc.ChangeSet(
            method="mtime", unchanged=["a"] * 80, modified=["b"] * 20
        )
        # 20% — under default 25% but over custom 10%
        plan = inc.classify_delta(cs, reclassify_pct_override=10)
        assert plan.l4_plan == "full_reclassify"

    def test_dict_shape(self) -> None:
        cs = inc.ChangeSet(method="mtime", modified=["a"])
        plan = inc.classify_delta(cs)
        d = plan.to_dict()
        assert set(d["layer_plan"].keys()) == {"L1", "L2", "L3", "L4", "L5", "L6"}


# ---------------------------------------------------------------------------
# apply_delta
# ---------------------------------------------------------------------------


class TestApplyDelta:
    def test_preserves_unchanged_and_removes_deleted(self) -> None:
        cs = inc.ChangeSet(
            method="mtime",
            unchanged=["keep.ts"],
            modified=["mod.ts"],
            new=["new.ts"],
            deleted=["gone.ts"],
        )
        prev_state = {
            "L3": {"files": {"keep.ts": 1, "mod.ts": 2, "gone.ts": 3}},
        }
        result = inc.apply_delta(cs, prev_state)
        assert "keep.ts" in result["L3"]["files"]
        assert "gone.ts" not in result["L3"]["files"]
        assert "mod.ts" in result["L3"]["pending_reprocess"]
        assert "new.ts" in result["L3"]["pending_reprocess"]

    def test_rename_triggers_full_reextract_flag(self) -> None:
        cs = inc.ChangeSet(
            method="mtime",
            renamed=[("old.ts", "new.ts")],
        )
        prev_state = {"L3": {"files": {"old.ts": 1}}}
        result = inc.apply_delta(cs, prev_state)
        assert result["L5"]["full_reextract_due_to_renames"] is True
        assert "new.ts" in result["L3"]["pending_reprocess"]
        assert "old.ts" not in result["L3"]["files"]


# ---------------------------------------------------------------------------
# Acceptance criteria from phase-F plan
# ---------------------------------------------------------------------------


class TestAcceptanceCriteria:
    def test_staleness_check_works_via_mtime(self, tmp_path: Path) -> None:
        """AC: Staleness check works (mtime)."""
        root = tmp_path / "proj"
        (root / "src").mkdir(parents=True)
        (root / "src" / "a.ts").write_text("x", encoding="utf-8")
        with patch.object(inc, "_is_git_repo", return_value=False):
            cs = inc.detect_changes(root, previous_mtimes={})
        assert len(cs.new) >= 1

    def test_delta_respects_threshold(self) -> None:
        """AC: Delta processing respects thresholds — 25% auto-upgrade."""
        cs = inc.ChangeSet(
            method="mtime",
            unchanged=["a"] * 70,
            modified=["b"] * 30,
        )
        plan = inc.classify_delta(cs)
        assert plan.auto_upgrade_to_full is True

    def test_rename_detection_levenshtein_or_signature(self, tmp_path: Path) -> None:
        """AC: Rename detection via Levenshtein + function signature."""
        a = tmp_path / "a.ts"
        b = tmp_path / "b.ts"
        a.write_text(
            "export function alpha(){}\nexport function beta(){}\nexport function gamma(){}\n",
            encoding="utf-8",
        )
        b.write_text(
            "export function alpha(){}\nexport function beta(){}\nexport function gamma(){}\n",
            encoding="utf-8",
        )
        assert inc._is_probable_rename(a, b) is True

    def test_re_scan_with_20pct_changes_stays_incremental(self) -> None:
        """AC: Re-scan voi 20% changes → khong auto-upgrade (plan should be delta/selective).

        Performance claim '≤ 30% time' la Phase I benchmark — o day ta verify
        rang logic khong bi auto-upgrade thanh full (chinh la dieu quyet dinh
        thoi gian).
        """
        cs = inc.ChangeSet(
            method="mtime",
            unchanged=["a"] * 80,
            modified=["b"] * 15,
            new=["c"] * 5,
        )
        # 20% affected
        plan = inc.classify_delta(cs)
        assert plan.auto_upgrade_to_full is False
        assert plan.l4_plan == "delta"
        assert plan.l5_plan == "selective"
