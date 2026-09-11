"""llm_lane — LLM-Augmented Scan Lane (Phase C v8 wf-fix-bugs).

Cho phep LLM agents phat hien bugs ma static probes khong bat duoc:
- Race conditions, integration bugs, business edge cases, UX inconsistencies.

Quality-first mode (default): tat ca budget caps = 0 (UNLIMITED).
Module track cost cumulative cho visibility nhung KHONG enforce hard caps.
Non-deterministic, opt-in qua --llm-scan.

Caller có thể opt-in to caps bằng cách pass non-zero values khi construct
`LLMBudget`, hoac qua `max_chunks` / `max_signals` parameters.

Public API:
    LLMBudget         — track cost (no enforcement by default)
    plan_chunks       — chia source files thanh chunks ≤ max_tokens
    parse_signals     — parse + validate agent output theo lane-signals-v1
    estimate_cost     — pre-flight cost estimate

Registry role: NONE.
"""
from __future__ import annotations

from .budget_guard import (
    BUDGET_DEFAULTS,
    BudgetExceeded,
    LLMBudget,
    estimate_cost,
)
from .chunk_planner import Chunk, plan_chunks
from .signal_parser import parse_signals, validate_signal

__version__ = "1.0.0"

__all__ = [
    "LLMBudget",
    "BudgetExceeded",
    "BUDGET_DEFAULTS",
    "estimate_cost",
    "Chunk",
    "plan_chunks",
    "parse_signals",
    "validate_signal",
]
