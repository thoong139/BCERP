# P-QD5-ui-traversal-deep — Deep UI Traversal & Interaction Smoke

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD5-ui-traversal-deep |
| **Loai** | runtime |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Deep UI traversal: click every link, button, nav item. Phat hien broken navigation (404/500), JavaScript console errors, loading state stalls, dead links. Verify all routes reachable from homepage. |
| **Cache** | skip (runtime probe) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co BASE_URL va khong co Playwright MCP -> SKIP, note "no_traversal_tooling"
IF khong co frontend source dir -> SKIP
IF profile=standard: chi crawl homepage + 10 links
IF profile=deep: crawl homepage + all same-origin links (max 50)
IF profile=exhaustive: deep crawl + interaction smoke (hover, click modals)
```

## SENSE

### B1: Static pre-check — extract route/URL patterns

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/raw/P-QD5-ui-traversal-deep.json"
mkdir -p "$(dirname "$RAW_OUT")"
SIGNALS_JSON='[]'
SOURCE="${SOURCE_DIR:-src/}"

# Extract internal route paths from code for coverage comparison
grep -rnE '(path\s*:\s*|href\s*=\s*|to\s*=\s*|navigate\s*\()["\x27]/' "$SOURCE" \
  --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' \
  2>/dev/null | grep -vE '(node_modules|\.test\.|\.spec\.|https?://)' | \
  grep -oE '["\x27](/[^"\x27]{2,60})["\x27]' | sed 's/["\x27]//g' | sort -u | head -50 > "$RAW_OUT.routes"
ROUTE_COUNT=$(wc -l < "$RAW_OUT.routes" 2>/dev/null || echo 0)
```

### B2: Runtime — Playwright deep crawl

```bash
if [ -n "${BASE_URL:-}" ]; then
  TRAV_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/runtime"
  mkdir -p "$TRAV_DIR"
  
  MAX_LINKS=10
  [ "${PROFILE:-standard}" = "deep" ] && MAX_LINKS=50
  [ "${PROFILE:-standard}" = "exhaustive" ] && MAX_LINKS=100
  
  # Launch shared browser session (playwright-session.js — xem _shared.md §0)
  pw_launch || { echo "E096: browser_unavailable" >&2; exit 1; }
  
  cat > "$TRAV_DIR/traversal.js" <<TRAV_SCRIPT
const { chromium } = require('playwright');
const fs = require('fs');
const baseUrl = process.env.BASE_URL;
const MAX_LINKS = parseInt(process.env.MAX_LINKS || '10');

(async () => {
  const state = JSON.parse(fs.readFileSync(process.env.SESSION_FILE, 'utf-8'));
  const browser = await chromium.connectOverCDP(state.wsEndpoint);
  const context = browser.contexts()[0] || await browser.newContext();
  const page = await context.newPage();
  const results = { pages: {}, summary: { totalPages: 0, errors: 0, warnings: 0, consoleErrors: 0 } };
  const consoleErrors = [];
  
  page.on('console', msg => {
    if (msg.type() === 'error') {
      consoleErrors.push({ text: msg.text().substring(0, 200), url: page.url() });
    }
  });
  
  page.on('pageerror', err => {
    consoleErrors.push({ text: err.message.substring(0, 200), url: page.url(), uncaught: true });
  });
  
  const visited = new Set();
  const toVisit = [baseUrl];
  let visitedCount = 0;
  
  while (toVisit.length > 0 && visitedCount < MAX_LINKS) {
    const url = toVisit.shift();
    if (visited.has(url)) continue;
    visited.add(url);
    visitedCount++;
    
    const pageResult = { url, status: null, title: '', links: [], interactions: [] };
    
    try {
      const response = await page.goto(url, { waitUntil: 'networkidle', timeout: 15000 });
      pageResult.status = response?.status() || 0;
      pageResult.title = await page.title();
      
      // Collect same-origin links for further traversal
      if (visitedCount < MAX_LINKS) {
        const links = await page.evaluate((base) => {
          const anchors = document.querySelectorAll('a[href]');
          return Array.from(anchors)
            .map(a => a.href)
            .filter(h => h.startsWith(base) && !h.includes('#') && !h.includes('logout') && !h.includes('sign-out'))
            .slice(0, 30);
        }, baseUrl);
        pageResult.links = links;
        links.forEach(l => { if (!visited.has(l)) toVisit.push(l); });
      }
      
      // Check for common error indicators
      const bodyText = await page.textContent('body') || '';
      const hasErrorText = /(404|not found|500|internal server error|something went wrong|page not found|unexpected error)/i.test(bodyText.substring(0, 2000));
      
      if (pageResult.status >= 400) {
        pageResult.issue = { type: 'http_error', status: pageResult.status };
        results.summary.errors++;
      } else if (hasErrorText && pageResult.status === 200) {
        // Soft 404: page returns 200 but shows error content
        pageResult.issue = { type: 'soft_error', description: 'Page returns 200 but contains error text' };
        results.summary.warnings++;
      }
      
      // Interaction smoke (exhaustive only)
      if (process.env.PROFILE === 'exhaustive' && pageResult.status < 400) {
        const buttons = await page.$$('button, [role="button"], .btn');
        for (let i = 0; i < Math.min(buttons.length, 5); i++) {
          try {
            const btnText = await buttons[i].textContent() || '';
            await buttons[i].click({ timeout: 3000 });
            await page.waitForTimeout(500);
            pageResult.interactions.push({ element: 'button', text: btnText.substring(0, 40), success: true });
            // Navigate back to continue traversal
            await page.goBack({ timeout: 5000 }).catch(() => {});
            await page.waitForTimeout(500);
          } catch (e) {
            pageResult.interactions.push({ element: 'button', error: e.message.substring(0, 80) });
          }
        }
      }
      
    } catch (e) {
      pageResult.status = 0;
      pageResult.issue = { type: 'navigation_failed', error: e.message.substring(0, 100) };
      results.summary.errors++;
    }
    
    results.pages[url] = pageResult;
  }
  
  results.summary.totalPages = visitedCount;
  results.summary.consoleErrors = consoleErrors.length;
  results.consoleErrors = consoleErrors.slice(0, 20);
  
  console.log(JSON.stringify(results));
  // Browser stays alive — shared session managed by playwright-session.js
})().catch(e => { console.error(JSON.stringify({ error: e.message })); process.exit(1); });
TRAV_SCRIPT

  if command -v npx &>/dev/null && npx playwright --version &>/dev/null 2>&1; then
    PROFILE="${PROFILE:-standard}" MAX_LINKS="$MAX_LINKS" BASE_URL="$BASE_URL" \
      SESSION_FILE="$SESSION_DIR/playwright-session.json" node "$TRAV_DIR/traversal.js" > "$TRAV_DIR/traversal-results.json" 2>/dev/null || true
    
    if [ -f "$TRAV_DIR/traversal-results.json" ]; then
      TOTAL=$(jq -r '.summary.totalPages // 0' "$TRAV_DIR/traversal-results.json" 2>/dev/null)
      ERRORS=$(jq -r '.summary.errors // 0' "$TRAV_DIR/traversal-results.json" 2>/dev/null)
      CONSOLE_ERRS=$(jq -r '.summary.consoleErrors // 0' "$TRAV_DIR/traversal-results.json" 2>/dev/null)
      
      # Emit per-error-page signals
      jq -c '.pages | to_entries[] | select(.value.issue != null)' "$TRAV_DIR/traversal-results.json" 2>/dev/null | \
      while IFS= read -r page_data; do
        page_url=$(echo "$page_data" | jq -r '.key')
        status=$(echo "$page_data" | jq -r '.value.status // 0')
        issue_type=$(echo "$page_data" | jq -r '.value.issue.type // "unknown"')
        
        severity="high"
        [ "$issue_type" = "soft_error" ] && severity="medium"
        
        fp=$(echo -n "QD5|traversal|$page_url|P-QD5-ui-traversal-deep" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
        sig=$(jq -nc \
          --arg url "$page_url" --argjson status "$status" --arg issue "$issue_type" \
          --arg severity "$severity" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-ui-traversal-deep",severity:$severity,fixability:"agent_fix",domain:"functional",
            title:("Broken page: "+$issue+" at "+$url), description:("Page "+$url+" returns HTTP "+($status|tostring)+" ("+$issue+"). Link or route may be broken."),
            location:{file:"runtime",line:null,url:$url}, evidence:[{type:"http_response",path:"runtime",description:"HTTP "+($status|tostring)+" on "+$url}],
            cdg_flags:[],fingerprint:$fp,
            remediation:{suggested_action:"Fix broken link/route. Check routing config, verify page component exports, fix server error.",suggested_agent:"frontend-developer",estimated_effort:"medium"},
            detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-ui-traversal-deep"}')
        SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
      done
      
      # Console errors signal (if many)
      if [ "$CONSOLE_ERRS" -gt 2 ] 2>/dev/null; then
        fp=$(echo -n "QD5|traversal|console_errors|P-QD5-ui-traversal-deep" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
        sig=$(jq -nc \
          --argjson count "$CONSOLE_ERRS" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-ui-traversal-deep",severity:"medium",fixability:"agent_fix",domain:"functional",
            title:("JavaScript console errors during traversal: "+($count|tostring)+" errors"), description:($count|tostring)+" console errors detected across pages. May indicate broken functionality or unhandled exceptions.",
            location:{file:"runtime",line:null,url:null}, evidence:[{type:"metric",path:"runtime",description:($count|tostring)+" console errors"}],
            cdg_flags:[],fingerprint:$fp,
            remediation:{suggested_action:"Review console errors. Fix unhandled exceptions, missing imports, or API call failures.",suggested_agent:"frontend-developer",estimated_effort:"medium"},
            detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-ui-traversal-deep"}')
        SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
      fi
      
      # Coverage gap: routes in code but not visited
      if [ -f "$RAW_OUT.routes" ] && [ "$TOTAL" -gt 0 ] 2>/dev/null; then
        VISITED_URLS=$(jq -r '.pages | keys[]' "$TRAV_DIR/traversal-results.json" 2>/dev/null)
        while IFS= read -r route; do
          [ -z "$route" ] && continue
          if ! echo "$VISITED_URLS" | grep -q "$route" 2>/dev/null; then
            fp=$(echo -n "QD5|traversal|unvisited|$route|P-QD5-ui-traversal-deep" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
            sig=$(jq -nc \
              --arg route "$route" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-ui-traversal-deep",severity:"low",fixability:"agent_fix",domain:"functional",
                title:("Route not reachable from homepage: "+$route), description:"Route "+$route+" exists in code but was not reachable via link traversal from homepage. May be orphan route.",
                location:{file:"runtime",line:null,url:$route}, evidence:[{type:"search",path:"runtime",description:"Unvisited route: "+$route}],
                cdg_flags:[],fingerprint:$fp,
                remediation:{suggested_action:"Verify this route is linked from navigation. Add link or remove orphan route.",suggested_agent:"frontend-developer",estimated_effort:"low"},
                detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-ui-traversal-deep"}')
            SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
          fi
        done < "$RAW_OUT.routes"
      fi
    fi
    rm -f "$TRAV_DIR/traversal.js"
  fi
fi

rm -f "$RAW_OUT.routes"

jq -nc \
  --arg lane "wf-fix-ux-a11y" --arg probe "P-QD5-ui-traversal-deep" --arg pver "v1.0" \
  --arg profile "${PROFILE:-standard}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson signals "$SIGNALS_JSON" \
  '{$schema:"lane-signals-v1",lane:$lane,dimension:"QD5",probe_id:$probe,
    probe_version:$pver,profile:$profile,generated_at:$now,signals:$signals}' \
  > "$RAW_OUT"
```

## THINK

1. **HTTP error pages (4xx/5xx):** Page returns error status → HIGH. Broken link or route bug. Primary traversal failure.

2. **Soft 404 (200 but error content):** Page returns 200 but contains "not found" or "error" text → MEDIUM. Misleading HTTP status, SEO penalty.

3. **Console errors:** JavaScript errors during traversal → MEDIUM. May indicate broken features, missing dependencies, or runtime exceptions.

4. **Orphan routes:** Routes in code but no link reaches them → LOW. Could be orphan, or reachable only via URL direct entry.

5. **Interaction smoke:** Click buttons, verify no crash → catches event handler errors, missing state, null refs.

6. **Profile-based depth:** standard=10 links, deep=50 links, exhaustive=100 links + button interactions.
7. **Domain:** `functional` (page traversal is functional correctness, not just UX)
8. **Fixability:** `agent_fix` (frontend-developer)

## ACT

Output schema `signal-v2`:
- `dimension_id: "QD5"`, `domain: "functional"`
- `evidence[].type: "http_response"` voi status code
- `evidence[].type: "metric"` cho console error counts
- `remediation.suggested_action`: route/link fix guidance
- `remediation.suggested_agent: "frontend-developer"`

## VERIFY

1. Moi Signal co `dimension_id == "QD5"` va `domain == "functional"`
2. HTTP error signals co status code + URL trong evidence
3. Console error signals co error count metric
4. Orphan route signals co route path
5. Count visited routes — verify khong duplicate signals for same page
6. Severity: 500 errors→HIGH, 404→HIGH, soft errors→MEDIUM, orphan→LOW

## Severity Rules

| Pattern | Severity | Ly do |
|---------|----------|-------|
| HTTP 500 Internal Server Error | HIGH | Server crash or unhandled exception |
| HTTP 404 Not Found | HIGH | Broken link, dead page |
| HTTP 403 Forbidden (unexpected) | HIGH | Auth gate blocking valid user |
| Soft 404 (200 with error text) | MEDIUM | Misleading response, hidden error |
| Console errors (> 2 across pages) | MEDIUM | JS exceptions affecting functionality |
| Navigation timeout (> 15s) | MEDIUM | Page load performance issue |
| Button click causes crash | MEDIUM | Event handler error |
| Orphan route (not reachable via links) | LOW | May be intentional deep link |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong co BASE_URL | Skip probe, note "runtime_skipped_no_base_url" |
| Playwright khong available | Skip probe, note "runtime_skipped_playwright_unavailable" |
| Single-page app (all content loads via JS) | Increase waitFor timeout, retry once |
| Auth wall requires login | Skip protected pages, note "auth_required_pages_skipped" |
| Crawl hits external links | Filter: chi crawl same-origin links (starts with BASE_URL) |
| Page timeout due to slow API | Skip page, log timeout, continue with next URL |
