"""partition — Generic partition planner + workload gate cho linear skills.

Cung cấp 2 chức năng chính:
    1. plan_partitions: Chia items thành partitions theo group_key
    2. check_workload_gate: Đánh giá workload và quyết định Plan A / Plan B

Registry role: NONE.

Public API:
    - plan_partitions: chia items theo group key
    - estimate_workload: ước lượng tổng thời gian
    - check_workload_gate: gate decision (dead_zone/warn/block)
    - Partition: dataclass cho 1 partition
    - WorkloadEstimate: dataclass cho workload estimate
    - GateResult: dataclass cho gate decision
"""
from __future__ import annotations

from .planner import Partition, WorkloadEstimate, estimate_workload, plan_partitions
from .workload_gate import GateResult, check_workload_gate

__version__ = "0.1.0"

__all__ = [
    "plan_partitions",
    "estimate_workload",
    "check_workload_gate",
    "Partition",
    "WorkloadEstimate",
    "GateResult",
]
