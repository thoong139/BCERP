"""concurrency — 3-tier Token Bucket + backpressure cho probe execution.

Shared utility module cho QD lanes. Global cap = 12, per-lane = 4, per-probe
= 6 (ADR-22 rule 3, KHÔNG override runtime). Backpressure: Semaphore
in-flight cap + AdaptiveBackpressure theo p95 latency.

ADR refs: ADR-17 (Concurrency Model), ADR-22 rule 3 (non-negotiable 12/4/6).

Public API:
    - token_bucket: TokenBucket, TokenBucket3Tier, BucketState, defaults
    - backpressure: SemaphoreBackpressure, AdaptiveBackpressure, LatencyWindow
"""

from .backpressure import (
    ADAPTIVE_BACKOFF_MAX_MS,
    ADAPTIVE_BACKOFF_MIN_MS,
    ADAPTIVE_BACKOFF_MULTIPLIER,
    ADAPTIVE_LATENCY_THRESHOLD_MS,
    DEFAULT_MAX_INFLIGHT,
    AdaptiveBackpressure,
    LatencyWindow,
    SemaphoreBackpressure,
)
from .token_bucket import (
    DEFAULT_GLOBAL_CAP,
    DEFAULT_INTRA_CAP,
    DEFAULT_LANE_CAP,
    REFILL_WINDOW_SEC,
    BucketState,
    TokenBucket,
    TokenBucket3Tier,
)

__version__ = "0.2.0-b2"

__all__ = [
    # token_bucket
    "TokenBucket",
    "TokenBucket3Tier",
    "BucketState",
    "DEFAULT_GLOBAL_CAP",
    "DEFAULT_LANE_CAP",
    "DEFAULT_INTRA_CAP",
    "REFILL_WINDOW_SEC",
    # backpressure
    "SemaphoreBackpressure",
    "AdaptiveBackpressure",
    "LatencyWindow",
    "DEFAULT_MAX_INFLIGHT",
    "ADAPTIVE_LATENCY_THRESHOLD_MS",
    "ADAPTIVE_BACKOFF_MIN_MS",
    "ADAPTIVE_BACKOFF_MAX_MS",
    "ADAPTIVE_BACKOFF_MULTIPLIER",
]
