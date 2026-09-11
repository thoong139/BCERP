# P-QD10-frontend-backend-coverage — Frontend-Backend Bidirectional Coverage Check

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD10-frontend-backend-coverage |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Phat hien mat can bang giua backend API endpoints va frontend consumer code: (A) backend endpoint khong co frontend consumer nao goi; (B) frontend API call khong tim thay backend handler. Day la blind spot chinh cua static analysis — khong probe nao kiem tra bidirectional coverage truoc day. |
| **Cache** | allowed (static per code state) |
| **Error codes** | E110 (registry parse error), E111 (no source dirs found) |
| **Migrates from** | (new in v9.1) |

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| Combined grep import pattern | `QD7 wf-fix-probe-static-deprecated.sh` | `:147-217` | COMBINED_REGEX cho frontend API call patterns (fetch, axios, useQuery, etc.) |
| API endpoint extraction | `P-QD1-route-config-parse.md` | `SENSE:B2` | Route config parse logic — reuse extract endpoint list tu backend code |
| Emit signal cross-module | `procedures/probes/_shared.md` (QD10) | `:42-92` | `emit_signal_cross_module()` pattern |
| Source file extensions | `QD3 wf-fix-probe-static-sast.sh` | `:138-142` | `SOURCE_EXTS` cho frontend + backend file detection |
| CI detect load | `QD9 P-QD9-spa-route-coverage.md` | `PRE-GATE:step 5` | CI detect pattern |

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Backend route listing | **Serena** `find_symbol({name_path_pattern: "Controller|Router|Handler"})` khop module path | Grep `@(Get|Post|Put|Delete|Patch)` decorators / `app.(get|post|put|delete)` | Extract all backend endpoint declarations |
| Frontend API call discovery | **Serena** `find_referencing_symbols({name_path: "fetch|axios|httpClient"})` | Grep `fetch(`, `axios.`, `useQuery`, `useMutation`, `$http` | Find all frontend API consumers |
| Endpoint symbol tracer | **GitNexus** `query("api endpoint")` | Manual grep route files | Trace which handler serves which endpoint |

---

## PRE-GATE

```
1. IF profile=quick:
     SKIP probe (QD10 quick=skip)

2. Detect source directories:
     FE_SOURCE_DIR=""  # frontend source (apps/web, apps/frontend, src/pages, src/components)
     BE_SOURCE_DIR=""  # backend source (apps/backend, apps/api, src/server, src/routes)

     for dir in apps/*/src apps/*/frontend src/pages src/components; do
       [ -d "$dir" ] && FE_FOUND+=("$dir")
     done
     for dir in apps/*/src apps/*/backend src/server src/routes src/controllers; do
       [ -d "$dir" ] && BE_FOUND+=("$dir")
     done

     IF FE_FOUND empty OR BE_FOUND empty:
       SKIP probe, ghi note "skipped_no_fe_or_be_dirs"
       → exit 0

3. Load CI availability:
     source <(bash .claude/scripts/ci-detect.sh --project-root "$PROJECT_ROOT" 2>/dev/null) || true
```

---

## SENSE

### S1: Build Backend Endpoint Inventory

```bash
ENDPOINT_RAW="$RAW_DIR/backend-endpoints.jsonl"
> "$ENDPOINT_RAW"

# Extract endpoint declarations from backend code
# Pattern 1: Decorator-based (NestJS, Spring, Flask, .NET)
grep -rn '@(Get|Post|Put|Delete|Patch|RequestMapping)\b' \
  $BE_SOURCE_DIR --include="*.ts" --include="*.java" --include="*.py" --include="*.cs" \
  2>/dev/null | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  METHOD=$(echo "$line" | grep -oE '@(Get|Post|Put|Delete|Patch)' | tr -d '@' | tr '[:lower:]' '[:upper:]')
  PATH_HINT=$(echo "$line" | grep -oE '["/][^"]*["/]' | head -1 | tr -d '"')
  echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"method\":\"$METHOD\",\"path\":\"$PATH_HINT\",\"source\":\"decorator\"}" >> "$ENDPOINT_RAW"
done

# Pattern 2: Express-style (app.get, router.post)
grep -rn '\bapp\.\(get\|post\|put\|delete\|patch\)\s*(' \
  $BE_SOURCE_DIR --include="*.ts" --include="*.js" \
  2>/dev/null | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  METHOD=$(echo "$line" | grep -oE '\.(get|post|put|delete|patch)\(' | tr -d '.(' | tr '[:lower:]' '[:upper:]')
  PATH_HINT=$(echo "$line" | grep -oE '"([^"]*)"' | head -1 | tr -d '"')
  echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"method\":\"$METHOD\",\"path\":\"$PATH_HINT\",\"source\":\"express\"}" >> "$ENDPOINT_RAW"
done

# Pattern 3: Next.js API routes (file-based routing)
find $BE_SOURCE_DIR -path "*/api/*" \( -name "route.ts" -o -name "route.tsx" -o -name "page.tsx" \) 2>/dev/null | while read -r file; do
  # Infer method from export function name
  METHODS=$(grep -oE 'export (async )?function (GET|POST|PUT|DELETE|PATCH)' "$file" 2>/dev/null | grep -oE '(GET|POST|PUT|DELETE|PATCH)' || echo "GET")
  PATH_HINT=$(echo "$file" | sed 's|.*/api||' | sed 's|/route\.tsx\?||' | sed 's|/page\.tsx\?||')
  echo "{\"file\":\"$file\",\"line\":1,\"method\":\"$METHODS\",\"path\":\"/api$PATH_HINT\",\"source\":\"nextjs\"}" >> "$ENDPOINT_RAW"
done

ENDPOINT_TOTAL=$(wc -l < "$ENDPOINT_RAW" || echo 0)
LOG "INFO: Found $ENDPOINT_TOTAL backend endpoint declarations" >&2
```

### S2: Build Frontend API Consumer Inventory

```bash
CONSUMER_RAW="$RAW_DIR/frontend-api-consumers.jsonl"
> "$CONSUMER_RAW"

# Build combined regex for all frontend API call patterns
# fetch() calls
grep -rn '\bfetch\s*(' \
  $FE_SOURCE_DIR --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.vue" \
  2>/dev/null | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  URL_HINT=$(echo "$line" | grep -oE "fetch\s*\(\s*['\"]([^'\"]+)['\"]" | sed 's/fetch\s*(\s*['\"]//' | sed 's/['\"]//' | head -1)
  echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"method\":\"fetch\",\"url\":\"$URL_HINT\",\"source\":\"fetch\"}" >> "$CONSUMER_RAW"
done

# axios calls
grep -rn '\baxios\.\(get\|post\|put\|delete\|patch\)\s*(' \
  $FE_SOURCE_DIR --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.vue" \
  2>/dev/null | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  METHOD=$(echo "$line" | grep -oE 'axios\.(get|post|put|delete|patch)' | sed 's/axios\.//' | tr '[:lower:]' '[:upper:]')
  URL_HINT=$(echo "$line" | grep -oE "\((['\"][^'\"]+['\"])" | tr -d "(')" | tr -d '"' | head -1)
  echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"method\":\"$METHOD\",\"url\":\"$URL_HINT\",\"source\":\"axios\"}" >> "$CONSUMER_RAW"
done

# React Query / TanStack Query hooks
grep -rn '\buseQuery\|useMutation\b' \
  $FE_SOURCE_DIR --include="*.ts" --include="*.tsx" \
  2>/dev/null | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  HOOK_TYPE=$(echo "$line" | grep -oE '\b(useQuery|useMutation)\b' | head -1)
  echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"method\":\"$HOOK_TYPE\",\"url\":\"(inferred)\",\"source\":\"react-query\"}" >> "$CONSUMER_RAW"
done

# GraphQL (apollo, urql, relay)
grep -rn '\buseQuery\|useMutation\|useLazyQuery\b' \
  $FE_SOURCE_DIR --include="*.ts" --include="*.tsx" \
  2>/dev/null | grep -v 'react-query' | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"method\":\"GraphQL\",\"url\":\"(graphql)\",\"source\":\"graphql-client\"}" >> "$CONSUMER_RAW"
done

# $http / HttpClient (Angular, NestJS client)
grep -rn '\$http\b\|this\.httpClient\.\(get\|post\|put\|delete\)' \
  $FE_SOURCE_DIR --include="*.ts" --include="*.tsx" --include="*.vue" \
  2>/dev/null | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  METHOD=$(echo "$line" | grep -oE '\.(get|post|put|delete)\(' | tr -d '.(' | tr '[:lower:]' '[:upper:]')
  echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"method\":\"${METHOD:-GET}\",\"url\":\"(httpClient)\",\"source\":\"httpClient\"}" >> "$CONSUMER_RAW"
done

CONSUMER_TOTAL=$(wc -l < "$CONSUMER_RAW" || echo 0)
LOG "INFO: Found $CONSUMER_TOTAL frontend API consumer calls" >&2
```

### S3: Build FE Form Inventory (complementary to S2)

```bash
FORM_RAW="$RAW_DIR/frontend-forms.jsonl"
> "$FORM_RAW"

grep -rn '<form\b' \
  $FE_SOURCE_DIR --include="*.tsx" --include="*.jsx" --include="*.vue" --include="*.html" \
  2>/dev/null | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  ACTION=$(echo "$line" | grep -oE 'action=["'\'']([^"'\'']+)["'\'']' | sed 's/action=["'\'']//' | sed 's/["'\'']//' | head -1)
  METHOD=$(echo "$line" | grep -oE 'method=["'\'']([^"'\'']+)["'\'']' | sed 's/method=["'\'']//' | sed 's/["'\'']//' | head -1)
  echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"action\":\"${ACTION:-}\",\"method\":\"${METHOD:-POST}\"}" >> "$FORM_RAW"
done

FORM_TOTAL=$(wc -l < "$FORM_RAW" || echo 0)
LOG "INFO: Found $FORM_TOTAL frontend form declarations" >&2
```

---

## THINK

### A: Backend Endpoint → Frontend Consumer Coverage

Voi moi backend endpoint trong `$ENDPOINT_RAW`, kiem tra co it nhat 1 frontend consumer goi no:

```
FOR each endpoint IN $ENDPOINTS[]:
  endpoint_key = normalize(endpoint.method + " " + endpoint.path)

  # Tim trong frontend API consumers
  consumer_matches = search $CONSUMERS[] WHERE:
    consumer.url CONTAINS normalize(endpoint.path)
    AND (consumer.method MATCHES endpoint.method OR consumer.source IN {react-query, graphql-client})

  # Tim trong frontend forms
  form_matches = search $FORMS[] WHERE:
    form.action CONTAINS normalize(endpoint.path)
    AND form.method MATCHES endpoint.method

  IF no consumer_match AND no form_match:
    # Backend co endpoint nhung frontend KHONG goi no
    → EMIT signal: "backend_endpoint_no_frontend_consumer"

    # Xac dinh severity theo impl_status
    IF feature co endpoint nay la done → HIGH
    IF feature co endpoint nay la in_progress → MEDIUM
    IF khong xac dinh duoc feature → LOW
```

### B: Frontend API Consumer → Backend Handler Coverage

Voi moi frontend API call trong `$CONSUMER_RAW`, kiem tra co backend handler tuong ung:

```
FOR each consumer IN $CONSUMERS[]:
  # Skip neu consumer.url rong hoac chi la placeholder
  IF consumer.url IN {"(inferred)", "(graphql)", "(httpClient)", ""} → SKIP

  consumer_key = normalize(consumer.method + " " + consumer.url)

  # Tim trong backend endpoints
  endpoint_matches = search $ENDPOINTS[] WHERE:
    endpoint.path MATCHES normalize_pattern(consumer.url)

  IF no endpoint_match:
    → EMIT signal: "frontend_api_call_no_backend_handler"

    # Severity theo ngu canh
    IF consumer goi trong form submit → HIGH
    IF consumer goi trong useEffect/componentDidMount → HIGH (broken page load)
    IF consumer goi trong event handler (onClick, onSubmit) → MEDIUM
    ELSE → MEDIUM
```

### Exclusion List

- Health check endpoints: `/api/health`, `/health`, `/api/ping`
- Static asset routes: `/api/public/*`, `/api/assets/*`
- Webhook receiver endpoints (external callers): `/api/webhooks/*`, `/api/callback/*`
- Cron job endpoints: `/api/cron/*`, `/api/jobs/*`
- Frontend dev-only calls: `localhost:`, `127.0.0.1:`
- Third-party API calls: URLs starting with `https://` (external domain)
- GraphQL endpoints: consumer GraphQL calls mapped to single `/api/graphql` endpoint
- Dynamic/parameterized URLs where ${id} or :id substitution matches

### Confidence Mapping

| Loai mismatch | Confidence | Ghi chu |
|---------------|-----------|---------|
| Backend endpoint khong co consumer (done feature) | 0.80 | Co the la internal/admin endpoint |
| Backend endpoint khong co consumer (in_progress feature) | 0.60 | Co the frontend chua implement |
| Frontend form action khong co backend handler | 0.85 | Form se fail HTTP 404 khi submit |
| Frontend fetch/axios khong co backend handler | 0.75 | Co the la external API hoac proxy |
| Frontend GraphQL/React Query khong co backend | 0.65 | Khong the xac dinh URL cu the |

---

## ACT

### Signal Emit: backend_endpoint_no_frontend_consumer

```json
{
  "probe_id": "P-QD10-frontend-backend-coverage",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-integration",
  "dimension_id": "QD10",
  "signal_type": "backend_endpoint_no_frontend_consumer",
  "target": {
    "kind": "api_endpoint",
    "file_path": "apps/backend/src/customers/customers.controller.ts",
    "line_range": [23, 28]
  },
  "description": "Backend endpoint POST /api/customers/import (feature FEAT-CRM-CUST-IMPORT, impl_status=done) khong tim thay frontend consumer nao goi no — co the la orphan endpoint hoac frontend chua duoc implement tuong ung",
  "evidence": {
    "code_snippet": "@Post('import')\nasync importCustomers(@Body() dto: ImportDto) {\n  return this.customerService.bulkImport(dto);\n}",
    "spec_ref": "FEAT-CRM-CUST-IMPORT trong req-registry.json co impl_status=done",
    "consumer_scan": "Da quet tat ca frontend API calls + forms trong apps/web/ — khong tim thay consumer nao goi /api/customers/import"
  },
  "location": {
    "provider_module": "MOD-CRM",
    "consumer_module": "NONE",
    "file_path": "apps/backend/src/customers/customers.controller.ts",
    "line_range": [23, 28]
  },
  "suggested_severity": "high",
  "fixability": "agent_fix",
  "dedup_key": "P-QD10-frontend-backend-coverage:backend_endpoint_no_frontend_consumer:/api/customers/import:POST"
}
```

### Signal Emit: frontend_api_call_no_backend_handler

```json
{
  "probe_id": "P-QD10-frontend-backend-coverage",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-integration",
  "dimension_id": "QD10",
  "signal_type": "frontend_api_call_no_backend_handler",
  "target": {
    "kind": "code",
    "file_path": "apps/web/src/pages/Dashboard.tsx",
    "line_range": [42, 48]
  },
  "description": "Frontend goi POST /api/analytics/custom-report trong Dashboard.tsx:45 nhung khong tim thay backend endpoint tuong ung trong bat ky controller/route nao — API call nay se fail HTTP 404 khi goi den server",
  "evidence": {
    "code_snippet": "const { data } = await axios.post('/api/analytics/custom-report', {\n  dateRange: [start, end],\n  metrics: ['revenue', 'churn']\n});",
    "backend_scan": "Da quet tat ca backend route declarations trong apps/backend/ — khong tim thay /api/analytics/custom-report"
  },
  "location": {
    "provider_module": "NONE",
    "consumer_module": "MOD-DASHBOARD",
    "file_path": "apps/web/src/pages/Dashboard.tsx",
    "line_range": [42, 48]
  },
  "suggested_severity": "high",
  "fixability": "agent_fix",
  "dedup_key": "P-QD10-frontend-backend-coverage:frontend_api_call_no_backend_handler:/api/analytics/custom-report:POST"
}
```

### Signal Emit: frontend_form_no_backend_handler

```json
{
  "probe_id": "P-QD10-frontend-backend-coverage",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-integration",
  "dimension_id": "QD10",
  "signal_type": "frontend_form_no_backend_handler",
  "target": {
    "kind": "code",
    "file_path": "apps/web/src/pages/Settings.tsx",
    "line_range": [88, 95]
  },
  "description": "Frontend form trong Settings.tsx:88 co action='POST /api/settings/export-config' nhung khong tim thay backend endpoint tuong ung — form se fail HTTP 404 khi nguoi dung submit",
  "evidence": {
    "code_snippet": "<form action=\"/api/settings/export-config\" method=\"POST\">\n  <Select name=\"format\">...</Select>\n  <Button type=\"submit\">Export</Button>\n</form>",
    "backend_scan": "Da quet tat ca backend route declarations — khong tim thay /api/settings/export-config"
  },
  "location": {
    "provider_module": "NONE",
    "consumer_module": "MOD-SETTINGS",
    "file_path": "apps/web/src/pages/Settings.tsx",
    "line_range": [88, 95]
  },
  "suggested_severity": "high",
  "fixability": "agent_fix",
  "dedup_key": "P-QD10-frontend-backend-coverage:frontend_form_no_backend_handler:/api/settings/export-config:POST"
}
```

### Write raw signals

```bash
cat > "$RAW_DIR/P-QD10-frontend-backend-coverage.json" << 'EOF'
$COVERAGE_SIGNALS
EOF
```

---

## VERIFY

1. Kiem tra moi signal co `signal_type` trong `["backend_endpoint_no_frontend_consumer", "frontend_api_call_no_backend_handler", "frontend_form_no_backend_handler"]`
2. Kiem tra moi signal co `dimension_id == "QD10"`
3. Kiem tra moi signal co `location` voi `file_path` va `line_range` hop le
4. Kiem tra moi signal co `evidence` non-empty (code_snippet >= 10 chars)
5. Kiem tra backend_endpoint_no_frontend_consumer signals KHONG overlap voi exclusion list
6. Kiem tra frontend signals KHONG phai third-party/external API calls
7. Drop signals voi confidence < 0.5

---

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| Backend endpoint (feature done) khong co frontend consumer | HIGH |
| Backend endpoint (feature in_progress) khong co frontend consumer | MEDIUM |
| Frontend form action khong co backend handler | HIGH |
| Frontend API call trong page load (useEffect/mount) khong co backend | HIGH |
| Frontend API call trong event handler khong co backend | MEDIUM |
| Backend endpoint (unknown feature) khong co frontend consumer | LOW |

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile=quick | SKIP lane (QD10 quick=skip) |
| Khong tim thay frontend source dirs | SKIP probe — emit note "skipped_no_fe_dirs" |
| Khong tim thay backend source dirs | SKIP probe — emit note "skipped_no_be_dirs" |
| > 200 endpoints | Sampling: chi phan tich endpoints tu features done + in_progress trong scope |
| > 300 frontend consumers | Sampling: chi phan tich consumers trong non-test files, uu tien forms + page-level calls |
| Serena unavailable | Fallback grep — LOG WARN, khong block |
| GitNexus unavailable | Skip endpoint-to-handler trace — LOG WARN |
| Endpoint path dynamic (:id, {id}) | Normalize sang pattern truoc khi match (e.g., `/api/users/:id` → match `/api/users/123`) |
| > 100 signals | Cap max 100, uu tien severity HIGH → MEDIUM → LOW |

---

## Cache Policy

**allowed** — probe nay la pure static analysis. Cache TTL: 24h.

Key: `{PROJECT_ROOT_SHA}:{endpoint_count}:{consumer_count}:{form_count}`.

---

## Dedup Hints

| Signal Type | Dedup Key Pattern |
|-------------|------------------|
| `backend_endpoint_no_frontend_consumer` | `P-QD10-frontend-backend-coverage:backend_endpoint_no_frontend_consumer:{path}:{method}` |
| `frontend_api_call_no_backend_handler` | `P-QD10-frontend-backend-coverage:frontend_api_call_no_backend_handler:{path}:{method}` |
| `frontend_form_no_backend_handler` | `P-QD10-frontend-backend-coverage:frontend_form_no_backend_handler:{form_path}:{method}` |

Cross-probe dedup: `frontend_form_no_backend_handler` tu probe nay co the overlap voi `orphan_form` tu P-QD1-orphan-ui-detect. Aggregator dedup boi URL+method. Probe nay la authoritative cho full-stack coverage; QD1 probe la authoritative cho UI-spec coverage.
