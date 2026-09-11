# P-QD8-timeout-config-audit — Timeout Configuration Audit

> **Type:** static (grep+jq) | **Profile:** quick/standard/deep/exhaustive | **Severity default:** HIGH | **Cache:** allowed

Phat hien external HTTP/DB/queue call khong cau hinh timeout — default infinite gay request hang khi dep cham.

---

## Detection Logic

### Step 1 — External HTTP without timeout

```bash
# Pattern: axios call khong co {timeout: ...}
AXIOS_NO_TIMEOUT=$(grep -rEn "axios\.(get|post|put|delete)\([^)]*\)" \
  --include="*.ts" --include="*.tsx" --include="*.js" \
  src/ apps/ 2>/dev/null | grep -v "timeout")

echo "$AXIOS_NO_TIMEOUT" | while IFS=: read -r file line code; do
  emit_signal_jsonl \
    "P-QD8-timeout-config-audit" \
    "high" \
    "axios call khong cau hinh timeout (default infinite)" \
    "Tai $file:$line, axios call khong them { timeout: <ms> }. Default = infinite → khi server cham hoac hang → request hang chiem connection. Nhieu request hang → connection pool exhaust." \
    "$file" "$line" "$code" "[]"
done

# Pattern: fetch() khong AbortSignal/timeout
FETCH_NO_TIMEOUT=$(grep -rEn "fetch\(" \
  --include="*.ts" --include="*.tsx" --include="*.js" \
  src/ apps/ 2>/dev/null | grep -v "AbortSignal\|signal:")

echo "$FETCH_NO_TIMEOUT" | head -50 | while IFS=: read -r file line code; do
  emit_signal_jsonl \
    "P-QD8-timeout-config-audit" \
    "medium" \
    "fetch() khong gan AbortSignal cho timeout" \
    "Tai $file:$line, fetch() khong dung AbortSignal de cancel sau timeout. Default browser/Node fetch khong tu timeout → request hang." \
    "$file" "$line" "$code" "[]"
done
```

### Step 2 — Python requests without timeout

```bash
PYTHON_NO_TIMEOUT=$(grep -rEn "requests\.(get|post|put|delete)\([^)]*\)" \
  --include="*.py" \
  src/ apps/ 2>/dev/null | grep -v "timeout")

echo "$PYTHON_NO_TIMEOUT" | while IFS=: read -r file line code; do
  emit_signal_jsonl \
    "P-QD8-timeout-config-audit" \
    "high" \
    "requests.* khong cau hinh timeout" \
    "Tai $file:$line, requests goi khong co timeout=. Library default = None (infinite). Production → request hang qua nha." \
    "$file" "$line" "$code" "[]"
done
```

### Step 3 — Database query timeout

```bash
# pg/postgres pool khong set statement_timeout
PG_NO_TIMEOUT=$(grep -rEn "new Pool\(|createConnection\(" \
  --include="*.ts" --include="*.js" \
  src/ apps/ 2>/dev/null | grep -v "statement_timeout\|connectionTimeoutMillis")

echo "$PG_NO_TIMEOUT" | head -10 | while IFS=: read -r file line code; do
  emit_signal_jsonl \
    "P-QD8-timeout-config-audit" \
    "high" \
    "DB connection pool khong cau hinh statement_timeout" \
    "Tai $file:$line, pg.Pool / createConnection khong set statement_timeout. Slow query → block connection. Recommend statement_timeout = 30s." \
    "$file" "$line" "$code" "[]"
done
```

## Negative Patterns (KHONG emit)

1. Timeout = 0 trong test fixtures.
2. Test file (`*.test.*`).
3. Internal service-to-service call co timeout o transport layer (gRPC deadline).
