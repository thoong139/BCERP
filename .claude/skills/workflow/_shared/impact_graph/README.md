# `impact_graph` — Probe P0.XREF Builder + Verify Ripple Consumer

Shared module cho `/wf-fix-*` lanes. Hai trách nhiệm độc lập:

1. **Builder (`builder.py`)** — Probe P0.XREF được gọi bởi `/wf-fix-bugs` Lane Dispatch
   Layer 0. Quét source code trong scope (ts/tsx/js/jsx/py/java/cs/go/rs), dựng đồ
   thị phụ thuộc giữa các file (`import`/`require`/`from ... import`), emit
   `$SESSION_DIR/impact-graph.json` (schema `impact-graph.v1`).

2. **Ripple consumer (`ripple.py`)** — Được `/wf-fix-execute` Phase 5 gọi sau mỗi fix.
   Đọc `impact-graph.json`, với 1 issue đã fix tính danh sách file cần re-verify
   (downstream dependents, **depth ≤ 1**, **strength ≥ 0.5**) theo ADR-22 rule 2.

## Public API

```python
from impact_graph import (
    # Builder
    build, emit, Graph, Node, Edge,
    # Ripple
    verify_ripple, RippleTarget, DEFAULT_DEPTH, DEFAULT_STRENGTH,
    # Constants
    SCHEMA_ID, SUPPORTED_LANGS,
)
```

## CLI

```bash
# Build graph (gọi từ wf-fix-bugs Lane Dispatch):
python -m _shared.impact_graph.builder \
    --repo-root "$REPO_ROOT" \
    --output "$SESSION_DIR/impact-graph.json" \
    --scope all

# Verify ripple sau khi fix (gọi từ wf-fix-execute Phase 5):
python -m _shared.impact_graph.ripple verify \
    --issue "$SESSION_DIR/issues/I-0001.json" \
    --graph "$SESSION_DIR/impact-graph.json" \
    --depth 1 \
    --strength 0.5
```

Output của CLI `ripple verify`:

```json
{
  "origin": "src/services/customer.ts",
  "depth": 1,
  "strength_threshold": 0.5,
  "target_count": 3,
  "targets": [
    { "file_path": "src/api/customer.controller.ts",
      "reason": "direct-dependent",
      "edge_strength": 0.7,
      "distance": 1,
      "origin": "src/services/customer.ts" }
  ]
}
```

## Heuristic Edge Strength

Base `0.5` + `+0.2` nếu import wildcard (`*`) + `+0.2` nếu ở eager top-of-file
(line_no ≤ max(3, 5% total lines)). Clamp `[0.1, 1.0]`, round 2 chữ số.

## Giới hạn phòng thủ (override qua flag CLI)

- `MAX_FILES_DEFAULT = 5000` file / 1 lần build.
- `MAX_FILE_BYTES_DEFAULT = 1 MiB` — bỏ qua file lớn hơn.
- Thư mục bỏ qua: `node_modules`, `.git`, `.venv`, `dist`, `build`, `target`,
  `.mc-data`, `.cache`, ... (xem `_SKIP_DIRS` trong `builder.py`).

## Hợp đồng tích hợp

- Producer: `/wf-fix-bugs` Lane Dispatch (tham chiếu ADR-18).
- Consumer: `/wf-fix-execute` Phase 5 (tham chiếu ADR-22 rule 2).
- Output path: `$SESSION_DIR/impact-graph.json` — khớp `00-core.md §4b` Cross-Skill
  Output Path Contract.
- Registry role: **NONE** (không ghi `req-registry.json`).

## Gotchas

- Python resolver ưu tiên **submodule**: `from pkg import c` → thử `pkg.c` là module
  trước khi fall back về package `pkg/__init__.py`.
- Java/C#/Go/Rust dùng stem-match **best-effort** — có thể false-positive nếu trùng
  tên class ở file xa. Graph là tín hiệu, không phải ground truth.
- Edges được **dedup** theo `(source, target, evidence_line)` và loại self-loop.
- `verify_ripple()` sort kết quả deterministic `(distance, -strength, file_path)`.

## Changelog

- `0.1.0-b3` — Builder + Ripple cả hai implement; submodule resolver fixed; schema v1 + smoke test passed.
