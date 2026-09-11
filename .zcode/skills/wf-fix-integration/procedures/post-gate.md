# POST-GATE — wf-fix-integration (QD10 Lane)

> **Reference:** `_shared/lane/post-gate.md` (T1-T4 chuan cho moi lane)
> **Schema:** `_shared/lane/_shared.md` §1, §5
> **Phien ban:** v1.0 (2026-05-10 — QD10 Cross-Module Integration)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-integration"
DIMENSION="QD10"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD10-integration"
```

## Tier Validation Chuan (T1-T4)

Doc va thuc hien day du theo `_shared/lane/post-gate.md`.

## QD10-Specific T3 Extension Rules

### T3.5 — Cross-module signal phai co provider + consumer evidence

Moi signal tu cross-module probes PHAI co evidence mo ta provider va consumer cu the:

```bash
CROSS_MODULE_PROBES=(
  "P-QD10-cross-module-ref-static"
  "P-QD10-api-contract-drift"
  "P-QD10-event-handler-coverage"
)
for probe in "${CROSS_MODULE_PROBES[@]}"; do
  NO_EVIDENCE=$(jq --arg p "$probe" \
    '[.signals[] | select(.probe_id == $p) | select((.evidence // []) | length == 0)] | length' \
    "$LANE_DIR/signals.json")
  [ "$NO_EVIDENCE" = "0" ] || {
    echo "T3 FAIL: $probe co $NO_EVIDENCE signals khong co evidence (provider+consumer path required)" >&2
    return 1
  }
done
```

### T3.6 — Orphan reference signal phai co DB query evidence

P-QD10-orphan-reference-runtime signals PHAI co query_result evidence:

```bash
ORPHAN_NO_QUERY=$(jq \
  '[.signals[] | select(.probe_id == "P-QD10-orphan-reference-runtime") |
    select((.evidence // []) | map(select(.type == "query_result")) | length == 0)] | length' \
  "$LANE_DIR/signals.json")
[ "$ORPHAN_NO_QUERY" = "0" ] || {
  echo "T3 FAIL: $ORPHAN_NO_QUERY orphan-reference signals thieu query_result evidence" >&2
  return 1
}
```

### T3.7 — API drift signal phai co schema evidence

P-QD10-api-contract-drift signals PHAI co schema_diff evidence:

```bash
DRIFT_NO_SCHEMA=$(jq \
  '[.signals[] | select(.probe_id == "P-QD10-api-contract-drift") |
    select((.evidence // []) | map(select(.type == "schema_diff" or .type == "field_diff")) | length == 0)] | length' \
  "$LANE_DIR/signals.json")
[ "$DRIFT_NO_SCHEMA" = "0" ] || {
  echo "T3 FAIL: $DRIFT_NO_SCHEMA api-contract-drift signals thieu schema_diff evidence" >&2
  return 1
}
```

### T3.8 — Orphan reference CRITICAL severity enforcement

Signals orphan_reference PHAI co severity=critical (data integrity risk):

```bash
ORPHAN_LOW=$(jq \
  '[.signals[] | select(.signal_type == "orphan_reference") |
    select(.severity != "critical")] | length' \
  "$LANE_DIR/signals.json")
[ "$ORPHAN_LOW" = "0" ] || {
  echo "T3 FAIL: $ORPHAN_LOW orphan_reference signals voi severity < critical — phai la critical" >&2
  return 1
}
```

## POST-GATE Pass Criteria

Theo `_shared/lane/post-gate.md` §"POST-GATE Pass Criteria".

CDG escalation: khi co signal `orphan_reference` (CRITICAL) trong payment hoac auth modules → CDG-RELIABILITY-RISK render (QD10 la reliability-risk domain — per _shared.md severity table).

## CORE-028 Phase Summary

Populate template voi:

- `[DIMENSION]` = QD10, `[DIMENSION_NAME]` = "Cross-Module Integration"
- `[ADVICE]` = e.g. "$n cross-module drifts phat hien — uu tien fix orphan references (data integrity) truoc API contract violations"

## Failure Handling

Theo `_shared/lane/post-gate.md`. Cross-module errors → wf-fix-triage classify. CDG auto-flag khi orphan_reference CRITICAL trong payment/auth modules.
