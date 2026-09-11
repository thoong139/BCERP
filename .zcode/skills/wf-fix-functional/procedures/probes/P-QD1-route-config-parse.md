# P-QD1-route-config-parse — Cross-Stack API Route Verification

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD1-route-config-parse |
| **Version** | 2.0.0 |
| **Loai** | static (GitNexus PRIMARY + grep fallback) |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Verify FE↔BE API contract: FE API calls co backend handler, BE endpoints co FE consumer. Phat hien 404 calls, orphan endpoints, cross-stack mismatch. |
| **Cache** | allowed (--use-cache, chi cho grep fallback) |
| **Migrates from** | v1.0.0 (v5 legacy — removed in v6) phase4-api-discovery.md (L1.1). v2.0.0: them .NET Minimal API patterns, GitNexus route_map PRIMARY, FE regex mo rong. |

---

## CI-ROUTE: Cross-Stack Route Mapping (Protocol 20 §20.5)

> **PRIMARY path:** GitNexus `route_map` tool — tra ve chinh xac route→handler→consumer.
> **Fallback path:** Grep regex (khi GitNexus khong available hoac index stale).

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `map_all_routes` | **GitNexus** `route_map()` | Grep B1-B3 | Lay toan bo route→handler→consumer mapping |
| `find_consumer_of_route` | **GitNexus** `route_map({route})` | Grep FE API calls | Xac dinh route co FE consumer khong |
| `find_handler_of_route` | **GitNexus** `route_map({route})` | Grep BE routes | Xac dinh FE call co BE handler khong |
| `locate_handler_file` | **Serena** `find_symbol({handler_name})` | Glob `Endpoints/*.cs` | Locate chinh xac handler implementation |

**Khi GitNexus available + index fresh:**
- Dung `route_map()` lay toan bo route→handler→consumer map → SENSE B0
- Cross-reference consumer vs handler → THINK
- Chi fallback grep khi route_map khong co consumer info (route goi tu external)

**Khi GitNexus unavailable:**
- Fallback grep B1-B3 (da mo rong regex) → LOG WARN "gitnexus_unavailable_fallback_grep"

---

## SENSE

### B0: GitNexus route_map (PRIMARY — khi GITNEXUS_AVAILABLE=true)

```bash
if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
  # Lay toan bo route map tu GitNexus
  # (Pseudocode — orchestrator agent thuc hien qua GitNexus MCP):
  # ROUTE_MAP = gitnexus_route_map({})
  #   → [{route, method, handler_file, handler_symbol, consumers: [{file, symbol, kind}]}]
  #
  # Trích xuất:
  #   $CODE_ROUTES[] = {method, path, file: handler_file, line_number, has_consumer: consumers.length > 0}
  #   $FRONTEND_API_CALLS[] = {path, file: consumer.file, method_hint: inferred}
  #
  # Dat ROUTE_MAP_SOURCE="gitnexus"
  LOG "INFO: GitNexus route_map PRIMARY — chinh xac 100% khong phu thuoc regex" >&2
  ROUTE_MAP_SOURCE="gitnexus"
else
  LOG "WARN: GitNexus unavailable — fallback grep regex (han che hon)" >&2
  ROUTE_MAP_SOURCE="grep"
fi
```

### B1: Phat hien tech stack routing (fallback)

```bash
# Node/TS stacks
grep -rl "express\|Router\|RouterModule" src/ apps/ --include="*.ts" --include="*.tsx" 2>/dev/null
grep -rl "createBrowserRouter\|NextResponse\|NextRequest" src/ apps/ --include="*.ts" --include="*.tsx" 2>/dev/null

# .NET Minimal API
grep -rl "MapGroup\|MapGet\|MapPost\|MapPut\|MapDelete\|MapPatch" apps/backend/ --include="*.cs" 2>/dev/null
grep -rl "IEndpointRouteBuilder\|IEndpointConventionBuilder" apps/backend/ --include="*.cs" 2>/dev/null
```

### B2: Grep route definitions theo tech stack (fallback)

```bash
# Express
grep -rn "app\.\(get\|post\|put\|delete\|patch\)\s*(\s*['\"]/" src/ apps/ --include="*.ts" 2>/dev/null

# NestJS
grep -rn "@\(Get\|Post\|Put\|Delete\|Patch\)\s*(\s*['\"]/" src/ apps/ --include="*.ts" 2>/dev/null

# .NET Minimal API — MapGroup + MapGet/MapPost/MapPut/MapDelete/MapPatch
grep -rn "MapGet\|MapPost\|MapPut\|MapDelete\|MapPatch" apps/backend/ --include="*.cs" 2>/dev/null | \
  grep -oE "Map(Get|Post|Put|Delete|Patch)\s*\(\s*[\"']([^\"']+)[\"']" || true

# .NET Minimal API — MapGroup prefix
grep -rn "MapGroup\s*\(\s*[\"']" apps/backend/ --include="*.cs" 2>/dev/null | \
  grep -oE "MapGroup\s*\(\s*[\"']([^\"']+)[\"']" || true

# Next.js (file-based routing)
find . -path "*/app/api/**/route.ts" -o -path "*/pages/api/**/*.ts" 2>/dev/null

# React Router
grep -rn "<Route\s\+path=" src/ apps/ --include="*.tsx" --include="*.jsx" 2>/dev/null

# GraphQL
grep -rn "type Query\|type Mutation" src/ apps/ --include="*.graphql" --include="*.gql" 2>/dev/null
```

Parse ra `$CODE_ROUTES[]` voi: `{method, path, file, line_number}`

**NET mapping:** `MapGet("/path")` → `GET /path`, `MapPost("/path")` → `POST /path`, etc.
**MapGroup prefix:** `MapGroup("/api/v1/marketing")` → prefix cho tat ca Map* trong group.

### B3: Grep frontend API calls (fallback — da mo rong regex)

```bash
# React Query hooks (useQuery, useMutation voi apiClient)
grep -rn "apiClient\.\(get\|post\|put\|delete\|patch\)<" src/ apps/ \
  --include="*.ts" --include="*.tsx" 2>/dev/null | \
  grep -oE "apiClient\.(get|post|put|delete|patch)<[^>]*>\s*\(\s*['\"]([^'\"]+)['\"]" || true

# Axios direct calls
grep -rn "axios\.\(get\|post\|put\|delete\|patch\)\s*(" src/ apps/ \
  --include="*.ts" --include="*.tsx" 2>/dev/null | \
  grep -oE "axios\.(get|post|put|delete|patch)\s*\(\s*['\"]([^'\"]+)['\"]" || true

# Raw fetch calls
grep -rn "fetch\s*(\s*['\"]" src/ apps/ \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | \
  grep -oE "fetch\s*\(\s*['\"]([^'\"]+)['\"]" || true

# tRPC calls
grep -rn "trpc\.\|\.useMutation\|\.useQuery" src/ apps/ \
  --include="*.ts" --include="*.tsx" 2>/dev/null | \
  grep -oE "(trpc\.[a-zA-Z]+\.[a-zA-Z]+|useMutation|useQuery)\s*\([^)]*\)" || true

# Catch-all: bat ky URL path pattern /api/ trong string literals
grep -rn "['\"]/api/v[0-9]/[^'\"]\+['\"]" src/ apps/ \
  --include="*.ts" --include="*.tsx" 2>/dev/null | \
  grep -oE "['\"](/api/v[0-9]+/[^'\"]+)['\"]" || true
```

Parse ra `$FRONTEND_API_CALLS[]` voi: `{method_hint, path, file, line_number}`

### B4: Doc Navigation specs + API contracts (optional context)

```bash
find .mc-data/docs/phase4-ux -name "Navigation-*.md" 2>/dev/null
find .mc-data/docs/phase3-architecture -name "API-*.md" -o -name "api-*.md" 2>/dev/null
```

### B5: Scan Cache check (khi --use-cache, chi cho grep fallback)

```bash
# Chi cache khi dung grep fallback — GitNexus route_map luon fresh
if [[ "$ROUTE_MAP_SOURCE" == "grep" ]]; then
  for FILE in $ROUTE_FILES; do
    FP=$(python -m _shared.scan_cache.fingerprint --probe-id P-QD1-route-config-parse --probe-version 2.0.0 --file "$FILE")
    HIT=$(python -m _shared.scan_cache.cache_lookup --cache-root .mc-data/cache/wf-fix-bugs/probes/ --fingerprint "$FP")
    if [ -n "$HIT" ]; then
      cat "$HIT" >> "$ACCUMULATED_SIGNALS"
      continue
    fi
    SCAN_FILES+=("$FILE")
  done
fi
```

---

## THINK

### Build route maps

1. `$CODE_ROUTES[]` — backend routes trong code (tu route_map hoac grep)
2. `$FRONTEND_API_CALLS[]` — API calls tu frontend (tu route_map consumers hoac grep)
3. `$SPEC_ROUTES[]` — routes tu Navigation specs (optional)

### Cross-reference analysis

**1. Frontend call → Backend mismatch (PRIMARY — SEVERITY: CRITICAL/HIGH):**
- Frontend goi endpoint backend khong co → `frontend_api_call_unmatched` (CRITICAL — se 404)
- Backend co endpoint frontend khong goi → `orphan_api` (MEDIUM — co the la orphan hoac external consumer)

**2. Code route → Navigation spec mismatch (secondary):**
- Route trong code khong trong spec → `orphan_route`
- Route trong spec khong trong code → `missing_route`

**3. Exclusion list (KHONG flag):**
- `/api/health`, `/health`, `/api` (health checks)
- `/api/webhooks/**`, `/api/cron/**`, `/api/jobs/**` (external callers)
- `/api/auth/**` (auth framework handled)
- `/api/trpc/**` (tRPC auto-generated)
- `_next/**` (Next.js internal)
- `/api/v1/customer/mobile/**` (mobile-customer app, goi tu external)
- `/api/v1/staff/mobile/**` (mobile-staff app, goi tu external)
- **KHONG exclude `/api/admin/**`** — business-critical

### Severity mapping (v2.0 — cross-stack focus)

| Dieu kien | Severity | Confidence |
|-----------|----------|-----------|
| FE goi endpoint, BE khong co handler (404) | **CRITICAL** | 0.95 |
| FE goi endpoint, BE handler khong match method | **HIGH** | 0.90 |
| BE endpoint co nhung KHONG co FE consumer | MEDIUM | 0.75 |
| Route trong code khong trong Navigation spec | MEDIUM | 0.70 |
| Route trong spec khong co trong code | HIGH | 0.85 |

---

## ACT

### Tao Signals

**FE call unmatched — frontend goi endpoint backend khong co (CRITICAL):**
```json
{
  "probe_id": "P-QD1-route-config-parse",
  "probe_version": "2.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "frontend_api_call_unmatched",
  "target": {
    "kind": "code",
    "file_path": "apps/erp-web/src/hooks/marketing/useDigitalAds.ts",
    "line_range": [25, 28],
    "symbol": "useAdsDashboard"
  },
  "description": "Frontend hook goi GET /api/v1/marketing/ads/dashboard nhung KHONG tim thay backend endpoint tuong ung — FE se nhan HTTP 404. Anh huong page: digital-ads/page.tsx",
  "evidence": {
    "code_snippet": "apiClient.get<AdsDashboard>('/api/v1/marketing/ads/dashboard', { params })",
    "route_map_source": "gitnexus",
    "consumer_file": "apps/erp-web/src/hooks/marketing/useDigitalAds.ts",
    "consumer_symbol": "useAdsDashboard"
  },
  "suggested_severity": "critical",
  "dedup_hints": ["fe-call-unmatched:/api/v1/marketing/ads/dashboard:GET"]
}
```

**Orphan BE endpoint — co backend nhung khong FE consumer (MEDIUM):**
```json
{
  "probe_id": "P-QD1-route-config-parse",
  "probe_version": "2.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "orphan_api",
  "target": {
    "kind": "route",
    "file_path": "apps/backend/Eureka.Api/Endpoints/MarketingEndpoints.cs",
    "line_range": [422, 430],
    "symbol": "MapEmailCampaignEndpoints"
  },
  "description": "Backend endpoint POST /api/v1/marketing/email-campaigns khong co frontend consumer — co the la orphan API (backend da build nhung thieu UI) hoac goi tu external system",
  "evidence": {
    "code_snippet": "group.MapPost(\"/email-campaigns\", async (IMediator mediator, ...) => ...)",
    "route_map_source": "gitnexus",
    "has_consumer": false
  },
  "suggested_severity": "medium",
  "dedup_hints": ["orphan-api:/api/v1/marketing/email-campaigns:POST"]
}
```

**Method mismatch — FE goi POST nhung BE chi co GET (HIGH):**
```json
{
  "probe_id": "P-QD1-route-config-parse",
  "probe_version": "2.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "method_mismatch",
  "target": {
    "kind": "code",
    "file_path": "apps/erp-web/src/hooks/marketing/useBudget.ts",
    "line_range": [120, 125]
  },
  "description": "Frontend goi POST /api/v1/marketing/budgets/{id}/close nhung backend chi khai bao POST /api/v1/marketing/budgets/{id}/approve — method khong khop, se 405 Method Not Allowed",
  "evidence": {
    "code_snippet": "apiClient.post(`/api/v1/marketing/budgets/${id}/close`)",
    "backend_route": "POST /api/v1/marketing/budgets/{id}/approve",
    "route_map_source": "gitnexus"
  },
  "suggested_severity": "high",
  "dedup_hints": ["method-mismatch:/api/v1/marketing/budgets/{id}/close:POST"]
}
```

**Missing route (Navigation spec nhung khong co code):**
```json
{
  "probe_id": "P-QD1-route-config-parse",
  "probe_version": "2.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "missing_route",
  "target": { "kind": "config_file", "file_path": "N/A", "line_range": [0, 0] },
  "description": "Navigation spec dinh nghia route /dashboard/settings nhung khong tim thay route definition trong code",
  "evidence": { "spec_ref": "Navigation-AdminPanel.md route /dashboard/settings" },
  "suggested_severity": "high",
  "dedup_hints": ["route:/dashboard/settings"]
}
```

### Scan Cache store (chi cho grep fallback)

```bash
if [[ "$ROUTE_MAP_SOURCE" == "grep" ]]; then
  for FILE in $SCAN_FILES; do
    python -m _shared.scan_cache.cache_store store \
      --probe-id P-QD1-route-config-parse --probe-version 2.0.0 \
      --file "$FILE" --signals-file "$TMP" \
      --cache-root .mc-data/cache/wf-fix-bugs/probes/
  done
fi
```

### Write raw signals

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/P-QD1-route-config-parse.json" << 'EOF'
$ROUTE_SIGNALS
EOF

# Ghi metadata ve route_map_source
jq -n --arg source "$ROUTE_MAP_SOURCE" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{probe_id: "P-QD1-route-config-parse", version: "2.0.0", route_map_source: $source, generated_at: $now}' \
  > "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/P-QD1-route-config-parse-meta.json"
```

---

## VERIFY

1. Kiem tra moi Signal co `evidence` voi it nhat 1 field non-empty
   - `code_snippet` min 10 chars
   - `route_map_source` = "gitnexus" hoac "grep"
2. Kiem tra moi Signal co `signal_type` trong ["frontend_api_call_unmatched","orphan_api","missing_route","method_mismatch"]
3. Kiem tra moi Signal co `dedup_hints` voi route info
4. Loai bo excluded routes (health, webhooks, auth, trpc, _next, customer/mobile, staff/mobile)
5. **FE call unmatched + GitNexus source → CRITICAL** (do chinh xac cao)
6. **FE call unmatched + grep source → HIGH** (co the false positive do regex)

---

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| GitNexus available + index fresh | Dung route_map PRIMARY — chinh xac 100%, khong can grep |
| GitNexus available + index stale | Dung route_map + WARN "index_stale" — van dung ket qua nhung co caveat |
| GitNexus unavailable | Fallback grep regex mo rong (B1-B3) — LOG WARN "gitnexus_unavailable_fallback_grep" |
| Khong tim thay route files | Skip probe, note "no_route_files" |
| Khong co Navigation specs | Skip nav cross-ref, chi flag FE↔BE mismatches |
| Khong co frontend API calls | Skip FE cross-ref, chi flag orphan BE endpoints |
| Scan Cache corrupt | Fallback: scan thuong, log WARNING |
| route_map khong co consumer info | Chi flag orphan_api, khong flag frontend_api_call_unmatched (external consumer) |
