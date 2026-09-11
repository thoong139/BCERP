"""impact_graph — Builder và Ripple consumer cho Verify Ripple (ADR-18, ADR-22 rule 2).

Module này gồm hai thành phần:

- ``builder``: probe **P0.XREF** cho ``/wf-fix-discover`` Layer 0 — quét source code
  (ts/tsx/js/jsx/py/java/go/rs/cs) và sinh ``$SESSION_DIR/impact-graph.json``
  chứa đồ thị phụ thuộc giữa các file (import/call), kèm ``edge_strength`` [0..1]
  và ``edge_type``.

- ``ripple``: consumer cho ``/wf-fix-execute`` Phase 5 — đọc impact-graph.json,
  với 1 issue cho trước, enumerate downstream nodes đạt ``strength >= 0.5`` ở
  ``depth <= 1`` (ADR-22 rule 2). Trả về danh sách file cần re-verify.

Public API (bất biến — consumer không được phá vỡ ở minor version):
    - builder.build, builder.emit, builder.Graph, builder.Edge, builder.Node
    - ripple.verify_ripple, ripple.RippleTarget, ripple.DEFAULT_DEPTH,
      ripple.DEFAULT_STRENGTH

Constants:
    - SCHEMA_ID
    - SUPPORTED_LANGS
"""

from .builder import (
    SCHEMA_ID,
    SUPPORTED_LANGS,
    Edge,
    Graph,
    Node,
    build,
    emit,
)
from .ripple import (
    DEFAULT_DEPTH,
    DEFAULT_STRENGTH,
    RippleTarget,
    verify_ripple,
)

__version__ = "0.1.0-b3"

__all__ = [
    # Builder
    "Graph",
    "Node",
    "Edge",
    "build",
    "emit",
    # Ripple
    "RippleTarget",
    "verify_ripple",
    "DEFAULT_DEPTH",
    "DEFAULT_STRENGTH",
    # Constants
    "SCHEMA_ID",
    "SUPPORTED_LANGS",
]
