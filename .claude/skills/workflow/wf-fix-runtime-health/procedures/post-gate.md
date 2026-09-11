# POST-GATE — wf-fix-runtime-health (QD9 Lane)

> **Reference:** `_shared/lane/post-gate.md` (T1-T4 chuan cho moi lane)
> **Schema:** `_shared/lane/_shared.md` §1, §5
> **Phien ban:** v1.0 (2026-05-10 — QD9 Runtime Health Verification)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-runtime-health"
DIMENSION="QD9"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health"
```

## Tier Validation Chuan (T1-T4)

Doc va thuc hien day du theo `_shared/lane/post-gate.md`.

## QD9-Specific T3 Extension Rules

### T3.5 — Browser evidence required cho runtime signals

Moi signal tu runtime probes (console-network-monitor, auth-aware-smoke, feature-checklist-smoke, interactive-smoke) PHAI co evidence:

```bash
RUNTIME_PROBES=(
  "P-QD9-console-network-monitor"
  "P-QD9-auth-aware-smoke"
  "P-QD9-feature-checklist-smoke"
  "P-QD9-interactive-smoke"
)
for probe in "${RUNTIME_PROBES[@]}"; do
  NO_EVIDENCE=$(jq --arg p "$probe" \
    '[.signals[] | select(.probe_id == $p) | select((.evidence // []) | length == 0)] | length' \
    "$LANE_DIR/signals.json")
  [ "$NO_EVIDENCE" = "0" ] || {
    echo "T3 FAIL: $probe co $NO_EVIDENCE signals khong co evidence (screenshot hoac log_excerpt required)" >&2
    return 1
  }
done
```

### T3.6 — Console error / pageerror severity enforcement

Signals pageerror (uncaught exception) PHAI co severity=critical hoac high:

```bash
PAGEERROR_LOW=$(jq '[.signals[] | select(.probe_id == "P-QD9-console-network-monitor") | select(.signal_type == "runtime_uncaught_exception") | select(.severity == "low" or .severity == "medium")] | length' "$LANE_DIR/signals.json")
[ "$PAGEERROR_LOW" = "0" ] || {
  echo "T3 FAIL: $PAGEERROR_LOW pageerror signals voi severity thap hon high — phai la high hoac critical" >&2
  return 1
}
```

### T3.7 — Dev server state evidence

P-QD9-dev-server-bootstrap PHAI tao dev-server-state.json khi thanh cong:

```bash
if [ -f "$LANE_DIR/../../../signals/QD9-ran.flag" ] || \
   jq -e '.signals[] | select(.probe_id == "P-QD9-dev-server-bootstrap")' "$LANE_DIR/signals.json" > /dev/null 2>&1; then
  # Probe ran — check state file
  if [ ! -f "$LANE_DIR/dev-server-state.json" ]; then
    echo "T3 WARN: P-QD9-dev-server-bootstrap chay nhung khong tao dev-server-state.json" >&2
    # WARN only — khong block lane (co the server da running tu truoc)
  fi
fi
```

### T3.8 — Network failure evidence

5xx signals tu console-network-monitor PHAI co url + status trong evidence:

```bash
NETWORK_5XX_NO_EV=$(jq '[.signals[] | select(.probe_id == "P-QD9-console-network-monitor") | select(.signal_type == "runtime_network_failure") | select(.severity == "high") | select((.evidence // []) | map(select(.type == "network_trace" or .type == "http_response")) | length == 0)] | length' "$LANE_DIR/signals.json")
[ "$NETWORK_5XX_NO_EV" = "0" ] || {
  echo "T3 FAIL: $NETWORK_5XX_NO_EV network 5xx signals thieu network_trace evidence" >&2
  return 1
}
```

## POST-GATE Pass Criteria

Theo `_shared/lane/post-gate.md` §"POST-GATE Pass Criteria".

## CORE-028 Phase Summary

Populate template voi:

- `[DIMENSION]` = QD9, `[DIMENSION_NAME]` = "Runtime Health Verification"
- `[ADVICE]` = e.g. "$a console errors/network failures can kiem tra tren browser truoc deploy"

## Failure Handling

Theo `_shared/lane/post-gate.md`. Runtime browser errors → wf-fix-triage classify. Khong co CDG auto-flag (QD9 khong co CRITICAL payment/auth escalation pattern; chi emit signals binh thuong).
