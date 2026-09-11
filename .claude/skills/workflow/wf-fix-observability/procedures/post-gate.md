# POST-GATE — wf-fix-observability (QD8 Lane)

> **Reference:** `_shared/lane/post-gate.md` (T1-T4 chuan cho moi lane)
> **Schema:** `_shared/lane/_shared.md` §1, §5
> **Phien ban:** v1.0 (2026-05-09 — QD8 Observability & Reliability)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-observability"
DIMENSION="QD8"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD8-observability"
```

## Tier Validation Chuan (T1-T4)

Doc va thuc hien day du theo `_shared/lane/post-gate.md`.

## QD8-Specific T3 Extension Rules

### T3.5 — External-call evidence required cho retry/circuit-breaker

Signals tu retry-circuit-breaker, timeout-config-audit, trace-propagation PHAI co evidence chua external call snippet:

```bash
EXTERNAL_PROBES=("P-QD8-retry-circuit-breaker" "P-QD8-timeout-config-audit" "P-QD8-trace-propagation")
for probe in "${EXTERNAL_PROBES[@]}"; do
  NO_EVIDENCE=$(jq --arg p "$probe" '[.signals[] | select(.probe_id == $p) | select((.evidence // []) | length == 0)] | length' "$LANE_DIR/signals.json")
  [ "$NO_EVIDENCE" = "0" ] || {
    echo "T3 FAIL: $probe co $NO_EVIDENCE signals khong co evidence" >&2; return 1;
  }
done
```

### T3.6 — Reliability CDG flag enforcement

Signals co severity = critical va lien quan retry/circuit-breaker tren payment/auth endpoint PHAI co `cdg_flags` chua `CDG-RELIABILITY-RISK`:

```bash
RELIABILITY_NO_CDG=$(jq '[.signals[] | select(.severity == "critical" and (.title | test("retry|circuit.breaker|idempoten"; "i"))) | select((.location.file // "") | test("payment|order|checkout|auth"; "i")) | select(((.cdg_flags // []) | map(select(. == "CDG-RELIABILITY-RISK")) | length) == 0)] | length' "$LANE_DIR/signals.json")
[ "$RELIABILITY_NO_CDG" = "0" ] || {
  echo "T3 FAIL: $RELIABILITY_NO_CDG reliability-risk critical signals tren payment/auth thieu CDG-RELIABILITY-RISK flag" >&2; return 1;
}
```

### T3.7 — Health check runtime evidence

P-QD8-health-check-probe signals (runtime) PHAI co HTTP trace evidence:

```bash
HEALTH_NO_RUNTIME_EV=$(jq '[.signals[] | select(.probe_id == "P-QD8-health-check-probe") | select((.evidence // []) | map(select(.type == "http_response" or .type == "trace")) | length == 0)] | length' "$LANE_DIR/signals.json")
[ "$HEALTH_NO_RUNTIME_EV" = "0" ] || {
  echo "T3 WARN: $HEALTH_NO_RUNTIME_EV health-check signals thieu runtime evidence" >&2
}
```

### T3.8 — Log PII leak check (lien quan QD3 — bo sung)

Logs co the leak PII; bo sung self-check chinh tri muc severity:

```bash
LOG_PII=$(jq '[.signals[] | select(.probe_id == "P-QD8-log-coverage-audit") | select(.description | test("password|token|jwt|credit.card|ssn|cccd"; "i")) | select(.severity != "critical" and .severity != "high")] | length' "$LANE_DIR/signals.json")
[ "$LOG_PII" = "0" ] || {
  echo "T3 FAIL: $LOG_PII log-coverage signals co PII keyword voi severity < high" >&2; return 1;
}
```

### T3.9 — Critical: Missing health check tren production deploy

```bash
HEALTH_404=$(jq '[.signals[] | select(.probe_id == "P-QD8-health-check-probe") | select(.title | test("404|not.found|missing"; "i")) | select(.severity != "critical")] | length' "$LANE_DIR/signals.json")
[ "$HEALTH_404" = "0" ] || {
  echo "T3 FAIL: $HEALTH_404 health-check 404 signals voi severity != critical" >&2; return 1;
}
```

## POST-GATE Pass Criteria

Theo `_shared/lane/post-gate.md` §"POST-GATE Pass Criteria".

## CORE-028 Phase Summary

Populate template voi:

- `[DIMENSION]` = QD8, `[DIMENSION_NAME]` = "Observability & Reliability"
- `[ADVICE]` = e.g. "$a reliability-risk critical can resolve truoc deploy production"

## Failure Handling

Theo `_shared/lane/post-gate.md`. Reliability risk + CRITICAL → escalate qua CDG, khong auto-fix.
