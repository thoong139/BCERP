"""budget_guard — Track LLM cost cho visibility (Phase C v8 — quality-first mode).

Quality-first defaults: caps = 0 (UNLIMITED). Module track cumulative usage cho
audit/visibility nhung KHONG enforce hard caps. Caller có thể opt-in to caps
bằng cách pass non-zero values khi construct.

Cost model based on Claude Sonnet 4.6 pricing (subject to change):
- Input: $3.00 / 1M tokens
- Output: $15.00 / 1M tokens
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Tuple

# Sonnet 4.6 pricing (USD per million tokens). Update as needed.
SONNET_INPUT_USD_PER_1M = 3.00
SONNET_OUTPUT_USD_PER_1M = 15.00

# Sentinel: 0 = no cap (track only, never enforce).
# Quality-first: defaults disable enforcement to maximize coverage.
UNLIMITED = 0

BUDGET_DEFAULTS: dict[str, float | int | bool] = {
    "max_total_tokens_in": UNLIMITED,
    "max_total_tokens_out": UNLIMITED,
    "estimated_cost_usd_cap": 0.0,
    "require_user_confirmation": False,
    "max_chunks_per_probe": UNLIMITED,
    "max_signals_per_probe": UNLIMITED,
}


class BudgetExceeded(Exception):
    """Raised khi caller set explicit cap (>0) va LLM invocation vuot cap.

    Default config (caps = 0) NEVER raises this.
    """
    pass


@dataclass
class LLMBudget:
    """Track cumulative LLM usage. Enforces caps ONLY when caps > 0.

    Quality-first defaults: tat ca caps = 0 (unlimited).
    Caller có thể opt-in to caps bằng cách pass non-zero values.

    Usage:
        # Default — unlimited, track only:
        budget = LLMBudget()
        ok, reason = budget.pre_check(estimated_chunks=5, avg_tokens_in=10000)
        # ok always True trong unlimited mode.
        budget.increment(tokens_in=9500, tokens_out=1200)
        # Always tracks; halts ONLY if caps explicitly set and exceeded.

        # Opt-in cap mode:
        budget = LLMBudget(estimated_cost_usd_cap=5.00)
        # Will halt khi cumulative cost vuot $5.00.
    """

    max_total_tokens_in: int = UNLIMITED
    max_total_tokens_out: int = UNLIMITED
    estimated_cost_usd_cap: float = 0.0
    require_user_confirmation: bool = False
    max_chunks_per_probe: int = UNLIMITED
    max_signals_per_probe: int = UNLIMITED

    # Runtime tracking
    used_tokens_in: int = 0
    used_tokens_out: int = 0
    invocations: int = 0
    halted: bool = False
    halt_reason: str = ""

    @classmethod
    def from_defaults(cls, **overrides) -> "LLMBudget":
        """Construct from BUDGET_DEFAULTS (unlimited), with overrides."""
        params = {**BUDGET_DEFAULTS, **overrides}
        return cls(**params)  # type: ignore[arg-type]

    def remaining_tokens_in(self) -> int:
        """Returns remaining tokens, or -1 sentinel khi unlimited."""
        if self.max_total_tokens_in == 0:
            return -1
        return max(0, self.max_total_tokens_in - self.used_tokens_in)

    def remaining_tokens_out(self) -> int:
        """Returns remaining tokens, or -1 sentinel khi unlimited."""
        if self.max_total_tokens_out == 0:
            return -1
        return max(0, self.max_total_tokens_out - self.used_tokens_out)

    def cumulative_cost_usd(self) -> float:
        return (
            self.used_tokens_in / 1_000_000 * SONNET_INPUT_USD_PER_1M
            + self.used_tokens_out / 1_000_000 * SONNET_OUTPUT_USD_PER_1M
        )

    def is_unlimited(self) -> bool:
        """True khi tat ca caps = 0 (no enforcement)."""
        return (
            self.max_total_tokens_in == 0
            and self.max_total_tokens_out == 0
            and self.estimated_cost_usd_cap == 0.0
            and self.max_chunks_per_probe == 0
        )

    def pre_check(self, *, estimated_chunks: int, avg_tokens_in: int,
                  avg_tokens_out: int = 1200) -> Tuple[bool, str]:
        """Pre-flight check truoc khi invoke agent.

        Default mode (all caps=0): always returns (True, info_message) —
        track cost cho visibility, KHONG block.

        Caps mode: returns (False, reason) khi vượt cap.

        Returns:
            (allowed, reason). Reason luon non-empty.
        """
        if self.halted:
            return False, f"Budget already halted: {self.halt_reason}"

        projected_in = self.used_tokens_in + estimated_chunks * avg_tokens_in
        projected_out = self.used_tokens_out + estimated_chunks * avg_tokens_out
        projected_cost = (
            projected_in / 1_000_000 * SONNET_INPUT_USD_PER_1M
            + projected_out / 1_000_000 * SONNET_OUTPUT_USD_PER_1M
        )

        # Enforce only when caps explicitly set (> 0).
        if self.max_chunks_per_probe > 0 and estimated_chunks > self.max_chunks_per_probe:
            return False, (
                f"Estimated chunks ({estimated_chunks}) exceeds cap "
                f"({self.max_chunks_per_probe}). Reduce scope or raise cap."
            )

        if self.max_total_tokens_in > 0 and projected_in > self.max_total_tokens_in:
            return False, (
                f"Projected total tokens_in ({projected_in:,}) exceeds cap "
                f"({self.max_total_tokens_in:,})."
            )
        if self.max_total_tokens_out > 0 and projected_out > self.max_total_tokens_out:
            return False, (
                f"Projected total tokens_out ({projected_out:,}) exceeds cap "
                f"({self.max_total_tokens_out:,})."
            )

        if self.estimated_cost_usd_cap > 0 and projected_cost > self.estimated_cost_usd_cap:
            return False, (
                f"Projected cost ${projected_cost:.2f} exceeds cap "
                f"${self.estimated_cost_usd_cap:.2f}."
            )

        mode_info = (
            "unlimited mode" if self.is_unlimited()
            else f"cap ${self.estimated_cost_usd_cap:.2f}" if self.estimated_cost_usd_cap > 0
            else "tracking-only"
        )
        return True, (
            f"OK: projected {projected_in:,} in / {projected_out:,} out, "
            f"cost ~${projected_cost:.2f} ({mode_info})"
        )

    def increment(self, *, tokens_in: int, tokens_out: int) -> None:
        """Update cumulative tracking after each successful invocation.

        Auto-halts ONLY khi caller set explicit cap (> 0) va cumulative usage
        vuot cap. Default config (all caps=0) never auto-halts.
        """
        if tokens_in < 0 or tokens_out < 0:
            raise ValueError("tokens must be non-negative")
        self.used_tokens_in += tokens_in
        self.used_tokens_out += tokens_out
        self.invocations += 1

        # Auto-halt only when explicit cap exceeded.
        if self.max_total_tokens_in > 0 and self.used_tokens_in > self.max_total_tokens_in:
            self.halted = True
            self.halt_reason = (
                f"tokens_in cumulative ({self.used_tokens_in:,}) > cap "
                f"({self.max_total_tokens_in:,})"
            )
        elif self.max_total_tokens_out > 0 and self.used_tokens_out > self.max_total_tokens_out:
            self.halted = True
            self.halt_reason = (
                f"tokens_out cumulative ({self.used_tokens_out:,}) > cap "
                f"({self.max_total_tokens_out:,})"
            )
        elif self.estimated_cost_usd_cap > 0 and self.cumulative_cost_usd() > self.estimated_cost_usd_cap:
            self.halted = True
            self.halt_reason = (
                f"cost cumulative ${self.cumulative_cost_usd():.2f} > cap "
                f"${self.estimated_cost_usd_cap:.2f}"
            )

    def summary(self) -> dict:
        return {
            "used_tokens_in": self.used_tokens_in,
            "used_tokens_out": self.used_tokens_out,
            "cumulative_cost_usd": round(self.cumulative_cost_usd(), 4),
            "invocations": self.invocations,
            "halted": self.halted,
            "halt_reason": self.halt_reason,
            "remaining_tokens_in": self.remaining_tokens_in(),
            "remaining_tokens_out": self.remaining_tokens_out(),
            "mode": "unlimited" if self.is_unlimited() else "capped",
        }


def estimate_cost(*, tokens_in: int, tokens_out: int) -> float:
    """Compute cost USD for given token counts (Sonnet 4.6 pricing)."""
    return (
        tokens_in / 1_000_000 * SONNET_INPUT_USD_PER_1M
        + tokens_out / 1_000_000 * SONNET_OUTPUT_USD_PER_1M
    )
