#!/usr/bin/env python3
"""generate-fixture.py — Sinh synthetic large-codebase fixture cho CI.

Deterministic theo seed. Output:
  - apps/{erp-web,backend,mobile-staff,sourcing-svc,wms-svc}/...{.ts,.cs,.py}
  - .mc-data/docs/_meta/req-registry.json (300 features)

Mỗi file source có comment header `// REQ-ID:` + `// FEAT-ID:` để probe xref
quét được. 200 unique REQ-IDs / 200 unique FEAT-IDs trải đều trên 50k files.
KHÔNG ghi binary blobs, KHÔNG dùng third-party libs (chỉ stdlib).

Usage:
    python generate-fixture.py --out-dir <path> [--seed 42] [--target-files 50000]
                               [--target-features 300]

Idempotent: nếu out-dir đã có file `.fixture-marker.json` cùng (seed, target-files,
target-features) thì exit 0. Force regen bằng --force.
"""
from __future__ import annotations

import argparse
import json
import random
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Cấu hình
# ---------------------------------------------------------------------------

DEPARTMENTS = ["CRM", "FIN", "HRM", "TMS", "WMS", "QC", "BI", "MKT", "SRC", "TAX"]
SYSTEMS = ["SYS-ERP", "SYS-MOB", "SYS-CUS"]
MODULES = [
    "CUST", "ORD", "INV", "PAY", "AUTH", "PROD", "VEND",
    "SHIP", "RPT", "DASH", "USER", "ROLE", "PERM", "TASK",
]

# Cấu trúc thư mục mô phỏng monorepo EUREKA
TREE_LAYOUT = [
    # (sub_path, file_ext, file_count_pct)
    ("apps/erp-web/src", ".ts", 0.30),
    ("apps/erp-web/src", ".tsx", 0.10),
    ("apps/backend", ".cs", 0.30),
    ("apps/mobile-staff/src", ".ts", 0.10),
    ("apps/sourcing-svc/src", ".py", 0.10),
    ("apps/wms-svc/src", ".py", 0.10),
]

IMPL_STATUS_DIST = [
    ("done", 0.50),
    ("in_progress", 0.33),
    ("not_started", 0.10),
    ("skipped", 0.07),
]

MARKER_NAME = ".fixture-marker.json"

# ---------------------------------------------------------------------------
# Templates (per language)
# ---------------------------------------------------------------------------

TEMPLATE_TS = """\
// REQ-ID: {req_id}
// FEAT-ID: {feat_id}
// Auto-generated fixture file (seed={seed}). KHONG sua tay.

import {{ Logger }} from '../core/logger';

export interface {iface_name} {{
  id: string;
  name: string;
  createdAt: Date;
}}

export class {class_name} {{
  private readonly log = new Logger('{class_name}');

  async handle(payload: {iface_name}): Promise<void> {{
    this.log.info('handle', {{ id: payload.id }});
  }}
}}
"""

TEMPLATE_TSX = """\
// REQ-ID: {req_id}
// FEAT-ID: {feat_id}
// Auto-generated fixture file (seed={seed}). KHONG sua tay.

import React from 'react';

export interface {iface_name}Props {{
  title: string;
  onClick?: () => void;
}}

export const {class_name}: React.FC<{iface_name}Props> = ({{ title, onClick }}) => (
  <button onClick={{onClick}}>{{title}}</button>
);
"""

TEMPLATE_CS = """\
// REQ-ID: {req_id}
// FEAT-ID: {feat_id}
// Auto-generated fixture file (seed={seed}). KHONG sua tay.

namespace Eureka.Modules.Generated;

public sealed record {class_name}Command(string Id, string Name);

public sealed class {class_name}Handler
{{
    public Task HandleAsync({class_name}Command command, CancellationToken ct)
    {{
        return Task.CompletedTask;
    }}
}}
"""

TEMPLATE_PY = """\
# REQ-ID: {req_id}
# FEAT-ID: {feat_id}
# Auto-generated fixture file (seed={seed}). KHONG sua tay.

from dataclasses import dataclass


@dataclass
class {class_name}:
    id: str
    name: str

    def describe(self) -> str:
        return f"{{self.__class__.__name__}}({{self.id}})"
"""

TEMPLATES = {
    ".ts": TEMPLATE_TS,
    ".tsx": TEMPLATE_TSX,
    ".cs": TEMPLATE_CS,
    ".py": TEMPLATE_PY,
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_req_ids(rng: random.Random, count: int = 200) -> list[str]:
    out: set[str] = set()
    while len(out) < count:
        dept = rng.choice(DEPARTMENTS)
        n = rng.randint(1, 999)
        out.add(f"REQ-{dept}-{n:03d}")
    return sorted(out)


def _make_feat_ids(rng: random.Random, count: int = 200) -> list[str]:
    out: set[str] = set()
    while len(out) < count:
        sys_short = rng.choice(["ERP", "MOB", "CUS"])
        mod = rng.choice(MODULES)
        n = rng.randint(1, 999)
        out.add(f"FEAT-{sys_short}-{mod}-{n:03d}")
    return sorted(out)


def _camel(name: str) -> str:
    parts = [p for p in name.split("-") if p]
    return "".join(p.capitalize() for p in parts)


def _generate_one_file(
    out_root: Path,
    rel_path: str,
    ext: str,
    idx: int,
    seed: int,
    req_id: str,
    feat_id: str,
) -> None:
    file_path = out_root / rel_path / f"file-{idx:06d}{ext}"
    file_path.parent.mkdir(parents=True, exist_ok=True)
    base_name = f"FixtureFile{idx}"
    content = TEMPLATES[ext].format(
        req_id=req_id,
        feat_id=feat_id,
        seed=seed,
        iface_name=base_name,
        class_name=base_name,
    )
    file_path.write_text(content, encoding="utf-8")


def _build_registry(req_ids: list[str], feat_ids: list[str], rng: random.Random,
                    target_features: int) -> dict:
    statuses = []
    for status, weight in IMPL_STATUS_DIST:
        statuses.extend([status] * int(weight * 100))
    while len(statuses) < 100:
        statuses.append("not_started")

    requirements = []
    used = set()
    for req_id in req_ids:
        used.add(req_id)
        requirements.append({
            "id": req_id,
            "title": f"Requirement {req_id}",
            "department": req_id.split("-")[1],
            "priority": rng.choice(["high", "medium", "low"]),
            "impl_status": rng.choice(statuses),
        })
    # Top up requirements neu can
    extra_idx = 1
    while len(requirements) < target_features // 2:
        dept = rng.choice(DEPARTMENTS)
        synthetic = f"REQ-{dept}-EXT{extra_idx:03d}"
        if synthetic in used:
            extra_idx += 1
            continue
        used.add(synthetic)
        requirements.append({
            "id": synthetic,
            "title": f"Requirement {synthetic}",
            "department": dept,
            "priority": rng.choice(["high", "medium", "low"]),
            "impl_status": rng.choice(statuses),
        })
        extra_idx += 1

    features = []
    used_feat = set()
    for feat_id in feat_ids[:target_features]:
        used_feat.add(feat_id)
        parts = feat_id.split("-")
        sys_id = "SYS-" + parts[1]
        mod_id = "MOD-" + parts[2]
        linked_req = rng.choice(req_ids) if req_ids else None
        features.append({
            "id": feat_id,
            "title": f"Feature {feat_id}",
            "system_id": sys_id,
            "module_id": mod_id,
            "req_ids": [linked_req] if linked_req else [],
            "impl_status": rng.choice(statuses),
            "owner_team": rng.choice(["backend", "frontend", "mobile", "qa"]),
        })

    while len(features) < target_features:
        sys_short = rng.choice(["ERP", "MOB", "CUS"])
        mod = rng.choice(MODULES)
        n = rng.randint(1, 999)
        synthetic = f"FEAT-{sys_short}-{mod}-EXT{n:03d}"
        if synthetic in used_feat:
            continue
        used_feat.add(synthetic)
        features.append({
            "id": synthetic,
            "title": f"Feature {synthetic}",
            "system_id": f"SYS-{sys_short}",
            "module_id": f"MOD-{mod}",
            "req_ids": [],
            "impl_status": rng.choice(statuses),
            "owner_team": rng.choice(["backend", "frontend", "mobile", "qa"]),
        })

    return {
        "version": "1.0.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "generator": "wf-fix-bugs/large-codebase-fixture",
        "requirements": requirements,
        "features": features,
    }


def _existing_marker(out_root: Path) -> dict | None:
    marker = out_root / MARKER_NAME
    if not marker.exists():
        return None
    try:
        return json.loads(marker.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def _write_marker(out_root: Path, data: dict) -> None:
    (out_root / MARKER_NAME).write_text(
        json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8"
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    # Windows cp1252 → force UTF-8 cho stdout/stderr
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Generate large-codebase fixture")
    parser.add_argument("--out-dir", required=True, type=Path,
                        help="Root directory for fixture (will be created).")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--target-files", type=int, default=50000)
    parser.add_argument("--target-features", type=int, default=300)
    parser.add_argument("--force", action="store_true",
                        help="Force regenerate even if marker matches.")
    parser.add_argument("--clean", action="store_true",
                        help="Clean out-dir trước khi generate (đảm bảo không lẫn file cũ).")
    args = parser.parse_args(argv)

    out_root: Path = args.out_dir.resolve()

    expected_marker = {
        "seed": args.seed,
        "target_files": args.target_files,
        "target_features": args.target_features,
    }

    existing = _existing_marker(out_root)
    if existing and existing.get("seed") == args.seed \
            and existing.get("target_files") == args.target_files \
            and existing.get("target_features") == args.target_features \
            and not args.force:
        print(f"[generate-fixture] cache hit ({out_root}); skip regen")
        return 0

    if args.clean and out_root.exists():
        print(f"[generate-fixture] cleaning {out_root}")
        shutil.rmtree(out_root, ignore_errors=True)

    out_root.mkdir(parents=True, exist_ok=True)

    started = time.monotonic()
    rng = random.Random(args.seed)
    req_ids = _make_req_ids(rng, count=200)
    feat_ids = _make_feat_ids(rng, count=200)

    # Phân bổ files theo TREE_LAYOUT tỷ lệ
    file_plan: list[tuple[str, str]] = []  # (rel_path, ext)
    cumulative = 0
    for sub_path, ext, pct in TREE_LAYOUT:
        n = int(args.target_files * pct)
        cumulative += n
        for _ in range(n):
            file_plan.append((sub_path, ext))
    while len(file_plan) < args.target_files:
        file_plan.append(TREE_LAYOUT[0][:2])

    # Bucket every ~200 files vào 1 subdir để tránh 1 thư mục có hàng chục nghìn entries
    rng.shuffle(file_plan)
    BUCKET_SIZE = 200
    for i, (sub_path, ext) in enumerate(file_plan):
        bucket = i // BUCKET_SIZE
        rel_path = f"{sub_path}/bucket-{bucket:04d}"
        req_id = req_ids[i % len(req_ids)]
        feat_id = feat_ids[i % len(feat_ids)]
        _generate_one_file(out_root, rel_path, ext, i, args.seed, req_id, feat_id)
        if i % 5000 == 0 and i > 0:
            elapsed = time.monotonic() - started
            print(f"[generate-fixture] {i}/{args.target_files} files ({elapsed:.1f}s)")

    # Registry
    registry = _build_registry(req_ids, feat_ids, rng, args.target_features)
    registry_path = out_root / ".mc-data" / "docs" / "_meta" / "req-registry.json"
    registry_path.parent.mkdir(parents=True, exist_ok=True)
    registry_path.write_text(
        json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    # Marker
    elapsed_total = time.monotonic() - started
    marker = dict(expected_marker)
    marker["files_written"] = len(file_plan)
    marker["features_written"] = len(registry["features"])
    marker["requirements_written"] = len(registry["requirements"])
    marker["elapsed_seconds"] = round(elapsed_total, 2)
    _write_marker(out_root, marker)

    print(
        f"[generate-fixture] done: {len(file_plan)} files, "
        f"{len(registry['requirements'])} reqs, {len(registry['features'])} feats "
        f"in {elapsed_total:.1f}s → {out_root}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
