"""Incremental Mode — Phase F Task F.3.

Staleness detection + delta classification cho re-scan.

Theo design:
- 02-scan-layers.md §7 Incremental Processing
- 09-thresholds-justification.md §2.3 Incremental Delta Triggers
  + 25% threshold (LEGACY_SCAN_DELTA_RECLASSIFY_PCT / LEGACY_SCAN_DELTA_REEXTRACT_PCT)
  + Rename detection: Levenshtein ≤10% OR matching 3+ function signatures

Core primitives:

1. `detect_changes(project_path, since_ref=None, previous_state=None)` →
   ChangeSet — lat kiem file nao UNCHANGED / MODIFIED / NEW / DELETED / RENAMED.

2. `classify_delta(changes)` → DeltaPlan — tinh auto-upgrade + decide
   per-layer plan (L3 incremental, L4 delta vs full-reclassify, L5 selective
   vs full-reextract).

3. `apply_delta(changes, previous_state, new_files_map)` → next_state —
   pure-function merge helper dung trong orchestrator (chua wire vao SKILL).
"""

from __future__ import annotations

import hashlib
import os
import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Sequence


# ---------------------------------------------------------------------------
# Thresholds + env overrides
# ---------------------------------------------------------------------------

DEFAULT_RECLASSIFY_PCT = 25
DEFAULT_REEXTRACT_PCT = 25

# Rename detection defaults
DEFAULT_LEVENSHTEIN_TOLERANCE_PCT = 10  # content distance ≤10% treated as same
DEFAULT_SIGNATURE_MATCH_MIN = 3         # OR: ≥3 matching function signatures


def _read_env_pct(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if not raw:
        return default
    try:
        v = int(raw)
        if 1 <= v <= 100:
            return v
    except (TypeError, ValueError):
        pass
    return default


def reclassify_threshold_pct() -> int:
    return _read_env_pct("LEGACY_SCAN_DELTA_RECLASSIFY_PCT", DEFAULT_RECLASSIFY_PCT)


def reextract_threshold_pct() -> int:
    return _read_env_pct("LEGACY_SCAN_DELTA_REEXTRACT_PCT", DEFAULT_REEXTRACT_PCT)


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------


@dataclass
class ChangeSet:
    """Ket qua phan loai thay doi tu staleness check."""

    method: str                          # "git_diff" | "mtime" | "full_scan"
    since_ref: str | None = None
    unchanged: list[str] = field(default_factory=list)
    modified: list[str] = field(default_factory=list)
    new: list[str] = field(default_factory=list)
    deleted: list[str] = field(default_factory=list)
    renamed: list[tuple[str, str]] = field(default_factory=list)  # (old, new)

    @property
    def total_previous(self) -> int:
        return len(self.unchanged) + len(self.modified) + len(self.deleted) + len(self.renamed)

    @property
    def total_current(self) -> int:
        return len(self.unchanged) + len(self.modified) + len(self.new) + len(self.renamed)

    @property
    def affected_count(self) -> int:
        """So luong file can re-process (exclude unchanged)."""
        return len(self.modified) + len(self.new) + len(self.deleted) + len(self.renamed)

    def affected_pct(self) -> float:
        """% affected vs total_previous (tranh chia cho 0)."""
        base = self.total_previous or self.total_current
        if not base:
            return 0.0
        return round(100.0 * self.affected_count / base, 2)

    def to_dict(self) -> dict[str, Any]:
        return {
            "method": self.method,
            "since_ref": self.since_ref,
            "unchanged_count": len(self.unchanged),
            "modified_count": len(self.modified),
            "new_count": len(self.new),
            "deleted_count": len(self.deleted),
            "renamed_count": len(self.renamed),
            "affected_pct": self.affected_pct(),
        }


@dataclass
class DeltaPlan:
    """Quyet dinh hanh vi per-layer dua tren ChangeSet."""

    auto_upgrade_to_full: bool
    reason: str
    affected_pct: float
    threshold_pct: int
    l1_plan: str  # "partial_redetect" | "skip"
    l2_plan: str  # "full" | "skip"
    l3_plan: str  # "partial" | "skip"
    l4_plan: str  # "delta" | "full_reclassify" | "skip"
    l5_plan: str  # "selective" | "full_reextract" | "skip"
    l6_plan: str  # "full" (always when something changed)

    def to_dict(self) -> dict[str, Any]:
        return {
            "auto_upgrade_to_full": self.auto_upgrade_to_full,
            "reason": self.reason,
            "affected_pct": self.affected_pct,
            "threshold_pct": self.threshold_pct,
            "layer_plan": {
                "L1": self.l1_plan,
                "L2": self.l2_plan,
                "L3": self.l3_plan,
                "L4": self.l4_plan,
                "L5": self.l5_plan,
                "L6": self.l6_plan,
            },
        }


# ---------------------------------------------------------------------------
# Helpers: hash + signature extraction
# ---------------------------------------------------------------------------


def content_hash(path: Path, *, algo: str = "sha256") -> str:
    """Hash noi dung file — chunked de khong load file lon vao RAM."""
    h = hashlib.new(algo)
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


_SIGNATURE_RE = re.compile(
    r"^\s*(?:export\s+)?(?:async\s+)?(?:function|def|class)\s+([A-Za-z_][A-Za-z0-9_]*)",
    re.MULTILINE,
)


def extract_function_signatures(path: Path, limit: int = 200) -> list[str]:
    """Tim top-level function/class name (ts/js/py). Limit de tranh mega-files."""
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    names = _SIGNATURE_RE.findall(text)
    return names[:limit]


def levenshtein_distance(a: str, b: str, *, max_len: int = 20000) -> int:
    """Classical Levenshtein — truncate neu qua dai (tranh O(n*m) explosion)."""
    if a == b:
        return 0
    if len(a) > max_len:
        a = a[:max_len]
    if len(b) > max_len:
        b = b[:max_len]
    if not a:
        return len(b)
    if not b:
        return len(a)

    prev = list(range(len(b) + 1))
    curr = [0] * (len(b) + 1)
    for i, ca in enumerate(a, 1):
        curr[0] = i
        for j, cb in enumerate(b, 1):
            cost = 0 if ca == cb else 1
            curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
        prev, curr = curr, prev
    return prev[len(b)]


def _is_probable_rename(
    deleted_path: Path,
    new_path: Path,
    *,
    leven_pct: int = DEFAULT_LEVENSHTEIN_TOLERANCE_PCT,
    signature_min: int = DEFAULT_SIGNATURE_MATCH_MIN,
) -> bool:
    """Ap dung rule 2-way tu 09-thresholds §2.3."""
    try:
        old_text = deleted_path.read_text(encoding="utf-8", errors="ignore")
        new_text = new_path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return False

    # Rule 1: content hash bang nhau → exact rename
    if hashlib.sha1(old_text.encode("utf-8")).hexdigest() == hashlib.sha1(
        new_text.encode("utf-8")
    ).hexdigest():
        return True

    # Rule 2: Levenshtein ≤ X%
    max_len = max(len(old_text), len(new_text), 1)
    dist = levenshtein_distance(old_text, new_text)
    if max_len and 100 * dist / max_len <= leven_pct:
        return True

    # Rule 3: ≥ signature_min function/class names matching
    old_sigs = set(_SIGNATURE_RE.findall(old_text))
    new_sigs = set(_SIGNATURE_RE.findall(new_text))
    return len(old_sigs & new_sigs) >= signature_min


# ---------------------------------------------------------------------------
# Git diff detection
# ---------------------------------------------------------------------------


def _is_git_repo(project_path: Path) -> bool:
    try:
        result = subprocess.run(
            ["git", "-C", str(project_path), "rev-parse", "--is-inside-work-tree"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        return result.returncode == 0 and result.stdout.strip() == "true"
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _git_diff_name_status(
    project_path: Path, since_ref: str, head_ref: str = "HEAD"
) -> list[tuple[str, str, str]] | None:
    """Run git diff --name-status with rename detection. Returns list of (status, old, new).

    None neu git call fail → caller fallback sang mtime compare.
    """
    try:
        result = subprocess.run(
            [
                "git",
                "-C",
                str(project_path),
                "diff",
                "--name-status",
                "--find-renames=80",
                since_ref,
                head_ref,
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None

    entries: list[tuple[str, str, str]] = []
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        status = parts[0]
        if status.startswith("R"):
            if len(parts) < 3:
                continue
            entries.append(("R", parts[1], parts[2]))
        elif status.startswith(("A", "M", "D")):
            entries.append((status[0], parts[1], parts[1]))
        # skip T/C/U... neu can them
    return entries


# ---------------------------------------------------------------------------
# Mtime comparison — fallback
# ---------------------------------------------------------------------------


def _walk_source_files(
    project_path: Path,
    *,
    extensions: Sequence[str] = (".ts", ".tsx", ".js", ".jsx", ".py", ".go", ".java", ".rs", ".cs", ".rb"),
    skip_dirs: Sequence[str] = ("node_modules", ".git", "dist", "build", "__pycache__", ".venv", "venv"),
) -> list[Path]:
    """Walk project, tra ve list source files. Skip heavy/generated dirs."""
    files: list[Path] = []
    skip_set = set(skip_dirs)
    for root, dirs, filenames in os.walk(project_path):
        dirs[:] = [d for d in dirs if d not in skip_set]
        for name in filenames:
            if any(name.endswith(ext) for ext in extensions):
                files.append(Path(root) / name)
    return files


def _mtime_map(files: Iterable[Path]) -> dict[str, float]:
    result: dict[str, float] = {}
    for f in files:
        try:
            result[str(f)] = f.stat().st_mtime
        except OSError:
            continue
    return result


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def detect_changes(
    project_path: str | Path,
    *,
    since_ref: str | None = None,
    previous_mtimes: dict[str, float] | None = None,
    previous_content_hashes: dict[str, str] | None = None,
    head_ref: str = "HEAD",
) -> ChangeSet:
    """Detect changes tu lan scan truoc.

    Args:
        project_path: Thu muc du an.
        since_ref: Git ref (e.g. "HEAD~5"). Neu None va repo la git → use "HEAD^".
                   Neu None va khong phai git → fallback mtime.
        previous_mtimes: Map {file_path: mtime} tu lan scan truoc (dung cho mtime mode).
        previous_content_hashes: Map {file_path: sha256_hex} optional — khi co
            thi mtime mode detect rename bang content hash compare (exact match).
            Khong co → deleted + new se stay separate (Git diff mode van handle
            rename qua `--find-renames`).
        head_ref: Git ref hien tai, default HEAD.
    """
    root = Path(project_path)
    if not root.is_dir():
        raise FileNotFoundError(f"Project path not found: {root}")

    use_git = since_ref is not None and _is_git_repo(root)
    if use_git:
        entries = _git_diff_name_status(root, since_ref, head_ref)
        if entries is None:
            # Git failed → fallback mtime
            use_git = False

    if use_git:
        cs = ChangeSet(method="git_diff", since_ref=since_ref)
        for status, old, new in entries:  # type: ignore[union-attr]
            if status == "A":
                cs.new.append(new)
            elif status == "M":
                cs.modified.append(new)
            elif status == "D":
                cs.deleted.append(old)
            elif status == "R":
                cs.renamed.append((old, new))
        # Unchanged khong co trong git diff → de rong (caller co the skip)
        return cs

    # mtime fallback
    current_files = _walk_source_files(root)
    current_map = _mtime_map(current_files)

    cs = ChangeSet(method="mtime", since_ref=since_ref)
    prev = previous_mtimes or {}
    prev_hashes = previous_content_hashes or {}

    prev_keys = set(prev.keys())
    curr_keys = set(current_map.keys())

    new_keys = curr_keys - prev_keys
    deleted_keys = prev_keys - curr_keys
    common = curr_keys & prev_keys

    # Rename detection: chi hoat dong khi caller cung cap previous_content_hashes
    # (vi deleted file khong the read content khi no da bi xoa khoi disk).
    renamed_pairs: list[tuple[str, str]] = []
    matched_deleted: set[str] = set()
    matched_new: set[str] = set()
    if prev_hashes and len(deleted_keys) * len(new_keys) <= 10_000:
        # Build hash map cho new files
        new_hashes: dict[str, str] = {}
        for n_path in new_keys:
            try:
                new_hashes[n_path] = content_hash(Path(n_path))
            except OSError:
                continue
        for d_path in deleted_keys:
            old_hash = prev_hashes.get(d_path)
            if not old_hash:
                continue
            for n_path, n_hash in new_hashes.items():
                if n_path in matched_new:
                    continue
                if n_hash == old_hash:
                    renamed_pairs.append((d_path, n_path))
                    matched_deleted.add(d_path)
                    matched_new.add(n_path)
                    break

    cs.renamed = renamed_pairs
    cs.new = sorted(new_keys - matched_new)
    cs.deleted = sorted(deleted_keys - matched_deleted)

    for key in sorted(common):
        if current_map[key] > prev.get(key, 0):
            cs.modified.append(key)
        else:
            cs.unchanged.append(key)
    return cs


def classify_delta(
    changes: ChangeSet,
    *,
    reclassify_pct_override: int | None = None,
    reextract_pct_override: int | None = None,
) -> DeltaPlan:
    """Tinh toan per-layer plan tu ChangeSet.

    Threshold rules (09-thresholds §2.3):
    - affected_pct > reclassify_threshold → L4 auto-upgrade full re-classify.
    - affected_pct > reextract_threshold → L5 auto-upgrade full re-extract.
    - renamed.length > 0 → L5 force full_reextract cho affected modules.
    """
    affected_pct = changes.affected_pct()
    reclassify_pct = reclassify_pct_override if reclassify_pct_override is not None else reclassify_threshold_pct()
    reextract_pct = reextract_pct_override if reextract_pct_override is not None else reextract_threshold_pct()
    threshold = max(reclassify_pct, reextract_pct)

    has_changes = changes.affected_count > 0

    # Default per layer theo 02-scan-layers.md §7 incremental table
    l1 = "partial_redetect" if has_changes else "skip"
    l2 = "full" if has_changes else "skip"
    l3 = "partial" if has_changes else "skip"
    l4 = "delta" if has_changes else "skip"
    l5 = "selective" if has_changes else "skip"
    l6 = "full" if has_changes else "skip"

    auto_upgrade = False
    reasons: list[str] = []

    if affected_pct > reclassify_pct:
        l4 = "full_reclassify"
        auto_upgrade = True
        reasons.append(f"affected {affected_pct}% > L4 threshold {reclassify_pct}%")

    if affected_pct > reextract_pct or changes.renamed:
        l5 = "full_reextract"
        if changes.renamed:
            reasons.append(f"{len(changes.renamed)} rename(s) detected — delta merge unreliable")
        if affected_pct > reextract_pct:
            auto_upgrade = True
            reasons.append(f"affected {affected_pct}% > L5 threshold {reextract_pct}%")

    reason = "; ".join(reasons) if reasons else "within delta thresholds"

    return DeltaPlan(
        auto_upgrade_to_full=auto_upgrade,
        reason=reason,
        affected_pct=affected_pct,
        threshold_pct=threshold,
        l1_plan=l1,
        l2_plan=l2,
        l3_plan=l3,
        l4_plan=l4,
        l5_plan=l5,
        l6_plan=l6,
    )


def apply_delta(
    changes: ChangeSet,
    previous_state: dict[str, Any],
    *,
    merge_rules: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Apply delta to L3/L4/L5 outputs.

    Pure function. Merge rules (tu 02-scan-layers.md §7):
    - UNCHANGED → keep cache
    - MODIFIED → re-process at L3, mark L4/L5 delta
    - NEW → add to L3, mark L4/L5
    - DELETED → remove, mark affected L4/L5
    - RENAMED → DELETE+ADD, full re-classify affected module

    Returns: next_state dict voi 3 keys: L3, L4, L5 — moi ben chi ra files can re-process.
    """
    del merge_rules  # reserved cho extension
    l3_state = dict(previous_state.get("L3", {}))
    l4_state = dict(previous_state.get("L4", {}))
    l5_state = dict(previous_state.get("L5", {}))

    kept_l3: dict[str, Any] = dict(l3_state.get("files", {}))
    for f in changes.deleted + [old for old, _ in changes.renamed]:
        kept_l3.pop(f, None)

    l3_state["files"] = kept_l3
    l3_state["pending_reprocess"] = sorted(
        changes.modified + changes.new + [new for _, new in changes.renamed]
    )

    l4_state["pending_reclassify"] = l3_state["pending_reprocess"][:]
    l4_state["invalidated_modules"] = sorted({
        f for f in changes.deleted + [old for old, _ in changes.renamed]
    })

    l5_state["pending_reextract_files"] = l3_state["pending_reprocess"][:]
    l5_state["full_reextract_due_to_renames"] = bool(changes.renamed)

    return {"L3": l3_state, "L4": l4_state, "L5": l5_state}


__all__ = [
    "DEFAULT_RECLASSIFY_PCT",
    "DEFAULT_REEXTRACT_PCT",
    "DEFAULT_LEVENSHTEIN_TOLERANCE_PCT",
    "DEFAULT_SIGNATURE_MATCH_MIN",
    "ChangeSet",
    "DeltaPlan",
    "reclassify_threshold_pct",
    "reextract_threshold_pct",
    "content_hash",
    "extract_function_signatures",
    "levenshtein_distance",
    "detect_changes",
    "classify_delta",
    "apply_delta",
]
