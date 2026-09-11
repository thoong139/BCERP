# P-QD8-metrics-instrumentation — Metrics Instrumentation Coverage

> **Type:** static (grep+jq) | **Profile:** standard/deep/exhaustive | **Severity default:** MEDIUM | **Cache:** allowed

Phat hien thieu sot ve metrics instrumentation — kho monitor production health.

---

## Detection Logic

### Step 1 — Critical endpoint thieu metric instrumentation

```bash
# Find HTTP route handlers (Express, Next.js, FastAPI, NestJS)
ROUTES=$(grep -rEn "@(Get|Post|Put|Delete|Patch)\(|router\.(get|post|put|delete)|app\.(get|post)|@(app|router)\.(get|post)" \
  --include="*.ts" --include="*.py" \
  src/ apps/ 2>/dev/null | head -50)

echo "$ROUTES" | while IFS=: read -r file line code; do
  # Check 20 lines for metrics call
  CONTEXT=$(awk "NR>=$line && NR<=$((line+20))" "$file" 2>/dev/null)
  HAS_METRIC=$(echo "$CONTEXT" | grep -ciE "histogram|counter|gauge|metrics\.(observe|inc|set)|prom-client|@opentelemetry|micrometer")

  if [ "$HAS_METRIC" = "0" ]; then
    # Check if route is critical (payment/auth)
    SEVERITY="low"
    if echo "$file$code" | grep -qiE "payment|checkout|auth|login|order"; then
      SEVERITY="medium"
    fi
    emit_signal_jsonl \
      "P-QD8-metrics-instrumentation" \
      "$SEVERITY" \
      "Endpoint thieu metric instrumentation (latency/count)" \
      "Tai $file:$line, route handler khong record metrics (histogram cho latency, counter cho request count). SRE khong monitor duoc baseline performance + error rate." \
      "$file" "$line" "$code" "[]"
  fi
done | head -30
```

### Step 2 — High-cardinality label warning

Label `user_id`, `request_id`, `session_id` lam time-series cardinality explode → Prometheus crash.

```bash
HIGH_CARDINALITY=$(grep -rEn "labels?:?.*['\"](user_id|userId|request_id|session_id|order_id|email)" \
  --include="*.ts" --include="*.py" \
  src/ apps/ 2>/dev/null | head -10)

echo "$HIGH_CARDINALITY" | while IFS=: read -r file line code; do
  emit_signal_jsonl \
    "P-QD8-metrics-instrumentation" \
    "medium" \
    "Metric label co high-cardinality risk" \
    "Tai $file:$line, metric label dung user_id/session_id → time-series cardinality phi mã (100k+ labels) → Prometheus storage explode + query slow. Dung trace_id ngoài log thay vi label." \
    "$file" "$line" "$code" "[]"
done
```

### Step 3 — Counter increment thieu mo ta error type

Pattern: `errorCounter.inc()` khong co label phan biet error type.

```bash
ERROR_COUNTER_NO_LABEL=$(grep -rEnA1 "errorCounter\.inc\(|errors_total\.inc\(" \
  --include="*.ts" --include="*.py" \
  src/ apps/ 2>/dev/null | grep -v "labels\|err.code\|err\.type")

echo "$ERROR_COUNTER_NO_LABEL" | head -10 | while IFS=: read -r file line code; do
  emit_signal_jsonl \
    "P-QD8-metrics-instrumentation" \
    "low" \
    "Error counter increment thieu label de phan loai error" \
    "Tai $file:$line, error counter inc() khong di kem label (error_type, status_code). SRE khong phan biet 4xx vs 5xx vs DB error → alert noisy." \
    "$file" "$line" "$code" "[]"
done
```

## Negative Patterns (KHONG emit)

1. Endpoint la pure static asset / health check (da co riêng).
2. Internal admin tool truy cap rare.
3. Metrics framework khong duoc deploy (project not requiring observability).
