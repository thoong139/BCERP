# Shared Probe Conventions — QD8 Observability & Reliability

Loaded by all 7 probe spec files trong cung directory. Dinh nghia variables, signal emit pattern.

---

## Common Variables

```bash
LANE_NAME="wf-fix-observability"
DIMENSION="QD8"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD8-observability"
RAW_DIR="$LANE_DIR/raw"
SIGNALS_FILE="$LANE_DIR/signals.json"
```

## Signal Emit Pattern

Theo `_shared/lane/signal-emit.md` — atomic JSON merge:

```bash
emit_signal_jsonl() {
  local probe_id="$1"
  local severity="$2"
  local title="$3"
  local description="$4"
  local file="$5"
  local line="$6"
  local code_snippet="$7"
  local cdg_flags="${8:-[]}"

  jq -n \
    --arg pid "$probe_id" \
    --arg sev "$severity" \
    --arg title "$title" \
    --arg desc "$description" \
    --arg file "$file" \
    --argjson line "$line" \
    --arg snippet "$code_snippet" \
    --argjson cdg "$cdg_flags" \
    '{
      "$schema": "signal-v2",
      probe_id: $pid,
      dimension_id: "QD8",
      severity: $sev,
      title: $title,
      description: $desc,
      location: {file: $file, line: $line},
      evidence: [{type: "code", content: $snippet}],
      cdg_flags: $cdg,
      fixability: "agent_fix"
    }' >> "$RAW_DIR/$probe_id.jsonl"
}
```

## Detection Patterns Reference

| Stack | HTTP client pattern | Logger pattern | Metrics pattern |
|-------|---------------------|----------------|-----------------|
| TS/Node | `axios\.|fetch\(|http\.(get|post|request)` | `winston\.|pino\(|console\.(log|info|warn)` | `@opentelemetry|prom-client` |
| Python | `requests\.|httpx\.|aiohttp` | `logging\.|loguru\.|logger\.` | `prometheus_client|opentelemetry` |
| Go | `http\.Get|http\.Post|http\.Do` | `log\.|logrus\.|zap\.` | `prometheus|otel\.` |
| Java | `RestTemplate|WebClient|OkHttp` | `slf4j|log4j|Logger\.` | `Micrometer|OpenTelemetry` |
| C# | `HttpClient\.|WebRequest` | `ILogger|Serilog|NLog` | `Prometheus.Net|OpenTelemetry` |

## CDG Flags

QD8 supports `CDG-RELIABILITY-RISK`:
- Missing circuit breaker tren payment/auth/critical external dep → severity=critical + flag CDG-RELIABILITY-RISK.
- Retry without idempotency on POST endpoint → cung lane.

## Common Self-Check

- Confidence cao chi khi co bang chung cu the (file:line + snippet).
- Severity follow `dimension.json` severity_rules.
- Probe nen skip neu dependency check (logger framework, external HTTP) khong tim thay.
