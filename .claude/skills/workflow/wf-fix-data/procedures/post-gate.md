# POST-GATE — wf-fix-data (QD6 Lane)

> **Reference:** `_shared/lane/post-gate.md` (T1-T4 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §1, §5
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-data"
DIMENSION="QD6"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD6-data"
```

## Tier Validation Chuẩn (T1-T4)

Đọc và thực hiện đầy đủ theo `_shared/lane/post-gate.md`.

## QD6-Specific T3 Extension Rules

### T3.5 — Schema/migration evidence required

Signals từ schema-drift-detect, migration-integrity, orm-model-sync PHẢI có evidence với schema_diff hoặc migration content:

```bash
SCHEMA_PROBES=("P-QD6-schema-drift-detect" "P-QD6-migration-integrity" "P-QD6-orm-model-sync")
for probe in "${SCHEMA_PROBES[@]}"; do
  NO_EVIDENCE=$(jq --arg p "$probe" '[.signals[] | select(.probe_id == $p) | select((.evidence // []) | length == 0)] | length' "$LANE_DIR/signals.json")
  [ "$NO_EVIDENCE" = "0" ] || {
    echo "T3 FAIL: $probe co $NO_EVIDENCE signals khong co evidence" >&2; return 1;
  }
done
```

### T3.6 — CDG flag enforcement cho schema-break

Signals có severity = critical và title chứa "drop|delete|alter" PHẢI có `cdg_flags` chứa `CDG-SCHEMA-BREAK` hoặc `CDG-DELETE-DATA`:

```bash
SCHEMA_BREAK_NO_CDG=$(jq '[.signals[] | select(.severity == "critical" and (.title | test("drop|delete|alter|migrate"; "i"))) | select(((.cdg_flags // []) | map(select(. == "CDG-SCHEMA-BREAK" or . == "CDG-DELETE-DATA")) | length) == 0)] | length' "$LANE_DIR/signals.json")
[ "$SCHEMA_BREAK_NO_CDG" = "0" ] || {
  echo "T3 FAIL: $SCHEMA_BREAK_NO_CDG schema-break critical signals thieu CDG-SCHEMA-BREAK/CDG-DELETE-DATA flag" >&2; return 1;
}
```

### T3.7 — Constraint violation evidence

P-QD6-constraint-violation signals (runtime) PHẢI có HTTP trace hoặc error_log evidence:

```bash
CONSTRAINT_NO_RUNTIME_EV=$(jq '[.signals[] | select(.probe_id == "P-QD6-constraint-violation") | select((.evidence // []) | map(select(.type == "http_response" or .type == "log" or .type == "trace")) | length == 0)] | length' "$LANE_DIR/signals.json")
[ "$CONSTRAINT_NO_RUNTIME_EV" = "0" ] || {
  echo "T3 WARN: $CONSTRAINT_NO_RUNTIME_EV constraint-violation signals thieu runtime evidence" >&2
}
```

### T3.8 — Critical: Missing idempotency on payment/order endpoint

```bash
IDEMPOTENCY_LOW=$(jq '[.signals[] | select(.description | test("idempotenc"; "i")) | select(.location.file | test("payment|order|checkout"; "i")) | select(.severity != "critical")] | length' "$LANE_DIR/signals.json")
[ "$IDEMPOTENCY_LOW" = "0" ] || {
  echo "T3 FAIL: $IDEMPOTENCY_LOW idempotency signals tren payment/order voi severity != critical" >&2; return 1;
}
```

## POST-GATE Pass Criteria

Theo `_shared/lane/post-gate.md` §"POST-GATE Pass Criteria".

## CORE-028 Phase Summary

Populate template với:

- `[DIMENSION]` = QD6, `[DIMENSION_NAME]` = "Data Integrity & Resilience"
- `[ADVICE]` = e.g. "$a schema drift critical can resolve truoc deploy"

## Failure Handling

Theo `_shared/lane/post-gate.md`. Schema-break + CRITICAL → escalate qua CDG, không auto-fix.
