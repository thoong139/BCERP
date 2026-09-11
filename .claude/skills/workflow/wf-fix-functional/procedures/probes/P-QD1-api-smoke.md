# P-QD1-api-smoke — API Smoke Test (Happy Path)

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD1-api-smoke |
| **Loai** | runtime |
| **Profile** | quick, standard, deep, exhaustive |
| **Muc dich** | curl happy path per endpoint → check HTTP 2xx. Phat hien broken endpoints. |
| **Cache** | skip (runtime probe) |
| **Migrates from** | (v5 legacy — removed in v6) phase4-api-discovery.md (L1.1 partial) |

## PRE-GATE

```
IF $BASE_URL == null:
  SKIP probe, note "skipped_no_base_url"

IF $INFRA_STATUS.backend == "not_running" (tu P-QD1-infra-preflight):
  SKIP probe, note "skipped_backend_down"
```

## SENSE

### B1: Build endpoint list

Priority order:
1. Doc API contract tu `.mc-data/docs/phase3-architecture/**/api-*.md` hoac `API-*.md`
2. Neu khong co API contract → parse routes tu code (dung P-QD1-route-config-parse logic)
3. Parse ra `$ENDPOINTS[]` voi: `{method, path, file, feature_id}`

### B2: Filter endpoints

**Exclusion list (KHONG smoke test):**
- `/api/health`, `/health`, `/api` — health checks (tested by infra-preflight)
- `/api/webhooks/**` — external callers
- `/api/cron/**`, `/api/jobs/**` — scheduled tasks
- `/api/auth/**` — auth flow (requires credentials)

**KHONG exclude `/api/admin/**`** — admin endpoints la business-critical.

### B3: Xac dinh happy path per endpoint

- GET → call voi default params (no body)
- POST → call voi minimal valid payload (empty JSON `{}`)
- PUT/PATCH → skip (requires existing resource ID)
- DELETE → skip (destructive)

## THINK

1. Expected HTTP codes: GET=200, POST=201/200
2. Cross-ref voi req-registry.json:
   - impl_status=done + endpoint returns 5xx → CRITICAL
   - impl_status=done + endpoint khong ton tai → CRITICAL
   - impl_status=in_progress + endpoint returns 5xx → HIGH

## ACT

### Chay happy path

```bash
for EP in $ENDPOINTS; do
  METHOD=$(echo "$EP" | jq -r '.method')
  PATH=$(echo "$EP" | jq -r '.path')
  URL="$BASE_URL$PATH"

  case "$METHOD" in
    GET)
      HTTP=$(curl -s -w "\n%{http_code}" "$URL" --max-time 10 2>/dev/null)
      BODY=$(echo "$HTTP" | head -n -1)
      CODE=$(echo "$HTTP" | tail -1)
      ;;
    POST)
      HTTP=$(curl -s -w "\n%{http_code}" -X POST "$URL" \
        -H "Content-Type: application/json" -d '{}' --max-time 10 2>/dev/null)
      BODY=$(echo "$HTTP" | head -n -1)
      CODE=$(echo "$HTTP" | tail -1)
      ;;
    *) continue ;;
  esac
done
```

### Tao Signals

**Server error (5xx):**
```json
{
  "probe_id": "P-QD1-api-smoke",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "api_error",
  "target": { "kind": "route", "file_path": "src/api/customers/route.ts", "line_range": [0, 0], "url": "/api/customers" },
  "description": "Endpoint GET /api/customers tra ve HTTP 500 (Internal Server Error) tren happy path",
  "evidence": { "log_excerpt": "HTTP 500: {\"error\":\"Internal Server Error\",\"message\":\"...\"}" },
  "suggested_severity": "critical",
  "dedup_hints": ["endpoint:/api/customers:GET"]
}
```

### Write raw signals

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/P-QD1-api-smoke.json" << 'EOF'
$API_SMOKE_SIGNALS
EOF
```

## VERIFY

1. Kiem tra moi Signal co `evidence.log_excerpt` non-empty (min 20 chars)
2. Kiem tra moi Signal co `target.url` voi endpoint path
3. Chi emit signals cho non-2xx responses
4. Neu tat ca endpoints pass → write empty signals array

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| $BASE_URL == null | Skip probe, note "skipped_no_base_url" |
| Backend down | Skip probe, note "skipped_backend_down" |
| Khong tim thay endpoints | Skip probe, note "no_endpoints_found" |
| curl timeout (>10s per endpoint) | Emit CRITICAL signal cho endpoint timeout |
| Khong co API contract docs | Fallback: parse routes tu code |
