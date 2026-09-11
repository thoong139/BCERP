"""signal_bus — Signal to Issue normalization bus.

Shared utility module cho các QD lane trong `/wf-fix-bugs` v6.0. Nhận Signal
v2 thô từ probe, validate evidence (ADR-09, ≥1 non-empty + MIN_EVIDENCE_LENGTH),
dedup theo target (sha256(dimension|file_path|line_range|symbol)), normalize
thành Issue v2, detect secrets hint (ADR-22 rule 4 → CDG), emit vào
`issue-registry.json` (POST-GATE T1-T4).

ADR refs: ADR-02, ADR-04, ADR-09, ADR-22 rule 4 (secrets CDG),
ADR-22 rule 5 (POST-GATE T1-T4).

Public API:
    - Signal, Issue (data classes)
    - validate_evidence, compute_dedup_key, detect_secrets_hint
    - normalize, merge_or_append, post_gate_check
    - SignalBus (session-bound facade)
    - Constants: VALID_DIMENSIONS, VALID_EVIDENCE_KINDS, MIN_EVIDENCE_LENGTH,
      SECRETS_HINT_PATTERNS
"""

from .signal_bus import (
    MIN_EVIDENCE_LENGTH,
    SECRETS_HINT_PATTERNS,
    VALID_DIMENSIONS,
    VALID_EVIDENCE_KINDS,
    Issue,
    Signal,
    SignalBus,
    compute_dedup_key,
    detect_secrets_hint,
    merge_or_append,
    normalize,
    post_gate_check,
    validate_evidence,
)

__version__ = "0.2.0-b2"

__all__ = [
    # Data classes
    "Signal",
    "Issue",
    # Core functions
    "validate_evidence",
    "compute_dedup_key",
    "detect_secrets_hint",
    "normalize",
    "merge_or_append",
    "post_gate_check",
    # Session facade
    "SignalBus",
    # Constants
    "VALID_DIMENSIONS",
    "VALID_EVIDENCE_KINDS",
    "MIN_EVIDENCE_LENGTH",
    "SECRETS_HINT_PATTERNS",
]
