# P-QD8-trace-propagation — Distributed Trace Propagation Audit

> **Type:** static (grep+jq) | **Profile:** deep/exhaustive | **Severity default:** MEDIUM | **Cache:** allowed

Phat hien tracing context (W3C TraceContext, OpenTelemetry) khong propagate giua services → distributed trace bi gay.

---

## Detection Logic

### Step 1 — Find external HTTP call without trace header propagation

```bash
EXTERNAL_HTTP=$(grep -rEn "axios\.(get|post)|fetch\(|http\.(Get|Post)|requests\.(get|post)" \
  --include="*.ts" --include="*.py" --include="*.go" \
  src/ apps/ 2>/dev/null | head -50)

echo "$EXTERNAL_HTTP" | while IFS=: read -r file line code; do
  # Check 5 lines around for traceparent / W3C TraceContext / OTEL inject
  CONTEXT=$(awk "NR>=$((line-3)) && NR<=$((line+8))" "$file" 2>/dev/null)
  HAS_TRACE=$(echo "$CONTEXT" | grep -ciE "traceparent|tracestate|W3CTraceContext|otel\.(inject|propagat)|trace_id|x-request-id")

  if [ "$HAS_TRACE" = "0" ]; then
    emit_signal_jsonl \
      "P-QD8-trace-propagation" \
      "medium" \
      "External HTTP call khong propagate trace context" \
      "Tai $file:$line, external HTTP call khong gan header traceparent/tracestate (W3C) hoac dong OTEL inject. Distributed trace bi gay — khong correlate request qua services trong Jaeger/Datadog." \
      "$file" "$line" "$code" "[]"
  fi
done | head -20
```

### Step 2 — Find queue/event publish without trace context

```bash
QUEUE_PUBLISH=$(grep -rEn "publish\(|sendMessage\(|sqs\.send|sns\.publish|kafka\.send|amqp\.publish" \
  --include="*.ts" --include="*.py" \
  src/ apps/ 2>/dev/null | head -30)

echo "$QUEUE_PUBLISH" | while IFS=: read -r file line code; do
  CONTEXT=$(awk "NR>=$((line-3)) && NR<=$((line+5))" "$file" 2>/dev/null)
  HAS_TRACE=$(echo "$CONTEXT" | grep -ciE "traceparent|trace_id|otel\.(inject|propagat)|MessageAttributes.*trace")

  if [ "$HAS_TRACE" = "0" ]; then
    emit_signal_jsonl \
      "P-QD8-trace-propagation" \
      "medium" \
      "Queue publish khong propagate trace context" \
      "Tai $file:$line, message publish khong dinh trace context vao MessageAttributes / headers. Consumer service mat upstream context → trace bi gay." \
      "$file" "$line" "$code" "[]"
  fi
done | head -10
```

### Step 3 — Check if OTEL SDK / tracing library configured

```bash
HAS_OTEL_SDK=$(grep -rEn "@opentelemetry/sdk|opentelemetry\.trace|init.*tracer|setTracerProvider" \
  --include="*.ts" --include="*.py" --include="*.js" \
  src/ apps/ 2>/dev/null | head -3)

if [ -z "$HAS_OTEL_SDK" ]; then
  # Check if metrics framework present (suggesting observability platform configured)
  HAS_METRICS=$(grep -rEn "@opentelemetry|prom-client|micrometer" \
    --include="package.json" --include="requirements.txt" --include="pom.xml" \
    . 2>/dev/null | head -1)

  if [ -n "$HAS_METRICS" ]; then
    emit_signal_jsonl \
      "P-QD8-trace-propagation" \
      "medium" \
      "Metrics duoc setup nhung tracing SDK chua init" \
      "Project co metrics framework (OTEL/Prom) nhung khong tim thay tracing SDK init. Observability stack incomplete: metrics tracks aggregate, traces tracks individual request → 2 mode bo sung lan nhau." \
      "package.json" 1 "" "[]"
  fi
fi
```

## Negative Patterns (KHONG emit)

1. Single-service monolith khong co downstream → tracing optional.
2. Internal call cung process (in-memory function call).
3. Test fixture khong can trace.
