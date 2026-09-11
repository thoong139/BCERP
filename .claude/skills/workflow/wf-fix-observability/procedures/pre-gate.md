# PRE-GATE — wf-fix-observability (QD8 Lane)

> **Reference:** `_shared/lane/pre-gate.md` (steps 1-7 chuan cho moi lane)
> **Schema:** `_shared/lane/_shared.md` §5 (lane-status-v1)
> **Phien ban:** v1.0 (2026-05-09 — QD8 Observability & Reliability)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-observability"
DIMENSION="QD8"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD8-observability"
```

## Steps Chuan (1-7)

Doc va thuc hien day du theo `_shared/lane/pre-gate.md`:

1. Verify orchestrator handoff (`SESSION_DIR`, `fix-status.json`)
2. Verify input data (registry + source dirs)
3. Verify dimension scope (QD8 trong dimensions_resolved)
4. Resolve profile → probe subset (Pattern A inline, xem `_shared/lane/profile-resolver.md` §QD8)
5. Initialize lane working dir
6. Init `lane-status.json` tu shared template
7. Init `signals.json` tu shared template

## QD8-Specific Extension Steps

### Step 8 — Detect external HTTP/RPC patterns (cho retry/circuit-breaker probe)

```bash
# Detect external HTTP call patterns
EXTERNAL_HTTP=$(grep -rE "axios\.|fetch\(|http\.get|http\.post|requests\.|RestTemplate|HttpClient" \
  src/ apps/ 2>/dev/null | head -1)
if [ -z "$EXTERNAL_HTTP" ]; then
  echo "INFO: Khong tim thay external HTTP call patterns — P-QD8-retry-circuit-breaker se skip" >&2
fi

# Detect logger framework
LOGGER=$(grep -rE "winston|pino|bunyan|loguru|logging\.|slf4j|log4j" \
  src/ apps/ package.json requirements.txt 2>/dev/null | head -1)
if [ -z "$LOGGER" ]; then
  echo "INFO: Khong detect duoc logger framework — P-QD8-log-coverage-audit se skip" >&2
fi

# Detect metrics framework
METRICS=$(grep -rE "prom-client|@opentelemetry|micrometer|statsd" \
  src/ apps/ package.json requirements.txt 2>/dev/null | head -1)
if [ -z "$METRICS" ]; then
  echo "INFO: Khong detect duoc metrics framework — P-QD8-metrics-instrumentation se skip" >&2
fi
```

### Step 9 — Verify --base-url cho runtime probe

```bash
if [ -z "${BASE_URL:-}" ]; then
  echo "INFO: BASE_URL khong set, runtime probe (P-QD8-health-check-probe) se skip" >&2
fi
```

### Step 10 — Resolve probe list theo profile (QD8)

```bash
case "$PROFILE" in
  quick)
    PROBES=("P-QD8-retry-circuit-breaker" "P-QD8-timeout-config-audit")
    ;;
  standard)
    PROBES=("P-QD8-retry-circuit-breaker" "P-QD8-timeout-config-audit"
            "P-QD8-log-coverage-audit" "P-QD8-metrics-instrumentation"
            "P-QD8-health-check-probe")
    ;;
  deep)
    PROBES=("P-QD8-retry-circuit-breaker" "P-QD8-timeout-config-audit"
            "P-QD8-log-coverage-audit" "P-QD8-metrics-instrumentation"
            "P-QD8-health-check-probe" "P-QD8-trace-propagation")
    ;;
  exhaustive)
    PROBES=("P-QD8-retry-circuit-breaker" "P-QD8-timeout-config-audit"
            "P-QD8-log-coverage-audit" "P-QD8-metrics-instrumentation"
            "P-QD8-health-check-probe" "P-QD8-trace-propagation"
            "P-QD8-alert-rule-audit")
    ;;
esac
```

## PRE-GATE Failure Handling

Theo `_shared/lane/pre-gate.md` §"PRE-GATE Failure Handling".

## Resume Behavior

Theo `_shared/lane/pre-gate.md` §"Resume Behavior".
