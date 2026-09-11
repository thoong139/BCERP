# QD6 Shared Probe Protocols

## 1. Signal Emission Protocol

Signal schema signal-v2. Moi signal phai co:
- `dimension_id: "QD6"`
- `probe_id` match `^P-QD6-[a-z0-9-]+$`
- `description` >= 10 ky tu
- It nhat 1 evidence field non-empty (ADR-09)

Raw output: `$SESSION_DIR/phase4-find-bugs/lanes/QD6-data/raw/P-QD6-<probe>.json`

## 2. Scan Cache Protocol

Cache policy: **allowed** cho static probes. Runtime probes luon skip cache.

## 3. Severity Mapping (QD6)

| Pattern | Severity |
|---------|----------|
| Critical trigger | CRITICAL |
| High trigger | HIGH |
| Medium trigger | MEDIUM |
| Informational | LOW |

## 4. Profile-Based Probe Selection

Chay probes theo profile (quick/standard/deep/exhaustive).
Xem dimension.json exit_criteria cho probe list chinh xac.

## 5. Checkpoint Protocol

Sau moi probe, update lane-status.json voi probe status va signal count.
