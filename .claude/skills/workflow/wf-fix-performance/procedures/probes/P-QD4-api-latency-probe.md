# P-QD4-api-latency-probe — Do latency API endpoint

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD4-api-latency-probe |
| **Loai** | runtime |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Do p50/p95/p99 response time cho API endpoints. Phat hien endpoints vuot nguong threshold. |
| **Cache** | **skip** (runtime probe — moi lan do khac nhau) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF --base-url khong duoc cung cap (BASE_URL empty) -> SKIP, note "no_base_url"
IF khong co curl installed -> SKIP, note "curl_unavailable"
IF profile=quick -> SKIP (chi chay o standard+)
IF khong tim thay API routes (src/routes, src/api, pages/api, app/api) -> chi do BASE_URL health check, khong do tung endpoint
```

## SENSE

### B1: Delegate to inline bash runtime measurement (S5 v7.0)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/raw/P-QD4-api-latency-probe.json"
mkdir -p "$(dirname "$RAW_OUT")"
SIGNALS_JSON='[]'

BASE_URL="${BASE_URL:-}"
[ -z "$BASE_URL" ] && {
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-performance","dimension":"QD4",
 "probe_id":"P-QD4-api-latency-probe","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"no_base_url"}
EOF
  exit 0
}

API_ROUTES_FILE="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/runtime/api_endpoints.txt"
mkdir -p "$(dirname "$API_ROUTES_FILE")"

# Auto-discover API endpoints from source code
API_ENDPOINTS=("$BASE_URL/api/health" "$BASE_URL/health" "$BASE_URL/api/v1/health")
SOURCE="${SOURCE_DIR:-src/}"
if [ -d "$SOURCE" ]; then
  # Discover routes from common framework patterns
  discovered=$(grep -rnhE '(router\.(get|post|put|delete|patch)|app\.(get|post|put|delete|patch)|Route::|@(Get|Post|Put|Delete|Patch)\()' \
    "$SOURCE" --include='*.ts' --include='*.js' --include='*.py' --include='*.java' --include='*.go' \
    2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.)' \
    | sed -E 's/.*["'\'']([^"'\'']*)["'\'']/\1/' | grep '^/' | sort -u | head -20 || true)
  while IFS= read -r path; do
    [ -n "$path" ] && API_ENDPOINTS+=("$BASE_URL$path")
  done <<< "$discovered"
fi

# Deduplicate endpoints
IFS=$'\n' API_ENDPOINTS=($(printf "%s\n" "${API_ENDPOINTS[@]}" | sort -u))

# Configuration
REQUEST_COUNT="${API_REQUEST_COUNT:-5}"
TIMEOUT_SEC="${API_TIMEOUT_SEC:-10}"
P95_WARN_MS="${API_P95_WARN_MS:-500}"    # MEDIUM threshold
P95_FAIL_MS="${API_P95_FAIL_MS:-2000}"   # HIGH threshold
P99_FAIL_MS="${API_P99_FAIL_MS:-10000}"  # CRITICAL threshold

for endpoint in "${API_ENDPOINTS[@]}"; do
  # Skip empty endpoints
  [ -z "$endpoint" ] && continue

  # Perform REQUEST_COUNT requests and collect timings
  timings=()
  http_codes=()
  errors=0
  for i in $(seq 1 $REQUEST_COUNT); do
    result=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}" \
      --max-time "$TIMEOUT_SEC" "$endpoint" 2>/dev/null || echo "000:0")
    http_code="${result%%:*}"
    time_total="${result##*:}"
    if [ "$http_code" = "000" ] || [ "$(echo "$time_total == 0" | bc -l 2>/dev/null)" = "1" ]; then
      errors=$((errors + 1))
    else
      timings+=("$time_total")
      http_codes+=("$http_code")
    fi
  done

  # Can't measure if all requests failed
  [ "${#timings[@]}" -eq 0 ] && continue

  # Sort timings for percentile calculation
  IFS=$'\n' sorted=($(printf "%s\n" "${timings[@]}" | sort -n))
  count=${#sorted[@]}

  # Calculate percentiles
  p50_idx=$(( (count * 50 + 99) / 100 - 1 ))
  p95_idx=$(( (count * 95 + 99) / 100 - 1 ))
  p99_idx=$(( (count * 99 + 99) / 100 - 1 ))
  [ "$p50_idx" -lt 0 ] && p50_idx=0
  [ "$p95_idx" -lt 0 ] && p95_idx=0
  [ "$p99_idx" -lt 0 ] && p99_idx=0
  [ "$p50_idx" -ge "$count" ] && p50_idx=$((count - 1))
  [ "$p95_idx" -ge "$count" ] && p95_idx=$((count - 1))
  [ "$p99_idx" -ge "$count" ] && p99_idx=$((count - 1))

  p50_ms=$(echo "${sorted[$p50_idx]} * 1000" | bc -l 2>/dev/null | xargs printf "%.0f" 2>/dev/null || echo 0)
  p95_ms=$(echo "${sorted[$p95_idx]} * 1000" | bc -l 2>/dev/null | xargs printf "%.0f" 2>/dev/null || echo 0)
  p99_ms=$(echo "${sorted[$p99_idx]} * 1000" | bc -l 2>/dev/null | xargs printf "%.0f" 2>/dev/null || echo 0)
  avg_ms=$(echo "${timings[*]}" | tr ' ' '+' | bc -l 2>/dev/null | xargs printf "%.0f" 2>/dev/null || echo 0)
  [ "$avg_ms" != "0" ] && avg_ms=$(( $(printf "%.0f" "$(echo "${timings[*]}" | tr ' ' '+' | bc -l 2>/dev/null)") * 1000 / count ))

  # Determine severity from p95
  severity="low"
  [ "$p95_ms" -gt "$P99_FAIL_MS" ] && severity="critical"
  [ "$p95_ms" -gt "$P95_FAIL_MS" ] && severity="high"
  [ "$p95_ms" -gt "$P95_WARN_MS" ] && severity="medium"

  # Skip if below all thresholds
  [ "$severity" = "low" ] && continue

  fp=$(echo -n "QD4|$endpoint|api|P-QD4-api-latency-probe|api_latency" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc \
    --arg endpoint "$endpoint" --argjson p50 "$p50_ms" --argjson p95 "$p95_ms" --argjson p99 "$p99_ms" \
    --argjson avg "$avg_ms" --argjson errors "$errors" --argjson count "$count" \
    --arg severity "$severity" --arg fp "$fp" \
    --argjson warn_p95 "$P95_WARN_MS" --argjson fail_p95 "$P95_FAIL_MS" --argjson fail_p99 "$P99_FAIL_MS" \
    --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-api-latency-probe",
      probe_version: "v1.0", severity: $severity, fixability: "agent_fix", domain: "backend",
      title: ("API latency " + $endpoint + " p95=" + ($p95 | tostring) + "ms - " + $severity),
      description: ("Endpoint " + $endpoint + " | p50=" + ($p50 | tostring) + "ms p95=" + ($p95 | tostring) + "ms p99=" + ($p99 | tostring) + "ms avg=" + ($avg | tostring) + "ms | errors=" + ($errors | tostring) + "/" + ($count | tostring) + " | thresholds: p95_warn=" + ($warn_p95 | tostring) + "ms p95_fail=" + ($fail_p95 | tostring) + "ms p99_fail=" + ($fail_p99 | tostring) + "ms"),
      location: {file: "runtime", line: null, column: null, selector: null, url: $endpoint},
      evidence: [
        {type: "metric", path: "runtime", description: ("p50: " + ($p50 | tostring) + "ms")},
        {type: "metric", path: "runtime", description: ("p95: " + ($p95 | tostring) + "ms")},
        {type: "metric", path: "runtime", description: ("p99: " + ($p99 | tostring) + "ms")},
        {type: "metric", path: "runtime", description: ("errors: " + ($errors | tostring) + "/" + ($count | tostring))}
      ],
      cdg_flags: ([if ($severity == "critical") then "CDG-API-LATENCY-CRITICAL" else empty end]),
      remediation: {suggested_action: ("Optimize endpoint " + $endpoint + ": add caching, optimize DB queries, enable connection pooling, or scale horizontally"), suggested_agent: "performance-benchmarker", estimated_effort: "medium"},
      detected_at: $now, detected_by: "wf-fix-performance/P-QD4-api-latency-probe"
    }')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done

# Final output
jq -nc \
  --arg lane "wf-fix-performance" --arg probe "P-QD4-api-latency-probe" --arg pver "v1.0" \
  --arg profile "${PROFILE:-standard}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson signals "$SIGNALS_JSON" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD4", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now, signals: $signals}' \
  > "$RAW_OUT"
```

**Bash script handles:**
- API endpoint discovery: tu dong quet source code tim router patterns (Express, Fastify, Next.js API routes, Django, Flask, Spring, Gin) de lay API paths
- curl timing: chay `REQUEST_COUNT` (default 5) requests per endpoint voi `curl -w %{http_code}:%{time_total}`
- Percentile calculation: sort timings, tinh p50/p95/p99, average
- Error tracking: dem so request fail (http_code=000 hoac timeout)
- Severity assignment: compare p95/p99 voi thresholds
- CDG flags: critical latency triggers CDG-API-LATENCY-CRITICAL flag
- Skip profiles: quick profile bo qua probe nay

### B2: Threshold customization

Default thresholds:
- p95 > 10000ms (10s) -> CRITICAL (CDG flag)
- p95 > 2000ms -> HIGH
- p95 > 500ms -> MEDIUM
- p95 <= 500ms -> no signal (within normal range)

Override qua env var: `API_P95_WARN_MS`, `API_P95_FAIL_MS`, `API_P99_FAIL_MS`, `API_REQUEST_COUNT`, `API_TIMEOUT_SEC`.

## THINK

Inline bash logic:
1. **Endpoint discovery:** grep source code cho route definitions (router.get, app.post, @Get annotation, Route::). Neu khong co source, chi test /health va /api/health.
2. **Percentile measurement:** 5 requests per endpoint (configurable). Sort => p50 (median), p95 (tail), p99 (extreme tail). Average cho reference.
3. **Error handling:** Request fail => tang error count. Neu tat ca fail => skip endpoint (khong emit signal).
4. **Severity:** p95 > 10s = CRITICAL (CDG threshold). p95 > 2s = HIGH. p95 > 500ms = MEDIUM.
5. **Domain:** `backend`
6. **Fixability:** `agent_fix` (performance-benchmarker)

## ACT

Output schema `signal-v2`:
- API latency: `title: "API latency <endpoint> p95=<val>ms - <severity>"`, `evidence` gom 4 metrics (p50, p95, p99, errors)
- `remediation.suggested_action`: Goi y optimize endpoint cu the (caching, query optimize, connection pooling, scale)
- Critical severity triggers `cdg_flags: ["CDG-API-LATENCY-CRITICAL"]`

## VERIFY

1. Moi Signal co `dimension_id == "QD4"`
2. Moi signal co `evidence` >= 2 metric entries
3. p50 <= p95 <= p99 trong moi signal (consistency check)
4. `p95_ms` trong description match voi threshold rule
5. `location.url` phai la URL hop le (bat dau bang http)
6. Khong co duplicate endpoints trong signals

## Severity Rules

| Pattern | Severity |
|---------|----------|
| p95 > 10000ms (10s) | CRITICAL |
| p95 > 2000ms | HIGH |
| p95 > 500ms | MEDIUM |
| All requests fail (100% error rate) | HIGH (separate signal) |
| p95 <= 500ms | No signal (within normal) |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| --base-url khong co | Skip probe, note "no_base_url" |
| curl not installed | Skip probe, note "curl_unavailable" |
| Khong tim thay API endpoints trong source | Chi test BASE_URL/health va BASE_URL/api/health, note "discovery_fallback" |
| Endpoint timeout (curl --max-time) | Ghi nhan request do bi fail, khong crash probe |
| Tat ca request deu fail cho 1 endpoint | Bo qua endpoint do, khong emit signal |
| bc khong available (Windows) | Fallback integer arithmetic, note "no_bc_precision_loss" |
