# P-QD9-spa-route-coverage — SPA Route Config Coverage

> **Type:** hybrid (static CI extraction + runtime browser navigation) | **Profile:** deep, exhaustive | **Cache:** skip (always runtime)
> **Parallel class:** runtime → sequential (browser session; chay sau P-QD9-auth-aware-smoke)
> **Signal types:** `spa_route_unreachable` (MEDIUM)
> **Error codes:** E096 (browser lock fail — tu `_shared.md`)

Trich xuat full route list tu router config (Next.js pages/, Vue Router, React Router, Vite SPA) — KHONG chi dua vao `<a href>` traversal tu homepage. Dung Serena `find_symbol("Routes", "createBrowserRouter", "pages/")` lam CI-ROUTE PRIMARY. Navigate tung route tinh qua browser, emit `spa_route_unreachable` (MEDIUM) cho routes khai bao trong router config nhung khong accessible (404, 500, connection refused). Probe nay phat hien orphan routes — routes ton tai trong router config nhung user khong the navigate.

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| Browser launch + close | `procedures/probes/_shared.md` | `:26-44` | `pw_launch` / `pw_close` + trap EXIT |
| `emit_signal_browser` pattern | `procedures/probes/_shared.md` | `:51-86` | signal-v2 schema, atomic append toi RAW_DIR/probe_id.jsonl |
| Common variables | `procedures/probes/_shared.md` | `:7-18` | `LANE_DIR, RAW_DIR, SIGNALS_FILE, SESSION_FILE, DEV_SERVER_STATE, AUTH_SESSION` |
| Auth session reuse (PRE-GATE) | `QD9 P-QD9-auth-aware-smoke.md` | `:PRE-GATE step 1-8` | Doc AUTH_SESSION de inject cookies, bao ve protected routes |
| DEV_SERVER_STATE check | `QD9 P-QD9-auth-aware-smoke.md` | `:PRE-GATE step 52-57` | Verify dev server ready truoc khi chay browser probe |
| CI detection load | `QD9 P-QD9-interactive-smoke.md` | `:PRE-GATE step 5` | `source <(bash ci-detect.sh)` pattern |

**Diff so voi QD1-QD8 va QD9 probes khac:**
- W1.5c la probe DUY NHAT trong QD9 focus vao router config analysis (static route extraction)
- Khong dung `<a href>` traversal lam primary method — dung Serena/framework detection de locate router config
- NEW parser logic: 4 framework detection strategies (Next.js pages/, Next.js app/, Vue Router, React Router/Vite)
- Tao `spa-routes.json` coordination file cho QD10 (optional, phu QD9 coordination outputs)
- CI-ROUTE: Serena `find_symbol("createBrowserRouter", "Routes", "routes")` + GitNexus `query("router")` PRIMARY

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Locate React Router config (createBrowserRouter) | **Serena** `find_symbol({name_path_pattern: "createBrowserRouter", include_body: true})` | Grep `createBrowserRouter\|<Route path=` trong src/ | Extract route paths tu router definition |
| Locate Vue Router config (routes array) | **Serena** `find_symbol({name_path_pattern: "routes", relative_path: "router", include_body: true})` | Grep `path:` trong router files | Extract route paths |
| Locate Vite SPA routes export | **Serena** `find_symbol({name_path_pattern: "routes", include_body: true})` | Grep `routes =` trong src/ | Extract routes array |
| Next.js pages/ dir enumeration | Glob `pages/**/*.{tsx,ts,jsx,js}` (filesystem-based, Serena N/A) | `find $PROJECT_ROOT -type d -name pages` | Enumerate file-system routes |
| Trace router registration flows | **GitNexus** `query("router, route, createBrowserRouter, RouterProvider")` | Grep | Tim them SPA dynamic routes khong co trong static config |

**Khi CI unavailable:**
```bash
if [[ "$SERENA_AVAILABLE" != "true" ]]; then
  echo "WARN: Serena unavailable — fallback to Grep/Glob for router config extraction" >&2
fi
if [[ "$GITNEXUS_AVAILABLE" != "true" ]]; then
  echo "WARN: GitNexus unavailable — skip route augmentation via graph query" >&2
fi
```

---

## PRE-GATE

```
1. IF profile=quick OR profile=standard:
     SKIP probe, note "QD9-deep-only-spa-route-coverage-skip"
     → Chi chay khi profile=deep hoac exhaustive

2. IF --no-browser: SKIP probe (da SKIP toan lane E093 — probe nay khong duoc goi)

3. IF DEV_SERVER_STATE khong ton tai HOAC status == "fail":
     SKIP probe, note "skipped_dev_server_not_ready (E095 upstream)"

4. Read BASE_URL tu DEV_SERVER_STATE.url
   IF BASE_URL == null hoac "": SKIP probe, note "skipped_no_base_url"

5. Load CI availability:
     source <(bash .claude/scripts/ci-detect.sh --project-root "$PROJECT_ROOT" 2>/dev/null) || true
     GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
     SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"

6. Detect PROJECT_ROOT (monorepo handling):
     PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
     # EUREKA: apps/erp-web/pages/ duoc scan nhu mot PROJECT_ROOT candidate
     # → tim tat ca package.json co "next" dependency, dung lam CANDIDATE_ROOTS[]

7. IF AUTH_SESSION ton tai va non-empty:
     LOG "INFO: AUTH_SESSION found — will inject cookies for protected routes"
   ELSE:
     LOG "INFO: No AUTH_SESSION — auth-protected routes se redirect to /login (skip, not error)"
```

---

## SENSE

### S1: Framework Detection

```bash
FRAMEWORK="unknown"
PAGES_DIR=""
ROUTER_FILES=()

# Xay dung danh sach candidate roots (monorepo support)
CANDIDATE_ROOTS=("$PROJECT_ROOT")
if [ -d "$PROJECT_ROOT/apps" ]; then
  for APP_DIR in "$PROJECT_ROOT"/apps/*/; do
    [ -d "$APP_DIR" ] && CANDIDATE_ROOTS+=("$APP_DIR")
  done
fi

# Next.js pages/ router detection
for CANDIDATE_ROOT in "${CANDIDATE_ROOTS[@]}"; do
  CANDIDATE_ROOT="${CANDIDATE_ROOT%/}"  # Xoa trailing slash

  if [ -d "$CANDIDATE_ROOT/pages" ]; then
    FRAMEWORK="nextjs-pages"
    PAGES_DIR="$CANDIDATE_ROOT/pages"
    LOG "INFO: Detected Next.js pages router: $PAGES_DIR" >&2
    break
  elif [ -d "$CANDIDATE_ROOT/app" ]; then
    # Kiem tra app router (Next.js 13+) — phai co it nhat 1 page.tsx
    if find "$CANDIDATE_ROOT/app" -name "page.tsx" -o -name "page.ts" -o -name "page.jsx" -o -name "page.js" 2>/dev/null | head -1 | grep -q .; then
      FRAMEWORK="nextjs-app"
      PAGES_DIR="$CANDIDATE_ROOT/app"
      LOG "INFO: Detected Next.js app router: $PAGES_DIR" >&2
      break
    fi
  fi
done

# Vue Router detection (neu chua phat hien Next.js)
if [[ "$FRAMEWORK" == "unknown" ]]; then
  VUE_ROUTER_FILE=$(find "$PROJECT_ROOT" -type f \( -name "router.ts" -o -name "router.js" -o -name "router/index.ts" -o -name "routes.ts" -o -name "routes.js" \) -not -path "*/node_modules/*" 2>/dev/null | head -1)
  if [ -n "$VUE_ROUTER_FILE" ]; then
    FRAMEWORK="vue-router"
    ROUTER_FILES+=("$VUE_ROUTER_FILE")
    LOG "INFO: Detected Vue Router: $VUE_ROUTER_FILE" >&2
  fi
fi

# React Router / Vite SPA detection (createBrowserRouter, BrowserRouter, Routes)
if [[ "$FRAMEWORK" == "unknown" ]]; then
  REACT_ROUTER_FILE=$(grep -rl "createBrowserRouter\|BrowserRouter\|<Routes>" "$PROJECT_ROOT/src" 2>/dev/null | grep -v node_modules | head -1)
  if [ -n "$REACT_ROUTER_FILE" ]; then
    FRAMEWORK="react-router"
    ROUTER_FILES+=("$REACT_ROUTER_FILE")
    LOG "INFO: Detected React Router: $REACT_ROUTER_FILE" >&2
  fi
fi

# Vite SPA generic routes export (fallback)
if [[ "$FRAMEWORK" == "unknown" ]]; then
  VITE_ROUTES_FILE=$(grep -rl "const routes" "$PROJECT_ROOT/src" 2>/dev/null | grep -E "\.(ts|js|tsx|jsx)$" | grep -v node_modules | head -1)
  if [ -n "$VITE_ROUTES_FILE" ]; then
    FRAMEWORK="vite-spa"
    ROUTER_FILES+=("$VITE_ROUTES_FILE")
    LOG "INFO: Detected Vite SPA routes: $VITE_ROUTES_FILE" >&2
  fi
fi

if [[ "$FRAMEWORK" == "unknown" ]]; then
  LOG "WARN: Cannot detect SPA framework — will attempt link traversal as fallback" >&2
fi
LOG "INFO: Framework: $FRAMEWORK" >&2
```

### S2: Static Route Extraction (CI-ROUTE PRIMARY: Serena / Glob)

```bash
STATIC_ROUTES=()

if [[ "$FRAMEWORK" == "nextjs-pages" ]]; then
  # Next.js pages/ pattern: file path → URL path
  # Serena khong applicable cho filesystem scan → Glob PRIMARY
  while IFS= read -r PAGE_FILE; do
    ROUTE=$(echo "$PAGE_FILE" | sed "s|$PAGES_DIR||" | \
      grep -vE '(^/_|/__|\/_)' | \
      grep -v '/api/' | \
      sed 's|/index\.[a-z]*$|/|' | \
      sed 's|\.[a-z]*$||' | \
      sed 's|\[\.\.\..*\]|CATCH_ALL|g' | \
      sed 's|\[.*\]|PARAM|g')
    [ -n "$ROUTE" ] && [[ "$ROUTE" != *"CATCH_ALL"* ]] && STATIC_ROUTES+=("$ROUTE")
  done < <(find "$PAGES_DIR" -type f \( -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" -o -name "*.js" \) 2>/dev/null | sort)

elif [[ "$FRAMEWORK" == "nextjs-app" ]]; then
  # Next.js app/ router: page.{tsx,ts,jsx,js} → URL path
  while IFS= read -r PAGE_FILE; do
    ROUTE=$(echo "$PAGE_FILE" | sed "s|$PAGES_DIR||" | \
      sed 's|/page\.[a-z]*$||' | \
      sed 's|^\s*$|/|' | \
      sed 's|\(route-group\).*||' | \
      sed 's|\[\.\.\..*\]|CATCH_ALL|g' | \
      sed 's|\[.*\]|PARAM|g')
    [ -n "$ROUTE" ] && [[ "$ROUTE" != *"CATCH_ALL"* ]] && STATIC_ROUTES+=("$ROUTE")
  done < <(find "$PAGES_DIR" \( -name "page.tsx" -o -name "page.ts" -o -name "page.jsx" -o -name "page.js" \) 2>/dev/null | sort)

elif [[ "$FRAMEWORK" == "vue-router" ]]; then
  # Vue Router: parse router file cho path: attributes
  # CI-ROUTE PRIMARY: Serena find_symbol({name_path_pattern: "routes", include_body: true})
  if [[ "$SERENA_AVAILABLE" == "true" ]]; then
    # (Pseudocode — orchestrator agent thuc hien):
    # ROUTER_BODY = serena_find_symbol({name_path_pattern: "routes", relative_path: "router", include_body: true})
    # STATIC_ROUTES = parse_path_attributes_from_body(ROUTER_BODY)
    LOG "INFO: Using Serena find_symbol(routes) for Vue Router config" >&2
  fi
  # Fallback: grep path attributes
  for ROUTER_FILE in "${ROUTER_FILES[@]}"; do
    while IFS= read -r ROUTE_PATH; do
      [ -n "$ROUTE_PATH" ] && STATIC_ROUTES+=("$ROUTE_PATH")
    done < <({
      grep -oE "path:\s*'[^']*'" "$ROUTER_FILE" 2>/dev/null | grep -oE "'[^']*'$" | tr -d "'"
      grep -oE 'path:\s*"[^"]*"' "$ROUTER_FILE" 2>/dev/null | grep -oE '"[^"]*"$' | tr -d '"'
    } | grep -v '^\s*$' | sort -u || echo "")
  done

elif [[ "$FRAMEWORK" == "react-router" || "$FRAMEWORK" == "vite-spa" ]]; then
  # React Router: parse createBrowserRouter({ path: "..." }) hoac <Route path="...">
  # CI-ROUTE PRIMARY: Serena find_symbol({name_path_pattern: "createBrowserRouter", include_body: true})
  if [[ "$SERENA_AVAILABLE" == "true" ]]; then
    # (Pseudocode — orchestrator agent thuc hien):
    # ROUTER_BODY = serena_find_symbol({name_path_pattern: "createBrowserRouter", include_body: true})
    # STATIC_ROUTES = parse_path_attributes_from_body(ROUTER_BODY)
    LOG "INFO: Using Serena find_symbol(createBrowserRouter) for React Router config" >&2
  fi
  # Fallback: grep path attributes tu router files
  for ROUTER_FILE in "${ROUTER_FILES[@]}"; do
    while IFS= read -r ROUTE_PATH; do
      [ -n "$ROUTE_PATH" ] && STATIC_ROUTES+=("$ROUTE_PATH")
    done < <({
      grep -oE '"path":\s*"[^"]*"' "$ROUTER_FILE" 2>/dev/null | grep -oE '"[^"]*"$' | tr -d '"'
      grep -oE "path:\s*'[^']*'" "$ROUTER_FILE" 2>/dev/null | grep -oE "'[^']*'$" | tr -d "'"
      grep -oE 'path="[^"]*"' "$ROUTER_FILE" 2>/dev/null | grep -oE '"[^"]*"$' | tr -d '"'
    } | grep -v '^\s*$' | sort -u || echo "")
  done
fi

LOG "INFO: Extracted ${#STATIC_ROUTES[@]} raw routes from $FRAMEWORK config" >&2
```

### S3: GitNexus Route Augmentation

```bash
if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
  # GitNexus query("router, route, createBrowserRouter, RouterProvider") → tim them routes
  # (Pseudocode — orchestrator agent thuc hien):
  # GN_RESULT = gitnexus_query({query: "router"})
  # Tim path strings tu GN_RESULT, append routes chua co trong STATIC_ROUTES
  LOG "INFO: GitNexus augmenting route list via query(router)" >&2
else
  LOG "WARN: GitNexus unavailable — skip route augmentation" >&2
fi
```

---

## THINK

### Route Normalization va Limit Application

```bash
# Profile limits (probe chi chay deep+)
case "${PROFILE:-standard}" in
  deep)       MAX_ROUTES=100 ;;
  exhaustive) MAX_ROUTES=300 ;;
  *)          MAX_ROUTES=0 ;;
esac

# Dedup va normalize STATIC_ROUTES
NORMALIZED_ROUTES=()
declare -A SEEN_ROUTES

for ROUTE in "${STATIC_ROUTES[@]}"; do
  # Normalize: them leading slash
  [[ "$ROUTE" != /* ]] && ROUTE="/$ROUTE"

  # Loai dynamic segments — khong the navigate truc tiep
  if echo "$ROUTE" | grep -qE '(:|\[).*\]|PARAM|\*|\+'; then
    LOG "INFO: Skip dynamic route: $ROUTE" >&2
    continue
  fi

  # Loai API routes
  if echo "$ROUTE" | grep -qE '^/api/'; then
    LOG "INFO: Skip API route: $ROUTE" >&2
    continue
  fi

  # Loai Next.js internal routes
  if echo "$ROUTE" | grep -qE '^/_next/|^/_app|^/_document|^/_error'; then
    LOG "INFO: Skip Next.js internal route: $ROUTE" >&2
    continue
  fi

  # Dedup
  [[ -n "${SEEN_ROUTES[$ROUTE]:-}" ]] && continue
  SEEN_ROUTES["$ROUTE"]=1
  NORMALIZED_ROUTES+=("$ROUTE")
done

# Apply MAX_ROUTES limit
TOTAL_DECLARED=${#NORMALIZED_ROUTES[@]}
if [ "$TOTAL_DECLARED" -gt "$MAX_ROUTES" ]; then
  LOG "INFO: Truncating route list: $TOTAL_DECLARED → $MAX_ROUTES (profile limit)" >&2
  NORMALIZED_ROUTES=("${NORMALIZED_ROUTES[@]:0:$MAX_ROUTES}")
fi

LOG "INFO: THINK: ${#NORMALIZED_ROUTES[@]} routes to navigate (framework=$FRAMEWORK, declared=$TOTAL_DECLARED, limit=$MAX_ROUTES)" >&2

# Neu STATIC_ROUTES rong: SKIP probe
if [ "${#NORMALIZED_ROUTES[@]}" -eq 0 ]; then
  LOG "WARN: No navigable routes extracted — skip probe (skipped_no_routes_extracted_from_config)" >&2
  cat > "$RAW_DIR/P-QD9-spa-route-coverage-summary.json" << EOF
{
  "probe_id": "P-QD9-spa-route-coverage",
  "framework": "$FRAMEWORK",
  "routes_declared": 0,
  "skip_reason": "skipped_no_routes_extracted_from_config"
}
EOF
  exit 0
fi

# Ghi spa-routes.json cho QD10 coordination (optional output)
ROUTES_JSON="["
for i in "${!NORMALIZED_ROUTES[@]}"; do
  [ $i -gt 0 ] && ROUTES_JSON+=","
  ROUTES_JSON+="\"${NORMALIZED_ROUTES[$i]}\""
done
ROUTES_JSON+="]"

cat > "$LANE_DIR/spa-routes.json" << EOF
{
  "framework": "$FRAMEWORK",
  "total_declared": $TOTAL_DECLARED,
  "total_navigable": ${#NORMALIZED_ROUTES[@]},
  "routes": $ROUTES_JSON,
  "profile": "${PROFILE:-standard}"
}
EOF
LOG "INFO: spa-routes.json created (${#NORMALIZED_ROUTES[@]} routes)" >&2
```

---

## ACT

### A0: Acquire Browser Singleton

```bash
pw_launch || {
  echo "ERROR: Cannot launch browser (E096)" >&2
  exit 1
}
trap "pw_close" EXIT
```

### A1: Auth Inject (neu AUTH_SESSION co san)

```bash
if [ -s "$AUTH_SESSION" ]; then
  AUTH_COOKIES=$(jq -r '.cookies // [] | .[] | "\(.name)=\(.value)"' "$AUTH_SESSION" 2>/dev/null || echo "")
  if [ -n "$AUTH_COOKIES" ]; then
    # Inject cookies qua document.cookie (Playwright bash-level compatible)
    # pw_evaluate expression="
    #   var c = '$AUTH_COOKIES'; document.cookie = c + '; path=/';
    # "
    LOG "INFO: Auth cookies injected from AUTH_SESSION" >&2
  fi
fi
```

### A2: Navigate Homepage (de establish session context)

```bash
# Navigate homepage de establish cookies va session
# pw_ url="$BASE_URL/" wait_until="networkidle"
# pw_ time=2000
LOG "INFO: Homepage loaded — starting static route navigation" >&2
```

### A3: Per-Route Navigate va Check

```bash
SIGNAL_COUNT=0
MAX_SIGNALS=50
ROUTES_TESTED=0
ROUTES_OK=0
ROUTES_BROKEN=0
ROUTES_SKIPPED_AUTH=0

for ROUTE_PATH in "${NORMALIZED_ROUTES[@]}"; do
  FULL_URL="$BASE_URL$ROUTE_PATH"
  LOG "INFO: SPA route coverage check: $FULL_URL" >&2

  # A3.1 — Navigate toi route
  NAV_RESULT=$(pw_ --url "$FULL_URL" --wait_until "domcontentloaded" 2>&1 || echo "NAV_ERROR")
  # pw_ time=2000

  ROUTES_TESTED=$((ROUTES_TESTED + 1))

  # A3.2 — Check current URL va title (theo doi redirect)
  CURRENT_URL=$(pw_evaluate ""window.location.href" 2>&1 || echo ""
  CURRENT_TITLE=$(pw_evaluate ""document.title" 2>&1 || echo ""

  # A3.3 — Auth redirect detection (khong phai error — la protected route)
  IS_AUTH_REDIRECT=false
  if echo "$CURRENT_URL" | grep -qiE '/login|/signin|/auth/login|/sign-in|/dang-nhap'; then
    IS_AUTH_REDIRECT=true
  fi

  if $IS_AUTH_REDIRECT; then
    LOG "INFO: Route $ROUTE_PATH redirects to auth — skip (protected route, not broken)" >&2
    ROUTES_SKIPPED_AUTH=$((ROUTES_SKIPPED_AUTH + 1))
    continue
  fi

  # A3.4 — Phan loai failure
  IS_ERROR=false
  ERROR_REASON=""

  if [[ "$NAV_RESULT" == *"NAV_ERROR"* ]] || [[ "$NAV_RESULT" == *"ERR_CONNECTION"* ]] || [[ "$NAV_RESULT" == *"net::ERR_"* ]]; then
    IS_ERROR=true
    ERROR_REASON="connection_refused"
  elif echo "$CURRENT_URL" | grep -qE '/404' || echo "$CURRENT_TITLE" | grep -qiE '^404|Not Found'; then
    IS_ERROR=true
    ERROR_REASON="404_not_found"
  elif echo "$CURRENT_URL" | grep -qE '/500' || echo "$CURRENT_TITLE" | grep -qiE '500|Internal Server Error'; then
    IS_ERROR=true
    ERROR_REASON="500_server_error"
  fi

  if $IS_ERROR; then
    [ "$SIGNAL_COUNT" -ge "$MAX_SIGNALS" ] && {
      LOG "WARN: max_signals_reached ($MAX_SIGNALS)" >&2
      break
    }

    SCREENSHOT_PATH="$RAW_DIR/screenshot-P-QD9-src-$(echo "$ROUTE_PATH" | md5sum | cut -c1-8).png"
    pw_screenshot "$SCREENSHOT_PATH" 2>/dev/null || \
      SCREENSHOT_PATH="null"

    emit_signal_browser "P-QD9-spa-route-coverage" \
      "spa_route_unreachable" "medium" \
      "Route khai bao trong router config nhung khong the navigate: $ROUTE_PATH" \
      "Route '$ROUTE_PATH' ton tai trong $FRAMEWORK router config nhung navigation that bai: $ERROR_REASON. URL hien tai: $CURRENT_URL — Title: $CURRENT_TITLE. Route co the la broken link, chua implement dung, hoac bi loi routing config." \
      "$FULL_URL" \
      "screenshot" \
      "Route: $ROUTE_PATH | Framework: $FRAMEWORK | Error: $ERROR_REASON | Current_URL: $CURRENT_URL | Title: $CURRENT_TITLE" \
      "\"$SCREENSHOT_PATH\""

    SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
    ROUTES_BROKEN=$((ROUTES_BROKEN + 1))
    LOG "INFO: Signal emitted — spa_route_unreachable: $ROUTE_PATH ($ERROR_REASON)" >&2

  else
    ROUTES_OK=$((ROUTES_OK + 1))
    LOG "INFO: Route $ROUTE_PATH OK (current_url=$CURRENT_URL)" >&2
  fi

done
```

---

## VERIFY

```
1. Kiem tra moi signal co dimension_id == "QD9" va probe_id == "P-QD9-spa-route-coverage"
2. Kiem tra moi signal co signal_type == "spa_route_unreachable"
3. Kiem tra moi signal co severity == "medium"
4. Kiem tra moi signal co evidence[] non-empty voi content >= 10 chars
5. Kiem tra spa-routes.json duoc tao voi framework field non-empty (hoac skip_reason neu 0 routes)
6. Kiem tra NORMALIZED_ROUTES list non-empty (hoac WARN "no routes extracted" neu 0)
7. Kiem tra route limit khong vuot MAX_ROUTES
8. Tong signals per probe <= 50 (hoac co WARNING "max_signals_reached")
9. Kiem tra sampling field ton tai khi TOTAL_DECLARED > MAX_ROUTES

Ghi summary:
  cat > "$RAW_DIR/P-QD9-spa-route-coverage-summary.json" << EOF
  {
    "probe_id": "P-QD9-spa-route-coverage",
    "framework": "$FRAMEWORK",
    "routes_declared": $TOTAL_DECLARED,
    "routes_navigable": ${#NORMALIZED_ROUTES[@]},
    "routes_tested": $ROUTES_TESTED,
    "routes_ok": $ROUTES_OK,
    "routes_broken": $ROUTES_BROKEN,
    "routes_skipped_auth": $ROUTES_SKIPPED_AUTH,
    "signals_emitted": $SIGNAL_COUNT,
    "serena_used": $SERENA_USED,
    "gitnexus_used": $GITNEXUS_USED,
    "sampling": {
      "rate": $((ROUTES_TESTED * 100 / (TOTAL_DECLARED == 0 ? 1 : TOTAL_DECLARED))),
      "total": $TOTAL_DECLARED,
      "sampled": $ROUTES_TESTED
    }
  }
  EOF
```

---

## Severity Rules

| Dieu kien | Severity | Ly do |
|-----------|----------|-------|
| Route trong router config → navigate → 404 Not Found | **MEDIUM** | Route khai bao nhung khong co handler — can them route handler |
| Route trong router config → navigate → 500 Server Error | **MEDIUM** | Route co handler nhung bi loi server khi render |
| Route trong router config → connection refused | **MEDIUM** | Khong the connect — co the dev server het hoac route sai |
| Route redirect toi /login hoac /auth | **SKIP** | Protected route — auth context thieu, khong phai bug routing |
| Route dynamic (:param, [param], catch-all) | **SKIP** | Can params — khong navigate truc tiep duoc |
| Route la /api/* | **SKIP** | API route — khong phai UI page |

> **Rationale severity MEDIUM (khong HIGH):** Route broken trong SPA config quan trong nhung khong critical —
> app van chay duoc (chi 1 route loi). CRITICAL chi khi toan app crash (pageerror tu _shared.md).
> HIGH chi khi feature co `impl_status=done` nhung route broken (do W1.5a phat hien, khong phai probe nay).

---

## Dedup Hints

Moi signal phai co `dedup_hints` array:

| Signal Type | Dedup Hint Pattern |
|-------------|-------------------|
| `spa_route_unreachable` | `["spa-route-unreachable:{framework}:{route_path}"]` |

Cross-probe dedup: `spa_route_unreachable` tu W1.5c co the trung voi `feature_route_broken` tu W1.5a khi cung route bi affect. Aggregator dedup boi fingerprint (probe_id, signal_type, route_path).

---

## Signal Schema Examples

### spa_route_unreachable

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD9-spa-route-coverage",
  "dimension_id": "QD9",
  "signal_type": "spa_route_unreachable",
  "severity": "medium",
  "title": "Route khai bao trong router config nhung khong the navigate: /dashboard/settings",
  "description": "Route '/dashboard/settings' ton tai trong nextjs-pages router config nhung navigation that bai: 404_not_found. URL hien tai: http://localhost:3000/404 — Title: '404 | Not Found'. Route co the la broken link, chua implement dung, hoac bi loi routing config.",
  "location": {"url": "http://localhost:3000/dashboard/settings"},
  "evidence": [
    {"type": "screenshot", "content": "/session/phase4-find-bugs/lanes/QD9-runtime-health/raw/screenshot-P-QD9-src-abc12345.png"},
    {"type": "log_excerpt", "content": "Route: /dashboard/settings | Framework: nextjs-pages | Error: 404_not_found | Current_URL: http://localhost:3000/404 | Title: 404 | Not Found"}
  ],
  "screenshot": "/session/phase4-find-bugs/lanes/QD9-runtime-health/raw/screenshot-P-QD9-src-abc12345.png",
  "cdg_flags": [],
  "fixability": "agent_fix",
  "dedup_hints": ["spa-route-unreachable:nextjs-pages:/dashboard/settings"]
}
```

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile=quick hoac standard | SKIP probe, note "QD9-deep-only-spa-route-coverage-skip" |
| DEV_SERVER_STATE khong co hoac failed | SKIP probe, note "skipped_dev_server_not_ready (E095 upstream)" |
| BASE_URL null | SKIP probe, note "skipped_no_base_url" |
| Framework khong detect duoc | Log WARN "framework_unknown" — fallback Glob `src/**/*.{tsx,ts,jsx,js}` de tim route clues |
| STATIC_ROUTES rong sau extraction | SKIP probe, note "skipped_no_routes_extracted_from_config" — khong emit signal |
| Route co dynamic params (:id, [slug]) | Skip navigation — log INFO "dynamic_route_skip_{path}" |
| Route la /api/* | Skip — log INFO "api_route_skip_{path}" |
| Route redirect toi /login | Skip — log INFO "auth_protected_route_skip_{path}" — khong phai bug |
| Navigation ERR_CONNECTION | Emit spa_route_unreachable, reason=connection_refused |
| 404 Not Found | Emit spa_route_unreachable, reason=404_not_found |
| 500 Internal Server Error | Emit spa_route_unreachable, reason=500_server_error |
| > MAX_ROUTES declared routes | Truncate list — log INFO "routes_truncated_to_{limit}" |
| > 50 signals tong | Stop emitting, log WARN "max_signals_reached" |
| Serena unavailable | Fallback to Grep/Glob for router config extraction — log WARN, khong block |
| GitNexus unavailable | Skip augmentation — log WARN, khong block |
| Screenshot capture fail | Set screenshot: "null" trong signal, tiep tuc |
| spa-routes.json write fail | Log WARN — khong block probe (optional coordination file) |
| pw_launch fail (E096) | STOP probe — exit 1, ghi error >&2 |

---

## Cache Policy

**skip** — probe nay co phase runtime (Playwright browser navigation). KHONG cache results.

Ly do: Route reachability la runtime state — cache se mask routes moi bi broken sau deploy.
Static route extraction (framework detection) co the cache 24h nhung navigation verification phai fresh.

---

## Profile-Resolver Entry

```yaml
# Trong _shared/lane/profile-resolver.md (QD9 section):
P-QD9-spa-route-coverage:
  quick: skip
  standard: skip
  deep: run
  exhaustive: run (extended limits: max_routes=300)
  parallel_class: runtime
  optional: false
  max_routes_by_profile:
    deep: 100
    exhaustive: 300
```

---

## Acceptance Test

**Synthetic test (CI):**
1. Setup Next.js project voi pages/:
   - `pages/index.tsx` → `/` (working — 200)
   - `pages/dashboard.tsx` → `/dashboard` (working — 200)
   - `pages/settings/profile.tsx` → `/settings/profile` (returns 404 — simulate loi)
2. Run probe voi `--profile=deep`
3. **Expected:**
   - `/` va `/dashboard` → KHONG co signal (routes accessible)
   - `/settings/profile` → `spa_route_unreachable` signal severity=MEDIUM trong P-QD9-spa-route-coverage.jsonl
   - `spa-routes.json` duoc tao voi `framework=nextjs-pages` va routes list
   - `routes_declared: 3, routes_tested: 3, routes_broken: 1` trong summary.json
4. Verify: `jq '.signal_type == "spa_route_unreachable"' RAW_DIR/P-QD9-spa-route-coverage.jsonl`

**EUREKA real-world acceptance (W1.5.E2E):**
- Chay `/wf-fix-bugs --lane=QD9 --profile=deep --scope=module --name=MOD-CRM` tren EUREKA erp-web
- Expect: Framework detected = nextjs-pages (apps/erp-web/pages/)
- Expect: >= 1 route duoc extract tu pages/ dir
- Expect: Routes navigate duoc → OK; routes 404 → signal emitted
- Expect: `spa-routes.json` duoc tao cho QD10 coordination (optional)
- Performance: probe complete trong <= 5 phut cho module scope (100 routes × 2s wait max)
