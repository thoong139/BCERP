#!/usr/bin/env python3
"""signal_bus.py — Signal → Issue normalization + dedup + emit.

Vai trò:
    Nhận Signal thô từ các QD lane, validate evidence (ADR-09), dedup theo
    (dimension, file_path, line_range, symbol), merge thành Issue schema v2,
    emit vào $SESSION_DIR/issue-registry.json. Chạy POST-GATE T1-T4 trước khi commit.

Registry role: NONE. Không ghi req-registry.json.

Tham chiếu:
    - ADR-02: utility module
    - ADR-04: Issue v2 extend v1 (non-breaking)
    - ADR-09: evidence bắt buộc
    - ADR-22 rule 2 (verify ripple — ở fix-execute), rule 4 (CDG secrets), rule 5 (POST-GATE T1-T4)
    - CORE-012: POST-GATE schema validation
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

VALID_DIMENSIONS: frozenset[str] = frozenset(
    {"QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"}
)

VALID_EVIDENCE_KINDS: frozenset[str] = frozenset(
    {
        "code_snippet",
        "screenshot_path",
        "log_excerpt",
        "stacktrace",
        "spec_ref",
        "test_failure_ref",
    }
)

MIN_EVIDENCE_LENGTH: dict[str, int] = {
    "code_snippet": 10,
    "log_excerpt": 20,
    "stacktrace": 50,
}

# ADR-22 rule 4: hint patterns cho "secrets in code"
SECRETS_HINT_PATTERNS: tuple[str, ...] = (
    "api_key",
    "apikey",
    "secret",
    "password",
    "credential",
    "bearer ",
    "private_key",
    "PRIVATE KEY",
)

SIGNAL_SCHEMA_ID: str = "signal-v2"
ISSUE_SCHEMA_ID: str = "issue-v2"
REGISTRY_SCHEMA_ID: str = "issue-registry-v2"

PROBE_ID_PATTERN: re.Pattern[str] = re.compile(r"^P-QD(1[0-1]|[1-9])-[a-z0-9-]+$")
ISSUE_ID_PATTERN: re.Pattern[str] = re.compile(r"^ISS-[0-9]{8}-[0-9]{3}$")
DEDUP_KEY_PATTERN: re.Pattern[str] = re.compile(r"^[a-f0-9]{64}$")


# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass
class Signal:
    """Finding thô từ probe (input của Signal Bus)."""

    probe_id: str
    probe_version: str
    emitted_at: str
    lane: str
    dimension_id: str
    target: dict[str, Any]
    description: str
    evidence: dict[str, Any]
    suggested_severity: str = "medium"
    dedup_hints: list[str] = field(default_factory=list)

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Signal":
        """Build Signal từ dict, validate required fields + dimension.

        Raises:
            ValueError: thiếu field, dimension không hợp lệ, hoặc probe_id format sai.
        """
        required = (
            "probe_id",
            "probe_version",
            "emitted_at",
            "lane",
            "dimension_id",
            "target",
            "description",
            "evidence",
        )
        missing = [k for k in required if k not in d]
        if missing:
            raise ValueError(
                f"Signal.from_dict: thiếu required field(s): {missing}"
            )

        dim = d["dimension_id"]
        if dim not in VALID_DIMENSIONS:
            raise ValueError(
                f"Signal.from_dict: dimension_id='{dim}' không hợp lệ "
                f"(cho phép: {sorted(VALID_DIMENSIONS)})"
            )

        probe_id = str(d["probe_id"])
        if not PROBE_ID_PATTERN.match(probe_id):
            raise ValueError(
                f"Signal.from_dict: probe_id='{probe_id}' không match P-QDx-<slug> (x ∈ {{1..11}})"
            )

        target = d["target"]
        if not isinstance(target, dict):
            raise ValueError("Signal.from_dict: target phải là object")
        if "kind" not in target:
            raise ValueError("Signal.from_dict: target.kind bắt buộc")

        evidence = d["evidence"]
        if not isinstance(evidence, dict):
            raise ValueError("Signal.from_dict: evidence phải là object")

        description = str(d["description"])
        if len(description) < 10:
            raise ValueError(
                "Signal.from_dict: description phải >= 10 ký tự "
                f"(nhận {len(description)})"
            )

        return cls(
            probe_id=probe_id,
            probe_version=str(d["probe_version"]),
            emitted_at=str(d["emitted_at"]),
            lane=str(d["lane"]),
            dimension_id=dim,
            target=dict(target),
            description=description,
            evidence=dict(evidence),
            suggested_severity=str(d.get("suggested_severity", "medium")),
            dedup_hints=list(d.get("dedup_hints", [])),
        )


@dataclass
class Issue:
    """Issue normalized (output của Signal Bus, input cho Triage)."""

    issue_id: str
    created_at: str
    dimensions: list[str]
    target: dict[str, Any]
    title: str
    description_md: str
    probe_sources: list[dict[str, str]]
    evidence: list[dict[str, Any]]
    dedup_key: str
    severity: str | None = None
    fixability: str | None = None
    triage_status: str = "pending"
    dedup_merged_signals: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        """Serialize theo schema issue-v2."""
        return {
            "$schema": ISSUE_SCHEMA_ID,
            "issue_id": self.issue_id,
            "created_at": self.created_at,
            "dimensions": list(self.dimensions),
            "target": dict(self.target),
            "title": self.title,
            "description_md": self.description_md,
            "probe_sources": list(self.probe_sources),
            "evidence": list(self.evidence),
            "dedup_key": self.dedup_key,
            "severity": self.severity,
            "fixability": self.fixability,
            "triage_status": self.triage_status,
            "dedup_merged_signals": list(self.dedup_merged_signals),
        }


# ──────────────────────────────────────────────────────────────────────
# 1. Evidence validation (ADR-09)
# ──────────────────────────────────────────────────────────────────────


def validate_evidence(signal: Signal) -> tuple[bool, str | None]:
    """ADR-09: Signal phải có ≥1 evidence field non-empty + đúng min length.

    Logic:
        - Duyệt evidence dict, chỉ xét kind ∈ VALID_EVIDENCE_KINDS.
        - Field có value (string non-empty): kiểm tra MIN_EVIDENCE_LENGTH nếu có.
        - Ít nhất 1 field pass → ok.

    Returns:
        (True, None) nếu ít nhất 1 evidence hợp lệ.
        (False, reason) nếu không có evidence hợp lệ.
    """
    found_valid = False
    for kind, value in signal.evidence.items():
        if kind not in VALID_EVIDENCE_KINDS:
            continue
        if value is None:
            continue
        if not isinstance(value, str):
            continue
        value_str = value.strip()
        if not value_str:
            continue
        min_len = MIN_EVIDENCE_LENGTH.get(kind)
        if min_len is not None and len(value_str) < min_len:
            continue
        found_valid = True
        break

    if not found_valid:
        return (
            False,
            "missing-evidence: không có evidence field nào non-empty đủ min length "
            f"(ADR-09). evidence keys={list(signal.evidence.keys())}",
        )
    return (True, None)


# ──────────────────────────────────────────────────────────────────────
# 2. Dedup key computation
# ──────────────────────────────────────────────────────────────────────


def compute_dedup_key(signal: Signal) -> str:
    """Sinh dedup key theo spec README.md §3.

    Format: sha256(dimension|file_path|line_range|symbol)

    Components:
        - dimension: signal.dimension_id (required).
        - file_path: target.file_path hoặc target.url (fallback cho runtime target).
        - line_range: "<start>-<end>" từ target.line_range, hoặc "0-0" nếu không có.
        - symbol: target.symbol hoặc "".
    """
    dimension = signal.dimension_id
    target = signal.target

    file_path = str(target.get("file_path") or target.get("url") or target.get("selector") or "")

    line_range_raw = target.get("line_range")
    if (
        isinstance(line_range_raw, list)
        and len(line_range_raw) == 2
        and all(isinstance(x, int) for x in line_range_raw)
    ):
        line_range = f"{line_range_raw[0]}-{line_range_raw[1]}"
    else:
        line_range = "0-0"

    symbol = str(target.get("symbol") or "")

    message = f"{dimension}|{file_path}|{line_range}|{symbol}"
    return hashlib.sha256(message.encode("utf-8")).hexdigest()


# ──────────────────────────────────────────────────────────────────────
# 3. Secrets detection (ADR-22 rule 4)
# ──────────────────────────────────────────────────────────────────────


def detect_secrets_hint(signal: Signal) -> bool:
    """Trả True nếu evidence.code_snippet / log_excerpt chứa keyword hint secret.

    Case-insensitive match với SECRETS_HINT_PATTERNS.
    """
    for kind in ("code_snippet", "log_excerpt"):
        value = signal.evidence.get(kind)
        if not isinstance(value, str) or not value:
            continue
        haystack = value.lower()
        for pattern in SECRETS_HINT_PATTERNS:
            if pattern.lower() in haystack:
                return True
    return False


# ──────────────────────────────────────────────────────────────────────
# 4. Normalize Signal → Issue
# ──────────────────────────────────────────────────────────────────────


def _title_from_signal(signal: Signal) -> str:
    """Tạo title ≥10 ký tự từ description (cắt đầu dòng)."""
    first_line = signal.description.strip().splitlines()[0] if signal.description else ""
    if len(first_line) > 200:
        first_line = first_line[:197] + "..."
    if len(first_line) < 10:
        # Pad để đạt min length — hiếm khi xảy ra vì validate_evidence chặn short desc
        first_line = f"{signal.dimension_id} — {first_line or 'bug phát hiện'}"
    return first_line


def _evidence_dict_to_list(
    evidence: dict[str, Any], source_signal_id: str
) -> list[dict[str, Any]]:
    """Convert evidence dict (Signal schema) → evidence list (Issue schema)."""
    out: list[dict[str, Any]] = []
    for kind in sorted(VALID_EVIDENCE_KINDS):
        value = evidence.get(kind)
        if isinstance(value, str) and value.strip():
            out.append(
                {
                    "kind": kind,
                    "content": value,
                    "source_signal_id": source_signal_id,
                }
            )
    return out


def normalize(signal: Signal, issue_id: str) -> Issue:
    """Tạo Issue mới từ 1 Signal (chưa merge với existing)."""
    if not ISSUE_ID_PATTERN.match(issue_id):
        raise ValueError(
            f"normalize: issue_id='{issue_id}' không match ISS-YYYYMMDD-NNN"
        )

    dedup_key = compute_dedup_key(signal)
    secrets_hit = detect_secrets_hint(signal)
    triage_status = "cdg_required" if secrets_hit else "pending"

    title = _title_from_signal(signal)
    description_md = signal.description

    probe_source = {
        "probe_id": signal.probe_id,
        "probe_version": signal.probe_version,
    }
    evidence_list = _evidence_dict_to_list(signal.evidence, signal.probe_id)

    return Issue(
        issue_id=issue_id,
        created_at=datetime.now(timezone.utc).isoformat(),
        dimensions=[signal.dimension_id],
        target=dict(signal.target),
        title=title,
        description_md=description_md,
        probe_sources=[probe_source],
        evidence=evidence_list,
        dedup_key=dedup_key,
        severity=None,
        fixability=None,
        triage_status=triage_status,
        dedup_merged_signals=[signal.probe_id],
    )


# ──────────────────────────────────────────────────────────────────────
# 5. Merge vào issue-registry existing
# ──────────────────────────────────────────────────────────────────────


def merge_or_append(
    new_issue: Issue, existing: list[Issue]
) -> tuple[list[Issue], str]:
    """Nếu new_issue.dedup_key == existing[i].dedup_key → merge vào existing[i].
    Nếu không → append new_issue.

    Merge logic:
        - probe_sources: union (dedup theo probe_id)
        - evidence: append (không dedup, cho phép nhiều evidence từ nhiều Signal)
        - dimensions: union (giữ thứ tự ổn định)
        - triage_status: escalate (cdg_required thắng pending)
        - title: giữ của existing (first-write wins)

    Returns:
        (merged_list, action) — action ∈ {"merged", "appended"}.
    """
    for idx, existing_issue in enumerate(existing):
        if existing_issue.dedup_key == new_issue.dedup_key:
            # Merge
            merged = Issue(
                issue_id=existing_issue.issue_id,
                created_at=existing_issue.created_at,
                dimensions=_union_preserve_order(
                    existing_issue.dimensions, new_issue.dimensions
                ),
                target=existing_issue.target,
                title=existing_issue.title,
                description_md=existing_issue.description_md,
                probe_sources=_union_probe_sources(
                    existing_issue.probe_sources, new_issue.probe_sources
                ),
                evidence=existing_issue.evidence + new_issue.evidence,
                dedup_key=existing_issue.dedup_key,
                severity=existing_issue.severity,
                fixability=existing_issue.fixability,
                triage_status=_escalate_triage(
                    existing_issue.triage_status, new_issue.triage_status
                ),
                dedup_merged_signals=_union_preserve_order(
                    existing_issue.dedup_merged_signals,
                    new_issue.dedup_merged_signals,
                ),
            )
            new_list = list(existing)
            new_list[idx] = merged
            return (new_list, "merged")

    return (list(existing) + [new_issue], "appended")


def _union_preserve_order(a: list[str], b: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for x in a + b:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out


def _union_probe_sources(
    a: list[dict[str, str]], b: list[dict[str, str]]
) -> list[dict[str, str]]:
    seen: set[tuple[str, str]] = set()
    out: list[dict[str, str]] = []
    for src in a + b:
        key = (src.get("probe_id", ""), src.get("probe_version", ""))
        if key not in seen:
            seen.add(key)
            out.append(dict(src))
    return out


def _escalate_triage(existing: str, new: str) -> str:
    """cdg_required > triaged > deferred > pending > closed (closed không override)."""
    priority = {
        "cdg_required": 4,
        "triaged": 3,
        "deferred": 2,
        "pending": 1,
        "closed": 0,
    }
    if priority.get(new, 0) > priority.get(existing, 0):
        return new
    return existing


# ──────────────────────────────────────────────────────────────────────
# 6. POST-GATE T1-T4 (ADR-22 rule 5)
# ──────────────────────────────────────────────────────────────────────


def post_gate_check(issue_registry_path: Path) -> tuple[bool, list[str]]:
    """Chạy 4 tầng check trước khi commit issue-registry.json.

    T1 Existence: file tồn tại + non-empty.
    T2 Structure: JSON parse OK + có $schema + issues[] (array).
    T3 Content: mỗi issue có issue_id + dimensions ≥ 1 + evidence ≥ 1 + dedup_key format ok.
    T4 Cross-reference: mỗi dimension ∈ VALID_DIMENSIONS + probe_id match pattern.

    Returns:
        (ok, errors_list).
    """
    errors: list[str] = []

    # T1
    if not issue_registry_path.exists():
        return (False, ["T1: file không tồn tại"])
    try:
        size = issue_registry_path.stat().st_size
    except OSError as exc:
        return (False, [f"T1: không đọc được stat: {exc}"])
    if size == 0:
        return (False, ["T1: file rỗng"])

    # T2
    try:
        raw = issue_registry_path.read_text(encoding="utf-8")
        data = json.loads(raw)
    except (json.JSONDecodeError, OSError) as exc:
        return (False, [f"T2: JSON parse fail: {exc}"])
    if not isinstance(data, dict):
        return (False, ["T2: root phải là object"])
    if data.get("$schema") != REGISTRY_SCHEMA_ID:
        errors.append(f"T2: $schema phải là '{REGISTRY_SCHEMA_ID}'")
    issues = data.get("issues")
    if not isinstance(issues, list):
        return (False, errors + ["T2: issues phải là array"])

    # T3 + T4
    for i, issue in enumerate(issues):
        if not isinstance(issue, dict):
            errors.append(f"T3: issues[{i}] không phải object")
            continue
        issue_id = issue.get("issue_id", "")
        if not ISSUE_ID_PATTERN.match(str(issue_id)):
            errors.append(f"T3: issues[{i}].issue_id='{issue_id}' sai format")
        dims = issue.get("dimensions", [])
        if not isinstance(dims, list) or not dims:
            errors.append(f"T3: issues[{i}].dimensions phải có ≥1 phần tử")
        else:
            for d in dims:
                if d not in VALID_DIMENSIONS:
                    errors.append(
                        f"T4: issues[{i}] dimension='{d}' không hợp lệ"
                    )
        evidence = issue.get("evidence", [])
        if not isinstance(evidence, list) or not evidence:
            errors.append(f"T3: issues[{i}].evidence phải có ≥1 phần tử")
        dedup_key = issue.get("dedup_key", "")
        if not DEDUP_KEY_PATTERN.match(str(dedup_key)):
            errors.append(f"T3: issues[{i}].dedup_key sai format 64 hex")
        probe_sources = issue.get("probe_sources", [])
        if not isinstance(probe_sources, list) or not probe_sources:
            errors.append(f"T3: issues[{i}].probe_sources phải có ≥1 phần tử")
        else:
            for j, ps in enumerate(probe_sources):
                if not isinstance(ps, dict):
                    errors.append(
                        f"T4: issues[{i}].probe_sources[{j}] không phải object"
                    )
                    continue
                pid = ps.get("probe_id", "")
                if not PROBE_ID_PATTERN.match(str(pid)):
                    errors.append(
                        f"T4: issues[{i}].probe_sources[{j}].probe_id="
                        f"'{pid}' sai format"
                    )

    return (len(errors) == 0, errors)


# ──────────────────────────────────────────────────────────────────────
# 7. SignalBus class — public API
# ──────────────────────────────────────────────────────────────────────


class SignalBus:
    """Main class — lane import + dùng như utility.

    Usage:
        bus = SignalBus(session_dir)
        bus.load_existing()
        for raw in signals:
            bus.ingest(raw)
        bus.flush()
    """

    def __init__(self, session_dir: Path) -> None:
        self.session_dir = session_dir
        self.registry_path = session_dir / "issue-registry.json"
        self._issues: list[Issue] = []
        self._loaded: bool = False
        self._id_counter: int = 0

    def load_existing(self) -> None:
        """Đọc issue-registry.json nếu tồn tại, populate self._issues."""
        if not self.registry_path.exists():
            self._issues = []
            self._loaded = True
            return
        try:
            raw = self.registry_path.read_text(encoding="utf-8")
            data = json.loads(raw)
        except (json.JSONDecodeError, OSError):
            self._issues = []
            self._loaded = True
            return

        issues_raw = data.get("issues", []) if isinstance(data, dict) else []
        parsed: list[Issue] = []
        for item in issues_raw:
            if not isinstance(item, dict):
                continue
            try:
                parsed.append(
                    Issue(
                        issue_id=str(item.get("issue_id", "")),
                        created_at=str(item.get("created_at", "")),
                        dimensions=list(item.get("dimensions", [])),
                        target=dict(item.get("target", {})),
                        title=str(item.get("title", "")),
                        description_md=str(item.get("description_md", "")),
                        probe_sources=list(item.get("probe_sources", [])),
                        evidence=list(item.get("evidence", [])),
                        dedup_key=str(item.get("dedup_key", "")),
                        severity=item.get("severity"),
                        fixability=item.get("fixability"),
                        triage_status=str(item.get("triage_status", "pending")),
                        dedup_merged_signals=list(
                            item.get("dedup_merged_signals", [])
                        ),
                    )
                )
            except (TypeError, ValueError):
                continue

        self._issues = parsed
        self._loaded = True
        # Tính counter cao nhất để _next_issue_id không va chạm
        today = datetime.now(timezone.utc).strftime("%Y%m%d")
        prefix = f"ISS-{today}-"
        max_n = 0
        for it in parsed:
            if it.issue_id.startswith(prefix):
                try:
                    n = int(it.issue_id.split("-")[-1])
                    if n > max_n:
                        max_n = n
                except ValueError:
                    continue
        self._id_counter = max_n

    def ingest(self, signal_dict: dict[str, Any]) -> Issue:
        """Entry point chính: validate + normalize + merge.

        Raises:
            ValueError: evidence missing (ADR-09) hoặc schema invalid.
        """
        if not self._loaded:
            self.load_existing()

        signal = Signal.from_dict(signal_dict)
        ok, err = validate_evidence(signal)
        if not ok:
            raise ValueError(err or "missing-evidence")

        issue_id = self._next_issue_id()
        new_issue = normalize(signal, issue_id)
        self._issues, action = merge_or_append(new_issue, self._issues)

        # Nếu merged, issue_id mới không được dùng → rollback counter
        if action == "merged":
            self._id_counter -= 1

        # Trả về issue trong registry (đã merged hoặc newly appended)
        for it in self._issues:
            if it.dedup_key == new_issue.dedup_key:
                return it
        return new_issue  # fallback, không nên xảy ra

    # F06.012 (Sprint 6 v10.3): Cross-process lock cho flush() để chống
    # Lost Update khi N concurrent lanes load → modify → flush.
    # Atomic rename giữ file-level integrity nhưng KHÔNG chống Lost Update
    # logic-level (Process A flush sau B → B changes mất). Lock-protect
    # toàn bộ read-modify-write sequence + reload-before-flush nếu file
    # đã thay đổi từ lúc load_existing().
    _FLUSH_LOCK_STALE_SEC = 60  # Aligned với F06.004 SIGNALS_LOCK_STALE_SEC
    _FLUSH_LOCK_TIMEOUT_SEC = 30  # Block writer up to 30s

    def _acquire_flush_lock(self) -> bool:
        """Acquire mkdir-based file lock cho registry_path.

        Compatible pattern với lane_dispatch._signals_lock_acquire (cùng
        convention `.lock/` directory). Cross-platform, no external dep.

        Returns:
            True nếu acquire trong timeout, False nếu timeout/fail.
        """
        lock_dir = self.registry_path.with_suffix(self.registry_path.suffix + ".lock")
        waited = 0
        import time as _time
        while waited < self._FLUSH_LOCK_TIMEOUT_SEC:
            # Stale takeover
            if lock_dir.exists():
                try:
                    age = _time.time() - lock_dir.stat().st_mtime
                except OSError:
                    age = 0
                if age > self._FLUSH_LOCK_STALE_SEC:
                    try:
                        lock_dir.rmdir()
                    except OSError:
                        pass
            try:
                lock_dir.parent.mkdir(parents=True, exist_ok=True)
                lock_dir.mkdir()
                return True
            except FileExistsError:
                _time.sleep(0.5)
                waited += 1
            except OSError:
                return False
        return False

    def _release_flush_lock(self) -> None:
        """Idempotent release."""
        lock_dir = self.registry_path.with_suffix(self.registry_path.suffix + ".lock")
        try:
            lock_dir.rmdir()
        except (FileNotFoundError, OSError):
            pass

    def flush(self) -> Path:
        """Commit buffer → issue-registry.json + POST-GATE T1-T4.

        Atomic write + POST-GATE; nếu POST-GATE fail → raise, KHÔNG để partial.

        F06.012 (Sprint 6): Cross-process lock toàn bộ load-modify-write
        sequence. Reload disk trước khi merge để chống Lost Update từ
        concurrent flushers (Process A flush sau B không mất B changes).
        """
        # F06.012: Lock-protect entire flush sequence
        if not self._acquire_flush_lock():
            raise RuntimeError(
                f"SignalBus.flush() lock timeout ({self._FLUSH_LOCK_TIMEOUT_SEC}s) "
                f"for {self.registry_path}"
            )
        try:
            # F06.012: Reload disk để bắt concurrent writes từ flusher khác.
            # Nếu file đã thay đổi từ lần load_existing(), merge issues từ disk
            # vào buffer trước khi rebuild (concurrent safety).
            if self._loaded:
                self._merge_with_disk_state()
            else:
                self.load_existing()

            data = {
                "$schema": REGISTRY_SCHEMA_ID,
                "generated_at": datetime.now(timezone.utc).isoformat(),
                "session_dir": str(self.session_dir),
                "issues": [it.to_dict() for it in self._issues],
            }

            self.registry_path.parent.mkdir(parents=True, exist_ok=True)
            tmp_fd, tmp_name = tempfile.mkstemp(
                prefix=f".{self.registry_path.name}.",
                suffix=".tmp",
                dir=str(self.registry_path.parent),
            )
            try:
                with os.fdopen(tmp_fd, "w", encoding="utf-8") as fh:
                    # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
                    json.dump(data, fh, indent=2, ensure_ascii=False, sort_keys=True)
                    fh.flush()
                    os.fsync(fh.fileno())
                os.replace(tmp_name, self.registry_path)
            except Exception:
                try:
                    os.unlink(tmp_name)
                except OSError:
                    pass
                raise

            ok, errors = post_gate_check(self.registry_path)
            if not ok:
                raise RuntimeError(
                    "POST-GATE T1-T4 FAIL (ADR-22 rule 5): " + "; ".join(errors)
                )
            return self.registry_path
        finally:
            self._release_flush_lock()

    def _merge_with_disk_state(self) -> None:
        """F06.012: Merge issues từ disk (concurrent writes) vào buffer.

        Khi 2+ process concurrent flush, mỗi process load_existing() lúc khởi
        tạo, modify buffer, flush. Nếu không reload trước flush → process B
        flush sẽ overwrite changes từ process A.

        Cách giải: trước khi flush, đọc lại disk state. Issues có cùng dedup_key
        đã có trong buffer → keep buffer version (priority: in-memory mới nhất).
        Issues chỉ có trên disk → merge vào buffer.
        """
        if not self.registry_path.exists():
            return
        # Lưu dedup_keys hiện tại trong buffer
        buffer_keys = {it.dedup_key for it in self._issues}
        # Reload disk
        try:
            raw = self.registry_path.read_text(encoding="utf-8")
            disk_data = json.loads(raw)
        except (json.JSONDecodeError, OSError):
            return
        disk_issues = disk_data.get("issues", []) if isinstance(disk_data, dict) else []
        for item in disk_issues:
            if not isinstance(item, dict):
                continue
            disk_dedup = str(item.get("dedup_key", ""))
            if disk_dedup in buffer_keys:
                continue  # Buffer version mới hơn — keep buffer
            try:
                self._issues.append(
                    Issue(
                        issue_id=str(item.get("issue_id", "")),
                        created_at=str(item.get("created_at", "")),
                        dimensions=list(item.get("dimensions", [])),
                        target=dict(item.get("target", {})),
                        title=str(item.get("title", "")),
                        description_md=str(item.get("description_md", "")),
                        probe_sources=list(item.get("probe_sources", [])),
                        evidence=list(item.get("evidence", [])),
                        dedup_key=disk_dedup,
                        severity=item.get("severity"),
                        fixability=item.get("fixability"),
                        triage_status=str(item.get("triage_status", "pending")),
                        dedup_merged_signals=list(item.get("dedup_merged_signals", [])),
                    )
                )
            except (TypeError, ValueError):
                continue

    def _next_issue_id(self) -> str:
        """Sinh issue_id format ISS-YYYYMMDD-NNN."""
        today = datetime.now(timezone.utc).strftime("%Y%m%d")
        self._id_counter += 1
        return f"ISS-{today}-{self._id_counter:03d}"

    @property
    def issues(self) -> list[Issue]:
        """Snapshot issues hiện có (read-only view)."""
        return list(self._issues)


# ──────────────────────────────────────────────────────────────────────
# CLI dispatch
# ──────────────────────────────────────────────────────────────────────


def _cmd_ingest(args: argparse.Namespace) -> int:
    """signal_bus.py ingest subcommand."""
    signal_dict = json.loads(args.signal_file.read_text(encoding="utf-8"))
    bus = SignalBus(args.session_dir)
    bus.load_existing()
    try:
        issue = bus.ingest(signal_dict)
    except ValueError as exc:
        print(f"[signal_bus REJECT] {exc}", file=sys.stderr)
        return 2
    if not args.dry_run:
        bus.flush()
    print(issue.issue_id)
    return 0


def _cmd_flush(args: argparse.Namespace) -> int:
    """signal_bus.py flush subcommand — re-validate + POST-GATE."""
    bus = SignalBus(args.session_dir)
    bus.load_existing()
    try:
        path = bus.flush()
    except RuntimeError as exc:
        print(f"[signal_bus POST-GATE FAIL] {exc}", file=sys.stderr)
        return 3
    print(str(path))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Signal Bus")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_ingest = sub.add_parser("ingest", help="Nhận 1 Signal → normalize + merge")
    p_ingest.add_argument("--signal-file", required=True, type=Path)
    p_ingest.add_argument("--session-dir", required=True, type=Path)
    p_ingest.add_argument("--dry-run", action="store_true")
    p_ingest.set_defaults(func=_cmd_ingest)

    p_flush = sub.add_parser(
        "flush", help="Commit buffer → issue-registry.json + POST-GATE"
    )
    p_flush.add_argument("--session-dir", required=True, type=Path)
    p_flush.set_defaults(func=_cmd_flush)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
