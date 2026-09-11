# P-QD5-keyboard-nav-check — Keyboard Navigation Verification

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD5-keyboard-nav-check |
| **Loai** | runtime |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Verify keyboard navigation: Tab order, focus indicators visible, focus traps (modals), skip links, no keyboard traps, Enter/Space/Escape key handlers on interactive elements. |
| **Cache** | skip (runtime probe) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co BASE_URL va khong co Playwright MCP -> SKIP, note "no_keyboard_test_tooling"
IF khong co frontend source dir -> SKIP, note "no_frontend_source"
IF profile=standard: chi chay static grep + basic tab check
IF profile=deep: bo sung modal focus trap verification
IF profile=exhaustive: bo sung all-page tab test + arrow key navigation
```

## SENSE

### B1: Static pre-check — grep for focus-visible, tabIndex, onKeyDown

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/raw/P-QD5-keyboard-nav-check.json"
mkdir -p "$(dirname "$RAW_OUT")"
SIGNALS_JSON='[]'
SOURCE="${SOURCE_DIR:-src/}"

# Static Check 1: Elements with positive tabIndex (bad practice — disrupts natural tab order)
grep -rnE 'tabIndex\s*[=:]\s*["\x27]?[1-9][0-9]*' "$SOURCE" \
  --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' \
  2>/dev/null | grep -vE '(node_modules|\.test\.|\.spec\.)' | head -15 | \
while IFS=: read -r file line match; do
  fp=$(echo -n "QD5|$file|$line|P-QD5-keyboard-nav-check|positive_tabindex" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc --arg file "$file" --argjson line "$line" --arg snip "${match:0:100}" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-keyboard-nav-check",severity:"medium",fixability:"agent_fix",domain:"accessibility",
      title:"Positive tabIndex disrupts natural tab order", description:("tabIndex > 0 tai "+$file+":"+($line|tostring)+". Disrupts natural DOM tab order, gay confusion cho keyboard users."),
      location:{file:$file,line:$line}, evidence:[{type:"code",path:$file,description:$snip}],
      cdg_flags:[],fingerprint:$fp,
      remediation:{suggested_action:"Avoid positive tabIndex. Use tabIndex=0 (include in order) or tabIndex=-1 (programmatic focus). Reorder DOM instead.",suggested_agent:"frontend-developer",estimated_effort:"low"},
      detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-keyboard-nav-check"}')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done

# Static Check 2: Non-interactive elements with onClick but no keyboard handler
grep -rnE 'onClick\s*=' "$SOURCE" \
  --include='*.tsx' --include='*.jsx' --include='*.vue' \
  2>/dev/null | grep -vE '(node_modules|\.test\.|\.spec\.)' | grep -vE '(onKeyDown|onKeyPress|onKeyUp|tabIndex|role\s*=\s*)' | \
while IFS=: read -r file line match; do
  # Check if it's on a div/span/non-interactive element (not button/a/input)
  elem=$(echo "$match" | grep -oE '<(div|span|li|td|p|img|svg)[^>]*onClick' || echo "")
  if [ -n "$elem" ]; then
    fp=$(echo -n "QD5|$file|$line|P-QD5-keyboard-nav-check|click_no_keyboard" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc --arg file "$file" --argjson line "$line" --arg snip "${match:0:100}" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-keyboard-nav-check",severity:"high",fixability:"agent_fix",domain:"accessibility",
        title:"Clickable non-interactive element thieu keyboard support", description:("Non-interactive element co onClick nhung khong co onKeyDown/role tai "+$file+":"+($line|tostring)+". Keyboard users cannot interact."),
        location:{file:$file,line:$line}, evidence:[{type:"code",path:$file,description:$snip}],
        cdg_flags:[],fingerprint:$fp,
        remediation:{suggested_action:"Add role='button', tabIndex=0, and onKeyDown (Enter/Space) handler. Or use <button> element instead.",suggested_agent:"frontend-developer",estimated_effort:"low"},
        detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-keyboard-nav-check"}')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  fi
done

# Static Check 3: Check for skip link presence
SKIP_COUNT=$(grep -rlcE '(skip.?link|skip.?nav|skip.?content|skipLink|SkipLink)' "$SOURCE" \
  --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' \
  2>/dev/null | grep -vE '(node_modules|\.test\.)' | wc -l)
if [ "$SKIP_COUNT" -eq 0 ]; then
  fp=$(echo -n "QD5|static|skip_link|P-QD5-keyboard-nav-check" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-keyboard-nav-check",severity:"medium",fixability:"agent_fix",domain:"accessibility",
      title:"Thieu skip-to-content link", description:"Khong tim thay skip navigation link. Keyboard users phai tab qua toan bo navigation de toi main content.",
      location:{file:"N/A",line:null}, evidence:[{type:"search",path:"N/A",description:"No skip link found in codebase"}],
      cdg_flags:[],fingerprint:$fp,
      remediation:{suggested_action:"Add skip-to-content link as first focusable element.",suggested_agent:"frontend-developer",estimated_effort:"low"},
      detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-keyboard-nav-check"}')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
fi
```

### B2: Runtime keyboard navigation test (Playwright, khi co BASE_URL)

```bash
if [ -n "${BASE_URL:-}" ]; then
  KB_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/runtime"
  mkdir -p "$KB_DIR"
  
  # Launch shared browser session (playwright-session.js — xem _shared.md §0)
  pw_launch || { echo "E096: browser_unavailable" >&2; exit 1; }
  
  cat > "$KB_DIR/keyboard-test.js" <<'KB_SCRIPT'
const { chromium } = require('playwright');
const fs = require('fs');
const baseUrl = process.env.BASE_URL;

(async () => {
  const state = JSON.parse(fs.readFileSync(process.env.SESSION_FILE, 'utf-8'));
  const browser = await chromium.connectOverCDP(state.wsEndpoint);
  const context = browser.contexts()[0] || await browser.newContext();
  const page = await context.newPage();
  const results = { focusableCount: 0, focusTraps: [], focusVisibleIssues: [] };
  
  try {
    await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(1000);
    
    // Count focusable elements
    results.focusableCount = await page.evaluate(() => {
      return document.querySelectorAll(
        'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
      ).length;
    });
    
    // Check if :focus-visible CSS is defined
    const focusVisibleStyles = await page.evaluate(() => {
      try {
        for (const sheet of document.styleSheets) {
          try {
            for (const rule of sheet.cssRules) {
              if (rule.selectorText && rule.selectorText.includes(':focus-visible')) {
                return true;
              }
            }
          } catch (e) {}
        }
      } catch (e) {}
      return false;
    });
    if (!focusVisibleStyles) {
      results.focusVisibleIssues.push('no_focus_visible_style');
    }
    
    // Tab through first 20 elements, check if focus moves
    let tabMoves = 0;
    let lastFocused = await page.evaluate(() => document.activeElement?.tagName || '');
    for (let i = 0; i < 20; i++) {
      await page.keyboard.press('Tab');
      await page.waitForTimeout(100);
      const current = await page.evaluate(() => document.activeElement?.tagName || '');
      if (current !== lastFocused) {
        tabMoves++;
        lastFocused = current;
      } else {
        break; // Focus stopped moving
      }
    }
    results.tabMoves = tabMoves;
    
  } catch (e) {
    results.error = e.message;
  }
  
  console.log(JSON.stringify(results));
  // Browser stays alive — shared session managed by playwright-session.js
})().catch(e => { console.error(e); process.exit(1); });
KB_SCRIPT

  if command -v npx &>/dev/null && npx playwright --version &>/dev/null 2>&1; then
    SESSION_FILE="$SESSION_DIR/playwright-session.json" BASE_URL="$BASE_URL" node "$KB_DIR/keyboard-test.js" > "$KB_DIR/kb-results.json" 2>/dev/null || true
    
    if [ -f "$KB_DIR/kb-results.json" ]; then
      FOCUSABLE=$(jq -r '.focusableCount // 0' "$KB_DIR/kb-results.json" 2>/dev/null)
      TAB_MOVES=$(jq -r '.tabMoves // 0' "$KB_DIR/kb-results.json" 2>/dev/null)
      NO_FOCUS_VISIBLE=$(jq -r '.focusVisibleIssues | length' "$KB_DIR/kb-results.json" 2>/dev/null)
      
      # Check 1: Very few focusable elements
      if [ "$FOCUSABLE" -lt 3 ] 2>/dev/null && [ "$FOCUSABLE" -gt 0 ] 2>/dev/null; then
        fp=$(echo -n "QD5|runtime|few_focusable|P-QD5-keyboard-nav-check" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
        sig=$(jq -nc --argjson count "$FOCUSABLE" --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-keyboard-nav-check",severity:"medium",fixability:"agent_fix",domain:"accessibility",
            title:("It focusable elements: "+($count|tostring)+" found"), description:"Very few focusable elements found on page. Interactive elements may be missing proper roles/attributes.",
            location:{file:"runtime",line:null,url:null}, evidence:[{type:"metric",path:"runtime",description:($count|tostring)+" focusable elements"}],
            cdg_flags:[],fingerprint:$fp,
            remediation:{suggested_action:"Ensure all interactive elements use native interactive HTML (<button>, <a>, <input>) or have role + tabIndex.",suggested_agent:"frontend-developer",estimated_effort:"medium"},
            detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-keyboard-nav-check"}')
        SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
      fi
      
      # Check 2: No :focus-visible styles
      if [ "$NO_FOCUS_VISIBLE" -gt 0 ] 2>/dev/null; then
        fp=$(echo -n "QD5|runtime|no_focus_visible|P-QD5-keyboard-nav-check" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
        sig=$(jq -nc --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-keyboard-nav-check",severity:"high",fixability:"agent_fix",domain:"accessibility",
            title:"Thieu :focus-visible CSS style", description:"No :focus-visible CSS rules found. Keyboard users cannot see which element is currently focused.",
            location:{file:"runtime",line:null,url:null}, evidence:[{type:"metric",path:"runtime",description:"No :focus-visible rules in stylesheets"}],
            cdg_flags:[],fingerprint:$fp,
            remediation:{suggested_action:"Add :focus-visible outline styles to interactive elements. Default browser focus ring may not be sufficient.",suggested_agent:"frontend-developer",estimated_effort:"low"},
            detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-keyboard-nav-check"}')
        SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
      fi
      
      # Check 3: Tab seems trapped (moves < 2)
      if [ "$TAB_MOVES" -lt 2 ] 2>/dev/null && [ "$FOCUSABLE" -gt 3 ] 2>/dev/null; then
        fp=$(echo -n "QD5|runtime|possible_trap|P-QD5-keyboard-nav-check" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
        sig=$(jq -nc --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{$schema:"signal-v2",dimension_id:"QD5",probe_id:"P-QD5-keyboard-nav-check",severity:"critical",fixability:"agent_fix",domain:"accessibility",
            title:"Possible keyboard focus trap detected", description:"Tab key stopped moving focus despite focusable elements present. Possible focus trap — keyboard users cannot navigate away.",
            location:{file:"runtime",line:null,url:null}, evidence:[{type:"metric",path:"runtime",description:"Tab stopped after few moves"}],
            cdg_flags:[],fingerprint:$fp,
            remediation:{suggested_action:"Check for focus trap (modal without Escape handler, aria-hidden issues). Add Escape key handler to close traps.",suggested_agent:"frontend-developer",estimated_effort:"medium"},
            detected_at:$now,detected_by:"wf-fix-ux-a11y/P-QD5-keyboard-nav-check"}')
        SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
      fi
    fi
    rm -f "$KB_DIR/keyboard-test.js"
  fi
fi

jq -nc \
  --arg lane "wf-fix-ux-a11y" --arg probe "P-QD5-keyboard-nav-check" --arg pver "v1.0" \
  --arg profile "${PROFILE:-standard}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson signals "$SIGNALS_JSON" \
  '{$schema:"lane-signals-v1",lane:$lane,dimension:"QD5",probe_id:$probe,
    probe_version:$pver,profile:$profile,generated_at:$now,signals:$signals}' \
  > "$RAW_OUT"
```

## THINK

1. **Positive tabIndex:** tabIndex > 0 disrupts natural DOM order → MEDIUM. Users expect tab to follow visual layout. Use DOM reorder instead.
2. **Clickable non-interactive elements:** div/span with onClick but no onKeyDown → HIGH. Keyboard users cannot trigger actions. Add role="button" + keyboard handlers.
3. **Missing skip link:** No skip-to-content link → MEDIUM. Keyboard users must navigate entire nav. Should be first focusable element.
4. **No :focus-visible style:** Missing focus indicator → HIGH. Users don't know where they are on the page. Critical for keyboard navigation.
5. **Possible focus trap:** Tab stops working → CRITICAL. User cannot leave current area. Check modals, dialogs, dropdowns.
6. **Domain:** `accessibility`
7. **Fixability:** `agent_fix` (frontend-developer)

## ACT

Output schema `signal-v2`:
- `dimension_id: "QD5"`, `domain: "accessibility"`
- Static signals: `evidence[].type: "code"` voi source snippet
- Runtime signals: `evidence[].type: "metric"` voi focusable count, tab moves
- `remediation.suggested_action`: keyboard support implementation guidance

## VERIFY

1. Moi Signal co `dimension_id == "QD5"` va `domain == "accessibility"`
2. Focus trap detection → severity CRITICAL
3. Missing focus-visible → severity HIGH
4. onClick without keyboard → severity HIGH
5. Skip link missing → severity MEDIUM
6. Positive tabIndex → severity MEDIUM

## Severity Rules

| Pattern | Severity | Ly do |
|---------|----------|-------|
| Keyboard focus trap (cannot Tab forward) | CRITICAL | User stuck, cannot navigate away |
| Clickable element without keyboard support | HIGH | Keyboard-only users cannot interact |
| Missing :focus-visible CSS style | HIGH | User cannot see current focus location |
| Thieu skip-to-content link | MEDIUM | Inefficient navigation for keyboard users |
| Positive tabIndex (>0) disrupts order | MEDIUM | Unpredictable tab order |
| Few focusable elements (< 3) | MEDIUM | Possible missing interactive semantics |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong co BASE_URL | Chi chay static checks, note "runtime_skipped_no_base_url" |
| Playwright khong available | Chi chay static checks, note "runtime_skipped_playwright_unavailable" |
| JavaScript-heavy app (focus elements loaded async) | Extend wait timeout, retry once |
| Page khong interactive (SSG landing page) | Skip runtime, emit empty signals, note "static_page" |
| Focus trap detected (some apps trap Tab intentionally in modals) | Distinguish: dialog[aria-modal] with Escape → OK. No Escape → flag |
