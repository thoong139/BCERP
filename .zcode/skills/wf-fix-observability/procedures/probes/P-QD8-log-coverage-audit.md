# P-QD8-log-coverage-audit — Log Coverage & Quality Audit

> **Type:** static (grep+jq) | **Profile:** standard/deep/exhaustive | **Severity default:** MEDIUM | **Cache:** allowed

Phat hien thieu sot ve logging — tang kha nang debug production khi loi xay ra.

---

## Detection Logic

### Step 1 — Catch block thieu logger

```bash
# Find try/catch with empty catch or only `console.log` (not structured logger)
CATCH_NO_LOGGER=$(grep -rEnA1 "} catch \(" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" \
  src/ apps/ 2>/dev/null | grep -E "catch \([^)]*\) \{$|catch \([^)]*\) \{ *\}|console\.")

echo "$CATCH_NO_LOGGER" | head -30 | while IFS=: read -r file line code; do
  emit_signal_jsonl \
    "P-QD8-log-coverage-audit" \
    "medium" \
    "Catch block khong dung structured logger" \
    "Tai $file:$line, catch block bo trong hoac dung console.log thay vi structured logger. Production → khong track duoc loi → khong debug duoc." \
    "$file" "$line" "$code" "[]"
done
```

### Step 2 — Critical operation thieu log

Critical operations: payment, order create, auth login, role change, delete.

```bash
CRITICAL_OPS=$(grep -rEn "createPayment|chargeCard|loginUser|deleteUser|changeRole|approve" \
  --include="*.ts" --include="*.py" \
  src/ apps/ 2>/dev/null | head -50)

echo "$CRITICAL_OPS" | while IFS=: read -r file line code; do
  # Check 5 lines around for logger
  CONTEXT=$(awk "NR>=$((line-2)) && NR<=$((line+5))" "$file" 2>/dev/null)
  HAS_LOG=$(echo "$CONTEXT" | grep -ciE "logger\.|log\.info|log\.warn|log\.error|winston|pino")

  if [ "$HAS_LOG" = "0" ]; then
    emit_signal_jsonl \
      "P-QD8-log-coverage-audit" \
      "medium" \
      "Critical operation thieu structured log" \
      "Tai $file:$line, critical business operation (payment/auth/delete) khong duoc log. Audit trail thieu → kho dieu tra incident." \
      "$file" "$line" "$code" "[]"
  fi
done
```

### Step 3 — Log thieu correlation_id / trace_id

```bash
LOGGER_CALLS=$(grep -rEn "logger\.(info|warn|error|debug)\(" \
  --include="*.ts" --include="*.py" \
  src/ apps/ 2>/dev/null | head -50)

# Sample: check if logger calls include trace_id / correlation_id / requestId
NO_TRACE=$(echo "$LOGGER_CALLS" | grep -v "trace_id\|correlation_id\|requestId\|reqId" | head -20)

echo "$NO_TRACE" | while IFS=: read -r file line code; do
  emit_signal_jsonl \
    "P-QD8-log-coverage-audit" \
    "low" \
    "Logger call thieu trace_id/correlation_id field" \
    "Tai $file:$line, logger goi khong include trace_id/correlation_id de track 1 request qua nhieu services. Distributed tracing → khong correlate log lines." \
    "$file" "$line" "$code" "[]"
done
```

### Step 4 — PII / sensitive data trong log

```bash
PII_LOG=$(grep -rEn "log.*\.(password|jwt|token|cardNumber|cvv|ssn|cccd|cmnd)" \
  --include="*.ts" --include="*.py" \
  src/ apps/ 2>/dev/null | head -10)

echo "$PII_LOG" | while IFS=: read -r file line code; do
  emit_signal_jsonl \
    "P-QD8-log-coverage-audit" \
    "high" \
    "Log co the leak PII / sensitive data" \
    "Tai $file:$line, logger statement chua field nhay cam (password/token/cccd). Production logs aggregated → potential GDPR violation. Bump severity neu duoc xac nhan." \
    "$file" "$line" "$code" "[]"
done
```

## Negative Patterns (KHONG emit)

1. `console.log` trong dev tool, build script.
2. Test file logger setup.
3. Logger trong example/demo code.
