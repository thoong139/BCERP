"""QD4 — Performance & Efficiency probe regression tests (skeleton).

Stage 0: skeleton-only — Stage 1 Phase 3 (build cases) sẽ implement test bodies
thực tế cho từng probe của lane `wf-fix-performance`.

Tham chiếu:
    - DoD: 13-definition-of-done.md §Phase 3 (Precision ≥0.7, Recall ≥0.6).
    - Fixture: fixtures/qd4-test/{expected-signals.json, run.sh, accuracy-report.md}.
    - Lane skill: .claude/skills/workflow/wf-fix-performance/.
"""
from __future__ import annotations

import pytest

pytestmark = pytest.mark.skip(reason="Stage 1 Phase 3 — chưa build cases")


def test_qd4_probes_skeleton() -> None:
    """Placeholder. Stage 1 Phase 3 sẽ split per-probe + per-case (positive/negative/advanced)."""
    assert True
