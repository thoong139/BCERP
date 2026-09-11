"""workload_estimator — Ước lượng fix workload cho Workload Gate.

Shared utility module cho `/wf-fix-discover` Phase 0 v6.0+. Tính số probe ×
file × avg-time × profile-multiplier, convert ra seconds, emit
`fix-workload.json` để ISG render và Workload Gate quyết định split/proceed
(45 phút = 2700s threshold). Partition Plan A (by_scope) và Plan B (by_dim)
per ADR-15.

ADR refs: ADR-14 (Workload Gate), ADR-15 (Partition Planner),
ADR-22 rule 1 (safety floor).

Public API:
    - LaneEstimate, PartitionPlan, Workload (data classes)
    - estimate_lane, count_files_in_scope, check_gate
    - propose_partitions, estimate, emit
    - Constants: PROBES_PER_DIM, AVG_TIME_PER_FILE_SEC, PROFILE_MULTIPLIER,
      GATE_THRESHOLD_SEC_DEFAULT, SCHEMA_ID
"""

from .estimator import (
    AVG_TIME_PER_FILE_SEC,
    GATE_THRESHOLD_SEC_DEFAULT,
    PROBES_PER_DIM,
    PROFILE_MULTIPLIER,
    SCHEMA_ID,
    LaneEstimate,
    PartitionPlan,
    Workload,
    check_gate,
    count_files_in_scope,
    emit,
    estimate,
    estimate_lane,
    propose_partitions,
)

__version__ = "0.2.0-b2"

__all__ = [
    # Data classes
    "LaneEstimate",
    "PartitionPlan",
    "Workload",
    # Core functions
    "estimate_lane",
    "count_files_in_scope",
    "check_gate",
    "propose_partitions",
    "estimate",
    "emit",
    # Constants
    "PROBES_PER_DIM",
    "AVG_TIME_PER_FILE_SEC",
    "PROFILE_MULTIPLIER",
    "GATE_THRESHOLD_SEC_DEFAULT",
    "SCHEMA_ID",
]
