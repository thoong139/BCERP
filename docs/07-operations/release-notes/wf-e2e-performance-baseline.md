# wf-e2e Pipeline — Performance Baseline

## Metrics Đo

| Metric | Đơn vị | Đo bằng |
|--------|--------|---------|
| Total runtime F0→F8 | phút | session timestamps |
| Per-phase runtime | giây | phase start/complete |
| Context usage per phase | % | context_estimate_pct |
| Agent spawn count | số | session-log.json |
| File writes | số | session-log.json |

## Baseline (v7.0 — trước refactor)

| Scenario | v7.0 Actual |
|----------|-------------|
| Simple FEAT (FIN-002) | ~20 min |
| Complex FEAT với cross-module | ~60 min |
| Context overflow rate | ~30% sessions |
| Flaky scenario rate | ~15% |

## Targets (v8.0)

| Scenario | Target | Acceptance |
|----------|--------|-----------|
| Simple FEAT | ≤30 min | +50% overhead OK (F0+F0a+F0b) |
| Complex FEAT | ≤90 min | |
| Batch 3 FEATs parallel | ≤2.5h | |
| Context overflow rate | <5% | ≥80% giảm (G4 checkpoint) |
| Flaky scenario rate | <5% | (G1 elimination) |

## Benchmark Run

```bash
# Run benchmark (sau khi có fixture FEATs)
python3 tools/benchmark/wf-e2e-pipeline-benchmark.py --scenario=simple
python3 tools/benchmark/wf-e2e-pipeline-benchmark.py --scenario=complex
python3 tools/benchmark/wf-e2e-pipeline-benchmark.py --scenario=batch3
```

## Acceptance Criteria

- Performance regression ≤30% acceptable (v8 tăng features)
- Context overflow giảm ≥80%
- Flaky rate <5%
