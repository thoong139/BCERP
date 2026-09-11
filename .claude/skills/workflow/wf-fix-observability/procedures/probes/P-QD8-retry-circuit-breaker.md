# P-QD8-retry-circuit-breaker — Retry & Circuit Breaker Pattern Audit

> **Type:** static (grep+jq) | **Profile:** quick/standard/deep/exhaustive | **Severity default:** HIGH | **Cache:** allowed

Phat hien external HTTP/RPC call thieu retry pattern hoac circuit breaker — gay system fail khi external dep cham/down.

---

## Detection Logic

### Step 1 — Find external HTTP/RPC call sites

```bash
EXTERNAL_CALLS=$(grep -rEn "(axios\.(get|post|put|delete)|fetch\(|http\.(Get|Post)|requests\.(get|post)|RestTemplate\.|HttpClient)" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" --include="*.cs" \
  src/ apps/ 2>/dev/null | head -100)

if [ -z "$EXTERNAL_CALLS" ]; then
  echo "INFO: Khong tim thay external HTTP/RPC call sites" >&2
  exit 0
fi
```

### Step 2 — For each call site, check retry pattern proximity

```bash
echo "$EXTERNAL_CALLS" | while IFS=: read -r file line code; do
  # Check 10 lines around for retry/circuit-breaker keywords
  CONTEXT=$(awk "NR>=$((line-5)) && NR<=$((line+5))" "$file" 2>/dev/null)

  HAS_RETRY=$(echo "$CONTEXT" | grep -ciE "retry|backoff|p-retry|axios-retry|polly|resilience4j|hystrix")
  HAS_CIRCUIT=$(echo "$CONTEXT" | grep -ciE "circuit.?breaker|opossum|hystrix|polly|resilience4j")

  if [ "$HAS_RETRY" = "0" ] && [ "$HAS_CIRCUIT" = "0" ]; then
    # Check if call is on payment/auth path → bump severity
    SEVERITY="high"
    CDG="[]"
    if echo "$file" | grep -qiE "payment|checkout|auth|order"; then
      SEVERITY="critical"
      CDG='["CDG-RELIABILITY-RISK"]'
    fi

    emit_signal_jsonl \
      "P-QD8-retry-circuit-breaker" \
      "$SEVERITY" \
      "External HTTP call thieu retry/circuit breaker" \
      "Tai $file:$line, external HTTP call khong wrap trong retry hoac circuit breaker. Network blip → request fail. Khi dep cham → cascade timeout. Tren payment/auth → impact tien hoac auth." \
      "$file" "$line" "$code" "$CDG"
  fi
done
```

### Step 3 — Check exponential backoff has jitter

Pattern: `setTimeout(retry, 1000 * 2 ** attempt)` thieu jitter → thundering herd.

```bash
THUNDERING_HERD=$(grep -rEn "setTimeout.*\*.*\*\*.*attempt|Math\.pow\(2,.*attempt\)" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" \
  src/ apps/ 2>/dev/null | grep -v "jitter\|random")

echo "$THUNDERING_HERD" | while IFS=: read -r file line code; do
  emit_signal_jsonl \
    "P-QD8-retry-circuit-breaker" \
    "high" \
    "Exponential backoff thieu jitter — risk thundering herd" \
    "Tai $file:$line, retry exponential backoff (2^attempt) khong them jitter random. Khi nhieu client cung fail simultaneously → tat ca retry cung thoi diem → DDOS internal service." \
    "$file" "$line" "$code" "[]"
done
```

## Negative Patterns (KHONG emit)

1. Retry trong CLI script chay 1 lan (offline tool).
2. External call trong test file (`*.test.ts`, `*.spec.ts`).
3. Internal service-to-service call trong cung cluster (low latency, monitored).
